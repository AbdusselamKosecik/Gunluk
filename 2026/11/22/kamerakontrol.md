# kamerakontrol — 2026-11-22

## Bağlam
Kullanıcı: "Bir repository proje açar mısın Kamera Kontrol diye".

## Yapılanlar

### 1. Repo açıldı
- **Ne yapıldı:** `X:\Gitlab\modfex-apparel\kamerakontrol` klasöründe `git init -b main` yapıldı ve README eklendi. Diğer modfex projeleri gibi GitLab'daki `modfex-apparel` grubuna push edildi. GitLab projeyi push sırasında **private** olarak oluşturdu.
- **Remote:** `git@gitlab.com:modfex-apparel/kamerakontrol.git`, web: https://gitlab.com/modfex-apparel/kamerakontrol
- **Komutlar:**
  ```bash
  mkdir kamerakontrol && cd kamerakontrol && git init -b main
  git add README.md && git commit -m "İlk commit"
  git remote add origin git@gitlab.com:modfex-apparel/kamerakontrol.git && git push -u origin main
  ```

## Açık kalanlar
- Kapsam henüz tanımlanmadı (hangi kameralar, ne kontrol edilecek, hangi platform).

---

## Bağlam (öğleden sonra)
Kullanıcı: "kamera sistemlerinin IP'sini gireceğiz, kanalları listeleyeceğiz; kameralar üzerinde çizim yapacağız, oraya
insan girince bildirim, elimizdeki yüzlerle yüz tanıma. Önce bir Windows servis ve bir yönetim paneli lazım." Soru-cevap
yerine "yapalım" dedi → doğrudan temel kuruldu. Kapsam: **1. aşama** (servis + panel + kanal listeleme + bölge çizimi).

