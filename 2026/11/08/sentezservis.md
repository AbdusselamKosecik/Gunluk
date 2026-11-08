# sentezservis — 2026-11-08

## Bağlam
Kullanıcının isteği:
- `Erp_InventoryReceipt` tablosuna `UZM_E_ReceiptCheckOK` adlı bir bool alan eklenecek.
- 08.11.2026'dan itibaren, 2 dakikada bir şu kontrol yapılacak:
  - Gönderilmiş e-arşiv faturalarının durumuna CRS'ten bakılacak.
  - CRS'te "GİB'e gönderilmiş" olan ve gönderiminin üzerinden 5 dakika geçmiş faturalar için Trendyol'da fatura var mı diye bakılacak.
  - Trendyol'da fatura yoksa yerel fatura (CRS'ten alınan PDF) otomatik yüklenecek.
- Kapsam yalnız Trendyol.
- Ek istek: bu iş ayrı bir uygulama olsun. Servis değil, elle çalıştırılan bir exe olsun ve logları ekranda göstersin.

Kullanıcı kararları (soru-cevap):
- PDF kaynağı: CRS'ten indirilecek.
- 5 dakika kuralı: CRS'teki belge saatine göre uygulanacak.
- Şirketler: 01, 03 ve 04'ün hepsi.

## Yapılanlar

### 1. Veri keşfi (yalnız SELECT, scratchpad `ss/q.sh`)
- **Neden:** Sentez'de bir faturanın Trendyol siparişine nasıl bağlandığını ve gönderim saatinin nerede tutulduğunu bulmak.
- **Bulgular:**
  - Trendyol faturaları: `Erp_Invoice.EArchivesWebAddress = 'www.trendyol.com'`. Sipariş numarası `Erp_InventoryReceipt.MarketPlaceOrderNo` alanında, ETTN `Erp_Invoice.EInvoiceGuid` alanında.
  - Fiş tipleri: satış 121, iade 2 (iadelerde ETTN yok). `IsEInvoice = 2` e-arşiv demek.
  - Gönderim saati Sentez'de yok. `EArchivesSendDate` yalnız tarih tutuyor; şirket 04'te `InsertedAt` hep 00:00, `UpdatedAt` NULL.
  - Bağlantı rolleri: ana servisin `EntegrasyonBaglantiCumlesi` ayarı **SentezCore2026Test** veritabanını gösteriyor. Bu yüzden canlıya yazmak için uygulamaya ayrı bir yazma bağlantısı verildi.
- **Sorgu:**
  ```sql
  SELECT ... FROM Erp_InventoryReceipt r JOIN Erp_Invoice i ON i.RecId=r.InvoiceId
  WHERE r.ReceiptDate>='2026-11-08' AND r.ReceiptType=121 AND i.IsEInvoice=2
    AND i.EArchivesWebAddress LIKE '%trendyol%' AND i.EInvoiceGuid<>'' AND r.MarketPlaceOrderNo<>''
  ```
  Bugün 134 aday çıktı, hepsi şirket 04'te.

### 2. CRS API keşfi
- **Ne yapıldı:** WSDL indirildi: `curl https://connect.crssoft.com/Services/Integration?singleWsdl`.
- **InvoiceStatus enum:** NotPrepared, NotSend, Draft, Canceled, Queued, Processing, **SentToGib**, **Approved**, WaitingForAprovement, Declined, Return, EArchivedCanceled, Error.
- **`GetOutboxInvoice`:** `CreateDateUtc` alanı canlıda **0001-01-01** döndü, kullanılamıyor.
- **`GetOutboxInvoiceStatusWithLogs(invoiceIds: ArrayOfString, tempuri ad alanı)`:** toplu çalışıyor. Durumu döndürüyor; ayrıca `Logs/CreateDateUtc` kayıtlarını saatiyle veriyor ("Fatura kaydedildi", "zarfa konuldu" …). Belge saati buradan alınıyor (son kaydın saati).
- **`GetOutboxInvoicePdf(invoiceId)`:** `Value/Data` alanında base64 PDF döndürüyor. Ölçülen boyut 85–87 KB.
- **Deneme:** scratchpad'deki `crs_probe.py` ile SOAP çağrısı yapıldı. Kimlik bilgileri appsettings'ten çalışma anında okundu, ekrana yazdırılmadı.

