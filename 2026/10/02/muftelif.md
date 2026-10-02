# muftelif — 2026-10-02

## Bağlam
Yıkama planlaması (SentezPlaning > Haftalık Kapasite) bir gün önce kuruldu. Kullanıcı:
*"dikimdeki gibi liste yükleyip Sentez'den getir dememiz lazım SMV'leri.
ÜRETİM PLANI GÜNCEL - 18.09.2026.xlsx ile yükleyeceğiz."*
Ardından: *"last date alacağız"*, *"oradaki tarihten 1 hafta önceki tarih olarak
düşünmemiz gerekiyor dendi"*.

## Yapılanlar

### 1. Liste Excel'i ile yıkama planı + Sentez'den adet çekme
- **Neden:** Yıkama planının order kümesi ERP'deki açık üretim emirlerinden geliyordu.
  Planlama aslında kendi liste Excel'i üzerinden yürüyor ve hafta ERP terminine göre değil
  **LAST DATE − 1 hafta** olarak düşünülüyor.
- **Dosya yapısı (`ÜRETİM PLANI GÜNCEL - 18.09.2026.xlsx`):** tek sayfa, 258 satır, 197 tekil style.
  `A GELİŞ TARİHİ · B KESİM TARİHİ · C ORDER · D STYLE · E FIT · F YIKAMA ADI ·
  G CONFIRMED PO DATE BY COH · H LAST DATE · I 1ST CUT · J SİP.ADETİ · K TTL · L DURUM · M AÇIKLAMA`.
  LAST DATE hiç boş değil; SİP.ADETİ bazı satırlarda boş, TTL hep dolu → **adet = TTL**, yoksa SİP.ADETİ.
- **Referans:** dikim tarafındaki `UretimPlanImport.cs` deseni (başlık adıyla kolon bulma,
  Excel seri no / tarih hücresi toleransı) birebir izlendi. Dosya formatı farklı olduğu için
  ayrı importer yazıldı.
- **Style → Sentez kartı çözümlemesi (veriyle doğrulandı):** 197 style'ın 173'ü `InventoryCode`
  ile tam eşleşti, 168'inin rotası var. Kalan **24'ün hepsi ana model kodu**, Sentez'de renk
  varyantı olarak duruyor (`2305-576` → `2305-576-BEZAL`). Kural: tam eşleşme → yoksa
  `style + ek` varyantları içinde **rotası olan** tercih edilir. İkame gizlenmiyor, ekranda
  "varyant: `<kod>`" olarak görünüyor.
- **Dokunulan dosyalar:**
  `SentezPlaning/api/Sentez/Planning/YikamaListeImport.cs` (yeni),
  `.../YikamaListeStore.cs` (yeni), `Storage/YikamaListeRepository.cs` (yeni),
  `PlanningSql.cs` (kod bazlı `KartCozum` / `BolumSureleriKod` / `YikamaSureleriKod` / `AdetlerByOrder`),
  `PlanningService.cs`, `PlanningController.cs`, `PlanningModels.cs`, `Storage/PlaningDb.cs`
  (`planning_yikama_liste` tablosu), `web/src/api/planning.ts`, `web/src/pages/PlanningPage.tsx`.
- **Uçlar:** `POST /liste` (yükle), `POST /liste/sentez-cek` (adet güncelle),
  `DELETE /liste` (temizle, plan ERP'ye döner), `GET /liste/durum`.
- **Doğrulama (gerçek dosya):**
  ```bash
  POST /api/sentez/planning/liste        # okunan 258, eklenen 258, süresi yok 1
  GET  /weeks                            # 10 hafta 2026-37..2026-46, 258 order
  POST /liste/sentez-cek                 # 258 kontrol, 31 adet güncellendi, 0 eksik
  GET  /export                           # 4 sayfa, Order Detay 258 satır
  ```
  - Hafta kuralı elle doğrulandı: order 94242 LAST DATE 2026-09-25 → −7g 2026-09-18 → ISO 2026-38,
    API de `2026-38` dönüyor.
  - Güncellenen 31 adedin hepsi Excel TTL'den biraz yüksek (ERP kesim fazlası) — tutarlı.
  - Süresi bulunamayan tek order: 94890 / `A3081-1285` (yıkama MADERA-DERİ, 12 adet).
  - Liste SQLite'ta kalıcı: API yeniden başladığında "258 order" yüklendi.
- **Commit:** `845547b` — feat(sentez-planing/yikama): liste Excel'i yukleme + Sentez'den adet cekme

### 2. Düzeltme — snapshot önbelleği hiç tutmuyormuş
- **Neden fark edildi:** liste yolunu ölçerken ikinci istek de 12 sn sürdü.
- **Sebep:** `IPlanningService` **Scoped** kayıtlıydı; her istekte yeni nesne oluşuyor ve alan
  düzeyindeki önbellek boş başlıyordu.
- **Önemli:** 2026-10-01 günlüğünde "Önbellek: 15,3 sn → 1,6 sn" diye yazdığım ölçüm yanlıştı;
  o hızlanma önbellek değil SQL tarafının ısınmasıydı. Bu satır o gün hatalı kaydedildi.
- **Ne yapıldı:** servis Singleton'a alındı (tüm bağımlılıkları zaten singleton:
  `ISentezConnectionFactory`, `WeeklyCapacityStore`, `PlanningWeekAtamaStore`, `YikamaListeStore`;
  per-request durum tutmuyor).
