# pbxtr — 2026-09-09

## Bağlam
Kullanıcı "hangi maddeler kaldı çıkarır mısın" diye sordu; ardından
"yapılacaklar listesi ClickUp'ta değil mi" ve "ClickUp'u güncelle" dedi.
Kod değişikliği yok; bu tur bir **ölçüm ve senkron** turudur.

## Yapılanlar

### 1. "Kalan maddeler" dört ayrı defterde ve üçü çelişiyor
- **Neden:** Tek bir "kalanlar" listesi yok; soru ancak kaynakları ayrı ayrı
  ölçerek cevaplanabiliyor.
- **Ne yapıldı:** Dört kaynak ayrı ayrı ayrıştırıldı:
  1. `Gunluk/2026/09/08/pbxtr.md` "Açık kalanlar" — son turdan 9 madde
  2. `yonetim/backlog.md` — `BR-*` kartları
  3. `doc/prototip-urun-farklari.md` — açık BORÇ satırları
  4. `yonetim/plan-tum-maddeler.md` — P1..P5 faz planı (2026-08-23)
- **Sonuç / doğrulama:**
  - `doc/prototip-urun-farklari.md`'de gerçekten açık **~11** satır kaldı
    (#54/1 Trunk Sağlığı karosu; #09/#53/#03 WS tazeleme üçlüsü — aynı kök;
    (6) SMS sağlayıcısı — sahibi kullanıcı; (11) bilgi bankası — Scripter faz 2;
    `script_answers` partition tripwire; `BR-FE-16` koşullu adım; açık sorular
    #22/1, #19 IVR/park, #34 hedef kapasitesi).
  - Aynı dosyanın **kendi §Sayım başlığı bayat**: hâlâ "Toplam fark satırı 60 ·
    BORÇ 31" diyor; dosyada 50'den fazla ekran bölümü var. O başlığa güvenilmedi.

### 2. Kendi saydığım rakam YANLIŞTI — aracın çıkarıcısı düzeltti
- **Neden:** Elle yazdığım ayrıştırıcı `backlog.md`'de "açık BR kartı: 222" dedi.
- **Ne yapıldı:** `clickup-cikar.js`/`clickup-senkron.js --kuru` koşuldu ve kendi
  sayımını bastı.
- **Sonuç:** Doğru tablo **337 BR kartı = 216 Bitti + 15 Devam/Kısmen + 107 Kalan.**
  Benim 222'm, kart satırlarının yanına **kurul şart satırlarını** (`Ş1-3`, `Ş2-6`…)
  da katmıştı. Kullanıcıya düzeltme yazıldı.
- **Ders (defterdekiyle birebir):** "envanter sayacı kendi filtresini ölçmez" —
  projede zaten bu işi yapan bir araç varken elle sayaç yazmak, aracın
  ayrıştırma kurallarını (kısmi satır, kurul kararı satırı) sıfırdan ve
  eksik yeniden üretmek demek.

### 3. ClickUp panosu 39 maddede bayattı
- **Neden:** Kullanıcı "yapılacaklar listesi ClickUp'ta değil mi" diye sordu.
  Önce panonun kaynakla aynı olup olmadığı ölçüldü — körlemesine "evet" denmedi.
- **Ne yapıldı:** `--kuru` (yazmayan) koşu farkı çıkardı:
  - **29 kart ClickUp'ta hiç oluşturulmamış:** `BR-AST-45..50`, `BR-BE-116..121`,
    `BR-QA-40..47`, `BR-SEC-12..15`, `BR-DOC-14/15`, `BR-FE-69`, `BR-SYS-90`,
    `BR-DB-45`
  - **10 kartın durumu eski:** `BR-SYS-54` · `BR-BE-88` · `BR-BE-103` ·
    `BR-AST-43` · `BR-BE-114` · `BR-SEC-10` · `BR-SEC-11` · `BR-QA-33`
    `backlog -> complete`; `BR-FE-59` `in progress -> complete`;
    `BR-DB-34` `backlog -> in progress`
- **Komutlar:**
  ```bash
  node yonetim/arac/clickup-senkron.js --kuru   # once olc
  node yonetim/arac/clickup-olustur.js          # 29 kart olusturuldu
  node yonetim/arac/clickup-senkron.js          # 10 durum yazildi
  node yonetim/arac/clickup-senkron.js --kuru   # dogrulama
  ```
- **Dokunulan dosyalar:** `yonetim/arac/clickup-kart-eslemesi.json` (308 -> 337)
- **Sonuç / doğrulama:** Doğrulama kuru koşusu **"fark olan kart: 0, izde olmayan: 0"**
  döndü; uzakta okunan görev 1154, 337/337 kart eşleşti.
- **Commit:** `03b1216` — clickup: pano 39 maddede bayatti

## Kararlar
- **ClickUp pano, kaynak değil.** Liste `yonetim/backlog.md`'de yaşar; senkron
  **tek yönlüdür** (backlog -> ClickUp). ClickUp'tan geri okuma yoktur, dolayısıyla
  panoda elle yapılan bir değişiklik bir sonraki senkronda **sessizce ezilir**.
- **Panoya bakarak "ne kaldı" sorulmaz** — bu tur ölçüldü: pano bitmiş 9 işi AÇIK,
  açık 29 işi HİÇ GÖRÜNMEZ gösteriyordu; kalan iş 107 yerine ~78 gibi duruyordu.
- **`backlog.md`'nin EPIC A–R story satırları bayat.** 122 satır hâlâ "Bekliyor"
  diyor (B-01 tasarım token'ları, C-01 tenant CRUD…) oysa o ekranlar canlıda.
  Bunlar kapanmamış değil, **güncellenmemiş**; kalan iş sayısına katılırsa rakam
  iki katına çıkar ve yalan olur. Bu satırlar `BR-*` kartı DEĞİLDİR, bu yüzden
  ClickUp senkronu onları hiç görmez.

## Açık kalanlar / sonraki adım
- `backlog.md` EPIC A–R'nin **122 bayat story satırı** koda karşı ölçülüp
  durumları düzeltilmeli (bu turda yapılmadı).
- 2026-09-08 turundan devreden 9 madde hâlâ açık; bunların **hiçbiri henüz kart
  değil** (confd manifest sapması, `staging-yayin.sh` nginx, yayın betiği format
  adımı, `test-kos.sh` yanlış kırmızı, `AST-03/04` yeniden ölçüm…).
- Karar #37'nin 38 şartı ve Karar #38'in şartları hâlâ `/sprint-planla` bekliyor.
