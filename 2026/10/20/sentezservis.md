# sentezservis — 2026-10-20

## Bağlam
İstek: CRS e-fatura kontrolü ekranında eşleşmeyen (Sentez'de yok) satırların "aktarım durumu"nu
bir butonla temizlemek. Satırlarda "Webservisten alınmış" ibaresi var; bu bayrağın nerede
tutulduğu ve nasıl geri alınacağı araştırıldı. Kod değişikliği yapılmadı.

## Yapılanlar

### 1. CRS tarafında "alındı" bayrağı geri alınabilir mi — HAYIR (canlı WSDL ile doğrulandı)
- **Neden:** "Webservisten alınmış" CRS portalındaki gelen kutusu "alındı" işareti olabilir.
- **Ne yapıldı:** Canlı WSDL indirildi, operasyon listesi ve şemalar tarandı.
- **Komutlar:**
  ```bash
  curl -s "https://connect.crssoft.com/Services/Integration?singleWsdl" -o crs.wsdl
  grep -o 'operation name="[^"]*"' crs.wsdl | sort -u
  ```
- **Sonuç:** 65 operasyon. Bayrakla ilgili yalnızca `SetInvoicesTaken(invoices: ArrayOfString)`
  var (yalnızca işaretler, parametresi yok) ve listelemede `InboxInvoiceQueryModel.SetTaken`.
  `InboxInvoiceListItem` alanları `IsNew`, `IsSeen`. Geri alan (untake/reset) bir uç YOK.
  `docs/api-kontrat.md` "SetTaken" bölümündeki tespit hâlâ geçerli. Giden (Outbox) kalemlerde
  böyle bir bayrak hiç yok. → CRS tarafındaki işaret ancak CRS destekle kaldırılabilir.
- Diğer işe yarayabilecek uçlar: `ChangeInvoiceArchiveStatus(invoiceIds, isInbox, isArchived)`,
  `TransferInboxInvoiceToAnotherBranch` — ikisi de "alındı"yı kaldırmaz.

### 2. Sentez tarafındaki aday: `Erp_EInvoice`
- **Neden:** Bayrak Sentez'in gelen e-fatura tablosunda da olabilir; ModaSimaModule
  `GET /EFautra/GetInvoice` → `POST /EFautra/Insert` akışı `RecId`+`UUID` ile çalışıyor.
- **Ne yapıldı:** Modasima ERP'ye buradan erişim yok (yerelde yalnızca localdb deneme DB'leri).
  Şema başka projenin EF modelinden okundu: `X:\Gitlab\viola2\server\Viola\Domain\ErpEinvoice.cs`.
- **Sonuç:** `Erp_EInvoice` kolonları: `RecId, CompanyId, InvoiceId, EinvoiceType, Uuid,
  TransactionType, ApprovedStatus, IsApproved, IsPurchaseApproved, EinvoiceReference,
  EinvoiceSpecial, InventoryReceiptId, OrderReceiptId, ...`. "Aktarım durumu" büyük olasılıkla
  `InvoiceId` (oluşan Erp_Invoice bağı) ve/veya `TransactionType`; değer anlamları canlıda
  doğrulanmadı.

## Kararlar
- Bekliyor: ERP'ye yazma Şart B-10 (ERP salt okunur, iki dar istisna) ile çelişiyor; buton için
  yeni istisna kararı gerekir.

## Açık kalanlar / sonraki adım
- Kullanıcıdan: ibarenin göründüğü ekran (Sentez mi CRS portalı mı), yön (gelen/giden), canlıda
  bir eşleşen + bir eşleşmeyen ETTN için `Erp_EInvoice` satırları.
- Bayrak Sentez'deyse: `/api/fatura/aktarim-temizle` (yönetici, denetim kaydı, önce önizleme)
  + karşılaştırma ekranında "Sentez'de yok" satırlar için buton.

## Ek: ModaSimaModule incelemesi (`X:\GitHub\Sentez-Core\ModaSimaModule`)

### 3. Gelen e-fatura akışı kodda
- **Dosyalar:** `Controllers/EFautraController.cs`, `Services/IncomingEInvoiceGetControlService.cs`,
  `Services/EInvoiceInsert.cs`.
- **Çekme (`ModaSimaIncomingEInvoiceGetControlService`, StartCrsInvoiceImport / GetCrsInvoice):**
  CRS `GetInboxInvoiceList`, son 30 gün (+10), `OnlyNewestInvoices=false`, SetTaken verilmiyor
  (WCF varsayılanı false). Yani CRS "alındı" bayrağı bu akışta neyin çekileceğini ETKİLEMEZ.
  Tekrar kontrolü `Erp_EInvoice.UUID` varlığıyla. Yeni kayıt:
  `INSERT Erp_EInvoice (..., TransactionType=1, ApprovedStatus=1, ...)`.
- **Okundu bilgisi:** `IncomingEInvoiceSendReadInfoAfterCreate == 0` ise her yeni UUID için
  `instance.ReceivedInvoice(uuid)` (Sentez CrsSoft sağlayıcısı → CRS `SetInvoicesTaken`). Geri alınamaz.
- **Aktarım:** `GET /EFautra/GetInvoice` = `Erp_EInvoice WHERE InvoiceId IS NULL AND ReceiverName=@ad`
  (varsayılan "DSM Grup ..."); `POST /EFautra/Insert` → `EInvoiceInsert.OnApproveCommand`,
  faturaya `EInvoiceGuid=UUID` yazar. `Erp_EInvoice.InvoiceId`'yi modül yazmıyor (Sentez çekirdeği).
- **"Webservisten alınmış" etiketi:** Sentez DLL'lerinde (UTF-16 tarandı) bu metin yok; büyük
  olasılıkla `TransactionType=1`'in ekran karşılığı → kaynağı anlatır, aktarım durumu değildir.
  Canlıda doğrulanmadı.
- **Aktarım durumu = `Erp_EInvoice.InvoiceId`.** Eşleşmeyenin takılma nedenleri: InvoiceId dolu ama
  fatura silinmiş (yetim) / ReceiverName DSM değil / 30 günden eski ve hiç çekilmemiş / Insert hata.

## Açık kalanlar (güncel)
- Canlıda teşhis sorgusu çalıştırılacak, ERP yazma (InvoiceId=NULL) için B-10 istisna kararı.
