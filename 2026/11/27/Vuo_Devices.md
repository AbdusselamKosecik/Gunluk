# Vuo_Devices + Vuo_Device_Emulator — 2026-11-27

## Bağlam
Kullanıcı iki yeni proje istedi.
- **Vuo_Devices**: Rust ile yazılacak UDP servisi. Referans: `X:/Gitlab/fredericTr/localserver/TechtsioService/TechtsioService`.
- **Vuo_Device_Emulator**: `UDPEmulator` (WinForms, netcoreapp3.1) uygulamasının "aynen" .NET 10 WPF'e taşınması.

İstenen davranış: cihazdan gelen OK'a cevap verilmeyecek; diğer her pakete `VERI-OK` ve dakika:saniye gönderilecek; servis aynı portta çalışacak.

## Yapılanlar

### 1. Rust araç zinciri
- **Neden:** makinede Rust ve MSVC Build Tools yoktu. GNU hedefi Build Tools gerektirmediği için RAM ve disk tasarrufu sağlıyor.
- **Komutlar:**
  ```bash
  curl -sSfL -o rustup-init.exe https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe
  ./rustup-init.exe -y --default-host x86_64-pc-windows-gnu --default-toolchain stable --profile minimal
  ```
- **Sorun:** chrono, `windows-link` (raw-dylib) üzerinden `dlltool.exe` istedi; GNU minimal kurulumda bu araç yok. Çözüm: chrono kaldırıldı, yerel saat `GetLocalTime` FFI ile okunuyor (`src/clock.rs`). Proje sıfır bağımlılıklı.

### 2. Vuo_Devices (Rust)
- **Repo:** github.com/vuo-app/Vuo_Devices (özel), dal `main`, yerel `X:/GitHub/vuo-app/Vuo_Devices`.
- **Protokol** (TechtsioService `WifiServer` ve `Uts23Service.SendDisplay/SendData` kodundan çıkarıldı):
  - Cihazdan gelen paket: `+IPD,56:SND=<mac>;...<CRC2>\n\r`.
  - OK paketi: `SND=<mac>;OK;`. Eski biçim: `+IPD,30:OK;<mac>`.
- **Davranış:**
  - `classify()`: OK paketine cevap yok.
  - Diğer her pakete `SND=` + `VERI-OK` (16 karaktere tamamlanmış) + `mm:ss` (16) + `;????`×10 + `\r\n`.
  - `????` alanları eski emülatörün `LoadData`'sının hata vermemesi için eklendi; cihazdaki değerleri değiştirmez.
