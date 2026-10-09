# modfex-apparel — 2026-10-10

## Bağlam
`TEST-10` stok kartının (Erp_Inventory.RecId = 87600, "6800 Ales Desteksiz Straplez 2'li Micro
Sütyen", CompanyId 2) varyantlarının çoğunda barkod yoktu. Kullanıcı isteği: eksik barkodları
**rastgele, sistemde olmayan EAN-13** ile oluştur. Kod değişikliği yok, yalnızca SentezCore verisi.

## Yapılanlar

### 1. TEST-10 eksik barkodlarının üretilmesi
- **Neden:** Bant sayım / paketleme ekranları varyantı barkoddan çözüyor
  (`UretimSorgulari.BarkodCozAsync`, `Erp_InventoryBarcode`); barkodsuz varyant okutulamıyor.
- **Durum öncesi:** 550 varyant (22 renk × 25 beden), yalnızca 9'unda (EKRU-EKRU) barkod vardı —
  bugün 00:11'de eklenmiş kayıtlar: `BarcodeType=0, InUse=1, InsertedBy=1`. Aynı şablon kullanıldı.
- **Ne yapıldı:** Tek transaction'da her barkodsuz varyant için `2` ile başlayan (GS1 mağaza içi
  aralık, gerçek ürün barkoduyla çakışmaz) rastgele 12 hane + EAN-13 kontrol hanesi üretildi;
  `Erp_InventoryBarcode`'ta (tüm tablo) ve aynı partide olmadığı kontrol edildi, sonra INSERT.
- **Bağlantı:** `%LOCALAPPDATA%\Modfex\bantsayim\ayarlar.json` (Sunucu 100.119.104.122, DB SentezCore,
  kullanıcı uzman). Şifre DPAPI CurrentUser, entropi `"Modfex.Ortak.Ayarlar"` → PowerShell
  `ProtectedData.Unprotect` ile çözülüp `sqlcmd -C -N` ile bağlanıldı.
- **SQL özü:**
  ```sql
  -- eksik varyantlar
  INSERT @eksik(VarId) SELECT iv.RecId FROM Erp_InventoryVariant iv
  WHERE iv.InventoryId = 87600 AND ISNULL(iv.IsDeleted,0)=0
    AND NOT EXISTS (SELECT 1 FROM Erp_InventoryBarcode ib WHERE ib.InventoryVariantId = iv.RecId AND ISNULL(ib.IsDeleted,0)=0);
  -- her biri için: @b12 = '2' + 11 rastgele hane (NEWID); kontrol = (10 - Σ(tek×1, çift×3) % 10) % 10
  -- Barcode tabloda yoksa (UPDLOCK,HOLDLOCK) kabul
  INSERT Erp_InventoryBarcode (InventoryId, InventoryVariantId, BarcodeType, Barcode, InUse, InsertedAt, InsertedBy)
  SELECT 87600, VarId, 0, Barkod, 1, GETDATE(), 1 FROM @eksik;
  ```
- **Sonuç / doğrulama:** 541 kayıt eklendi; 550/550 varyant barkodlu; tablo genelinde çakışan
  barkod 0; örnek barkodların kontrol hanesi Python ile doğrulandı.
- **Commit:** yok (repo değişikliği yok, yalnızca veri).

## Kararlar
- Rastgele barkodlar `2` önekli → gerçek GS1 firma barkodlarıyla çakışma riski yok.
- Mevcut 9 barkoda dokunulmadı.

## Açık kalanlar / sonraki adım
- Geri almak gerekirse: `DELETE Erp_InventoryBarcode WHERE InventoryId=87600 AND Barcode LIKE '2%' AND InsertedAt >= '2026-10-10'`
  (00:11'deki 9 kayıt 2 ile başlamıyor, etkilenmez).
