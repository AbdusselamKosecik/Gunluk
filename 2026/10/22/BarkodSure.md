# BarkodSure — 2026-10-22

## Bağlam
Kullanıcı, kumaş topu etiketindeki çok satırlı QR'ın (SF-P755-KALA, Fred Eric etiketi; içinde
sayısı bilinmeyen Enter'lar var) el terminali/okuyucuyla kaç saniyede okunduğunu ölçen bir
Android APK istedi. Önce muftelif içinde başlandı, kullanıcı "yeni proje olsun" deyince ayrı
GitLab projesine taşındı.

## Yapılanlar

### 1. Flutter projesi + ölçüm ekranı
- **Neden:** Okuyucu klavye kaması gibi karakter karakter yazıyor; Enter sayısı bilinmediği için
  bitiş Enter'la değil sessizlikle anlaşılmalı.
- **Ne yapıldı:** Tek ekran (`lib/main.dart`):
  - Odaklı çok satırlı `TextField` (`keyboardType: TextInputType.none` → ekran klavyesi gizli,
    anahtarla açılabilir; `textInputAction: newline` → Enter metne `\n` olarak girer).
  - `HardwareKeyboard.instance.addHandler` ile her KeyDown'da zaman damgası + Enter sayımı;
    `onChanged` ile de (okuyucu IME/commitText ile gönderiyorsa).
  - Zaman: `Stopwatch` mikro saniye. Süre = ilk giriş → son giriş. Son girişten sonra
    `_sessizlikMs` (varsayılan 400, slider 100–2000) giriş yoksa okuma kapanır; bekleme süreye dahil değil.
  - Enter = max(tuş olayındaki Enter, metindeki satır sonu). Karakter, satır, tuş olayı sayısı.
  - Adet/ortalama/en az/en çok; son içeriği ↵ işaretleriyle gösterir; CSV'yi panoya kopyalar.
  - Süre <1 ms ise "veri tek parça geldi" uyarısı (okuyucu paste/intent modunda).
- **Dokunulan dosyalar:** `lib/main.dart`, `android/app/src/main/AndroidManifest.xml`
  (label "Barkod Süre"), `pubspec.yaml` (version 1.0.0+1), `build-apk.ps1`, `README.md`, `.gitignore` (+`*.apk`)
- **Komutlar:**
  ```powershell
  $env:PATH='C:\flutter\bin;'+$env:PATH
  flutter create --org com.frederic --project-name barkod_sure --platforms android --empty BarkodSure
  powershell -ExecutionPolicy Bypass -File build-apk.ps1
  ```

### 2. Gradle sürüm uyuşmazlığı
- **Neden:** Flutter 3.47 şablonu Gradle 9.3.1 / AGP 9.1.0 / Kotlin 2.4.0 istiyor; indirme
  `SunCertPathBuilderException` (sertifika) ile düştü.
- **Ne yapıldı:** `settings.gradle.kts`, `gradle-wrapper.properties` muftelif/SentezSelvedge/mobile'dan
  kopyalandı (Gradle 8.14, AGP 8.11.1, Kotlin 2.2.20 — önbellekte var). `app/build.gradle.kts`
  da oradan alınıp namespace/applicationId `com.frederic.barkod_sure` yapıldı (`kotlin-android`
  eklentisi + `kotlinOptions`).
- **Sonuç:** `barkod-sure-1.0.0.1.apk` 46.6 MB derlendi (yeni konumda da tekrar derlendi).

### 3. Ayrı projeye taşıma
- **Ne yapıldı:** `X:\Gitlab\fredericTr\muftelif\BarkodSure` → `X:\Gitlab\fredericTr\BarkodSure`.
  Gradle daemon `classes.dex`'i kilitlediği için muftelif altında yalnız `BarkodSure\build\` artığı
  kaldı (git'e girmiyor; daemon kapanınca silinebilir). muftelif'e commit yapılmadı.
  `git init -b main`, remote `https://gitlab.com/fredericTr/BarkodSure.git` — push-to-create ile
  GitLab projesi (private) otomatik açıldı.
- **Commit:** `dbd4ea3` — feat: barkod okuma suresi olcer (Flutter Android)

## Kararlar
- Kamera ile okuma yok; ölçülen şey donanım okuyucunun veri gönderme süresi.
- Tetik tuşuna basma anı ölçülmüyor (okuyucu tuş olayı göndermezse görünmez); ilk karakterden başlar.

## Açık kalanlar / sonraki adım
- APK cihazda denenmedi. El terminalinde ilk denemede süre ~0 çıkarsa okuyucu "paste/intent"
  modunda; DataWedge vb. ayarında çıktı "keystroke" yapılmalı.
- Okuma ortasında >400 ms boşluk olursa iki okuma sayılır → sessizlik süresini artır.
- `X:\Gitlab\fredericTr\muftelif\BarkodSure\build` artığını sil.
