# pbxtr — 2026-10-26

## Bağlam
Kalan kartların bitirilmesi turu (kurul dağıtık, soru yok). backend-dev-1'e dört kart:
BR-BE-277, BR-BE-278, BR-BE-282, BR-OPS-21. Paralel çalışan backend-dev-2'nin (CDR/ETL)
yarım dosyalarına dokunulmadı; commit'ler `git commit --only -- <yollar>` ile.

## Yapılanlar

### 1. BR-BE-277 — santral tenant'ında dahili kotası
- **Neden:** t1001'de (kind=pbx) ikinci dahili reddedildi; limit elle 30'a çekilmişti.
- **Ölçüm:** Dahili ekleme ucu (`EfExtensionAdministration`) zaten yalnız `extension_limit`'e
  bakıyor. Engel provisioning'deydi: `ConfigRenderGuard.AssertAgentQuota` üretilen PJSIP endpoint
  sayısını `tenants.agent_limit`'e karşı ölçüyor → 409 PROVISIONING_BLOCKED extensions/count.
  Sunucuda: t1001 pbx agent=30 ext=30 (12 dahili), t1002 pbx agent=2 ext=5.
- **Ne yapıldı:** `TenantEndpointQuota.For(kind, agentLimit, extensionLimit)` (Domain): pbx →
  `extension_limit` (null = kapı koşmaz, dahili ucuyla aynı anlam); call_center/hybrid/boş →
  `agent_limit` (değişmedi). `ProvisioningRevisionService` tür bilgisini zaten okuduğu modül
  anlık görüntüsünden (`EfTenantModuleResolver.ReadAsync().Kind`) alır, ek sorgu yok. Bayi kotası
  (§10/1) bu yola dokunmaz.
- **Dokunulan dosyalar:** `src/Pbxtr.Domain/Modules/Tenancy/TenantEndpointQuota.cs`,
  `src/Pbxtr.Infrastructure/Provisioning/ProvisioningRevisionService.cs`,
  `tests/Pbxtr.Api.Tests/Modules/Tenancy/TenantEndpointQuotaTests.cs`
- **Sonuç / doğrulama:** 9 test (helper + `ConfigRenderer.Render` üzerinden). Mutasyon
  (`? extensionLimit` → `? agentLimit`) 4 testi kırdı. Bağlantı satırı (servisin helper'ı
  çağırması) yalnız kodla, entegrasyonla ölçülmedi.
- **Commit:** `949dc07b` — BR-BE-277: santral (pbx) tenant'inda dahili kotasi extension_limit

### 2. BR-BE-282 — telefon özellik kodu denetiminde aktör adı
- **Neden:** `*28/*29`, `*78/*79`, yönlendirme satırlarında actor_name boş.
- **Ne yapıldı:** `ExtensionFeatureActor`'a `ActorName`; telefon yolunda dahili sahibinin görünen
  adı (`ExtensionForwardingAdminRow.UserDisplayName`, zaten okunuyordu), sahipsiz dahilide
  "telefon"; gece modu (`NightModeService`) aynı adı alır. Panel yolu (`FromHttp`) JWT `name`
  — orada da boştu, aynı turda doldu.
- **Dokunulan dosyalar:** `src/Pbxtr.Api/Modules/Telephony/ExtensionFeatureService.cs`,
  `src/Pbxtr.Api/Modules/Telephony/FeatureCodeEndpoints.cs`,
  `tests/Pbxtr.Api.Tests/Modules/Telephony/FeatureCodeEndpointTests.cs`
- **Sonuç:** fikstüre sahip kullanıcı satırı eklendi; yönlendirme/DND/gece modu + yeni
  "sahipsiz → telefon" testi. Mutasyon (`ActorName: null`) 3 testi kırdı.
- **Commit:** `b22601c7`

### 3. BR-BE-278 — yeni tenant düğüm anahtarıyla doğar
- **Ölçüm:** confd tenant'ı `api_keys.node` üzerinden keşfediyor (node-bundle); edge
  `/etc/pbxtr-edge/credentials/api-keys` dosyasında `tNNNN keyid.secret` açık değer istiyor;
  pbxtr yalnız özeti saklar. Sahipte `apikey.manage` yok; olsa bile `/api/v1/api-keys` düğüm adı
  + IP listesini istekten aldığı için Kurul #77 yolunu açardı.
