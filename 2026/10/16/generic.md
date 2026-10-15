# generic — 2026-10-16

## Bağlam
Kullanıcı: bu bilgisayarda en çok internet kullanan 20 uygulamayı, hangi ağdan ne kadar indirme/yükleme yaptığını
gösteren bir pano; ilk 20 dışındakiler tıklanıp detay görülebilsin.

## Yapılanlar

### 1. Veri kaynağı: Windows SRUM
- `C:\Windows\System32\sru\SRUDB.dat` (ESE). Kilitli → yönetici: `esentutl /y ... /vss /d veri\SRUDB.dat`
  (`srum_kopyala.ps1`, UAC; ilk denemede kullanıcı iptal etti, ikincide onaylandı).
- Ağ tablosu `{973F5D5C-1D90-4944-BE8E-24B94231A174}`: AppId, InterfaceLuid, L2ProfileId, BytesSent, BytesRecvd, TimeStamp.
  TimeStamp = OLE tarihi (double) int bit deseni olarak gelir → `struct.pack('<q')/unpack('<d')`.
- `SruDbIdMapTable`: IdType 0 uygulama, 1 hizmet (DoSvc, BITS), 2 mağaza paketi (WhatsApp, Codex), 3 SID.
- **Tuzak:** AppId 1 (blob boş) = arayüz başına TÜM uygulamaların toplamı (1.112 GB vs diğerleri 1.102 GB) → hariç tutulur.
- InterfaceLuid >> 48 = IfType (71 Wi-Fi, 6 Ethernet, 53 VPN/Tailscale). Wi-Fi adı: L2ProfileId = registry
  `HKLM\SOFTWARE\Microsoft\WlanSvc\Interfaces\*\Profiles\{guid}\ProfileIndex` → `C:\ProgramData\Microsoft\Wlansvc\Profiles\Interfaces\*\{guid}.xml` <name>.
- Aynı adlı kimlikler (sürümler) birleştirilir.
- pip bash sandbox'ında ağa çıkamadı (WinError 10051) → PowerShell'den `.venv` içine `dissect.esedb`.

### 2. Pano
- `pano_sablon.html` (bağımsız, CDN yok) + `srum_oku.py` veriyi JSON olarak gömer → `pano.html`.
- İlk 20 yatay yığılmış çubuk (indirme mavi `#2a78d6` / yükleme turuncu `#eb6834`, dataviz paleti slot 1-2), ağ filtresi,
  "Ağlara göre" (tıkla → süz), diğer uygulamalar aranabilir tablo, detay paneli (ağ kırılımı + günlük çizgi, artı imleç),
  tablo görünümü, açık/koyu tema, `#uygulama=<ad>` doğrudan bağlantı.
- Headless Edge ile ekran görüntüsü kontrolü (açık, koyu, detay).
- **Sonuç (18.08–15.10.2026):** 377 uygulama, 14 ağ, ↓1.102,5 GB ↑159,1 GB; steam 452,9 GB, chrome 346,3 GB; ilk 20 = %93,6.
- **Yenileme:** `powershell -File X:\Yazilim\generic\ag-kullanimi\guncelle.ps1`
- **Commit:** yerel repo `X:\Yazilim\generic\ag-kullanimi` (veri/, pano.html, .venv gitignore). **Remote yok.**

## Açık kalanlar
- Remote (GitLab/GitHub) açılıp push edilmesi — kullanıcıya soruldu.

### 3. Anlık (canlı) ağ panosu
- **Neden:** Kullanıcı SRUM panosunu beğendi ("dursun"), anlık olanı istedi. SRUM saatlik yazıldığı için canlı değil.
- **Ne:** `ag-kullanimi\canli` — .NET 10 konsol + `Microsoft.Diagnostics.Tracing.TraceEvent 4.0.0`.
  Özel çekirdek ETW oturumu `AgCanliKernel`, `Keywords.NetworkTCPIP`: TcpIp/UdpIp Send/Recv (+IPv6) → PID, size, saddr/daddr.
  Yerel taraf = makinenin IP'si olan adres (NetworkInterface, 10 sn'de bir yenilenir); Wi-Fi adı `netsh wlan show interfaces` SSID.
  Çoklu yayın/yayın/link-local → "Yerel ağ (yayın)". Loopback hariç. Süreç adına göre gruplanır (chrome'un tüm PID'leri tek satır).
  120 sn halka tampon (toplam + uygulama başına); hız = son 3 sn ortalaması.
- HttpListener `http://localhost:8765/`: `/` (wwwroot/index.html, her istekte diskten), `/api/anlik`, `/api/uygulama?ad=`.
- `app.manifest` requireAdministrator → UAC. Başlatma: `canli-baslat.cmd` (önce derler, sonra başlatır).
- Pano: SRUM panosuyla aynı görünüm; mod "Şu anki hız / Başlangıçtan beri", ağ filtresi, son 2 dk çizgi + imleç,
  ilk 20, ağlar, diğerleri, detay (canlı grafik, ağ kırılımı, en çok konuştuğu 15 uzak adres:port).
- **Doğrulama:** `curl -o NUL https://speed.cloudflare.com/__down?bytes=20000000` → curl.exe ↓ **20,0 MB**, ağ Orange_347F_5G. ✔
  Headless Edge ekran görüntüsü kontrol edildi.
- **Not:** Çalışan yönetici süreci normal kullanıcıdan kapatılamıyor (Access denied) → pencereyi kullanıcı kapatır.
- **Commit:** yerel repo (remote yok).
