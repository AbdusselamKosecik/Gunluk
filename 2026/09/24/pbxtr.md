# pbxtr — 2026-09-24

## Bağlam

Gün, önceki gecenin "kalan maddeler" turundan devraldı: **793 kart · 79 açık** (P0 4, P1 33,
P2 37, P3 5). Dört P0'ın dördü de (`BR-00d`, `BR-SYS-117`, `BR-DB-91`, `BR-BE-150`) **yayın
penceresi** bekliyordu. 84 yerel kapıdan 3'ü kırmızıydı, üçü de karta bağlıydı. Sunucuda
`current-20260923-r3` koşuyordu, migration 229.

Kullanıcının bugünkü istekleri sırasıyla:
1. *"doker paketi çıkartı ver. sunucuya bağlanalım güncelleyelim"*
2. *"Locale bir asterisk kuralım, docker'a oradan sunucudaki asteriske trunk verelim, aramayı
   localden tetikletip deneyelim."*
3. (mesai kapısı sorusuna) *"bir şey bekleme direk yap geç"*
4. *"sunucuda çalıştırmadın mı docker up'u"*
5. *"şu kalan maddeleri de bitirir misin. ne koşacaksan ssh'da koş"*
6. `/goal tüm maddeleri bitirelim.`

Sunucu: `176.88.41.220` — **test/sunum ortamı, canlı müşteri yok**. SSH `root@`.

---

## Yapılanlar

### 1. Yayın ön koşulları: `kapi_07` ve `BR-SYS-131`

- **Neden:** `deploy/yerel-yayin.sh` adım 1'de `kapi_07` (expand-only migration sözleşmesi)
  KIRMIZI olduğu için yayın **hiç başlamıyordu**. Bugün çıkacak `TelephonyEffectMuteCheck`
  onay defterinde yoktu.
- **Ne yapıldı:** db-dev yedi migration'ın `Up()` gövdesini okuyup **gerekçesiyle** onayladı
  (`Karar#81`). Çıplak "onaylandı" satırı yok. İkisi gerçekten daraltıcıydı ve defterde
  **saklanmadı**: `Sprint03TrunkSecurity…` FK'yi `(user_id)` → `(user_id, tenant_id)`'ye
  çekiyor (ihlal eden satır 0 ölçüldü, gövde `RAISE EXCEPTION` ile düşer, daraltma §4
  tenant izolasyonunun kendisi); `WallboardUserLayouts` bir `DropIndex` taşıyor (aynı satır
  kümesi üzerinde aynı tekillik, sıkılık düşmez).
- **`BR-DB-112`'nin öncülü çürük çıktı:** kart "backfill FORCE RLS altında 0 satır görmüş
  olabilir" diyordu. Ölçüm: `call_events` 8535 / `cdr` 1438 satır, **`source IS NULL` = 0**.
  Olamazdı da: `ALTER COLUMN … SET NOT NULL` depolama seviyesinde tarar ve **RLS'e tabi
  değildir** — backfill boş kümede koşsaydı `23502` ile düşer, migration history'ye yazılmazdı.
  Backfill migration'ı **yazılmadı** (vacuous olurdu).
- **`BR-SYS-131`:** öz-testin kontrol grubu dün 150'ye çıkan ağır-DDL listesinin içine
  düşmüştü → HEP KIRMIZI kapı. Kontrol grubu, Karar #73 ile **ölçerek** listenin dışında
  tutulmuş `GuardsTemplateRefreshSysInventory` yapıldı. 24/24; mutasyon 23/1.
- **`BR-BE-150` ölçümü recreate'ten ÖNCE alındı** (sayaç süreç ömürlü, `Reset` yok,
  recreate sıfırlar): **0**, kip `audit`, pencere ~2 gün 4 saat.
