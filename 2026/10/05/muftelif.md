# muftelif — 2026-10-05

## Bağlam

Faz 1b planı 3 Ekim'de yazılmıştı (6.955 satır, 12 görev) ama uygulanmamıştı.
Bugün planın tamamı **native** yöntemle, bu oturumda görev görev uygulandı.
Başlangıç: 159 test. Bitiş: **400 test**, hepsi yeşil, 10 commit `main`'e push edildi.

Yürütme defteri: `.superpowers/sdd/2026-10-03-sentezselvedge-faz1b-kk-olcum/progress.md`

## Yapılanlar

### 1. Şema — 6 tablo (Task 1)

- **Neden:** KK raporu ve ölçüm kayıtları için tablo yoktu.
- **Ne yapıldı:** `db/0004_kk.sql` (QaReport, QaDefect, QaSample, QaMeasurement) ve
  `db/0005_olcum.sql` (Measure, MeasureItem + `Olcum.CiftOlcuPomListesi` ayar tohumu)
  plandan çıkarıldı, `SemaBeklenen.cs`'e 6 tablo eklendi (14 → 20).
- **Komutlar:**
  ```bash
  ConnectionStrings__Sentez="..." dotnet run --project SentezSelvedge.Db.csproj -- ../db
  sqlcmd ... -Q "SELECT COUNT(*) FROM sys.tables WHERE name LIKE 'UZM[_]Selvedge[_]%'"
  ```
- **Sonuç:** `5 script uygulandi.` → ikinci koşuda `Degisiklik yok, sema guncel.` → **20 tablo**.
- **İki düzeltme:**
  - `0005_olcum.sql` AppSetting tohumunu `[Description]` kolonuna yazıyordu; gerçek kolon
    **`Aciklama`** (`0001_iskelet.sql:36`). Plan metni yanlıştı.
  - `SemaDogrulayiciTests`'teki üç Faz 1a testi `14` sayısına bağlıydı ve
    `Fazla_tablo_sorun_degil` "fazla tablo" olarak **QaReport** kullanıyordu — o artık
    zorunlu. 14 → 20 ve örnek tablo adı değiştirildi.
- **Yetki:** `9001_yetki.sql`'in GRANT imleci `sys.tables ... LIKE 'UZM[_]Selvedge[_]%'`
  deseniyle çalıştığı için altı yeni tabloyu kendiliğinden kapsıyor; desen canlıda
  sorgulandı, altısı da seçildi. Script **değişmedi**. Not: `uzm_selvedge_app`
  kullanıcısı bu geliştirme veritabanında **yok** (sunucu kurulumunda açılıyor).
- **Commit:** `18e1f9f`

### 2. Saf iş kuralları (Task 2–5)

| Sınıf | Ne | Test |
|---|---|---|
| `DhuHesap` | DHU %, kusurlu %, adetler | 15 |
| `AqlPlan` | lot → numune adedi + DANIŞMA AMAÇLI kabul/ret | ~25 |
| `RaporNo` | `KK-202610-0007` | ~12 |
| `OlcumSpecExcel` | POM Excel düzeni + ×2 listesi | 27 |

**Üç düzeltme:**

- **`AqlPlan` testi yanlıştı.** `NumuneAdedi(3) = 3` bekliyordu. Z1.4'ün en küçük satırı
  2 numune ister ve üretimden taşınan `Math.min(numune, lot)` kırpması **aşağı** çalışır,
  tabloyu büyütmez. 1→1, 2→2, 3→**2**, 8→2 olarak düzeltildi.
- **`RaporNo` `KodNormalize`'a fazla güveniyordu.** Plan "Consumes: KodNormalize.Uygula"
  diyordu ama o yalnızca `Trim` + Türkçe `ToUpper` yapıyor; testler ASCII'ye inmeyi ve
  alfanumerik dışını atmayı istiyordu (`"levi's deri"`, `"Ölçüm"` → `OLCUM-`).
  `RaporNo`'ya kendi `OnekTemizle`'si yazıldı. **`KodNormalize` DEĞİŞTİRİLMEDİ** —
  `Firm.Code` gibi alanlarda `Ö` korunmak zorunda.
