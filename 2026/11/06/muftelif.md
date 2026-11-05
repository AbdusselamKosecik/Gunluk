# muftelif — 2026-11-06

## Bağlam
İstek: SentezSelvedge'de kalite kontrol (QC raporu) maili gönderilirken konuya sipariş (order) numarası eklensin.
Önceki durum (2026-11-04 sonrası): 0008 canlıya uygulanmış, site 192.168.3.228:91 açık (HTTP 200, `UZM_Selvedge_QaReportMeasure` var).

## Yapılanlar

### 1. QC mail konusunda sipariş numarası
- **Neden:** Konu yalnız PDF adından geliyordu (`QC Raporu - KK-202610-0007-QC`); alıcılar maili siparişle eşleştiremiyordu.
- **Ne yapıldı:**
  - `RaporServisi.KkPdfAsync` dönüşüne `SiparisNo` (= `r.WorkOrderNo`) eklendi: `(Pdf, DosyaAdi, SiparisNo)`.
  - Yeni `RaporServisi.KkMailKonusu(raporAdi, siparisNo, ingilizce)`: TR `QC Raporu - Siparis <no> - KK-...-QC`, EN `QC Report - Order <no> - ...`; sipariş yoksa eski konu.
  - `KkController.Mail` bu yardımcıyı kullanıyor. Sipariş raporu maili (`OrderQaController`) zaten `order-<no>-MFG` adını taşıdığı için değişmedi.
- **Dokunulan dosyalar:** `SentezSelvedge/api/Rapor/RaporServisi.cs`, `SentezSelvedge/api/Selvedge/Kk/KkController.cs`, `SentezSelvedge/tests/SentezSelvedge.Tests/KkMailKonusuTests.cs`
- **Sonuç / doğrulama:** `dotnet test` 550/550.
- **Commit:** `bf6189b` — feat(sentez-selvedge/mail): QC raporu mail konusunda siparis numarasi

### 2. Sunucu paketi
- `Deploy-IIS.ps1 -SkipWebBuild -OutputDir '...\SentezSelvedge-IIS-192.168.3.228-91\site'` (web değişmedi, bundle `index-CuyHwEBZ.js`).
- `IIS-KURULUM.txt` başına 2026-11-06 bölümü (şema değişmedi), zip yenilendi: `X:\Gitlab\fredericTr\muftelif\SentezSelvedge-IIS-192.168.3.228-91.zip`.

## Kararlar
- Konuda "Siparis/Order" etiketi + iş emri no; mobil/web değişikliği gerekmez (konu sunucuda üretiliyor).

## Açık kalanlar / sonraki adım
- Paket sunucuya kurulmalı (yalnız adım 6/9, veritabanı adımı yok).
- Kurulumdan sonra bir QC raporundan "Mail" ile konu kontrol edilmeli (SMTP ayarları tanımlı olmalı).
