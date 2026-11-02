# muftelif — 2026-11-02

## Bağlam
Kullanıcı bildirimi (acil): SentezSelvedge PDF raporunda hata fotoğrafları geliyor, anket fotoğrafları gelmiyor.

## Yapılanlar

### 1. Anket fotoğraflarının PDF'e gelmemesi — kök neden ve düzeltme
- **Neden:** PDF'te hata ve anket fotoğrafları aynı yoldan basılıyor (`RaporServisi.AnketResimleriAsync` → `Attachments` → `OrderQaDocument.DefectImagePages`), yani rapor tarafı sağlamdı; şüphe yüklemeye kaydı.
- **Kanıt (canlı DB, SentezLive, `uzm_selvedge_app`):**
  - Son 13 anket cevabında `Fotograf` sorusunda bildirilen adet var (1–8), `UZM_Selvedge_Attachment` içinde `EntityType='SurveyResponse'` eki **0** (yalnız 2026-10-03 tarihli 2 eski test eki).
  - Anket cevapları KK raporuyla aynı saniyede yazılmış → anket `SurveyFillScreen`'den değil, KK giriş ekranından (`qc_entry_screen.dart`) gönderiliyor.
- **Kök neden:** `qc_entry_screen.dart` `_save` akışı `submitResponse` dönüşünü (cevap id) atıyor ve fotoğraf sorularının resimlerini **hiç yüklemiyordu**. Hata fotoğrafları için yükleme döngüsü vardı, anket için yoktu.
- **Ne yapıldı:** Cevap kaydından sonra `tamsayi(sonuc['id'])` alınır; her `SurveyQuestionType.photo` sorusunun `draft.photos`'u `uploadBytes(entityType: 'SurveyResponse', entityId: responseId, kind: 'image', caption: q.text)` ile yüklenir. Yüklenemeyen adet snackbar'daki anket hatalarına eklenir (artık sessiz değil). `atts` tanımı anket döngüsünün önüne alındı (hata foto döngüsü de aynısını kullanıyor).
- **Dokunulan dosyalar:** `SentezSelvedge/mobile/lib/features/qc/qc_entry_screen.dart`, `SentezSelvedge/mobile/lib/core/version.dart` (2.0.0.5), `SentezSelvedge/mobile/pubspec.yaml` (2.0.0+5)
- **Komutlar:**
  ```bash
  sqlcmd -S 192.168.1.22 -U uzm_selvedge_app -d SentezLive -i anket_foto_kontrol.sql   # SQLCMDPASSWORD ortam degiskeni
  /c/flutter/bin/flutter analyze lib/features/qc/qc_entry_screen.dart   # hata/uyari yok
  export JAVA_HOME="C:\Program Files\Android\openjdk\jdk-21.0.8"   # JAVA_HOME tanimli degildi; yol gradle daemon logundan bulundu
  /c/flutter/bin/flutter build apk --release
  cp build/app/outputs/flutter-apk/app-release.apk ../../sentez-selvedge-2.0.0.5.apk
  ```
- **Sonuç / doğrulama:** Analiz temiz, APK derlendi (75 MB). Cihazda uçtan uca test henüz yapılmadı.
- **Commit:** `caf7369` — fix(sentez-selvedge/mobile): KK girisindeki anket fotograflari sunucuya yuklenir (2.0.0.5)

## Kararlar
- Eski cevapların fotoğrafları kurtarılamaz: resimler sunucuya hiç gitmedi, yalnız o anki telefonda bellekteydi.

## Açık kalanlar / sonraki adım
- `sentez-selvedge-2.0.0.5.apk` telefonlara kurulmalı; yeni bir KK + anket girip PDF'te "Anket fotografları" sayfası görülmeli.
- `survey_fill_screen.dart` (siparişten tek anket doldurma) yüklemeyi yapıyor ama hatayı hâlâ `catch (_)` ile yutuyor — aynı bildirim eklenebilir.
- Web/mobilde dolu anketin cevap+foto detay görünümü yok (yalnız PDF'te görülüyor).
