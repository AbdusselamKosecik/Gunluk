# muftelif — 2026-10-03

## Bağlam
Yeni iş: `X:\Gitlab\fredericTr\muftelif\Selvedge` için **Sentez'e bağlı yeni bir proje**
planlanacak. Kullanıcı girişi Sentez'den, order/model Sentez'den, anket + QA tabloları
`UZM_Servege_*` (sonradan `UZM_Selvedge_*` olarak düzeltildi), dosyalar sunucuda yerelde.
Kod yazılmadı — bu tur tamamen tasarım.

## Yapılanlar

### 1. Mevcut durumun çıkarılması (kod yazmadan önce)
- **Neden:** "yeni proje" denmişti ama `Selvedge/` boş değil. Ne olduğunu bilmeden
  planlamak, çalışan bir ürünü yanlışlıkla kapsama almak demekti.
- **Bulgular:**
  - `Selvedge` **yayında bir ürün**: kendi SQL Server DB'si (`Selvedge`), 38 `sv_*` tablo,
    26 migration, kendi kullanıcı/rol/JWT tabloları, dosyalar `C:\Selvedge\files`,
    mobil APK **1.0.4.80**, `mfg.nasilbu.com`.
  - Sentez'e kısmen bağlı: `Selvedge` DB'si içinde SentezLive'ı okuyan 8 view
    (`vw_SentezUser`, `vw_SentezWorkOrder`, `vw_SentezUzmOrder`, `vw_SentezInventory`...),
    73 ayrı SentezLive referansı.
  - 13 alt sistem: Dashboard, Customer Orders, Ölçüm, KK, Anket, Hata kataloğu, Lookup'lar,
    Firma, Kullanıcı/Rol, Ekler, PO PDF import, PDF rapor, Watcher, mobil.
- **Sonuç:** tek spec'e sığmaz; parçalanması gerektiği kullanıcıya söylendi.

### 2. Sentez giriş ve okuma yüzeyinin tespiti
- **Giriş:** `SentezLive.dbo.Meta_User`, Unicode MD5 hex-upper, salt yok
  (`SentezPlaning/api/Auth/SentezAuthService.cs`). Sentez rol döndürmüyor → yetki bizde.
- **Order/model:** `Erp_WorkOrder`, `Erp_WorkOrderItem`, `Erp_Inventory`,
  `Erp_CurrentAccount`, `Erp_Season`, `Erp_WorkOrderAttachment`.
- **Dosyalar:** `Selvedge/db/views/sentez_views.sql` bunların eşlemesini zaten taşıyor.

### 3. mezura ölçüm modelinin çıkarılması
- **Neden:** kullanıcı "ölçüm tablosu `X:\Gitlab\fredericTr\mezura`daki gibi olsun ama
  bizim tablomuz olsun" dedi.
- **Bulgular:** mezura bir .NET MAUI uygulaması, `.sql` dosyası yok — tabloları doğrudan
  SentezLive'daki `Uzm_Measure` (başlık) + `Uzm_MeasureItem` (satır), yazma
  `UZM_MeasureUpdateOrInsert` prosedürüyle.
  - Başlık: `WorkOrderId`, `UserId`, `WorkOrderAttachmentId`, `WorkOrderAttachmentType`,
    `Size`, `StartTime`, `EndTime`
  - Satır: `MeasureId`, `Short` (sıra), `Process` (POM kodu), `Description`, `Size`,
    `Tolerans`, `Referance` (spec), `Measurement` (ölçülen), `IsSkip`
  - **Spec'in kaynağı Sentez:** POM listesi iş emrine ekli Excel'den
    (`Erp_WorkOrderAttachment.Attachment` blob, adı `UD_MeasurementType`). Excel düzeni
    sabit: 10. satırda bedenler 6. kolondan, satırlarda 1=sıra 2=POM 4=açıklama
    5=tolerans 6+=spec (`Services/ExcelReader.cs`).
  - **Ölçü aleti bluetooth mezura:** değer "barkod" string olarak geliyor, ondalığa
    çevriliyor, bazı POM'larda **×2** ediliyor (yarım ölçülen yerler).
