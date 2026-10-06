# selvedge — 2026-10-06

## Bağlam
Kullanıcı: "Tanımların hepsini Sentez'den çekmemiz lazım. MFG olan her şeyi Modfex olarak değiştir. Order'ları da
Sentez'den çekmemiz gerekiyor. Bizde QA, anket sistemi kalacak sadece. Kullanıcılar da Sentez'den çekilecek
(örnek giriş: bantsayim)." DB: modfexsrv `SentezCore` (CompanyId=2). Sunucudaki `Selvedge` DB'si kurulu ama iş
verisi boştu (yalnız 193 hata tanımı + admin) → şema serbestçe değiştirilebildi.

Kararlar (kullanıcıya soruldu, hepsi önerilen):
- Order = `Erp_WorkOrder` WorkOrderType=15 (1439 kayıt). `Erp_OrderReceipt` tip 2 (satış siparişi) SentezCore'da yok.
- Marka / Tedarikçi / Firma = Cari (`Erp_CurrentAccount`). Marka = Order'ı olan cari.
- Roller Selvedge'de; ilk admin `Sentez` + `ADM-01..03`, diğerleri QualityControl.
- Yerel kalan: QA raporları, ölçüm, anket, hata kataloğu, POM şablonları + model ölçü tabloları, UPC.

## Yapılanlar

### 1. Sentez → Selvedge ayna eşitlemesi
- **Neden:** 1850 satırlık QA servisi EF navigasyonlarıyla sv_Style/sv_CustomerOrder/sv_Brand'e bağlı. Canlı
  okumaya çevirmek yerine yerel tabloları salt-okunur ayna yapmak QA/anket kodunu hiç bozmadı.
- **Ne yapıldı:**
  - `SentezSyncService` (Infrastructure/Sentez): Selvedge bağlantısında **cross-database** set-based MERGE
    (`SentezSyncSql.cs`, `{S}` → `[SentezCore]`, `@CompanyId`, `@AdminCodes`). Tek transaction + `sp_getapplock`.
    Sıra: Sezon → Cari (Supplier, Firm, Brand) → `#wv` varyant satırları → Renk/Beden → Model → Order → Order
    beden/renk adetleri → Kullanıcı. Kaynak #temp'e alınır, kod çakışmaları ROW_NUMBER ile tekillenir, Sentez
    kimliği olmayan aynı kodlu yerel satır önce sahiplenilir, sonra MERGE. Sentez'de olmayan → `IsDeleted=1`.
    Renk/beden yalnız upsert (ölçü Excel'inden gelen ek kodlar silinmesin).
  - Order'ın QC durumu (Status/FinalQc/Supplier) yerel; Sentez'de iptal → `Cancelled`.
  - Yeni kullanıcıya OUTPUT ile rol: AdminCodes → Admin, değilse QualityControl.
  - `SentezSyncWorker` (Api, BackgroundService): açılışta + `Sentez:SyncIntervalMinutes` (10).
  - `SentezController`: `GET/POST /api/sentez/sync` (POST Admin).
  - appsettings `Sentez: { Database: SentezCore, CompanyId: 2, SyncIntervalMinutes: 10, AdminUserCodes }`.
- **ÖNEMLİ bulgu:** SentezCore `Turkish_CS_AS`, Selvedge `SQL_Latin1_General_CP1_CI_AS` → kaynak metin kolonları ve
  PARTITION BY anahtarları `COLLATE DATABASE_DEFAULT`.
- **Doğrulama:** Sunucuda `Selvedge` DB'de BEGIN TRAN → 0027 + tüm eşitleme → ROLLBACK (kalıcı değişiklik yok,
  `COL_LENGTH` NULL doğrulandı). Sonuç: Sezon 12, Model 588, Order 1439, OrderBeden 23 402 (beden toplamı = Order
  miktarı), Renk 163, Beden 64, Marka 13, Tedarikçi/Firma 49, aktif kullanıcı 41. İkinci çalıştırma 0 değişiklik.
  Not: 192.168.0.2 bu makineden erişilemedi; **Tailscale IP 100.119.104.122** ile bağlanıldı.
- **Dosyalar:** `src/Selvedge.Infrastructure/Sentez/SentezSync{Sql,Service}.cs`,
  `src/Selvedge.Application/Common/{SentezOptions.cs,Abstractions/ISentezSyncService.cs}`, `src/Selvedge.Api/Sentez/*`.

### 2. Giriş Sentez'den
- `AuthService.LoginAsync`: `Meta_User` (UserCode, IsDeleted=0, IsUserRole=0) → şifre `MD5(UTF-16LE(trim))` büyük
  hex (bantsayim `SentezGiris` ile aynı) → yerel ayna kullanıcı (`SentezUserId`); yoksa `SyncUsersAsync` sonra tekrar.
  `IPasswordHasher`/BCrypt kaldırıldı. Kullanıcı ekle/sil/şifre uçları kaldırıldı; PUT yalnız dil+rol+tedarikçi.

