# bantsayim — 2026-09-29

## Bağlam
Modfex Apparel uygulamalarının GitLab repoları kontrol edildi (6 klasörün hepsi `gitlab.com:modfex-apparel/<ad>`
altında vardı ve senkrondu; "İç Giyim Üretim Planlama Uygulaması" git reposu değil). Hedef: bantsayim'i
Linux'ta çalıştırmak — Ubuntu 26.04 veya daha hafif bir dağıtımda **kiosk**: açılışta yalnızca uygulama,
uygulama kapanınca bilgisayar kapanır, başka yere geçiş PIN korumalı Yönetici düğmesiyle.

## Yapılanlar

### 1. linux-x64 tek dosya paket
- **Neden:** Hedef makinede .NET kurmadan çalışsın.
- **Ne yapıldı:** `BantSayim.Desktop.csproj` içinde `RuntimeIdentifier == linux-x64` koşullu PropertyGroup:
  SelfContained, PublishSingleFile, IncludeNativeLibrariesForSelfExtract, DebugType none.
  `paketle-linux.sh` → `dotnet publish BantSayim.Desktop -c Release -r linux-x64 -o dagitim/bantsayim-linux-x64`,
  linux/ betiklerini + ikon kopyalar, *.pdb siler, `dagitim/bantsayim-linux-x64.tar.gz` (~46 MB) üretir.
  `dagitim/` .gitignore'da.
- **Tuzak:** Windows NTFS büyük/küçük harf duyarsız → `bantsayim.desktop` dosyası `BantSayim.Desktop`
  binary'sinin ÜZERİNE yazıldı (244 bayt binary). Çözüm: menü dosyası adı `modfex-bantsayim.desktop`.
- **Tuzak:** `core.autocrlf=true` → `.gitattributes` ile `*.sh`, `*.desktop` `eol=lf`.
- `Program.cs`: `X11PlatformOptions { WmClass = "bantsayim" }` (.desktop StartupWMClass ile eşleşir);
  `Main` artık `int` döndürür (çıkış kodu kiosk betiğine gider).
- `Ortak/Veri/Ayarlar.cs`: Linux/macOS'ta ayarlar.json `chmod 600` (DPAPI yok, SQL şifresi b64).
- **Dokunulan dosyalar:** `BantSayim.Desktop/*.csproj`, `BantSayim.Desktop/Program.cs`, `paketle-linux.sh`,
  `linux/kur.sh`, `linux/kaldir.sh`, `linux/modfex-bantsayim.desktop`, `.gitattributes`, `.gitignore`

### 2. Kiosk modu (uygulama tarafı)
- **Ne yapıldı:** `Ortak/Kiosk.cs` (namespace Modfex.Ortak): `MODFEX_KIOSK=1` ise aktif; pencere FullScreen;
  çıkış kodları 0=bilgisayarı kapat, 10=yönetici terminali, 11=yeniden başlat;
  PIN doğrulama `/etc/modfex/kiosk-pin` = `tuz:sha256("tuz:pin")` (FixedTimeEquals).
