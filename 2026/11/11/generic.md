# generic — 2026-11-11

## Bağlam
192.168.1.3 ve 192.168.1.4 kapanmış; neden kapandıkları araştırıldı.

## Yapılanlar

### 1. 192.168.1.4 (MDSMHYPERV, Hyper-V host) kapanma analizi
- **Neden:** Sunucular habersiz kapandı, sebep bulunmalı.
- **Ne yapıldı:**
  - Yerel makine domain dışı → WinRM için TrustedHosts'a `192.168.1.3,192.168.1.4` eklendi (yönetici PowerShell, kullanıcı yaptı).
  - `modfextr` cred'i (srv02.cred, 192.168.0.2 için) burada geçmedi. Kullanıcı `Get-Credential | Export-Clixml "$env:USERPROFILE\hyperv04.cred"` ile `administrator` (yerel) kaydetti; ilk olarak `modsima\administrator` Access denied verdi.
  - System log: Id 41, 6008, 1074, 1001, WHEA; Hyper-V-Worker-Admin; Get-VM.
- **Komutlar:**
  ```powershell
  $c = Import-Clixml "$env:USERPROFILE\hyperv04.cred"
  Invoke-Command -ComputerName 192.168.1.4 -Credential $c -ScriptBlock {
    Get-WinEvent -FilterHashtable @{LogName='System';Id=41,6008,1074,1001;StartTime=(Get-Date).AddDays(-7)}
    Get-VM }
  ```
- **Sonuç:**
  - Bugün 2 beklenmedik kapanma: **19:10:55** ve **20:21:26**. Kernel-Power 41, BugcheckCode=0, PowerButtonTimestamp=0, 1074 yok, BSOD yok, WHEA yok → **elektrik kesintisi / güç kaybı** (veya tam donma). UPS koruması yok gibi.
  - Önceki: 2026-11-01 09:57 ve 2026-08-20 15:56 da aynı tip beklenmedik kapanma.
  - Host IP'leri: 192.168.1.4 (vEthernet Lan02HyperV) + 192.168.1.5 (LAN03).
  - VM'ler: 2016_LOGO (.1.11) ve debian (.1.141) otomatik açıldı (19:20, 20:30). 2026_FS, MDSM_AD, RDP_Server03, RDP_Server04 kapalı (StartIfRunning → kapanmadan önce de kapalıydılar).
  - 192.168.1.3: hâlâ kapalı, ARP Incomplete; hiçbir VM'de bu IP yok → ayrı fiziksel makine olması muhtemel, açılınca bakılacak.

## Kararlar
- Şifre sohbete yazılmaz; DPAPI cred dosyası (`hyperv04.cred`) kullanılır.

## Açık kalanlar / sonraki adım
- 192.168.1.3'ü fiziksel olarak aç, aynı log sorgusunu orada çalıştır.
- UPS durumu kontrol edilmeli (iki kesinti aynı akşam).
