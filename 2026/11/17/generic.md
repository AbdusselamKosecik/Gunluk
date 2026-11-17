# generic — 2026-11-17

## Bağlam
İki ayrı destek işi: (1) Sentez'de e-fatura oluştururken DBNull hatası, (2) ZKBio Time'da (PDKS)
biyometrik fotoğrafların cihazlarda görünmemesi.

## Yapılanlar

### 1. Sentez e-fatura: "Object cannot be cast from DBNull" (yalnız teşhis, veri değişmedi)
- **Neden:** MDM2026000000362 için e-fatura oluşturulamıyordu (`EInvoiceCreateFileService.InventoryAndServiceRowAdd`).
- **Erişim:** 192.168.1.3 (ADAOSRV) SQL `sa`; VPN açıkken 1433 erişilemedi → VPN kapatılınca bağlandı.
  Fatura `SentezCore2026`, CompanyId **2** (MODASIMA), RecId 1270773; alıcı VIUMA (şirket 7).
- **Ne yapıldı:** Satırlar `Erp_InventoryReceipt.InvoiceId` → `Erp_InventoryReceiptItem`. Bozuk faturayı başarılı
  faturalarla (361, 363–365) NULL kolon bazında karşılaştırdım; satır/stok/varyant/birim tablolarında özgü NULL yok.
  `X:\GitHub\Sentez-Core\Dlls\InvoiceModule.dll` ilspycmd ile açıldı: metod içinde korumasız
  `Convert.ToBoolean(itemRow["VatIncluded"])` (2 yer, her satırda çalışıyor).
- **Kök neden:** Faturadaki 3 satırda (`2284744`, `2300151`, `2300153`, stok 1211 Penye Kapli Atlet)
  `VatIncluded` NULL. Her gece ~23:28'de çalışan şirketlerarası irsaliye süreci (InsertedBy=1; SQL Agent değil,
  muhtemelen MDSMHYPERV'deki SWService) `VatIncluded`'ı doldurmuyor. Faturalanmamış NULL satır: şirket 7: 1105,
  şirket 2: 679, şirket 5: 89. Şirket 7'de ayrıca MDM2026000000299 (durum 0) aynı sorunla bekliyor.
- **Komutlar:** `sqlcmd -S 192.168.1.3 -U sa -P *** -d SentezCore2026 ...`; `ilspycmd -t Sentez.InvoiceModule.Services2.EInvoiceCreateFileService InvoiceModule.dll`
- **Önerilen (onay bekliyor):** yedek tablo + `UPDATE Erp_InventoryReceiptItem SET VatIncluded=0 WHERE RecId IN (...) AND VatIncluded IS NULL`;
  sonra toplu düzeltme; kalıcı çözüm gece sürecinde. Not: NULL satırların fiyatı KDV dahil hesaplanmış (3,00 dahil / 2,727 net),
  elle düzeltilmiş benzeri 3,00 net — fiyat kullanıcıca teyit edilmeli.

### 2. ZKBio Time biyometrik fotoğraflar cihaza gitmiyor (DÜZELTİLDİ)
- **Neden:** 15-11'deki kişi kodu değişikliğinden sonra cihazlar `CLEAR DATA` ile temizlendi (15-11 18:04);
  sonraki senkronlarda (16-11 23:19, 17-11 00:02, 17-11 14:52, Bio-Fotoğraf=True) hiç `DATA UPDATE BIOPHOTO` üretilmedi.
- **Kök neden:** Cihaz komutu dosyayı PIN ile istiyor: `Url=iclock/doc/biophoto/<emp_code>.jpg`. Dosyalar ve
  `iclock_biophoto.approval_photo` eski kodla kalmıştı (ör. 000021 → `1508.jpg`). 331 kayıt uyumsuz (326 aktif).
  Dosyalar/DB sağlam (818/818 dosya mevcut). `bio-redis` Manual+Stopped normal; önbellek `bio-cache` (7396).