- **Task 2'de test ve uygulamayı aynı adımda yazdım**, RED'i izlemedim. Düzeltme olarak
  `DhuHesap.cs` kaldırılıp takım koşturuldu → 3 derleme hatası, yani 15 test gerçekten
  uygulamaya bağlı. Task 3'ten itibaren test-ilk sırası uygulandı.
- **Commit'ler:** `fcabe26`, `5ebdb32`, `8273ec7`

### 3. Sentez'den varyant ve POM eki okuma (Task 6)

- **Ne yapıldı:** `SentezSql.VaryantAra` / `EkListe` / `EkIcerik`, `VaryantSatiri` /
  `EkOzet`, üç reader metodu, iki controller ucu.
- **Canlı doğrulama token'sız yapıldı** (UZM şifresi elimde yok; test edilen şey zaten
  SQL sabitlerinin kendisi):
  ```
  VaryantAra, iş emri 121228 (95449):
    8 satır, IND/INDIGO, beden 23..30, miktar 84/172/212/304/218/124/92/94
    → planın beklediğiyle BİREBİR. Review Focus #4: ItemCode (metin) okunuyor, RecId değil.
  EkListe, iş emri 120956 (95238):
    45124 "Yikama Öncesi" + 45123 (tip NULL), ikisi de xlsx, SizeBytes dolu, blob YOK.
  ```
- **YENİ BULGU:** aynı iş emrinde **üçüncü** bir ek var — RecId 44812, **10.481.916 bayt
  PDF**. Plan "en büyük örnek 688 KB" diyordu, yanlış. `EkIcerikAsync`'in boyut sınırı
  yok; kullanıcı listeden PDF'i seçerse 10 MB çekilip sonra reddedilirdi — doğru sonuç,
  israflı yol. Task 9'da uzantı ön-kontrolü eklendi.
- **Bir test düzeltmesi:** `Ek_listesi_blob_ICERMEZ` testinin regex'i WHERE'deki
  `a.Attachment IS NOT NULL` guard'ını yanlışlıkla yakalıyordu. Kontrol
  `SELECT ... FROM` arasındaki metne daraltıldı.
- **Commit:** `d1a3a98`

### 4. KK rapor başlığı (Task 7)

- **Ne yapıldı:** `KkModeller`, `KkStore` (numara üretimi + 2601/2627'de yeniden deneme +
  iyimser kilit + `AuditLog`), `KkController`, Program.cs kaydı.
- **Review Focus #3 CANLIDA DOĞRULANDI** — sorgunun kendisiyle:
  ```
  acildi      | RecId 1 | KK-202610-0001
  dogru surum | 1 satir etkilendi
  bayat surum | 0 satir etkilendi      <-- 409'un dayanagi
  son durum   | FinalDecision = Gecti  <-- bayat istek karari DEGISTIRMEDI
  ```
- Aynı `ReportNo`'yu tekrar INSERT etmek **hata 2601** veriyor → `EkleAsync`'in yeniden
  deneme yolu gerçek bir hata koduna bağlı.
- **Bir test düzeltmesi:** `Sorgular_silinmis_kayitlari_disarida_birakir` `EkleSorgusu`'nu
  da `IsDeleted` istiyordu; INSERT'in dışarıda bırakacağı satır yok.
- **Commit:** `208f107`

### 5. KK detay satırları (Task 8)

- **Ne yapıldı:** hata/numune/ölçüm upsert'leri + türetilen alanların **aynı
  transaction** içinde yeniden hesabı.
- **Canlı doğrulama:** üç detay tablosuna insert çalıştı (`[Count]`, `[Result]`,
  `[Description]` köşeli parantezli kolonlar dahil), `TuretilenGuncelleSorgusu` 1 satır
  etkiledi, `DhuPercent=14.00`, `UnitsSampled=50`, `TotalOrderQty=304` yazıldı.
- **`Aql = 2.50` kayıpsız saklandı** — plan aşamasında `INT`'ten `DECIMAL(4,2)`'ye
  çevirdiğim kolon **gerekliydi**; `INT` olsa AQL 1.5 ve 2.5 hiç girilemezdi.
