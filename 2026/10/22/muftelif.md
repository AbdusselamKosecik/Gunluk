# muftelif (SentezPlaning) — 2026-10-22

## Bağlam
Planlamadan (Asiye Aydın) "YIKAMA PLANI GELİŞTİRME" e-posta zinciri geldi
(`muftelif/YIKAMA PLANI GELİŞTİRME.eml`). Kullanıcı: *"yeni sorunlar istenen çıktıda buna göre
olacakmış. Frederic Template v85 week12 PLAN.xlsm"*. Şablon dosyası 10-05'teki
`Output-...PLAn.xlsm` ile birebir aynı (md5 `84b7498b…`).

- **20.10 maili:** Parametrelerde çalışan sayısı yok. Lazerde makine sayısı önemli ama kapasite
  **çalışan sayısına göre** hesaplanacak. Vardiyalı = 7,25 saat × 6 gün, normal = 9 saat × 5 gün.
- **22.10 maili:** "Vardiyalı ibaresi eklenmiş ancak kapasite 9×7,25 = 65,25 olacağına 392
  görünüyor"; başlık "Müsait sa." → **"Mevcut Kapasite"**.

## Yapılanlar

### 1. Çözümleme
- **Ölçülen:** raporun grup kapasitesi (`YikamaOzetSatirDto.MusaitSaat`) yalnızca
  `SablonGrup.Gruplar` içindeki **koddaki sabit** kadrodan geliyordu (DYE&WHITE 9 V, LASER 12 V,
  TOUCH UP 6 S, TACKING 5 S, POTASSIUM 6 S, PP SPRAY 6 S). `weekly_capacity` /
  `operasyon_param`'a hiç bakmıyordu; planlamanın değiştirebileceği bir yer yoktu.
- **392 nereden:** 9 × 7,25 × 6 = 391,5 → **haftalık** saat. Şablonun formülü de haftalık
  (`G = E*$E$5*6 + F*$F$5*5`, Lazer 12×7,25×6 = 522). Asiye Hanım'ın 65,25'i **günlük**.
  Sunucudaki sürüm 10-16 öncesi (kodda DYE&WHITE için şablonun 7,5'i ile 405 çıkıyordu,
  ekranda 392 → paket eski).
