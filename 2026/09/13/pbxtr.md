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

---

# Üçüncü tur — Kurul Karar #47, BR-SEC-03/09, BR-QA-48 ve kendi commit'imde atladığım allowlist

## Bağlam

Üç ajan paralel koşarken kurul `BR-BE-126` için toplandı. Bu bölüm kararı, iki ajan raporunu ve
**kendi hatamı** kaydeder.

## Yapılanlar

### 1. Önce düzeltme: `1cbf7dfb`'de zorunlu iki dosyayı atlamışım

- **Ne oldu:** `BR-BE-64`'ü commit ederken `CrossTenantScopeSurfaces.cs` ve
  `RawSqlAllowlistTests.cs`'i **almadım**. Bunlar `CampaignSmsRunJob`'ın **zorunlu allowlist
  kayıtları**; onlarsız o commit'te mimari bekçiler **kırmızı**.
- **Sebep:** dosya seçimini elle yaparken, ajanın dokunduğu iki *test* dosyasını
  *"SEC ajanınındır"* diye ayırmışım. Oysa ikisinin diff'i de `BR-BE-64` diyor.
- **Ders:** `git add -A` yasağı doğru, ama **yol sayarken sahipliği diff'ten ölç**, klasör
  adından tahmin etme. Bir sonraki commit'te kapatıldı ve commit mesajına açıkça yazıldı.

### 2. Kurul Karar #47 — sessizlik alarmı: **ŞARTLI ONAY** (9 ŞARTLI / 1 HAYIR)

**Sonuç:** Sessizlik alarmı mevcut `alarm.raised` boru hattına **girer**, ayrı yüzey **açılmaz**;
**doğruluk kaynağı PostgreSQL**, birleşme **okuma tarafında**.

**Kurula verdiğim çerçevenin ÜÇ ÖNCÜLÜ oylama sırasında çürüdü** — karar düzeltilmiş olgulara
dayanıyor:

1. *"Ön yüzde `silence` geçen üretim dosyası yok"* **YANLIŞ**. `useRealtimeSilence.ts` var ve
   `WallboardScreen.tsx:218` çağırıyor. Ama o **başka bir sessizlik**: saniye ölçekli **WS
   bayatlığı** ("kanal ölü") vs dakika ölçekli **çağrı yokluğu** ("santral arızalı"). İkisi **zıt
   aksiyon** ister. Yanlış öncül, kurulun gerçek bir **ad çakışması riskini** hiç görmemesine
   sebep olacaktı.
2. *"Kenar tetikli yazım ↔ TTL çelişkisi"* teşhisi **yanlış yerdeydi**. `SilenceSamplerJob` PG'ye
   **her turda koşulsuz** yazıyor; kenar tetikli olan yalnız **log satırı**. Asimetri TTL'de değil,
   **kenarın neye karşı ölçüldüğünde**: kuyruk motoru Redis'e karşı hesapladığı için **kendini
   onarıyor**, sessizlik PG'ye karşı hesapladığı için onarmıyor.
3. *"`AlarmMetrics.All`'a eklemeden `metricText` yaz"* **bugün teknik olarak imkânsız** — union
   `generate-alarm-metrics.mjs` ile doğrudan `All`'dan üretiliyor (TS2353 / TS2741).

**Şeytan HAYIR verdi ve turun en değerli bulgusu ondan geldi:** `silence_thresholds` yüzeyi
**kurul onayı olmadan sevk edilmiş**; ADR-016 hâlâ *"TASLAK — kurul onayı bekliyor"* ve sevk
edilen koddan **daha dar** (kuyruk-only, yani Karar #36 / Ş-S2'yi ihlal ediyor). **Bu deponun
baskın deseni bu kez ters çıktı:** *karar yazılmış ama uygulanmamış* değil, **uygulama yazılmış
ama karar alınmamış.** Dokuz itirazın tamamı yazılı cevaplandı; Ş-1'in çıkarımı reddedildi (sevk
edilen şey ikinci bir *alarm yüzeyi* değil, bir *eşik yapılandırma ucu*).

**Kurulun ölçtüğü, kartta hiç yazılı olmayan dört kusur:**

- `IndexAddAsync` (`RedisLiveStateStore.cs:730-746`) bir Redis SET işlemi **değil** —
  oku-değiştir-yaz. Advisory lock işin kopyalarını serileştirir ama **AMI tüketicisine karşı
  serileştirmez** → kayıp güncelleme: alarm anahtarı **yaşarken indeksten düşer** ve ekran
  *"aktif alarm yok"* der.
- `#14`'ün Sustur düğmesi sessizlik kuralına **yabancı bir kimlik** POST'lardı
  (`RuleId` ≠ `silence_thresholds.id`).
- `cdr`'da `(tenant_id, queue_id, started_at)` indeksi **yok** ve `observed_since` aktiviteyle
  ilerlemiyor → maliyet **tam alarmın yanması gereken anda** zirve yapıyor.
- İş bugün **"kurulu ama silahsız"**: hiçbir tenant'ta tek bir eşik kuralı yok
  (`LogDebug` seviyesinde *"ölçecek bir şey yok"*), `mail_settings` **0 satır**.

**Saha tarafı iki cümleyle özetledi.** Agent: *"Ekranda görünen ama kimseyi uyandırmayan alarm
benim problemimi çözmez"* ve *"yanlış alarm, alarmı öldürür"*. Süpervizör: ***"Süresini
söyleyemediğim arıza, olmamış arızadır."***

### 3. `BR-SEC-03` / `BR-SEC-09` — dört madde kapandı, üçü başka ekibe

- **Ş37-8 (`PhoneSurfaces.System`):** şartın **lafzı** sadece *"taban `All`"* diyordu. Ölçüm: bu
  uçlar bugün **hiç yüzey bildirmiyor**, yani `IsLedger`'ın *"tanınmayan yüzey de kayıt
  defteridir"* dalındalar — fiilî davranış **"All, ve `phone.unmask` bile açamaz"**. Lafza uymak
  (kayıt defteri yapmadan tanımlamak) **adlandırma kisvesi altında bir gevşetme** olurdu. Kurul
  gevşetme kararı vermedi → mevcut davranış korundu, yüzey kararı artık **yazılı**, davranış farkı
  **sıfır**.
- **Ş37-12 zaten kapanmıştı — kart bayattı** (`CarriesDtmf`, DTO, ekran, 9 dil depoda duruyordu).
- **Katalog bekçisinde ölçülmüş boşluk:** mevcut iki bekçi de *"açıkça yazılmış küme"* üzerinden
  çalışıyordu; kataloğa **yeni** bir satır eklendiğinde otomatik olarak "dar yetkili" tarafına
  düşüyor ve **ikisi de yeşil kalıyordu**.
