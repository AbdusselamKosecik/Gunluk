# ModaSimaModule — 2026-09-19

## Bağlam

`Controllers/EArsivController.cs` iskelet halindeydi: `GetList` boş bir liste
döndürüyordu, `Run` içinde ise tanımsız bir `CompanyCode` değişkeni vardı, yani
dosya derlenmiyordu. Kullanıcı controller'ın üstüne notlarını (type 1/2/3
anlamları) yazmış ve karşılık gelen üç SQL sorgusunu verdi. Hedef: notları
çalışan koda çevirmek.

## Yapılanlar

### 1. `GetList` — Erp_Invoice sorgusu

- **Neden:** Uç nokta boş liste döndürüyordu; e-arşiv ekranının beslenmesi için
  gerçek veriye ihtiyaç var.
- **Ne yapıldı:** `type` parametresine göre üç ayrı WHERE koşulu:
  - `1` = Durum sorgulanacaklar → `EInvoiceStatus is not null and EInvoiceStatus not in (7,10,11)`
  - `2` = Yeni gönderilecekler → `EInvoiceStatus is null`
  - `3` = Hatalar → `EInvoiceStatus = 11`

  Üç sorgunun gövdesi (select listesi, `Erp_Company` left join, `ReceiptType`,
  `ReceiptDate`, `IsEInvoice = 2`, `order by ReceiptDate`) aynı olduğu için tek
  SQL string'i kuruldu, sadece WHERE parçası değişiyor.
- **Karar:** Kullanıcının sorgularındaki uzun `CASE WHEN ... EInvoiceStatusName`
  bloğu SQL'e üç kez kopyalanmadı; `GetEInvoiceStatusName(int)` adında statik bir
  C# yardımcı metoduna taşındı. SQL sadece `isnull(EInvoiceStatus,0)` döndürüyor,
  isim C# tarafında çözülüyor. Tek yerden bakım.
- **Karar:** Sorgudaki sabitler query parametresi yapıldı —
  `startDate` (varsayılan `20260701`), `receiptType` (varsayılan `121`),
  `company` (boşsa şirket filtresi uygulanmıyor). Sabitler dosyanın başında
  `DefaultStartDate` / `DefaultReceiptType` / `DefaultCompanyCode` olarak duruyor.
- **Karar:** Geçersiz `type` (0 veya 3'ten büyük) için sessizce boş liste yerine
  `BadRequest` dönülüyor — çağıran tarafın hatayı fark etmesi için.
- **Not:** SQL string interpolasyonla kuruluyor (projenin `EFautraController.
  GetInvoice` içindeki mevcut deseni), string değerler `Escape()` ile
  `'` → `''` yapılıyor.
- **Veri erişimi:** `EFautraController` ile aynı yol —
  `sys.LoginToOtherCompany("Sentez", <kod>, out LiveSession session)` ile oturum,
  sonra `UtilityFunctions.GetDataTableList(session.dbInfo.DBProvider,
  session.dbInfo.Connection, null, "Erp_Invoice", sql)`.
  Sorgu şirket bağımsız çalışabiliyor (CompanyId filtresi yok, şirket join ile
  geliyor) ama bir oturum açmak gerektiği için `company` boşsa `"01"` ile giriliyor.

### 2. `Run` — şirket bazlı gruplama (derleme hatası düzeltildi)

- **Neden:** Metot gövdesinde `sys.LoginToOtherCompany("Sentez", CompanyCode, ...)`
  yazıyordu; `CompanyCode` diye bir değişken yoktu → proje derlenmiyordu.
  Ayrıca aynı liste hem Create hem Status komutuna veriliyor, sonuçlar iki kez
  `rtn`'e ekleniyordu.
- **Ne yapıldı:** Gelen `List<InvoiceItem>` `CompanyCode`'a göre `GroupBy` ile
  gruplanıyor, her grup için ayrı `LoginToOtherCompany` yapılıp sadece o grubun
  satırları işleniyor. Login başarısız olursa o gruptaki satırlar
  `CreateStatus = -3` ve açıklayıcı `CreateError` ile dönüyor (tüm istek
  patlamıyor).
- **Karar:** type yönlendirmesi notlardaki anlamlara göre netleştirildi:
  `type 1` → `OnEArchiveInvoiceStatusCommand` (durum sorgula),
  `type 2` ve `3` → `OnEArchiveInvoiceCreateCommand` (oluştur + gönder).
  Eskiden ikisi de arka arkaya çağrılıyordu.
- **Karar:** `OnEArchiveInvoiceCreateCommand` içindeki switch kaldırıldı.
  Eski kod `type 1` ve `2` için servis verbi olarak `"CreateEInvoice"`
  seçiyordu; yeni anlamlandırmada create yoluna sadece 2 ve 3 giriyor ve ikisi de
  gönderim istediği için verb sabit `"CreateAndSend"`.
- **Not:** Boş liste veya geçersiz `type` için `BadRequest`.

- **Dokunulan dosyalar:** `Controllers/EArsivController.cs`

- **Komutlar:**
  ```bash
  # Build (vswhere ile MSBuild bulundu)
  "C:/Program Files/Microsoft Visual Studio/18/Community/MSBuild/Current/Bin/MSBuild.exe" \
    "X:/GitHub/Sentez-Core/ModaSimaModule/ModaSimaModule.csproj" /t:Build /v:m /nologo
  ```

- **Sonuç / doğrulama:** Build EXIT=0. Çıktı:
  `X:\GitHub\Sentez-Core\output\Debug\net6.0-windows\ModaSimaModule.dll`.
  Kalan uyarılar bu değişiklikle ilgisiz, önceden de vardı (MSB3277 — CoreWCF /
  System.IO.Pipelines sürüm çakışmaları).
  Uç noktalar henüz canlı istekle denenmedi.

- **Commit:** `24aa89d` — EArsiv: GetList sorgulari ve Run sirket bazli gruplama eklendi

## Kararlar

- Durum kodu → isim çevirimi SQL'de değil C#'ta (`GetEInvoiceStatusName`).
- Sorgu sabitleri (tarih, fiş tipi, şirket) query parametresi; varsayılanlar
  kullanıcının verdiği sorgularla birebir aynı (`20260701`, `121`).
- Hata durumunda tüm istek yerine satır bazlı hata (`CreateStatus` negatif +
  `CreateError`).
- `CreateStatus` kodları: `1` başarılı, `-1` zaten oluşturulmuş / servis hatası,
  `-2` RecId bulunamadı, `-3` şirkete bağlanılamadı (yeni).

## Açık kalanlar / sonraki adım

- Uç noktalar çalışan servise karşı denenmedi: `GET /EArsiv/GetList?type=1|2|3`
  ve `POST /EArsiv/Run?type=...` (body: GetList'ten dönen liste). Port 3132.
- `IsEInvoice = 2` ve `ReceiptType = 121` sabitlerinin e-arşiv için doğru
  kombinasyon olduğu kullanıcının sorgularından alındı, ayrıca doğrulanmadı.
- `"CreateAndSend"` verbinin `EInvoiceAndEArchiveCreateAndSendService` içinde
  type 3 (hatalı faturayı tekrar gönderme) senaryosunda beklendiği gibi
  davrandığı test edilmeli.
- Çalışma alanında ilgisiz başka değişiklikler duruyor (`EFautraController`,
  `ReceiptCalculatorController`, silinmiş `ECommerceTransfer/*`, yeni
  `Services/IncomingEInvoiceGetControlService.cs`) — commit edilmedi.
