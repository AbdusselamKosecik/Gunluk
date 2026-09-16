# pbxtr — 2026-09-16

## Bağlam

Güne "maddeleri bitirelim" hedefiyle başlandı. Çalışma ağacında **87 değişmiş + 24 yeni**
dosya duruyordu. İlk değerlendirmem "başka bir oturumun yarım işi" idi ve **yanlıştı**:
`git log` gösterdi ki dünkü (2026-09-15) `a10a3d30` ve `ad75a0f1` commit'leri "BR-BE-156
**kod bitti**" diyor ama **yalnızca `yonetim/` altına** dokunuyor. Kodun kendisi
(`CrossTenantWriteAttribute.cs`, middleware kapısı, iki migration, beş yeni entegrasyon
testi) commit edilmemiş hâlde diskteydi. Global kural 1: push edilmemiş iş bitmiş sayılmaz.

Dosya zaman damgaları 14:54–15:07Z aralığında kümelenmişti, hiçbir `dotnet`/`node` süreci
çalışmıyordu → iş bitmiş, sahibi commit'lememiş.

## Yapılanlar

### 1. Dünkü işin ölçülüp commit edilmesi

- **Neden:** Dünkü yeşil TRX'ler (13:06–14:22Z) bu ağacı **kapsamıyordu** — dosyaların
  tamamı 14:54Z ve sonrası. "Takım yeşil" bir tarih iddiasıdır.
- **Ne yapıldı:** ağaç yeniden ölçüldü, sonra 111 yol **tek tek sayılarak** (`git add -A`
  yok, `--pathspec-from-file`) commit edildi.
- **Komutlar:**
  ```bash
  dotnet build pbxtr.sln -c Debug
  bash deploy/test-kos.sh tests/Pbxtr.Architecture.Tests/Pbxtr.Architecture.Tests.csproj --no-build
  bash deploy/ci/api-test-shards.sh --parca 4
  cd src/Pbxtr.Web && npm run typecheck && npx vitest run
  ```
- **Sonuç:** build 0 hata · Architecture **607/607** (beklenen 607) · Api.Tests
  **5347/5347**, kapsam dışı 0 metod · web typecheck rc=0 · vitest **1887/1887** (209 dosya).
- **Commit:** `d8181aa3` — Entegrasyon 8 kodu: çapraz kip yazma kapısı, tenant anons dili,
  kara liste sayacı, migrate sözleşmesi.

### 2. Docker: "yok" değil, YANLIŞ YERDE ARANMIŞ

- **Neden:** `docker info` bağlanamıyordu; 09-11'den beri "Docker Desktop kapalı →
  entegrasyon ölçülemez" diye not düşülüyordu. Bu, **10 kartın tamamını** bloke eden tek
  şeydi ("entegrasyon 8 bekliyor").
- **Ne yapıldı:** kurulum `C:\Program Files\Docker` altında **değil**,
  `C:\Users\abdus\AppData\Local\Programs\DockerDesktop` altındaydı. Oradan başlatıldı.
- **Sonuç:** motor `29.7.2` ayağa kalktı, Testcontainers (postgres:16-alpine + redis:7-alpine)
  çalıştı. **Ders:** "araç yok" ile "aracı yanlış yerde aradım" aynı hata mesajını verir.

### 3. Entegrasyon 8 — 11 kırmızı, üçü de fikstür kusuru

