# malkabul (SentezCore bakımı) — 2026-11-26

## Bağlam
Dünkü muhasebe sıfırlamasının (bkz. 2026/11/25/malkabul.md §6–8) devamı. Kullanıcı: "KDV'ler temizlensin; yalnız %14, %5, %0 kalsın, diğerlerinin kullanıldığı her yer %14'e çekilsin, sonra silinsin."

## Yapılanlar

### 1. Canlı SentezCore: KDV kartları temizlendi
- **Keşif (salt okunur):**
  - KDV kartları `Erp_Tax` (TaxType 1) tablosunda.
  - Kalanlar: RecId 4 (%0), 19 (%5), 18 (%14).
  - Silinenler: 1 (%1), 2 (%8), 3 (%18), 15 (%20), 16 (%10).
  - FK yok, referanslar kolon adıyla bulundu:
    - `Erp_Inventory`: VatId, RetailVatId, RetailReturnVatId, WholeSaleVatId, WholeSaleReturnVatId, TaxId.
    - `Erp_Service`: Purchase(Return)VatId, Sales(Return)VatId, ACC/EXT/SCTVatId, TaxId.
    - `Erp_TaxIA.TaxId`: KDV başına muhasebe entegrasyon satırları.
  - Bu tablolarda tetikleyici yok.
- **Ne yapıldı:** Tek Serializable işlemde çalıştırıldı; önce ROLLBACK ile deneme yapıldı, sonra `--onayla` ile COMMIT edildi.
  - `UPDATE <tablo> SET <kolon>=18 WHERE <kolon> IN (1,2,3,15,16)`, yukarıdaki tüm kolonlar için:
    - Stok kartları: VatId, RetailVatId, RetailReturnVatId ve WholeSaleVatId kolonlarında 4204'er; WholeSaleReturnVatId'de 376.
    - Hizmet kartları: Purchase ve PurchaseReturn 36'şar; Sales ve SalesReturn 1'er.
  - `Erp_Expense.VatRate` (masraf kartı oran alanı): 0/5/14 dışındaki 1 kayıt (%1) 14 yapıldı.
  - Silinen KDV'lerin `Erp_TaxIA` satırları silindi: 63. KDV 18'in kendi 25 satırı duruyor.
  - `DELETE Erp_Tax WHERE RecId IN (1,2,3,15,16)`: 5 kayıt.
  - Kontrol: kart kolonlarında yetim KDV referansı 0. Kalan: 4 = %0, 19 = %5, 18 = %14.
- **Yedek:** `X:\Gitlab\modfex-apparel\yedek\sentez-kdv-20261126-135852.json`. İçeriği: tüm Erp_Tax, silinen TaxIA satırları, değişen her kolon için RecId ve eski değer.
- **Betik:** scratchpad `sqldene/kdvsil.cs`. glsil.cs kalıbı: dotnet run file-based; malkabul csproj'una `#:project` ile bağlanıp `Veritabani.AcAsync()` kullanıyor.

## Kararlar
- Geçmiş fişlerdeki satır oranlarına (`VatRate` decimal; Erp_InventoryReceiptItem'da 8 → 74 ve 10 → 703 satır, Erp_OrderReceiptItem'da 8 → 44 ve 10 → 89 satır) dokunulmadı. Bunlar KDV kartına bağlı değil, belgeye yazılmış oran; değiştirilirse tutarlar bozulur.

## Açık kalanlar
- Geçmiş fiş satırlarındaki %8/%10 oranları değişmesin mi, yoksa fişler de mi temizlensin? Kullanıcı karar verecek.
- KDV 18/19'un `Erp_TaxIA` muhasebe hesapları, yeni hesap planı girildikten sonra bağlanacak.

### 2. Canlı SentezCore: GL hesapları tekrar silindi (yeni plan yüklenecek)
- **Neden:** 25.11 16:11'de yüklenen 160 hesap yeniden yüklenecek; kullanıcı "silermisin, yenisini yükleyeceğim" dedi.
- **Ne yapıldı:** `sqldene/glsil.cs` (2026/11/25 §7 betiği) önce ROLLBACK denemesiyle, sonra `--onayla` ile çalıştırıldı.
  - FK kolonlarında dolu değer yoktu.
  - GLAccountTotal 0, GLReceipt 0.
  - Erp_GLAccount'tan 160 hesap silindi; kalan 0.
