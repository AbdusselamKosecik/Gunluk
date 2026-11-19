# selvedge — 2026-11-19

## Bağlam
Kullanıcı: "1. Selvedge'de model güncellemede/eklemede `A9010D-1371-F1309 PARKER LONG FIT VINTAGE SHORT IN BANK 8.27.26.pdf` ekleyince 500 alıyoruz. 2. Selvedge'de ölçüm sonuçlarını Excel'le girmemiz lazım, SentezSelvedge projesindeki gibi." Ardından: "bitince docker paketi oluştur", "peşinden web'i güncelle".
Proje: `muftelif/Selvedge` (MFG, canlı: Docker Hub `tekbirsoft/selvedge-*` image'ları, `docker-compose.yml`).

## Yapılanlar

### 1. Model PDF içe aktarma 500
- **Neden:** AGOLDE SPRING 2027 PDF'inde "Wash Code" alanında kod yerine not var: `TURKEY DEVELOPED (#S01 - 143469-1A)` (35 karakter). Kolon `sv_Style.WashCode` 32 karakter → SQL kesme hatası → 500. Gerçek kod Wash Color Code alanında (BAN).
- **Bulgu yöntemi:** PDF'i `StylePdfParser` ile ayrıştıran geçici xunit testi (PdfPig `ContentOrderTextExtractor` metni).
- **Ne yapıldı:**
  - `WashCodes.EffectiveCode`: Wash Code virgülle ayrılmış boşluksuz kısa kodlar değilse (`^[A-Za-z0-9][A-Za-z0-9._-]{0,15}$`) ve Wash Color Code doluysa Wash Color Code kullanılır.
  - `StyleService.ApplyHeader` ve yıkama kodu/adı: PDF değerleri kolon boyuna kırpılır (`Clip`), bir daha 500 vermez.
  - Fixture: `tests/Selvedge.PdfImport.Tests/fixtures/agolde-parker-bank-washcode-note.pdf`; 3 yeni test.
- **Sonuç:** 36/36 test; PDF → model `A9010D-1371/BAN`, yıkama BANK.
- **Commit:** `53188c1` — fix(selvedge/pdf-import): Wash Code serbest metinse Wash Color Code kullanilir; PDF alanlari kolon boyuna kirpilir (500)

### 2. Ölçüm sonuçları Excel'den (SentezSelvedge ile aynı)
- **Ne yapıldı:**
  - `Selvedge.Application/Measures/OlcumSpecExcel.cs`: SentezSelvedge `api/Selvedge/Olcum/OlcumSpecExcel.cs`'in kopyası (x2 yardımcıları hariç). Kurallar: başlık "P O M" satırı / 10. satır, beden 6. kolondan; bedenin yanındaki başlığı boş kolonlar okuma (OK=0, +1/8, -1/2, sayı); iki bloklu sayfa ayrımı.
  - `MeasureReadingImportService`: sipariş → modeli; dosya önce tamamen okunur (bozuksa hiçbir şey yazılmaz), okuma yoksa hata. Aynı dosyayla modelin ölçü tablosu güncellenir (`ImportMeasureSpecsFromExcelAsync`). Siparişin önceki "Excel okuma" ölçümleri soft-delete edilir. (beden, adet) başına kapalı bir `Measure` (Notes `Excel okuma - N. adet (dosya)`), bedenin tüm POM'ları; ölçülen = spec + sapma, Difference = sapma, 2x uygulanmaz; okunmamış POM boş kalır. Excel Style ↔ model taban kodu tutmazsa uyarı.
  - API: `POST /api/customer-orders/{id}/measure-readings/import-excel` (QualityControl policy, .xlsx/.xlsm, 20 MB).
  - Web: Siparişler listesinde satır başına Excel ikonu (FileSpreadsheet) → dosya seç → özet + uyarılar toast. i18n tr/en.
  - Yeni test projesi `tests/Selvedge.Application.Tests` (slnx'e eklendi): RANK düzeni sentetik dosya, sapma metinleri, Style eşleşmesi, gerçek dosya (repoda değil: `muftelif/91798 LOW CURVE UTILITY A336-1885-1535 RANK.xlsx`, varsa çalışır).
- **Komutlar:**
  ```bash
  cd Selvedge/tests/Selvedge.Application.Tests && dotnet test   # 13/13
  cd Selvedge/src/Selvedge.Web && npx tsc -b
  dotnet build Selvedge/src/Selvedge.Api
  ```
- **Sonuç:** Gerçek RANK dosyası: 13 beden, 340 okuma → 20 ölçüm (23–32 × 2 adet), 0 uyarı. Canlı DB'ye karşı denenmedi (yerel SQL yok).
- **Commit:** `39f44af` — feat(selvedge/olcum): olcum sonuclari Excel'den (SentezSelvedge ile ayni duzen)

### 3. Docker paketi
- `docker compose -f docker-compose.yml -f docker-compose.build.yml build selvedge-api selvedge-web` (muftelif kökünden).

## Kararlar
- Mobilden ölçüm girişi kapatılmadı (SentezSelvedge'de kapatılmıştı); istenmedi.
- Excel'den ölçüm yükleme modelin ölçü tablosunu da günceller (SentezSelvedge ile aynı).

## Açık kalanlar / sonraki adım
- Web güncellemesi: image'ların Docker Hub'a push'u için bu makinede Docker Hub girişi yok.
