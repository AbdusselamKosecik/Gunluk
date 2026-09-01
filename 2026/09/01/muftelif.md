# muftelif (Selvedge) — 2026-09-01

## Bağlam
Branch: `feat/sentez-planing-ayrimi`. İstek: Selvedge'de "Units sampled" yazan
tüm yerlerin (PDF çıktıları ve girişler) "Units reviewed" olması; ardından APK ve
Docker üretimi.

## Yapılanlar

### 1. "Units Sampled" → "Units Reviewed" etiket değişikliği
- **Neden:** Müşteri terminolojisi; numune değil, kontrol edilen adet anlamı.
- **Ne yapıldı:** Sadece **görünen metinler** değiştirildi. Kod tarafındaki
  `UnitsSampled` alan/DTO/kolon adları ve `unitsSampled` i18n anahtarı aynen
  bırakıldı (DB kolonu ve API sözleşmesi kırılmasın diye).
- **Dokunulan dosyalar:**
  - `Selvedge/src/Selvedge.Reports/Templates/LevisAuditDocument.cs` (2 yer:
    tablo hücresi + özet satırı; TR karşılığı "Numune Adedi" korundu)
  - `Selvedge/src/Selvedge.Reports/Templates/OrderQaDocument.cs` (KeyVal başlığı)
  - `Selvedge/src/Selvedge.Reports/Templates/InditexInspectionDocument.cs`
    (tablo başlığı "Sampled" → "Reviewed")
  - `Selvedge/src/Selvedge.Web/src/i18n/en.json` → `qaReports.unitsSampled`
    değeri "Units Reviewed". TR (`tr.json`) zaten "Kontrol Edilen Adet", dokunulmadı.
- **Doğrulama:** `grep -rni "units sampled"` kaynak ağacında (bin/obj/dist hariç)
  sadece `qc_entry_screen.dart` içindeki bir yorum satırında kaldı; görünen metin yok.
- **Not:** Mobil (Flutter) tarafında bu etiketin görünen bir karşılığı yok —
  sadece API alan adı olarak geçiyor, yani mobil UI'da değişiklik gerekmedi.

### 2. Docker imajları 1.0.4.77
- **Ne yapıldı:** `BuildDocker_1.0.4.76.bat` şablonundan `BuildDocker_1.0.4.77.bat`
  üretildi (açıklama başlığı güncellendi) ve çalıştırıldı.
- **Komut:**
  ```bat
  X:\Gitlab\fredericTr\muftelif\BuildDocker_1.0.4.77.bat
  ```
- **Sonuç / doğrulama:** İkisi de build + push oldu:
  - `tekbirsoft/selvedge-api:1.0.4.77-dev` + `:latest`
    → digest `sha256:1d775a6ac963b26de0c777f8f8bec20422f65da2e55d529ada90847603f1bb21`
  - `tekbirsoft/selvedge-web:1.0.4.77-dev` + `:latest`
    → digest `sha256:d748a7636135c941568e5fa4a214ebd2da20eeecb6c4785959698766228516f4`

### 3. APK — ÜRETİLEMEDİ
- **Neden olmadı:** Bu makinede **Flutter SDK kurulu değil**. PATH'te `flutter`
  yok; tüm disklerde (C/D/X/Y) tarandı, sadece
  `D:\Hdd\Root\20240114 Yedekler\C\flutter` altında **3.16.0** (Dart 3.2) yedeği var;
  proje `sdk: ^3.11.1` istiyor, o yüzden kullanılamaz.
- **Karar (kullanıcı):** APK atlandı — mobilde zaten görünen bir metin değişmedi.
  `version.dart` / `pubspec.yaml` için yapılan 1.0.4.77 bump'ı **geri alındı**
  (mobil sürüm son yayınlanan APK ile aynı kalsın: 1.0.4.75).
- **Commit:** `b405aa2` — feat(selvedge): "Units Sampled" etiketleri "Units Reviewed" oldu

## Kararlar
- Görünen metin değişti, **şema/alan adları değişmedi** (`UnitsSampled` kolonu,
  `unitsSampled` JSON alanı ve i18n anahtarı korundu) — eski APK'lar ve mevcut
  DB kırılmasın diye.
- Türkçe metinler (PDF'te "Numune Adedi", web'de "Kontrol Edilen Adet")
  değiştirilmedi; istek İngilizce etiket içindi.

## Açık kalanlar / sonraki adım
- Flutter SDK kurulunca (stable, Dart ≥3.11.1) mobil sürüm bump + APK üretimi
  gerekirse yapılacak. Şablon: `deploy/build-apk-1.0.4.75.ps1`.
- İstenirse PDF'teki TR karşılığı da "Kontrol Edilen Adet" olarak hizalanabilir.
