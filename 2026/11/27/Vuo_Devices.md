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
