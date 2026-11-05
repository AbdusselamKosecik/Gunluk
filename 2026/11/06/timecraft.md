# timecraft — 2026-11-06

## Bağlam
Repo: `X:\Gitlab\fredericTr\timecraft` (GitLab `fredericTr/timecraft`, ASP.NET Core MVC, SentezLive SQL Server @192.168.1.22).
`doc/` altında iki dosya duruyordu ve git'e eklenmemişti: Etüt Vision HTML prototipi (`index.html`) ve `YAZILIMCI_APK_GEREKSINIMLERI.md`.
Hedef: dokümanları projeye eklemek, API yazmak ve Android tablet uygulaması (APK) çıkarmak. Kullanıcı soru-cevap aşamasını atlattı ("devam et").

## Yapılanlar

### 1. Dokümanlar + API sözleşmesi + SQL şema
- **Neden:** Backend ve Android paralel yazılacağı için önce ortak bir sözleşme gerekiyordu.
- **Ne yapıldı:**
  - `doc/ETUT_API.md`: uçlar, JSON şekilleri, hata kodları, durum makinesi ve formül ETUT-1.
  - `doc/sql/etut_schema.sql`: `UZM_ETUT_*` tabloları (UserRole, Machine, Operation, Study, Measurement, Media, Annotation, AuditEvent). Tekrar çalıştırılabilir (`IF NOT EXISTS` + `MERGE`). 14 kaynak makine ve 16 işlem kodu seed ediliyor; ÖN SÜRME → MAKİNA YOK eşlemesi de var.
  - Yıkama adları ve işlem kodları prototipteki `WASH_REFERENCE` JSON'undan çıkarılıp `Etut/Reference/wash_reference.json` dosyasına yazıldı.
- **Dokunulan dosyalar:** `doc/*`, `Etut/Reference/wash_reference.json`

### 2. Backend: `/api/etut` (JWT)
- **Neden:** APK'nın ortak çalışabilmesi için sunucu, kimlik ve sürüm kontrolü gerekiyordu (gereksinim §1, §11, §12).
- **Ne yapıldı:**
  - **Ayrı `EtutContext`:** `SentezLiveContext`, `Database.ps1` ile `--force` scaffold ediliyor; etüt eşlemeleri oraya konursa silinirdi. `Meta_User` bu context'te salt-okunur ve `ExcludeFromMigrations` ile işaretli.
  - **Giriş:** Meta_User şifresi, web girişiyle aynı yöntemle (MD5(UTF-16LE(trim)), büyük harf hex) doğrulanıyor ve JWT veriliyor. Yetkiler her istekte `UZM_ETUT_UserRole` tablosundan okunuyor.
  - **Saf kurallar (`Etut/Domain/EtutRules.cs`):** hesap, eksik alan listesi, durum geçişleri, `AllowedActions`. Hesaplayan kişi kendi SMV'sini onaylayamıyor.
  - **`EtutStudyService`:**
    - `Version` bir concurrency token; eski sürümle kayıt 409 dönüyor.
    - Kayıt öncesi/sonrası snapshot farkı geçmişi üretiyor. Değişiklik yoksa sürüm artmıyor ve geçmiş yazılmıyor.
    - Veri değişirse Kontrol bekliyor / Onaylandı → SMV bekliyor oluyor ve onay temizleniyor.
    - Medya önce `.part` dosyasına yazılıp sonra adlandırılıyor; DB kaydı başarısız olursa dosya siliniyor.
    - Foto işaretleri normalize koordinatlarla (0..1) tutuluyor.
  - **Program.cs:** `builder.AddEtut(connectionString)` eklendi. Cookie şeması varsayılan olarak kaldı.
