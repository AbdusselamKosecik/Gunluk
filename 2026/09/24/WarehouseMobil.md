# WarehouseMobil — 2026-09-24

## Bağlam
Ayarlar ekranında DB bilgileri elle yazılıyordu. İstek: veritabanı bilgilerinin seçilebildiği
bir parametreler ekranı. Kapsam sorusunda kullanıcı yalnızca "listeden seçim"i seçti
(bağlantı profilleri, girişten erişim, yönetici şifresi seçilmedi). Tur ortasında varsayılan
bağlantı bilgileri verildi: 192.168.1.3 / sa / (şifre) / SentezCore2026Test.

## Yapılanlar

### 1. Parametreler ekranı: veritabanı ve depo listeden seçim
- **Neden:** Veritabanı ve depo kodunu elle yazmak hataya açık; sunucudan liste gelsin.
- **Ne yapıldı:**
  - Ekran başlığı AYARLAR → PARAMETRELER (`strings.xml` `settings`).
  - VERİTABANI ve DEPO KODU alanlarının yanına `SEÇ` butonu (88dp, border zemin, amber yazı).
    Alan elle de yazılabilir kaldı.
  - Kullanıcı/şifre alanları veritabanı alanının üstüne taşındı (listeyi almak için önce lazım).
  - `Db.listDatabases()`: `master`'a bağlanır (`open(database)` / `url(database)` parametresi
    eklendi), `SELECT name FROM sys.databases WHERE database_id > 4 AND state = 0 AND
    HAS_DBACCESS(name) = 1 ORDER BY name`.
  - `SpRepo.warehouses()` → yeni `sp_WM_WarehouseList` (DepoKodu, Ad). `Sp.WAREHOUSE_LIST`.
  - `SettingsActivity.fetchAndPick(button, title, current, load, onPick)`: butonu kilitler,
    "Liste alınıyor…" yazar, AlertDialog `setSingleChoiceItems` ile gösterir, mevcut değer
    işaretli gelir; hata/boş liste kırmızı olarak `testResult` satırına yazılır.
    Seçimden önce `save()` çağrılır (test butonuyla aynı davranış).
  - SQL: `03-sp.sql` (gövde + GRANT), `00-sozlesme.sql` (imza), `04-test.sql` (EXEC), README.
- **Dokunulan dosyalar:** `data/db/Db.kt`, `data/db/SpRepo.kt`, `ui/SettingsActivity.kt`,
  `res/layout/activity_settings.xml`, `res/values/strings.xml`, `docs/mssql/00,03,04`, `README.md`
- **Sonuç / doğrulama:** `assembleDebug` + `lintDebug` başarılı, 0 hata, 108 uyarı (öncesiyle
  aynı). Veritabanı sorgusu gerçek sunucuda (PowerShell SqlClient) denendi: SentezCore2026,
  SentezCore2026Test, SentezServices döndü. Cihazda/emülatörde denenmedi (adb PATH'te yok).
- **Commit:** `0a0e3ed` — Parametreler ekrani: veritabani ve depo listeden secilir

### 2. Varsayılan bağlantı bilgileri
- **Neden:** Kullanıcı varsayılanları verdi; `sa` şifresi GitLab'a girmemeli.
- **Ne yapıldı:** `app/build.gradle.kts` `local.properties`'i okur (`import java.util.Properties`
  — kts içinde `java.util...` android `java` eklentisiyle çakışıyor, import şart) ve
  `DEF_DB_HOST/NAME/USER/PASS` BuildConfig alanlarını üretir. `Prefs` varsayılanları bunlardan.
  `local.properties` (gitignored) içine eklendi:
  ```properties
  wm.db.host=192.168.1.3
  wm.db.name=SentezCore2026Test
  wm.db.user=sa
  wm.db.pass=<sa şifresi — kullanıcıda>
  ```
- **Not:** Varsayılanlar sadece prefs'te değer yoksa geçerli; önceden kaydedilmiş cihazda
  eski değerler kalır (uygulama verisi silinirse yeniler gelir).

## Kararlar
- Şifre repoya değil `local.properties`'e; disk uçarsa bu 4 satır elle yeniden yazılır.
- Profiller / yönetici şifresi / girişten erişim yapılmadı (kullanıcı seçmedi).

## Açık kalanlar / sonraki adım
- `sp_WM_WarehouseList` (ve tüm `sp_WM_*`) SentezCore2026Test'te yok — Sentez şemasına göre
  yazılmalı; o zamana kadar DEPO `SEÇ` "Could not find stored procedure" hatası verir.
- SQL modda parametrelere yalnızca menüden (girişten sonra) ulaşılıyor; bağlantı bozuksa
  giriş yapılamaz → giriş ekranından erişim gerekebilir.
- Cihazda ekran testi.
