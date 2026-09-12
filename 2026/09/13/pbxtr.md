# pbxtr — 2026-09-13

## Bağlam

Dün (2026-09-12) `M1` ölçümü C ekseninin **üretimde hiçbir veri üretemeyeceğini** gösterdi:
`PJSIPShowEndpoints`/`PJSIPShowEndpoint` bugünkü AMI kimliğiyle `Permission denied` alıyordu ve
çalıştırmanın bilinen tek yolu `write += system` idi. Kart `BR-AST-71` açılmış, karar kurula
bırakılmıştı. Bugün kurul toplandı, karar alındı ve **aynı gün uygulandı**.

## Yapılanlar

### 1. Kurul — `Karar #46`

- **Neden:** yetki yükseltmesi CLAUDE.md §3.1'in doğrudan konusu; kararı tek başıma veremezdim.
- **Ne oldu — kararın en önemli kısmı budur:** oylama sırasında **sorunun öncülü çürüdü.**
  Kurula üç seçenek sunulmuştu ((a) `write += system`, (b) yalnız okuma için ikinci bir AMI
  kullanıcısı, (c) `pbxtr-sysagent` → `AST-CLI`). Asterisk uzmanı oyuyla birlikte **ölçülmemiş
  dördüncü bir yol** bildirdi — ARI `GET /endpoints` — ve *"iddia etmiyorum, ölçülmeli"* dedi.
  Ölçüldü ve **sıfır yetki değişikliğiyle çalıştı.** Ardından Şeytan'ın birinci itirazı ikinci
  bir ölçüm doğurdu (`ContactStatus` olayı bugünkü yetkiyle akıyor mu → akıyor). Sunulan üç
  seçeneğin **hiçbiri kazanmadı.**
- **Sonuç:**
  - **Karar 1** — `registered` ← ARI `GET /endpoints`; **AMI yetkisi DEĞİŞMEZ**; (a) ve (b)
    **CTO tarafından veto edildi**; seçenek (a) **kalıcı olarak reddedildi**.
  - **Karar 2** — `transportWs` ve `contactCount` yüzeyden **kaldırıldı**.
  - 15 şart (Ş-46-1…15). Şeytan'ın 13 itirazı: 7'si geri çekildi, 2'si kabul edildi, **1'i
    ölçüldü ve YANLIŞ çıktı**, 1'i konusuz kaldı, 1'i kayda geçti, **1'i AÇIK kaldı.**
- **Dosya:** `yonetim/kurul-kararlari.md` → `## Karar #46` (satır 9471)
- **Komut:**
  ```bash
  cat karar46.md >> yonetim/kurul-kararlari.md
  git add yonetim/kurul-kararlari.md && git commit -F msg46.txt && git push
  ```
- **Commit:** `2591b2a4`

**CTO'nun veto gerekçesi (ölçülmüş):** AMI kimliğimizde **zaten `originate` var**. `system` ile
birleşince `Originate: Application: System` üzerinden Asterisk konteynerinde **sarmalayıcısız
keyfi kabuk** açılır; `ModuleLoad: LoadType: unload` ise CLAUDE.md §3.1'in **adıyla** yasakladığı
`module unload` yüzeyini geri açar. Seçenek (b) blast radius'u **küçültmüyordu**:
`manager.conf`'ta **eylem bazlı ACL yoktur** — bir sınıf açılırsa sınıfın tamamı açılır.

### 2. Kayıt ekseni AMI'den ARI'ye taşındı

- **Neden:** aynı soruyu sıfır yetkiyle cevaplıyor.
- **Ne yapıldı:** `AsteriskAriProvider.GetRegistrationInventoryAsync` → `GET /endpoints`.
  Kapalı eşleme (Ş-46-2): `online`→`true`, `offline`→`false`, **diğer her şey** (`unknown`
  dâhil, henüz görülmemiş sürümlerin getireceği her metin dâhil) → `null`. Tanınmayan değer
  **sayaç + `LogWarning`** üretir — sessiz toplu "ölçülemedi"ye düşüş bugünkü arızanın aynısı
  olurdu. `channel_ids` **okunmaz** (Ş-46-4: aktif *kanal* sayar, contact değil).
- **`AmiCommandChannel.RegistrationInventoryAsync` SİLİNDİ** — çalışmayan ama duran bir yol, bir
  gün "zaten yazılı" diye yeniden bağlanır ve o gün yetki sorusu bir daha sorulmaz.
- **Tam ya da hiç (Ş-46-3):** `200` dışı yanıt, dizi olmayan gövde ve ayrıştırılamayan gövde
  **istisna** üretir — asla boş liste. Boş liste "santralde hiç nesne yok" cümlesidir ve HTTP'de
  bu hatayı yapmak AMI'dekinden kolaydır.
