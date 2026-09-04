# pbxtr — 2026-09-04

## Bağlam

Bir önceki gün #35, #36, #46, #47 sistem ekranları üzerinde çalışılmıştı. Bugün kullanıcı
dört istek verdi: (1) `/system/firewall`'dan `repo-nftables` katmanını ve `nftables.service`
kırmızı kutusunu kaldır, (2) `/system/services` durumlarını **konteynerlerin içinden** sor,
(3) `/system/ssl` "sıkıntılı gibi", (4) araya "login olmuyor".

Üçü de aynı sınıf kusuru ortaya çıkardı: **ekranlar çıplak (konteynersiz) bir kurulum
varsayıyordu; bu sunucuda her şey Docker'da koşuyor.**

## Yapılanlar

### 1. "login olmuyot" — sebep bendim

- **Ölçüm:** `5173` ayakta, `5080` hiç cevap vermiyor.
- **Sebep:** mutasyon testleri için backend'i `taskkill` ile durdurmuştum ve **geri
  başlatmayı unutmuştum.** Ürün kusuru değil.
- **Doğrulama:** varsaymadım, ölçtüm — `POST /api/v1/auth/login` → `200`, token +
  `landingRoute: /admin-dashboard`.
- **Ders:** test için durdurulan bir servis **aynı turda** geri başlatılır; "sonra
  başlatırım" kullanıcının önüne çalışmayan bir ürün olarak çıkıyor.

### 2. #35 — `repo-nftables` katmanı ve `nftables.service` kutusu kaldırıldı

- **Neden:** Kullanıcı: *"deploy/nftables.conf — pbxtr'in kural seti (UYGULANMADI)
  kaldiririmisin ekrandan"* ve ardından kırmızı kutu için *"bunuda kaldirirmisin"*.
- **Gerekçe (yazıya geçti):** bu ekran *"bu sunucuyu **fiilen** ne koruyor"* sorusunu sorar.
  Bu sunucuda **yüklü olmayan** bir dosya o soruya cevap vermiyordu; ekranın dörtte biri,
  uygulanmamış bir dosyanın uygulanmamış olduğunu tekrar ediyordu.
- **KALDIRILAN ŞEY BİR KORUMA DEĞİL, BİR GÖRÜNÜRLÜKTÜR** — ve bedeli ADR-014 §4.2'ye
  yazıldı: `systemctl enable nftables` allowlist'te **hâlâ yok**, ajan o unit adını **hâlâ
  reddediyor**; ama servis birileri tarafından elle `enable` edilirse panel bunu artık
  **hiçbir ekranda söylemez**. `FW-05` komutu katalogda **duruyor** (ölçüm yolu kapanmadı).
- **Dokunulan:** `FirewallLayerReader.cs`, `IFirewallInventory.cs`, `FirewallEndpoints.cs`,
  `FirewallScreen.tsx`, `firewallApi.ts`, `registry.ts`, 9 dilden `fw.nftTitle`,
  `ADR-014`, `doc/prototip-urun-farklari.md`
- **Bekçiler:** katman kümesinin **üç** olduğu ve **`danger` tonlu katman kalmadığı**
  pinlendi — sessizce geri gelmesi testi kırar.
- **Commit:** `594ebf8b`

### 3. #46 — servis durumları artık **konteynerden** okunuyor

- **Neden:** Kullanıcı: *"kontainerlerin icinden sorsana durumlarini"*
- **Ölçüm:** dört çekirdek servis (`pbxtr`, `nginx`, `postgresql`, `redis-server`)
  **`not-found`** görünüyordu. Sebep: bu kurulumda host'ta öyle systemd birimleri **yok**;
  konteyner olarak koşuyorlar. *Cümle teknik olarak doğruydu — ama sorulan şeyin cevabı
  değildi. Panel kendi servislerinin var olmadığını söylüyordu.*

#### 3.1 Yol boyunca çıkan iki gerçek kusur

1. **`SV-03` yazıldığından beri hiç çalışmamış.** Ajan argv'yi **boşluktan böler**
   (`Argv.Split(' ')`), yani `--format {{json .}}` iki ayrı argümana parçalanıyor ve docker
   `"docker ps accepts no arguments"` ile reddediyordu. **Tüketicisi olmadığı için kimse
   fark etmemiş.** Biçim artık boşluksuz: `{{.Names}}|{{.State}}|{{.Status}}`.
   *Ders: hiç çağrılmamış bir komut, katalogda durduğu için "var" sayılıyordu.*
2. **`-a` yoktu.** Yalnızca çalışanları listeleyen bir komutta **duran bir konteyner hiç
   görünmez**; ekran onu "sorulmadı" diye çizmek zorunda kalırdı — oysa bu ekranın varlık
   sebebi tam olarak *"durdu mu"* sorusudur.