### 3. Trendyol API keşfi
- **Paket sorgusu (getShipmentPackages):** `orderNumber` parametresiyle süzülebiliyor. Cevaptaki pakette `invoiceLink` alanı var; fatura yüklenmişse dolu geliyor. Canlıda doğrulandı: 01.11 siparişlerinde dolu, 08.11 siparişlerinde boş.
- **Dosya yükleme:** `POST /integration/sellers/{id}/seller-invoice-file`, multipart. Alanlar: `shipmentPackageId` (metin) ve `file` (pdf/jpeg/png, en fazla 10 MB). Fatura daha önce yüklenmişse hata metni "(paketNo) numaralı pakete ait fatura önceden gönderilmiş" / "has already been sent".
- **Risk:** Trendyol, `order/sellers/{id}/orders` ucunun 15.10.2026'da kullanımdan kalktığını duyurmuş; yerine `v2/orders` ve `storeFrontCode` başlığı öneriliyor. Uç 08.11.2026 itibarıyla hâlâ 200 dönüyor.
- **Kaynaklar:** developers.trendyol.com/v3.0/docs/2-get-shipment-packages, /v2.0/docs/send-customer-invoice-file, /docs/fatura-dosyası-gönderme.

### 4. Kod
- **Core eklemeleri:**
  - `CrsIstemcisi.PdfGetirAsync` ve `CrsIstemcisi.DurumVeKayitSorAsync` eklendi. `CrsBelgeDurumu` kaydına `SonIslemUtc` alanı eklendi. `BelgeGetirAsync` artık hata sebebini Debug seviyesinde logluyor.
  - `TrendyolSaglayici.PaketleriGetirAsync(siparisNo)` ve `FaturaDosyasiGonderAsync(paketNo, pdf, ad)` eklendi. Gönderim multipart, yükleme tekrar denenmiyor (`tekrarDene:false`). `TrendyolPaketi` kaydı eklendi.
  - `Fatura/TrendyolPaketKarari.cs` eklendi. Bu saf fonksiyonun kararları:
    - Paket yok → atla
    - Tüm paketler iptal → atla
    - Tüm etkin paketlerde fatura var → ZatenVar
    - Tek etkin paket ve faturasız → yükle
    - Bölünmüş sipariş → atla (TODO: kullanıcı kararı)
- **Yeni proje `src/SentezServis.TrendyolFatura`:** derlenince `TrendyolFaturaKontrol.exe` çıkıyor; net10.0-windows, tek dosya, self-contained.
  - `Program.cs`:
    - Ayar katmanları sırasıyla: ana servisin appsettings dosyası (`ServisAyarDosyasi`), sonra uygulamanın kendi `appsettings.json` dosyası.
    - Log: SimpleConsole (tek satır, zaman damgalı) ve `DosyaLogSaglayici` ile `log\yyyy-MM-dd.log`.
    - Seçenekler: `--kuru`, `--bir-kez`, `--ayrintili`. Ctrl+C ile durur.
  - `FaturaAdayDeposu`:
    - Aday sorgusunu çalıştırır ve `UPDATE ... SET UZM_E_ReceiptCheckOK=1 WHERE RecId=@id` ile işaretler.
    - Bağlantı olarak `TrendyolFatura:ErpBaglantiCumlesi` (yazma yetkili) kullanılır.
    - Kolon yoksa canlı kip çalışmaz; kuru kip süzgeçsiz devam eder.
  - `TrendyolFaturaKontrolcusu`:
    - Akış: şirket bazında CRS'e toplu sorgu → `SentToGib`/`Approved` kontrolü → son işlem saatinden 5 dakika geçmiş mi → Trendyol paket kontrolü → PDF yükleme → fişi işaretleme.
    - Atlanan fişler 30 dakika ertelenir. Bir şirket hata verirse diğer şirketler durmaz.
  - `sql/UZM_E_ReceiptCheckOK.sql`: `ALTER TABLE dbo.Erp_InventoryReceipt ADD UZM_E_ReceiptCheckOK BIT NULL` (NULL kabul eden kolon olduğu için ekleme anında biter). Dosyada en az yetki GRANT örnekleri de var.
  - `appsettings.ornek.json` ve README. Gerçek `appsettings.json` .gitignore'a eklendi.
  - `SentezServis.slnx` dosyasına proje eklendi.
