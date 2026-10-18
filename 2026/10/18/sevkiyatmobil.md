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

### 4. Yazılar küçültüldü (kullanıcı: "yazıları biraz daha küçültelim, ekrana daha oturaklı olsun, son okutulanlar özellikle")
- **Ne yapıldı:**
  - `Stiller.axaml`:
    - Son okutulanlar: ana satır 17 → 14 px, ayrıntı 15 → 12, saat 14 → 12; satır iç boşluğu 10 → 8,6; nokta 12 → 10.
    - Sonuç kutusu: 24 → 19, ayrıntı 17 → 14, iç boşluk 16,18 → 12,10, MinHeight 120 → 84.
    - Barkod kutusu 18 → 16 / 44; Sil düğmesi 15 → 13, iç boşluk 14,6 → 8,4 (barkod kutusuna yer kalsın).
  - `MamulGirisView.axaml`: sayaç 20 → 16 (cihazda "800 ad…" diye kırpılıyordu); satır aralıkları sıklaştırıldı.
  - `OkutmaView.axaml` (sevk): üst kart 18 → 16, koli metni 15 → 14; satır aralıkları sıklaştırıldı.
- **Doğrulama:** Headless görüntüler (TR/AR mamul ve sevk): satırlar tek satıra sığıyor, sayaç kırpılmıyor. `MODFEX_DB_TEST=1 MODFEX_SUNUCU=192.168.0.2 dotnet test` → 82/82.
- **Derleme:** `dotnet publish SevkiyatMobil.Android -c Release -f net10.0-android` → `dagitim/sevkiyatmobil-2026-10-18b.apk`.
- **Kurulum:** `adb install -r` → Success. Uygulama giriş ekranında açıldı (oturum yeniden açılınca şifre istiyor).
- **Commit:** `04fd2a1`. Push edildi.

### 5. Sentez'de silinen 17 fişinin kolileri yeniden okutulamıyordu
- **Kullanıcı:** "El terminali okutulup okutulmadığını nereden anlıyor. 17 numaralı fişi sildim ama gene okutamıyorum."
- **Neden:**
  - "Alınmış" kararı `UZM_PaketKoli.MamulFisId`'den, "sevk edilmiş" kararı `Erp_Box.InventoryReceiptId`'den veriliyor.
  - Sentez fişi tamamen (hard delete) siliyor, bizim tablo silinen fişi göstermeye devam ediyor → `KoliZatenMamulde`.
- **Canlı:**
  - 16 koli (PK1-00000002-001…017) bugün silinen 738593'e bağlıydı; 2 koli 14.10'da silinen 738045 / 738049'a bağlıydı.
  - PK1-00000001-001'in Erp_Box.InventoryReceiptId'si 738046.
- **Ne yapıldı:**
  - `SevkDeposu.KoliAsync`: Erp_InventoryReceipt'e LEFT JOIN. Fiş yoksa ya da IsDeleted=1 ise `MamulFisId`, `MamulAt`, `InventoryReceiptId` NULL okunur.
    Koli hiç alınmamış / sevk edilmemiş gibi davranır; yeniden okutmada MamulFisId yeni fişle üzerine yazılır. Veriye elle dokunulmadı.
  - `SevkSorgulari` (bugün sayacı + son mamul kolileri): fişi olmayan koli sayılmıyor.
- **Test:** `Mamul_fisi_Sentezde_silinmisse_koli_yeniden_okutulur`: MamulFisId olmayan bir fişe çevrilip yeniden okutuluyor.
  Önce `KoliZatenMamulde` ile kırmızıydı (sahadaki hata), sonra yeşil. 83/83.
- **Kurulum:** `dagitim/sevkiyatmobil-2026-10-18c.apk` → `adb install -r` Success.
- **Commit:** `5b6741e`. Push edildi.

### 6. Mamul girişinde "Object reference not set" (Android release budaması)
- **Kullanıcı:** "object not bilmem ne hatası veriyor."
- **Teşhis:**
  - Release APK debuggable değil, `run-as` çalışmıyor.
  - `dotnet build SevkiyatMobil.Android -c Debug -f net10.0-android -p:EmbedAssembliesIntoApk=true` ile debuggable APK üzerine kuruldu (aynı varsayılan debug imzası, `install -r` veriyi koruyor).
  - `adb shell run-as com.modfex.sevkiyatmobil cat files/Modfex/sevkiyatmobil/log/2026-10-18.log` ile uygulama günlüğü okundu.
  - Hata: `NullReferenceException at RuntimeILGenerator.Emit … Dapper.SqlMapper.GenerateValueTupleDeserializer … SevkDeposu.IcerikAsync`.
  - Aynı koli (PK1-00000002-002) masaüstünde, ROLLBACK'li transaction'da sorunsuz alındı (MamulAlindi). Yani hata yalnız Android'de.
- **Neden:** Bugün (12c20a3) `IcerikAsync` iş emri alanlarıyla 7'li ValueTuple'a okunur oldu. Android release budaması ValueTuple`7 kurucusunu siliyor; Dapper IL üretirken null ConstructorInfo. 2'li tuple'lar sahada çalışıyor.
- **Düzeltme:** `IcerikAsync` → `private sealed class IcerikHam` (SQL alias'ları Ori/Oriv/Wi/Wiv). Kodda başka çok elemanlı tuple yok.
- **Test:** 83/83. Budama masaüstü testinde tekrarlanamıyor; doğrulama sahada okutmayla.
- **Kurulum:** `dagitim/sevkiyatmobil-2026-10-18d.apk` (Release) → Success; debuggable değil (teşhis sürümünün yerine geçti).
- **Commit:** `ea79798`. Push edildi.
- **Ders:** Android'de Dapper'a çok elemanlı ValueTuple verme; sınıf kullan.
