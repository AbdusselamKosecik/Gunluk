# muftelif (SentezSelvedge) — 2026-10-20

## Bağlam
Kullanıcı tepkisi: "tasarımı ve ekran düzenini X:\Gitlab\fredericTr\muftelif\Selvedge gibi yap" ve ardından
"siparişlerde indirme, ölçümler falan bir yığın şey yok, QA'larda da indirme yok". SentezSelvedge arayüzü çıplak
tablo/formdu; eski Selvedge'in PDF raporları ve sipariş satırı işlevleri taşınmamıştı.

## Yapılanlar

### 1. Arayüz eski Selvedge görünümüne çekildi
- **Neden:** Kullanıcı eski uygulamanın düzenini istiyor.
- **Ne yapıldı:** `Selvedge/src/Selvedge.Web` incelendi (MainLayout, Button/Card/Badge/Input/PageHeader/DataTable/Modal).
  `web/src/components/ui.tsx` ortak bileşenler, `Yerlesim.tsx` koyu kenar menü (slate-900, aktif indigo, MFG logosu
  invert), üst şerit kullanıcı menüsü; giriş ekranı degrade zemin; tüm liste sayfaları DataTable; form sayfaları
  PageHeader + kart; sipariş KK/model QA modal; yeni ölçüm modal. `index.css` base katmanında form odak stili ve
  tablo hücre dolgusu. Bağımlılık: `lucide-react@1.17.0`, `@radix-ui/react-dialog@1.1.15`; `public/mfg-logo.png`.
- **Doğrulama:** Sahte API (scratchpad `mock/sahte-api.mjs`, port 5401) + vite 5179 + Chrome DevTools ekran
  görüntüleri: giriş, ana sayfa, siparişler, sipariş modalı, QA raporu, ölçüm modalı, anket tasarım. Bulunan
  kusurlar düzeltildi: filtre kutularının `w-full` ile yayılması (`girdi()` yardımcı), tarih/rozet satır kırma,
  form tablolarında başlıkların yapışması, "Sil" metni → çöp kutusu ikonu, anket form etiketleri.
- **Commit:** `c6587b5` — style(sentez-selvedge/web): eski Selvedge arayuzu

### 2. PDF raporları + sipariş penceresi + QA fotoğrafları
- **Neden:** Eski uygulamada "QA raporu (MFG) indir", tekil QC PDF, sipariş anketleri/ölçümleri vardı.
- **Ne yapıldı:**
  - `Selvedge.Reports` → `api/Rapor` (OrderQaDocument, RaporVerisi, ImageDimensions, MeasureValueFormatter,
    QuestPdfBootstrap), QuestPDF 2026.5.0. Levi's/Inditex şablonları alınmadı (eskide de kullanım dışı).
  - `RaporServisi`: tek QC (`/api/kk/{id}/pdf`) ve sipariş birleşik (`/api/order-qa/order/{id}/pdf`), `?en=true`.
    Veri: KkStore detay, Measure/MeasureItem oturumları, SurveyResponse/Answer/Option, Attachment resimleri
    (`MimeType LIKE 'image/%'`), Sentez'den marka/sezon, OrderQc tedarikçi/final karar. PublicBaseUrl boş (spec §6).
  - `/api/order-qa/order/{id}/anketler`, `/api/files?entityType&entityId`, `DELETE /api/files/{id}` (soft delete).
  - Web: sipariş satırında MFG PDF + "QA raporu aç" (`/kk/yeni?siparis=`), modalda sekmeler (Sipariş KK, Model QA,
    QA raporları, Ölçümler, Anketler); QA listesinde PDF; rapor sayfasında QC PDF TR/EN + Fotoğraflar.
- **Doğrulama:** `RaporSablonTests` (QC/ORDER × TR/EN + boş rapor) gerçek PDF üretiyor; rapor SQL'leri canlıda
  salt okuma ile çalıştırıldı; testler 472/472; web build temiz.
- **Commit:** `943a603` — feat(sentez-selvedge): QA PDF raporlari, siparis penceresi, QA fotograflari

