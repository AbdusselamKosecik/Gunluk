<#
.SYNOPSIS
  Windows Medya Oynatıcı'nın açamadığı MP4/M4V/MOV videolarını bulur, uyumlu hale getirir ve orijinalin yerine koyar.

.DESCRIPTION
  Sorunlu = MP4 kabında Windows'un tanımadığı ses (Vorbis, Opus, …) veya görüntü (VP8, VP9, …) formatı.
  - Ses AAC'ye çevrilir; görüntü uyumluysa yeniden kodlanmaz (kayıpsız kopyalanır), değilse H.264'e çevrilir.
  - Yeni dosya doğrulanır (süre ±1 sn, codec'ler uyumlu); başarısızsa orijinale dokunulmaz.
  - Orijinal silinmez: <Arsiv>\<göreli yol> altına taşınır. Yeni dosya aynı ad ve tarihleri alır.
  Varsayılan KURU ÇALIŞMADIR (yalnız rapor). Değişiklik için -Uygula verin.

.EXAMPLE
  .\video_duzelt.ps1                     # tarar, rapor yazar, hiçbir dosyaya dokunmaz
  .\video_duzelt.ps1 -Uygula             # dönüştürür ve yer değiştirir
  .\video_duzelt.ps1 -Uygula -Dosya "D:\...\a.mp4"   # tek dosya
#>
param(
    [string[]]$Klasorler = @('D:\Backup\003-Media\Videolarım', 'D:\Backup\003-Media\Videos'),
    [string]$Arsiv = 'D:\Backup\003-Media\_orijinaller',
    [string]$Dosya,
    [switch]$Uygula
)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$Uzantilar = '.mp4', '.m4v', '.mov'
# Windows Media Foundation'ın MP4 içinde yerleşik çözebildikleri (HEVC/AV1 için Store eklentisi yeterli sayılır).
$UyumluSes = 'aac', 'mp3', 'ac3', 'eac3', 'alac', 'flac', 'pcm_s16le', 'pcm_s24le', 'pcm_f32le'
$UyumluGoruntu = 'h264', 'hevc', 'mpeg4', 'mjpeg', 'av1', 'h263'
$KapakGoruntu = 'mjpeg', 'png', 'bmp'   # albüm kapağı akışları sorun sayılmaz

foreach ($a in 'ffprobe', 'ffmpeg') {
    if (-not (Get-Command $a -ErrorAction SilentlyContinue)) { throw "$a bulunamadı. Kurulum: winget install Gyan.FFmpeg" }
}

function ParcaliMi([string]$yol) {
    # Üst düzey atomları dolaşır: 'moof' varsa parçalı (fragmented/DASH) MP4 — Windows Medya Oynatıcı çoğu zaman açamaz.
    $fs = [IO.File]::OpenRead($yol)
    try {
        $b = New-Object byte[] 16; $o = 0L
        while ($o + 8 -le $fs.Length) {
            $fs.Position = $o
            if ($fs.Read($b, 0, 16) -lt 8) { break }
            $n = [long]([uint32]$b[0] -shl 24 -bor [uint32]$b[1] -shl 16 -bor [uint32]$b[2] -shl 8 -bor [uint32]$b[3])
            $tur = [Text.Encoding]::ASCII.GetString($b, 4, 4)
            if ($tur -eq 'moof') { return $true }
            if ($n -eq 1) { $n = [long][BitConverter]::ToUInt64(($b[15..8]), 0) }   # 64-bit boyut (big-endian)
            elseif ($n -eq 0) { break }
            if ($n -lt 8) { break }
            $o += $n
        }
        return $false
    } finally { $fs.Dispose() }
}

function Incele([string]$yol) {
    $j = & ffprobe -v error -show_entries 'stream=index,codec_type,codec_name:stream_disposition=attached_pic:format=duration' -of json -- $yol 2>$null | Out-String
    if (-not $j) { return $null }
    $d = $j | ConvertFrom-Json
    [pscustomobject]@{
        Sure     = [double]($d.format.duration)
        Goruntu  = @($d.streams | Where-Object { $_.codec_type -eq 'video' -and -not $_.disposition.attached_pic } | ForEach-Object codec_name)
        Ses      = @($d.streams | Where-Object codec_type -eq 'audio' | ForEach-Object codec_name)
        Parcali  = ParcaliMi $yol
    }
}

function Sorunlar($b) {
    $s = @()
    if ($b.Parcali) { $s += 'yapı:parçalı-mp4' }
    $s += $b.Ses | Where-Object { $_ -notin $UyumluSes } | ForEach-Object { "ses:$_" }
    $s += $b.Goruntu | Where-Object { $_ -notin $UyumluGoruntu -and $_ -notin $KapakGoruntu } | ForEach-Object { "görüntü:$_" }
    $s
}

$dosyalar = if ($Dosya) { @(Get-Item -LiteralPath $Dosya) } else {
    $Klasorler | Where-Object { Test-Path -LiteralPath $_ } | ForEach-Object {
        Get-ChildItem -LiteralPath $_ -Recurse -File | Where-Object { $_.Extension.ToLower() -in $Uzantilar }
    }
}
Write-Host ("{0} video taranıyor…" -f @($dosyalar).Count)

$rapor = [Collections.Generic.List[object]]::new()
$i = 0
foreach ($f in $dosyalar) {
    $i++
    Write-Progress -Activity 'Taranıyor' -Status $f.Name -PercentComplete (100 * $i / @($dosyalar).Count)
    $b = Incele $f.FullName
    if (-not $b) { $rapor.Add([pscustomobject]@{ Dosya = $f.FullName; Durum = 'OKUNAMADI'; Sorun = ''; MB = [math]::Round($f.Length / 1MB, 1) }); continue }
    $sorun = @(Sorunlar $b)
    if ($sorun.Count -eq 0) { continue }

    $satir = [pscustomobject]@{ Dosya = $f.FullName; Durum = 'SORUNLU'; Sorun = ($sorun -join ', '); MB = [math]::Round($f.Length / 1MB, 1) }
    $rapor.Add($satir)
    Write-Host ("  ✗ {0}  [{1}]" -f $f.FullName, $satir.Sorun)
    if (-not $Uygula) { continue }

    # --- Dönüştür ---
    $gecici = Join-Path $f.DirectoryName ('.duzelt_' + [guid]::NewGuid().ToString('N') + '.mp4')
    $goruntuSorunlu = $sorun | Where-Object { $_ -like 'görüntü:*' }
    $vArg = if ($goruntuSorunlu) { @('-c:v', 'libx264', '-preset', 'medium', '-crf', '18', '-pix_fmt', 'yuv420p') } else { @('-c:v', 'copy') }
    # Ses uyumluysa kopyalanır (yalnız yapı sorunu → kayıpsız remux), değilse AAC'ye çevrilir.
    $aArg = if ($sorun | Where-Object { $_ -like 'ses:*' }) { @('-c:a', 'aac', '-b:a', '192k') } else { @('-c:a', 'copy') }
    $ffArgs = @('-hide_banner', '-loglevel', 'error', '-y', '-i', $f.FullName,
        '-map', '0:v?', '-map', '0:a?', '-map_metadata', '0') + $vArg + $aArg + @('-movflags', '+faststart', $gecici)
    & ffmpeg @ffArgs
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $gecici)) {
        $satir.Durum = 'HATA: ffmpeg'; Remove-Item -LiteralPath $gecici -ErrorAction SilentlyContinue; continue
    }

    # --- Doğrula ---
    $y = Incele $gecici
    $kalan = if ($y) { @(Sorunlar $y) } else { @('okunamadı') }
    if (-not $y -or $kalan.Count -gt 0 -or [math]::Abs($y.Sure - $b.Sure) -gt 1.0 -or $y.Ses.Count -ne $b.Ses.Count) {
        $satir.Durum = "HATA: doğrulama (süre {0:N1}/{1:N1}, kalan: {2})" -f $y.Sure, $b.Sure, ($kalan -join ',')
        Remove-Item -LiteralPath $gecici -ErrorAction SilentlyContinue; continue
    }

    # --- Yer değiştir: orijinal arşive, yeni dosya orijinalin yerine (aynı ad + tarihler) ---
    $kok = ($Klasorler | Where-Object { $f.FullName.StartsWith($_, [StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1)
    $goreli = if ($kok) { Join-Path (Split-Path $kok -Leaf) $f.FullName.Substring($kok.Length).TrimStart('\') } else { $f.Name }
    $hedef = Join-Path $Arsiv $goreli
    New-Item -ItemType Directory -Force (Split-Path $hedef) | Out-Null
    if (Test-Path -LiteralPath $hedef) { $hedef = [IO.Path]::ChangeExtension($hedef, (Get-Date -f 'yyyyMMddHHmmss') + $f.Extension) }
    $olusturma, $degisiklik = $f.CreationTime, $f.LastWriteTime
    Move-Item -LiteralPath $f.FullName -Destination $hedef
    $yeniAd = [IO.Path]::ChangeExtension($f.FullName, '.mp4')   # .mov/.m4v içerik MP4 olur
    if ($yeniAd -ne $f.FullName -and (Test-Path -LiteralPath $yeniAd)) {   # aynı adlı başka bir .mp4 varsa ezme
        $yeniAd = Join-Path $f.DirectoryName ($f.BaseName + ' (uyumlu).mp4')
    }
    Move-Item -LiteralPath $gecici -Destination $yeniAd
    $n = Get-Item -LiteralPath $yeniAd; $n.CreationTime = $olusturma; $n.LastWriteTime = $degisiklik
    $satir.Durum = 'DÜZELTİLDİ'
    $satir | Add-Member Orijinal $hedef
    Write-Host ("    ✓ düzeltildi → orijinal: {0}" -f $hedef)
}
Write-Progress -Activity 'Taranıyor' -Completed

$raporYolu = Join-Path $PSScriptRoot ("rapor_{0}{1}.csv" -f (Get-Date -f 'yyyyMMdd_HHmmss'), $(if ($Uygula) { '' } else { '_kuru' }))
$rapor | Export-Csv -LiteralPath $raporYolu -NoTypeInformation -Encoding UTF8
Write-Host ''
Write-Host ("Sorunlu: {0} | Düzeltildi: {1} | Hata: {2} | Okunamadı: {3}" -f
    @($rapor | Where-Object Durum -ne 'OKUNAMADI').Count, @($rapor | Where-Object Durum -eq 'DÜZELTİLDİ').Count,
    @($rapor | Where-Object Durum -like 'HATA*').Count, @($rapor | Where-Object Durum -eq 'OKUNAMADI').Count)
Write-Host "Rapor: $raporYolu"
if (-not $Uygula -and $rapor.Count) { Write-Host 'Kuru çalışma: hiçbir dosya değişmedi. Düzeltmek için -Uygula ile çalıştırın.' }
