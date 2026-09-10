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
