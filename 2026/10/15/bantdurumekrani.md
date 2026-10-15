# bantdurumekrani — 2026-10-15

## Bağlam
Kullanıcı: "Bant durum ve tezgah durum ekranini tablete yuklermisin".

## Yapılanlar

### 1. Android projesi tablete hazırlandı
- **Neden:** Android projesi şablon ayarlarıyla duruyordu (`com.CompanyName.BantDurumEkrani`, etiket "BantDurumEkrani").
- **Ne yapıldı:**
  - `ApplicationId` `com.modfex.bantdurumekrani` oldu; uygulama adı "Bant Durum" oldu.
  - `RuntimeIdentifiers` = `android-arm;android-arm64`.
  - `MainActivity`: `ScreenOrientation.SensorLandscape` ve `WindowManagerFlags.KeepScreenOn` (pano yatay durur, ekran kararmaz).
  - `.gitignore`'a `dagitim/*.apk`, `dagitim/*.zip` eklendi.
- **Dokunulan dosyalar:**
  - `BantDurumEkrani.Android/BantDurumEkrani.Android.csproj`
  - `BantDurumEkrani.Android/MainActivity.cs`
  - `BantDurumEkrani.Android/Properties/AndroidManifest.xml`
  - `.gitignore`
- **Komutlar:**
  ```bash
  dotnet build BantDurumEkrani.Android -c Release
  cp BantDurumEkrani.Android/bin/Release/net10.0-android/com.modfex.bantdurumekrani-Signed.apk dagitim/bantdurumekrani-2026-10-15.apk
  adb install -r dagitim/bantdurumekrani-2026-10-15.apk
  ```
- **Sonuç:** APK derlendi. Tablet (seri R83XB0S3C7Y) bağlı ama USB hata ayıklama izni verilmedi (`unauthorized`); **APK yüklenemedi**.
- **Commit:** `7dd170e`

## Açık kalanlar
- Tablette USB hata ayıklama onayı verilince `adb install -r` ile yüklenecek.
- Tablette ilk açılışta bağlantı ayarları girilecek: evde Tailscale `100.119.104.122`, ofiste `192.168.0.2`.
