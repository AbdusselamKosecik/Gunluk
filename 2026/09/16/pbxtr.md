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