### 2. Mimari ve proje iskeleti
- **Neden:** Kardeş projelerle (ServisPlanlama, FortiSyslog) aynı düzen → bakım ve kurulum aynı.
- **Ne yapıldı:** Tek ASP.NET Core (.NET 10) uygulaması, `UseWindowsService` ile servis; API + panel (wwwroot, düz JS)
  aynı süreçte, port **8088** (8086 başka projelerde dolu). MSSQL + Dapper. `db/tablolar/*.sql` her açılışta idempotent
  uygulanır (ServisPlanlama'daki `Depo.TablolariKurAsync` kalıbı). Çerez kimlik doğrulama, roller: `yonetici`, `izleyici`.
- **Tablolar:** `Kullanici`, `Cihaz` (parola `varbinary` şifreli), `Kanal` (UQ CihazId+No, `Mevcut` bayrağı), `Bolge`
  (`Noktalar` = JSON `[[x,y],...]` 0..1 oransal, `Kural`='insan-girisi'). FK'ler ON DELETE CASCADE.
- **Dokunulan dosyalar:** `KameraKontrol.slnx`, `Directory.Packages.props`, `db/000_veritabani.sql`,
  `db/tablolar/001_kullanici.sql`, `002_cihaz.sql`, `src/KameraKontrol/{Program.cs,Ayarlar.cs,appsettings.json}`,
  `Veri/{Depo,KullaniciDeposu,CihazDeposu}.cs`, `Kimlik/{Parola,Sifreleyici}.cs`, `Api/*.cs`
- **Komutlar:**
  ```bash
  sqlcmd -S <sunucu> -U <kullanici> -C -i db/000_veritabani.sql   # KameraKontrol DB (Turkish_100_CI_AS)
  dotnet build KameraKontrol.slnx
  ```
- **Not:** SqlClient 6.1.1, System.Security.Cryptography.Pkcs 9.0.4'ü (açıklı) dolaylı getiriyor →
  `CentralPackageTransitivePinningEnabled` + Pkcs 10.0.13 sabitlendi.

### 3. Cihaz sürücüleri (Hikvision / Dahua / ONVIF)
- **Neden:** Marka bilinmiyordu; NVR'lar marka API'si ile daha zengin bilgi verir, ONVIF ortak yedek.
- **Ne yapıldı:** `ICihazSurucusu { TaniAsync, KanallarAsync }`. Otomatik algılama sırası Hikvision → Dahua → ONVIF;
  bulunan marka `AlgilananMarka`ya yazılır ve sonra önce o denenir.
  - Hikvision: `/ISAPI/System/deviceInfo`, `/ISAPI/ContentMgmt/InputProxy/channels` (+`/status`), yoksa
    `/ISAPI/System/Video/inputs/channels`; görüntü `/ISAPI/Streaming/channels/{n}01/picture`; RTSP `/Streaming/Channels/{n}01|02`.
  - Dahua: `magicBox.cgi?action=getSystemInfo`, `configManager.cgi?action=getConfig&name=ChannelTitle` (0 tabanlı → +1),
    `LogicDeviceManager.cgi?action=getCameraState`; `snapshot.cgi?channel=n`; `/cam/realmonitor?channel=n&subtype=0|1`.
  - ONVIF: SOAP 1.2 + WS-Security UsernameToken PasswordDigest = Base64(SHA1(nonce+created+parola)), `created` cihaz
    saatine göre (GetSystemDateAndTime farkı). GetCapabilities→Media XAddr, GetProfiles → SourceToken'a göre grupla
    (ana = en yüksek çözünürlük, alt = en düşük), GetStreamUri/GetSnapshotUri. Cihazın bildirdiği iç IP bağlanılan adresle değiştirilir.
  - HTTP Digest/Basic: `SocketsHttpHandler { Credentials = NetworkCredential, PreAuthenticate = true }`.
    `BaglantiHavuzu`: cihaz başına tek HttpClient (anahtar adres|port|kullanıcı|SHA256(parola)).
  - Ayrıştırıcılar ağdan bağımsız static sınıflar (`HikvisionAyristirici` vb.) → test edilebilir.
- **Dokunulan dosyalar:** `src/KameraKontrol/Cihazlar/*.cs`
- **Hata düzeltmeleri (test sırasında bulundu):**
  1. Yanlış parolada otomatik algılama ONVIF'e geçip onun 501 hatasını gösteriyordu → durum kodlu `HttpRequestException`
     "bu marka değil" sayılıp sıradakine geçiliyor; sonunda "parola kabul edilmedi" dönüyor.
  2. Anlık görüntüde havuzdaki ölü keep-alive bağlantısı arada hata veriyordu → aktarım hatasında (durum kodu yok,
     SocketException değil) bir kez yeniden deneme.

### 4. Parola şifreleme
- **Karar:** DPAPI değil, **AES-256-GCM + appsettings anahtarı** (`KameraKontrol:SifrelemeAnahtari`, base64 32 bayt).
  **Neden:** Geliştirme ve sunucu aynı SQL sunucusunu paylaşabiliyor; DPAPI makineye bağlı, öbürü çözemezdi.
  Biçim `[12 nonce][16 tag][şifreli]`. Anahtar değişirse cihaz parolası yeniden girilir (anlaşılır hata mesajı var).

### 5. Arka plan + panel
- `Isciler/DurumYoklayici`: `PeriodicTimer`, `YoklamaDakika` (5) aralıkla aktif cihazları eşitler.
- Panel: `index.html` sekmeler Kanallar / Cihazlar / Kullanıcılar. Kanal ızgarası — yalnız ekranda görünen kartların
  görüntüsü yenilenir (IntersectionObserver; 64 kanal NVR'ı yormasın). `bolge.js`: SVG viewBox = görüntünün gerçek
  piksel boyutu, noktalar oransal; kipler bos/ciz/duzenle; ilk noktaya tıkla/çift tık/Enter kapatır, Backspace geri,
  Esc vazgeç, köşe sürükleme. Cihaz diyaloğunda "Bağlantıyı dene" (kaydetmeden; düzenlemede boş parola = kayıtlı parola).

### 6. Test ve doğrulama
- `dotnet test` → **23/23 geçti** (Hikvision/Dahua/ONVIF ayrıştırıcıları, ONVIF çekirdek belirtimi digest örneği
  `tuOSpGlFlIXsozq4HFNeeGeFLEI=`, AES-GCM, bölge/adres doğrulama).
- `tools/sahte_nvr.py` (Python, PIL) sahte Hikvision NVR ile API uçtan uca + Chrome DevTools ile panel: bölge çiz,
  kapat, kaydet, köşe sürükle → sunucuda doğru noktalar; konsol hatası yok.
- **Gerçek cihazlar** (kullanıcı verdi; Hikvision, Digest):
  - 192.168.0.245 → DS-7632NXI-K2(D), V4.84.101, 32 kanal (31 çevrimiçi), kameralar 192.168.40.x
  - 192.168.0.244 → DS-7732NXI-K4, V4.83.010, 32 kanal, kameralar 192.168.10.x; **RTSP 554 kapalı** (80, 8000 açık)
  - Anlık görüntü ~0.4 sn, 704×576 JPEG. İki cihaz **geliştirme anahtarıyla** DB'ye kayıtlı bırakıldı (64 kanal);
    test kullanıcısı silindi → ilk girişte yönetici oluşturulacak.
- Kanal adlarının neredeyse hepsi "Camera 01" (kameraların fabrika adı, NVR'da değiştirilmemiş).

### 7. Kurulum betikleri
- `deploy/yayinla.ps1` (publish + zip, denendi), `deploy/servis-kur.ps1` (ServisPlanlama'dan uyarlandı; ek olarak
  `SifrelemeAnahtari` boşsa üretip yazar). PS 5.1 için UTF-8 BOM eklendi, sözdizimi denetlendi.
- **Commit:** `5323b8e` — Temel: Windows servis + yönetim paneli, NVR kanal listeleme, bölge çizimi

## Kararlar
- Tek süreç (servis + panel), port 8088, MSSQL `KameraKontrol`.
- Bölge noktaları oransal (0..1); kanal silinmez `Mevcut=0` (bölgeler korunur).
- Parola AES-GCM + yapılandırma anahtarı; dev ve prod aynı DB'yi kullanacaksa **aynı anahtar**.

## Açık kalanlar / sonraki adım
- Sunucuya kurulum: prod `appsettings.Production.json`'a dev'deki `SifrelemeAnahtari` konmalı (yoksa 2 NVR'ın parolası yeniden girilir).
- .244'ün RTSP portu öğrenilmeli (algılama için gerekecek).
- Panelde kanala yerel ad verme ("Camera 01" yerine "Kesimhane 3").
- **2. aşama:** RTSP alt akış → FFmpeg kare → ONNX Runtime + YOLO insan tespiti, ayak noktası çokgen içinde mi,
  cooldown, olay kaydı + kare, bildirim kanalı seçimi (panel / e-posta / Telegram / WhatsApp?).
- **3. aşama:** yüz tanıma (SCRFD + ArcFace ONNX), kişi/yüz kaydı. **KVKK**: açık rıza, aydınlatma, saklama süresi.

### 8. Yüz verisi kaynağı ve rıza (12:50)
- **Kullanıcı:** Tüm izinler yazılı alındı; PDKS için alınan biyometrik yüzlerin kamera sisteminde kullanımı için de açık
  rıza alındı (Mısır'da zorunlu olmadığını düşünüyorlar; not: Mısır 151/2020 Kişisel Veri Kanunu biyometriyi hassas sayar,
  alınan yazılı rıza bunu karşılıyor).
- **Keşif (yalnız şema/sayı, kişisel veri çekilmedi):** `zkbiotime.dbo.iclock_biophoto` → 821 onaylı (`approval_state=3`)
  kayıt fotoğrafı, `register_photo` = `<guid>.jpg` (dosya BioTime sunucusunda, DB'de değil). `iclock_biodata`: bio_type 9
  (görünür ışık yüz, v39) 828, parmak izi (1) 24, tür 8 61 — ZK'ya özel şablon, kullanılamaz. `personnel_employee.photo`
  = `photo/<pin>.jpg`, 360 aktif personelin 338'inde var.
- **Karar:** 3. aşamada yüz kaynağı BioTime biophoto JPG'leri (ArcFace ile vektöre çevrilecek); yeniden fotoğraf yok.
- **Açık:** JPG dosyalarına erişim yolu (BioTime sunucusundaki klasör/paylaşım ya da BioTime web üzerinden).
- **Commit:** README güncellendi.
