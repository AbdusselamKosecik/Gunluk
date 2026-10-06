# kesimhane — 2026-10-06

## Bağlam
Kesimhane uygulaması boş iskeletti (Sentez girişi + boş ana sayfa). Hedef: kesimhane Gemini CAD pastal PDF'ini yükleyip
verimlilik, üretilecek adet ve Gemini modellerinin Sentez karşılıklarını girsin; ihtiyaç planı (metre, top, fire) çıksın;
pastal bir kez yüklenince yalnız revizyon eklenebilsin, **asla silinmesin**; pastal onaylanmadan depo kumaş vermesin,
kesim girilemesin; depodan gelen kumaşın teslimini kesimhane onaylasın; kesim girişi pastal değerlerine göre.
Spec: `depo/docs/superpowers/specs/2026-10-06-pastal-kesim-hammadde-design.md`. Sentez'e yazma yok.

## Yapılanlar

### 1. Örnek PDF'lerin çözümlenmesi
- 4 örnek: `6328-4731001-[4315]-EKRU|PUDRA-D|L-40KAT.pdf` (Gemini "Marker report").
- Sentez karşılığı: **6328** = model (`Erp_Inventory` 1316), **4731001** = müşteri modeli, **4315** = WorkOrder 51162,
  renk = WorkOrderItem (EKRU 63095, PUDRA 63094, SİYAH 63093), **D** = KMS-0196 Dantel (172 cm), **L** = KMS-0201 Lamineli Dantel (160 cm),
  **40KAT** = kat. Gemini model `4731001-2-SUTYEN-B/C/D` = kap grupları; bedenler (75B…) Sentez beden koduyla birebir.
- Örnek: EKRU-D 7,40 m × 40 kat (+2 cm pay) = 296,8 m; verim %60,05 → fire %40,11; 50 m top → 6 top; 77 × 40 = 3.080 adet (order +10/beden).
- PDF'ler `Kesimhane.Tests/Ornekler/` altına taşındı (test verisi).

### 2. DB şeması
- **Dosya:** `db/0001_pastal.sql` — `UZM_Pastal` (UNIQUE CompanyId+WorkOrderItemId+PastalKodu; tek kumaş), `UZM_PastalRevizyon`
  (RevNo, PDF yolu+SHA, en/boy/verim/kat/pay/top, OnayDurum 0/1/2), `UZM_PastalBeden` (Gemini model/beden → InventoryId/VariantId, kat başı),
  `UZM_PastalModelEslesme`, `UZM_KesimGiris`. Tetikleyiciler: hepsinde `INSTEAD OF DELETE` → THROW 50100; revizyonda yalnız onay kolonları
  güncellenebilir, diğerleri THROW 50101. Ayarlar: `PastalOnayKullanicilari`, `PastalPayiCm`=2, `TopBoyuM`, `DosyaKlasoru`.
- **Komut:** `sqlcmd -S 100.119.104.122 -U uzman -P '***' -d SentezCore -C -b -i db/0001_pastal.sql` (iki kez, idempotent)
- **Commit:** `4e45b95`, SHA kolonu düzeltmesi `0801f08` (UdtCode 25 karakter, SHA 64)

### 3. Ayrıştırıcı + ihtiyaç hesabı
- **Dosyalar:** `Kesimhane/Ekranlar/Veri/GeminiMarker.cs` (PdfPig 0.1.16; kelimeler Y'ye göre satır, regex: Marker width/length/efficiency,
  Number products, tarih; `Model:` blokları → Sizes/Quantitie; 0 adetli ve çift beden temizlenir; dosya adından pastal kodu + `NNKAT`),
  `IhtiyacPlani.cs`.
- **Commit:** `4e9e689`

### 4. Pastal deposu + kurallar
- **Dosyalar:** `Veri/PastalDeposu.cs`, `Veri/PastalKurallari.cs`; `Ortak/Veri/DosyaDeposu.cs`, `UzmAyar.cs` (depodan kopya).
- Aynı order + pastal kodu tekrar gelirse yeni revizyon (UPDLOCK); ilk yüklemede PDF şart; farklı kumaşla aynı kod reddedilir.
- Onay: yalnız son + bekleyen revizyon, yetki `PastalOnayKullanicilari`.
- Kesim kilidi sırası: pastal onaysız → teslim bekleyen kumaş var → bu kumaştan net teslim yok → kat aşımı (kalan kat mesajda).
- Teslim aldım: `UZM_HammaddeHareket` (kumaş Ver/Extra) onayı.
- **Commit:** `0801f08`

### 5. Ekranlar
- `OrderListe` (ana sayfa; arama gecikmeli), `OrderDetay` (pastal kartları + kesim girişi/engel metni, depodan kumaş teslimleri),
  `PastalForm` (PDF seç → ayrıştır, kumaş reçeteden, beden → Sentez varyantı otomatik eşleşir, canlı ihtiyaç planı, renk/order/eksik alan uyarıları),
  `PastalDetay` (revizyon geçmişi, PDF aç, onay/ret — ret notu zorunlu). `DosyaSecici` (Avalonia StorageProvider). TR/EN/AR metinler.
- **Commit:** `d3c02d6`, README `dfbc6ce`

### 6. Doğrulama
- `Kesimhane.Tests`: ayrıştırıcı (4 gerçek PDF), hesap, kurallar; `MODFEX_DB_TEST=1` ile tüm kilit zinciri + tetikleyiciler (ROLLBACK);
  headless Skia ekran görüntüsü (canlı veri, salt okuma). **20/20 geçti.** `Kesimhane.Desktop` build + açılış OK.
- Ekran görüntüsünde renk uyarısı gerçek hatayı yakaladı: 63093 SİYAH'mış (testlerde EKRU sanılmıştı, düzeltildi).
- **Komut:** `MODFEX_DB_TEST=1 MODFEX_TEST_CIKTI=<klasör> dotnet test Kesimhane.Tests`

## Kararlar
- Pastal onayını kesimhane uygulamasından yetkili kullanıcı verir; kumaş teslim onayı kesimhanede.
- Kesim girişi = kesilen kat; adet = kat başı × kat (girildiği revizyona göre).
- Headless test için `oturum.Dispatch(Func<Task<T>>)` kullanılmalı — `async () => {}` Action overload'una düşüp beklenmiyor.

## Açık kalanlar / sonraki adım
- Fabrika DB'sine betikler (depo 0001 → kesimhane 0001), `PastalOnayKullanicilari` ve `DosyaKlasoru` (UNC) belirlenmeli.
- Android'de PDF "aç" yalnız yolu gösteriyor.
- Kesim sonrası bant/paketleme entegrasyonu kapsam dışı.