- **İki düzeltme:** üç taban DTO plan metninde `sealed` yazılmıştı ama `*Oku` tipleri
  onlardan türüyor (CS0509); `KkController`'a `using ...Sentez;` eklendi.
- **Commit:** `729c758`

### 6. Ölçüm (Task 9) — buradaki bulgu turun en önemlisi

- **Ne yapıldı:** `AyarServisi` (AppSetting + 5 dk önbellek, eksik anahtarı **bir kez**
  loglar), `OlcumModeller` (`SapmaHesap`, `OlcumDurumu`, doğrulama), `OlcumStore`
  (ekten aç, satırları dondur, ×2 sunucuda), `OlcumController`.

#### 6.1 Uzantı ön-kontrolü

`OlcumDogrulama.HesapTablosuMu(dosyaAdi)` eklendi; `AcAsync` ek'i **indirmeden** önce
`.xlsx/.xlsm/.xls` bakıyor. 10 MB'lık PDF'i çekip sonra reddetmek boşa taşıma.

#### 6.2 PLANIN ÖLÇÜMÜ YANLIŞTI — gerçek dosya incelendi

Plan şöyle diyordu: *"45123'te bedenler 6–18. kolonlarda, 19–20 boş, sonra 21–33'te aynı
bedenler tekrar — ikinci blok YANDA."*

Ek diske çıkarılıp `openpyxl` ile incelendi. **İkinci blok yanda değil, ALTTA:**

```
satir  3   "BEFORE AND AFTER"
satir 10   basliklar + bedenler (kolon 6..18, 13 beden: 22..34)
satir 11-39  1. BLOK — yikama ONCESI     (WB HEIGHT = 1.665)
satir 40   AYIRICI: POM kodu bos, kolon 1'de "Graded Measurements"
satir 41   IKINCI baslik satiri, kolon 2'de "P O M "
satir 42-69  2. BLOK — yikama SONRASI    (WB HEIGHT = 1.5)
```

`SatirlariOku` boş POM satırını **atlayıp devam ediyordu**. Sonuç: 29 POM yerine 58
okunuyordu — her POM iki kez, ikinci kopya **yıkama sonrası** spec'iyle; üstüne ikinci
başlık satırı da `"P O M "` adlı bir POM sayılıyordu.

**Ölçülen zarar:**

| Ek | Önce | Sonra |
|---|---|---|
| 45124 (tek blok) | 377 satır | 377 satır |
| 45123 (iki blok) | **754 satır** | **377 satır** |

**Düzeltme:** kural keskinleştirildi — POM kodu boş **VE** beden hücreleri de boşsa blok
**biter**; beden değeri varsa yalnızca o satır atlanır. Bu ikinci koşul şart: eski
`POM_kodu_bos_satir_ATLANIR_hata_vermez` testi, etiketi eksik ama verisi olan bir satırın
atlanıp devam edilmesini istiyor ve ikisi birlikte tutuyor.

Planın yanlış ölçümüne dayanan test adı `Bedenler_yanda_tekrar_ederse_IKINCI_BLOK_okunmaz`
olarak daraltıldı (yandaki durum da gerçek bir koruma, beden taraması onu kesiyor), gerçek
düzen için yeni test yazıldı: **RED → GREEN**.

- **Geçici test:** `GeciciPomOkumaTests.cs` canlı DB'ye bağlanıp blob'u parser'a veriyordu;
  ölçüm alındıktan sonra **silindi** — takımda canlı veritabanına bağlanan test bırakılmaz.
- **Commit:** `91deb6d`

### 7. Web ekranları (Task 10–11)

- `api/kk.ts`, `KkListePage`, `KkRaporPage` (524 satır), `api/olcum.ts`,
  `OlcumListePage`, `OlcumDoldurPage`; `App.tsx`'e 5 yol, menüye 2 bağlantı.
- Ölçüm ekranı bir form değil **kuyruk**: `Enter` ve `Tab` aynı işi yapıyor (ölçü aletinin
  HID klavyesi `Tab` gönderiyor), `Shift+Tab` geri. Kaydedilmemiş değer varken sayfadan
  ayrılma uyarılıyor.