- **mezura'da tekrarlanmayacak 4 şey** (spec'e yazıldı): ×2 listesi kodda bozuk (iki blok
  yapışmış, `WAIST` 2, `SWEEP` 3 kez); beden hem başlıkta hem satırda; SQL string
  birleştirmeyle kuruluyor (`where m.RecId={recId}`); `IsSkip` olunca ölçü 0 yazılıyor
  ("atlandı" ile "0 ölçüldü" aynı değere düşüyor).

### 4. Tasarım kararları (kullanıcıyla tek tek onaylandı)
- Mevcut Selvedge **dokunulmaz**, paralel çalışır; yeni uygulama sıfır veriyle başlar.
- Tablolar **SentezLive içinde**, `UZM_Selvedge_*` önekiyle. ("Servege" yazımı düzeltildi.)
- Şema mevcut `sv_*`'tan taşınır; Sentez'e giden 4 kolon adı değişir.
- Faz 1 = iskelet + anket + KK (+ ölçüm, sonradan kullanıcı isteğiyle eklendi).
- Mimari: SentezPlaning/SarfKullanim kalıbı (tek IIS sitesi, Dapper, elle SQL).

### 5. İki tasarım kararı ki gerekçesi önemli
- **Sentez'e yazmama garantisi koda değil veritabanı yetkisine bağlandı:**
  `GRANT SELECT ON SCHEMA::dbo` + 20 tabloda tek tek write. `DENY` **kullanılmıyor** —
  SQL Server'da `DENY` `GRANT`'i ezer, şema düzeyinde `DENY INSERT` verilse kendi
  tablolarımıza da yazılamazdı.
- **Uygulamanın DDL yetkisi yok.** İlk tasarımda "açılışta şema runner" önermiştim;
  geri aldım — o, IIS'te koşan siteye ERP'nin canlı DB'sinde DDL yetkisi vermek demekti.
  Şema ayrı CLI ile uygulanır, uygulama yalnızca doğrular, eksikse açılmaz.

### 6. Spec yazıldı ve kendi gözden geçirmemde iki şey düzeldi
- **Tablo sayımı hatalıydı:** listelediğim tablolar 21 veriyordu, metinde 20 yazmıştım
  (`Role`+`UserRole`'ü tek satırda sayarken bir tablo kaybetmişim).
- **`sv_Attachment` ile `sv_QaAttachment` aynı işi yapıyordu.** Tek `Attachment`
  tablosunda birleştirildi (`EntityType`/`EntityId`) → 20 tablo. Mevcut şemayı taşıma
  kararından bilinçli tek sapma, spec'te gerekçesiyle yazılı.
- **Dokümanda açık bırakılanlar** (tahminle şema kurmamak için): `QaSample` renk/beden
  kırılımının ERP'de hangi tabloda durduğu, SentezLive'daki mevcut `UZM_*` nesne listesi,
  rapor şablonu sayısı.
- **Dosya:** `docs/superpowers/specs/2026-10-03-sentezselvedge-design.md`
- **Commit:** `982a9c0`

## Kararlar
- Mevcut Selvedge'ye dokunulmayacak; iki sistem bir süre paralel yaşayacak.
- Veri taşıma ayrı bir karar; şema bunu mümkün kılacak şekilde (4 kolon eşlemesi) kuruldu.
- Yetkiler tabloda değil kodda; yerel kullanıcı tablosu hiç yok, isim `Meta_User`'a JOIN.
- İlk yönetici kilitlenmesi `appsettings`'teki `Selvedge:Yoneticiler` listesiyle çözülüyor.
- Veri iki ayrı yerde olacak (tablolar SentezLive yedeğinde, dosyalar diskte) — geri
  yükleme ikisini aynı ana denk getirmek zorunda. Dosya klasörü için ayrı yedek gerekiyor.
- Dağıtım portu 91 (89 SarfKullanim, 90 SentezPlaning).

## Açık kalanlar / sonraki adım
- Kullanıcı spec'i okuyup onaylayacak; sonra `writing-plans` ile implementasyon planı.
  Plan iki tura bölünecek: (a) iskelet + anket, (b) KK + ölçüm.
- **VPN düştü** (`192.168.1.22` erişilemiyor, 1433 kapalı): yukarıdaki üç doğrulama
  maddesi VPN gelince ölçülüp spec güncellenecek.
