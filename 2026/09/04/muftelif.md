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
- API imajı 1.0.4.79 Docker Hub'da; sunucuda pull + up -d yapılmalı (bu turda sunucuya dokunulmadı).
  build + deploy gerekiyor. Sonra müşteri sırayla: önce 5 model PDF, sonra PO066 ve POLEN018.
- Deploy sonrası `2322/NA` diye yanlış oluşmuş bir model varsa elle silinmeli.

### 3. Docker sürümü 1.0.4.79 (sadece API)
- **Neden:** Düzeltme yalnızca API tarafında; web imajı değişmedi (1.0.4.78'de kalır).
- **Ne yapıldı:** `BuildDocker_1.0.4.79.bat` oluşturuldu (1.0.4.78 şablonundan, web adımı çıkarıldı).
  Build + push arka planda doğrudan docker komutlarıyla yapıldı.
- **Komutlar:**
  ```bash
  docker build . --compress --no-cache -f Selvedge/src/Selvedge.Api/Dockerfile \
    --tag tekbirsoft/selvedge-api:1.0.4.79-dev --tag tekbirsoft/selvedge-api:latest
  docker push tekbirsoft/selvedge-api:1.0.4.79-dev && docker push tekbirsoft/selvedge-api:latest
  ```
- **Sonuç:** İki tag da Docker Hub'da, digest `sha256:a7958880...`. Sunucuda `docker compose pull && up -d`
  ile alınacak (compose `:latest`'i kullanıyor).
- **Commit:** `cdce91e` — chore(selvedge): surum 1.0.4.79

### 4. Model "Beden Başlangıç / Bitiş" alanı INT → metin (XS-XL) — 1.0.4.80
- **Neden:** Kullanıcı model formunda "Beden Başlangıç (örn. 23)" alanına XS yazıp kaydedemiyordu.
  Alan uçtan uca tam sayıydı: `sv_Style.SizeRangeStart/End INT`, entity `int?`, DTO'lar, `StylePdfHeader`,
  web zod `z.coerce.number()` + `type="number"`. Parser da `(\d+)-(\d+)` regex'iyle "XS-XL"i sessizce
  atıyordu (fixture'ların çoğu XS-XL, hepsinde alan boş kalıyordu).
- **Ne yapıldı:**
  - `Selvedge/db/migrations/0026_style_sizerange_text.sql` — koşullu `ALTER COLUMN ... NVARCHAR(16) NULL`
    (API açılışında `SqlMigrationRunner` otomatik uygular; sayısal değerler metne döner, veri kaybı yok).
  - `Selvedge.Domain/Entities/Style.cs`, `Dtos/{Create,Update}StyleRequest.cs`, `Dtos/StyleDto.cs` → `string?`.
  - `StyleConfiguration.cs` → `.HasMaxLength(16)`; `StyleService.cs` → `Trim(r.SizeRange*)`,
    PDF apply `!string.IsNullOrWhiteSpace`.
  - `StylePdfParser.cs` → regex `([A-Z0-9]+)\s*-\s*([A-Z0-9]+)`, upper-case.
  - Web: `StylesPage.tsx` zod `z.string().max(16)`, `type="number"` kaldırıldı, submit `trim() || null`;
    `api/lookups.ts`, `types/api.ts` → `string`; `i18n/tr.json`, `en.json` etiket "örn. 23 veya XS".
  - Test: `StylePdfParserSizeRangeTests` (clara XS-XL, winslow 23-34). 33/33.
- **Komutlar:**
  ```bash
  cd Selvedge/tests/Selvedge.PdfImport.Tests && dotnet test
  cd Selvedge/src/Selvedge.Api && dotnet build -c Release
  cd Selvedge/src/Selvedge.Web && npx tsc --noEmit -p tsconfig.json
  ```
- **Commit:** `3fd79a9` — feat(selvedge): model beden araligi metin oldu + 1.0.4.80
- **Docker:** `BuildDocker_1.0.4.80.bat` (API + web). Build/push arka planda çalıştırıldı; sonuç aşağıda.
- **Docker sonucu:** `tekbirsoft/selvedge-api:1.0.4.80-dev` + `:latest` → `sha256:ad35c17a…`;
  `tekbirsoft/selvedge-web:1.0.4.80-dev` + `:latest` → `sha256:b44a018a…`. Sunucuya dokunulmadı.

## Açık kalanlar / sonraki adım (güncel)
- Sunucuda `docker compose pull && docker compose up -d` (api + web). API açılışında migration 0026 otomatik koşar.
- Müşteri: önce 5 model PDF, sonra PO066 + POLEN018. Yanlış oluşmuş `2322/NA` modeli varsa elle sil.