- **Yedek:** `X:\Gitlab\modfex-apparel\yedek\sentez-glaccount-20261126-144943.json`

### 3. Canlı SentezCore: 1 tipli satın alma irsaliyeleri, seri kartları ve hareketleri silindi
- **Neden:** Kullanıcı tüm 1 tipli (satın alma) irsaliyeleri, bunlarla giren seri kartlarını ve kartların bütün hareketlerini sildirmek istedi.
- **Ön inceleme (salt okunur):**
  - 21 fiş (08.10.2025–22.11.2026), 773 kalem.
  - Kalemlerin 765'i satın alma siparişine bağlıydı.
  - Etkilenen stok/depo bakiyesi 102; bunlardan 8'i eksiye düşüyor. Kullanıcıya bildirildi.
- **Ne yapıldı:** `sqldene/irssil.cs`, tek bir Serializable işlem içinde.
  - Kümeler: #R = tip 1 fişler, #I = bu fişlerin kalemleri, #S = bu kalemlerde hareketi olan seri kartları.
  - Erp_InventoryReceipt / ReceiptItem / SerialCard'a giden tüm FK'lar tarandı. Bağlı tablolardaki satırlar silindi:
    - SerialTransaction 45
    - SerialCardTotal 45 (seri hareketleri silindikten sonra; tetikleyici bu tabloya yazıyor)
    - Allocation 910
    - ReceiptItemVariant 755
  - Ardından SerialCard 45, ReceiptItem 773 ve Receipt 21 silindi.
  - Güvenlik kontrolü: tablo sayılarındaki gerçek azalma 21/773/45 değilse COMMIT yapılmıyor. ExecuteAsync satır sayıları stok toplamı tetikleyicileri yüzünden şişik görünüyor (ör. kalem için 8441).
  - İlk denemede iki hata çıktı ve geri alındı: silinecek kalemlerin fiş FK'sı NULL'lanıyordu, SerialCardTotal ise FK'ya takılıyordu. Düzeltildi; ikinci deneme temiz geçti, sonra COMMIT edildi.
- **Yedek:** `X:/Gitlab/modfex-apparel/yedek/sentez-irsaliye-tip1-20261126-150701.json` (tüm silinen satırlar).
- **Sonuç:** Kalan tip 1 fiş: 0.

## Açık kalanlar (güncel)
- 8 stok/depo bakiyesi eksiye düştü: tip 1 girişlerinden sonra yapılan çıkışlar duruyor.
- Silinen fişlere bağlı satın alma siparişleri yeniden açık (teslim alınmamış) görünecek.

### 4. Canlı SentezCore: 1 tipli satın alma siparişleri silindi
- **Neden:** Kullanıcı "Satınalma siparişleri 1 tipi silermisin" dedi. §3'te irsaliyeler silindikten sonra bu siparişlere fiş bağı kalmamıştı.
- **Ne yapıldı:** `sqldene/sipsil.cs`, irssil.cs kalıbıyla yazıldı; önce ROLLBACK denemesi, sonra COMMIT.
  - Kümeler: #R = Erp_OrderReceipt tip 1 (45 kayıt, 06.10.2025–15.11.2026); #I = bu siparişlerin kalemleri (1099).
  - FK taraması: kalemler dışında yalnız Erp_OrderReceiptItemVariant (1005) ve Erp_InventoryAllocation.OrderReceiptItemId (1320) bağlıydı; ikisi de silindi.
  - FK'sız OrderReceiptItemId/OrderReceiptId kolonlarında da referans yoktu.
  - Ardından kalemler ve siparişler silindi.
  - Gerçek azalma kontrolü: 45 sipariş, 1099 kalem doğrulandı.
- **Yedek:** `X:\Gitlab\modfex-apparel\yedek\sentez-siparis-tip1-20261126-151732.json`
- **Sonuç:** Kalan tip 1 sipariş 0. Tip 2 (satış) siparişlerinin 21'i duruyor.