- **Dokunulan dosyalar:** `deploy/migration-contract-onay.blobs`, `deploy/yayin-onkosul-selftest.sh`
- **Commit:** `7a370bbc` (trunk commit'iyle birlikte)

### 2. Trunk: yerel Asterisk → sunucudaki Asterisk

- **Neden:** kullanıcı isteği (2).
- **Ölçülen engel:** sunucuda PJSIP UDP transport **`127.0.0.1:5060`**'a bağlıydı ve compose
  5060'ı **hiç yayımlamıyordu** — SIP konteynerin dışından erişilemezdi. Ayrıca ufw RTP'ye
  `10000:20000/udp` izni veriyor ama gerçek aralık `20000-20099` (örtüşme tek port).
- **Karar — tailscale üzerinden, SIP internete AÇILMADI:** yerel makine (`100.84.6.73`) ve
  sunucu (`100.106.82.119`) aynı tailnet'te. Docker'ın yayımladığı portlar iptables'a DOCKER
  zincirinden girer ve **ufw'yi baypas eder**; `0.0.0.0:5060` yazılsaydı SIP internete açık
  kalırdı. Yayımlama tailscale adresine bağlandı.
- **Ne yapıldı (backend-dev-2):** transport `0.0.0.0:5060` + `external_*_address` +
  `local_net`; trunk `t0007-trunk-lab` (tenant önekli, zorunlu); `pbxtr.d/pjsip/` altına
  **yazılmadı** (confd alanı), ayrı `pbxtr-lab.d/` include'u; yerel taraf
  `deploy/asterisk-lab/trunk/`.
- **Ölçüm — sinyalleşme ve medya AYRI AYRI:** `401 → digest → 100 Trying → 200 OK → ACK`,
  CDR `ANSWERED` 51 sn; medya **çift yönlü**, 13 sn'de Rx 654 / Tx 604, kayıp 0, alaw. Çağrı
  bilerek `Milliwatt` ile başlatıldı (`Echo` ilk paketi üretmez, sunucu gerçek adresi
  öğrenemez → "bağlandı ama ses yok"). **Negatif test:** `176.88.41.220:5060` → 0 bayt,
  `100.106.82.119:5060` → `401`.
- **Yolda üretilen arıza:** lab dosyası `640 root:root` bırakılınca Asterisk (uid 1000)
  okuyamadı, `#include` "dosya yok" sayıldı ve **PJSIP'in tamamı ~90 sn düştü** (altı WebRTC
  dahilisi dahil). Konteyner `healthy`, `module reload` "successfully" diyordu. `chown` ile
  düzeldi.
- **Komutlar:**
  ```bash
  docker run --rm alpine sh -c "apk add netcat-openbsd; nc -z -w5 100.106.82.119 22"
  docker exec asterisk-trunk-lab asterisk -rx "channel originate PJSIP/9001@t0007-trunk-lab-remote application Milliwatt"
  ssh root@176.88.41.220 'docker exec pbxtr-asterisk asterisk -rx "pjsip show channelstats"'
  ```
- **Commit:** `7a370bbc` — Trunk: yerel Asterisk -> sunucu, uçtan uca ölçüldü

### 3. Mesai kapısı: ölçülmüş-pencere muafiyeti

- **Neden:** yayın `mesai_kapisi`nda durdu (TR 09:22) ve `PBXTR_MESAI_ICI_YAYIN=1` **işlemedi**,
  çünkü `TelephonyEffectMuteCheck` dün üretilen 150 adlık ağır-DDL listesindeydi. Kapının ilk
  gerçek müşterisi bu yayın oldu. Kullanıcı: *"bir şey bekleme direk yap geç."*
- **Ölçüm:** migration gövdesi birebir, gerçek santralde, `ROLLBACK` ile: DROP 8,0 ms + ADD NOT
  VALID 3,7 ms + **VALIDATE 47,8 ms** (52.476 satır) = **≈62 ms** ACCESS EXCLUSIVE.
- **Benim hatam, kayıt için:** ilk ölçüm denemesinde migration'ın değer listesini dosyadan
  okumak yerine **elle yazdım**, `VALIDATE` patladı ve bir an migration'ı kusurlu sandım.
  Dosyadaki liste doğruydu. Ayrıca `docker exec` **`-i` olmadan** stdin okumadı ve DDL
  **sessizce hiç koşmadı** (`rc=0`).