### 3. Dağıtım paketi yenilendi
- `Deploy-IIS.ps1` publish'e `-r win-x64 --self-contained false` eklendi (QuestPDF linux/osx/arm yerel
  kütüphaneleri paketi 50 MB yapıyordu → 23,6 MB). Commit `2203f19`.
- `SentezSelvedge-IIS-192.168.3.228-91.zip` yeniden üretildi (152 dosya); `IIS-KURULUM.txt`'e 2026-10-20 ekleri.

### 4. Mobil uygulama (APK) SentezSelvedge uçlarına çevrildi
- **Neden:** Kullanıcı "buna göre apk'yı da ayarla, endpointlerini" dedi. Eski MFG Selvedge Flutter
  uygulaması (`Selvedge/src/selvedge_mobil`, 1.0.4.77) eski Selvedge API'sine (`/api/customer-orders`,
  `/api/qa-reports`, `/api/measures`…) gidiyordu; yeni API'de bunların hiçbiri yok.
- **Ne yapıldı:**
  - Uygulama `SentezSelvedge/mobile` altına kopyalandı (yalnız Android; ios/web/windows yok). Önce değişmemiş
    kopya ayrı commit (`4058b19`), sonra uyarlama (`7ae436c`) — fark okunur olsun diye.
  - Yalnız veri katmanı (`lib/data/api/*`) yeniden yazıldı; ekranlar eski sözleşmeyi görmeye devam ediyor
    (adaptör: `QaReportsApi.get` sunucunun baslik+detay'ını eski tek parça haritaya çevirir, `update` geri böler).
  - Eşleme tablosu `SentezSelvedge/mobile/README.md`'de. Özet: firma = siparişin yerel tedarikçisi, yoksa
    Sentez carisi (modfex selvedge 0029 ile aynı kural); sipariş = Sentez iş emri tip 15; QC = `/api/kk`;
    ölçü tablosu = Sentez iş emrinin Excel eki; TP = iş emrinin PDF eki.
  - **API'ye mobil için eklenenler:** `/api/sentez/order?firmaId` + sorguya yerel KK satırı (TedarikciId/Adi,
    KkDurumu, FinalQcResult); `/api/hata-katalog`; `/api/olcum/spec?isEmri&ek` (bedenler, satırlar,
    `ciftOlculer`); `PUT /api/olcum/{id}/kk` (rapor bağı, aynı iş emri şartı); `PUT /api/files/{id}`
    (başlık); `/api/sentez/order/{id}/ek/{ekId}` (ek o iş emrine ait değilse 404); ölçüm listesinde
    `SatirSayisi`. `KkDeger.Asamalar`'a mobilin QC tipleri (Kumas Kalite … Finish/Paket Final QC) eklendi
    (web `DENETIM_ASAMALARI` de; `ArayuzSozlukTests` ikisini eşit tutar).
  - **Yakalanan hata:** ölçüm açılınca sunucu satırları 1..n numaralar, ekran ise Excel'in 1. sütundaki sıra
    no'su ile dizer → değer başka POM'a yazılabilirdi. `satirEsle` (konum + POM kodu) ile eşleniyor; 4 birim testi.
  - Hata kataloğu canlıda **0 satır** → QC girişinde aranan metin "… hatasını ekle" ile serbest hata olur.
  - Anket cevabı sonradan rapora bağlanamıyor (uç yok) → QC sihirbazında anketler rapor oluşunca `qaReportId`
    ile gönderiliyor; QC detayında anketler salt okunur özet.
  - E-posta düğmeleri kaldırıldı (API'de yok). Sunucu ayarlarındaki sahte "bağlantı testi" (1,5 sn sonra hep
    başarılı) gerçek istek oldu (`/api/auth/me` → 401 = ayakta). "Daha Fazla"daki sabit örnek kullanıcı
    ("Ayşe Yılmaz #4471") yerine oturumdaki Sentez kullanıcısı.
  - Kimlik `com.mfg.sentezselvedge`, ad "Selvedge Sentez", sürüm 2.0.0.1 → eski uygulamayla yan yana kurulur.
    Varsayılan sunucu `http://192.168.3.228:91`, giriş ekranı → Sunucu Ayarları'ndan değişir.
