# warehouse — 2026-08-28

## Bağlam
Depo raporları sayfasında (Reports) Stok Özet / Stok Detay / Free Stok / Sevk Edilen Koliler
sekmeleri vardı. Free stok sekmesinin yanına, depoya giren mal hareketlerini
yıl–hafta–iş emri kırılımında gösteren yeni bir rapor istendi.

## Yapılanlar

### 1. "Depo Girişleri" raporu
- **Neden:** Depo 26'ya giren üretim/kabul satırlarının hangi hafta, hangi iş emrinden
  geldiğini raporda görmek isteniyordu. Ham SQL kullanıcı tarafından verildi.
- **Ne yapıldı:**
  - `ReportsApiController` içine `WarehouseReceiptsSql` sabiti eklendi. Kullanıcının verdiği
    sorgu birebir korundu; tek değişiklik `InWarehouseId = 26` yerine `@whId` parametresi ve
    determinist çıktı için `ORDER BY YEAR DESC, WEEK DESC, WorkOrderNo, InventoryCode, ...`.
  - `GET /api/reports/warehouse-receipts` (JSON) ve
    `GET /api/reports/warehouse-receipts/excel` (ClosedXML) endpoint'leri, diğer raporlarla
    aynı kalıpta (session UserId kontrolü, `ExecuteReaderAsync`, `#1a1a2e` başlık stili).
  - View'a `receipts` sekmesi + istatistik kartları (iş emri sayısı, satır, toplam miktar) +
    tablo (Yıl, Hafta, İş Emri, Stok Kodu, Stok Adı, Yıkama, Renk, Beden, Miktar) eklendi.
  - Vue tarafında `receiptsData`, `loadingReceipts`, `receiptStats`, `filteredReceipts`,
    `loadReceipts()` ve `EXCEL_ENDPOINTS.receipts` eklendi; arama mevcut `matchSearch` ile
    çalışıyor (inventoryCode / inventoryName / workOrderNo / washName alanları zaten kapsamda).
  - `i18n.js` TR+EN: `warehouseReceipts`, `yearCol`, `weekCol`.
- **Dokunulan dosyalar:** `src/Warehouse/Controllers/Api/ReportsApiController.cs`,
  `src/Warehouse/Views/Reports/Index.cshtml`, `src/Warehouse/wwwroot/js/i18n.js`
- **Komutlar:**
  ```bash
  cd src/Warehouse && dotnet build -v q --nologo
  ```
- **Sonuç / doğrulama:** Build 0 error, 21 warning (hepsi mevcut `Depper/SqlMapper.cs`
  nullable uyarıları, bu değişiklikle ilgisiz). Sorgu canlı DB'de çalıştırılmadı.
- **Commit:** `6658473` — Raporlara "Depo Girisleri" sekmesi eklendi

