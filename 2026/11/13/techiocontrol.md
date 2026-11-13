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

## Kararlar
- Ayrı bir konsol uygulaması; `--once` + Görev Zamanlayıcı (15 dk) önerildi. Windows Service yerine bu seçildi çünkü daha basit ve hata sonrası kendiliğinden yeniden çalışıyor.
- 69'a yazma yalnızca mevcut `BulkInstall` API'si üzerinden yapılıyor; doğrudan DB'ye yazılmıyor.
- "Sipariş miktarının fazlasını geçmiş" = `kesim >= sipariş` (EsikOrani=1.0, ayarlanabilir).
- Bağlantı şifreleri repoya girmiyor: `appsettings.Local.json` (örnek: `appsettings.Local.example.json`).

## Açık kalanlar / sonraki adım
- Canlı gönderim henüz yapılmadı (sadece `--dry-run`). İlk canlı tur: `dotnet run --project src/TechioControl -- --once`.
- Sunucuya kurulum: `dotnet publish -c Release -o C:\TechioControl` + `schtasks` (README'de).
- Etüdü olmayan model (`Genre` → "Modelde Etut Bulunamadı") her turda HATA loglar; gerekirse susturma/bildirim eklenebilir.
