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
