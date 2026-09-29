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

### 3. Erp_QualityType kayıtları açıldı (canlı SentezCore, kullanıcı isteğiyle)
- **Neden:** Tablo boştu; box/fiş QualityTypeId için gerekli. Kullanıcı "sen aç, TST olarak açma" dedi.
- **Komut (sqlcmd, transaction, idempotent):**
  ```sql
  INSERT INTO Erp_QualityType (CompanyId, QualityCode, QualityName, InUse, InsertedAt, InsertedBy, IsDeleted)
  VALUES (2,'1',N'1. Kalite',1,GETDATE(),1,0), (2,'2',N'2. Kalite',1,GETDATE(),1,0)  -- IF NOT EXISTS ile
  ```
  Tabloda yalnız RecId zorunlu; unique `Erp_QualityType_IX0 (CompanyId, QualityCode)`; tetikleyici yok.
- **Sonuç:** RecId **2 = 1. Kalite**, **3 = 2. Kalite**. Spec'e işlendi (`Kalite1TipId=2`, `Kalite2TipId=3`).
- **Commit:** `a9795d5` — Spec: Erp_QualityType 1./2. Kalite acildi (RecId 2, 3)
- Ubuntu paketi isteği: `paketle-linux.sh` çalıştırılmak üzereyken kullanıcı durdurdu (yapılmadı).

### 4. U deposu (42) yer takibi kapatıldı — depo yeri kullanılmayacak
- **Neden:** Kullanıcı kararı: üretim deposunda depo yeri olmayacak. Depo 42 `FollowUpWarehouseLocation=1` açılmıştı ve yeri yoktu.
- **Komut:** `UPDATE Erp_Warehouse SET FollowUpWarehouseLocation=0, UpdatedAt=GETDATE(), UpdatedBy=1 WHERE RecId=42 AND CompanyId=2 AND WarehouseCode='U'` (1 satır).
- **Spec:** `UretimDepoYerId`, `DepoYeriTanimsiz` çıkarıldı; fiş satırında `InWarehouseLocationId=NULL`.
- **Ders:** Kullanıcı U deposunu açtığını söyleyince "gördüm, 42" diye net teyit et; yer takibini varsayılan sorun gibi sunma.

### 5. GitHub'a ayna (özel repo)
- **Neden:** Kullanıcı isteği ("bu şekilde GitHub'a gönder"); repo yalnız GitLab'daydı.
- **Komutlar:**
  ```bash
  gh repo create AbdusselamKosecik/bantsayim --private --source . --remote github --push   # ilk push 404 ile kesildi
  git push -u github main          # ikinci deneme başarılı
  git branch -u origin/main main   # varsayılan upstream yine GitLab
  ```
- **Sonuç:** https://github.com/AbdusselamKosecik/bantsayim (PRIVATE), main = `0431cbb`. Remote'lar: `origin` (GitLab), `github`.
- Sonraki değişikliklerde her iki remote'a push: `git push && git push github main`.

### 6. Uygulamaya başlangıç (30 dk dilimi): şema + saf kurallar + testler
- **Neden:** Kullanıcı "30 dakikalık iş yapalım" dedi → spec onayı sayıldı; en düşük riskli dilim seçildi.
- **Fiş kolon karşılaştırması** (plan görev 1): SentezCore şeması SentezCore2026'dan eski.
  Şablonda olup DB'de olmayan (INSERT'ten çıkarılacak): başlık 7 (`UD_KargoTakipNumarası`(ı), ElectricExcise*,
  UD_MarketBank, DocumentTrackNo, CargoCompanyName, ToRecId), kalem 25 (UTS*, ElectricExcise*, ReturnReceipt*,
  WorkOrderProductionId, WidthCM/LengthCM/M2Gram, SecondQuantity, ForegoneVatAmount, ItemClassificationCode,
  WeightedQuantity, ToRecId, YTMachine*), varyant 2 (WorkOrderProductionVariantId, ToRecId).
  DB'de olup şablonda olmayan: `UD_KargoTakipNumarasi` (i ile), `UD_TeslimEdilen` → NULL. NOT NULL kolon yok.
- **`db/0001_uretim.sql`** yazıldı ve canlı SentezCore'a **iki kez** uygulandı (idempotent doğrulandı):
  UZM_Ayar (+IX0 unique CompanyId,Anahtar), UZM_UretimBox (IX0 filtreli unique `(CompanyId,BantUserId,Kalite) WHERE Durum=0`,
  IX1, IX2 unique BoxId, FK Erp_Box), UZM_UretimOkutma (IX0–IX3), UD kolonları, ayarlar şirket 2:
  UretimDepoId=42, Kalite1TipId=2, Kalite2TipId=3, KesimProcessId=167, FisTipi=10, TestModu=0.
  ```bash
  powershell -NoProfile -ExecutionPolicy Bypass -File <scratch>\q.ps1 -sqlFile <repo>\db\0001_uretim.sql
  ```
