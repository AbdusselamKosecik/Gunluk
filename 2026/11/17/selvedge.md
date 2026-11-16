# selvedge — 2026-11-17

## Mal kabul inspection (workflow adım 7 / "Selvedge'e mal kabul inspection, raporlara da; Order bağımsız ama birden fazla Order eklenebilir")
- **DB:** `db/migrations/0030_malkabul_inspection.sql` (Selvedge DB, API açılışta uygular).
  - `sv_QaReport`'a WaybillNo, PurchaseOrderNo, MaterialCode, SerialCodes kolonları.
  - Yeni tablo `sv_QaReportOrder` (QaReportId, CustomerOrderId; benzersiz). Order Sentez view'i olduğu için Order tarafına FK yok.
- **Backend:**
  - `QaReportOrder` entity ve EF config.
  - Create/Update isteklerine `CustomerOrderIds` (REPLACE; ana Order hep bağlı) ve mal kabul alanları.
  - Detayda Order no listesi.
  - Liste filtresi ve Order PDF'leri bağlı Order'ları da kapsıyor. Final QC sorguları değişmedi.
  - Validator'a "Mal Kabul" aşaması eklendi.
  - QC PDF başlığında mal kabul özeti.
- **Web:** form aşama listesine "Mal Kabul" eklendi; seçilince irsaliye, satın alma, malzeme, seri kodları ve çoklu Order seçimi çıkıyor. Anket aşama listesine de eklendi.
- **Mobil:** aşama listelerine "Mal Kabul" eklendi; APK yeniden derlenmedi.
- **Doğrulama:** `dotnet build Selvedge.Api` ve `tsc -b` temiz. Canlı deneme yok.
- **Commitler:** `8a4a4e1`, `7255ced` (bekleyen yerel değişiklikler). Servis yeniden yayınlanmadı (`deploy/yayinla.ps1`).
