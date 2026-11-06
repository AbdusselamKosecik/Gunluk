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

### 5. Etüt Yetkileri ekranı (web, `/EtutRole`)
- **Neden:** Kullanıcı, Sentez kullanıcılarına etüt rollerinin SQL yazmadan ekrandan atanmasını istedi.
- **Ne yapıldı:**
  - **Liste:** `EtutRoleController` + `Views/EtutRole/Index.cshtml` aktif Meta_User kullanıcılarını gösteriyor. `IsUserRole=1` satırları (17 Sentez rol kaydı) hariç; canlı DB'de salt-okunur sorguyla doğrulandı: 277 kullanıcı.
  - **Yetkiler:** 5 onay kutusu (Etüt yapar / SMV hesaplar / Kontrol eder / Makine tanımlar / Yetki yönetir), satır başına Kaydet. Arama, filtre (yetkili/yetkisiz) ve Sentez rolü filtresi var.
  - **Erişim:** Ekranı yalnız `CanManageRoles` sahibi açabiliyor. Kimsede yoksa ilk kurulum modu devreye giriyor: giriş yapan herkes açabiliyor, ilk yönetici atanınca kilitleniyor. Son yönetici kendi bayrağını kaldıramıyor.
  - **Neden yeni bayrak:** Web girişi herkese aynı "user" rolünü veriyor; mevcut `Roles="Admin"` kontrolü (SystemSettings) hiçbir zaman sağlanmıyor.
  - **Login:** `LoginCommand` artık `UserId` ve `FirstName` claim'i de veriyor ("son değiştiren" bilgisi için). Eski oturumlar yeniden giriş yapmalı.
  - **Şema:** `UZM_ETUT_UserRole` tablosuna `CanManageRoles`, `UpdatedAt`, `UpdatedBy` eklendi (eski tablo için `ALTER` de var).
  - Tablolar yoksa ekran, çalıştırılması gereken `sqlcmd` komutunu gösteriyor.
- **Dokunulan dosyalar:** `Controllers/EtutRole/*`, `Views/EtutRole/Index.cshtml`, `Views/Shared/_Menu.cshtml`, `Controllers/Auth/LoginCommand.cs`, `Etut/Data/*`, `doc/sql/etut_schema.sql`, test SQL'i
- **Sonuç / doğrulama:**
  - Derleme temiz, testler 30/30 geçti. (Test `Meta_User` tablosuna yeni kolonlar eklenmesi gerekti.)
  - Girişsiz `/EtutRole` → 302 Login.
  - Giriş yapılmış ekran görsel olarak denenmedi: tablolar yok ve test için bir kullanıcı şifresi yok.
- **Commit:** `9d0332f` — Etut Yetkileri ekrani: Sentez kullanicilarina etut rolu atama

### 6. IIS yayın paketi (192.168.3.228:81) + APK varsayılan adresi
- **Neden:** Kullanıcı TimeCraft'ın 192.168.3.228:81 IIS'inde çalışmasını istedi.
- **Durum tespiti:** Sunucuda eski TimeCraft (net9, framework-dependent) çalışıyor (`/` → 302 Login, `Server: Microsoft-IIS/10.0`). Buradan dosya paylaşımına erişim yok (`net view` → hata 1702), bu yüzden kopyalama elle yapılacak.
- **Ne yapıldı:**
  - **Self-contained win-x64 paket:** Proje net10. Sunucuda .NET 10 Hosting Bundle olup olmadığı bilinmiyor, runtime paketin içinde gidiyor. ANCM v2 sunucuda zaten var (eski site çalışıyor), `aspnetcorev2_inprocess.dll` pakette.
  - **`web.config` (repo kökünde):** `requestLimits maxAllowedContentLength=2147483648`. Publish sırasında aspNetCore handler'ı bu dosyaya kendisi ekliyor.
  - **`appsettings.Production.json`:** Yalnız paketin içinde, rastgele 48 baytlık `Etut:JwtKey` ile; repoya girmedi. Not: Windows'taki `openssl` çıktısının sonundaki `\r` JSON'u bozdu ("0x0D is invalid"), `sed 's/\r//g'` ile temizlendi.
  - **`appsettings.Development.json`:** Paketten silindi.
  - **Android:** `SettingsStore.DEFAULT_URL = "http://192.168.3.228:81/"`, README güncellendi, APK yeniden derlendi.
- **Komutlar:**
  ```bash
  dotnet publish TimeCraft.csproj -c Release -r win-x64 --self-contained true -o X:/Gitlab/fredericTr/timecraft-publish
  # appsettings.Production.json: {"Etut":{"JwtKey":"<openssl rand -base64 48>"}}
  ASPNETCORE_ENVIRONMENT=Production ./TimeCraft.exe --urls http://localhost:5188   # smoke test
  Compress-Archive timecraft-publish\* X:\Gitlab\fredericTr\TimeCraft-iis-20261106.zip
  ```
