# sentezservis — 2026-11-09

## Bağlam
Dün yazılan `TrendyolFaturaKontrol.exe`'de bölünmüş siparişler (birden çok etkin paket) "elle bakılmalı" diye atlanıyordu. Kullanıcı şunu bildirdi: "her siparişin faturası CRS'de farklı". Yani bölünmüş siparişte her paket için Sentez'de ayrı bir fatura (ayrı ETTN) kesiliyor.

## Yapılanlar

### 1. Veri keşfi (yalnız SELECT)
- **Neden:** Faturanın hangi pakete ait olduğunu bulmak.
- **Yöntem:** Scratchpad'deki `q.ps1` betiği. Bağlantı cümlesini servisin appsettings dosyasındaki salt okur `ErpBaglantiCumlesi` ayarından çalışma anında okuyor, ekrana yazmıyor. SqlClient + DataTable ile çalışıyor.
- **Bulgular:**
  - Aynı `MarketPlaceOrderNo` ile birden çok 121 fişi var ve her birinin ETTN'si farklı. Bölünme şirketler arasında da oluyor; örneğin sipariş 11789921627'nin bir paketi şirket 03'ten, öbürü 04'ten faturalanmış.
  - Fişi pakete bağlayan alan `Erp_InventoryReceipt.UD_CargoBarcode`. Bu, Trendyol paketinin `cargoTrackingNumber` alanına eşit (`UD_KargoTakipNumarası` da aynı değeri tutuyor).
  - Ekim'den bu yana yaklaşık 15.900 paket var. Bunların 83'ünde aynı pakete birden çok fatura kesilmiş. Barkodsuz fiş yok.

### 2. Kod
- `TrendyolPaketi` kaydına `KargoTakipNo` eklendi; `cargoTrackingNumber` alanı sayı da metin de olsa okunuyor.
- `PaketKarari.Ver(paketler, kargoBarkodu, ayniPaketFisSayisi)` kuralları:
  - Aynı pakette birden çok fatura varsa: Atla. Trendyol paket başına tek dosya kabul ediyor.
  - Barkodun paketi bulunduysa: paket iptalse Atla, faturalıysa ZatenVar, faturasızsa o pakete Yükle.
  - Barkod hiçbir pakete uymuyorsa: tek paket olsa bile Atla.
  - Barkod boşsa: eski kural uygulanıyor (tek etkin paket varsa yükle, yoksa atla).
- `FaturaAdayDeposu` aday sorgusu:
  - İlk denenen bağlı alt sorgu (`COUNT ... WHERE MarketPlaceOrderNo = ...`) index olmadığı için **120 sn zaman aşımına** düştü.
  - Sorgu CTE ile yeniden yazıldı. `COUNT(*) OVER (PARTITION BY sipariş, barkod)` sayımı `ReceiptDate >= başlangıç - 15 gün` penceresiyle sınırlandı. Sorgu artık saniyeler içinde dönüyor.
- 6 yeni test eklendi; toplam 777 test geçti.
- README güncellendi.
- **Dokunulan dosyalar:**
  - `src/SentezServis.Core/Fatura/TrendyolPaketKarari.cs`
  - `src/SentezServis.Core/Pazaryerleri/Saglayicilar/TrendyolSaglayici.cs`
  - `src/SentezServis.TrendyolFatura/FaturaAdayDeposu.cs`
  - `src/SentezServis.TrendyolFatura/TrendyolFaturaKontrolcusu.cs`
  - `src/SentezServis.TrendyolFatura/README.md`
  - `tests/SentezServis.Core.Tests/TrendyolPaketKarariTestleri.cs`

### 3. Canlı kuru deneme
- **Ayar:** `BaslangicTarihi = 2026-11-06`, `TurBasinaAzami = 1500`. Komut: `--kuru --bir-kez`. Deneme bitince test ayarları geri alındı.
- **Sonuç:** 1500 fiş işlendi (852 sn); 01'den 4, 03'ten 37, geri kalanı 04'ten.
  - 1465 fişte barkod Trendyol paketine uydu ve paket faturalıydı ("zaten var").
  - 21 fişin paketi Trendyol'da `Cancelled` olduğu için atlandı.
  - 14 fiş (7 paket) "aynı pakete 2 fatura" olduğu için atlandı.
  - Barkod uyuşmazlığı **0**, hata 0.