- **Dokunulan dosyalar:** `Etut/**`, `Program.cs`, `TimeCraft.csproj` (JwtBearer 10.0.5; `tests/`, `android/`, `App_Data/` derlemeden çıkarıldı; daha önce commit edilmemiş net9→net10 değişikliği de bu commit'e girdi), `appsettings.json` (`Etut` bölümü, `JwtKey` boş), `.gitignore`
- **Sonuç / doğrulama:**
  - `dotnet run --urls http://localhost:5099` ile denendi:
    - token olmadan `/api/etut/machines` → 401
    - boş login → 400 JSON hata
    - olmayan kullanıcı → `invalid_credentials` (DB'ye bağlanıp Meta_User okuyabildiğini gösteriyor)
    - `/Auth/Login` → 200
- **Commit:** `a8f6602` — Etut Vision API: /api/etut (JWT), UZM_ETUT_* sema, is kurallari + testler

### 3. Testler: `tests/TimeCraft.Tests` (xUnit + SQLite bellek içi)
- **Kapsam:**
  - Kabul testi 3: 10/20/30 sn → 0,41 dk / 24,6 sn.
  - Kabul testi 4: 380352 ms / 9 → 0,832965333 dk / 49,97792 sn.
  - 11. ölçüm reddi, durum makinesi, onay geçersizleşmesi, gerekçesiz düzeltme reddi, 409, değişiklik yoksa geçmiş yok, medya ve işaret akışı.
  - Şifre hash'i `LoginCommandHandler.Encrypt` ile birebir aynı.
  - Not: Meta_User testte `CREATE TABLE` ile elle açılıyor, çünkü `ExcludeFromMigrations` yüzünden `EnsureCreated` onu oluşturmuyor.
- **Komut:** `cd tests/TimeCraft.Tests && dotnet test` → **30/30 geçti**

### 4. Android: `android/` (Kotlin + Compose)
- **Ne yapıldı:** Arka plan ajanıyla yazıldı ve sözleşmeye göre eşleşmesi kontrol edildi.
  - **Sürümler:** Gradle 8.14 wrapper, AGP 8.11.1, Kotlin 2.2.10, Compose BOM 2025.05.00, Retrofit/OkHttp/kotlinx.serialization, Coil, Media3. minSdk 26, target 35, `com.timecraft.etutvision`.
  - **Ekranlar:** Giriş, liste, düzenleyici (sekmeler: Bilgiler & süre / Fotoğraf / Video / SMV & kontrol / Sonuç / Geçmiş).
  - **Kronometre:** `elapsedRealtime` + DataStore + BOOT_COUNT ile çalışıyor. Uygulama kapanınca geri yükleniyor; cihaz yeniden başlarsa ölçüm görünür bir uyarıyla düşürülüyor.
- **Komutlar:**
  ```bash
  export JAVA_HOME="/c/Program Files/Android/openjdk/jdk-21.0.8"
  cd android && ./gradlew :app:testDebugUnitTest :app:assembleDebug
  ```
- **Sonuç:** 13/13 test geçti. APK: `android/app/build/outputs/apk/debug/app-debug.apk` (15,9 MB).
- **Commit:** `068385b` — Etut Vision Android tablet uygulamasi (Kotlin + Compose)

## Kararlar
- Tablo öneki `UZM_ETUT_` (projedeki `UZM_GSD_*` geleneğine uyuldu).
- Uygulama yalnızca çevrimiçi çalışıyor; çevrimdışı eşitleme kapsam dışı.
- Medya diskte (`Etut:MediaRoot`, varsayılan `App_Data/etut-media`); DB'de yalnız depolama anahtarı tutuluyor.
- Veri değişince `DuzeltmeIstendi` durumu değişmiyor; yalnız `KontrolBekliyor`/`Onaylandi` → `SmvBekliyor` oluyor.
- Düzeltme isteğini hesaplayan kişi de yapabiliyor; yasak yalnız onay için.

## Açık kalanlar / sonraki adım
- **`doc/sql/etut_schema.sql` SentezLive'da henüz ÇALIŞTIRILMADI** (canlı ERP DB, kullanıcı onayı bekleniyor). `UZM_ETUT_UserRole` için kullanıcı yetkileri de girilmeli.
- Canlıda `Etut:JwtKey` (≥32 karakter) tanımlanmalı; tanımlı değilse her yeniden başlatmada oturumlar düşüyor.
- IIS arkasındaysa büyük video için `web.config` → `maxAllowedContentLength` artırılmalı.
- Gerçek tablette uçtan uca test yapılmadı (kabul testleri 5–7, 10).
- Release APK imzalama: `android/README.md`.
- Yapılmayanlar: işaretleme ekranında pinch-zoom, prototip JSON yedeğinin içe aktarımı (§14).
- `Database.ps1` içinde sa şifresi düz metin olarak repoda duruyor (önceki commit'lerden).
