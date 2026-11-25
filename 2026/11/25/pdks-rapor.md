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

### 3. 5055 → 000376 ve fotoğraf düzeltmesi
- **Kod:** 5055 Mervat Rasheed Mohamed (id 3049) → 000376. Yedek `C:\Yedek\zkbiotime_kod_degisimi_20261125\zkbiotime_5055_oncesi.bak`. `kod_degistir.sql` (`-I`): kuru 1/1, 766 geçiş → COMMIT.
- **Fotoğraflar (9 kişi):** `C:\ZKBioTime1\auth_files\photo\<eski>.jpg` ve `auth_files\biophoto\<eski>.jpg` → `<yeni>.jpg` kopyalandı (18 dosya; eskiler yerinde bırakıldı). `personnel_employee.photo` = `photo/<yeni>.jpg` (9 satır). 5055'in fotoğrafı yok.
- **Cihaz komutları (her iki cihaz):** `DATA DELETE USERINFO PIN=5055`, 000376 USERINFO + avuç BIODATA (Type 8, Index 0–4; yüz şablonu yok), 9 kişi için `DATA UPDATE USERPIC`. Toplam 32 komut, hepsi return 0 (önceki -1100'ler giderildi).

### 4. DENDATA manuel giriş kontrolü (000040)
- **İstek:** Kullanıcı Den'e 000040 için 01/11/2026 07:40 (D=0, manuel) ve 17:40 (D=0, manuel) girdi; kayıt kontrolü.
- **Yöntem:** `\192.168.0.2\Dendata` altında son 3 saatte değişen dosyalar → `f01\2026\MODXX.MAS`, `ELTXX.MAS`, `GENXX.MAS`, `CFF\PYRXX.USR`. Kopyalar scratchpad `den\`.
- **Dosya yapısı (yeni öğrenilen):**
  - `ELTXX.MAS`: 243 B kayıt = 15 × 16 B giriş + 3 B. Giriş: `word dakika` + `byte D` (boş=FF) + ShortString[10] tarih `dd/mm/yyyy` + `char 'E'` + 1 B. Kayıt 9: `cc01 00 "01/11/2026" E` (460 dk = 07:40) ve `2404 00 "01/11/2026" E` (1060 dk = 17:40). Kayıt 5: başka birinin 01–05/11 girişleri. ELT kaydı ↔ personel bağı EMPXX'te bulunamadı.
  - `MODXX.MAS`: personel başına 9864 B (EMPXX sırasıyla), 12 × 822 B aylık blok. Kasım bloğu +113 ve +117 = toplam saat. 000040 (EMPXX idx 38, Abbas Tariq Nasr Abbas): `01 0a 00 00 00 0a` → **10 saat** (07:40–17:40). Kasımda saat değeri olan diğerleri: 000001 = 8, 000250 = 9.
- **Sonuç:** Giriş kaydedilmiş ve Kasım ayı hesabına 10 saat olarak yansımış.

### 5. 000040 Kasım kayıtlarını PDKS'den Den'e aktarma — ön inceleme (yazma yapılmadı)
- **İstek:** Den'deki deneme girişlerini silip 000040'ın Kasım günlük giriş/çıkışlarını BioTime'dan Den'e eklemek.
- **BioTime (salt okunur):** 000040'ın Kasımda 19 günü var (01–25/11, Cuma ve Cumartesi yok), günde 2 okutma (giriş ~08:20, çıkış ~17:45) → 38 giriş.
- **Den biçimi, düzeltilmiş yorum:** MODXX Kasım bloğu +113/+117 = ELTXX kayıt göstergesi (1 tabanlı; 000040 → 10 = ELT kayıt 9), saat değil. 000001 → 8, 000250 → 9 olan ELT kayıtları boş (silinmiş girişler). ELT kaydı en fazla 15 giriş tutuyor; 38 giriş için kayıt zinciri gerekiyor, ama zincir biçimi (+113 ilk / +117 son? sondaki 3 bayt?) henüz belli değil.
- **Karar:** Delphi bordro programının ikili dosyasına biçim bilinmeden yazılmadı. Kullanıcıdan Den arayüzünde 15'ten fazla giriş içeren bir deneme (ya da Den'in içe aktarma menüsünün biçimi) istendi.

### 6. Den ELTXX biçimi çözüldü + aktarım betiği (canlıya yazılmadı)
- **Deneme:** Kullanıcı Den'de 000040 için 01–10/11 arası giriş yaptı; önce/sonra karşılaştırıldı.
- **Biçim (kesin):**
  - `ELTXX.MAS` 243 B = **14 giriş × 16 B** + ShortString[10] sicil (@224) + int32 önceki (@235) + int32 sonraki (@239), 1 tabanlı kayıt no. Giriş: uint16 dakika, uint8 D (boş FF), ShortString[10] tarih, 'E', ' '. Den silinen girişi boşaltır (slot boş kalır), kaydı/zinciri silmez.
  - `MODXX.MAS` ay bloğu +113 ilk, +117 son ELT kaydı (000040 Kasım: 10 → 12).
  - `GENXX.MAS` int32[0] = sonraki boş ELT kayıt no (kayıt sayısı + 1).
- **Betik:** `X:\Yazilim\generic\pdks-rapor\den-aktarim\den_elt.py` (`goster`, `yaz ... --hepsini-temizle`). Zinciri yürür, gerekirse sona kayıt ekler, MODXX son ve GEN'i günceller.
- **Kuru çalıştırma (yerel kopya):** tüm girişler boşaltıldı; 000040 Kasım 38 giriş (BioTime, 19 gün) → zincir 10 → 12 → 13 (yeni), GEN 14. `goster` ile doğrulandı.
- **Canlıya yazılmadı:** Den açık (192.168.0.204 ELTXX.MAS'ı tutuyor, 192.168.0.179 ayman.hany, sunucuda RDP oturumu). Kapatılınca: yedek → yaz → kontrol.
- **Commit:** pdks-rapor (remote yok → push edilemedi).