- Bölünmüş sipariş 11789921627'de şirket 04'ün fişi kendi paketine (4310582421) eşlendi.

### 4. Paket
- `TrendyolFaturaKontrol-2026-11-09.zip` repo kökünde (exe, README, örnek ayar dosyası, sql). Commit edilmedi.
- **Komut:** `dotnet publish src/SentezServis.TrendyolFatura -c Release -o yayin-trendyol-fatura`; ardından README, ayar örneği ve sql/ kopyalanıp Compress-Archive ile sıkıştırıldı.
- **Commit:** `c043caf` — Trendyol fatura: bolunmus sipariste fis pakete kargo barkoduyla eslenir

## Kararlar
- Fiş pakete sipariş numarasıyla değil, kargo barkoduyla bağlanıyor. Barkod uymazsa yanlış pakete yüklemek yerine atlanıyor.
- Aynı pakete iki fatura kesildiyse fiş atlanıyor; hangisinin yükleneceğine elle karar verilecek.

## Açık kalanlar / sonraki adım
- Kullanıcı SSMS'te `UZM_E_ReceiptCheckOK.sql` dosyasını çalıştıracak ve yazma yetkili `appsettings.json` hazırlayacak.
- İptal edilen paketlerin fişleri ve aynı pakete iki fatura kesilmiş fişler hiç işaretlenmiyor; 30 dakikada bir yeniden loglanıyorlar. İstenirse iptal paket "işaretle" ya da "ayrı kolon" olarak ele alınabilir.
- Trendyol `orders` ucundan `v2/orders` ucuna geçiş.

---

## Tur 2 — Trendyol fatura gönderimi ekranı (otomatik değil)

### Bağlam
Kullanıcı otomatik yüklemeden çekindi. İstekleri:
- sentezservis'te bir ekran: gönderilmemişleri bulsun, CRS'ten sorgulasın.
- Seçilenleri / 10 adet / 100 adet / tamamını gönder düğmeleri.
- "Otomatik servis yapmayalım."
- "Servis şimdilik boş kalsın, çalıştırmak istediğimde cron değerini vereyim." Yani bir iş tanımlanacak ama zamanlaması boş olacak.

### 1. Tasarım kararları
- **"Gönderildi" bilgisinin kaynağı Trendyol:** paketin `invoiceLink` alanı dolu mu diye bakılıyor. ERP'ye hiç yazılmıyor, `UZM_E_ReceiptCheckOK` kolonuna ekran için gerek yok. Host'un ERP bağlantısı salt okur kalıyor.
- **Ortak çekirdek:** `Core/Fatura/TrendyolFaturaGonderici.cs`.
  - `ListeleAsync(bas, bit)`: Sentez fişleri → her sipariş için Trendyol'a tek tek sorgu (5 paralel istek, hesabın saniyede 5 istek sınırlayıcısı ayrıca uygulanıyor) → `PaketKarari` → yalnız yüklenmesi gereken fişler için CRS toplu sorgusu → `Degerlendir`.
  - `GonderAsync(fisIdleri, kuru)`: her fiş için Trendyol paketi ve CRS durumu taze sorgulanıyor, sonra PDF yükleniyor. Bir kilit (semaphore) iki kişinin aynı anda göndermesini engelliyor. Sınır: istek başına en çok 50 fiş.
  - `Degerlendir`: saf fonksiyon. Sonuçlar: gonderilebilir / gonderildi / crsBekliyor / sureDolmadi / elleBakilmali / crsYok / hata.
  - Önbellek: Trendyol'da faturası görülen fişler süreç boyunca bellekte tutuluyor. Bir günün ilk listelenmesi ~5 dk sürüyor (1.194 fiş), ikincisi ~5 sn.