- **Kullanıcı kararları (soruldu):**
  - Mevcut Kapasite: **günlük ve haftalık yan yana**; yük % haftalıkla.
  - DYE & WHITE: **7,25** (şablonun 7,5'i tutarsızlık sayıldı) → 405 değil 391,5.

### 2. Uygulama
- **Ne yapıldı:**
  - `SablonGrup`: `Kisi` ondalıklı; `GunlukSaatEzme` kaldırıldı; `GunlukSaat` (kişi × 7,25 | × 9),
    `MusaitSaat` = günlük × 6 | × 5; `Kadro` kaydı, `Etkin(kayıtlar)` (kayıtlı kadro varsayılanı
    ezer, sıra/üyeler/`MakineVardiya` şablondan), `KadroListesi`, `KadroDenetle` (tanımsız grup,
    kişi 0–1000).
  - SQLite `yikama_kadro (grup PK NOCASE, kisi REAL, vardiyali INT, updated_utc)` — hafta bazlı
    değil. `YikamaKadroRepository` (LoadAll / Kaydet, tek transaction). Kaydı olmayan grup
    şablon varsayılanında kalır.
  - API: `GET` / `PUT api/sentez/planning/yikama-kadro` (`YikamaKadroDto`, `YikamaKadroGiris`).
  - `PlanningService.GetYikamaOzetAsync`: gruplar `SablonGrup.Etkin(_kadro.LoadAll())`'dan;
    DTO'ya `GunlukSaat`.
  - Web: `YikamaKadroPanel` (Parametreler → Kapasite, CapacityPanel'in yanında): grup başına
    "Çalışan sayısı" (virgüllü ondalık), "Vardiyalı (7,25 × 6) / Normal (9 × 5)", canlı
    "Mevcut Kapasite: x sa/gün · y sa/hafta", şablon varsayılanından sapma notu.
    `YikamaOzetTablo`: "Müsait sa." → iki kolon "Mevcut Kapasite sa/gün" + "sa/hafta".
  - Excel (`YikamaPlanExport` Weekly Capacity): operasyonların altına **KAPASİTE GRUPLARI**
    satırları (E/F kadro, G haftalık, hafta yükleri, ek kolon "Mevcut Kapasite (sa/gün)").
- **Dokunulan dosyalar:** `SentezPlaning/api/Sentez/Planning/{SablonGrup,PlanningService,PlanningController,PlanningModels,YikamaPlanExport}.cs`,
  `api/Storage/{PlaningDb,YikamaKadroRepository}.cs`, `api/Program.cs`,
  `web/src/api/planning.ts`, `web/src/components/planning/{YikamaKadroPanel,YikamaOzetTablo,CapacityPanel}.tsx`
  (`Num` export edildi), `web/src/pages/PlanningPage.tsx`,
  `tests/SentezPlaning.Tests/{SablonGrupTests,OperasyonStoreTests,ArayuzSozlukTests}.cs`.
- **Komutlar:**
  ```bash
  dotnet test tests/SentezPlaning.Tests          # 263/263
  cd web && npx tsc -b                           # temiz
  # canlı: data/sentez-planing.db yedeklendi, API 5299 Development, JWT dev anahtarıyla imzalandı
  GET  /api/sentez/planning/yikama-kadro         # DYE&WHITE 9 V → 65,25 / 391,5
  PUT  .../yikama-kadro [{"grup":"YOK",...}]     # 400 "Tanimsiz grup"
  # paket
  powershell -ExecutionPolicy Bypass -File .\Deploy-IIS.ps1
  Compress-Archive publish\* X:\Gitlab\fredericTr\SentezPlaning-paket-2026-10-22-5bf314f.zip
  ```
- **Sonuç / doğrulama:**
  - 263/263 test (yeni: günlük/haftalık 65,25/391,5 · 54/270 · 2,5 kişi; Etkin ezme + tanımsız grup;
    denetim; repository üzerine yazma; TS↔C# alan sözlüğü). DYE&WHITE testi 405 → 391,5.
  - ESLint: yeni dosyalar temiz; `PlanningPage.tsx:46` ve `:94`'teki iki `set-state-in-effect`
    hatası önceden vardı.
  - **Doğrulanamayan:** `yikama-ozet` canlı veriyle denenemedi (192.168.1.22:1433 kapalı, VPN yok).
    Tarayıcı kontrolü yapılamadı (chrome-devtools profili başka oturumda kilitli).
  - Yerel SQLite test sonrası yedekten geri konuldu (md5 aynı).
  - Paket: `publish` 70 dosya, zip 7,9 MB; `.db`/`.log`/Development yok; JS'de "Kadroyu Kaydet",
    "Mevcut Kapasite", "sa/gün", DLL'de `yikama_kadro` var → bayat değil.
- **Commit:** `5bf314f` — feat(yikama): kadro parametresi (calisan + vardiyali/normal) ve "Mevcut Kapasite" gunluk/haftalik

## Kararlar
- Kadro **grup başına ve global** (hafta bazlı değil) — şablonda da tek kolon.
- Mevcut Kapasite günlük + haftalık yan yana; kullanım oranı haftalıkla (hafta kolonları haftalık saat).
- Vardiyalı her satırda 7,25 (şablon satır 55'teki 7,5 uygulanmaz).
- Haftalık Kapasite bölüm hesabına (`CapacityCalc`, Lazer = makine × saat × vardiya) dokunulmadı;
  çalışan esaslı kapasite yalnızca raporun grup satırlarında.

## Açık kalanlar / sonraki adım
- Sunucuya kurulum (kullanıcıda):
  `.\Deploy-IIS.ps1 -SkipWebBuild -SetupIIS -SiteName SentezPlaning -Port 8090 -PhysicalPath 'C:\inetpub\SentezPlaning'`
  ya da zip `X:\Gitlab\fredericTr\SentezPlaning-paket-2026-10-22-5bf314f.zip`.
- VPN açıkken `yikama-ozet` ve Parametreler ekranı canlı kontrol edilmeli.
- Haftalık Kapasite'deki Lazer bölümü de çalışan esaslı olsun istenirse `CapacityCalc` ayrıca değişmeli.