- **Ne yapıldı:**
  - `Telephony:NodeKey:Node` + `IpAllowlist` (platform kararı; boş = üretilmez ve yanıt
    `nodeKey.status=not_configured`; dolu ama geçersiz IP = uygulama açılmaz, ValidateOnStart).
  - `POST /api/v1/tenants` (süper admin + bayi, tek uç): anahtar `EfTenantProvisioning`
    işleminde tenant ile AYNI transaction'da yazılır (özet), `apikey.created` denetimi
    (`origin=tenant.create`), açık değer yanıtın `nodeKey.plaintextKey`'inde bir kez.
  - `GET /api/v1/tenant/node-key` + `POST /api/v1/tenant/node-key/rotation` (`tenant.manage`):
    rotasyon eskiyi iptal eder, yeni üretir; sahip yalnız VAR OLAN üyeliği yeniler, ilk bağlantı
    yalnız global kapsam (Kurul #77), `not_delivered` niyette yalnız global (Karar #58).
  - Edge elle adımı `deploy/pbxtr-edge/README.md` "Tenant anahtari" bölümünde; edge kodu
    DEĞİŞMEDİ. Compose eşlemesi + env şablonu eklendi.
- **Dokunulan dosyalar:** `src/Pbxtr.Api/Modules/Security/TenantNodeKey{Endpoints,Options}.cs`,
  `src/Pbxtr.Api/Modules/Tenancy/TenantEndpoints.cs`, `src/Pbxtr.Api/Program.cs`,
  `src/Pbxtr.Domain/Modules/Tenancy/ITenantProvisioning.cs`,
  `src/Pbxtr.Infrastructure/Modules/EfTenantProvisioning.cs`, testler
  (`TenantNodeKeyOptionsTests`, `TenantNodeKeyHttpTests`, `TenantCreateHttpTests`),
  `doc/ekran-yazma-yollari.md` (yeniden üretildi, 256→257), `deploy/pbxtr-edge/README.md`,
  `deploy/pbxtr.env.example`, `pbxtr-demo/docker-compose.yml`
- **Komutlar:** entegrasyon sunucuda: `git archive HEAD` + değişen dosyalar →
  `/root/pbxtr-it-278`, SDK konteyneri `--network host` + docker.sock, nohup + `EXIT=`.
- **Sonuç:** Integration 10/10 (TenantNodeKey + TenantCreate + ApiKeyForeignNodePin +
  ApiKeyNodePin). İki ilk koşu kendi test hatamdı (`roles.code` global tekil; DateTime cast).
  Mutasyonlar: komuttan NodeKey düşürme → kırmızı; üyelik kuralını kapatma → kırmızı (201).
- **Commit:** `5e1da098`

### 4. BR-OPS-21 — ortak demo parolası
- **Ölçüm:** eski parola 11 karakter (politika 12). İç adresle (172.28.0.11:5080) giriş
  denemesi: 16 kullanıcı ortak parolayla giriyordu — demo.superadmin, demo.admin, demo.bayi,
  demo.sahip, demo.supervizor, demo.agent, demo.wallboard, demo.fabrika, 1043–1047, 2011–2013.
  (kuzey.sahip, deneme.* farklı parola; fabrika.* rastgele.) Dış adres python urllib'e 403
  veriyor (CDN), curl ile 401/200 normal.
- **Ne yapıldı:** 20 karakter rastgele (harf+rakam) parola; 16 kullanıcı ürün yoluyla
  `POST /api/v1/me/password` (eski → yeni) değiştirildi; sonra yalnız `PBXTR_SAMPLE_PASSWORD`
  satırı üç yerde güncellendi (yerel `pbxtr-demo/.env`, sifreler kopyası, sunucu
  `/home/vuo/pbxtr-demo/.env`), aynı turda `Telephony__NodeKey__*` satırları eklendi.
  Betik: `align_owner_password` ham SQL yerine süper admin `password-reset` + sahip
  `/me/password`; `attach_to_node` önce tenant yanıtındaki `nodeKey`, sonra
  `/tenant/node-key/rotation`, en son #57 yolu.
- **Sonuç:** `https://app.pbxtr.com/api/v1/auth/login` 16/16 → 200. Sunucudaki geçici betikler
  ve `.env` yedeği silindi. Parola hiçbir çıktıya/commit'e girmedi (commit'lerde arandı: 0).
- **Commit:** `75527fd2` (pbxtr), `c0583ba` (sifreler)

## Testler
- Architecture 858: 854 geçti; 4 kırmızıdan 1'i benim (ekran yazma kanıt tablosu,
  yeniden üretildi → yeşil), 3'ü backend-dev-2'nin yarım ETL dosyaları (RawSql/CallDataSource).
- Api.Tests: Platform 1501 (2 skip), Modules.Telephony 1744 (2 skip), Tenancy+Security 390,
  diğer Modules 3686 (27 HTTP 100 sn zaman aşımı → aynı 27 sınıf yeniden: 756/756), rest 9.
- `dotnet format --verify-no-changes`: LF kopyada (sunucu konteyneri) değişen .cs'ler temiz.

## Kararlar
- Hibrit tenant bilerek agent kotasında kaldı (kota gevşetme geri alınamaz satış kararı).
- Sahip için yeni yetki uydurulmadı: `tenant.manage` (IP kuralları ile aynı gerekçe).
- Edge dosyasını ürün yazmaz (yalnız özet saklanır, SSH yok) — elle adım runbook'ta.

## Açık kalanlar / sonraki adım
- **Yayın gerekli** (277/278/282 kodu + compose eşlemesi). Sunucu `.env`'inde NodeKey değerleri
  hazır; compose yayınla gelince etkin olur. Edge değişmedi.
- FE: #57/ayarlarda düğüm anahtarı durumu + yeniden üretme düğmesi yok (uç hazır).
- `deploy/env-esleme-kontrol.sh` önceden kırmızı: PhoneProvisioning__* şablonda yok (benim değil).
- Uygulama konteyneri `Bootstrap__SampleUserPassword` eski değeri yayına kadar taşır (yalnız
  yeni örnek kullanıcı tohumlar).
