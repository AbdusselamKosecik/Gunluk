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