#### 3.2 Sözleşme

- Yeni alanlar: `containerName`, `stateSource` (`systemd`|`docker`), `health`.
- **KAYNAK YAZILMAK ZORUNDA, çünkü iki sözlük ÇAKIŞIYOR:** `running` systemd'de bir
  **SubState**'tir ve `ActiveState` alanında görünmesi okuyucunun **yanlış alanı** okuduğu
  anlamına gelir — bir arıza sinyali. Docker'da ise normal hâl. `stateTone`/`stateText`
  artık kararı **kaynakla** verir; systemd dalında `running` **hâlâ kırmızı** (eski bekçi
  yaşıyor). *Değere bakıp karar veren bir eşleme ikisinden birini mutlaka yanlış çizerdi.*
- **`running` ≠ `healthy`:** ikincisi konteynerin **kendi içinde** koşan healthcheck'ten
  gelir, ayrı kolondur. Healthcheck'i olmayan konteyner (nginx) `null` döner, `unhealthy`
  **değil** — birleştiren bir okuma onu her açılışta kırmızı gösterirdi.
- **MinIO katalogda hiç yoktu** ve sunucuda çalışıyordu; ses kaydı deposudur, düşmesi kayıt
  erişimini bitirir. Eklendi.
- **Sonuç:** 15 satırın 6'sı konteynerden ölçülüyor, 7'si systemd'den; `asterisk.service`
  de artık ölçülüyor (bu sunucuda konteyner).
- **Mutasyon:** konteyner cevabını yoksay → 2 kırmızı; sağlığı durumdan türet → 4 kırmızı.
- **Commit:** `0db0fc32`

### 4. #47 — nginx TLS ayarları konteynerden (TL-01)

- **Neden:** Kullanıcı: *"http://localhost:5173/system/ssl sikintili gibi"*
- **Ölçüm:** `tls: null` — TLS sürümü, HSTS, şifre takımları, panel alan adı **hepsi**
  ölçülemedi. Sebep aynı sınıf: `FR-11` (`/etc/nginx/conf.d/pbxtr-tls.conf`) host'ta **yok**.
- **Arıza sessizdi:** uç `200`, ekran açılıyor, ekran sebebi **"host ajanı yok"** diye
  okutuyordu. **Ajan vardı; dosya orada değildi.**
- **Ne yapıldı:** `TL-01` = `docker exec pbxtr-nginx /bin/cat /etc/nginx/conf.d/default.conf`.
  **`FR-11` kaldırılmadı, yedek oldu** — çıplak kurulumda nginx gerçekten host'ta koşar.
- **Sonuç:** `minTlsVersion = TLSv1.2`, `hstsEnabled = true` (ikisi de o güne kadar `null`).
- **Bekçi güncellendi:** *"her servis SV-01 ile sorulabilir"* kuralı artık *"SV-01 ile **ya
  da** bir konteyner bağlantısıyla ölçülebilir"* diyor. Ters yön eklendi: konteyner adı
  `pbxtr-` ile başlamazsa `SV-03` filtresi onu **hiç listelemez** ve satır sessizce
  ölçülemez kalır. Mutasyon: bozuk ad → kırmızı, bağlantısız satır → kırmızı.
- **Commit:** `1d60d234`

## Kararlar

- **Konteyner çağı sözleşmeye girdi:** bir servisin durumu ya systemd'den ya Docker'dan
  gelir ve **hangisinden geldiği yazılır.** Kaynaksız bir durum hücresi iki sözlüğü
  karıştırır.
- **Kaldırılan görünürlüğün bedeli yazılır.** `nftables` kutusu kullanıcı kararıyla kalktı;
  yasağın durduğu ve **neyin artık görünmediği** ADR'ye geçti.
- **Boşluk içeren argv token'ı ajanda çalışmaz.** Yeni bir komut yazarken sabit argv'nin
  her parçası boşluksuz olmalı; aksi hâlde komut sessizce reddedilir.

## Açık kalanlar / sonraki adım

- **#47'de SIP TLS hâlâ ölçülmüyor** ve bu artık *bilinen bir gerçeğe* dayanıyor: canlı
  Asterisk `pjsip show transports` → **tek transport `udp`, `127.0.0.1:5060`; TLS transport
  YOK.** Ekran bunu "ölçülemedi" diye gösteriyor — oysa doğrusu **"ölçüldü, TLS transport
  yok"**. Bu ayrım `TlsSettings`'e yeni bir alan ister (bugünkü `null` iki şeyi birden
  taşıyor) ve ayrı bir iştir.