- **Ölçüm:** 12,6 sn → **0,008 sn** (2. ve 3. istek), orders 0,02 sn, export 1,2 sn.

### 4. Yıkama özet raporu — şablon biçiminde
- **Neden:** Kullanıcı `Frederic Template v85 week12 PLAN.xlsm` dosyasını verdi:
  *"yıkama için özet rapor bu şekilde olması lazımmış, diğer verilerle bir harmanlar mısın"*.
- **Şablonun çözümlenmesi:** 4 sayfa (New Product / Orders / Weekly Capacity / Data).
  Özet rapor **Weekly Capacity** sayfası: satırlar `WSH-*` operasyonları, kolonlar haftalar,
  değer = `SUMPRODUCT(Data!BW<adet>, Data!<op SMV>)/60` yani **saat**. Kapasite
  `E*vardiyalı*6 + F*standart*5`, kullanım = yük/kapasite/verimlilik. Operasyon satırlarının
  etiketleri `Data!` sayfasının başlık satırından (r9) geliyor: her operasyonun bir "X" kolonu
  ve bir "SMV" kolonu var.
- **Ana zorluk:** şablonun ~21 satırı KONSOLİDE, ERP'de aynı işi yapan **88 ayrı operasyon** var
  ve ERP adları Türkçe. Eşleme uydurulamaz; `YikamaOzetEsleme.cs` içinde TEK yerde, desen bazlı
  ve **denetlenebilir** kuruldu.
  - Kesin olanlar: PERMANGANAT→POTASSIUM (potasyum permanganat), KURUTMA→DRYING,
    PARÇABOYA→DYE, KASAR→WHITE, LAZER→LASER, KILÇIK SÖKME→REMOVE TACKING, KILÇIK→TACKING,
    RODEO→BRUSH, BIYIK→WHISKERS, PP bölümü→PP SPRAY.
  - **Islak işlemin sprey öncesi/sonrası ayrımı şablonun `1ST WET PROCESS` / `2ND WET PROCESS`
    satırlarına karşılık geliyor** — dün eklediğim ayrım tam buraya oturdu.
  - **Onay bekleyen:** şablonda yıpratma tarafında üç satır var (DESTROY, BASIC GRINDING,
    OPEN GRINDING W/AIR); ERP'de ESKİTME1/2 ve YIPRATMA1/2/3 duruyor. Şimdilik
    ESKİTME→DESTROY, YIPRATMA→BASIC GRINDING kabul edildi, OPEN GRINDING W/AIR boş.
- **Dokunulan dosyalar:** `PlanningSql.cs` (`OperasyonSureleriKod`), `YikamaOzetEsleme.cs` (yeni),
  `PlanningModels.cs`, `PlanningService.cs` (`GetYikamaOzetAsync`), `PlanningController.cs`
  (`GET /yikama-ozet`), `PlanningExport.cs` ("Yıkama Özet" + "Operasyon Eşleme" sayfaları).
- **İki hata bulup düzelttim:**
  1. Bölüm ara toplamları tekrar tekrar basılıyordu — şablon sırası ıslak önce/sonra arasında
     geçtiği için "bölüm değişince ara toplam" kuralı aynı bölüm için birden fazla ara toplam
     üretiyordu. Satırlar artık bölüm blokları halinde diziliyor, her bölüm bir kez.
  2. **Türkçe harf:** `ToUpperInvariant` `'ı'` harfini `'I'` yapmadığı için `Zımpara Rodeo`
     (5902) `"ZIMPARA RODEO"` desenine takılmıyor, bölüm kuralına düşüp yanlışlıkla
     WHISKERS'a gidiyordu. Adlar artık ASCII'ye normalize edilip eşleştiriliyor.
