# Yönetici olarak çalışır: kilitli SRUM veritabanının kopyasını (VSS) ve Wi-Fi profil eşlemesini alır.
param([string]$Hedef = "$PSScriptRoot\veri")
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force $Hedef | Out-Null
$db = Join-Path $Hedef 'SRUDB.dat'
if (Test-Path $db) { Remove-Item $db -Force }
esentutl.exe /y C:\Windows\System32\sru\SRUDB.dat /vss /d $db | Out-Null

# L2ProfileId (Wi-Fi profil indeksi) -> SSID ve ağ adı eşlemesi
$wifi = foreach ($p in Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\WlanSvc\Interfaces\*\Profiles\*' -ErrorAction SilentlyContinue) {
    $m = Get-ItemProperty (Join-Path $p.PSPath 'MetaData') -ErrorAction SilentlyContinue
    $xml = (Get-ItemProperty $p.PSPath -ErrorAction SilentlyContinue).'Profile'
    $ad = if ($m.'Channel Hints') { [Text.Encoding]::ASCII.GetString($m.'Channel Hints'[4..35]).Trim([char]0) } else { $null }
    [pscustomobject]@{ Indeks = $m.'Profile Index'; Ssid = $ad; Guid = $p.PSChildName }
}
$wifi | ConvertTo-Json -Depth 3 | Out-File -Encoding utf8 (Join-Path $Hedef 'wifi.json')

# Arayüz LUID -> ad (Ethernet/VPN adları için)
Get-NetAdapter -IncludeHidden | Select-Object Name, InterfaceDescription, @{n='Luid';e={[string]$_.NetLuid}}, InterfaceType |
    ConvertTo-Json | Out-File -Encoding utf8 (Join-Path $Hedef 'arayuzler.json')
"tamam" | Out-File (Join-Path $Hedef 'kopya.ok')
