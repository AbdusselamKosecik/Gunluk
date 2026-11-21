# generic — 2026-11-21

## Bağlam
2026-11-20'de URT-15 (Nil Kara, Meta_User 103) Sentez'de 27 eski iş emrinde miktar/durum değiştirdi ve 18 yeni
alt iş emri açtı (bkz. 2026/11/20/generic.md). Kullanıcı eskilerin miktar ve durumlarını ilk hale almayı istedi;
yeniler manuel düzenlenecek.

## Yapılanlar

### 1. Eski 27 iş emrinde miktar/durum geri alma (08:55)
- **Yer:** 192.168.1.3 (ADAOSRV) `SentezCore2026` (Techtsio VPN kapalı olmalı).
- **Kaynak:** `Log_Transaction` (UserCode='Urt-15', 20.11, BOName='WorkOrderCardBO'), JSON `ChangeColumns`;
  her alan için günün **ilk** `BeforeValue`'su hedef değer. Yeni iş emirleri (log'da OperationType yok) hariç.
- **Ön kontrol:** 287 alanın tamamı hâlâ Nil'in son değerinde, 20.11 12:00 sonrası başka kullanıcı logu yok.
- **Geri alınan alanlar (258):** Erp_WorkOrder Quantity, QuantityPerLot, Status, UD_Durum, PackingQuantity;
  Erp_WorkOrderItem Quantity, RequirementIsChanged; Erp_WorkOrderItemVariant Quantity (143 hücre).
  **Dokunulmayan:** SpecialCode1 (4317-2, 4320-2'de boş kaldı), yeni 18 iş emri. `size_*`, `LotTotalQuantity`,
  `UD_Durum_*` sanal alan (varyanttan türüyor).
- **Yöntem:** scratchpad `revert.py` (pyodbc, tek transaction; her UPDATE `WHERE kolon = Nil'in son değeri`,
  eşleşmeyen olursa ROLLBACK). UpdatedAt=GETDATE(), UpdatedBy=1. Sentez Log_Transaction'a kayıt düşmez.
- **Yedek (değişiklik öncesi tam satırlar):** `zz_bak_URT15_WO_20261121` (27), `zz_bak_URT15_WOI_20261121` (25),
  `zz_bak_URT15_WOIV_20261121` (143).
- **Doğrulama:** `verify.py` → 258/258 alan log'daki önceki değerle aynı.
- **Uyarı:** Eskilerden alt iş emirlerine aktarılan adetler (4220-3, 4315-3, 4316-3, 4317-3, 4319-3, 4320-3,
  4823-1/-2, 4251-1/-2, 4278-1/-2, 4324-1/-2, 4378-1/-2, 4379-1/-2) yeniler düzeltilene kadar çift sayılır.
- **Geri dönüş (Nil'in haline):**
  ```sql
  UPDATE t SET Quantity=b.Quantity, QuantityPerLot=b.QuantityPerLot, Status=b.Status, UD_Durum=b.UD_Durum,
    PackingQuantity=b.PackingQuantity, UpdatedAt=b.UpdatedAt, UpdatedBy=b.UpdatedBy
  FROM Erp_WorkOrder t JOIN zz_bak_URT15_WO_20261121 b ON b.RecId=t.RecId;
  UPDATE t SET Quantity=b.Quantity, RequirementIsChanged=b.RequirementIsChanged, UpdatedAt=b.UpdatedAt, UpdatedBy=b.UpdatedBy
  FROM Erp_WorkOrderItem t JOIN zz_bak_URT15_WOI_20261121 b ON b.RecId=t.RecId;
  UPDATE t SET Quantity=b.Quantity, UpdatedAt=b.UpdatedAt, UpdatedBy=b.UpdatedBy
  FROM Erp_WorkOrderItemVariant t JOIN zz_bak_URT15_WOIV_20261121 b ON b.RecId=t.RecId;
  ```

## Açık kalanlar / sonraki adım
- Yeni 18 alt iş emri kullanıcı tarafında manuel düzenlenecek.
- Sentez Status kodlarının (1,2,4,5,6,7) açıklamaları bilinmiyor.
