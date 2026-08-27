# ModaSimaModule — 2026-08-27

## Bağlam
ModaSimaModule, UzmanAdresModule'den kopyalanmış bir Sentez ERP eklenti modülü
(`X:\GitHub\Sentez-Core\ModaSimaModule`, remote: github.com/Sentez-Core/ModaSimaModule).
Sahadaki `ModaSimaModule.dll` JetBrains dotPeek ile decompile edilip
`Y:\defactor\ModaSimaModule` altına çıkarılmıştı. Amaç: DLL'de olup repo kaynağında
olmayan işlevleri geri almak ve üzerine yeni Web API'yi eklemek.

## Yapılanlar

### 1. Repo kaynağı ↔ decompile çıktısı karşılaştırması
- **Neden:** `Y:\defactor\ModaSimaModule` "refactor" sanılıyordu; aslında derlenmiş
  DLL'in decompile çıktısıydı (dosya başlıklarında `// Decompiled with JetBrains decompiler`,
  csproj'da `<!--Project was exported from assembly: Y:\ModaSimaModule.dll-->`,
  `DapperLite\Database`1.cs` gibi backtick'li adlar, `lib\System.*.dll` referansları).
  Yani karşılaştırma "iki kaynak sürümü" değil, **repo kaynağı ↔ sahadaki DLL** idi.
- **Ne yapıldı:** Dosya ağaçları ve ortak dosyalar diff'lendi; metot setleri
  `grep -oE '(public|private|protected|internal)[^({=]*\('` ile çıkarılıp `comm` ile karşılaştırıldı.
- **Bulgular:**
  - DLL'de olup repo'da **olmayan**: `OnInvoiceListCollectiveIntegrationCommand`,
    `OnInvoiceListCollectiveIntegrationNonErrorCommand`,
    `OnInvoiceListCollectiveIntegrationCommandRun(obj, bool ShowError = true)`
    → menüdeki "Toplu Entegrasyon Calistir" ve "Toplu Entegrasyon Calistir(HATA GOSTERME)".
  - Repo'da olup DLL'de olmayan: `StartWebApi` / `WriteApiLog` (commit `b10a9ad`) ve `Controllers/`.
    Yani DLL bu commit'ten eski bir build.
  - Marka farkı: DLL `"UzmanAdres"` caption'ı ve `Vogue,Live` application adını taşıyor;
    repo `"ModaSima"` ve `Fabric,Live`. Repo doğru olan.
  - `Depper/` (repo) ve `DapperLite/` (decompile) klasör adları farklı ama namespace ikisinde de
    `DapperLite`, metot setleri aynı — fark değil.
  - Geri kalan tüm fark decompiler gürültüsü (primary constructor gösterimi, `#nullable disable`,
    file-scoped namespace, `this.` ön ekleri, açık cast'ler, XAML'den `d:`/`mc:` attribute düşmesi).
    `InvoiceEntegrasyonCommand`, `InvoiceControlCommand`, `Parameter`, `ParameterItem`,
    `ParametersPM`, `InvoiceExtension`, `OrderEditExtension` gövdeleri mantıken birebir aynı.
- **Dokunulan dosyalar:** yok (sadece analiz)
- **Sonuç:** Eksik toplu entegrasyon komutları tespit edildi; kullanıcı bunları decompile
  çıktısından `ModaSimaModule.cs`'e kendisi taşıdı (`moduleID` `Modules.ExternalModule22`
  olarak korundu, `3021` sabiti yorumda bırakıldı).

### 2. Web API controller'larına ulaşılamama sorunu
- **Neden:** `http://<host>:3132/` (minimal `app.MapGet`) çalışıyor ama
  `Controllers/HelloController.cs` içindeki `/hello` **404** dönüyordu.
- **Kök sebep:** `WebApplication.CreateBuilder(...)` + `AddControllers()` kombinasyonunda
  ASP.NET Core, controller'ları `ApplicationPartManager` üzerinden **entry assembly**'den
  ve onun bağımlılık grafiğinden keşfeder. Burada entry assembly host EXE'si
  (`LiveServer.exe` / Sentez host) — plugin olarak yüklenen `ModaSimaModule.dll` bu
  grafikte olmadığı için içindeki controller'lar hiç taranmıyordu.
