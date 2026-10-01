# GaleriIndirici — 2026-10-01

## Bağlam
Uygulama yalnızca myhentaigallery.com'u destekliyordu (ilk commit `ba669eb`). Hedef: nhentai.net
galerilerini (örn. `https://nhentai.net/g/655528`) de indirebilmek.

## Yapılanlar

### 1. nhentai.net desteği
- **Neden:** Kullanıcı nhentai galerilerini de aynı uygulamayla indirmek istedi.
- **Araştırma:**
  - Eski `https://nhentai.net/api/gallery/<id>` → 403 + "Use new API https://nhentai.net/api/v2/docs".
  - `https://nhentai.net/api/v2/galleries/<id>` anahtarsız 200 dönüyor (curl ve .NET HttpClient ikisi de).
    JSON: `id`, `media_id`, `title{english,japanese,pretty}`, `num_pages`,
    `pages[]{number, path:"galleries/<media_id>/<n>.webp|.jpg", width, height, thumbnail}`.
  - `https://nhentai.net/api/v2/cdn` → `image_servers: [i1..i4.nhentai.net]`.
  - Görseller `https://iN.nhentai.net/<path>`; mevcut UA + myhentaigallery Referer ile 200.
- **Ne yapıldı:**
  - `GalleryScraper.TryParseId`: `nhentai\.net/g/(\d+)` tanınır, kimlik `nh<id>` (klasör adı
    `<Başlık> [nh655528]` → myhentaigallery kimlikleriyle çakışmaz).
  - `GetNhentaiGalleryAsync`: API JSON'u `System.Text.Json` ile ayrıştırılır; başlık
    english → pretty → japanese; sayfalar `number`'a göre sıralanıp `servers[number % n]` ile
    sunuculara dağıtılır. `/cdn` alınamazsa `https://i1.nhentai.net`'e düşülür.
  - JSON da mevcut `GetHtmlAsync` üzerinden çekilir (403 olursa curl.exe fallback'i aynen geçerli).
  - `ExampleUrls` sabiti; MainWindow hata mesajı ve URL kutusu tooltip'i iki siteyi gösterir.
  - README'ye teknik not eklendi.
- **Dokunulan dosyalar:** `src/GaleriIndirici/Services/GalleryScraper.cs`, `src/GaleriIndirici/MainWindow.xaml`,
  `src/GaleriIndirici/MainWindow.xaml.cs`, `README.md`
- **Komutlar:**
  ```bash
  curl.exe -s -A "GaleriIndirici/1.0" https://nhentai.net/api/v2/galleries/655528
  curl.exe -s -A "GaleriIndirici/1.0" https://nhentai.net/api/v2/cdn
  dotnet build src/GaleriIndirici
  # scratchpad'de GalleryScraper.cs'i Compile Include eden net10.0 konsol projesiyle uçtan uca test
  ```
- **Sonuç / doğrulama:** Build 0 uyarı/0 hata. Test: `nh655528 | [GSUS] Oshi No Ko BEHIND THE STAGE #2 [English] | 160 sayfa`;
  1/2/3/160. sayfalar i2/i3/i4/i1 üzerinden HTTP 200. myhentaigallery URL ayrıştırması değişmedi.
- **Commit:** `1075c61` — nhentai.net desteği: v2 JSON API ile galeri okuma

### 2. Çoklu adres girişi (çok satırlı adres kutusu)
- **Neden:** Kullanıcı tek seferde birden fazla galeri adresi girmek istedi.
- **Ne yapıldı:**
  - `MainWindow.xaml`: `UrlBox` → `AcceptsReturn="True"`, yükseklik 110, kaydırma çubukları; butonlar
    (İndir/İptal/Oku) sağda dikey `StackPanel`'e alındı. `IsDefault` kaldırıldı (Enter artık satır sonu).
  - `MainWindow.xaml.cs` `Download_Click`: metin satır sonu/boşluk/tab ile bölünür, tekrarlar atılır
    (OrdinalIgnoreCase), `TryParseId` ile geçerli/geçersiz ayrılır. Geçerliler sırayla indirilir,
    ilerleme metnine `[i/n]` öneki. Tek galerinin hatası diğerlerini durdurmaz (loglanır); İptal kalanları durdurur.
  - Bittiğinde geçersiz + başarısız + iptal edilen adresler kutuda bırakılır (tekrar denenebilir).
    Tek adres girildiyse hata yine MessageBox ile gösterilir (eski davranış).
  - Kısayol: Ctrl+Enter = indir (`UrlBox_KeyDown`), Kısayollar penceresi ve README güncellendi.
- **Dokunulan dosyalar:** `src/GaleriIndirici/MainWindow.xaml`, `src/GaleriIndirici/MainWindow.xaml.cs`, `README.md`
- **Komutlar:**
  ```bash
  dotnet build src/GaleriIndirici
  ```
- **Sonuç / doğrulama:** Build 0 uyarı/0 hata. Arayüz elle test edilmedi.
- **Commit:** `e5db6fc` — Çoklu adres: adres kutusu çok satırlı, galeriler sırayla indirilir

## Kararlar
- HTML kazıma yerine resmi v2 JSON API (daha kararlı, Cloudflare'e daha az takılıyor).
- nhentai kimliğine `nh` öneki (klasör çakışması önlemi).
- Çoklu adreste indirme paralel değil sıralı (siteye yük/ban riski, ilerleme göstergesi tek).
- Ayrı `ISiteScraper` soyutlamasına gidilmedi; iki site için `GalleryScraper` içinde dallanma yeterli.

## Açık kalanlar / sonraki adım
- **Projenin git remote'u yok → push yapılamadı** (`1075c61`, `e5db6fc` sadece yerelde). GitHub'da repo açılıp `git remote add origin ... && git push -u origin main` gerekiyor.
- API ileride anahtar isterse `Authorization: Key <API_KEY>` başlığı eklenmeli (ayarlara alan).
