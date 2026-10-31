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

## Kararlar
- S2: `user` rolünde `order.create/edit` yok → teklif oluşturma/düzenleme artık yalnız owner/admin/manager (POST /orders ile tutarlı). Kullanıcı onayı bekleniyor.

## Açık kalanlar / sonraki adım
- S1c tevkifat seçici UX düzeltmeleri (wte10, sürüyor): toplamlarda tevkifat/ödenecek ön izleme, kodlu satırda oran salt-okunur, kod temizleme, placeholder.
- 390px düzeltmesinin tarayıcıda doğrulanması.
- Sonraki E12 dilimi: S3 satış sevk takibi (öneri + kurul).