- **Ne yapıldı:** `ModaSimaModule.cs` → `StartWebApi()`:
  - `builder.Services.AddControllers().AddApplicationPart(moduleAssembly);`
    (`moduleAssembly = typeof(ModaSimaModule).Assembly`) — asıl düzeltme.
  - `WebApplicationOptions` ile `ApplicationName` = modül assembly adı,
    `ContentRootPath` = modül DLL klasörü; host EXE'nin adı/dizini sızmasın diye.
  - `app.UseRouting()` çağrısı `MapGet`/`MapControllers` **öncesine** alındı.
  - Teşhis için yüklenen `ApplicationPart` adları loga yazılıyor.
  - `Instance_AfterLogin` her oturum açılışında tetiklendiği için
    `Interlocked.CompareExchange(ref _webApiStarted, 1, 0)` ile API yalnızca bir kez
    ayağa kaldırılıyor (aksi halde ikinci login'de "address already in use").
  - `using System.Threading;` eklendi.
- **Dokunulan dosyalar:** `ModaSimaModule.cs`
- **Sonuç / doğrulama:** `dotnet build ModaSimaModule.csproj` → **0 Error, 22 Warning**
  (uyarılar mevcut, konu dışı: DevExpress/LiveCore sürüm çakışmaları, `WebClient` obsolete).
  Runtime doğrulaması yapılmadı — LiveServer üzerinde `/hello` denenmeli.

### 3. Log dosyası modül klasörüne taşındı
- **Neden:** Log `C:\log\modasima_<tarih>.log` altına yazılıyordu; modülün kendi klasöründe
  olması istendi (dağıtımda tek klasör, yazma izni sorunu yok).
- **Ne yapıldı:** `ModuleDirectory` adında static property eklendi —
  `typeof(ModaSimaModule).Assembly.Location`'ın klasörü, boşsa `AppContext.BaseDirectory`,
  o da boşsa `Environment.CurrentDirectory`. (Single-file publish'te `Location` boş döner,
  bu yüzden fallback zinciri var.) `WriteApiLog` artık `Path.Combine(ModuleDirectory, ...)`
  kullanıyor ve `Directory.CreateDirectory` çağrısına gerek kalmadı.
  Aynı property `WebApplicationOptions.ContentRootPath` için de kullanılıyor.
- **Dokunulan dosyalar:** `ModaSimaModule.cs`
- **Sonuç:** Log artık `<LiveServer klasörü>\modasima_yyyy-MM-dd.log`.

### 4. Commit / push
- **Komutlar:**
  ```bash
  git add ModaSimaModule.cs Controllers/EArsivController.cs \
          Controllers/EFautraController.cs Controllers/ReceiptCalculatorController.cs
  git commit -m "Web API: controller kesfi duzeltildi, log modul klasorune tasindi"
  git push origin main
  ```
- **Commit:** `85ef645` — Web API: controller kesfi duzeltildi, log modul klasorune tasindi
- Kullanıcının yeni eklediği `EArsivController`, `EFautraController`,
  `ReceiptCalculatorController` de takibe alındı (gizli bilgi taraması yapıldı, temiz).

## Kararlar
- `Y:\defactor` bir refactor değil, decompile arşivi. Referans olarak kullanılabilir ama
  kaynak doğruluğu repo'da; DLL repo'dan **eski**.
- Plugin DLL içindeki controller'lar için `AddApplicationPart` **zorunlu** — host EXE'nin
  içinde çalışan her modülde aynı desen uygulanmalı (ViolaModule dahil).
- API'nin yalnız `LiveServer` sürecinde ayağa kalkması kontrolü kullanıcı tarafından
  yorum satırına alındı (şimdilik her süreçte başlıyor); üretimde geri açılmalı.

## Açık kalanlar / sonraki adım
- **Runtime testi:** LiveServer'da modül yüklenip `http://<host>:3132/hello` denenmeli;
  log dosyasındaki `ApplicationPart:` satırlarında `ModaSimaModule` görünmeli.
- **`ModuleMenu.xml` tutarsızlığı:** Menü hâlâ Trendyol alt menüsünü (4 madde:
  `UzmTrendyolProductCardTransferPM`, `UzmTrendyolTransferPM`, `UzmTrendyolParametersPM`,
  `TrentyolListPM`) gösteriyor, ama `ECommerceTransfer/*` (38 dosya) working tree'de
  silinmiş ve bu silme henüz commit edilmemiş. Menü XML'i temizlenmeli, yoksa çalışma
  anında var olmayan PM'lere gidilip hata alınır.
- `Instance_AfterLogin` içindeki `applicationName` değişkeni artık kullanılmıyor
  (LiveServer kontrolü yorumda) — kontrol geri açılınca tekrar devreye girecek.
