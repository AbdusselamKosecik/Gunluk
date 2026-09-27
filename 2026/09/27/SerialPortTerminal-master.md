# SerialPortTerminal-master — 2026-09-27

## Bağlam
Uygulama çalışınca COM port adlarının/verinin sonunda garip karakterler çıkıyor; "PC'yi izleyen bir şey / virüs mü?" şüphesi.

## Yapılanlar

### 1. Güvenlik ve COM port incelemesi (kod değişikliği yok)
- **Neden:** Virüs/izleme şüphesini doğrulamak veya elemek.
- **Ne yapıldı:**
  - `Terminal.cs`, `Program.cs` tarandı: ağ, dosya, registry yazma, process başlatma yok. Sadece `System.IO.Ports.SerialPort`.
  - Sürücüler: com0com / Eltima / HHD / sniffer türü sanal port veya dinleme sürücüsü yok.
  - `HKLM\HARDWARE\DEVICEMAP\SERIALCOMM`: COM3, COM4 (Bluetooth BthModem) temiz, karakter kodları normal.
  - Defender: gerçek zamanlı koruma açık, imzalar güncel, tespit edilen tehdit yok.
- **Komutlar:**
  ```powershell
  Get-CimInstance Win32_PnPEntity | ? Name -match '\(COM\d+\)'
  Get-Item 'HKLM:\HARDWARE\DEVICEMAP\SERIALCOMM'   # değer karakter kodları
  [System.IO.Ports.SerialPort]::GetPortNames()
  Get-MpComputerStatus; Get-MpThreatDetection
  ```
- **Sonuç:** Virüs bulgusu yok. Olası nedenler: (a) bazı USB-seri sürücülerinin SERIALCOMM'a null-sonlandırılmamış değer yazması → `GetPortNames()` "COM5ÿ" gibi ad döndürür (bilinen .NET sorunu); (b) veri sonunda çöp → baud/parity uyuşmazlığı veya `ReadExisting()`'in varsayılan ASCII encoding'i (>127 byte'lar '?' olur).

## Açık kalanlar / sonraki adım
- Sorun anında cihaz takılıyken SERIALCOMM ve GetPortNames tekrar kontrol edilecek.
- İstenirse `GetPortNames` sonucunu `COM\d+` regex ile temizleyen düzeltme eklenebilir.

### 2. Ek kontrol: cihaz takılı değilken
- **Neden:** Kullanıcı sorunun USB cihaz takılı değilken de olduğunu söyledi; USB sürücü açıklaması düştü.
- **Ne yapıldı:** `bin/Debug`'da exe yok (sadece .config/.manifest/.application; ClickOnce publish kalıntısı). Defender olay günlüğü (1006-1119) tarandı: exe silinmemiş; tek kayıt 2026-09-04 balenaEtcher `Behavior:Win32/ModifiedBootRecord` (SD kart yazma, ilgisiz). Kayıtlı ayar: `%LOCALAPPDATA%\SerialPortTerminal\...\user.config` → COM4, 9600 8N1, Text.
- **Sonuç:** Hâlâ virüs izi yok. Tek port kaynağı Bluetooth COM3/COM4; sorun ekranı görülmeden kesin teşhis yok, kullanıcıdan ekran görüntüsü istendi.

### 3. Kök neden bulundu ve düzeltildi: "COM4潥", "COM3慦"
- **Neden:** Kullanıcı port listesinde `COM4潥`, `COM3慦` gördüğünü bildirdi.
- **Teşhis:** Virüs değil. Bluetooth (BthModem) sürücüsü `HKLM\HARDWARE\DEVICEMAP\SERIALCOMM` değerini null sonlandırıcısız yazıyor; .NET 2.0/3.5 `SerialPort.GetPortNames()` sonrasındaki bellek baytlarını UTF-16 karakter olarak ekliyor. Proje `TargetFrameworkVersion v3.5` olduğu için etkileniyor (.NET 4+ PowerShell'de aynı değerler temiz).
- **Ne yapıldı:** `Terminal.cs`'e `using System.Text.RegularExpressions;` ve `private static string[] GetPortNames()` eklendi: her adı `^COM\d+` ile kırpıyor, `Distinct()`. Üç `SerialPort.GetPortNames()` çağrısı (OrderedPortNames, RefreshComPortList x2) buna yönlendirildi.
- **Dokunulan dosyalar:** `Terminal.cs`
- **Komutlar:**
  ```bash
  /c/Windows/Microsoft.NET/Framework/v4.0.30319/MSBuild.exe SerialPortTerminal.csproj //p:Configuration=Debug //v:minimal
  ```
- **Sonuç / doğrulama:** Derleme hatasız. Regex testi: `COM4潥`→`COM4`, `COM3慦`→`COM3`, `COM10`→`COM10`. Uygulamada kullanıcı doğrulaması bekleniyor.
- **Commit:** Yok — proje klasörü git deposu değil, remote yok (kullanıcıya bildirildi).

## Kararlar
- .NET 4.x'e retarget yerine ad temizleme seçildi: minimum değişiklik, VS2008/2010 çözümleri bozulmuyor.