- **Doğrulama (258 order, 10 hafta):** 122 operasyon satırı eşlendi, **eşlenmeyen 0**.
  Örnek yük (saat): 1ST WET 2063, PP SPRAY 1804, ZIMPARA 1906, LAZER 812, DYE 945.
  Excel 6 sayfa: Yıkama Özet (38 satır) · Operasyon Eşleme (122) · Haftalık Yük · Kapasite ·
  Order Detay (259) · Suresi Yok.
- **Commit:** `52c9796` — feat(sentez-planing/yikama): ozet rapor sablon biciminde

### Veri boşlukları (kullanıcıya iletildi)
- **9 ERP operasyonunun `Erp_Process.StandartTime` alanı boş**, bu yüzden 0 saat katkı veriyorlar.
  En önemlisi `5075 SANTRİFÜJ SIKMA` — **90 kartta** geçiyor ve süresi yok. Diğerleri:
  `5084 KURUTMA` (WSH-DRYING satırı bu yüzden 0), `5093 TAŞ TEMİZLEME(GÖMLEK)`, `207/212 DURULAMA`,
  `5921 Lazer Yıpratma`, `5901 Zımpara Bıyık`, `5902 Zımpara Rodeo`.
- Şablonda olup ERP rotalarında karşılığı olmayan satırlar (boş kalıyor, şekil korunsun diye
  duruyor): LASER FOR POSITION, Cut of Hem with scissor, Overlock Hem with SHORT,
  Cut of Hem with O/L MC, ATTACH FRONT, TIE FRONT B/LOOPS, OPEN GRINDING W/AIR.
- 2026-37..2026-46 haftalarında kapasite girişi yok (yerelde yalnız 2026-27 dolu), bu yüzden
  ara toplam satırlarında kapasite ve yük % sıfır görünüyor.

## Kararlar
- Yıkama haftası = `LAST DATE − 7 gün` (`YikamaListeImport.YikamaOnceGun`).
- Adet = TTL, boşsa SİP.ADETİ. "Sentez'den çek" yalnızca ADET günceller, uyarı vermez.
- Süreler hiçbir zaman Excel'den gelmez; her zaman Sentez'den (rota → etüt → aynı yıkama).
- Liste boşsa eski davranış korunur: order kümesi ERP açık emirleri, hafta UD_TerminRvz2.

### 3. IIS paketi yenilendi
- **Neden:** paket `845547b`'den önce çıkarılmıştı, liste özelliği içinde yoktu.
- **Ne yapıldı:** temiz derleme (`npm run build` + `Deploy-IIS.ps1`), paket yeniden kuruldu:
  `SentezPlaning-IIS-192.168.3.228-90/` (site 94 dosya, `ornek/appsettings.json`,
  `IIS-KURULUM.txt`) + zip 24,1 MB / 96 girdi.
- **Denetim:** sır taraması temiz; `site/logs` ve `site/appsettings.json` pakete girmiyor;
  DLL baytlarında yeni semboller doğrulandı (`planning_yikama_liste`, `YikamaListeImport`,
  `YikamaOnceGun`, `KartCozum`, `AdetlerByOrder`, `BolumSureleriKod`); wwwroot yeni bundle
  (`index-CNQfSmTv.js`).
- **IIS-KURULUM.txt güncellendi:** iki günün değişiklik listesi, `robocopy /XD data logs` komutu,
  `appsettings.json` kopyalanmama uyarısı, iki yeni tablonun açılışta kendiliğinden oluştuğu,
  ve kontrol adımı ("Liste yükle / Sentez'den çek" butonları görünüyorsa yeni sürüm).

## Açık kalanlar / sonraki adım
- Arayüz canlıda denenmedi; paket hazır ama canlıya kurulmadı.
- Sunucu erişimi gün içinde kesildi (192.168.3.228 ping'e cevap vermedi, SQL 1433 kapandı),
  VPN ile geri geldi. Canlı ekranın hangi sürümü koştuğu hâlâ doğrulanmadı.
- Süresi bulunamayan 1 order (94890 / A3081-1285) için rota ya da etüt girilmesi gerekiyor.
