# Saas_erp — 2026-11-02

## Bağlam
İstek: "Entegrasyon testlerini, E2E testlerini yazar mısın sisteme." Başlangıç durumu:
`tests/integration` altında 37 dosyalık DB seviyesi test vardı (handler + Testcontainers Postgres),
ama HTTP seviyesinde (gerçek API boru hattı) test yoktu; Playwright/E2E hiç yoktu. Tek HTTP testi
(`HealthCheckTests`) `CustomWebApplicationFactory` ile `Development` ortamında açılıyordu →
`appsettings.Development.json`'u (paylaşımlı DEV DB) okuyup açılış migration'ını oraya uygulayabiliyordu.

## Yapılanlar

### 1. API entegrasyon test altyapısı (gerçek Program + Testcontainers)
- **Neden:** middleware zinciri, JWT, tenant çözümü, modül kapısı, ApiResponse zarfı ve gerçek Postgres
  davranışı (Gridify filtresi, unique index) bellek içi testlerle görülmüyor.
- **Ne yapıldı:** `ApiTestHost` (xUnit collection fixture "Api"): Postgres 17 + redis:7-alpine container,
  ayrı Hangfire DB'si, bağlantılar **ortam değişkeniyle** (CreateBuilder anında okunur, en yüksek öncelik),
  ortam `Testing` (Development json yüklenmez), MQTT boş port, dış servisler 127.0.0.1:1.
  Açılış sonrası `AssertIsolated`: DefaultConnection container'ı göstermiyorsa koşu durur.
  Seed admin `admin@e2e.test`, şifre her koşuda rastgele. `TenantAsync("A"/"B")`: süper admin ile firma
  açar (`POST /api/v1/admin/tenants`, plan pro) + tüm modülleri açar (`PUT .../modules`), sahibiyle giriş.
  Token cache: "auth" rate limit kovası süreç geneli 10 istek / 5 dk → kullanıcı başına tek giriş.
- **Testler (22):** AuthFlow (hatalı şifre 401 `auth.invalid_credentials`, token yok/sahte 401, me,
  refresh rotasyonu + yeniden kullanım → tüm oturum düşer), TenantIsolation (B, A'nın carisini ID/liste/
  güncelleme ile göremez; aynı kod iki firmada serbest; yabancı X-Tenant-Id red; başlıksız red; tenants/my),
  CurrentAccount (round-trip, 409 `crm.current_account.duplicate_code`, 400, Gridify filtre+pagination,
  trim), InventoryItem (oluştur/oku/filtre, 400, başka firmadan 404), Platform (health live/ready,
  güvenlik başlıkları, owner → admin 403).
- **Dokunulan dosyalar:** `tests/integration/VuoApp.IntegrationTests/Api/*.cs`, csproj (+Testcontainers.Redis 4.16.0);
  silinen: `Fixtures/CustomWebApplicationFactory.cs`, `HealthCheckTests.cs`.
- **Komutlar:**
  ```bash
  dotnet test tests/integration/VuoApp.IntegrationTests --filter "FullyQualifiedName~VuoApp.IntegrationTests.Api"
  ```
- **Sonuç:** ilk koşu: JWT key ≥64 byte istendi (düzeltildi); sonra boş DB'de platform seed çöktü (madde 2). Sonra 22/22.

### 2. Bulunan hata: boş DB'de platform seed `IX_Module_Code` ile çöküyor
- **Neden:** `SeedMissingSidebarModules` vb. veri migration'ları Plan boşken de `saas.Module`'e satır ekliyor;
  `SaasDataSeeder` "Plan yoksa her şeyi ekle" diyerek aynı kodları tekrar ekliyordu → fail-fast → API açılmıyor
  (yeni sunucu / felaket kurtarma senaryosu).
- **Ne yapıldı:** TDD — `Saas/SaasDataSeederFreshInstallTests.cs` önce kırmızı. Düzeltme yazıldı, ama rebase'de
  gördüm ki Arda `6f984d02`'de aynı hatayı bağımsız düzeltmiş → onun sürümü alındı, benim seeder değişikliğim
  atıldı; test onun düzeltmesinin regresyon testi olarak kaldı.

### 3. Playwright E2E (`tests/e2e`, kendi paketi)
- **Neden:** gerçek tarayıcıda kullanıcı akışları; frontend package.json'a dokunmamak için ayrı paket.
- **Ne yapıldı:** projeler: `setup` (giriş formu → `/tenants/my` → `active_tenant_id` → `.auth/user.json`),
  `public` (korumalı sayfa → login, kayıtsız adresle hatalı giriş — gerçek kullanıcının 5'te kilit sayacına
  dokunmaz —, şifre göster, /tanitim, /yenilikler), `app` (17 modül ekranı duman testi: error boundary metni /
  pageerror / API 5xx yok; cari `?edit=<id>` paylaşım linki — veri API ile `E2E-*` koduyla üretilip siliniyor;
  oturum kalıcılığı / token silinince login).
- **Tuzak:** testMatch `/app\//` Windows'ta tam yol `vuo-app/...` olduğu için public testleri de yakaladı →
  desenler `specs[\\/]app[\\/]` ile sabitlendi.
- **Komutlar:**
  ```bash
  cd tests/e2e && npm install && npx playwright install chromium
  bash <eski-scratchpad>/local-up.sh        # origin/dev'den local stack (:3131/:5240)
  E2E_EMAIL=... E2E_PASSWORD=... npx playwright test
  ```
- **Sonuç:** 27/27 (3.0 dk), local stack @ origin/dev d8d23c32.

### 4. Doğrulama + push
- Unit 7321/7321. Entegrasyon suite: 22 **önceden var olan** kırmızı (ör. `CK_ProductionOrder_WeavingKind`
  test verisini reddediyor) — yeni testler hariç tutulunca da aynı 22, yani bu işten bağımsız.
- Rebase'de çakışma: SaasDataSeeder (upstream alındı), autostash'te agent-audit.log (işaretler temizlendi).
- **Commit:** `2cdcb12d` — test(e2e,integration): gercek API + Testcontainers entegrasyon testleri ve Playwright E2E

## Kararlar
- Kurul çalıştırılmadı: iş yalnız test ekleme + test altyapısı (review-board "kapsam dışı: test ekleme");
  üretim koduna dokunan seeder düzeltmesi upstream'de zaten vardı.
- Entegrasyon testleri CI/`verify.sh` kapısına EKLENMEDİ (Docker gerektiriyor, mevcut 22 kırmızı kapıyı kırar) — öneri.
- Yenilikler (changelog) maddesi yok: kullanıcıya görünen değişiklik yok.

## Açık kalanlar / sonraki adım
- Önceden var olan 22 kırmızı entegrasyon testi düzeltilmeli (çoğu Inventory receipt / Production fixture'ları).
- Sonra `tools/verify.sh`'e `integration` adımı + CI'da Docker'lı job.
- E2E için ayrı bir test kullanıcısı/firması (DEV'de admin@vuo.app kullanıldı).
- Kapsam genişletme: satın alma/satış zinciri (talep→sipariş→irsaliye→fatura) — `docs/qa/VuoApp_Test_Senaryolari.xlsx` entegrasyon sayfası.
