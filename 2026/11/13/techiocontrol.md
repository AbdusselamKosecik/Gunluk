# techiocontrol — 2026-11-13

## Bağlam
Yeni proje. Kesimhane'de bir sipariş Sentez'de kesimi tamamlansa bile 69 sunucusuna
(TechtsioMerkez, `http://192.168.1.69:81`) ancak kesimhane uygulamasındaki "Sisteme Gönder" /
"Toplu Aktarım" ile **elle** gidiyordu. Gönderilmeyen siparişler hatta okutulamıyor.
Hedef: kesimi sipariş miktarına ulaşmış ama 69'a gitmemiş siparişleri otomatik göndermek.

Kullanıcı kararı: Sentez'de "gönderildi" alanı yok. Son **10 gün**de kesimi yapılmış siparişlerde,
sipariş 69'da yoksa **veya** kartları 69'da yoksa gönderilmemiş sayılır.

## Yapılanlar

### 1. Mevcut gönderim mekanizmasının çözülmesi
- **Neden:** Otomatik servis, elle yapılan gönderimle birebir aynı paketi üretmeli.
- **Ne yapıldı:** `kesimhane/kesimhane/Models/BulkOrders.cs` → `BulkOrders.Genre(con, workOrderNo, companyId)`
  Sentez'den paket üretiyor; `ViewModels/OrderDetailViewModel.cs` ve `Views/TopluAktarimWindow.xaml.cs`
  bu paketi `POST /api/BulkInstall` (content-type `application/json-patch+json`) ile gönderiyor.
  69 tarafı: `techtsio-core/Techtsio.Presentation/Controllers/BulkInstallController.cs`, siparişi
  `Orders.No` ile, kartları `Cards.Code` ile upsert ediyor, yani **idempotent**. Ayrıca aynı kodlu
  kartı diğer siparişlerde `IsDeleted=1` yapıp bu siparişe taşıyor.
- **Sonuç:** Tekrar göndermek zararsız. Ancak kart başka siparişe geçtiyse "çalma" riski var (bkz. 3).

### 2. Aday sorgusu (Sentez 192.168.1.22 / SentezLive)
- Kesim = `Erp_WorkOrderProduction` `ProductionType=1 AND ProductionSubType=1` (kesimhane kuralı).
- Sipariş adedi = `sum(Erp_WorkOrderItemVariant.Quantity)`, kesim adedi = `sum(p.Quantity)`;
  `max(p.InsertedAt) >= getdate()-10` ve `kesim >= sipariş * EsikOrani (1.0)`. `WorkOrderType=15`, `CompanyId=1`.
- Sentez'de "gönderildi" alanı yok; `Erp_WorkOrderProduction` tarih alanları: `InsertedAt`, `ProductionDate` ...
- **Sonuç:** Canlıda 74 aday iş emri.

### 3. Kart tekrar kullanımı: sahiplik kuralı
- **Neden:** İlk kuru çalışmada 8 sipariş "1 kart eksik" çıktı. İnceleme: fiziksel kartlar siparişler
  arasında tekrar kullanılıyor (`A6D2DB02`: 95519 16:37 → 96052 16:44; `26103802`: onlarca sipariş).
  Basit kontrol, eski siparişi gönderip kartı yeni siparişten çalar ve her turda ping-pong yapardı.
- **Ne yapıldı:** Bir kod, Sentez'de **en son** (`InsertedAt`) kesime girdiği iş emrine aittir.
  `SentezDeposu.KartSql`: `cross apply string_split(p.UD_SerialCodes, ',')` (compat level 150) ve
  `not exists` ile daha yeni başka iş emri kullanımı. Karşılaştırma yalnızca sahip olunan kodlarla yapılıyor.
  `KartFiltresi.Uygula` ile gönderilen paketten başka siparişe geçmiş kodlar çıkarılıyor.
- **Sonuç:** Gönderilecek sayısı 8'den 3'e indi (96052, 96073, 96059). `26103802` elle doğrulandı:
  Sentez'de son kullanım 96073 (2026-11-06), 69'da ise hâlâ 95567'de görünüyor. Yani gerçek bir düzeltme.

