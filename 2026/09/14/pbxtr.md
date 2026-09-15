# pbxtr — 2026-09-14

## Bağlam
2026-09-13 gecesinden devam (o günün dosyası §1–16). Hedef (kullanıcı `/goal`): **"kalan maddeleri bitir. dasbordu guncelle"** — canlıdan onay alınmaz, kurulun kararıyla ilerlenir, her iş commit → push → ClickUp → günlük. Gece yarısında canlı imaj `demo-5ac884c7533b`'ydi; yayın #7 kapı bekçisine takılmıştı (13/§16).

## Yapılanlar

### 1. Yayın #7 engeli: ajan worktree'leri compose envanterine giriyordu (`d10369e4`)
- **Neden:** `capture-topology-guard.py` depo içindeki tüm `docker-compose*.yml` dosyalarını topluyor; `isolation: worktree` ajanları `.claude/worktrees/` altında depo kopyası bırakıyor → bekçi "fazladan compose" KALDI.
- **Ne yapıldı:** `compose_inventory` dizin yürüyüşünde `.claude` hariç tutuldu. Eski worktree'ler `git worktree remove --force` + `git branch -D worktree-agent-*` ile silindi, artık gate konteyneri ve öksüz testhost durduruldu.
- **Dokunulan dosyalar:** `deploy/capture-topology-guard.py`

### 2. `BR-BE-93` ölçülerek kapatıldı (`b7431ec0`)
- Platform tabanı kararı (Ş34-8 düzeltmesi + kod + iki aktörlü test) zaten uygulanmıştı; kart yalnız durum.

### 3. `BR-AST-60` Ş43-1 üretim santralinde ölçüldü (`42aea205`)
- **Neden:** Stasis'e giren kanalın PBXTR_CTL=1 iken asılı kalıp kalmadığı hiç ölçülmemişti.
- **Ne yapıldı:** Sunucuda geçici ölçüm bağlamı (`/root/ast60-olcum.sh`, sonra temizlendi). Sonuç: PBXTR_CTL=1 kanalı Stasis(pbxtr) içinde priority 3'te **33 sn asılı kaldı**. Aynı ölçümde iki yan bulgu: ARI `GET /endpoints` canlıda **404** (yol kökten başlıyordu), AMI `CoreShowChannels` **Permission denied**.
- **Kartlar:** `BR-AST-83` (ARI yol), `BR-AST-84` (CoreShowChannels), `BR-QA-78`.

