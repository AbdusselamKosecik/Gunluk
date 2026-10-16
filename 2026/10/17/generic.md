# generic — 2026-10-17

## Bağlam
`Duman - Manası Yok.mp4` Windows Medya Oynatıcı'da açılmıyor, MPC Classic'te açılıyor.

## Yapılanlar

### 1. Teşhis
- MP4 atom ayrıştırma (python, stsd/esds): görüntü H.264 Main 3.1 854x480 ✔; ses `mp4a` ama esds objectType **0xDD = Vorbis**
  (DSI içinde "vorbis", "encoder=Google") → 2015 YouTube indirmesi, Vorbis MP4 içine konmuş. Windows Media Foundation MP4 içinde
  Vorbis çözmez; MPC-HC LAV filtreleriyle çözer. Ayrıca attached_pic mjpeg kapak (YouTube küçük resmi) var.

### 2. Toplu düzeltme betiği
- ffmpeg 9.0.2 kuruldu: `winget install --id Gyan.FFmpeg -e` (yavaş hat, ~10+ dk).
- `X:\Yazilim\generic\video-duzelt\video_duzelt.ps1`:
  ffprobe ile mp4/m4v/mov tarar; uyumsuz ses (aac/mp3/ac3/eac3/alac/flac/pcm dışı) veya görüntü (h264/hevc/mpeg4/mjpeg/av1 dışı)
  → `ffmpeg -c:v copy -c:a aac -b:a 192k -movflags +faststart` (görüntü sorunluysa libx264 crf 18) geçici dosyaya;
  doğrulama (süre ±1 sn, ses akışı sayısı, kalan sorun yok); orijinal `D:\Backup\003-Media\_orijinaller\<kök>\<göreli>` altına taşınır,
  yeni dosya aynı ad + CreationTime/LastWriteTime ile yerine konur. Varsayılan kuru çalışma; `-Uygula`, `-Dosya`.
- **Tuzak:** PS 5.1 BOM'suz UTF-8 betiği ANSI okur → Türkçe karakterli betik **UTF-8 BOM** ile kaydedilmeli.
- **Kuru tarama:** Videolarım 86 mp4 → 0 sorunlu; Videos 143 mp4 (+20 webm kapsam dışı) → **80 sorunlu, hepsi ses:vorbis**,
  hepsi `Videos\Abdusselam Kösecik`. Rapor `rapor_20261017_013409_kuru.csv`.
- **Tek dosya testi:** Duman - Manası Yok → h264 + **aac** + mjpeg kapak (attached_pic korunur), süre 228,09 sn, tarih 2015-04-02 korundu,
  6,6 → 8,3 MB; orijinal arşivde.
- WPF MediaPlayer ile otomatik oynatma testi takıldı (dispatcher) → iptal; kullanıcı Medya Oynatıcı'da elle deneyecek.
- **Commit:** yerel repo `video-duzelt` (remote yok).

## Açık kalanlar
- Kullanıcı test dosyasını onaylarsa: `video_duzelt.ps1 -Uygula` (kalan 79 dosya).

### 3. Toplu uygulama
- Kullanıcı test dosyasını (Duman - Manası Yok) Medya Oynatıcı'da onayladı → `video_duzelt.ps1 -Uygula`.
- Sonuç: **79/79 düzeltildi, 0 hata** (rapor `rapor_20261017_020210.csv`). Yeniden kuru tarama: **0 sorunlu**.
- Arşiv `D:\Backup\003-Media\_orijinaller\Videos\Abdusselam Kösecik\` : 80 orijinal, 1.714 MB.
