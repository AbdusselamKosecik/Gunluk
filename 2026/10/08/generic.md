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

---

## Ek: Log analizi — "her elektrik kesintisinde sorun" (2026-10-09 gece)

### Bulgular
- **Sunucu nadiren elektriksiz kalıyor:** 90 günde tek Event 41 (15.09 10:25).
- **Switch/ağ düşüyor:** HPE AMS id=4367 "NIC Link Failure": 15.09 (2x), 30.09 (6x, 15:25–18:41),
  01.10 (3x, 15:43'te "All links are down"). Sunucu ayakta kalıyor, linki gidip geliyor.
  Sunucuda UPS yazılımı yok.
- **DC + NLA sorunu:** DNS sırası `127.0.0.1, 192.168.0.3`. Ağ geri gelince NlaSvc domaini bulamıyor →
  "Network 4 / Public". Reboot sonrası 23:59'da Public, ancak 00:06'da DomainAuthenticated
  (NetworkProfile/Operational 10000/10001).
- **Kilitlenme deseni:** SCM 7011 (30 sn timeout) — 23.09: NlaSvc+iphlpsvc; 08.10 12:06–12:18:
  NlaSvc+iphlpsvc+Schedule (9'ar kez). Sonra RDP kopuyor, reboot takılıyor (23.09'da 44 dk,
  08.10'da hiç bitmedi). 23.09 21:53 TermService başlayamadı (7000/7038).
- **Yan riskler:** PDC saat kaynağı "Local CMOS Clock" (30.09'da ~2 dk geri atlama);
  SQL max server memory sınırsız (RAM 96 GB); 15.09'da bio-redis 168 kez crash-loop (09:34–10:23);
  FlexibleLOM Port 3'te genel IP 196.204.119.91 / GW .89 tanımlı (kablo takılı değil).

### Kullanılan sorgular (özet)
```powershell
Get-WinEvent -FilterHashtable @{LogName='System';Id=41,6005,6006,6008,1074,1076,109,12,13;StartTime=(Get-Date).AddDays(-90)}
Get-WinEvent -FilterHashtable @{LogName='System';ProviderName='Service Control Manager';Id=7000,7011,7031,7034,7038,7043;StartTime=(Get-Date).AddDays(-30)}
# Mesajlar uzaktan boş geliyor → $_.Properties ile oku
Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-NetworkProfile/Operational';StartTime=(Get-Date).AddDays(-30)}
Get-WinEvent -FilterHashtable @{LogName='System';ProviderName='Agentless Management Service';Level=1,2,3}
w32tm /query /source
```

### Önerilen düzeltmeler (onay bekliyor, uygulanmadı)
1. Switch + FortiGate'i UPS'e bağla (fiziksel, asıl tetikleyici).
2. DNS sırası: önce 192.168.0.3 (DC olduğu doğrulanınca), sonra 127.0.0.1.
3. NlaSvc → DNS/NTDS bağımlılığı + gecikmeli başlatma.
4. PDC → dış NTP (`w32tm /config /manualpeerlist:... /syncfromflags:manual /reliable:yes`).
5. SQL max server memory sınırı (ör. 64 GB).
6. UPS varsa kapatma ajanı kur.

---

## Ek 2: Düzeltmelerin uygulanması (2026-10-09 ~02:40)

### Ön kontrolde çıkan kritik bulgu
- `netdom query fsmo` → **tüm FSMO rolleri + PDC = DataSRV.modfextr.local (192.168.0.3)**, MODFEXSRV değil.
- DataSRV ulaşılamıyor (ping, 53/88/389/445/3389 kapalı). `repadmin /replsummary`: DATASRV→MODFEXSRV
  5/5 fail, (1722) RPC server unavailable, son başarılı replikasyon ~9h37m önce (08.10 ~17:00).
- MODFEXSRV w32tm: Source=Local CMOS Clock, not synchronized; time.windows.com'a göre **-122 sn**.

### Uygulanan
1. **NlaSvc (DC için):**
   ```powershell
   New-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters -Name AlwaysExpectDomainController -PropertyType DWord -Value 1 -Force
   sc.exe config NlaSvc start= delayed-auto
   ```
   Doğrulandı: AlwaysExpectDomainController=1, DelayedAutostart=1. Bir sonraki açılışta etkin
   (servis şimdi yeniden başlatılmadı). Geri alma: değeri sil + `sc config NlaSvc start= auto`.
2. **SQL max server memory:** 2147483647 → **65536 MB** (`sp_configure`, RECONFIGURE; value_in_use=65536).
   `show advanced options` tekrar 0'a alındı.

### Uygulanmadı (bilinçli)
- DNS sırası (0.3 önce): DataSRV kapalıyken isim çözümlemeyi yavaşlatır → DataSRV dönünce.
- NTP: dış NTP, PDC olan DataSRV'de yapılmalı; MODFEXSRV NT5DS (domain hiyerarşisi) olmalı → DataSRV dönünce.
- UPS ajanı: sunucuda UPS cihazı (Win32_Battery / PnP) görünmüyor → UPS'in USB/ağ kartı ile bağlı olup olmadığı fiziksel kontrol.

### Açık kalanlar
- **DataSRV (192.168.0.3) neden kapalı?** Fiziksel kontrol gerek. Dönünce: repadmin ile replikasyon,
  DataSRV'de `w32tm /config /manualpeerlist:"0.pool.ntp.org,0x8 1.pool.ntp.org,0x8" /syncfromflags:manual /reliable:yes /update`,
  MODFEXSRV'de `w32tm /config /syncfromflags:domhier /update`, sonra DNS sırası.