- **Denenip bırakılan yol: toplu Trendyol listesi** (`startDate`/`endDate`).
  - Trendyol tek sorguda en çok **10.000** paket döndürüyor; değişiklik tarihine göre sorguda sonuç tam 10.000'de kesildi.
  - Fatura siparişten günler sonra kesildiği için pencere bunu aşıyor: 1.334 siparişin yalnız 283'ü listedeydi.
  - Oluşturma tarihine göre 2 günlük sorgu 65 sn sürdü.
- **İş `trendyol-fatura-gonder`:** `DefaultCron = null`. Parametreleri: `gun` (geriye kaç gün, 0 = bugün), `azami`, `deneme`. Değerler: `MaxAttempts = 1`, `Unsafe`, `SingleInstance`.

### 2. Dokunulan dosyalar
- Core:
  - `Fatura/TrendyolFaturaGonderici.cs` (yeni)
  - `Fatura/TrendyolFaturaGonderJob.cs` (yeni)
  - `Modeller.cs`: denetim eylemi `trendyol-fatura-gonderimi` eklendi.
  - `TrendyolSaglayici.cs`: paket okuma `PaketleriOku` adıyla ayrıldı.
- Host:
  - `Api/TrendyolFaturaUclari.cs` (yeni).
    - `GET /api/trendyol-fatura/liste`: giriş yapan herkese açık.
    - `POST /api/trendyol-fatura/gonder`: müdahale yetkisi ve CSRF istiyor, her istek denetime yazılıyor.
  - `Program.cs`: servis, iş ve uç kayıtları eklendi.
- Web:
  - `api/trendyolFatura.ts`
  - `pages/TrendyolFaturaSayfasi.tsx` ve `.test.tsx`
  - `App.tsx` (`/trendyol-fatura` rotası)
  - `Layout.tsx` (menü: Operasyon → "Trendyol fatura gönderimi")
  - `api/index.ts`
- Ekran:
  - Filtreler: tarih aralığı (en çok 7 gün), durum süzgeci (varsayılan "Trendyol'da olmayanlar").
  - Düğmeler: Seçilenleri / İlk 10'u / İlk 100'ü / Tamamını gönder. Gönderim 10'arlı öbeklerle yapılıyor; Durdur düğmesi ve Deneme kutusu var.
  - Her gönderimden önce onay satırı çıkıyor. Satır bazında sonuç gösteriliyor.
- Testler:
  - Core: `TrendyolFaturaDegerlendirmeTestleri` (12 test). Toplam 789 test geçti.
  - Web: 5 yeni test. Toplam 95 test geçti. oxlint temiz.

### 3. Canlı doğrulama (salt okur, scratchpad'deki `deneme-liste` programı)
- Host bilerek başlatılmadı: zamanlayıcı canlı işleri tetikleyebilirdi. Bunun yerine Core servisi, Host'un appsettings dosyasıyla doğrudan çağrıldı.
- 08.11 sonucu:
  - 1.194 fiş: 1.171 Trendyol'da zaten faturalı, 23 elle bakılmalı (iptal edilmiş paket, aynı pakete iki fatura).
  - Gönderilebilir fiş yok; dün "faturası yok" görünen fişler bu arada yüklenmiş.
- `GonderAsync` deneme modunda:
  - 1271643 → zatenVar (barkod eşleşti).
  - 1230415 → atlandı (aynı pakete 2 fatura).
  - Olmayan kimlik → hata.

### 4. Paket
- Komut: `deploy\yayinla.ps1` → `yayin\`. İçinden `appsettings.json` çıkarılıp `SentezServis-2026-11-09-trendyol-fatura.zip` oluşturuldu (~81 MB). Zip commit edilmedi.
- **Commit:** `bf2cd0e` — Trendyol fatura gonderimi ekrani + zamanlamasiz is

### Açık kalanlar
- Sunucuya kurulum kullanıcıda; kurulum sırasında mevcut appsettings korunmalı.
- Gerçek bir yükleme henüz hiç yapılmadı. İlk gönderimin "Deneme" kutusu işaretliyken, sonra 1–2 fişle yapılması önerildi.
- Konsol uygulaması `TrendyolFaturaKontrol` repoda duruyor ama artık önerilmiyor. Ekran ve iş onun yerini aldı.
- İş için cron değeri kullanıcı istediğinde verilecek.
