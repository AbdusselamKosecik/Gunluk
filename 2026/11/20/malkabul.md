# malkabul — 2026-11-20

## Yapılanlar

### 1. Masaüstü uygulaması açıldı
- Dünkü `5a4dee0` derlemesi (scratchpad `mk_win`) kullanıcı için başlatıldı.
- İlk açılışta saat 21:28'de "Şirketler okunamadı" hatası alındı: SQL 192.168.0.2'ye ağ bağlantısı anlık koptu (Win32 64, network name no longer available).
- `Test-NetConnection 192.168.0.2 -Port 1433` başarılı oldu; uygulama yeniden açıldı, hata tekrarlamadı.

### 2. Android emülatörü (Modfex'e özel)
- **Neden:** Kullanıcı uygulamayı emülatörde görmek istedi. Var olan `Terminal_API23` emülatöründe Modasima uygulamaları kurulu; kullanıcı "Modasima için olanı değil, Modfex için olanı" dedi.
- **Ne yapıldı:**
  - Yeni AVD `Modfex_Terminal` oluşturuldu: android-34 google_apis x86_64, 720×1280, density 320, donanım klavyesi, çerçevesiz.
    ```powershell
    $env:JAVA_HOME="C:\Program Files\Android\openjdk\jdk-21.0.8"
    avdmanager create avd -n Modfex_Terminal -k "system-images;android-34;google_apis;x86_64" -d pixel
    # config.ini: hw.lcd.width=720, hw.lcd.height=1280, hw.lcd.density=320, hw.keyboard=yes, showDeviceFrame=no
    emulator -avd Modfex_Terminal -no-snapshot-save -no-boot-anim
    ```
  - APK yalnız arm/arm64 derleniyordu: emülatörde INSTALL_FAILED_NO_MATCHING_ABIS.
    - Komut satırından `-p:RuntimeIdentifiers=android-x64` verilince ayar alt kütüphane projesine de geçti ve AVLN9999 hatası alındı.
    - Çözüm: `MalKabul.Android.csproj`'a koşullu `RuntimeIdentifiers` eklendi (`-p:Emulator=true` → android-x64).
    ```bash
    dotnet publish MalKabul.Android -c Release -p:Emulator=true -o <klasör>
    adb install -r <klasör>/com.modfex.malkabul-Signed.apk
    ```
- **Sonuç:** Uygulama emülatörde açıldı ve çalışıyor, çökme yok. Sunucu ayarlarını ilk açılışta kullanıcı girecek.
- **Commit:** Android emülatör derleme anahtarı (bu günün malkabul commit'i).

## Notlar
- Emülatörden ana makinedeki Zebra simülatörüne basmak için yazıcı IP'si `10.0.2.2`, port 9100. 10.0.2.2, emülatörün ana makineye ulaştığı adres.

## Açık kalanlar
- `5a4dee0` için kod gözden geçirmesi yarım kaldı.
- PM66'ya yeni APK yüklenmedi.
