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
