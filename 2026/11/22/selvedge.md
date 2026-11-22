# selvedge — 2026-11-22

## Bağlam
Kullanıcı yeni Satın Alma Inspection API'sini (commit 4c97ccc) sunucuya kendisi kurdu; tablete 1.0.5 kurulması istendi.

## Yapılanlar

### 1. Tablete Selvedge QC 1.0.5
- **Ne yapıldı:** `adb -s R83XB0S3C7Y install -r build/app/outputs/flutter-apk/app-release.apk` (SM-X110).
- **Sonuç:** 1.0.4 (5) → 1.0.5 (6); veri korunur (install -r, aynı imza). Uygulama başlatıldı, süreç çalışıyor.

### 2. Sunucu kurulum kontrolü (192.168.0.2:8085)
- **Kontroller:** kök 200; `SentezSelvedge` Running/Automatic; Selvedge.Api.dll içinde `purchase-inspection`,
  Application.dll içinde `PurchaseInspectionService` var; appsettings*.json değişmemiş (10/6 tarihli);
  log 23:43 temiz açılış, migration 0, hata yok; `/api/purchase-inspection/orders` tokensız 401 (uç nokta yetkili, var).
- **Komut:** WinRM `Invoke-Command -ComputerName 192.168.0.2` + `Invoke-WebRequest`.

## Açık kalanlar
- Gerçek kullanıcıyla tabletten sipariş listesinin geldiğini görmek (şifre bende yok).

### 3. Satın alma inspection: hata girişi (gece)
- **Neden:** Kullanıcı: "satın almada hataları girmemiz lazım; anketten en ve m2'yi kaldıralım; PDF indirebilmeliyim; desktop depoda da görmeliyim".
  Seçimler: yeni KUMAŞ kategorisi, sipariş bazında hata + adet, "Görsel hata" sorusu da kalksın.
- **Ne yapıldı:**
  - `db/migrations/0032_satin_alma_hatalari.sql`: sv_Defect'e 18 kumaş hatası (kod 701-718, Category 'HAMMADDE / KUMAŞ',
    Operation 'Fabric', önem Minor/Major/Critical); MALKABUL anketinde 'En (cm)', 'Gramaj (g/m2)', 'Gorsel hata' soruları
    (ve seçenekleri) IsDeleted=1. Tekrar çalışınca çift eklemez. Canlıda rollback'li transaction içinde iki kez çalıştırılıp doğrulandı.
  - Mobil: `purchase_defects.dart` (fabricCatalog, PurchaseDefect.toJson/caption, totalDefectCount), `purchase_defect_sheet.dart`
    (alt panel: ara/seç → adet, önem, not, foto), `purchase_inspection_screen.dart` sonuç adımında "Hatalar" + "Hata ekle";
    kayıtta `defects` gider, yorumda "Hata adedi: N", hata fotoğrafları QaReport'a caption "kod · ad · adet". `DefectItem`'a category/severity.
    Sürüm 1.0.6+7.
  - PDF (`OrderQaDocument`): "Defect notes" satırına hata açıklaması eklendi; tablo zaten kod/ad/önem/adet basıyordu.
- **Testler:** `test/purchase_defects_test.dart` (RED→GREEN), `test/purchase_inspection_defects_test.dart` (ekle → GEÇTİ → Kaydet,
  istek gövdesi). `flutter test` 15/15. Kılavuz sahneleri: tablet-5-hata-sec, tablet-6-hata-detay, tablet-4-sonuc yenilendi.
- **Paketler:** `publish/Selvedge-Servis-2026-11-22.rar` (yayinla.ps1 çıktısı, appsettings hariç, 0032 içinde),
  `publish/Selvedge-Tablet-1.0.6.rar` / `modfex-qc-1.0.6.7.apk`.
- **Commit:** `5491a8d`.

## Kararlar
- Hata girilmesi sonucu otomatik Kaldı yapmaz; sonucu kalite kontrol seçer.
- Kumaş hatası tanımlı değilse (migration öncesi) tüm katalog gösterilir.
- Önce sunucu (migration 0032), sonra tablet 1.0.6 kurulmalı.

### 4. Tablete Selvedge QC 1.0.6
- **Neden:** Kullanıcı web sunucusunu (migration 0032) kendisi güncelliyor; tablet kurulumu bana bırakıldı.
- **Komut:** `MSYS_NO_PATHCONV=1 adb -s R83XB0S3C7Y install -r publish/modfex-qc-1.0.6.7.apk`
- **Sonuç:** com.modfex.selvedge versionName=1.0.6, versionCode=7; uygulama açıldı (process çalışıyor).

### 5. Sunucu güncelleme kontrolü (0032)
- **Ne yapıldı:** WinRM ile servis/dosya/log; canlı DB'ye scratchpad dotnet script ile salt-okur sorgu.
- **Sonuç:** SentezSelvedge Running, kök 200; log "0032_satin_alma_hatalari.sql uygulandi (75 ms)", temiz açılış; appsettings dokunulmamış (10/6).
  `_sv_SqlMigrations` 0032 kayıtlı; aktif Fabric hata 18, 7xx kod tekrarı 0; MALKABUL anketinde En/Gramaj/Görsel hata yok (kalan: 1,2,6,7,8,9).

### 6. Mal kabul PDF'i: ayrı şablon
- **Neden:** Kullanıcı MK-1795297704998 PDF'ini gösterdi: Brand/Season/Style/AQL gibi alanlar hep "-", anket bölümü boştu.
- **Kök neden (anket):** `LoadSurveyResponsesForOrderAsync` müşteri siparişi yoksa hiç cevap döndürmüyordu; satın alma raporunun anketi yalnız `QaReportId`'ye bağlı.
- **Ne yapıldı:**
  - `src/Selvedge.Reports/Templates/PurchaseQaDocument.cs` (yeni): başlık (GEÇTİ/KALDI, rapor no, tarih); Genel tablo yalnız dolu alanlar (satın alma, tedarikçi, irsaliye, malzeme, top sayısı, denetçi, tarih, seri no'lar); KONTROL LİSTESİ (soru/cevap); HATALAR (kod, ad, önem, adet, not; yoksa "Hata girilmedi."); NOT; sonra anket ve hata fotoğrafları birer sayfa.
  - `QaReportRenderData`: PurchaseOrderNo, WaybillNo, MaterialCode, SerialCodes, `IsPurchaseReceipt` (AuditStage "Mal Kabul"). `QaReportPdfRenderer.Render` buna göre şablon seçer.
  - `QaReportService.MapToRenderData`: mal kabulde alanları doldurur; `MalKabulYorumunuAyir` tablet yorumundan tedarikçiyi alır, "Sipariş:/Top:/Hata adedi:" parçalarını atar, yalnız serbest notu bırakır.
  - Anket yükleyici: siparişsiz ama `qaReportId`'li çağrıda QaReportId ile filtreler.
- **Doğrulama:** scratchpad'de Selvedge.Reports'a bağlı dotnet script ile gerçek verilerle dolu/boş PDF üretildi, PyMuPDF ile görüntülendi.
- **Commit:** `11e5316`. Paket: `publish/Selvedge-Servis-2026-11-22-pdf.rar` (appsettings hariç). Sunucuya kullanıcı kuracak.
