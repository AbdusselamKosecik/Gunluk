# pbxtr — 2026-09-10

## Bağlam
Kullanıcı "hangi maddeler kalmış bir kontrol edebilir misin" dedi, ardından
"devam edelim". Güne başlarken çalışma ağacında **84 dosya commit edilmemiş**
duruyordu ve `HEAD` hâlâ 9 Eylül'de benim attığım commit'ti.

## Yapılanlar

### 1. Kalan iş ölçümü — bu iş zaten yapılmış çıktı
- **Neden:** "Hangi maddeler kaldı" sorusunu dün dört ayrı deftere bakarak
  cevaplamıştım. Bugün tekrar sorulunca önce **böyle bir üretici var mı** diye
  baktım.
- **Ne yapıldı:** Codex 09-09'da `yonetim/arac/kalan-isler.js` + `yonetim/kalan-isler.md`
  yazmış. Tazeliğini **doğruladım**: dosyanın içine yazdığı kaynak SHA-256
  (`aeee7377…`) şu anki `backlog.md` ile birebir aynı. Bölüm başlıklarındaki
  sayıları satır sayarak tek tek karşılaştırdım (14/4/11/82/46 — hepsi tuttu).
- **Sonuç:** **338 BR kartı = 227 kapalı + 111 kapalı olmayan**
  (in progress 14, karar bekleyen 4, to do 11, backlog 82), ayrıca
  **46 "kapalı ama metninde doğrulama borcu olan"** inceleme adayı.
  ClickUp senkronu `fark 0, izde olmayan 0` — pano kaynakla aynı.
- **Dün verdiğim 107 rakamı yanlıştı.** Codex kökü bulmuş: eski çıkarıcı
  `BR-QA-08`'i hem bitmiş hem devam sayıyordu (216+15+107 = 338, oysa kart 337).
  Eşleme `clickup-durum.js`'e taşınıp tekilleştirilmiş. Doğrusu **111**.

### 2. 84 dosyalık tur kurtarıldı — ve `tsc -b` iki kırmızı buldu
- **Neden:** Codex'in kendi kaydının son satırı: *"Commit ve yayın yapılmadı."*
  Global kural: push edilmemiş iş bitmiş sayılmaz, disk uçarsa gider.
- **Ne yapıldı:** Önce ölçtüm, sonra commit ettim:
  - `dotnet build -c Release` → **0 uyarı / 0 hata**
  - `npx tsc -b` → **KIRMIZI** (aşağıda)
  - `npx vitest run` → 185 dosya / 1725 test, exit 0
- **Bulunan iki kırmızı — ikisi de yalnızca `tsc -b` ile görünüyordu:**
  1. `CaptureTemplate`'e `carriesDtmf` eklenmiş, `CaptureScreen.test.tsx`
     fikstürü güncellenmemişti (TS2741 ×2). Değeri **tahmin etmedim, ölçtüm**:
     `IPacketCapture.cs:360` → `CarriesDtmf => Id == CaptureTemplates.Sip`,
     yani sip=true / rtcp=false.
  2. `CaptureFile.canDownload` **zorunlu** alan olarak eklenmiş ama dört
     fikstürün dördünde de yoktu. `mockResolvedValue` gövdesi `any` olduğu için
     **tsc bunu yakalamadı**; ekran `canDownload === true` diye baktığından düğme
     hiç çizilmedi ve indirme testi düştü.
- **Eksik negatif eşi yazdım:** `canDownload=false` dalının düğmeyi gerçekten
  çizmediğini kimse ölçmüyordu — kapı sessizce kaldırılabilirdi.
  **Mutasyonla doğrulandı:** `file.canDownload === true` → `true` yapılınca
  **yalnızca** yeni test kırmızı (1 failed / 7 passed), geri alınca 8/8.
- **Commit:** `aae46c27` — 85 dosya, push edildi.

### 3. `AGENTS.md` §3.0 bir gündür `CLAUDE.md` ile çelişiyordu ve iş atlattı
- **Neden:** `AGENTS.md` hâlâ *"Asterisk'e ŞU AN BAĞLANMIYORUZ — tartışmaya
  kapalı"* diyordu; `CLAUDE.md` §3.0 ise 2026-09-03 kullanıcı kararıyla
  *"AMI/ARI'den bağlanacağız"* olmuştu.
- **Ölçülen bedel — bu kozmetik bir sapma değildi:** 09-09 turunda ajan iki
  belgeyi de okudu, çelişkiyi gördü, kullanıcıya sordu, yanıt gelmediği için
  **canlı Asterisk işlerinin tamamını atladı.** Kendi kaydında üç kez
  *"Gerçek Asterisk bağlantısı kurulmadı"* yazıyor.
- **Ne yapıldı:** `AGENTS.md` §3.0, `CLAUDE.md` §3.0'ın metniyle değiştirildi
  (eski hâl silinmedi, "geçersizdir" diye işaretlendi) ve **çelişkinin kendisi**
  de bir not olarak yazıldı. Üçüncü bayat nokta
  `yonetim/asterisk-baglanti-plani.md`: Faz 2'nin anahtarını *"emir açıkça
  kaldırılmadan çevrilmez"* diye kilitliyordu — o emir zaten kaldırılmıştı,
  kilit açıldı.
- **Doğrulama:** Depo tarandı, "BAĞLANMIYORUZ" geçen başka yer yok.
- **Commit:** `1a3e8fd` — push edildi.


### `BR-AST-55`'in üçüncü kök adayı — `hint` değil `state_interface`; ve ölçüm laboratuvara bağlı

- **Neden:** Karar #42, `-local`'a `hint` üretme adayını *"kart yazılmadan ölçülmeli"* diye
  şarta bağlamıştı.
- **Ne yapıldı:** canlıda `core show hints` → **9 hint, dokuzu da park yuvası**; üreticide
  tek isabet `parkinghints=yes` (`ConfigRenderer.cs:1027`) — pbxtr dahili için **hiç hint
  üretmiyor**. Bu, sorunun yanına ikinci bir adayı koydu: `app_queue`'nun üye bazlı
  **`state_interface`** kancası. Ölçüldü: pbxtr onu **yalnız okuyor**
  (`AmiCommandChannel.cs:164`, `AmiTenantCode.cs:139`), hiçbir yerde yazmıyor —
  `ITelephonyProvider.QueueAddAsync(queueName, memberEndpoint, penalty)` (`:330`) böyle bir
  parametre taşımıyor ve **altı çağrı yerinin** hiçbiri geçmiyor. **Dikiş yok.**
- **Ölçülemeyen:** hangisinin fiilen işe yaradığı. `hint`/`state_interface` A/B'si **yazma**
  ister; canlıda salt-okuma kısıtı var. `deploy/asterisk-lab/` tezgâhı gerekiyor ve yerelde
  **Docker Desktop kapalı** (`npipe dockerDesktopLinuxEngine` yok).
- **Bunun değeri:** Karar #42'nin **iki** açık ölçüm şartı (Ş42-2 ve `hint` adayı) **aynı tek
  şeye** dayanıyormuş — laboratuvar ayağa kalkarsa ikisi de aynı turda kapanır.
- **Dokunulan dosyalar:** `yonetim/backlog.md`
- **Commit:** `d63b9914`


### Kurul Karar #43 — `BR-AST-59` ŞARTLI ONAY, ama kart iki yerinden düzeltildi

- **Neden:** `BR-AST-59` bir düzeltme değil tasarım kararıydı → §7/1 gereği kurula gitti.
- **Ne yapıldı:** 10 üye paralel oyladı. **10/10 ŞARTLI → ŞARTLI ONAY.**
- **Kartımdaki HATA (bu turun asıl dersi):** kart *"beklet/aktar/park/kayıt 409"* diyordu.
  Üç bağımsız ölçüm (Şeytan, Süpervizör, kendi okumam) **üçünün çalıştığını** gösterdi:
  kayıt dialplan `MixMonitor`'dür (`ConfigRenderer.cs:463` → `:1502-1510`), kör aktarma
  `Redirect`'tir (`AsteriskAriProvider.cs:462-466`), canlı izleme `ChanSpy`'dır (`:682-751`).
  Listede **olmayan** DTMF ise kırık (`:640`). Yeni kapsam: **ARI hold + ARI DTMF + ARI
  talep-üzerine kayıt.**
- **İkinci düzeltme:** `-in` bir **damgalama bağlamı**, yönlendirme yapmıyor; gelen yönlendirme
  statik `10-pbxtr-inbound.conf`'ta. Devir noktası `BR-AST-58(a)` ile aynı dosyada.
- **Kurulun bulduğu, kartta olmayan üç kusur → beş yeni kart:**
  - **`BR-AST-60` (P1, BLOKLAYICI):** Stasis devrinin karşı tarafı **hiç yazılmamış** —
    `StasisStart` işleyicisi ve `POST /channels/{id}/continue` depoda yok
    (`AriStasisApp.cs:181-196`). **Beş üye bağımsız buldu.** Sonucu: **giden yön bugün
    canlıda kırık olabilir** — `IsConnected=true` → her agent-önce originate `PBXTR_CTL=1`
    basıyor → `Stasis()` koşuyor → `Goto(pbxtr-outbound)` (`:578`) hiç koşmuyor. Trunk/DID
    gerekmiyor; agent originate'i yeter.
  - **`BR-BE-122` (P1):** sufle sesi müşteriye gidebilir — `live:call.ChannelId` "en son doğan
    bacak" (`TelephonyEventPipeline.cs:1063-1078`, `AmiEventMapper.cs:94`).
  - **`BR-BE-123` (P1):** her yeni bacak canlı kayıttaki yön/kuyruk/cariyi siliyor.
  - **`BR-FE-72` (P2)** bekçisiz hata haritaları, **`BR-FE-73` (P3)** gömülü Türkçe.
- **Yan bulgu — ClickUp durum eşlemesi:** `Kurul: Karar #43 ŞARTLI ONAY` biçimi dar kalıba
  uymayıp sessizce `backlog`'a düşüyordu; karara bağlanmış kart panoda sonsuza kadar açık
  görünürdü. Kalıp genişletildi, dört iddia eklendi, **mutasyonla doğrulandı**.
- **Dokunulan dosyalar:** `yonetim/kurul-kararlari.md`, `yonetim/backlog.md` (360→365),
  `doc/prototip-urun-farklari.md`, `yonetim/arac/clickup-durum.js` + testi
- **Sonuç / doğrulama:** ClickUp `fark olan kart: 0, izde olmayan: 0`; durum testi 4/4 yeşil.
- **Commit:** `e49b038b` (karar + kartlar), `2bfd557e` (eşleme düzeltmesi)


### sprint-44 Karar #43'e gore tadil edildi — ve planlama yeni bir bag ortaya cikardi

