# paketleme — 2026-10-18

## Bağlam
Kullanıcı: "PK1-00000002-036 bunların type'larını 1 yapıyoruz, sıkıntı oldu Sentez'de … InventoryReceiptItemId alanlarını doldurmayalım, sadece sevkiyatta … 10, 130 ve 17 numaralı fişlerde workorder(item)id ekleyelim."
Canlıda PK1 kolileri Erp_Box.BoxType=2 (41 adet); Sentez'in kendi box'ları ve bant box'ları (URT) 1.

## Yapılanlar

### 1. Koli BoxType 1; fiş 10/130'a iş emri ve iş emri satırı
- **Ne yapıldı:**
  - **Koli tipi:** `KoliDeposu.KoliAcAsync` → Erp_Box.BoxType=1.
  - **Bant box'ı ayrımı:** BoxType ile değil, `UZM_UretimBox` ile yapılıyor:
    - `TezgahDeposu.BantBoxuMuAsync` → EXISTS UZM_UretimBox.
    - `DokAsync`'ten `BoxType=1` filtresi kalktı (zaten JOIN'li).
    - Sonuç: PK1 kodu tezgahta `BoxBulunamadi` verir.
  - **Fişler:**
    - Paketleme yalnız 10 ve 130 yazıyor (set kolisi kapanınca). 17'yi sevkiyatmobil yazıyor.
    - Kaleme `WorkOrderId` + `WorkOrderReceiptItemId` (varyantın o iş emrindeki `Erp_WorkOrderItemVariant.WorkOrderItemId`); varyant kalemine `WorkOrderItemVariantId`.
    - Kalem (InventoryId, iş emri satırı) başına ayrılıyor. İş emri kaynağı `Erp_Box.WorkOrderId`.
    - Satır bulunamazsa NULL (karma set); koli iş emirsizse eski davranış.
  - **BoxItem:**
    - `InventoryReceiptItemId` paketlemede zaten doldurulmuyordu; yorum + test eklendi.
    - `UD_WorkOrderItemId` koli okutmada zaten yazılıyordu (13.10).
  - **Testler:** `DbTestOrtami`: `MODFEX_SUNUCU` ile sunucu yalnız bellekte değişiyor.
- **Dokunulan dosyalar:**
  - Kod: `Paketleme/Ekranlar/Veri/{KoliDeposu.cs, KoliDeposu.Kapat.cs, TezgahDeposu.cs, FisYazici.cs, FisSql.cs}`, `db/0002_tezgah.sql` (yorum).
  - Testler: `Paketleme.Tests/{DbTestOrtami, FisYaziciTestleri, KoliIsEmriTestleri, KoliOkutmaTestleri, TezgahTestVerisi, TezgahTestleri}.cs`.
- **Test:** 4 yeni DB testi (2 fiş, 1 koli kapatma, 1 tezgah), önce kırmızı. `MODFEX_DB_TEST=1 MODFEX_SUNUCU=192.168.0.2 dotnet test` → 215/215.
- **Commit:** `4a3081e`. Push edildi. Kurulmadı.

## Kararlar
- Koli ile bant box'ı tipten değil kendi UZM tablolarından ayrılır (UZM_PaketKoli / UZM_UretimBox).

## Açık kalanlar
- **sevkiyatmobil:** `SevkDeposu.KoliAsync` `BoxType=2` aramasını bırakmalı (ayrı çalışmada). İki uygulama birlikte yayınlanmalı.
- **Canlıdaki 41 eski PK1 kolisi** (BoxType 2) kullanıcı onayı olmadan güncellenmedi. Önerilen:
  `UPDATE bx SET BoxType = 1 FROM dbo.Erp_Box bx JOIN dbo.UZM_PaketKoli pk ON pk.BoxId = bx.RecId WHERE bx.BoxType = 2`