- **Ne yapıldı:** `deploy/test-kos.sh tests/Pbxtr.Integration.Tests/...` → **980/991**.
  Kalan 11'in **tamamı** dün yazılan tek sınıftaydı: `CrossTenantWriteSurfaceHttpTests`.
  Ölçülen kapı (BR-BE-156) doğru çalışıyordu; kırık olan onu ölçen fikstürdü.

  1. **Tohum çapraz kipte `UPDATE public.users` yapıyordu** → `42501 new row violates RLS`.
     Bu arıza değil **karardır**: `users_tenant_isolation` WITH CHECK'i tam olarak
     `home_tenant_id = app_current_tenant()`; çapraz dal yalnız `USING`'de. Metin
     `USERS_ISOLATION_WRONG_QUAL` bekçisiyle birebir dondurulmuş (Karar #23 Ş23-3) — yani
     policy'yi gevşetmek, testin ölçtüğü yüzeyi açmak olurdu. Tohum hedef kullanıcının
     **ev tenant'ı** kapsamına alındı.
  2. **`sender_title`** fikstürü `varchar(11)` + `^[A-Z0-9][A-Z0-9 ]{1,9}[A-Z0-9]$`
     kısıtını ihlal ediyordu (8 haneli küçük harfli suffix) → `22001`.
  3. **İki kontrol yanlış uçta kuruluydu:**
     - Kontrol grubu `GET /api/v1/queues`: superadmin `queue.read` **taşımıyor**
       (permissions.seed.json) → 403 `PERMISSION_DENIED`. "Çapraz başlık GET'te kabul
       edilir" iddiası **hiç ölçülmüyordu**. `GET /api/v1/users` ile değiştirildi.
     - Vacuity `users-parola`: superadmin bir agent'ın parolasını **başlıksız da**
       sıfırlayamıyor (403 `target_more_privileged`; `UserAdminRules` parola sıfırlamada
       alt küme kuralı uyguluyor, agent'ta `call.originate`/`sms.send` var superadmin'de
       yok). O yolda "başlıksız geçer" iddiası baştan yanlıştı → `smtp-ayari`ye taşındı.
- **Dokunulan dosya:** `tests/Pbxtr.Integration.Tests/Tests/CrossTenantWriteSurfaceHttpTests.cs`
- **Sonuç:** `--filter CrossTenantWriteSurfaceHttpTests` → **11/11**, atlanan 0.
- **Commit:** `f3637458`

### 4. Kart ve pano

- 9 kart (`BR-BE-156/157/158/161`, `BR-DB-69/71`, `BR-QA-87`, `BR-OPS-10`, `BR-FE-87`)
  `Kod bitti → Bitti` yapıldı. Durum hücresi **şema ile** adreslendi (öncelik = `P<rakam>`
  ile başlayan son hücre, durum = ondan sonraki ikinci hücre) — konumsal indeks değil.
- ClickUp: `yazilan: 8`, doğrulama koşusunda `fark olan kart: 0, izde olmayan: 0`.

## Kararlar

- **`users` çapraz kipte yazılmaz** — testi geçirmek için policy gevşetilmedi; fikstür
  düzeltildi. Bir bekçinin birebir dondurduğu metni test uğruna değiştirmek, bekçiyi
  kaldırmakla aynı şeydir.
- **Vacuity kontrolü, aktörün gerçekten yapabildiği bir yazma üzerinde kurulur.** Aksi
  hâlde kontrol "başka bir kapıyı" ölçer ve kırmızısı yanlış sınıfta olur.

## Açık kalanlar / sonraki adım

- **Tam entegrasyon takımı fikstür düzeltmesinden SONRA yeniden koşturulmadı** (kullanıcı
  hız istedi). Geri kalan 980 test düzeltmeden önceki koşuda yeşildi ve commit yalnız o
  sınıfın fikstürüne dokunuyor — ama bu, tam takımın bugünkü HEAD'de ölçüldüğü anlamına
  **gelmez**.
- 09-11'den devreden: `BR-QA-55` (f) platform kararı (kurula), `BR-QA-56` (d) iki
  POSIX-bağımlı ST-44 öz-testi.
- Kullanıcıya ait: `/basla pbxtr sprint-44`, confd `ExecStart` geçişi (`BR-SYS-80/86`),
  `BR-SEC-16` sır rotasyonu.
- Yan tespit: 09-11'de bulunan `visual-tests/` typecheck deliği **kapanmış** —
  `npm run typecheck` artık `tsc -b --noEmit && tsc -p tsconfig.visual-tests.json` koşuyor.

---

## İkinci tur — "kalan maddelerden devam"

### 5. BR-OPS-12 — mesai kapısı ortak kaynağa taşındı (`0f198b9d`)

- **Neden:** Mesai kapısı (BR-OPS-08 / Karar #65 Ş65-3.7) yalnız `staging-yayin.sh`
  içinde yazılıydı. Sunucudaki **ikinci** yayın yolu `pbxtr-deploy-artifact` aynı etkiyi
  üretiyor (app konteynerini yeniden yaratıyor, migrate DDL kilidi alıyor) ama kapıyı
  **hiç çağırmıyordu** — mesai içinde, bayraksız, sessizce yayın yapılabiliyordu.
  `BR-OPS-10`'un düzelttiği sınıfın aynısı.
- **Ne yapıldı:** `mesai_kapisi` + `YAYIN_MESAI_RED=67` → `deploy/lib/pbxtr-migrate-adimi.sh`
  (SÜRÜM 1→2; iki okuyanın sürüm kapısı da 2'ye çekildi, bayat kurulum yayını durdurur).
  Sarmalayıcı kapıyı imaj/checksum/imza kontrolünden ve `flock`'tan **önce** çağırıyor.
- **Neden en başta değil:** kütüphaneyi yayının 0. adımı kurar; kapıyı ondan önce çağırmak
  ilk kurulumu ve her kütüphane güncellemesini 66/65 ile kırardı. 0. adım yalnızca
  `/usr/local` altına betik yazar.
- **Ölçüm:** yeni `kapi_55` (`deploy/mesai-kapisi-selftest.sh`) **12/12** — davranış
  (mesai içi RED · bayrakla devam · mesai dışı devam · saat dilimi ölçülemezse fail-closed),
  bağlantı (iki yol da çağırıyor, kopya yok), mutasyon (çağrı silinince kırmızı).
  Sarmalayıcı öz-testi 13/13 (yeni `w9`), `staging-yayin` öz-testi 16/16.
- **Yan tespit:** Docker Desktop VM saati 6 saat ileri (konteyner 07:08Z, host 01:15Z).
  Öz-test iç tutarlılık ölçtüğü için etkilenmiyor; ölçülen saat çıktıya yazdırıldı.

### 6. BR-BE-162 — santral üye sayısı artık ölçülüyor (`aa744435`)

- **Neden:** `GET /tenants/{id}/suspension-impact` `queueMembersOnPbx`'i **daima null**
  dönüyordu. Uç AMI'ye senkron gidemez (Ş64-14); sayıyı üretebilecek tek yer — her tick
  zaten `QueueStatus` okuyan `QueueMembershipSyncJob` — onu hiçbir yere yazmıyordu.
- **Ne yapıldı:** `QueueMembersOnPbxSnapshot` (sayı + sunucudan ölçüm anı, anahtar tek
  sabitte). İş her tenant için toplamı `ITenantCache`'e yazıyor; **yazım ve okuma aynı
  hedef-tenant kapsamında** (önek `pbxtr:{tenantId}:` — kapsam ayrışsa uç sessizce null
  dönerdi). TTL `MissingQueueStreakTtl` sabitinden.
- **Eksik ölçüm yazılmaz:** envanter ölçülemediyse ya da bir kuyruğun `QueueStatus`'u
  okunamazsa hiçbir şey yazılmaz. Santralde olmayan kuyruk 0 katkı verir — o bir ölçümdür.
- **Ölçüm:** uç 7/7, iş 15/15, Architecture 607/607, tenant ekranı vitest 92/92.
  Mutasyon: okuma `null`'a çevrilince uç kırmızı; `onPbxComplete` hep `true` → iş 2 kırmızı.
- **İki tuzak:** (1) negatif test önce "hiç yazım yok" diyordu; fikstürde birden çok tenant
  var ve bir tenant'ın AMI arızası diğerlerini susturmamalı → kontrol gruplu hâle getirildi
  (taban sayım, sonra `taban−1`). (2) İlk mutasyonum `if (false)` idi, **derlenmedi**, test
  eski ikiliyi koşup "yeşil" dedi; derlenen mutasyonla tekrarlandı.

### 7. BR-BE-163 / BR-DB-72 — canlı sunucuda salt-okuma ölçümleri (`8858d9b2`, `b444fd9b`)

- `pbxtr-edge` sunucuda **YOK**; canlı dialplan Sınıf B'ye hiç bağlanmamış
  (`call-permission` 0 dosya, `route-decision` 0, `CURL` 0; pozitif kontrol `exten =>` 3
  dosyada eşliyor). nginx `proxy_next_upstream error timeout`, `non_idempotent` yok →
  gönderilmiş POST yeniden gönderilmez. "Edge retry → kara liste sayacı iki kez" riski
  bugün **üretilemez**.
- `pbxtr_app` rolünün `tenants` üzerinde UPDATE yetkisi **yok** → `roles=pbxtr_app` olan
  `tenants_update` policy'si **ölü**. `tenants`'a yazan tek iki definer fonksiyon:
  `move_tenants_to_dealer`, `set_tenant_status`. `pg_stat_statements` **kurulu değil**.
- `tenants_seed_update` canlıda **hâlâ var**: `BR-DB-69` migration'ı yayın #17'den sonra
  yazıldı, henüz dağıtılmadı — kart "kod bitti, canlıda yok" olarak düzeltildi.
- **Araç tuzağı:** `docker exec -i`, heredoc'la beslenen betiğin kalan satırlarını yutuyor;
  sorgular `</dev/null` ile koşuldu.

### 8. BR-BE-133 — AlarmMetrics iki eksene ayrıldı (`e5263bca`)

- `All` = kural kurulabilir kapalı liste; `Displayable` = etiket evreni (jeneratörün yeni
  kaynağı). `queue_silence_min` yalnız `Displayable`'da.
- Ad çakışması (Ş47-6): etiket "sessizlik" demiyor → *"Çağrısız süre (dk)"*, 9 dilde.
- Ölçüm: `AlarmMetricsContractTests` 4/4, `AlarmRuleEndpointTests` 23/23 (negatif test
  400 + kontrol grubu 201), typecheck rc=0 (önce tam olarak kartın öngördüğü TS2741).

### 9. BR-QA-71 / BR-QA-26 — ölçüm aletinin kendisi (`5b8d7038`, `5fc65e92`)

- **Kapılar ilk kez gerçek evinde tam koştu** (docker soketi bağlı konteyner): **55/55**.
  Bu koşu kendi kusurumu yakaladı: `BR-OPS-12` sonrası `pbxtr-deploy-artifact-selftest.sh`
  tüm senaryoları 67 ile dönüyordu (`kapi_06` kırmızı) → bayrak eklendi.
- `BR-QA-26`: çökme **üç yük rejiminde, 13 koşuda üremedi** (32 çekirdek, 63,7 GB).
  Yükün gerçekten koştuğu zaman damgasıyla kanıtlandı. "Çökmüyor" değil, **"bu donanımda
  üretilemedi"** yazıldı. Sessiz abort riski zaten kapalı: shard TRX kimlik doğrulaması.

## Kararlar (ikinci tur)

- Ölçüm iddiası, **ölçüm ortamının kanıtı** olmadan yazılmaz: "yüklü koşuda üremedi"
  demek için yükün koştuğu zaman damgasıyla gösterilmelidir.
- Bir kapıyı ortak kaynağa taşırken **sürüm numarası artırılır** ve okuyanların kapısı da
  yükseltilir; aksi hâlde bayat kurulum sessizce eski kararı uygular.

## Açık kalanlar (ikinci tur)

- 206 açık kart: 63 canlı/santral, 49 kurul, 10 kullanıcı, 84 yerel kod/test işi.
  İlk sınıflandırmam fazla genişti (blokaj çoğu kartta gövdede yazılı, durum hücresinde
  değil) — başlık+durum birlikte okunarak düzeltildi.
- Sıradaki yerel kartlar: `BR-FE-79` (eşik yüzeyi + üç değerli görünüm + aria-live),
  `BR-OPS-04` (bildirim bacağı — teslim kanıtı staging gerektirir, kod yarısı yapılabilir).

---

## Üçüncü tur

### 10. BR-FE-79 — sessizlik eşiği yüzeyi `#14` içinden (`5aa13f81`, `bf645efb`)

- **Neden:** ürün eşik **seed etmiyor** (bilinçli). Opt-in bir özelliğin opt-in yüzeyi
  yoksa özellik **sonsuza kadar kapalıdır** — ve ölçüldü: hiçbir tenant'ta tek bir kural
  yoktu, iş `LogDebug` seviyesinde *"ölçecek bir şey yok"* basıyordu.
- **Ne yapıldı:** `SilenceThresholdPanel.tsx` (yeni) `#14`'ün içine indi: liste + ekle/
  düzenle/sil, `enabledCount === 0` **warn** tonuyla *"Hiçbir hedef izlenmiyor — sessizlik
  alarmı KURULU DEĞİL"*, ölçüm **üç değerli** (`null` = ölçülemedi, `0` = gerçek sıfır),
  sınır/tür/şiddet kümeleri **sunucudan**. Alarm satırına yapılandırılmış hedef
  (`alarmTargetText`), `aria-live="polite"`, kararlı ikincil sıralama.
- **Yakalanan kendi kusurum:** `5aa13f81` bir typecheck hatası taşıyordu — yeni testler
  `AlarmRuleListResponse` için `{ items: [] }` veriyordu (`metrics`/`severities` eksik).
  vitest geçiyordu, `npm run typecheck` kırmızıydı (6 yer). Ders defterdeki
  `tsc --noEmit yayın kapısı değil` maddesinin tersi: **vitest de kapı değildir**.
- **Borç kaydı:** `doc/prototip-urun-farklari.md` → *"#14 alarm satırında yapılandırılmış
  hedef — prototipte YOK, üründe VAR (BORÇ)"*.

### 11. BR-OPS-04 — bildirim bacağı (`3abb21d7`) — **kod yarısı; kart AÇIK kalıyor**

- **Neden:** Karar #47 / Ş47-13, *"kimseyi uyandırmayan alarm alarm değildir."* Ölçülen
  hâl: `SilenceSamplerJob` yükselen kenarda yalnızca `LogWarning` ediyordu.
- **Kartta yazılı olmayan tıkaç — işi tek başına vacuous bırakacaktı:**
  `AlarmNotificationDrainService` susturma penceresini
  `IAlarmNotificationGate.TryClaimAsync(ruleId, …)` ile **yalnızca `alarm_rules`**
  üzerinde kapatıyordu. Sessizlik kuralının kimliği `silence_thresholds.id`'dir ve o
  tabloda **hiçbir zaman bulunmaz** → naif bir `TryEnqueue`, isteği drenajda *"kural
  yok/kapalı"* diye **sessizce düşürürdü**: kuyruk dolu, gönderim sıfır, günlükte hiçbir
  arıza yok. Yani "bildirim bacağı kuruldu" denip **hiçbir şey göndermeyebilirdi**.
- **Ne yapıldı:**
  - `AlarmNotificationRequest` **`Source`** taşıyor — **varsayılanı YOK** (zorunlu konum
    parametresi), böylece yeni bir çağıran onu *unutamaz*; kapı isteğin **tamamını** alıyor
    ve `AlarmRule` yerine nötr bir `AlarmNotificationClaim(NotifyChannel, NotifyEmail)`
    dönüyor. Drenaj **tek yol** kaldı.
  - `silence_thresholds` üç kolon kazandı (`notify_channel`/`notify_email`/
    `notify_muted_until`) — göç `20260916163502_SilenceThresholdNotifyChannel`.
    Susturma penceresi `silence_observations`'a **yazılmadı**: gözlem satırı her turda
    yeniden yazılır, pencere ise operatörün kurduğu kuralın özelliğidir.
  - **`email_off_hours` fiilen `400`** → `BR-OPS-01`'in şartı **vacuous olmaktan çıktı**
    (bugüne kadar sessizlik tarafında **hiç kanal kolonu yoktu**, yani reddedilecek bir şey
    de yoktu). Gerekçe çeviri değil **ölçülmüş bir çelişki**: sessizlik **AÇIK DAKİKA**
    sayar (takvim kapalıyken sayaç ilerlemez) → alarm yalnızca çalışma saati **İÇİNDE**
    yanabilir; o kanal ise yalnızca **DIŞINDA** gönderir. Kesişim **boş kümedir**.
  - Yasak **üç yerde** durur: `AlarmNotifyChannels.SilenceAllowed`, uç doğrulaması
    (400 + gerekçe **yanıtın içinde**), `ck_silence_thresholds_notify_channel`.
  - Mail ön koşulu (`mail_settings` = 0 satır) liste ucunda `mailConfigured` olarak
    **üç değerli** döner ve panelde uyarı olur — ama **kural yazımını engellemez**: ayar
    sistem genelindedir, alarm kuralını yazan kişi onu düzeltemez ve yarın girilebilir.
- **Dokunulan dosyalar:** `src/Pbxtr.Domain/Modules/Live/AlarmNotification.cs`,
  `…/Silence/SilenceThresholdRule.cs`, `…/ISilenceThresholdAdministration.cs`,
  `src/Pbxtr.Infrastructure/Modules/EfAlarmRuleAdministration.cs`,
  `…/EfSilenceThresholdAdministration.cs`, `…/Configurations/SilenceConfigurations.cs`,
  `…/BackgroundJobs/SilenceSamplerJob.cs`, `…/Pipeline/TelephonyEventPipeline.cs`,
  `src/Pbxtr.Api/Modules/Realtime/SilenceThresholdEndpoints.cs`,
  `src/Pbxtr.Api/Platform/Realtime/AlarmNotificationDrainService.cs`,
  `src/Pbxtr.Web/src/app/screens/live/SilenceThresholdPanel.tsx`, `…/api/opsContracts.ts`,
  9 dil dosyası, 4 test dosyası.
- **Komutlar:**
  ```bash
  dotnet ef migrations add SilenceThresholdNotifyChannel \
    --project src/Pbxtr.Infrastructure --startup-project src/Pbxtr.Infrastructure \
    --context PbxtrDbContext
  dotnet test tests/Pbxtr.Api.Tests --filter "FullyQualifiedName~SilenceThresholdEndpointTests"
  dotnet test tests/Pbxtr.Integration.Tests --filter "FullyQualifiedName~SilenceSamplerJobTests"
  dotnet test tests/Pbxtr.Architecture.Tests
  npx vitest run && npm run typecheck
  dotnet format Pbxtr.sln --verify-no-changes --no-restore
  ```
- **Sonuç / doğrulama:** Api.Tests **27/27**, Architecture.Tests **615/615** (önce 611 —
  4 yeni sözleşme testi), Integration `SilenceSamplerJobTests` **15/15** (`Skipped: 0`,
  docker gerçekten ayakta — `docker ps` ile teyit edildi, `RequiresDockerFact` atlamadı),
  vitest **1899/1899**, typecheck rc=0, `dotnet format` temiz.
- **İki mutasyon kontrolü:**
  1. `ck_silence_thresholds_notify_channel` kısıtına `email_off_hours` eklendi →
     sözleşme testi **kırmızı** (4'ten 1'i); geri alındı.
  2. Örnekleyicide kanal `none`'a sabitlendi (derlenen değişiklik) → pozitif test
     **kırmızı**, kontrol grubu **yeşil**. Beklenen asimetri.
- **Commit:** `3abb21d7`

### 12. Format kapısı — kendi eski dosyalarım

`dotnet format --verify-no-changes` **7 dosyada** CHARSET/IMPORTS hatası verdi; hepsi bu
günün **önceki turlarına** aitti (python ile yazılan dosyalara ASCII dışı içerik girince
BOM gerekiyor). Bu turda kapatıldı — bırakılsaydı `yerel-yayin.sh` sessizce kırmızıya
dönerdi (defterdeki *"yayın yolu kapıları bayatlar"* maddesi).

### 13. BR-OPS-04 (e) — opt-in bedelinin adedi `#37`'de (`91ed1da5`)

- **Neden:** tenant kendi adedini `#14`'te görüyordu; *"kaç müşterimiz bu alarmı hiç
  kurmamış"* sorusunu **hiçbir yüzey** cevaplamıyordu.
- **Ne yapıldı:** `silence-alarm-coverage` sağlık satırı. Sayım `PlatformRollupJob`'ta
  (`app.cross_tenant='on'` + denetim satırı) üretilir, yoklama yalnızca **taşır** — her
  sağlık isteğinde üretilseydi 30 saniyede bir çapraz-tenant okuma denetim günlüğünü
  kullanılamaz hâle getirirdi (`provisioning-pull` ile birebir aynı gerekçe, o satırın
  belgesinde zaten yazılı olan karar).
- **Satır hiçbir zaman KIRMIZI olmaz.** Kural açmamış tenant bir **arıza değil tercihtir**;
  kırmızı yapmak bir ürün kararını kesinti gibi raporlar ve gerçek kesintilerin arasında
  kaybederdi. `Ok` + `Warning` (Ş35-22'nin dar yüklemi: *ölçüldü, çalışıyor, sayısal eşiği
  aştı*) ve detay **hem eşiği hem miktarı** yazar. `null` (rollup koşmadı) `0`'a
  **düşürülmez**.
- **Asıl incelik `enabled`:** kural satırı VAR ama hepsi kapalı olan tenant da *"kurulu
  değil"*dir — örnekleyici pasif kuralı hiç ölçmez. `EXISTS(… FROM silence_thresholds)`
  yazılsaydı o tenant KURULU sayılır ve eksiklik sessizce kaybolurdu. Entegrasyon testi
  bunu üç adımda ölçer (**fark ölçülür, mutlak sayı değil**: paylaşılan fikstürde tenant
  sayısı bu testin denetleyebileceği bir şey değil) ve **mutasyonla doğrulandı** —
  `AND s.enabled` kaldırılınca kırmızı.
- **Kapı kendi kusurumu yakaladı:** bileşeni `HealthComponents.All`'a eklemeyi unuttum;
  `HealthComponentInventoryTests` kırmızı yandı. Listeyi gezen her tüketici o satırı
  **sessizce atlayacaktı** — `BR-SYS-71`'deki `sysagent` kaçağının birebir tekrarı. Bu,
  o kapının tam olarak var olma sebebi.
- **Dokunulan dosyalar:** `ISystemHealthProbe.cs`, `IPlatformCounters.cs`,
  `PlatformRollupJob.cs`, `SystemHealthProbe.cs`, `platformApi.ts`, 9 dil dosyası,
  `SilenceCoverageHealthTests.cs` (yeni), `PlatformRollupJobDbTests.cs`.
- **Sonuç:** Architecture.Tests **615/615**, Api.Tests SystemAdmin **454/454**,
  Integration `PlatformRollupJobDbTests` **2/2**, vitest **1899/1899**, format temiz.
- **Commit:** `91ed1da5`

### 14. BR-QA-69 — cross-tenant turda eşzamanlı izolasyon + maskeleme telde (`564e531a`)

- **(a)** `Eszamanli_iki_tur_tenant_sinirini_KORUR`: iki tur `Task.WhenAll` ile **aynı
  anda**. Mevcut test aynı sınırı **sıralı** ölçüyordu; defterdeki kural açık —
  *"tek aktörlü test yarış deliğini görmez"*. Risk artık **hipotetik değil**: `BR-OPS-04`
  ile cross-tenant turun içine **üçüncü bir yüzey** (bildirim kuyruğu) eklendi. Test üçünü
  birden ölçer: kalıcı yazım, WS odası, bildirim isteği.
  **Mutasyon (kartın açıkça istediği):** `tenantScope` yayından **önce** kapatılınca iki
  test de kırmızı. Yayın commit'ten sonra olduğu için DB yazımı etkilenmez — mutasyon
  **yalnız yayını** hedefler, "her şeyi kırdım" değil.
- **(b)** `Aktif_alarm_yanitinin_HICBIR_alani_DID_numarasini_tasimaz`: gerçek E.164,
  **gövdenin tamamı** rakam dizisi olarak taranır (ayraçlı yazım da aynı diziyi taşır).
  Üç ön koşul testin **içinde**: DID gerçekten o numarayla duruyor; etiketi numarayı
  **gerçekten** taşıyor; ve **kontrol grubu** olarak aynı tenant'ın kuyruk alarmı yanıtta
  **görünüyor** (tarama boş gövde üzerinde değil).
- **Beklenmedik bulgu — mutasyon sınırı çizdi.** Yalnız salım kapısı kaldırılınca test
  **YEŞİL** kaldı: DID satırı uca çıktı ama `SilenceAlarmLabel` numarayı **tek başına**
  sildi. Kapı **ve** maske birlikte kaldırılınca **KIRMIZI**. Yani yüzeyde **iki bağımsız
  savunma** var ve **her biri tek başına yetiyor**; bu bir *derinlemesine savunma* testidir,
  katman testi değil. Sınır testin belgesine **yazıldı** — yoksa bir gün maske kaldırılıp
  *"test yeşil, sorun yok"* denirdi. (İlk mutasyonun yeşil kalması defterdeki
  *"mutasyon yeşilse fikstürü sorgula"* maddesinin tam karşılığı: bu kez sebep fikstür
  değil, **ikinci bir savunma katmanıydı**.)
- **Ölçüm kaybı notu:** ilk koşu `Test host process crashed` ile düştü ve sarmalayıcı yine
  de `exit 0` döndü (`BR-QA-26`'nin konusu). `--blame-crash` ile ikinci koşu 4/4 yeşil —
  çökme bu testten değil.
- **Sonuç:** Integration `~Silence` **25/25**, format temiz. **Commit:** `564e531a`

### 15. BR-BE-124 — teslim gözlemi deposu gerçek Redis'e karşı (`93e0af89`)

- **Neden:** sınıfın tek bir gerçek-Redis testi yoktu. İkiz, bayatlık kuralını **aynı
  sabitten** uyguluyor ama **üretim kodunu çağırmıyordu** — *"test ikizi üretimden
  müsamahakâr"* ile *"hiç koşmamış bileşim ölçülmemiştir"* sınıflarının kesişimi.
- **Üretim kayıt yolundan** (`AddPbxtrCache`), elle `new Redis…` yazılmadan. Saat
  `AddPbxtrCache`'ten **önce** kaydedilir: üretim fabrikası
  `GetService<TimeProvider>() ?? TimeProvider.System` der, yani sabit saat de üretimin
  kendi yolundan okunur.
- **(a) TTL** ham istemciyle ölçülür — ayrı ölçülmek zorundaydı: sınıf
  `ITenantCache.SetAsync` yolundan **geçmez** (o imza TTL'i zorunlu kılar), ham
  `HashSetAsync` kullanır ve **TTL'siz yazım derleme hatası vermez**. D-10 disiplini
  burada tipten değil **yalnızca bu testten** gelir.
- **(b) Bayatlık alan başına**, iki tenant aynı hash'te. Tek tenant'la ölçseydik anahtar
  TTL'i ile alan damgası ayırt edilemezdi ve test **anahtar bazlı** bir uygulamadan da
  geçerdi. **(c)** Bozuk JSON atlanır ama toplamı yalana çevirmez. **(d)** Boş depo
  **boş liste** döner, `null` değil.
- **Kartın şikâyet ettiği kusuru önce kendim yaptım — ve mutasyon yakaladı.** Testin ilk
  hâli damgaları `Now - StaleAfter ± 1 dk` diye yazıyordu; eşiği 3650 güne çektiğimde
  testin *"bayat"* damgası da onunla birlikte kaydı ve **mutasyon yeşil kaldı**. Bu,
  kartın *"ikiz, bayatlık kuralını AYNI SABİTTEN uyguluyor"* teşhisinin **birebir
  aynısıydı, bu kez testin kendisinde**. Damgalar **14 dk / 16 dk literaline** çevrildi
  ve pencerenin hâlâ 15 dakika olduğu **ayrıca** iddia edildi — pencere değişirse test
  sessizce uyum sağlamaz, yüksek sesle kırılır.
- **Üçüncü mutasyon bu yüzden gerekliydi:** ikincinin kırmızısı o koruma satırından
  gelebilirdi. `IsStale` her zaman `false` yapıldı (`StaleAfter`'a **dokunulmadan**) →
  kırmızı; yani **süzmenin kendisi** ölçülüyor.
- **Sonuç:** 4/4 yeşil (`Skipped: 0`), format temiz. Üç mutasyonun üçü de yakalandı.
  **Commit:** `93e0af89`

### 16. BR-QA-15 — node-bundle yolunda iki GUC **adıyla** (`26435b92`)

- **Kart daraltılmıştı:** *"hiç koşmadı"* önculü 2026-09-07'de çürümüştü; kalan iş,
  `app.cross_tenant` ve `app.tenant_id` varsayımlarını **GUC adıyla** iddia etmekti.
  Dolaylı ölçüm (*"iki tenant da paketini aldı"*) GUC'lar hiç yazılmasa da aynı çıkardı.
- **İki tasarım denedim, ikisi de ölçümle çürüdü — ve testin ilk satırı ikisini de
  yakaladı:**
  1. `DbCommandInterceptor` ile `TenantSessionWriter.CommandText`'i yakalamak: yazıcı GUC
     komutunu **ham bağlantı üzerinde kendisi** oluşturuyor (`connection.CreateCommand()`),
     yani EF'in komut interceptor'undan **hiç geçmiyor**.
  2. Dinleyiciyi DI'ya `IInterceptor` olarak kaydetmek: bu bileşimde **hiç çağrılmadı** —
     `AddDbContext` interceptor listesini **açıkça** veriyor ve DI'daki kayıtlar
     keşfedilmiyor.
  **İki hâlde de dinleyici sessizce boş kalır ve test "GUC yazılmış" diye GEÇERDİ.**
  Testin ilk satırı olan *"hiç yakalanmadı"* iddiası tam olarak bunun için vardı ve iki
  kez kırmızı yanarak beni durdurdu. Bu, defterdeki *"kapı kurmadan önce mevcut veriyi
  ölç"* maddesinin tersten çalışan hâli: **önce ölçüm aletinin kendisini ölç**.
- **Bugünkü sekme üretim portudur** (`IUnitOfWork` dekoratörü): transaction açıldıktan
  **sonra** — yani `TenantSessionInterceptor` GUC'ları yazdıktan sonra — **aynı transaction
  içinde** `current_setting(...)` okunur. Bu, *"yazıcı şu komutu koştu"*dan **daha güçlü**
  bir iddiadır: **ucun gerçek sorguları o değerleri görüyor**, ve RLS'in okuduğu şey de tam
  olarak budur. Üretim interceptor zinciri **değiştirilmedi**.
- **Kontrol grubu:** başka düğüme pinli tenant C'nin kimliği **hiç** yazılmaz — *"her
  tenant yazılıyor"* diyen bir uygulama ilk iki iddiayı geçerdi.
- **Mutasyon — ada bağlılık ispatlandı:** `app.cross_tenant` → `app.cross_tenant_x`
  kırmızı; `app.tenant_id` → `app.tenant_id_x` kırmızı.
- **Sonuç:** `~ProvisioningNodeBundleHttpTests` **7/7**, `~Provisioning` **64/64**, format
  temiz. **Commit:** `26435b92`

## Kararlar (üçüncü tur)

- Bir kuyruğa **kimlik** bırakılıyorsa, o kimliğin **hangi tabloya** ait olduğu da
  bırakılmalıdır ve bu alanın **varsayılanı olmamalıdır**. Varsayılanı olan bir kaynak
  alanı, yeni bir çağıranın bacağı sessizce kesmesine izin verir.
- Bir kısıt üç yerde yazılıysa (kod listesi, uç, DB CHECK), **üçünün aynı kümeyi
  saydığını ölçen bir test** şarttır; yoksa biri değişince diğerleri sessizce eskir ve
  sonuç ya `500` ya "hiç göndermeyen kural" olur.
- Teslim kanıtı üretilemiyorsa **yerine bir şey konmaz, daha dar bir iddia yazılır** ve
  kartta hangi kanıtın eksik olduğu açıkça durur.

## Açık kalanlar (üçüncü tur)

- `BR-OPS-04` **açık**: staging'de gerçek bir sessizlik alarmının `#14`'te görünmesi ve
  `mail_settings`'in doldurulması gerekiyor (SPF relay'i kapsamıyor, DKIM selector
  bilinmiyor). Üçü de **sunucu işi**; canlı erişim bu oturumda **salt-okunur**.
- ~~`#37`'de `enabledCount = 0` olan tenant sayısı~~ → **kapandı** (madde 13).