- **Sonuç / doğrulama:**
  - Paket yerelde Production modunda denendi: `/Auth/Login` → 200; tokensiz API → 401; login → `invalid_credentials`; JwtKey uyarısı yok.
  - Çıktılar: `X:\Gitlab\fredericTr\TimeCraft-iis-20261106.zip` (172 MB) ve `X:\Gitlab\fredericTr\EtutVision-debug.apk`.
  - **Sunucuya kopyalanmadı.**
- **Commit:** `f54f473` — IIS yayini: web.config (2GB upload limiti), APK varsayilan sunucu 192.168.3.228:81

### 7. Tablet geri bildirimi: "kayıt ekranı yok" + yıkamada arama
- **Durum:**
  - Kullanıcı yeni paketi IIS'e kurmuş; `192.168.3.228:81/api/etut` JSON dönüyor.
  - Şemayı da çalıştırmış (8 `UZM_ETUT_*` tablosu var).
  - `UZM` (RecId 78) ile girişte "Yeni etüt" görünmedi.
- **Neden:** `UZM_ETUT_UserRole` tablosunda RecId 78 için satır yok, yani `canStudy=false`. Buton bilerek gizli, kod hatası değil. Ayrıca kullanıcı (`me()`) yalnız uygulama açılışında okunuyordu: web'den yetki verilse bile uygulama yeniden açılmadan görünmezdi.
- **Ne yapıldı:**
  - `StudyListViewModel.load()` her yenilemede `me()` çağırıp yetkileri tazeliyor.
  - Hiç etüt yetkisi olmayan kullanıcıya listede açıklayıcı uyarı gösteriliyor.
  - `SelectField` seçenek sayısı 8'den fazlaysa aranabilir oluyor: açılınca alan arama kutusuna dönüşüyor, seçim yine yalnız listeden yapılıyor. Bu, listedeki Yıkama (191 seçenek) ve İşlem (16) filtrelerini kapsıyor.
  - `searchKey()`: Türkçe küçük harf + ı/ş/ğ/ü/ö/ç katlama. Tablet klavyesinde "yikama" yazan da "YIKAMA"yı buluyor. Düzenleyicideki Yıkama `AutoCompleteField`'ı da aynı anahtarı kullanıyor.
- **Dokunulan dosyalar:** `android/.../ui/common/Components.kt`, `android/.../ui/list/StudyListScreen.kt`
- **Sonuç:**
  - Derleme ve 13 test geçti.
  - APK `X:\Gitlab\fredericTr\EtutVision-debug.apk` dosyasına kopyalandı.
  - Cihazda denenmedi.
- **Commit:** `3b91196`

### 8. SentezY'ye tam etüt yetkisi (DB)
- **Neden:** Kullanıcı açıkça istedi: "SentezY'ye yetki verir misin, her şeyi yapabilsin".
- **Ne yapıldı:** `Meta_User` RecId 12 (SentezY, "Sentez Yönetici") için `UZM_ETUT_UserRole`'a satır eklendi. Beş bayrağın hepsi 1, `UpdatedBy=NULL` (script ile yapıldı).
- **Komut:**
  ```sql
  INSERT UZM_ETUT_UserRole(UserId,CanStudy,CanCalcSmv,CanControl,CanManageMachines,CanManageRoles,UpdatedAt,UpdatedBy)
  VALUES(12,1,1,1,1,1,SYSUTCDATETIME(),NULL);
  ```
- **Sonuç:** Tabloda iki tam yetkili var: SentezY (12) ve Üretim-04 (126, kullanıcı tarafından ekrandan verilmiş, 07:51 UTC). Yetki ekranı artık yalnız bu ikisine açık.
- **Not:** Aynı kişi kendi hesapladığı SMV'yi onaylayamaz (kural). Tam akış için onaylayan ikinci bir kişi gerekiyor.

### 9. Order → model doldurma, çoklu medya, medya silme, 500 teşhisi, harf duyarsız arama
- **İstekler:**
  - Order seçilince model kodu/adı otomatik gelsin.
  - Fotoğraf yüklerken 500 hatası alınıyor.
  - Birden fazla fotoğraf/video eklenebilmeli.
  - Fotoğraf/video silinebilmeli.
  - IIS'i ben güncelleyeyim.
- **Veri kaynağı tespiti (salt-okunur sqlcmd):**
  - Sipariş: `Erp_OrderReceipt`, ReceiptType=2 (satış). 257 fiş, `ReceiptNo` "00001206" biçiminde.
  - Kalemler: `Erp_OrderReceiptItem` → `Erp_Inventory`. Model no = `InventoryCode`, ad = `InventoryName`, yıkama = `UD_WashName` (%99,7 dolu).
  - Bir siparişte ortalama ~20 model var, bu yüzden "tek model otomatik, çoksa listeden seç" yaklaşımı seçildi.
  - `Erp_WorkOrder` içinde InventoryId boş, kullanılmadı.
- **Backend:**
  - `EtutOrderLookup`: `Database.SqlQuery<T>` ile parametreli ham SQL; ERP tabloları EF modeline eklenmedi.
  - Yeni uçlar: `GET orders?search=`, `GET orders/models?orderNo=`. Order no, sorgu parametresi olarak gidiyor; içinde `/` olabilir.