### 4. `BR-AST-83` + `BR-AST-60` emniyeti (`abafbcf3`)
- **Neden:** `HttpClient` BaseAddress `.../ari/` iken `"/endpoints"` host köküne gidiyordu → `/endpoints` 404; kayıt envanteri (Karar #46 yolu) canlıda hiç çalışmamıştı.
- **Ne yapıldı:** `AriClient.Resolve(path)` başında `/` veya `\` olan ve ARI kökü dışına çıkan yolu reddeder; `AsteriskAriProvider` `GetAsync("endpoints")`; originate değişkeni `PBXTR_CTL` sabit `"0"`.
- **Testler:** yeni `AriRequestUriTests`, `AsteriskAriProviderOriginateTests` +2, `RegistrationSourceGuardTests` çıpası `"endpoints"`. Mutasyon 5 kırmızı, geri alınca 21/21.

### 5. `BR-AST-40` — Karar #53 (`0d684985`)
- `HaveParseMode { SingleTenant, Node }` (`ProvisioningAcknowledgedRevisions.cs`): öneksiz `X-Pbxtr-Have` yalnız `/node-bundle` kipinde yok sayılır, `/bundle`'da aynen. Çağıranlar `ProvisioningEndpoints` (SingleTenant), `ProvisioningNodeBundleEndpoints` (Node), `ProvisioningRealtimeSignal.DeliveryChanged`; `deploy/pbxtr-confd-cek.sh` yorumu.

### 6. `BR-BE-141` — sessizlik eşiği hata kodları (`788b0f62`)
- `SilenceThresholdWriteStatus { Ok, NotFound, TargetNotFound, Duplicate }`; `EfSilenceThresholdAdministration.SaveAsync` 23505 → Duplicate (409), 23503 → TargetNotFound (400; yabancı ve var olmayan hedef aynı gövde — varlık sızdırmaz). Yeni `SilenceThresholdHttpTests`.

### 7. `BR-QA-76/77` — fikstür kalıntıları (`0dd785de`)
- `TelephonyEventPipelineTests` kendi `cdr` satırlarını izleyip siler (`TrackCdr`/`RequireCdrCleanup`/`DeleteOwnCdrRowsAsync`); `CrossTenantVersionGateOracleTests` ve `TrunkAdminPersistenceTests` sabit secretRef kullanmaz (tam takımda başka sınıfta 409 üretiyordu).

### 8. `BR-BE-140` — sessizlik alarmı WebSocket invalidation (`3284d6e0`)
- **Neden:** ADR-016 sessizlik alarmı yanınca ekran polling yasağı yüzünden hiç tazelenmiyordu.
- **Ne yapıldı:** yeni `SilenceAlarmRealtimeSignal`; `SilenceSamplerJob.PublishEdgesAsync` metrik alarmıyla aynı `alarm.raised`/`alarm.cleared` olay + oda çiftini yayar (Alarm odası gövdesi yalnız `{ruleSource:"silence"}`, Tenant odası boş). `RealtimePublicLayerGuardTests` 7→9, `RealtimeProvider.test.tsx`.
- **Hata:** entegrasyon testi 2 sinyal bekleyip 3 aldı — boşluk tabanı kayınca meşru yeniden yanma; test 5. tur zamanı `fourth.AddSeconds(30)` yapıldı. İlk mutasyon (`if(false)`) CS0162 ile derlenmedi ve testler eski DLL'e koştu → derlenebilir mutasyon `_ = (raisedInTour, clearedInTour, now);` → 2 kırmızı.

### 9. Yayın #8 — canlı imaj `tekbirsoft/pbxtr:demo-3284d6e0c889`
- **Komut:** `PBXTR_CONFD_SAPMA=0 bash deploy/yerel-yayin.sh --yayinla > scratchpad/yayin48/yayinN.log` (confd sapma kapısı bilinen `BR-SYS-101`; nginx/compose kapıları artık atlamasız yeşil). 52/52 kapı.
- **Doğrulama:** health 200, AMI bağlı, ARI Stasis açık, `/endpoints` **200** (404 kapandı), WS 101. Yedek `pre-3284d6e0c889.dump`.
- **Kartlar kapandı (`fe8cd22e`):** AST-83, AST-40, BE-140, BE-141, QA-76, QA-77.

### 10. Kurul Karar #55–#58 (`a760b55e`, kartlar `76f75523`)
- **#55 `BR-AST-84`:** AMI'ye `reporting` sınıfı **REDDEDİLDİ**; kanal okuma ARI `GET /channels` (sıfır yetki değişikliği). Öncül çürüdü: kodda kopma sonrası kanal resync'i hiç yok → `BR-AST-86`.
- **#56 `BR-AST-85`:** superadmin kilidinde `QueueRemove` kilitten ÖNCE, kilit altında taze sayım (d); canlıda kuyruk üyeliği olan superadmin 0 → P3.
- **#57 `BR-DB-53`:** kota tetikleyicisine `ALTER FUNCTION ... SET lock_timeout='2s'`; Down yalnız `RESET lock_timeout` (`RESET ALL` `app.cross_tenant`'ı silip kotayı fail-open yapardı).
- **#58 `BR-AST-49`:** teslim niyeti platform işi; kısa vadede `tenant.suspend` adıyla yeniden kullanım, borç `BR-SEC-18`; t0012 ölçüldü (2026-09-05 panelden açılmış, 3 kullanıcı, 30 cdr, trunk yok).

### 11. CANLI ARIZA: etki defteri kısıtı 6 işlemi reddediyor → Kurul Karar #59 (`5188174d`)
- **Neden / nasıl bulundu:** `/endpoints` düzelince arkasındaki ikinci arıza göründü:
  ```bash
  ssh root@176.88.41.220 "docker logs --since 30m pbxtr-app 2>&1 | grep -E '23514|registration-sampler'"
  ```
  → `23514 ... violates check constraint "telephony_provider_effects_operation_check"`. `pg_get_constraintdef` 18 değer (`20260823130000_TelephonyProviderEffectLedger.cs:16`), `TelephonyOperation` enum'u 24: eksik `SendDtmf, TrunkHealth, ChannelUsage, QueuePenalty, QueueSummary, RegistrationInventory`. Hiçbir kapı enum ↔ kısıt eşitliğini ölçmüyordu.
- **Etki (kurulda sayıldı):** kayıt envanteri turu başarısız; trunk sağlığı ve kanal doluluğu hatayı YUTUP "ölçülemedi" gösteriyor (santrale ulaşıldığı hâlde); kuyruk özet senkronu onarmıyor; DTMF ve penaltı 500 — ve kayıt etkiden SONRA yapıldığı için DTMF tuşu karşıya gitmiş oluyor (çift gönderim riski).
- **Karar:** 10/10 ŞARTLI ONAY — genişletme; kısıtı kaldırmak ve okumaları deftere yazmamak reddedildi. Şartlar: `lock_timeout` + `ADD ... NOT VALID` + ayrı `VALIDATE` + DO bloğu doğrulaması; gerçek PG kapısı hem küme eşitliği hem her enum değeri için `Record` satırı + mutasyon; canlıda 23514=0, `/trunks/health anyMeasured=true`, DTMF tek kez.
- **Kartlar:** `BR-DB-54` (P0, migration + kapı — worktree ajanında yazılıyor), `BR-BE-144` (P1, defter-sonrası hata sonucu çevirmesin), `BR-DB-55` (P2, append-only defterin periyodik okumalarla büyümesi — 24 saat ölçüm sonrası karar).

## Kararlar
- Karar #55–#59 (yukarıda). Sınıf dersi: **enum'u aynalayan her CHECK kısıtı bir kapı ister** — yeni enum değeri migration'sız eklenince arıza canlıda ve çoğu çağıranda sessiz çıkıyor.

## Açık kalanlar / sonraki adım
- `BR-DB-54` migration'ını entegre et, build + test + mutasyon, yayın #9.
- Ana ağaçta uygulanmış, testi koşan üç yama: `BR-FE-80` (SMS şablonları ekranı), `BR-DB-52` (retention zaman aşımı hiyerarşisi 50<80<90<150 sn), `BR-BE-137` (serileştirme kilitlerinde `lock_timeout=2s`, 55P03 → 503 `RESOURCE_BUSY`) — yeşil gelince ayrı commit'ler.
- `BR-AST-49` ajanı Karar #58 şartlarını uyguluyor.
- Yayın #9 sonrası: Ş59-4/5 canlı ölçümleri, Ş49-4, 24 saat sonra Ş59-6 defter büyümesi.

---

## Devam (2026-09-14 ~02:00–05:00 TR)

### 12. Karar #59 kaydı ve kartlar (`5188174d`)
- 10/10 ŞARTLI. Şeytan'ın 5 itirazı yazılı cevaplandı (çağıranlar tek tek sayıldı; defter-sonrası hata ayrı kart; büyüme ölçülecek; `NOT VALID`+`VALIDATE`+`lock_timeout`; kapı hem liste hem gerçek `Record` satırı).
- Kartlar: `BR-DB-54` (P0), `BR-BE-144` (P1), `BR-DB-55` (P2).

### 13. Üç yamanın testi ve bir fikstür kusuru (`798efda1`, `2a0bd756`, `e8d137d3`)
- Arch 479, Api 1560, vitest 88, `tsc -b` 0 yeşil; Integration'da `SerializationLockWaitBoundTests` 2 kırmızı.
- **Kök sebep:** fikstür bayi+tenant'ı sabit kimlikle açıp siliyordu; `tenants` üzerinde DELETE policy bilinçli olarak YOK (`01-rls-template.sql` "DELETE: policy YOK"), FORCE RLS altında owner silmesi sessizce 0 satır → sonraki koşuda `DELETE FROM dealers` 23503. Düzeltme: kimlikler test örneği başına `Guid.NewGuid()`, kod eki rastgele; temizlik kaldırıldı. 26/26.
- Üç kart ayrı commit.

### 14. `BR-DB-54` entegrasyonu (`0166cac8`)
- Worktree ajanının yaması: migration `20260914100000_TelephonyEffectOperationCheckWiden` (SET LOCAL lock_timeout 5s → DROP → ADD ... NOT VALID → VALIDATE → DO bloğu 24 değer + convalidated doğrulaması; Down 18'lik NOT VALID), onay satırı `Karar#59`, st44 json son migration adı, `EnumMirrorCheckConstraintTests` (28 enum-aynası CHECK için kurulu DB eşitliği + her `TelephonyOperation` için gerçek `Record` satırı).
- Ajan ölçümü: 1,05M satırda Up 0,46 sn; başka oturum tabloyu tutarken 5,2 sn'de lock timeout. Diğer 27 kısıtta uyuşmazlık YOK.
- Doğrulama: guard `ONAYLI (Karar#59)`; 28/28; **mutasyon** enum'a `MutantX = 24` → 2 kırmızı; geri alınıp `touch` + rebuild, DLL'de `MutantX` 0 → 28/28; Arch 479/479.

### 15. Yayın #9 — `tekbirsoft/pbxtr:demo-0166cac8669a`
- Önce tüm ajan worktree'leri kaldırıldı (değişiklikleri ana ağaçla `cmp` ile karşılaştırıldı, hepsi entegre).
- `PBXTR_CONFD_SAPMA=0 bash deploy/yerel-yayin.sh --yayinla` → 52/52 kapı, Integration 868, Api 1278 yeşil, yedek `pre-0166cac8669a.dump`.
- **Canlı ölçüm (60 dk):** kısıt `convalidated=t` 24 değer; 23514 = 0; "Arka plan isi hata verdi" = 0; defter satır/saat: QueueSummary 84, QueueStatus 24, RegistrationInventory 12 (~2.900/gün → `BR-DB-55`).
- Ş59-5 ölçülemedi: `/trunks/health` trunk yok (boş küme); `admin/overview.channelUsageAt=null` çünkü ChannelUsage AMI `CoreShowChannels` ile okunuyor ve canlıda Permission denied → `BR-AST-84`. Kalan canlı ölçüm kartı `BR-QA-79`.
- **Yan bulgu:** `registration-sampler` her turda 503 nesne düşürüyor. ARI `/endpoints` sınıflandırması: 500 `t9001-olcek-*`, 3 `t9001-olcum-*`, 6 `t0007-wrtc-*`; `t9001` tenant'ı yok, `/etc/asterisk`'te tanım yok → eski ölçek ölçümünün bellekteki kalıntısı → `BR-AST-87`.
- ARI `GET /channels` canlıda `200 []` (aktif kanal 0), `ari.conf`'ta `channelvars` YOK — `BR-AST-84`'ün linkedid ölçümü gerçek çağrı ister.
- Ölçüm betikleri sırrı yazmaz: ARI kimliği `docker exec pbxtr-app printenv` ile değişkene, curl'e stdin'den (`read -r A`).
- Kartlar kapandı (`50a039b8`): BR-DB-54, BR-FE-80, BR-BE-137. Yeni: BR-QA-79, BR-AST-87, BR-DB-56.

### 16. Paralel tur — dört worktree ajanı (yayın koşarken, derleme yasak)
- `BR-BE-144`: etki başarılı + defter düştü → sonuç aynen, Error log + `pbxtr.telephony.effect_ledger.write_failed` sayacı.
- `BR-BE-139`: kapalı saatte sessizlik metriği 0 (taban korunur, açılışta kaldığı yerden), alarm kapanışta `alarm.cleared`; ADR-016 K-2a.
- `BR-DB-53`: iki migration (bekçi tazeleme `20260914105000` + `ALTER FUNCTION ... SET lock_timeout='2s'` `20260914110000`, md5 gövde doğrulaması), Down yalnız `RESET lock_timeout`, üç yazma yolunda 55P03 → 503; kapsam dışı bulgu → `BR-DB-56`.
- `BR-AST-85`: `QueueRemove` kilitten önce, taze sayım kilit altında, telafi `OnCompleted` ile commit/rollback sonrası.
- `BR-AST-49` yaması (Karar #58) da aynı turda.
- Entegrasyon: beş yama `git apply --3way`; iki çakışma (`TenantLimitsEndpoints.cs` niyet bloğu + 55P03 catch birleşti; ADR-005 iki durum notu birlikte). `BR-AST-49` migration'ı `20260914090000` → `20260914120000` (canlıda uygulanmış `100000`'dan eski olmasın), Designer attribute + st44 json.
- Build: tek hata (eksik `using Microsoft.Extensions.DependencyInjection`) → 0. Arch 479, Api 5159, vitest 192 dosya, `tsc -b` 0; **Integration 894'te 6 kırmızı** (DB-53 iki test 500, AST-85 bir test 403 yetki, QueueMembershipSyncAlarmTests 3 test yalnız tam takımda) — düzeltme sürüyor.

## Açık kalanlar / sonraki adım
- 6 Integration kırmızısı → yeşil, mutasyonlar, beş kart ayrı commit, yayın #10.
- Yayın #10 sonrası: BR-AST-49 Ş49-4, BR-QA-79 gerçek çağrı ölçümleri, 24 saat sonra BR-DB-55.

### 17. Integration kırmızıları — iki gerçek ürün kusuru (`d5f887bc` içinde)
- **55P03 hiç 503'e çevrilmiyordu:** Npgsql 55P03'ü geçici hata sayıyor, EF yürütme stratejisi `InvalidOperationException → DbUpdateException → PostgresException` diye sarıyor; `catch (DbUpdateException) when IsLockNotAvailable` hiç eşleşmiyordu. `PostgresErrors` bu tek sarmalayıcıyı açar. Mutasyon: 2 kırmızı.
- **`POST /api/v1/dealers/{id}/tenants` gerçek PG'de HER ZAMAN 500'dü:** `tenants_update` policy çapraz kipte yazmaz; bayi dalı eski+yeni bayiyi tek GUC ile karşılayamaz → UPDATE 0 satır → `DbUpdateConcurrencyException`. Bu uç için hiç entegrasyon testi yoktu. Düzeltme: satır başına `set_config('app.tenant_id', <tenant>, true)`. Desen incelemesi `BR-DB-57`.
- Test tarafı: AST-85 aktörüne `owner` rolü (extension.write); `QueueMembershipSyncAlarmTests` başka sınıfın bıraktığı pinli anahtara karşı kendini korur (kaynak `BR-QA-80`).
- Tam Integration 894/894. Mutasyon koşucusu (`scratchpad/mut10.py`: çıpa → build iki proje → filtreli test → baytları geri yaz + utime → rebuild → temiz koşu): BE-144 2+1, BE-139 4+1, AST-49 1, AST-85 4 kırmızı; temiz koşuda hepsi yeşil.
- Commit'ler: `51ef5bad` (BE-144), `876da7cd` (BE-139), `d5f887bc` (AST-49+DB-53+AST-85 — ortak dosyalar yüzünden birlikte).

### 18. Yayın #10 — iki deneme, canlı `tekbirsoft/pbxtr:demo-f10d1cbf096c`
- **Deneme 1 KALDI:** ST-44 öz-testleri (BR-QA-56) — `deploy/st44/st44-role-matrix.json` `sources/permissionsSha256` bayat (AST-49 `permissions.seed.json` açıklamalarını değiştirdi; yetki kümesi aynı). dotnet takımları bunu görmez.
  ```bash
  python deploy/st44/s30-canonical-fixtures.py --root . --matrix $S/m.json --seed $S/s.json
  # alan alan fark: yalniz /sources/permissionsSha256
  cp $S/m.json deploy/st44/st44-role-matrix.json && python deploy/st44/s30-canonical-fixtures-test.py  # 6/6
  ```
  Commit `f10d1cbf`. Hafızaya eklendi (yetki-seedi-iki-namespace-ister: üçüncü yüzey).
- **Deneme 2:** 52/52 kapı, testler yeşil, yedek `pre-f10d1cbf096c.dump`.
- **Canlı doğrulama:** 4 yeni migration; `pbxtr_dealer_quota_reject.proconfig = {app.cross_tenant=on,lock_timeout=2s}`; 20 dk logda 23514=0, iş hatası=0, `fail:`=0, "defter yazilamadi"=0.
- **Karar #49 uygulandı:** superadmin `PUT /api/v1/tenant` (X-Tenant-Id t0012; ad/limitler aynen gönderildi — uç hepsini zorunlu istiyor, ilk deneme 400) + gerekçe → 200; `provisioning_delivery_intent=not_delivered`; denetim `tenant.provisioning_delivery.changed`.
- **Ş49-4 ölçüldü:** `/api/v1/system/health` provisioning satırı önce "1 tanesi hicbir pbxtr-confd dugumune ATANMAMIS" (03:50 UTC), sonra `state=ok` "1 tenant BILEREK TESLIM EDILMIYOR (Karar #49) — ariza degil" (04:31 UTC).
- Ders: sunucuda `pkill -f <betik adı>` ssh'nin kendi `bash -c` komut satırını da eşler ve oturumu öldürür (exit 255) — PID ile öldür ya da hiç öldürme.
- Kartlar kapandı (`683bdd1a`): BR-AST-49, BR-DB-53, BR-AST-85, BR-BE-144, BR-BE-139. Yeni: BR-BE-145, BR-DB-58.

## Günün sonu durumu
- Canlı: `demo-f10d1cbf096c`. Bugün canlıya çıkan kartlar: AST-83, AST-40, BE-140, BE-141, QA-76/77, DB-54, FE-80, BE-137, DB-52 (kod), AST-49, DB-53, AST-85, BE-144, BE-139.
- ClickUp: fark 0; 189 açık kart.
- Sıradaki: BR-AST-84 (ARI `/channels`, gerçek çağrı ölçümüyle BR-QA-79), BR-DB-56, BR-DB-57 incelemesi, BR-DB-55 24 saat ölçümü (2026-09-15 ~00:30 UTC), BR-AST-87 t9001 temizliği.

---

## Devam (2026-09-14 gündüz)

### 19. BR-AST-87 ölçüldü — t9001 kayıtları PJSIP nesnesi değil (`d74e55a3`)
- ARI `/endpoints` 500 `t9001-olcek-*` + 3 `t9001-olcum-*` gösteriyor; `pjsip show endpoint t9001-olcek-137` → "Unable to find object"; `GET /ari/asterisk/config/dynamic/res_pjsip/endpoint/t9001-olcek-137` → 404 (kontrol `t0007-wrtc-1042` → 200); `grep -r t9001 /etc/asterisk` boş. Bayat endpoint anlık görüntüleri; reload silmez, `core restart` yasak → temizlik YAPILMADI.
- Ders: `pjsip show endpoint <tahmin>` ad biçimini listeden al (ilk tahmin `-001` yanlıştı, gerçek `-137`).

### 20. Paralel tur: BR-DB-56, BR-DB-58 (WS), BR-FE-81, BR-BE-145 + Kurul #60/#61
- Worktree ajanları derlemeden yazdı; yamalar `git -C $W add -N . && git -C $W diff HEAD > patch` ile alındı.
- **Kurul #60** (BR-DB-58 (1)): 10/10 ŞARTLI (d) — DB bekçisi BİLİNÇLİ yok (uygulama GUC'larında kapsam yok; admin ve owner aynı GUC'larla gelir). Şeytan itiraz 2 ölçüldü: `tenant.suspend` `bundle.tenant` içinde, `CustomRolePolicy` reddetmiyordu. **Kurul #61** (BR-DB-57): 10/10 ŞARTLI (a) geçici tek uç istisnası; Şeytan itiraz 2 (EF otomatik savepoint GUC'u geri almaz) kaynakta doğrulandı. Kayıt `821c32df`, kartlar BR-DB-59/60/61.
- Şartları uygulayan ajan (ana ağaç): `Tenant` setter'ları private + tek-yazıcı bekçisi; `CustomRolePolicy` `platform_only` (mutasyonda HTTP 201/200 → açık GERÇEKTİ); `SaveTenantRowAsync(Tenant)` izleyici kapısı, geri yükleme `finally` + 25P02 yutma; istek yolu `set_config` kapalı listesi; dört taşıma hâli + havuz GUC testi. Mutasyon: geri yükleme silinince taşıma YİNE 200, GUC son tenant'ta — sessiz kusur.
- Tam koşu: Arch 489, Api 5172 (6 parça — Modules tek parça 8 GB'a çıkıp 5 test TaskCanceled ile kesildi), Integration 907, vitest 1801, tsc 0. Commit `885074a0`.
- BR-FE-81 (`ed4725ec`): wallboard testi aynı metni rozet+şeritte buldu (multiple elements) → iddia `role=status` içine daraltıldı; mutasyon `isDeliveryWithheld` hep false → 4 dosya kırmızı.

### 21. Yayın #11 — `tekbirsoft/pbxtr:demo-457ae80d8db0`
- **Deneme 1 EXIT=2:** 52/52 kapıdan sonra `dotnet format --verify-no-changes` (ajan dosyalarında using sırası + boşluk). Betik biçimi kopyaya uyguladığı için depo temiz görünüyordu → yerelde `dotnet format pbxtr.sln --include <dosyalar>`, `git diff -w` yalnız biçim, commit `457ae80d`. Hafıza: format-kapisi-yayinda.
- **Deneme 2:** 52/52, Arch 489, Integration 907, Api 1293×4 parça yeşil; yedek `pre-457ae80d8db0.dump`.
- **Canlı ölçüm:** superadmin `POST /api/v1/roles/custom` (X-Tenant-Id t0007, `tenant.suspend`) → **409 `platform_only`**, rol oluşmadı; sağlık `telephony-effect-ledger` `ok`, `provisioning` `ok`; 20 dk 23514=0, fail=0.
- Kartlar kapandı (`c370bd25`): BR-DB-56, BR-DB-57, BR-DB-58, BR-BE-145, BR-FE-81. Yeni: BR-AST-88 (Ş58-4), BR-BE-147 (X-Cross-Tenant yazma 500), BR-QA-81 (St44 seeder sessiz yeşil), BR-SYS-102 (confd curl kararı).

### 22. Sonraki paralel tur (yamalar hazır, entegrasyon sürüyor)
- BR-QA-80 (test anahtar kalıntısı; TOTP `000000` flake kök sebebi: rastgele sırda ±1 pencere 3/10⁶), BR-BE-146 (`/queues` deliveryState; #03 "Kuyruk varlığı" satırı teslim edilmeyen tenant'a "Hepsi yerinde" yazıyordu), BR-BE-115 (Karar #54 testleri + saklama bekçisi), BR-BE-111 (`NODE_NOT_PINNED` + ajan üç yönlü 403), #57 PİNSİZ rozeti, BR-DB-60 envanteri (7 yol, 3'üne test), **confd komut enjeksiyonu:** nginx kipinde ETag/mediaId `sh -c` metnine gömülüyordu, `x$(touch /tmp/PWNED1)` nginx konteynerinde çalıştı → konumsal argüman; BusyBox wget 4xx gövdesi yazmıyor (ölçüldü) → "OKUNAMADI" mesajı.
- confd ile BR-BE-111 aynı üç bash dosyasında çakıştı; birleştirme + tam test ana ağaçta ajan ile.

### 23. Kurul #62 — BR-DB-59 `tenants` platform kolonları (ŞARTLI ONAY, (c) karışık)
- **Neden:** Karar #60 Ş60-4/5 — owner oturumunun DB düzeyinde hangi `tenants` kolonlarını yazabildiği ölçülmemişti.
- **Ölçüm:** db-lider (kaynak) — `tenants_update` owner'a `id` dışında 13 kolonu açıyor; `dealer_id = NULL` kota tetikleyicisinin erken dönüşüyle koşulsuz geçer. **Canlı (salt-okuma, 09:12 UTC):** yayın #11 `migrate --with-sample` t0007/t0012 satırlarını ezmiş, t0012 niyeti `not_delivered` → `deliver` geri dönmüş (`pbxtr-demo/docker-compose.yml:113` + `deploy/staging-yayin.sh:408` — her yayında).
  ```bash
  ssh root@176.88.41.220 "echo 'select code,status,provisioning_delivery_intent,created_at,updated_at from tenants' | docker exec -i pbxtr-postgres psql -U postgres -d pbxtr -At"
  ```
- **Karar:** 10/10 ŞARTLI. `pbxtr_app` için yazılamaz kolonlara rol tetikleyicisi (`BR-DB-62`), değişebilir platform kolonlarına tek-yazıcı bekçisi + seeder düzeltmesi (`BR-BE-148`, P0), `PUT /tenant` saklama alanını bırakır (`BR-BE-149`), `dealer_id`/`status` tetikleyicisi `BR-DB-61` ile (`BR-DB-63`), `users` ölçümü (`BR-DB-64`).
- **Commit:** `b422e502` (karar + kartlar).

### 24. BR-DB-64 ölçümü + Kurul #63 — `users`/`user_roles` yetki kaynağı (ŞARTLI ONAY)
- **Ölçüm (canlı DB, tek transaction + ROLLBACK, sonra geri okundu):** `SET LOCAL ROLE pbxtr_app`, `app.tenant_id=t0007`, cross off → M1 `demo.sahip` `scope=dealer` 1 satır, M2 `scope=global` 1 satır, M5 `INSERT user_roles(superadmin)` geçti; kontrol M3 23514, M4 0. Betik scp → çalıştır → sil (`/root/db64.sql`).
- **Karar:** 10/10 ŞARTLI; gündemdeki GUC tabanlı DB tetikleyicisi REDDEDİLDİ (meşru süper admin/bootstrap yolları cross off ile koşuyor). İki katman: jeton tutarlılık kapısı taklit dahil (`BR-BE-150`, `audit`→`enforce`), aktörden bağımsız veri kuralı (`BR-DB-66`). Canlı sayım: platform dışı global kullanıcı 0.
- **BR-DB-65 (kod okuması, pbxtr-qa):** M5-only kullanıcı superadminin tüm yetkilerini alıyor; `globalScopeOnly` istek anında denetlenmiyor; `POST /users {roles:[superadmin]}` ile tek istekte global superadmin üretilebiliyor; `SystemCommandRunner` kapsamı yalnız AST-CLI için; SMTP ayarı kapsamsız → `BR-BE-150`'ye (A) yazma kapısı, (B) merkezi filtre, (C) uç kontrolleri eklendi.
- **Commit:** `7e1468b0`, `80ff5efe`, `fcac3020` (BR-BE-153: seeder kullanıcı durumu/kara liste/operasyon verisi ezmesi).

### 25. Entegrasyon 1 — yedi yama (QA-80, BE-146, BE-115, DB-60, FE-57, BE-111, confd) commit
- **Çakışma çözümü:** confd 403 dalı önce `RED_KODU` okur, sonra BR-BE-111 üç yönlü yönlendirme; nginx kipinde gövde okunamaz → selftest'te sahte `curl` shim ile curl kipi fikstürleri (F28–F31), BusyBox gövde taklidi kaldırıldı. Selftest 144 geçti; HEAD ajanı yeni selftest ile 19 KALDI.
- **Sonuç:** format 0, build 0/0, Arch 506, Api 5177 (6 parça, `--list-tests` ile eşit), Integration 914, vitest 1836, `tsc -b` 0. Mutasyon 4/4 kırmızı.
- **Bulgu:** confd medya hedef yolu enjeksiyonu → `BR-SYS-103` (P1).
- **Commit:** `44f7f98d`, `91688270`, `2f57f8ba`, `a7b8c35e`, `a155f81f`; kartlar `afe171cd`.

### 26. Entegrasyon 2 başladı — BE-147/148/149/150 yamaları ana ağaçta
- Dört worktree yaması (`scratchpad/be147|148|149|150.patch`) `git apply --3way` ile çakışmasız uygulandı, tüm worktree'ler kaldırıldı. Derleme/test/mutasyon backend-lider ajanında; BE-150 `permissions.seed.json` değiştirdiği için st44 sha yeniden üretilecek.

### 27. Entegrasyon 2 + yayın #12 — `tekbirsoft/pbxtr:demo-70f3eb309db1`
- **Entegrasyon 2 (BE-147/148/149/150):** yama dışı düzeltmeler: `PbxtrExceptionHandler` saat `TimeProvider` (AmbientClock bekçisi), fikstürler `Tenant.Create`'e, M5 şekilli test aktörleri platform oturumuna; st44 `permissionsSha256` yeniden üretildi. Arch 552, Api 5230 (= list-tests), Integration 926, vitest 1838, `tsc -b` 0. Mutasyon 8/8 kırmızı.
- **Commit:** `8cc49f99` (BE-148), `70f3eb30` (BE-147+149+150, ortak hunk'lar tek commit).
- **Yayın:** `PBXTR_CONFD_SAPMA=0 bash deploy/yerel-yayin.sh --yayinla` exit 0.
- **Canlı doğrulama (14:43–14:46 UTC):** `migrate --with-sample` sonrası t0007/t0012 `updated_at` 08:57'de kaldı (seeder artık ezmiyor); 23514/42501/`fail:` 0; `session-scope-consistency` ok; t0012 niyeti süper admin API ile yeniden `not_delivered` (PUT 200, retention alanı gönderilmeden). API erişimi sunucuda `https://127.0.0.1/api/v1` (`-k`), parola `/home/vuo/pbxtr-demo/.env`'den değişkene okunur (konteyner env'inde yok).
- **Kapanan kartlar:** BR-QA-80, BR-DB-60, BR-BE-146, BR-BE-115, BR-BE-111, BR-BE-147, BR-BE-149; BR-BE-148 son kabul bir sonraki yayında; BR-BE-150 `audit` kipinde.

### 28. BR-SYS-103, BR-BE-151 kararı, BR-DB-66 öncülü
- **BR-SYS-103** (`af179302`): confd medya yolu doğrulaması + konumsal argüman; selftest 170/0, HEAD ajanı 21 KALDI (enjeksiyon gerçekten koştu).
- **BR-BE-151** db-lider kararı (a): bayi personeli barındıran tenant taşıması 409 `TENANT_HAS_DEALER_STAFF`; (b) otomatik personel taşıma yeni yetki davranışı olduğu için reddedildi. Yama ana ağaçta, entegrasyon 3 koşuyor. Yeni kartlar BR-FE-83, BR-DB-67 (bayi ev tenant'ı yok).
- **Canlı ölçüm:** `roles.scope` tüm sistem rollerinde `single` → BR-DB-66 kuralı kapsamı bu kolondan okuyamaz (kart güncellendi `e44192d0`).

### 29. Entegrasyon 3 + yayın #13 — `tekbirsoft/pbxtr:demo-af8b059d8ee7`
- **BR-BE-151 + BR-FE-83** (`af8b059d`): bayi personeli barındıran tenant taşıması 409 `TENANT_HAS_DEALER_STAFF`. Entegrasyonda senaryo 5'in boş geçtiği (erken dönüş, M2 yeşil) yakalandı ve karışık istekle düzeltildi. Arch 552, Api 5231, Integration 933, vitest 1839; mutasyon 5/5.
- **Ölçüm:** kural dışı SQL ile `tenants.dealer_id` değişince A personeli B listesinde görünür; B bayisinin parola sıfırlaması 403 (`PERMISSION_DENIED`).
- **Canlı (18:04 UTC):** t0012 yayın #13 migrate sonrasında `not_delivered` KALDI → BR-BE-148 son kabul. Sağlık provisioning ok ("1 tenant BİLEREK TESLİM EDİLMİYOR"), session-scope ok, loglar temiz.
- **Kapanan:** BR-BE-148, BR-BE-151, BR-FE-83.

### 30. BR-QA-83 — KRİTİK: reddedilen taklit ve SMS red denetim satırları geri alınıyordu
- **Neden:** `UnitOfWorkMiddleware` yalnız 2xx commit ediyor; `ImpersonationEndpoints` (403) ve `SmsEndpoints` kara liste/İYS/arama saati reddi (409) denetim satırını transactional `IAuditLog` ile yazıyordu → satır kayboluyordu. Bellek içi denetim ikizi bunu göremiyordu.
- **Düzeltme (yama, entegrasyon 4'te):** red satırları `IAuditSink` kuyruğuna; bekçi `DeniedAuditOutsideTransactionTests` (Api'de transactional Forbidden/Rejected/Failed yazımı yasak, gerekçeli izin listesi, bayat liste kırmızı).
- **BR-FE-82** yaması aynı entegrasyonda (oturum reddi ekranları; wallboard/masaüstü şeridindeki ham i18n anahtarı ve eksik `kapsam-tutarsiz` sebebi düzeltmeleri). Yeni kart BR-FE-84.

### 31. Entegrasyon 4 + yayın #14 — `tekbirsoft/pbxtr:demo-fc4e54560ad6`
- **BR-QA-83** (`d599fa3b`) ve **BR-FE-82** (`fc4e5456`): Arch 554, Api 5231, Integration 935, vitest 1860, `tsc -b` 0; mutasyon 11/11. Q1 mutasyonunda taklit red satırı gerçek PG'de geri alındı — eski kusur gerçek DB'de ölçülmüş oldu. Tek yama dışı düzeltme `SmsEndpoints.cs` format girintisi.
- **Canlı (21:26 UTC):** sağlık ok, loglar temiz, t0012 `not_delivered` üçüncü yayında da korundu. Kapanan: BR-QA-83, BR-FE-82. Yeni borç kartı BR-QA-84 (SMS red kalıcılığı gerçek PG'de ölçülmedi; bekçi yalnız literal biçim + yalnız Api).

### 32. BR-BE-153 — seeder operasyon verisi (yama, entegrasyon 5 koşuyor)
- **Karar:** tenant-sahipli operasyon verisi yalnız tenant o koşuda oluşturulduysa yazılır (silinen satır geri gelmez; aynı numaralı yeni kuyrukta migrate düşmez); kullanıcılar yoksa ekle; çağrı geçmişi tazeleme kalır.
- **Canlı ölçüm (dayanak):** `call_events` önek dağılımı — cdr 3727, live 3698, Asterisk epoch 293, demo 9 → `cdr-` yalnız tohum, silme gerçek çağrıya dokunmaz.
  ```sql
  select case when call_id ~ '^[0-9]+\.[0-9]+' then 'asterisk-epoch' else split_part(call_id,'-',1) end p, count(*) from call_events group by 1 order by 2 desc;
  ```

### 33. Kurul #64 — BR-DB-61/63 `tenants.dealer_id`/`status` tek yazma kapısı: ŞARTLI ONAY
- **Neden:** Karar #61 Ş61-7 ve #62 Ş62-6: istek yolundaki GUC daraltması geçiciydi; `pbxtr_app` `dealer_id`/`status`'u DB'de serbestçe yazabiliyordu.
- **Ne yapıldı:** db-lider tasarımı (`scratchpad/kurul64.md`) 10 üyeye paralel verildi; 10/10 ŞARTLI. Şeytan'ın 7 itirazı tasarımı değiştirdi: `FOR UPDATE` → `FOR NO KEY UPDATE` + tenant başına advisory lock (81 FK KEY SHARE'i bekletmesin); kolon yetkisi birinci hat, üyelik ölçütlü tetikleyici ikinci hat; owner policy platform tenant'ını literal dışarıda bırakır; `tenants_seed_update` ayrı adımda (BR-DB-69); Ş62-5 `session_user` açılış kapısı bu değişikliğe alındı.
- **Kurulda çıkan bulgu:** askıya almak santrali durdurmuyor (dialer/geri arama originate, kuyruk üyeleri Asterisk'te kalıyor) → yeni P1 **BR-AST-90**.
- **Dokunulan dosyalar:** `yonetim/kurul-kararlari.md` (Karar #64), `yonetim/backlog.md`.
- **Commit:** `eb5028c9`.

### 34. BR-BE-152 ölçümü + yeni kartlar
- **Sonuç:** KRİTİK yok; 7 yolun hiçbiri yabancı tenant satırına yazdırmıyor. RLS WITH CHECK'teki `OR app_is_cross_tenant()` dalı ilk commit'ten beri var, ADR-002 aksini söylüyor → kurul kartı BR-SEC-19. Kurul gerektirmeyenler: BR-BE-154 (`TENANT_MISMATCH`), BR-BE-155 (#52 önizleme HitCount), BR-BE-156, BR-FE-85, BR-QA-85.
- **Commit:** `8caa990d`.

### 35. Paralel worktree ajanları — yamalar (derlenmedi, entegrasyon bekliyor)
- **Kural:** ajanlara git yazma ve dotnet/vitest yasak (Entegrasyon 5 koşuyor); yama `git -C $W add -N . && git -C $W diff HEAD > scratchpad/X.patch`, sonra `git worktree remove --force` + `git branch -D`.
- **Yamalar:** `qa73.patch` (migration kapısı `DeployDbScripts.Read` çözümlemesi, selftest +23/4 mutasyon), `qa82.patch` (UserAdmin fikstürleri platform oturumu), `qa84.patch` (SMS red gerçek PG + bekçi yeniden tanımı), `fe85.patch` (denetim eylemi etiketi + parite testi; 230 eylemin 199'u etiketsiz → BR-FE-86), `be154.patch` (BE-154+155), `ast80.patch` (AMI tenant erteleme tamponu, 4807/4808), `ast90.patch` (askı: `CallPermissionGate` `TENANT_SUSPENDED`, `QueuePause(pbxtr-suspended)`), `fe87.patch` (askı metni 9 dil), `db66.patch` (users/user_roles veri kuralı), `db61.patch` (SQL adım 0-2).
- **Entegrasyon uyarıları:** FE-85 parite testi BE-154'ün yeni eylemiyle kırmızı yanar; FE-87 AST-90'dan önce girmez; DB-66 ile DB-61 01/02 şablonlarında çakışır; DB-66 `system` kullanıcısı (global, rolsüz) kuralı ihlal eder.
- **Commit'ler:** `8690041f`, `26c4ce9b`, `a97825e7`.

### 36. Canlı ölçümler (salt-okuma / ROLLBACK, root@176.88.41.220)
- **Komutlar:** betik scp → `docker exec -i pbxtr-postgres psql -U postgres -d pbxtr -At` → rm.
- **BR-DB-61 açığın kaydı (ROLLBACK):** `SET LOCAL ROLE pbxtr_app`; t0007 oturumundan `SET dealer_id=<başka bayi>` UPDATE 1, `SET dealer_id=NULL` UPDATE 1; bayi oturumundan t0012 `SET status` UPDATE 1; geri okumada satırlar değişmedi.
- **BR-DB-66:** 7 sistem rolü `scope=single`; platform dışı global kullanıcı 0; sistem kodlu özel rol 0; `system` kullanıcısı global + rolsüz.
- **BR-BE-158:** yayın #14 logunda `NoAmbientTransactionException` 0, `PostCallSms` 0 (kural tanımlı tenant ölçülmedi).
- **BR-DB-61 adım 0 (geçici PG16):** (A') GUC yan tümcesi owner'a `42501 permission denied to set parameter` → eklenmedi; taşıma kilidi altında `call_attempts` INSERT p99 0,060 ms.

## Açık kalanlar / sonraki adım (15 Eylül gecesi)
- Entegrasyon 5 (BE-153) → yayın #15; ardından 11 yamanın seri entegrasyonu (tek dotnet yükü).
- BR-DB-61 adım 3 C# ajanı çalışıyor.
- BR-AST-90 (e) route-decision kurul sorusu; BR-DB-66 iki sapma db-lider onayı; migrate `lock_timeout` panel bekletmesi (3,7 sn).

### 37. Entegrasyon 5 + yayın #15 — BR-BE-153 canlıda (`demo-d151999623b3`)
- **Neden:** SampleDataSeeder her yayında tenant operasyon verisini ve kullanıcı durumunu geri alıyordu.
- **Ne yapıldı:** insert-only kapı; entegrasyon ilk kurulum eksiksizlik kontrolünü (8 tablo × 2 tenant) ekledi.
- **Sonuç:** Arch 588, Api 5231, Integration 936, vitest 1860. Canlı: seed sonrası `tenants`/`demo.*` `updated_at` değişmedi, t0012 `not_delivered` korundu.
- **Commit:** `d1519996`, kart `ace56fc4`.

### 38. Kurul #65 — dört açık karar
- **Karar:** (1) askıdaki tenant'a gelen çağrı `announce_hangup` (BR-AST-91); (2) BR-DB-66 yeniden çalışma; (3) migrate yeniden deneme + KRİTİK bulgu: `MaintenanceCli` bakım kilidini alamayınca 0 ile çıkıyordu (BR-OPS-08); (4) BR-SEC-19 (B) şimdi, (A) BR-DB-70 ölçümüne bağlı.
- **Kurulda canlı ölçüm:** `has_parameter_privilege('pbxtr_owner','app.tenant_id','SET')` = f → BR-DB-66 yamasındaki `SET "app.tenant_id"` yan tümcesi canlı migrate'i düşürecekti. Snapshot yazıcısı yok; kuyruk `joinempty=no`; `ensure_future_partitions` kendi `lock_timeout=5s`'ini taşıyor.
- **Commit:** `6baf04ac`.

### 39. Entegrasyon 6 + yayın #16 (`demo-4cb4fcfa9de8`)
- **Kartlar:** BR-QA-73/82/84, BR-AST-80/89/90, BR-BE-154/155, BR-FE-85, BR-FE-87 (metin).
- **Olay:** entegrasyon ajanı Api parça 5'te ~4 saat takıldı (testhost 3,8 GB); süreç öldürüldü, `--blame-hang` ile yeniden koşuda takılma tekrarlamadı. Derleme 09:04'te ikiliyi yeniden ürettiği için Api 6 parça TAZE ikiliye karşı yeniden koşuldu (5262/5262). Parça 6'da tek seferlik testhost çökmesi (blame toplayıcı), blame'siz yeniden koşu 84/84.
- **Sonuç:** Arch 595, Api 5262, Integration 948, vitest 1866. Canlı: `DECISION_UNAVAILABLE` 0, `pbxtr_app` kendi tenant satırını RLS altında görüyor. BR-DB-69 ön koşulu: `tenants` n_tup_upd yayın #16 seed'inden sonra 79→79.
- **Commit'ler:** `e146ba6a`, `78a6882c`, `ba470ef8`, `a653bb15`, `4cb4fcfa`; kartlar `47cd5343`.

### 40. Entegrasyon 7 — BR-DB-61/63 + BR-DB-66 + BR-OPS-08 + BR-AST-91
- **Ön birleştirme (worktree, db-lider):** migration sırası 120000 → 121000 → 122000; personel sayımı tek fonksiyon (`pbxtr_tenant_dealer_staff_count`), kilit anahtarı tek fonksiyon (`pbxtr_tenant_staff_lock_key`); gerçek owner rolüyle Up→Down→Up md5 birebir.
- **Entegrasyonda bulunan 9 kusur:** 02-guards dondurulmuş hash bayattı (626 Integration kırmızı, canlı migrate düşerdi); `CALLER-CROSS` sınıflandırıcı; `pg_stat_activity` başka rolün `wait_event`'ini göstermiyor → `pg_locks`; `text || "char"`; oracle geometrisi; `53300 too many clients` (test PG `max_connections=200`, kart BR-QA-87).
- **Canlı ön kontrol S1–S12 (salt-okuma):** system hesabı inert, S2–S6 ihlal 0, backfill 3 rol satırı, son migration `20260914120000`.
- **Sonuç:** Arch 605, Api 5311, Integration 967, vitest 1870, kapi_53 16/16.
- **Yayın #17:** mesai içinde `PBXTR_MESAI_ICI_YAYIN=1` ile (kullanıcının "onay almadan en hızlı üretime" talimatı; Ş65-3.7 açık onay bayrağı).
- **Commit:** `37276de1`, kartlar `5e3584e6`.

### 41. Yayın #17 canlıda (`demo-ea567d11bb2e`)
- **İlk deneme kapılarda düştü (canlıya dokunmadan):** kapi_10 yorum satırlarındaki `SET "app.` desenini yakaladı → yorumlar yeniden yazıldı, 122000 blob'u `migration-contract-onay.blobs`'ta yeniden hesaplandı; `pbxtr-demo/db/00-roles.sql` bayattı → `deploy/db/00-roles.sql`'den kopyalandı. Commit `ea567d11`.
- **Canlı doğrulama:** yeni migrate adımı "bekleyen 3 → deneme 1/3 başarılı → bekleyen 0"; `pbxtr_app` `SET dealer_id=NULL` → permission denied, `SET name=name` → UPDATE 1; `POST /tenants/t0007/status` aynı değer → 204 denetimsiz; `roles.scope` backfill; `pbxtr_user_scope_guard()` 0; log 23514/42501/55P03 0.
- **Kapanan:** BR-DB-61/63/66, BR-OPS-08, BR-AST-91. Kartlar `8c1940c3`.

### 42. Yedi paralel worktree ajanı → Entegrasyon 8
- **Neden:** kalan maddeleri tek entegrasyon + tek yayında toplamak (worktree ajanları derleme/test koşmaz, eşzamanlı yük yasağı).
- **Yamalar (scratchpad, `git add -N . && git diff HEAD`):** qa87 (ClearPool, max_connections 100), ops10 (`deploy/lib/pbxtr-migrate-adimi.sh`, kapi_54), db69 (`20260915123000_TenantsSeedUpdatePolicyRemoval`), fe87c (`suspension-impact` + `TenantSuspendDialog`), be157 (BE-157/158/161), db71 (`TenantAnnouncementLanguage`), be156 (çapraz kip yazma reddi).
- **Ajan ölçümleri:** BE-157 kısmen doğru — sahip rolü 403, açık yol özel rol (`tenant.write` platforma özel değil); BE-158 doğru — adım 5c commit edilmiş DbContext'i kullanıyordu; BE-161 kartın saydığından geniş — Sınıf B `call-permission` da sayacı geri alıyordu; BE-156 — superadmin başlıklı SMTP/SMS/parola/TOTP yazımları 200 dönüyordu; DB-69 — `tenants_sys_update` seed_update'in üst kümesi, kaldırma owner yüzeyini daraltmıyor.
- **Birleştirme:** altı yama `git apply --3way` ile çakışmasız; DB-69 ve DB-71 aynı migration zaman damgasını (123000) taşıyordu → DB-71 `20260915124000`'e yeniden adlandırıldı (Designer, TenancyConfigurations yorumu, st44 kanonik/rapor JSON). BE-156 index uyuşmazlığı yüzünden düz `git apply` ile.
- **Ara ölçüm (ilk 6 yama):** `dotnet build pbxtr.sln` 0 uyarı/0 hata, `tsc -b` 0, vitest 208 dosya / 1884 test.
- **Pano:** "Kod yazildi" durum eşlemesinde `backlog` çıkıyordu → "Kod bitti (…, entegrasyon 8 bekliyor)" kullanıldı (in progress). Yeni kartlar BR-DB-72 (sys_update daraltma), BR-OPS-12 (artifact yolunda mesai kapısı), BR-BE-162 (`queueMembersOnPbx` null), BR-BE-163 (edge retry çift sayım, çift SMS riski, adım 5c maliyeti), BR-AST-92 (santralde `hizmet-disi-<dil>` dosyaları yok). Kartlar `ad75a0f1`, `a10a3d30`; ClickUp fark 0.
- **Sonraki:** Entegrasyon 8 (backend-lider, ana ağaç) → commit → yayın #18 (ortak migrate kütüphanesinin ilk gerçek kullanımı).
