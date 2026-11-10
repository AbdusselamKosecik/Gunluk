# paketleme — 2026-11-10

## Bağlam
SentezServis "Koli listesi" (hazır barkodlu koliler; bkz. 2026/11/10/sentezservis.md) için QR etiketi paketlemeden basılacak
(kullanıcı: "Paketleme uygulamasında görünecek, sadece yazıcı seçip ölçü seçmemiz yeterli", "ürün etiketi gibi yazdıracağız").

## Yapılanlar

### 1. "Koli QR" sekmesi
- **Ne yapıldı:** Ana sayfaya 4. sekme. Liste `UZM_KoliListe` + `Erp_Box` (arama, yalnız basılmamışlar, en çok 3000).
  Yazıcı seçimi (ürün etiketi / koli yazıcısı, dpi yazıcıya göre), ölçü (Ayarlar'daki ürün etiketi ölçüsü 2'li / 100×100);
  seçimler `ayarlar.json`'da `KoliQrKoliYazicisi`, `KoliQrOlcu`. Koli başına 1 etiket; basılınca `EtiketBasimSayisi++`, `SonEtiketAt`.
  45×20: solda 17 mm QR (`ZplEtiket.Qr`), sağda barkod numarası (kalın, sığmazsa küçülür), model, renk, "S-M:6 L-XL:6 = 12".
  Tablo yoksa uyarı (sentezservis db/sentezcore/koli-liste.sql).
- **Dokunulan dosyalar:** `Paketleme/Ekranlar/Veri/KoliQrEtiketi.cs`, `Ekranlar/KoliQrViewModel.cs`, `KoliQrView.axaml(.cs)`,
  `AnaSayfaView(Model)`, `UygulamaMetinleri.cs` (TR/EN/AR), `Ortak/Veri/Ayarlar.cs`, `Paketleme.Tests/KoliQrEtiketiTestleri.cs`.
- **Doğrulama:** `dotnet test Paketleme.Tests` → 170 geçti, 57 atlandı (DB). Desktop derlendi ve açıldı. Gerçek yazıcıda basılmadı.
- **Commit:** `34b144f` — Koli QR sekmesi

## Not
- Kullanıcı tarayıcıda açık kalan **mock** SentezServis sayfasını (localhost:5299, VITE_MOCK=1, sahte "fiş 00000123") gerçek sandı;
  sekme kapatıldı, sunucu durduruldu. Canlıda koli/fiş yok: `UZM_KoliListe` tablosu yok, web yaması kurulmadı.

## Açık kalanlar
- Canlı: koli-liste.sql (kullanıcı), SentezServis yaması, masaüstündeki 2277.xlsx (338 koli) / 2278.xlsx (432 koli) yüklenmesi,
  sonra QR baskısı. Paketleme yaması çıkarılmadı.
