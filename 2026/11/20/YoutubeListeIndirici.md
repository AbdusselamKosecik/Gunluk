# YoutubeListeIndirici â€” 2026-11-20

## BaÄŸlam
SÄ±fÄ±rdan baÅŸlandÄ±. Hedef: verilen YouTube oynatma listesinin tÃ¼m videolarÄ±nÄ±, liste adÄ±yla aÃ§Ä±lan klasÃ¶re indiren bir uygulama.
Repo: https://github.com/AbdusselamKosecik/YoutubeListeIndirici (private) â€” yerel: `X:\Yazilim\YoutubeListeIndirici`

## YapÄ±lanlar

### 1. Ä°ndirici uygulamasÄ± (GUI + CLI)
- **Neden:** KullanÄ±cÄ± liste linki verip videolarÄ± liste adÄ±na gÃ¶re klasÃ¶rlenmiÅŸ indirmek istedi.
- **Ne yapÄ±ldÄ±:** Python + yt-dlp + ffmpeg. Tek dosya `liste_indirici.py`:
  - `outtmpl = <hedef>/%(playlist_title)s/%(playlist_index)03d - %(title)s.%(ext)s` â†’ klasÃ¶r adÄ± = liste adÄ±.
  - `ignoreerrors` (silinmiÅŸ/Ã¶zel video listeyi durdurmasÄ±n), `windowsfilenames`, `download_archive=.indirilenler.txt` (tekrar Ã§alÄ±ÅŸtÄ±rÄ±nca sadece yeniler iner).
  - Video: `bestvideo[height<=K]+bestaudio`, `merge_output_format=mp4`. Ses: `FFmpegExtractAudio` mp3 192k.
  - tkinter arayÃ¼z (URL, klasÃ¶r, kalite, MP3 seÃ§eneÄŸi, log; indirme ayrÄ± thread, log queue ile UI'ye).
  - ArgÃ¼man verilirse CLI: `python liste_indirici.py <url> [-o klasÃ¶r] [--mp3] [--kalite 1080]`.
  - VarsayÄ±lan kayÄ±t yeri `~/Videos/YouTube Listeleri`.
- **Dokunulan dosyalar:** `liste_indirici.py`, `requirements.txt`, `baslat.bat`, `README.md`, `.gitignore`
- **Komutlar:**
  ```bash
  python -m pip install -U yt-dlp        # 2026.10.26 kuruldu
  gh repo create YoutubeListeIndirici --private --source . --push
  ```
- **SonuÃ§ / doÄŸrulama:** `@Google/videos` ile 1 Ã¶ÄŸe mp3 indirildi â†’ `Google - Videos/001 - ....` klasÃ¶rÃ¼ oluÅŸtu.
- **Commit:** `b9d79ef` â€” YouTube oynatma listesi indirici

### 2. watch?v=..&list=.. linklerinin desteklenmesi
- **Neden:** KullanÄ±cÄ±nÄ±n Ã¶rnek linki `watch?v=THeLVhU53ow&list=PLrAMR0by1bVCQ4C8YBgadCZqWePNGIB_K` biÃ§imindeydi; tek video yerine liste insin diye.
- **Ne yapÄ±ldÄ±:** `liste_url()` â€” `list` parametresini alÄ±p `https://www.youtube.com/playlist?list=...` Ã¼retir.
- **SonuÃ§ / doÄŸrulama:** Liste adÄ± "Son", 58 video; 360p ile ilk video `Son/001 - Jess Glynne - ....mp4` olarak birleÅŸik indi.
- **Commit:** bkz. git log â€” "watch?v=..&list=.. linklerini saf liste linkine Ã§evir"

## Kararlar
- yt-dlp seÃ§ildi (bakÄ±mÄ± aktif, YouTube deÄŸiÅŸikliklerine hÄ±zlÄ± uyum). Ã‡alÄ±ÅŸmazsa Ã¶nce `python -m pip install -U yt-dlp`.
- GUI iÃ§in tkinter (ek baÄŸÄ±mlÄ±lÄ±k yok).

## AÃ§Ä±k kalanlar / sonraki adÄ±m
- Log'da video+ses akÄ±ÅŸlarÄ± iÃ§in iki kez "indirildi" yazÄ±yor (kozmetik).
- Ä°stenirse .exe paketleme (PyInstaller).

