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

## Ek — tablosuz (15:40)
- Koli QR listesi `Erp_Box.SpecialCode = 'KLY'` + içerik Erp_BoxItem/Variant; basıldı = `Erp_Box.IsPrinted/PrintedAt/PrintedBy`
  (UZM_KoliListe kaldırıldı, kullanıcı isteği). Liste SQL'i canlıda salt okunur denendi (PK1 kolileriyle, çalışıyor).
- **Commit:** `c3bdb75`
- **Yama:** `dagitim/paketleme-yama-2026-11-10-koli-qr.zip` (1,6 MB: Paketleme.dll, Paketleme.Desktop.dll/.exe); baz
  `dagitim/paketleme-win-x64` artık bu sürüm. 02.11b yaması kurulu makineye uygulanır.

## Ek — etiket üst boşluğu (15:50)
- **Neden (kullanıcı):** "etiketlerde (paket) yazdırırken yukarıdan biraz boşluk bırakabilir misin, 3 mm gibi".
- **Ne yapıldı:** `ZplEtiket.UstKayma(mm)` → `^LT` (±120 nokta). `Ayarlar.EtiketUstMm` (varsayılan **3**) ürün etiketi yazıcısındaki
  ürün/paket, hata barkodu ve koli QR (2'li) etiketlerine; `KoliEtiketUstMm` (varsayılan 0) 10×10 koli etiketi ve 100×100 QR'a.
  Ayarlar ekranında "Üst boşluk (mm)" ve "Koli etiketi üst boşluk (mm)" (−5…15). Etiketin tamamı kayar; 20 mm etikette alt satır
  (barkod numarası / MADE IN EGYPT ~18,6 mm) 3 mm ile kenara yaklaşır — gerçek yazıcıda bakılacak.
- **Doğrulama:** 173 test geçti (3 yeni). Gerçek yazıcıda basılmadı.
- **Commit:** `20b61ad`
- **Yama:** `dagitim/paketleme-yama-2026-11-10-koli-qr.zip` yeniden üretildi (1,7 MB; Koli QR + üst boşluk; 02.11b üstüne).
- Not: Ortak/ (ZplEtiket, Ayarlar) yalnız paketlemede değişti; diğer uygulamaların Ortak kopyalarına taşınmadı.

## Ek (17:35) — Koli QR: sevk edilmeyenleri tekrar yazdır
- **Neden:** kullanıcı "sevk edilmeyenleri tekrar yazdır diyebilir misin paketlemede".
- **Ne yapıldı:** Sevk bilgisi yeni alan olmadan `Erp_Box.InventoryReceiptId` (sevkiyatmobil irsaliyeye okuttuğunda dolar).
  `KoliQrEtiketi.ListeAsync(..., yalnizSevkEdilmemis)` + `KoliQrKaydi.SevkEdildi`; ekranda "Yalnız sevk edilmemişler"
  onay kutusu (varsayılan açık), 🚚 sütunu, "Sevk edilmeyenleri tekrar yazdır" düğmesi (basılmamış süzgecini kapatır,
  sevk edilmemişleri listeler, hepsini seçer; basım yine Yazdır → onay ile).
- **Dosyalar:** `Paketleme/Ekranlar/Veri/KoliQrEtiketi.cs`, `KoliQrViewModel.cs`, `KoliQrView.axaml`, `UygulamaMetinleri.cs`.
- **Doğrulama:** `dotnet test Paketleme.Tests` 173 geçti. Yayım + farklar.py: değişen Paketleme.dll, Paketleme.Desktop.dll/.exe.
- **Paket:** `dagitim/paketleme-yama-2026-11-10-koli-qr-b.zip` (1,7 MB; öncekinin yerine, 02.11b üstüne). Taban `dagitim/paketleme-win-x64` güncellendi, uygulama açıldı.
