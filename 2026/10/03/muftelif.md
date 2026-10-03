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

---

### 7. İmplementasyon planı yazıldı (Faz 1a) ve kendi gözden geçirmemde dört şey düzeldi
- **Neden:** Spec Faz 1'in tamamını tanımlıyor; tek turda yazmak çok büyük. Plan
  (a) iskelet + anket, (b) KK + ölçüm olarak ikiye bölündü. Bu tur (a).
- **Ne yapıldı:** 11 görevlik, ~6350 satırlık plan. Her görev TDD adımlarıyla
  (testi yaz → kırmızı olduğunu gör → implement et → yeşil → commit) yazıldı.
- **Plan öz-gözden geçirmesinde çıkan dört kusur:**
  1. **Dapper ValueTuple'a eşlemez.** Plandaki 4 sorgu `(long, string)` gibi tuple
     döndürüyordu; çalışma anında patlardı. Hepsi adlandırılmış tipe çevrildi.
  2. Review Focus #2 ve #4 yanlış görev numaralarına işaret ediyordu.
  3. `SORU1`/`SEC10` doğrulama adımında elle doldurulacak yer tutucuydu; programatik
     hale getirildi (anket detayından ilk tek-seçimli soru + puanlı seçenek seçiliyor).
  4. Faz 1b'ye bilerek bırakılanlar yazılı değildi; "Spec'in bu plana GİRMEYEN
     kısımları" tablosu eklendi — unutulmuşla bilerek bırakılmış karışmasın.
- **Dosya:** `docs/superpowers/plans/2026-10-03-sentezselvedge-faz1a-iskelet-anket.md`
- **Commit:** `cbd1759`

### 8. Faz 1a uygulandı — 11 görev, 105 test
- **Neden:** Plan onaylandı, native (bu oturumda satır satır) yürütme seçildi.
- **Ne yapıldı / dosyalar:**
  - `SentezSelvedge/db-tool/` — şema uygulayıcı CLI. `ScriptTarayici` **her script'i
    uygulamadan ÖNCE** tarar: `UZM_Selvedge_` öneki olmayan hiçbir nesneye DDL/yazma,
    hiç `DROP` yok. `ScriptUygulayici` SHA256 özetini `UZM_Selvedge_SchemaHistory`'ye
    yazar; daha önce uygulanmış bir script'in içeriği değiştiyse durur.
  - `SentezSelvedge/db/0001..0003_*.sql` — 14 tablo, idempotent. Türkçe harfli
    tohum verisi `NCHAR()` ile kuruluyor (sqlcmd `.sql` dosyasını ANSI okuyor).
  - `SentezSelvedge/db/elle/9001_yetki.sql` — SQL kullanıcısı + izinler. **Bilerek
    `db/` ALTINDA DEĞİL**, yoksa runner onu da otomatik koşturur.
  - `api/Sentez/` — Sentez'den SALT OKUNUR 5 sorgu (login, order, model, cari).
  - `api/Auth/` — MD5 (Sentez'in kendi hash'i), rol→izin haritası, JWT, 401/403 ayrımı.
  - `api/Dosya/` — uzantı beyaz listesi + imza (magic bytes) kontrolü + yol kaçışı.
  - `api/Selvedge/{Firma,Anket}/` — firma yönetimi, anket tasarımı, anket doldurma.
  - `web/` — React 19 + Vite 8 + Tailwind 4; login, order, firma, anket ekranları.
  - `tests/` — 11 test dosyası, **105 test**.
- **Komutlar:**

      cd SentezSelvedge
      dotnet test tests/SentezSelvedge.Tests/SentezSelvedge.Tests.csproj
      # Passed! - Failed: 0, Passed: 105, Skipped: 0, Total: 105

- **Commit'ler:** `1b102a5`, `21ffad2`, `74b19bb`, `3c9dbc6`, `bea38bc`, `af78b5e`,
  `2886804`, `a3ec926`, `0c6548a`, `e252b04`, `56dd9cf`, `5acbfd8`, `a0cd356`

