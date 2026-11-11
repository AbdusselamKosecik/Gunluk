# FredericModule — 2026-11-11

## Bağlam
`doc/Yazilimci-Teknik-Dokuman.md` (Sürüm 3, UPC aktarımı) ve `doc/UPC-Aktarim-Demo.html` (tarayıcı demosu) vardı.
Hedef: modüle bir ekran ekleyip Amerika Excel'indeki seçili modellerin UPC'lerini InventoryBO üzerinden
Varyant → Barkod'a yazmak (Get → kontrol → PostData).

## Yapılanlar

### 1. UPC Barkod Aktarımı ekranı
- **Neden:** Yeni modellerin renk/beden UPC'leri elle giriliyordu; doküman seçili modellerin koşullu aktarımını istiyor.
- **Ne yapıldı:**
  - `UpcSourceReader`: XLSX (EPPlus) / CSV okur. Başlık 1. satır; alias'lar: Style No|Model Kart No|Model,
    Color Code|Renk, Size|Beden, UPC Number|UPC|Barkod. Birden fazla uygun sayfa / tekrar eden başlık → hata.
    Sayı olarak saklanmış UPC'ye sıfır EKLENMEZ (11 hane kalır → hata). Sınırlar 35 MB / 100.000 satır.
  - `UpcValidator`: UPC-A (12 rakam + kontrol basamağı: tek pozisyonlar ×3), boş alan, model+renk+beden tekrarı,
    aynı UPC farklı varyantta → `KaynakHatasi`. Yazıldı/Atlandı satırların durumuna dokunmaz.
  - `UpcTransferService.TransferModel`: model kartı `Erp_Inventory where CompanyId, InventoryCode, InventoryType=6,
    InventorySubType=1` (tam 1 sonuç şart) → `InventoryBO.Get(RecId)` → varyant `Erp_InventoryVariant` +
    `Erp_VariantItem` (Variant1=renk, Variant2=beden). BO'daki `Erp_InventoryBarcode`: aynı barkod → Atlandı;
    varyantta farklı barkod → Hata (ezmez); UPC bu kartta başka varyantta / başka kartta (aynı firma) → Hata;
    değilse NewRow+SetParentRow (InventoryId, InventoryVariantId, Barcode, ItemVariant1/2Code varsa).
    Kart başına tek `PostData()` (≠ `PostResult.Succeed` → o kartın yazılacak satırları Hata + `bo.ErrorMessage`).
    Günlük CSV: `Belgeler\FredericUpcLog\UPC_yyyyMMdd_HHmmss.csv`.
  - `UpcCodeMapper`: renk/beden eşlemesi, varsayılan birebir (bilgi işlem doğrulaması bekleniyor).
  - `UpcTransferPM` + `Views/UpcTransfer.xaml` (gevşek XAML, Resource): dosya yükle (seçim boş başlar), arama
    (seçimi değiştirmez), tümünü seç (filtre dışı dahil), toplu kod (bulunmayan kod varsa tümü reddedilir, eski
    seçim korunur), önizleme grid'i (durum renkli), Sentez'e Aktar (kaynak hatası varsa engel, `_busy` ile çift tık
    koruması, başarılılar tekrar gönderilmez, Message ilerleme penceresi).
  - Kayıt: `FredericModule.cs` RegisterPM (`UpcTransferPM`) + RegisterViews (`UpcTransfer`, ResSource.Page),
    csproj `Page Remove` + `Resource Include`, `ModuleMenu.xml` → "UPC Barkod Aktarimi".
- **Dokunulan dosyalar:** `Bussines/UpcTransfer/*.cs`, `Models/UpcTransferModels.cs`,
  `PresentationModels/UpcTransferPM.cs`, `Views/UpcTransfer.xaml`, `FredericModule.cs`, `FredericModule.csproj`, `ModuleMenu.xml`
- **Komutlar / doğrulama:**
  - Repo bu makinede olduğu gibi derlenmiyor (baz durum): `Y:\D\frederic\...` VModule/VUIModule/VRprModule yok ve
    `Views/UzmanCuttingCard.xaml` `AlignmentConverter` hatası (MC3074). Doğrulama scratch kopyada yapıldı:
    `Dlls` junction, Y: HintPath'leri `..\Dlls\x64\` ile değiştirildi, UzmanCuttingCard.xaml `Page Remove` → `dotnet build` 0 hata.
  - `XamlReader.Parse(UpcTransfer.xaml)` → OK.
  - Küçük net8 konsol testi (UpcValidator + modeller): 10/10 PASS (geçerli/0'la başlayan UPC, yanlış kontrol
    basamağı, 11 hane, harf, anahtar tekrarı, UPC çakışması, boş renk, yazılmış satır korunur).
  - Canlı Sentez'e yazma test EDİLMEDİ.
