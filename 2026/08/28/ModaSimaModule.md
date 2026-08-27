# ModaSimaModule — 2026-08-28

## Bağlam
Dün (2026-08-27) Web API'nin controller keşfi düzeltilmişti (bkz. `2026/08/27/ModaSimaModule.md`).
Bugün `EFautraController` içindeki boş bırakılmış `GetInvoice` ucu dolduruldu.

## Yapılanlar

### 1. `EFautra/GetInvoice` ucu yazıldı
- **Neden:** `Erp_EInvoice` tablosunda `InvoiceId is null` olan, yani henüz `Erp_Invoice`'a
  aktarılmamış gelen e-faturaların API üzerinden listelenmesi gerekiyordu. Öncelikli hedef
  Trendyol faturaları (`ReceiverName = 'DSM Grup Danışmanlık İletişim ve Satış Tic. A.Ş.'`).
- **Ne yapıldı:** `Controllers/EFautraController.cs` içindeki boş `GetInvoice()` gövdesi dolduruldu.
  - Oturum: diğer uçlardaki desenle aynı —
    `ModaSimaModule.LoginSysMng.LoginToOtherCompany("Sentez", "01", out LiveSession session)`.
  - Veri çekme: kod tabanındaki mevcut idiom kullanıldı —
    `UtilityFunctions.GetDataTableList(session.dbInfo.DBProvider, session.dbInfo.Connection,
    (DbTransaction)null, "Erp_EInvoice", sql)`.
  - Sorgu **şirket bağımsız** (`CompanyId` filtresi yok); şirket bilgisi
    `left join Erp_Company c on ei.CompanyId=c.RecId` ile `CompanyCode` olarak dönüyor.
    Bu yüzden hangi şirkete login olunduğu sonucu etkilemiyor, sadece bağlantı için gerekli.
  - `with (nolock)` her iki tabloya da eklendi (mevcut sorgu deseniyle uyumlu).
  - `receiverName` opsiyonel `[FromQuery]` parametresi; boş/whitespace gelirse
    `DefaultReceiverName` sabitine (DSM Grup) düşüyor.
  - SQL string interpolation ile kuruluyor (kod tabanı ideomu), ancak tek tırnak
    `Replace("'", "''")` ile kaçırılıyor — kesme işaretli unvanlarda sorgu kırılmasın diye.
  - `DataTable` satırları `IsNull` kontrolleriyle nullable tiplere map'lenip anonim
    nesne listesi olarak dönüyor: RecId, EInvoiceType, UUID, ReceiverName, DocumentNo,
    ReceiptDate, InvoiceId, CompanyCode. Yanıt: `{ success, at, count, data }`.
- **Dokunulan dosyalar:** `Controllers/EFautraController.cs`
  (eklenen using'ler: `System.Data`, `System.Data.Common`, `Sentez.Data.Tools`)
- **Sonuç / doğrulama:** `dotnet build` → **0 Error, 36 Warning**.
  Runtime testi yapılmadı; LiveServer'da `http://<host>:3132/EFautra/GetInvoice` denenmeli.
- **Commit:** `89996f4` — EFautra/GetInvoice: aktarilmamis gelen e-faturalari dondurur

### 2. `Services/EInvoiceInsert.cs` takibe alındı
- **Neden:** `EFautra/Insert` ucunun bağımlılığı olan bu dosya untracked'dı, derlemeye giriyordu
  ama repo'da yoktu — disk kaybında uçardı.
- **Ne yapıldı:** Aynı commit'e dahil edildi.

## Kararlar
- `GetInvoice` sorgusu şirket bağımsız bırakıldı (kullanıcının verdiği SQL'e sadık kalındı).
  Şirket kırılımı gerekirse `CompanyCode` alanı üzerinden istemci tarafında filtrelenebilir,
  ya da uca opsiyonel `companyCode` parametresi eklenir.
- `ReceiverName` sabit yazılmak yerine varsayılanı DSM Grup olan bir query parametresi yapıldı;
  başka tedarikçiler için de kullanılabilsin diye.

## Açık kalanlar / sonraki adım
- **Runtime testi:** `/EFautra/GetInvoice` ve dünkü `/hello` ucu LiveServer'da denenmeli.
- **`ModuleMenu.xml` tutarsızlığı hâlâ duruyor** (dünden devir): menü silinmiş
  `ECommerceTransfer` PM'lerine (Trendyol alt menüsü, 4 madde) işaret ediyor.
- **Commit edilmemiş çalışma var:** `ModaSimaModule.cs` (kullanıcının eklediği
  `public static SysMng LoginSysMng` ve atanması), `ModaSimaModule.csproj`,
  `Views/OrderNumberInput.xaml(.cs)` değişiklikleri ve `ECommerceTransfer/*` altındaki
  38 dosyalık silme henüz push edilmedi.