### 4. Proje iskeleti
- **Dokunulan dosyalar:** `X:\Gitlab\fredericTr\techiocontrol\`
  - `src/TechioControl/Program.cs`: `--once`, `--dry-run`, sürekli mod (15 dk), `Global\TechioControl` mutex, çıkış kodları 0/1/2/3
  - `Ayarlar.cs`: `appsettings.json` + `appsettings.Local.json` (gitignore, şifreler) + `TECHIO_` ortam değişkenleri
  - `Gunluk.cs`: konsol + `logs/yyyy-MM-dd.log`
  - `Models/BulkOrders.cs`: kesimhane'den kopya (DapperLite → Dapper, `#nullable disable`)
  - `Services/SentezDeposu.cs`, `MerkezDeposu.cs` (69'da sadece SELECT), `MerkezGonderici.cs` (HTTP),
    `GonderimKarari.cs` (saf karar), `KartFiltresi.cs`, `Kontrolcu.cs` (tur + gönderim sonrası doğrulama)
  - `tests/TechioControl.Tests`: 8 xUnit testi
- **Komutlar:**
  ```bash
  dotnet new sln -n TechioControl; dotnet new console -n TechioControl -o src/TechioControl -f net10.0
  dotnet new xunit -n TechioControl.Tests -o tests/TechioControl.Tests -f net10.0
  dotnet add package Dapper 2.1.66 / Microsoft.Data.SqlClient 6.1.4 / Newtonsoft.Json 13.0.4
  dotnet add package Microsoft.Extensions.Configuration.Json|EnvironmentVariables|Binder 10.0.0
  dotnet test                                   # 8/8 geçti
  dotnet run --project src/TechioControl -- --once --dry-run   # ~21 sn, 74 aday, 3 gönderilecek
  git remote add origin git@gitlab.com:fredericTr/techiocontrol.git; git push -u origin main
  ```
- **Commit:** `700cac8` — TechioControl: kesimi tamamlanip 69'a gitmemis siparisleri otomatik gonder

### 5. Windows Servisi olarak çalışma
- **Neden:** Kullanıcı Görev Zamanlayıcı yerine Windows Servisi istedi.
- **Ne yapıldı:** `Microsoft.Extensions.Hosting.WindowsServices 10.0.0` eklendi.
  `KontrolServisi.cs` (BackgroundService): açılışta 30 sn bekliyor (SQL/ağ hazır olsun), sonra `PeriodicTimer` ile
  her `AralikDakika` (15) dakikada bir tur atıyor; bir turdaki hata servisi durdurmuyor.
  `Program.cs`: `--once` verilirse konsolda tek tur, verilmezse `Host.CreateApplicationBuilder` + `AddWindowsService("TechioControl")`.
  Tek kopya mutex'i: SYSTEM hesabındaki servisin oluşturduğu mutex'i kullanıcı konsolu açamayınca
  `UnauthorizedAccessException` alıyor; bu durum "servis çalışıyor" olarak yorumlanıyor (çift gönderim olmuyor).
- **Dokunulan dosyalar:** `src/TechioControl/KontrolServisi.cs`, `Program.cs`, `TechioControl.csproj`,
  `scripts/servis-kur.ps1`, `scripts/servis-kaldir.ps1`, `README.md`
- **Kurulum betiği:** `dotnet publish -c Release -r win-x64 -o C:\Servisler\TechioControl`, `appsettings.Local.json`
  kopyalanıyor, `New-Service`, `sc config start= delayed-auto`, `sc failure ... restart/60000 x3`,
  `-KuruCalisma` verilirse binPath `--dry-run` ile kuruluyor. Tekrar çalıştırmak güncelleme yapıyor.
- **Komutlar:**
  ```powershell
  powershell -ExecutionPolicy Bypass -File scripts\servis-kur.ps1 -KuruCalisma   # önce kuru
  powershell -ExecutionPolicy Bypass -File scripts\servis-kur.ps1                # gerçek
  powershell -ExecutionPolicy Bypass -File scripts\servis-kaldir.ps1
  ```
- **Sonuç / doğrulama:** Servis gövdesi konsolda `--dry-run` ile çalıştırıldı: 30 sn sonra tur atıldı (74 aday, 3 gönderilecek).
  Aynı anda ikinci kopya exit=2 ile reddedildi. `--once --dry-run` hâlâ çalışıyor. publish başarılı, ps1 betikleri
  sözdizimi hatasız. 8/8 test geçti. Servis bu makineye **kurulmadı**.
- **Commit:** `2499ed3` — Windows Servisi olarak calisma + kurulum betikleri

## Kararlar
- İlk sürümde Görev Zamanlayıcı önerildi; kullanıcı isteğiyle **Windows Servisi**ne geçildi (`--once` konsol modu korundu).
- 69'a yazma yalnızca mevcut `BulkInstall` API'si üzerinden yapılıyor; doğrudan DB'ye yazılmıyor.
- "Sipariş miktarının fazlasını geçmiş" = `kesim >= sipariş` (EsikOrani=1.0, ayarlanabilir).
- Bağlantı şifreleri repoya girmiyor: `appsettings.Local.json` (örnek: `appsettings.Local.example.json`).

## Açık kalanlar / sonraki adım
- Canlı gönderim henüz yapılmadı (sadece `--dry-run`). İlk canlı tur: `dotnet run --project src/TechioControl -- --once`.
- Servisi sunucuya kurmak: önce `servis-kur.ps1 -KuruCalisma`, loglar doğruysa `-KuruCalisma` olmadan.
- Etüdü olmayan model (`Genre` → "Modelde Etut Bulunamadı") her turda HATA loglar; gerekirse susturma/bildirim eklenebilir.