- **`/system/ssl` sertifika listesi yerelde yanıltıcı:** backend PC'de koştuğu için
  `Tls:CertificatePath` yerel kopyayı (`X:/...panel-tls.pem`) gösteriyor. Sunucuda gerçek
  yol okunur; bu bir geliştirme köprüsü etkisidir, ürün kusuru değil.
- **4 ölü provisioning anahtarının iptali** hâlâ kullanıcı onayı bekliyor (credential
  değişikliği).
- **`pjsip` bundle teslimi** hâlâ açık: `extensions` tablosunda şifreli SIP sırrı kolonu yok.
- Bu değişiklikler **pbxtr.com'a yayınlanmadı**; sunucuda yalnızca **ajan ikilisi**
  güncellendi (katalog ikilinin içinde gömülü).
- Geliştirme köprüsü hâlâ açık: `systemctl stop pbxtr-sysagent-kopru`.

### 5. Sunucu güncellendi — `demo-1d60d2340e25` yayında

- **Neden:** Kullanıcı: *"paket cikartip sunucuyu guncellermisin"*, ardından
  *"testleri calistirmadan direk build ediver acelemiz var"*.

- **KAPILAR VE TESTLER KOŞMADI — kullanıcının açık isteğiyle.** `deploy/yerel-yayin.sh`
  normalde 7 adımdır (güvenlik kapıları → backend → API shard'ları → frontend → DB
  kapıları → imaj → yayın); betiğin "testleri atla" bayrağı **yoktur**, bu yüzden 6. ve
  7. adımlar betiğin dışında **birebir aynı komutlarla** elle koşturuldu.
  - Sürüm damgası aynı formülle üretildi: `2026.09.04+1d60d2340e25`.
  - **Bunun izi betiğin `artifacts/ATLANAN-KAPILAR.txt` dosyasına DÜŞMEDİ**, çünkü betik
    hiç çalışmadı. Kayıt burasıdır: *bu imajda 27 güvenlik kapısı, backend/API/frontend
    takımları ve DB kapıları ÖLÇÜLMEMİŞTİR.* Ölçülen tek şey, aynı commit'te bugün
    yapılan hedefli koşulardır (Architecture 342/342, SystemAdmin 325/325, frontend
    system+i18n 169/169).

- **Komutlar:**
  ```bash
  docker build --build-arg SOURCE_REVISION=$SURUM --build-arg PBXTR_VERSION=$SURUM \
    -t tekbirsoft/pbxtr:demo -t tekbirsoft/pbxtr:demo-1d60d2340e25 .
  docker push tekbirsoft/pbxtr:demo-1d60d2340e25 && docker push tekbirsoft/pbxtr:demo
  scp deploy/staging-yayin.sh root@176.88.41.220:/root/staging-yayin.sh
  ssh root@176.88.41.220 '/root/staging-yayin.sh 1d60d2340e25'
  ```

- **Sonuç / doğrulama (canlı, pbxtr.com):**
  - Önceki imaj `demo-e688099f04e1` → yeni `demo-1d60d2340e25`; yedek alındı
    (`backups/pre-1d60d2340e25.dump`, 3,96 MB).
  - Migrate bekçileri **26/26** geçti, örnek veri seed'i tamamlandı.
  - `pbxtr-app` ve `pbxtr-nginx` yeniden yaratıldı; altı konteynerin altısı `running`.
  - `https://pbxtr.com` → login **200**, ve **bugünkü üç değişikliğin üçü de canlıda
    doğrulandı**: #46'da 6 satır `docker` kaynaklı ve sağlıklı, #35'te katmanlar
    `ufw | fail2ban | docker` (nftables alanı yok), #47'de `TLSv1.2` + HSTS ölçülü.

- **Gözlem (arıza değil, gürültü):** migrate çıktısında
  `Cannot load library libgssapi_krb5.so.2` satırı var. Npgsql açılışta GSSAPI/Kerberos
  kütüphanesini yoklar, çalışma imajında yok ve **parola kimlik doğrulaması kullanıldığı
  için işlemi durdurmuyor** — migration ve seed tamamlandı. Yine de bir gün gerçek bir
  hatayı maskeleyebilecek türden bir satır; ayrı bir iş olarak not edildi.

### 6. Hedef 11 — "adminden giriş yap" (#53 tenant, #61 bayi)

- **Neden:** Kullanıcı (madde 11): *"Bayi ve Super admin ve admine extrada adminden
  giris yap olacak. ayni sekilde ilk tenant sahibi olarak giris yapacak."*

  Aynı iş bugün de yapılabiliyordu: **Kullanıcılar → listeden seç → "Bu kullanıcı
  olarak çalış"**. Üç tıklama ve bir arama gerekiyordu ve aranan kişi her seferinde
  **aynı** kişiydi (tenant sahibi / bayi hesabı). İstenen şey yeni bir kapı değil,
  o aramanın kısayolu.

