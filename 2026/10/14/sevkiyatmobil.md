# sevkiyatmobil — 2026-10-14

## Bağlam
Mal kabul (Mamul Giriş, fiş 17, 42 → 41) yapılacak. Şema canlıda yoktu; el terminali Point Mobile PM66 (Android 6.0.1, API 23,
armeabi-v7a, seri 39916cf0) USB ile bağlandı.

## Yapılanlar

### 1. db/0001_sevkiyatmobil.sql canlıda çalıştırıldı (kullanıcı: "sen çalıştırabilir misin")
- Betik okundu: tek transaction; `UZM_SevkIrsaliye`, `UZM_SevkOkutma` + indeksler; eksikse `UZM_Ayar` SevkFisTipi=120,
  MamulDepoId=41, MamulFisTipi=17. scratchpad `yaz.ps1` ile çalıştırıldı.
- Doğrulama: iki tablo var; ayarlar MamulDepoId=41, MamulFisTipi=17, SevkFisTipi=120.

### 2. APK yüklendi → Android 6'da açılışta çöktü
- `adb install -r dagitim/sevkiyatmobil-2026-10-12.apk` → Success; açılışta
  `FATAL UNHANDLED EXCEPTION: System.EntryPointNotFoundException: AChoreographer_getInstance`.
- **Sebep (ilspycmd ile Avalonia.Android 12.1.2):** `AndroidPlatform.Initialize` koşulsuz `new ChoreographerTimer()`; timer kendi
  iş parçacığında `AChoreographer_getInstance` (NDK, API 24) çağırır. `AndroidFramebuffer`'ın "android" P/Invoke'ları:
  ANativeWindow_fromSurface/getWidth/getHeight/release/unlockAndPost/lock, AChoreographer_getInstance/postFrameCallback(64).

### 3. Çözüm: libavaloniashim.so — `64493cc`
- `SevkiyatMobil.Android/native/avaloniashim.c`: aynı 9 işlevi verir. ANativeWindow_* → `dlopen("libandroid.so")`+`dlsym` ile gerçeğe.
  `AChoreographer_getInstance` → çağıran iş parçacığının `ALooper_forThread()` (Avalonia Looper.Prepare yapmış). 
  `postFrameCallback(64)` → tek seferlik `timerfd` (bir sonraki 16,67 ms sınırı, CLOCK_MONOTONIC) + `ALooper_addFd`; geri çağırma
  monotonic ns ile, fd kapatılır.
- `native/derle.sh`: NDK 28 clang, `armv7a-linux-androideabi23` ve `aarch64-linux-android23` → `lib/<abi>/libavaloniashim.so`.
- csproj: `AndroidNativeLibrary` (iki ABI). `Application` static ctor: API < 24 ise
  `NativeLibrary.SetDllImportResolver(typeof(AvaloniaMainActivity).Assembly, ad == "android" → Load("libavaloniashim.so"))`.
- **Doğrulama:** Release APK (shim iki ABI'de içinde) yüklendi; çökme yok, `MainActivity` ön planda; ekran görüntüsünde
  "Bağlantı Ayarları" ekranı çiziliyor. APK: `dagitim/sevkiyatmobil-2026-10-14.apk` (dagitim gitignore'da).
- Not: Python `'''...lib\armeabi...'''` → `\a` zil karakterine döndü; csproj Write ile yeniden yazıldı.

## Açık kalanlar
- Cihazda bağlantı ayarları girilecek (kullanıcı; şifre cihazda girilir). Evden 100.119.104.122 için cihazda Tailscale gerekir;
  ofiste 192.168.0.2.
- Mal kabul denemesi; dokunma/kaydırma ve okuyucu ile uzun süreli kullanım shim ile sınanmadı.
- Diğer Avalonia Android uygulamaları (bantsayim vb.) Android 6'da aynı sorunu yaşar; shim oraya da taşınabilir.

### 4. Shim: tek kalıcı timerfd — `210aefa`
- **Belirti:** uygulama kullanılırken bir noktadan sonra ekran güncellenmiyordu (dokunma tepkisiz görünüyordu).
- **Sebep (tahmin, kodla tutarlı):** her kare için yeni timerfd açılıp looper'a ekleniyor, geri çağırmada kapatılıp 0 dönülüyordu.
  Başka iş parçacığı arada yeni kare isterse kapanan fd numarası yeniden kullanılıyor, looper eski kaydı silerken yeni bekleyen kareyi de
  siliyordu → `_pendingCallback` sonsuza dek true, zamanlayıcı ölü.
- **Ne yapıldı:** `getInstance`'ta bir kez timerfd + `ALooper_addFd` (geri çağırma 1 döner, kalıcı); `postFrameCallback(64)` isteği
  pthread mutex altında saklar ve timerfd'yi bir sonraki 16,67 ms sınırına kurar.
- **Ölçüm (geçici logcat, sonra kaldırıldı):** getInstance looper ve fd geldi; kareler ~16 ms aralıkla; boşta Avalonia kare istemiyor
  (normal), dokunuşta yeniden istiyor.
- **Açık:** adb `input tap` ile Avalonia tepki vermedi (giriş kuyruğu boş, pencere odakta). Kullanıcı sabah cihazda elle gezinebildi;
  elle dokunma ile doğrulama kullanıcıdan bekleniyor. Son APK (`dagitim/sevkiyatmobil-2026-10-14.apk`) cihaz USB'den çıkarıldığı için
  yüklenemedi — cihazda bir önceki (günlüklü) sürüm var.
- Araç: `dotnet tool install -g ilspycmd` (Avalonia.Android kodunu okumak için).

## Sonraki adım
- Mobil ekranlar küçük ekranda (480×800, ölçek 1,5 → 320 dp) çok büyük: genel ~%80 küçültme + üst çubuk (dil düğmeleri taşıyor).
