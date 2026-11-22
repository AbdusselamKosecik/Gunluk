# onaymerkezi — 2026-11-22

## Bağlam
Kullanıcı Kesimhane pastal onayının Telegram'dan gelmesini istedi (bkz. kesimhane günlüğü). Kesimhane masaüstü uygulaması olduğu için HTTP geri çağırma alamaz. Karar, Onay Merkezi tarafından aynı veritabanına yazılmalı.

## Yapılanlar

### 1. PastalSonucYazici (`9939c5e`)
- **Ne yapıldı:** `Servis/PastalSonucYazici.cs`, bir `IGeriCagirici` süsleyicisi.
  - Olay kapanınca önce `PastalSonucu.Coz` çalışır. Koşullar: tür kodu `pastal`, kaynakRef `PastalRevizyon:{id}`, durum Onaylandı ya da Reddedildi.
  - Sonra `UZM_PastalRevizyon` güncellenir: OnayDurum 1/2, OnayAt, OnayBy = NULL, OnayNotu "Telegram onay: Ahmet, Mehmet" ya da "Telegram ret: Ahmet — neden".
  - Not en fazla 100 karakter (UdtExpLong = nvarchar(100)).
  - Yalnız son ve bekleyen revizyon güncellenir (kesimhane `OnayVerAsync` ile aynı kural). Tablo yoksa hiçbir şey yapılmaz.
  - Zaman aşımı ve iptal revizyona dokunmaz.
  - Yazım hatası loglanır; ardından HTTP geri çağırma yine çalışır.
- **Dokunulan dosyalar:** `Program.cs` (IGeriCagirici = PastalSonucYazici(HttpGeriCagirici)).
- **Testler:** `PastalSonucYaziciTestleri`: çözümleme, retler, kısaltma, hata yutma; DB testi TransactionScope ile.
- **Sonuç:** 201/201 (3 canlı YZ testi atlandı).

## Açık kalanlar
- Sunucuya kurulum (kullanıcı onayıyla).
- Panel ayarları: `kesimhane` uygulaması ve `pastal` olay türü.
