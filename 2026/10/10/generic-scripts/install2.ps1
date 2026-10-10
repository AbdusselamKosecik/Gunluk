# llama-server başlatıcı: 6 thread (10 çekirdeğin 4'ü AD/DNS/SQL için boş kalır)
$run = @'
@echo off
cd /d C:\llama
C:\llama\bin\llama-server.exe ^
  -m C:\llama\models\gemma-4-26B_q4_0-it.gguf ^
  --mmproj C:\llama\models\gemma-4-26B-it-mmproj.gguf ^
  --host 0.0.0.0 --port 8180 ^
  -t 6 -tb 6 -c 16384 -np 2 ^
  --alias gemma-4-26b ^
  --log-file C:\llama\logs\llama-server.log
'@
Set-Content C:\llama\run-server.cmd $run -Encoding ASCII

# Servis yerine zamanlanmış görev: açılışta SYSTEM, öncelik 7 = BelowNormal, çökünce yeniden başlat
$a = New-ScheduledTaskAction -Execute 'C:\llama\run-server.cmd'
$t = New-ScheduledTaskTrigger -AtStartup
$s = New-ScheduledTaskSettingsSet -Priority 7 -ExecutionTimeLimit ([TimeSpan]::Zero) `
       -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -AllowStartIfOnBatteries -StartWhenAvailable
Register-ScheduledTask -TaskName 'llama-server' -Action $a -Trigger $t -Settings $s -User SYSTEM -RunLevel Highest -Force | Out-Null

# Güvenlik duvarı: sadece iç ağ + Tailscale; public IP (196.204.119.88/29) hariç
New-NetFirewallRule -DisplayName 'llama-server 8180' -Direction Inbound -Protocol TCP -LocalPort 8180 `
  -RemoteAddress 192.168.0.0/16,100.64.0.0/10 -Action Allow -Profile Any | Out-Null

Get-ScheduledTask llama-server | Select-Object TaskName, State
Get-NetFirewallRule -DisplayName 'llama-server 8180' | Get-NetFirewallAddressFilter | Select-Object RemoteAddress
