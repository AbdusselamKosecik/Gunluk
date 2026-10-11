# bantsayim — 2026-10-11

## Bağlam
Kullanıcı (bant ekranı): banttaki box barkodlarını tekrar yazdırmak için bandın son 2 günlük barkodları görülsün; box etiketinde
barkod küçülsün, ürün detayına yer kalsın; hata barkodlarının yazdırılması eklensin (karar: Yönetim → Hata kodları, 45×20 2'li).
Çalışma alanında başka kaynaktan kalmış commit edilmemiş bir test vardı (`Box_etiketi_barkodu_kisa_urun_detayi_genis`, 13:14);
diğer modfex oturumu kendisinin olmadığını söyledi; isteğe birebir uyduğu için korunup temel alındı.

## Yapılanlar

### 1. Box etiketi: barkod küçük, ürün detayı geniş
- `BoxEtiketi.Zpl`: Code 128 yükseklik 20 → 10 mm; altındaki bloklar 11 mm yukarı; matris 59 → 48 mm'den başlar (34 mm alan).
- **Commit:** `62833cf`

### 2. Bant ekranı: son 2 gün box listesi + tekrar yazdır
- `UretimKurallari.SonGunler(simdi, gun)` (testli), `OkutmaViewModel.BoxListesi/BoxYazdir` → mevcut `UretimRaporlari.BoxlarAsync(…, Bant.UserId)`;
  Okutma ekranında "🖨 Son 2 gün" düğmesi, satırda Yazdır (kapalı box).
- **Commit:** `98ccd3f`

### 3. Hata barkodu yazdırma
- Ayarlar: ayrı küçük etiket yazıcısı `KucukYaziciIp/Port/Dpi` + `EtiketGenislik/Yukseklik/Ara/SolMm` (box yazıcısı aynen).
- `ZplEtiket` paketlemeden kopyalandı (üst küme). `HataEtiketi`: ad kalın/ortalı, Code 128 `HK`+kod, okunur metin; `~SD15 ^PR3 ^MNY`.
- Yönetim → Hata kodları: Adet + "Seçiliyi yazdır" / "Tümünü yazdır" (aktif kartlar).
- **Komutlar:** `dotnet test BantSayim.Tests` → 46 geçti, 15 atlandı; Desktop + Android derleme başarılı.
- **Commit:** `4e0c9ee`

## Açık kalanlar
- Ayarlar'a küçük yazıcı IP'si girilmeli (paketlemedeki ürün etiketi yazıcısı 192.168.0.251).
- Box etiketi ve hata barkodu gerçek baskıda kontrol edilmedi.
- Ortak/ farkları: bantsayim ZplEtiket/Ayarlar diğer repolardan ayrıştı (paketleme ile ZplEtiket aynı).