### 9. Canlı doğrulamada çıkan altı kusur — her biri ölçülerek bulundu
- **Neden:** Testler yeşildi ama gerçek SentezLive'a karşı koşmadan "bitti" denmez.

1. **`ScriptTarayici` `MERGE`'i kaçırıyordu.** Yazma deseni `INSERT/UPDATE/DELETE/
   TRUNCATE` arıyordu; `0001_iskelet.sql` rolleri `MERGE` ile tohumluyor. Yani
   `MERGE dbo.Erp_WorkOrder` korumadan geçerdi. Önce test (KIRMIZI), sonra regex'e
   `MERGE(\s+INTO)?` eklendi.
2. **Plandaki yazma-koruma testi yanlıştı.** Naif alt dize araması yapıyordu;
   `IsDeleted` içinde "DELETE" geçtiği için DOĞRU sorguyu reddediyordu. Kelime
   sınırlı regex ile yeniden yazıldı, 5 sorgunun hepsini kapsıyor.
3. **İyimser kilit İLK (doğru) yazmayı reddediyordu — 200 yerine 409.** Tahminle
   değil SQL'de ölçülerek bulundu: `DATETIME2(7)` değeri `2026-10-03T06:00:01.0159399`,
   `datetime`'a cast edilince `...01.017` oluyor → `FARKLI`. **Sebep: Dapper
   `DateTime`'ı varsayılan olarak `datetime` gönderiyor (~3.33 ms çözünürlük).**
   `api/Sentez/DapperAyar.cs` ile global olarak `DbType.DateTime2`'ye eşlendi.
4. **`AuditLog.SentezUserId` NULL kalıyordu.** Token'da `sub = 78` var, ama
   **JwtBearer gelen `sub` istemini `ClaimTypes.NameIdentifier`'a çeviriyor**, bu
   yüzden `FindFirst("sub")` null dönüyordu. `/api/auth/me` yedek okuması olduğu
   için çalışıyordu — kusuru gizliyordu. `api/Auth/KullaniciKimligi.cs` her iki
   ismi de okuyor; tüm kontrolcüler + `IzinGerekli` ona bağlandı (8 test).
5. **`api/Files` (kaynak) ile `api/files` (yükleme kökü) Windows'ta AYNI klasör.**
   `git check-ignore -v` kanıtladı: `.gitignore:199 SentezSelvedge/api/files/`
   oraya konan her yeni kaynak dosyayı sessizce gizliyordu. `git mv` ile
   `api/Dosya`'ya taşındı, namespace'ler değişti, yolun artık gizlenmediği
   `git check-ignore` ile yeniden doğrulandı.
6. **`Deploy-IIS.ps1 -SkipWebBuild` sunucuda çalışmıyordu.** Adım 1 `web\dist\index.html`
   arıyor (sunucuda `web\` yok), adım 2 yine `dotnet publish` çalıştırıyor (sunucuda
   SDK ve kaynak yok). Yani KURULUM dokümanına yazacağım komut ilk adımda patlardı.
   `-SkipBuild` kipi eklendi: ikisini de atlar, `-OutputDir` ile verilen hazır paketi
   doğrular (`SentezSelvedge.Api.dll`, `web.config`, `wwwroot\index.html` aranır).

- **Ayrıca 4 TypeScript derleme hatası:** `import.meta.env` ve `./index.css` için
  `src/vite-env.d.ts` (`/// <reference types="vite/client" />`); `AnketDoldurPage`'de
  iki TS2783 yayılma-ezme hatası, önceki değer açıkça okunarak düzeltildi.

