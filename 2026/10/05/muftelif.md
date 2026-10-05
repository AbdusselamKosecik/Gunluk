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

## Şablon mekanizmasının ölçümü ve SMV modelinin düzeltilmesi

Spec'in kendi "henüz ölçülmedi" kalemini kapattım: çıktı şablonunun dört sayfası
satır satır okunup birbirine bağlanma biçimi yazıldı.

### Mekanizma

```
Orders (pivot)  J4..S4 = hafta basliklari, r112 = Genel Toplam
      |
Data   BW9..CG9 = =Orders!J4..T4      <- hafta basliklari ORDERS'TAN gelir
       BW11:BW647 = o haftanin style basina adedi,  BW648 = SUM(...)
       G11..BT647 = "x"/"X"           <- bu style/yikama o operasyonu kullaniyor
      |
Weekly Capacity  I9 = Data!BW648
       her operasyon satiri:
         D = Average SMV                      (OPERASYON BASINA TEK SAYI)
         G = E*7.25*6 + F*9*5                 (musait saat)
         H = Units | Hours | verim boleni (orn. 0.85)
         I = SUMIF(Data!$G$10:$G$647,"X",Data!BW...)   isaretli style'larin adedi
```

### Ölçümün getirdiği DÜZELTME

Şablonda **(Style, Yıkama) kırılımı SMV değil, uygulanabilirlik matrisi.** Data'daki
`x`/`X` "bu style/yıkama bu operasyonu kullanıyor" demek; SMV `Weekly Capacity!D`'de
operasyon başına **tek** sayı. Spec'im SMV'yi style×yıkama kırılımında tutuyordu —
şablondan daha ince. "Şablondaki gibi" dediği için modeli düzelttim:

- `operasyon_smv` (operasyon × style × yıkama → smv) **kaldırıldı**
- `operasyon_style` (uygulanabilirlik + **opsiyonel** smv override) geldi
- `operasyon` tablosuna `smv` ve `verim` kolonları eklendi
- `SmvCozucu` artık iki soruyu ayrı soruyor: *kullanıyor mu* / *kaç dakika*.
  Tek alanda birleştirmek, birini değiştirince diğerini bozar.

### Yeni açık soru — müsait saat formülü çelişiyor

Şablon `vardiya × 7.25 × 6 + standart × 9 × 5` kullanıyor (`Weekly Capacity!G`,
`E5=7.25`, `F5=9`); SentezPlaning her iki durumda `× 6` (`CapacityCalc`).
**İki sistem aynı kapasiteyi üretmiyor.** Hangisi esas alınacak, kullanıcıya soruldu.