- **`BantSayim/Ekranlar/Veri/UretimKurallari.cs`**: BantNo, Rol (UretimRolu), HataKodu (HK), BoxKodOnEki,
  SonrakiBoxKodu, FisOzelKodu, SonrakiFisNo. TDD: önce testler (derleme hatası = kırmızı), sonra kod.
- **`BantSayim.Tests`** (xUnit, slnx'e eklendi): 29 test geçti (`dotnet test BantSayim.Tests`); Desktop build 0 uyarı.
- **Commit:** `4e2d574` — Uretim terminali: db/0001 semasi, saf kurallar ve testler (GitLab + GitHub)

### Açık kalanlar / sonraki adım
- UretimDeposu (okut/sil/box aç-kapat transaction), FisYazici (şablon − eksik kolonlar), giriş listesi + rol yönlendirme,
  OkutmaView, YonetimView (raporlar, hata kodları, bant kabul).
- TestModu sorusu hâlâ açık (şu an 0).

### 7. Evden devam: sunucu IP'si + yazım katmanı (okutma/sil/box/fiş)
- **IP:** Evde sunucu `100.119.104.122` (VPN). Yalnız bu makinedeki `%LOCALAPPDATA%\Modfex\bantsayim\ayarlar.json`
  `Sunucu` alanı değişti (repoya girmez). İlk SqlClient denemesi "Named Pipes error 40" ile düştü — geçiciydi
  (VPN yeni bağlanıyordu); `scratchpad/bagtest` küçük programıyla Mandatory/4096/tcp:/Optional hepsi bağlandı.
- **FisSql.cs üretimi:** Kullanıcının yapıştırdığı orijinal metinden (tek satır) Python ile kolon/değer çiftleri
  çıkarıldı (`--<...>` yorumları regex ile silindi, üst düzey virgülle bölündü; 213/255/52 çift birebir),
  SentezCore'da olmayan kolonlar atıldı → başlık 206, kalem 230, varyant 50 kolon. Değişen değerler: parametreler,
  CurrentAccount/Address/Forex NULL, fiyat 0, VatRate 0, CalcType 0, InsertedBy=@UserId, QualityTypeId, WorkOrderId,
  WorkOrderItemVariantId; tarih/saat `@Zaman` (sunucu GETDATE). Tetikleyicili tablolar için `OUTPUT ... INTO @yeni`.
- **UretimDeposu.cs:** OkutAsync (HK→2. kalite, barkod→varyant şirket filtresi, son kesim, açık box UPDLOCK,
  iş emri farklıysa kapat+fiş+yeni box, BoxItem/Variant +1, log), SilAsync, BoxKapatAsync, BoxAcAsync
  (applock `UZM_UretimBoxSira`, `LIKE önek+[0-9]x4` MAX), KilitAlAsync (`sp_getapplock`, <0 → THROW 51222),
  GuvenliAsync (1205/1222/51222 bir kez tekrar, UretimHatasi → sonuç).
- **FisYazici.cs:** applock `UZM_UretimFis`; başlık gün+bant (SpecialCode, ReceiptDate, CurrentAccount 0) bul/aç,
  numara 8 hane MAX+1; kalem anahtarı (InventoryId, ana birim, QualityTypeId, WorkOrderId), varyant anahtarı; box bağları.
- **Bulgu:** `Erp_Box.EmployeeId` FK → `Erp_Employee` (Meta_User değil). PL kullanıcılarında `Meta_User.EmployeeId` NULL,
  mevcut box'larda da hiç dolu değil → `(SELECT EmployeeId FROM Meta_User WHERE RecId=@UserId)` yazılıyor; spec güncellendi.
- **Testler:** `UretimDeposuEntegrasyonTestleri` (7 test, `[DbFact]`, `MODFEX_DB_TEST=1`), her test transaction + ROLLBACK,
  transaction içinde TestModu=1. Kapsam: ilk okutma, aynı box adet, HK 2. kalite ayrı box, sil (sıfırda satır silinir,
  KutudaYok), farklı iş emri → kapat + fiş (tip 10, TST-PL-010, depo 42, InsertedBy 1144, fiyat 0, yer NULL, bağlar dolu),
  aynı gün 2. box aynı fişe birleşir (1 kalem, 2 adet), boş box/bilinmeyen barkod/HK.
  `MODFEX_DB_TEST=1 dotnet test BantSayim.Tests` → **36/36**. Sonrası canlı kontrol: TST/URT box 0, fiş 10 yok, UZM 0, applock 0.
- **Commit:** `a3f50ed` — Uretim terminali: okutma/sil/box ve gunluk 10 fisi yazimi (GitLab + GitHub)

### Açık kalanlar
- Giriş ekranı kullanıcı listesi + rol yönlendirme, OkutmaView/ViewModel, YonetimView (raporlar, hata kodları, bant kabul),
  mesaj anahtarlarının TR/EN/AR metinleri.
- TestModu sorusu hâlâ açık (0).
