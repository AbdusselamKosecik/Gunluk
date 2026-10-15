# Panoyu yeniler: SRUM kopyası (yönetici onayı ister) -> veri çıkarma -> pano.html'i açar.
$kok = $PSScriptRoot
Start-Process powershell -Verb RunAs -Wait -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$kok\srum_kopyala.ps1`""
& "$kok\.venv\Scripts\python.exe" "$kok\srum_oku.py"
Start-Process "$kok\pano.html"