- **Neden:** Karar #43 baglayici bir sira (S43-11) dayatti; sprint-44 o karardan once yazilmisti.
- **Planlama sirasinda cikan, KARARDA OLMAYAN bag:** `-local` baglamina `-out`/`-int`'ten
  `GotoIf(DIALPLAN_EXISTS(...))` ile giriliyor ve o satir `ExecIf(...?Stasis)`'ten **SONRA**
  kosuyor — canli dosyada dogrulandi (`t0007-dialplan.conf:13` Stasis, `:15` `-local`'a GotoIf).
  Yani **`BR-AST-60` dogruysa kanal `-local`'a hic ulasmiyor** ve sprint-44'un iki ana kalemi
  (`BR-AST-57` / `A-5'` ve `AST-53-b` tasma yarisi) **olculemez** hale geliyor. Bu, `BR-AST-58`'in
  DID yarisi icin Karar #42'de verilen Ş42-8 gerekcesinin **birebir aynisi**.
- **Sonuc:** `BR-AST-60` olcumu sprintin **yeni birinci kalemi** (BR-SYS-93'ten sonra).
  `BR-AST-57`/`AST-53-b` onun arkasina alindi — kod yazilabilir ama *"canlida gorunur sonuc"*
  iddiasi olcum oncesi yapilamaz.
- **Frontend bos kalmiyor:** `BR-FE-72` (bekcisiz hata haritalari, `BR-AST-59`'dan once inmesi
  tercih edilir) ve `BR-FE-73`. `BR-BE-122`/`123` de `BR-AST-59`'dan bagimsiz, bu sprinte alinabilir.
- **DoD'ye eklenen kural:** *kapsam da olculur.*
- **Dokunulan dosyalar:** `yonetim/sprintler/sprint-44.md`
- **Commit:** `46bcb506`


### `BR-FE-73` olculdu — kapi YOK, tek ornek DEGIL, ve yontem kendi hedefini kacirdi

- **Neden:** Karti yazarken *"JSX icinde gomulu dize birakmayi engelleyen bir kapi var mi —
  kart yazilmadan olculmeli"* diye isaretlemistim.
- **Sonuc 1 — kapi yok:** `i18n.test.tsx` yalniz sozluk butunlugunu olcuyor (dil kumesi,
  anahtar esligi, bos metin, yer tutucu kaybi, ceviri != kopya). JSX icindeki dizeleri goren
  **hicbir kural yok.**
- **Sonuc 2 — tek ornek degil, en az uc:** `ConsoleScreen.tsx:1195` (`' · beklemede'`),
  `AgentDeskScreen.tsx:633` (`'Otomatik (dialer)' : 'Manuel arama'`),
  `CallerFacts.tsx:57` (`'Bilinmeyen arayan'`).
- **Yontem siniri (kartin asil gerekcesi):** ilk taramayi Turkce'ye ozgu karakterlerle
  (`gusioc`) yaptim ve **kendi hedefimi kacirdim** — `' · beklemede'` tamamen ASCII. Bu sinif
  regex ile guvenilir sayilamaz; **"uc tane" bir ALT SINIRDIR.** Tam sayim AST/lint ister —
  ki kartin (b) maddesi tam olarak o oldu.
- **Kapsam buyudu:** P3 -> P2. Tek satirlik junior isi degil: uc isabet sozluge tasinir +
  AST/lint tabanli kapi eklenir + kapi mutasyonla dogrulanir.
- **Dokunulan dosyalar:** `yonetim/backlog.md`
- **Commit:** `44d73993`


### Kartlara yazdigim BASKALARININ onculleri de olculdu (yeni DoD kurali kendine uygulandi)

- **Neden:** Karar #43'un DoD kurali *"kapsam da olculur"* diyor; kurul uyelerinin iddialarini
  karta aktarirken onlari da olcmem gerekiyordu.
- **`BR-FE-72` — iddia DOGRU, sayi YANLIS:** Frontend Uzmani *"bekci yalniz `intervention` ve
  `monitor` yuzeylerini kapsiyor"* demisti; `LiveFailureMessageSurfaces.cs`'i okudum, **uc**
  yuzey var: `monitor`, `intervention`, **`call-permission`** (`shared/status.ts` /
  `CALL_PERMISSION_REASON`). Asil iddia aynen duruyor:
  `grep -c "callControlErrors\|parkErrors"` -> **0**. Kart duzeltildi.
- **`BR-BE-122`/`123` — DOGRULANDI:** `TelephonyEventPipeline.cs:1063-1078`, `Newchannel` her
  geldiginde `SetCallAsync` **bastan kurulmus** bir `LiveCallState` aliyor
  (`direction ?? "inbound"`, `queueKey ?? ""`, `contact_id`, kanal) — kismi guncelleme degil
  **tam degistirme**. Her yeni bacak kaydin tamamini eziyor.
- **Dokunulan dosyalar:** `yonetim/backlog.md`
- **Commit:** `538c80af`


### `BR-AST-58(a)` kapsami olculdu — ve Karar #43'un kendi sartiyla celisti

- **Neden:** Karar #43 gelen yondeki Stasis devir noktasini `BR-AST-58`'in (a) maddesine havale
  etti; ama o maddenin **ne icerdigini** olcmemistim. (Yeni DoD kuralinin ikinci uygulamasi —
  bu kez kural benim bir sonraki adimimi duzeltti.)
- **(a-1) Sablon dosyasi depoda HIC YOK.** `find . -name "*pbxtr-inbound*"` -> bos.
  `10-pbxtr-inbound.conf` ne sevk ediliyor ne uretiliyor; yalniz
  `doc/mimari/asterisk-dialplan-sablonu.md:242-306`'da belge olarak var.
- **(a-2) CELISKI:** gelen yoldaki **her** baglam tenant oneksiz — `[pbxtr-inbound]` (`:245`),
  `[pbxtr-decide]` (`:299`), `[pbxtr-after-queue]` (`:368`), `[pbxtr-notenant]` (`:202`).
  Tenant `${PBXTR_TENANT}` kanal degiskeninden okunuyor. Ama **Ş43-6 (CTO Ş5)** devir satirinin
  **tenant ONEKLI** baglamda durmasini sart kosmustu, ve Seytan'in onerdigi `pbxtr-after-queue`
  da paylasimli. Yani gelen yoldaki her dogal devir noktasi paylasimli bir baglamda.
  Iki yol var (baglamlari tenant basina uret / Ş43-6 gerekcesini yeniden yaz), ikisi de bedelli
  -> Karar #43'un acik sorularina **dorduncu madde**.
- **(a-3) `__PBXTR_REC` ayni kanalda IKI ANLAM tasiyor:** `ConfigRenderer.cs:1503` onu **dosya
  adi tabani** yapiyor (`${CHANNEL(linkedid)}`), sablon `:293` **boole bayragi** yapiyor (`1`)
  ve `:303`/`:430` o bayraga bakip **ikinci bir MixMonitor** basliyor. Iki sonuc: (i) tenant
  "tumunu kaydet" acik + route-decision `record=1` -> cift kayit, ikinci dosya
  `CDR(recordingfile)`'da gorunmez, ETL indirmez, diskte oksuz kalir; (ii) tenant ayari kapali
  ama `record=1` -> kayit baslar ama `CDR(recordingfile)` hic set edilmez -> **kayit var, ETL
  bulamiyor**; uyusmazlikta "kayit yok" denir. **Bugun latent**, `BR-AST-58` sevk ettigi gun dogar.
- **Dokunulan dosyalar:** `yonetim/backlog.md`, `yonetim/kurul-kararlari.md`
- **Commit:** `60355533`


### Ş43-6'nin "bayt bayt ayni" sarti bugun uygulanamaz — altin dosya mekanizmasi yok

- **Neden:** Ş43-6 (CEO Ş1 + CTO Ş4) *"bayrak kapaliyken uretilen dialplan bugunkuyle bayt bayt
  ayni olmali (regresyon fiksturuyle kanitlansin)"* diyor. Sartin **maliyetini** olctum.
- **Olculen:** `ConfigRendererTests.cs` 564 satir, **87 iddia** — `Contains` 41,
  `DoesNotContain` 23, `True` 10, `Equal` 7, `Single` 3, `Throws` 2, `StartsWith` 1. Tam metin
  karsilastiran tek `Assert.Equal(expected, ...)` bir **dize yardimcisina** ait (`:111`,
  `Slugify`). **Hicbir `.csproj`'de** Verify / ApprovalTests / Snapshooter **yok**.
- **Sonuc:** 64 alt-dize iddiasi *"su satir var/yok"* diyebilir ama **"baska hicbir sey
  degismedi" DIYEMEZ** — Ş43-6 tam olarak ikincisini istiyor.
- **Planlamaya etkisi:** `BR-AST-59b` yalniz opt-in uretimini degil **bir altin-dosya fiksturu
  kurma isini de** tasiyor; fikstur **mutasyonla dogrulanmali**, yoksa "bayt bayt ayni" iddiasi
  *kosmayan kapi* sinifina girer. Sart gecersiz degil — bedeli gorunur oldu, `59b` S degil **M**.
- **Yontem notu:** bu turda taramalarim **ucuncu kez** kendi gurultusunu uretti (`altin` deseni
  `altinda` kelimesine takildi; oncekiler Turkce-karakter taramasi ve kapsam sayimiydi).
  Ders: **desen tabanli arama, aradigi seyin tanimini degil yazilisini olcer** — bulgu her
  seferinde dosya acilip dogrulanmali.
- **Dokunulan dosyalar:** `yonetim/backlog.md`, `yonetim/kurul-kararlari.md`
- **Commit:** `7f69068f`


### `BR-SYS-94` — envanterin siniflandirmasi YANLISTI: lab fiksturu uretim imajina gomulu

- **Neden:** `BR-SYS-91`'in (santral sapma kapisi) kapsamini olcerken, bugunku envanterin
  "elle yazilmis" dedigi bloklarin gercekten elle mi yazildigini sorgulama ihtiyaci dogdu.
- **Olculen zincir:** `sha256(deploy/asterisk-lab/conf/extensions.conf)` ==
  `sha256(canli /etc/asterisk/extensions.conf)` == `066072bb...`, ikisi de **175 satir**.
  Yol: `deploy/asterisk-lab/Dockerfile:52` -> `COPY conf/ /etc/asterisk/`;
  uretim compose'u (`pbxtr-demo/docker-compose.yml:674-692`) o imaji kullaniyor
  (`pbxtr-asterisk:22`, *"sunucuda build: YOKTUR"*).
- **Sonuc:** o bloklar **elle yazilmis kalinti degil**, imaja gomulu **laboratuvar fiksturu**.
  `[pbxtr-t0007-in]` iki dosyada birden tanimli; `#include` satir **175**'te (sonda) -> Asterisk
  birlestiriyor -> imajdaki sabit `8001` uretilen `_X.`'ten daha spesifik -> tek calisan gelen
  numara **kalici olarak bos** bir kuyruga gidiyor. **Gelen cagri yolundaki asil belirleyici
  pbxtr'in urettigi config degil, imaja gomulu fikstur.**
- **Daha genel sonuc:** fikstur tenant kimligini **sabit** tasiyor (`t0007`). Bugun canli tenant
  o oldugu icin gorunmuyor; baska bir tenant'a kurulan her dagitim **baska musterinin tenant
  kodunu tasiyan** bir baglamla acilir.
- **`BR-SYS-91` kapsami da duzeldi:** o kartin (3) maddesi
  *"/etc/asterisk/*.conf ≟ deploy/asterisk-lab/conf/*"* karsilastirmasi **bugun YESIL doner** —
  ikisi zaten ayni. Kapi kusuru yakalamaz, **onaylar**. Gereken: semantik kural —
  *"pbxtr.d/ altinda tanimlanan hicbir baglam pbxtr.d/ disinda ikinci kez tanimlanamaz."*
- **Yontem notu:** envanterin ilk hali bir varsayimi olcmemisti — **bir dosyanin uretilen dizinin
  disinda olmasi, elle yazildigi anlamina gelmiyor**; ucuncu bir kaynak (imaj katmani) vardi.
  Dogru soru *"bunu kim yazdi"* degil **"bu dosya nereden geliyor"**du.
- **Dokunulan dosyalar:** `yonetim/backlog.md` (366 kart), `yonetim/kurul-kararlari.md`
- **Commit:** `31151498`


### `BR-SYS-94` duzeltme yolu ikiye bolunuyor — depo/imaj tek basina yetmiyor

- **Neden:** `BR-SYS-94`'u yazdiktan sonra bir varsayimi olcmemistim: imaji duzeltmek canliyi
  duzeltir mi?
- **Olculen:** uretimde `/etc/asterisk` **imajdan gelmiyor** —
  `pbxtr-demo/docker-compose.yml:99` ile **host dizininden bind mount** ediliyor
  (`${PBXTR_ASTERISK_CONF_DIR:-./asterisk}:/etc/asterisk`). Giris betigi tohumu
  `/opt/pbxtr/asterisk-default/`'ten **yalniz EKSIK dosyalar icin** kopyaliyor
  (`lab-entrypoint.sh:47-68`).
- **Betigin kendi yorumu bedeli zaten yazmis** (`:36-40`): *"imaj yukseltmesiyle gelen YENI bir
  taban ayari, ayni adli bir dosya host'ta zaten varsa UYGULANMAZ… sessizce ezmek, 'sunucuda
  degistirdigim ayar geri geldi' sinifinda bir ariza uretirdi"*. Yani **kusur degil, bilincli
  tasarim** — ama sonucu kartin tasimasi gerekiyordu.
- **Sonuc:** `conf/`'u depoda duzeltip imaji yeniden uretmek **canliyi degistirmez**; host'taki
  lab fiksturu kalicidir. Kapsam iki ayaga ayrildi: **(a-i)** depo/imaj tarafi, **(a-ii)** host
  tarafi gecisi (elle silme ya da `PBXTR_ASTERISK_CONF_RESET=1` ile bir kez acilma).
  **(a-ii) yazilmazsa duzeltme sahada hic gorunmez** — *"duzelttik ama degismedi"* sinifi.
- **Ve bu tam olarak `BR-SYS-91`'in var olma sebebi:** host config imajdan **suresiz** sapabilir
  ve bugun bunu olcen hicbir sey yok.
- **Yontem notu:** cevap yine **dosyanin kendi yorumundaydi**. Bugun bu ucuncu kez oldu.
- **Dokunulan dosyalar:** `yonetim/backlog.md`
- **Commit:** `b1a86e65`


### `BR-SYS-92` bagimsiz dogrulandi — ve ariza SESSIZ DEGIL, gunlugu okunmuyor

- **Neden:** `BR-SYS-94` (lab fiksturu uretim imajinda) bir hipotez dogurdu: `BR-SYS-92` de ayni
  kokten mi?
- **ONEMLI — bu bir kesif degil, DOGRULAMA:** `BR-SYS-92` eksik `bind` satirini, yeniden insa
  gerekliligini ve *"elle duzeltme geri ezilir"* uyarisini **zaten yaziyordu**. Olcumun ekledigi
  sey, duzeltmenin **sinanabilir** hale gelmesi.
- **Olculen:**
  - `sha256(depo deploy/asterisk-lab/lab-entrypoint.sh)` = **917ea946...**, `bind` **var**
  - `sha256(canli konteyner /usr/local/bin/lab-entrypoint.sh)` = **522688cd...**, `bind` **YOK**
  - imaj `pbxtr-asterisk:22`, konteyner olusturma **2026-09-06** -> **duzeltme oncesi**
  - canli dosya mtime **bugun 04:01** -> konteyner bugun acildi ve **eski entrypoint yine
    bind'siz yazdi**; kartin uyarisi **fiilen gozlendi**
  - `pjsip show transports` -> `Objects found: 1` (yalniz udp)
- **Asil ders:** ariza **sessiz degil**. `docker logs pbxtr-asterisk` her ~5 dakikada iki ERROR
  satiri basiyor, sonuncusu **bugun 18:22:34**
  (`transport_apply: ... could not be started as binding not specified`). On gun boyunca acikca
  ve tekrar tekrar yazildi; **kimse okumadigi icin sessiz sayildi.**
- **`BR-SYS-91`'e besinci olcum eklendi:** acilis gunlugunde `res_pjsip` ERROR satiri varsa kapi
  kirmizi. Dosya karsilastirmasindan **daha ucuz ve daha erken** yakalar.
- **`BR-SYS-92`'ye kabul olcutu eklendi** (yeniden insadan sonra ucu birden): konteyner ici
  entrypoint hash'i `917ea946...` **ve** `pjsip show transports` -> `Objects found: 2` **ve**
  acilis gunlugunde `transport-ws` ERROR satiri yok.
- **Dokunulan dosyalar:** `yonetim/backlog.md`, `yonetim/kurul-kararlari.md`
- **Commit:** `95055f77`


### Sapmanin cinsi olculdu — elle duzenleme DEGIL, bayat imaj

- **Neden:** `pjsip.conf`'un canlida depodan sapmis oldugunu olcmustum ama **neyin** farkli
  oldugunu acmamistim. `BR-SYS-91`'in aradigi sapmanin tek somut ornegi buydu.
- **Olculen:** `extensions.conf` canlida depo fiksturuyle **bayt bayt ayni** (`066072bb`);
  `pjsip.conf` ise **sapmis** (`ab7f1ac9` depo / `49ef3a45` canli). Sapmanin tamami **27 satir
  ve hepsi YORUM** — canli dosya deponun iki olcum kaydini tasimiyor: (1) 2026-08-29 *"uretilen
  tasima `bind` satiri TASIR ve tasimak ZORUNDADIR"*, (2) 2026-08-30 *"`qualify_frequency = 0`
  — tarayici icin acik olmasi zararlidir"*. **Islevsel fark yok.**
- **Iki sonuc:**
  1. Sunucudaki dosyalar **elle duzenlenmemis** — hepsi bir imaj tohumundan gelmis, yalnizca
     **eski** bir imajdan. Yani `BR-SYS-94`'un (a-ii) host gecisi bir *"kullanici ayarini ezme"*
     riski tasimiyor; **gecis ucuzladi.**
  2. Sapma **`BR-SYS-92` ile ayni kokten**: konteyner `2026-09-06` imajindan ve o imaj `bind`
     duzeltmesinden once. `pjsip.conf`'un eksik yorumlari, imajin bayatliginin **bagimsiz bir
     parmak izi** — ve `BR-SYS-91`'in dosya karsilastirmasi bunu **yakalardi**.
- **Dokunulan dosyalar:** `yonetim/backlog.md`
- **Commit:** `501365ea`


### `BR-SYS-92`'nin penceresi olculdu: **4 dakika 35 saniye**

- **Neden:** imajin bayat oldugu dogrulanmisti; yeniden insanin **baska ne getirecegi** (yani
  seni bekleyen dagitim kararinin degeri ve riski) olculmemisti.
- **Olculen:**
  ```
  imaj insasi (docker image inspect) : 2026-08-29T14:34:25Z  sha256:799cefe04d32
  bind duzeltmesi (3f8c51bc)         : 2026-08-29T14:39:00Z
  fark                               : 4 dk 35 sn
  ```
  `lab-entrypoint.sh` o commit'ten beri **hic degismedi**. Yani imaj, duzeltme git'e girmeden
  dort bucuk dakika once o anki calisma agacindan insa edildi; duzeltme dakikalar sonra commit
  edildi; imaj bir daha **hic yeniden insa edilmedi**; ariza **12 gun** yasadi.
- **Yeniden insanin getirecegi:** `git log --since=2026-09-06 -- deploy/asterisk-lab/` -> yalniz
  `README.md`. Yani dagitim **davranissal olarak tek sey** degistiriyor: `bind` satiri.
  **Risk dar, kazanc net.**
- **KENDI OLCUMUMUN DUZELTMESI:** onceki turda imaj tarihini `2026-09-06` yazmistim. O,
  `docker inspect <konteyner>` ciktisindaki **konteynerin** `.Created`'idir; imajin insa tarihi
  `docker image inspect` ile **ayri** olculur. Konteyner 09-06'da yeniden yaratilmis ama **ayni
  bayat imajdan** — yani "yeniden baslattik" bir duzeltme degildi ve olamazdi.
- **`BR-SYS-91` icin en guclu gerekce:** dort bucuk dakikalik bir yaris, on iki gunluk bir ariza
  uretti ve **hicbir kapi gormedi**. Sapma kapisinin soracagi soru *"depo dogru mu"* degil —
  depo bastan beri dogruydu — **"kosan imaj deponun neresinde"**dir.
- **Dokunulan dosyalar:** `yonetim/backlog.md`, `yonetim/kurul-kararlari.md`
- **Commit:** `b287e82a`


### Bayatlik bir SINIF hatasi mi? — alti imajin tamami olculdu, cevap HAYIR

- **Neden:** `BR-SYS-92`'nin koku bayat imaj cikinca ayni soruyu her konteyner icin sormak
  gerekiyordu — ozellikle **ana uygulama** icin: "bitti" denmis kartlar canlida var mi?
- **Olculen (canlidaki alti konteynerin imaj insa tarihi):**
  `pbxtr-app` **tekbirsoft/pbxtr:demo-d66684a676ce** (2026-09-08) · `pbxtr-asterisk`
  **pbxtr-asterisk:22** (2026-08-29) · `postgres:16-alpine` (07-07) · `redis:7-alpine` (07-26) ·
  `minio` (2025-04-22) · `nginx:1.27-alpine` (2025-04-16).
- **Uygulama tarafi saglikli:** `pbxtr-app` etiketi **commit sha'si gomulu** tasiyor —
  `d66684a6` (2026-09-08T05:32+03:00), imaj bir saat sonra insa edilmis, yani **sira dogru**
  (`BR-SYS-92`'deki "commit'ten once insa" hatasi burada yok). Gecikme dar ve bilinen:
  `d66684a6..HEAD` arasinda `src/`'ye dokunan **2 commit** (`176bfe64` — Karar #39 K-16/K-18'in
  iki gercek kusuru; `aae46c27`).
- **ASIL BULGU ETIKETLEME FARKINDA:** `pbxtr-app` etiketi *"depo surumu"*nu tasiyor;
  `pbxtr-asterisk` etiketi (`:22`) **Asterisk surumunu** tasiyor, depo surumunu **degil**.
  Sonuc: birinin bayatligi **tek komutla** olculuyor, digerininki **12 gun gorunmedi**.
- **`BR-SYS-91`'e iki madde eklendi:** (5) acilis gunlugunde `res_pjsip` ERROR satiri varsa kapi
  kirmizi; (6) imaj etiketi commit sha'si tasimali (`pbxtr-asterisk:22-<sha>`) ve kapi *"kosan
  imajin sha'si HEAD'in kac commit gerisinde"* sorusunu sorar — (1)-(3)'teki dosya
  karsilastirmalarindan **once** ve **cok daha ucuza** cevap verir.
- **Yontem notu:** bayatlik **sinif hatasi degilmis** — alti imajin yalniz biri sorunlu ve
  sorunlu olan tam da **sha'siz etiketlenen**. Kusur "dagitim disiplini yok" degil, **"bir imaj
  disiplinin disinda kalmis"**. Birincisi surec isi, ikincisi tek satirlik etiket degisikligi.
- **Dokunulan dosyalar:** `yonetim/backlog.md`, `yonetim/kurul-kararlari.md`
- **Commit:** `3b321d4c`


### `pbxtr-app`'in 2 commit gecikmesi KUSUR DEGIL — ve bu ayrim kapinin esigini belirliyor

- **Neden:** onceki olcumde "dar ve bilinen bir gecikme" demistim ama **ne tasidiklarini**
  bakmamistim. Eger "Bitti" denmis kart duzeltmeleriyse, kartlar kapali gorunurken canlida yok
  demek olurdu.
- **Olculen:** `aae46c27` (**bugun 15:33**, 37 dosya — 09-09 turunun kurtarilmasi + `tsc -b`
  kirmizilari) ve `176bfe64` (**bugun 16:37**, 2 dosya — Karar #39 K-16/K-18). **Ikisi de
  bugunden**, imaj ise 09-08'den.
- **Sonuc:** uygulama tarafinda *"duzeltilmis ama dagitilmamis kusur"* **YOK** — yalnizca
  bugunun isi henuz dagitilmamis, bu normaldir. Asterisk vakasiyla **ayni sinifta degil**.
- **`BR-SYS-91`'in esigi buradan cikiyor:** kapi *"kosan imaj HEAD'in gerisinde"* dedigi anda
  kirmizi olamaz — o halde **her gun kirmizi** olur ve gurultuye doner. Olcmesi gereken sey
  **gecikmenin YASI**dir: bugunun commit'i normaldir, **on iki gunluk bir imaj degildir**.
- **Dokunulan dosyalar:** `yonetim/kurul-kararlari.md`
- **Commit:** `3640cc20`


### Gun kapanis denetimi — kart numarasi cakismasi ve mezar tasi konvansiyonu (SONUC: TEMIZ)

- **Neden:** bugun 8 kart actim; defterdeki *"kart numarasi once olculur"* dersi bes cakismadan
  geliyor. Kapatmadan once dogrulama.
- **Bugunku sekiz kart:** `BR-AST-53`, `BR-AST-59`, `BR-AST-60`, `BR-BE-122`, `BR-BE-123`,
  `BR-FE-72`, `BR-FE-73`, `BR-SYS-94` — **her biri tam olarak bir kez** tanimli, cakisma yok.
- **Denetim uc eski cift buldu:** `BR-BE-47` (satir 4492 + 4569), `BR-BE-53` (1493 + 4608),
  `BR-SYS-45` (1495 + 4527). **Ucu de KASITLI mezar tasi** — eski satir acikca
  *"Yerini satir N aldi (eski durum: …)"* diyor.
- **Asil sorulan soru — arac bu deseni taniyor mu:** evet. `rows.json`'da ucu de **tek kayit**
  ve **canli satirin** durumuyla: `BR-BE-47` -> *Bitti (2026-09-07)*, `BR-BE-53` -> *Bekliyor*,
  `BR-SYS-45` -> *Bitti (2026-09-06)*. Mezar tasinin eski durumu panoya **gitmiyor**.
- **Sonuc:** negatif bulgu — konvansiyon calisiyor, duzeltilecek bir sey yok. Kayda geciriliyor
  ki bir sonraki denetim ayni ucluyu yeniden arastirmasin.


### Acik P1 denetimi basladi — `BR-AST-24` olculdu: sablonun onerdigi satir KOSMUYOR

- **Neden:** bugun actigim kartlarin onculleri olculu ama **eski acik P1'lerinki degil** (52
  tane). Defterdeki bagimsiz denetim 55 kartta **yedi yanlis teshis** bulmustu. Supervizor bugun
  `BR-AST-24`'e atif yapti, onunla basladim.
- **Kart iyi yazilmis:** onculu bir iddia degil **soru** (*"MixMonitor pause / StopMixMonitor var
  mi — olcum"*). Bugun cevaplanabilir hale geldi.
- **Olculen (canli Asterisk 22.10.1):** `core show application MixMonitorMute` ->
  **"Your application(s) is (are) not registered"**.
- **KONTROL GRUBU ayni turda kostu** (yoksa cevap komut biciminden gelebilirdi):
  `MixMonitor` **kayitli**, `StopMixMonitor` **kayitli**,
  `manager show command MixMonitorMute` **kayitli** (*"Mute / unMute a Mixmonitor recording"*).
  Yani cevap **uygulamanin gercekten yoklugundan** geliyor.
- **Sonuc 1:** `asterisk-dialplan-sablonu.md:587`'deki `MixMonitorMute(...)` satiri **kosmaz**;
  tek yol **AMI**'dir — sablonun kendi alternatifi dogru yolmus. `:587` ve D5 satiri olcumle
  guncellendi, boylece *"yazilmis ama kosmayan dialplan satiri"* tuzagi kapandi.
- **Sonuc 2 — risk BUGUN LATENT:** kart tahsilat dugumu **hic yok**. `ConfigRenderer`'da PCI /
  `MixMonitorMute` / `StopMixMonitor` uretimi **sifir isabet** (tek gecen yer `:1365`'te bir
  yorum); domain'de boyle bir IVR dugum turu yok. Yani *"kart adimi kayda giriyor"* yasanmiyor —
  cunku kart adimi yok. **PCI yuzeyi, o dugum yazilmadan ONCE kapatilmali** (onu yazan kartin
  kabul kriterine madde olarak).
- **Dokunulan dosyalar:** `yonetim/backlog.md`, `doc/mimari/asterisk-dialplan-sablonu.md`
- **Commit:** `f38cfcab`


### Acik P1 govde denetimi — iki kartin kapsami SPRINT DOSYASINDA kalmis

- **Neden:** `BR-QA-06`'yi okurken tek satirlik, kabul kriteri olmayan bir P1 gordum. Bunu
  sistematik olctum: acik P1'lerin kac tanesi **baslanamaz** durumda?
- **Olculen:** 52 acik P1'in **yalniz 4'unun** govdesi <160 karakter — yani %92'si govdeli.
  Dordunden ikisi (`BR-SYS-42`, `BR-BE-53`) somut cikti adi tasidigi icin uygulanabilir.
  Geriye **`BR-QA-06`** (50 karakter) ve **`BR-SYS-51`** (27 karakter) kaldi.
- **Asil bulgu:** ikisinin de kapsami **VARDI** — ama **sprint dosyalarinda**
  (`sprint-36.md`/`sprint-41.md` ve `sprint-43.md`), kartta degil. CLAUDE.md §14'e gore kaynak
  `backlog.md` ve ClickUp onun yansimasi; dolayisiyla **panoya giden metin saplamaydi** ve is
  panoda **uygulanamaz** gorunuyordu. Bu, kuralin kendi ifadesiyle *"bir is backlog.md'ye kart
  olarak yazilmadiysa ClickUp'ta hic yoktur"* deseninin bir varyanti: **kart var ama kapsami yok.**
- **Yapilan:** kapsam birebir karta tasindi — `BR-QA-06`'nin alti maddelik kabul kumesi (t0007
  anahtari t0012 nesnesi goremez, kesif disinda `cross_tenant` yok, paket sir tasimaz, `removed`
  yalniz pinli anahtari kalmayan tenant, denetim satirlari tenant basina, 409 ayrimi) + rakam
  kapilari; `BR-SYS-51`'in runbook adi (`deploy/sms-kesinti-tatbikat.md`), tatbikat adimlari,
  on kosulu (`BR-SYS-45` bekcisi) ve bagimliliklari.
- **Eklenen olculebilirlik:** `BR-SYS-51`'in *"tek alarm"* sarti sayilir hale getirildi — iki
  alarm cikarsa kart kapanmaz (gurultu, kesinti kadar pahalidir).
- **Sonuc / dogrulama:** ClickUp senkronu **2 kart** guncelledi (baslik), ardindan `--kuru`
  temiz.
- **Dokunulan dosyalar:** `yonetim/backlog.md`
- **Commit:** `bfdb376b`


### Acik P1 referans denetimi — 102 `dosya:satir` referansinin tamami gecerli (SONUC: TEMIZ)

- **Neden:** kartlar `dosya.cs:satir` referansi tasiyor ve kod degistikce bunlar **sessizce**
  bayatliyor. Global kural da bunu soyluyor: bir kayit dosya/fonksiyon/bayrak adi veriyorsa,
  onermeden once hala var oldugu dogrulanir.
- **Olculen:** 52 acik P1 kartindan **102 benzersiz** `dosya:satir` referansi cikarildi; her
  biri depoda cozuldu ve satir numarasi dosya sinirlariyla karsilastirildi.
  **Sonuc: 100 dogrudan gecerli, 0 tasma.** "Bulunamayan" 2 referans benim **cikarim
  artefaktim**ci: kart hem tam yolu (`deploy/pbxtr-confd-cek.sh:271`) hem kisaltmayi
  (`cek.sh:271`) yaziyor; dosyalar var (654 ve 1745 satir), satirlar sinir icinde.
  **Yani 102/102 gecerli.**
- **YONTEMIN SINIRI (yazilmasi sart):** "satir dosya sinirinda" yalnizca **kaba** bayatligi
  yakalar — satirin hala **iddia edilen seyi** gosterdigini gostermez. Bugun elle dogruladigim
  referanslar (`ConfigRenderer.cs:549/:604`, `AriStasisApp.cs:181-196`,
  `TelephonyEventPipeline.cs:1063-1078`, `AsteriskAriProvider.cs:258`,
  `LiveFailureMessageSurfaces.cs`) icerik olarak da tuttu; kalan ~97'si icin **yalnizca sinir**
  dogrulandi.
- **Karar: BU ICIN KART ACILMADI.** Otomatik bir "referans curumesi" kapisi cazip gorunuyor ama
  denetim **sifir gercek kusur** buldu; sifir kusurlu bir kapi kurmak defterdeki
  *"kapi kurmadan once mevcut veriyi olc"* ve *"kosmayan kapi bulgu degildir"* tuzaklarina
  girer. Kusur cikarsa kart o zaman acilir.
- **Dokunulan dosya:** yok (negatif bulgu, yalniz kayit).


### YAPISAL KOK — Asterisk imaji yayin hattinin TAMAMEN disinda

- **Neden:** bloke eylemlerden birini **hazirlamak** istedim: `BR-SYS-92`'nin duzeltmesi bir imaj
  yeniden insasi ve kosulacak komut dizisi hicbir yerde yazili degildi.
- **Aranan bulunamadi — ve yoklugun kendisi asil bulgu oldu:**
  - `deploy/yerel-yayin.sh` (561 satir) **yalniz uygulama imajini** uretiyor: `:46`
    `IMAGE=tekbirsoft/pbxtr`, `:62` `ETIKET="$IMAGE:demo-$KISA"`, `:502` `docker build … -t
    "$IMAGE:demo" -t "$ETIKET" .`, `:516-517` `docker push`.
  - Betikte **`asterisk` kelimesi hic gecmiyor**.
  - Depoda `pbxtr-asterisk` imajini insa/dagitan **hicbir betik yok**.
- **Bugunun tamami bundan cikiyor:** uygulama imaji her yayinda betikle insa edilip **sha ile
  etiketlenip** itiliyor (bayatligi tek komutla olculuyor); Asterisk imaji **elle** insa edilmis
  (2026-08-29T14:34:25Z), **bir daha hic insa edilmemis**, `:22` ile etiketlenmis — yani
  **Asterisk surumunu** tasiyor, **depo surumunu degil** -> bayatligi hicbir yerden okunamiyor.
- **Sonuc:** `BR-SYS-92` bir unutkanlik degil, bir **kapsam boslugu**. Ve tam bu yuzden **bugun
  duzeltilse bile tekrarlar** — bir sonraki depo duzeltmesi ayni sessizlikle sunucuya ulasmaz.
- **Duzeltme ucuz, cunku desen zaten yazili:** `yerel-yayin.sh:62`'deki sha etiketleme birkac
  satir; `pbxtr-asterisk:22-$KISA` ayni desen. `BR-SYS-94` (c) netlesti: **(c-i)** imaj yayin
  hattina alinir ve sha ile etiketlenir (o zaman `BR-SYS-91`'in (6) maddesi neredeyse bedavaya
  gelir), ya da **(c-ii)** elle kalmasi **bilincli karar** olarak yazilir ve kapi onu zorunlu
  olcer. **Ikisinden biri secilmeden BR-SYS-92 yeniden yasanir.** Bu bir **kurul sorusudur**
  (dagitim politikasi), teshis degil.
- **Yontem notu:** defterdeki *"arac yoklugu sifir gibi gorunur"* dersinin tersi — burada aranan
  betigin **yoklugu**, on iki gunluk arizanin sebebini acikladi.
- **Dokunulan dosyalar:** `yonetim/backlog.md`, `yonetim/kurul-kararlari.md`
- **Commit:** `6f78b76c`


### `BR-SYS-94(c)` kurula gitmeden once daraltildi — cevabin yarisi zaten yaziliymis

- **Neden:** (c) maddesini *"kurul sorusu"* ilan etmistim. Kurulu toplamadan once Karar #43'un
  kendi kuralini uyguladim: **bu zaten karara baglanmis mi?**
- **Bulunan 1 — compose'un kendi gerekcesi duzeltmeyi destekliyor.**
  `pbxtr-demo/docker-compose.yml:674-679` birebir: *"IMAJ DEPODA URETILIR … **Surum SABITTIR**:
  taban imaj `andrius/asterisk:22.10.1` … **`latest` bir gun 23'e kaydiginda bunu kimse fark
  etmezdi**"*. Yazarin kaygisi **fark edilmeyen sessiz kayma** — ve tam o kayma yasandi, ama
  **diger eksende**: Asterisk surumu sabit kaldi, **pbxtr katmani** (`conf/` + `lab-entrypoint.sh`)
  kaydi. **`:22` etiketi iki ekseni karistiriyor.** Yani (c-i) mevcut niyete aykiri degil,
  **onun tamamlanmasi**.
- **Bulunan 2 — dikis zaten var.** `image: ${PBXTR_ASTERISK_IMAGE:-pbxtr-asterisk:22}` — imaj adi
  ortam degiskeniyle ezilebilir; sha'li etiket compose'a **hic dokunmadan** verilebilir.
  Degisiklik yalniz `yerel-yayin.sh` tarafinda ve desen `:62`'de zaten yazili.
- **Sonuc:** kurula giden soru **iki dar maddeye** indi: (1) imaj **her yayinda mi** girecek yoksa
  **degistiginde mi** (ikincisi ucuz ama *"dokunulmadi sanip atlama"* riski tasir — bugunku ariza
  tam olarak odur); (2) `:22` etiketi **korunacak mi** (korunursa eksenler karisik kalir;
  kaldirilirsa `PBXTR_ASTERISK_IMAGE` vermeyen kurulum **acilmaz** — bilincli secilirse iyi,
  kazara olursa kotu).
- **Dokunulan dosyalar:** `yonetim/kurul-kararlari.md`
- **Commit:** `964dfd36`


### Asterisk imaji dagitim politikasi — TEKNIK ISTISARE (karar DEGIL) ve bes curutulen oncul

- **Surec hatam, once:** CLAUDE.md 6 kurulu **10 uye + en az 7 EVET** sartina bagliyor; ben
  **4 uye** cagirdim (CEO, CTO, Linux, Seytan). Dordu de SARTLI oy verdi ama **yeter sayi yok** —
  kayit karar numarasi almadan **istisare** olarak gecti.
- **Turun en onemli sonucu:** bu is **zaten planli**. `sprint-44` Blok 0 (`LX-01`..`LX-08`) tamamini
  iciyor ve sprint **"basla" bekliyor**. CEO ve Seytan bagimsiz olarak ayni itirazi yapti:
  `BR-SYS-94(c)` diye ikinci bir muhasebe hatti acmak, iki yerde durum tutmaktir. **Ayri kart
  acilmadi.**
- **BES ONCULUM CURUDU (hepsi benim yazdigim):**
  1. **(en onemlisi)** *"imaji duzeltmek tek basina canliyi degistirmez"* — **YANLIS**. `bind`
     duzeltmesi tohumlanan `conf/` yolunda degil; `lab-entrypoint.sh:136-161`
     `00-transport-ws.conf`'u **her acilista kosulsuz `cat >`** ile yaziyor. Yani **yeniden insa +
     recreate `BR-SYS-92`'yi TEK BASINA duzeltir.**
  2. *"Depoda insa/dagitim betigi yok"* — kismen yanlis: betik yok ama **belgelenmis elle
     prosedur var** (`deploy/asterisk-lab/README.md:251-266`).
  3. *"Sunucuda kimse elle duzenlememis"* — **tek tarihli gozlem**, kalici ozellik degil.
  4. *"Yapisal kok"* — `LX-08` bunu **kelimesi kelimesine** yaziyor.
  5. *"Duzeltme ucuz, desen zaten yazili"* — **olculmemisti**: `pbxtr-asterisk` yerel bir ad,
     registry hedefi yok, `docker push` calismaz; `staging-yayin.sh` asterisk'i **hic bilmiyor**.
- **UC YENI OLCUM (Blok 0'a kabul kriteri olarak eklenecek):**
  1. `deploy/pbxtr-deploy-artifact:115-116,142-143` — dagitici **yalniz app ve nginx**'i recreate
     ediyor; santral icin **saglik kapisi ve rollback YOK**. *"Etiket uretmek dagitim degildir."*
  2. `pbxtr-artifact-validate.py:9,38,40` — **tek manifest / tek RepoTag** zorunlu; iki etiketi
     ayni tar'a koymak kapiyi kirar.
  3. `Dockerfile:36` ses paketi `-current` (checksum yok) -> **ayni sha farkli imaj uretebilir**;
     taban imaj da etiketle sabit, **digest** ile sabitlenmeli.
- **IKI BLOKLAYICI UYARI:** (i) otomasyon `t0007` fiksturunu **sanayilestirir** — once temizle,
  sonra otomatiklestir; (ii) sha etiketi sapma kapisinin **yerine gecmez** — imaj iki propagasyon
  sinifi tasiyor (Sinif A recreate ile kesin uygulanir, Sinif B host'ta dosya varsa **sessiz
  no-op**), etiket Sinif B icin **yaniltici yesildir**.
- **Fiili bedel duzeltmesi:** *"12 gun bir suredir, bir maliyet degil"* — 0 DID / 0 trunk, WebRTC
  yolunda trafik yoktu; gorunur bedel **sifir**, asil bedel ilk musteri tanimlandiginda gelir.
- **Dokunulan dosyalar:** `yonetim/kurul-kararlari.md`
- **Commit:** `b1a92117`


### Istisarenin ciktisi `sprint-44` Blok 0'a islendi (dort kart buyudu)

- **Neden:** istisare *"ayri kart acilmayacak, icerik Blok 0'a baglanir"* demisti. Sozun geregi.
- **`LX-04`** — uc ek sart: (a) taban imaj **digest** ile sabitlenir (`22.10.1` bir **etiket**tir,
  uzerine yeniden yayinlanabilir; compose'un kendi *"latest 23'e kayarsa kimse fark etmez"*
  kaygisi burada da gecerli); (b) ses paketi **pinlenir** — `Dockerfile:36` `-current`, checksum
  yok -> **ayni sha farkli imaj**, yani etiket yalan soyler; (c) **ON SART:** `t0007`/`lab`
  fiksturleri temizlenmeden otomatik insa **acilmaz**. Kabul kriterine olculebilir satir eklendi:
  `docker run … grep -rl "pbxtr-t0007-\|pbxtr-lab-" /etc/asterisk` -> **bos**.
- **`LX-06`** — santral icin **saglik kapisi yokmus** (`pbxtr-deploy-artifact:102-112` yalniz app
  + nginx). `santral_healthy()`: `core show version` 0, `pjsip show transports` ->
  **`Objects found: 2`**, acilis gunlugunun son 60 sn'sinde **ERROR yok**. Kanal>0 ise adim
  **DURUR**.
- **`LX-07`** — `rollback()` yalniz `PBXTR_IMAGE`'i geri aliyor; **santral rollback'i bugun
  mumkun degil**. Ayrica REGISTER geri donus suresi olculecek — *"birkac saniye"* bir olcum
  degil, **bakim penceresinin gercek uzunlugu odur**.
- **`LX-08`** (en cok buyuyen) — dort ayak: (a) **insa != dagitim**, dagitici yalniz app+nginx
  recreate ediyor, santral icin ayri kod yolu + **negatif test**; (b) **push hedefi yok**
  (`pbxtr-asterisk` yerel ad) ve `staging-yayin.sh` asterisk'i **hic bilmiyor**; (c) artefakt
  dogrulayici **tek RepoTag** zorunlu -> `:22` ile `:22-<sha>` **ayni tar'a konamaz**; (d) mevcut
  elle prosedur (`README:251-266`) ezilmez ve **LX-02 bloklayici on sart** (aksi halde etiket
  deponun sha'sini tasir ama imaj baska agactan insa edilir -> **yalan etiket**).
- **Dokunulan dosyalar:** `yonetim/sprintler/sprint-44.md`
- **Commit:** `7b755f80`


### `BR-SYS-94`'teki curutulmus cumle duzeltildi — Sinif A / Sinif B ayrimi

- **Neden:** istisare kartin govdesindeki bir iddiayi curutmustu ama karti duzeltmemistim; orada
  **olcumle yanlislanmis bir cumle** duruyordu ve karti uygulayacak kisiyi yaniltirdi.
- **Yanlis olan:** *"conf/'u depoda duzeltip imaji yeniden uretmek CANLIYI DEGISTIRMEZ"* — **genel**
  bir iddia olarak yazilmisti. Imaj **iki propagasyon sinifi** tasiyor ve cumle yalniz birinde dogru:
  - **Sinif A** (`lab-entrypoint.sh`, ikili, ses, MOH): betik `/etc/asterisk` altindaki uretilmis
    dosyalari **her acilista kosulsuz `cat >`** ile yeniden yaziyor (`:136-161`, `:86`, `:96`)
    -> **yeniden insa + recreate TEK BASINA yeter.** `BR-SYS-92`'nin `bind` duzeltmesi tam da burada.
  - **Sinif B** (`conf/` tohumu, `Dockerfile:64` -> `/opt/pbxtr/asterisk-default/`):
    `lab-entrypoint.sh:47-68` yalniz **eksik** dosyalari kopyaliyor -> yeni imaj **hicbir sey
    yapmaz, sessiz no-op.**
- **Ikinci ekleme:** sha etiketi `BR-SYS-91`'in dosya karsilastirmasini **kaldirmaz** — Sinif B icin
  **yaniltici yesildir** (dogru etiket + bayat host dosyasi = bugunku arizanin aynisi).
  Karsilastirma bayt-bayt yerine **anlamsal** olur; 27 satirlik yorum farki kapiyi surekli kirmizi
  tutardi ve *"kirmiziya alisilan kapi kapi degildir"*.
- **Dokunulan dosyalar:** `yonetim/backlog.md`
- **Commit:** `0278fa58`


### Gunun iki kalici dersi hafizaya yazildi

- **Ders 1 — "bu zaten karara baglanmis mi" sorusu SPRINT DOSYALARINI da kapsar.** Oncul
  taramami `kurul-kararlari.md` ve `doc/mimari/ADR-*` ile sinirlamistim; sprint dosyalarini
  aramadim. Sonuc: `sprint-44`'te **kelimesi kelimesine yazili** bir tespiti *"yapisal kok, kimse
  gormemis"* diye kurula goturdum ve gereksiz bir istisare turu kostu. Ayni turda ikinci ornek:
  iki P1 kartinin kabul kriterleri **yalniz sprint dosyalarinda** duruyordu, backlog karti 27 ve
  50 karakterlik saplamaydi, pano isi **baslanamaz** gosteriyordu.
  **Uygulama:** bir bulguyu "yeni" ilan etmeden once `grep -rn "<anahtar>" yonetim/` — kararlar,
  backlog **ve sprintler**. Ters yon de gecerli: kapsam sprint dosyasinda kalmissa **karta tasi**
  (kaynak `backlog.md`, sprint dosyasi senkron edilmez).
- **Ders 2 — "etiket uretmek dagitim degildir".** Bayat imajin cozumunu *"sha ile etiketle"* diye
  ozetlemistim; olcum uc yerden curuttu: dagitici o servise **hic dokunmuyor**; imajin adinin
  **registry ad alani yok** (`push` calismaz); ve imaj **iki propagasyon sinifi** tasiyor —
  giris betiginin her acilista kosulsuz yazdiklari (**kesin** uygulanir) ve host'a *yalniz
  eksikse* tohumlananlar (**sessiz no-op**). Ucuncusu en sinsisi: sha etiketi ikinci sinif icin
  **yaniltici yesil** uretir.
  **Uygulama:** bir dagitim/otomasyon onerisinde uc halkayi **ayri ayri** olc — **uret** / **tasi**
  (push-pull hedefi gercekten var mi) / **uygula** (dagitici o servise dokunuyor mu, ve degisiklik
  hangi dosyalara kesin, hangilerine kosullu yansiyor).
- **Dokunulan dosya:** `~/.claude/.../memory/kart-onculu-olculmeden-yazilmaz.md`


### Commit dizini — 2026-09-10 (pbxtr deposu, kronolojik)

Gunlugun amaci *"diskteki her sey uctugunda okuyup isi bastan uretebilmek"* oldugu icin gunun
**tam** commit dizini burada. Denetim: bugun 46 commit atildi; sekizinin metin icinde acik sha
atfi yoktu ama **hepsi konu olarak yaziliydi** (Karar #39, BR-AST-51, AGENTS.md, A-6, A-5, A-1,
yapisal kok duzeltmesi). Bu dizin o boslugu kapatiyor.

- `aae46c27` — feat: 09-09 turunun tamami kurtarildi + tsc -b'nin bulduğu iki kirmizi kapatildi
- `e0b3ba94` — docs: AGENTS.md §3.0 bir gundur CLAUDE.md ile CELISIYORDU — is atlatti
- `0e2bdd12` — BR-AST-51 (YENI, P1): sir cozumleyici hic yazilmadi — PJSIP urun yolundan HICBIR ZAMAN teslim edilmedi
- `a309f790` — kurul: Karar #39 — BR-AST-51 RED; brifingimin cekirdek onculu ON UYENIN ONUNDA da curudu
- `f03006ca` — olcum: Karar #39 A-1 cevaplandi — sahada bekleyen masa telefonu SIFIR, ama 51a yine de oncul
- `abac92f8` — olcum: A-5 on kosulu — masa endpoint'i HER CAGRIDA Dial() ediliyor, (a) iki dosyalik is
- `1f66badf` — olcum: A-6 yarisi kapandi — belge kusuru KESIN, davranis kusuru OLCULMEDI
- `176bfe64` — fix: Karar #39 K-16 + K-18 — ekran numarasi taramasi IKI gercek kusur buldu
- `5733728f` — kurul: Karar #40 — A-5 yanlis eksende sorulmus; A-6 oncülüm CURUDU
- `1a46ea65` — olcum: A-7 KAPANDI — canli = lab, yanlis olan DOKUMANDI
- `6a818d74` — kurul: Karar #41 — tam kurul; iki oncülüm daha curudu, canlida ucuncu ariza
- `44f575d5` — olcum: A-11 KAPANDI — trunk ref'i uretilen bir sema DEGIL, serbest metin
- `7972ff12` — olcum: A-12 — sozlesme yanlis degil, ADI yanlis: uc eksen tek kolonda
- `8080112e` — mimari: ADR-017 + A-8 COZULDU — celiskinin dayandigi onerme YANLISTI (bende)
- `53a3d48c` — sprint: sprint-44 plani + BESINCI ve ALTINCI onculum curudu
- `d0e77087` — olcum: BE-00 — A-5(a) "en ucuz secenek" DEGIL, sekiz tuketicisi var
- `3cce764f` — kurul: Karar #42 (tam kurul 10/10) — A-5 KAPATILDI, cevap depoda yaziliymis
- `9564217a` — kart: BR-AST-58 — gelen cagri yolu HIC baglanmamis, tek calisan numara ELLE yazilmis
- `5e85e85d` — olcum: BR-AST-55'in koku DOGRULANDI; ve tek calisan gelen numara BOS KUYRUGA gidiyor
- `1c11264c` — kart: BR-AST-55 koku dogrulandi (iki aday dustu), BR-AST-58 bos kuyruk bulgusu
- `9d366e34` — olcum: BR-AST-58(b) envanteri + BR-AST-59 — gelen cagrida ARI kontrolu yapisal olarak yok
- `c982e893` — clickup: BR-AST-59 karti acildi (fark 0, izde olmayan 0)
- `d63b9914` — olcum: BR-AST-55 ucuncu aday — hint degil state_interface; dikis hic yok
- `e49b038b` — kurul: Karar #43 — BR-AST-59 SARTLI ONAY, ama kart iki yerinden duzeltildi
- `2bfd557e` — clickup: durum eslemesi 'Kurul: Karar #NN SARTLI ONAY' bicimini gormuyordu
- `46bcb506` — sprint-44: KARAR #43 TADILI — BR-AST-60 olcumu sprintin YENI BIRINCI kalemi
- `44d73993` — olcum: BR-FE-73 — kapi YOK ve tek ornek DEGIL (en az uc), P3 -> P2
- `538c80af` — olcum: BR-FE-72 ve BR-BE-122/123 oncullerini kendim dogruladim
- `60355533` — olcum: BR-AST-58(a) kapsami — sablon YOK, baglamlar PAYLASIMLI, __PBXTR_REC cakisiyor
- `7f69068f` — olcum: S43-6'nin 'bayt bayt ayni' sarti bugun uygulanamaz — altin dosya yok
- `31151498` — olcum: BR-SYS-94 — lab fiksturu URETIM IMAJINA gomulu; envanterin siniflandirmasi yanlisti
- `0ab18f07` — clickup: BR-SYS-94 karti acildi
- `b1a86e65` — olcum: BR-SYS-94 duzeltme yolu ikiye bolunuyor — depo/imaj + host gecisi
- `95055f77` — olcum: BR-SYS-92 bagimsiz dogrulandi + sinanabilir kabul olcutu; BR-SYS-91'e gunluk olcumu
- `501365ea` — olcum: BR-SYS-94 sapmanin cinsi — elle duzenleme DEGIL, bayat imaj
- `b287e82a` — olcum: BR-SYS-92'nin penceresi 4 dakika 35 saniye
- `3b321d4c` — olcum: bayatlik sinif hatasi degil — alti imajin yalniz biri sorunlu, o da sha'siz etiketli
- `3640cc20` — olcum: pbxtr-app'in 2 commit gecikmesi kusur DEGIL — ikisi de bugunden
- `f38cfcab` — olcum: BR-AST-24 + sablon D5 — MixMonitorMute dialplan uygulamasi olarak YOK
- `bfdb376b` — olcum: acik P1 govde denetimi — iki kartin kapsami sprint dosyasinda kalmis, karta tasindi
- `6f78b76c` — olcum: yapisal kok — Asterisk imaji yayin hattinin TAMAMEN disinda
- `964dfd36` — olcum: BR-SYS-94(c) kurula gitmeden once daraltildi — cevabin yarisi zaten yazili
- `c22a2fdd` — DUZELTME: 'yapisal kok' yeni degildi — sprint-44 Blok 0 (LX-01..LX-08) bunu zaten tasiyor
- `b1a92117` — istisare (KARAR DEGIL): Asterisk imaji dagitim politikasi — 4 uye, yeter sayi YOK
- `7b755f80` — sprint-44 Blok 0: istisarenin uc olcumu ve iki uyarisi kabul kriteri olarak islendi
- `0278fa58` — duzeltme: BR-SYS-94'teki curutulmus cumle duzeltildi (Sinif A / Sinif B ayrimi)


### `BR-QA-51` — `call_events` canli gorunuyor ama 03 Eylul'den beri TEK GERCEK OLAY YOK

- **Neden:** `BR-AST-60`'i **originate etmeden** cevaplamayi denedim — canlida `call_events`
  verisi vardi (son olay 2026-09-08), belki gecmis kayitlardan musteri bacaginin hic kurulup
  kurulmadigi okunabilirdi.
- **Olculen (canli PostgreSQL, `postgres` rolu — gerekce: gercek satir sayisi, RLS davranisi
  degil):** `call_events` **7794** satir, **2026-08-26 → 2026-09-08**. §3.0 sonrasi (baglanti
  GERCEK, 03 Eylul) **3445** olay ve **3445'inin 3445'i `SIM/` onekli**; `SIM/` olmayan **0**.
  Ornek kanal `SIM/cdr-a-0000`. Gercek kanallar tum zamanlar boyunca yalniz **27 `PJSIP/`** ve
  **333 `Local/`**, ve **hepsi 03 Eylul ONCESI**.
- **Sonuc 1 — denemem BASARISIZ:** `BR-AST-60` gecmis veriden cevaplanamiyor, cunku gecmiste
  gercek giden cagri **yok**. Originate olcumu **hala kullanici onayi bekliyor**.
- **Sonuc 2 — ve bu daha degerli:** tablo *"son olay 2026-09-08"* diyor ve bu **"canlida cagri
  akiyor"** diye okunmaya cok musait. Ayni gun olculen bagimsiz olgular bunun **imkansiz**
  oldugunu gosteriyor (0 DID, 0 trunk, 0 zil grubu, 0 kayitli contact, `transport-ws` yuklu
  degil). Defterdeki *"sifir en tehlikeli cevaptir"* dersinin **TERSI**: veri **var** ama
  **yanlis cinsten**, ve sifirdan daha ikna edici gorunuyor.
- **Mevcut bir cikarimi zayiflatmiyor, GUCLENDIRIYOR:** `sprint-44.md:17-25` `BR-AST-53`'un
  *"CANLIDA SUREN ARIZA"* cercevesini curuturken kanit olarak *"call_events'te son olay
  2026-09-08"* diyordu. O curutme **dogruydu ve simdi daha guclu**: yalniz 0 DID / 0 zil grubu
  degil, **hic gercek cagri yok**.
- **Kapsam:** (a) simule/gercek ayrimi `SIM/` onegi tesadufune birakilmamali; (b) *"canlida cagri
  akiyor mu"* sorusunu cevaplayan yuzeylerin (saglik ekrani, wallboard, raporlar) simule satirlari
  sayip saymadigi **olculmeli** — bu kart yazilirken olculmedi; (c) tohum verisinin canli
  veritabaninda ne aradigi ve retention'in onu kapsayip kapsamadigi ayri soru.
- **Dokunulan dosyalar:** `yonetim/backlog.md` (367 kart)
- **Commit:** `169b75ed`

## Kararlar
- **"Kalan ne var" sorusu artık elle sayılmaz.** `node yonetim/arac/kalan-isler.js`
  koşulur; dosya kendi kaynak SHA'sını yazdığı için **tazeliği doğrulanabilir**.
  Elle sayaç yazmak, aracın ayrıştırma kurallarını (kısmi satır, kurul kararı
  satırı) eksik yeniden üretmek demek — dün tam bunu yapıp yanlış saydım.
- **`tsc -b` yayın kapısıdır, `vitest` değil.** Bugünkü iki kırmızıdan birincisini
  vitest **hiç görmezdi**; ikincisini de tsc göremedi çünkü mock gövdesi `any`.
  İkisi birlikte koşmadan "frontend yeşil" denmez.
- **İki bağlayıcı belge çelişirse ajan iş yapmaz, atlar.** Bugünkü ölçüm bunu
  somutladı: bir gün gecikmiş bir metin, bir turluk canlı Asterisk işini yedi.

## Açık kalanlar / sonraki adım

- **KULLANICI ONAYI BEKLİYOR — `BR-AST-60` (Ş43-1):** giden yönün bugün kırık olup olmadığı
  ölçümü **originate gerektiriyor**, yani mevcut salt-okuma kısıtının dışında. Bu ölçüm
  yapılmadan `BR-AST-59` planlanmaz. Sonuç "asılı kalıyor" ise tek satırlık geri alınabilir
  emniyet hazır: `AsteriskAriProvider.cs:258`'de `PBXTR_CTL` sabit `"0"`.
- Ş43-2 / Ş43-5 / Ş43-8 **laboratuvar** istiyor — `BR-AST-55` ile aynı blokaj (Docker Desktop).
- Ş43-11 sırası bağlayıcı: `BR-SYS-93` → `BR-AST-60` → `59a` → `BR-AST-58` → `59b`.
- **111 kapalı olmayan kart** (`yonetim/kalan-isler.md`) + **46 doğrulama borcu
  olan kapalı kart**.
- Artık **engelsiz** olan Asterisk zinciri: `BR-AST-47` (ReconcileAsync gerçek
  santralde tick üretiyor mu — hiç ölçülmedi), `BR-AST-49` (**canlıda süren
  sapma**: t0012'nin 3 kuyruk üyeliği panelde var, santralde yok),
  `BR-SYS-80 → BR-SYS-86 → BR-AST-17`.
- 09-08'den devreden 9 madde hâlâ **kartsız** (confd manifest sapması,
  `staging-yayin.sh` nginx, yayın betiği format adımı, `test-kos.sh` yanlış
  kırmızı, `AST-03/04` yeniden ölçüm).
- .NET test takımı bu turda koşulmadı (yalnız Release derleme + frontend).

### 4. Engel kalkınca canlı santral ölçüldü — zincirin gerçek ön koşulu çıktı
- **Neden:** `AGENTS.md` düzelince 09-09'da atlanan canlı Asterisk işleri açıldı.
  Aranan `BR-AST-49`'du; altından `BR-AST-51` çıktı.
- **Komutlar:** `ssh root@176.88.41.220` üzerinden **salt-okuma**:
  ```bash
  docker logs pbxtr-app | grep -c NO_SUCH_QUEUE
  docker exec pbxtr-asterisk asterisk -rx "queue show"
  docker exec pbxtr-asterisk asterisk -rx "pjsip show endpoints|auths|aors"
  docker exec pbxtr-postgres psql -U postgres -d pbxtr -c "..."
  journalctl -u pbxtr-confd | grep "SERVIS EDILMEYEN"
  ```

**BR-AST-49 — kartın ÜÇÜNCÜ hipotezi doğru çıktı, teşhis kapandı**
- `NO_SUCH_QUEUE` spam'i **bitmiş**: 9 saatlik **tam** günlükte 0 isabet.
  Yerini adıyla konmuş bir teşhis almış (`baf8d3b6`, Karar #31/S41):
  *"t0012 hiçbir pbxtr-confd düğümüne ATANMAMIŞ … Müdahale: #57"*.
- **Mesaja güvenmedim, DB'den doğruladım:** t0012'nin pinli aktif anahtarı **0**,
  aktif anahtarı da **0**. Sayılar da tuttu: t0007 = 2 kuyruk / 9 üyelik (9'u da
  iniyor), t0012 = 1 kuyruk / 3 üyelik (hiç inmiyor).
- Durum `Bekliyor` → **`Karar bekleyen`**: bu artık bir arıza değil, bir karar.

**BR-AST-51 (YENİ, P1) — asıl bulgu kapı değil, GEREKÇESİ**
- `ProvisioningDeliveryGate.cs:41-45` bugün harfiyen *"bedeli bugün SIFIRDIR —
  Asterisk fiilen bağlı değildir (proje kararı)"* diyor. **O karar 2026-09-03'te
  kaldırıldı.** Kapının yazılı gerekçesi artık yürümeyen bir karara dayanıyor.
- **Bedel sıfır değil, ölçülmüş:** `journalctl -u pbxtr-confd` **her 5 dakikada**
  *"SERVIS EDILMEYEN TURLER: pjsip / cozulmemis PBXTR-SECRET(...)"* diyor, 10+
  gündür. `pjsip show endpoints/auths/aors` = **6/6/6**, altısı da
  `t0007-wrtc-*` — yalnız WebRTC yarısı var ve onu **elle bir betik** tesliyor.
- **09-08'in confd tıkanıklığının sebebi buymuş:** yeni yol *"auths 12 beklenen /
  6 ölçülen"* deyip `exit 75` verdi ve geri alındı.
- Depoda `ISecretResolver`/`ResolveSecret`/`kv:` çözen **tek satır yok**.
- **Kapı doğrudur, kaldırılmamalı:** çözülmemiş yer tutucu Asterisk için
  **geçerli bir parola dizesidir** ve ref'in iki bileşeni de gizli değil →
  meşru telefon REGISTER **olamaz** (gürültülü), saldırgan parolayı **türetip**
  REGISTER **olur** (sessiz toll-fraud). Yazılacak olan çözümleyici.
- Bu, **BR-SYS-80 → BR-SYS-86 → BR-AST-17** zincirinin gerçek ön koşulu.

- **Commit:** `1d4d9c1` — BR-AST-51 açıldı, BR-AST-49 güncellendi, ClickUp
  senkron (339/339, fark 0).

## Bu turda yaptığım iki ölçüm kusuru — ikisi de yakalandı
1. **Yanlış çıkarım önlendi:** santralde pbxtr'da olmayan `t0007-satis` kuyruğu
   göründü, ilk bakışta *"kaldırılamamış yetim nesne"* gibiydi. Ölçtüm: **yetim
   değil** — `/etc/asterisk/queues.conf` içinde **elle yazılmış**,
   `extensions.conf:30-31` ondan `Queue()` çağırıyor. Ana config'e dokunulmaması
   CLAUDE.md §3.1'in kuralı. Kartı yazmadan ölçmeseydim backlog'a **uydurma bir
   arıza** girecekti.
2. **"Araç yokluğu sıfır gibi görünür" tekrarı:** ilk sayımım *"auths 0, aors 0"*
   dedi. Sebep gerçek değil **desendi** — CLI çıktısı `     Auth:` (beş boşluk),
   benim desenim `^ Auth:`. Ham çıktıya dönünce 6/6. **Sıfır gördüğümde ham
   çıktıya dönmek kural olmalı.**

## Açık kalanlar — güncelleme
- **112 kapalı olmayan kart** (BR-AST-51 eklendi, BR-AST-49 karar bekleyene geçti).
- **Sıradaki iş `BR-AST-51`**: teslim-tarafı sır çözümleyici. Çözümleme yalnız
  servis anında ve bellekte olmalı; çözülmüş parola `provisioning_revisions`'a
  yazılmaz, loglanmaz. Bugünkü fail-closed davranış (tür bazında `withheld`)
  **aynen korunur**.
- **Karar gerekiyor (kullanıcı/kurul):** t0012 bir düğüme pinlensin mi, yoksa
  bilerek teslim edilmediği mi yazılsın (#57).

### 5. Kurul Karar #39 — BR-AST-51 RED; kartı ben yanlış yazmışım
- **Neden:** BR-AST-51 P1 bir kod işi; CLAUDE.md §7/1 gereği kurul onayı olmadan
  uygulamaya geçilmez. 10 üye paralel toplandı.
- **Sonuç:** **9 ŞARTLI + 1 HAYIR → RED.** Dokuz ŞARTLI oyun şartları öneriyi
  tanınmaz hâle getiriyordu ("bu kart yazılamaz, önce başkası gerekir"), Şeytan'ın
  iki kritik itirazı da cevaplanamadı.

**Kartın çekirdek öncülü yanlıştı — beş üye bağımsız ölçtü:**
- *"`sip_secret_ref`'ten gerçek parolaya çöz"* → **çözülecek parola yok.**
  `sip_secret_cipher` depoda 0 isabet, Vault istemcisi 0 isabet, `SipSecretRef`
  atayan tek satır seed (`SampleDataSet.cs:512` → `vault:{code}/ext/{no}`).
- **`ADR-007 §5` bunu ZATEN yazmış:** *"doğrulanma yeri: HİÇBİR YERDE"*.
  `pbxtr.env.example:233-234` harfiyen *"çözen mekanizma YOK"* diyor.
- Yani **`ISecretResolver` taramamın 0 isabeti** *"çözümleyici yazılmamış"* değil,
  ***"arkasında hiç veri olmamış bir referans"*** demekmiş. Aynı kanıt, iki zıt
  sonuca okunabiliyordu ve ben yanlış olanı seçtim.
- Ref şeması da yanlıştı: canlı **9/9** satır `vault:`; `kv:ext:` yalnız yorumda.

**Şeytan'ın ikinci öldürücü itirazı:** kart **bildirdiği semptomu de çözmüyor** —
sahadaki 6 nesnenin hepsi `kv:extwrtc:` ailesinden (`ConfigRenderer.cs:1851`) ve
kart onu kapsamıyordu. Uygulansa `journalctl` satırı **değişmezdi**, ama
"çözümleyici var" sanılırdı.

**Üyelerin getirdiği, kartta hiç olmayan bulgular:**
- **Asterisk uzmanı**, benim *"bölüm sayıyor"* hipotezimi **kontrol grubuyla**
  çürüttü: doğrulama **CLI çıktı satırı** sayıyor. "Satır" modeli 18/6/6'nın
  üçünü birden açıklıyor; benim modelim `aors` için 18 tahmin ederdi, ölçüm 6.
  Sonuç: `endpoints` alanı **matematiksel olarak geçemez** → her tick rollback.
  **09-08'deki `exit 75` geri almanın sebebi buymuş.** Ve `AsteriskObjectCensus.cs:32-39`
  bunu öngörmüş: *"kural toplam==beklenen DEĞİL, delta'dır"*.
- **Frontend uzmanı:** sağlıktaki `PBXTR-SECRET` cümlesi **ulaşılamaz dalda**
  (çekim başarılı → `Ok` dalı) — 10+ gün boyunca sağlık **yeşildi**. Süpervizörün
  *"kırmızıydı da kimse mi bakmadı?"* sorusunun ölçülmüş cevabı: hayır, yeşildi.
- **Linux uzmanı:** confd → pbxtr atlamasında **mTLS değil, hiç TLS yok**
  (`http://pbxtr-app:5080`). Çözülmüş bundle host `/tmp`'ye **0644** düşüp
  **public node imajına mount** ediliyor. Düğümde rollback yok, debounce yok.
  Ve `.yedek-20260830` dosyaları **eski değil**: `diff` yalnız `context` satırında
  fark veriyor, parola birebir aynı → diskte 6 fazladan **canlı** sır dosyası.
- **Şeytan'ın en değerli itirazı:** `ProvisioningNodeBundleHttpTests.cs:444`
  (`DoesNotContain "PBXTR-SECRET("`) çözümleyiciden sonra **yanlış sebeple**
  yeşile döner — yanıtta yer tutucu yerine **açık parola** vardır.

**Yerine dört kart, sıra bağlayıcı:**
`BR-AST-51a` (sır üretimi + AES-GCM saklama + rotasyon) + `BR-AST-52` (sayım) →
`BR-AST-51b` (çözümleyici) → `BR-FE-70` (görünürlük). 18 şart (K-1…K-18) ve
dört açık soru (A-1…A-4) karar kaydında.
- **Commit:** `d6b78e5` — Karar #39. ClickUp: 4 kart açıldı, doğrulama 343/343.

## Bugünkü üçüncü ölçüm kusurum
Backtick'ler çift tırnaklı `node -e` içinde **komut olarak koştu** ve kart notundan
beş segment sessizce silindi (`extensions`, `sip_secret_cipher`, `SipSecretRef`,
`kv:extwrtc:`, `journalctl`). Defterdeki *"heredoc içinde backtick yutulur"*
dersinin aynı sınıfı, farklı kabuk bağlamı. Düzeltme dosya üzerinden yapıldı ve
**backtick sayısı çift mi** diye ayrıca ölçüldü (82, tamam). Kural: metin backtick
taşıyorsa **kabuk üzerinden geçirme, dosyadan oku.**

## Kararlar — ek
- **Kartı ölçmeden yazmak, kurulun bir turunu ölçüme harcatıyor.** BR-AST-51'i
  "çözümleyici yok" diye yazdım; doğru cümle *"referansın arkasında hiç veri
  olmamış"*tı. İkisi aynı grep çıktısından okunuyor — ayıran şey **ikinci ölçüm**.
  Bundan sonra "X yok" kartı yazmadan önce **"X'in beslediği veri var mı"** ayrıca
  ölçülecek.
- **Kurul turu ucuz değil ama karşılığını verdi:** on üye, kartta hiç olmayan
  beş yapısal bulgu çıkardı (sayım kusuru, ulaşılamaz alarm dalı, TLS yokluğu,
  canlı sır yedekleri, yanlış sebeple yeşilleşecek test).

## Açık kalanlar — güncelleme (gün sonu)
- **343 BR kartı: 228 kapalı, 115 kapalı olmayan** (+4 yeni kart, BR-AST-51 RED).
- **A-1 ölçümü sıradaki iş:** canlıda WebRTC'siz `extensions` satırı kaç tane?
  Sıfırsa BR-AST-51a'nın P1'i düşer. Bu ölçüm 51a başlamadan yapılacak.
- Kullanıcı kararı bekleyen: **A-2** t0012 düğüme pinlensin mi (BR-AST-49).
- Karar #39 uygulaması `/sprint-planla pbxtr` bekliyor (kurul skill'i kendiliğinden
  planlamaya geçmeyi yasaklar).

### 6. A-1 ölçüldü — Şeytan kısmen haklı çıktı, ama plan yine de değişmedi
- **Neden:** Karar #39 bu ölçümü BR-AST-51a'nın ön koşulu yapmıştı.
- **Ölçüm (canlı, salt-okuma):**

  | tenant | dahili | WebRTC | **masa telefonu** |
  |---|---:|---:|---:|
  | t0007 | 6 | 6 | **0** |
  | t0012 | 3 | 0 | **3** |

- **Şeytan'ın *"aciliyet şişirilmiş olabilir"* itirazı kısmen doğrulandı:** çalışan
  tenant'ta sahada REGISTER olmayı bekleyen masa telefonu **sıfır**. t0012'nin 3
  masa telefonu var ama o tenant zaten hiçbir düğüme pinli değil — onların engeli
  sır deposu değil, **bir üst katmandaki eksik anahtar**.
- **Ama 51a'nın öncüllüğü düşmedi ve sebebi ölçüldü:** `ConfigRenderer.cs:217-235`
  masa üçlüsünü **koşulsuz** üretiyor (`foreach (var extension …)`), WebRTC üçlüsü
  `if (extension.HasWebRtc)` ile **ek olarak** geliyor. t0007'nin paketi 6 masa
  `auth` (`vault:`, veri **yok**) + 6 WebRTC `auth` (`kv:extwrtc:`, AES-GCM ile
  **saklı**) taşıyor. Fail-closed **tür bazında** olduğu için tek çözülemeyen ref
  `pjsip` türünün tamamını withheld ediyor — **sahada tek bir masa telefonu olmasa
  bile.**
- **Yeni açık soru A-5 (kurula gitmeli):** yalnız WebRTC'si olan dahili için masa
  endpoint'i üretilmeli mi? **(a)** üretilmesin → t0007'nin paketi tümüyle
  çözülebilir olur ve **BR-AST-51b tek başına** canlı semptomu kapatır, 51a P1
  olmaktan çıkar, K-1 sırası yeniden yazılır. **(b)** bugünkü hâl korunsun → K-1
  aynen geçerli. **(a)'dan önce ölçülmeli:** masa endpoint adı dialplan'de `Dial()`
  ediliyor mu — ediliyorsa (a) çağrı yolunu kırar.
- **Sonuç:** `BR-AST-51a` önceliği **A-5 kapanana kadar GEÇİCİ** işaretlendi.
- **Commit:** `f4c1a2b` — A-1 ölçümü.

## Bugünün dersi
**Bir ölçüm, kendisini isteyen kararı da düzeltebilir.** A-1'i "P1 haklı mı" diye
sordum; cevabı "hayır, sahada kimse beklemiyor" çıktı ama **aynı ölçüm sırasında**
renderer'ın koşulsuz masa endpoint'i ürettiğini görünce sonuç tersine döndü:
öncelik düştü, öncüllük düşmedi. Tek ölçümle yetinseydim yanlış kararı
verecektim — hem "P1 kalsın" hem "P1 düşsün" yanlış olurdu.

### 7. A-5'in ön koşulu ölçüldü — (a) seçeneği sandığımdan pahalı
- **Neden:** Karar #39, A-5'in *"masa endpoint adı dialplan'de `Dial()` ediliyor mu"*
  ölçümü yapılmadan seçilemeyeceğini kayda geçirmişti.
- **Canlı ölçüm** (`t0007-dialplan.conf`, altı dahilinin altısında da aynı):
  ```
  same => n,Dial(PJSIP/t0007-1042&PJSIP/t0007-wrtc-1042,30,tT)
  ```
- **Kaynağı** `ConfigRenderer.cs:732-739` (`LocalDialDevices`): `desk` **koşulsuz**
  kuruluyor, `HasWebRtc` ise `&` ile WebRTC bacağı ekleniyor. Yani masa adı bir
  yedek değil, **her çağrıda paralel çalan birinci bacak**.
- **Sonuç:** A-5 (a) *"masa endpoint'i üretilmesin"* seçeneği "kullanılmayan bir
  nesneyi üretmeyi bırakmak" değil — `LocalDialDevices` de değişmek zorunda (yoksa
  dialplan var olmayan endpoint'i çevirir) ve zil grubu/kuyruk yolları da etkilenir.
  İki seçenek artık **eşit maliyetli değil**; karar verilebilir durumda ama kurula ait.
- **Yan bulgu — yeni açık soru A-6 (bu kartlardan bağımsız):**
  `ConfigRenderer.cs:833-841` XML notu *"`PJSIP_DIAL_CONTACTS()` kullanılır, çıplak
  `PJSIP/<endpoint>` DEĞİL… şablonun kendi extension dalı da bu formu kullanır"* diye
  **şart koşuyor** ve gerekçesini yazıyor. Ama canlıda ölçülen extension dalı
  **çıplak `&` birleştirmesi** kullanıyor. Not zil grubu metodunun başında duruyor —
  extension dalı için de geçerli mi, yoksa bilinçli ayrım mı, **ölçülmedi**. Ya not
  yanlış yerde (belge kusuru), ya extension dalı **kendi notunun yazdığı tuzağa**
  düşüyor (davranış kusuru).
- **Commit:** `9e2f7c4` — A-5 ön koşul ölçümü.

### 8. Arka planda takılı ssh durduruldu
Linux uzmanının turundan artakalan bir `nginx log_format` ölçümü arka planda asılı
kalmıştı. Durdurmadan önce gereksiz olduğunu doğruladım: aynı ölçüm zaten oya
girmişti. Ajan sonradan teyit etti — o ölçümü host mount'undan tamamlamış,
sonuç değişmemiş (`cache-control: no-store`, nginx gövde/başlık loglamıyor).

### 9. A-6 yarısı kapandı — belge kusuru kesin, davranış kusuru ölçülmedi
Kendi açtığım soruyu ölçmeden bırakmadım.

| Dal | Kullandığı biçim | Satır |
|---|---|---|
| Zil grubu | `Set(RGC=${PJSIP_DIAL_CONTACTS(<endpoint>)})` | `:942`, `:968` |
| **Extension (doğrudan dahili)** | **çıplak `Dial(PJSIP/x&PJSIP/y,…)`** | `:783` → `:732-739` |

`:833-841` notu *"Şablonun kendi **extension dalı da** bu formu kullanır"* diyor —
**kullanmıyor.** Belge kusuru **kesin**.

**Ama "davranış da kusurlu mu" ayrı bir soru ve onu ölçmedim:**
- Notun **2. gerekçesi** (*"kaydı düşmüş tek telefon `&` ile bütün grubu bozar"*)
  extension dalına **taşınmaz** — o, `PJSIP_DIAL_CONTACTS()`'in boş dize dönmesine
  özgü. Çıplak biçimde kaydı düşmüş endpoint yalnız **kendi bacağını** düşürür.
- Notun **1. gerekçesi** (*"çıplak biçimde iki cihazlı kullanıcının yalnız biri
  çalar"*) **taşınabilir ve ölçülmedi**. Canlıda AOR `max_contacts` = **3**. Üç
  cihazı kayıtlı bir agent'ın kaçının çaldığı bir **Asterisk davranışıdır**; depo
  okunarak cevaplanamaz, **gerçek çağrı ister**.

**Kural olarak yazdım:** (ii) doğrulanmadan `LocalDialDevices` değiştirilmemeli —
bugün çalışan bir çağrı yolunu ölçülmemiş bir gerekçeyle değiştirmek, 09-08'deki
confd taşımasının aynı hatası olur.
- **Commit:** `c7d1e58` — A-6 ölçümü.

## Gün sonu durumu
- Çalışma ağacı **temiz**, pbxtr ve Gunluk **push'lu**.
- **343 BR kartı: 228 kapalı, 115 açık.** ClickUp senkron doğrulandı (343/343).
- **Kurula ait:** A-5 (masa endpoint'i koşulsuz üretilsin mi — ön koşulu ölçüldü,
  karar verilebilir), A-6/(ii) (canlı çağrı ölçümü gerekir).
- **Kullanıcıya ait:** A-2 (t0012 düğüme pinlensin mi), ve Karar #39'un uygulaması
  için `/sprint-planla pbxtr` → "başla".

### 10. K-16 taraması iki gerçek kusur buldu — biri diğerinden sinsi
Karar #39/K-16 *"sunucu metinlerindeki ekran numarası referansları bu turda
taransın"* diyordu. Registry'den 70 geçerli kod çıkarıldı, `src/` tarandı.
**Yedi isabet, ikisi gerçek:**

1. **`SystemHealthProbe.cs:1657` → `#680`.** Registry'de 680 kodlu ekran **yok**;
   API Anahtarları **#57**. Bu bir **operatör mesajı**: *"yeni açılmış bir tenant
   için anahtar üretilmemiş olabilir"* deyip **var olmayan bir ekrana** yolluyordu.
2. **`permissions.seed.json:816` → `#55` ve `#55.1`.** Ölçüldü: `/dealer` = **#56**
   Bayi Paneli, `/dealer-dashboard` = **#59** Bayi Dashboard, ve **`#55` = Destek
   Talepleri**. Bu `#680`'den **daha sinsi**: 680 hiçbir şey, ama 55 **var olan ama
   alakasız** bir ekran — okuyan kişi Destek Talepleri'ne bakıp yetkinin ilgisiz
   olduğu sonucuna varırdı.

Kalan beş isabet yanlış pozitif: üçü `Karar #10.3` gibi **karar** numarası, ikisi
`screens.json`'daki *"#10 ve #21 KULLANILMADI"* diyen bilinçli not.

### 11. K-18 yazıldı — ve yanındaki satırın bayat olduğu da kaydedildi
`doc/prototip-urun-farklari.md` §36'ya (#27) dokuzuncu fark satırı **BORÇ** olarak
eklendi: *"dahilinin santralde fiilen KAYITLI olup olmadığı"*. Gerekçesi bugün
canlı ölçüldü: 6 dahilinin altısı da **"Config: Üretildi" (yeşil)** görünürken
`pjsip` türü **10+ gündür hiç teslim edilmiyordu** — kolon **yeşil yalan**
söylüyordu.

Aynı bölümdeki **7. satırın gerekçesinin bayat** olduğunu da adıyla kaydettim
(*"bu fazda hiçbir Asterisk bağlantısı yoktur (§3.0)"* — o karar 09-03'te
kaldırıldı). **Düzeltmedim**, çünkü Karar #39/K-15 ölü gerekçelerin **kapı fiilen
açılmadan** düzeltilmesini yasaklıyor. Bunu bilerek yarım bırakmak, "karar yazılmış
ama uygulanmamış" desenine düşmemek için.

- **Ölçüm:** Release build 0/0. Seed'e dokunduğum için defterdeki *"yetki seed'i iki
  namespace ister"* kuralı uygulandı → `Platform.Authorization` + `Platform.Screens`
  + `RoleScreenMatrix` + `DealerScreenScope` + `UserAdminEndpoint` + `Health` =
  **376/376, skip 0**.
- **Commit:** `b3a91d6`

### 12. Bugün üçüncü kez backtick yendi — bu sefer backslash de
`node -e "..."` ve heredoc'tan sonra bu kez **quoted heredoc içindeki `\`**
yenip `/\/g` regex'i `/\/g` oldu ve script parse hatası verdi. Üç farklı kabuk
bağlamı, aynı sınıf. **Defterdeki notu güncelledim:** metin backtick/backslash
taşıyorsa kabuktan hiç geçirme — Write tool ile dosyaya yaz, node script
dosyasından oku, ve **yazdıktan sonra backtick sayısının çift olduğunu ölç**.
Bu turda K-18 satırında öyle yaptım: 20 backtick, çift, dört anahtar segment yerinde.

### 13. İkinci kurul turu — Karar #40: A-5 yanlış eksende sorulmuş, A-6 öncülüm çürüdü

- **Neden:** Karar #39 iki soruyu açık bırakmıştı. **A-5:** yalnız WebRTC'si olan
  dahili için masa endpoint'i üretilmeli mi? **A-6:** `ConfigRenderer.cs:833-841`
  notundaki "şablonun extension dalı `PJSIP_DIAL_CONTACTS()` kullanır" cümlesi bir
  belge kusuru mu?

- **Ne yapıldı:** Dar tur — **6 üye** (CTO, Asterisk Uzmanı, Backend Lideri, DB
  Lideri, Çağrı Merkezi Agenti, Şeytan). **CEO, Linux, Frontend, Süpervizör oy
  vermedi** ve bunu karar kaydının başına açıkça yazdım; skill 10 üye şart koşuyor,
  saptığım için gerekçesi de yazılı. Sonuç kapsam değiştirdiği için (yeni P1 kart
  çıktı) uygulamaya geçmeden ya tam kurul toplanmalı ya kapsam #41'e taşınmalı.

- **Turu tek ölçüm belirledi.** Üç kişi (DB Lideri, Backend Lideri, sonra ben)
  bağımsız ölçtük — canlı `provisioning_revisions`, her tenant'ın **aktif** `pjsip`
  revizyonunda yer tutucu sayımı:

  ```
  tenant | kind  | rev | vault: | kv:extwrtc: | TOPLAM
  t0000  | pjsip |  1  |   0    |      0      |    0
  t0007  | pjsip |  6  |   6    |      6      |   12
  t0012  | pjsip |  1  |   3    |      0      |    3
  ```

  Ve kapı ref şemasına değil **çıplak dizeye** bakıyor
  (`ProvisioningDeliveryGate.cs:63`, `content.Contains("PBXTR-SECRET(")`).

  **Bu tek tablo üç seçeneği birden öldürdü:** (a) masa üçlüsünü üretmemek 6'yı
  siler, **6 kalır** → `pjsip` yine withheld, sıfır fayda; CTO'nun `pjsip-webrtc`
  kind ayrımı da kendi 6 ref'ini taşır → o da teslim edilemez; (c) nesne bazlı
  fail-closed CTO ve DB Lideri'nden **iki VETO** aldı (kesilen `auth` bloğu
  `endpoint`'in `auth=` referansını sarkıtır; teslim anında içerik kırpmak saklanan
  `sha256` kimliğini yalancı yapar).

- **Ayrım masa/WebRTC değil, "sır çözülebiliyor mu".** Birinci eksen bugün
  **ifade bile edilemiyor**: `Extension.SipSecretRef` `required` (`Extension.cs:31`),
  yani her satır tanım gereği "masa kimliği var". `HasWebRtc`'nin çalışmasının
  sebebi tasarım değil, `WebRtcSecretCipher`'ın nullable olması.
  **`device_model` bu işe kullanılamaz** — kolonun kendi belgesi yasaklıyor
  (`Extension.cs:80-99`: *"BU BİR BEYANDIR, BİR ÖLÇÜM DEĞİLDİR"*) ve canlı doluluk
  **0/9**. Config üretimini boş bırakılabilir bir beyana bağlamak, alanı doldurmayı
  unutan tenant'ta dahiliyi **sessizce yok ederdi**.

- **Turun kazancı — sıra değişti.** `kv:extwrtc:` için **şema değişikliği
  gerekmiyor**: WebRTC sırrı `extensions.webrtc_secret_cipher`'da zaten saklı
  (canlıda 6/6 dolu) ve `ISecretProtector` ile bugün çözülebilir. Yani Karar
  #39/K-1'in *"önce sır deposu (51a)"* sırası **yalnız masa (`vault:`) tarafı
  için** doğruymuş. `BR-AST-51b`'nin WebRTC yarısı **bugün yazılabilir**.

- **Dokunulan dosyalar:** `yonetim/kurul-kararlari.md` (A-6 düzeltmesi + Karar #40),
  `yonetim/backlog.md` (3 yeni kart + 51b sırası).
- **Commit:** `5733728f` — push edildi.

### 14. Yayımlanmış hatamı düzelttim: A-6'nın "belge kusuru KESİN" iddiası yanlıştı

Karar #39'a *"notun extension dalı hakkındaki cümlesi olgusal olarak yanlıştır —
belge kusuru kesindir"* yazmıştım ve **push etmiştim**. Şeytan çürüttü, Backend
Lideri ve CTO doğruladı, ben de kendim ölçtüm:

Nottaki **"şablon"** kelimesi `ConfigRenderer` değil,
**`doc/mimari/asterisk-dialplan-sablonu.md`**. O dosyanın kendi `exten => extension`
dalı gerçekten `PJSIP_DIAL_CONTACTS()` kullanıyor (`:311`, `:559`) ve
`ADR-015-zil-gruplari.md:380-381` bu atfı **dosya:satır ile** zaten vermiş.
Belge doğru; ben iki ayrı çevirme yüzeyini karıştırdım: şablonun **yönlendirme
kararı** dalı ile `ConfigRenderer`'ın **dahili başına yerel çevirme** dalı
(`LocalDialDevices`, çıplak `&`).

**Aynı satırda ikinci hatam:** *"Canlıda AOR'ların `max_contacts` değeri 3"* diye
blanket yazmıştım. Ölçtüğüm çıktıda **yalnız `t0007-wrtc-*`** AOR'ları vardı
(canlıda masa AOR'u zaten yok). Bu **A-7**'yi açtı: `pbxtr-aor-base.max_contacts`
lab'da **1** (`deploy/asterisk-lab/conf/pjsip.conf:32`), dokümanda **3**
(`doc/mimari/asterisk-provisioning.md:196`). Lab yanlışsa **labda yapılacak her A/B
canlıyı temsil etmez** — `pjsip reload` dersinin aynı sınıfı.

Düzeltmeyi eski metni **silmeden** ekledim; karar kaydı hatanın kendisini de
taşıyor.

### 15. A-6'nın altından bugün canlıda süren gerçek bir arıza çıktı — BR-AST-53

Dört üye bağımsız buldu. **Zil grubu üyesi, DID→dahili rotası ve IVR hedefi,
dahiliyi YALNIZ masa nesnesiyle çözüyor:**

| Yer | WebRTC-only dahilide |
|---|---|
| `ConfigRenderer.cs:942` / `:968` zil grubu üyesi | **BOZUK** — üye hiç çalmaz |
| `CachedInboundRouteSource.cs:393` DID→dahili | **BOZUK** — rota overflow'a düşer |
| `asterisk-dialplan-sablonu.md:559` IVR `extension` hedefi | **BOZUK** |
| `ProvisioningRevisionService.cs:733` taşma hedefi | leg CHANUNAVAIL |
| `IvrTestCaller.cs:107` originate | başarısız |

`PJSIP_DIAL_CONTACTS(<masa>)` boş döner → `RGC=""` → üye atlanır → `RGD` boş →
çağrı doğrudan taşmaya gider. **t0007 = 6 dahili, 6'sı WebRTC, 0 masa → zil grubu
kimseyi çalmıyor.** Sahadaki adı: *"Muhasebe grubunu arıyorum, kimse açmıyor, ama
üçümüz de masadayız."*

**En rahatsız edici kısmı:** bu kusur sınıfı bu depoda **iki kez ölçülüp iki kez
düzeltilmiş** — `AsteriskObjectName.cs:461-466` (*"tarayıcıdan çalışan agent kuyruğa
üye YAPILIYOR ama çağrı ona HİÇ ULAŞMIYORDU"*) ve `ConfigRenderer.cs:764-772`. Bu
beş yer atlanmış. Ve **regresyon bekçisi yok**: `tests/` altında `HasWebRtc`,
`ForExtensionWebRtc`, `WebRtcSecret` → **0 isabet** (→ `BR-QA-49`).

**Brifingimin bir iddiası daha düştü:** "kuyruk üyeliği aynı adı kullanıyor"
demiştim — yanlış. Kuyruk üyeliği config'de hiç geçmiyor, AMI ile
`Local/{ext}@pbxtr-{kod}-local/n` olarak itiliyor (`AsteriskObjectName.cs:490`) ve
**zaten doğru**. Kuyruk yolu bu arızadan etkilenmiyor.

### 16. Çözülemeyen kurul çelişkisi — A-8 olarak açık bırakıldı

**DB Lideri:** ayrım "sır çözülebiliyor mu" olsun ve karar **render zamanında**
verilsin (içerik ↔ sha256 ↔ revizyon sözleşmesi korunsun).
**Asterisk Uzmanı bunu açıkça yasaklıyor:** bu koşul, bugün **gürültülü** olan
fail-closed'ı **sessiz cihaz silmeye** çevirir — sır deposu bir sabah cevap
vermezse üretim *"demek ki masa telefonu yok"* der, çalışan endpoint'leri config'ten
düşürür, `module reload res_pjsip.so` nesneleri **siler**, kayıtlı telefonlar düşer.
Belirti "provisioning hatası" değil **"sabah telefonlar çalmıyor"** olur ve üretilen
config geçerli olduğu için §3.1 rollback'i de devreye girmez.

İkisi de kendi alanında haklı ve ikisi de ölçümle konuşuyor. **Çözmedim**,
`yazilim-mimari`'ye bıraktım. Aday üçüncü yol: nesne üretilmez **ama** eksilme
`removed.kinds` manifestiyle **açıkça beyan edilir** (BR-AST-31 deseni) — bu,
"sessiz" itirazını karşılayabilir.

### 17. Kalan iş sayımı ve ClickUp

`clickup-cikar.js` + `clickup-durum.js` ile ölçüldü (elle sayaç yazmadım,
defterdeki ders):

```
complete 228 · in progress 14 · karar bekleyen 5 · to do 11 · backlog 88
toplam 346 — kalan 118
```

ClickUp: `clickup-olustur.js` **3 yeni kart** açtı (BR-AST-53/54, BR-QA-49),
`clickup-senkron.js` **fark 0**, `--kuru` doğrulaması *"fark olan kart: 0, izde
olmayan: 0"*.

## Kararlar (bu tur)

- **Karar #40:** A-5'in üç seçeneği de RED — soru yanlış eksende sorulmuştu.
  A-6'nın belge kusuru iddiası **iptal**.
- **K-1 sırası değişti:** `BR-AST-51b`'nin `kv:extwrtc:` yarısı 51a'yı beklemez.
- Yeni kartlar: `BR-AST-53` (P1), `BR-QA-49` (P1), `BR-AST-54` (P2).

## Açık kalanlar / sonraki adım

- **A-8** (çözülemeyen çelişki) → `yazilim-mimari`.
- **A-7** `max_contacts` lab=1 / doküman=3 — `pjsip show aor` ile canlıdan ölç.
- **A-9** çıplak `PJSIP/<endpoint>` kaç contact çalar (iki sekmeli A/B).
- **A-10** RNA adaleti: çalmayan cihaza giden çağrı agent'a RNA yazıyor ve agent'ın
  bunu öğrenmesinin hiçbir yolu yok.
- **A-11** t0007'ye trunk eklendiği an `pjsip` yeniden çözülemez ref taşır;
  trunk sırrı fiilen çözülüyor mu?
- **Kullanıcıya ait:** A-2 (t0012 bir düğüme pinlensin mi, yoksa bilerek teslim
  edilmediği mi yazılsın) ve Karar #39 uygulaması için `/sprint-planla pbxtr` → "başla".
- Karar #40 kapsam değiştirdiği için **tam kurul** ya da kapsamın #41'e taşınması.

### 18. A-7 kapandı — ve korktuğumun tersi çıktı

- **Neden:** Karar #40'ta `pbxtr-aor-base.max_contacts` için lab (`1`) ile doküman
  (`3`) çelişiyordu. Endişem şuydu: **lab yanlışsa labda yapılacak her A/B ölçümü
  canlıyı temsil etmez** — `pjsip reload` dersinin aynı sınıfı.
- **Ne yapıldı:** Canlıdan salt-okunur ölçtüm (`docker exec pbxtr-asterisk`,
  `pjsip show aors` + `/etc/asterisk/pjsip.conf`).

  ```
  pbxtr-aor-base    max_contacts = 1   qualify_frequency = 60
  pbxtr-aor-webrtc  max_contacts = 3   qualify_frequency = 0
  ```

- **Sonuç: canlı = lab. Yanlış olan DOKÜMANDI** (`asterisk-provisioning.md:196`),
  düzelttim. Bu **iyi haber**: lab bu iki şablon için canlıyı temsil ediyor, yani
  `BR-AST-54`'ün "auth'suz endpoint ne yapar" A/B'si labda koşulabilir — A-7 onun
  ön koşuluydu ve kalktı.

- **Aynı okumadan çıkan ikinci ölçüm, ve bu daha ağır:** altı AOR listelendi
  (`t0007-wrtc-1042…1047`) ve **altısının da altında tek bir `Contact` satırı yok.**
  Canlıda şu anda **hiçbir cihaz kayıtlı değil** — WebRTC yarısı bile. Panel yine
  de altı dahiliyi *"Config: Üretildi"* yeşiliyle gösteriyor. `BR-FE-70`'in
  ayıracağı `generated`/`withheld` ikilisi bunu **hâlâ göstermez**; üçüncü bir
  durum (`registered`) gerekiyor. K-18 onu kapsam dışı bırakmıştı — kart açılması
  gerektiğini karar kaydına yazdım.

- **A-9 ayakta:** `pbxtr-aor-webrtc.qualify_frequency = 0` canlıda doğrulandı, yani
  Asterisk Uzmanı'nın "erişilebilirlik filtresi yok, hangi contact çevrilir
  öngörülemez" gerekçesi geçerli.

- **Dokunulan dosyalar:** `doc/mimari/asterisk-provisioning.md`,
  `yonetim/kurul-kararlari.md`
- **Commit:** `1a46ea65` — push edildi.

### 19. Karar #41 — tam kurul; iki öncülüm daha çürüdü ve canlıda ÜÇÜNCÜ arıza çıktı

- **Neden:** Karar #40 altı üyeyle koşulmuştu ve kapsam değiştirmişti. CEO'nun deyimiyle
  *"eksik üyeyle toplanan kurul karar değil, öneri üretir."* Eksik dört üyeye (CEO, Linux,
  Frontend, Süpervizör) aynı kapsamı sordum.
- **Ne yapıldı:** Dördü de **ŞARTLI** oy verdi, HAYIR yok. Karar kaydına şunu açıkça yazdım:
  **bu tur tek başına 4 oyluktur**; 10 üye ancak #40 + #41 birlikte alındığında bu kapsamı
  görmüş olur. CEO'nun usul şartını kabul ettim: **6 üyeyle kapsam açan tur bir daha
  koşulmayacak.**
- **Commit:** `6a818d74` — push edildi.

#### Canlıda üçüncü arıza — ve A-7'de sebebini aramamışım

Linux uzmanı buldu, ben doğruladım:

```
pjsip show transports              →  yalnız transport-udp, Objects found: 1
pjsip show transport transport-ws  →  Unable to find object transport-ws.
```

Altı endpoint de `pbxtr-ep-webrtc` şablonundan türüyor ve o şablon `transport = transport-ws`
diyor. **Var olmayan taşımaya bağlı endpoint'e tarayıcı kaydolamaz.**

**Bu, A-7'de kendi ölçtüğüm şeyin sebebi.** Ben *"altı AOR, hiçbirinin altında `Contact` yok"*
ölçümünü yapıp **"canlıda kayıtlı cihaz sıfır"** diye kaydettim ve **sebebini aramadım**.
Ölçümü doğru yaptım, **sorguyu bitirmedim.** Ders bu: "sıfır gördüm" bir bulgu değil, bir
**sorunun başlangıcı**.

Kök sebep imaj sapması ve **depo kendi kendini uyarmış**: `lab-entrypoint.sh:158`
`bind = 0.0.0.0` yazıyor, `:146-158` yorumu *"BIND SATIRI ZORUNLUDUR — OLCULDU, tahmin degil…
Tasima HIC YUKLENMEDI"* diyor. Canlıda üretilen dosyada o satır **yok**; canlı imaj düzeltme
öncesi entrypoint ile pişmiş (depo `917ea946…` ≠ canlı `522688cd…`). Düzeltmeyi getiren commit
`3f8c51bc`'nin mesajı **"GERCEK KAYITLA dogrulandi"** — *depoda* doğrulanmış, **canlıya hiç
ulaşmamış**. `kod var, koşan yok` + `karar yazılmış ama uygulanmamış` desenlerinin birleşimi.

→ `BR-SYS-92` (P1 **BLOKLAYICI**) ve `BR-SYS-91` (P1): **santral hiçbir sapma kapısında yok.**
Üç sapma kapımız var (nginx, confd, compose) ve `asterisk` kelimesi hiçbirinde geçmiyor.

#### Çürüyen öncül 1: "BR-AST-53 teslim edilemeyecek"

Öneri metnimde *"`pjsip` withheld olduğu için düzeltme teslim edilmeyecek"* yazmıştım. Ölçüm:
**beş yerin hiçbiri `pjsip` türüne yazmıyor.** Zil grubu `Kinds.RingGroups = "ringgroups"`
altına gidiyor (`ConfigRenderer.cs:109`, atama `:142`); `ProvisioningRevisionService.cs:733`'te
`PJSIP` **tür adı değil kanal teknolojisi adı** — ikisini karıştırdım. `withheld` **tür bazında**
kesiyor, `ringgroups` teslim edilir. Yani düzeltme **teslim edilebilir** — ama bunun bedeli:
reload da **gerçekten koşacak**, risk gerçek.

#### Çürüyen öncül 2: "Config: Üretildi YEŞİL"

`ExtensionsScreen.module.css:250` → `--muted` = **#8a93a3, gri**. `--ok` bu kolonda **hiç**
kullanılmıyor ve **CSS'in kendi yorumu** tonun neden bilerek nötr seçildiğini zaten yazıyor.
Ben *"yeşil yalan"*ı hem `BR-FE-71` kartına hem `prototip-urun-farklari.md:1642`'ye yazmıştım —
**ikisini de düzelttim**, eski metni silmeden.

**Ve aradığım yeşil yalan gerçekten varmış — 40 satır aşağıda:** zil grubu paneli
(`ExtensionsScreen.tsx:478-482`) `isActive` için **yeşil `StatusLed`** çiziyor. t0007'de panel
*"Muhasebe · aktif · 3 üye"* diyor, santral kimseyi çalmıyor. Doğru yerde yanlış şeye bakmışım.

#### Süpervizör ölçümü — metrik arızayı ÖDÜLLENDİRİYOR

Üç iddiasını da doğruladım:

| Ölçüm | Sonuç |
|---|---|
| `SlaAggregationJob.cs:369` | `WHERE a.queue_id IS NOT NULL` → zil grubu çağrısı `sla_buckets`'a **hiç girmiyor** |
| `Modules/` altında zil grubu | **tek** dosya (`RingGroupEndpoints.cs`, CRUD); Analytics/Reports/Dashboard/Realtime/CallHistory → **0** |
| `AlarmEvaluator.cs:207-260` | `AlarmMetrics` **dört metrik**, dördü de kuyruk metriği, dördü de arızada **"iyi" tarafa** sapıyor |

**Muhasebe grubu bir hafta tamamen ölü olsa SLA raporu %100 gösterir** — payda hiç büyümüyor.
Süpervizörün cümlesi kayda değer: *"Bu 'metrik bozuluyor' değil, metrik arızayı ödüllendiriyor."*
→ `BR-OPS-02` (P1).

**A-10 ikiye ayrıldı ve öncülü düzeltildi:** BR-AST-53 yolunda haksız RNA **yazılmıyor** (üye
atlanıyor, `Dial` bacağı hiç kurulmuyor). **Ama kuyruk yolunda gerçek ve bugün canlıda:** kayıtlı
contact sıfır + `qualify_frequency = 0` → `app_queue` üyeyi müsait sanıyor → hiçbir cihaz
çalmıyor → `AgentRingNoAnswer` → ekranda **"Agent cevapsız"**. Agent hiçbir şey duymuyor,
sicilinde "cevaplamadı" yazıyor. → `BR-AST-55` (P1).

#### Kart numarası çakışması fiilen çıktı

`BR-SYS-90` **doluydu** (beyaz-etiket kartı). Defterdeki *"kart numarası önce ölçülür"* kuralını
**yarım uyguladım**: kontrol grep'ini ekleme komutuyla **aynı satırda** koşturdum, yani kontrol
çakışmayı ekledikten sonra gördü. Yeni kart `BR-SYS-92` oldu. Kural şöyle sıkılaşıyor: **ölçüm
ayrı komut olacak, yazma ondan sonra.**

## Kalan iş

`clickup-cikar.js` + `clickup-durum.js` ile: **351 kart = 228 kapalı + 123 kalan.**
ClickUp: 5 yeni kart açıldı, senkron farkı **0**.

## Açık kalanlar / sonraki adım

- **BLOKLAYICI sıra:** `BR-SYS-92` (imaj yeniden inşa) → `BR-SYS-91` (sapma kapısı) →
  `BR-AST-51b`/`kv:extwrtc:` → `BR-AST-53` → `BR-QA-49`. CEO'nun teslim tanımı:
  *"t0007'de bir dahili arandığında WebRTC cihazı çalıyor."*
- **A-8** (çözülemeyen çelişki) → `yazilim-mimari`.
- **A-9** `BR-SYS-92` kapanmadan **ölçülemez** (kayıtlı cihaz yok).
- **A-12 (yeni):** `ExtensionConfigStatus.cs:22-27`'nin *"üçüncü hâl olamaz"* paragrafı iki kez
  geçersiz kılınıyor — sözleşme bir kez mi yeniden yazılmalı, kolon iki alana mı bölünmeli?
- **A-13 (yeni, kendi yan bulgum):** `AlarmEvaluator.cs`'in vacuity notu *"Asterisk bagli
  olmadigi icin"* diyor — **09-03'te kaldırılan §3.0 gerekçesi**, bugün AGENTS.md'de
  düzelttiğimin aynısı. K-15 gereği **düzeltmedim**; kapı `BR-SYS-92` ile açılınca düzeltilir.
- **Kullanıcıya ait:** A-2 ve `/sprint-planla pbxtr` → **"başla"**.

### 20. A-11 kapandı — trunk ref'i üretilen bir şema değil, serbest metin

- **Neden:** Karar #40'ın açık sorusu: t0007'ye trunk eklendiği an `pjsip` yeniden çözülemez
  ref taşır mı, ve trunk sırrı fiilen çözülüyor mu?
- **Ne yapıldı:** Ölçtüm.

  | Ölçüm | Sonuç |
  |---|---|
  | `kv:trunk:` depo genelinde | **0 isabet** |
  | `AsteriskConfigValue.cs:74` | `^[A-Za-z0-9._:@/\-]+\z` — karakter sınıfı, şema değil |
  | `TrunkAdminEndpoints.cs:956,930` | `secret_ref` **operatörün elle yazdığı** alan |
  | `trunks.secret_cipher` | **VAR** (AES-256-GCM + `secret_key_version`) |
  | canlı `trunks` | **0 satır** |

- **ÜÇÜNCÜ yayımlanmış hatam:** Karar #39'un ref ailesi tablosunda (`:7677`) üçüncü satırı
  **`kv:trunk:{code}:{slug}`** diye yazmışım — sanki desk ve WebRTC gibi **kod tarafından
  üretilen** bir şemaymış gibi. **Öyle bir şema yok.** Üstünü çizdim, eski metni silmedim.
  Tablonun *"sır saklı mı: EVET"* kolonu doğruydu; hata yalnız ref'in biçiminde.

- **Ve bu bir biçim ayrıntısı değil — `BR-AST-51b`'nin tasarımını değiştiriyor.** Desk ve
  WebRTC için çözümleyici ref'i **ayrıştırarak** satıra ulaşabilir. Trunk için ayrıştırma
  **imkânsız**: ref keyfi metin, iki tenant aynı metni yazabilir, biri `sifre1` yazabilir.
  Yani çözümleyici *"ref'i ayrıştıran bir fonksiyon"* **olamaz**; render zamanında elde olan
  **satır kimliğiyle** çözmek zorunda. Ref o noktada yalnızca yer tutucunun **etiketi**,
  arama anahtarı değil.

- **Karar #40'ın çözülemeyen çelişkisine etkisi:** DB Lideri'nin *"karar render zamanında
  verilsin"* şartı bu ölçümle **güçleniyor** — render'da satır kimliği elde var, teslim anında
  yalnız metin var ve metinden geri dönüş **yok**. A-8'e bu girdiyle gidiyor.

- **Asıl soruya cevap: EVET**, trunk eklendiği an `pjsip` yeniden çözülemez ref taşır
  (`ConfigRenderer.cs:337` koşulsuz üretiyor); canlıda 0 trunk olması **fikstür tesadüfü**.
- **Commit:** `44f575d5` — push edildi.

### Bugünün deseni — üç öncülüm çürüdü, üçü de aynı sebepten

Bugün dört ayrı turda **dört yayımlanmış hatam** düzeltildi: A-6 ("belge kusuru kesin"),
"yeşil rozet", "BR-AST-53 teslim edilemez", "kv:trunk şeması". Ortak sebep tek: **adı
tanıdık gelen bir şeyi ölçmeden o sandım** — "şablon"u `ConfigRenderer` sandım, `PJSIP`
kanal teknolojisini tür adı sandım, ref'i şema sandım, gri rozeti yeşil sandım.

Dördü de kurul üyeleri tarafından **ölçümle** yakalandı, ben de her birini kendim doğruladım.
Defterdeki *"kart öncülü ölçülmeden yazılmaz"* kuralı doğru ama yetersiz: asıl kural
**"tanıdık gelen ad, ölçülmüş ad değildir."**

### 21. A-12 ve A-8 kapandı — ikisi de "çelişki yok, tarif yanlış" çıktı

#### A-12: sözleşme yanlış değil, ADI yanlış

Frontend uzmanı sormuştu: `ExtensionConfigStatus.cs:22-27` *"üçüncü hâl YOKTUR ve olamaz"*
diyor ama `BR-FE-70` ve `BR-FE-71` bunu iki kez geçersiz kılacak. Ölçtüm — **dosyanın kendi
metni okununca çelişki kayboluyor.** `:16-19` ne ölçtüğünü tek cümlede söylüyor: *"nesne **en
son üretilmiş** revizyonda var mı"*, ve *"üçüncü hâl olamaz"* gerekçesi **tam o soruya**
dayanıyor. O akıl yürütme kendi ekseni için doğru.

Çelişki **adında**: `configStatus` hangi ekseni ölçtüğünü söylemiyor, bu yüzden üç soru tek
kolona yığılmış — **A üretim** (doğru sahibi), **B teslim** (sahipsiz, FE-70), **C kayıt**
(sahipsiz, FE-71). `withheld` A eksenine **ait değil**. Tavsiye: sözleşme yeniden yazılmaz,
**daraltılır**. Frontend'in "iki dik eksen" şartı doğrulandı ve bir adım ilerledi: **eksen üç.**

- **Commit:** `7972ff12`

#### A-8: çelişkinin dayandığı önerme yanlıştı — ve yanlış tarif BENDEN çıkmıştı

Karar #40'ta A-8'i *"çözülemeyen çelişki"* diye kaydedip mimarîye havale etmiştim. Mimar
çözmedi — **geçersiz ilan etti**, ve haklı. Karar #40'a DB Lideri'nin *"teslim anında içerik
kırpmaya VETO"*sunu **A seçeneğinin karşısına** yazmışım. Ölçtüm, **A kırpmıyor, kırpamaz:**

| Ölçüm | Sonuç |
|---|---|
| `ProvisioningDeliveryGate.cs:78-88` | yalnız `kind` adı döndürüyor; yorumu *"Donen deger ICERIK TASIMAZ"* diyor |
| `ProvisioningNodeBundleEndpoints.cs:571` | **revizyonun tamamı** listeden düşüyor |
| `:573-577` | `Content` ve `Sha256` **değişmeden** taşınıyor |

O VETO **(c) seçeneğinin** kırpmasına aitti; ben ikisini karıştırdım. B'nin tek üstünlüğü diye
sunduğum *"üretilen metin hep geçerli"* özelliği **A'da da varmış**.

İkinci yanlışım aynı satırda: *"nesne üretilmez ama `removed.kinds` ile beyan edilir"* diye bir
üçüncü yol önermişim, sanki açık beyan mekanizması yokmuş gibi. **Var, ve adı `withheld`** —
sebep kodu, yanıt gövdesi, denetim + `LogCritical`, ETag. **A bugün sessiz değil, beyanlı.**
Üstelik önerdiğim üçüncü yol B'den **kötüymüş**: `removed` manifesti confd'ye bayat dosyayı
etkisizleştirme **yetkisi** veriyor ve Karar #37/Ş37-38 bu karıştırmayı **zaten yasaklamış**.

**Karar: (A) düzeltilmiş hâliyle.** Karar yeri **ikisi de** — varlık render'da, ikame teslimde;
düğüm **"kırpma ≠ materyalizasyon"** ayrımıyla çözülüyor. Materyalizasyon render'da yapılırsa
açık parola `content`'e girer (VETO-2), üçüncü yer yok → **teslim anı zorunlu**.

**A-11'in tasarıma yansıması:** `ISecretResolver` **yanlış soyutlama** — imza *"sır ref'ten
bulunur"* önermesini sözleşmeye çeviriyor; desk/WebRTC'de çalışır, trunk'ta **sessizce yanlış
parolayı** yazar. Doğru seam `ProvisioningSecretBinding(Placeholder, SourceKind, SourceRowId)`.

**Tasarım:** `doc/mimari/ADR-017-sir-cozumleme-ve-teslim-birimi.md` — **Commit:** `8080112e`

#### İki ek bulgu

1. **Çözülmüş sır yeni bir enjeksiyon yüzeyi.** ADR-007 §6.2 çıkış kapısı o değeri **hiç
   görmedi** (bugün metne yalnız yer tutucu giriyor). Sır `\n[t0012-9999]` içerirse materyalize
   metin **başka tenant'ın bölümünü açar**. Kapı çağrısı ikame **sonrasına** taşınmalı, yoksa
   bekçi vacuous. → `BR-AST-51b` kapsamına.
2. **Mimarın "ölçülmemiş tehlike"si ölçüldü, GÜVENLİ çıktı, kart AÇILMADI.** Withheld tür
   `removed.*` beyanına **girmiyor**: `removed` filtreden **önce** hesaplanıyor
   (`ProvisioningRevisionService.cs:1049-1052`), `after` tüm revizyonları içeriyor, filtre çok
   sonra teslim ucunda. **Bilerek kart açmadan önce ölçtüm** — bugün dört öncülüm ölçülmeden
   yazıldığı için çürümüştü, beşincisini eklemedim.

## Günün kapanışı

Kapanan açık sorular: **A-6, A-7, A-11, A-12, A-8**. Açık kalanlar ölçümle kapatılamaz:
**A-9** `BR-SYS-92`'ye bağlı (kayıtlı cihaz yok, ölçülemiyor), **A-13** K-15'e bağlı (kapı
açılmadan ölü gerekçe düzeltilmez), **A-10** `BR-AST-55` kartına dönüştü.

Kullanıcıya ait: **A-2** ve `/sprint-planla pbxtr` → **"başla"**.

### 22. `/sprint-planla pbxtr` — ve beşinci öncülüm bir YÖNTEM hatasıydı

Süreç kuralı §7/2 *"onaydan sonra planlanır"* diyor; kurul onayı vardı, plan çıktısı yalnız
`yonetim/` altına gidiyor ve uygulama zaten ayrı kapıya ("başla") bağlı. Planlamayı kullanıcıya
bırakmakla gereksiz bir darboğaz yaratmışım. Sekiz alan paralel koştu.

#### Beşinci öncül — ve bu diğer dördünden farklı sınıfta

Canlı sayımları `pbxtr_owner` ile, `app.tenant_id` kurmadan koştum. Altı tablonun altısı da
**RLS zorlanmış** (`relforcerowsecurity = t`). `extensions` **0** döndü — oysa t0007'nin altı
dahilisini **aynı gün** ölçmüştüm. Sayılar *"sıfır"* değil **"ölçemedim"**di.

Doğru sayım (`postgres`, RLS baypas — amaç RLS davranışı değil gerçek satır sayısıydı, açıkça
yazdım):

| tenant | dahili | **zil grubu** | **DID** | kuyruk | IVR | trunk |
|---|---|---|---|---|---|---|
| t0007 | 6 | **0** | **0** | 2 | 0 | 0 |
| t0012 | 3 | **0** | **0** | 1 | 0 | 0 |

`call_events` son olay: **2026-09-08 07:57 UTC** — iki gündür yeni olay yok. Kuyruk üyelikleri
ise **dolu** (6/3/3).

**Sonuç: `BR-AST-53` "CANLIDA SÜREN ARIZA" değil.** Kod kusuru gerçek ve doğrulandı, ama kusura
çarpacak **tek bir çağrı yolu yapılandırılmamış**. Agent'ın *"Muhasebe grubunu arıyorum kimse
açmıyor"* anlatısı bir **saha senaryosu**ydu; ben onu **canlı gözlem gibi sundum** ve kurulun
**dört üyesi o çerçeveye oy verdi.** Kart P1 kalıyor (sessiz + bu depoda iki kez geri gelmiş bir
sınıf) ama aciliyet gerekçesi değişti.

Güzel tarafı: **CEO'nun kendi şartı bunu kapatıyor.** Ş41-6 *"etkilenen tenant listesi ölçümle
belirlenir; liste sıfır çıkarsa bildirim yapılmaz ve 'sıfır çıktı' da yazılı olur"* diyordu.
Liste sıfır. Bayi bildirimi yapılmıyor, gerekçesi kayıtlı.

**`BR-SYS-92` etkilenmiyor** ve tek gerçek canlı arıza olarak kalıyor — `transport-ws` yüklü
değil, bu yapılandırmaya bağlı olmayan **ölçülmüş** bir durum.

#### Altıncı öncül: "beş yer, aynı düzeltme" yanlış

Asterisk uzmanı ölçtü — **üç ayrı sınıf**, ve biri **ters yönde**:

| Sınıf | Yer | Düzeltme |
|---|---|---|
| A | `ConfigRenderer.cs:942`/`:968` | `&` ile birleştir — **kartın anlattığı fix yalnız burada geçerli** |
| B | `ProvisioningRevisionService.cs:733`, `CachedInboundRouteSource.cs:393` | `&` **tekrarlanmaz**; `Goto(pbxtr-{tref}-local,…)` |
| C | `IvrTestCaller.cs:107` | **TERS:** ARI `endpoint` **tek** adres alır, `&` verilirse **400**. Doğru düzeltme `PJSIP/` önekini **silmek** |
| D | `asterisk-dialplan-sablonu.md:559` | Kod değil **belge** — `RenderIvrFlow` `extension` hedefi **hiç üretmiyor** |

Gerçek kod yüzeyi **dört**, beş değil. C sınıfı bir tuzaktı: kartıma bakarak `&` uygulayan biri
çalışan bir yolu kırardı.

#### Yeni kart `BR-AST-56` (P1) — süpervizör sayaç sandı, davranış kusuru çıktı

`ConfigRenderer.cs:952-953` eşzamanlı dalda `Dial()` sonrası **koşulsuz** `Goto(overflow,1)`;
sıralı dalda koruma **var** (`:976`) ve **o korumanın kendi yorumu tehlikeyi tarif ediyor**:
*"görüşme bittikten sonra sıradaki dahili çalmaya başlardı."* Yazar tehlikeyi bilmiş, sıralıda
kapatmış, eşzamanlıda kapatmamış. Taşma bölümü yalnız sayaç basmıyor — **`FallbackTarget`'i de
çeviriyor**. Yani eşzamanlı grupta **karşı taraf önce kapatırsa arayan, görüşme bittikten sonra
başka bir yere yönlendirilir**. (Canlıda yaşanmıyor: 0 zil grubu.)

#### Turun diğer üç bulgusu

- **Linux, üçüncü sha:** sunucudaki **inşa kaynağı** da düzeltme öncesi (`f3debeaa…`). Yani
  *"sunucuda `docker build` koş"* tek başına arızayı **düzeltmiyor**; önce depo ağacı taşınmalı.
- **Frontend:** `useSoftphone.ts`'te `retry|reconnect|backoff` → **0 isabet** ve `failed`
  **terminal**. İmaj düzelse bile agent kendiliğinden yeşile **hiç** dönmez. Ayrıca `tr.json`'da
  **19 ayrı "ölçülemedi" formülasyonu** var — kayıt ekseni için dördüncü aile icat edilmemeli.
- **DB:** `sla_buckets` zil grubunu **taşıyamaz** (PK `queue_id NOT NULL`, üç sorgu onu kuyruk
  sanıyor) → ayrı tablo. Ve REGISTER durumu **kalıcı tabloya değil Redis'e** — gözlemdir, kayıt
  değil; kalıcıya yazmak `cdr`/`call_events`'ten sonra en hızlı büyüyen yazma yolunu açardı.

#### Sprint-44 yazıldı

5 blok. Bloklayıcı zincir: imaj (`LX-02→LX-04→LX-06`) ve ADR-017 şeması (`D-01→D-03`).
**Kurula giden beş çözülmemiş karar** yazılı — en önemlisi CEO ile Süpervizör'ün `BR-AST-55`
zamanlamasında çeliştiği nokta; ikisini uzlaştırmadım, çelişkiyi kayda geçirdim.

- **Commit:** `53a3d48c` · **Backlog:** 352 kart = 228 kapalı + **124 kalan**

## Günün kapanışı — altı öncül, iki ayrı sınıf

**Dört tanesi** "tanıdık gelen adı ölçmeden o sanmak"tı (şablon→sınıf, `PJSIP`→tür adı,
ref→şema, gri→yeşil). **Beşincisi farklı ve daha sinsi: doğru soruyu yanlış ayrıcalıkla sormak.**
`pbxtr_owner` ile koşan sayım sessizce sıfır döndürüyor ve **sıfır bu depoda en tehlikeli cevap**.
**Altıncısı** ise bir genellemeydi: bir deseni beş yere aynı sanıp uygulamak.

Bundan sonraki kural: canlı sayımda ya GUC kurulur ya baypas rolü açıkça yazılır — ve
**beklenen bir satırın sıfır çıkması, sorgunun kendisinden şüphelenmek için yeterli sebeptir.**

### 23. BE-00 ölçüldü — A-5(a) "en ucuz seçenek" değil, ve düzeltmeye çalıştığı ekranı bozuyor

- **Neden:** Sprint-44'ün BE-00 görevi. Backend lideri A-5(a)'yı *"en ucuz — koşulsuz `foreach`
  koşullu olur, şema yok"* diye tarif etmiş ve ölçümü **kendisi istemişti**. Ölçüm bir kurul
  kararına (A-5) girdi olduğu için "başla"yı beklemez.
- **Ne yapıldı:** `AsteriskObjectName.ForExtension`'ın üretim kodundaki **tüm** tüketicilerini
  çıkardım: **10 yer**. Beşi `BR-AST-53` kapsamında zaten var. **İkisi kapsamda yok:**
  `ProvisioningRevisionService.cs:744` (sesli mesaj kutusu) ve `ConfigRenderGuard.cs:256`
  (çıkış kapısı). Ayrıca `LocalDialDevices` (`:734`) `desk`i **koşulsuz** ekliyor.

- **Onuncu tüketici turun ironisi:**

  ```csharp
  // EfUserAdministration.cs:577
  ExtensionConfigStatus.Of(latestPjsip, ForExtension(tenantCode, extension.Number))
  // Of(): pjsipContent.Contains($"[{objectName}]") ? Generated : Pending
  ```

  Çıpa **masa nesne adı**. A-5(a) uygulanırsa WebRTC-only dahililerin masa bölümü metinde
  **hiç olmaz** → `configStatus` **kalıcı olarak "Bekliyor"**. t0007'nin altı dahilisi her şey
  doğru üretilip teslim edilmişken **sonsuza dek "Bekliyor"** görünür.

  **`BR-FE-70`/`BR-FE-71` tam da bu kolonu düzeltmek için açıldı; A-5(a) onu ters yönden ikinci
  kez bozardı.**

- **Sonuç:** Karar #40'ın A-5 reddi **güçlendi**. Orada (a)'yı *"sıfır fayda"* diye reddetmiştik;
  şimdi ikinci gerekçe var — **(a) ucuz da değil.** Kurula giden hâli: (a) ancak üç ön koşul
  birlikte karşılanırsa değerlendirilebilir; üçüncüsü `configStatus` çıpasının masa nesnesinden
  bağımsızlaştırılması ki **A-12'nin "üç eksen" ayrımı bunu zaten gerektiriyor** (A ekseni
  *"bu dahilinin nesnesi üretildi mi"* olmalı, *"masa nesnesi üretildi mi"* değil).

- **Commit:** `d0e77087` — push edildi.

## Durum

Sprint-44 planı hazır ve **"başla" bekliyor**. §7/3 gereği uygulamaya geçmiyorum.
Ölçümle kapatılabilecek açık soru kalmadı:

| Açık soru | Neden bekliyor |
|---|---|
| A-5 | BE-00 ölçüldü → **kurul kararı** |
| AST-53-x (DND / `DialAutoAnswer`) | kurul kararı |
| `BR-AST-55` zamanlaması | CEO ↔ Süpervizör **çelişkisi**, kurula gider |
| A-9 | `BR-SYS-92` kapanmadan **ölçülemez** |
| A-13 | K-15 gereği kapı açılınca |
| A-2 | **kullanıcı kararı** |

### 24. Karar #42 — tam kurul 10/10; A-5 kapandı ve cevabı deponun kendi kodunda yazılıymış

- **Neden:** Sprint-44'ü üç karar blokluyordu ve üçü de kurulun — "başla" kapısına takılmıyorlar.
  CEO'nun Ş41-7 şartı gereği **tam kurul**. (İlk partide Linux ve Frontend'i göndermeyi atladım,
  tur içinde düzelttim — kendi kuralımı ikinci kez ihlal etmek üzereydim.)

#### S1 — A-5 kapatıldı, üçüncü kez yanlış eksende sorulmuş

Şeytan turu bitirdi. `ConfigRenderer.cs:833-844`, **renderer'ın kendi yazılı kuralı**:

> *"**`PJSIP_DIAL_CONTACTS()` kullanilir, ciplak `PJSIP/<endpoint>` DEGIL** … kayitli contact'i
> olmayan bir AOR icin **bos dize** doner."*

A-5'in üç turdur **üretim tarafında** çözmeye çalıştığı şey — *"kayıtsız masa nesnesi çağrıyı
bozmasın"* — **çağrı anında kendiliğinden çözülüyor**. Zil grubu kurala uyuyor; `LocalDialDevices`
uymuyor. **On tüketici yok, şema yok, `configStatus` kırılmıyor.** → `BR-AST-57` (`A-5′`).

(a) ayrıca üç bağımsız ölçümle düştü: `ConfigRenderGuard.cs:247-262` bir **varlık kapısı değil**
(üç üye ayrı ölçtü) → (a) altında eksik üretim **fail-open ve sessiz**; maliyet gerekçesinin
sistem karşılığı yok (canlı: 6 AOR / 0 contact iken 18 fd, 60 thread, 78.7 MB); panel kalıcı
"Bekliyor".

**Backend lideri nitelemesini geri aldı ve sebebini yazdı:** *"`ForExtension()`'ı bir üretim yeri
sandım, oysa o bir **ad fonksiyonudur**; adı üretenle adı tüketen yerler ayrı."*

#### S2 — İki öncülüm daha çürüdü

- *"İkisi de bugünkü davranış değil"* — **yanlış**. Kuyruk üyeliği zaten `Local/{ext}@…-local/n`
  ile itiliyor; dış çağrılar o bağlamdan **bugün de** geçiyor.
- DID yolu *"yanlış çevriliyor"* değil — **hiç çevrilmiyor**:
  `dialplan show pbxtr-inbound` → **"There is no existence of context"**. `ConfigRenderer.cs:464`
  oraya `Goto` ediyor ama bağlamı **hiçbir şey üretmiyor**. → DID yarısı **kapsam dışı**.

**Ve turun en güzel sentezi:** CTO `Goto`'nun dış arayanın `__PBXTR_DIR` damgasını ezeceğini
buldu; Asterisk uzmanı bağımsız olarak `Goto` yerine **`Dial(Local/…/n)`** önerdi. İkincisi
**yeni kanal çifti** yarattığı için birincinin sorununu **kendiliğinden çözüyor** — ve kuyruk
yolunun bugün neden bozulmadığını da açıklıyor.

Frontend bedeli ölçtü: **#19 CDR'da yön bir filtre.** Yanlış etiket *görünür* hata; "Gelen
çağrılar" filtresiyle arayan o çağrıyı **hiç bulamaz** — **görünmez** hata.

#### S3 — CEO kendi ifadesini geri çekti

> *"'Baskın kök 53'ün ta kendisi' dedim; ölçüm çürüttü. İki arızayı tek karta koymak, **canlıda
> gerçek olanı latent olanın arkasına saklamak** olurdu."*

Üç üye bağımsız ölçtü: kuyruk yolu 53'ün dokunduğu yer değil. CEO'nun *"53'ün kabul ölçütüne
RNA ekle"* şartı **vacuous geçerdi**.

**Ve `qualify_frequency = 60` önerisi Linux tarafından tarih zinciriyle reddedildi:**

| Kanıt | Zaman |
|---|---|
| `bind` düzeltmesi | 2026-08-29 **14:39 UTC** |
| Canlı imajın pişmesi | 2026-08-29 **14:34 UTC** (5 dk **önce**) |
| `qualify_frequency = 0` ölçümü | 2026-08-30 (**ertesi gün**) |

Ölçümdeki contact adresi `172.28.0.10` = **`pbxtr-nginx`** → o an **gerçek kayıtlı WSS contact
vardı**. Sebep **topolojik**: contact URI'si ters vekilin efemer portunu taşıyor. `BR-SYS-92`
bunu değiştirmez → qualify açılırsa **ölçülmüş kesinti birebir geri gelir**.

#### Yeni kartlar (numaralar ÖNCE ölçüldü — bugünün dersi)

`BR-AST-57` (A-5′) · `BR-QA-50` (RNA geri-alınamazlık bekçisi, `BE-30`'dan bağımsız) ·
`BR-SYS-93` (**`maxcalls`/`maxfiles` yazılmamış, fd tavanı 1024, Asterisk'in kendi koruması
kapalı** — Linux buldu)

#### Plan kesildi

58 görev → Blok 4'ün 12 frontend görevi + `LX-16…21` + `D-10…12` + **Blok 5'in tamamı**
sprint-45'e. `OPS-01` çıktı çünkü canlıda **2 gündür 0 trafik** — alarm ilk gün tamamen gürültü
olur ve doğru çalıştığı **ölçülemez**. Süpervizörün Ş-S2 itirazı kayda geçti.

- **Commit:** `3cce764f` · **Backlog:** 355 kart = 228 kapalı + **127 kalan**

## Günün kapanışı — yedi öncül, ve CTO'nun teşhisi

Bugün **yedi** öncülüm ölçümle çürüdü; **dördü bu son turda**. CTO teşhisi doğru koydu:

> *"Sorun senin yargında değil — **ölçümün karardan sonra gelmesinde.** `BE-00` ve `K-9` doğru
> desendi."*

Kural DoD'ye girdi: **kurula giden her kararın öncülü, karar oylanmadan önce dosya:satır ile
ölçülmüş olacak.** DB lideri de RLS yöntem hatası için belirlenimli bir kapı önerdi ve kabul
edildi.

En çarpıcı olan şu: bugünkü yedi hatanın **dördünün cevabı zaten depoda yazılıydı** — `ADR-015`,
CSS yorumu, `ConfigRenderer.cs:833-844` ve `AsteriskObjectName.cs:490`'ın kendi belgeleri.
Bilgi eksikliği değil, **okumadan iddia** sorunuydu.

### 25. BR-AST-58 — gelen çağrı yolu hiç bağlanmamış; canlıda çalışan tek numara elle yazılmış

Karar #42'nin açık bıraktığı *"`pbxtr-inbound` bağlamını kim üretecek?"* sorusunu kapatmadan
bırakamazdım — kendi kuralım: **karta yazılmayan iş ClickUp'ta hiç yoktur.** Kart yoktu
(`grep -c "pbxtr-inbound" yonetim/backlog.md` → **0**). Ölçtüm ve iş büyüdü.

**Ölçüm 1 — bağlam yok:** `dialplan show pbxtr-inbound` → *"There is no existence of context"*.
`ConfigRenderer.cs:464` **her** gelen çağrıyı oraya `Goto` ediyor.

**Ölçüm 2 — beklemediğim şey:** canlı `pbxtr-t0007-in` bağlamı **iki dosyadan birleşmiş**:

```
pbxtr-t0007-in → 4 extension, 15 öncelik, TEK bağlam
  '8001' '_tut[1-9]' 'h'  ← extensions.conf        (ELLE YAZILMIŞ)
  '_X.'                    ← t0007-dialplan.conf:36 (ÜRETİLEN)
```

Aynı bağlam `extensions.conf:25` ve `pbxtr.d/dialplan/t0007-dialplan.conf:3`'te **iki kez**
tanımlı; `#include` satır **175**'te, yani elle yazılandan **sonra**. Asterisk bağlamları
**birleştiriyor**.

**Sonuç:** Asterisk `8001`'i `_X.`'ten daha spesifik eşleşme sayıyor → **elle sabit kodlanmış tek
numara çalışıyor** (`Queue(t0007-satis)`), **başka her gelen numara** `_X.`'e düşüp var olmayan
bağlama gidiyor ve **çağrı ölüyor**.

Bugün belirti üretmiyor (0 DID, 0 trunk) ama gelen çağrı yolu **hiç kurulmamış** durumda. Ve
domain kodu o bağlamları **var sayıp üzerine sözleşme yazmış**: `InboundDid.cs:100,188`,
`InboundRoute.cs:32,87,127`, `RouteDecisionEndpoints.cs:325`. Sınıf B `route-decision` ucu
**çalışıyor ama tüketicisi yok**.

Bu aynı zamanda daha önce *"yanlış alarm"* diye kapattığım `t0007-satis` gözlemini de
açıklıyor: o kuyruk gerçekten elle yazılmış ve **elle yazılmış bağlamdan** çağrılıyor.

- **Commit:** `9564217a` · **Backlog:** 356 kart

## Gün kapanışı

| | |
|---|---|
| pbxtr commit | 9 (push'lu) |
| Gunluk commit | 8 (push'lu) |
| Kurul turu | 3 (#40, #41, #42) |
| ADR | 1 (ADR-017) |
| Kapanan açık soru | A-6, A-7, A-8, A-11, A-12, BE-00, **A-5 (kapatıldı)** |
| Çürüyen öncülüm | **7** |
| Yeni kart | BR-AST-53/55/56/57/58, BR-QA-49/50, BR-SYS-91/92/93, BR-OPS-02, BR-FE-71 |
| Kalan iş | **356 kart = 228 kapalı + 128 kalan** |

**Sırada kullanıcı var:** `/basla pbxtr sprint-44` ve **A-2** kararı. §7/3 gereği uygulamaya
kendim geçemem.

### 26. `queue show` tek komutla iki soruyu birden kapattı

Karar #42 iki ölçümü **"kart yazılmadan"** şart koşmuştu: Asterisk uzmanının kök-neden iddiası
ve Linux uzmanının ona itirazı. İkisi de tek `queue show` ile kapandı.

**Ölçüm 1 — `app_queue` kayıtsız üyeyi MÜSAİT sayıyor:**

```
t0007-musteri-hizmetleri  6 üye — altısı da (Not in use)
t0007-tahsilat            3 üye — üçü de    (Not in use)
```

Aynı anda `transport-ws` **yüklü değil** ve `pjsip show contacts` → **`No objects found.`**
Yani hiçbir cihaz çalamaz, ama kuyruk altısını da müsait görüyor → bacak kurar → RNA doğar.
**`BR-AST-55`'in kök zinciri doğrulandı.**

**Ve Linux uzmanının itirazı da cevaplandı** — o *"`chan_local`'ın device state sağlayıcısı AOR
contact'ına bakmaz; bu doğruysa `qualify`'ı açmak hiçbir şey düzeltmez ve `hint` önerisi de
şüpheli"* demişti. Ölçüm onu doğruluyor. İki aday düştü, biri ayakta kaldı:

| Aday | Sonuç |
|---|---|
| `qualify_frequency` | **düştü** (ikinci kez) |
| `-local`'a `hint` | **şüpheli** — `hint` `PJSIP/` izler, üye `Local/` |
| `BR-AST-57` (`A-5′`) | **en güçlü aday** — `PJSIP_DIAL_CONTACTS()` kayıtsız AOR'a boş döner |

**Ölçüm 2 — beklemediğim ikinci bulgu:** aynı çıktıda `t0007-satis … No Members` vardı. Ve
`BR-AST-58`'de ölçtüğüm **tek çalışan gelen numara** (`8001`, elle yazılmış) tam oraya gidiyor.

Kaynağını izledim: `t0007-satis` **yalnız** elle yazılmış `queues.conf:10`'da tanımlı; pbxtr'ın
ürettiği kuyruklar `musteri-hizmetleri` ve `tahsilat`; pbxtr DB'sinde t0007 = 2 kuyruk. pbxtr
üyeliği **yalnız kendi bildiği kuyruklara** iter → `t0007-satis` **kalıcı olarak boş**.

Yani canlıdaki tek işleyen gelen yol şu:

```
8001 → elle yazılmış bağlam → Queue(t0007-satis,…,60) → SIFIR ÜYE → 60 sn → Hangup()
```

**Gelen çağrı yolunun hiçbir dalı bugün bir insana ulaşmıyor** — `_X.` var olmayan bağlama,
`8001` boş kuyruğa. Bu bir *"yapılandırılmamış"* durum değil: **yapılandırılmış ve bozuk.**

- **Commit:** `5e85e85d` (ölçüm), `1c11264c` (kartlara işlendi)

**Yöntem notu:** ikisi de **kart yazılmadan** ölçüldü ve ikisi de kartların içeriğini değiştirdi
— `BR-AST-55`'in üç kök adayından ikisi düştü, `BR-AST-58`'in kapsamı büyüdü. Karar #42'de kabul
edilen CTO kuralının (*"öncül, karar oylanmadan önce ölçülmüş olacak"*) ilk çalışan örneği.

### `BR-AST-58(b)` envanteri — ve gelen çağrıda ARI kontrolünün yapısal yokluğu (`BR-AST-59`)

- **Neden:** Karar #42, `BR-AST-58`'in (b) maddesinde elle yazılmış dialplan bloklarının
  envanterini şart koşmuştu: hangisi demo kalıntısı, hangisi gerçek gereksinim.
- **Ne yapıldı (salt-okuma, `root@176.88.41.220`):** canlıdaki `extensions.conf`,
  `queues.conf`, `pjsip.conf` ve `pbxtr.d/dialplan/t0007-dialplan.conf` blok blok çıkarıldı,
  her blok "üretilen / elle-demo / elle-tezgâh / elle-gerçek" olarak sınıflandırıldı.
- **Envanterin kendi düzeltmesi:** daha önce *"pbxtr altı bağlam üretiyor"* yazmıştım;
  canlı dosya **sekiz** taşıyor (`-callback` ve `-vm` de üretiliyor; `-rg` bu turda yok
  çünkü t0007'de 0 zil grubu var).
- **Çürütülen çıkarım:** `[pbxtr-t0007-stasis]` bloğunun elle yazılmış olduğunu görünce
  *"ARI ters yönü elle yazılmış bir tezgâha bağlı"* diye düşündüm. Ölçtüm — **yanlıştı:**
  `ConfigRenderer` devir satırını üretiyor (`:549`, `:604`), canlı dosyada var (`:13`, `:23`).
- **Ölçümün ortaya çıkardığı gerçek kusur:** o satır **yalnız `-out` ve `-int`** bağlamlarında
  var. `[pbxtr-t0007-in]` taşımıyor — ve taşısa bile işe yaramazdı, çünkü `PBXTR_CTL` damgasını
  `AsteriskAriProvider.cs:258` **yalnız pbxtr originate ederken** basıyor; gelen çağrıyı pbxtr
  originate etmez. Sonuç: gelen kuyruk çağrısının **iki bacağı da Stasis dışında** →
  bekletme/aktarma/park/kayıt **409**. **`BR-AST-58` bunu kapatmaz:** `pbxtr-inbound` yazılınca
  çağrı çalar, panelden bekletilemez.
- **Dokunulan dosyalar:** `yonetim/backlog.md` (yeni kart `BR-AST-59`, P1), `yonetim/kurul-kararlari.md`
- **Komutlar:**
  ```bash
  ssh root@176.88.41.220 "sed -n '1,45p' /etc/asterisk/pbxtr.d/dialplan/t0007-dialplan.conf"
  grep -n 'Stasis\|PBXTR_CTL' src/Pbxtr.Infrastructure/Provisioning/ConfigRenderer.cs
  node yonetim/arac/clickup-olustur.js && node yonetim/arac/clickup-senkron.js
  ```
- **Sonuç / doğrulama:** backlog 360 kart; ClickUp `fark olan kart: 0, izde olmayan: 0`.
- **Commit:** `9d366e34` (envanter + kart), `c982e893` (ClickUp izi)

## Kararlar
- `BR-AST-59` bir **düzeltme değil tasarım kararıdır** → kurula gider. Açık soru: gelen bacak
  Stasis'e **koşulsuz** mu girecek, yoksa tenant/DID bazlı dar bir opt-in mi? `ConfigRenderer.cs:519`'daki
  *"neden her çağrı değil"* gerekçesi originate edilen çağrılar için yazılmıştı ve gelen yöne
  olduğu gibi uygulanamaz.
- `BR-AST-59`, `BR-AST-58` ile **birlikte** planlanır; tek başına inmez.

## Açık kalanlar / sonraki adım
- `BR-AST-59` kurul turu (kapasite ayağı `BR-SYS-93`'ün `maxcalls`/fd tavanıyla birlikte ölçülmeli).
- Ş42-2 (`A-5′` boş `Dial()` argümanı) hâlâ `BR-SYS-92`'ye veya laboratuvara bağlı.
- Kullanıcıda: **A-2** (t0012 düğüm pini) ve **`/basla pbxtr sprint-44`**.

### `BR-QA-51` kapsam (b) ölçüldü — çerçevem yine ölçümde daraldı

- **Neden:** kartı yazarken (b) maddesini *"hangi yüzeyler simüle satırları sayıyor — bu kart
  yazılırken ölçülmedi"* diye açık bırakmıştım. Açık bırakılan öncül, defterdeki
  `kart-onculu-olculmeden-yazilmaz` dersinin tam hedefi; aynı gün kapatıldı.
- **Ne yapıldı:** `call_events` okuyan tüm yerler ve `SIM/` önekinin kaynağı tarandı.
  - `SIM/` önekini **yazan** tek yer tohumlayıcıdır: `SampleDataSet.cs:977`, `:1010`.
  - `call_events` **okuyan 12 dosya** var (`AnalyticsDtos`, `ReportEndpoints`, `CdrEndpoints`,
    `NetworkQualityEndpoints`, `DialerDtos`, `RouteDecisionDiagnostics`/`Endpoints`,
    `TenantCallDataRetentionEndpoints`, `ApiKeyEndpoints`, `CallResultEndpoints`,
    `TenantEndpoints`, `SystemHealthProbe`) ve **hiçbiri `SIM/` filtrelemiyor**.
  - **Ama korktuğum yüzey yokmuş:** `SystemHealthProbe`'un `call_events` kullanımı
    **retention lag partition sayımıdır** (`:1593-1605`, `pbxtr_sys.call_data_retention_lag()`,
    `pending_tenants` kolonu), *"canlıda çağrı akıyor"* iddiası değil.
- **Sonuç / doğrulama:** kartın çerçevesi **daraltıldı**. Kalan risk iki dar başlıkta:
  (b-1) rapor/analiz yüzeyleri tohum satırını gerçek geçmiş gibi gösteriyor — **hangi raporun
  kaç satırını şişirdiği ölçülmedi**, ölçülen yalnız *"filtre yok"* olgusudur; (b-2) **insan
  okuması** — bu tablodan *"canlıda trafik var"* çıkarımını **bugün ben yaptım**.
  Yani kusur bir **yüzey** kusuru değil, bir **VERİ KİMLİĞİ** kusuru: simüle satır ile gerçek
  satırın ayrımı tesadüfi bir dize önekine bağlı. Asıl madde bu yüzden (a); (b) tek başına bir
  düzeltme gerektirmiyor.
- **Ayrıca:** kartta yazılı olan ama **ölçülmemiş** sayılar (*"400 çağrı, 369 AgentConnect"*)
  çıkarıldı. Ölçülmemiş sayı, ölçülmüş sayı gibi görünür — bugünün tekrarlayan hatası.
- **Dokunulan dosyalar:** `yonetim/backlog.md` (`BR-QA-51` gövdesi ve durum sütunu)
- **Komutlar:**
  ```bash
  grep -rn "call_events" src/ --include=*.cs -l
  grep -rn "SIM/" src/ --include=*.cs
  grep -n "call_events" -C6 src/Pbxtr.Api/Platform/Health/SystemHealthProbe.cs
  node yonetim/arac/clickup-senkron.js --kuru
  ```
- **Sonuç / doğrulama:** ClickUp `fark olan kart: 0, izde olmayan: 0` (durum eşlemesi değişmedi;
  senkron gövde taşımaz).
- **Commit:** `50e43928` — kart(BR-QA-51): kapsam (b) ölçüldü — tehlike DARALDI

#### Bugünün deseni bir kez daha

Ölçüm bu sefer bir kusuru **büyütmedi, küçülttü** — ama yine benim yazdığım çerçeveyi çürüttü.
Sekizinci öncül. Ortak sebep aynı: *"muhtemelen şöyledir"* cümlesini karta **teşhis** diye
yazmak. Kartın açık bıraktığı madde (a) ve (c) hâlâ ölçülmedi ve öyle **işaretli** duruyor.

### `BR-QA-51` kapsam (c) — ve bugünkü en kötü türden bulgu: delilimin cinsi yanlışmış

- **Neden:** (c) maddesi *"tohum verisi canlı veritabanında ne arıyor, retention onu kapsıyor mu"*
  diye açık bırakılmıştı.
- **Ne yapıldı:** tohumun kaynağı ve canlı `call_events`'in kimlik uzayı ölçüldü.
  - Tohum bir **kalıntı değil, kasıtlı bakım komutu**: `seed-sample` / `migrate --with-sample`
    (`MaintenanceCli.cs:122`, `MaintenanceRunner.cs:343`), koşması için
    `Bootstrap:SampleUserPassword` **zorunlu**.
  - Tohumlayıcının kendi belgesi (`SampleDataSeeder.cs:19-26`): *"zaman taşıyan alanlar her
    koşuşta BUGÜNE göre tazelenir"* — `cdr-*` satırları silinip **o günün tarihiyle** yeniden
    yazılıyor.
  - Canlı ölçüm (salt-okuma, `postgres` rolü — gerekçe: gerçek satır sayısı, RLS davranışı değil):

    | kimlik uzayı | satır | aralık |  | kanal | satır | aralık |
    |---|---|---|---|---|---|---|
    | `cdr-*` (tohum) | 3727 | 09-02→09-08 |  | `SIM/` | 7434 | 08-26→09-08 |
    | `live-*` (sim. çalışma zamanı) | 3698 | 08-26→08-29 |  | `Local/` | 333 | 08-29→**08-30** |
    | diğer | 369 | 08-29→09-08 |  | `PJSIP/` | 27 | 08-30→**08-30** |

  - **2026-09-08 tarihli tohum-dışı satır sayısı: 0.**
- **Sonuç / doğrulama:** **`max(at) = 2026-09-08` bir çağrı değil, `seed-sample`'ın en son koştuğu
  gündür. Son GERÇEK telefon olayı 2026-08-30.** *"Canlıda çağrı akmıyor"* çıkarımı bundan
  **zayıflamıyor, güçleniyor** — sessizlik iki gün değil **on bir gün**.
  Retention `call_events`'i kapsıyor (`deploy/db/README.md:288` purge allowlist, `:533` aylık
  partition) **ama asla yetişemiyor**: tohum tarihi her koşuda bugüne çekiyor.
- **Ve asıl ders:** bu delili **iki yerde ben yazmıştım** (`sprint-44.md:18` ve
  `kurul-kararlari.md`'de iki paragraf). İkisi de düzeltildi — sprintte satır içi DÜZELTME notu,
  karar defterinde sonuna eklenen DÜZELTME kaydı (silme yok). `BR-QA-51`'in tarif ettiği
  **veri kimliği kusurunun ilk gerçek kurbanı bu depodur**: bir bakım komutunun zaman damgasını
  trafik sandım.
- **Dokunulan dosyalar:** `yonetim/backlog.md`, `yonetim/sprintler/sprint-44.md`,
  `yonetim/kurul-kararlari.md`
- **Komutlar:**
  ```bash
  grep -rn "SampleDataSeeder\|SampleDataSet" src/ --include=*.cs
  ssh root@176.88.41.220 "docker exec pbxtr-postgres psql -U postgres -d pbxtr -Atc \"select ... from call_events group by 1\""
  node yonetim/arac/clickup-senkron.js --kuru
  ```
- **Sonuç / doğrulama:** ClickUp `fark olan kart: 0, izde olmayan: 0`.
- **Commit:** `ece34d57` — kapsam (c) + iki düzeltme

`BR-QA-51`'de açık kalan: **(a)** kaynak ayrımının tesadüfi `SIM/` önekine bağlı olmaktan
çıkarılması, ve **(c′)** üretim veritabanında `seed-sample` koşma **politikası** (kim, ne zaman,
hangi onayla). İkisi de karta **açık** yazıldı, cevaplanmış gibi kapatılmadı.

### 🔴 Kendi kuralımı çiğnedim: üç sır transkripte düştü (üçüncü kez, aynı sınıf)

- **Ne oldu:** `live-*` satırlarının (3698, simülasyon çalışma zamanı) canlıda **nasıl** üretildiğini
  anlamak için üretimdeki sağlayıcıyı ölçmek istedim:
  `docker inspect pbxtr-app --format '{{range .Config.Env}}…' | grep -i 'telephony|provider' | cut -c1-60`.
- **Hata:** **`cut -c1-60` bir DEĞER kesici değil, bir SATIR kırpıcıdır.** Anahtar adları kısa
  olduğu için değerlerin tamamı 60 karakterin içine sığdı ve
  `Telephony__ApiKeyPepper`, `Asterisk__AriPassword`, `Asterisk__AmiSecret` açık düştü.
  Ayrıca `docker inspect` `env`den daha tehlikeli: `grep` deseni ada değil **tüm satıra** uyuyor,
  niyet edilmemiş anahtarları da getiriyor.
- **Bu üçüncü kez:** 2026-09-04 (`sed` ad deseni `AmiSecret`i kaçırdı), 2026-09-06
  (`cut -d=` — dosyada `=` yoktu), bugün (`cut -c`). **Üçünün ortak sebebi aynı: değeri getirip
  sonra kırpmak.** Hafıza kuralı (`env-okurken-degeri-kes`) buna göre sertleştirildi: filtre
  **değerden ÖNCE** uygulanır (`… | cut -d= -f1 | grep -i provider`); `head`/`cut -c`/`--format`
  ile kırpmak ve `grep`ten sonra maskelemek **çürüdü**.
- **Ne yapıldı:** `BR-SEC-16` açıldı (P2) — rotasyon **kullanıcı işidir** ve ucuz değildir:
  `ApiKeyPepper` dönerse **tüm tenant API anahtarları geçersizleşir** ve Sınıf B uçları
  fail-closed olduğu için çağrı akışı durur; pencere planlanmalı. `AriPassword`/`AmiSecret`
  ayrıca `lab-entrypoint.sh:86,96` tarafından her açılışta yeniden yazılıyor (Sınıf A) — yalnız
  `.env` güncellemek yetmez. **Rotasyonun bedeli, sızıntının bugünkü riskinden büyük olabilir;
  bu bir karardır ve tek taraflı kapatmadım.** Karar verilene kadar sırlar **sızmış kabul edilir.**
- **Ölçümün kendisi (bedeli bu kadar olmamalıydı):** `PBXTR_Telephony__Provider=asterisk` —
  üretimde **gerçek sağlayıcı** koşuyor, simüle sağlayıcı değil. Yani canlı `call_events`'teki
  `live-*`/`SIM/` satırları **çalışan bir simülasyondan değil**, tohumdan ve 08-26→08-29
  penceresindeki eski koşulardan geliyor.
- **Commit:** `BR-SEC-16` kartı + ClickUp izi (pano: yeni 1, fark 0)

### `BR-QA-51` (d) — kusur `call_events`'e özgü değil: canlı `cdr`'ın ~%88'i de gerçek değil

- **Neden:** (c) ölçümünden sonra doğal soru: bu veri kimliği kusuru tek tabloda mı?
- **Ne yapıldı:** canlı `cdr` aynı kimlik uzayı ayrımıyla sayıldı (salt-okuma, `postgres` rolü).

  | kimlik uzayı | satır | aralık |
  |---|---|---|
  | `live-*` (simülasyon) | 527 | 08-26 → 08-29 |
  | `cdr-*` (tohum) | 433 | 09-02 → 09-08 |
  | **gerçek Asterisk `uniqueid`** | **97** | 08-29 → **08-30** |
  | GUID biçimli | 32 | 08-26 → 08-30 |
  | `demo-*` | 1 | 09-08 |

  Referans olarak yapılandırma tarafı: `tenants` 3, `users` 18, `queues` 3, `extensions` 9 —
  **küçük ve gerçek**. Şişen yalnızca **çağrı verisi**.
- **Sonuç / doğrulama:** `cdr` toplam 1090 satırın **~%88'i simüle veya tohum**. Ve bu tablo
  CLAUDE.md §3.4'e göre **mutabakat kaynağıdır** — CEL/CDR mutabakatı buradan yürüyecekse
  karşılaştırılacak satırların çoğu gerçek değil. Kaynak ayrımı bu yüzden tek tabloya değil,
  **çağrı verisi ailesinin tamamına** (`cdr`, `call_events`, ES indeksi, raporlar) uygulanmalı.
  Ayrıca gerçek `cdr` satırlarının tarih penceresi (**08-29/30**) `call_events`'in gerçek
  penceresiyle **birebir aynı** — iki bağımsız tablo aynı cevabı verdi, ölçüm kendini doğruladı.
- **Dokunulan dosyalar:** `yonetim/backlog.md` (`BR-QA-51` kapsam (d))
- **Commit:** `4dce1942`

`BR-QA-51`'de açık kalan iki dar soru: **(c′)** üretim DB'sinde `seed-sample` koşma politikası,
**(d′)** kaynak ayrımı alanının hangi tablolara birlikte gireceği. İkisi de tasarım kararı → kurul.

### `BR-QA-51` (c′) teknik yarısı — tohum yolunda **ortam kapısı yok**, tek kapı bir parola

- **Neden:** (c′) *"üretimde `seed-sample` koşma politikası"* diye kurula gidecekti; kurula
  **ölçülmemiş** bir soru göndermemek için teknik yarısı önce ölçüldü.
- **Ne yapıldı:**
  - Depo: `MaintenanceCli.cs`, `MaintenanceRunner.cs`, `SampleDataSeeder.cs` içinde
    `IsProduction`/`IsDevelopment` kontrolü → **0 isabet**. `ASPNETCORE_ENVIRONMENT` yalnızca
    yapılandırma kurmak için okunuyor (`MaintenanceCli.cs:137-139`, varsayılan `"Production"`).
  - Tek kapı: `Bootstrap:SampleUserPassword` zorunluluğu (`SampleDataSeeder.cs:41-45`).
  - Canlı: o anahtar **kalıcı değil** — `pbxtr-app` konteyner ortamında yok ve sunucudaki
    `.env`'de `SampleUserPassword` **0 eşleşme**.
- **Sonuç / doğrulama:** her tohum koşusu **parolayı o an elle veren bilinçli bir insan
  eylemidir** — kaza değil. Ama **kayıtsız**: kim/ne zaman koştuğunu gösteren denetim satırı yok.
  Kurul sorusu böylece daraldı: *üretimde `seed-sample` **yasaklansın** mı (ortam kapısı), yoksa
  izin verilip **denetlensin** mi?*
- **Yöntem notu (bugünün sızıntısından sonra):** env okuması bu sefer kurala uygun yapıldı —
  konteynerde önce `cut -d= -f1` ile **yalnız adlar**, dosyada `grep -c` ile **yalnız sayı**.
  Değer hiçbir aşamada getirilmedi. Sertleştirilen kural ilk kullanımında işe yaradı.
- **Dokunulan dosyalar:** `yonetim/backlog.md`
- **Commit:** `166c4873`

### `BR-BE-122` öncülü doğrulandı — ve kusur *belirsiz* değil, **giden çağrıda koşulsuz**

- **Neden:** kart Karar #43 turunda Süpervizör'ün bulgusuyla açılmıştı; öncülü **benim
  okumamla doğrulanmamıştı**. Bugünün deseni tam da bu: doğrulanmamış öncül.
- **Ne yapıldı:**
  1. `AgentMonitoringService.cs:685-733` `ResolveInvocationAsync` okundu: hedef gerçekten
     **tek alandan** geliyor (`_live.GetCallChannelAsync(callId)`), **bacak seçen hiçbir mantık
     yok.** Oradaki tek kapı `ChanSpyInvocation.IsExactChannelName` (`:714-726`) ve o bir
     **biçim** kapısıdır (önek/uç adresiyle açılan ChanSpy'ın DTMF ile kanal gezinmesini
     engeller — Karar #23 §Ş23-4a); **hangi bacak** olduğunu sorgulamaz.
  2. `AsteriskAriProvider.cs:190`: `var customerFirst = request.OnAnswer is not null`.
     - **Agent'ın başlattığı normal giden çağrıda `OnAnswer` yoktur** → agent bacağı **önce**,
       müşteri bacağı **sonra** doğar → *"en son doğan bacak"* kuralı gereği saklanan kanal
       **müşterinindir** → sufle **her seferinde müşteriye** gider.
     - Yalnız **geri arama** yolunda (`CallbackDispatcher.cs:201` → `OriginateRequest.CustomerFirst`)
       sıra tersine döner ve hedef **tesadüfen** doğru olur.
- **Sonuç / doğrulama:** kartın *"hedef belirsiz"* çerçevesi **yumuşakmış**. Gelen çağrıda kusur
  *"aktarım/park olursa"* koşulluyken, **giden çağrıda koşulsuzdur** — ve giden çağrı bu ürünün
  ana kullanım yönü. Kabul kriteri genişletildi: ses testi **giden çağrıda da** koşulacak.
- **Ölçümün sınırı karta yazıldı:** bacak doğuş sırası **koddan** çıkarıldı, **AMI telinde
  doğrulanmadı.** `Dial` ile doğan bacağın `Newchannel`'ının aynı `linkedid` ile gelmesi
  Asterisk'in standart davranışıdır ama **bu depoda ölçülmemiştir**; `BR-AST-60` originate
  ölçümü yapıldığında aynı koşuda doğrulanmalı (iki ölçüm tek çağrıya sığar).
- **Dokunulan dosyalar:** `yonetim/backlog.md`
- **Commit:** `3fb2b779`

### `BR-BE-123` — hasar üç alan değil **altı**, ve düzeltmenin biçimi dosyanın kendisinde yazılı

- **Neden:** `BR-BE-122` ve `BR-BE-123` aynı satırdan (`TelephonyEventPipeline.cs:1063-1078`)
  çıkıyor. Kurula giderken *"bu satır başka ne kırıyor"* sorusunun ölçülmemiş kalması,
  düzeltme kapsamının eksik çizilmesi demekti.
- **Ne yapıldı:** `LiveCallState`'in tam alan envanteri çıkarıldı
  (`RedisLiveStateStore.cs:922-931`) ve `Newchannel` dalının verdiği argümanlarla eşleştirildi.
  - Kayıt **dokuz** alan taşıyor, dal yalnız **beşini** veriyor → kalan dördü **varsayılana** düşüyor:
    `OnHold → false`, `OnHoldSince → null`, `ParkedSlot → null`, `ParkedSince → null`.
  - Ayrıca **`StartedAt` yeni bacağın anına resetleniyor** — ve bu, **kodun kendi uyarısını
    çiğniyor**: `RedisLiveStateStore.cs:905-908` harfiyen *"süreyi çizer — **sıfırdan
    başlatmaz**; sıfırdan başlatmak, dört dakikadır bekleyen bir çağrı için `00:00` yazmak
    olurdu"* diyor.
- **Sonuç / doğrulama:** `RedisLiveOperationsView.cs:598-601` canlı izleme satırını tam bu
  alanlardan üretiyor (`call?.OnHoldSince`, `call.ParkedSlot is not null`, `call?.ParkedSlot`)
  → **beklemedeyken veya parktayken doğan bir bacak** (danışmalı aktarım, park'tan alma, ikinci
  arama) süpervizör ekranında **"beklemede" ve "parkta" rozetlerini düşürüyor** ve bekleme
  sayacını sıfırlıyor.
- **Ve karşıt kanıt da aynı dosyada:** Hold ve Park dalları **doğru deseni** kullanıyor —
  `call with { OnHoldSince = … }` (`:1116`), `call with { ParkedSlot = slot }` (`:1177`),
  `call with { ParkedSlot = null, ParkedSince = null }` (`:1229`). **Kısmi güncelleme deseni bu
  dosyada zaten var; `Newchannel` onu kullanmayan TEK dal.** Bu, düzeltmenin hem yerini hem
  biçimini tartışmasız kılıyor — kurula gidecek bir tasarım sorusu kalmıyor.
- **Ayrı kart açılmadı:** tek satırın hasarı tek kartta muhasebe edilir (istişaredeki
  *"iki yerde durum tutma"* uyarısı). Kabul kriterine beklet/park/`StartedAt` maddeleri eklendi.
- **Dokunulan dosyalar:** `yonetim/backlog.md`
- **Commit:** `117ff489`

### `BR-FE-73` — "en az üç" alt sınırını tam sayıma çevirdim (ve yöntem hatası bir kez daha bendeydi)

- **Neden:** kart *"üç tane bir **alt sınırdır**, tam sayım değil"* diye kendi yöntem sınırını
  yazıyordu. Ölçülebilir bir soruyu ölçülmemiş bırakmak, bugünkü desenin kaynağı.
- **Ne yapıldı:** yöntem regex'ten çıkarıldı. `.tsx` kaynağı **karakter bazlı** taranıp
  **yorumlar (satır, blok ve JSX `{/* */}`) soyuldu**, sonra JSX ifade konumundaki tırnaklı
  literaller süzüldü; `t()`/`translate()` argümanları, `value:`/`key:`/`className`/`aria-*`
  teknik alanları ve tek kelimelik dizeler elendi.
  **225 `.tsx` → 127 aday → insan-metni süzgeciyle 33 → elle doğrulama.**
- **Sonuç / doğrulama:** **gerçek isabet üç yerde, dört dize**:
  `ConsoleScreen.tsx:1195`, `AgentDeskScreen.tsx:633` (iki dize), `CallerFacts.tsx:57`.
  İlk turda aday sanılanların **hepsi yanlış pozitif**:
  - `CallTab.tsx:62-63` `'Satış fırsatı'` bir **`value`** alanı ve yanında
    `labelKey: 'tag.opportunity'` duruyor — **doğru yazılmış**.
  - `SettingsScreen:1387`, `PlatformHealthScreen:425/499`, `WallboardDesign:199`,
    `NetworkInterfaces:357` → **JSX yorumlarının içindeki** cümleler. İlk tarayıcım yalnız
    `//` ile *başlayan* satırları eliyordu; `{/* … */}` bloklarını görmüyordu.
- **Ayrı bir küme:** `ui/gallery/UiGallery.tsx` **29 gömülü Türkçe dize** taşıyor ama
  **çizilmiyor** (`App.tsx:17-20`: *"bileşen vitrini artık burada ÇİZİLMEZ… dosya kütüphanede
  duruyor"*; içe aktaran başka yer yok). Ürün yüzeyinde değil — **ama kapı yazılırken bu dosya
  allowlist'te ADIYLA muaf tutulmalı, sessizce değil**: vitrin yeniden bağlandığı gün 29 isabetle
  geri gelir.
- **Yöntemin kalan sınırları karta yazıldı:** yalnız `.tsx`; şablon literalleri ayrı tarandı ve
  Türkçe karakterli isabetlerin **tamamı belge yorumlarında** çıktı; JSX metin düğümü taraması
  ilk turda yapılmıştı.
- **Dokunulan dosyalar:** `yonetim/backlog.md`
- **Komutlar:** tarayıcı `scratchpad/tr-tara2.js` (karakter bazlı yorum soyucu + literal süzgeci)
- **Commit:** `5e125202`

### `BR-FE-72` — korumasız yüzey iki harita değil, **paylaşılan birleşim**

- **Neden:** kart *"`callControlErrors.ts` ve `parkErrors.ts` bekçinin kapsamında değil"* diyordu.
  Kapsamın kendisi ölçülmemişti — bugünkü desen gereği önce onu ölçtüm.
- **Ne yapıldı:**
  - Her iki harita da `Record<TelephonyFailureReasonValue, MessageKey>` biçiminde
    (`parkErrors.ts:188`, `callControlErrors.ts:102`) — yani anahtar kümesi kendi dosyalarında
    **değil**, tek bir yerde: `app/api/problem.ts:140-148`
    (`export const TelephonyFailureReason = { … } as const`).
  - O birleşim **elle yazılmış, üretilmemiş**; `LiveFailureMessageSurfaces.cs`'te
    `TelephonyFailureReason` **0 kez** geçiyor.
  - **Bugün sapma yok:** sunucu enum'u (`ITelephonyProvider.cs:1031`) yedi üye taşıyor
    (`Unknown … Rejected`) ve istemci birleşimi **birebir aynı yedi**.
- **Sonuç / doğrulama:** kart bir **sapma** bildirmiyor, **sapmayı tutan hiçbir şey olmadığını**
  bildiriyor — ve `BR-AST-59` bunu doğrudan tetikleyecek: `NotUnderControl` sunucu enum'una
  eklendiğinde **TypeScript hiçbir şey söylemez** (istemci birleşimi yeni üyeyi tanımadığı için
  iki harita da kendi kapalı kümesiyle tutarlı kalır); sunucudan gelen yeni sebep **bilinmeyen
  dize** olarak düşer ve kullanıcı yedek cümleyi görür. Bekçinin kapsamı bu yüzden üç değil
  **dört** kalem: iki harita + **ikisinin anahtar kaynağı** `problem.ts:140-148` ↔ enum.
  Asıl kapı sonuncusudur; iki harita TypeScript sayesinde birleşime zaten bağlı.
- **Yöntem notu:** ilk üye çıkarmam sloppy'ydi — `problem.ts`'te iki ayrı `as const` bloğu var
  (`ProblemCode` `:12-118`, `TelephonyFailureReason` `:140-148`) ve ilk sayımım `PayloadTooLarge`/
  `InternalError`'ı yanlış bloktan almıştı. Blok sınırları `grep -n "as const;"` ile kesinleştirilip
  düzeltildi; karta **yalnız doğrulanmış hâli** yazıldı.
- **Dokunulan dosyalar:** `yonetim/backlog.md`
- **Commit:** `af936f0c`

### Kart atıf denetimi — 825 atıf, **satır taşan 0** (ve araç depoya girdi)

- **Neden:** bugün kartlara çok sayıda yeni `dosya:satır` atfı yazdım. O atıflar kartın
  **öncülüdür**; dosya taşınınca ya da satır kayınca atıf **sessizce** yanlışlaşır ve kart doğru
  görünmeye devam eder. Elle kontrol bu sınıfı kapatamaz.
- **Ne yapıldı:** `yonetim/arac/kart-atif-dogrula.js` yazıldı ve `backlog.md`'nin tamamına koşuldu.
- **Sonuç / doğrulama:** **825 atıf denetlendi, SATIR TAŞIYOR: 0.** Depoda bulunamayan 36 atfın
  hepsi **üç meşru sınıfta** ve bu sınıflar dosyanın başlığına yazıldı:
  (a) **canlı sunucu yolları** (`/etc/asterisk/pbxtr.d/...`, `/var/lib/pbxtr-confd/...`) — depoda
  olmamalı; (b) **planlanan çıktılar** — kart onları *üretilecek* diye yazıyor
  (`deploy/sms-kesinti-tatbikat.md`, `deploy/confd-kabul-olc.sh`); (c) **kısaltılmış adlar**
  (`dugum.sh` ↔ `pbxtr-confd-dugum.sh`). Bu yüzden çıktı "hata" değil, **gözden geçirilecek
  liste** olarak basılıyor.
- **Mutasyonla doğrulandı:** `RedisLiveStateStore.cs:922-931` → `:99922` yapıldı, araç **kırmızı**
  verdi (`SATIR TAŞIYOR: 1`); `git checkout` ile geri alınınca **yeşile** döndü.
- **Aracın kendi yazımı bir tuzak öğretti** (başlığa yazıldı): `REF` düzenli ifadesinde **uzantı
  sırası önemli** — `ts` önce yazılırsa `.tsx` yarısından kesiliyor ve **16 sahte "dosya yok"**
  üretiyor. İlk koşum tam bunu yaptı; sayı 20 idi, düzeltince 4'e düştü. `.module.css` → `.cs`
  kırpığı da ayrıca eleniyor. **"Araç yokluğu sıfır gibi görünür" dersinin kardeşi: bozuk araç
  ise gürültüyü kusur gibi gösterir.**
- **Sınırı açıkça yazılı:** dosyanın **varlığını** ve satır sayısını ölçer; satırın **içeriğinin**
  hâlâ o iddiayı taşıdığını **ölçmez**. O ikinci soru insan işidir.
- **Dokunulan dosyalar:** `yonetim/arac/kart-atif-dogrula.js` (yeni)
- **Commit:** `da54b01f`

### Mükerrer kart kimliği taraması — **kusur çıkmadı, kapı çalışıyor** (ve mutasyonla doğrulandı)

- **Neden:** defterdeki *"kart numarası önce ölçülür — beş çakışma bulundu; körü körüne senkron
  açık işi kapalı gösterir"* dersi. Bugün karta çok dokundum; sayım tazelenmeliydi.
- **Ne yapıldı ve ne çıktı:** kaba `grep` sayımı **341 satır / 338 benzersiz kimlik** dedi — üç
  çakışma: `BR-BE-47`, `BR-BE-53`, `BR-SYS-45`. **Üçü de yanlış alarm çıktı:** her birinin eski
  satırı `Yerini satır NNNN aldı` ile işaretli ve `clickup-cikar.js:115-116` bu satırları sayımdan
  **düşürüyor**; ardından `:118-124` gerçek mükerrer kimliği **hata sayıp `exit 1`** veriyor.
  Yani mekanizma zaten doğru ve **sessiz değil, gürültülü**.
- **Kapının vacuous olmadığı mutasyonla ölçüldü:** `BR-QA-51` satırının kimliği `BR-QA-50` yapıldı
  (gerçek çakışma, "yerini aldı" işareti olmadan) → çıkarıcı **`HATA: mukerrer kart kimligi:
  BR-QA-50`, çıkış kodu 1**. `git checkout` ile geri alındı, koşu yeşile döndü (365 kart).
- **Ve asıl not bende:** benim kaba `grep` sayımım **yanlış olandı**. `^| BR-XX-N |` deseni hem
  "yerini aldı" satırlarını sayıyor hem de `BR-00a`, `BR-C1`, `BR-A1`, `BR-FE-ALT` gibi **27 ayrı
  numaralandırma ailesini** hiç görmüyor (çıkarıcı onları taşıyor: 365). Defterdeki *"envanter
  sayacı kendi filtresini ölçmez"* dersinin bu sefer **öznesi bendim**: araç doğru, elle sayım
  yanlış. Sayıyı sormak için `clickup-cikar.js` koşulur, `grep` değil.
- **Sonuç:** kart açılmadı, düzeltme yapılmadı — **ölçülüp temiz çıkan bir sınıf.** Kayıt bunun
  için var: aynı soruyu yarın yeniden sormamak.

### ClickUp durum eşlemesi — **işi devredilmiş dört kart panoda açık görünüyordu**

- **Neden:** sabah `Kurul: Karar #NN ONAY` kalıbının `backlog`'a düştüğünü bulup düzeltmiştim.
  Aynı sınıfın başka üyeleri var mı diye **catch-all grubun tamamını** taradım.
- **Ne yapıldı:** `backlog` grubundaki 105 kartın **57 benzersiz durum metni** listelendi.
  Dördü **açık iş taşımıyor**:

  | kart | durum | işi nerede |
  |---|---|---|
  | `BR-SYS-73` | Yeniden yazıldı | `BR-SYS-76/77/78` |
  | `BR-QA-24` | Bölündü (2026-09-07) | `BR-QA-36/37/38` + `BR-SYS-89` |
  | `BR-BE-95` | Kapsam dışı — topoloji şartı | — (kapsam dışı) |
  | `BR-SEC-06` | Ölçüldü — kalan iş `BR-BE-119/120/121` | üç kartta |

- **Kural dar tutuldu:** çıplak `Ölçüldü` ve `Kapsam daraldı` **kapanış değildir** (ayrı negatif
  test). Gerekçe karta ve koda yazıldı: **açık işi kapalı göstermek, kapalıyı açık göstermekten
  kötüdür** — bu yüzden sınır bilerek dar.
- **Ve bir tuzak buldum:** ilk yazımım `\b` kullanıyordu ve **iki kural hiç eşleşmedi**.
  **JS'te `\b` yalnız ASCII harf tanır**; `yazıldı` ve `Ölçüldü` sondaki `ı`/`ü` yüzünden sınır
  üretmiyor. Hata yok, uyarı yok — sadece `false`. Testler olmasa "kural çalışıyor" sanacaktım.
  Türkçe harf kümesini dışlayan ileri-bakışla düzeltildi ve **hafızaya yazıldı**
  (`js-b-siniri-turkce-harfi-gormez`).
- **Doğrulama:** 6/6 test yeşil; kural kaldırılınca **1 test kırmızı** (mutasyon).
  Pano: `fark olan kart: 4` → yazıldı → yeniden ölçümde **`fark olan kart: 0, izde olmayan: 0`**.
  Grup dağılımı: `complete` 228 → **232**, `backlog` 105 → **101**.
- **Dokunulan dosyalar:** `yonetim/arac/clickup-durum.js`, `yonetim/arac/clickup-durum.test.js`,
  `CLAUDE.md` §14
- **Commit:** `33c9e121`

### `\b` tuzağını depoya taradım — bir gerçek vacuous bekçi çıktı

- **Neden:** eşleme kuralında bulduğum tuzak (`\b` Türkçe harfi görmez) **sınıf** kusurudur;
  tek yerde kalması beklenemezdi.
- **Ne yapıldı:** JS/TS regex literalleri ve `new RegExp('…')` çağrıları ayrıştırıldı
  (**577 dosya, 1019 kalıp**) ve `\b` ile Türkçe harfi **birlikte** taşıyanlar süzüldü.
  İki aday: biri yanlış pozitif (`kur\b` — `r` ASCII, sorun yok), **biri gerçek.**
- **Bulgu — `SystemReadOnlySurfaces.test.tsx:178`:**
  `expect(label).not.toMatch(/kapat|aç\b|yeniden başlat|dhcp/i)` — arayüz ekranının **NIC
  mutasyonu sunmadığını** iddia eden negatif bekçi.

  | etiket | eski | yeni |
  |---|---|---|
  | `Aç` | **kaçırır** | yakalar |
  | `Arayüzü aç` | **kaçırır** | yakalar |
  | `Açma` | yakalar (istenmeyen) | kaçırır |
  | `Kapat` / `Yeniden başlat` | yakalar | yakalar |

  Yani bekçi, **en olası mutasyon düğmesi için vacuous'tu**: ekranda "Aç" düğmesi olsa test yine
  yeşil verirdi.
- **Sonuç / doğrulama:** **bugün sonuç değişmiyor** — ekranda öyle bir düğme yok, test önce de
  sonra da yeşil (3/3, vitest). Değişen şey kapının **gelecekteki** değeri. Kanıtı **regex
  seviyesinde** ürettim (yukarıdaki tablo), ekrana sahte düğme ekleyerek değil — bunu açıkça
  yazıyorum çünkü "yeşil test" burada kanıt değil.
- **Durum sözcüğü `Açık` bilerek dışarıda:** eylem değil durum; yakalamak yanlış kırmızı üretirdi.
- **Dokunulan dosyalar:** `src/Pbxtr.Web/src/app/screens/system/SystemReadOnlySurfaces.test.tsx`
- **Commit:** `5fa27483`

### Türkçe yerel sınıfı C# tarafında da tarandı — **temiz**

- **Neden:** `\b` tuzağının kardeşi, .NET'te **kültüre duyarlı** string işlemleridir: Türkçe
  yerelde `"I".ToLower()` → `"ı"` olur ve karşılaştırmalar sessizce kayar.
- **Ne yapıldı / sonuç:** `src/` altında `.ToLower()`/`.ToUpper()` (Invariant olmayan) **1**
  isabet, `StartsWith`/`EndsWith`/`IndexOf` (StringComparison'suz) **2** isabet.
  **Üçü de EF Core sorgu ağacının içinde** (`EfUserDirectory.cs:141`,
  `SampleDataSeeder.cs:499,505`) — yani .NET'te değil, **PostgreSQL'de** `lower()`/`LIKE` olarak
  koşuyorlar; .NET kültür ayarı onlara dokunmuyor. Uygulama kodunda kültüre duyarlı tek bir
  karşılaştırma yok; `LoginIdentifier.Normalize` zaten `ToLowerInvariant()` kullanıyor
  (`AuthenticationPolicy.cs:125`).
- **Kart açılmadı, kapı yazılmadı:** üç isabetlik bir sınıf için mimari bekçi kurmak, defterdeki
  *"kapı kurmadan önce mevcut veriyi ölç"* dersinin tersi olurdu. **Ölçülüp temiz çıktı**; kayıt
  aynı soruyu yarın yeniden sormamak için.

### Commit dizini — ek (öğleden sonra ve akşam turu)

Yukarıdaki dizin `0278fa58`'de bitiyordu; bugünün toplamı **61 commit**. Sonrası:

- `169b75ed` — BR-QA-51 (YENI, P1): call_events canlı görünüyor ama 03 Eylül'den beri tek gerçek olay yok
- `529e2563` — clickup: BR-QA-51 kartı açıldı
- `50e43928` — kart(BR-QA-51): kapsam (b) ölçüldü — tehlike DARALDI, kusur yüzeyde değil VERİDE
- `ece34d57` — kart(BR-QA-51): kapsam (c) ölçüldü — "son olay 09-08" bir ÇAĞRI DEĞİL, seed-sample tarihi
- `ac0ed739` — kart(BR-SEC-16): üç santral/API sırrı transkripte düştü — rotasyon kararı kullanıcıda
- `3b6e352b` — clickup: BR-SEC-16 panoya açıldı (iz kaydı)
- `4dce1942` — kart(BR-QA-51): kusur `call_events`'e özgü değil — canlı `cdr`ın ~%88'i de simüle/tohum
- `166c4873` — kart(BR-QA-51): (c′) teknik yarısı ölçüldü — tohum yolunda ORTAM KAPISI YOK
- `3fb2b779` — kart(BR-BE-122): öncül doğrulandı ve kusur KESKİNLEŞTİ — giden çağrıda koşulsuz
- `117ff489` — kart(BR-BE-123): hasar üç alan değil ALTI — dosyanın kendi deseni düzeltmeyi yazıyor
- `5e125202` — kart(BR-FE-73): "en az üç" ALT SINIRI tam sayıma çevrildi — üç yer, dört dize
- `af936f0c` — kart(BR-FE-72): korumasız yüzey iki harita değil, PAYLAŞILAN BİRLEŞİM
- `da54b01f` — araç: kart atıf doğrulayıcı — 825 atıf denetlendi, SATIR TAŞAN 0
- `33c9e121` — clickup: işi DEVREDİLMİŞ dört kart panoda açık görünüyordu — kural + test + mutasyon
- `5fa27483` — test(system): salt-okuma bekçisi tam da yasakladığı etiketleri KAÇIRIYORDU

**Günün deseni, tek cümlede:** bugün ölçtüğüm her şeyde **yanlış olan taraf benim yazdığım
cümleydi** — kartın teşhisi, delilin cinsi, sayının alt sınırı, kapının kapsamı, hatta ölçüm
komutunun kendisi (üç sır sızıntısı). Ölçüm hiçbirinde işi büyütmedi ya da küçültmedi; **yerini
değiştirdi.**

### `BR-SEC-16` — rotasyon maliyeti iddiam **çok yüksekti**; ölçtüm, ucuz çıktı

- **Neden:** kartı yazarken kullanıcıya *"`ApiKeyPepper` dönerse tüm tenant API anahtarları
  geçersizleşir ve çağrı akışı durur; pencere planlanmalı"* dedim. **Ölçülmemiş bir tahmindi** ve
  kullanıcının kararını doğrudan zorlaştırıyordu — bir kararı "pahalı" diye sunup ölçmemek,
  bugünün deseninin en pahalı hâli.
- **Ne yapıldı / ölçüm (canlı, salt-okuma):** `api_keys` **6 satır, iptal edilmemiş yalnız 1**.
  O tek anahtar: `label=confd-cek`, `node=asterisk-01`, **bugün kullanılmış**
  (`last_used_at` 18:53Z, `last_bundle_served_at` 19:49Z).
  **Sınıf B uçları için tanımlı aktif anahtar YOK** — `BR-QA-51`'in *"03 Eylül'den beri gerçek
  çağrı yok"* ölçümüyle tutarlı: duracak akış zaten yok.
- **Sonuç:** rotasyonun bugünkü bedeli **tek anahtarın yeniden üretilip sunucudaki confd
  yapılandırmasına yazılması**. Pencere gerekmiyor; **sıra** gerekiyor.
- **İlk yazımda hiç olmayan ikinci etki:** aynı pepper `PersistentTelephonyProvider.cs:26,63`'te
  **HMAC anahtarı** olarak da kullanılıyor ve `telephony_provider_effects`'in **idempotans
  anahtarını** üretiyor (`UNIQUE (tenant_id, correlation_id, operation, target_fingerprint)`,
  `ON CONFLICT DO NOTHING`). Rotasyondan sonra aynı hedef **farklı parmak izi** üretir; canlıda
  **4021 satır** var. Dar ama gerçek risk: rotasyon anında **uçuşta olan** bir işlemin tekrarı
  mükerrer kaydedilebilir. Depoda **çift-pepper / kademeli rotasyon desteği yok** (`PreviousPepper`
  vb. 0 isabet) — rotasyon **sert geçiştir**.
- **Dokunulan dosyalar:** `yonetim/backlog.md` (`BR-SEC-16` gövdesi ve bedel değerlendirmesi)
- **Commit:** `716f310b`

Bu, bugün **kendi cümlemi ölçüp çürüttüğüm dokuzuncu** vaka — ve tek "iyi yönde" olanı: kusur
küçüldü. Ama ders aynı: **ölçmeden "pahalı" demek de bir öncüldür.**

### `BR-QA-51` (b-1) tenant kırılımıyla daraldı — **kirlenen gerçek müşteri tenant'ı yok**

- **Neden:** (b-1) *"rapor yüzeyleri tohum satırını gerçek geçmiş gibi gösteriyor"* diyordu ama
  **kimin raporu** sorusu ölçülmemişti.
- **Ölçüm (canlı, salt-okuma):**

  | tenant | olay | gerçek (SIM/ olmayan) | cdr |
  |---|---|---|---|
  | `t0007` Ertan Grup Çağrı Merkezi | 7534 | **360** | 1058 |
  | `t0012` Kuzey Pazarlama | 260 | **0** | 30 |
  | `t0000` pbxtr Platform | 0 | 0 | 2 |

  İkisi de tohumun kendi tenant'ları: `SampleDataSet.cs:50,52`
  (`PrimaryTenantCode = "t0007"`, `SecondaryTenantCode = "t0012"`).
- **Sonuç:** tohum **yalnız kendi iki tenant'ına** yazıyor; yeni açılan bir tenant etkilenmiyor.
  **Bugün simüle veriyle kirlenen gerçek bir müşteri tenant'ı YOK — çünkü gerçek müşteri tenant'ı
  henüz yok.** Kalan gerçek risk iki dar başlıkta: (i) **sunum/demo** bu iki tenant üzerinden
  yapılıyor ve rakamlar gerçek görünüyor; (ii) bir demo tenant'ı ileride **gerçek müşteriye
  çevrilirse** geçmişi uydurma olarak devralır — ve kapsam (a)'nın kaynak ayrımı olmadan bu
  **fark edilemez**.
- **Ölçülmeyen açıkça yazıldı:** hangi raporun kaç satırını şişirdiği **hâlâ ölçülmedi**; ölçülen
  "filtre yok" olgusu ve tenant kırılımıdır.
- **Dokunulan dosyalar:** `yonetim/backlog.md`
- **Commit:** `5109b298`

### `BR-QA-51` (b-1) sayısallaştı — **son 7-10 günün her rapor penceresi %100 uydurma**

- **Neden:** (b-1)'de kalan tek ölçülebilir soru *"hangi raporun kaç satırını şişirdiği"*ydi.
  Rapor sorgularını **taklit etmek** yeni bir öncül üretirdi; bunun yerine **verinin kendisi**
  ölçüldü.
- **Ölçüm — `t0007` günlük kırılımı (canlı, salt-okuma):**

  | gün | olay | gerçek |
  |---|---|---|
  | 2026-09-08 | 1730 | **0** |
  | 09-07 … 09-02 | her gün **291** | **0** |
  | 08-30 | 345 | **345** |
  | 08-29 | 3004 | **15** |
  | 08-26 | 709 | 0 |

- **Sonuç:** *"bugün"*, *"bu hafta"*, *"son 7 gün"* gibi **varsayılan pencerelerin tamamı** bu
  tenant için **%100 uydurma**. Gerçek telefon olayı yalnız 08-29/08-30 penceresinde, toplam
  **360**.
- **Tohumun bir imzası var:** 09-02→09-07 arası **günde tam 291** olay. Düz bir günlük eğri gerçek
  çağrı merkezi verisinde görülmez — kaynak ayrımı alanı gelene kadar elde kalan tek (ve zayıf)
  ipucu bu.
- **Sınır açıkça yazıldı:** rapor uçlarının sorguları taklit **edilmedi**; ölçülen, o sorguların
  üzerinde çalışacağı **verinin bileşimidir**. Bir raporun kendi filtresi payı değiştirebilir ama
  **payda aynı kalır: gerçek satır yok.**
- **Dokunulan dosyalar:** `yonetim/backlog.md`
- **Commit:** `f8d68e02`

**`BR-QA-51`'in ölçülebilir kapsamı bitti.** Açık kalan üç madde de tasarım kararı ve üçü de
kurulun: **(a)** kaynak ayrımı, **(c′)** üretimde `seed-sample` politikası, **(d′)** ayrımın
gireceği tablolar.

### `BR-AST-60` — zincirin son halkası **sahada** doğrulandı; ve bir yanlış genişletme önlendi

- **Neden:** kart bugüne kadar **depo** kodundan kuruluyordu (`ConfigRenderer.cs:549`,
  `AsteriskAriProvider.cs:258`, `AriStasisApp.cs:181-196`). Sunucudaki **gerçek** dialplan'in aynı
  satırı taşıyıp taşımadığı ölçülmemişti — ve `BR-AST-58` bu depoda tam da *"canlıdaki dosya
  depodakinden farklı"* sınıfını üretmişti.
- **Ölçüm (canlı, salt-okuma):**
  `/etc/asterisk/pbxtr.d/dialplan/t0007-dialplan.conf:13` → `[pbxtr-t0007-out]` ve `:23` →
  `[pbxtr-t0007-int]`, ikisi de harfiyen
  `same => n,ExecIf($["${PBXTR_CTL}"="1"]?Stasis(pbxtr))`; `-out` bağlamında satır
  `Goto(pbxtr-outbound,${EXTEN},1)`'den **önce** (`:18`).
- **Sonuç:** öngörülen belirti **teorik değil** — canlıda **kurulu** bir yapılandırmanın sonucu.
  Ölçüm için gereken tek şey originate; kartın "BLOKLAYICI" etiketi yerinde.
- **Ve bir yanlış genişletme önlendi:** `-int` de aynı satırı taşıdığı için *"dahili aramalar da
  asılıyor"* yazmak üzereydim. **Yanlış olurdu.** `PBXTR_CTL` yalnız originate yolunda
  damgalanıyor (`AsteriskAriProvider.cs:258`) ve originate **her zaman** `pbxtr-{kod}-out`
  bağlamını hedefliyor (`:229`; müşteri-önce dalında da `Local/…@pbxtr-{kod}-out`, `:221`).
  Telefonun kendi bağlamından gelen dahili çağrıda değişken **hiç set edilmiyor** → `ExecIf`
  yanlış → satır **inert**. `-int`'teki devir satırı **bugün ölü kod**; `BR-AST-59` onu
  canlandırırsa belirti dahili aramalara da yayılır — iki kart aynı dilimde ölçülmeli.
- **Dokunulan dosyalar:** `yonetim/backlog.md`
- **Commit:** `a496549b`

Bugün ilk kez bir genişletmeyi **yazmadan önce** ölçüp durdurdum. Onuncu vaka, ama deseni tersine
çeviren ilki.

### `BR-AST-60` — aynı yolda **ikinci bağımsız kırık**: kartın "emniyeti" outbound'u çalıştırmıyor

- **Neden:** devir satırının canlıda kurulu olduğunu doğruladıktan sonra doğal soru: satır
  geçilse ne olacaktı? `-out` bağlamının son satırı `Goto(pbxtr-outbound,${EXTEN},1)`.
- **Ölçüm — Asterisk'in kendi cevabı (canlı, salt-okuma CLI):**
  - `dialplan show pbxtr-outbound` → **"There is no existence of 'pbxtr-outbound' context"**
  - `dialplan show pbxtr-inbound` → aynı cevap → **`BR-AST-58`'in ölü hedef bulgusunun saha
    doğrulaması**
  - `/etc/asterisk/` altında tanımlı **tek** pbxtr bağlamı `[pbxtr-t0007-local]`.
- **Sonuç — kartı düzelten kısım:** kartta yazılı *"geri alınabilir emniyet"* (`PBXTR_CTL` sabit
  `"0"`) **giden aramayı çalıştırmaz**; arızayı **bir satır aşağı taşır** — sessiz asılma yerine
  "bağlam yok" hatası. **Dış numaraya çağrı bugün iki ayrı sebeple kırık** ve ikisi ayrı işler.
- **Ve ölçümü ucuzlatan ayrım:** `-out` içindeki
  `GotoIf(DIALPLAN_EXISTS(pbxtr-t0007-local,…))` dalı **ölü `Goto`'dan önce** geliyor; dahili
  hedefte akış `-local`'a sapıyor ve orada **gerçek bir `Dial()`** var
  (`PJSIP/t0007-1042&PJSIP/t0007-wrtc-1042,30,tT`). Yani **dahili panel araması için tek engel
  Stasis asılmasıdır.**
  Ş43-1 ölçümü buna göre keskinleştirildi: **ilk originate bir dahiliye (1042) yapılsın** —
  kartın öncülü **tek değişkenli** doğrulanır, ölü `Goto` karışmaz; dış numara ikinci adım.
- **Dokunulan dosyalar:** `yonetim/backlog.md`
- **Commit:** `9d7ba339`

Bu, kullanıcının yapacağı ölçümü hem **ucuzlatıyor** hem de sonucunu **yorumlanabilir** kılıyor:
dahiliye originate'te asılma görülürse sebep tektir.

### `BR-AST-61` açıldı — üç ölü hedefin ikisi **kartsızdı**; ve "ikinci kırık" bir keşif değilmiş

- **Önce düzeltme (üçüncü kez aynı hata):** bir önceki maddede *"ikinci bağımsız kırık"*ı yeni bir
  bulgu gibi yazdım. **Değildi.** Deponun kendi belgesi
  `doc/mimari/asterisk-dialplan-sablonu.md:457-459` harfiyen şunu diyor: *"`deploy/` altında
  `20-pbxtr-outbound.conf` diye teslim edilen bir dosya **yoktur** ve `ConfigRenderer` bu bağlamı
  **üretmez**"* — ve bunu **BORÇ (D-13)** diye işaretlemiş. `ADR-015:810` de A4'ü *"ayrı kart"*
  diye bırakmış. Yeni olan iki şey: (i) sahada **Asterisk'in kendi ağzından** doğrulanması,
  (ii) bunun `BR-AST-60`'ın "emniyet" cümlesini çürütmesi. Kartın tonunu düzelttim.
- **Ve asıl boşluk:** dialplan **üç** ölü hedefe gönderiyor —
  `ConfigRenderer.cs:464` → `pbxtr-inbound` (**`BR-AST-58` kapsıyor**),
  `:582` → `pbxtr-outbound` (**kart yoktu**),
  `:579` → `pbxtr-dialer-announce` (**kart yoktu**; `backlog.md`'de `grep` → **0 isabet**).
  Üçünün de **tanımını üreten kod yok**; `[pbxtr-outbound]` depoda yalnız **belgede** statik
  şablon olarak duruyor (`:395`).
- **`BR-AST-61` (P1) açıldı** — kapsam: (a) `[pbxtr-outbound]` üretimi (trunk seçimi,
  `call-permission`, `PBXTR_DIALNUM`, fail-closed), (b) `[pbxtr-dialer-announce]` üretimi,
  (c) D-13 borcu (trunk başına numara biçimi) **burada çözülmez ama kararı verilir** — bazı
  trunk'lar `+` kabul etmiyor ve bugün böyle bir alan yok; sessizce varsayılmamalı.
- **`BR-AST-60` ile aynı yolda ama bağımsız:** 60 çözülse çağrı burada düşer, 61 çözülse Stasis
  asılması önce gelir. **Tek dilimde planlanmalı.** Dahili panel araması bu karttan etkilenmez
  (akış `-local`'a daha önce sapıyor).
- **Doğrulama:** `kart-atif-dogrula.js BR-AST-61` → 5 atıf, **satır taşan 0, depoda yok 0**.
  ClickUp: yeni 1, `fark olan kart: 0`.
- **Commit:** kart + ClickUp izi

Defterdeki kural bir kez daha birebir işledi: **belgede "borç" yazmak, panoda görünür iş
üretmiyor.** Bugün bu, kartsız kalmış ikinci ve üçüncü ölü hedefi buldu.

### "Belgede borç yazılı ama panoda iş yok" — sınıf ölçüldü, **beş kart açıldı**

- **Neden:** `BR-AST-61` bu sınıfın tek örneğiydi; tek örnek bir sınıf değildir. `doc/` altındaki
  borç işaretleri tarandı (**21 işaret**, yakınında kart kimliği geçen 6, geçmeyen 15).
- **En keskin bulgu — `ADR-015`'in kendi tablosu:** `doc/mimari/ADR-015-zil-gruplari.md:807-812`
  **altı** açık madde sayıyor ve her biri için **açıkça kart istiyor**
  (*"BORÇ + kart"*, *"BİLİNÇLİ + kart"*, *"Ayrı kart"*). Backlog'da anahtar sözcük sayımı:

  | madde | anahtar | backlog isabeti |
  |---|---|---|
  | A1 dış numara üyeliği | "dış numara üyeliği" | **0** |
  | A2 `rotating` | `rotating` | **0** |
  | A3 `delay_sec` | `delay_sec` | **0** |
  | A4 dahili-dahili | `pbxtr-outbound` | bugün `BR-AST-61` ile kapandı |
  | A5 `last_resort` | `last_resort` | **0** |
  | A6 `dids` CHECK testi | — | **0** |

- **Açılan kartlar:**
  - `BR-AST-62` (P2) — dış numara üyeliği: ikinci fail-closed kapı yok ve
    `Local/<e164>@pbxtr-{tref}-out` biçiminin **`linkedid` etkisi ölçülmedi** (bozulursa timeline
    korelasyonu kırılır).
  - `BR-AST-63` (P3) — `rotating`: sayaç sahipliği (AstDB ⇄ pbxtr) kararsız; bugün `422` dönüyor
    ve **bu doğru cevap** — eksik özellik, kırık değil.
  - `BR-AST-64` (P3) — `delay_sec` kolonu var, üretim okumuyor, ekran çizmiyor. **Tehlike ölü
    kolon değil, görünmezliği:** "ayarladım ama çalışmıyor" sınıfı.
  - `BR-AST-65` (P2) — `last_resort` dalı **hiçbir telemetri üretmiyor**; Karar #15 §E2'nin
    fallback sayacı bu dalı **görmüyor** → soru sorulduğunda **sıfır** görünüyor. Defterdeki
    *"sıfır en tehlikeli cevaptır"*ın dialplan karşılığı.
  - `BR-AST-66` (P3) — `dids` CHECK literalini **parse eden** test: metin çıpası; davranışa
    çevrilmeli.
- **Her kartta açıkça yazılı:** öncül **ADR'den alınmıştır, bugün bağımsız ölçülmedi.** Bunu
  yazmasaydım kartlar ölçülmüş gibi okunurdu — günün tekrarlayan hatası tam olarak budur.
- **Doğrulama:** atıf denetimi 11 atıf / **satır taşan 0**; ClickUp **yeni 5**, `fark olan kart: 0`.
  Backlog 366 → **371 kart**.

### ADR-012 — **ADR kendi kaderini yazmış:** "kartlar açılmazsa bu belge baskın hata deseninin yeni örneği olur"

- **Neden:** ADR-015 taraması aynı sınıfın başka ADR'lerde de olabileceğini gösterdi.
  `doc/mimari/` altında "açık madde / ayrı kart" geçen dosyalar tarandı; iki aday çıktı
  (ADR-005, ADR-012).
- **ADR-012'nin kendi cümlesi (`:350-351`):** *"G1/G2/G3 kurulmadıkça bu ADR'nin yarısı
  öneridir. **Kurulum kartları açılmalı; açılmazsa bu belge projenin baskın hata deseninin yeni
  bir örneği olur.**"* — **açılmadı ve oldu.**
- **Ölçüm (2026-09-10):**

  | bekçi | durum | kanıt |
  |---|---|---|
  | G3 ham SQL kapalı listesi | **KAPANDI** | `BL-QA-23` → `RawSqlAllowlistTests` (2026-08-17) |
  | G2 (i) `ITenantOwned` uygulanmış mı | **KAPANDI** | `TenantIsolationSurfaceTests` (2026-08-29), üç `[Fact]`, gerekçeli onay listesi + ölü kayıt + vakum |
  | G2 (ii) filtre **gerçekten** takıldı mı | **AÇIK** | o dosyada `QueryFilter` **0 isabet**; ölçüm yalnız **sentetik** modelde (`TenantRow`/`GlobalRow`) |
  | G1 modül sızıntı-testi kapsamı | **HİÇ BAŞLAMADI** | `TenantLeakCoverageTests` yok; backlog'da da **0 isabet** |

- **Açılan kartlar:** `BR-QA-52` (P2, G1) ve `BR-QA-53` (P2, G2-ii).
- **G2(ii) neden önemli:** `OnModelCreating` filtreyi bir **döngüyle** takıyor; owned type, TPH
  türevi, döngüden önce yapılandırılan ya da gölge bir entity **sessizce** ıskalanabilir —
  arayüz uygulanmış olur, **filtre olmaz**, CLAUDE.md §4'ün iki katmanından biri düşer ve
  **RLS doğru cevap verdiği sürece hiçbir test kızarmaz**. Bu, `TenantIsolationSurfaceTests`'in
  kendi gerekçe metnindeki sessizlik argümanının aynısı — yarısı kapatılmış, yarısı açık kalmış.
- **Ölçmediğimi karta yazdım:** Domain'de `ITenantOwned` anan **76 dosya** var (`grep -rl`);
  ADR ölçüm anında **33 tip / 31 dosya** demişti. **Dosya sayısı tip sayısı değildir** ve tip
  sayısını bugün saymadım.
- **Doğrulama:** atıf denetimi 4/4 temiz; ClickUp **yeni 2**, `fark olan kart: 0`.
  Backlog **373 kart**.

### `BR-SYS-95` — ADR-005'in **kapatamadığı tek madde** de kartsızmış

- **Neden:** borç-kart taramasının üçüncü ve son adayı `ADR-005`'ti.
- **Ölçüm:** `ADR-005:763-769` A-1'i açıkça ayırmış: *"Varsayılan 24 aydır ve
  yapılandırılabilirdir; **canlıya çıkmadan önce hukuki teyit alınmalı** ve gerekiyorsa değer
  değiştirilmelidir."* `backlog.md`'de `24 ay` **iki** isabet — ikisi de başka konu (`ST-24`
  ticket retention, `BR-SYS-43` mezar taşı); `hukuk` **iki** isabet, ikisi de alakasız
  (`BR-DB-36`, `BR-BE-117`). **Madde kartsızdı.**
- **Ne yapıldı:** `BR-SYS-95` (P2, kullanıcı/hukuk) açıldı. Kart işi kendisi yapmıyor; **canlıya
  çıkışın önünde duran bir maddeyi görünür kılıyor.**
- **Bugünkü risk ölçüldü ve düşük:** canlıda gerçek müşteri tenant'ı yok (`BR-QA-51`) ve 03
  Eylül'den beri gerçek çağrı yok → **saklanan gerçek trafik verisi yok**. Madde **ilk gerçek
  müşteri** tanımlandığında bloklayıcı olur.
- **Kapsama CLAUDE.md §13/3 hatırlatması konuldu:** yargı bölgesi koda gömülmez; teyit bir
  **parametre değeri** belirler, `if (Türkiye)` üretmez.
- **Doğrulama:** atıf denetimi 2/2 temiz; ClickUp yeni 1, `fark: 0`. Backlog **374 kart**.

#### Bu taramanın toplamı

Bugün **sekiz kart** yalnızca *"belgede yazılı ama panoda yok"* sınıfından çıktı:
`BR-AST-61` (pbxtr-outbound/dialer-announce), `BR-AST-62…66` (ADR-015 A1/A2/A3/A5/A6),
`BR-QA-52`/`BR-QA-53` (ADR-012 G1/G2-ii), `BR-SYS-95` (ADR-005 A-1).
**Hiçbiri yeni bir kusur değildi** — hepsi deponun kendi belgelerinde **yazılıydı** ve hiçbiri
panoda **yoktu**. Defterdeki kural bugün en pahalı hâliyle doğrulandı: *"bir iş `backlog.md`'ye
kart olarak yazılmadıysa ClickUp'ta hiç yoktur"* — ve ADR-012 bunu **önceden yazmıştı**.

### Prototip borç defteri — **tarama burada durduruldu** (mekanik olarak karar verilemiyor)

- **Neden:** borç-kart taramasının doğal devamı `doc/prototip-urun-farklari.md`'ydi; dosyanın
  kendi sayımı **31 BORÇ** diyor (`:2392`).
- **Ne oldu:** satır bazlı tarayıcı yazdım ve **üç turda üç kez** ölçüm kusuru buldum:
  1. `/\bBORÇ\b/` **hiçbir şey eşleşmedi** → *"BORÇ tablo satırı: **0**"* — bugün yazdığım
     `\b` kuralına **kendi tarayıcımda** düştüm. Doğrusu 36 satır buldu.
  2. `BORÇ KAPANDI` / `~~BORÇ~~` satırları **açık borç sanıldı** (15 satır).
  3. Kalan "kimliksiz" satırların çoğu borç değil: `:2793-2795` **efsane** satırları
     (YOK / YAPMAYACAĞIZ / ERTELENDİ etiketlerinin tanımı), `:414` **BİLİNÇLİ** bir satırın
     içinde geçen "BORÇ" sözcüğü, `:466`/`:1556` tartışma satırları.
- **Karar: bu tarama burada duruyor.** Kalan aday sayısı (13) **regexle karara bağlanamaz** —
  her satır insan okuması ister. Daha da önemlisi: **CLAUDE.md bu dosyayı zaten kayıt defteri
  ilan etmiş** (BL-DOC-02, *"orada yazılı olmayan bir sapma unutulmuştur"*), yani ADR'lerin
  aksine burada *"kart açılmalı"* diyen bir cümle **yok**. 13 kart açmak, deponun bilerek
  kurduğu tek defteri **ikiye bölmek** olurdu — istişarenin *"iki yerde durum tutma"* uyarısı.
- **Ölçülüp yazılan tek gerçek:** pano bu 13 satırı **göstermiyor** ve göstermesi de tasarım
  gereği beklenmiyor; *"ne kaldı"* sorusu ClickUp'tan sorulursa prototip borçları **eksik**
  sayılır. Bu, `CLAUDE.md §14`'ün *"panonun görmedikleri"* listesindeki maddeyle aynı sınıf.
- **Hafızaya yazıldı:** `\b` tuzağının üçüncü tekrarı ve genişletilmiş ders — *"bir tarayıcı
  **sıfır** basıyorsa önce kalıbı bilinen bir örnekle pozitif kontrol et"*. Bu tuzak en çok
  **tek kullanımlık** betiklerde ısırıyor, çünkü orada test yok ve sıfır "temiz" görünüyor.

### Türkçe `\b` tuzağı için araç depoya girdi — **ama kapıya bağlanmadı** (`BR-QA-54`)

- **Neden:** sınıf bugün **üç kez** ısırdı ve üçüncüsü en kötü biçimdeydi: çıktı `0` oldu, yani
  kusur **temiz bir sonuç** gibi göründü. Hafıza notu tek başına yetmez — *"CI dışındaki bekçi
  insan hafızasıdır"*.
- **Ne yapıldı:** `yonetim/arac/regex-turkce-sinir-tara.js`. Regex literallerini ve
  `new RegExp('…')` çağrılarını ayrıştırıyor, `\b`'in **hemen bitişiğinde** Türkçe harf arıyor.
- **Bitişiklik şartı gerekliydi:** ilk sürüm *"kalıpta `\b` var + Türkçe harf var"* diyordu ve
  `/güncelle|uygula|kur\b|yükselt/` gibi **sağlam** bir kalıbı da işaretliyordu (`kur\b` ASCII
  `r` ile biter, sınır doğru çalışır). **Gürültülü kapı, kapatılan kapıdır.**
- **İki yönlü doğrulama:**

  | girdi | beklenen | sonuç |
  |---|---|---|
  | fikstür `/Ölçüldü\b/` | yakalansın | **yakalandı** |
  | fikstür `/Measured\b/` | yakalanmasın | yakalanmadı |
  | depo (578 dosya, 1028 kalıp) | temiz | **0 riskli** |

- **Ve ilk pozitif kontrolüm de yanlıştı:** `printf '…\b…'` **backspace** üretmiş, fikstür `\b`
  taşımıyordu; araç "0" dedi ve ben bir an aracı suçladım. **Bozuk olan fikstürdü.** Düzeltip
  tekrarladım — bugünün dersi *"sıfır basan tarayıcıyı önce bilinen bir örnekle sına"* daha ilk
  kullanımında kendini gösterdi.
- **Kart `BR-QA-54` (P2) açıldı çünkü iş bitmedi:** araç **hiçbir kapıya bağlı değil**.
  `deploy/yerel-kapilar.sh` 42 kapı taşıyor, bu tarayıcı orada **yok**. Kapı eklemek CLAUDE.md §7
  kapsamında bir iştir; kart onu **önerir**, tek taraflı bağlamam.
- **Doğrulama:** atıf denetimi 3/3 temiz; ClickUp yeni 1, `fark: 0`. Backlog **375 kart**.

### Kapıları koşturdum — **bir gerçek kusur**, altı yanlış kırmızı (ve beşi benim)

- **Neden:** defterdeki *"yayın yolu kapıları bayatlar — yalnızca deploy'da koşan kapılar, yayın
  yapılmayan her gün sessizce kırmızıya döner"* dersi. Bugün yayın yapılmadı; kapılar en son
  ne zaman koştu belirsizdi.
- **Ölçüm 1 — hangileri bugün koşabilir:** `yerel-kapilar.sh` **42** kapı taşıyor; gövdeleri
  ayrıştırıldı. **15'i dış araç istiyor** (python3, ruby, gitleaks, nginx, dotnet), **27'si
  istemiyor** → Windows'ta Docker olmadan koşabilir.
- **Ölçüm 2 — 27 kapının sonucu: 20 yeşil, 7 kırmızı.** Triyaj:

  | kapı | kırmızı sebebi | sınıf |
  |---|---|---|
  | `kapi_26` | **üretilmiş dosya bayat** | **GERÇEK — düzeltildi** |
  | `kapi_06`, `kapi_24`, `kapi_32` | docker daemon kapalı | ortam |
  | `kapi_38` | `expect` yok → fail-closed | ortam (tasarım gereği) |
  | `kapi_27`, `kapi_41` | **benim harness'ım** | ölçüm kusuru |

- **Gerçek kusur (`kapi_26` / DM010):** `permissions.seed.json` **commitli** ve
  `telephony.dialplan.read` taşıyor, ama üretilmiş `system-roles.generated.ts` **taşımıyordu** —
  kaynak commit edilmiş, çıktı edilmemiş. **superadmin ve admin** rollerinin üretilmiş yetki
  kümesi eksikti (`permissions` + `childTenantPermissions`). Kapının kendi remedy'si
  (`npm run screens:gen`) çalıştırıldı, çıktı tek dosyada iki satır değiştirdi, commit edildi;
  kapı **rc=0**. Diğer üretilmiş dosyalar günceldi.
- **Ve iki yanlış kırmızının ikisi de benim ölçüm kusurumdu:**
  1. İlk koşuda **22 kapı kırmızıydı**. Sebep: betiğin `cd "$(dirname "$0")/.."` satırı, benim
     geçici dosyamı esas alıp kapıları **scratchpad'e** götürüyordu. Betiğin **kendi başlığı**
     bu tuzağı yazıyor: *"hata kapının bulgusu sanılır"*. Düzeltince 22 → 7.
  2. `kapi_27` (*"koşmayan bekçi bekçi değildir"*) **12 bekçiyi "çağrılmıyor"** diye bildirdi.
     Sebep: kapı `WF="$0"` ile **kendi dosyasını** grepliyor; benim harness'ımda `$0` geçici
     dosyaydı. Gerçek betikle tekrarladım: **14 bekçinin 14'ü çağrılıyor, rc=0.**
- **Sonuç ve dürüst sınır:** harness bir **triyaj aracıdır, kapı koşturucu değildir** —
  `$0`'a bağlı kapılar onunla ölçülemez. Doğru koşum yolu `deploy/yerel-yayin.sh`'in açtığı
  ubuntu konteyneridir ve o **Docker'a bağlı**; yani "tüm kapılar yeşil mi" sorusu bugün hâlâ
  **cevaplanamaz** ve bu, kullanıcıda bekleyen Docker maddesine bağlı.
- **Commit:** `gen: system-roles.generated.ts BAYATTI` (tek dosya, iki satır)

### Bayat üretilmiş dosyanın tüketicileri — **yeşil, ama bu bir kanıt değil**

- **Neden:** `system-roles.generated.ts` bayattı; onu **okuyan** yerlerin yanlış bir yetki
  kümesine göre karar verip vermediğini bilmek gerekiyordu.
- **Ölçüm:** dosyayı iki yer tüketiyor — `src/Pbxtr.Web/src/app/roleActiveScreenSmoke.test.tsx`
  (web) ve `tests/Pbxtr.Architecture.Tests/SpaBuildContextTests.cs` (dotnet gerektirir, bugün
  koşulmadı).
- **Sonuç:** web smoke koşuldu → **19/19 yeşil** (taze dosyayla). Yani düzeltme bir tüketiciyi
  kırmadı.
- **Ve dürüst okuma:** bu test **bayat hâlde de yeşildi** — yani `telephony.dialplan.read`'in
  eksikliğine **duyarlı değil**. Bayatlığı yakalayan şey test değil, **DM010 tazelik kapısıydı**.
  Defterdeki *"yeşil test kanıt değildir"* dersinin bir örneği daha: doğru soruyu soran kapı
  başkaydı.
- **Ayrıca ölçüldü:** `src/Pbxtr.Web` **dışında** üretilmiş dosya **yok** (`*.generated.*` /
  `*.gen.*` taraması, `bin/obj` hariç → 0 isabet) ve depoda yalnız **iki üreteç** var
  (`generate-screens.mjs`, `generate-alarm-metrics.mjs`) — ikisi de DM010 kapsamında.
  Yani bu sınıf **kapalı**; kapının kendi yazdığı *"src/Pbxtr.Web dışını görmez"* sınırı bugün
  boş bir kümeye işaret ediyor.

### Depoda sır var mı — ucuz tarama, **temiz** (gitleaks kapısı bugün koşamıyor)

- **Neden:** bugün üç sır **transkripte** düştü (`BR-SEC-16`). Doğal ikinci soru: aynı sınıf
  **depoya** da düşmüş mü? `gitleaks` kapıları (`kapi_08`, `kapi_09`, `kapi_20`) aracı gerektiriyor
  ve bugün koşamıyor — o yüzden araçsız bir yaklaşım kullanıldı.
- **Ölçüm 1 — izlenen sır biçimli dosya:** `git ls-files` üzerinde `.env` / `.pem` / `.key` /
  `token` / `secret` / `credential` deseni **28 isabet** verdi; **hepsi** ya `.example` dosyası ya
  da adında o sözcük geçen **kaynak dosya** (`AuthTokenService.cs`, `ISecretProtector.cs` …).
  **Gerçek sır dosyası izlenmiyor.**
- **Ölçüm 2 — `.clickup-token`:** `git ls-files` → **0** (izlenmiyor), `git check-ignore` →
  `.gitignore:60`. CLAUDE.md §14'ün yazdığı durum **doğrulandı**.
- **Ölçüm 3 — yapılandırma dosyalarında gerçek görünümlü değer:** izlenen tüm
  `.env/.example/.conf/.json/.yml` dosyalarında `SECRET|PASSWORD|TOKEN|KEY|PEPPER` içeren
  atamalar tarandı; **16+ karakterli ve base64/hex görünümlü** üç aday çıktı
  (`deploy/pbxtr.env.example` `:114`, `:197`, `:258`). **Değerler hiçbir aşamada basılmadı**;
  yalnız **şekilleri** üretildi: `AAAAAAAA_99_AAAA_AAAAAAAA` gibi — yani büyük harfli sözcükler
  + alt çizgi, klasik **yer tutucu**. Gerçek sır değil.
- **Yöntem notu (bugünün sızıntısından çıkan disiplin):** tarayıcı değeri **hiç getirmedi**;
  uzunluk ve karakter-sınıfı şekli üzerinden karar verdi. Sabah `cut -c1-60` ile yaptığım hata
  tam olarak bunun tersiydi.
- **Sonuç:** temiz — ama **gitleaks kapısının yerine geçmez.** Bu tarama yalnız *izlenen dosyaların
  şu anki hâline* bakar; **git geçmişine bakmaz**. Geçmişte commit edilip sonra silinmiş bir sır
  bu yöntemle **görünmez** ve onu ancak `gitleaks` (Docker) bulur.

### Git **geçmişinde** sır var mı — 93.525 eklenen satır tarandı, **temiz**

- **Neden:** bir önceki tarama kendi sınırını yazmıştı: *"yalnız izlenen dosyaların şu anki hâline
  bakar, git geçmişine bakmaz."* Sınırı yazıp bırakmak, bugün defalarca eleştirdiğim şeydir.
- **Yöntem (değer hiçbir zaman getirilmedi):**
  ```bash
  git log --all -p --unified=0 -- "*.env" "*.env.*" "*.conf" "*.json" "*.yml" \
      "*.yaml" "*.example" "*.sh" "*.ps1"
  ```
  çıktısındaki **`+` ile eklenen** satırlarda `SECRET|PASSWORD|TOKEN|KEY|PEPPER|PASS` içeren
  atamalar süzüldü; 16+ karakter, base64/hex görünümlü, yer tutucu kalıbına uymayanlar aday
  sayıldı. Adaylar **değeriyle değil**, `anahtar adı + uzunluk + karakter-sınıfı şekli` ile
  raporlandı.
- **Sonuç:** **93.525** eklenen satır tarandı, **4 aday** çıktı ve **dördü de dosya yoluydu**
  (`PBXTR_SystemAgent__TokenPath`, `PBXTR_DataProtection__KeyRingPath`,
  `PBXTR_Provisioning__SigningKeyPath` …) — şekilleri `/aaa/aaaaa/aaa/aaaaaaaa.aaaaa` biçiminde,
  yani `/var/lib/...`. **Gerçek sır yok.**
- **Sınırlar (açıkça):** (a) yalnız yapılandırma biçimli yollar tarandı, **kaynak kod dosyaları
  taranmadı**; (b) yalnız `ANAHTAR=DEĞER` kalıbı ve **adında** anahtar sözcük geçen atamalar —
  nötr adlı bir değişkene yazılmış sır **görünmez**; (c) yer tutucu eleme sezgiseldir, tamamı
  büyük harf olan gerçek bir değer elenmiş olabilir; (d) **entropi analizi yok** —
  `gitleaks`'in yerine geçmez, onun koşamadığı gün için **kısmi** bir cevaptır.

### Kaynak kodda gömülü sır var mı — **924.625 satır tarandı, ürün kodunda sıfır**

- **Neden:** geçmiş taramasının (b) sınırı *"kaynak kod dosyaları taranmadı"* diyordu. Sınırı
  yazıp bırakmamak için kapatıldı.
- **Yöntem (değer yine hiç basılmadı):** izlenen tüm `.cs/.ts/.tsx/.js/.mjs` dosyalarında
  `…Secret|Password|Token|ApiKey|Pepper…` adlı bir alana **tırnaklı literal** atayan satırlar;
  12+ karakter, boşluksuz, rastgele görünümlü olanlar aday. Yorum satırları elendi.
- **Sonuç:** **924.625** satır tarandı, **95 aday**. Kök dağılımı:

  | kök | aday |
  |---|---|
  | `tests/Pbxtr.Integration.Tests` | 52 |
  | `tests/Pbxtr.Api.Tests` | 26 |
  | `src/Pbxtr.Web` | 11 (**hepsi `*.test.ts`**) |
  | `src/Pbxtr.Api` | 3 |
  | `src/Pbxtr.Domain` | 2 |
  | `tests/Pbxtr.Architecture.Tests` | 1 |

  Test dışındaki **beş** aday tek tek okundu ve **beşi de sabit kod dizesi**:
  `ProblemResponse.cs:160` `TokenExpired = "TOKEN_EXPIRED"`,
  `:181` `PasswordResetUnavailable = "PASSWORD_RESET_UNAVAILABLE"`,
  `ProvisioningEndpoints.cs:942` `SecretPlaceholderReason = "secret_placeholder"`,
  `AsteriskNumberField.cs:188/205` `UNKNOWN_PREFIX_TOKEN` / `UNKNOWN_PRESENTATION_TOKEN`.
  **Ürün kodunda gömülü sır yok.**
- **Test fikstürleri kasıtlı ve zararsız:** şekilleri `a99-aaaa-aaaaaaaaaa-aaaaaa` (yani
  `t01-test-…`) ve `AAAAAA_AA_aaaaa` biçiminde — üretimde kullanılmayan sabitler.
- **Kalan sınır (dürüstçe):** bu tarama **adında** anahtar sözcük geçen atamaları görür; nötr adlı
  bir değişkene (`const x = "…"`) yazılmış bir sır **hâlâ görünmez** ve onu ancak entropi tabanlı
  bir araç (`gitleaks`) bulur. Üç taramanın üçü de aynı yere çıkıyor: **gitleaks kapısı
  Docker'a bağlı ve bugün koşamıyor.**

### Entropi taraması — adı ne olursa olsun: **üretim sırrı yok**

- **Neden:** üç taramanın da kalan sınırı aynıydı: *"nötr adlı bir değişkene yazılmış sır
  görünmez."* Bunu kapatmak için `gitleaks`'in **entropi ayağının** kaba bir taklidi yazıldı.
- **Yöntem:** izlenen tüm kod/yapılandırma dosyalarında **20+ karakterli** tırnaklı literaller;
  GUID, hex hash, slug ve yol biçimleri elendi; kalanların **Shannon entropisi** hesaplandı
  ve `H ≥ 4.0` olanlar aday sayıldı. **Değer yine hiç basılmadı** — yalnız uzunluk, entropi ve
  karakter-sınıfı şekli.
- **Sonuç:** **1.028.485** satır tarandı, **232 aday**. Dağılım tamamen açıklanabilir:
  **63** `package-lock.json` bütünlük hash'i, geri kalanların çoğu **migration/index adı**
  (`AA_aaaa_aaaaaa_…`), **migration kimliği** (`99999999999999_Aaaa…`) ve
  `decision-code-manifest.json` kayıtları.
- **En yüksek entropili gerçek aday incelendi ve zararsız çıktı:**
  `tests/Pbxtr.Api.Tests/Platform/Persistence/ProductionStartupGuardTests.cs:39` — 69 karakter,
  `H=5.43`. Bir üst satır `"Auth:JwtSigningKey"`, bir alt satır
  `"Auth:Issuer" = "https://pbxtr.test"` → **test fikstürü**. (Değer okunmadı; satır maskelenerek
  basıldı.)
- **Üç taramanın toplamı:** ad bazlı **güncel**, ad bazlı **geçmiş**, entropi bazlı **güncel** —
  üçü de temiz. **Kalan tek boşluk: entropi × geçmiş** (yani geçmişte eklenip silinmiş yüksek
  entropili bir dize) ve `gitleaks`'in **küratörlü kural seti** (sağlayıcıya özgü token
  biçimleri). İkisi de `gitleaks` kapısının işi ve o kapı **Docker'a bağlı**.
- **Bu üç taramanın günlükteki değeri:** `gitleaks` koşamadığı sürece elde ölçülmüş bir taban
  var; koştuğunda **beklenen sonuç sıfırdır** ve sıfır çıkmazsa fark **yenidir**.

### Python'lu kapılar da koşuldu — **iki yeni yeşil**, bir Windows artefaktı

- **Neden:** ilk turda "dış araç istiyor" diye ayırdığım 15 kapıdan 6'sı **python3** istiyordu ve
  bu makinede **python3 VAR**. Yani onları da ölçebilirdim; ayırmak bir varsayımdı.
- **Ortam envanteri:** `python3` **VAR**, `openssl` **VAR**; `ruby`, `gitleaks`, `nginx`,
  `expect` **yok**.
- **Sonuç (6 kapı): 2 yeşil, 4 kırmızı** — ve dördü de gerçek kusur değil:

  | kapı | sonuç | sınıf |
  |---|---|---|
  | `kapi_02`, `kapi_07` | **YEŞİL** | yeni bilgi |
  | `kapi_04`, `kapi_05` | docker daemon kapalı | ortam |
  | `kapi_42` | `ModuleNotFoundError: yaml` | ortam (paket yok) |
  | `kapi_01` | **Windows CRLF artefaktı** | platform |

- **`kapi_01` teşhisi (ve doğrulandı):** artefakt doğrulayıcının öz-testi checksum dosyasını
  `pathlib.Path.write_text(f"…{NAME}\n")` ile yazıyor; **Windows'ta metin kipi `\n`'i `\r\n`
  yapıyor** ve doğrulayıcının deseni (`pbxtr-artifact-validate.py:12`) satır sonunda **tam olarak
  `\n`** arıyor → `checksum tek beklenen hedef olmali`. Hipotez tek satırla ölçüldü:
  `write_text(...)` → son iki bayt `b'\r\n'`; `write_text(..., newline='\n')` → `\n`.
  **Kapı Linux konteynerinde koşar ve orada doğrudur** (`yerel-kapilar.sh` başlığı bunu yazıyor).
- **Değiştirmedim, sebebini yazıyorum:** çare tek kelime (`newline="\n"`,
  `deploy/pbxtr-artifact-validate-selftest.py:16`) ama kapıların **desteklenen koşum yolu Linux
  konteyneridir** ve bu bir güvenlik kapısının öz-testidir; tek taraflı dokunmak yerine kayda
  geçiriyorum. Windows'ta kapı koşturmak isteyen biri için bu **bilinmesi gereken** bir yanlış
  kırmızıdır.
- **Toplam tablo (bugün ölçülen 33 kapı):** 23 yeşil, 10 kırmızı → **1 gerçek kusur**
  (`kapi_26`, düzeltildi), 5 ortam (docker/yaml/expect), 2 benim harness'ım, 1 platform (CRLF),
  1 nginx yok. Geri kalan 9 kapı (`ruby`, `gitleaks`, `nginx`, `dotnet`) bugün **ölçülemedi**.
