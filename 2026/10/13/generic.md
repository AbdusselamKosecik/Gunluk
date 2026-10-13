# generic — 2026-10-13

## Bağlam
modfexsrv (192.168.0.2) RDP yine çöktü; kullanıcı kök sebep istedi.

## Yapılanlar

### 1. Kök sebep analizi
- Kaynak sorunu yok: CPU %2, 79 GB RAM boş, llama sağlıklı. Politika ayarları (TCP-only, tek oturum, 10 dk) yerinde.
- **Desen (System 7011 + LSM):**
  - 08.10 12:05:56 Administrator RDP bağlantısı **0x80070040 (ERROR_NETNAME_DELETED = ağ bağlantısı koptu)** ile düştü →
    30 sn sonra iphlpsvc, NlaSvc, Schedule SCM'ye yanıt vermedi (12:06–12:18 dakikada bir) → o gece yeniden başlatma (23:57).
  - 11.10 13:03 TermService çöküşü = önceki gün bizim düzeltmemiz.
  - 13.10 16:05 Administrator yine 0x80070040 ile düştü; 16:22 çıkış; 16:22:51 iphlpsvc, 16:23:21 NlaSvc timeout; LSM (qwinsta) kilitli;
    Get-NetAdapter / Win32_PerfFormattedData sorguları takıldı; TermService süreci Stop-Process ile hemen ölmedi (çekirdekte bekleme).
  - 13.10 05:06–05:08 OnayMerkezi Telegram botu "SSL connection could not be established" → aynı tür ağ kesintisi işareti.
- **Sonuç:** RDP kurban; asıl sorun **ana makinenin ağ yığınında anlık takılma** (NIC/vSwitch). Tailscale logları temiz (yalnız SessionChange).
- **Ağ yapısı:** HPE 331FLR (Broadcom) 4 port, sürücü **221.0.5.0 (2022-05-09, oem8.inf)**; Port1 → Hyper-V external vSwitch
  (vEthernet 192.168.0.2), Port2/3/4 Disconnected (**Port 3 = public 196.204.119.91, 10.10'da bağlıydı, şimdi kopuk**).
  VMQ tüm portlarda kapalı. **vSwitch SoftwareRsc=True**, vEthernet RSC IPv4=True. VM: Debian (Running).

### 2. Anlık düzeltme
- TermService + UmRdpService PID'leri sonlandırıldı → yeniden başlatıldı; qwinsta OK, IP Helper ve NLA (DomainAuthenticated) yanıt veriyor, 3389 açık.

## Öneriler (onay bekliyor)
1. `Set-VMSwitch -Name "HPE Ethernet 1Gb 4-port 331FLR Adapter #3 - Virtual Switch" -EnableSoftwareRsc $false`
   + `Set-NetAdapterRsc -Name "vEthernet (...)" -IPv4Enabled $false -IPv6Enabled $false` (bilinen Server 2019/2022 vSwitch RSC sorunları).
2. HPE SPP ile 331FLR sürücü + firmware güncellemesi (yeniden başlatma gerektirir, mesai dışı).
3. İzleme görevi: dakikada bir iphlpsvc/LSM yanıt kontrolü + log; takılınca TermService otomatik yeniden başlatma (geçici yama).
4. Port 3 (public) kopukluğu kontrol edilmeli.