- Kabuk (`KabukView.axaml`/`KabukViewModel.cs`): kiosk'ta ⚙ gizli; üst barda "Yönetici" ve güç simgesi
  (PathIcon — ⏻ karakteri IBM Plex'te yok, kutu çıkıyordu). Katman: kapatma onayı / PIN / yönetici menüsü
  (Ayarlar, Terminal, Yeniden Başlat, Bilgisayarı Kapat). 3 hatalı PIN → 30 sn kilit. PIN kutusuna otomatik odak.
- `OrtakMetinler.cs`: Yonetici, YoneticiPin, PinYanlis, PinBekle, Terminal, YenidenBaslat, BilgisayariKapat, KapatOnay (TR/EN/AR).
- `App.axaml.cs`: `Kiosk.PencereyiAyarla(desktop.MainWindow)`.

### 3. Kiosk kurulum betikleri (Linux tarafı)
- **Dağıtım kararı:** Debian 13 netinst, masaüstü ortamı seçilmeden (SSH + standart araçlar). Ubuntu'da da çalışır.
- `linux/kiosk-kur.sh` (root): PIN sorar (veya `KIOSK_PIN=`); apt: xserver-xorg xinit x11-xserver-utils
  matchbox-window-manager xterm fontconfig fonts-dejavu-core libfontconfig1 libice6 libsm6 libx11-6 libxcursor1
  libxrandr2 libxi6 libicuNN(otomatik bulunur) openssl ca-certificates sudo; `kur.sh`; `kiosk` kullanıcısı
  (şifre kilitli, dialout/video/input/audio); `~kiosk/.bash_profile` tty1'de `exec startx`; `.xinitrc` →
  `/opt/modfex/kiosk/oturum.sh`; sudoers: yalnızca `systemctl poweroff/reboot`; getty@tty1 autologin;
  gdm3/lightdm/sddm disable, multi-user.target; Xorg DontVTSwitch/DontZap/blank kapalı; ctrl-alt-del mask;
  GRUB_TIMEOUT=1 hidden.
- `linux/kiosk-oturum.sh`: xset blank kapalı, matchbox (başlık çubuğu yok), döngü: 0→poweroff, 11→reboot,
  10→xterm (-u8; exit ile uygulama geri gelir), çökme→2 sn sonra yeniden aç; 30 sn içinde 5 çökme→hata terminali.
- `linux/kiosk-kaldir.sh`: ayarları geri alır.

### 4. Doğrulama (Docker, debian:trixie)
- **Komutlar:** paket klasörü container'a mount; systemctl taklidi; `KIOSK_PIN=4321 bash kiosk-kur.sh`;
  Xvfb :1 1366x768; `su kiosk -c 'DISPLAY=:1 /opt/modfex/kiosk/oturum.sh'`; xdotool + ImageMagick import.
- **Sonuç:** Kurulum Debian 13'te hatasız (paket adları doğru). Pencere 1366x768 tam ekran; Türkçe karakterler OK.
  Yanlış PIN → "PIN yanlış"; doğru PIN → menü. Terminal → uygulama kod 10 ile kapandı, xterm açıldı, `exit` →
  uygulama geri açıldı. Güç → onay → sudo üzerinden `systemctl poweroff` çağrıldı. İlk denemede xterm Türkçe
  bozuktu → `-u8` + `LANG=C.UTF-8` ile düzeldi.
- **Commit:** `12dbbae` — Linux (Ubuntu/Debian) paketi ve kiosk modu (gitlab.com:modfex-apparel/bantsayim)

## Kararlar
- Kiosk: tam masaüstü yok; X + matchbox-window-manager. Wayland/cage yerine X (Avalonia X11 backend).
- Çıkış kodu protokolü: 0 kapat, 10 yönetici, 11 yeniden başlat, diğer = çökme → yeniden aç.
- Yönetici PIN'i uygulama ayarında değil, root'a ait `/etc/modfex/kiosk-pin` (640 root:kiosk).
- Kiosk'ta Ayarlar yalnızca yönetici menüsünden (ilk kurulumda bağlantı yoksa ayar ekranı yine açılır).

## Açık kalanlar / sonraki adım
- `Ortak/` değişti (Kiosk.cs, Kabuk, OrtakMetinler, Ayarlar.cs) → depo, paketleme, sevkiyat, bantdurumekrani'ye kopyalanmalı.
- Gerçek donanımda (Debian 13 netinst) uçtan uca deneme: otomatik giriş, poweroff, USB tartı (/dev/ttyUSB0).
- Linux'ta SQL şifresi b64 (dosya 600); gerekirse libsecret/anahtar dosyası.
- Tartı ayarı placeholder'ı "COM3" — Linux'ta /dev/ttyUSB0 olmalı.

---

## Tur 2 — Üretim bant terminali (Sentez ERP) tasarımı

### Bağlam
Yeni görev: PL-001..PL-010 bant kullanıcıları için barkod okutma → 1./2. kalite box → box kapanınca
10 numaralı fiş, SentezCore'a doğrudan SQL. Önce inceleme + brainstorming, kod yok; spec yazıldı.

### 1. SentezCore incelemesi (salt-okuma)
- **Nasıl:** Uygulamanın kendi `ayarlar.json`'ındaki DPAPI şifresi PowerShell `ProtectedData.Unprotect`
  (entropi `Modfex.Ortak.Ayarlar`, CurrentUser) ile `SQLCMDPASSWORD`'a alındı, ekrana basılmadı;
  `sqlcmd -S 192.168.0.2 -d SentezCore -U uzman -C -N -W -s "|"`. Script scratchpad'de (`q.ps1`,
  `powershell -ExecutionPolicy Bypass` şart; yol `cygpath -w` ile verilmeli).
- **Bulgular:** Kesim=ProcessId 167 (1020 kayıt); kesim başlığında WorkOrderId NULL → iş emri
  `Erp_WorkOrderItem.WorkOrderId`; varyant yolu `ProductionVariant.WorkOrderItemVariantId → WorkOrderItemVariant`.
  UZM_FindBarcode / UZM_CreateReceipt* SentezCore'da YOK (SentezCore2026'da var). ReceiptType 10 hiç yok.
  Erp_QualityType boş. FaultyCard 13 kayıt. TRM-01 (1128) günlük Erp_Box açıyor (8 haneli kod).
  15.841 barkod çok şirketli → barkod `Erp_Inventory.CompanyId` ile filtrelenmeli.
  Depo 42 · U · Uretim Depo: yer takibi açık, **yeri yok**.

### 2. Kararlar (kullanıcı)
- Test/geliştirme doğrudan canlı SentezCore (TestModu → `TST` önek + temizle.sql).
- Box kodu `URT{K}-{YYAAGG}-{BANT:000}-{SIRA:0000}`; UD_ kolonları (BoxItem.UD_WorkOrderItemId,
  BoxItemVariant.UD_WorkOrderItemVariantId); farklı iş emri okutulursa box otomatik kapanıp yenisi açılır.
- Hata kartı barkodu `HK`+FaultyCode; 2K modu tek okutmalık; Sil modu var.
- Fiş: tip 10, fiyatsız, **gün+bant** başına tek fiş (SpecialCode `URT-PL-003`), depo 42, 2K aynı depo (QualityTypeId).
- Mantık uygulamada (C# + Dapper transaction, applock), SP değil.
- Bant Kabul ekranları kalıyor → Sentez kullanıcısının Yönetim menüsünde.
- **Dokunulan dosyalar:** `docs/superpowers/specs/2026-09-29-uretim-bant-terminali-design.md`,
  `docs/referans/sentezcore2026-uzm-createreceipt.sql` (kullanıcının yapıştırdığı SP'ler)
- **Commit:** `fd76a4b` — Uretim bant terminali tasarimi (spec) + fis sablonu referansi

### Açık kalanlar
- Kullanıcı spec'i inceleyecek → sonra writing-plans ile uygulama planı.
- Kullanıcı Sentez'de açacak: Erp_QualityType 1./2. Kalite, depo 42 için yer; RecId'ler UZM_Ayar'a.
- Plan görev 1: Erp_InventoryReceiptItem(Variant) kolonlarını SentezCore'da şablonla karşılaştır.
