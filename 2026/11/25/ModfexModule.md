# ModfexModule — 2026-11-25

## Bağlam
ModfexModule (Sentez Live extension, `X:\GitHub\Sentez-Core\ModfexModule`, ModaSimaModule kopyası).
Referans kaynak: `D:\Backup\007-Coding\Sentez\SENTEZ-ERP\Sentez`.
Hedef: Hizmet stopajı — parametre ekranı + faturadan 56 tipli cari fiş otomatik üretimi.

## Yapılanlar

### 1. Tasarım ve plan
- **Neden:** Kurallar netleşsin (eşik tabanı, yön, saklama yeri).
- **Ne yapıldı:** Kullanıcıyla kararlar: eşik = faturanın KDV hariç toplamı (tüm satırlar),
  kayıtta baştan eşitleme (A), parametreler Sentez DB parametre sistemi (A).
- **Dokunulan dosyalar:** `docs/superpowers/specs/2026-11-25-stopaj-cari-fis-design.md`,
  `docs/superpowers/plans/2026-11-25-stopaj-cari-fis.md`
- **Referanstan öğrenilenler:**
  - Tip 56 kaynakta YOK; sadece güncel `Dlls\LiveCore.dll`'de "56-Cari İşlem Fişi (Genel)".
  - Fatura satırları `Erp_InventoryReceiptItem`; hizmet `ItemType=2`, kart `ServiceCardId` → `Erp_Service`.
  - KDV hariç satır tutarı `NetItemTotal` (iskonto/masraf dağıtılmış).
  - Sistem entegrasyonu tip 21 + `Erp_Invoice.CurrentAccountReceiptId` kullanır → dokunulmadı.
  - Cari fiş: `CurrentAccountReceiptBO`, ilişki `FK_Erp_CurrentAccountReceiptItem_Erp_CurrentAccountReceipt`,
    satırda `GLAccountId` (int), `SourceModule/SourceId/SourceType`, `SpecialCode`.
  - `InvoiceReceiptType` namespace'i `Sentez.Common.SystemServices`; `.Purchase`, `.Returned`.
- **Commit:** `6adec43`