- **Doğrulama:** `npm run build` → `tsc -b` **temiz**. Yani altı dosya gerçek API
  DTO'larıyla tip düzeyinde uyuşuyor. Tarayıcıda elle denenemedi (token yok).
- **Commit:** `30dfc85`

### 8. AQL kaynak doğrulaması + paket (Task 12)

- **Müşterinin AQL sayfası ARANDI, BULUNAMADI:** depoda `*aql*` / `*2859*` / `*z1.4*`;
  ERP'de `Erp_WorkOrderAttachment` içinde `FileName LIKE '%AQL%'` → yalnızca 82859 numaralı
  iş emrinin ölçü dosyaları çıktı.
- **Numune adedi DOĞRULANDI:** çalışan **iki** üretim kaynağı aynı 14 satırlık tabloyu ve
  `Math.min(numune, lot)` kırpmasını kullanıyor —
  `Selvedge.Application/QaReports/QaReportService.AqlSampleSize` ve
  `Selvedge.Web/src/utils/aql.ts`. Task 3'teki test düzeltmem bu kaynaklarla uyuşuyor.
- **`KabulRet` DOĞRULANMADI:** ikisinde de yok. Test yayınlanmış ISO 2859-1 / Z1.4 Tablo
  II-A değerleriyle yazıldı, kaynak testin özetinde ve kurulum dokümanının 10. bölümünde
  açıkça yazıyor. Arayüzde "danışma amaçlı", `FinalDecision` insan alanı.
- **Commit:** `7130c34`

#### 8.1 Paket — bir hata ve toparlaması

