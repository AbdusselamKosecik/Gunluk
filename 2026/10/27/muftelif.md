# muftelif — 2026-10-27

## Bağlam
26.10'da SentezPlaning'de Fashion & ND hattına Fashion / Non Denim alt görünümü (yalnız yük) eklenmişti
(`3148029`, `d7ee125`). Planlama (Asiye H.) paketi kurup kontrol etti, iki istek iletti (WhatsApp + mail):
1. Alt görünümde başlıklar eksik: **Çalışan, Eff, Dev., Tahmini, Fark**.
2. "Parametreler kısmına da bantları ekleyelim, oraya parametreleri gireyim."

Aynı gün (Olcay B.): SentezSelvedge'den mail gidecek kişiler — hbolu@, mtureli@, ybabadag@ (mfggiyim.com.tr).
Kullanıcı ayrıca "APK'yı da değiştirmen gerekiyor, önce SentezPlaning bitir sonra bak" dedi.

## Yapılanlar

### 1. SentezPlaning: bantlara (Fashion / Non Denim) kendi kadro parametresi
- **Neden:** Alt görünüm kapasite göstermiyordu çünkü çalışan hat başınaydı ve dikim yerine bölünemiyordu
  (26.10 kararı). Planlama bantların kadrosunu ayrı girmek istiyor → bölmek yerine bant başına ayrı parametre.