### 3. Migration 0027 + seed
- `db/migrations/0027_sentez_kaynak.sql`: `SentezSeasonId`, `SentezInventoryId`, `SentezWorkOrderId`,
  `SentezCurrentAccountId` (Brand/Supplier/Firm) + filtreli unique index; Size.Code, OrderSize.ColorCode,
  QaSample/QaMeasurement kodları 32'ye; `UX_sv_User_Email` kaldırıldı (Sentez e-postaları boş/ortak);
  `SentezUserId IS NULL` kullanıcılar pasif; eski `vw_Sentez*` view'leri DROP; `ReportTemplate 'MFG' → 'MODFEX'`.
- `db/seed/0002_admin_user.sql` boşaltıldı (yeni kurulumda 0027'den sonra aktif admin/Admin123! oluşmasın).
- `db/kurulum/9001_yetki.sql`: SentezCore'da 9 tablo SELECT (WorkOrderItemVariant, InventoryVariant, VariantItem eklendi).

### 4. Kaldırılanlar
- Tanım (marka/sezon/beden/renk/tedarikçi/firma) ve Order ekle/düzenle/sil uçları; Model PUT yalnız yerel QA alanları.
- PO/Style PDF içe aktarma, firma Excel; `Selvedge.PdfImport` + `Selvedge.Watcher` projeleri, `/api/pdf-imports`,
  `/api/ingest`, `/api/mfg-orders` (MfgOrders), `db/views/sentez_views.sql`.

### 5. Web + mobil (iki paralel ajan)
- Web: salt-okunur listeler + "Sentez'den eşitlenir" notu, Order sayfasında Admin "Sentez'den eşitle" + son eşitleme
  zamanı (`src/api/sentez.ts`), salt-okunur Order detay modalı, kullanıcı formu yalnız dil/rol/tedarikçi, giriş
  etiketi "Sentez kullanıcı kodu", MFG→MODFEX. `tsc -b`, `vite build` geçti; eslint yeni sorun yok.
- Mobil: firma formu + Excel ekranı silindi, giriş etiketi, 'MFG'→'MODFEX', iç anahtar 'mfg'→'modfex'.
  `flutter analyze` önce/sonra 89 info.
- **Doğrulama:** `dotnet build Selvedge.slnx -c Release` 0 hata.
- **Commit:** `3cef4b1` — Sentez kaynak: tanimlar, Order'lar ve kullanicilar Sentez'den; MFG -> Modfex

## Açık kalanlar / sonraki adım
- Sunucuya kurulmadı. Kurulum: önce `sql\sql-1-yetki.cmd` yeniden (yeni GRANT'ler), sonra `yayinla.ps1` +
  `servis-kur.ps1`. API uçtan uca (giriş + eşitleme) gerçek sunucuda henüz denenmedi; SQL rollback testiyle doğrulandı.
- APK yeniden derlenmedi (mobil değişti).
- `src/selvedge_mobil/analysis_options.yaml` bu işten önce değiştirilmişti; commit'e alınmadı.
- Mobil `pubspec.yaml`'daki `file_picker` artık kullanılmıyor olabilir.

### 6. Yayın paketi
- **Komut:** `powershell -ExecutionPolicy Bypass -File deploy\yayinla.ps1`
- **Sonuç:** `publish\Selvedge-Modfex-Servis-20261006-1254.zip` (47.6 MB, gitignore). İçinde: web wwwroot, API,
  `db/migrations/0027_sentez_kaynak.sql`, `appsettings.json` (Sentez bölümü), doldurulmuş
  `appsettings.Production.json` + `sql\sql-1-yetki.cmd` (**parola içerir**, kurulumdan sonra zip silinmeli),
  `servis-kur.ps1`. `db/views` artık yok.
- Sunucuda sıra: `sql\sql-1-yetki.cmd` (yeni GRANT'ler) → `servis-kur.ps1`.

---

## Devam: eşitleme iptal → doğrudan SentezCore (kullanıcı: "senkronizasyonu iptal et. direk sentez database'inden çalışacak")

### 7. Ayna tablolar → canlı view'ler
- **Durum:** Paket sunucuya kurulmuştu (`_sv_SqlMigrations`'ta 0027 var, `sv_CustomerOrder` 0 kayıt, `sv_User` 42).
- **Karar:** Tablo yerine **aynı adlı view** → EF modeli ve QA/anket servisleri değişmeden canlı Sentez okur.
  Kimlik = Sentez RecId. Yazılabilir yerel alanlar küçük tablolarda; view'de `INSTEAD OF UPDATE` tetikleyicisi
  (EF `ToTable(..., t => t.HasTrigger(...))` — OUTPUT kullanmasın diye).
- **Ne yapıldı:** `db/migrations/0028_sentez_canli.sql`:
  1. 10 tabloya bağlı tüm FK'ler dinamik DROP.
  2. Yerel tablolar: `sv_OrderQc` (Status, SupplierId, Notes, FinalQcResult/At), `sv_StyleQa` (QA alanları),
     `sv_UserPref` (PreferredLanguage, LastLoginAt).
  3. `sv_RefreshToken`, `sv_UserRole`, `sv_UserSupplier` temizlendi (eski yerel kimlikler); 10 tablo DROP.
  4. View'ler: Season, Supplier, Firm, Brand (Order'ı olan cari), Color/Size (VariantType 'Renk'/'%Beden%',
     kod başına MIN(RecId)), Style (tip 15 kalemlerindeki stok + sv_StyleQa), CustomerOrder (WorkOrder tip 15 +
     sv_OrderQc; iptal → Cancelled), CustomerOrderSize (Variant1 renk/Variant2 beden, kodla view join), User
     (Meta_User + sv_UserPref). Tüm id kolonları `CAST(... AS BIGINT)` (Meta_User/VariantItem RecId int — EF long okur).
  5. Tetikleyiciler: `TR_sv_CustomerOrder_Update`, `TR_sv_Style_Update`, `TR_sv_User_Update` (MERGE).
- Kod: `SentezSyncService/Sql`, `SentezSyncWorker`, `SentezController` silindi; `SentezUserDirectory` (yalnız
  Meta_User şifre okuma). `AuthService`: rolsüz kullanıcıya ilk girişte AdminUserCodes → Admin, değilse QC.
  Model ölçü Excel'i bilinmeyen bedeni oluşturmaz, uyarıyla atlar. Entity'lerden Sentez*Id kaldırıldı.
  Web: eşitle düğmesi/son eşitleme kaldırıldı. `9001_yetki.sql`: +Erp_VariantCard, +Erp_VariantType (11 tablo).
- **Doğrulama:**
  - Sunucu `Selvedge`'de BEGIN TRAN → 0028 → sayılar/tetikleyici → ROLLBACK: Season 12, Style 588, Order 1439,
    OrderSize 23 402, Color 517, Size 120, Brand 13, Supplier/Firm 49, User 41; UPDATE'lerde `@@ROWCOUNT = 1`.
  - Uçtan uca: sunucuda geçici `SelvedgeTest` DB → API yerelde (`ConnectionStrings__Selvedge` env) → tüm
    migration'lar temiz → dev Jwt anahtarıyla ADM-01 (RecId 104, Admin) token'ı (python HMAC) ile: Order listesi/
    detay (4 beden satırı, toplam 2500), lookups, firms, users, PATCH supplier, PUT style, PUT user (rol),
    POST qa-reports (201), POST final-qc (Order Closed/Pass), birleşik QA PDF (200, 54 KB), yanlış şifre girişi 401.
    Yerel tablolara doğru yazdığı SQL ile görüldü. Sonra `SelvedgeTest` DROP edildi.
- **Commit:** `3caf65f` — Sentez: esitleme kaldirildi, tanim/Order/kullanici dogrudan SentezCore'dan
- **Paket:** `publish\Selvedge-Modfex-Servis-20261006-1336.zip` (parola içerir).

## Açık kalanlar (güncel)
- Sunucuda: önce `sql\sql-1-yetki.cmd` (yeni GRANT'ler — yoksa view'ler hata verir), sonra `servis-kur.ps1`.
  0028 açılışta otomatik uygulanır. Gerçek Sentez şifresiyle giriş henüz denenmedi (şifre bilinmiyor; MD5 yolu
  bantsayim ile aynı).
- `src/Selvedge.Web/package-lock.json` yayinla.ps1'in npm install'ı ile değişti, commit'lenmedi.
- APK yeniden derlenmedi.

### 8. Android APK 1.0.1+2
- **Neden:** Mobil kod Sentez girişi / salt-okunur tanımlar / MODFEX için değişmişti (madde 5).
- **Ne yapıldı:** `pubspec.yaml` `1.0.0+1 → 1.0.1+2`, `lib/core/version.dart` `kAppVersion` (Frederic'ten kalan
  `1.0.4.77`) → `1.0.1.2`. `powershell -ExecutionPolicy Bypass -File deploy\build-apk.ps1`.
- **Sonuç:** `publish\modfex-qc-1.0.1.2.apk` (74.8 MB). Cihazda denenmedi.
  `web/index.html` splash üretiminin yan etkisiyle değişti, commit'lenmedi.
- **Commit:** `ea6e849` — mobil: surum 1.0.1+2
