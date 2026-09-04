# muftelif (Selvedge) — 2026-09-04

## Bağlam
Müşteri `C:\Users\abdus\Downloads\fw` içindeki 7 PDF'i (5 model PDF + PO066.PDF + POLEN018.PDF)
Selvedge web arayüzünden içeri alamıyor diye geldi. PO'lar "N sipariş atlandı (modeli sistemde yok)"
uyarısıyla atlanıyor; 2322 CLARA için XS..XL bedenleri sistemde görünmüyor, sipariş popup'ında
sadece rakam bedenler seçilebiliyor.

Branch: `feat/sentez-planing-ayrimi`.

## Yapılanlar

### 1. Teşhis — parser'ları 7 dosyaya karşı lokalde çalıştırma
- **Neden:** Watcher bu makinede kurulu değil, müşteri logu yok; en kesin kanıt parser çıktısı.
- **Ne yapıldı:** Scratch console projesi (`Selvedge.PdfImport.csproj`'a ProjectReference) ile
  `PoPdfParser.Parse` / `StylePdfParser.Parse` / `GetRawText` çıktıları alındı; referans olarak
  `Selvedge/doc/PO023.PDF` (eski, çalışan format) ile karşılaştırıldı.
- **Bulgular:**
  1. `PoPdfParser.StyleRegex` = `^([A-Z0-9]+-\d+(?:-[A-Z0-9]+)?)\s*/\s*...` → stil no'da tire+rakam
     zorunlu. Yeni COH PO'larında stil `2321 / WNWHT`, `9293B / WNWHT`, `2321-EXT / WNWHT` (tiresiz).
     Eşleşmeyince satır bloğu hiç okunmuyor → StyleNumber boş, Qty 0 → `CustomerOrderService`
     "modeli yok" diye atlıyor.
  2. `NumbersAfterLabel("SZ:")` sadece `^\d+$` kabul ediyor → `SZ: XS S M L XL` boş dönüyor.
  3. 2322 CLARA model PDF'inde `Wash Code = "NA"` (N/A değil). `WashCodes.EffectiveCode` yalnız
     `N/A`'da Wash Color Code'a düşüyor → `2322/NA` modeli oluşuyor, PO'daki `2322 / HTRBR` eşleşmez.
  4. `CustomerOrderService.MergeExtRows` EXT regex'i `^([A-Z0-9]+-\d+)-EXT` de aynı tire varsayımı.
- Web popup'ta "sadece numara girilebiliyor" şikayeti: beden alanı `lookups/sizes` tablosundan
  select; XS..XL kayıtları henüz yok. PO import `ResolveOrCreateSizeIdAsync` ile eksik bedeni
  otomatik yaratıyor → parser düzelince PO import ile XS..XL kendiliğinden oluşur.
  Alternatif: Tanımlar > Bedenler sayfasından elle eklenebilir (code serbest metin, max 16).

### 2. Düzeltme (TDD: önce 7 kırmızı test, sonra yama)
- **Dokunulan dosyalar:**
  - `Selvedge/src/Selvedge.PdfImport/PoPdfParser.cs` — `StyleRegex` →
    `^([A-Z0-9]+(?:-[A-Z0-9]+)*)\s*/\s*([A-Z0-9-]+)`; yeni `SizeTokenRegex`
    `^(\d+|X{0,3}[SML]|[1-9]X[LS]?|OS)$`; `NumbersAfterLabel` bunu kullanıyor, bedeni upper-case ediyor.
  - `Selvedge/src/Selvedge.PdfImport/WashCodes.cs` — `EffectiveCode` artık `NA`'yı da `N/A` gibi ele alıyor.
  - `Selvedge/src/Selvedge.Application/CustomerOrders/CustomerOrderService.cs` — EXT regex
    `^([A-Z0-9]+(?:-[A-Z0-9]+)*?)-EXT(\b)`.
  - `Selvedge/tests/Selvedge.PdfImport.Tests/PoPdfParserTests.cs` (yeni, 4 test),
    `WashCodesTests.cs` (+2 test), fixtures: `coh-po-nodash-numeric.pdf` (=PO066),
    `coh-po-letter-sizes.pdf` (=POLEN018), `new-gerber-clara-wash-na.pdf` (=2322 CLARA).
- **Komutlar:**
  ```bash
  cd Selvedge/tests/Selvedge.PdfImport.Tests && dotnet test    # 31/31 geçti
  cd Selvedge/src/Selvedge.Application && dotnet build -c Release
  ```
- **Sonuç / doğrulama:** PO066 → 5 satır (2321, 2321-EXT, 9293B XS..XL, 2332, 2332-EXT);
  POLEN018 → 4 satır, hepsi XS..XL, toplamlar PDF ile aynı (300/300/600/600).
  PO023 çıktısı değişmedi (regresyon yok).
- **Commit:** `180cf47` — fix(selvedge/pdf-import): COH 2026 PO/model PDF formati

## Kararlar
- Watcher'da `IncludeSubdirectories=false` (alt klasör izlenmiyor) — bilinçli, değiştirilmedi.
- 9514 PDF'inde Wash Code / Wash sırası PDF'te farklı (HEGRY→"HEATHER BROWN" adı çıkıyor); kozmetik,
  eşleşmeyi bozmuyor, dokunulmadı.

## Açık kalanlar / sonraki adım
- **API henüz deploy edilmedi.** Düzeltme prod'a çıkması için yeni API imajı (son: BuildDocker_1.0.4.78)
  build + deploy gerekiyor. Sonra müşteri sırayla: önce 5 model PDF, sonra PO066 ve POLEN018.
- Deploy sonrası `2322/NA` diye yanlış oluşmuş bir model varsa elle silinmeli.