- **Ne yapıldı:**
  - Model: `LineDef.YerParametreleri : List<YerParam>`; `YerParam { DikimYeri, Calisan, EffGercek=0.85, Abs=0.03 }`.
    `HatAltGrup.Param(line, yer)` (boşluk/harf duyarsız eşleşme).
  - SQLite: yeni tablo `line_yer_param (line_id, dikim_yeri, calisan, eff_gercek, abs, PK(line_id,dikim_yeri))`,
    `CREATE TABLE IF NOT EXISTS` → açılışta kendiliğinden oluşur. Repository Load/Save + `DELETE FROM line_yer_param`.
  - `PUT lines`: bant parametresi yalnız hattın güncel dikim yerleri için tutulur (dikim yeri silinirse parametresi
    düşer), çift kayıt tekilleşir; doğrulama: calisan ≥ 0, eff 0–3, devamsızlık 0–1.
  - `GetWeeks(yer)`: bant parametresi varsa calisan/eff/abs ondan → Tahmini, Fark, Durum, Op. ihtiyacı (abs) hesaplanır;
    `CalisanKaynak/EffKaynak = "bant"`. Yoksa eskisi gibi `Durum="yok"` (yalnız yük). Bantta hafta override'ı yok.
    `GetWeeksToplam(yer)` parametreli bantta tam hafta özetini verir. `GetSevk(yer)` Op. ihtiyacında bandın abs'ı.
  - Excel: bant sayfası parametre varsa `Çalışan, Eff, Dev., Tahmini, Fark` kolonları (+ toplam) taşır.
  - Web: Parametreler → Hatlar'da çok dikim yerli hattın altında `↳ Fashion`, `↳ Non Denim` satırları
    (Çalışan / Eff gerçek / Devamsızlık; çalışan boşaltılırsa bant parametresi silinir). Dikim'de `bantParam`
    varsa `yukOnly=false` → kolonlar ve tam hafta özeti açılır; kaynak simgesi "⚙ bant satırı".
  - **Birleşik Fashion & ND hattının hesabı DEĞİŞMEDİ** (kendi Varsayilan'ını kullanır).
- **Dokunulan dosyalar:** `SentezPlaning/api/Sentez/UretimPlan/{HatAltGrup,UretimPlanController,UretimPlanExport,UretimPlanModels,UretimPlanService}.cs`,
  `SentezPlaning/api/Storage/{PlaningDb,UretimPlanRepository}.cs`, `SentezPlaning/web/src/api/uretimPlan.ts`,
  `SentezPlaning/web/src/pages/UretimPlanlamaPage.tsx`, `SentezPlaning/tests/SentezPlaning.Tests/{HatAltGrupTests,BantParamKayitTests}.cs`
- **Komutlar:**
  ```powershell
  cd SentezPlaning/api; dotnet build
  cd ../tests/SentezPlaning.Tests; dotnet test        # 271/271
  cd ../../web; npx tsc -b; npm run build
  cd ..; powershell -ExecutionPolicy Bypass -File .\Deploy-IIS.ps1
  Compress-Archive publish\* X:\Gitlab\fredericTr\SentezPlaning-paket-2026-10-27-4a71920.zip -Force
  ```
- **Sonuç / doğrulama:** test 271/271 (yeni: bant param eşleşmesi, Excel bant kolonları, SQLite kaydet/oku turu);
  tsc/build temiz; bundle `index-Cn6rDXyl.js`, zip 7.9 MB. Ekran tarayıcıda denenmedi (sunucu kullanıcıda).
- **Commit:** `4a71920` — feat(sentez-planing/dikim): Fashion ve Non Denim bantlarina kendi parametresi

### 2. SentezSelvedge: QA PDF maili (web + mobil) ve mobil 2.0.0.4
- **Neden:** Olcay B.: "SentezSelvedge'de mail gönderilecek kişiler" hbolu@, mtureli@, ybabadag@ (mfggiyim.com.tr).
  Kullanıcı: "APK'yı da değiştirmen gerekiyor". Eski Selvedge'de "Raporu Maille" (sipariş birleşik PDF) ve QC kartında
  "Mail" vardı (Smtp:Recipients'e PDF); 7ae436c'de API karşılığı olmadığı için mobilden kaldırılmıştı.
  Kullanıcı sorulara cevap vermeden "bitirdin mi" deyince varsayılanla ilerlendi: eskisi gibi elle tetiklenen mail.
- **Ne yapıldı:**
  - API: `Rapor/MailServisi` (MailKit 4.13.0, eski SmtpEmailService ile aynı kural: 465 SSL, 587 STARTTLS, EnableSsl=false
    şifresiz). `Smtp` config: Host/Port/EnableSsl/Username/Password/From/Recipients; Recipients JSON dizi ya da `a;b`.
    Host yoksa `InvalidOperationException("Mail sunucusu tanimli degil (Smtp:Host bos)...")` → 400 `{hata}`.
    Uçlar: `POST /api/kk/{id}/mail?en=`, `POST /api/order-qa/order/{workOrderId}/mail?en=` (izin KkOku), yanıt `{gonderildi, alici}`.
  - `appsettings.json`: `Smtp.Recipients` = 3 adres; Host/Username/Password BOŞ (ortam değişkeni `Smtp__*`).
  - Web: `MailDugmesi` (TR + EN, onay sorar) → KkRaporPage başlığı, OrderPage "Raporu maille".
  - Mobil: `sendQaEmail` / `sendEmail` geri (yeni uçlara); sipariş ekranında "Raporu Maille", QC kartında "Mail";
    Mezuralar başlığındaki "+ Yeni" kaldırıldı (`_sectionHeader` aksiyonu opsiyonel) + açıklama notu. Sürüm 2.0.0.4.
- **Dokunulan dosyalar:** `SentezSelvedge/api/{Program.cs,appsettings.json,SentezSelvedge.Api.csproj,Rapor/MailServisi.cs,Selvedge/Kk/KkController.cs,Selvedge/OrderQa/OrderQaController.cs}`,
  `SentezSelvedge/tests/SentezSelvedge.Tests/MailServisiTests.cs`, `SentezSelvedge/web/src/{components/RaporBilesenleri.tsx,pages/KkRaporPage.tsx,pages/OrderPage.tsx}`,
  `SentezSelvedge/mobile/{pubspec.yaml,lib/core/version.dart,lib/data/api/customer_orders_api.dart,lib/data/api/qa_reports_api.dart,lib/features/orders/order_detail_screen.dart}`
- **Komutlar:**
  ```powershell
  cd SentezSelvedge/api; dotnet add package MailKit --version 4.13.0
  dotnet test SentezSelvedge/tests/SentezSelvedge.Tests          # 538/538
  cd SentezSelvedge/web; npx tsc -b; npm run build
  cd SentezSelvedge/mobile; .\build-apk.ps1 -Surum 2.0.0.4        # analyze temiz, 75 MB
  .\SentezSelvedge\Deploy-IIS.ps1 -OutputDir "$PK\site"          # bundle index-CuyHwEBZ.js
  Compress-Archive SentezSelvedge-IIS-192.168.3.228-91\* SentezSelvedge-IIS-192.168.3.228-91.zip -Force   # 25.0 MB
  ```
- **Sonuç / doğrulama:** test 538/538 (alıcı çözümü, appsettings'te 3 alıcı ve şifre yok, Host yoksa anlaşılır hata).
  Gerçek SMTP ile gönderim DENENMEDİ (sunucu bilgisi yok). IIS-KURULUM.txt'ye "2026-10-27" bölümü (Smtp__* komutları).
  APK: `X:\Gitlab\fredericTr\muftelif\sentez-selvedge-2.0.0.4.apk` (repoya girmez).
- **Commit:** `8f389d9` — feat(sentez-selvedge): QA PDF maili + mobil 2.0.0.4 (yeni olcum dugmesi kaldirildi)

### 3. SentezPlaning: bant kolonları her zaman görünür
- **Neden:** Kullanıcı 4a71920 paketini kurdu; "Fashion ve Non Denim'de Çalışan, Eff, Dev., Tahmini, Fark alanları yok".
  Kolonlar yalnız bant parametresi girildiyse açılıyordu (`yukOnly`); parametre girilmeden bakılınca kayıp sanıldı.
- **Ne yapıldı:** `CapacityTable`: `kap` hep true, `bos = yukOnly` → Çalışan/Eff/Dev./Tahmini/Fark hücreleri "—"
  (title: Parametreler → Hatlar'da çalışan girilmedi). Alt görünüm başlığı: "⚠ <bant> bandına henüz çalışan girilmedi…
  ↳ <bant> satırına çalışan girip Kaydet". Excel bant sayfasında kolonlar hep var, parametresizse boş.
- **Dokunulan dosyalar:** `SentezPlaning/web/src/pages/UretimPlanlamaPage.tsx`, `SentezPlaning/api/Sentez/UretimPlan/UretimPlanExport.cs`,
  `SentezPlaning/tests/SentezPlaning.Tests/HatAltGrupTests.cs`
- **Sonuç:** test 271/271, tsc/build temiz; paket `X:\GitlabredericTr\SentezPlaning-paket-2026-10-27-5acf0e4.zip`
  (7.9 MB, bundle `index-DCTRbtBz.js`). Ekran tarayıcıda denenmedi.
- **Commit:** `5acf0e4` — fix(sentez-planing/dikim): Fashion / Non Denim'de Calisan-Eff-Dev-Tahmini-Fark kolonlari hep gorunur

## Kararlar
- Bant kadrosu hattın kadrosundan **bölünmüyor**, ayrıca giriliyor; birleşik hat kendi parametresiyle kalır
  (ikisi tutarsız girilebilir — planlamaya söylenecek).
- Bant için İK departman eşleşmesi ve hafta override'ı yok (istenmedi); verimlilik senaryoları hattınkiler.

## Açık kalanlar / sonraki adım
- SentezPlaning paketi (`SentezPlaning-paket-2026-10-27-5acf0e4.zip`, 4a71920'in yerine) sunucuya kurulmalı → Parametreler'de
  Fashion / Non Denim satırlarına çalışan girilmeli → Ctrl+F5.
- Birleşik hat çalışanı = bantların toplamı mı olmalı? Planlamaya sorulacak.
- SentezSelvedge paketi (8f389d9) kurulmalı + app pool'a `Smtp__Host/Port/Username/Password/From` girilmeli;
  bilgi kullanıcıdan/BT'den gelecek (bana yazılmayacak). Sonra bir QC'den "Maille" ile deneme.
- APK 2.0.0.4 cihazlara dağıtılmalı. Mail otomatik mi olmalı (KK Fail vb.)? Kullanıcıya sorulmuştu, cevap yok.
