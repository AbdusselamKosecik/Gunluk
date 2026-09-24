# pbxtr — 2026-09-23

## Bağlam

Güne, bir önceki turda atılan **kurtarma commit'i** (`c4eba581`, 639 dosya, 3 günlük
commit'lenmemiş iş) ile başlandı. O commit'in mesajı açıkça *"dört test takımı ve 41 kapı
KOŞMADI"* diyordu — bugünün ilk işi o çekinceyi kapatmaktı. İkinci iş, `Pbxtr.Architecture.Tests`
içindeki **üç kırmızı**yı gidermekti (hepsi tek kök sebep: `SystemHealthProbe` içindeki ham
çapraz-tenant açılışı). Üçüncüsü: gerçek santralde ölçüm bekleyen kartların **gerçekten
bekleyip beklemediğini** ölçmek.

Aktif hedef (kullanıcı): *"Kurula hiçbir şey sorma. Sadece yapacak arkadaşa sor ne yapılabilir
diye. Maddeleri kontrol et, ClickUp'ı çevrim sonlarında güncelle, o şekilde devam et."*

## Yapılanlar

### 1. `SystemHealthProbe` ham çapraz-tenant açılışı kaldırıldı (BR-SYS-127)

- **Neden:** `Pbxtr.Architecture.Tests` üç testte kırmızıydı (`RawSqlAllowlistTests` ×2,
  `CrossTenantScopeGuardTests`). Kök sebep tek: `CheckWebhookDeadLetterSizeAsync` içinde
  ham `SELECT set_config('app.cross_tenant','on',true)`.
- **Ölçülen üç kusur:**
  1. **Bayrak hiç kapatılmıyordu.** `set_config(...,true)` transaction kapsamlıdır ve yoklama
     isteğin *ambient* transaction'ını kullanıyordu → bayrak isteğin sonuna kadar açık kalıyordu.
     Altına eklenecek her yeni DB kontrolü sessizce çapraz-tenant koşardı.
  2. **Denetim satırı ve yetki kontrolü yoktu** (`BeginCrossTenantScope` atlanmıştı).
  3. **Emsale uymak (A seçeneği) sahte yeşil üretirdi:** `/api/v1/system/health`
     `SelfManagedTransaction` değildir; `UnitOfWorkMiddleware` transaction'ı zaten açmıştır ve
     `BeginCrossTenantScope` yalnız `AsyncLocal` çevirir — GUC **yalnızca**
     `TenantSessionInterceptor.TransactionStarted`'da, transaction **açılırken** yazılır.
     Yani denetim satırı yazılır, **RLS kapalı kalır**, `dead` sayımı yalnız aktif tenant'ı sayar.
     Bu, kapatılmak istenen sahte yeşilin ta kendisiydi. **Bu belirleyici ayrıntıyı ben
     görmemiştim; `backend-dev-1` ölçtü.**
- **Ne yapıldı (B, dar varyant):** dead-letter sayımı `PlatformRollupJob.CountsSql`'e **iki skaler
  alt sorgu** olarak eklendi (ayrı gidiş-dönüş yok; koşu başına denetim satırı sayısı değişmedi),
  `IPlatformCounters` anlık görüntüsüne `WebhookDeadLetterMax24h`/`Total24h` (`int?`) geldi,
  `#37` satırı sayıyı **taşır, üretmez**. Ham `set_config` ve `dead` CTE'si tamamen kaldırıldı;
  yoklamada yalnız `pg_inherits`/`pg_class` **katalog** sorgusu kaldı (RLS uygulanmaz).
- **Karar:** sayım yoksa satır **`unmeasurable`**, asla *"eşik altında"*. `?? 0` yazılamaz —
  `WebhookDeadLetterHealthTests` `[Theory]` üç `null` kombinasyonuyla çiviliyor.
- **Aynı turda yakalanan iki ek kusur:**
  - `coalesce(sum(bytes),0)` → PostgreSQL'de `sum(bigint)` **numeric** döner, `GetInt64`
    `InvalidCastException` atar ve satır *"sorgu okunamadı"* diye **gri** görünürdü: arızası
    kendi hata koluna saklanan bir ölçüm. `::bigint` cast'i eklendi.
  - `dead` CTE'si `GROUP BY subscription_id` idi. Çapraz kapsamda RLS satır elemez ve abonelik
    kimliği tenant'lar arası tekil olmak **zorunda değildir** → iki tenant'ın sayısı toplanıp
    eşiği hak etmeden yanabilirdi. Artık `(tenant_id, subscription_id)`.
