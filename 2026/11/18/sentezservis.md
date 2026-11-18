# sentezservis — 2026-11-18

## Bağlam
İstek: X şirketinin Y fatura tipindeki Z numaralı fişinin detayını kümülatif (ÜrünKodu, Adet, TL fiyat)
çıkarıp, başka bir şirkette seçilen fişle karşılaştıran ekran. Ek istek: faturada olmayan ve fazla olan
kalemler de görünsün.

## Yapılanlar

### 1. Fiş karşılaştırma ekranı (`/fis-karsilastirma`)
- **Neden:** Şirketler arası (01/03/04) aynı malın fişlerini kalem kalem elle karşılaştırmak yerine.
- **Ne yapıldı:**
  - Kalem yolu: `Erp_Invoice` → `Erp_InventoryReceipt (InvoiceId = i.RecId OR RecId = i.InventoryReceiptId)`
    → `Erp_InventoryReceiptItem` (IsDeleted=0). Kod: `Erp_Inventory.InventoryCode`, yoksa `Erp_Service.ServiceCode`.
  - Ürün koduna göre GROUP BY: `SUM(Quantity)` adet, `SUM(NetItemTotal)` tutar. NetItemTotal = KDV hariç,
    indirim düşülmüş TL; toplamı faturanın `SubTotal`'ına eşit (canlıda 04/121/00507172 ile doğrulandı:
    6 kalem → 1 kod, 2164,49 = SubTotal). `UnitPrice` VatIncluded=1 iken KDV dahil olduğu için kullanılmadı.
  - Birim fiyat = tutar / adet (ağırlıklı ortalama).
  - Fiş no `ReceiptNo`; rakamsa baştaki sıfır önemsiz (507172 = 00507172). Aynı numarada >1 fatura varsa
    hepsi toplanır, ekranda uyarı.
  - Karşılaştırma C#'ta tam dış birleştirme; durumlar: eşit / adet farklı / fiyat farklı (±0,01 TL) /
    adet ve fiyat farklı / "2. fişte yok" / "1. fişte yok". Fark kolonları 2 − 1 (işaretli).
  - Fatura tipi kutusu şirkette kullanılan `ReceiptType`'lar + fiş sayısı (ad tablosu Sentez'de yok;
    `ReceiptTypeMap` bizim stok devir tablomuz, eksik — kullanılmadı).
- **Dokunulan dosyalar:** `src/SentezServis.Core/Fatura/FisKarsilastirma.cs`, `FisKarsilastirmaDeposu.cs`,
  `src/SentezServis.Host/Api/FisKarsilastirmaUclari.cs`, `src/SentezServis.Host/Program.cs`,
  `web/src/api/fisKarsilastirma.ts`, `web/src/pages/FisKarsilastirmaSayfasi.tsx` (+ `.test.tsx`),
  `web/src/App.tsx`, `web/src/components/Layout.tsx` (Operasyon menüsü), `tests/.../FisKarsilastirmaTestleri.cs`
- **Uçlar:** `GET /api/fis-karsilastirma/tipler?sirketId=`,
  `GET /api/fis-karsilastirma/?aSirketId&aTip&aNo&bSirketId&bTip&bNo` (GirisIster, ERP salt okur).
- **Komutlar:**
  ```bash
  dotnet test tests/SentezServis.Core.Tests     # 797/797
  cd web && npx vitest run && npm run build      # 99/99
  ```
- **Sonuç / doğrulama:** SQL canlı ERP'de (192.168.1.3 SentezCore2026) sqlcmd ile denendi, ~3 sn. Ekran
  tarayıcıda canlı veriyle denenmedi.
- **Commit:** `e520156` — Fis karsilastirma ekrani: iki sirketin fisini urun kodu bazinda karsilastirir

## Kararlar
- TL fiyat = NetItemTotal (KDV hariç net). KDV dahil gerekirse ItemTotalVatIncluded'a geçilir.
- Kod eşleşmesi büyük/küçük harf + boşluk duyarsız.

## Açık kalanlar / sonraki adım
- Canlı paket + tarayıcıda gerçek iki fişle deneme.
- Yeni istek (netleştirme bekliyor): 01/03/04 için barkodu olup satın alma/satış KONS fiyat kodu olmayan
  veya farklı olan ürünler ekranı.
