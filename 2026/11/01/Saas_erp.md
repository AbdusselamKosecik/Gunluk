# Saas_erp — 2026-11-01

## Bağlam
31 Ekim gecesinden devam (bkz. 2026/10/31/Saas_erp.md). Hedef: E12 backlog (QA Excel riskleri) dilimleri.

## Yapılanlar

### 1. Dokuma raporu testinin gece flake'i
- **Neden:** `WeavingReportLoomTests.Handle_Efficiency_EqualsBoardNumberForSameScenario` 00:00–01:01 (İstanbul) arasında kırmızı (220 ≠ 0): senaryo "bugün" kurulur, olaylar gelecekte kalır; pano sayar, rapor şimdiye kırpar.
- **Ne yapıldı:** Bu pencerede test erken döner (`if (DateTime.UtcNow < d.AddMinutes(61)) return;` eşitlik iddialarından önce).
- **Dokunulan dosyalar:** `tests/unit/VuoApp.UnitTests/Modules.Production/Features/WeavingReportLoomTests.cs`
- **Commit:** `470becef`

### 2. E12 S2 — tekliften siparişe kısmi dönüşüm
- **Neden:** QA Excel riski; kullanıcı kararı (teklif kısmi sipariş olabilsin).
- **Ne yapıldı:** `QuotationLine.ConvertedQuantity`, `OrderReceipt.SourceQuotationId`, `OrderReceiptItem.SourceQuotationLineId`; `QuotationConversionLedger` (teklif `FOR UPDATE` → kalan kontrolü → durum yeniden hesap: accepted / partially_converted / converted); sipariş silme/iptal/düzenlemede miktar teklife geri döner; 55P03/23514 → 409; teklif durum/düzenleme de kilidi alır; teklif ve sipariş mutasyon uçlarına `RequirePermission(order.create/edit/delete)`.
- **Migration'lar:** `20261031190847_E12S2_QuotationConversion` (kolonlar + 3 backfill + CHECK/FK NOT VALID), `20261031190905_..Indexes` (CONCURRENTLY, CREATE sırasında `lock_timeout = 0`), `20261031190933_..Validate`.
- **Sonuç / doğrulama:** backend 8035, frontend 3206, Postgres dönüşüm testleri 15/15 yeşil; DBA + security PASS-WITH-NOTES, notlar uygulandı.
- **Commit:** `9044f736`

### 3. Local UX recheck düzeltmeleri
- **Ne yapıldı:** Stok Kontrolleri tablo kutusu `w-0 min-w-full overflow-x-auto` (tablonun min-content genişliği sayfa flex düzenini büyütmesin); `tr-TR.json` menü/başlık: "İade Tipleri", "Satış Temsilcileri".
- **Commit:** `71466773`

### 4. S1c tevkifat seçici UX (f4e3bf33) ve local UX kontrolü
- **Ne yapıldı:** Toplamlar/alt bilgide tevkifat + "Ödenecek (önizleme)"; sabit oranlı kodda oran salt-okunur (650 düzenlenebilir); combo "Kodu temizle" + "Kod seçin".
- **Local UX (f4e3bf33, scratchpad/uxlocal6-notes.md):** A (S2 kısmi dönüşüm 4+6, silmede iade, kaynak teklif linki) PASS-WITH-NOTES; B (tevkifat) PASS-WITH-NOTES; C (Stok Kontrol 390px scrollWidth=390, menü adları) PASS. Artık: UXT-TKL-6 teklifi (Kabul, silinemez — yalnız taslak silinir).
- **Commit:** `f4e3bf33`

### 5. Tevkifat kodu baştan seçim + sahte "kaydedilmemiş" uyarısı
- **Neden:** UX: kod hücresi oran girilmeden gizliydi (sabit oranlı kodlarda sıra ters); İptal ile çıkınca sonraki yenilemede yanlış uyarı.
- **Ne yapıldı:** `invoice_create.page.tsx` cellHiddenFor kaldırıldı; `receipt-detail-control.tsx` combo aria-label = kolon başlığı; `use-unsaved-changes.ts` `data-unsaved-ignore` (İptal/Geri) izlemeyi başlatmaz, unmount'ta sıfırlanır; "Tevkifat:" 11 dil.
- **Sonuç:** frontend gate 3219 yeşil.
- **Commit:** `6c318c79`

