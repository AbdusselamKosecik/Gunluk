# generic — 2026-10-11

## Bağlam
Kullanıcı modfexsrv'ye (192.168.0.2) Uzak Masaüstü ile bağlanamıyor.

## Yapılanlar

### 1. RDP arıza teşhisi
- **Ağ:** laptop artık 192.168.0.80 (aynı LAN); ping, 3389, 5985, 445, 8180 açık. llama-server /health ok, CPU %2, 77 GB RAM boş → LLM ile ilgisiz.
- **Bulgular:**
  - 2 uzak oturum hakkı (RDS CAL yok) iki KOPUK oturumla dolu: s2 Administrator (09.10'dan beri), s3 busra.komurcugil (10.10'dan beri).
  - LSM takılı: `quser`/`qwinsta` yanıt vermiyor → yeniden bağlanma çalışmıyor.
  - RdpCoreTS 226 `0x8007139F` + RDP_UDP hataları (12:57–13:00) — bilinen Server 2022 UDP sorunu.
  - NLA kapalı (UserAuthentication=0), SecurityLayer=2, sertifika 2027-01-14'e kadar geçerli.
  - 4625 başarısız girişler: 192.168.0.204 (4), 192.168.0.5 (2).
- **Teşhis komutu ipucu:** `qwinsta` takılabildiği için `Start-Job` + `Wait-Job -Timeout` ile çalıştır.

### 2. Düzeltme (kullanıcı onayıyla)
- Politika anahtarı `HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services`:
  - `SelectTransport=1` → RDP yalnız TCP
  - `fSingleSessionPerUser=1` → aynı kullanıcı tek oturum (kullanıcı isteği)
  - `MaxDisconnectionTime=600000` → kopuk oturum 10 dk sonra kapanır (kullanıcı isteği)
- `Restart-Service TermService` zaman aşımına düştü, UmRdpService StopPending'de kaldı →
  her iki servisin PID'i `Stop-Process -Force`, sonra `Start-Service TermService, UmRdpService`. LSM düzeldi.
- `logoff 2; logoff 3` (kopuk oturumlar). Sonuç: yalnız console + rdp-tcp Listen; 3389 erişilebilir.

## Kararlar
- Lokal politika registry ile ayarlandı; domain GPO aynı ayarları tanımlarsa onlar üstün gelir — kalıcılık için
  ileride Default Domain Controllers Policy'ye taşınabilir.

## Açık kalanlar
- Kullanıcının RDP ile bağlanabildiğinin teyidi.
- NLA kapalı → açılması önerilecek. Domain Admin şifresi değişikliği hâlâ bekliyor.