`Deploy-IIS.ps1`'i `-OutputDir <paket kökü>` ile koşturdum. Publish paket köküne **düz
açıldı** ve `IIS-KURULUM.txt` + `sema\` + `ornek\` **silindi**. Klasör `.gitignore`'lu
olduğu için git'ten geri alınamadı.

Toparlama: 3 Ekim'deki zip'ten `site\` dışındaki 64 parça geri çıkarıldı, yeni publish
`site\` altına taşındı, şema aracı yeniden publish edildi, `0004`/`0005` kopyalandı.

**Ders:** bu betikte `-OutputDir` **publish hedefidir**, paket kökü değil. Doğrusu
`-OutputDir ...\site`.

#### 8.2 Paket kontrolleri

```
sifre yok · appsettings.Development.json yok · log yok
sema/db 5 script · sema/elle 9001_yetki.sql
site\ API dll + web.config + wwwroot/index.html var
yeni ekran metinleri bundle'da
zip: 11.9 MB / 142 parca
```

`IIS-KURULUM.txt` güncellendi: bölüm 2 (3→5 script, 14→20 tablo), bölüm 7'ye üç yeni
doğrulama adımı (KK, Ölçüm, ayar tohumu), bölüm 10 yeniden yazıldı.

## Kararlar

- **Token'lı uçlar yerine sorguların kendisi ölçüldü.** UZM kullanıcısının şifresi elimde
  olmadığı için Task 6/7/8'in canlı adımları HTTP yerine `sqlcmd` ile koşturuldu. Test
  edilen şey SQL sabitleri olduğu için kanıt değeri aynı; eksik kalan taraf HTTP katmanı
  (yetki, JSON eşlemesi, 409'a çevirme) ve tarayıcı davranışı.
- **Ölçüm satırı yazıldığı an donar.** Spec ve tolerans satıra kopyalanır, FK ile
  bağlanmaz. `SatirGuncelleSorgusu` `SpecValue`/`Tolerance`/`PomCode`/`SizeCode`/`SortOrder`
  kolonlarına hiç dokunmuyor ve bir test bunu metin düzeyinde kanıtlıyor.
- **×2 kuralı sunucuda uygulanır, arayüzde değil.** Mobil uygulama da aynı API'yi
  kullanacak; kuralın iki yerde yaşaması iki farklı sonuç demek.
- **"Atlandı" ile "sıfır ölçüldü" ayrı.** mezura'da atlanan nokta `0` yazıyordu; o `0`
  raporda "ölçüldü ve 0 çıktı" diye okunur.
- **BEFORE AND AFTER dosyalarında yalnızca ilk blok okunur.** Yıkama sonrası spec'e şu an
  erişilmiyor; operatör **eki** seçiyor ve tek bloklu "y.ö." dosyası ayrıca var.

## İnceleme turu ve düzeltme pası (akşam)

Taze gözle tüm dal incelemesi bitti: **2 kritik, 7 önemli, 5 küçük** bulgu ve beş
"yargıya varmadım" kalemi. Yeniden derecelendirme (etkiye göre, spec'in sessizliğine
göre değil) sonrası dokuz bulgu tek düzeltme turuna alındı; küçükler ertelendi.

### Kapatılan bulgular — her biri önce KIRMIZI görülen testle

| # | Bulgu | Düzeltme | Test |
|---|-------|----------|------|
| C1 | `kk.ts` aşama/karar sabitleri sunucunun kabul ettiği değerlerden kaymış: iki dropdown değeri **kaydedilemiyordu** | sabitler sunucuyla hizalandı | `ArayuzSozlukTests` (yeni, TS dosyalarını okuyan 4 test) |
| C2 | `TuretilenGuncelleSorgusu` ikinci kaydetmede **yanlış DHU** yayınlıyordu | sorgu düzeltildi | `KkSqlTests` +2 |
| I1 | ölçüm `Difference`/`Status` sunucuda **hiç hesaplanmıyordu** | `KkOlcumHesap.cs` (saf) | `KkOlcumHesapTests` 14 |
| I2 | rapor numarası öneki Türkçe harf taşıyınca numara bozuluyordu | `RaporNo.AyOneki` + `OnekTemizle` | `RaporNoTests` +3 |
| I3 | `OlcumDoldurPage` ×2 satırında **kayıtlı** değeri ham değer gibi gösteriyordu; yeniden kaydetmede değer ikiye katlanıyordu | ham/kayıtlı ayrıldı, "Kayıtlı" kolonu eklendi | `tsc -b` temiz |
| I4 | ikinci ölçüm bloğunun başlığı POM satırı sayılıyordu | pozitif blok sınırı (`TekrarlananBaslikMi`) | `OlcumSpecExcelTests` +2, gerçek ekler 377 satır |
| I5 | **bozuk ×2 listesi** (virgül yerine noktalı virgül) sessizce yarım ölçüm üretiyordu | `CiftOlcuDenetim.EslesmeYok` + `OlcumStore` uyarı logu | `CiftOlcuDenetimTests` 6 |
| I6 | Z1.4 tablosu **her varyant satırına** uygulanıyordu: 100/200/300'lük üç renkte 114 parça önerilirken lot planı 80'di | `AqlPlan.NumuneDagit` — lot planı satırlara orantılı dağıtılıyor, artan en büyük kesirli paya | `AqlPlanTests` +6 |
| I7 | `KabulRet` ok çözümü lottan **büyük** numune adedi döndürüp ekranda plan gibi gösteriliyordu (3 adetlik lotta "8 parça çek") | `AqlPlan.TumMuayeneMi` + `KkOzet.TumMuayene` + banner "%100 muayene" | `AqlPlanTests` +4, `ArayuzSozlukTests` +1 |

- **Neden `ArayuzSozlukTests`:** C1'i `tsc -b` göremez — string literal kaymasıdır.
  C# tarafından TS dosyasını okuyup sunucu sabitleriyle karşılaştıran bir sürüklenme
  nöbetçisi, bu sınıfı bir daha sessiz bırakmıyor.
- **Testler:** 400 → **442**, tamamı geçer. Web: `tsc -b` temiz, vite 441.67 kB.
- **Commit:** `b733ef3` — fix(sentez-selvedge): inceleme turunun dokuz bulgusu kapatildi

### Ertelenen küçükler (M1–M5)

- M1 `OlcumStore.SatirVarMiSorgusu` ölü dal (`mevcut` her zaman 0); yorumun iddia ettiği
  yarışı engellemiyor.
- M2 `SatirKaydetAsync`'te iyimser kilit yok; iki ölçümcü satır satır birbirini eziyor.
- M3 `ozet.SizeBytes` okunup kullanılmıyor; 60 MB'lık `.xlsm` hâlâ belleğe çekiliyor.
- M4 KK detay UPDATE'leri `RecId+ReportId` ile eşleşip `IsDeleted` filtresi taşımıyor;
  başka rapora ait `RecId` hata yerine INSERT'e düşüyor.
- M5 `OlcumSpecExcel` `Sira` iki numara kaynağını karıştırıyor (sonuç yanlış değil, tuhaf).

### Paket yenilendi

`site\` eski kodu taşıyordu; API yeniden publish edildi, **eski bundle dosyaları
silindi** (publish temizlemiyor, üst üste yığıyor), zip yeniden kuruldu.

- Kontroller: şifre yok, `appsettings.Development.json` yok, log yok, `sema/db` 5 script,
  `sema/elle/9001_yetki.sql`, `ornek/appsettings.json`, `site` API dll + web.config +
  wwwroot/index.html.
- **Zip:** 12.5 MB / 126 dosya (önceki 142'de eski bundle kopyaları vardı).

## SentezPlaning yıkama — tasarım (akşam, ikinci tur)

Kullanıcı önceliği düzeltti: **mobil değil, planlama.** ("mobil uygulama degil bizim
planlamaya olacak.") Kalıcı nota yazıldı.

### Ölçülen zemin

- SentezPlaning verisi **yerel SQLite**'ta (`PlaningDb`, `EnsureSchema`+`EnsureColumns`).
  Yeni tablolar buraya girer; SentezLive salt okunur kalır.
- Mevcut `smv` tablosu **style bazlı** — operasyon kırılımı yok.
- Yıkama yükü ERP rotasından (`PlanningService:616-625`, `op.Dakika`, ıslak işlemde
  kazan doluluğuna bölme). Kapasite 7 bölümde (`WeeklyCapacityInput`).
- Girdi Excel'i **zaten ayrıştırılıyor** (`YikamaListeImport`) — yeni ayrıştırıcı yok.

### Çıktı şablonunun ölçümü — iki önemli bulgu

1. **Pivotlar kendi Data sayfasını okumuyor.** Beş pivot önbelleğinin kaynağı harici
   `C:\Dosyalar\Yeni Sip List.xlsm` → `sip list` sayfası (`A13:CF202` vb.). Dosyada
   görünen pivot değerleri son yenilemeden kalan önbellek anlık görüntüsü. Yani
   "Data'yı doldurursak pivotlar dolar" **yanlış**; pivot sayfaları değer olarak
   üretilecek. (`.xlsm` ama vbaProject **yok** — makro taşımıyor.)
2. **Şablonun 21 `WSH-` kolonu `YikamaOzetEsleme.Satirlar` ile birebir örtüşüyor**
   (normalize karşılaştırma, iki yönde de fark yok). Operasyon kataloğu tahminle değil
   **şablondan tohumlanabilir**. Kolonlar: R,S,U,W,Z,AC,AE,AF,AH,AJ,AL,AN,AP,AR,AT,AU,
   AV,AW,AX,AY,AZ.

**Önceki yanlış notu düzelttim:** 12 pivotTable / 15 pivotCache / 4 externalLink /
"üç pivot sayfası" diye not edilmişti. Doğrusu **6 / 5 / 2 / iki sayfa**
(New Product 4 pivot, Orders 2 pivot). Plan bu sayılara dayanmayacak.

Ayrıca şablonun `Weekly Capacity!satır 4` başlıkları istenen dört parametrenin aynısı:
`Average SMV`, `# of Employees (shift/Std)`, `# Available Weekly Capacity(Hours)`,
**`Capacity Units/Hours`** (= birim esası). Şablon operasyon başına bu dördünü zaten
tutuyor; tasarımın `operasyon_param` tablosu onun veritabanı karşılığı.

