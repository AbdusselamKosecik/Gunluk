# malkabul — 2026-11-18

## Bağlam
El terminali yazıcı aktarıcısı (`yaziciaktarici.md`) üzerinden basıyor; kullanıcı "çalışıyor" dedi. Bugünkü istekler:
- 99×99 etiket tasarımı
- sayımda depo seçimi
- masaüstünde sayım serilerini görüp tekrar basma ve düzeltme
- etikette TR/EN açıklamalar; kumaşta "Top No", diğerlerinde "Koli No"

## Yapılanlar

### 1. 99 × 99 mm etiket (kullanıcı tasarımı, onaylandı: "Tasarım tamam")
- **Yerleşim** (`SeriEtiketi.cs`, `EtiketIcerigi` record):
  - En üstte MODFEX APPAREL.
  - Ürün kodu, ürün adı (2 satır), renk ve lot.
  - QR (`^BQN,2,9`, `QA,<seri>`) ve yanında okunur kod (kumaşta TOP NO / ROLL NO, diğerlerinde KOLİ NO / BOX NO) ile miktar.
  - Sayımı yapan / Counted by, Sayım zamanı / Count time; mal kabulde Hazırlayan / Prepared by, Hazırlama zamanı / Prepared.
  - Basım zamanı / Printed. Mal kabulde SAS no/satır.
- 203 dpi'de 99 mm = 791 nokta. Varsayılan ölçü 99×99; kayıtlı 100×50 olan ayarlar açılışta 99×99'a geçiyor.
- **Kumaş tespiti:** Sentez `Erp_Inventory.InventorySubType = 2` (canlıda kumaş ihtiyaçlarının 147/152'si) ya da kod `KMS` ile başlıyor; okunamazsa koli sayılıyor.
- **Sayımı yapan:** `SayimKalemi.Yapan` = `Meta_User.UserCode` (kalemin InsertedBy'ı).
- Örnek etiketler aktarıcıdan basıldı.

### 2. Sayım ekranında depo seçimi
Üstte depo listesi var. Seçilen depo `SayimDepoId` ayarına yazılıyor ve sonraki açılışta hatırlanıyor.

### 3. Masaüstü "Sayım serileri" (`SayimListesiViewModel/View`, ana menü)
- Sayım deposu + tarih aralığı (varsayılan bugün) + arama (seri / stok / lot / kullanıcı).
- Tekrar bas: tek satır ya da seçililer.
- Düzelt: miktar ve lot (`SayimDeposu.DegistirAsync`).
  - Miktar yalnız fiş 16'da ve seri sonradan hareket görmediyse değişir. Değişince kalem Quantity / NetQuantity, varyant, seri hareketi ve seri kartı birlikte güncellenir; stok toplamlarını Sentez tetikleyicileri düzeltir.
  - Fiş 17'de miktar değişmez, yalnız lot.

### 4. ÖNEMLİ HATA DÜZELTMESİ: stok iki kat okunuyordu
- **Bulgu:** `Erp_InventoryTotal`'da her stok × depo için bir genel toplam satırı (`TotalDate IS NULL`) ve günlük satırlar var (`EditInventoryTotal` → `EditInventoryTotalD` hem NULL hem tarihle çağrılıyor). `SUM(ActualStock)` stoğu iki kat gösteriyordu.
- **Etkisi:**
  - Sayımı kapat depoyu iki kat düşüp eksiye indirirdi (testte 182 satır).
  - Karantina listesinde serisiz miktar iki kat görünürdü.
  - `StokAsync` (serisiz verme ve onay kontrolü) iki kat izin verirdi.
- **Düzeltme:** üç sorguya `TotalDate IS NULL` eklendi. Yeni testler: kapatınca pozitif kalmaz ve yeni eksi oluşmaz; stok genel toplam satırından okunur. Diğer repolarda bu desen yok.
- Sayımı kapat canlıda hiç kullanılmadığı için gerçek veri bozulmadı.

## Sonuç
- 144/144 test (DB dahil, ROLLBACK).
- APK PM66'ya kuruldu: `dagitim/malkabul-2026-11-18.apk`. Windows paketi: `dagitim/malkabul-masaustu-2026-11-18.zip`.
- **Commitler:** `20c3a16` (etiket + depo), `e3eb7de` (stok düzeltmesi), `5b222e5` (sayım serileri + TR/EN + top/koli no).

## Açık kalanlar
- Windows'ta masaüstü paketinin kurulması (yeni ana menü: Sayım serileri).
