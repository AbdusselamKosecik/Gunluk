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

### 6. Kurulum paketi
- **Neden:** Kullanıcı sunucuya taşınacak bir paket istedi (SentezPlaning-paket-*.zip geleneği).
- **Ne yapıldı:** `scripts/paket-yap.ps1`: self-contained `win-x64` publish → `app\`, yanına `servis-kur.ps1`,
  `servis-kaldir.ps1`, `KURULUM.txt` → `X:\Gitlab\fredericTr\TechioControl-paket-<yyyy-MM-dd>-<sha>.zip`.
  `servis-kur.ps1` artık yanında `app\TechioControl.exe` varsa paketten kuruyor, yoksa repodan derliyor (o da self-contained).
  Güncellemede sunucudaki `appsettings.Local.json` ezilmiyor, `logs\` korunuyor.
  `appsettings.Local.json` (SQL şifreleri) pakete giriyor, yoksa yalnızca örnek dosya konuyor.
- **Dokunulan dosyalar:** `scripts/paket-yap.ps1`, `scripts/KURULUM.txt`, `scripts/servis-kur.ps1`
- **Komutlar:**
  ```powershell
  powershell -ExecutionPolicy Bypass -File scripts\paket-yap.ps1
  ```
- **Sonuç / doğrulama:** Paket 38.5 MB. Zip açılıp `app\TechioControl.exe --once --dry-run` çalıştırıldı
  (74 aday, 3 gönderilecek; log `app\logs\` altına yazıldı). ps1 betikleri sözdizimi hatasız.
  Servis kurulumu gerçek olarak denenmedi (yönetici + servis kaydı gerektiriyor).
- **Paket:** `X:\Gitlab\fredericTr\TechioControl-paket-2026-11-13-ed7113d.zip` (yalnızca diskte; içinde şifre olduğu için repoya girmedi)
- **Commit:** `ed7113d` — Kurulum paketi: scripts/paket-yap.ps1 + paketten kurulum

### 7. 96052 "ESLESME HATASI" incelemesi
- **Neden:** Kullanıcı bildirdi: 96052 bantta eşleşme hatası veriyor.
- **Bulgular:**
  - Mesaj `localserver/TechtsioService/.../Server/Providers/UTS23/Uts23Service.cs:876` (case 9 CardSerial):
    `GetModelCheck(cihaz.OperationId, kart.ModelId)` false ise → `CurrentDeviceListManager.cs:1277`
    `select top 1 Id from ModelRoutes where ModelId=.. and OperationId=.. and IsDeleted=0`.
  - Kart bulma: `Bussiness/GetDatas.cs` `SeriCache`, `Code` ile aktif satırı buluyor ama
    model ve sipariş bilgisini **`isnull(ParentId,Id)` satırından** (demetin ana kartı) alıyor.
  - Hat sunucusu `172.16.1.2` (DIKIMANALIZSRV), 69 = MERKEZANALIZ. 96052 verisi ikisinde aynı.
    69'daki `TransferData` job'ı (her gün 04:00) yalnızca Transections'ı 172 → 69 taşıyor.
  - **Kök neden:** `A6D2DB02` kartı 69/172'de hâlâ **95519'da aktifti** (model 2334-1989). 96052'nin modeli 2282-1248.
    Bantta okutulunca 95519'un modeli geliyordu, rota eşleşmiyordu. Servis bunu sabah 05:04'te "1 kart 69'da yok (A6D2DB02)"
    olarak yakalamıştı. Saat 12:00'de 96052 yeniden gönderilmiş görünüyor (silinmiş ve aktif iki 96052 satırı var); şu an düzgün.
  - 96052'nin rotası (82 operasyon) Sentez etüdüyle birebir aynı.
- **Komut örneği:** `sqlcmd -S 172.16.1.2 -d TechtsioMerkez ... "select c.Code, o.No, c.IsDeleted, c.ParentId ... where c.Code='A6D2DB02'"`

### 8. Etüt/rota farkı kontrolü
- **Neden:** Kullanıcı istedi ("etüt farklılıklarını da kontrol edelim"). ESLESME HATASI'nın ikinci nedeni:
  etüde sonradan eklenen operasyon rotada olmuyor.
- **Ne yapıldı:** `SentezDeposu.EtutSql` (Genre qEtut ile aynı distinct kolonlar) ve `MerkezDeposu.RotaSql`
  (Orders → OrderItems → ModelRoutes → Operations). `EtutKarsilastirici.Farklar` → `EtutFarki(FarkTuru, Aciklama)`;
  türler: Operasyon (eksik/fazla/adet), Süre (tolerans 0.001), Sıra, SonOperasyon. Kodu boş etüt satırı yok sayılıyor (BulkInstall da atlıyor).
  `Kontrolcu`: operasyon farkı varsa gönder. Yalnızca süre/sıra farkı varsa `EtutSureFarkiniGonder` (varsayılan false) açıksa gönder,
  değilse turda tek satır logla. Etüdü olmayan model gönderilmiyor. Gönderim sonrası doğrulama rotayı da kontrol ediyor.
- **Bulgu:** İlk denemede 28 sipariş fark gösterdi; çoğunda 69 rotasındaki tüm süreler **tam sayı** (95519: 84/84, 96097: 88/88;
  14 vs 14.97). Kaynak bulunamadı: techtsio-core DTO'ları decimal, Sentez'de ilgili trigger/job yok.
  69 `Models.UpdatedAt` değerleri Sentez etüt `UpdatedAt` ile saniyeler içinde örtüşüyor, yani etüdü 69'a yazan başka bir entegrasyon var.
  Bu yüzden süre farkı otomatik ezilmiyor.
- **Sonuç:** 78 aday; gönderilecek 1: **95938** (`rotada yok: 1398-3, 1398-4`). Süre farkı olan 27 iş emri yalnızca loglanıyor. 17/17 test geçti.
- **Dokunulan dosyalar:** `Services/EtutKarsilastirici.cs` (yeni), `SentezDeposu.cs`, `MerkezDeposu.cs`, `Kontrolcu.cs`,
  `GonderimKarari.cs`, `Ayarlar.cs`, `appsettings.json`, `tests/.../EtutKarsilastiriciTests.cs`, `README.md`
- **Commit:** `20fa751` — Etut/rota farki kontrolu (ESLESME HATASI onlemi)
- **Paket:** `X:\Gitlab\fredericTr\TechioControl-paket-2026-11-13-20fa751.zip`

### 9. Süre farkı kararı
- **Karar (kullanıcı):** Etütte yalnızca süre/sıra/son-operasyon farkı varsa sipariş **gönderilmez**.
- **Ne yapıldı:** `EtutSureFarkiniGonder` ayarı kaldırıldı (`Ayarlar.cs`, `appsettings.json`, `README.md`). `Kontrolcu.Karar` içinde sabit kural;
  süre farkları her turda yalnızca bilgi satırı olarak loglanıyor.
- **Sonuç:** Kuru çalışma: 78 aday, gönderilecek 1 (95938, operasyon farkı), 27 süre farkı yalnızca loglandı. 17/17 test geçti.
- **Commit:** `2d1cf1a` — Sure farki gonderim sebebi degil: EtutSureFarkiniGonder ayari kaldirildi
- **Paket:** `X:\GitlabredericTr\TechioControl-paket-2026-11-13-2d1cf1a.zip`
- **Not:** Sipariş başka bir sebeple (eksik kart / operasyon farkı) gönderildiğinde BulkInstall rotayı baştan yazar,
  yani o modelin 69'daki süreleri de Sentez değerleriyle değişir.

### 10. Gönderimde 69'daki rota sürelerinin korunması
- **Karar (kullanıcı):** "Süreleri 69'daki değerlerle değiştir." Başka bir sebeple gönderimde 69 süreleri ezilmesin.
- **Ne yapıldı:** `Services/RotaSureKoruyucu.cs`: paketteki `ModelRoutes[].StandartTime`, 69'da aynı operasyon varsa 69 değeriyle değiştiriliyor.
  Eşleme kod (trim, büyük/küçük harf duyarsız) + kod içinde Sıra sırasıyla yapılıyor. Yeni operasyon Sentez süresiyle gidiyor.
  `Kontrolcu`: `Genre` + `KartFiltresi` sonrasında, `Gonder` öncesinde uygulanıyor ve korunan adım sayısı loglanıyor. 6 yeni test, toplam 23/23.
- **Doğrulama (gönderimsiz, scratchpad'de küçük konsol: Genre → Koruyucu → EtutKarsilastirici):**
  95519: önce 77 süre farkı, 77 korundu, sonra 0. 95938: süre farkı 0, kalan yalnızca `rotada yok: 1398-3; 1398-4`.
- **Ek kontrol:** BulkInstall `Operations.AverageStandardTime` (global) değerini de Sentez `p.StandartTime*60` ile güncelliyor.
  4173 ortak operasyondan yalnızca 1'i farklı (kod `15`: 69=300, Sentez NULL). Bu yüzden dokunulmadı.
- **Commit:** `81a4d29` — Gonderimde 69'daki rota sureleri korunur (RotaSureKoruyucu)
- **Paket:** `X:\GitlabredericTr\TechioControl-paket-2026-11-13-81a4d29.zip`

## Kararlar
- İlk sürümde Görev Zamanlayıcı önerildi; kullanıcı isteğiyle **Windows Servisi**ne geçildi (`--once` konsol modu korundu).
- 69'a yazma yalnızca mevcut `BulkInstall` API'si üzerinden yapılıyor; doğrudan DB'ye yazılmıyor.
- "Sipariş miktarının fazlasını geçmiş" = `kesim >= sipariş` (EsikOrani=1.0, ayarlanabilir).
- Bağlantı şifreleri repoya girmiyor: `appsettings.Local.json` (örnek: `appsettings.Local.example.json`).

## Açık kalanlar / sonraki adım
- 69'daki rota süreleri: gönderim sebebi değil ve gönderimde korunuyor (karar verildi). Tam sayı sürelerin kaynağı hâlâ bilinmiyor.
- localserver `SeriCache` silinmiş ana kart satırını da kabul ediyor (`c.Id = isnull(ParentId,Id)`, IsDeleted kontrolü yok); kalıcı çözüm orada.
- Canlı gönderim henüz yapılmadı (sadece `--dry-run`). İlk canlı tur: `dotnet run --project src/TechioControl -- --once`.
- Servisi sunucuya kurmak: önce `servis-kur.ps1 -KuruCalisma`, loglar doğruysa `-KuruCalisma` olmadan.
- Etüdü olmayan model (`Genre` → "Modelde Etut Bulunamadı") her turda HATA loglar; gerekirse susturma/bildirim eklenebilir.