## Kararlar
- Sorgunun mantığına (LEFT JOIN'ler, `ReceiptType <> 200`, `WITH(NOLOCK)`) dokunulmadı;
  kullanıcının verdiği hâli korundu.
- Depo id'si sabit 26 yerine `warehouseId` query parametresi (varsayılan 26) — diğer
  rapor endpoint'leriyle tutarlı.

## Açık kalanlar / sonraki adım
- Rapor tarih aralığı filtresi yok; tüm geçmiş dönüyor. Veri büyürse yıl/hafta filtresi
  veya sayfalama gerekebilir.

### 2. Raporun mail ile gönderilmesi (Excel eki)
- **Neden:** Depo Girişleri raporunun Excel'e alınıp mail olarak gönderilmesi istendi.
- **Ne yapıldı:**
  - Excel üretimi `BuildWarehouseReceiptsExcelAsync(warehouseId)` metoduna çıkarıldı;
    hem indirme hem mail endpoint'i aynı byte[]'i kullanıyor (tek kaynak).
  - `POST /api/reports/warehouse-receipts/mail` eklendi. `appsettings.json` içindeki mevcut
    `Smtp` bölümünü (faturalarda kullanılan aynı `System.Net.Mail.SmtpClient` kalıbı)
    kullanıyor; alıcılar varsayılan olarak `Smtp:Recipients`, `?to=a@x;b@y` ile override
    edilebiliyor. Konu: "Depo Girisleri Raporu - dd.MM.yyyy", ek: `depo-girisleri-<tarih>.xlsx`.
  - Controller'a `IConfiguration` enjekte edildi + `System.Net`, `System.Net.Mail` using'leri.
  - Raporlar toolbar'ına, sadece `receipts` sekmesi aktifken görünen "Mail Gönder" butonu;
    Vue tarafında `sendingMail` ref'i ile çift tıklama koruması ve alert ile geri bildirim.
  - `i18n.js` TR+EN: `sendMail`, `sending`, `mailSent`, `mailSendError`.
- **Dokunulan dosyalar:** `src/Warehouse/Controllers/Api/ReportsApiController.cs`,
  `src/Warehouse/Views/Reports/Index.cshtml`, `src/Warehouse/wwwroot/js/i18n.js`
- **Sonuç / doğrulama:** Build 0 error. Mail fiilen gönderilmedi (SMTP'ye çıkış yapılmadı),
  butondan test edilmesi gerekiyor.
- **Commit:** `f5b8a58` — Depo Girisleri raporu mail ile gonderilebiliyor

## Kararlar (ek)
- Alıcı listesi için yeni bir ayar bölümü açılmadı; faturaların kullandığı `Smtp:Recipients`
  aynen kullanıldı. Farklı alıcı gerekirse `?to=` parametresi var.
- Mail butonu tüm sekmeler için genelleştirilmedi; sadece istenen rapor için eklendi.

### 3. win-x64 yayın paketi
- **Neden:** Değişiklikleri sunucuya atmak için self-contained x64 çıktı istendi.
- **Komut:**
  ```bash
  dotnet publish src/Warehouse/Warehouse.csproj -c Release -r win-x64 \
      --self-contained true -p:PublishProfile=FolderProfile
  ```
- **Sonuç:** Çıktı `src/Warehouse/bin/Release/net10.0/win-x64/publish/` (400 dosya, ~182 MB,
  `Warehouse.exe` + `web.config`). i18n.js yeni anahtarları içeriyor, Razor view'lar
  `Warehouse.dll` içine derlenmiş (`warehouse-receipts` string'i mevcut).
- **Dikkat:** Profildeki `PublishUrl` (`bin\Release\net10.0\publish\`) klasörü CLI ile
  publish'te kullanılmıyor; orada 21 Temmuz'dan kalma ESKİ bir çıktı duruyor. Deploy
  yaparken `win-x64\publish` klasörü alınmalı, diğeri yanıltıcı.
- **Zip:** `src/Warehouse/bin/Release/warehouse-win-x64-2026-08-28.zip` (597 dosya, 79.6 MB).
  İlk denemede `ZipFile::CreateFromDirectory` girdi adlarını ters bölü ile yazdı (Windows
  PowerShell 5.1 davranışı, zip spec'ine aykırı; Linux/unzip ve bazı deploy araçları
  bozuk isim üretebiliyor). Zip, girdi adları `/` ile normalize edilerek yeniden üretildi.

### 4. Depo Girişleri raporuna filtre + gruplama
- **Neden:** Rapor tüm geçmişi dönüyordu; hafta ve tarih aralığı seçimi ile gruplama istendi.
- **Ne yapıldı:**
  - **Filtreler** (hepsi opsiyonel, nullable parametre olarak SQL'e gidiyor — dinamik string
    birleştirme yok, `(@p IS NULL OR ...)` kalıbı): `startDate`, `endDate` (bitiş tarihi dahil
    olsun diye `< DATEADD(day,1,@endDate)`), `year`, `week`.
  - **Gruplama** (`groupBy`): `detail` (varsayılan) | `week` (Yıl-Hafta) | `workorder` |
    `inventory`. Gruplu sorgular `SUM(iriv.Quantity)` döndürüyor. Kolon sırası her gruplamada
    aynı tutuldu (9 kolon), kullanılmayanlar `CAST(NULL AS ...)` — böylece tek okuma kodu
    yetiyor; UI `RECEIPT_COLUMNS` haritasıyla, Excel `columns` dizisiyle o kolonları gizliyor.
  - SQL, `WarehouseReceiptsFrom` sabiti + `BuildWarehouseReceiptsSql(groupBy)` switch'i olarak
    yeniden düzenlendi; parametreler `AddReceiptsParameters` ile tek yerden ekleniyor.
  - Filtre/gruplama JSON, Excel ve **mail** uç noktalarının hepsine uygulanıyor; mail gövdesine
    seçili filtre özeti (`DescribeReceiptsFilter`) yazılıyor. Excel'e miktar toplamı satırı eklendi.
  - UI: sekme üstünde filtre kartı (tarih aralığı, yıl, hafta, gruplama seçimi, Filtrele/Temizle).
    `loadReceipts(force)` — filtre uygulanınca önbelleği atlayıp yeniden çekiyor. Tablo altında
    filtrelenmiş miktar toplamı gösteriliyor.
  - `i18n.js` TR+EN: `startDate`, `endDate`, `groupBy`, `groupDetail/Week/WorkOrder/Inventory`,
    `applyFilter`, `clearFilter`.
- **Doğrulama:** `dotnet build` 0 error; `node --check` ile hem sayfa script'i hem `i18n.js`
  sözdizimi doğrulandı; markup div dengesi 76/76. DB'de fiilen sorgu çalıştırılmadı.
- **Commit:** `fea3adf` — Depo Girisleri raporuna filtre ve gruplama eklendi
- **Paket:** win-x64 publish + zip yenilendi (`warehouse-win-x64-2026-08-28.zip`, 79.7 MB).

## Açık kalanlar (güncel)
- `DATEPART(WEEK,...)` SQL Server'ın `DATEFIRST`/dil ayarına bağlı; ISO hafta gerekiyorsa
  `DATEPART(ISO_WEEK,...)` kullanılmalı. Şu an kullanıcının verdiği orijinal davranış korundu.
- Rapor hâlâ tüm satırları çekip istemciye gönderiyor (sayfalama yok); tarih filtresi bunu
  pratikte hafifletiyor ama çok büyük aralıklarda yavaş kalabilir.
