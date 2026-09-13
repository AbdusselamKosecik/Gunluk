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

---

# Ek tur — SMS veri bağı, canlı DND ekseni ve kendi kart betiğimdeki ikinci kolon hatası

## Bağlam

Önceki turun ardından beş kart paralel ajanlara dağıtıldı. Bu bölüm ikisinin (`backend-dev-1`
ve `backend-dev-2`) kapanışını, kart güncellemesinde **kendi betiğimde ikinci kez çıkan** bir
sessiz kusuru ve panoya yansımayı kaydeder.

## Yapılanlar

### 1. `BR-DB-43` + `BR-BE-60` + `BR-BE-64` — çağrı sonrası / kampanya SMS veri bağı

- **Neden:** Üç kart da birbirini bekliyordu; `BR-BE-60` *"yarısı bitti (veri bağı BR-DB-43)"*,
  `BR-BE-64` *"çoğu bitti (otomatik tur BR-DB-43)"* diyordu. Özellik bugün **inert**ti.
- **Kartın kendi tıkacı ölçüldü ve YOK çıktı.** Kart işi bir "terminal migration" engeline
  bağlamıştı; `BR-DB-34` A seçeneği **2026-09-12'de uygulanmış** ve `TerminalMigration` sabiti
  silinmişti. Taşınacak bir şey yoktu. *(Bu, "kart öncülü ölçülmeden yazılmaz" dersinin bugün
  dördüncü tekrarı.)*
- **Ne yapıldı:** `20260913150000_PostCallAndCampaignSmsBinding` —
  `tenant_settings.post_call_sms_template_id`, `campaigns.sms_template_id`,
  `sms_templates.trigger` (text NULL + CHECK).
  - **DB varsayılanı bilerek yok:** varsayılan konsaydı mevcut **her tenant** bir dağıtımla
    sessizce **SMS göndermeye başlardı**.
  - İki FK de **bileşik** `(tenant_id, template_id)` — tekil FK çapraz-tenant şablon işaret
    etmeyi DB seviyesinde serbest bırakırdı.
