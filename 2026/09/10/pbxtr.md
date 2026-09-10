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
