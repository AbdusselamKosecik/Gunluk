# sevkiyatmobil — 2026-10-11

## Bağlam
Kullanıcı: paketleme masasının yanında yalnız sevkiyat için Android 6 mobil uygulama. Netleşen kapsam: paketlemede
kapanan kolileri okutup sevk irsaliyesine (fiş 120) bağlamak. Dahili lazer okuyuculu el terminali.

## Yapılanlar

### 1. Araştırma + kararlar + tasarım
- **Neden:** referans (Frederic `UZM_Sevkiyat_BoxRead`) SP gövdeleri hiçbir yerde yok; mantık C# çağıranlardan çıkarıldı
  (fiş 120, InvoiceId NULL liste, ret kodları -1/-2/-3/-4, P1/P2 kırpma, ilk okutmada irsaliye oluşur).
- **Kararlar (kullanıcı):** yeni repo; tek sipariş/irsaliye; 120 stoktan düşer; palet yok; ilk okutmada
  "bu müşterinin kolisi, devam?" onayı.
- **Teknik karar:** depo kalem bazında — set → PaketlemeDepoId (fiş 10 ile girmişti), tekli → UretimDepoId 42
  (paketleme stok kuralı `Erp_Box.InventoryReceiptId IS NULL` ile tutarlı). Yeni tablolar `UZM_SevkIrsaliye`, `UZM_SevkOkutma`.
- **Dokunulan dosyalar:** `docs/superpowers/specs/2026-10-11-sevkiyatmobil-design.md`
- **Komutlar:** `git init -b main; git remote add origin git@gitlab.com:modfex-apparel/sevkiyatmobil.git; git push -u origin main` (push ile proje oluştu)
- **Commit:** ilk commit — Tasarım: sevkiyat mobil

## Açık kalanlar / sonraki adım
- Spec incelemesi (kullanıcı) → plan → uygulama.
- Canlıda doğrulanacak: Erp_InventoryReceipt `DriverName/DriverIdNo/PlateNumber`, mevcut 120 fişlerinin alanları, kalem bazında depo.
- Sunucu şu an erişilemiyor (laptop ağ dışı).
- Sırada: paketlemede barkod + adet girişi.
