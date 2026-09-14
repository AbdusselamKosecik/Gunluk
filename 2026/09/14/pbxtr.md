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
