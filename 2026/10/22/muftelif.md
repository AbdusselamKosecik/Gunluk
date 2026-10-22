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


---

## Devam: SentezSelvedge — eski Selvedge anketleri + Fotoğraf soru tipi

### Bağlam
Kullanıcı: "https://mfg.nasilbu.com/surveys'deki anketleri http://192.168.3.228:91/anket'e ekle"
(kaynak girişi admin / kullanıcının verdiği şifre). Kaynakta 3 anket var: Genel (4 soru),
FINISH (6), FINISHLASTSTATUS "Karar Sorulari" (3 TekSecim FAIL/PASS). 2 soru `Photo` tipinde;
SentezSelvedge'de fotoğraf tipi yoktu → kullanıcı "Fotoğraf tipini ekle" seçti.

### 1. Fotograf soru tipi
- **Ne yapıldı:**
  - `api/Selvedge/Anket/AnketModeller.cs`: `SoruTipi.Fotograf` (`Hepsi`'ye eklendi, seçeneksiz).
  - `AnketPuan.Dolu`: Fotograf → `int.TryParse(TextValue) > 0`. Fotoğraflar cevap kaydından SONRA
    yüklendiği için sunucu zorunluluğu istemcinin bildirdiği foto adedine (`textValue`) bakar.
  - `api/Rapor/RaporServisi.cs` `Cevap()`: Fotograf → "N fotograf / photo(s)" (resimler zaten
    "Anket fotograflari" bölümünde `SurveyResponse` eklerinden basılıyordu).
  - Testler: `AnketPuanTests` (+6: adet 2/1 geçer, 0/null/"foto" geçmez; tip kanonik + seçenek almaz).
  - Web `api/anket.ts` `SORU_TIPLERI` += 'Fotograf' (tasarım ekranındaki açılır liste buradan gelir).
    `AnketDoldurPage.tsx`: çoklu `<input type=file>`; kaydet → `cevapApi.kaydet` → her foto
    `dosyaApi.yukle('SurveyResponse', r.id, f, 'foto', soruMetni)`; başarısız foto sayısı toast.
  - Mobil: `survey_models.dart` 'Fotograf' → photo; `toJson` photo → `textValue = adet`.
    `survey_fill_screen.dart`: yükleme `SurveyAnswer`/`answers[].id` (sunucu dönmüyordu → foto HİÇ
    yüklenmiyordu) yerine `SurveyResponse` + `result['id']`, caption = soru metni. Sürüm 2.0.0.3.
  - İzin: AnketDoldur olan her rolde DosyaYaz var (QA, Anketor, Admin) — ek değişiklik yok.
  - Şema değişmedi (`[Type] NVARCHAR(32)`).
- **Doğrulama:** `dotnet test` 486/486; `npm run build` temiz; `build-apk.ps1 -Surum 2.0.0.3` → 
  `sentez-selvedge-2.0.0.3.apk` (75 MB; analyze yalnız info).

### 2. Aktarım betiği
- `SentezSelvedge/araclar/anket_aktar.py`: kaynak `/api/surveys` (+detay) → hedef `POST /api/anket`.
  Tip eşlemesi Text→Metin, Number→Sayi, YesNo→EvetHayir, Date→Tarih, SingleChoice→TekSecim,
  MultipleChoice→CokSecim, Photo→Fotograf. TextEn/NameEn/tarih/qcStage/target korunur, puan null.
  Aynı Code hedefte varsa atlar. Şifreler env: `KAYNAK_SIFRE`, `HEDEF_SIFRE`. `--dene` = yalnız göster.
- **Tuzak:** mfg.nasilbu.com Cloudflare arkasında; Python-urllib User-Agent'ı `403 error code: 1010`
  → `User-Agent: Mozilla/5.0 anket-aktar` eklendi (curl'de sorun yoktu).
- `--dene` çıktısı doğrulandı (3 anket, tipler doğru).
- **Hedefe henüz YAZILMADI:** (a) Sentez'de `admin` kullanıcısı yok ("Kullanici adi bulunamadi");
  anket.yaz izinli bir Sentez kullanıcı kodu/şifresi gerekiyor. (b) Canlıdaki eski sürüm 'Fotograf'
  tipini 400 ile reddeder → önce deploy.

### 3. IIS paketi
- `.\SentezSelvedge\Deploy-IIS.ps1 -OutputDir '...\SentezSelvedge-IIS-192.168.3.228-91\site'`, Deploy-IIS.ps1
  pakete kopyalandı, `SentezSelvedge-IIS-192.168.3.228-91.zip` (21,9 MB) yeniden üretildi.
  Buradan `\\192.168.3.228` paylaşımına erişim yok → kurulum kullanıcıda:
  `.\Deploy-IIS.ps1 -SkipBuild -OutputDir '.\site' -SetupIIS -SiteName SentezSelvedge -Port 91 -PhysicalPath 'C:\inetpub\SentezSelvedge'`
- **Commit:** `3e2e01d` — feat(sentez-selvedge/anket): Fotograf soru tipi + eski Selvedge anket aktarim betigi

### Açık kalanlar
- Sunucuya paket kur → Sentez kullanıcısıyla:
  `set KAYNAK_SIFRE=...& set HEDEF_SIFRE=...& python SentezSelvedge\araclar\anket_aktar.py --hedef-kullanici <kod>`
- Eski 233 anket CEVABI aktarılmadı (yalnız tanımlar istendi).
- APK 2.0.0.3 cihazda denenmedi; foto yüklemesi canlıda denenmedi.
### 4. Aktarım çalıştırıldı (deploy sonrası)
- Kullanıcı paketi sunucuya kurdu; doğrulama: yayındaki bundle `index-DRdw7sbi.js` = yerel paket, içinde `'Fotograf'`.
- `python SentezSelvedge\araclar\anket_aktar.py --hedef-kullanici UZM` (şifreler env) →
  EKLENDI FINISH → RecId 3 (6 soru), FINISHLASTSTATUS → 4 (3), Genel → 5 (4; kod sunucuda `GENEL`'e normalize).
- Geri okuma: 13 sorunun tipi, zorunluluğu, TR/EN metni, seçenekleri (FAIL/PASS), qcStage ve tarihleri kaynakla aynı.
- Hedefte önceden duran test anketleri `FASON01` (RecId 1) ve `TIPTEST` (RecId 2) aktif; dokunulmadı.
### 5. Yetkiler sayfası + anket silme + hata kartları (paket hazır, kurulum bekliyor)
- **İstek:** "yetkilendirmeyi nereden yapacağız" → ekran yoktu (yalnız `POST /api/yetki/ata|kaldir`,
  SentezUserId ister; Admin ayrıca `appsettings Selvedge:Yoneticiler`). "Yetkiler sayfasını yap, Sentez ve
  UZM görsün"; "FASON01 ve TIPTEST'i sil"; "hata kartlarını da ekle".
- **Yetkiler:** `GET /api/yetki/kullanicilar?q=` (`YetkiController`): q boş → rolü olanlar + yönetici
  listesindekiler; dolu → Meta_User kod/ad LIKE (Turkish_CI_AS), TOP 50; roller ikinci sorguyla.
  `YoneticiListesi.Kodlar` eklendi. Web `pages/YetkiPage.tsx` + `api/yetki.ts`, rota `/yetki`
  (`Izin.YetkiYonet`), menü "Yonetim > Yetkiler". Rol başına kutu; sabit yöneticinin Admin kutusu kilitli.
  Roller token'a girişte yazıldığı için değişiklik bir SONRAKİ girişte geçerli.
- **"Sentez" kullanıcısı:** login denemesi `SENTEZ`/`Sentez`/`sentez` → "Kullanici adi bulunamadi".
  Yönetici listesine eklenmedi; kod bulunamadı (kurulumdan sonra Yetkiler'de adla aranacak).
- **Anket silme:** `DELETE /api/anket/{id}` (anket.yaz) → `AnketStore.SilAsync`: Survey + SurveyResponse
  IsDeleted=1 (SiparisListe ve PDF anketin IsDeleted'ına bakmıyor; cevaplar da kapanmalı) + AuditLog.
  Liste ekranında Sil düğmesi (confirm). FASON01 (RecId 1) ve TIPTEST (2) ikişer test cevaplı.
- **Hata kartları:** eski `/api/defects` = 193 kayıt (Yıkama 73, Dikim 67, Finish 43, Kesim 10; severity
  hep null). Hedef `UZM_Selvedge_Defect` boş ve API salt okunurdu → `POST /api/hata-katalog/toplu`
  (YetkiYonet; aynı Code varsa atlar, UPDLOCK/HOLDLOCK; `HataKatalogDogrulama` kod boş/tekrar + kolon
  boyları) + `HataKatalogDogrulamaTests` (5). `araclar/hata_aktar.py` (anket_aktar'ın `giris/istek`'ini
  kullanır). `--dene`: 193 hata, sınır aşan/tekrar yok.
- **Doğrulama:** `dotnet test` 491/491, `npm run build` temiz. Paket + zip yenilendi (bundle `index-BTmf8gfG.js`).
- **Commit:** `079107a` — feat(sentez-selvedge): Yetkiler sayfasi, anket silme, hata katalogu toplu aktarim
- **Sonraki:** kullanıcı paketi kurar → bundle kontrol → `DELETE /api/anket/1`, `/2` → `hata_aktar.py --hedef-kullanici UZM`.
### 6. Kurulum sonrası uygulandı
- Bundle `index-BTmf8gfG.js` = yerel paket (kullanıcı kurdu).
- `hata_aktar.py --hedef-kullanici UZM` → 193 eklendi, 0 atlandı. Katalog geri okuma: Yıkama 73, Dikim 67,
  Finish 43, Kesim 10; TR/EN ad + operation doğru.
- `DELETE /api/anket/1` (FASON01), `/2` (TIPTEST) → kalan: FINISH(3), GENEL(5), FINISHLASTSTATUS(4).
- `GET /api/yetki/kullanicilar` çalışıyor. "Sentez" kullanıcısının kodu **`SentezY`** ("Sentez Yönetici").
  `POST /api/yetki/ata` ile SentezY'ye Admin rolü verildi (DB kaydı; appsettings'e eklenmedi).
  Liste: SentezY [Admin], UZM (sabit yönetici).