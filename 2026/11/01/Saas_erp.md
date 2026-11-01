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

## Kararlar
- S2: `user` rolünde `order.create/edit` yok → teklif oluşturma/düzenleme artık yalnız owner/admin/manager (POST /orders ile tutarlı). Kullanıcı onayı bekleniyor.

## Açık kalanlar / sonraki adım
- S3 local UX kontrolü (Kalan sütunu, durumlar) — a6344514 üzerinde.
- S3 backfill: PROD öncesi sahip onayı (runbook).
- Sahte "kaydedilmemiş" uyarısı diğer editörlerde (talep/sipariş/teklif/fiş) de olabilir — takip.
- Sonraki E12: S4 (iskonto irsaliyeye, açık siparişler, link guard), S5, S6, S7, S11, S12.
