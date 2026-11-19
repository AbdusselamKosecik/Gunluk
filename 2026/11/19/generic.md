# generic — 2026-11-19

## Bağlam
`X:\Yazilim\generic` (git reposu değil) üzerinden altyapı/ERP destek işleri: OneDrive kaldırma,
Datas.xlsx hesap adı çevirisi, Sentez KONS fiyat senkronizasyonu.

## Yapılanlar

### 1. OneDrive'ın bilgisayardan kaldırılması
- **Neden:** Kullanıcı OneDrive'ı tamamen istemedi.
- **Ne yapıldı:** `OneDriveSetup.exe /uninstall /allusers` ve `/uninstall` (exit 0). Run anahtarı silindi,
  Explorer gezinti bölmesi girdisi gizlendi: CLSID `{018D5C66-4533-4307-9B53-224DE2ED1FE6}` →
  `System.IsPinnedToNameSpaceTree=0`. Kilitli 2 shell-extension DLL yüzünden
  `%LOCALAPPDATA%\Microsoft\OneDrive` silinemedi → RunOnce `OneDriveKalintiSil` sonraki oturumda siler.
- **Veri:** `C:\Users\abdus\OneDrive` klasörüne dokunulmadı (Known Folder Move aktifti; Desktop/Documents/
  Pictures orada; 3980 dosya cloud-only idi).
- **Açık:** Yönetici yetkisi yoktu, tekrar kurulumu engelleyen policy kullanıcıya verildi:
  ```powershell
  New-Item 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive' -Force | Out-Null; Set-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive' -Name DisableFileSyncNGSC -Value 1 -Type DWord
  ```

### 2. Datas.xlsx AccountName → İngilizce, max 50 karakter
- **Neden:** Tekdüzen hesap planı adlarının İngilizcesi isteniyordu.
- **Ne yapıldı:** Sheet1 (AccountCode, AccountName, Explanation, AccountType, CDType), 685 dolu satır,
  454 benzersiz ad. TR→EN sözlüğü (453 girdi, `.strip()` ile eşleşme), firma adları olduğu gibi.
  openpyxl ile `Datas_EN.xlsx` üretildi; orijinal `Datas.xlsx` değişmedi.
  İkinci tur: 50 karakteri aşan 25 ad (44 satır) muhasebe kısaltmalarıyla kısaltıldı
  (`ST LIAB.`/`LT LIAB.`, `DEPT.`, `ACC.`, `EXP.`, `R&D`, `QTY`, `MIN. OF ENVIRONMENT`...).
- **Sonuç / doğrulama:** 0 eşleşmeyen, en uzun ad 50, 50 üstü 0. Explanation sütunu Türkçe kaldı.
- **Not:** Python `-I` ile `PYTHONIOENCODING` yok sayılır → `sys.stdout.reconfigure(encoding='utf-8')`.

### 3. Sentez KONS fiyatları: 01 → 03 ve 04 (barkod eşleşmeli)
- **Neden:** KONS fiyat kodunda 01 şirketi baz; 03 ve 04'teki karşılık stoklar güncellenecek/eklenecek.
- **Yer:** SQL Server `192.168.1.3` (ADAOSRV), DB `SentezCore2026`.
  Şirketler: 01=CompanyId 2 (MODASIMA), 03=5 (VIUMOD), 04=7 (VIUMA). Stoklar şirkete özel (`Erp_Inventory.CompanyId`).
- **Yöntem:**
  1. Kaynak: `Erp_InventoryPriceList` CompanyId=2, PriceCode='KONS', silinmemiş; InventoryId+PriceType başına
     en son RecId (kaynakta çift kayıtlar var ama fiyatları aynı — 0 çakışma). 1221 satır / 614 stok.
  2. Eşleşme: kaynak stoğun tüm `Erp_InventoryBarcode` barkodları → hedef şirketteki aynı barkodlu stok.
  3. Belirsizlik kuralı: bir barkod birden fazla stoğa gidiyorsa (paket ürünler barkod paylaşıyor:
     6206↔6020, 6805↔6005, 6804↔6000-2, 6622↔6022) sadece **aynı InventoryCode** olan eşleşme tutuldu;
     hâlâ belirsiz kalan atıldı.
  4. Hedefte KONS+PriceType varsa Price UPDATE, yoksa kaynak satırdan kopyalanarak INSERT (UnitSetItemId NULL,
     InsertedBy=1, NEWID()).
- **Yedek:** `zz_bak_KONS_PriceList_20261119` (03+04 tüm KONS satırları, 1744 satır).
- **Script:** scratchpad `apply2.sql` (sqlcmd `-I -b`).
- **Sonuç:**
  - UPD RecId 45350 (03, stok 16202 / 2664 Dantelli Tek Slip, PriceType 1): 1.00 → 0.60
  - UPD RecId 46707 (04, stok 20834 / 2665 Tek Slip, PriceType 2): 1.00 → 0.60
  - INS RecId 47386 (03, stok 21315 / 1211 Penye Kapli Atlet, PriceType 2): 3.00
  - INS RecId 47387 (04, stok 21314 / 1211 Penye Kapli Atlet, PriceType 2): 3.00
  - Doğrulama: eşleşen satırlarda kalan fark 0 (03: 863, 04: 751 satır senkron).
- **Eşleşmeyenler:** 01'deki KONS stoklarından 03'te 179, 04'te 235 tanesinin barkod karşılığı yok
  (157'sinin 01'de hiç barkodu yok; kodla eşleşen sadece 1 / 5 adet).
- **Geri alma:**
  ```sql
  DELETE FROM Erp_InventoryPriceList WHERE RecId IN (47386,47387);
  UPDATE t SET Price=b.Price, UpdatedAt=b.UpdatedAt, UpdatedBy=b.UpdatedBy FROM Erp_InventoryPriceList t JOIN zz_bak_KONS_PriceList_20261119 b ON b.RecId=t.RecId WHERE t.RecId IN (45350,46707);
  ```

## Kararlar
- "İstanbul / 01-03-04" → `SentezCore2026` (SentezNewIst'te 04 şirketi yok).
- Barkod paylaşan farklı ürünlere fiyat yazılmadı (aynı kod şartı).

## Açık kalanlar / sonraki adım
- OneDrive engelleme policy'si yönetici olarak çalıştırılmalı.
- Sentez `VatIncluded` NULL düzeltmesi (2026-11-17) hâlâ onay bekliyor.
- BioTime cihaz senkronu (Yuz1/Yuz2, Fotoğraf + Bio-Fotoğraf) kullanıcıda.