### 6. E12 S3 — satış siparişi sevk takibi
- **Neden:** QA riski: satış siparişinde sevk miktarı/durumu yürümüyordu. Kurul koşulları C1–C10 (scratchpad e12s3-proposal.md).
- **Ne yapıldı:** Domain `SalesReceiptFulfillmentChangedEvent`; Shared ayrı `IOrderShipmentQuery` (satınalma portu değişmedi); Inventory `OrderShipmentQueryService` (3052+3053−3002−3003, malzeme/varyant/birim/cari eşleşmesi, 1000'lik parçalar) + `SalesFulfillmentSignal`; Orders `SalesFulfillment`, Outbox handler (önce kalemler, 40P01 log+retry, Id sıralı kilit); `UpdateOrderReceipt` canlı sevk guard'ı + durum yeniden türetme; `OpenExposureSales` (Sevk Edildi satış faturaya kadar riskte); `BackfillSalesFulfillment` (SuperAdmin endpoint+handler, kuru koşu varsayılan, 40P01/40001 parça atlanır); FE Kalan sütunu (+X fazla), açık sipariş setleri.
- **Dokunulan dosyalar:** 39 dosya (bkz. commit); runbook `docs/runbooks/sales-fulfillment-backfill.md`.
- **Sonuç / doğrulama:** backend 8096, frontend 3222, Postgres `SalesShipmentPostgresTests` 8/8; migration yok; DBA + security post-check PASS(-WITH-NOTES), must-fix'ler uygulandı.
- **Commit:** `a6344514`

### 7. S3 local UX (a6344514)
- **Sonuç:** Kısmen Sevk → Sevk Edildi, Kalan 10→6→0; miktar sevkin altına düşürülemez (TR hata); açık listede Sevk Edildi yok; onay geri alma durumu geri çeker. Tevkifat düzeltmesi (6c318c79) PASS. Notlar `scratchpad/uxlocal7-notes.md`; artık UXT kayıtları: sipariş UXT-S3 (İptal), irsaliye IRS1/IRS2 (onaysız).

### 8. Silme uçlarında iş kuralı hatası 500 → doğru kod
- **Neden:** UX kontrolünde taslak olmayan sipariş / hareketli fiş silme 500 döndü; 20 controller noktasında `NotFound ? 404 : 500`.
- **Ne yapıldı:** Orders/Finance/Crm/Ast/Saas'ta altı durumlu eşleme; InventoryController.HandleDeleteResult'a Validation→400, Unauthorized→401. Gövde aynı.
- **Sonuç:** backend 8102. Kalan aile: Ast:76, InvoiceController:82, QualityController:86, PmsController:56.
- **Commit:** `5160f9df`

### 9. E12 S4 — satış irsaliyesi ← sipariş
- **Kurul:** CTO/Skeptic/PO/DBA APPROVE-WITH-CONDITIONS → K1–K14 (`scratchpad/e12s4-proposal.md`). Kritik bulgu (Skeptic/CTO): konfeksiyon 3052/3053 bağları tip-1 siparişlere → guard yalnız 5202/5206'da çalışır.
- **Ne yapıldı:** Shared `IOpenSalesOrderLineQuery` (sayfalı); Orders `OpenSalesOrderLineQueryService`; Inventory `GetOpenSalesOrderLines` (order:read, cari zorunlu, kalan>0, 500+truncated), `SalesOrderLinkGuard` (S3 MismatchReason ile aynı kural, iade yalnız iptalde ret, Changed bayrağı), Update'te order-fulfil kilidi fiş FOR UPDATE'ten önce; FE `open-sales-orders-dialog.tsx`, `carriedLineDiscount` (efektif oran), kayıt öncesi fazla sevk onayı, `shipWarnings`.
- **K10:** DEV salt-okunur sayım: bağlı onaylı 3052/3053/3002/3003 satırı 0.
- **Sonuç:** backend 8118, frontend 3235, PG 15; migration yok; DBA PASS-WITH-NOTES (sayfalama + kilit testi eklendi), güvenlik PASS.
- **Commit:** `f39d848d`
- **Takip:** Arda'ya ClickUp z8v9xnjvde (satınalma seçici indirimi ENT-SA-13 + UpdateReceipt kilit sırası).

## Kararlar
- S2: `user` rolünde `order.create/edit` yok → teklif oluşturma/düzenleme artık yalnız owner/admin/manager (POST /orders ile tutarlı). Kullanıcı onayı bekleniyor.

## Açık kalanlar / sonraki adım
- S4 local UX kontrolü (f39d848d).
- S4: staging EXPLAIN (K6), PROD kuru sayım (K10) — sahip onayı.
- S3 backfill: PROD öncesi sahip onayı (runbook).
- Sahte "kaydedilmemiş" uyarısı diğer editörlerde (talep/sipariş/teklif/fiş) de olabilir — takip.
- Sonraki E12: S5 (faturalama), S6, S7, S11, S12.
