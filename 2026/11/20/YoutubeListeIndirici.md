# YoutubeListeIndirici — 2026-11-20

## Bağlam
Sıfırdan başlandı. Hedef: verilen YouTube oynatma listesinin tüm videolarını, liste adıyla açılan klasöre indiren bir uygulama.
Repo: https://github.com/AbdusselamKosecik/YoutubeListeIndirici (private) — yerel: `X:\Yazilim\YoutubeListeIndirici`

## Yapılanlar

### 1. İndirici uygulaması (GUI + CLI)
- **Neden:** Kullanıcı liste linki verip videoları liste adına göre klasörlenmiş indirmek istedi.
- **Ne yapıldı:** Python + yt-dlp + ffmpeg. Tek dosya `liste_indirici.py`:
  - `outtmpl = <hedef>/%(playlist_title)s/%(playlist_index)03d - %(title)s.%(ext)s` → klasör adı = liste adı.
  - `ignoreerrors` (silinmiş/özel video listeyi durdurmasın), `windowsfilenames`, `download_archive=.indirilenler.txt` (tekrar çalıştırınca sadece yeniler iner).
  - Video: `bestvideo[height<=K]+bestaudio`, `merge_output_format=mp4`. Ses: `FFmpegExtractAudio` mp3 192k.
  - tkinter arayüz (URL, klasör, kalite, MP3 seçeneği, log; indirme ayrı thread, log queue ile UI'ye).
  - Argüman verilirse CLI: `python liste_indirici.py <url> [-o klasör] [--mp3] [--kalite 1080]`.
  - Varsayılan kayıt yeri `~/Videos/YouTube Listeleri`.
- **Dokunulan dosyalar:** `liste_indirici.py`, `requirements.txt`, `baslat.bat`, `README.md`, `.gitignore`
- **Komutlar:**
  ```bash
  python -m pip install -U yt-dlp        # 2026.10.26 kuruldu
  gh repo create YoutubeListeIndirici --private --source . --push
  ```
- **Sonuç / doğrulama:** `@Google/videos` ile 1 öğe mp3 indirildi → `Google - Videos/001 - ....` klasörü oluştu.
- **Commit:** `b9d79ef` — YouTube oynatma listesi indirici

### 2. watch?v=..&list=.. linklerinin desteklenmesi
- **Neden:** Kullanıcının örnek linki `watch?v=THeLVhU53ow&list=PLrAMR0by1bVCQ4C8YBgadCZqWePNGIB_K` biçimindeydi; tek video yerine liste insin diye.
- **Ne yapıldı:** `liste_url()` — `list` parametresini alıp `https://www.youtube.com/playlist?list=...` üretir.
- **Sonuç / doğrulama:** Liste adı "Son", 58 video; 360p ile ilk video `Son/001 - Jess Glynne - ....mp4` olarak birleşik indi.
- **Commit:** `fea7e49` — "watch?v=..&list=.. linklerini saf liste linkine çevir"

### 3. Aynı adlı listeler çakışmasın
- **Neden:** Kullanıcının 2. listesi (`PLrAMR0by1bVDX3A8kmYZfrIM9OQCoGVut`) de "Son" adlı; ikisi aynı klasöre karışıp numaralar çakışacaktı.
- **Ne yapıldı:** `liste_klasoru()` — klasör adını kod seçiyor (`sanitize_filename`), içine `.liste_id` yazıyor. Aynı adlı klasör başka listeye aitse `Ad (liste_id)` kullanılıyor. Liste bilgisi önce `extract_flat` ile alınıyor. `main()` içinde `sys.stdout.reconfigure(utf-8)` (cp1252 konsolda `⧸` vb. karakterler çöküyordu).
- **Sonuç / doğrulama:** Birim test: `Son`, `Son (PLB)`, tekrar çağrıda aynı klasörler döndü. 2. liste 360p tam indirildi: `Son/001 - Alanis Morissette - Ironic...mp4`, `Son/002 - Gaye Su Akyol - ...mp4`.
- **Commit:** `6fdfb6e` — Aynı adlı listeler ayrı klasöre (.liste_id işareti), konsol UTF-8

## Kararlar
- Not: PowerShell 5.1 `Get-Content` BOM'suz UTF-8'i yanlış okur → günlük dosyalarını Python/Bash ile düzenle.
- yt-dlp seçildi (bakımı aktif, YouTube değişikliklerine hızlı uyum). Çalışmazsa önce `python -m pip install -U yt-dlp`.
- GUI için tkinter (ek bağımlılık yok).

## Açık kalanlar / sonraki adım
- Log'da video+ses akışları için iki kez "indirildi" yazıyor (kozmetik).
- İstenirse .exe paketleme (PyInstaller).

