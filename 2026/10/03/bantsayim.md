# bantsayim — 2026-10-03

## Bağlam
Zebra 10×10 box etiketi (01.10, `9aefb51`) gerçek yazıcıda basıldı. Kullanıcı iki sorun bildirdi:
"2ND QUALITY" rozete sığmıyor ve üst üste biniyor; matristeki yazılar büyük.

## Yapılanlar

### 1. Kalite rozeti iki satır, matris yazıları küçük
- **Neden:** Yazıcının `^A0` fontu, BinaryKits önizlemesinden daha geniş basıyor. `^FB` ile 1 satıra sığmayan metin
  aynı satıra üst üste basılıyor.
- **Ne yapıldı:**
  - `BoxEtiketi.Zpl` içinde rozet 33×13 mm dolu kutu olarak kaldı. Yazı iki satıra bölündü: "2ND" (5 mm, y=37) ve "QUALITY" (4,5 mm, y=42,5), ikisi de `^FR`.
  - Matris yazı yüksekliği `clamp(satırH·0,62; 2,2; 3,8)` iken `clamp(satırH·0,5; 2; 3)` mm yapıldı.
- **Dokunulan dosyalar:** `BantSayim/Ekranlar/Veri/BoxEtiketi.cs`, `BantSayim.Tests/ZplTestleri.cs`
  (testte `^FD2ND^FS` ve `^FDQUALITY^FS` aranıyor).
- **Sonuç / doğrulama:** 53/53 test geçti. Scratchpad `zplonizle` ile PNG önizleme kontrol edildi.
- **Bağlantı:** Evden VPN ile bağlanıldı. `ayarlar.json` içinde Sunucu `100.119.104.122` yapıldı (192.168.0.2 kapalıydı).
  Yazıcıya (192.168.0.199) evden erişilemedi, test basımı yapılmadı.
- **Commit:** `3efa37e` — Box etiketi: 2ND QUALITY iki satir, matris yazilari kucuk

## Açık kalanlar / sonraki adım
- Firmada gerçek basımla kontrol edilecek. Yazıcı yine geniş basarsa `^A0N,h,w` içinde genişlik (w) daraltılacak.
- Etiket basımına otomatik tekrar deneme eklenmesi (SQL ve yazıcı bağlantısı ilk denemede düşüyor) kullanıcıya soruldu, cevap bekleniyor.
