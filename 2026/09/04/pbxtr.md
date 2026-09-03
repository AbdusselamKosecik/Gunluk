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
