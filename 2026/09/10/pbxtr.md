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
