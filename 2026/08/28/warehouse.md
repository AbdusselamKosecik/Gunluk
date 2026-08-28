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