- **Yedek:** `C:\Yedek\biophoto_duzeltme_20261117\` → `biophoto\` (825 dosya), `zkbiotime_20261117_1600.bak`
  (COPY_ONLY+CHECKSUM, VERIFYONLY ok); tablo `zz_bak_iclock_biophoto_20261117` (819).
- **Test:** `54562.jpg` → `099999.jpg` kopyası; `http://127.0.0.1:8088/iclock/doc/biophoto/099999.jpg?SN=...`
  → 200, `FF D8 FF` (dosyalar `eav1` şifreli ama ad bağımsız çözülüyor). Port 80/81'de bu yol 404, cihaz portu 8088.
- **Uygulama:** 330 dosya `<eski>.jpg` → `<emp_code>.jpg` **kopyalandı** (eskiler duruyor);
  `UPDATE iclock_biophoto SET approval_photo=emp_code+'.jpg'` tek transaction, beklenen 331 = 331 → COMMIT.
  Kalan uyumsuz 0, DB'de olup diskte olmayan 0. `Restart-Service bio-cache`; web 200.
- **Erişim:** WinRM `srv02.cred` → 192.168.0.2, `sqlcmd -S . -E -d zkbiotime`.

## Kararlar
- Fotoğraf dosyaları yeniden adlandırılmadı, kopyalandı (geri dönüş kolay).
- Sentez verisine onaysız dokunulmadı.

## Açık kalanlar / sonraki adım
- BioTime: kullanıcı "Verileri Cihaza Senkronize Et" (Yuz1+Yuz2, Bio-Fotoğraf) → `iclock_terminalcommandlog`'da
  `DATA UPDATE BIOPHOTO` ~331/cihaz ve return_value=0 doğrulanacak.
- Gelecekte kod değişikliğinde `iclock_biophoto.approval_photo` + biophoto dosya adları da güncellenmeli.
- Sentez: VatIncluded düzeltmesi + gece sürecinin kaynağı (SWService?) onay bekliyor.

## Ek — 16:15 Profil fotoğrafları + parmak/avuç listesi
- **Neden:** Kullanıcı profil fotoğraflarının (`personnel_employee.photo`) da düzeltilmesini, olmayanların biyometrik
  fotoğraftan doldurulmasını istedi. Durum: aktif 357 kişiden yalnız 1'inde (4521) profil fotoğrafı vardı.
- **Yedek:** `C:\Yedek\biophoto_duzeltme_20261117\photo\` (30 dosya), tablo `zz_bak_employee_photo_20261117` (917).
- **Ne yapıldı:** Profil ve biyometrik fotoğraf aynı `eav1` şifreli biçimde. Aktif + foto boş kişiler için kaynak sırası:
  (a) `photo\<eski kod>.jpg` (eski kod = `zz_bak_iclock_biophoto_20261117.approval_photo`) → 15 kişi,
  (b) `biophoto\<emp_code>.jpg` → 322 kişi. Hedef `photo\<emp_code>.jpg` (kopya), `photo='photo/'+emp_code+'.jpg'`.
  İlk UPDATE `QUOTED_IDENTIFIER` hatasıyla (Msg 1934) reddedildi → `sqlcmd -I` ile tekrar: COMMIT 337/337.
- **Sonuç:** Aktif fotoğraflı 338, diskte eksik 0. Kaynağı olmayan 19 aktif kişi (çoğu yalnız avuç/parmak kayıtlı).
- **Parmak/avuç:** `iclock_biodata` bio_type 1 (parmak), 8 (avuç). Aktif: avuç 23 kişi, parmak 6 kişi; yüz kaydı
  olmayan aktif kişiler fotoğrafsız kalanlarla örtüşüyor.
- **Açık:** Cihazlara "Verileri Cihaza Senkronize Et" (Fotoğraf + Bio-Fotoğraf) kullanıcıda; sonra komut logu kontrolü.
