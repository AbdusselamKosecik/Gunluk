# tezgahekrani — 2026-10-15

## Bağlam
Kullanıcı tezgah durum ekranının tablete yüklenmesini istedi. Projenin Android hedefi yoktu (yalnız Desktop).

## Yapılanlar

### 1. TezgahEkrani.Android projesi
- **Ne yapıldı:**
  - `bantdurumekrani/BantDurumEkrani.Android` dosyaları kopyalandı.
  - Adlar değiştirildi: BantDurumEkrani → TezgahEkrani, "Bant Durum" → "Tezgah Durum", `com.modfex.tezgahekrani`.
  - Ayarlar bant durumdakiyle aynı: yatay ekran, ekran kararmaz, arm ve arm64.
  - `Directory.Packages.props`'a `Avalonia.Android` 12.1.2 ve `Xamarin.AndroidX.Core.SplashScreen` 1.0.1.15 eklendi.
  - `TezgahEkrani.slnx`'e Android projesi eklendi (`<Deploy />`).
- **Komutlar:**
  ```bash
  dotnet build TezgahEkrani.Android -c Release
  cp TezgahEkrani.Android/bin/Release/net10.0-android/com.modfex.tezgahekrani-Signed.apk dagitim/tezgahekrani-2026-10-15.apk
  ```
  `dagitim/` zaten gitignore'da.
- **Sonuç:** Derleme 0 hata. Tablet izni olmadığı için **yüklenemedi**.
- **Commit:** `ea77fc5`

## Açık kalanlar
- Tablete yükleme ve ilk açılış kontrolü. Ekran tablet çözünürlüğüne göre hiç denenmedi.