### Seçilen yaklaşım

**Operasyon kataloğu kaynak, bölüm türetilmiş.** Üç yeni SQLite tablosu: `operasyon`
(katalog), `operasyon_param` (operasyon×hafta, dört parametre), `operasyon_smv`
(operasyon×style×yıkama). `weekly_capacity` silinmez, türetilmiş olur — bir bölümde hiç
operasyon paramı yoksa davranış **bugünküyle birebir aynı** kalır.

- **Neden:** aynı ekranın iki farklı rakam göstermesi bu depoda bir kez pahalıya geldi —
  Faz 1b'nin I6 bulgusu tam buydu (satır başına 114 parça, lot planı 80). Tek kaynak
  kuralı o sınıf hatayı imkânsız kılar.
- **Ekran:** `/haftalik-kapasite` iki sekme; hafta seçimi ortak. Operasyon paramı girilen
  bölümlerde bölüm alanları salt okunur + "operasyondan türetildi".
- **SMV önceliği:** elle > rota; hangisi kullanıldı özet raporda satır başına yazılır
  (I5 dersi: sessizce uygulanmayan kural görünür olmalı).

### İki açık noktayı varsayılan olarak kararlaştırdım

Kullanıcı iki turdur cevap vermedi; mimariyi değiştirmeyen, geri alınabilir seçimler
olduğu için karara bağladım ve spec'e gerekçesiyle yazdım:

