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

### 5. Yıpratma eşlemesi karara bağlandı + paket yenilendi
- **Karar (kullanıcı):** *"boş kalsın"* → ESKİTME → `WSH-DESTROY`,
  YIPRATMA → `WSH-BASIC GRINDING`, `WSH-OPEN GRINDING W/AIR` **boş kalır**.
  Kodda "onay bekliyor" notu yerine alınan karar yazıldı; davranış değişmedi.
  **Commit:** `07855aa`
- **Paket:** `52c9796` + `07855aa` üzerinden temiz derleme ile yeniden çıkarıldı.
  `SentezPlaning-IIS-192.168.3.228-90/` (site 94 dosya, `ornek/appsettings.json`,
  `IIS-KURULUM.txt`) + zip 24,1 MB / 96 girdi. Sır taraması temiz, `site/logs` ve
  `site/appsettings.json` pakete girmiyor. DLL'de yeni semboller doğrulandı
  (`YikamaOzetEsleme`, `OperasyonSureleriKod`, `Yıkama Özet`, `Operasyon Eşleme`,
  `WSH-1ST WET PROCESS`).
- **IIS-KURULUM.txt'e eklendi:** 6 Excel sayfasının ne olduğu ve özet raporda bazı
  satırların neden boş göründüğü (ERP'de StandartTime boş olan operasyonlar,
  şablonda olup ERP'de karşılığı olmayan satırlar, kapasite girişi olmayan haftalar) —
  planlamacı bunu hata sanmasın.

### 6. Dikim: export filtresiz + SMV kart ID'sinden
- **Neden (kullanıcı):** *"dikimde excel'e atınca 3 sayfa geliyor, fashion nondenim basic
  gelmiyor. olması gereken böyle (PLANNN.xlsx)"* ve *"SMV'leri alırken model koduna göre değil
  de order numarasından order item'e gidelim, oradan ilk modeli alalım, o id'ye göre yapalım.
  model numarası sıkıntılı giriyorlar zannımca."*
- **PLANNN.xlsx incelendi:** 10 sayfa (5 CEP, FASHION, FASHION BASIC, NON DENIM, GÖMLEK,
  KATEGORISIZ + 3 kapasite + Özet). **Önemli:** dikim çıkış tarihi BOŞ satırlar da içinde
  (5 CEP'te 210 satırın 166'sı) ve `A9255-1601` de var — yani 2026-10-01'de eklediğim
  "planda olmayanlar çıkmasın" filtresinin kaldırılması gerekiyordu. Kullanıcıya bu sonucu
  söyleyip öyle yapıldı.
- **Ne yapıldı (1 — export):** `ExportExcel()` artık parametre almıyor, ekran filtresi
  uygulanmıyor. Controller ve web çağrısı da parametresiz. Çıktı 10 sayfa, `MODEL` kolonu yerinde.
- **Ne yapıldı (2 — SMV):** `OrderModel` sorgusu order no → `Erp_WorkOrderItem` → **ilk kalem**
  (ItemOrderNo, sonra RecId) ve kalemin `InventoryId`'sini döndürüyor. Yeni `EtutSmvById` sorgusu
  etüdü **ID ile** arıyor; kod metniyle arama yalnızca ID çözülemeyen order'lar için yedek.
  Eskiden order birden fazla model taşıyorsa (`ModelSayisi != 1`) model hiç çözülmüyor, order
  kendi style'ında bırakılıyordu — artık her zaman ilk kalem alınıyor.
  `orders.inventory_id` kolonu eklendi (EnsureColumns ile mevcut DB'ye de).
- **Hata:** `COUNT(DISTINCT ...) OVER (...)` SQL Server'da desteklenmiyor — ilk denemede 500
  döndü. `ModelSayisi` ayrı bir CTE ile toplanacak şekilde düzeltildi.
- **Doğrulama:** 1189 order → **1189'unun kart ID'si çözüldü** (0 eksik; eskiden çok modelli
  order'lar atlanıyordu). SMV recalc 579 kayıt. Kullanıcının tarif ettiği vaka yakalandı:
  order 93974, style `A328-1885` yazılmış, ERP kartı `A328-1885-1535`, artık etütten SMV alıyor.
  Export 10 sayfa / 124 KB. SMV'si olmayan 128 order kaldı — bunların modellerinde ERP'de etüt
  satırı yok (ör. `9519-1359-OPW`), veri eksiği.
- **Commit:** `7e5e614`

### 7. Yıkama liste yüklemesi 415 veriyordu
- **Belirti (kullanıcı):** *"yıkamaya excel yüklerken hata veriyor"* —
  `ÜRETİM PLANI GÜNCEL - 18.09.2026.xlsx`.
- **Teşhis:** `apiClient` örneği varsayılan `Content-Type: application/json` başlığı taşıyor.
  `listeYukle` FormData gönderirken bu başlık kalıyor, sunucu multipart beklediği için
  **415 Unsupported Media Type** dönüyor. Tekrar üretildi: multipart gövdeyi
  `application/json` başlığıyla göndermek → 415.
- **Sebep:** dikim tarafındaki dört import çağrısı başlığı açıkça `multipart/form-data`
  olarak geçiyor; yıkama yüklemesini yazarken bunu atlamışım.
- **Düzeltme:** aynı başlık eklendi. Axios 1.19 FormData için elle verilen Content-Type'ı
  düşürüp boundary'yi tarayıcıya bıraktığı için kalıp güvenli (dikim import'ları bunu
  kanıtlıyor, canlıda çalışıyorlar).
- **Doğrulama:** `multipart/form-data` → 200, okunan 258, süresi yok 1. Boş dosya → 400.
  Bozuk dosya → 400 "Excel okunamadi: File contains corrupted data."
- **Not:** yükleme 12-13 sn sürüyor; `kartiYok` sayısını hesaplamak için üç ağır ERP sorgusu
  koşuyor. Buton "Yükleniyor…" gösteriyor ama uzun gelirse bu adım ertelenebilir.
- **Commit:** `0fc9b00`

### 8. Yeni IIS paketi (commit 0fc9b00)
- **Neden:** elimdeki paket `52c9796`'da kalmıştı; ne dikim export/SMV düzeltmesini
  (`7e5e614`) ne de yıkama yükleme 415 düzeltmesini (`0fc9b00`) içeriyordu.
- **Ne yapıldı:**
  - `web` build + `dotnet publish -c Release`.
  - `publish\logs` altında Ağustos'tan kalma yerel log dosyaları vardı (deploy betiği
    `logs`/`data` klasörlerini koruyor) — paketlemeden önce silindi.
  - `SentezPlaning-IIS-192.168.3.228-90\site` robocopy /MIR ile yenilendi,
    `ornekppsettings.json` güncellendi, `IIS-KURULUM.txt` yeniden yazıldı.
  - **IIS-KURULUM.txt'teki DİKİM bölümü yanlıştı:** "Excel'e aktarım artık ekrandaki
    filtreyi uygular" yazıyordu, oysa `7e5e614` bunu geri aldı (filtresiz, 3 sayfa).
    Düzeltildi; SMV'nin artık kart ID'sinden okunduğu da açıklandı.
- **Komutlar:**
  ```bash
  taskkill /F /IM SentezPlaning.Api.exe     # exe kilidi -> MSB3027
  npm run build                              # web/
  .\Deploy-IIS.ps1 -Configuration Release -SkipWebBuild
  rm -rf publish/logs publish/data
  robocopy publish <paket>\site /MIR
  Compress-Archive site,ornek,IIS-KURULUM.txt -> SentezPlaning-IIS-192.168.3.228-90.zip
  ```
- **Doğrulama (paketin kendisi çalıştırılarak, port 5399):**
  - Açılış OK, `/` → 200 (React), `/api/auth/login` → 200 (SentezLive bağlantısı çalışıyor).
  - `swagger` → 404: Release'de beklenen, Swashbuckle yalnızca Development'ta açık.
  - Yıkama liste yüklemesi → **200**, okunan 258, süresi yok 1, 13,1 sn. Düzeltme pakette.
  - Minify edilmiş bundle içinde `listeYukle` çağrısı
    `{headers:{"Content-Type":"multipart/form-data"}}` ile görünüyor.
  - Pakette `appsettings.Development.json`, `.log`, `data/`, `logs/` YOK; şifre taraması temiz.
  - Zip: 24,1 MB, 125 girdi.
- **Not:** smoke test sırasında `site\data` ve `site\logs` oluşuyor; zip bunlardan ÖNCE
  üretildi, sonra iki klasör de silindi. Sıra bozulursa canlı veri paketle taşınır.
- **Paket gitignore'da**, repoya commit girmedi.

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
