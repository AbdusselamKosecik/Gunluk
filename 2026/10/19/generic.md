# generic — 2026-10-19

## Bağlam
Yeni indirilen `D:\Backup\003-Media\Videolarım\turkce` (26 mp4) videoları Windows Medya Oynatıcı'da açılmıyor.

## Yapılanlar

### 1. Teşhis
- Hepsi ffprobe ile okunuyor; ses hepsinde AAC (Vorbis sorunu yok). 6 dosya AV1 — `Microsoft.AV1VideoExtension 2.0.35` kurulu, sorun değil.
- **Asıl sebep:** 21 dosya **parçalı (fragmented/DASH) MP4** — üst düzey `moof`/`sidx` atomları; indirme aracı DASH akışını
  normal MP4'e remux etmemiş. Parçalı olmayan 5 dosya (Mabel Matiz, Bahar, Dağları Deldim, Hep Yek, Cinayet) normal.
- `Özlem Tekin - Laubali.mp4` yalnız görüntü (av1 320x240, ses YOK, 3,1 MB) → eksik indirme, yeniden indirilmeli.

### 2. Betik güncellemesi (`video_duzelt.ps1`)
- `ParcaliMi`: üst düzey atomları dolaşır, `moof` varsa sorun `yapı:parçalı-mp4`.
- Ses uyumluysa `-c:a copy` (yalnız yapı sorunu → kayıpsız remux), değilse AAC. `-movflags +faststart`.
- Kuru tarama Videolarım: 21 sorunlu (hepsi turkce\, yapı:parçalı-mp4); diğer 65 video temiz.
- Test: `Mirkelam - Asuman Pansuman.mp4` → h264|aac, süre 196,27 sn, 14,0 → 14,0 MB, yeniden tarama 0 sorun; orijinal
  `_orijinaller\Videolarım\turkce\`.
- **Commit:** yerel `video-duzelt` (remote yok).

## Açık kalanlar
- Kullanıcı Mirkelam'ı onaylarsa kalan 20 dosya: `video_duzelt.ps1 -Klasorler 'D:\Backup\003-Media\Videolarım' -Uygula`.
- İndirme aracının ayarı (remux/merge) düzeltilirse sorun tekrar etmez.

### 3. Toplu uygulama
- Kullanıcı "yaptın mı" → kalan 20 dosya `-Uygula`: **20/20 düzeltildi, 0 hata** (rapor `rapor_20261019_213906.csv`).
- Yeniden tarama Videolarım: **0 sorunlu**. Orijinaller `_orijinaller\Videolarım\turkce\` (21 dosya).
- Laubali yine sessiz (kaynak eksik) — yeniden indirilmeli.
