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

### 9. BioTime sunucusu ve yüz fotoğraflarının yeri (12:55)
- Kullanıcı önce 192.168.0.3 dedi: orası **etki alanı denetleyicisi + dosya sunucusu** (NETLOGON/SYSVOL, `Modfex Data`),
  BioTime yok. Sonra **192.168.0.2** dedi → doğru: `modfexsrv` (Tailscale 100.119.104.122 ile aynı makine; SQL 1433, 80/81 "Modfex İşlem Merkezi").
- `\192.168.0.2\C$` altında 4 kurulum: `ZKBioTime`, `ZKBioTime9.4` (boş), `ZKBioTimeOrj` (eski, 540 foto, 2025-10),
  **`ZKBioTime1` (kullanımda)** → `auth_files\biophoto\<sicil>.jpg`, düz klasör, 1160 dosya, bugün de güncellenmiş.
  (DB'deki `register_photo` GUID adları diskteki adlarla eşleşmiyor; disk sicil no ile.)
- Eşleşme: 1160 dosyanın 825'i personele bağlı; **360 aktif personelin 341'inin fotoğrafı var**.
- **Engel:** Dosyalar JPG değil, **BioTime tarafından şifreli** — hepsi `65 61 76 31 30 31 24` = `eav101$` başlığıyla
  başlıyor, sonraki bloklar dosyalar arasında aynı (deterministik şifreleme). GDI açamıyor.
- **Karar:** BioTime şifresi kırılmayacak (üretici korumasını aşmak + her güncellemede kırılır). Fotoğraflar BioTime'ın
  kendi REST API'si üzerinden alınacak: `ZKBioTime1\attsite.ini` → web `Port=8088`; `POST http://192.168.0.2:8088/api-token-auth/`
  boş gövdeye 400 döndü (uç var). Salt okunur BioTime API kullanıcısı gerekiyor (kullanıcıdan istenecek).
- **Port çakışması düzeltildi:** BioTime 8088 kullanıyor → KameraKontrol **8090**'a alındı
  (`appsettings.json`, `deploy/servis-kur.ps1`, README). Komut: yalnız ini'den port satırları okundu (parola satırları süzüldü).
- **Commit:** `b4fea1a` — Port 8090'a alındı (8088 BioTime'ın portu); yüz kaynağı ayrıntıları README'de

## Açık kalanlar (güncel)
- BioTime API kullanıcısı (salt okunur) → API'nin biyo-fotoğrafı çözülmüş verip vermediği doğrulanacak.
- Bildirim kanalı seçimi (panel / e-posta / Telegram / WhatsApp).
- .244 RTSP portu; kanal yerel adları.

### 10. İnsan algılama + olaylar + OnayMerkezi bildirimi (13:00–13:30)
- **İstek:** "http://192.168.0.245/ D10 D3 D1 de çalışalım şimdilik". Bildirim: "bizim bildirim sistemimiz vardı oradan
  göndereceğiz" → **OnayMerkezi** (`onaymerkezi` reposu; 192.168.0.2:8087, `POST /api/olay` + `X-Api-Anahtari`, görsel ≤5 MB,
  `GerekenOnay=0` türleri Telegram'a butonsuz bildirim). Model indirme izni alındı.
- **Kanallar:** NVR 245 D1 (avlu/kulübe, kamera 192.168.40.25), D3 (konteyner deposu, .26), D10 (ana kapı, .20); hepsi dış alan,
  704×576. DB'de yalnız bu üçü `Izlenir=1`, diğer 61 kanal 0.
- **Model:** `yolox_s.onnx` 35,8 MB, Megvii resmî GitHub 0.1.1rc0, Apache-2.0 (Ultralytics YOLO AGPL olduğu için seçilmedi),
  SHA-256 `c5c2d13e…8063`. Git dışı: `modeller/README.md` (kaynak + hash), csproj varsa çıktıya/yayına kopyalar.
  Giriş 640×640 **BGR** 0-255 normalize yok, sol üst letterbox dolgu 114; çıkış [1,8400,85], obj/cls sigmoid'li, ızgara
  çözümü bizde (adım 8/16/32). **Doğrulama:** RGB verince 10→4 kişi (BGR doğru); kutular çizdirilip gözle kontrol edildi.
  Fabrika içi kalabalıkta (masa arkasında oturanlar) bazılarını kaçırıyor → eşik 0,5 yerine **0,35**; dış kameralarda 0 yanlış pozitif.
  Hız: CPU'da ~50-80 ms (kare alma dahil ~300 ms).
- **Mimari kararlar:**
  - Kare kaynağı = NVR ISAPI anlık görüntü (RTSP/FFmpeg yok; 3 kanal 1 fps için yeterli).
  - Bölgeye giriş = **kutunun alt ortası (ayak)** çokgende (ray casting).
  - `AlarmTakibi`: 2 ardışık kare → alarm; bölge dolu kaldıkça **tek olay**; 30 sn boş → olay kapanır; aynı bölge en az 5 dk ara.
  - `AlgilamaIscisi`: 30 sn'de bir DB'den hedef tazeleme, kanal başına ayrı Task; hata sürerse geri çekilme (≤30 sn), günlükte ilk ve her 60. hata.
  - `Olay` tablosu (kutuları çizili JPEG `Kare`), BolgeId FK'siz (SQL Server çoklu cascade yolu), 90 gün saklama.