- **Beş mutasyon, hepsi iki yönlü.** M5 (seed'e `globalScopeOnly` yetki) **95 kırmızı** verdi ve
  gerçek kapının **testten önce** olduğunu gösterdi: `PermissionCatalog.Parse` açılış
  doğrulaması — böyle bir yetki tenant kapsamlı role konursa uygulama **hiç açılmıyor**.
- **Ajanın bir ölçümü yanlış evrendeydi ve düzeltildi:** *"Ş37-14 açık, `yerel-kapilar.sh`'te 0
  eşleşme"* dedi; kapı o dosyada **jeton olarak** değil, bir betiğe **devrederek** duruyor
  (`yerel-kapilar.sh:1087-1088` → `capture-topology-guard.py` + `DeployPrivilegeTests`).
  `BR-QA-34` doğru kapanmış; kart açılmadı.

### 4. `BR-QA-48` — A15 doğrulaması: dört şart yeşil, biri yarım, biri ölçülemedi

- Ölçüm `HEAD 1c995179`'da, **beklenen=koşan** doğrulamasıyla: Api.Tests **56/56**, mutasyonlu
  **23/26 (3 kırmızı)**, geri alınıp **yeniden derlenince 26/26**; Architecture **12/12**;
  Integration **1/1** (gerçek PG + RLS, `Skipped 0`).
- **Ş38-12 yarım ve sebebi karar metninin kendisi:** şartın *"`admin` 12 komutu korur"* cümlesi
  **yanlış** — seedden hesaplandı: superadmin **12/12**, admin **11/12** (AST-01 yok, çünkü admin
  `phone.unmask` taşımıyor). Ayrıca **rol → görünür komut kümesini çivileyen test yok**.
- **Yetki reddi 403 değil 404 dönüyor** (gerekçesi yazılı, envanter sızıntısı). Asıl boşluk
  denetimde: ret `system.command.requested`/`Forbidden` olarak yazılıyor, yani
  `AuditActions.PermissionDenied` ile filtreleyen bir güvenlik incelemesi bu denemeyi **hiç
  görmez** → `BR-BE-136`.
- **Ş38-15 ölçülemedi:** yerel `asterisk-lab`'ta üç komut da `No objects found` — **hiç PJSIP
  nesnesi yok**. *"0 nesne"* ile *"ölçemedim"* burada **aynı şey değil**: komut koştu, çıktı boş
  geldi. Şartı `BR-QA-48` içinde bırakmak kartı **kapatılamaz** yapar ve ölçülmüş üç şartı **rehin
  alır** → `BR-AST-77`.

## Kararlar

- **Karar #47 ŞARTLI ONAY**, 13 şart. `queue_silence_min` **`AlarmMetrics.All`'a eklenmez** —
  böylece Şeytan'ın korktuğu *"geri alınamaz `alarm_rules` satırları"* senaryosu **yapısal olarak
  imkânsız** hâle geldi.
- **CEO'nun "bildirim bacağı sprint-45'e ertelensin" şartı kabul edilmedi:** `cm-agent` ve
  `linux-uzmani` bağımsız olarak *"kimseyi uyandırmayan alarm alarm değildir"* dedi; erteleme
  kartı **çözmeden kapatır**.
- Kararın doğurduğu **her iş aynı gün kartlaştı** (CLAUDE.md §14). Kartsız bırakılan iş panoda
  hiç yoktur.

## Ölçümler ve panoya yansıma

```
git push                   -> 72d20a4b (+ eslesme commit'i)
clickup-olustur.js         -> yeni: 14, atlanan: 413
clickup-senkron.js --kuru  -> fark olan kart: 0, izde olmayan: 0
kart sayimi                -> complete 258 · in progress 9 · karar bekleyen 7 · to do 13 · backlog 140
```

## Açık kalanlar / sonraki adım

- **`BR-SYS-70` ajanı hâlâ koşuyor** (`deploy/nginx-*`, `pbxtr-demo/*` onun). Bitince **tam
  doğrulama** tek ve **sessiz** ağaçta koşacak — ve §1'deki allowlist düzeltmesi de **ilk kez o
  koşuda ölçülecek**.
- **İki commit de derleme/test koşturulmadan atıldı** ve bu commit mesajlarına **yazıldı**.
  Eşzamanlı `dotnet` koşusu ölçümü bozuyor; bu turda bunun bir örneği daha görüldü (ajanın ilk
  build'i başka ajanların `testhost`'ları yüzünden MSB3027 ile düştü, `--artifacts-path` ile
  kaçmaya çalışınca Architecture **178 kırmızı** verdi — sebep ürün değil, depo-kökü çözümünün
  ikili konumundan tırmanması).
- `BR-AST-51b` öncülleri (`51a`, `52`) hâlâ `Bekliyor`; `BR-SYS-97(b)` **sunucu erişimi**,
  `BR-AST-53(b)` **kurul kararı** bekliyor. Üçü de bu turda kapatılamaz.

---

# Dördüncü tur — BR-SYS-70, Karar #35 EKİ-3 ve tam doğrulama

## Bağlam

Son ajan (`BR-SYS-70`) bitti, ağaç sessizleşti ve **tam doğrulama** ilk kez tek başına koşabildi —
bu turun iki commit'i test koşturulmadan atılmıştı ve o eksik burada kapandı.

## Yapılanlar

### 1. `BR-SYS-70` kapandı — ve kurulun Ş35-1 metni **ikinci kez** çürüdü

- **Ne ölçüldü:** EKİ (2026-09-07) Ş35-1'i *"`.rev/` altına yazılır, `conf.d` ve `snippets` için
  **ayrı iki hedef dizin** kullanılır ve symlink çevrilir"* diye yeniden yazmıştı. **Bu hâl de
  çalışmıyor** ve sebebi tek-dosya mount'unun sebebiyle **aynı sınıftan**: bind mount kaynağı
  **açılırken** çözülür.
- **Gerçek Docker bind mount ile A/B, aynı symlink:**

  | Kurulum | `current` çevrildi | Konteynerin okuduğu |
  |---|---|---|
  | `mount --bind /x/current /y` — symlink'in **kendisi** | evet | **`A`** — swap **ULAŞMADI** |
  | `mount --bind /x /y` — **ebeveyn dizin** | evet | **`B`** — **ULAŞTI** |

- **Neden kritik:** kurulun yazdığı gibi yapılsaydı symlink çevirme **sessizce hiçbir şey
  yapmazdı** — `.rev` yazılır, symlink çevrilir, `nginx -t` **yeşil** yanar, reload koşar ve nginx
  **eski config'i servis etmeye devam ederdi**. Belirti *"yayın çalışmıyor"* değil, **"yayın
  çalışıyor gibi görünüyor"** olurdu.
- **Çözüm:** mount **ebeveyn dizin**, symlink **konteyner içinde** çözülür. Sıra: yaz → symlink
  çevir (`mv -T`, atomik) → **konteyner içi `readlink`** → `nginx -t` → kırmızıysa symlink geri
  alınır, **reload hiç koşmaz**. Ş35-2'nin sırası bu sunucuda uygulanamaz (kendi şartı olan gerçek
  konteynerdeki `nginx -t` yalnız `current`'ı okur) ama **koruduğu şey korunuyor**.
- **Yan ölçüm:** 2026-09-13'e kadar **yayın nginx config'ini sunucuya hiç göndermiyordu.**
- **Gerçek körlük, sayıyla:** `telefon-kanali-kontrol.sh` kanal **açıkken bile** *"8443 listen
  YOK"* diyordu (`nginx -T` → **1 eşleşme**, eski glob → **0**). Kaynak `nginx -T` yapıldı; boş
  dönerse artık *"yok"* değil **`RC=2` (ölçemedim)**.
- **`kapi_24` dokunulmadan önce zaten kırmızıydı** — demo profili **var olmayan bir düzeni**
  doğruluyordu.
- **Ş35-30 konusuz kaldı:** yeni düzende `.conf` ile biten bir yedek **çift server bloğu
  yükletmiyor** (`nginx -T` 0 eşleşme). Tarif edilen arıza **yapısal olarak yok**.
- **Telefon kanalı OPT-IN ve bu zorunluydu:** 8443 bloğu koşulsuz eklenseydi PKI olmadığı için
  `nginx -t` **her yayında kırmızı** yanar, Ş35-2 gereği hiçbir şey değişmez ve nginx taşıması
  **kalıcı olarak kilitlenirdi**.
- Kayıt: `Karar #35 EKİ-3`. **Canlıya hiç dokunulmadı** (ajan `ssh` yerine **çıkış 255 dönen sahte
  bir `ssh`** kullandı).

### 2. Tam doğrulama — sessiz ağaçta, `f2bd28dc`

```
dotnet build pbxtr.sln              -> 0 Warning, 0 Error (EXIT=0)
Architecture.Tests                  -> Failed 0, Passed  476, Skipped 0
Api.Tests ~Platform                 -> Failed 0, Passed 1188, Skipped 0
Api.Tests ~Live|Realtime|Telephony  -> Failed 0, Passed 1171, Skipped 0
yayin-nginx-kontrol.sh (kapi_40)    -> 20 iddia, 20 gecti, EXIT=0
nginx-dogrula.sh (kapi_24)          -> uretim + demo, EXIT=0
dash -n (alti betik)                -> hepsi OK
```

**Architecture'ın yeşil olması bu turun en önemli doğrulaması:** `1cbf7dfb`'de atladığım
`CrossTenantScopeSurfaces.cs` + `RawSqlAllowlistTests.cs` (yani `CampaignSmsRunJob`'ın **zorunlu**
allowlist kayıtları) artık **fiilen ölçüldü**.

### 3. Kendi ölçümümde "0 mı, ölçülemedi mi" tuzağına düştüm

- **Ne oldu:** Api.Tests'i üç filtreye böldüm; üçüncüsü (`Sms|Campaign|Messaging`) **hiçbir şey
  basmadı** ve komut yine **exit 0** verdi. Filtreyi kurarken `FullyQualifiedName~Pbxtr.Api.Tests.`
  önekini yanlış çoğalttım, yani filtre **hiçbir teste uymadı**.
- **Neden tehlikeli:** `grep`'im `No test matches` satırını da yakalamıyordu. Sonuç, "üç küme
  koştu, hepsi yeşil" gibi **okunabilirdi** — oysa üçüncü küme **hiç ölçülmemişti**. Bu, defterin
  en çok tekrarlayan kusuru: **`0` ile "ölçülemedi" aynı çıktıyı üretti.**
- **Düzeltme:** `--list-tests` ile toplam ölçüldü (**5019**), koşan kümeler sayıldı ve **kalan
  namespace'ler ayrı kümeler hâlinde** koşuldu. Kural: *koşan test sayısı beklenenle
  karşılaştırılmadan hiçbir koşu yeşil sayılmaz.*

## Kararlar

- **Ş35-1 ikinci kez yeniden yazıldı** (EKİ-3): mount **ebeveyn dizin**, symlink **konteyner
  içinde** çözülür.
- **Ş35-30 konusuz ilan edildi** (ölçümle), sunucudaki altı yedek dosyanın arşive alınması
  taşımanın **ön koşulu değil**, ayrı bir temizlik.
- `BR-SYS-99` açıldı: Ş35-4'ün WebSocket **101** ölçümü — yerelde ölçülemez, çünkü `/ws/`
  upgrade'ine cevabı veren şey nginx değil **arkadaki uygulamanın kimlik doğrulamasıdır**.

## Açık kalanlar / sonraki adım

- **Devreye alma şartı:** compose değişikliği için bakım penceresinde **tek seferlik**
  `docker compose up -d --force-recreate nginx` gerekir (Karar #35'te yazılı istisna). O yapılmadan
  `nginx_tasi` yayını **`exit` ile durdurur** — sessizce etkisiz kalmaz.
  `nginx-sunucu-sapma.sh` ve `compose-sunucu-sapma.sh` **ilk koşuda kırmızı yanacak ve bu
  doğrudur**: depo ileride, sunucu geride.
- **8443 artık compose'da yayınlanıyor.** Dışarıya açılması nftables ile `@asterisk_hosts`'a
  kısıtlıdır ve **o kural seti sunucuda yüklü değildir** (2026-08-18 ölçümü). Kanalı açan kişi
  firewall'u **aynı pencerede** yüklemek zorundadır.
- Kart numarası bu turda **ikinci kez çakıştı** (`BR-SYS-98` doluydu); çıkarıcı mükerrer kimlikte
  durdu ve kart `BR-SYS-99`'a alındı. *"Kart numarası önce ölçülür"* kuralı yazılı olmasına rağmen
  iki kez ısırdı — numara, metni yazmadan **önce** sorgulanmalı.

---

# Beşinci tur — tam doğrulama, `npm test`'in yayını durdurması ve kapıların gerçek evi

## Bağlam

Tüm ajanlar bitti, ağaç sessiz. Bu turun amacı tek şeydi: **iki commit'in test koşturulmadan
atılmış olması** eksiğini kapatmak. Kapatırken üç gerçek bulgu çıktı ve **ikisi benim
yazdığım kapı/testteydi**.

## Yapılanlar

### 1. Tam doğrulama

```
dotnet build pbxtr.sln            -> 0 Warning, 0 Error
Architecture.Tests                -> 476/476, Skipped 0
Api.Tests (4 kume)                -> 5019/5019  (--list-tests toplami: 5019 — BIREBIR)
tsc -b                            -> temiz
db-kapilari-docker.sh             -> TUM KAPILAR YESIL
vitest                            -> 1786/1786 test yesil, KOSU exit 1   (asagida)
yerel-kapilar.sh (gercek evinde)  -> 1 kapi kaldi                        (asagida)
```

`Architecture` yeşili bu turun en önemli doğrulaması: `1cbf7dfb`'de atladığım
`CrossTenantScopeSurfaces.cs` + `RawSqlAllowlistTests.cs` (yani `CampaignSmsRunJob`'ın **zorunlu**
allowlist kayıtları) artık **fiilen ölçüldü**.

**Kendi ölçümümde "0 mı, ölçülemedi mi" tuzağına düştüm:** Api.Tests'i üç filtreye bölmüştüm,
üçüncüsü **hiçbir teste uymadı** ve komut yine `exit 0` verdi; grep'im `No test matches` satırını
da yakalamıyordu. "Üç küme koştu, hepsi yeşil" diye okunabilirdi. `--list-tests` ile toplam
ölçülüp koşan sayılarla karşılaştırıldı.

### 2. `npm test` yayını durduruyor — ve sebebi bir test değil (`BR-QA-70`)

```
npx vitest run -> Test Files 191 passed · Tests 1786 passed · Errors 1 error · EXIT=1
Error: [vitest-worker]: Timeout calling "onTaskUpdate"
```

- **Kozmetik değil:** `deploy/yerel-yayin.sh:42` `set -euo pipefail`, `:414` `npm test` →
  **yayın tam bu satırda durur**, durma sebebi *"bir test kırmızı"* değil, **"kırmızının sahibi
  okunamaz"**.
- **Sebep izole edildi:** `src/Pbxtr.Web/src/test/viMockTargets.test.ts` içinde üç test
  **19,1 / 19,2 / 19,3 sn** (dosya 58,6 sn); `vitest.config.ts` `testTimeout: 20_000` → sınıra
  **~800 ms (%4)** kala.
- **Kontrol grubu:** dosya **tek başına** 13/13, `EXIT=0`. Hata yalnız **tam koşuda**.
- **İlk hipotezim ("paralel yük") ölçüldü ve çürüdü:** üç tam koşunun üçünde de tekrarladı, ikisi
  sessiz makinede. Düzeltmeyi ona dayandırsaydım **yanlış yeri tamir edecektim**.
- İkinci risk: bir ekran daha eklendiğinde `exit 1` yerine **gerçek kırmızı** gelecek ve sebebi
  *"bekçi bozuldu"* gibi görünecek.

### 3. Kapılar **gerçek evinde** koşturuldu — ve tablo tamamen değişti (`BR-QA-71`)

| Koşu | Kalan kapı |
|---|---|
| Windows host | **7** |
| konteyner, docker soketi **bağlanmadan** | **8** |
| konteyner, `yerel-yayin.sh`'ın kendi çağrısıyla | **1** |

Windows'taki 7'nin **beşi araç/ortam yokluğuydu** (`gitleaks` yok, `No module named 'yaml'`,
cp1252 `UnicodeEncodeError`, *"POSIX YOK … ölçemedi"*) — yani o kapılar **hiçbir şey ölçmedi**.
`deploy/yerel-kapilar.Dockerfile` bu dersi zaten **adıyla** yazıyor. İlk konteyner koşumda
**soketi ben bağlamadım** ve beş kapı yine ölçemedi; o çıktıyı da neredeyse "kırmızı" diye
raporlayacaktım.

**Düzeltme 1 — `kapi_49` ortama bağlı YANLIŞ KIRMIZI veriyordu (kendi kapım):**
`grep -v … | grep -q 'GOLGELEME/IMAJ'` — `grep -q` eşleşmeyi bulur bulmaz çıkıyor, üstteki
`grep -v` **SIGPIPE (141)** alıyor ve `pipefail` altında boru hattı **başarısız** sayılıyor.
Yani `staging-yayin.sh`'teki `exit 1` dalı **yerinde dururken** kapı *"YOK, kapı yine yalnızca
raporluyor"* diyordu. Zamanlamaya bağlı olduğu için **Windows'ta geçiyor, konteynerde
kalıyordu** — kapı ölçtüğü şeyi değil **koştuğu makineyi** ölçüyordu. `grep -c` + sayı
karşılaştırmasına çevrildi; **aynı dosyadaki diğer iki kontrol zaten öyleydi**, hata benim
onlarla tutarsız yazmamdı. Mutasyon iki yönlü, geri alma `git diff` boş.

**Düzeltme 2 — `clickup-durum.test.js` canlı bir kartı çıpa yapıyordu:**
`rows.find(r => r.id === 'BR-BE-64').durum` → o kartı bugün kapattım, test kırmızı yandı. Oysa
eşlemede hiçbir şey bozulmamıştı: kırmızı bir kusuru değil, bir **fikstür tercihini**
gösteriyordu — canlı veri çıpa yapılırsa test, ölçmesi gereken **kuralla** birlikte ölçmemesi
gereken **iş durumuna** da bağlanır ve iş ilerledikçe kendiliğinden kırılır. Çıpa
sentetikleştirildi, canlı envanterden yalnız **biçimsel** bir şey (en az 3 kova) doğrulanır.

### 4. Kalan tek gerçek kapı bulgusu — `BR-DB-48` (kurula)

`20260913120000_CallDataRetentionPartitionBatch` normal deploy'da **reddediliyor** (DROP/ALTER
deseni + **ham SQL fail-closed**). Kapının öz-testi **OK**, yani bulgu gerçek.

**Neden görülmedi:** `BR-DB-42` turunda *"db kapıları EXIT=0"* raporlandı — ama o
`db-kapilari-docker.sh`'tır, **başka bir kapı**; `kapi_07` o turda **hiç koşmadı**. İki kapının
adı birbirine benziyor ve biri diğerinin yerine sayıldı.

**Kapsam ölçüldü:** ledger dışı **dört** migration var ve **yalnız bu** düşüyor (benim
`20260913150000`'im dahil diğerleri geçiyor). **Ledger bir kaçış yolu değil:** dosyanın kendi
başlığı *"yeni migration'lar listeye eklenmez … bir satırı değiştirmek kurul/maintenance
kararıdır"* diyor. **Karar alınmadan ledger'a dokunulmadı.**

## Kararlar

- Yanlış kırmızı, yanlış yeşil kadar zararlıdır: sahibi *"kapı bozuk"* deyip devre dışı bırakmaya
  yönelir. `kapi_49` düzeltilirken kapının **ölçüm gücü** korundu (mutasyon iki yönlü).
- `BR-DB-48` **kurula gidiyor**; üç seçenek yazıldı (bakım penceresi · ham SQL istisnasının
  fonksiyon yeniden-tanımı için dar genişletilmesi · migration'ın bölünmesi) ve hangisi seçilirse
  seçilsin kapının **gerçek** bir contract değişikliğini hâlâ yakaladığı mutasyonla gösterilecek.

## Açık kalanlar / sonraki adım

- `BR-QA-70` (vitest `exit 1`) ve `BR-DB-48` (kurul) inmeden **yayın koşamaz**.
- `BR-QA-71`: kapıların yalnız konteynerde koşması **yazılı** hale gelmeli — bugün
  `yerel-yayin.sh` doğru yapıyor ama elle `bash deploy/yerel-kapilar.sh` diyen biri **sessizce
  eksik ölçüyor** ve çıktı *kırmızı gibi* görünüyor. Ayrıca `grep -q` + `pipefail` deseni depoda
  **taranmalı**; aynı sınıf başka kapılarda da olabilir.

---

# Altıncı tur — paralel kartlar, sunucudaki gerçek Asterisk ve canlıda 20 satırlık kaza + kurtarma

## Bağlam

Kullanıcı: *"maddeleri paralelde yapamaz mısın hızlıca"*. Beş ajan paralel koştu; süreç
yarıda çıktı ve üçü yarım kaldı. Tur ortasında kullanıcı ikinci bir düzeltme verdi:
*"asterisk sunucuda var. neden localdeki dockere asterisk kurma ihtiyacı ediniyorsun, config
için oradan yap"* — önceki *"canlıdan onay alma"* talimatını ben **"canlıya dokunma"** diye
okumuştum. Yanlış okumaydı; hafızaya yazıldı (`asterisk-olcumu-sunucuda-yapilir`).

## Yapılanlar

### 1. `BR-QA-70` — `npm test` EXIT=0 (`aeb54b11`)
- **Neden:** `viMockTargets.test.ts` üç testi 19,x sn (sınır 20 sn) → tam koşuda `Errors 1`, yayın `npm test` satırında duruyordu.
- **Ne yapıldı:** `mockGraph.ts` saf fonksiyonları bellekli; her giriş **kaynak metnini** saklayıp `===` ile doğruluyor (aksi hâlde vacuity testleri körleşir). `GRAPH_GATE_TIMEOUT_MS = 120_000` muafiyeti kaldırıldı.
- **Sonuç:** dosya 37,25 sn → 0,52 sn; `vitest` 1787 passed, Errors satırı yok, EXIT=0.
- **Ders:** ajanın kendi eklediği doğrulama ilk mutasyonda **hiçbir testi kırmızı yapmadı** → yeni test yazıldı, sonra kırmızı görüldü.

### 2. `BR-FE-77` bloke → `BR-FE-80` açıldı
- Kartın öncülü yanlıştı: üç alanın **HTTP sözleşmesi sıfırdı** (`src/Pbxtr.Api` taraması 0). "#09 SMS Şablonları" diye ekran yok (#09 = Agent Çalışma Merkezi). Sözleşme işi `BR-BE-130`'a eklendi.

### 3. Yarım kalan ajanlar ve NUL dosyası
- Süreç çıkışında `SilenceSamplerJob.cs` silinmiş, yerinde **23 137 baytı tamamen NUL** `dHYiSr5g` kalmıştı (yarım atomik yazma). HEAD'den geri yüklendi, NUL dosyası silindi, `src/**/*.cs` NUL taraması (tek eşleşme `PermissionRequirement.DenyAll` — commit'li, bilinçli `"\0deny-all"`).
- Üç ajan `SendMessage` ile devam ettirildi.

### 4. `BR-DB-47` — iki kısmi indeks (`625c1d1d`)
- `ix_cdr_tenant_queue_started_inbound` → 14,772 ms / 82 888 buffer → **0,175 ms / 12 buffer** (394 508 cdr, `pbxtr_app` + RLS).
- `ix_silence_observations_tenant_alarm` → 1,576 ms → 0,105 ms.
- İlk fikstür geçersizdi (kuyruk sessiz değildi); yeniden ölçüldü.
- `observed_since` yön mutasyonu ilk hâlde **5/5 yeşil** → saklanan kolonu okuyan test eklendi → 1 kırmızı → 6/6.
- Yeni kart `BR-DB-49` (DID/zil grubu dalı indekssiz, hiç koşmamış).

### 5. `BR-BE-132` — `/alarms/active` PG+Redis okuma birleşimi (`17af452a`)
- Gerçek PG, EF'in çeviremediği bir sorguyu yakaladı (sahte testler görmedi).
- **Bilinçli sözleşme değişikliği:** 503 yalnız iki kaynak birden düşükken.
- Mutasyon 6/6 kırmızı. **Temiz worktree'de commit tek başına:** build 0/0, Architecture 479/479, Api `Live|Alarm|Silence` 299/299.

### 6. `DeployPrivilegeTests` makineye bağlı kırmızı (`a223ec4c`)
- Kapı betiklerini yerelde koşturmak `deploy/__pycache__/*.pyc` üretiyor (gitignore'da); bekçi diski taradığı için derlenmiş dize sabitlerini ayrıcalık artışı saydı.
- `__pycache__` muafiyeti; mutasyon: klasör `__pycachX__` → kırmızı, geri → 28/28.

### 7. `BR-BE-130` — SMS sözleşmesi + trigger doğrulaması (`8eaec04b`)
- Öncül yanlıştı: işaretçiyi yazan **hiçbir uç yoktu**. Sözleşme indi (alan adları kartta).
- NULL trigger reddedilir (bugün her şablon NULL; kabul edilseydi hepsi otomatik gönderime uygun olurdu).
- Mutasyon → 14 testten tam 5 kırmızı. Ajan 13 dosyaya BOM eklemişti, geri alındı.
- Temiz worktree: Architecture 479/479, Api `Sms|Campaign|TenantSettings|Live|Alarm` 655/655.
- `BR-QA-72` açıldı (gerçek PG testi yok).

### 8. Sunucudaki gerçek Asterisk'te ölçüm (`30c5e23b`)
- **Erişim:** `root@176.88.41.220`, Asterisk 22.10.1 `pbxtr-asterisk` konteynerinde.
- `BR-AST-77` **Bitti:** `pjsip show contacts` rakam dizisini açık basıyor (2/2).
- `BR-AST-72` Kısmen: ARI açık; `unknown` 10 hâlde hiç üretilmedi; statik contact `online` görünüyor.
- `BR-AST-55` Kısmen: RNA **anında** ve retry periyoduyla doğuyor (20 sn'de 10); `state_interface`/`hint:` → 0. Canlıda tek çağrıdan 42 haksız RNA.
- `BR-AST-74`: DND'nin PJSIP'te çalışma-anı karşılığı yok; `DNDState` **chan_dahdi** olayı (kart düzeltildi).
- `BR-SEC-17`: trunk yok → "açık değil" denemez.
- **Yeni kartlar:** `BR-AST-78` (P0 — tek çağrının olayları farklı tenant'lara bölünüyor), `BR-AST-79`, `BR-SYS-100` (confd pjsip teslim etmiyor, günde ~860 koşulsuz reload), `BR-OPS-05` (canlı imaj 2026-09-08).
- Ajan test nesnelerini `t9001` önekiyle kurdu, yedekledi, sildi, geri dönüşü ölçtü.

### 9. KAZA: canlı `call_events`'ten 22 yerine 42 satır silindi — ve 20'si geri alındı
- **Neden silme:** ölçüm çağrısının 22 `Newchannel` satırı t0007 adına yazılmıştı (`BR-AST-78`'in kanıtı).
- **Hata:** `DELETE ... WHERE ctid IN (select ctid ...)` — `call_events` **bölümlü**, `ctid` yalnız bölüm içinde tekil. Guard **seçim** sayısına konmuştu (22), silinen sayıya değil → `DELETE 42`. `call_events_2026_08` blok 0'daki 20 gerçek satır da gitti. WAL arşivi yok (`archive_mode=off`).
- **Kurtarma:**
  1. Beş bölümde `autovacuum_enabled=false`.
  2. `pageinspect`: silen xid **244617** → `_09`'da 22 (test), `_08`'de 20 (blok 0, lp 1–20).
  3. Güvenlik yedeği için `pg_dump` alındı — **bu sıralı tarama fırsatçı budamayı tetikledi**, satır işaretçileri `LP_DEAD` / uzunluk 0 oldu.
  4. Blokta canlı tuple olmadığı için baytlar boş alanda duruyordu: `get_raw_page` hex'i indirildi, tuple'lar `t_xmax=244617` + `t_ctid=(0,lp)` ile bulundu (20/20), `xmin=2`, `xmax=0`, `XMIN_COMMITTED|XMAX_INVALID` yapılarak yeni sayfa kuruldu (`scratchpad/sayfa_kur.py`).
  5. Yerel `postgres:16-alpine`'de aynı şemalı tablonun dosyasına yazıldı (sunucu durdurulup `docker cp`), Postgres `jsonb` dahil çözdü.
  6. `jsonb_to_recordset` ile canlıya geri yazıldı: guard "zaten var" + eklenen = 20 + payload dahil geri okuma = 20 → **59 → 79**.
  7. autovacuum `reset`, `pageinspect` drop, yerel konteyner silindi.
- **Kurtarılan satırlar:** 19'u tenant `1111…` 2026-08-29 simülasyon kuyruk olayları, 1'i 2026-08-30 `Newchannel`.
- **Hafıza:** `bolumlu-tabloda-ctid-tekil-degil`.

## Kararlar
- Asterisk ölçümü ve config işi sunucudaki gerçek santralde yapılır; onay sorulmaz. §3 sınırları aynen geçerli.
- Canlıda silme: bölümlü mü bak, guard `returning` sayısına, yedek **silmeden önce**.
- Paralel ajanlarla ortak ağaçta commit, **temiz worktree'de tek başına** doğrulanıp push'lanır.

## Açık kalanlar / sonraki adım
- Koşan ajanlar: `BR-AST-78` (P0), `BR-SYS-100` (a) confd debounce + sunucuya kurulum, `BR-QA-72`, `BR-DB-49`.
- `BR-OPS-05`: canlı imaj eski → yayın; engel `BR-DB-48` (kurul).
- Kurul bekleyen: `BR-DB-48`, `BR-FE-80`, `BR-AST-74`, `BR-AST-55` (`joinempty=no` etkileşimi).
- Sunucuda kalan: `/root/olcum-20260913/` (yedek tgz, `call_events` dump — chmod 600).

### 10. Sunucu bulgularından doğan dört kart paralel kapandı

**`BR-QA-72` (`86f832f9`) — SMS şablon kapısı gerçek PG'de**
- `SmsTemplateBindingTenantLeakTests`, `PBXTR_REQUIRE_DOCKER_TESTS=1` ile koştu; 18/18.
- **Bulgu:** `.IgnoreQueryFilters()` mutasyonu **2/2 yeşil** kaldı. Bu yolu bugün yalnız RLS koruyor.
- `sms_templates_tenant` politikasında çapraz-tenant dalı yok. Bu yüzden EF filtresinin katkısı tek bir mutasyonla ölçülemiyor.
- İkinci mutasyon (`IsActive` koşulu kaldırıldı) kırmızı yandı. Bu, koşunun yeni DLL'i kullandığını kanıtlıyor.

**`BR-DB-49` (`e19340ff`) — DID / zil grubu dalının indeksi**
- Kartın öncülü kısmen yanlıştı: numara indeksi vardı, ama `started_at` taşımıyordu.
- Yeni indeks `ix_cdr_tenant_called_started_inbound`: 9,258 ms → 0,138 ms.
- İlk hâliyle test dalı hiç koşturmuyordu (`GapTolerance`); düzeltildi. Numara koşulu mutasyonu 2 kırmızı verdi.
- **Canlı ölçüm (salt-okuma):** `dids` 0, `ring_groups` 0, `silence_thresholds` tablosu **yok**. Canlı DB sessizlik migration'larından önce kalmış.

**`BR-SYS-100` (a) (`b5d6a43f`) — confd reload disiplini, canlıya kuruldu**
- Tür bazında sha256 ve yükleme defteri eklendi.
- Canlıda aynı içerikle **0 reload**; tek bir türün defter satırı silinince yalnız o türün reload'u koştu. Önce günde ~846 reload vardı.
- Sunucudaki betik depodan 3 commit gerideydi.
- `kapi_50` gate konteynerinde 13/13 geçti.
- **Düzeltme:** `Last reload` damgası `dialplan reload` ve `queue reload all` komutlarını görmüyor. Kanıt olarak santral logu kullanıldı.

**`BR-AST-78` (a) (`fb4f851e`) — tenant çelişkisi**
- **Teşhis:** `AmiTenantCode.Resolve` değişken yoksa ikincil kaynağı sorgusuz kabul ediyor; linkedid belleği yok.
- **Çözüm:** `AmiTenantConsistencyGuard` hem çerçeve içi hem linkedid içi çelişkiyi yakalıyor. Çelişkide olay yazılmıyor, 4803 alarmı basılıyor ve linkedid karantinaya alınıyor.
- Test vakasında kayıtlı `t0012` seçildi; kayıtsız bir kod kontrol olmadan da düşerdi ve test hiçbir şey ölçmezdi.
- **Temiz worktree ölçümü:** Architecture 479/479, Api Telephony 947/947, Integration 10/10.
- **Mutasyon:** 8/14 + 2/3 kırmızı; linkedid dalı ayrıca 5/14 + 1/3.
- **Yeni kart `BR-AST-80`:** ilk olay yalnız context ile yazıldıktan sonra gelen geç çelişki. O satır geri alınmıyor.

## Açık kalanlar (tur sonu)
- **Yayın engeli:** yeni kodların hiçbiri canlıda değil (`BR-OPS-05`). Önündeki tek engel `BR-DB-48` (migration kapısı), kurula gidiyor.
- **Kurul bekleyenler:** `BR-DB-48`, `BR-FE-80`, `BR-AST-74`, `BR-AST-55` (`joinempty`), `BR-AST-80`.

### 11. Kurul Karar #49–#54 — altı açık kararın toplu oylaması (`917c11e1`)
- **Neden:** Kullanıcı kararları kullanıcıya değil kurula göndermemi istiyor. Karar bekleyen altı kart iş listesini tıkıyordu.
- **Ne yapıldı:**
  - Gündem dosyası yazıldı.
  - 10 üye paralel oyladı. Her üye kart metnini ve kaynağı kendisi okudu.
  - Kararlar `yonetim/kurul-kararlari.md` dosyasına eklendi.
  - Altı kartın durumu `Kurul: (ŞARTLI) ONAY` olarak güncellendi. 8 yeni kart açıldı.
- **Sonuçlar:**
  - **#49 `BR-AST-49`:** t0012 bugün pinlenmiyor.
    - Gerekçe: canlı unit `pbxtr-confd-cek.sh`, tek tenantlık `/bundle` ucunu kullanıyor. PJSIP de teslim edilmiyor. Pin yapılırsa `Queue()` üyeleri `NOT_INUSE` görünür ve çağrı sessizce boşa çalar.
    - Niyet DB kolonunda tutulacak. Susturma koşulu: niyet var **VE** pinli anahtar yok.
  - **#50 `BR-AST-74`:** Kısa vadede DND kaynağı teslim gözlemi olacak (`null` disiplini).
    - Hedef yol ARI `deviceStates`. Önce santralde ölçülecek (`BR-AST-81`).
    - `DBPut` yolu reddedildi, çünkü `system` sınıfını istiyor.
  - **#51 `BR-SEC-08`:** İlke: "global roller platformu yönetir, tenant'ı işletmez."
    - Admin rolüne de uygulanıyor, ama Ş36-31 impersonation ölçümü yapılmadan tek bir yetki bile kaldırılmayacak.
    - Şeytan bunun kullanıcı kararını yeniden açmak olduğunu söyleyerek itiraz etti. Cevabı karar kaydına yazıldı.
  - **#52 `BR-FE-80`:** 55. ekran açılmıyor. SMS şablonları #49 Ayarlar ekranının SMS bölümüne giriyor. `campaign.write` için dar bir seçici ucu eklenecek.
  - **#53 `BR-AST-40`:** Kısıt yalnız `/node-bundle` kipinde daraltılıyor.
    - Kartın "canlı `Have` göndermiyor" öncülü bu akşamki kurulumla bayatlamıştı.
  - **#54 `BR-BE-115`:** Seçenek (c). Her revizyonun bir denetim satırıyla eşleştiği testle kanıtlanacak.
- **Yeni kartlar:**
  - `BR-SYS-101` — canlı unit sapması
  - `BR-AST-81`, `BR-AST-82`
  - `BR-DB-51`
  - `BR-DB-52` — retention 30 sn sınırları ile 50 sn bütçesi çelişiyor
  - `BR-QA-76` — `TelephonyEventPipelineTests` kalıntı bırakıyor
  - `BR-QA-77` — iki fikstürde secretRef sabit kalmış
  - `BR-OPS-07` — compose ↔ nginx yerleşimi
- **Doğrulama:** ClickUp senkronu `fark olan kart: 0, izde olmayan: 0` verdi. `kalan-isler.md` yeniden üretildi (452 kart).
- **Ders:** Kurul oylaması, kartın öncülünü kaynakla yeniden ölçen tek adım oldu. Altı maddenin ikisinde gündem metni bayattı.

### 12. Canlı yayın — `tekbirsoft/pbxtr:demo-5ac884c7533b` (Karar #48 uygulandı, `3faa18b8`)

**Neden:** Bugünkü kodların hiçbiri canlıda değildi (`BR-OPS-05`). Canlı imaj 2026-09-08 tarihliydi.

**Yayın #6 kapıları (`scratchpad/yayin48/yayin6.log`):**
- 1/7 kapılar geçti.
- 2/7 backend geçti: format, Architecture ve Integration.
- 3/7 frontend geçti.
- 4/7 API shard'ları geçti: 1267/1267, 1267/1267, 1266/1266.
- 5/7 DB kapıları geçti.
- 6/7 imaj üretildi ve push edildi.

**Ş48-7 yayın öncesi kontroller (23:23 TR):**
- aktif kanal 0
- kuyrukta bekleyen 0 (W:0)
- kampanya 0
- aktif sorgu 0
- retention kapalı
- disk %19

**7/7'de durdu:** `nginx: konteynerde /etc/nginx/pbxtr YOK -- YENI MOUNT DUZENI KURULU DEGIL`.
- Betik uygulamayı eski imaja geri aldı.
- **Migration geri alınmadı.** Eski imaj yeni şemayla healthy kaldı (`/health` 200).
- Bu, `BR-OPS-07` kartında yazılı olan sapmanın ta kendisiydi.

**`BR-OPS-07` geçişi (sunucuda `/root/nginx-duzen-gecis.sh`):**
- **Ölçüm:** depo compose'u ile sunucu compose'u arasındaki tek fark, nginx bloğu ve 8443 portuydu.
- **Adımlar:**
  1. Yedek alındı: `docker-compose.yml.yedek-20260913T202725Z` ve `/root/nginx-dizin-yedek-…tgz`.
  2. `nginx/bootstrap`, `.rev/<ts>-gecis` ve `current` symlink'i kuruldu (`mv -T`).
  3. Geçici konteynerde, aynı ağ ve yeni mount'larla `nginx -t` koşuldu: **yeşil**.
  4. Compose kopyalandı.
  5. `docker compose up -d --force-recreate nginx` koşuldu.
  6. Kontroller: konteyner içinde `current/conf.d` var, `nginx -t` yeşil, `/health` 200, SPA 200.
- Kırmızı olsaydı otomatik geri alma devreye girecekti; gerekmedi.

**7/7 yeniden koşuldu:**
- **Neden tüm hat baştan koşulmadı:** `git diff 5ac884c7 HEAD -- src tests deploy pbxtr-demo` boş, sonraki commit'ler yalnız `doc/` ve `yonetim/`.
- Aynı imaj ve aynı argümanlarla doğrudan sunucuda koşuldu:
  ```bash
  ssh root@176.88.41.220 "PBXTR_DAGITICI_SHA=… PBXTR_DOGRULAYICI_SHA=… PBXTR_SANTRAL_IMAJ='' PBXTR_SANTRAL_ZORLA=0 PBXTR_CONFD_KUR=0 /root/staging-yayin.sh 5ac884c7533b"
  ```
- Sonuç `STAGING_EXIT=0`. nginx revizyonla reload edildi, konteyner yeniden yaratılmadı.

**Ş48-8 yayın sonrası ölçümler:**
- migration 176, son migration `20260913161315`
- `silence_thresholds` ve `silence_observations` tabloları var
- `sms_templates.trigger` kolonu var
- `purge_call_data` prosrc md5 = `298567d8…`; tüm `pbxtr_sys` fonksiyonlarında beklentiden fark 0
- bekçi assert 27/27
- AMI bağlandı, ARI Stasis açık
- WS 101 döndü, gerçek istemci yeniden bağlandı
- son 10 dakikada exception 0
- sessizlik, SMS ve wallboard uçları 200
- nginx ve compose sapma kapıları **bayraksız** yeşil

**Ölçülemeyenler:**
- `ruleSource` gözlenemedi: aktif alarm 0 olduğu için kontrol vacuous.
- #14 VERİ EKSİK smoke koşulmadı.
- Ş48-9 koşulmadı: retention kapalı ve 30 sn sınırları var. Kontrol `BR-DB-52`'ye devredildi.
- `smoke.sh` yanlış porta (5080) bağlandığı için 62 kontrol "token yok" diye KALDI. Bu bir ölçüm değildir.

### 13. `BR-BE-138` (P0) — üretimde sessizlik alarmı hiç yanmıyordu (`558cfaac`)

**Bulgu:** ADR-016 hizalamasında (`BR-AST-76`, `ca37fb6c`) çıktı, canlı log ile doğrulandı.
- Konak tick'i 5 dakika (`tick=00:05:00`).
- Örnekleyici boşluk toleransı 180 sn.
- Her tur boşluk sayılıyor, ölçüm `null` dönüyor ve alarm yanmıyor.

**Düzeltme:**
- Tolerans formülü: `max(180 sn, 2,5 × TickInterval)`; üretimde 750 sn.
- Canlıda ölçülen en büyük tur aralığı 728,7 sn; yeni tolerans bunu kapsıyor.
- Olay akışı toleransı 180 sn olarak kaldı. Onu yazan `QueueMetricDeriver`'in kendi 60 sn'lik döngüsü.

**Doğrulama:**
- birim testler 8/8
- gerçek PG testleri 10/10, 5 dk tick ile iki yeni test dahil
- **mutasyon** (toleransı eski sabite çekmek) 2 testi kırmızıya çevirdi; geri alınınca 10/10
- Architecture 479/479
- Api Platform + Live 1350/1350
- kapılar 52/52

### 14. `BR-QA-75` — kapılarda grep çıkış 2 artık "temiz" sayılmıyor (`447ca902`)
- 15 çağrı noktası düzeltildi.
- Yeni `kapi_52` öz-testi eklendi; mutasyon 9/9 kırmızı.
- **Kartın teşhisi yanlıştı:** `kapi_25` CRLF kontrolü `head -c 2` ile yalnız `#!` karakterlerine bakıyordu, yani hiç tetiklenemiyordu.
- `saglayici-sirri-kontrol.sh`: sahnelenip diskten silinmiş sır dosyasında "sır YOK" deyip çıkış 0 veriyordu.

### 15. `BR-DOC-14` — ADR-005 kilit kuralı 2a/2b (`696ffbf1`), db-lider onayı
- **2a:** liderlik kilidi yalnız `try_` ile alınır.
- **2b:** serileştirme kilidi bloklayan kilitle alınır ve Ş1–Ş9 şartlarına tabidir.
- Açılan kartlar: `BR-BE-137` (`lock_timeout` üç yerde yok) ve `BR-BE-142` (lider transaction açıkken ikinci bağlantı).

### 16. Yayın #7 ilk denemesi — iki yanlış kırmızı
1. **confd sapma kapısı:** Bilinen `BR-SYS-101` sapması. Karar #53 gereği `/node-bundle` daraltması inmeden bu geçiş yapılmaz. Kapı `PBXTR_CONFD_SAPMA=0` ile, izli olarak atlandı.
2. **`capture-topology-guard` (BR-QA-34):** Paralel ajan worktree'leri `.claude/worktrees/` altına compose kopyası bırakınca compose envanteri değişmiş sayıldı.
   - `.claude` hariç tutuldu (`d10369e4`).
   - Öz-test 16/16.
   - Negatif kontrol: depo içindeki yeni compose dosyası hâlâ yakalanıyor.
   - **Ders:** Worktree izolasyonu depo ağacının içinde yaşar. Dizin yürüyen her kapı onu da görür.
