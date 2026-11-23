# generic — 2026-11-23

## Yapılanlar

### 1. DENDATA departman listesi
- **Neden:** Kullanıcı Den'deki departman listesini istedi.
- **Ne yapıldı:** `\192.168.0.2\Dendata\Den\Per\Egp\12r\f01\2026\DEPXX.MAS` (990 × 4331 B kayıt, son yazım 22.11 10:17) scratchpad'e kopyalandı, ad @3 ShortString (uzunluk @2, cp1254) okundu. Python UNC yolu açamadı → önce PowerShell `Copy-Item` ile yerel kopya.
- **Sonuç:** 18 dolu kayıt (19–990 boş): 1 ADMINISTRATION, 2 PRODUCTION MGMT, 3 SAMPLE, 4 RAW MAT. WAREHOUSE, 5 CUTTING, 6–12 LINE 1–7, 13 QUALITY CONTROL, 14 PACKING, 15 FG WH. & SHIPPING, 16 MAINTENANCE, 17 SECURITY, 18 SERVICE (TRANSPORT). BioTime'daki DEN01–DEN18 ile aynı sıra.

### 2. (21.11 devamı) 0.3:8085
- 192.168.0.3 = DATASRV (MODFEXTR DC); WMI/DCOM (srv02.cred) ile dinleyen portlar listelendi, 8085 yok. 192.168.1.3'te 8085 dışarıdan kapalı, srv02.cred ile WMI erişimi reddedildi. Kullanıcıdan hangi makine olduğu bekleniyor.

### 3. Departman listesi Excel
- **Ne yapıldı:** scratchpad `depxl.py` (openpyxl) ile `DEPXX.MAS` → `C:\Users\abdus\Desktop\DENDATA_Departmanlar_20261123.xlsx` (sütunlar No, Departman; 18 satır).

### 4. SentezCore (192.168.0.2) — USD kullanım dökümü (ana para birimi USD yapılacak)
- **Neden:** Kullanıcı ana para birimini USD yapacak; bunun için USD'nin `Meta_Forex`'ten silinmesi gerekiyor. Silmeden önce USD'nin nerelerde kullanıldığı istendi. DB yedeği kullanıcı tarafından alındı. **Hiçbir şey değiştirilmedi** (yalnızca okuma).
- **Erişim:** WinRM `srv02.cred` → 192.168.0.2 (modfexsrv), `sqlcmd -S . -E -d SentezCore`. Türkçe karakter için `-f 65001 -o dosya` + UTF-8 okuma (konsola OEM sayfası basıyor).
- **Bulgular:**
  - `Meta_Forex`: USD=1, EUR=2, GBP=3, TL=17, LE=18. 86 FK Meta_Forex'e bağlı.
  - Ana para birimi `Erp_Parameter` PrmGroup=2 PrmId=10: genel `LE`, şirket 2 (01 MODFEX) ve 5 (03 VIUMOD) `TL`.
  - USD satırı olan tablolar: Meta_ForexRate 2388 (RateDate 2025-01-21…2026-11-22), Erp_OrderReceiptItem 235, Erp_InventoryReceiptItem 165, Erp_CostCenterTotal 5, Erp_OrderReceipt 5, Erp_InventoryReceipt 4, Erp_WorkOrderItem 4, Erp_InitialCost 2, Erp_InitialCostItem 2, Erp_WorkOrder 2, Erp_CurrentAccountReceiptItem 1, Erp_CurrentAccountTotal 1, Erp_Invoice 1, Erp_ReceiptPaymentItem 1. Diğer ~100 kolon 0.
  - Belge bazında (hepsi şirket 2): 21 sipariş, 7 irsaliye, 1 fatura (00000002), 2 iş emri (8500, CKR-001).
