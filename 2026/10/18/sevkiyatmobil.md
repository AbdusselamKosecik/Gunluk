# sevkiyatmobil — 2026-10-18

## Bağlam
Kullanıcı:
- "Mobil PC'ye takılı, ekran görüntüsüne göre kontrol edebilir misin, okutulanlar net görünmüyor."
- "Hangi model hangi order hangi sipariş görmek istiyorlar okuttukları ürünleri."
- Ayrıca: PK1 kolileri BoxType 1 olacak; InventoryReceiptItemId yalnız sevkiyatta doldurulacak; 17 fişine iş emri (satırı) yazılacak.

Cihaz: PM66 (adb 39916cf0), 480x800, uygulama Arapça. Ana menü: "Mamul giriş (fiş 17)" / "Sevkiyat (fiş 120)".

## Yapılanlar

### 1. Veri: koli araması, fiş 17 iş emri, 120'de box kalemi → fiş kalemi
- **Koli araması:** `SevkDeposu.KoliAsync`'ten `bx.BoxType = 2` kalktı (UZM_PaketKoli JOIN'i ayırıyor); tip 1 ve tip 2 koli bulunuyor (test).
- **Fiş 17:**
  - Kaleme `WorkOrderId` + `WorkOrderReceiptItemId`, varyanta `WorkOrderItemVariantId`. FisSql'de sabit null → parametre.
  - İş emri kaynağı `UZM_PaketKoli.WorkOrderId` (COL_LENGTH kontrolü; canlıda 41 kolinin hepsinde dolu).
  - Satır, varyantın o iş emrindeki Erp_WorkOrderItemVariant kaydından; kalem (ürün, iş emri satırı) başına.
- **Box kalemi → fiş kalemi:**
  - 17 doldurmuyor.
  - 120 (sevk) koli eklenince `Erp_BoxItem.InventoryReceiptItemId`'yi sevk fişi kalemine bağlıyor.
  - Koli irsaliyeden çıkarılırken referans, fiş satırları silinmeden önce boşaltılıyor (FK hatası).
- **Bulgu:**
  - PK1-00000002-036'daki ürün set kartı `4731001/2-2 SIYAH-EKRU`; iş emri 4315-2 ise tekli `4731001/2`'yi üretiyor.
  - Varyant eşleşmediği için bugünkü kolilerde yalnız WorkOrderId dolar, WorkOrderReceiptItemId boş kalır (testle sabitlendi).
- **Commit:** `12c20a3`.

### 2. Ekran: model / üretim emri / sipariş, okunaklılık, Arapça kod yönü
- Sonuç kutusunda ve listelerde her okutmanın altında "Model … · Üretim emri … · Sipariş …" (`KoliAyrinti`, `SevkSorgulari`).
- Satır yazısı 13 px → 17 px kalın, ayrıntı 15 px; saat artık soluk değil.
- Arapçada "4315-2" → "2-4315" ters çiziliyordu: değerler LRM (U+200E) ile sarıldı (`Yon.cs`). LRI/PDI Avalonia'da işlenmiyor.
- Headless ekran görüntüsü testi (`EkranGoruntusuTestleri`, Avalonia.Headless/Skia 12.1.2); TR/AR mamul ve sevk görüntüleri kontrol edildi.
- **Commit:** `e170046`.

### Test / çıktı
- `MODFEX_DB_TEST=1 MODFEX_SUNUCU=192.168.0.2 dotnet test` → 82/82.
- Bu PC'deki sevkiyatmobil ayarlar.json boş olduğundan test ortamı paketleme ayarına düşüyor (bellekte).
- APK: `dagitim/sevkiyatmobil-2026-10-18.apk` (Release, 71,6 MB), cihaza kurulmadı.

## Açık kalanlar
- Set ürünlü kolilerde WorkOrderReceiptItemId boş. Set ↔ tekli eşleme kuralı (renk bileşenleri) gerekirse ayrıca yapılacak.
- Yeni APK cihazda görsel olarak kontrol edilmedi.
- paketleme (koli BoxType 1) ile birlikte yayınlanmalı.

### 3. Cihaza kurulum (kullanıcı: "cihaza kurar mısın")
- **Komut:** `adb install -r dagitim/sevkiyatmobil-2026-10-18.apk` → Success (lastUpdateTime 2026-10-18 15:56:08; önceki 2026-10-14). Ayarlar korundu.
- **Kontrol:** Uygulama açıldı (Türkçe). Mamul giriş ekranında "Bugün: 16 koli · 800 adet"; son okutulanlarda "PK1-00000002-012 · 50 adet / Model 4731001/2-2 · Üretim emri 4315-2 · Sipariş 00000002" görünüyor.
- **Cihazda görülen küçük düzen sorunları:**
  - Üstteki özet satırı sağdan kırpılıyor ("800 ad…").
  - Barkod kutusu klavye düğmesi yüzünden dar ("Koli…").
- paketleme henüz kurulmadı. Bu sürüm hem BoxType 1 hem 2 koliyi okuduğu için tek başına kurulması güvenli.