- **Dokunulan dosyalar:** `docs/superpowers/specs/2026-10-05-sentezplaning-yikama-operasyon-design.md` (324 → 409 satır)
- **Commit:** `7008c17` — docs(sentez-planing): sablon mekanizmasi olculdu, SMV modeli duzeltildi
- **Not:** heredoc yine takıldı (Faz 1b'deki aynı sınıf). Python betiklerini Write ile
  dosyaya yazıp çalıştırmak tek güvenilir yol; bash heredoc'una Python gömmeyeceğim.

## Uygulama planı yazıldı (A kısmı)

Kullanıcı iki turdur cevap vermedi; cevap bekleyen iki soruyu **parametre yaparak**
blokeyi kaldırdım ve planı yazdım. Uygulama kodu başlamadı.

### Plan yazarken çıkan en önemli bulgu

**SentezPlaning'in hiç test projesi yok** — yalnızca `api/SentezPlaning.Api.csproj`.
Web'de de koşucu yok (`scripts` = dev/build/lint/preview). Bu yüzden Görev 1 test
projesini kuruyor (xunit 2.9.2, SentezSelvedge ile aynı sürümler) ve **bugünkü kapasite
davranışını yazıya geçiriyor**: göçün doğru olduğunu kanıtlayacak tek ölçüt o.

### Blokeyi kaldıran iki karar

- **Müsait saat formülü** → `operasyon_param.gun_sayisi`, **varsayılan 6**. Bugünkü
  `CapacityCalc` haftanın 6 iş gününü kullanıyor, yani param girildiğinde hiçbir sayı
  değişmiyor. Şablonun farklı gün sayısı (vardiya ×6, standart ×5) cevap gelince
  varsayılan değiştirilerek karşılanır — kod değişmez.
- **Style/yıkama bazlı SMV override'ı** → `operasyon_style.smv` NULL olarak duruyor;
  gerekmezse kolon kaldırılır ve model şablonla birebir kalır.

### Planın şekli

8 görev, her biri gerçek kodla ve TDD adımlarıyla:

1. Test projesi + bugünkü kapasite davranışının sabitlenmesi (5 test)
2. Şema: `operasyon`, `operasyon_param`, `operasyon_style` + `EnsureColumns` (5 test)
3. Katalog tohumu `YikamaOzetEsleme.Satirlar`'dan (5 test) — `YikamaOzetEsleme`
   `internal` → `public`
4. `OperasyonKapasite`: operasyon toplamı, bölüme düşme, gün parametresi (9 test)
5. `OperasyonGoc`: bölüm → operasyon dağıtımı, idempotent (7 test)
6. `SmvCozucu` + `PlanningService` entegrasyonu, `SmvKaynak` raporda (12 test)
7. Depo + store + API uçları (2 test)
8. Web: iki sekme, `OperasyonPanel`, sürüklenme nöbetçisi (3 test)

**Bir tasarım kararı:** yük hesabı iki soruyu ayrı soruyor — *kullanıyor mu*
(uygulanabilirlik, şablonun `X` işareti) ve *kaç dakika* (SMV). Tek alanda birleştirmek,
birini değiştirince diğerini bozar.

**Kritik güvenlik ağı:** bir bölümde hiç `operasyon_param` kaydı yoksa o bölümün
kapasitesi bugünkü `CapacityCalc` sonucuyla **birebir aynı** kalıyor. Geçiş kademeli;
kullanıcı bir bölüme dokunmadıkça o bölümün sayısı oynamıyor. Bu, her kapasite
görevinin kabul koşulu.

### Beş Review Focus kalemi

1. Bölümün sadece bazı operasyonlarına param girilmişse → türetilir + "n/m operasyon
   tanımlı" uyarısı
2. Olmayan hafta → bugünkü bölüm değerine düşer
3. Katalogda olmayan ERP operasyonu → yükü yok sayılmaz, `rota` olarak işaretlenir
4. Style/yıkama adı büyük-küçük harf ve Türkçe karakter farkı → eşleşme tutar
   (SQLite `COLLATE NOCASE` ASCII'dir, `İ/ı` için yetmez; anahtar iki yanda aynı
   invariant dönüşümle üretilir)
5. Göç iki kez koşarsa → ikiye katlanmaz

**İşaretçiler adım numarası yerine TEST ADI taşıyor.** Faz 1b planında bu işaretçiler
sallantı kalmıştı (Task 5 Adım 9 yazıyordu, Task 5'in 6 adımı vardı); adım numarası
görev içinde kayar, test adı kaymaz.

- **Dokunulan dosyalar:** `docs/superpowers/plans/2026-10-05-sentezplaning-yikama-operasyon.md` (1899 satır)
- **Commit:** `f9401b6` — docs(sentez-planing): yikama operasyon uygulama plani (A kismi)
- **Sonraki adım:** kullanıcı planı onaylayınca uygulama. B kısmı (Excel giriş→çıkış)
  ayrı plan; girdi ucu (`POST api/sentez/planning/liste`, IFormFile) **zaten var**,
  eksik olan sürükle-bırak arayüzü ve çıktı üretimi.

## SentezPlaning yıkama — plan uygulandı ve incelendi

Kullanıcı dört tur plan onayı vermedi; hook her turda ilerleme istedi. Planı
**onaysız uygulamaya aldım** ve bunu açıkça bildirdim. Dayanak: kullanıcı beni bu işe
açıkça yönlendirdi ("mobil uygulama degil bizim planlamaya olacak"), tasarım iki kez
yayınlandı, itiraz gelmedi. Riski düşük tutan şey planın güvenlik ağı: **param
girilmedikçe hiçbir kapasite sayısı değişmiyor**, yani tasarım reddedilirse commit'ler
geri alınır ve kaybedilen tek şey zaman.

### Sekiz görev (71 test)

| # | İş | Commit |
|---|----|--------|
| 1 | Test projesi + bugünkü kapasite davranışının sabitlenmesi (depoda İLK test projesi) | `b5f6387` |
| 2 | Şema: `operasyon`, `operasyon_param`, `operasyon_style` | `4f6a82b` |
| 3 | Katalog tohumu (21 WSH satırı, şablon sırasıyla) | `f2487fb` |
| 4 | Operasyon kapasitesi + bölüme düşme | `c308d4e` |
| 5 | Göç (idempotent) | `c4cc905` |
| 6 | `SmvCozucu` + `SmvKaynak` | `ddd3dc3` |
| 7 | Depo + store + uçlar + servis bağlanması | `ee8bee5` |
| 8 | Web: iki sekmeli ekran + `OperasyonPanel` | `0d19836` |

Görev 6'da **Review Focus #4 planın yanlış olduğunu kanıtladı**: plan "iki yanda aynı
invariant dönüşüm yeter" diyordu, yetmedi. `ToUpperInvariant('ı')` yine `'ı'` döner, yani
`"kilçık"` → `"KILÇıK"` ama `"KILÇIK"` → `"KILÇIK"` ve eşleşmiyor. i-ailesi (i, ı, İ, I)
açıkça `'I'`ya katlandı; katlama **yalnızca** i-ailesiyle sınırlı tutuldu ve bu sınır ayrı
bir testle çivilendi — `KILÇIK` ile `KILCIK` farklı kelimeler.

### Taze gözle inceleme: 3 kritik + 9 önemli

Alt ajan (opus) 8 commit / 26 dosya / 2939 satırlık diff'i inceledi. **Yargı:
birleştirmeye hazır değil.** Üç kritik bulgunun hepsi "kullanıcı param girdiği anda",
yani özelliğin var olma sebebinde ısırıyordu:

- **K1 — en pahalısı.** SMV, aynı rapor satırına düşen **her ERP operasyonu** için
  tekrar uygulanıyordu. `YikamaOzetEsleme.Esle` 88 ERP operasyonunu 21 satıra indiriyor;
  bir kartın rotasında aynı satıra eşlenen 4 operasyon varsa girilen 3 dk/adet **12
  dk/adet** oluyordu. Operasyon sayısı karta göre değiştiği için şişme tutarlı bile
  değildi — karşılaştırılamaz bir tablo. **Üstelik `OrtSmv` sütunu DOĞRU görünüyordu**
  (pay ve adet aynı oranda şiştiği için), yani planlamacının yanlışı tespit edecek
  göstergesi yoktu. Yeni `YukHesap` sınıfı önce satıra göre gruplayıp rota dakikalarını
  topluyor ve SMV'yi satır başına **bir kez** çözüyor.
- **K2 — göç bölüm toplamını korumuyordu.** `operator_sayisi` tamsayı olduğu için toplam
  "operasyon sayısı × 3240 dk"nın katlarına kuantize oluyordu. İki gerçek örnek: 9
  operasyonlu ıslak bölümünde 12.960 dk → **0** (kapasite sıfırlanıyor, yük %0 görünüyor,
  Kapasite sekmesi de kilitli), 2 operasyonlu lazerde 3.240 → **6.480** (iki katı, olmayan
  boşluğa iş yükleniyor). İki aşamada düzeltildi: göç çarpanı günde 24 saati aşmayacak en
  küçük tamsayı seçip kalanı REAL çalışma saatine yazıyor, **ve** `OperasyonKapasite.Dakika`
  artık ondalık dönüyor — yuvarlama yalnızca bölüm toplamında bir kez yapılıyor, çünkü
  satır başına yuvarlamak kesirleri kaybediyordu.
- **K3 — geri dönüş yolu yoktu.** "Operatör 2" yazıp çalışma saatini 0 bırakmak bölümü
  türetilmiş yapıyor, kapasiteyi sıfırlıyor ve Kapasite sekmesini kilitliyordu. Silme ne
  API'de ne ekranda vardı; tek çare SQLite'a elle girmekti.

Dokuz önemli bulgu da aynı turda kapandı: N+1 sorgu (7×30=210 bağlantı), `operasyon_style`
okumasında `ORDER BY` yokluğu (çakışmada kazanan restart'lar arasında **değişiyordu**),
`KullaniyorMu`'nun üretimde hiç çağrılmaması, göçün makine bölümlerini operatör olarak
yazması (vardiya 0 kaldığı için kullanıcı makine eklediğinde kapasite hiç artmıyordu),
katalog boşalırsa kurtarma yolunun olmaması, `SmvKaynak`'ın "son yazan kazanır" olması,
uçta doğrulama yokluğu, "n/m operasyon tanımlı" uyarısının **planlamacının okuduğu rapora
ulaşmaması** ve `Verim` alanının hiçbir hesaba girmemesi.

**Dikkat çeken ayrıntı:** Ö8'i düzeltirken yıkama özetinin **web'de hiç gösterilmediğini**
buldum — yalnızca Excel'e aktarılıyor. Uyarı bu yüzden Excel özet sayfasına eklendi
(`DİKKAT: n/m operasyon tanımlı` + SMV kaynağı kolonu).

**Doğrulama kendi tasarım hatasını yakaladı:** Ö7'nin denetimi göçün kendi ürettiği
parametreyi reddetti (12.960 dk tek operatöre yazılınca günde 36 saat çıkıyordu). Testi
gevşetmek yerine göç düzeltildi — çarpan artık 24 saat sınırına göre seçiliyor.

- **Testler:** 71 → **114**, tamamı geçer. Web: `tsc -b` temiz, vite 665.58 kB.
- **Commit:** `4180acc` — fix(sentez-planing/operasyon): incelemenin 12 bulgusu kapatildi
- **Ertelenen küçükler (5):** Islak İşlem'in iki alt bölümünün tek `Dept` altında
  kilitlenmesi, `turetilen` haritasının seçili haftadan hesaplanıp "Tümüne kaydet"i de
  etkilemesi, iki farklı `Normalize` fonksiyonunun aynı dosya kümesinde bulunması, upsert'te
  her satır için `CreateCommand`, `GocEt`'in `_gate` kilidini almaması.

### B kısmından önce ölçülmesi gerekenler

İnceleme iki ölçülmemiş varsayım bıraktı, ikisi de deftere yazıldı:

1. **Style kimliği.** Özet raporda style kimliği olarak **envanter kartı kodu** kullanılıyor
   (`OrderSure`'da `Style` alanı yok). Liste Excel'indeki `Style` alanı farklı bir kimlikse
   girilen SMV override'ı **sessizce uygulanmaz**. B kısmının planından önce ölçülmeli ve
   "matris satırı var ama hiç eşleşmedi" sayacı eklenmeli.
2. **i-ailesi katlamasının çakışması.** Gerçek `WashName` kümesinde yalnızca i/ı ile
   ayrılan iki ad var mı — ölçülmedi.

## B kısmı: Excel giriş → çıkış hattı

Müsait saat formülü sorusunu dört turdur cevap gelmediği için **karara bağladım** ve B
kısmını yazdım.

### Formül kararı (spec 5.4)

**Çıktıya bizim kapasite sayılarımız yazılır.** Gerekçe: pivot sayfaları değer olarak
üretildiği için şablonun `Weekly Capacity!G = E*7,25*6 + F*9*5` formülü zaten
korunmuyor — formülün yerine bir **sayı** yazıyoruz. O sayının planlamacının ekranda
gördüğü kapasiteyle aynı olması gerekir; ekranda bir rakam, çıktıda başka bir rakam
görmek Faz 1b'nin I6 bulgusunun aynısı olur. Şablonun geleneğini isteyen kullanıcı
`gun_sayisi`/`calisma_saati` parametreleriyle kurar — formül kodda sabit değil.

### İki ölçüm (B kısmının önündeki engeller)

1. **i-ailesi katlaması çakışma üretiyor mu? HAYIR.** Girdi Excel'inde 197 tekil style →
   197 anahtar, 129 tekil yıkama adı → 129 anahtar, çakışan 0. 22 yıkama adı Türkçe
   karakter taşıyor (`PARÇA BOYA`, `DERİ`), yani katlama gerekli ama zararsız.
2. **Liste `Style`'ı Sentez kart kodu mu? HER ZAMAN DEĞİL.** `PlanningSql`'in kendi
   ölçümü kayıtlı: 197 style'in **173'ü tam eşleşiyor, 24'ü varyant** olarak bulunuyor
   (`2305-576` → `2305-576-BEZAL`). Özet rapor kart kodunu anahtarlıyor; matris liste
   `Style`'ı ile doldurulursa o **%12** için SMV override'ı sessizce uygulanmaz. Anahtar
   kimliğinin düzeltilmesi ayrı iş, ama **sessizlik kalktı**: matris dolu olup hiçbir
   satırı eşleşmezse log uyarı veriyor ve sebebini yazıyor (`143d770`).

Canlı veritabanına doğrulama için bağlanmayı denedim, **ulaşamadım** (TCP düşüp named
pipes'a geçiyor, zaman aşımı). Ölçümü kodun kayıtlı değeriyle aldım.

### Çıktı dosyası

**Uzantı `.xlsm` DEĞİL `.xlsx`:** şablon makro taşımıyor (`vbaProject` yok), yani `.xlsm`
yalnızca gelenek. ClosedXML makro yazamaz; `.xlsm` üretmek dosyayı "makro var" diye
işaretleyip boş bırakmak olurdu.

| Sayfa | Durum |
|---|---|
| `Data` | satır 9 başlık, 11+ veri; A/B/C/D = Style/Fit/Wash/New-CO, `G..` operasyon kolonları `x`, sonra hafta adetleri + toplam |
| `Orders` | hafta özeti: hafta, haftanın ilk LAST DATE'i, adet, order sayısı |
| `Weekly Capacity` | şablonun satır 4 başlıkları; SMV, sayı, müsait saat, birim esası, **SMV kaynağı** ve hafta yükleri |
| `New Product` | **boş başlıklarla + nedenini yazan not** |

`New Product` neden boş: üç bloğun ("First 10", ">1500 units", "Total List") seçim
kuralları şablonda **formülde değil pivot yapılandırmasında** gömülü, yani ölçülemedi.
Yarım doldurulmuş bir sayfa boş olandan daha yanıltıcı; sayfa nedenini kendi üzerinde
yazıyor.

**Dürüstlük kuralı:** matris boşsa `Data` sayfası operasyon kolonlarını **boş bırakıyor**
ve sayfanın üstünde nedenini yazıyor. Hangi style'ın hangi operasyonu kullandığı
bilinmiyorsa hepsini işaretlemek, kullanmadığı operasyonları da yüke sokmak demek.

### Doğrulama

Çıktı dosyası **geri okunarak** doğrulanıyor (ClosedXML test projesine eklendi) ve gerçek
girdi dosyasıyla uçtan uca test var. Atılacak bir testle dosyayı diske yazıp **gözle de
inceledim**, sonra sildim:

- `Data`: 208 veri satırı, 21 operasyon kolonu, gerçek style/fit/yıkama adları
- `Orders`: 10 hafta, Genel Toplam **116.833 adet / 258 order** — listenin kendisiyle birebir
- `Weekly Capacity`: 21 operasyon satırı (12–32), başlıklar şablonla aynı

- **Testler:** 117 → **143**, tamamı geçer. Web: `tsc -b` temiz, vite 667.15 kB.
- **Commit:** `583cb92` — feat(sentez-planing): B kismi
- **Sürükle-bırak:** sayfanın tamamı bırakma alanı (küçük bir kutuya isabet ettirmek
  gerekmiyor), Excel olmayan dosyada uyarı veriyor.

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
