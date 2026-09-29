# GaleriIndirici — 2026-09-29

## Bağlam
Önce `X:\Yazilim\manga` altında HakuNeko (manga-download/hakuneko, zip snapshot) build edilmeye
çalışıldı; sonra vazgeçilip tamamen silindi. Yerine, bir galeri URL'si verildiğinde tüm sayfaları
klasöre indiren ve okuyucu ekranı olan küçük bir C# WPF uygulaması yazıldı.
(Hedef sitenin adı bu public günlükte bilerek yazılmadı; ayrıntı projenin `README.md`'sinde.)

## Yapılanlar

### 1. HakuNeko denemesi (iptal, silindi)
- **Neden:** Hazır bir indirici kullanmak istendi.
- **Ne yapıldı:** `npm install` (çok yavaş ağ, ~30 dk), `build:web` başarılı; `build:app` Electron 8.3.4 zip
  indirmesi sürerken kullanıcı vazgeçti.
- **Öğrenilenler (tekrar denenirse):**
  - `src/app` postinstall: `discord-rpc` → `register-scheme` native modülü Visual Studio olmadan derlenmiyor.
    npm 11'de `--no-optional` çalışmıyor; `npm install --omit=optional --ignore-scripts` ile geçildi.
  - `fs-extra@latest` (11) Node ≥14.14 istiyor, Electron 8 Node 12 → `src/app` içinde `fs-extra@^9.1.0` pinlenmeli.
  - `build-web.js` git repo istiyor (stash + rev-parse); zip snapshot'ta `git init` + commit gerekli.
  - `build-app.js` Electron zip'ini yarım inerse bozuk bırakıyor → önce `curl -C - --retry` ile `redist/`e indir.
  - 7-Zip PATH'e eklenmeli (`/c/Program Files/7-Zip`).
- **Sonuç:** Klasör ve `%APPDATA%\hakuneko-dev` silindi.

### 2. GaleriIndirici (WPF, .NET 10)
- **Konum:** `X:\Yazilim\manga\GaleriIndirici` (yalnız yerel git, remote yok)
- **Yapı:**
  - `Services/GalleryScraper.cs` — URL'den galeri id'si (regex `/(a|g|...)/(\d+)`), `<h1>` başlık,
    galeri sayfasındaki `.../thumbnail/NNN.webp` küçük resimlerini `.../original/NNN.webp`'ye çevirir;
    bulunamazsa `/a/<id>/<n>` sayfalarını tek tek tarar.
  - `Services/GalleryDownloader.cs` — `Parallel.ForEachAsync` (4 paralel), 3 deneme, `.part` → move,
    var olan dosyayı atlar (devam ettirilebilir), `gallery.json` yazar. Klasör: `<kök>\<Başlık> [id]\001.webp`.
  - `Services/Library.cs` — kütüphane taraması, kapak, `ImageLoader` (WIC; WebP için Windows WebP uzantısı).
  - `Services/AppSettings.cs` — `%APPDATA%\GaleriIndirici\settings.json`, varsayılan kök `Resimler\GaleriIndirici`.
  - `MainWindow` — Menü (Dosya/Kütüphane/Yardım), İndir sekmesi (URL, ilerleme, log, iptal, Oku), Kütüphane sekmesi (kapak grid).
  - `ViewerWindow` — tek sayfa okuyucu: ←/→, tekerlek, tık, kaydırıcı, F sığdırma modu, F11 tam ekran, önbellek/ön yükleme.
- **Kritik bulgu:** Site HTML'i Cloudflare arkasında; .NET `HttpClient` header/TLS/ALPN ne yapılırsa yapılsın
  403 `cf-mitigated: challenge`. Windows `C:\Windows\System32\curl.exe` (Schannel) tarayıcı UA'sıyla 200 dönüyor.
  Çözüm: HTML için önce HttpClient, 403 gelirse `curl.exe`'ye düş. Görsel CDN'i HttpClient ile 200.
- **Komutlar:**
  ```bash
  dotnet new wpf -n GaleriIndirici -o src/GaleriIndirici -f net10.0
  dotnet build -c Release
  dotnet publish src/GaleriIndirici -c Release -r win-x64 --self-contained false -p:PublishSingleFile=true -o publish
  ```
- **Doğrulama:** Services kodunu kullanan geçici konsol harness'i ile gerçek bir galeri: 35/35 sayfa indi,
  35/35 WIC ile çözüldü, kütüphane 1 kayıt buldu. Exe açıldı, pencere yanıt veriyor. Test çıktısı silindi.
- **Commit:** `ba669eb` — Galeri İndirici: URL'den galeri indirme, kütüphane ve okuyucu (WPF .NET 10)

## Kararlar
- SkiaSharp yerine WIC: yavaş ağda NuGet indirmesi takıldı; Windows 11'de WebP codec zaten var.
- Framework-dependent single-file exe (self-contained runtime pack indirmesi yavaş ağda gereksiz).

## Açık kalanlar / sonraki adım
- Projenin remote'u yok → private GitHub repo açılıp push edilmeli (kullanıcı onayı bekleniyor).
- Cloudflare kuralı sıkılaşırsa curl de düşebilir → yedek plan WebView2 ile sayfa okuma.
