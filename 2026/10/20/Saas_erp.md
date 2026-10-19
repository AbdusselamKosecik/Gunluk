# Saas_erp — 2026-10-20

## Bağlam
19 Ekim'deki CI hızlandırma (33 dk → ~6 dk) bitmişti. Kullanıcı yeni istek verdi: Santral ve PMS menülerden ve
modüllerden kalksın (yapılmayacak), self-signup kalksın, yönetici yeni firma açsın; firma yönetimi Pbxtr'deki gibi
olsun (firma listesi, kullanıcıları görme, kullanıcıya bürünme, yeni kullanıcı, mevcut kullanıcıyı atama, admin yapma).
Önce landing ekranı için bir Claude Design promptu istendi.

## Yapılanlar

### 1. Landing için Claude Design promptu
- **Neden:** Kullanıcı landing tasarımını Claude Design'da yaptıracak.
- **Ne yapıldı:** Tek sayfa landing promptu. Turuncu #D35400 + Inter; "Kayıt ol" yok, "Demo talep et" + "Giriş yap";
  hero, güven şeridi, 6 üretim alt modülü, modül ızgarası (Santral/PMS yok), nasıl çalışır (hesabı biz açarız),
  yetenekler, sayılar, SSS, kapanış CTA, KVKK onaylı demo formu, footer.
- **Dokunulan dosyalar:** `docs/design/landing-claude-design-prompt.md`
- **Commit:** `6a80103a` — docs: landing sayfasi icin Claude Design promptu

### 2. Keşif
- Pbxtr (`X:\GitHub\Pbxtr\pbxtr`) tenant yönetimi: tenant listesi + oluşturma sihirbazı (sahip için tek seferlik
  şifre), kullanıcı listesi/detay, rol seçici, "Bu kullanıcı olarak çalış" (30 dk JWT, refresh yok, kapatılamaz banner,
  "Kendi hesabıma dön", denetim kaydı), self-signup yok.
- VuoApp'te zaten var olan: admin tenant listesi (askıya al/aktif et/modüller/"Giriş Yap" = süper admin kendi kimliğiyle),
  tenant düzenleme (ad, paket, üyeler, mevcut kullanıcı ekle, rol değiştir, çıkar, şifre, e-posta onayı, üye modül yetkisi).
  Eksik olan: gerçek bürünme, admin'in yeni kimlik açması, admin'in tenant açması. Self-signup yolları: auth/signup,
  onboarding/complete, POST /tenants (herkese açıktı).

### 3. Kurul
- cto, skeptic, dba, product-owner → APPROVE-WITH-CONDITIONS; security-reviewer → PASS-WITH-NOTES. BLOCK yok.
- Önemli şartlar: bürünme token'ı tek tenant'a sabit (imp_tid) ve is_super_admin=false; bürünmede kimlik/yönetim
  mutasyonları 403; frontend 401'de admin refresh'ine düşmesin, tek token erişimcisi; geçici şifre Dragonfly idempotency
  önbelleğine/loglara girmesin; signup kontrolü controller'da (handler testleri bozulmasın); boş DB'de migration 0 satır
  günceller → seeder da modülleri pasif eklemeli; AlwaysCreateNew'da "kazanan tenant'ı döndür" ve DefaultTenantId ezme yok.
- Karar: sunucu şifre üretmez, **yönetici şifreyi formda girer** (rastgele oluştur/kopyala butonu). Böylece şifre yanıtta
  dönmez, önbelleğe/loga düşmez. "İlk girişte şifre değiştirmeye zorla" şema gerektirdiği için ertelendi.

### 4. Santral (ast) + PMS gizleme
- **Ne yapıldı:** `saas."Module".IsActive=false` (pms, ast). Module.IsActive enabled-modules hesabında
  (IntersectWith), admin modül listesinde, modül mağazasında, fiyat seed'inde zaten süzülüyor. Ek olarak menüde
  `isNav:false`, API anahtarı scope listesinden çıkarıldı. Kod/tablolar silinmedi.
- **Dokunulan dosyalar:** `VuoApp.Migrator/Migrations/20261019211725_DeactivatePmsAndAstModules.cs` (Down=true),
  `VuoApp.Modules.Saas/Seed/SaasDataSeeder.cs` (IsActive=false), `routes.tsx`, `api_keys.page.tsx`.
- **Komutlar:**
  ```bash
  # design-time için sahte bağlantı (Migrator connection string ister, DB'ye bağlanmaz)
  ConnectionStrings__DefaultConnection='Host=localhost;Port=5432;Database=design;Username=x;Password=x' \
    dotnet ef migrations add DeactivatePmsAndAstModules --project src/backend/VuoApp.Migrator --context MigratorDbContext --no-build
  node tools/strip-migration-designers.mjs   # 110 Designer, 1 inceltildi
  ```
- Migration API açılışında paylaşımlı dev DB'ye uygulandı (log: "1 bekleyen migration uygulanıyor").

### 5. Self-signup kapatma
- `Auth:SelfSignupEnabled` (varsayılan false; appsettings.json + Development.example). auth/signup ve onboarding/complete
  controller'da 403 `Auth.SelfSignupDisabled` (kullanıcı oluşturulmadan). POST /api/v1/tenants handler'da yalnız süper
  admin. auth/register açık (davet kabul sayfası kullanıyor; tenantsız hesap hiçbir veriye erişemez).
- Frontend: login'den "Kayıt olun" kalktı; /auth/register ve /onboarding/signup → /auth/login; firmasız kullanıcı
  `/no-tenant` ("firmanıza bağlı değilsiniz"), firmasız süper admin → /admin.