- **Dokunulan dosyalar:** `SentezSelvedge/mobile/**`, `api/Sentez/SentezSql.cs|SentezReader.cs|SentezController.cs|SentezModeller.cs`,
  `api/Selvedge/Kk/HataKatalog.cs|KkModeller.cs`, `api/Selvedge/Olcum/OlcumStore.cs|OlcumController.cs|OlcumModeller.cs`,
  `api/Dosya/DosyaDeposu.cs|DosyaController.cs`, `tests/.../MobilUcTests.cs`, `web/src/api/kk.ts`, spec §12 notu.
- **Komutlar:**
  ```powershell
  # APK (C:\flutter 3.47.2, JDK 21, Android SDK) — çıktı muftelif kökünde, repoya girmez
  powershell -ExecutionPolicy Bypass -File SentezSelvedge\mobile\build-apk.ps1 [-Surum 2.0.0.2]
  # IIS paketi (yalnız site klasörü; kurulum notları korunur) + zip
  .\SentezSelvedge\Deploy-IIS.ps1 -OutputDir '...\SentezSelvedge-IIS-192.168.3.228-91\site'
  ```
- **Sonuç / doğrulama:** `dotnet test` 480/480, `tsc -b` temiz, `flutter analyze` 0 hata/uyarı, `flutter test` 7/7.
  Yeni SQL'ler canlıda salt okunur denendi (OrderAra firma süzgeçli/süzgeçsiz, OrderById, ölçüm listesi,
  katalog, ek listesi; KkBagla UPDATE'i BEGIN TRAN/ROLLBACK ile). Not: sqlcmd varsayılanı QUOTED_IDENTIFIER OFF —
  filtreli indeksli tabloya UPDATE denerken `SET QUOTED_IDENTIFIER ON` şart (.NET istemcisi zaten ON).
  İlk APK derlemesi, derleme sürerken paralel `flutter analyze/test` çalıştırdığım için bozuldu
  (GeneratedPluginRegistrant debug modda dev bağımlılığıyla yeniden üretildi) → `flutter clean` + tek başına derleme.
  APK: `X:\Gitlab\fredericTr\muftelif\sentez-selvedge-2.0.0.1.apk` (75 MB, repoya girmez). IIS paketi yeniden üretildi ve ziplendi (152 dosya, 21,9 MB).
- **Commit:** `4058b19` (kopya), `7ae436c` — feat(sentez-selvedge/mobile): mobil uygulama SentezSelvedge API'sine cevrildi

## Kararlar
- PDF'te resimler link'siz (fotoğraflar açık adreste durmaz).
- Sipariş raporunun sonucu = Sipariş KK paneli "Final KK kararı".
- Mobil, eski uygulamanın yerine değil yanına kurulur (ayrı applicationId); geçiş bitince eskisi kaldırılır.
- Ölçüm ↔ rapor bağı 1-N kaldı (ölçüm başına bir rapor); eski N-N'e geçilmedi.

## Açık kalanlar / sonraki adım (eski Selvedge'de olup henüz yok)
- Dashboard (KPI/grafikler), e-posta ile rapor gönderme, listelerde Excel'e aktarma, anket cevapları sayfası +
  Excel, hata kataloğu ekranı, kullanıcı/rol yönetim ekranı, Final QC onay/sıfırlama akışı (kısmen Sipariş KK'da).
- Mobil: telefonda gerçek sunucuya karşı uçtan uca deneme yapılmadı (giriş, QC kaydı, ölçüm, PDF).
  Hata kataloğu boş — eski Selvedge'deki hata listesi taşınmalı ya da web'e katalog ekranı eklenmeli.
  "Raporlar" sekmesi eski uygulamadaki gibi örnek (seed) veri gösteriyor.
- Gerçek veriyle uçtan uca deneme sunucuda yapılmalı (bu makinede .NET → SQL bağlantısı zaman aşımı).