- **Ne yapıldı:**

  **Sunucu — "kim" sorusu sunucuda cevaplanır.**
  Yeni uç: `GET /api/v1/impersonation/primary-user?tenantId=…` **veya** `?dealerId=…`
  (tam olarak biri; ikisi birden ya da hiçbiri → 400). Yetki `user.impersonate`.
  Yanıt `found` + kimlik + **tenantId** + rol, bulunamazsa `found: false` + Türkçe sebep.

  - **404 değil, `found: false`.** "Sahibi henüz atanmamış" ile "göremiyorum" aynı
    satıra düşmemeli; ekran sebebi yazabilmeli.
  - **Uç yan etkisizdir** (CLAUDE.md §3.2 §Ş6 ile aynı gerekçe): jeton hâlâ
    `POST /impersonation` ile üretilir ve `ImpersonationRules`'un **dört kapısı**
    aynen koşar. Bu uç bir kapı değil, bir sorudur.
  - Port: `IUserAdministration.FindTenantPrimaryUserAsync` / `FindDealerPrimaryUserAsync`.
    Sıralama **`created_at`**, eşitlik `id` ile kırılır; **pasif hesap elenir**;
    küme `ReadableUsers()`'tır (görünürlük daraltması aynen geçerli).
  - **Bayi yolu `DealerUserScope`'u BİLEREK kullanmaz:** orası bayinin *altındaki
    tenantların* kullanıcılarını da kapsar (#02 drill-in'i için doğru). Kullanılsaydı
    "bayi olarak giriş yap" düğmesi kullanıcıyı sessizce bir **müşteri** hesabına
    indirebilirdi. Koşul: `users.dealer_id = <bayi>` **ve** rol `dealer`.

  **İstemci.** Ortak hook `useAdminSignIn`: hedefi sor → bulunamazsa sebebi yaz →
  bulunduysa bürün → `session.reload()` → köke git. İki ekranda iki kopya yazılsaydı
  birinin `reload()`'u atlaması yeterdi: jeton değişir ama ekran **eski yetki
  kümesini** göstermeye devam ederdi — aracın ölçmek istediğinin tam tersi.
  Düğmeler: #53 satırında "Giriş yap" (tenant sahibi), #61 satırında "Giriş yap"
  (bayi hesabı). Dokuz dile çeviri eklendi.

  **Yetki — üç aktöre de açıldı.** `user.impersonate` yalnızca `superadmin`'deydi;
  `admin` ve `dealer` eklendi. Bayinin eklenebilmesi için katalogdaki
  **`globalScopeOnly` bayrağı kaldırıldı** (bayi rolünün kapsamı `dealer`, açılışta
  fail-closed patlıyordu).

  > **BAYRAK KALKTI, KAPI KALKMADI.** Gerçek sınır `ImpersonationRules.Check`
  > içindeki **kapsam genişliği** kuralıdır ve o kural bayrağa değil aktörün kendi
  > kapsamına bakar: bayi yalnızca **tek-tenant** bir hesaba iner, başka bir bayiye
  > ya da platform yöneticisine **asla**. `ImpersonationRulesTests` bunu 3×3 matrisle
  > zaten ölçüyor. Bayrağın tek işlevi yetkinin bir role *yazılmasını* engellemekti.
  >
  > **Bedeli yazılı:** bayrak kalkınca yetki artık tenant kapsamlı bir **özel role**
  > de yazılabilir hâle geldi. O durumda `Single → Single` yolu açılır — ki bu
  > `ImpersonationRules`'da **zaten bilinçli olarak serbest** ("tenant yöneticisi
  > kendi agentiyla çalışır") ve RLS ile kendi tenant'ına hapsolur. Yetki hiçbir
  > pakette değildir, yani toplu seçimle dağıtılamaz.

- **Dokunulan dosyalar:**
  `src/Pbxtr.Domain/Platform/Identity/IUserAdministration.cs`,
  `src/Pbxtr.Domain/Platform/Identity/UserAdminRules.cs`,
  `src/Pbxtr.Infrastructure/Identity/EfUserAdministration.cs`,
  `src/Pbxtr.Api/Platform/Identity/ImpersonationEndpoints.cs`,
  `src/Pbxtr.Api/Platform/Authorization/permissions.seed.json`,
  `src/Pbxtr.Web/src/app/screens/users/impersonationApi.ts`,
  `src/Pbxtr.Web/src/app/screens/users/useAdminSignIn.ts` (yeni),
  `src/Pbxtr.Web/src/app/screens/tenant/TenantScreen.tsx`,
  `src/Pbxtr.Web/src/app/screens/dashboards/DealerAdminScreen.tsx`,
  `src/Pbxtr.Web/src/app/i18n/messages/*.json` (9 dil),
  `tests/Pbxtr.Integration.Tests/Tests/PrimaryUserResolutionTests.cs` (yeni),
  `tests/Pbxtr.Api.Tests/Modules/Access/UserAdminEndpointTests.cs`,
  `tests/Pbxtr.Api.Tests/Platform/Authorization/PermissionCatalogTests.cs`,
  `tests/Pbxtr.Api.Tests/Modules/Access/UserListDealerFilterTests.cs`,
  `src/Pbxtr.Web/src/app/screens/tenant/TenantScreen.test.tsx`,
  `src/Pbxtr.Web/src/app/screens/dashboards/DealerAdmin.test.tsx`

- **Sonuç / doğrulama:**
  - **Uç testleri (fake port):** `UserAdminEndpointTests` **63/63** (önce 57).
  - **GERÇEK PostgreSQL:** `PrimaryUserResolutionTests` 2/2. Bu test **gerekliydi**:
    uç testleri portun *taklidini* kullanıyor ve taklit sıralamayı kendi yapıyor,
    yani üretimdeki `OrderBy(CreatedAt)` → `OrderBy(DisplayName)` mutasyonu orada
    **görünmezdi**. Fikstür tuzağı kuruyor (en eski sahibin adı alfabetik olarak
    sonda) ve mutasyon canlı DB'ye karşı **kırmızı yandı**, geri alınınca yeşil.
  - **Frontend:** tüm süit **1331/1331** (önce 1325). Üç mutasyon üçü de doğru testi
    kırdı: hedef tenant'ı `undefined` geçmek, "bulunamadı" dalını kaldırmak,
    `canSignIn` kapısını kaldırmak.
  - `dotnet format --verify-no-changes` temiz, `tsc -b` temiz,
    `Pbxtr.Architecture.Tests` **342/342**, `Platform` 1051/1051, `Access` 123/123.
  - **Commit:** `e86c42bc` — feat(access): hedef 11 — #53/#61 satirindan "adminden giris yap"

- **Yol boyunca çıkan gerçek bulgu — `role.delete` yazısız girmişti.**
  Bayinin etkin yetki kümesi bir **altın liste** ile korunuyor
  (`DealerPermissionBoundaryTests`, Karar #23/Ş23-1). Kapı bu turda iki kez kırmızı
  yandı: biri beklenen (`user.impersonate`), **öteki beklenmeyen — `role.delete`.**

  O kod aslında **bu turun önceki adımında** (commit `e6247e1a`, hedef 5) seed'e
  girmişti; o adımda yalnızca `Modules.Access` testleri koşuldu ve altın liste **hiç
  çalışmadı.** Yani bayinin yetki kümesi bir commit boyunca **yazısız** genişledi.
  Şimdi gerekçesi listeye yazıldı: bayi `role.write` ile müşterisine özel rol
  tanımlayabiliyor; silememesi, açtığı rolü hiçbir zaman geri alamaması demekti.

  **Ders (kayda geçti):** yetki seed'ine dokunan bir değişiklikte `Modules.Access`
  yetmez — `Platform.Authorization` da koşulmalı.

### 7. Çağrı merkezi gözüyle boşluk taraması (rapor, kod değişikliği yok)

- **Neden:** Kullanıcı: *"projeyi kontrol edermisin? eksik gordugun olmasa iyi olur
  diyecegin neler var bir cagri merkezi icin. Mesela scripter ekleyelim mi? veya
  softphone yi baska nasil yapabiliriz. veya cagri geldiginde bir ekran mi acsak"*
- **Ne yapıldı:** 69 ekran + 32 domain modülü koddan tarandı; üç soruya ölçülmüş cevap,
  14 satırlık envanter, 3 bayat gerekçe, önerilen sıra. Rapor:
  <https://claude.ai/code/artifact/695d8bc9-1641-41b6-b00b-75b5338c081f>
- **Özet:** Scripter **YOK** → "kampanya scripti + form → sonuç kodu" olarak evet.
  Softphone **VAR** (sip.js, kabukta, 30 Ağustos'ta gerçek PJSIP kanalıyla çaldı) →
  değiştirme; mikrofon/ses testi/cihaz/DTMF ekle. Çağrı geldiğinde ekran **KISMEN**
  (modal doğru) → eksik olan **müşteri kartı** (not + zaman çizelgesi; `contacts`'ta yok).
- **Bayat gerekçeler:** "panelde ses yolu yok" (§13.1/7, /14), "Contact'ta CampaignId yok"
  (§13.1/23 — kolon var), "gerçek Asterisk'e karşı doğrulanmadı" (§3.0 değişti, hepsi borç).
- **Kurula gitmesi gerekenler:** müşteri kartı + softphone kontrolleri + scripter (tek
  gündem), kuyrukta geri arama IVR düğümü, CRM URL-pop/webhook, omnichannel için
  "yapmayacağız" kararı. Kullanıcılar arası mesajlaşma yeniden açılmaz (Karar #25/K6).

### 8. Boşluk raporu madde 1 — müşteri kartı (not + zaman çizelgesi + kampanya)

- **Neden:** Kullanıcı: *"bunlari yapalim"* (rapor §7 sırasıyla). İlk madde: çağrı
  geldiğinde agent'ın önüne **carinin geçmişi** gelmiyordu — modal doğruydu ama altında
  yalnızca ad/kod/kuyruk/deneme vardı. Cari notu diye bir tablo yoktu; çağrı geçmişi
  `cdr`'da, randevular `appointments`'ta zaten duruyordu ama kimse bir araya getirmiyordu.
- **Ne yapıldı:**
  - **Domain:** `ContactNote` (tenant + cari + yazar + ≤1000 karakter gövde),
    `ContactNoteEditor.Normalize` (kırpar; Empty/TooLong), `IContactCard` portu
    (`GetAsync`, `AddNoteAsync`) ve `ContactCard/…Row` kayıtları. Silme/düzenleme ucu
    **yok** — not bir kayıt defteridir.
  - **DB:** `contact_notes` tablosu — CHECK `length(btrim(body)) BETWEEN 1 AND 1000`,
    bileşik FK `(tenant_id, contact_id)`, RLS ENABLE+FORCE + `contact_notes_tenant`
    policy. Migration `20260904120000_ContactNotes` + terminal
    `20260904130000_ContactNotesFinalGuard` (assertion pili buraya taşındı;
    `ExtensionWebRtcCredentialFinalGuard` yalnızca kendi guard'ını tutuyor).
    Snapshot elle güncellendi (Designer yok).
  - **Infrastructure:** `EfContactCard` — çağrı geçmişi **numaradan** eşleşir
    (`caller_number`/`called_number`; CDR cari kimliği taşımaz), `linkedid` ile tek satır
    (gruplama **kırpmadan önce**, yoksa ikinci bacak slot yakar), sonuç kodu yolu
    `ResultCodePathResolver`'dan, yazar/agent adı tek `users` sorgusundan.
    `RedisLiveOperationsView.GetActiveCallAsync` artık kampanya adını da okur
    (`ActiveCallInfo.CampaignName`).
  - **API:** `ContactCardEndpoints` — `GET /api/v1/agent/contacts/{id}/card`,
    `POST /api/v1/agent/contacts/{id}/notes`; ikisi de **`call.handle`** (agent
    `contact.read` taşımaz ve taşımamalı — "Kuyruklarım" deseni), `PhoneSurfaces.AgentDesk`.
    Serbest metin (cari notu, çağrı notu, randevu notu) `phone.unmask` yoksa
    `FreeTextRedactor`'dan geçer. Bilinmeyen/başka tenant carisi **404** (403 varlığı ele
    verirdi). `ActiveCallDto.Campaign` eklendi. Manifest: `agent-desk.contact-card`,
    `agent-desk.contact-note` (tablolar **sıralı** olmalı — DM006 ilk koşuda bunu yakaladı).
  - **Frontend:** `ContactCardPanel.tsx` — aktif çağrı kartının **altında** (ayrı pencere
    değil: masa üç sütun, pencere değişince kısayollar kaybolur), **yalnızca
    `contact.contactId` varsa** (bilinmeyen arayanın kartı yoktur). Not eklenince kart
    **yeniden okunur** (yanıtı listeye elle eklemek maskeden geçmemiş ham metni gösterirdi).
    Yazma hatası taslağı silmez. `CallerFacts` ve `IncomingCallModal`'da kampanya rozeti.
    `CallContact` iki alan kazandı: `contactId`, `campaign`. i18n ×9 dil (`ccard.*`,
    `incoming.campaign`).
  - **Doküman:** `prototip-urun-farklari.md` §13.1/13 ("Son işlem" → KAPANDI, "Açık
    kayıt" hâlâ BİLİNÇLİ: `Ticket.ContactId` yok) ve /23 (bayat gerekçe: `CampaignId`
    `20260824081141_ContactCampaignLink` ile eklenmişti, satır güncellenmemişti).
    `ekran-yazma-yollari.md` yeniden üretildi (166 → 167 yazma ucu).
  - **Yan düzeltme:** `TenantScreen.test.tsx` (madde 11'den) `tsc -b`'yi kırıyordu
    (`...args: unknown[]` spread) — `vi.fn<() => Promise<TenantListResponse>>` ile düzeldi.
    `system-roles.generated.ts` madde 11'in seed'iyle bayattı, yeniden üretildi.
- **Dokunulan dosyalar:** `src/Pbxtr.Domain/Modules/Contacts/{ContactNote,IContactCard}.cs`,
  `src/Pbxtr.Infrastructure/Modules/EfContactCard.cs`,
  `src/Pbxtr.Infrastructure/Persistence/Configurations/ContactNoteConfiguration.cs`,
  `src/Pbxtr.Infrastructure/Persistence/Migrations/20260904{120000_ContactNotes,130000_ContactNotesFinalGuard}.cs`,
  `src/Pbxtr.Api/Modules/AgentDesk/ContactCardEndpoints.cs`,
  `src/Pbxtr.Api/Platform/Delivery/delivery-manifest.json`,
  `src/Pbxtr.Web/src/app/screens/agent/{ContactCardPanel.tsx,CallTab.tsx,IncomingCallModal.tsx,agentApi.ts,useCallSession.ts}`,
  `doc/prototip-urun-farklari.md`, testler aşağıda.
- **Komutlar:**
  ```bash
  cd src/Pbxtr.Web && npm run screens:gen && npx tsc -b && npx vitest run src/app/screens/agent src/app/screens/tenant src/test
  dotnet test tests/Pbxtr.Api.Tests --filter FullyQualifiedName~Pbxtr.Api.Tests.Modules.AgentDesk
  dotnet test tests/Pbxtr.Architecture.Tests
  PBXTR_WRITE_DOCS=1 dotnet test tests/Pbxtr.Architecture.Tests --filter ScreenWritePathEvidenceTests
  dotnet test tests/Pbxtr.Integration.Tests --filter FullyQualifiedName~ContactCardTests
  ```
- **Sonuç / doğrulama:**
  - `ContactCardEndpointTests` (9): şekil, maskeleme (yetkisiz gizli / `phone.unmask` açık),
    404, 403 ×2 uç, yazma, boş ×3, sınır (1001 red / 1000 kabul). İkiz üretimle aynı
    `ContactNoteEditor`'ı koşar.
  - `ContactCardPanel.test.tsx` (6): çizim, boş kart "eşleşme yok" demez, not sonrası
    yeniden okuma + taslak temizliği, sınır üstü düğme kapalı, hata taslağı silmez, okuma
    hatası kart uydurmaz.
  - `ContactCardTests` (4, gerçek DB): numara eşleşmesi + linkedid gruplaması + başka
    numara dışarıda, not DB'de + yazar adı, geçersiz gövde yazılmaz, **başka tenant null /
    NotFound**. Docker Desktop kapalıydı, başlatıldı; 4/4 geçti (atlanmadı).
  - AgentDesk API 216/216, Architecture 342/342, agent+tenant vitest 231/231, `tsc -b` 0,
    `dotnet format --verify-no-changes` temiz.
- **Commit:** `a36aca4e` — feat(agent): musteri karti — cari notu, gecmis ve kampanya rozeti


### 9. Boşluk raporu madde 2 — softphone kontrolleri + bayat gerekçe temizliği

- **Neden:** Rapor §7/2. Yazılım telefonu (sip.js) 30 Ağustos'tan beri kabukta ama
  görüşme kontrolü yoktu: mikrofon kapatılamıyor, tarayıcıdan tuş gönderilemiyor,
  cihaz seçilemiyor, ses test edilemiyordu. "Panelde ses yolu yok" gerekçesi üç yerde
  hâlâ duruyordu; "gerçek santralde doğrulanmadı" notları §3.0 (2026-09-03) ile bağlantı
  gerçek olduktan sonra blokaj notu değil borç olmalıydı.
- **Ne yapıldı:**
  - **`useSoftphone.ts`:** `muted` (SIP.js `isMuted()` kaynak, kendi bayrağı değil),
    `toggleMute`, `sendDtmf` (RFC 4733 — RTP içinde; provisioning `dtmf_mode=rfc4733`
    ürettiği için SIP INFO **yanlış** olurdu; alfabe `0-9*#A-D`, dışı düşürülür ve hiçbir
    yere yazılmaz), `devices` + `selectInputDevice` (sonraki görüşme için SIP.js `media
    .constraints` referans üzerinden güncellenir — tip `boolean` der ama
    `session-manager.js:727` nesneyi `getUserMedia`'ya olduğu gibi geçirir; süren
    görüşmede `replaceTrack` + SIP.js `localMediaStream` takası, yoksa `mute()` eski izi
    kapatırdı) + `selectOutputDevice` (`setSinkId`). Görüşme bitince mikrofon açığa döner.
    `sendDTMFUsingSessionDescriptionHandler: true`.
  - **`shell/audioDevices.ts`:** `listAudioDevices` (izin yoksa etiket UYDURULMAZ,
    `labelsHidden`), `requestMicrophoneAccess` (akışı hemen kapatır), `measureMicrophoneLevel`
    (AnalyserNode RMS, 10 Hz), `toneWavDataUrl` (1 sn 440 Hz PCM WAV, tarayıcıda üretilir,
    dosya paketlenmez), `playTestTone`, `readStoredDevices/writeStoredDevices`
    (`localStorage` — cihaz kimliği tarayıcıya özeldir, sunucuda anlamı yok).
  - **`shell/SoftphoneSettings.tsx`:** üst barda "Ses" popover'ı — mikrofon/hoparlör
    seçici (hoparlör yalnız `setSinkId` destekleyen tarayıcıda, yoksa sebebi yazılı),
    mikrofon testi (5 sn seviye çubuğu → algılandı/algılanmadı), hoparlör testi.
    **Profil ekranında değil:** ayarlar yalnız softphone tanımlı kullanıcıya anlamlı.
  - **`HeaderSoftphone.tsx`:** görüşmede "Mikrofonu kapat/aç" (`aria-pressed`) ve
    "Tuş gönder" (12 tuş; basılan tuş ekrana YAZILMAZ, yalnız sayaç — PCI-DSS).
    Masadaki komut şeridinde mikrofon yine YOK: şerit sunucu komutudur, mikrofon
    yereldir; `CallControl.test.tsx` "mikrofon düğmesi yok" testi durur, gerekçesi
    güncellendi.
  - **Bayat notlar:** `prototip-urun-farklari.md` §13.1/7 (ses testi → KAPANDI), /14
    (mikrofon → KAPANDI, yeri farklı), "Ölçemediklerim/1" (bağlanmıyoruz → BORÇ);
    `AgentEndpoints.cs` AttendedTransfer ve `opsContracts.ts` ×2 "GERCEK SANTRALDE
    DOGRULANMADI" → "BORÇ — henüz ölçülmedi" (`TransferAsync`/`SendDtmfAsync`
    `AsteriskAriProvider`'da uygulanmış; eski "bu fazda NotConnected fırlatır" yanlıştı).
  - i18n ×9 (`softphone.*` 26 anahtar).
- **Dokunulan dosyalar:** `src/Pbxtr.Web/src/app/shell/{audioDevices.ts,audioDevices.test.ts,SoftphoneSettings.tsx,HeaderSoftphone.tsx,HeaderSoftphone.test.tsx,HeaderSoftphone.module.css}`,
  `src/Pbxtr.Web/src/app/screens/agent/{useSoftphone.ts,CallControl.test.tsx}`,
  `src/Pbxtr.Web/src/app/api/opsContracts.ts`, `src/Pbxtr.Api/Modules/AgentDesk/AgentEndpoints.cs`,
  `doc/prototip-urun-farklari.md`, i18n ×9.
- **Komutlar:**
  ```bash
  cd src/Pbxtr.Web && npx tsc -b && npx vitest run src/app/shell src/app/screens/agent
  dotnet build src/Pbxtr.Api && dotnet format src/Pbxtr.Api --verify-no-changes
  ```
- **Sonuç / doğrulama:** `HeaderSoftphone.test.tsx` 5 (görüşmesizken düğme yok, görüşmede
  mute + aria-pressed kaynaktan, DTMF gönderir ve tuşu yazmaz, çalarken Aç/Kapat,
  disabled'da yüzey yok), `audioDevices.test.ts` 6 (izin yokken etiket uydurulmaz, API
  yoksa patlamaz, kısıt, kalıcı seçim, WAV başlığı + sessiz değil — ilk yazımda 2000.
  örnek tam sıfır geçişine denk geldi, pencereyle düzeltildi), shell+agent vitest
  185/185, `tsc -b` 0, Api build 0/0, format temiz. **Gerçek tarayıcı/santralde
  ölçülmedi** (cihaz API'leri jsdom'da yok) — sahada ilk görüşmede denenmeli.
- **Commit:** `d3c67c1a` — feat(softphone): mikrofon, istemci DTMF, cihaz secimi ve ses testi