### 10. Canlı doğrulama — ölçülenler
- **Komutlar (özet):** API `127.0.0.1:5401/5402/5403`'te koşturulup curl + sqlcmd ile.
- **Sonuçlar:**
  - Şema: 14 tablo; ikinci koşuda "Değişiklik yok, şema güncel" (idempotent).
  - Giriş: büyük/küçük harfli kullanıcı kodu (Review Focus #1) — yanlış kullanıcıya düşmüyor.
  - **Review Focus #3:** tokensiz **401**, geçerli token + rol yok **403**, bozuk token **401**.
    (`Selvedge__Yoneticiler__0` geçici olarak var olmayan bir koda çevrilerek ölçüldü.)
  - **Review Focus #4:** anket ve firma iyimser kilidi — doğru sürüm **200**, bayat
    sürüm **409**, bayat istek veriyi **DEĞİŞTİRMİYOR** (DB'den teyit edildi).
  - Order: 160 kayıt, model kart ID'sinden okunuyor. Cari önbelleği 0.32s → 0.03s.
  - Firma: Türkçe kod normalizasyonu + tekil kod çakışmasında 409.
  - Anket: oluşturma + doğrulamalar; cevap puanı 10.000.
  - Denetim kaydı: `SentezUserId=78`, `SurveyResponse.CreatedBy=78` (eskiden NULL).
  - Dosya: yükleme, imza kontrolü, yetkisiz erişim reddi.

### 11. Dağıtım paketi
- **Ne yapıldı:** `SentezSelvedge-IIS-192.168.3.228-91/` + `.zip` (12.4 MB, 140 girdi).
  - `site/` — API + `wwwroot` (React build)
  - `sema/` — `SentezSelvedge.Db.exe` + `db/*.sql` + `elle/9001_yetki.sql`
  - `Deploy-IIS.ps1`, `IIS-KURULUM.txt`, `ornek/appsettings.json`
- **Paket duman testi (paketteki exe ile, port 5410):** `/` 200 (index.html),
  `/firma` 200 (SPA fallback), `/assets/*.css` 200 `text/css`, login 200,
  `/api/anket` 200, `/api/sentez/order` 200.
- **Sızıntı taraması:** şifre/bağlantı dizesi yok, `appsettings.Development.json` yok,
  log dosyası yok. Duman testinin ürettiği `site/logs` zip'lemeden önce silindi.
- **Komutlar:**

      # PowerShell vite uyarısını NativeCommandError'a sarıyor; web build'i Bash'te al
      cd SentezSelvedge/web && npm run build
      cd SentezSelvedge && ./Deploy-IIS.ps1 -SkipWebBuild
      dotnet publish db-tool/SentezSelvedge.Db.csproj -c Release -o publish-dbtool

## Kararlar (öğleden sonra)
- **Veritabanı izni, kod kuralı değil.** Erp_* salt okunurluğu `GRANT SELECT ON
  SCHEMA::dbo` + tablo tablo yazma izni ile garanti ediliyor. **`DENY` KULLANILMIYOR:**
  SQL Server'da DENY, GRANT'i ezer; şema düzeyinde DENY INSERT verilseydi kendi
  tablolarımıza da yazamazdık.
- **Cache tutan servisler Singleton.** Scoped olsaydı önbellek hiç tutmazdı.
- **JWT anahtarı uygulamalar arasında PAYLAŞILMAZ.** Paylaşılırsa diğer uygulamanın
  token'ı burada doğrulanır; kullanıcı 401 değil 403 alır. Güvenlik açığı değil ama
  kafa karıştırıcı — her uygulamaya kendi anahtarı.
- **Türkçe karakter doğrulaması göz kararı yapılmaz.** Konsol çıktısı bozuk
  gösterebiliyor; Unicode kod noktasıyla (214/231/304) teyit edildi.
- `web/tsconfig.tsbuildinfo` commit'ten çıkarıldı, `.gitignore`'a eklendi (derleme artefaktı).

## Açık kalanlar / sonraki adım
- **Faz 1b:** kalite kontrol kayıtları + ölçüm (POM) tabloları ve Excel ile POM yükleme.
- SentezLive'da canlı test verisi duruyor: `UZM_Selvedge_Firm` F001,
  `UZM_Selvedge_Survey` FASON01, iki cevap, bir ek dosya. Örnek veri olarak
  kalsın mı, silinsin mi — karar verilecek.
- Paket sunucuya kurulmadı; `IIS-KURULUM.txt` adım adım anlatıyor.