- **İki gerçek kusur bulundu ve düzeltildi:**
  1. `ef migrations remove` model anlık görüntüsünü **boşalttı** (önceki migration
     Designer'sız elle yazılmıştı). Sonraki `add`, tüm şemayı yeniden yaratan **3657 satırlık**
     bir migration üretti: taze DB'de `42P07`, artımlı kurulumda **tamamen sessiz**. Doğru
     166 satırlık fark elle yazıldı, Designer bu kez **bilerek** bırakıldı.
  2. EF'in ürettiği FK adı **68 karakterdi**; PostgreSQL 63'te kırpar → `Down()`'daki
     `DROP CONSTRAINT <tam ad>` **hiçbir zaman eşleşmezdi**. Ad 41 karaktere indirildi.
- **M2 mutasyonu ilk koşuda YEŞİL kaldı = gerçek kapsam deliği.** RLS satırları zaten
  gizlediği için test, EF sorgu filtresi hakkında **hiçbir şey ölçmüyordu**.
  `CampaignTenantLeakTests` deseniyle 6. test eklendi; M2 sonra kırmızı yandı.
  *(Defterdeki "mutasyon yeşilse fikstürü sorgula" kuralı yine doğru çıktı.)*
- **İkinci vacuity yakalaması:** eksik `services.AddLogging()` üç negatif testi **yanlış
  sebepten** geçirtiyordu — iş her kampanyada fırlatıyordu.
- `BR-BE-64` kendi advisory kilidini alır (**36**): dialer (22) ve geri arama (25) santrale
  **çağrı** başlatır, bu iş bir **SMS sağlayıcısına** HTTP atar. Paylaşılan kilit birini
  ötekinin **açlığına** düşürürdü ve bu hiçbir yerde hata üretmezdi.
- **Ölçüm:** db kapıları EXIT=0 (iki kez), build 0 hata, Architecture 470/470, Api.Tests
  `Sms|Campaign` 237/237, yeni Integration 10/10. Integration tam takım **806/813** — 7 kırmızı
  `git stash` ile temiz HEAD'de tekrar ölçüldü: **aynı 6 önceden var olan hata** + 1 sıra
  bağımlı flaky.

### 2. `BR-BE-128` — canlı DND ekseni

- **Ne yapıldı:** `LiveAgentRow` ve `LiveAgentDto` (14 → 15 alan) üç değerli `bool? Dnd`.
  `null` = ölçülemedi, `false` = ölçüldü ve kapalı. `grep -rn "Dnd ?? false" src/` → **0**.
- **Redis agent gövdesine KOYULMADI ve sebebi ölçüldü:** `SetAgentAsync` her durum olayında
  gövdenin **tamamını** yeniden yazar. DND orada olsaydı `dnd` taşımayan ilk olay — yani
  **bütün çağrı kenarları** ve `QueueMemberStatus` resync'i — ölçülmüş bir `true`'yu **sessizce
  silerdi**. Belirti "DND çalışmıyor" değil, **"rozet ilk çağrıyla kaybolur"** olurdu.
  Ayrı anahtar, TTL 1 saat; **anahtarın yokluğu `false` değil `null` üretir.**
- **Yeni WS olay tipi açılmadı:** `dnd` yalnızca **beyan edilmişse** `agent.status.changed`in
  dar katmanına eklenir. Her olayda `dnd: null` göndermek **reddedildi** — ilgisiz her çağrı
  kenarı rozeti "ölçülemedi"ye düşürür, **rozet yanıp sönerdi**.
- **Ölçüm:** build 0/0, Architecture 476/476, `Live|AgentState` 298, `LiveAgentDnd` 11/11.
  Mutasyon iki yönlü: `?? false` → 1 kırmızı, olay yayımı kesildi → 3 kırmızı.
  `if (false)` yerine **sabit olmayan** ifade kullanıldı ki CS0162 mutasyonu maskelemesin.
- **Açık eksik, "çalışıyor" sayılmaz:** bugün `dnd` beyan eden **hiçbir üretici yok**; alan
  üretimde her satırda `null` döner ve **rozet hâlâ çizilmez**. Uydurulmadı, çünkü eldeki tek
  değer `extensions.Dnd` **yapılandırma** kolonu ve kart onu açıkça yasaklıyor. Sebep ölçüldü:
  pbxtr'ın DND'si bir **dialplan dalıdır** (`ConfigRenderer.cs:786` → `Busy(20)`); Asterisk'te
  karşılığı olan bir **çalışma-anı durumu yoktur** (`DNDState` AMI olayı `chan_sip` mirasıdır,
  PJSIP'te doğmaz).

### 3. Kendi kart betiğimde AYNI SINIF hata — ikinci kez

- **Ne oldu:** `BR-BE-128`in kapanış metnini yazarken `h[4]`'ü durum sandım. O satırın
  **açıklaması içinde ` | ` geçiyordu**, kolonlar kaydı, `assert len(h) in (5,6)` **yine
  tuttu** (yani hiçbir şey ölçmedi) ve uzun kapanış metni **sprint hücresine** yazıldı.
  Gerçek durum `Bekliyor` kaldı → **kapanmış kart panoda AÇIK görünüyordu.**
- **Bu, sabahki hatanın düzeltmesiydi.** Sabah `h[-1]` kullanmıştım; 6 kolonlu satırlarda o
  **kaynak** sütunudur ve iki kartta kaynağı ezip durumu hiç değiştirmemişti. "Durum daima
  index 4" diye düzelttim — **o da yanlıştı.**
- **Doğrusu zaten depoda yazılıydı:** `clickup-cikar.js` bu sorunu çözmüş ve gerekçesini
  yorumlarına yazmış: **son `P0..P3` hücresi = öncelik**, `sprint = +1`, `durum = +2`.
  Ben aracın çözdüğü problemi kendi betiğimde **yeniden ürettim**.
- **Düzeltme:** satır `HEAD`'ten birebir geri alındı, öncelik çıpasıyla yeniden yazıldı ve
  yazmadan önce **eski hücre değeri doğrulandı** (`assert önceki == 'Bekliyor'`) — kolon
  kaydıysa bu assert patlar, uzunluk assert'i patlamaz.
- **Sınıfın genişliği ölçüldü:** 389 BR satırı tarandı, **başka sapan satır yok**; ama
  **11 satır** açıklamasında boru işareti taşıyor, yani bu bir istisna değil.
- Kart metnine yazılan ham `|` markdown tablosunda yeni hücre açıyor; `BR-FE-76`'da `\|`
  olarak kaçırıldı.

### 4. Açılan kartlar

Ajanların **"bunu yapmadım"** dediği her şey karta dönüştürüldü — aksi hâlde panoda görünmez
olurdu (CLAUDE.md §14):

| Kart | Ne |
|---|---|
| `BR-BE-130` | `sms_templates.trigger` **yazım-anı doğrulaması yok**; CHECK yalnız değerin kümede olmasına bakar, kullanım yeriyle tutarlılığına bakmaz |
| `BR-QA-67` | Checked-in kanonik şema artefaktı bayat; bu tur borcu **3 → 4** migration'a çıkardı |
| `BR-AST-74` | DND'nin santralde **nasıl ölçüleceği** — üç aday, karar kurulun *(numara önce ölçüldü: `BR-AST-72` zaten doluydu)* |
| `BR-FE-76` | WS tüketicisi `dnd` alanının **yokluğu** ile `null` gelmesini ayırmalı; `?? null` okuması rozeti her çağrı kenarında söndürür |
| `BR-FE-77` | Üç alanın **ön yüz seçicileri yok** — bu bir görünüm eksiği değil, özelliğin **tek açma anahtarı** |

## Kararlar

- **`BR-AST-51b` başlatılmadı**, çünkü kendi kartı *"`BR-AST-51a` VE `BR-AST-52` kapanmadan
  başlamaz (Karar #39/K-1)"* diyor ve ölçüldü: ikisi de `Bekliyor`. Hızlı gitmek için bir
  kurul şartını atlamak, hızlı gitmek değildir.
- **`BR-SYS-97(b)` ve `BR-AST-53(b)` bu turda kapatılamaz** — biri **sunucu erişimi**, diğeri
  **kurul kararı** bekliyor. Kullanıcının emri gereği canlıdan onay alınmıyor; bu yüzden bu
  ikisi "yapılmadı" değil, **yetki dışı** olarak kaydedildi.
- Commit mesajına **"bu commit'te derleme/test koşturulmadı"** açıkça yazıldı: `BR-SEC-03/09`
  ajanı aynı ağaçta hâlâ çalışıyordu ve eşzamanlı `dotnet` koşusu ölçümü bozuyor.

## Ölçümler ve panoya yansıma

```
git push                      -> 1cbf7dfb (bekleyen 7348f5fc de gitti)
clickup-olustur.js            -> yeni: 7, atlanan: 406
clickup-senkron.js            -> fark olan kart: 7, yazilan: 7
clickup-senkron.js --kuru     -> fark olan kart: 0, izde olmayan: 0
```

Kart sayımı: **in progress 11 → 9** (ikisi hâlâ koşan ajanın), `karar bekleyen` 8,
`complete` 257.

## Açık kalanlar / sonraki adım

- Koşan üç ajan: `BR-SEC-03`+`BR-SEC-09`, `BR-SYS-70` (Ş35-1/5/13), `BR-QA-48` (A15
  doğrulaması). Bitince **tam doğrulama** (build + Architecture + Api.Tests + `tsc -b` +
  vitest + `deploy/db-kapilari-docker.sh`) tek ve **sessiz** ağaçta koşulacak.
- **`BR-BE-126` için kurul toplanacak** — tek soru: sessizlik alarmı mevcut `alarm.raised`
  boru hattına mı girecek, yoksa kendi yüzeyini mi alacak? Üçüncü tıkaç (`GET /alarms/active`
  yalnız Redis'ten besleniyor, sessizlik alarmı yalnız PostgreSQL'e yazıyor, **birleştirme
  yok**) kartta yazılı değildi ve seçeneklerden birini **tek başına vacuous** yapıyor.
- `BR-FE-77` inmeden `BR-DB-43` + `BR-BE-60` + `BR-BE-64` üçlüsünün tamamı depoda durur ve
  üretimde **hiç koşmaz**. Bu üç kart "Bitti" ama **özellik açık değil** — ikisi aynı şey
  değildir ve kart metinlerine böyle yazıldı.