- **Dokunulan dosyalar:** `src/Pbxtr.Infrastructure/Telephony/Asterisk/AsteriskAriProvider.cs`,
  `AmiCommandChannel.cs`, `src/Pbxtr.Domain/Modules/Telephony/Runtime/EndpointRegistrationStates.cs`

### 3. `contactCount` ve `transportWs` kaldırıldı — ama **aynı cümle değiller**

- **Neden ayrı yazıldı (db-liderin şartı, Ş-46-14):** aynı kutuya konsalardı bir gün "ikisi de
  ölçülemiyordu" diye ikisi birden geri getirilirdi.
  - `transportWs` → **kaynak YOK.** `TransportDetail` çerçevesi Asterisk 22.10.1'de hiç
    üretilmiyor; alan üretimde daima `null`'du, yani `Down` dalı **erişilemezdi**.
  - `contactCount` → **kaynak VAR ve çalışıyor** (`AorDetail.ContactsRegistered`, 1→2→3 doğru
    saydı); **yetki bilinçle alınmadı.**
- **Ne yapıldı:** domain tipleri (`RegistrationObservation`, `RegistrationInventory`,
  `RegistrationSummary`, `RegistrationAxis`, `RegistrationAxisDto`), `#37` bileşeni, ön yüz
  sözlüğü (4→**3** hâl) ve 9 dilin i18n'i temizlendi (18 + 9 satır silindi).
  `asterisk-transport-ws` satırı kaldırıldı; `asterisk-registered-contacts` →
  **`asterisk-registered-objects`** (o satır hiçbir zaman contact saymadı — adı taşıdığı ölçümü
  **yanlış** anlatıyordu).
- **`IsWellFormed` (gözlem tarafı) birlikte emekli oldu:** koruyacağı alan kalmadı. Ölçtüm:
  `src` altında zaten **hiç çağrılmıyordu** — yani alan kalsaydı bile koruma yoktu.
  (`RegistrationAxis.IsWellFormed` **duruyor**: onun koruduğu invaryant
  `Registered == null ⇔ MeasuredAt == null` ve o hâlâ geçerli.)
- **Ş-46-15 mutasyonla doğrulandı:** `{ registered: true, contactCount: 3 }` taşıyan bir fikstür
  artık **derlenmiyor** (`TS2353`). Alan tipte opsiyonel bırakılsaydı mutasyon sessizce yeşil
  kalır ve kaldırma yarım olurdu.

### 4. `Response: Error` yutulması — **ölçülmüş, karardan bağımsız kusur** (Ş-46-7)

- **Neden:** AMI okuma döngüleri yalnızca `*Complete` ve veri olaylarını tanıyordu. Santral bir
  eylemi **reddettiğinde** tek gönderdiği şey `Response: Error` taşıyan bir yanıt çerçevesidir ve
  o çerçeve **hiçbir dala uymuyordu**: döngü hiç gelmeyecek `*Complete`'i beklemeye devam
  ediyordu. Yani **reddediliş bir yavaşlık gibi yaşanıyordu** (10 sn zaman aşımı) ve günlükte
  reddin adı hiç geçmiyordu.
- **Ne yapıldı:** `IsRefusal` ortak yardımcısı; `QueueStatus`, `QueueSummary`,
  `CoreShowChannels` ve `PJSIPShowEndpoints` döngülerinin **dördünde birden** uygulandı.
  `Message` başlığı loglanır (reddin gerekçesini taşır), ham çerçeve loglanmaz (tenant önekli
  adlar taşıyabilir).

### 5. `job_runs` artık yalan söylemiyor (Ş-46-8, birinci yarısı)

- **Neden:** ölçemeyen tur `return 0` ile **`succeeded`** yazıyordu; "tur koştu, ölçemedi" ile
  "tur koştu, ölçecek bir şey yoktu" canlıda **ayırt edilemiyordu**.
- **Ne yapıldı:** `RegistrationSamplerJob` istisnayı yutmuyor, **yeniden fırlatıyor** → iş
  `failed` yazılıyor, bir sonraki tick baştan deniyor. Simülasyon/soketsiz bileşimde sağlayıcı
  `null` döner ve o **hâlâ `Information` + başarılı tur**'dur — çünkü orada bir arıza yok.