- **Dokunulan dosyalar:** `src/Pbxtr.Api/Platform/Health/SystemHealthProbe.cs`,
  `src/Pbxtr.Domain/Platform/Observability/IPlatformCounters.cs`,
  `src/Pbxtr.Infrastructure/Platform/Jobs/PlatformRollupJob.cs`,
  `tests/Pbxtr.Api.Tests/Modules/SystemAdmin/WebhookDeadLetterHealthTests.cs`,
  `tests/Pbxtr.Architecture.Tests/RawSqlAllowlistTests.cs`
- **Sonuç / doğrulama:**
  - `dotnet build -c Release` → **0 hata / 0 uyarı**
  - `Pbxtr.Architecture.Tests` → **777/777**. `CrossTenantScopeSurfaces.cs` envanterine
    **hiç dokunulmadı** (`SystemHealthProbe` artık o kümede yok); `RawSqlAllowlistTests`'te
    `SystemHealthProbe` girdisi 6 → **7** yazılı gerekçeyle, toplam 216 → 217 `Allowed.Sum`'dan
    **kendiliğinden** türedi, `PlatformRollupJob` sayısı **değişmedi**.
  - Api.Tests süzgeci (`WebhookDeadLetter|SystemHealth|PlatformRollup|PlatformCounters`) → **76/76**
  - **Gerçek PostgreSQL** (test sunucusu, 19:37Z): 12 kolonlu `CountsSql` **üretim rolü
    `pbxtr_app`** ile hatasız koştu; iki yeni alt sorgunun tipi **`bigint`**.
- **ÖLÇÜLMEYEN, açıkça:** `PlatformRollupJobDbTests` yerelde **SKIPPED** (Docker Desktop kapalı).
  Sayıların *doğruluğu* değil, yalnız sözdizimi/kolon sayısı/rol okunabilirliği ölçüldü.
- **Commit:** `cc38741e`

### 2. Api.Tests tam koşusu — kurtarma commit'inin çekincesi kapandı

- **Komut (üç dilim):**

  ```bash
  dotnet test tests/Pbxtr.Api.Tests/Pbxtr.Api.Tests.csproj -c Release --no-build --no-restore \
    --filter "FullyQualifiedName~Pbxtr.Api.Tests.Platform|FullyQualifiedName~Pbxtr.Api.Tests.Support"
  # + Telephony|SystemAdmin|Tenancy|AgentDesk dilimi
  # + kalan Modules dilimi
  ```

