# malkabul — 2026-11-15

## Yapılanlar
### 1. Mal alım tasarımı (taslak, onay bekliyor)
- **Neden:** Kullanıcı: "Serisizler direkt, serililer seri oluşturup mal alım… sonra inspection (17 veya iade)"; "T-00000001 siparişini
  kapatarak seri üreterek almamız lazım"; "aksesuarlar da serili, sadece iplikte yok".
- **Canlı bulgular:** serili = `Erp_Inventory.HasSeries`; `Erp_InventoryReceiptItemInsert` → `EditOrderReceived` siparişi Sentez kapatır;
  tip 122 geri düşer; `Erp_InventorySerialTransactionInsert` seri × depo toplamını tutar. Bugünkü malkabul yalnız seri kartı açıyor.
- **Ne yapıldı:** `docs/superpowers/specs/2026-11-15-mal-alim-fis1-design.md` — fiş 1 → 43, (sipariş, irsaliye no) başına başlık,
  serili satırda seri kartı + seri hareketi, serisizde düz kalem; inspection Adım 2.
- **Commit:** `358f5af`

## Açık kalanlar
- Kullanıcı onayı → plan → uygulama. Önce varyant barkodları (sentezservis barkod ekranı).