### 2. Saf hesaplayıcı + xUnit testleri
- **Ne yapıldı:** `Withholding/WithholdingCalculator.cs` (Sentez'den bağımsız):
  toplam `<= MinAmount` → boş; hizmet ve oran≠0 satır → `round(Net×oran/100, 2, AwayFromZero)`;
  `Side(purchase, returned) = purchase XOR returned ? Debit : Credit`.
  `Tests/ModfexModule.Tests.csproj` kaynak dosyayı link ile derler; ana csproj'da `Tests\**` Remove.
- **Komutlar:** `dotnet test Tests` → 9/9 geçti.
- **Commit:** `6adec43`

### 3. Parametre ekranı
- **Ne yapıldı:** `Parameters/ModfexWithholdingParameters.cs` (`ParameterBase`, ID **3121**:
  IsActive byte, MinAmount decimal `DecimalDefaultValue(300)`, GLAccountCode string).
  `ParametersPM` → `GetParameterClass<>()` + `Load/Save(companyId?, null, null, conn)`
  (CanCompanyBased ise firma bazlı). `Views/Parameters.xaml` 3 alan. `RegisterCoreDocuments`'ta
  `RegisterParameterClass`, `RegisterViews`'ta `Parameters` view kaydı. Menüden Trendyol kaldırıldı.
- **Commit:** `7d6b652`

### 4. InvoiceBO extension
- **Ne yapıldı:** `BoExtensions/WithholdingInvoiceExtension.cs` + `Withholding/WithholdingReceiptSync.cs`.
  - `OnAfterPost` (aktifse): fatura transaction'ında hedef hesaplanır; fiş
    `ReceiptType=56 and SourceModule and SourceId=fatura` ile bulunur; satırlar `SpecialCode=fatura satırı RecId`
    ile eşlenir (ekle/güncelle/sil); hedef boşsa fiş silinir; iptal faturada fiş silinir.
  - `OnBeforeDelete`: fiş silinir (parametre pasif olsa da).
  - Eşik toplamından indirim(50)/masraf(51) satırları hariç (çift sayım olmasın).
  - `UD_WithholdingTax` kolonu `COL_LENGTH` ile kontrol; yoksa stopaj yok.
  - Hesap kodu yok / 56 tipi tanımsız → exception, fatura kaydı geri alınır.
  - `RegisterBO`: `AddCustomExtension("InvoiceBO", typeof(WithholdingInvoiceExtension))`.
- **Sonuç:** `dotnet build` 0 hata; push edildi.
- **Commit:** `4a4d207`

## Kararlar
- Satır olayı takibi yerine her kayıtta baştan eşitleme (eşik geçişlerini doğal çözer).
- Parametre pasife çekilince mevcut fişlere dokunulmaz.
- Fiş satırında SourceId = fatura RecId (drill-down), satır kimliği SpecialCode'da.

## Açık kalanlar / sonraki adım
- Canlı Sentez'de manuel test: alış/satış/iade, eşik 300 sınırı, satır silme, fatura silme, iptal.
- `UD_WithholdingTax` oranı yüzde mi (20) yoksa kesir mi (0.20) — müşteride doğrulanmalı.
- Yüklü LiveCore.dll'de 56 tipinin Borç/Alacak izinleri doğrulanmalı.
- Kullanılmayan `Models/Parameter.cs` / `ParameterItem.cs` (JSON) temizlenebilir.

### 5. Hata düzeltme: "Başka modülden üretilmiş cari hesap fişine satır ekleyemezsiniz."
- **Neden:** İlk canlı denemede fatura kaydı bu hatayla durdu.
- **Kök neden:** `FinanceModule/BoExtensions/CurrentAccountReceiptDataCheckServiceExtension` —
  `SourceModule/SourceId` dolu cari fişte değişiklik/satır ekleme-silmeyi engelliyor. Sentez'in kendi
  `CreateCurrentAccountReceiptIntegrationService`'i (satır 249-253, 536) bu extension'ı ve
  `UpdateApprovedReceiptControlExtension`'ı `Extensions[name].BusinessObject = null` ile kapatıyor.
- **Ne yapıldı:** `WithholdingReceiptSync.CreateReceiptBO` içinde `Init` sonrası iki extension kapatıldı
  (`ContainsKey` korumalı).
- **Sonuç:** Derleme OK (çıktı DLL'i Live/VS açık olduğu için kopyalanamadı). Canlıda tekrar denenecek.

### 6. Hata düzeltme: "Fiş satırlarına masraf yeri girmelisiniz."
- **Kök neden:** `Common/Core/Services/ReceiptControlService/ReceiptCostCenterControlExtension.cs:101-106` —
  `WorkPeriodParameters.CurrentAccountReceiptCostCenterControl` 2/3 ise `Erp_CurrentAccountReceiptItem.CostCenterId`
  boş satırı reddeder.
- **Ne yapıldı:** Fiş başlığına faturanın `CostCenterId`'si; fiş satırına fatura satırının `CostCenterId`'si,
  boşsa fatura başlığınınki yazılıyor (`CostCenterOf`). Kontrol kapatılmadı — iş kuralı, veriyle karşılanıyor.
- **Not:** Faturada hem satırda hem başlıkta masraf yeri boşsa hata yine çıkar (beklenen davranış).

### 7. Hata düzeltme: 56 fiş cari hesaba yansımıyor ("hesaba katmıyor")
- **Belirti:** Elle girilen 56 fiş (00000002) çalışıyor, modülün ürettiği (00000001) yansımıyor.
- **Teşhis (SentezCore_test @ 192.168.0.2, sadece SELECT):** Fiş 26278'in başlığı var (Debit 50,
  UpdatedAt 10:56:44) ama **hiç satırı yok**. Fatura 557694 10:57:58'de tekrar kaydedilmiş; aynı anda tip 21
  satırı 1628222 oluşmuş. Bizim satırımız (RecId boşluğu 1628221) o kayıtta silinmiş.
- **Kök neden:** Sentez `DeleteIntegrationCurrentAccountReceiptService` / `CreateCurrentAccountReceiptIntegrationService`
  `delete from Erp_CurrentAccountReceiptItem where SourceModule=11 and SourceId=<fatura> and SourceType=<tip> ...`
  ile eski entegrasyon satırlarını düz SQL siliyor; bizim satırlar bu üçlüyü taşıyordu.
- **Ne yapıldı:** Satırda `SourceModule/SourceId/SourceType` = NULL; bağ sadece başlıkta. Satıra `TermDate`
  (elle girilen fişte dolu, bizde boştu).
- **Onarım:** Mevcut satırsız fiş, fatura tekrar kaydedilince eşitleme satırı yeniden ekler.

### 8. Bozuk 56 fişin temizlenmesi (SentezCore_test)
- **Neden:** Satırsız kalan fiş 26278 (00000001) arayüzden silinemiyordu ("başka modülden üretilmiş" kontrolü — tasarım gereği).
- **Bulgu:** Fişe bağlı otomatik muhasebe fişi vardı: Erp_GLReceipt 604769 (SourceModule=3, SourceId=26278), 2 satır
  (9196 borç / 10201 alacak, 50 TL). Yani 56 cari fiş Sentez tarafından muhasebeye de entegre ediliyor.
- **Ne yapıldı:** Tek transaction, xact_abort, ön koşul kontrollü: GLReceiptItem(2), GLReceipt(1), CurrentAccountReceipt(1) silindi;
  CostCenterDistribution / GLReceiptItemInv / GLReceiptIntegration'da kayıt yoktu.
- **Not:** Fatura 557694 tekrar kaydedilince yeni 56 fiş (yeni kodla, satır kaynak alanları boş) oluşur.
