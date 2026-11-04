# muftelif — 2026-11-04

## Bağlam
Frederic (Olcay) WhatsApp'tan SentezSelvedge kalite için iki istek iletti:
1. MFG giyimde 2. kontrolde ölçümler rapora bağlanamıyor (1. kontrol "kaldı" → tamir → tekrar kontrol).
2. PDF'te fotoğraf sırası İstanbul'daki gibi olmalı: önce anket, sonra hata fotoğrafları.

## Yapılanlar

### 1. KK raporu ↔ ölçüm bağı N-N (0008)
- **Neden:** Bağ tek kolondu (`UZM_Selvedge_Measure.QaReportId`). 1. rapora bağlı ölçüm, mobilin `availableMeasures` filtresinde (`qaReportId == null || == bu rapor`) 2. rapor için hiç listelenmiyordu. Bağlansa bile 1. rapordan kopacaktı. Eski Selvedge'de bağ N-N idi (`sv_QaReportMeasure`).
- **Ne yapıldı:**
  - `db/0008_kk_olcum_bag.sql`: `UZM_Selvedge_QaReportMeasure(RecId, QaReportId FK, MeasureId FK, CreatedAt, CreatedBy)`, tekil `(QaReportId, MeasureId)` indeksi, eski `Measure.QaReportId` bağları taşınır (idempotent). Eski kolon silinmedi, artık okunmuyor/yazılmıyor.
  - `OlcumStore`: liste/getir `OUTER APPLY` ile son bağlı rapor (`QaReportId`, `ReportNo`) + tüm bağlar (`QaReportIdleri`, `STRING_AGG`). `KkBaglaSorgusu` artık bağ tablosuna INSERT (aynı iş emri şartı korundu, tekrar bağlama 1 döner). Yeni `KkBagKaldirSorgusu` (rapor bazlı; NULL = tüm bağlar, eski istemci uyumu). Rapordan açılan ölçüm açılışta bağ satırı alır; `EkleSorgusu` QaReportId yazmaz.
  - `OlcumModeller.OlcumOku.QaReportIdler` (JSON'a gider), `QaReportIdleri` JsonIgnore.
  - `OlcumController`: `DELETE /api/olcum/{id}/kk/{qaReportId}`; PUT mevcut sözleşmeyle bağ EKLER.
  - `RaporServisi` QC PDF ölçümleri: `EXISTS (... UZM_Selvedge_QaReportMeasure ...)`.
  - `SemaBeklenen` +1 tablo (23), uygulama komutuna 0008. Testler: tablo/script sayıları 8/23, N-N SQL testleri (`MobilUcTests`).
  - Mobil: `MeasureListItem.qaReportIds`, `availableMeasures` siparişin TÜM ölçümlerini listeler, `isLinked = qaReportIds.contains(rapor)`, `detachMeasure` → yeni `unlinkReport` (DELETE).
- **Doğrulama:** `dotnet test` 545/545. LocalDB'de boş veritabanına 0001–0008 uygulandı; senaryo: ölçüm 10 rapor 1'e bağlı → 0008 iki kez (bir kez taşındı) → rapor 2'ye bağla = 1, tekrar = 1, başka siparişin raporu = 0, liste `QaReportId=2, QaReportIdleri=1,2`, rapor 1 bağını kaldır → yalnız `2|10` kaldı. Canlı DB (192.168.1.22) bugün erişilemedi.
  ```bash
  sqlcmd -S "(localdb)\MSSQLLocalDB" -d SvTest0008 -I -b -i 0008_kk_olcum_bag.sql   # -I: QUOTED_IDENTIFIER ON sart (filtreli/tekil indeks)
  ```
- **Commit:** `c6d31c3` — feat(sentez-selvedge/olcum): KK raporu-olcum bagi N-N (0008)

### 2. PDF'te önce anket, sonra hata fotoğrafları
- **Neden:** Anket fotoğrafları `AnketResimleriAsync` ile hata fotoğraflarının `Attachments` listesine SONA ekleniyordu; şablondaki "önce anket" bölümü (`SurveyImagePages`, `Answer.ImagePaths`) hiç beslenmediği için boştu.
- **Ne yapıldı:** Yeni `api/Rapor/AnketFotoEslestirme.cs`: ek başlığı (= soru metni, TR veya EN, büyük/küçük harf ve boşluk duyarsız) ile fotoğraf sorusuna eşler; uymayan → cevabın ilk fotoğraf sorusu; fotoğraf sorusu yoksa "eşleşmeyen" olarak eski yere (hata foto listesi) düşer, resim kaybolmaz. `AnketlerAsync` cevapların `ImagePaths/ImageIds`'ini doldurur; `AnketResimleriAsync` kaldırıldı. Şablon sırası değişmedi: FINISH anketi → diğer anketler → hata fotoğrafları → ölçümler.
- **Dokunulan dosyalar:** `api/Rapor/RaporServisi.cs`, `api/Rapor/AnketFotoEslestirme.cs`, `tests/.../AnketFotoEslestirmeTests.cs`
- **Commit:** `bde96e4` — fix(sentez-selvedge/rapor): PDF'te once anket fotograflari, sonra hata fotograflari

### 3. Mobil 2.0.0.6 + IIS paketi
- `fc02698` — sürüm 2.0.0.6; `sentez-selvedge-2.0.0.6.apk` (JAVA_HOME = `C:\Program Files\Android\openjdk\jdk-21.0.8`).
- `Deploy-IIS.ps1 -OutputDir '...\SentezSelvedge-IIS-192.168.3.228-91\site'`; `sema\db\0008_kk_olcum_bag.sql` ve APK pakete kopyalandı; `IIS-KURULUM.txt` başına 2026-11-04 bölümü yazıldı; zip yenilendi (`SentezSelvedge-IIS-192.168.3.228-91.zip`).

## Kararlar
- Bağ N-N, eski kolon korunur (geri dönüş). Bağ satırı hard delete; iz AuditLog'da (`KkBagla` / `KkBagKaldir`).
- Fotoğraf↔soru eşlemesi başlıktan; ek tablosuna QuestionId kolonu eklemek yerine (şema + iki istemci değişikliği) mevcut sözleşme kullanıldı.

## Açık kalanlar / sonraki adım
- SUNUCU SIRASI: 0008 (DDL yetkili hesap) → 9001 GRANT bloğu → paket → APK 2.0.0.6. Yeni API 0008 olmadan açılmaz (şema doğrulaması).
- Canlıda doğrulama: kaldı → tamir → 2. kontrol akışında ölçüm seçimi; PDF'te anket fotoğrafı sırası (2.0.0.5'ten önceki cevaplarda foto yok, test için yeni kayıt gerekir).
- 2026-11-02'den: `survey_fill_screen.dart` yükleme hatasını hâlâ yutuyor.