- **Testler:** `tests/.../TrendyolPaketKarariTestleri.cs` (6 test). Toplam 771 test geçti.
- **Komutlar:**
  ```bash
  dotnet build SentezServis.slnx
  dotnet test tests/SentezServis.Core.Tests
  dotnet publish src/SentezServis.TrendyolFatura -c Release -o yayin-trendyol-fatura
  ```

### 5. Canlı kuru deneme (yükleme ve ERP'ye yazma yok)
- **Deneme ayarları:** `bin/.../win-x64/appsettings.json` içinde `ServisAyarDosyasi` Host'un appsettings dosyasını, ERP bağlantısı servisin salt okur bağlantısını gösterdi.
- **Komut:** `TrendyolFaturaKontrol.exe --kuru --bir-kez --ayrintili`
- **Sonuç:**
  - 25 fiş denendi. Hepsi CRS'te `Approved` durumundaydı ve son işlemleri yaklaşık 161 dakika önceydi.
  - Her biri için tek paket bulundu, hiçbirinde fatura yoktu. Kuru kip "paket X'e 86 KB PDF yüklenecekti" dedi.
  - 01.11 tarihli 6 fişte sonuç "Trendyol'da fatura var" oldu; kontrolün çalıştığı böylece görüldü.

### 6. Paket
- `TrendyolFaturaKontrol-2026-11-08.zip`: exe (184 MB), README, `appsettings.ornek.json`, `sql/`.
- Repo kökünde duruyor, commit edilmedi (dosya büyük).

- **Commit:** `de52abf` — Trendyol fatura kontrol: ayri konsol uygulamasi (CRS SentToGib -> Trendyol invoiceLink -> PDF yukle)

## Kararlar
- Uygulama ayrı bir exe olarak yazıldı, servis değil (kullanıcı kararı). Canlı ERP'ye yazma ve Trendyol'a yükleme yetkisi ana servisin sürecinden ayrı tutuldu.
- Belge saati CRS işlem kayıtlarından alınıyor (`GetOutboxInvoice` bu alanı boş döndürüyor).
- "GİB'e gönderilmiş" sayılan CRS durumları: `SentToGib` ve `Approved`. Bu liste ayarlardan değiştirilebiliyor.
- Fiş yalnız iki durumda işaretleniyor: Trendyol'da fatura var, ya da yükleme başarılı (Trendyol "önceden gönderilmiş" dediyse de başarılı sayılıyor).

## Açık kalanlar / sonraki adım
- Kullanıcının SSMS'te `UZM_E_ReceiptCheckOK.sql` dosyasını çalıştırması gerekiyor.
- `appsettings.json` hazırlanmalı: yazma yetkili login ve servis ayar dosyasının yolu.
- İlk canlı çalıştırma `TurBasinaAzami` = 5 ile yapılmalı. Bugünkü 134 faturanın hepsi yüklenecek.
- Bölünmüş siparişte ne yapılacağı kullanıcıya soruldu (`TrendyolPaketKarari` içindeki TODO).
- Trendyol `orders` ucunun `v2/orders` ucuna taşınması gerekiyor; bu ana servisi de etkiliyor.
