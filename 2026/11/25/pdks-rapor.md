# pdks-rapor — 2026-11-25

## Bağlam
Kullanıcı 9 kişinin eski→yeni kod listesini yapıştırdı (sol yeni Den kodu, sağ eski BioTime kodu), PDKS (ZKBio Time, 192.168.0.2, `zkbiotime`) güncellenmesi istendi.

## Yapılanlar

### 1. 9 kişinin kod değişimi
- **Eşleme:** 1550→000366, 4345→000367, 4485→000368, 4570→000369, 4810→000370, 5004→000371, 5234→000372, 5251→000373, 5415→000374.
- **Ön kontrol:** 9 eski kod `personnel_employee`'de mevcut (id 412, 488, 539, 583, 641, 757, 9236, 9253, 9426), yeni kodların hiçbiri kullanılmıyor, eski kodlu geçişlerin hepsi aynı kişiye ait (başka emp_id 0). En büyük 6 haneli kod 000375 (zaten var).
- **Yedek:** `C:\Yedek\zkbiotime_kod_degisimi_20261125\zkbiotime_once.bak` (COPY_ONLY, CHECKSUM, VERIFYONLY ok, 2,07 GB).
- **Betik:** `X:\Yazilim\generic\pdks-rapor\kod-degisimi\kod_degistir.sql` (değişmedi), yer tutucular PowerShell `.Replace` ile dolduruldu; WinRM `srv02.cred`.
  - **Dikkat:** `sqlcmd` varsayılan QUOTED_IDENTIFIER OFF → Msg 1934 (indeksli kolon). **`-I` şart.** İlk deneme her iki modda da hata verip geri alındı.
  ```powershell
  sqlcmd -S . -E -I -d zkbiotime -W -s "|" -b -i k.sql   # UYGULA=0 kuru, sonra 1
  ```
- **Sonuç:** kuru 9/9, 6487 geçiş + 6487 ep → COMMIT. Eski kodla kalan geçiş 0. `bio-cache` restart; bio-server/bio-cache Running.

## Açık kalanlar
- Cihazlar (Yuz1 192.168.0.30, Yuz2 192.168.0.29): BioTime yeni PIN'i gönderir, eski PIN cihazda kalır → cihaz temizleme + Sync Data to Device (15.11'den beri bekliyor).

### 2. Cihazlara gönderim (kullanıcı "tamam değiştir")
- **Yöntem:** `iclock_terminalcommand`'a BioTime'ın kendi komut biçimiyle kayıt (terminal 3042 Yuz1, 3043 Yuz2), kişi başına: `DATA DELETE USERINFO PIN=<eski>` → `DATA UPDATE USERINFO PIN=<yeni>\tName=<first_name>\tPri=0\tPasswd=\tCard=\tTZ=0000000000000000\tGrp=1\tVerify=-1` → `DATA UPDATE BIODATA Pin=..\tNo..\tIndex..\tType..\tMajorVer..\tMinorVer..\tTmp=zk_bio_data_%010d_%02d` (biodata.id, index; avuç Type=8 için Index 0–4) → `DATA UPDATE USERPIC ZK_PERSONNEL_PHOTO_PIN=<yeni>`.
  - Yer tutucu `zk_bio_data_...` gönderim anında `iclock/utils.pyc getCacheBioData` ile DB'deki BioData'dan çözülüyor (pyc string incelemesi) → elle komut eklemek güvenli.
- **Sonuç:** 82 komut (41/cihaz); DELETE/USERINFO/BIODATA 0 (başarılı), USERPIC 18 adet `-1100` (fotoğraf dosyası eski kod adıyla: `photo/1550.jpg` vb.).
- **Aynı anda:** `modasima` kullanıcısı (192.168.0.176) BioTime arayüzünden 17:43:20 ve 17:43:52'de (sunucu saati) iki cihaza **Tüm Verileri Temizle**, 17:44:14'te **Verileri Cihaza Senkronize Et** yaptı (base_adminlog). Tam senkron 17:45'te bitti: cihaz başına 356 USERINFO, 454 BIODATA, 11 FINGERTMP, 325 USERPIC — hepsi 0. 9 kişi yeni kodlarıyla 23'er komut (USERPIC yok). Eski kodlar temizlikle cihazdan gitti.
- Not: `yara` (192.168.0.180) aynı saatlerde arayüzden başka kişilerin kodlarını değiştiriyordu (ör. 5430→000292).
- **Açık:** 9 kişinin fotoğraf dosyası eski kod adında → cihazda kayıt fotoğrafı yok (yüz şablonu var, tanıma etkilenmez). İstenirse `photo/<yeni>.jpg` kopyası + `personnel_employee.photo` güncellemesi.
