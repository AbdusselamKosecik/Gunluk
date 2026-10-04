# selvedge — 2026-10-04

## Bağlam
Kullanıcı Frederic/MFG'deki eski Selvedge QC sisteminin tamamının (API + kendi `Selvedge` DB + React web +
Flutter mobil) Modfex'e taşınmasını istedi. Kararlar: "Eski Selvedge'in tümü", "Yalnız iç ağ" (modfexsrv
192.168.0.2), IIS (Docker yok), ayrı SQL girişi, SentezSelvedge web kopyası iptal. Doğrudan main dalında çalışıldı.
Yeni repo: `X:\Gitlab\modfex-apparel\selvedge` → git@gitlab.com:modfex-apparel/selvedge.git

## Yapılanlar

### 1. Kaynak kopyası + Modfex uyarlaması
- **Neden:** Eski sistem MFG markalı, `mfg.nasilbu.com`'a gömülü, Docker/nginx ile kurulu.
- **Ne yapıldı:**
  - Yalnız takip edilen dosyalar alındı:
    `git archive HEAD Selvedge/src Selvedge/db Selvedge/tests Selvedge/doc/sentez-inventory.md | tar -x --strip-components=1`
    (kaynak: `X:\Gitlab\fredericTr\muftelif`).
  - `tests/` silindi (Agolde/CoH müşteri PDF fikstürleri), `.slnx`'ten test projesi çıkarıldı.
  - Marka: web `index.html`, `i18n/tr|en.json` (name/tagline/title), `DashboardPage` başlığı,
    PDF şablonları (`OrderQaDocument.cs`, `LevisAuditDocument.cs`) "MFG" → "Modfex".
    Rapor şablon kodu `'MFG'` (DB'de saklanan enum) DEĞİŞTİRİLMEDİ.
  - Logo: gerçek Modfex logosu yok → PIL ile "MODFEX" yazı logosu (`modfex-logo.png`, `modfex-logo-white.png`,
    launcher `icon.png`/`icon_fg.png` "M"). Eski `mfg-logo*.png` silindi.
  - Varsayılan adres `https://mfg.nasilbu.com` → `http://192.168.0.2:8085` (appsettings `Api:PublicBaseUrl`,
    `QaReportService.DefaultPublicBaseUrl`, Watcher).
  - Mobil: `ServerCfg` varsayılanı 192.168.0.2 / HTTP / 8085; `baseUrl` getter; `host|proto|port|db` olarak saklanır
    (anahtar `sv.server.cfg`); `dioProvider` artık `ref.watch(serverCfgProvider)` → release'te ayardaki adres,
    debug'ta `http://10.0.2.2:5000`. `applicationId = com.modfex.selvedge` (namespace/Kotlin paketi aynı),
    etiket "Modfex QC", sürüm 1.0.0+1.
  - API `Program.cs`: `UseDefaultFiles` + `UseStaticFiles` + `MapFallbackToFile("index.html")` (web wwwroot'tan, nginx yok).
  - Seed `0003_lookups.sql`: Frederic marka (AGOLDE, COH) ve tedarikçileri (LEUSART, ÖZAK, POLEN) kaldırıldı.
- **Sonuç:** `dotnet build Selvedge.slnx -c Release` 0 hata; `tsc -b` temiz.
- **Commit:** `71ee32f` — Selvedge: Frederic/MFG kopyasi Modfex'e uyarlandi

### 2. Sentez view'leri → SentezCore, CompanyId=2
- **Neden:** View'ler `SentezLive`'a ve Frederic'e özel kolonlara bağlıydı; SentezCore çok şirketli.
- **Bulgular (salt okunur, `uzman` ile):**
  - API yalnız 3 view kullanıyor: `vw_SentezWorkOrder`, `vw_SentezInventory`, `vw_SentezCurrentAccount` (`MfgOrderService.cs`).
  - Eksik: `Erp_WorkOrderAttachment.UD_MeasurementType/UD_Marker`, `UZM_Order` tablosu.
  - Modfex'te `Erp_WorkOrder.InventoryId` 1444 kaydın hepsinde NULL; stok `Erp_WorkOrderItem`'da.
- **Ne yapıldı:** `db/views/sentez_views.sql`: `SentezCore.dbo.*`, `CompanyId = 2` filtreleri; stok için
  `OUTER APPLY` ile ilk kalemin `InventoryId`'si; UD_ kolonları `CAST(NULL AS NVARCHAR(50))`; UZM_Order view'i
  kaldırıldı. Frederic iş akışı view dosyaları (proses 11/12/15/22, `>'54000'`) repodan silindi (API kullanmıyor).
  `db/kurulum/9001_yetki.sql`: login `uzm_selvedge_app` (parola `sqlcmd -v SelvedgeSifre=`), `Selvedge` DB db_owner,
  SentezCore'da 7 tabloda yalnız SELECT.
- **Doğrulama:** 6 view gövdesi SentezCore'da çalıştırıldı: WorkOrder 1444 (5'i stoksuz), Attachment 7, User 42,
  CurrentAccount 49, Inventory 4168, Season 12.
- **Commit:** `1503d5e`

### 3. IIS yayın paketi + yerel doğrulama
- **Ne yapıldı:** `src/Selvedge.Api/web.config` (inprocess, Production, `maxAllowedContentLength` 50 MB),
  `deploy/yayinla.ps1` (npm install → tsc -b → vite build → dotnet publish → dist'i wwwroot'a → zip),
  `deploy/appsettings.Production.ornek.json` (parolasız şablon), `deploy/KURULUM.md` (IIS site 8085, app pool,
  icacls, firewall LocalSubnet, sqlcmd adımları).
- **Doğrulama:** LocalDB `SelvedgeModfexTest` ile API: 26 migration + 4 seed temiz uygulandı, `admin` girişi token döndü,
  `/` ve `/qa-reports` index.html (title "Modfex — ..."), `/modfex-logo.png` 200, `/api/mfg-orders` 401.
  Not: `timeout dotnet run` alt süreci öldürmüyor → eski Selvedge.Api.exe portta kaldı; `Stop-Process` ile kapatıldı.
  Paket: `publish\Selvedge-Modfex-IIS-20261004-1529.zip` (~51 MB, gitignore).
- **Commit:** `caa111d`

### 4. APK derleme script'i
- **Ne yapıldı:** `deploy/build-apk.ps1` (pub get → flutter_launcher_icons → flutter_native_splash → build apk →
  `publish\modfex-qc-<sürüm>.apk`).
- **Sonuç:** BAŞARISIZ — "Building with plugins requires symlink support. Please enable Developer Mode".
  Bu makinede Windows Geliştirici Modu kapalı (disk değişiminden sonra). APK üretilmedi.
- **Commit:** `48e3ae4`

## Kararlar
- Docker yerine IIS tek site (API + web wwwroot), port 8085, yalnız iç ağ.
- Watcher/PdfImport ve dashboard servisleri kurulmaz (Agolde/CoH PDF ve Frederic depo id'lerine özel).
- CompanyId=2 view'lerde sabit.
- SentezSelvedge web kopyası iptal.

## Açık kalanlar / sonraki adım
- Kullanıcı: Geliştirici Modu aç (`start ms-settings:developers`) → `deploy\build-apk.ps1`.
- DBA: `9001_yetki.sql`; sunucuda Hosting Bundle .NET 10; KURULUM.md adımları; `sentez_views.sql`.
- Gerçek Modfex logosu gelirse `modfex-logo*.png` + launcher ikonları değiştirilecek.
- Sunucuda canlı deneme: Üretim Emirleri listesi, QC kaydı, foto yükleme, PDF.

---

## Devam (öğleden sonra): IIS → Windows servisi, APK

### 5. Windows servisi (kullanıcı: "iis degilde servis olacak sekilde")
- **Ne yapıldı:**
  - `Program.cs`: `WebApplicationOptions { ContentRootPath = WindowsServiceHelpers.IsWindowsService() ? AppContext.BaseDirectory : default }`
    + `builder.Services.AddWindowsService(o => o.ServiceName = "Selvedge")`; Serilog dosya yolu `ContentRootPath\logs`
    (servisin çalışma klasörü System32 olduğu için). Paket `Microsoft.Extensions.Hosting.WindowsServices` 10.0.9.
  - `web.config` silindi, csproj `IsTransformWebConfigDisabled=true`.
  - `deploy/servis-kur.ps1` (sunucuda yönetici, zip klasöründen): ASP.NET Core 10 runtime kontrolü → servisi durdur →
    robocopy `C:\Selvedge\app` (`appsettings.Production.json` hariç) → ilk kez ise örnekten oluşturup durur →
    icacls NetworkService (app RX, logs + `C:\Selvedge\files` M) → `sc.exe create Selvedge start= delayed-auto
    obj= "NT AUTHORITY\NetworkService"` + `sc.exe failure ... restart/10000` → firewall 8085 LocalSubnet → başlat →
    swagger kontrolü.
  - `appsettings.Production.ornek.json`: `Kestrel:Endpoints:Http:Url = http://0.0.0.0:8085`; tek ters bölü
    (`C:\Selvedge\files`) geçersiz JSON hatası düzeltildi.
  - `yayinla.ps1` → `publish\Selvedge-Modfex-Servis-<tarih>.zip` (servis-kur.ps1 dahil). KURULUM.md yeniden yazıldı.
- **Doğrulama:** yayın çıktısı Production ayarı + LocalDB ile çalıştırıldı: 8085'te `/` ve `/login` 200, admin token,
  `/api/mfg-orders` 401, log `publish\selvedge\logs\` altında. Gerçek servis modu (sc create) yönetici gerektirdiği için
  yerelde denenmedi.
- **Commit:** `f00d624`

### 6. APK
- Kullanıcı Geliştirici Modu'nu açtı. İkinci hata: `JAVA_HOME is not set` → `build-apk.ps1`'e varsayılanlar:
  `ANDROID_SDK_ROOT=%LOCALAPPDATA%\Android\Sdk`, `JAVA_HOME=C:\Program Files\Android\openjdk\jdk-21.0.8`.
- **Sonuç:** `publish\modfex-qc-1.0.0.1.apk` (74.8 MB). İkon/splash kaynakları yeniden üretildi.
- **Commit:** `18e8e45`

## Açık kalanlar (güncel)
- Sunucu: runtime 10, `9001_yetki.sql`, `servis-kur.ps1` (iki kez), `sentez_views.sql`, admin parolası.
- APK cihazda denenmedi.

### 7. Sunucu ayarı dolduruldu (kullanıcı: "appseting i sen doldurulmusun")
- **Ne yapıldı:** PowerShell `RandomNumberGenerator` ile SQL parolası (karmaşıklık politikasına uygun, `; " ' = $ \``
  içermez) ve 64 karakter `Jwt:Key` üretildi → `publish\gizli\appsettings.Production.json` (gitignore; repoya ve
  günlüğe yazılmadı). Aynı parolayla `publish\gizli\sql-1-yetki.cmd` (`sqlcmd -E -i 9001_yetki.sql -v SelvedgeSifre=...`)
  ve `sql-2-viewler.cmd`.
  `yayinla.ps1` bunları + `sql\` (9001_yetki.sql, sentez_views.sql) pakete koyar; `servis-kur.ps1` dolu ayarı yalnız
  ilk kurulumda kopyalar, `sql\`'i uygulama klasörüne almaz (robocopy `/L` ile doğrulandı).
- **Paket:** `publish\Selvedge-Modfex-Servis-20261004-2202.zip` (içinde parola var; kurulumdan sonra silinmeli).
- **Risk:** parola yalnız bu diskte (`publish\gizli`). Disk uçarsa: SQL'de `ALTER LOGIN uzm_selvedge_app WITH PASSWORD`
  ile yenisi verilip sunucudaki `C:\Selvedge\app\appsettings.Production.json` güncellenir.
- **Commit:** `e7375c0`

### 8. servis-kur.ps1 SentezServis `kur.ps1` düzenine göre yeniden yazıldı
- **Neden:** Kullanıcı SentezServis'in kur.ps1'ini örnek verdi ("bunun gibi yaparmisin setupu").
- **Ne yapıldı:** comment-based help; `param(-Kaynak=$PSScriptRoot, -Hedef C:\Selvedge\app, -Dosyalar, -Port 8085,
  -Hesap NetworkService)`; yönetici kontrolü; exe/runtime kontrolü; `Yaz()`; servis varsa durdur + `sc.exe config`,
  yoksa `sc.exe create ... delayed-auto`; `sc.exe failure restart/10000/30000/60000`; firewall `Selvedge HTTP 8085`
  LocalSubnet; `WaitForStatus('Running')` + swagger kontrolü. Bizim eklerimiz korundu: appsettings.Production.json
  koruma/paketten/şablondan, `sql\` kopyalanmaz, icacls. Dosya UTF-8 BOM ile (PS 5.1).
- **Doğrulama:** parse 0 hata; yönetici olmayan çalıştırmada "Bu betik yönetici olarak çalıştırılmalıdır." ile durdu.
  Paket: `publish\Selvedge-Modfex-Servis-20261004-2233.zip`.
- **Commit:** `47c97a7`
