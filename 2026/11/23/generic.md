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