### 6. Admin firma/kullanıcı + hesap pasifleştirme
- `POST /api/v1/admin/tenants` {companyName, ownerEmail, ownerDisplayName, ownerPassword?, planCode?} — mevcut e-posta →
  o kullanıcı owner; yeni → şifre zorunlu. TenantProvisioner `AlwaysCreateNew` ile her zaman yeni tenant. Plan yoksa "free".
- `POST /api/v1/admin/tenants/{id}/members/new` {email, displayName, password?, role} — pasif üyeliği yeniden aktifler.
- `PUT /api/v1/admin/users/{id}/active` — kendini/süper admini pasifleyemez; pasiflemede refresh token'lar revoke.
  GET admin/users/{id} artık `isActive` döner (IUserProvisioner.IsActiveAsync).
- Ekranlar: "Yeni Firma" ve "Yeni Kullanıcı" diyalogları (ortak şifre sonuç bileşeni), kullanıcı detayında
  Pasifleştir/Aktifleştir.

### 7. Kullanıcıya bürünme
- `POST /api/v1/admin/tenants/{t}/members/{u}/impersonate` → `IImpersonationTokenIssuer` (Domain arayüzü, Identity impl).
  Kurallar: süper admin, hedef ≠ kendisi, hedef aktif, hedef süper admin değil, hedefin o tenant'ta aktif üyeliği var;
  ret tek tip 403 `Admin.ImpersonationNotAllowed`, sebep audit'e. Token 30 dk, refresh yok, claim'ler: hedefin
  sub/email/name, is_super_admin=false, act_sub, act_name, imp_tid.
- `ImpersonationGuard` (TenantResolutionMiddleware): X-Tenant-Id ≠ imp_tid → 403; GET dışı istekler
  auth/profile/api-keys/tenants/admin/onboarding/roles/permissions/saas/stripe → 403. NotificationHub imp_tid'e sabit.
  ICurrentUser.ImpersonatorId (default member), Serilog LogContext ImpersonatorId, audit newValues'a impersonatorId.
- Frontend: `src/core/auth/session.ts` tek erişimci; bürünme verisi sessionStorage'da (sekmeye özel), admin localStorage
  token'larına dokunulmaz; axios + iki SignalR hub'ı buradan okur; 401'de refresh denenmez, bürünme biter. Bürünmede
  profil `POST /auth/provision` yerine `GET /auth/me`'den (ilk sürümde provision guard'a takılıp admini düşürüyordu —
  UX kontrolü yakaladı). Kapatılamaz turuncu banner + "Kendi hesabıma dön"; başlatmadan önce onay diyaloğu.
  Süper admin olmayan /admin* → "/" (ön yüz koruması yoktu).

### 8. UX kontrolü bulguları ve düzeltmeler
- Admin ekranlarında Türkçe karakterler (Kullanıcılar, Üyeler, Şifre Değiştir…), AdminUsers.menu/AdminBilling.menu
  i18n anahtarları, dialog "Close" → "Kapat", 375px taşma (overflow-x-auto, flex-wrap), "Açılıyor…" bekleme durumları,
  pasifleştirmede rozet anında güncellenir, kullanıcı aramasında 300 ms debounce.
- Admin kullanıcı araması 500: Gridify filtresi record constructor projeksiyonu üzerinde SQL'e çevrilemiyordu →
  filtre/sıralama/sayfa UserProfile üzerinde, projeksiyon en sonda (`GetAllUsers.cs`, test `GetAllUsersTests`).

- **Doğrulama:** backend build 0 hata/0 uyarı, unit 3880 geçti (3 skip). Frontend typecheck 0 hata, vitest 828 geçti,
  7 kırmızı hepsi önceden var (i18n parity, login jsdom SVG, orders worklist). Tarayıcıda (headless Chrome):
  login'de kayıt linki yok, Santral/PMS yok, firma açma, yeni kullanıcı, admin yapma, bürünme başlat + banner + Yönetim
  menüsü gizli + admin token korunuyor + "Kendi hesabıma dön", pasifleştir/aktifleştir, 375px'te genişlik 375.
  Güvenlik son kontrolü PASS-WITH-NOTES (iki Low not uygulandı: hub imp_tid, saas/stripe bloğu).
- **Commit:** `12e673be` — feat(admin): yonetici firma/kullanici acar, kullaniciya burunme; kayit kapandi, Santral/PMS gizlendi

## Kararlar
- Kod silinmez, modül pasiflenir (geri dönüş: migration Down / config true).
- Şifreyi yönetici girer; sunucu üretmez/döndürmez.
- auth/register açık kalır (davet akışı).
- Bürünme oturumu sessionStorage'da; sayfa yenilense de sekmede sürer, sekme kapanınca biter.

## Açık kalanlar / sonraki adım
- **GitHub Actions çalışmıyor:** 6a80103a ve 12e673be koşuları "recent account payments have failed or your spending
  limit needs to be increased" ile başlamadı → DEV'e deploy olmadı. Kullanıcı GitHub Billing'i düzeltince son commit
  için workflow yeniden tetiklenmeli (`gh run rerun 39331116063`).
- İlk girişte şifre değiştirmeye zorlama (User'a alan + migration) — ürün sahibi önerdi, ertelendi.
- Paylaşımlı dev DB'de test verisi: "UX Test Firma 2010", ux-test-2010@vuo.app, ux-user-2010@vuo.app.
- Önceden var olan: `VuoApp.Api/Hubs/NotificationHub.SendToTenant` herhangi bir girişli kullanıcının herhangi bir tenant
  grubuna mesaj göndermesine izin veriyor (yetki kontrolü yok) — ayrı iş olarak ele alınmalı.
- Tailscale üzerinden dev sunucuya ping ~1.1 sn idi (yerelde sayfalar 20-30 sn yükleniyordu) — ağ kaynaklı.
