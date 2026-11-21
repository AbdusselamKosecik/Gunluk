# ik — 2026-11-21

## Bağlam
Kullanıcı: İK uygulamasında personel listesi grid olarak gelsin, hücre düzenleme + seçili satırlara toplu atama, tek "Kaydet". Alanlar: temel kimlik, iş bilgisi, iletişim, resmi/ücret. Kaynak ve kayıt yeri: "komple DENDATA'dan" (eski Mısır bordro programı, Delphi, ikili Pascal kayıt dosyaları).

## Yapılanlar
### 1. Veri kaynağı incelemesi
- Sentez `Erp_Employee` (şirket 2: 373 kişi; çoğunda yalnız kod/ad/soyad/istasyon dolu) — kullanıcı bunu değil DENDATA'yı istedi.
- DENDATA kopyası `C:\Users\abdus\OneDrive\Masaüstü\1260920182832-Desktop\12r` (eski not `12r` diyordu, klasör taşınmış). `f01\2026\EMPXX.MAS` 0 bayt — personel yok; başka dolu kopya bulunamadı.
- Program veriyi göreli yoldan buluyor (`..\CFF\TNMXX.MAS`, PEELIB.exe: EMPXX.MAS / EMPXX.NDX).

### 2. Kayıt yapısını çözmek için deneme kopyası
- `C:\DENDATA-ornek\12r` (kopya) + `C:\DENDATA-ornek\GIRILECEK-DEGERLER.txt`: kullanıcı 3 deneme personelini ayırt edici değerlerle girecek; sonra EMPXX.MAS / .NDX baytları değerlerle eşlenip alan yerleşimi çıkarılacak.

## Açık kalanlar / sonraki adım
- Kullanıcı deneme kayıtlarını girince: kayıt boyu, alan offset/tipleri (ShortString, tarih, Real/Currency), NDX biçimi → okuma/yazma katmanı + testler (önce kopya üzerinde), sonra grid ekranı.
- Yazma: program kapalıyken + önce yedek; NDX tutarlılığı korunmalı.
