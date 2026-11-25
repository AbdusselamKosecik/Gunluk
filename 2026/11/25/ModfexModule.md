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