- **Çıktı:** `C:\Users\abdus\Desktop\SentezCore_USD_Kullanim_20261123.xlsx` (Özet, Belgeler, Kur, tablo başına ayrıntı). Betikler scratchpad `usdxl.py`, `usd\*.tsv`.
- **Açık:** USD silinmeden önce bu kayıtların ne olacağı (TL/LE'ye mi çevrilecek, ForexId NULL mı) ve PrmId=10 değişikliği kullanıcı kararı bekliyor.

### 5. SentezCore USD kurları silindi
- **Neden:** Kullanıcı "önce kurları direk silelim" dedi (DB yedeği kullanıcıda).
- **Kontrol:** `Meta_ForexRate`'e FK/trigger yok; `%ForexRateId` kolonlarının hiçbiri USD kur RecId'lerine bakmıyor. Meta_Forex / Meta_ForexRate'te CompanyId yok → **global** (tüm şirketler ortak).
- **Uygulama (tek transaction, sayı kontrollü):**
  ```sql
  select * into zz_bak_MetaForexRate_USD_20261123 from Meta_ForexRate where ForexId=1;  -- 2388
  delete from Meta_ForexRate where ForexId=1;                                           -- 2388
  ```
- **Sonuç:** COMMIT, kalan USD kur 0, toplam kur 4776 (EUR+GBP).
- **Geri alma:** `insert Meta_ForexRate select * from zz_bak_MetaForexRate_USD_20261123` (RecId identity ise `set identity_insert Meta_ForexRate on` + kolon listesi).

### 6. SentezCore — 02 ve 03 şirketleri tüm verileriyle silindi
- **Neden:** Kullanıcı 02 ("Sil", RecId 3) ve 03 (VIUMOD, RecId 5) şirketlerini komple silmek istedi; "yedek almadan sil, DB yedeğini aldım" dedi → ek yedek tablosu **alınmadı**, geri dönüş yalnızca kullanıcının tam DB yedeğinden.
- **Analiz:** 185 CompanyId'li tablodan 23'ünde veri (hareket yok; sadece stok/hizmet kartları, kategori, rota, parametre vb.). FK üzerinden özyinelemeli (RecId bazlı) bağımlı satırlar toplandı + FK'siz `Erp_ServiceTotal.ServiceId` (35). Toplam **131.568 satır** (InventoryVariant 87.990, InventoryBarcode 23.269, InventoryUnitItemSize 10.274, Parameter 2.206, Inventory 2.028 …). 01'den bu satırlara bakan kayıt yok (FK ve ad eşleşmeli FK'siz kolon kontrolü).
- **Uygulama:** tek transaction, xact_abort; satır düzeyinde gerçek FK kenarlarıyla topolojik sıra; takılırsa yalnız döngüdeki NULL'lanabilir kenarlar koparılacaktı (gerek olmadı). Silinen = hedef kontrolü.
  - 1. deneme: tablo düzeyi sıralama → döngü, ROLLBACK.
  - 2. deneme: tüm NULL'lanabilir kenarları NULL'lama → `Erp_CostCenter_IX0` unique ihlali (CompanyId NULL), ROLLBACK.
  - 3. deneme: COMMIT 131568/131568, döngü kırma 0. Süre ~20 dk (Erp_VariantItem silmesi FK kontrolleri yüzünden yavaş).
- **Doğrulama:** CompanyId in (3,5) olan satır kalmadı; `Erp_Company` yalnız RecId 2 (01 2025-MODFEX).

### 7. SentezCore — USD döviz kayıtları ana paraya çevrildi, USD silindi
- **Neden:** Ana para birimi USD olacak; kullanıcı kuralı: USD'li her kayıtta `UnitPrice=ForexUnitPrice, ForexId=NULL, ForexRate=0, ForexUnitPrice=0`, sonra USD'yi sil. Ek yedek alınmadı (kullanıcının tam DB yedeği var).
- **Ne yapıldı:** Meta_Forex'e bağlı tüm FK kolonlarında `=1` olan tablolar bulundu; tablo başına mevcut kolonlara göre dinamik UPDATE (ForexRate yoksa / UnitPrice-ForexUnitPrice yoksa o kısım atlandı; UpdatedAt=getdate(), UpdatedBy=1). Tek transaction, satır sayısı kontrolü, ardından `delete Meta_Forex where RecId=1`.
- **Sonuç (COMMIT):** OrderReceiptItem 235, InventoryReceiptItem 165, CostCenterTotal 5, OrderReceipt 5, WorkOrderItem 4, InventoryReceipt 4, InitialCostItem 2, InitialCost 2, WorkOrder 2, ReceiptPaymentItem 1, Invoice 1, CurrentAccountReceiptItem 1, CurrentAccountTotal 1. Meta_Forex'te kalan aktif: EUR, GBP, TL, LE.
- **Dokunulmayanlar (kural dışı):** ForexAmount (ReceiptPaymentItem), ForexDebit/ForexCredit (CurrentAccountReceiptItem), Forex2Rate/Forex3Rate; satır tutarları (Amount vb.) yeniden hesaplanmadı.
- **Açık:** Ana para parametresi `Erp_Parameter` 2/10 hâlâ 01=TL, genel=LE → USD yapılacak mı.

### 8. SentezCore — masraf yerleri silindi
- **Neden:** Kullanıcı "masraf yerlerini sil, sonra accountları" dedi.
- **Analiz:** `Erp_CostCenter` 25 kayıt; FK referansları: Erp_CostCenterTotal 74, Erp_Cash.CostCenterId 5, Erp_Expense.CostCenterId 1. FK'siz `%CostCenter%Id` kolonlarında referans yok.
- **Uygulama (tek transaction, sayı kontrollü):** `delete Erp_CostCenterTotal` (74) → Erp_Cash/Erp_Expense CostCenterId=NULL (5/1) → Erp_CostCenter self-ref NULL → `delete Erp_CostCenter` (25). İlk denemede beklenen total sayısı 80 (eski tarama, 02/03 dahil) yazıldığı için ROLLBACK; 74 ile COMMIT. Kalan 0.
- **Accountlar:** cari (`Erp_CurrentAccount` 46; iş emri 1461, sipariş 63, irsaliye 46, fatura 5 … bağlı) mi muhasebe hesabı (`Erp_GLAccount` 371; BankAccountIA 16, GLAccountTotal 6, GLReceiptItem 5, cari GL bağlantısı 2+2) mı — kullanıcıya soruldu.