- **Sonuç:** **1376 + 2465 + 2485 = 6326 geçti, Failed 0.** (Kayıtlı ders gereği üç dilime
  bölündü: tek seferde 7 GB'a çıkıp takılıyor.)
- **Sınır:** bu koşu **değişiklikten önceki ikiliye** karşıdır; değişiklik sonrası Architecture
  777/777 ve ilgili Api süzgeci 76/76 ayrıca ölçüldü.

### 3. Format borcu kapatıldı (yayın kapısı kırmızıya düşerdi)

- **Neden:** `dotnet format --verify-no-changes` **12 dosyada** `IMPORTS` ihlali veriyordu.
  Hiçbiri bu turun dosyası değil — `c4eba581` kurtarma commit'inden kalma. Format kapısı
  yalnız **yayın betiğinde** koştuğu için bu borç yayın gününe kadar görünmezdi.
- **Komut:** `dotnet format Pbxtr.sln --no-restore --include <12 dosya>`
- **Sonuç:** `dotnet format --verify-no-changes` → **EXIT=0**; sonrasında build + Architecture
  tekrar ölçüldü (yine 0/0 ve 777/777).

### 4. Gerçek santral ölçümleri — BR-00a/b/c kapandı, BR-00d'nin engeli düzeltildi

`backend-dev-2`, `176.88.41.220` / `pbxtr-asterisk` (Asterisk 22.10.1) üzerinde ölçtü.
**Üç kartın "bekliyor" gerekçesi çürüktü.**

- **BR-00b:** kartın engeli *"kuyruklarda üye yok"* idi — **yanlış**: `t0007-tahsilat` **3 üye**,
  hepsi `penalty 1`, 483 bin saniyedir login. Tam zincir ölçüldü: `QueueAdd` (mevcut üye) →
  `Error: Already there` ve penalty **değişmedi** (kusur doğrulandı) → `QueuePenalty` →
  `Penalty: 7` (telafi **gerçekten çalışıyor**) → geri alındı, `queue show` ile okundu.
- **BR-00a:** engeli *"bakım penceresi"* idi — originate **serbest**. Negatif koşuda
  `queue show` = **No Callers**, `core show channels` = **0** → **hayalet çağrı yok**.
  Pozitif koşuda `QueueCallerJoin → AgentCalled ×3×5 → AgentRingNoAnswer → Abandon → Leave`;
  `queue_log`: `ENTERQUEUE` + 15 `RINGNOANSWER` + `NONE|ABANDON|1|1|25`.
  **Ölçülmeyen:** kutuda **hiç trunk yok** → PSTN `Dial()` bacağı ölçülmedi.
- **BR-00c:** `Gosub(pbxtr-t0007-vm,...)` tam zinciri koştu, `UserEvent(PbxtrVoicemail)` **tam bir
  kez**. **Kritik:** `/var/spool/asterisk/recording` **dizini hiç yoktu**; `Record()` dört seviye
  ara dizini **kendisi açtı** — açmasaydı sesli mesaj canlıda **sessizce hiç yazılmazdı**.
  **Ölçülmeyen:** dosya 44 bayt (yalnız WAV başlığı) — `Local/` kanalının medya kaynağı yok.
- **BR-00d (açık kaldı, engeli düzeltildi):** `manager.conf:22` → `channelvars = PBXTR_TENANT`
  tek değer. Davranışla da doğrulandı: `ChanVariable: PBXTR_TENANT` **573**, `PBXTR_ORIGIN` **0**,
  `QUEUE_PRIO` **0** → `CallEventPayload.Origin`/`.QueuePriority` canlıda **daima null** ve
  `AmiEventMapper.cs:38` bunları isteğe bağlı saydığı için **kimse kırmızı yakmıyor**.
  **Engel yazma değil, yürürlüğe alma:** `/etc/asterisk` `rw` bind-mount, ama `manager reload`
  **Karar #70 / Ş70-23 kalıcı kırmızı çizgi**. Tek yol: `docker restart pbxtr-asterisk`.
- **Sunucuda bırakılan iz yok:** geçici bağlamlar yedekten geri yüklendi, penalty 1'e döndürüldü,
  `verbose 0`, recording ağacı `rm -rf`, `/tmp` betikleri silindi.

### 5. Yayın penceresi ölçümü — iki kartın da öncülü çürük (BR-SYS-117, BR-DB-91)

`linux-uzmani` ölçtü. İlk satır sunucu saatiydi (`date -u`, sapma 16 sn).

- **Pencere geçti ve ölçülmedi.** `__EFMigrationsHistory` **229** = depodaki migration **229**
  → **bekleyen 0**. DDL'in fiilen koştuğu an, tablo dosyası mtime'ından:
  **2026-09-21 01:38:58–01:39:00** ve **2026-09-22 01:44:10**. Kartlar "bekliyor" değil,
  **kaçırıldı** durumunda.
- **Ş78-L2 ayarları hâlâ açık:** `log_lock_waits=on`, `log_min_duration_statement=1s`,
  `postgresql.auto.conf`'ta yazılı. Kartın *"yayın bitince geri dönülür"* taahhüdü uygulanmadı;
  5 günde loga düşen `duration:` satırı **toplam 9** (dokuzu da gece yedeğinin `COPY`'si) →
  maliyet fiilen sıfır, Ş78-L3 sayısı yazılana kadar açık kalsın.
- **Geçmişten çıkarım kartı kapatmaz, iki sebeple:** (1) `log_min_duration_statement` **ifade**
  başınadır, Ş78-L3 **transaction tutma** süresini ister; (2) `log_lock_waits` yalnız **biri
  beklerse** yanar ve bu kutuda `call-permission` trafiği **sıfırdır** (`call_attempts` 0 satır).
- **BR-DB-91:** kart *"ölçülmeden yayınlanamaz"* diyordu — **yayınlandı**. Ayrıca bu ortamda
  RED sayısı **yapısal olarak 0**: uç var ve çalışıyor (anahtarsız **401**), ama santral onu
  **hiç çağırmıyor**. Yük üretmeden ölçülecek *"0 → 0, fark 0"* **vacuous** olurdu; bu, kart
  metninde yazılı değildi.
- **`lock_timeout=10s` oturum varsayılanı değil rol ayarı** (`pg_db_role_setting`) — kartın
  "lock_timeout=0" ölçümü **bayat**.

### 6. Sunucu temizliği: iki yetim ölçüm döngüsü 6 gündür koşuyordu

- **Neden:** `docker logs pbxtr-postgres` içinde **42.680** `ERROR: trailing junk after numeric
  literal` / `syntax error` satırı (~8.520/gün). Bu gürültü, Ş78-L3 için kullanacağımız log
  kanalını da kirletiyordu.
- **Ne yapıldı:** PID **920528** (2026-09-17 18:40:43) ve PID **952151** (2026-09-17 19:02:39)
  sonlandırıldı. İkisi de bir ajan oturumundan kalma, tırnakları bozulmuş **sonsuz** `until`
  döngüsüydü.
- **İlginç ayrıntı:** hata metnindeki `952151call`, bash'in `$$call-data-retention$$`
  sınırlayıcısını **kendi PID'ine** genişletmesiydi — yani **hata mesajı koşucunun PID'ini
  taşıyordu** ve ilk turda kimse okumamıştı.
- **Komutlar:**

  ```bash
  ssh root@176.88.41.220 'kill 920528; kill 952151'
  ssh root@176.88.41.220 'ps -ef | grep -c "[u]ntil docker exec"'   # -> 0
  ```

- **Sonuç:** döngü sayısı **0**, hata akışı durdu, konteynerler sağlıklı.

### 7. Backlog + ClickUp

- **Durum hücreleri yazıldı:** `BR-00a`, `BR-00b`, `BR-00c` (Bitti), `BR-00d` (engel düzeltildi),
  `BR-SYS-117`, `BR-DB-91`, `BR-SYS-127`, `BR-SYS-128`.
- **Altı yeni kart** (numaralar önce ölçüldü, çakışma yok):
  `BR-DB-109` (`kapi_71` **KIRMIZI** — `02-guards.sql` gövdesi kurulu DB'ye ulaşmıyor,
  `BR-DB-88` sınıfının nüksü), `BR-SYS-128` (yetim döngüler), `BR-SYS-129` (`recording` ağacı
  canlıda hiç yoktu), `BR-AST-121` (AMI `Originate`+`Application: Gosub` Gosub'u hiç
  çalıştırmıyor — **ölçüm tuzağı**), `BR-BE-212` (`#37` node-state satırı daima `unmeasurable`
  olabilir), `BR-DOC-23` (`SystemHealthProbe.cs:1509` yorumunun öncülü çürük — polling yok).
- **Kart sayısı:** 773 → **779**.
- **ClickUp:** `--kuru` (fark 13, izde olmayan 6) → `clickup-olustur.js` (yeni 6) →
  `clickup-senkron.js` (yazılan 13) → `--kuru` doğrulama: **`fark olan kart: 0, izde olmayan: 0`**.
- **Commit:** `7d6024bc`

### 8. İkinci çevrim — BR-DB-109 (`kapi_71`) ve BR-00d

- **BR-DB-109 kapandı (`2e568aa3`).** `deploy/sablon-refresh-kapisi.sh` kırmızıydı: `02-guards.sql`
  gövdesi değişmiş ama onu kurulu veritabanına yeniden uygulayan migration yazılmamıştı.
  **Öncül ölçümü çarpıcı: defterdeki sha bir hayaletmiş** — `1dd931b4…` hiçbir commit'te var
  olmamış (son 20 sürüm tarandı). Defter, üç gün commit'lenmeden duran işin (`c4eba581`,
  639 dosya) **ortasından** alınmış bir ara hâli donduruyordu.
  **Fark yorum değil gövde:** `pbxtr_sys_function_expectations()` +4 fonksiyon (md5
  `c732d80e… → 52efa832…`, 30→33), `pbxtr_partial_unique_index_expectations()` +
  `ux_prov_queue_gaps_open` (7→8), `pbxtr_special_rls_guard()` +
  `recording_retention_effective_at`. Üçünün de iddiası `MaintenanceRunner.GuardAsserts`'te
  koşuyor → eski gövde kalan bir DB'de **uygulama hiç açılmaz**. Hijyen değil, açılış ön koşulu.
  **K6 git'e bakar, kurulu DB'ye bakmaz** — o üç günlük pencerede migrate koşan bir DB
  `20260921200000`'i eski gövdeyle uygulamıştır ve EF onu bir daha koşmaz.
  **Kilit sınıfı DDL'den sayıldı:** 51 `CREATE OR REPLACE FUNCTION`, 16 `CREATE FUNCTION`,
  16 `DROP FUNCTION IF EXISTS`, 40 `COMMENT ON FUNCTION`; satır başında **sıfır** `CREATE TABLE`/
  `ALTER TABLE`/`CREATE INDEX`/`GRANT`/`CREATE POLICY` → **ACCESS EXCLUSIVE yalnız 83 fonksiyon
  nesnesinde**, hiçbir kullanıcı tablosunda kilit yok. Bu yüzden 01 koşturulmadı (o
  `ensure_future_partitions(3)` ile `tenants`/`call_attempts` kilitler ve `call-permission`
  FAIL-CLOSED'dır). Ölçüm: build 0/0, Architecture **777/777**, `kapi_71` **rc=0**.
- **BR-00d'nin `PBXTR_ORIGIN` yarısı kapandı.** `manager.conf:22` →
  `channelvars = PBXTR_TENANT,PBXTR_ORIGIN,QUEUE_PRIO` + `docker restart pbxtr-asterisk`
  (yasak listeden hiçbir komut kullanılmadı; AMI'nin `write = call,agent,originate` kümesi
  el değmedi). `ChanVariable: PBXTR_ORIGIN=callback` **0 → 72**, timeline'ın ihtiyaç duyduğu
  her olayda dolu.
- **`QUEUE_PRIO` yarısı kapanmadı ve bu ancak DEĞER sayılınca görüldü.** Başlık 144 kez var,
  **144'ünün 144'ü boş**; değişkeni **kimse `Set` etmiyor** (`grep` tek isabet, o da bir yorum).
  **Tuzak:** başlık *adını* saymak 0 → 144 der ve kartı **yanlışlıkla kapatırdı** — Asterisk
  listedeki değişkeni kanalda tanımlı olmasa bile boş değerle yayıyor. → `BR-AST-122`.
- **SLA olay sırası gerçek santralde ölçüldü:** `QueueCallerLeave → AgentConnect → AgentComplete`,
  `Leave` iki turda da önce: **−3586 µs** ve **−65 µs** (lab kaydı −272 µs). Yön aynı, büyüklük
  **55× oynuyor** → öncelik-önce sıralaması doğru ve gerekliydi; ayrıca **zaman damgasına dayalı
  bir eşik güvenli değildir**.
- **Yeni kart `BR-BE-213` (P1) — sessiz ve üretimi ilgilendiren bir bulgu:** restart sonrası
  `t0007-musteri-hizmetleri`'nin **6 dinamik üyesi düştü** ve 100+ sn sonra hâlâ `No Members`;
  `pbxtr-app` logunda `QueueAdd`/resync izi **yok**. AMI ve ARI **geri geldi** — yani §3.4 resync
  durumu **okuyor**, üyeliği **itmiyor**. Üretimde aynı restart tüm agent'ları kuyruktan düşürür,
  panelde "müsait" görünürler ve kuyruk onlara çağrı dağıtmaz. **Hiçbir alarm yanmaz.**

### 9. Frontend ve Integration ölçümleri

- **Frontend temiz:** `vitest` **253 dosya / 2209 test, hepsi geçti** (exit 0); `npx tsc -b` → **0**.
  (`tsc --noEmit` yayın kapısı değildir — `-b` koşuldu.)
- **Docker Desktop kapalıydı**, başlatıldı (`%LOCALAPPDATA%\Programs\DockerDesktop`), böylece
  `Pbxtr.Integration.Tests` **bu oturumda ilk kez** gerçek PostgreSQL'e karşı koştu:
  **`Failed: 44, Passed: 1164, Skipped: 2, Total: 1210`** (25 dk 15 sn).
- **Bu 44 kırmızı muhtemelen haftalardır görünmüyordu:** yerelde Docker kapalı, GitHub Actions
  kaldırılmış. Kayıtlı dersin tam örneği — *koşmayan kapı bulgu değildir*.
- **Baskın sebep tek:** 26 kez `42703: column e.source does not exist`
  (`SlaAggregationJob.cs:406,810,956` → `public.call_events`). Kolonu ekleyen migration **var**
  (`20260919020000_CallDataSourceColumn.cs:92`) ve snapshot'ta da var → sorun SQL'de değil,
  testlerin koştuğu **fikstür şemasının üründen geri kalmasında** görünüyor (*test ikizi
  üretimden müsamahakâr*). Ajana ölçtürülüyor.
- **Ayrıca gerçek bir ürün kusuru:** `telephony_provider_effects` CHECK kısıtında **`Mute`/`Unmute`
  yok** ama C# kümesinde var → o iki işlem canlıda **`23514`** ile düşer.
- Diğer kümeler: IVR `complete_graph_required` 409'ları, `DeliveryProofHttpRunnerTests`
  `proof_step_failed` / `cleanup_failed`, `FinalDeliveryReportTests` donmuş defteri.

### 10. "Kalan maddeleri bitirelim" turu — 115 açık → 79, ve öncül çürükleri

Kullanıcı *"tamam hacım bitirelim kalan maddeleri"* dedi. 115 açık kartın **111'i** altı ajana
dağıtıldı (AST 29, DB 19, BE 18, QA/OPS/SEC 27, SYS 10, DOC/FE/C2 6). Dördü bilerek
dağıtılmadı — `BR-00d`, `BR-SYS-117`, `BR-DB-91`, `BR-BE-150`: dördü de **yayın penceresine**
bağlı ve planı hazır.

Her ajana aynı üç kural verildi: **(1)** önce kartın *"şu yüzden açık"* cümlesini **ölç**,
**(2)** küçük ve güvenli işi uygula, **(3)** büyük işe **düşürücü kriter** yaz. Hiçbiri
`dotnet`/`vitest` koşmadı (tek kilit bende), hiçbiri commit/push yapmadı.

**TURUN TEK BÜYÜK DERSİ: en az 20 kartın öncülü çürük çıktı.** Kartların *"şu yüzden açık"*
cümleleri haftalardır **doğrulanmadan** taşınıyormuş:

- `BR-AST-*` kartlarının çoğu *"sunucudaki ikili eski (`demo-ea567d11bb2e`, 2026-09-15)"*
  öncülüne yaslanıyordu. Koşan imaj `current-20260923-r3`, dialplan dosyaları 2026-09-22.
  `BR-AST-58`'in **kendi dört adımlı reçetesi dörtte dört** geçti → kapandı.
- `BR-AST-122` — dün benim yazdığım kart. *"`QUEUE_PRIO`'yu kimse `Set` etmiyor"* **yanlış**:
  `CallbackDispatcher.cs:316` yazıyor, ama **yalnız geri arama yolunda**; ölçüm penceresinde
  hiç geri arama sevk edilmediği için 144/144 boştu. Kartın iki şıkkı da düşer.
- `BR-BE-213` — yine dün benim açtığım kart. *"Restart üyeleri düşürdü, uygulama geri
  yazmıyor"* → **itme var, gecikmeli**: iş 300 sn periyotla koşuyor, üyeler ~8 dk sonra
  kendiliğinden geri gelmiş. **Benim ölçümüm 100. saniyedeydi.** Kalan gerçek olgu (8 dk
  üyesiz pencere + alarm yok) `BR-AST-126`'ya taşındı.
- `BR-SYS-60` — *"kanarya kodu yok"*: aslında **64 isabet** var. Eski ölçüm `frozen` arıyordu,
  kod `DONDURULMUS` diyor. **Arama terimi yanlışmış.**
- `BR-SYS-111` — *"bekçi sunucuda kurulu değil"* → kurulu. Üstelik vacuity ölçütünün **iki
  ayağı da** ölçüldü: canlıda pozitif (0 ihlal, `proconfig={lock_timeout=2s}`), gerçek
  `postgres:16` tam zincirde negatif (**3 ihlal RAISE**). Bekçi vacuous **değil**.
- `BR-OPS-14` — şartın penceresi **kaçırılmış** ve bu migration için bir daha ölçülemez.
  **Sahte ölçüm üretilmeyecek**; şart `BR-OPS-11`'e taşınacak.
- `BR-OPS-17` — *"hiçbir kapıya bağlı değil"* **kısmen yanlış**: skip fail-closed'ı
  `DockerEnvironment.cs:34-44`'te **kurulu**. Gerçek boşluk başka: takım **yalnız yayın
  yolunda** koşuyor ve yayın yapılmayan her gün **sessizce bayatlıyor**.

**Tersi de oldu — iki kart kötüleşti:**
- `BR-DB-76`: `telephony_provider_effects` **17.913 → 50.213 satır**, `n_tup_del = 0`, 26 MB;
  purge fonksiyonu ne kodda ne canlıda. Bayat teşhis değil, **büyüyen tablo**.
- `BR-BE-163`: kart *"bugün `MockSmsProvider` ile zararsız"* diyordu; bugün
  `SmsServiceCollectionExtensions.cs:200` **gerçek sağlayıcıyı** kaydediyor → çift-SMS riski
  **erişilebilir**. Mekanizma da farklı çıktı: açık bir `Release` değil, **ambient transaction
  rollback'i** jeton satırını yok ediyor.
- `BR-DB-16`: *"tam 63 karakter: 3 ad"* → **9 ad**, ve `webhook_deliveries` ailesi **bölümlü**:
  PG kısıt adını her partition'a çoğaltıyor, tek EF ad değişimi **yedi** katalog satırını
  birden ayrıştırır.

**İnen kod:** `#37` node-state satırı (kartın önerdiği yol **sahte yeşil** üretirdi — `app.cross_tenant`
GUC'u yalnız transaction açılışında yazılır; emsale göre **ayrı DI kapsamı** kullanıldı), üç
kapalı küme için C# kaynağı, `MESAI_MUAFIYETI_YASAK` listesinin **elle tutulmaktan türetilmeye**
geçmesi (elle defter **2 ad** taşıyordu, gerçek sayı **150**), kayıt ağacı kurulumu + `kapi_87`,
IVR Phase B sözleşmesi + bekçisi.

**Commit:** `65045696` (16 dosya) · **ClickUp:** `11b5a363` (yeni 4, 53 durum güncellemesi)

### 11. 84 yerel kapı: 15 kırmızı → 3

**Önce kendi hatamı ölçtüm.** Kapıları doğrudan Git Bash'te koşturmuştum ve 22 kırmızı
almıştım. Betiğin kendi başlığı bunu yazıyor: *"python3, gitleaks, openssl ve nginx yoktur,
10 kapı 'araç yok' diye düşer — ve o çıktı bir BULGU değil, ortamın eksiğidir."* Doğru
ortamda (`pbxtr-kapi:local` konteyneri + docker soketi) koşunca **15** kırmızı.

**11 kapı kapatıldı**, her biri üç sınıftan birine konularak — **(A) gerçek bulgu**,
**(B) donmuş envanter bayat**, **(C) ölçemedi**:

- **Sır taraması (A):** gitleaks'in yakaladığı şey kapıların kendi yorumu **değil**, gerçek
  bir sabitti (`ProvisioningSecretMaterializationHttpTests.cs:70`, `c4eba581`). Konvansiyona
  çevrildi; **değer hiçbir yere yazılmadı**.
- **Ortam değişkeni eşlemesi (A):** 9 değişken şablonda var, compose'da yok → operatör
  `.env`'e yazar, **uygulamaya hiç ulaşmaz**. Aynı katman bu depoda **dördüncü kez** atlanmış.
- **confd selftest (A):** 7 kırmızı iddia **tek kök sebepti** — `[general]` düşümü geldi ama
  fikstür güncellenmedi → *"teslim edilen kuyruk yüklenmedi"* kriteri **hiç ölçülmüyordu**.
- **Görsel taban manifestosu (A):** yeniden üretim **gerekmiyordu**; `producedFromSha` yanlış
  yazılmıştı. Piksel kapısı zaten 13/13 geçiyordu → görsel sapma yoktu, **kayıt yanlıştı**.
- **`SET LOCAL` ve `set_config` kapıları (A, kapının kendi kusuru):** isabetlerin tamamı
  **belge metni** ve **negatif fikstür**di. Kapı **gevşetilmedi**, desen sıkılaştırıldı ve
  muafiyet listesine **yeni ad eklenmedi**.
- **Üç donmuş envanter (B):** farkın meşruluğu **ölçüldükten sonra** tazelendi; `--dondur`
  körü körüne koşulmadı.

**Benim kendi alanım (#8, #9) — ve burada kendi hatamı buldum:**
kapı satırı **naif olarak `|` ile bölüyor**; benim yazdığım durum hücrelerindeki kabuk
boruları (`ss -lntp | grep`, `... | head`, `backup_tier | skill_mismatch`) hücreyi kaydırmış
ve durum metni Şart sütununa düşmüştü. Altı satır düzeltildi (metin kaybolmadı, borular
`/` oldu). **Ayrıca beş satırda öncelik hücresi `P#` biçiminde değildi** (`P1 (P3'ten
yükseltildi)`, `P1/P2`, `—`, ve `BR-SYS-43`'te hücre **hiç yoktu**) → o kartların önceliği
**panoda görünmüyormuş**. Beşi de onarıldı, notlar Story hücresine taşındı. Dört bayat
mezar taşı satır atıfı tazelendi.

**Açık kalan 3 kırmızının üçü de karta bağlı** ve ikisi ciddi:
- **`BR-DB-111` (P1, ürün kusuru):** `QueueMembershipSyncJob.WriteGapLedgerAsync` **çapraz
  kipte yazıyor**. Karar #65 Ş65-4.5'in savunması **uygulama katmanındadır** ve arka plan
  işleri o savunmanın **dışındadır** → bu yazma hiçbir yerde reddedilmiyor. `--dondur`
  **bilerek koşulmadı**: mutlak kural envanterden bağımsız ateşler, dondurmak yalnız gerçek
  sinyali susturur.
- **`BR-DB-112` (P1):** `20260919020000_CallDataSourceColumn` **onaydan sonra düzenlenmiş**.
  EF uygulanmış bir migration'ı **bir daha koşmaz** → düzeltme, migrate'i daha önce koşmuş
  **hiçbir veritabanında uygulanmaz** ve backfill FORCE RLS altında **0 satır** görmüş
  olabilir. *Şablon gövdesi kurulu DB'ye ulaşmaz* sınıfının birebir kardeşi.
- **`BR-SYS-131` (P2):** `BR-SYS-130` listeyi 2'den 150 ada çıkarınca öz-testin **kontrol
  grubu** listenin içine düştü → düzeltilmezse **HEP KIRMIZI kapı** olur.
- **`BR-BE-215` (P2):** `kapi_07`'de kalan 7 migration için onay satırı.

**Commit:** `c07c1691` (17 dosya) · **ClickUp:** `6efebda8`

### 12. Günün kapanış ölçümleri

| Doğrulama | Sonuç |
|---|---|
| `dotnet build -c Release` | **0 hata / 0 uyarı** |
| `Pbxtr.Architecture.Tests` | **777/777** |
| `Pbxtr.Api.Tests` (3 dilim) | **6326 geçti, 0 kırmızı** |
| `Pbxtr.Integration.Tests` | **1214/1216** — iki bağımsız koşu |
| frontend `vitest` | **2209/2209** · `npx tsc -b` **0** |
| `dotnet format --verify-no-changes` | **EXIT=0** |
| 84 yerel kapı (konteynerde) | **15 kırmızı → 3**, üçü de karta bağlı |
| Kart sayımı | **793 kart · 714 kapalı · 79 açık** (P0 4, P1 33, P2 37, P3 5) |

## Kararlar

1. **`#37` sağlık satırı sayıyı taşır, üretmez.** ≤15 dk bayatlık kabul; rollup durursa satır
   `unmeasurable`'a döner, *"eşik altında"*ya **değil**. Emsal: `ProvisioningKeysNeverPulled`.
2. **`BeginCrossTenantScope` açık bir transaction'ın GUC'unu geri yazmaz.** Kapsam transaction'dan
   **önce** açılmak zorundadır; aksi hâlde denetim satırı yazılır ama RLS kapalı kalır. Bu, ileride
   "emsale uyduk" diye yapılacak her düzeltmenin önündeki **ölçülmüş** engeldir.
3. **Format borcu yayın gününe bırakılmaz.** Kapı yalnız yayın betiğinde koştuğu için entegrasyondan
   sonra yerelde `--verify-no-changes` koşulur.
4. **Ş78-L2 ayarları Ş78-L3 sayısı yazılana kadar açık kalır** (maliyet ölçüldü: fiilen sıfır).
5. **Ölçüm döngüsü bırakan her tur kendi döngüsünü adıyla kapatır.** Oturum bitince döngü ölmüyor.

## Açık kalanlar / sonraki adım

- **`kapi_71` KIRMIZI (`BR-DB-109`) — P0.** `02-guards.sql` için tazeleme migration'ı yazılmalı.
  Bu migration bir sonraki yayında **zorunlu olarak koşacak** → `BR-SYS-117`/Ş78-L3 kilit-tutma
  örnekleyicisini `deploy/lib/pbxtr-migrate-adimi.sh` etrafına takmanın doğal anı odur;
  **iki kart tek pencerede kapanabilir.**
- **`BR-SYS-117` + `BR-DB-91` tek koşuda:** 20 ms `pg_locks` örnekleyicisi + `01-rls-template.sql`
  replay (sha `3f2cc36e…`, defterle birebir) + `deploy/e09-yuk-olcum.sh` ile **üretilmiş yük**.
  Düşürücü kriter yazılı; kontrol grubu (3 sn `LOCK TABLE`) **zorunlu**, yoksa körlük ölçülmüş olur.
- **`BR-00d`:** `manager.conf` → `channelvars = PBXTR_TENANT,PBXTR_ORIGIN,QUEUE_PRIO` +
  `docker restart pbxtr-asterisk`; sahibi `linux-uzmani`. Kartın **SLA olay sırası** yarısı buna
  bağımlı değil, ayrıca ölçülebilir.
- **Henüz koşmayan doğrulamalar:** `Pbxtr.Integration.Tests` (yerelde Docker kapalı),
  41 yerel kapı (`deploy/yerel-kapilar.sh`), frontend vitest.
- **İkinci yetim döngü şeklinin koşucusu bulundu ve kapatıldı**, ama benzerlerinin kalıp
  kalmadığı yalnız `ps` ile ölçüldü — systemd timer/cron tarafı taranmadı.
