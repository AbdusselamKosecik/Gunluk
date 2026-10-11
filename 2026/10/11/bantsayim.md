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

### 4. Linux x64 paketi
- `bash paketle-linux.sh` → `dagitim/bantsayim-linux-x64.tar.gz` (~46 MB, tek dosya ELF, commit `4e0c9ee` içerir: 10 mm box barkodu, 2 günlük liste, hata barkodu). Kurulum: `tar xzf …; cd bantsayim-linux-x64; ./kur.sh` (kiosk için `kiosk-kur.sh`).

### 5. Order değişimi yalnız "YENİ ORDER" düğmesiyle
- **Neden:** kullanıcı: operatörler "beş yaşındaki çocuk gibi"; başka order okutmasınlar, order değişince box'lar kapansın, ekran temizlensin.
- **Ne yapıldı:** `UretimDeposu.OkutAsync` bandın tüm açık box'larını (1K+2K, UPDLOCK, WorkOrderNo ile) okur; biri başka order'daysa
  `BaskaOrder` reddi (eskiden box kendiliğinden kapanıp yeni order'a geçiyordu). `YeniOrderAsync`: açık box'ları tek transaction'da
  kapatır (dolu → günlük fiş; boş → InUse=0). Genel `TransactionAsync<T>` (1205/1222/51222 bir kez yeniden). Ekran: büyük
  "🔄 YENİ ORDER" → onay ("EVET, YENİ ORDER" / İptal) → kapanan box etiketleri basılır, kesim tablosu/hata/son okutmalar temizlenir.
- **Testler:** entegrasyon (canlı DB, rollback) `MODFEX_DB_TEST=1` → 10/10 (yeni: başka order reddi 1K/2K, yeni order kapatır+fiş, açık box yoksa boş);
  tüm suite 46 geçti.
- **Commit:** `f3841c4`
- **Açık:** 1320×768 ekran düzeni kontrolü; Ubuntu kiosk hatası (kullanıcıdan log bekleniyor).
