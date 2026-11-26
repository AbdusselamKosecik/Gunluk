# generic — 2026-11-26

## Yapılanlar

### 1. SentezCore2026 (192.168.1.3) — kodunda PZR geçen modellerin markası PZR
- **İstek:** "Kodunda PZR geçen modellerin gruplarını PZR yap" → soru üzerine kullanıcı: PZR bir **marka** (grup değil).
- **Kapsam:** `Erp_Inventory where InventoryCode like '%PZR%'` = 177 kart (hepsi InventoryType 6 model, CompanyId 2; 173'ü `-PZR-`/`-PZR` biçiminde, 4'ü `PZR-2056-*`, `PZR-2622`).
- **Önceki marka:** Pierre Cardin 171, PZR 5, misirli 1. Mevcut marka `Erp_Mark` RecId 33 "PZR" (2026-07-29, kullanıcı 104) kullanıldı, yeni marka açılmadı.
- **Uygulama (tek transaction, sayı kontrollü):** yedek `zz_bak_PZR_Mark_20261126` (RecId, MarkId, UpdatedAt, UpdatedBy; 177) → `update Erp_Inventory set MarkId=33, UpdatedAt=getdate(), UpdatedBy=1` (177) → COMMIT, kontrol 177.
- **Geri alma:**
  ```sql
  update i set MarkId=b.MarkId, UpdatedAt=b.UpdatedAt, UpdatedBy=b.UpdatedBy from Erp_Inventory i join zz_bak_PZR_Mark_20261126 b on b.RecId=i.RecId;
  ```
- **Not:** Grup (GroupId) değişmedi: 155 M-GÜNLÜK, 22 grupsuz.
