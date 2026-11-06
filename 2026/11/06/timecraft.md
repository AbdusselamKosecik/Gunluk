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

### 10. Order = Erp_WorkOrder (düzeltme) + emülatörde uçtan uca test
- **Geri bildirim:** "Model adı/kodu hiç gelmiyor", "Order dediğimiz Erp_WorkOrder". Kullanıcı UZM şifresini emülatör testi için verdi.
- **Kök neden:** Sipariş kaynağı yanlış seçilmişti (`Erp_OrderReceipt` satış siparişi). Doğrusu üretim iş emri.
- **Veri tespiti:**
  - `Erp_WorkOrder` WorkOrderType **15** = üretim iş emri, WorkOrderNo sayısal (96236). Model `Erp_WorkOrderItem.InventoryId` → `Erp_Inventory`; başlıktaki InventoryId boş.
  - 18.078 iş emrinden yalnız 31'inde birden fazla model var. WorkOrderNo benzersiz.
  - Tip 30 (33,5 bin satır) bakım kaydı (ResourceId = makine, Maintenance* alanları), kapsam dışı.
- **Ne yapıldı:**
  - `EtutOrderLookup` iş emrine çevrildi: OUTER APPLY ile ilk model + yıkama özeti, order no ile başlayanlar önce, model kodu/adıyla da arama. LTRIM/RTRIM (ERP'de " RINSE" gibi boşluklu değerler var).
  - Android: öneri satırı "96236 — 2282-3025 COURT DENIM SHORT — müşteri". Tek modelde seçim anında dolduruluyor.
  - Yıkama kuralı: yalnız boşsa ya da önceki otomatik değerse güncelleniyor (`autoWash`). Böylece order değişince yıkama da değişiyor; elle seçilen yıkamaya dokunulmuyor.
  - UZM'ye (RecId 78) etüt yetkileri verildi (yetki yönetimi hariç, `UpdatedBy=12`). Yetkisizken form salt-okunur açılıyor, order/model alanları hiç açılmıyordu.
- **Emülatör kurulumu:**
  ```bash
  sdkmanager --install "system-images;android-34;google_apis;x86_64"
  avdmanager create avd -n Etut_Tablet_34 -k "system-images;android-34;google_apis;x86_64" -d pixel_tablet
  emulator -avd Etut_Tablet_34 -no-snapshot -no-audio -gpu swiftshader_indirect
  ```
  - Mevcut AVD'ler API 23'tü, uygulamanın minSdk'i 26.
  - Arayüz `adb uiautomator dump` + `input tap/text` ile sürüldü (scratchpad'de `ui.py`).
  - Yerel backend `0.0.0.0:5099` üzerinde paketin JwtKey'iyle çalıştırıldı; emülatörde sunucu `http://10.0.2.2:5099/`.
- **Doğrulama (emülatör, UZM ile):**
  - "9623" yazınca öneriler geldi; 96236 seçilince Model no 2282-3025, Model adı COURT DENIM SHORT, Yıkama CUPID oldu.
  - 96175 tam yazılınca A9191E-1968-1664 / REN HIGH RISE WIDE LEG / YUMA oldu (yıkama CUPID'den güncellendi).
  - Not: Çok hızlı `adb input text` ile karakterler başka alana kayabildi; karakter başına 0,2 sn ile sorun yok. Gerçek klavyede ayrıca gözlenmeli.
- **Paket:** Yeniden publish edildi (JwtKey korundu); zip ve APK güncellendi. Canlı IIS'e kurulmadı (erişim yok).
- **Commit:** `1b59116`

### 11. Fotoğrafta ölçü: 2 nokta → cm popup → ok uçlu çizgi (çoklu)
- **İstek:** Resim üzerinde 2 nokta işaretlensin, popup'ta cm girilsin, çizgi ok uçlu olsun, birden fazla ölçü eklenebilsin.
- **Durum:**
  - 2 nokta → cm popup → çoklu ölçü ve kayıt (`PUT media/{id}/annotations`) zaten vardı. Kullanıcı görmemiş olabilir, çünkü editör küçük resme dokununca açılıyor ve 500 yüzünden foto yüklenemiyordu.
  - Eksik olanlar: ok uçları ve okunur etiket.
- **Ne yapıldı (`MediaTabs.kt`):**
  - `drawMeasure()` ekran ve dışa aktarma için ortak: çizgi + iki uçta dolu üçgen ok (`Path`), beyaz zeminli yuvarlak etiket "N) xx,x cm".
  - Etiket çizginin normali yönünde kayıyor (yatayda üste, dikeyde sağa).
  - Çakışma önleme: denenen konumlar t = 0.5, 0.3, 0.7, 0.2, 0.8 …; dolu dikdörtgenler listesinde `RectF.intersects` ile kontrol.
  - Foto yüksekliği 520dp ile sınırlandı (`heightIn` + `aspectRatio(matchHeightConstraintsFirst)`); tablette kaydırmadan iki nokta seçilebiliyor.
  - Yönerge metni güncellendi.
- **Emülatör testi:**
  - Yerel backend'le etüt #1'e 800x600 test PNG'si yüklendi.
  - Yatay 60 cm ve dikey 25,5 cm ölçü eklendi, "İşaretleri kaydet" yapıldı. APK yeniden kurulup açıldığında "2 işaret" sunucudan geri geldi ve etiketler ayrık göründü.
  - Test fotoğrafı silindi (etüt #1'de aktif medya 0).
- **Commit:** `5af9012`. APK güncellendi; backend değişmediği için IIS zip'i aynı.

### 12. Web etüt ekranları + onayda SMV'nin Sentez'e yazılması
- **İstek:** APK'daki liste ve detay webde de görünsün; webde düzenleme, foto/video izleme ve SMV değiştirme olsun. SMV değişince Sentez'deki operasyon süresi güncellensin.
- **Veri tespiti:**
  - Model × operasyon süresi `Erp_InventoryWorkStudy` tablosunda (InventoryId × ProcessId; StandartTime1/2/3, StandartTimeActual; dakika).
  - Etüt işlem kodları `Erp_Process.ProcessCode` ile birebir eşleşiyor (16/16).
  - Örnek: A384-2061 / 5206-1 → StandartTime1 = 0,75, StandartTimeActual = 0,7546. Mevcut WorkStudy ekranı StandartTimeActual'ı topluyor.
- **Kullanıcı kararları (AskUserQuestion):**
  1. SMV, StandartTime1 **ve** StandartTimeActual alanlarına yazılır.
  2. Rotada satır yoksa yazılmaz, uyarı verilir.
  3. Yazım yalnız **onayda** yapılır.
- **Backend:**
  - `IEtutSentezSync` / `EtutSentezSync`: `CurrentAsync` okur, `WriteSmvAsync` ile UPDATE … FROM JOIN (UpdatedAt, UpdatedBy = onaylayan).
  - `TransitionAsync` approve geçişinde `BeginTransaction` açıyor: CommitAsync + yazım + `sentezSync` geçmiş olayı. Hata olursa onay da geri alınıyor.
  - `StudyDetailDto.Notice` eklendi.
  - Servise isteğe bağlı 3. parametre eklendi; mevcut testler değişmedi.
- **Web (`EtutController`, `Views/Etut`):**
  - Liste: tabletteki filtreler ve sıralama.
  - Detay:
    - Bilgi formu; ölçümler saniye olarak (tr virgül/nokta ayrıştırma; değişmeyen ölçümün kaynağı korunuyor), makine.
    - İşlem kodu seçilince açıklama ve önerilen makine geliyor; order önerisi (`/Etut/Orders`) model, ad ve yıkamayı dolduruyor.
    - Hesap kartı; SMV & kontrol (SMV değiştir/kaydet, onayla ve Sentez'e yaz, düzeltme iste, temizle).
    - **Sentez'deki mevcut süre kutusu:** satır yoksa uyarı gösteriyor.
    - Foto: canvas üzerinde tabletle aynı ok/etiket çizimi, büyük görünüm modalı.
    - Video: HTML5 `<video>`, `PhysicalFile(enableRangeProcessing)`.
    - Geçmiş tablosu.
  - Menüye "Etüt Kayıtları" eklendi.
- **Android:** Onay sonrası `notice` mesajı gösteriliyor.
- **Doğrulama:**
  - 34/34 test. Yeni testler: yazım ve geçmiş, satır yoksa uyarı, yazım hatasında onayın geri alınması, onay dışı geçişte yazım olmaması.
  - Chrome DevTools ile web girişi (UZM) yapıldı:
    - Liste 4 gerçek etüdü gösterdi.
    - Etüt #4 (A384-2061/5210-1) için "rotada yok" uyarısı çıktı.
    - Etüt #3 (5206-1) için Sentez 0,75 / 0,7546 okundu.
    - Etüt #1'e yüklenen test fotoğrafında oklar ve etiketler küçük ve büyük görünümde doğru çizildi (test fotoğrafı silindi).
  - **Gerçek UPDATE SQL'i** `BEGIN TRAN … ROLLBACK` ile denendi: 1 satır güncellendi (0,833), geri alma sonrası değer 0,75 / 0,7546. Canlıya kalıcı yazım yapılmadı.
  - Uçtan uca onay akışı (gerçek kalıcı yazım) çalıştırılmadı; canlı ERP'yi değiştireceği için kullanıcıya bırakıldı.
- **Not:** Etüt #3'ün foto ve videosu IIS sunucusunun diskinde; yerel çalıştırmada açılmadı (beklenen durum).
- **Paket:** Yeniden publish edildi (JwtKey korundu), zip ve APK güncellendi.
- **Commit:** `bd50080`

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

### 13. Web: Excel etüt formu (BENSON- ÖN SÜRME şablonu) + Yazdır/PDF
- **Neden:** Firma webden şablondaki Excel'i ve tabletteki "Yazdır / PDF" çıktısını istedi.
- **Ne yapıldı:**
  - `EtutExcelExport.Build` (ClosedXML), `doc/BENSON- ÖN SÜRME.xlsx` düzenini birebir üretiyor:
    - A1:D2 başlık; satır 3–8 tarih / operatör / operasyon / "modelNo-modelAdı" / yıkama / order (sayı).
    - 15 ölçüm satırı (sn, 0.000).
    - Formüller: TOPLAM `=SUM(B9:B23)/60`, ORTALAMA `=B24/COUNT(...)`; şablondaki sabit `/9` yerine COUNT kullanıldı.
    - DEMET PAYI 0,03, PAYLAR = makine+dinlenme, STANDART ZAMAN `=B25*(1+B27)+B26`.
    - AÇIKLAMA "KİMYASAL: …" + not; SMV varsa ayrı satır.
    - Makine payları tablosu DB'den geliyor; seçili makine sarı ve kalın.
  - Dosya adı "YIKAMA- İŞLEM.xlsx" (UTF-8 filename*).
  - `/Etut/Print/{id}`: tabletteki buildResultHtml'in Razor kopyası; açılınca window.print() çağrılıyor, PDF tarayıcıdan kaydediliyor.
  - Butonlar: detay başlığında ve listede her satırda Excel / PDF.
- **Dokunulan dosyalar:** `Etut/Services/EtutExcelExport.cs`, `Controllers/Etut/EtutController.cs` (Excel, Print), `Views/Etut/Print.cshtml`, `Views/Etut/Details.cshtml`, `Views/Etut/Index.cshtml`, `tests/TimeCraft.Tests/EtutExcelExportTests.cs`, `doc/BENSON- ÖN SÜRME.xlsx`
- **Sonuç / doğrulama:**
  - 35/35 test geçti; ClosedXML formülü hesaplayıp beklenen standart zamanı verdi.
  - Chrome (UZM): `/Etut/Excel/3` 200 döndü (8 KB), hücreler openpyxl ile kontrol edildi; `/Etut/Print/3` ekran görüntüsü doğru.
  - Paket yeniden publish edildi (JwtKey korundu), zip 180 MB.
- **Commit:** `f00aea5`

## Kararlar (13)
- Şablondaki `ORTALAMA=B24/9` sabiti hataydı; ölçüm adedi COUNT ile alınıyor.
- PDF sunucuda üretilmiyor; tarayıcının yazdır → PDF yolu kullanılıyor (tabletle aynı yaklaşım, ek kütüphane yok).
- "Onaya gönderilen SMV onaylanınca Sentez'e" isteği 12. maddede (bd50080) zaten yapıldı; canlıya kurulum bekliyor.

## Açık kalanlar (13)
- `TimeCraft-iis-20261106.zip` IIS'e kurulmalı; App_Data Modify izni verilmeli.

### 14. Kayıt silme, Reçete kaldırma, foto üzerinde serbest ölçü (titreme düzeltme)
- **Neden:** Firma üç şey istedi. (1) Tablet ve webde etüt kaydı silinebilsin. (2) Reçete alanı kalksın; "kalacak" yazılmıştı, kullanıcı "kaldırılsın" diye netleştirdi. (3) Foto üzerinde serbest çizim olsun, C/S gibi kavisli çizilebilsin. Uzunluk elle girilecek, yalnız titreme düzeltilecek.
- **Kararlar (kullanıcı):**
  - Silme yetkisi: **sadece yetki yöneticisi** (`CanManageRoles`).
  - Reçete: ekranlardan kaldırılsın.
- **Ne yapıldı:**
  - **Silme (yumuşak):**
    - `EtutStudyService.DeleteAsync` → `IsDeleted=1`, sürüm artar, `delete` audit olayı nedeniyle birlikte yazılır, 409 çakışma kontrolü var.
    - `EtutPermissions.CanDelete` = `CanManageRoles`; `auth/me` artık `canDelete` döndürüyor.
    - API: `DELETE /api/etut/studies/{id}?version=&reason=`. Web: detayda "Kaydı sil" (prompt ile neden sorulur). Tablet: üst barda "Kaydı sil" + onay diyaloğu.
  - **Reçete:** web formunda hidden input'a çevrildi, böylece kaydetme eski değeri silmiyor. Tablet formundan, listeden, sonuç ekranından ve PDF'ten kaldırıldı. DB sütunu duruyor.
  - **Serbest ölçü (`curve`):**
    - `UZM_ETUT_Annotation.Points NVARCHAR(MAX) NULL` sütunu eklendi. Canlı DB'de sqlcmd ile eklendi (yalnız UZM_ETUT tablosu; ERP'ye dokunulmadı). `etut_schema.sql` idempotent ALTER içeriyor.
    - Sunucu doğrulaması: 2–500 nokta, değerler 0..1 aralığında, cm > 0.
    - Tablet `domain/StrokeSmoother.kt`:
      1. Eşit aralıklı yeniden örnekleme (aralık = köşegen/150).
      2. Uçları sabit kayan ortalama (yarıçap 4), 2 tur.
      3. Douglas–Peucker (tolerans = aralık×0,3).
    - Tablet ekranı: "Serbest ölçü (çiz → cm)" modu (detectDragGestures). Çizerken ham iz mavi görünüyor; bırakınca düzeltilmiş eğri "? cm" ile çiziliyor, ardından cm diyaloğu açılıyor.
    - Çizim: `drawMeasurePath` (ikinci derece eğri, uç okları yerel yöne göre, etiket yay ortasında, çakışma önleme); düz ölçü de bunu kullanıyor. Web `drawAnnotations` aynı algoritmanın JS hali.
- **Dokunulan dosyalar:**
  - Backend: `Etut/Services/EtutStudyService.cs`, `Etut/Api/EtutApiController.cs`, `Etut/Api/EtutDtos.cs`, `Etut/Data/EtutEntities.cs`, `Etut/Domain/EtutRules.cs`, `Etut/Services/EtutInfrastructure.cs`
  - Web: `Controllers/Etut/EtutController.cs`, `Views/Etut/Details.cshtml`, `Views/Etut/Print.cshtml`
  - Doküman: `doc/sql/etut_schema.sql`, `doc/ETUT_API.md`
  - Android: `android/.../domain/StrokeSmoother.kt` (+ test), `ui/editor/MediaTabs.kt`, `EditorScreen.kt`, `EditorViewModel.kt`, `SmvResultTabs.kt`, `ui/list/StudyListScreen.kt`, `data/Dtos.kt`, `data/EtutApi.kt`
- **Komutlar:**
  ```bash
  sqlcmd -S 192.168.1.22 -d SentezLive -U sa -C -Q "IF COL_LENGTH('dbo.UZM_ETUT_Annotation','Points') IS NULL ALTER TABLE dbo.UZM_ETUT_Annotation ADD Points NVARCHAR(MAX) NULL"
  JAVA_HOME="/c/Program Files/Android/openjdk/jdk-21.0.8" ./gradlew :app:testDebugUnitTest :app:assembleDebug
  # yerel test: Etut__JwtKey=test-local-key-... ile çalıştır, SentezY (12) için token scratchpad/mint.py ile üretildi
  ```
- **Sonuç / doğrulama:**
  - .NET testleri 37/37 geçti (silme yetkisi, 409, listeden kalkma, audit, curve doğrulaması). Android `StrokeSmootherTest` 4/4 geçti (±5 px titreşimli S → sapma < 3 px, uçlar sabit).
  - Emülatör: test etüdü #7'ye adb motionevent ile ±12 px titrek bir S çizildi. Düzgün S ve çift ok çıktı; 23,5 cm girilip kaydedildi.
  - Web detayında aynı eğri ve "1) 23,5 cm" etiketi doğru göründü. Reçete etiketi yok.
  - API silme denemesi: UZM 403, eski sürüm 409, SentezY 204; sonra GET 404 döndü. Test etüdü #7 silinmiş durumda (yumuşak).
  - Paket ve APK yenilendi.
- **Commit:** `a29699f`

## Açık kalanlar (14)
- Yeni zip IIS'e kurulmalı ve yeni APK dağıtılmalı. DB sütunu canlıda hazır; eski sürüm sorunsuz çalışır.
- Webde "Kaydı sil" butonu yönetici girişiyle tarayıcıda görülmedi (SentezY şifresi yok); API ve test üzerinden doğrulandı.
