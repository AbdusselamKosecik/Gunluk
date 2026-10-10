# generic — 2026-10-10

## Bağlam
08.10 gecesi MODFEXSRV (192.168.0.2) takılı reboot çözülmüş, log analizinde ikinci DC/PDC
**DataSRV (192.168.0.3)**'nin 08.10 ~17:00'den beri kapalı olduğu bulunmuştu (bkz. 2026/10/08/generic.md).
Hedef: DataSRV'yi ayağa kaldırmak, bekleyen saat + DNS düzeltmelerini uygulamak.

## Yapılanlar

### 1. DataSRV'yi uyandırma
- **Uzaktan yol yok:** iLO/IPMI yok (HPE ML10 Gen9), ARP'ta MAC yok (WoL yapılamadı).
  0.x'te 443 açık cihazlar: .61 Aruba Instant On switch, .140 nginx, .221 ?, .241 HP LaserJet.
- **Fiziksel:** Kullanıcı gitti; güç düğmesi **sarı** (standby = kapalı), Health LED **kırmızı yanıp sönüyor**.
  Düğmeye basıldı → yeşil, 08:50:49'da açıldı.
- **Erişim:** Bu PC'den 0.3'e WinRM TrustedHosts nedeniyle reddedildi; MODFEXSRV üzerinden
  `Invoke-Command -ComputerName DataSRV.modfextr.local -Credential $c` (double-hop, explicit cred) ile girildi.

### 2. DataSRV kapanma geçmişi (asıl "elektrik" mağduru)
- Event 41/6008 (ani güç kaybı): 23.09 12:21, 15:10 · 07.10 14:32, 17:15, 17:29 · 08.10 16:29, **17:07**
  (sonuncusunda kendiliğinden açılmadı, ~40 saat kapalı kaldı).
- Aynı anlarda MODFEXSRV'de Event 41 yok → **MODFEXSRV UPS'te, DataSRV değil (veya UPS'i çalışmıyor).**
- Harddisk3 (her gün 21:00 ve 21:16, artan DRn — muhtemelen yedekleme hedefi) Disk 153 (IO retry) uyarıları.

### 3. Sağlık + replikasyon
- NTDS, DNS, DHCPServer, KDC, Netlogon, ADWS, DFSR, W32Time Running; askıda servis yok; RAID diskler Healthy.
- `repadmin /syncall DataSRV /AdeP` + `repadmin /syncall MODFEXSRV /AdeP` → replsummary her iki yön **0/5 fail**.

### 4. Saat (W32Time)
- Önce: iki DC de "Local CMOS Clock", time.windows.com'a göre ~123 sn **ileride**.
  ```powershell
  # DataSRV (PDC)
  w32tm /config /manualpeerlist:"0.pool.ntp.org,0x8 1.pool.ntp.org,0x8 time.windows.com,0x8" /syncfromflags:manual /reliable:yes /update
  Restart-Service W32Time; w32tm /resync /rediscover
  # MODFEXSRV
  w32tm /config /syncfromflags:domhier /update
  Restart-Service W32Time; w32tm /resync /rediscover
  ```
- Sonuç: DataSRV kaynak=NTP (Event 37 ile peer'lar doğrulandı), sapma -123 sn → -11 sn ve düşüyor.
  MODFEXSRV kaynak=DataSRV.modfextr.local.

### 5. DNS istemci sırası
- DataSRV `Ethernet`: `127.0.0.1,192.168.0.2,8.8.8.8,8.8.4.4` → **`192.168.0.2,127.0.0.1`**
  (8.8.x kaldırıldı; internet çözümlemesi forwarder'larda: 8.8.8.8, 8.8.4.4, 192.168.0.2).
- MODFEXSRV ifIndex 21 (vEthernet): `127.0.0.1,192.168.0.3` → **`192.168.0.3,127.0.0.1`**.
- İkisinde de `Resolve-DnsName modfextr.local` ve `www.microsoft.com` çalışıyor.

## Kararlar
- PDC yalnızca DataSRV olduğu için dış NTP orada; MODFEXSRV domain hiyerarşisinden alır.
- DC'lerin NIC DNS'inde genel DNS (8.8.8.8) olmaz; internet için DNS forwarder kullanılır.

## Açık kalanlar / sonraki adım
- **DataSRV'yi UPS'e bağla** (veya UPS'ini test et). BIOS: "After AC Power Loss → Power On/Last State".
- **Health LED kırmızı** nedeni bilinmiyor (iLO yok); ML10 Gen9'da ön panel/POST mesajı ya da HPE
  Insight Diagnostics ile bakılmalı (PSU/fan/ısı olabilir).
- Harddisk3 Disk 153 uyarıları + MODFEXSRV'de 2089 (AD yedeği yok) → yedekleme durumu incelenmeli.
- Switch + FortiGate UPS (08.10 notu) hâlâ açık.
- Administrator şifresi değiştirilmeli.