- **Göç:** bölüm değeri operasyonlara eşit bölünür, her satır `kaynak='goc'` işaretlenir.
  *Neden:* sıfırdan giriş o haftanın kapasitesini aniden sıfıra düşürür. Bölüm **toplamı**
  doğru kaldığı için ara toplamlar etkilenmez; yanlış olan yalnızca kırılım, ilk
  düzenlemede düzelir.
- **Bölüm alanları salt okunur.** İki kaynak çelişkisini önlemek için.

- **Dokunulan dosyalar:** `docs/superpowers/specs/2026-10-05-sentezplaning-yikama-operasyon-design.md` (324 satır)
- **Commit:** `98ed34f` — docs(sentez-planing): yikama operasyon parametreleri tasarimi
- **Sonraki adım:** kullanıcı spec'i onaylayınca uygulama planı. **Uygulama kodu plan
  onayına kadar başlamadı.** B kısmının planından önce New Product + Orders sayfalarının
  satır/sütun düzeni ölçülmeli (Faz 1b'de ölçülmemiş Excel varsayımı yanlış çıkmıştı).

## Açık kalanlar / sonraki adım

- **Taze gözle tüm dal incelemesi arkada koşuyor** — bulguları gelince Critical/Important
  olanlar tek bir düzeltme turunda, her biri RED→GREEN testle kapatılacak.
- **GÜVENLİK DUVARI HÂLÂ KAPALI** — 3 Ekim'de doğrulama için kapatıldı, geri açılmalı.
- **UZM kullanıcısının şifresi** gerekiyor: HTTP katmanının (yetki, 409, izleyici rolünde
  düğmelerin gizlenmesi) ve tarayıcı akışının elle doğrulanması bunu bekliyor.
- **AQL kabul/ret tablosu** ilk canlı denetimde denetçiyle birlikte bir partide teyit
  edilmeli.
- **Yıkama sonrası spec** (45123'ün ikinci bloğu) şu an okunmuyor; gerekiyorsa ayrı iş.
- **Canlı test verisi** — kullanıcı kararı bekliyor: Firm 1, Survey 2, SurveyResponse 4,
  QaReport 1, QaDefect 2, QaSample 1, QaMeasurement 1, Measure 0, MeasureItem 0,
  Attachment 3, AuditLog 4. (`UZM_Selvedge_AppSetting` tohum veridir, silinmez.)
- **Sıradaki iş:** MAUI Android mobil uygulaması — kendi brainstorm → spec → plan turunu
  alacak. API-only (cihazdan doğrudan SQL yok), çevrimdışı yok, ölçü aleti Bluetooth HID
  klavye olarak.
- **Ayrı bir iş kuyruğa girdi:** SentezPlaning yıkama ekranı — parametreleri ayrı sekmeye
  almak + operasyon bazlı parametre değerleri + Excel giriş/çıkış hattı. Mevcut kod ve iki
  Excel dosyası analiz edildi, dört tasarım sorusu cevaplandı; tasarım sunumu bekliyor.