- **Ne yapıldı:** `pbxtr-migrate-adimi.sh`'a `PBXTR_OLCULMUS_PENCERE='Ad=ms'` ayağı. Üç şart,
  üçü fail-closed: ad yasak listesinde olmalı, ms tam sayı ve eşiğin (250) altında, değer
  **ortamdan** gelir (dosyada tutulsaydı ikinci koşuda bayatlardı — dünkü "elle tutulan
  defter" kusuru). `yerel-yayin.sh` değişkeni sunucuya **taşımıyordu**, iletim eklendi.
- **Sonuç:** mutasyon 6/6. **Gerçek yayında ateşledi:**
  `mesai: TelephonyEffectMuteCheck muaf -- … GERCEK SANTRALDE olculdu: 62 ms (esik 250 ms).`
- **Commit:** `7a370bbc`

### 4. Yayın yolunda çıkan üç "sunucuda elle duran yapılandırma"

Günün tekrar eden deseni: **çalışan yapılandırma sunucuda elle duruyor, depoda karşılığı yok,
ve bir sonraki yayın onu sessizce siliyor.**

**4a. `pbxtr-confd` (`BR-SYS-132`)** — sapma kapısı kırmızıydı, `staging-yayin.sh` bu dosyaları
hiç göndermiyor. Kapının taşıma yolu koşuldu ve **dört katman** art arda çıktı:
1. taşıma tablosu `pbxtr-asterisk-observe`'u saymıyordu → `status=127`;
2. o sarmalayıcı koşulsuz `/usr/sbin/asterisk` çağırıyordu, Asterisk ise **konteynerde** →
   konteyner dalı eklendi (host öncelikli, kapalı liste bozulmadan; üç negatif ayak reddedildi);
3. `dugum.sh:596` **kendi kataloğunda olmayan** bir anahtarı çağırıyordu → betik hangi
   sunucuda olursa olsun düşerdi;
4. `Timestamp Events:` (büyük E) ↔ Asterisk 22 `Timestamp events:` → fail-closed kontrol
   **her zaman** düşüyordu. Yapılandırma doğruydu.

**Asıl engel yamayla kapanmıyor:** yeni ajan tasarım gereği düğüm başına **mTLS istemci
sertifikası** istiyor ve `nginx` kipini yasaklıyor; eski çalışan sürüm tam da o yolu
kullanıyordu. Sertifika hiç üretilmemiş.

**Benim hatam:** `--tasi`'yı dört kez koştum, her koşu tek yedeği (`.onceki`) üzerine yazdı
ve **çalışan orijinal betik (`sha 5dea8b51`) kayboldu**. Git'te 17 sürüm tarandı — o dosya
git'e hiç girmemişti. **Ders:** geçmişi olmayan bir sunucu dosyasının tek yedeğini üzerine
yazan bir taşıma betiği, ikinci koşuda geri alma yolunu yok eder. Bundan sonra yedekler
damgalı alındı.

**4b. Compose (`05f5151b`)** — sunucuda olup depoda olmayan **`/etc/pbxtr/pki` bağlaması** ve
**SIP portu** vardı. Depo dosyası olduğu gibi gönderilseydi imza anahtarı konteynerde
bulunmaz, bundle ucu **503** döner, belirti "provisioning çalışmıyor" olurdu. İkisi depoya
taşındı; SIP adresi **parametrik** ve varsayılanı loopback. İmza anahtarlarının dördü
taşınmadı (sunucunun `.env`'i zaten taşıyor).

**4c. Asterisk transport (`e80d2cf7`)** — trunk değişikliği depo imajında yoktu → S3 sapması.
Depoya taşındı; kuruluma özgü iki adres **sabit** kaldı ve borç olarak yazıldı (`BR-AST-128`)
— S3 anlamsal karşılaştırdığı için parametrik yazmak bugün mümkün değildi.

### 5. Santral sapma kapısının S1 kilidi (`10238ffc`)

- **Neden:** kapı adım 1'de, santral imajı adım 6b'de yayınlanıyor. `--santral` verilse bile
  S1 "imaj geride" deyip yayını durduruyordu → **imajı güncelleyen tek yol, imajın güncel
  olmasını şart koşan kapı tarafından kapatılıyordu.** Santral imajı bu betikle hiç
  yayınlanamazdı. Kayıtlı sınıf: çıkışı olmayan kapı fiilen atlanır.
- **Ne yapıldı:** muafiyet dar — yalnız `PBXTR_SANTRAL_YAYINLANACAK=1` iken, yalnız "geride"
  dalında; damga yoksa/depoda yoksa dal çalışmaz. Mesaj bir borç: *"YAYIN SONRASI S1 YENİDEN
  ÖLÇÜLMELİDİR."*
- **Sonuç:** bayrakla RC=0, bayraksız aynı kapı RC=1. **Borç yayından sonra ödendi:** bayraksız
  koşu `TAMAM S1 — imaj ff5d78ea09b4 güncel`, sekiz iddia da sağlandı.

### 6. Yayın: yerel Docker çöktü, bellek kesti, adımlar elle

- 6. koşuda kapılar 871 satır ilerledi, sonra yerel Docker motoru çöktü (API 500).
  Docker Desktop yeniden başlatıldı.
- 7. koşu **bellek yetersizliği** nedeniyle Claude Code tarafından kesildi (frontend testlerindeydi).
- Kullanıcı: *"sunucuda çalıştırmadın mı docker up'u"*. Çalıştırmıştım — ama `.env`'deki
  **`PBXTR_IMAGE=s04-perf-local`** sabiti yüzünden uygulama **eski imaja geri alınmıştı**
  (benim yol açtığım gerileme) ve yeni imaj henüz registry'de yoktu. Adımlar elle yapıldı:
  imaj üret → push → nginx/dağıtıcı/migrate kütüphanesi taşı → SHA'ları `tr -d '\r'` ile
  normalize et → `staging-yayin.sh`.
- **Komutlar:**
  ```bash
  docker build --build-arg SOURCE_REVISION=... -t tekbirsoft/pbxtr:demo-<sha> .
  docker build --build-arg PBXTR_GIT_SHA=... -t tekbirsoft/pbxtr-asterisk:22-<sha> deploy/asterisk-lab
  docker push ...
  ssh root@176.88.41.220 "PBXTR_DAGITICI_SHA=... PBXTR_SANTRAL_IMAJ=... PBXTR_MESAI_ICI_YAYIN=1 PBXTR_OLCULMUS_PENCERE='TelephonyEffectMuteCheck=62' /root/staging-yayin.sh <sha>"
  ```

### 7. `BR-BE-216`: üretimde `migrate --with-sample` şemayı HİÇ koşmuyordu (`ff5d78ea`)

- **Ölçüm (gerçek yayın, STAGING_RC=69):** migrate "uygulanmış 229, bekleyen 2" bastı, sonra
  `HATA: seed-sample üretim ortamında kapalıdır` ile düştü ve **hiçbir migration uygulamadı**.
- **Sebep:** `MaintenanceCli.cs` üretimde `SeedSample` görünce **koşulsuz `return Failure`**.
  Compose migrate'i `["migrate","--with-sample"]` ile koşuyor, imajın varsayılan ortamı
  Production. Belirti yanıltıcıydı: şemanın güncellenmediğini söyleyen bir cümle yoktu.
- **Neden bugüne kadar görülmedi:** eski imaj bu kapıyı taşımıyordu — sabah 06:51'de onun
  migrate'i üretim ortamında gerçekten **örnek veri bastı**.
- **İkinci kusur:** reddin denetim satırı hiç yazılamıyordu —
  `set_config(unknown, uuid, boolean)` yok (`42883`). `@tenant::text`.
- **Düzeltme ayrımı korur:** tek başına `seed-sample` üretimde **aynen reddedilir**; yalnız
  `migrate --with-sample` seed'i atlayıp şemayı koşar.

### 8. Yayın indi (`d06f2ed0`)

| | |
|---|---|
| `pbxtr-app` | `tekbirsoft/pbxtr:demo-ff5d78ea09b4` — healthy |
| `pbxtr-asterisk` | `tekbirsoft/pbxtr-asterisk:22-ff5d78ea09b4` — healthy |
| Migration | **229 → 231** |
| `telephony_provider_effects_operation_check` | `mute=true unmute=true valid=true` |

Trunk recreate'ten **sağ çıktı** ve üç ardışık örnekle yeniden ölçüldü: Rx 792→950→1107,
Tx 742→900→1057, kayıp 0.

Yayının kendi BR-SYS-97 kontrolü bir gölgeleme yakaladı: host `asterisk.conf` (`8cd60bf8…`)
≠ imaj (`879fa8eb…`), bind mount imajı eziyor → `BR-SYS-133`. Sapma kapısı bunu **görmüyor**
(S3 depo↔host ölçer, farklı olan imaj↔host).

### 9. Kalan maddeler turu 1 — sunucuda (`83fedb67`, `1e0cbf31`)

Kullanıcı: *"ne koşacaksan ssh'da koş."* Dört ajan, tüm ölçümler sunucuda.

- **Dört P0'ın dördü de kapandı:**
  - `BR-SYS-117`: ajan önce **benim 62 ms ölçümümün şartı karşılamadığını** gösterdi (Ş78-L3
    üç başka tabloyu istiyor). Gerçek pencere örneklenmeden geçtiği için **sahte ölçüm
    üretilmedi**; iki migration gövdesi ayrı transaction'larda replay edildi (8963 örnek):
    `telephony_provider_effects` 80 ms, `pg_proc` 180 ms, `tenants` 123 ms. Ş78-L3'ün üç
    tablosunda tutma **0 ms — yapısal**, DDL yok. Ş78-L2 geri alındı; geri alma `pbxtr_owner`
    ile **koşmuyor**, `-U postgres` gerekiyor ve bu yazılı değildi.
  - `BR-DB-91`: öncül bayat (`RlsTemplateRefresh` zaten canlıda, ölçülmeden çıkmış). **Ölçüm
    aletinde kusur:** `awk` özeti tek tırnak çakışmasıyla hiç çalışmıyordu. Körlük iki
    seviyede geçti. Eşik: FAIL-CLOSED red yalnız `statement_timeout` (30 sn) dolunca
    **görünür**; altındaki tutmalar **askıda bırakır**; `httptimeout=1` ile operasyonel eşik
    **1 sn**.
  - `BR-BE-150`: recreate öncesi 0, sonrası iki okuma 0; koşan ikili kapıyı UTF-16LE taramasıyla
    **taşıyor** (ASCII grep 0 derdi).
  - `BR-00d`: 23 Eylül'ün `channelvars` değişikliği yeni imajla yeniden yaratmadan **sağ çıktı**
    — hem bind mount hem imajın kendisi aynı satırı taşıyor.
- **Canlı kusur (`BR-BE-217`):** `credential-rotation` **6/6 istek HTTP 500**,
  `42703: column e.sip_secret_set_at does not exist`; `PlatformRollupJob` de yanıyordu.
  `Sprint03TrunkSecurity…` history'de uygulanmış ama DB'ye **eski gövdesi** koşmuş. Onarım
  migration'ı `20260924093000_ExtensionSipSecretSetAtRepair` yazıldı (`Karar#82`). Sunucuda
  eşdeğer SQL elle uygulandı, rotasyon 200.
- **`BR-DB-111` ürün kusuru düzeltildi:** `QueueMembershipSyncJob.WriteGapLedgerAsync` çapraz
  kipte yazıyordu → satırın kendi tenant'ına alındı. Mutasyon KIRMIZI (2 bulgu).
- **CLAUDE.md + AGENTS.md düzeltmesi (`BR-DOC-24`):** BR-DOC-22 tablosu "`ConfigRenderer.cs`'de
  `CURL(` sayısı 0" diyordu; kendim ölçtüm — bugün **1**, ve teslim edilen dialplan
  (`t0007:170`, `t0012:122`) gerçekten `127.0.0.1:8790/telephony/route-decision`'ı çağırıyor.
  Satır silinmedi, üzeri çizildi; `kapi_75` düzeltmeden sonra da yeşil.
- **Öncülü çürüyen kartlar:** `BR-BE-203` ("call_events 0 satır" → 8541), `BR-AST-17` (dört
  iddiadan üçü), `BR-AST-111`/`114` (engel şema değil **veri**), `BR-AST-104`
  (`[pbxtr-t0007-vm]` **ölü kod**), `BR-AST-79`, `BR-DB-76` (144 bin/gün → 7.809/gün).
- **Yeni kart `BR-DB-113`:** `iys_permissions` canlıda **0 satır** → her giden arama
  `BLOCKED_IYS`.
- **Sonuç:** açık **79 → 72**, P0 **0**.

### 10. ClickUp (`a2238619`)

`--kuru` → `clickup-olustur.js` (7 yeni kart) → `clickup-senkron.js` (13 durum) → `--kuru`:
**fark olan kart 0, izde olmayan 0.**

---

## Kararlar

- **Trunk tailscale üzerinden, SIP internete açılmaz.** Docker publish ufw'yi baypas eder.
- **Mesai muafiyeti ölçüme bağlanır, bayrağa değil.** Ölçüm ortamdan gelir, dosyada tutulmaz.
- **S1 muafiyeti yalnız `--santral` ile ve yalnız "geride" dalında**; yayın sonrası yeniden
  ölçüm zorunlu (ödendi).
- **Koordinatör kararı `Karar#81`/`#82`** (kurul dağıtıldı biçimi).
- **Sahte ölçüm üretilmez:** kaçırılan migrate penceresinin yerine replay, ve bu kayıtta
  açıkça yazılı.

## Açık kalanlar / sonraki adım

- **Beş ajan koşuyor** (`/goal tüm maddeleri bitirelim`): SYS+OPS (başta `BR-SYS-132` confd
  mTLS), 12 ölçülmemiş Asterisk kartı, BE+FE (+ `BR-BE-216` regresyon bekçisi), QA+SEC+genel,
  DB (+ `BR-DB-113`).
- **Yayına girmemiş kod:** `20260924093000_ExtensionSipSecretSetAtRepair`, `BR-DB-111`
  düzeltmesi. Girmezse `credential-rotation` bir sonraki temiz kurulumda yine kırık.
- **`pbxtr-confd` ölü** — provisioning teslimi 06:35:50Z'den beri durmuş.
- **`pbxtr-edge` uygulanmamış** — `4573` ve `8790` dinlemiyor; giden yol kapalı, gelen yönde
  rota kararı hiç sorulmuyor.
- Bu günün commit'lerinde **tam test takımı koşmadı** (7. yayın koşusu bellekten kesildi).

---

## Öğleden sonra turu (10:40–11:00Z) — QA/Asterisk sonuçları + sır döndürme

### 1. pbxtr-qa ve Asterisk ajanı sonuçları backlog'a işlendi
- **Neden:** paralel ajan dalgasının iki üyesi bitti; sonuçları görünmez kalmasın.
- **Ne yapıldı:** QA 13 kart (BR-SEC-16/28, BR-10, BR-QA-121/123/95/112/122/124, BR-SEC-08, BR-A1, BR-C2-1/2)
  + yeni **BR-BE-218** (rapor zamanlaması canlıda 500 ama satır yazılıyor → çift zamanlama).
  Asterisk 12 kart: **5 kapandı** (BR-AST-53/105/123/109/125), 3'ünde öncül çürüdü (62/81/89),
  4'ü engel adıyla açık (119/117/118/126); yeni **BR-AST-129** (SLA zil grubu yüklemi 0 canlı satıra eşleşiyor).
- **Dokunulan:** `yonetim/backlog.md`, `SlaAggregationJob.cs` + `AsteriskEndpointDialGuardTests.cs` (yalnız XML yorum).
- **Betik yöntemi:** backlog yamaları `scratchpad/t6.py`, `t7.py` (Write ile yazıldı — Bash heredoc'u `'PYEOF'` ile bile tırnak hatası verdi).
- **Commit:** `46d38d29`, `1704edbb`.

### 2. SIR DÖNDÜRME — BR-SEC-16 + BR-SEC-28 KAPANDI (kullanıcı kararı "Şimdi, hepsini döndür")
- **Neden:** QA ölçtü: 09-10'da sızan pepper/AMI/ARI hiç döndürülmemişti; sızan confd anahtarı bugün de kullanılıyordu.
- **Tarif (yeniden yapılabilir):**
  1. `.env` (`/home/vuo/pbxtr-demo/.env`) python ile yerinde: üç anahtarın her biri tam 1 kez bulunmalı,
     yeni değer `secrets.token_urlsafe(32)`; yalnız sha256 öneki basılır.
  2. `docker compose up -d --no-deps --force-recreate asterisk app` → sağlık bekle → imajın değişmediğini doğrula
     → beş env değişkeninin konteynerde yeni değere eşit olduğunu `docker inspect` ile ölç.
  3. **SIRA ÖNEMLİ (iki kez duvara çarpıldı):** (a) t0012 anahtarı aynı düğümde aktifken sahip anahtar açamaz
     → **403 `node_owned_by_other_tenant`** (Kurul #77); (b) aynı tenant+düğümde eski anahtar aktifken
     → **409 `node_already_pinned`**. Doğru sıra: **eski anahtarları iptal et → demo.sahip ile yeni anahtar
     (`POST /api/v1/api-keys`, node `asterisk-01`, allowlist `172.16.0.0/12`) → `anahtar.next`'e 0600 yaz
     → superadmin + `X-Tenant-Id: 2222…` ile t0012 üyelik anahtarını yeniden aç** (yoksa t0012 düğümden düşer, confd TEMPFAIL 75).
  4. confd `.next`'i 200 ile kabul etti ama **`mv` Read-only file system** ile düştü (birim `ReadOnlyPaths=/etc/pbxtr/confd`) → elle `mv`.
- **Sonuç / doğrulama:** önekler `5c157b52→73aa0505`, `0e5b1296→64b6e20a`, `f2d6aa51→9cab332d`
  (eskiler QA'nın ölçtüğü sızan değerlerle aynı). Eski anahtar **401**, yeni **200**; AMI `pbxtr` bağlı, ARI `pbxtr` app var;
  confd 304. Yeni anahtarlar: t0007 `ak_52767582a273a168`, t0012 `ak_f4aedbd0a303d366`. `sifreler` aynası `f0c46f6`.
  Sunucudaki eski-sır yedekleri ve betikler silindi.
- **Yeni kartlar:** **BR-SYS-134** (P1, belgelenen örtüşmeli rotasyon iki yerden kırık), **BR-BE-219** (P2, node-bundle
  sürüm başlığı eksikse 500 `INTERNAL`).
- **Commit:** `5979fd7f`, ClickUp `bdb20ff5` (4 yeni kart, 10 durum, kuru fark 0).

## Açık kalanlar (tur sonu)
- linux-uzmani (BR-SYS-132 confd mTLS), backend-dev-1 (BE+FE), db-dev (DB + BR-DB-113) hâlâ koşuyor.
- Yayınlanmamış kod: `20260924093000` onarım migration'ı, BR-DB-111, BR-BE-216.
- `.env.oncesi-demo` ölü üç sırrı hâlâ taşıyor (diğer satırları kapsam dışı).

---

## 11:45–12:00Z — linux-uzmani sonuçları, SIP parola döndürme, BR-SYS-134

### 1. BR-SYS-132 KAPANDI — confd mTLS teslimi çalışıyor (`03861d73`)
- **Neden:** provisioning teslimi 06:35Z'den beri ölüydü; engel hiç var olmayan PKI zinciriydi.
- **Ne yapıldı (linux-uzmani):** iç CA + düğüm istemci sertifikası + 30 günlük CRL + nginx 8443 opt-in + DOCKER-USER kısıtı.
  Dört kusur düzeltildi (ayrıştırıcı docker dalı, reload host ikilisi, getpwnam(asterisk)→UID/GID env, TimeoutStartSec 30→180).
  CRL yenilemesi nginx'e ulaşmıyordu → BindPaths drop-in'i.
- **Koordinatör:** yalnız sunucuda duran dört dosya depoya alındı: `deploy/pbxtr-crl-yenile.service.d/10-nginx-mount-yayilmasi.conf`,
  `deploy/telefon-kanali/8443.conf`, `deploy/pbxtr-8443-guvenlik-duvari.{service,sh}` (günün tekrarlayan deseni: sunucuda elle duran, depoda karşılığı olmayan yapılandırma).
- **Sonuç:** HTTP 200 + Ed25519, kararlı 304; t0007 endpoint 7→13. Ayrıca kapanan: BR-SYS-131, BR-SYS-118, BR-OPS-17.

### 2. t0007 SIP + WebRTC parolaları döndürüldü
- **Neden:** linux ajanı tanılamada `t0007-1042` bloğunu açık `password=` ile bastı.
- **Tarif:** demo.sahip ile `GET /api/v1/extensions` → her dahili için `POST /api/v1/extensions/{id}/credential-rotation`
  ve WebRTC olanlar için `POST /api/v1/users/extensions/{id}/webrtc` (yeniden vermek = döndürmek); yanıtlar atılır.
  pjsip dosyası `/etc/asterisk/pbxtr.d/pjsip/t0007-pjsip.conf` (alt dizin!).
- **Sonuç:** 12/12 200, `password=` satırları özeti `ab27f65d→1d425ab9`, `reload: res_pjsip`, endpoint 13 sabit.

### 3. BR-SYS-134 BİTTİ — anahtar rotasyonu elle müdahalesiz (`de4bd263`)
- **Karar (koordinatör):** anahtarlar `/etc/pbxtr/confd/anahtarlik/` alt dizinine, birimde yalnız o `ReadWritePaths=-…`;
  trusted-signers.d/dugum/mTLS anahtarı salt-okunur kalır. Tek aktif anahtar kuralı korunur, sıra "önce iptal → üret → .next".
- **Dokunulan:** `deploy/pbxtr-confd-dugum.sh`, `deploy/pbxtr-confd/pbxtr-confd.service`, `deploy/staging-yayin.sh`, `deploy/pbxtr-confd-runbook.md`.
- **Yolda tuzak:** paylaşılan düğümde (t0012 üyeyken) t0007 sahibi yeni anahtar açamaz → 403 `node_owned_by_other_tenant`;
  eski anahtar zaten iptal edilmişti → confd ~40 sn anahtarsız kaldı; superadmin + `X-Tenant-Id: 1111…` ile kurtarıldı.
  **Paylaşılan düğümde rotasyonu platform yöneticisi yapar.**
- **Sonuç:** aday 304 ile kabul, `.next` kalmadı, özet `b4e763fc→9b25a4dc`; systemd-run sandbox testi: trusted-signers.d ve dugum RO, anahtarlik RW.
- ClickUp: 6 durum güncellendi, kuru fark 0.

### BR-SYS-129 (a) — Asterisk spool'u adlı hacme taşındı (linux-uzmani, ~15:31Z)
- **Neden:** `/var/spool/asterisk` ANONİM hacimdi (`4dc45b2f…`); yedeklenemiyor, `down -v` / `--renew-anon-volumes` ile sessizce siliniyordu. Sesli mesajlar (`recording/pbxtr-vm/`) orada.
- **Ne yapıldı:** `pbxtr-demo/docker-compose.yml` → `asteriskspool:/var/spool/asterisk` + üst düzey `asteriskspool:`. Sunucuda: compose damgalı yedek, anonim hacim damgalı tar'a (`/var/backups/pbxtr/asterisk-spool-anonim-20260924T153116Z.tgz`), compose etiketli `pbxtr_asteriskspool` yaratıldı, `compose stop asterisk` → `cp -a` → `up -d --no-deps asterisk`. `deploy/demo/yedek-al.sh` [6] adımı spool'u arşivliyor.
- **Komutlar:**
  ```bash
  docker volume create --label com.docker.compose.project=pbxtr --label com.docker.compose.volume=asteriskspool pbxtr_asteriskspool
  docker run --rm -v <anonim>:/kaynak:ro -v pbxtr_asteriskspool:/hedef alpine:3 cp -a /kaynak/. /hedef/
  docker compose -p pbxtr --project-directory /home/vuo/pbxtr-demo up -d --no-deps asterisk
  ```
- **Doğrulama:** bağlantı `volume pbxtr_asteriskspool`, `healthy`, asterisk kullanıcısıyla gerçek yaz-sil OK, t0007 endpoint 13, `compose-sunucu-sapma.sh` exit 0, yedek arşivi sunucuda 8 girdi.
- **Geri alma:** `docker-compose.yml.onceki-20260924T153116Z` geri koy + `up -d --no-deps asterisk` (anonim hacim silinmedi).
- **Commit:** `e1b62898` (compose + yedek), `107da240` (backlog), eşleme json. ClickUp kuru fark 0.
- **Kalan:** (b) uygulama sağlık satırı; zamanlanmış `pbxtr-yedek` HİÇ hacim yedeklemiyor (yalnız DB) — ayrı bulgu.
- **Yayın:** imaj çıkarılmadı — bu turdaki değişikliklerin hiçbiri imaja girmiyor (compose/confd/yedek sunucu tarafı, hepsi uygulandı); yayın betiği yerelde `dotnet build`/`docker build` ister, bu turda yasaktı.

---

## 12:00–16:30Z — db-dev + backend-dev-1 entegrasyonu, kapılar, yayın hazırlığı

### 1. İki ajanın işi birleşik ağaçta doğrulanıp tek commit'te alındı (`5f891308`)
- **Neden:** sağlık yüzeyi (`platformApi.ts`, 9 i18n, `SystemHealthProbe.cs` …) iki ajanın yarım işini birlikte taşıyordu; yarı commit build'i kırardı.
- **Tarif:** `git ls-files -co --exclude-standard` → tar → sunucu `/root/birlesik` → SDK 10 konteyneri: build + Architecture + Api (filtreli) + Integration (filtreli) + node:22 vitest/tsc.
- **Tuzaklar (sırayla):** çözüm dosyası `pbxtr.sln` (slnx değil; yanlış adla "RC=0" sahte çıktı);
  vitest yalnız `Pbxtr.Web` bağlanınca 7 sahte kırmızı (C# kaynağını okuyan parite testleri) → tüm depo bağlanmalı;
  Integration iç içe docker'da Ryuk başlamıyor (`ResourceReaperException`) ve `172.17.0.1:<port>` zaman aşımı →
  **`--network host` + `TESTCONTAINERS_RYUK_DISABLED=true`** + koşu sonunda `label=org.testcontainers=true` temizliği;
  `pkill -f <betik>` ssh oturumunun kendisini öldürdü → `/proc/<pid>/cmdline` tam eşleşmesiyle öldür.
- **Bulunan test kusuru:** `DbDevSeptember24MigrationRollbackTests:61` `MigrationId > '20260924093000'` hedef migration'ın
  kendi kimliğini de sayıyordu (her zaman 1) → tam kimlikle.
- **Karar#83** (koordinatör): üç migration onay defterine; blob'lar dosyalarla eşleşti.
- **Sonuç:** build 0 hata; Api 742/742; Integration 62/63 + düzeltilen 1/1; Vitest 167/167; tsc 0; Architecture 776/777 (jq yok, ortam).

### 2. Yayın kapıları: 8 kırmızı → 0 (`d10c336c`, `06fb1ae4`)
- çapraz kip envanteri + yazma daraltması `--dondur` (CallbackRunJob'daki `ExecuteUpdateAsync` ayrı DI kapsamı + kendi transaction'ı → metin tabanlı yanlış pozitif, incelendi);
  mesai listesi `migration-agir-ddl.py --uret`; trunk compose üç envantere + digest; backlog BR-AST-17/111 boru kayması (`\ /`).
- **BR-OPS-17 bayatlık kapısı** tam Integration takımını istedi → sunucuda 44 dk: **1226/1229**; 2 kırmızı:
  kanonik şema revizyonu bayattı + SignedFixture dosyaları Linux umask'ında 0644 doğuyordu (Windows'ta kontrol yok) → ikisi düzeltildi, sınıf 25/25.
- `--santral` ile yeniden: **87 konteyner + 6 host kapı YEŞİL**.

### 3. Yayın
- İmajlar sunucuda HEAD `06fb1ae45f59`'dan: `tekbirsoft/pbxtr:demo-06fb1ae45f59`, `tekbirsoft/pbxtr-asterisk:22-06fb1ae45f59` (git.sha damgası doğrulandı).
- `yayin7.sh` (yerel-yayin 7/7'nin sunucu karşılığı: push + dosya kopyası + SHA'lar + staging-yayin) → **mesai kapısı 71**:
  4 yeni migration muafiyeti yasak listesinde, ölçülmüş pencere yok. Hiçbir şey değişmedi (yedek `pre-06fb1ae45f59.dump`).
- **Karar:** kapının belgelenmiş kaçış yolu mesai dışı yayın → sunucuda 17:01Z'ye (20:01 TR) zamanlandı.

### Ayrıca
- linux-uzmani ek tur: BR-SYS-129(a) spool adlı hacme; yeni kart **BR-SYS-135** (gece yedeği hacimleri almıyor).