- **Commit:** `95128d0` — UPC Barkod Aktarimi ekrani eklendi

## Kararlar
- Yazma SQL ile değil InventoryBO ile (doc §5: tablo tahminiyle update yok; BO extension'ları çalışsın).
- Varyantta farklı barkod varsa (ör. EAN) hata — doc §4 "farklı barkod → hata" aynen uygulandı.
- Global UPC çakışma kontrolü firma kapsamında (`i.CompanyId`).
- `doc/` klasörü commit edilmedi (demo HTML şirket ürün verisi içeriyor; kullanıcı kararı).

## Açık kalanlar / sonraki adım
- Test Sentez'de gerçek bir modelin iki bedeniyle yaz + yeniden oku; aynı/farklı barkod senaryoları.
- `Erp_InventoryBarcode` için BarcodeType/UnitId zorunlu mu — Sentez yetkilisiyle teyit.
- Renk/beden kodları Amerika ↔ Sentez aynı mı? Değilse `UpcCodeMapper` doldurulacak.
- Model filtresi `InventoryType=6 / InventorySubType=1` doğru mu teyit.
- İsteğe bağlı: "Seçilen UPC'leri Excel indir" (doc §7) eklenmedi.

---

## Ek tur (gece) — "Dosya okunamadi" hata detayi yok

### 2. Dosya okuma hatalarinin gorunur ve dayanikli hale getirilmesi
- **Neden:** Kullanici: "dosya okunamadi diyor ama hata detayi yok". Pencere yalnizca `ex.Message` gosteriyordu;
  inner exception ve tur kayboluyordu. Ilk surum `new ExcelPackage(FileInfo)` ile dosyayi dogrudan aciyordu (Excel'de acikken kilit sorunu riski).
- **Ne yapildi:**
  - `UpcSourceReader.Read`: dosya `FileShare.ReadWrite|Delete` ile `byte[]`'a alinir; once EPPlus, olmazsa ExcelDataReader
    (`Encoding.RegisterProvider(CodePagesEncodingProvider.Instance)` + `ExcelReaderFactory.CreateReader`, .xls de okunur).
    Ikisi de basarisizsa mesajda iki hata birlikte + "Farkli Kaydet .xlsx" onerisi.
  - Okuma ham "Sheet(Name, List<string[]>)" yapisina indirildi; baslik eslestirme/satir olusturma ortak `Parse`'ta.
  - Baslik bulunamazsa her sayfanin okunan basliklari ve eksik alanlar mesajda listelenir.
  - `Describe(ex)`: `Tur: mesaj -> InnerTur: mesaj` zinciri.
  - PM: hata penceresi zinciri gosterir; tam `ex.ToString()` `Belgeler\FredericUpcLog\OkumaHatasi_yyyyMMdd_HHmmss.txt`.
- **Dokunulan dosyalar:** `Bussines/UpcTransfer/UpcSourceReader.cs`, `PresentationModels/UpcTransferPM.cs`
- **Dogrulama:** scratch kopyada `dotnet build` 0 hata (Dlls junction yeniden kuruldu: `mklink /J scratch\bt\Dlls X:\GitHub\Sentez-Core\Dlls`).
  net6 konsol testi (EPPlus.Core 1.5.4 + ExcelDataReader 3.6.0 + reader kaynak dosyasi) 5/5 PASS: xlsx metin+sayi UPC,
  kilitli (FileShare.Read) dosya, BOM'lu `;` CSV, yanlis baslik mesaji, bozuk xlsx'te iki okuyucu hatasi.
  Kullanicinin gercek dosyasindaki asil hata henuz bilinmiyor — yeni surumle tekrar denenince mesaj/log ile gorulecek.
- **Commit:** `abd7658` — UPC aktarim: dosya okuma hatasinda detay goster, kilitli/sorunlu dosyalari oku

### Notlar
- Kullanici `FredericModule.csproj`'de Y:\ HintPath'lerini `..\Dlls\x64\` yapmis (commit edilmemis, dokunulmadi).
