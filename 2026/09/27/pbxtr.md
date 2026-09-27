# pbxtr — 2026-09-27

## Bağlam
Dün (`2026/09/26/pbxtr.md`) `yonetim/bekleyen-maddeler.md` turu bitmiş, iki kart kullanıcı
kararına kalmıştı: **BR-BE-43-B** (paylaşılan düğümde pinsiz anahtar) ve **BR-DB-67** (bayinin ev
tenant'ı). Kullanıcı bugün karar verdi:
- *"1. onerdigini yap"* → 43-B için önerdiğim daraltılmış kural.
- *"2. ayri bir tenat turu olmasi lazim zaten"* → 67'de bayiye ayrı tenant türü.

Genel kural aynı: kodu yaz, testi kullanıcı yapar; kalanı yalnız test olan kart Bitti'ye çekilir.

## Yapılanlar

### 1. BR-BE-43-B — paylaşılan düğümde pinsiz anahtar 403 `NODE_SHARED_UNPINNED`
- **Neden:** Kartın ilk tanımı ("pinsiz düğümde ikinci tenant 409") pinsiz anahtarın düğümünü
  SAKLAMAYI gerektiriyordu. Karar #66 İ2 bu değerin istemci başlığından yazılmasını yasaklıyor
  (sahte başlıkla başka tenant'a 409 yedirilebilirdi). Pinsiz anahtarın sunucuda çözülebilir bir
  düğüm kimliği de yok.
- **Ne yapıldı (kullanıcının onayladığı kural):** `/provisioning/bundle`'da pinsiz anahtar
  `X-Pbxtr-Node`'daki düğümden çekerken o düğüme **başka tenant'ın pinli anahtarı** varsa 403.
  Küme sunucudaki pinlerden (`IProvisioningNodeDirectory.ListTenantsForNodeAsync`) gelir. Kapı
  hiçbir şey yazmaz, başlık yalnız çağıranın kendi isteğini etkiler. Güvenlik sınırı değil,
  yanlış kurulum kapısı; keşif okunamazsa fail-open + CRITICAL log. Migration yok.
- **Dokunulan dosyalar:** `src/Pbxtr.Api/Modules/Provisioning/ProvisioningEndpoints.cs`
  (`SharedNodeUnpinnedAsync`, `ProvisioningKeyValidator.NodeSharedUnpinned`),
  `tests/Pbxtr.Api.Tests/Modules/Provisioning/SharedNodeUnpinnedGateTests.cs` (6 test),
  `doc/mimari/asterisk-dugum-paketi-sozlesmesi.md`, `doc/mimari/api-kontrat-v1.md`,
  `deploy/pbxtr-confd-cek.sh` (403 ipucu).
- **Sonuç / doğrulama:** 6/6. Mutasyonda karşılaştırma ters çevrildi → 2 kırmızı; geri alındı ve
  ikilide yeniden koşuldu. Api Provisioning+Security 356/356, Architecture 794/794, format temiz.
- **Commit:** `7d74d927` — BR-BE-43-B: paylasilan dugumde pinsiz anahtar 403 NODE_SHARED_UNPINNED (/bundle)
- **Test adımı (kullanıcı):** t0007 anahtarını asterisk-01'e pinle. t0012'nin pinsiz anahtarıyla
  aynı düğüm başlığıyla `/bundle` → 403. Pinsiz bir düğüm başlığıyla → 200.

### 2. BR-DB-67 — bayinin ev tenant'ı (`tenants.is_dealer_home`)
- **Neden:** Bayi personeli müşteri tenant'ında barınıyordu (demo.bayi → t0007). BR-BE-151 personelli
  tenant'ı taşımadığı için tek müşterili bayinin müşterisi **kalıcı olarak** taşınamıyordu.
- **Model:** Koordinatör kararı (2026-09-19, `kurul-kararlari.md`) uygulandı; kullanıcının "ayrı
  tür" isteğiyle aynı şey. Tür `TenantKinds` üyesi **değil**, çünkü o küme işlevi sınıflandırır ve
  tür → zorunlu belge eşlemesine bağlıdır. Tür `tenants.is_dealer_home` işaretiyle ifade ediliyor:
  platform tenant kalıbı, limitler 0, `kind` NULL.
  `dealers.home_tenant_id` reddedildi (karşılıklı FK).
- **Ne yapıldı:**
  - Migration `20260927094212_DealerHomeTenant`: kolon (DEFAULT false), `ux_tenants_dealer_home`
    (kısmi tekil, bayi başına ≤1), `ck_tenants_dealer_home` (bayisiz/limitli ev tenant'ı yok).
    İlk üretimde EF mevcut `IX_tenants_dealer_id`'yi düşürüyordu (yeni indeksi FK indeksi saydı).
    İki indeks de adlandırılıp migration yeniden üretildi.
  - Kota tetikleyicisi `pbxtr_dealer_quota_reject()` ev tenant'ını saymıyor (01 şablonu). Kolon
    `to_jsonb(NEW)->>'is_dealer_home'` ile okunuyor. Sebep: şablon taze zincirde InitialSchema'dan
    itibaren uygulanıyor, fikstürlerde dar `tenants` tabloları var ve doğrudan `NEW.is_dealer_home`
    oralarda 42703 verirdi.
  - Migration **yalnız o fonksiyonu** şablondan çalışma anında kesip tazeliyor. Tüm 01 şablonu
    uygulanmıyor: tenants/call_attempts policy yeniden kurulumu call-permission'ı FAIL-CLOSED
    pencereye sokardı (kartın engeli buydu). `DO $verify$` iki SET yan tümcesini doğruluyor.
  - Domain: `Tenant.IsDealerHome` (özel setter) + `Tenant.CreateDealerHome`;
    `DealerHomeTenant.IdFor` (deterministik v5 kimlik), `NameFor` ("… (bayi merkezi)").
  - `ITenantProvisioning.EnsureDealerHomeAsync` (idempotent; 23505 → "zaten var").
  - `POST /api/v1/dealers` yeni bayide ev tenant'ını kendisi açıyor. Eski bayiler için
    `POST /api/v1/dealers/{id}/home-tenant` (`dealer.write` + `tenant.write`, 201/200/404).
  - `EfDealerQuota` ev tenant'ını saymıyor.
  - Taşıma: personelli ev tenant'ı → 409 `TENANT_HAS_DEALER_STAFF` (değişmedi, kabul ölçütü 2);
    boş ev tenant'ı → 409 `INVALID_STATE`.
  - `is_dealer_home`, `pbxtr_app` UPDATE kolon listesinde yok, yani uygulama rolü işareti sonradan
    değiştiremiyor.
- **Dokunulan dosyalar:** `src/Pbxtr.Domain/Modules/Tenancy/{Tenant,DealerHomeTenant,ITenantProvisioning}.cs`,
  `src/Pbxtr.Infrastructure/Modules/{EfTenantProvisioning,EfDealerAdministration,EfDealerQuota}.cs`,
  `src/Pbxtr.Infrastructure/Persistence/Configurations/TenancyConfigurations.cs`, migration + Designer +
  snapshot, `deploy/db/01-rls-template.sql`, `src/Pbxtr.Api/Modules/Tenancy/{DealerEditEndpoints,TenantEndpoints}.cs`,
  testler: `DealerHomeTenantTests`, `DealerCreateEndpointTests` (+stub provisioning, 8 yeni vaka),
  `TenantPlatformColumnsSingleWriterTests` (ikinci fabrika + kapalı setter + çağrı yeri sayımı),
  `DealerTenantMoveDealerStaffHttpTests` (5 entegrasyon testi: `BrDb67_*`), `doc/ekran-yazma-yollari.md`
  (yeniden üretildi, 208→209), `doc/mimari/api-kontrat-v1.md`.
- **Komutlar:**
  ```bash
  dotnet ef migrations add DealerHomeTenant -p src/Pbxtr.Infrastructure -s src/Pbxtr.Infrastructure \
    -o Persistence/Migrations --context PbxtrDbContext
  # 'migrations remove' DB'ye bağlanmak istiyor (Docker kapalı) → dosyalar silinip snapshot git checkout ile geri alındı
  PBXTR_WRITE_DOCS=1 dotnet test tests/Pbxtr.Architecture.Tests --filter Ekran_yazma_yollari_belgesini_URET
  python3 deploy/migration-compatibility-guard.py
  ```
- **Sonuç / doğrulama:**
  - Api Tenancy 296/296, Platform 1394/1394, Architecture 794/794.
  - Mutasyon: `POST /api/v1/dealers` içindeki ev tenant'ı çağrısı `if (DateTime.UtcNow.Year < 0)`
    ile devre dışı bırakıldı → 2 kırmızı; geri alındı, 26/26.
  - İlk mutasyon denemesi (`if (false)`) CS0162 ile derlenmedi ve test eski ikiliye gitti. O ölçüm
    geçersiz sayıldı.
  - **Koşulmadı:** 5 entegrasyon testi (yerel Docker kapalı); gerçek PG'de Up→Down→Up.
- **Commit:** `9c94a71a` — BR-DB-67: bayinin ev tenant'i (tenants.is_dealer_home) + BR-DB-117 karti + Karar#85 goc onayi

### 3. Kapı_07 (migration uyumluluk) — üç onaysız migration yakalandı
- **Neden:** Kapıyı yeni migration için koşunca 09-25'teki `SlaAutoAnsweredCount` ve 09-26'daki
  `RingGroupExternalMember` de **onaysız kırmızı** çıktı. Yani bir sonraki yayın göç adımında
  duracaktı; dünkü tur bunu görmemişti.
- **Ne yapıldı:** Üçünün de `Up`'ı genişletme (düşürmeler yalnız `Down`'da ya da idempotent kısıt
  yeniden kurulumunda). `deploy/migration-contract-onay.blobs`'a **Karar#85 — koordinatör kararı**
  bloğu eklendi; ölçülen ve ölçülmeyen ayrı yazıldı.
- **Sonuç:** Kapı rc=0, self-test OK. Blob SHA'ları çalışma kopyası = HEAD (CRLF uyarısına rağmen
  eşleşiyor, kontrol edildi).

### 4. BR-DB-117 açıldı + ClickUp
- Mevcut bayi personelinin ev tenant'ına taşınması tek EF transaction'ında yapılamıyor:
  `user_roles` bileşik FK + `users_tenant_isolation` WITH CHECK, çapraz dalı yok. Kart P3 açık.
- **Düzeltilen yanlış:** Karta önce "eski personeli pasife al" diye bir el yolu yazmıştım.
  **Yanlış:** `pbxtr_tenant_dealer_staff_count` durum filtresi taşımıyor, pasif personel de
  taşımayı kilitliyor. Kart ve BR-DB-67 test adımı buna göre düzeltildi: demo.bayi / t0007 bu
  turla açılmaz.
- ClickUp: `clickup-olustur.js` (yeni 1) → `clickup-senkron.js` (BR-DB-67 complete) → `--kuru`:
  fark 0, izde olmayan 0.
- **Commit:** `bcb402b6` — ClickUp: BR-DB-117 karti eslemeye eklendi

## Kararlar
- BR-BE-43-B: kapı yazmaz ve güvenlik sınırı değildir; okuma hatasında fail-open.
- BR-DB-67: tür `TenantKinds` değil `is_dealer_home`; ev tenant'ı kotaya sayılmaz ve taşınmaz;
  migration yalnız kota fonksiyonunu tazeler. Mevcut bayilerde backfill yok, uçla açılır.
- Kapı_07 onayı koordinatör kararıyla (Karar#85), kurul dağıtılmış olduğu için.

## Açık kalanlar / sonraki adım
- **Integration.Tests hiç koşmadı** (yerel Docker kapalı): `DealerHomeTenant` + `RingGroupExternalMember`
  + 09-25 migration'ları; `BrDb67_*` beş test.
- BR-DB-117 — mevcut bayi personelini ev tenant'ına taşıma (model seçilmedi).
- BR-DB-67 kullanıcı testi: yeni bayi → ev tenant'ı → personel → müşteri taşı 200; ev tenant'ı taşı 409.
- BR-10, BR-OPS-09: yapılacak yazılmadı; BR-C2-1/2, BR-DB-74, BR-OPS-14: es geçildi.