- **Kalan iş kartlaştırıldı:** `BR-AST-73` (ardışık N başarısız tur → `#37`'de kırmızı satır).

### 6. `kapi_48` — AMI `write` kümesi kilitlendi (Ş-46-1, kararın **tek kalıcı çıktısı**)

- **Neden bir kapı, neden bir yorum satırı değil:** `system` yetkisi verilince eylem **gerçekten
  akıyor** (A/B ölçüldü). Yani bir gün "tek satır, hemen çalışıyor" diye eklenmesi çok kolay.
- **Ne yapıldı:** `deploy/yerel-kapilar.sh` `kapi_48` (47 → **48 kapı**). Depodaki **her** AMI
  `write = ...` bildirimini tarar; izinli küme `call agent originate`. İki korumayla:
  - **Öz-test** (kapıdan **önce** koşar): temiz küme kabul edilmeli, yasak sınıf taşıyan mutant
    **reddedilmeli**. Kapının sessizce yeşil kalması, kilidin hiç olmamasından kötüdür.
  - **Vacuity:** hiç bildirim bulunamazsa **kırmızı** — "0 ihlal" bir ölçüm değil, bir
    sessizlik olurdu.
  - Mutant dize **parçadan üretilir**; düz yazılsaydı kapı **kendi kaynağını** yakalar ve
    sonsuza kadar kırmızı yanardı (homoglif tarayıcısının düştüğü tuzağın aynısı).
- **Mutasyonla doğrulandı:**
  ```
  sed -i 's/^write = call,agent,originate$/&,system/' deploy/asterisk-lab/lab-entrypoint.sh
  -> IHLAL: lab-entrypoint.sh:93 (izinsiz sinif: system)   RC=1
  git checkout -- deploy/asterisk-lab/lab-entrypoint.sh    (kalinti: 0)
  -> depoda 3 AMI 'write' bildirimi tarandi   RC=0
  ```

**Kapı kurulduğu İLK KOŞUDA gerçek bir sızıntı yakaladı:**
`doc/mimari/asterisk-olay-eslemesi.md` §2.1 `write = call,agent,originate,reporting,system`
tarif ediyordu — yani **belge, koddan daha geniş bir yetki öneriyordu**. Sunucuda `manager.conf`
**elle** yönetildiği için bu, bir gün operatörün belgeye bakıp fazladan yetki vermesi demekti.
Düzeltildi ve gerekçesi belgeye yazıldı.

### 7. Belgeler

- `CLAUDE.md` §3.1 — yasak **adıyla** yazıldı ("üçüncü yol yoktur"), gerekçesiyle ve `kapi_48`
  referansıyla.
- `doc/prototip-urun-farklari.md` — Ş-46-14'ün **iki ayrı satırı** (tablo: kaynak var/yok).
- `doc/mimari/m1-kayit-envanteri-olcumu.md` — ölçümün **sonucu**: hangi seçenek neden düştü.
- `doc/mimari/asterisk-transport-ve-kayit-gozlemi-sozlesmesi.md` — başına uyarı bloğu: belgenin
  **iki konusu da kapandı**, ama §2.2 (*ayrıştırılan CLI metni bir kontrat değildir*) ve §4.2
  (*H1 ölçülemez*) **hâlâ bağlayıcı**. Metin silinmedi.
- `yonetim/backlog.md` — `BR-AST-71` kapandı; `BR-AST-72` ve `BR-AST-73` açıldı.

### 8. ClickUp eşleme kusuru — kendi kartım yakaladı

- **Nasıl çıktı:** `BR-AST-71`'i kapatıp senkronu koşturunca kart `to do` göründü. Oysa
  kartın kendi işi **aynı gün bitmiş ve push edilmişti**; kalan tek şey `BR-AST-72`'ye
  devredilmişti.
- **Birinci kusur:** durum metni hem `Kurul: ŞARTLI ONAY (Karar #46)` hem
  `Bitti (2026-09-13)` taşıyordu ve eşlemede `Kurul: … ONAY → to do` kuralı `Bitti →
  complete` kuralından **önce** geliyordu. Yani onaylanmış **ve bitmiş** her kart panoda
  açık görünüyordu.
- **İkinci, daha eski kusur (düzeltirken çıktı) — ikisi birbirini örtüyordu:**
  - Kural 6 (*"ortadaki `bitti` → in progress"*) `!/^Bitti/i` kullanıyordu. JS'te ``
    **yalnız ASCII harf tanır**: `Bittiği` metninde `Bitti`den sonra gelen `ğ` ASCII'de
    harf olmadığı için **sınır üretiyor** ve kural 6 metni **kaçırıyordu**. Bu, dosyanın
    kendi yorumlarının 2026-09-10'da uyardığı tuzağın ta kendisi — **uyarı yazılmış, aynı
    satırda uygulanmamıştı.**
  - Kaçan metin sonra çıpasız `/Bitti|Kapandı/` alt dize testine düşüp **`complete`**
    yazılıyordu. Yani *"Bittiği sanılıyordu ama değil"* panoda **KAPALI** görünüyordu —
    deponun en pahalı yönü (**açık işi kapalı göstermek**).
- **Ne yapıldı:** `SON` ileri-bakışı fonksiyonun başına alındı, `BASTA_BITTI` tek yerde
  tanımlandı, çıplak `Bitti` alt dize testi kaldırıldı. **Ters yön korundu:** onaylanmış
  ama **başlamamış** kart hâlâ `to do`.
- **Mutasyonla doğrulandı:** düzeltme geri alınınca 8 testin **2'si kırmızı**, geri
  getirilince **8/8 yeşil**, kalıntı `0`.
- **Senkron:** `BR-AST-72` ve `BR-AST-73` panoda açıldı; `fark olan kart: 0, izde olmayan: 0`.
- **Commit:** `e57bdfdd`

**Ders:** *bir uyarıyı yazmak, onu uygulamak değildir.* Aynı dosyanın yorumları ``
tuzağını isim isim anlatıyordu ve **bir satır yukarıda** o tuzağa düşülmüştü. Uyarı yazılan
dosyada, uyarının kendi kuralına uyulup uyulmadığı ayrıca ölçülmeli.

## Kararlar

- **Ölçülmemiş bir seçeneği "yol" diye sunmak, kurulu yanlış soruya oy verdirir.** Kurula üç
  seçenek götürdüm; dördüncüsü ölçülmemişti ve **kazanan oydu**. Öneri yazarken *"hangi
  seçenekleri ölçmedim"* sorusu, *"hangilerini ölçtüm"*den daha önemli.
- **Şeytan'ın itirazı doğru olduğu için değil, ölçüm doğurduğu için değerli.** 13 itirazın 7'si
  geri çekildi ve **biri ölçüldü, yanlış çıktı** (`AmiAriEventConsumer` lider seçmiyor dedi;
  seçiyor — `AmiAriEventConsumer.cs:244-245`, `BackgroundJobLocks.AmiConsumer`). Ama itiraz 1
  olmasaydı ARI hiç ölçülmeyecekti. **İtirazı doğrulamak da cevaplamanın parçası:** yanlış bir
  itirazı sessizce kabul etmek, doğru bir itirazı görmezden gelmek kadar pahalı.
- **"Kaynağı yok" ile "yetkisi alınmadı" aynı kutuya konmaz.** İkisi de bugün aynı ekranı
  üretiyor (alan yok) ama **geri gelme maliyetleri ve karar sahipleri farklı**.
- **Bir arıza "yavaşlık" kılığında geliyorsa, hiç kimse onu arıza diye aramaz.** `Permission
  denied` 10 saniyelik bir zaman aşımı olarak yaşanıyordu; bu yüzden düzeltme karardan bağımsız
  bir şart olarak yazıldı.
- **Bir uyarıyı yazmak, onu uygulamak değildir.** ClickUp eşlemesinin yorumları ``
  tuzağını isim isim anlatıyordu; **bir satır yukarıda** o tuzağa düşülmüştü ve kusur iki
  yıl değil, iki kural boyunca birbirini örterek saklanmıştı.
- **Bir yasağın en güvenilir hâli bir cümle değil, bir kapıdır** — ve kapı kurulduğu ilk koşuda
  yasağın **zaten çiğnendiğini** gösterdi (belgede). Yorum satırı olsaydı hiç görülmezdi.

## Açık kalanlar / sonraki adım

- **`BR-AST-72` — üretim santralinde hiçbir şey doğrulanmadı** (Ş-46-10; Şeytan'ın 5. itirazı
  **AÇIK**). ARI üretimde kapalıysa veya farklı portta dinliyorsa C ekseni yine **sessizce boş
  kalır** ve bunu söyleyen bir alarm yoktur. Tamamı salt-okuma: `core show version`,
  `ari show status`, `curl -u ... http://127.0.0.1:8088/ari/endpoints`. Ayrıca Ş-46-11'in üç
  ölçümü: `unknown` durumunun **fiilen üretilmesi**, statik contact'lı endpoint'in `online`
  görünüp görünmediği, ve **ölçek** (laboratuvarda 1 endpoint vardı). **Bu tablo dolmadan C
  ekseni "çalışıyor" ilan edilmez.**
- **`BR-AST-73`** — Ş-46-8'in ikinci yarısı (ardışık N başarısız tur → `#37`'de kırmızı satır,
  yeni `HealthState` değeri **eklenmeden**).
- `ContactStatus`'un değer kümesi tam görülmedi (yalnız `NonQualified`); **düşme yönü**
  ölçülmedi. Seçenek (b) bir gün açılırsa bunlar ölçülmeden `contactCount` yayınlanmaz.