- **Collation bulgusu:** SentezLive **Turkish_CS_AS**, yani harf duyarlı ve "i"≠"I": "aritzia" araması "ARITZIA"yı bulmuyordu. Arama `COLLATE Latin1_General_CI_AI` ile yapılıyor (`EtutSql.SearchCollation`). Aynı düzeltme etüt listesi aramasına (yalnız SQL Server'da; SQLite testinde değil) ve Etüt Yetkileri aramasına da uygulandı.
- **500 teşhisi:**
  - Paketteki JwtKey ile 30 dakikalık test JWT'si üretildi (sub=12) ve canlıda `auth/me` doğrulandı.
  - 1x1 PNG yükleme canlıda boş gövdeli 500 verdi. Yerelde aynı istek başarılı oldu (test medyası sonra silindi).
  - Sonuç: kod değil sunucu. En olası neden, IIS app pool kullanıcısının `App_Data\etut-media` yazma izninin olmaması.
  - Hata filtresi artık beklenmeyen hataları JSON (`server_error` + tip/mesaj) döndürüp logluyor; `UnauthorizedAccessException` için izin talimatı veriyor.
- **Android:**
  - `SuggestField`: Order alanında sunucu önerisi var. Tek model varsa otomatik doluyor; birden fazlaysa Model no alanı listeye dönüşüyor. Yıkama boşsa stok kartındaki yıkama adı yazılıyor.
  - Video seçimi çoklu (`OpenMultipleDocuments`), seçilen listeden tek tek "Çıkar" yapılabiliyor.
  - Fotoğraf küçük resminde 🗑 butonu var. Çoklu foto seçimi zaten vardı.
  - Yükleme sıralı ve her yanıtın sürümünü kullanıyor (409 olmuyor).
- **Doğrulama:**
  - .NET 30/30 ve Android 13/13 test geçti.
  - Yerel API'de `orders?search=1206/aritzia/citizens` ve `orders/models?orderNo=00001207` (2 model + yıkama) çalıştı; `studies?search=adore` küçük harfle bulundu.
- **Paket:** Yeniden publish edildi, eski `appsettings.Production.json` (JwtKey) korundu. `TimeCraft-iis-20261106.zip` güncellendi, APK `EtutVision-debug.apk` güncellendi.
- **IIS'e erişim:** 445 kapalı; 5985 (WinRM) ve 8172 (Web Deploy) açık. Kimlik bilgisi bekleniyor.
- **Commit:** `7e0f35f`

## Kararlar
- UZM'ye yetki DB'ye elle yazılmadı; web'deki Etüt Yetkileri ekranından verilmesi önerildi (kimde yönetici yoksa ilk kurulum modu açık).
- IIS paketi self-contained: sunucudaki .NET sürümüne bağımlı değil (353 MB açık, 172 MB zip).
- JwtKey yalnız yayın paketinde duruyor. Paket yeniden üretilirse eski `appsettings.Production.json` korunmalı, yoksa tablet oturumları düşer.
- Tablo öneki `UZM_ETUT_` (projedeki `UZM_GSD_*` geleneğine uyuldu).
- Uygulama yalnızca çevrimiçi çalışıyor; çevrimdışı eşitleme kapsam dışı.
- Medya diskte (`Etut:MediaRoot`, varsayılan `App_Data/etut-media`); DB'de yalnız depolama anahtarı tutuluyor.
- Veri değişince `DuzeltmeIstendi` durumu değişmiyor; yalnız `KontrolBekliyor`/`Onaylandi` → `SmvBekliyor` oluyor.
- Düzeltme isteğini hesaplayan kişi de yapabiliyor; yasak yalnız onay için.

## Açık kalanlar / sonraki adım
- **IIS'e kopyalama (elle):**
  - Site durdurulmalı (veya `app_offline.htm` konmalı), mevcut klasör yedeklenmeli, zip içeriği üzerine açılmalı.
  - App pool identity'ye `App_Data` için Modify izni verilmeli (medya yüklemeleri).
  - App pool'da ".NET CLR version = No Managed Code" seçili olmalı.
- **`doc/sql/etut_schema.sql` SentezLive'da henüz ÇALIŞTIRILMADI** (canlı ERP DB, kullanıcı onayı bekleniyor). `UZM_ETUT_UserRole` için kullanıcı yetkileri de girilmeli.
- Canlıda `Etut:JwtKey` (≥32 karakter) tanımlanmalı; tanımlı değilse her yeniden başlatmada oturumlar düşüyor.
- IIS arkasındaysa büyük video için `web.config` → `maxAllowedContentLength` artırılmalı.
- Gerçek tablette uçtan uca test yapılmadı (kabul testleri 5–7, 10).
- Release APK imzalama: `android/README.md`.
- Yapılmayanlar: işaretleme ekranında pinch-zoom, prototip JSON yedeğinin içe aktarımı (§14).
- `Database.ps1` içinde sa şifresi düz metin olarak repoda duruyor (önceki commit'lerden).