- **Kritik karar:** cevap, dinlenen soketten (`send_to`) gönderiliyor. Emülatör ve cihaz sunucuya `Connect` edilmiş UDP soketi kullandığından başka porttan gelen paketi almaz. TechtsioService'in `SendDisplay`'i her cevapta yeni bir UdpClient açıyordu.
- **Port:** varsayılan 85 (TechtsioService `WifiPort`). Değiştirmek için ilk argüman veya `VUO_DEVICES_PORT`.
- **Windows'a özgü önlem:** `WSAECONNRESET` alındığında döngü durmuyor, devam ediyor.
- **Dosyalar:** `src/main.rs`, `src/lib.rs`, `src/protocol.rs`, `src/clock.rs`, `tests/udp_roundtrip.rs`, `README.md`.
- **Doğrulama:** `cargo test` 9/9 geçti: 7 protokol, 1 saat, 1 uçtan uca test (binary boş bir portta başlatılıyor; connect edilmiş soket VERI-OK alıyor, OK'a cevap gelmiyor, servis çalışmaya devam ediyor). Release exe 1.2 MB.
- **Commit:** `137d62b` — feat: Vuo_Devices UDP servisi

### 3. Vuo_Device_Emulator (.NET 10 WPF)
- **Repo:** github.com/vuo-app/Vuo_Device_Emulator (özel), dal `main`.
- **Yapı:** `Vuo_Device_Emulator.slnx`.
  - `src/VuoDeviceEmulator.Core` (net10.0): `Protocol`, `DeviceData`, `DeviceService`, `MoqRunner`, `MoqSeed`.
  - `src/VuoDeviceEmulator` (net10.0-windows, WPF).
  - `tests/VuoDeviceEmulator.Tests` (xUnit).
- **Birebir taşınanlar:**
  - Butonlar: Send OK, Sayaç Arttır ve Gönder (&OK), Sayaç Gönder, Data Döndür, Barkod, Kart, Hata, Yeni Cihaz Ekle, Moq Datadan Oluştur, Başla.
  - Paket biçimi ve sağlama: ASCII toplamının rakamları toplanıyor, sonuç 2 haneye tamamlanıyor.
  - Moq verisi: 188 cihaz, sicil, operasyon ve 600 seri kart. Form1.cs'den script ile çıkarıldı (`MoqSeed.cs`); yazım hataları dahil olduğu gibi bırakıldı.
- **Düzeltilenler:**
  - Kısa `SND=` ekran mesajında `LoadData` hata veriyordu.
  - Sunucu kapalıyken alma döngüsü %100 CPU yakıyordu (WSAECONNRESET); artık 200 ms bekliyor.
  - "Gönder & OK" butonundaki `Thread.Sleep` yerine `await Task.Delay` kullanılıyor.
  - "Başla" ikinci kez basılınca ikinci thread açmıyor.
  - Kapanışta thread'ler iptal ediliyor (CancellationToken).
- **Eklenenler:**
  - Tabloda bütün alanlar (Satır 1/2, sayaç, hedef vb.).
  - Sağda trafik listesi (en fazla 2000 satır).
- **Bulunan yarış durumu:** `Traffic` olayı `LoadData`'dan önce tetikleniyordu; sıra değiştirildi.
- **Doğrulama:**
  - `dotnet test` 11/11 geçti. İçinde TechtsioService'in sağlama ve uzunluk kontrolünün birebir kopyası var: adet paketi 55, RFG 44, HATAKODU 43 karakter (2 hane kod + 2 hane CRC).
  - Rust binary'sine karşı uçtan uca test: `VUO_DEVICES_EXE=...` ile geçti.
  - WPF exe açıldı; pencere başlığı doğru, yaklaşık 165 MB.
- **Commit:** `115ca28` — feat: Vuo Device Emulator

## Kararlar
- Emülatör aynı protokolü konuştuğu için TechtsioService'e karşı da kullanılabilir.
- Kurul: bu iş kullanıcının doğrudan talimatı olan yeni bir iç araç ve Saas_erp'ye dokunmuyor. Kurula sunulmadı.

## Açık kalanlar / sonraki adım
- Vuo_Devices şu an yalnız VERI-OK dönüyor. Gerçek iş mantığı (cihaz kaydı, vardiya, adet işleme ve Saas_erp ile bağlantı) henüz tanımlanmadı.
- Port 85'te TechtsioService ile aynı anda çalışamaz; bir UDP portunu tek süreç dinleyebilir.

### Canlı log sayfası ve Docker imajı
- **Neden:** Kullanıcı gelen/giden trafiği bir adresten (`/logs`) görmek ve servisi Docker'a çıkarmak istedi.
- **Ne yapıldı:**
  - `src/weblog.rs`: `LogBook` halka tampon (Mutex<VecDeque>, varsayılan 5000, `VUO_DEVICES_LOG_CAPACITY`); her kayıt aynı zamanda stdout'a. Bağımlılıksız HTTP (std `TcpListener`, bağlantı başına thread, 5 sn timeout, 8 KB başlık sınırı): `GET /logs` (gömülü HTML, 1 sn'de bir `/logs.json?after=<son id>` çeker, filtre/yön/duraklat/temizle, koyu tema), `GET /logs.json?after=&limit=` (`{"last":N,"entries":[...]}`; after=0 ilk açılışta son `limit` kayıt), `GET /health`.
  - `main.rs`: `VUO_DEVICES_HTTP_PORT` (varsayılan 8085, `0` kapalı). HTTP bind hatası UDP'yi durdurmaz. Paketler `escape_debug` ile kaydedilir (`\r\n` görünür).
  - `clock.rs`: Linux için `localtime_r` + `tzset` FFI (önce UTC'ye düşüyordu; Docker'da `TZ=Europe/Istanbul`).
  - `Dockerfile`: `rust:1.91-bookworm` derleme → `debian:bookworm-slim` + tzdata, `USER 65534`, EXPOSE 85/udp 8085/tcp. `.dockerignore`, `docker-compose.yml` (restart unless-stopped, json-file log 20m×3).
- **Doğrulama:**
  - `cargo test` 15/15 (yeni: halka tampon, ilk sayfa limiti, JSON kaçışı, query parse; uçtan uca `/logs.json` in/out/OK kaydı, `/logs`, `/health`, 404). Testler boş TCP portu verir, 8085'e çarpmaz.
  - `cargo check --target x86_64-unknown-linux-gnu` (rustup target eklendi).
  - `docker build -t vuo-devices .` → 114 MB. `docker run -p 9085:85/udp -p 18085:8085`: bağlı UDP soketle VERI-OK geldi (Docker NAT cevabı aynı porttan döndürüyor), OK'a cevap yok, saat İstanbul, süreç `nobody`. Sayfa Chrome'da açılıp kayıtlar görüldü. Test konteyneri silindi.
- **Commit:** `07db5ce` — feat: canlı log sayfası (/logs) ve Docker imajı

## Kararlar (ek)
- Log sayfası `0.0.0.0`'a bağlanır (Docker'da zorunlu); kimlik doğrulama yok → port yalnız iç ağa açılmalı.
- İmaj Docker Hub'a pushlanmadı (yerel `vuo-devices:latest`).

### Docker Hub'a yayın
- **Neden:** Kullanıcı imajın Docker Hub'a gönderilmesini istedi.
- **Ne yapıldı:** İlk push "insufficient_scope" ile reddedildi (credential store boştu); kullanıcı `docker login` yaptı. `tekbirsoft/vuo-devices:0.1.0-07db5ce` ve `:latest` gönderildi, digest `sha256:0473591c…be51`. Anonim `GET hub.docker.com/v2/repositories/tekbirsoft/vuo-devices/` → 404, yani repo private.
- `docker-compose.yml` imaj adı `tekbirsoft/vuo-devices:latest` yapıldı (ilk denemede sed ayraç hatasıyla uygulanmamıştı, Edit ile düzeltildi); README’ye başka makinede `docker login` + `docker run` tarifi eklendi.
- **Etiket kuralı:** `<Cargo sürümü>-<kısa commit>` + `latest`.
