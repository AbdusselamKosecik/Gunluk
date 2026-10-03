# paketleme — 2026-10-04

## Bağlam
03.10'da yazılan spec (`docs/superpowers/specs/2026-10-03-paketleme-etiket-koli-design.md`, `7c8cf09`) kullanıcı tarafından
onaylandı ("bu şekilde yapalım"). Bu tur: uygulama planı (writing-plans). Kod yok.

## Yapılanlar

### 1. SentezCore doğrulamaları (salt-okuma, `uzman`)
- **Neden:** Planı tahminle değil gerçek şemayla yazmak.
- **Komut:** scratchpad `db.ps1` (ayarlar.json'daki DPAPI şifresi çözülür, System.Data.SqlClient ile sorgu; `Fark` fonksiyonu iki kaydın
  farklı kolonlarını listeler).
- **Bulgular:**
  - 10 fişi (731526) ↔ 130 fişi (731509): başlık/kalem/varyantta tek anlamlı fark depo yönü (10: `InWarehouseId`, 130: `OutWarehouseId`).
    → bantsayim `FisSql.cs` VALUES satırları 240/681/967 (`OutWarehouseId` = NULL) `@OutWarehouseId` yapılarak paylaşılır.
  - `Erp_Box.OrderReceiptId`, `Erp_BoxItem.OrderReceiptItemId`, `Erp_BoxItemVariant.OrderReceiptItemVariantId` mevcut → UD_ gerekmez.
  - `Erp_InventoryTotal` kalite tutmuyor, `Erp_InventoryReceiptItemVariant`'ta `QualityTypeId` yok → kaliteli stok kalemden;
    NULL kalite 1K sayılır.
  - **Şirket 2'de satış siparişi (`ReceiptType=2`) yok**; 44 sipariş tip 1 = satın alma (FOSHAN, YIWU, aksesuar). Uygulama tip 2 kullanır.
  - Sipariş/box/fiş tablolarında NOT NULL + default'suz kolon yok → testler transaction içinde sahte satış siparişi ve stok fişi açabilir.
  - `uzman` CREATE TABLE yetkili → testler `UZM_KarmaKoli*` yoksa transaction içinde oluşturup ROLLBACK eder.

### 2. Plan
- **Dosya:** `docs/superpowers/plans/2026-10-04-paketleme-etiket-koli.md` (14 görev, TDD, her görev commit + push):
  1 Ortak SURUM 3 + test projesi · 2 şema `db/0001_paketleme.sql` + PaketAyarlari · 3 PaketKurallari · 4 tartı (V1/V2) ·
  5 FisYazici 10/130 · 6 karma koli/stok/sipariş sorguları · 7 okut/sil · 8 kapat (10+130) · 9 ürün etiketi 2×50×30 + Ortak SURUM 4 ·
  10 koli etiketi 10×10 · 11 eski ekranları sil + ana sayfa + etiket sekmesi · 12 koli listesi · 13 okutma/tartı ekranı · 14 canlı deneme + README.
- Spec §3'e bulgular eklendi.
- **Commit:** `576a7e6` — Paketleme: uygulama plani (14 gorev) + spec'e SentezCore bulgulari

## Kararlar
- Box tablolarına fiş bağı yazılmaz; `Erp_Box.InventoryReceiptId` sevkiyat irsaliyesine ayrılır (sevk edilmemiş tekli = InventoryReceiptId NULL).
- Etiket ölçüleri (50/30/2/0 mm) Ortak `Ayarlar`'a → Ortak SURUM 4 (diğer repolara taşıma ayrı iş).

## Açık kalanlar / sonraki adım
- Kullanıcı planı inceleyip yürütme yöntemini seçecek (subagent-driven / native).
- Sentez'de: paketleme deposu, en az bir satış siparişi, karma koli tabloları + tanımları.