- **Dokunulan dosyalar:** `src/KameraKontrol/Algilama/{InsanAlgilayici,Geometri,AlarmTakibi,KareCizici,AlgilamaIscisi}.cs`,
  `Bildirim/OnayMerkeziIstemcisi.cs`, `Veri/OlayDeposu.cs`, `Api/OlayUclari.cs`, `Ayarlar.cs` (Algilama, OnayMerkezi),
  `db/tablolar/003_olay.sql`, `wwwroot/{index.html,panel.js,bolge.js,panel.css}`, `tests/.../{AlgilamaTests,OnayMerkeziTests}.cs`,
  `tools/sahte_nvr.py` (2. argüman: 1. kanal verilen fotoğrafı döner), `deploy/*`. Paketler: Microsoft.ML.OnnxRuntime 1.31.1, SkiaSharp 3.119.4.
- **Komutlar:**
  ```bash
  curl -L -o modeller/yolox_s.onnx https://github.com/Megvii-BaseDetection/YOLOX/releases/download/0.1.1rc0/yolox_s.onnx
  KK_MODEL=modeller/yolox_s.onnx KK_ORNEK=<insanli.jpg> KK_EN_AZ=8 dotnet test   # 39/39
  python tools/sahte_nvr.py 18080 <insanli.jpg>
  ```
- **Uçtan uca sonuç:** Sahte NVR (fabrika karesi) → olay 1, 10 kişi, sürekli görünmesine rağmen tekrar olay yok (kural çalışıyor).
  **Gerçek:** olay 2 D10 ana kapı önünde yürüyen kişi (güven %88), olay 3 D1 avluda el arabası çeken kişi (%65) — ikisi de doğru.
  Panel Olaylar sekmesi tarayıcıda denetlendi, konsol hatası yok.
- **Bırakılan durum:** D1/D3/D10'da geçici bölgeler "Avlu (deneme)", "Konteyner alani (deneme)", "Ana kapi (deneme)" + olay 2, 3.
  Sahte cihaz ve test kullanıcısı silindi.
- Not: NVR saati sunucudan 1 saat geri görünüyor (NVR 12:17, geliştirme makinesi TR saati 13:17) — Mısır sunucusunda kontrol edilmeli.
- **Commit:** `92f8e74` — İnsan algılama + olaylar + OnayMerkezi bildirimi

## Açık kalanlar (güncel)
- OnayMerkezi: panelde `kamera-alarm` olay türü (Gereken onay = 0, Telegram grubu) + KameraKontrol için API anahtarı →
  `appsettings` `KameraKontrol:OnayMerkezi:ApiAnahtari`.
- D1/D3/D10 bölgelerini gerçek ihtiyaca göre yeniden çiz / adlandır.
- Sunucuya kurulum (192.168.0.2, port 8090; dev şifreleme anahtarı prod'a taşınmalı; model dosyası pakete girer).
- BioTime API kullanıcısı (yüz tanıma); .244 RTSP portu; kanal yerel adları.

### 11. OnayMerkezi bağlandı, Telegram'a ilk bildirimler (14:00)
- OnayMerkezi zaten kurulu: `http://192.168.0.2:8087` (SentezCore `UZM_` tabloları). Salt okunur kontrol: Telegram grupları
  "Modfex Onay", "Modfex Bildirim"; olay türü/uygulama yoktu. Kullanıcı panelden açtı: tür `kamera-alarm` (Kamera alarmi,
  GerekenOnay 0, grup **Modfex Bildirim**, aktif); uygulama kaydı (kodu yanlışlıkla `kamera-alarm` girilmiş — işlevsel engel değil).
- Anahtar (`om_…`) yalnız `src/KameraKontrol/appsettings.Development.json` (git dışı) → `KameraKontrol:OnayMerkezi:ApiAnahtari`.
  Kullanıcı anahtarı sohbete yapıştırdı; isterse OnayMerkezi'nde pasif yapıp yenilenebilir.
- **Yeni:** `POST /api/kanal/{id}/deneme-bildirim` (yönetici) + bölge ekranında "Deneme bildirimi" düğmesi: anlık kareyi
  `🧪 Deneme — <cihaz> D<no>` olarak gönderir, olay açmaz. **Commit:** `0883229`.
- **Sonuç:** OnayMerkezi olay 3 (deneme, D10) → Durum 5 Bildirildi, Telegram MesajId 48 ✅. Hemen ardından 3 GERÇEK alarm
  (olay 6/7/8 → OnayMerkezi 4/5/6, MesajId 49-51): saat 14:01 mola/vardiya — Ana kapı 4, Avlu 10, Konteyner 20 kişi;
  algılamalar doğru (bölge dışı sarı, içi kırmızı).
- **Sorun:** Mesai saatinde avlu sürekli dolu → tüm avluyu kaplayan "(deneme)" bölgeleri 5 dk'da bir alarm üretir, Telegram
  grubunu boğar. Geliştirme makinesindeki servis **durduruldu** (gruba mesaj gitmesin). Test kullanıcısı silindi.
- **Karar bekleniyor:** alarm ne zaman / kime anlamlı? (mesai dışı zaman çizelgesi, kısıtlı küçük bölgeler, kişi sayısı eşiği, yüz tanıma ile çalışanları eleme)
