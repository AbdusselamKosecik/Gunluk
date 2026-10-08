# generic — 2026-10-08

## Bağlam
MODFEXSRV (192.168.0.2, modfextr domain) sunucusuna RDP ile bağlanılamıyordu. Sunucu DC + DNS +
SQL Server + Hyper-V host (Debian VM). 15:07'de yeniden başlatma verilmiş ama "çok uzun sürmüş";
uzak PowerShell'de askıda servisler görülmüştü. Hedef: sebebi bulmak, sunucuyu yeniden başlatıp RDP'yi açmak.

## Yapılanlar

### 1. Bu PC'den erişim sorunu (VPN/DNS)
- **Neden:** 192.168.0.2 ping/3389/5985/445'e hiç yanıt yoktu.
- **Ne yapıldı:** Rota incelendi: 192.168.0.0/24 → "Ethernet 2" (Fortinet Virtual Ethernet, 10.250.0.10 → gw 10.250.0.11).
  0.1–0.20 aralığında hiçbir cihaz (FortiGate 0.5 dahil) yanıt vermiyordu → tünel ölü. Tüm arayüzlerde
  DNS'in ilki 192.168.0.3 olduğu için tünel düşünce DNS de çöküyor; Tailscale bu yüzden DERP/kontrol
  sunucusuna ulaşamıyordu (netcheck: UDP false, DERP yok). İnternet TCP ile çalışıyordu (ICMP engelli).
- **Çözüm:** Kullanıcı modemi resetleyip Forti VPN'i kapatıp açtı → 0.5:4443, 0.2:5985/3389 erişilir oldu.
- **Komutlar:**
  ```powershell
  Find-NetRoute -RemoteIPAddress 192.168.0.2
  Get-DnsClientServerAddress -AddressFamily IPv4
  & 'C:\Program Files\Tailscale\tailscale.exe' netcheck
  ```

### 2. Sunucudaki takılı yeniden başlatma
- **Bulgu:** System log: 15:07:26'da 1074 (shutdown.exe restart) var ama sonrasında açılış yok; son açılış 23.09.2026.
  130 servis hâlâ RUNNING, kapanma ilerlememiş. Askıda: `sppsvc` STOP_PENDING, `wlidsvc` STOP_PENDING,
  `AppXSvc` START_PENDING. RDP servisleri çalışıyordu ama sistem kapanma modunda yeni oturum kabul etmiyordu.
- **Denenenler (başarısız):** `taskkill /F` → wlidsvc öldü, sppsvc/AppXSvc korumalı işlem (Access denied).
  `shutdown /r /f` ve WMI `Win32Shutdown(6)` takıldı. SYSTEM olarak schtasks ile çalıştırma: görev hiç çalışmadı
  (Görev Zamanlayıcı da kilitli).
- **Güvenli hazırlık (kullanıcı onayıyla):** `Stop-VM -Name Debian` (guest shutdown) → Off;
  `Stop-Service MSSQLSERVER -Force` → Stopped.
- **Çözen adım:** WinRM oturumundan doğrudan kernel reboot (SCM'yi atlar, cache flush eder):
  ```powershell
  Add-Type 'using System;using System.Runtime.InteropServices;public static class NtR2{
   [DllImport("ntdll.dll")]public static extern int RtlAdjustPrivilege(int p,bool e,bool t,out bool w);
   [DllImport("ntdll.dll")]public static extern int NtShutdownSystem(int a);}'
  $w=$false;[NtR2]::RtlAdjustPrivilege(19,$true,$false,[ref]$w)  # SeShutdownPrivilege
  [NtR2]::NtShutdownSystem(1)                                    # 1 = reboot
  ```
- **Sonuç / doğrulama:** Yeni açılış 08.10.2026 23:58. DNS, NTDS, Netlogon, MSSQLSERVER, SQLSERVERAGENT,
  TermService, UmRdpService, vmms, SentezServis Running; askıda servis yok. Debian VM `Start-VM` ile
  başlatıldı (Heartbeat OK). Geçici NtReboot görevi ve script silindi.
- **Dikkat:** Açılıştan sonraki ilk ~2 dk WinRM "Access is denied" verdi (DC'de AD hazır olana kadar normal).
  Arada yaşanan 5 dk'lık bir port kesintisi VPN kaynaklıydı, reboot değildi — doğrulamayı her zaman
  açılış zamanıyla (`(Get-Process -Id 4).StartTime`) yap.

## Kararlar
- wininit'i öldürüp bugcheck yerine önce NtShutdownSystem denendi (daha temiz).
- Debian VM "Save" yerine "Shutdown" ile durduruldu (kullanıcı tercihi).

## Açık kalanlar / sonraki adım
- sppsvc'nin neden kapanırken takıldığı bilinmiyor; tekrarlarsa olay günlüğü incelenmeli.
- Değerlendir: `WaitToKillServiceTimeout` kısaltma.
- Debian VM'in AutomaticStartAction'ı "StartIfRunning" — kapalıyken host açılırsa otomatik başlamaz.
- Administrator şifresi sohbette düz metin paylaşıldı → değiştirilmeli.
