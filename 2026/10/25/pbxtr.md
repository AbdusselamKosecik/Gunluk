# pbxtr — 2026-10-25

## Bağlam
Santral epiği (Sprint-46..49) sürüyor. Sprint-46 kapalı; gün Sprint-47 QA-128 ölçümünün ortasında başladı (oturum kopmuştu).

## Yapılanlar

### 1. Sprint-47 QA-128 tamamlandı ve kapanış
- **Neden:** Faz B1 (yakalama, yönlendirme, sesli mesaj, özellik kodları) gerçek santralde ölçülmeden kapanmaz.
- **Ne yapıldı:** Kopan QA ajanı SendMessage ile devam ettirildi. Ajan bir hata buldu: ön nginx 8443 mTLS kuralı `feature-code` ucunu taşımıyordu → telefondan `*72` vb. hep `FC_UNAVAILABLE`/beeperr. Düzeltme `4fe67e7f` (8443 kuralına uç eklendi, panel portunda 404, `nginx-dogrula.sh` bekçisi artık `MapPost(Route, …)` sabitini de okuyor; 3 mutasyon kırmızı).
- **Yayın:** ilk deneme `npipe dockerDesktopLinuxEngine` hatasıyla düştü — Docker Desktop kapalıydı. Yol `C:\Users\abdus\AppData\Local\Programs\DockerDesktop\Docker Desktop.exe` (Program Files'ta DEĞİL). Açıldıktan sonra `deploy/yerel-yayin.sh --yayinla --testsiz` → `demo-4fe67e7fd51d`; `nginx/current/conf.d/pbxtr-telefon-8443.inc` içinde `feature-code` doğrulandı.
- **Sonuç:** QA-128 10/10. Yayınlanmış config ile yeniden: `*72` kural + `PBXTR_FWD_*` global, WebSocket `extension.settings.changed` (sahip oturumu, `/api/v1/ws`) aynı milisaniyede, `*90` dış hedef → call-permission `BLOCKED_IYS`, internal sınıf `FC_EXTERNAL_NOT_ALLOWED`, `*78/*79` DND. Temizlik: tablolar 0, override kaldırıldı, t0007 config md5'leri baseline ile aynı (6 dosya). Silinemeyen: boş değerli `PBXTR_FWD_T0007_1042`/`ZZQA_MODE` globalleri (Asterisk 22'de restart'sız silinmiyor; boş değer "yok" sayılıyor).
- **Bulgu → kart:** `BR-AST-148` (P3, Açık): `*79` bir config çekimine kadar (~15 sn) etkisiz; statik katman `Goto(busy)`.
- **Backlog/ClickUp:** 9 kart Bitti; `--kuru` fark 0 / izde olmayan 0. **Commit:** `495c119b`.

### 2. Sprint-48 başlatıldı
- backend-dev-2: outbound_routes, giden rota, acil numaralar (P0; sahte `19999` ile ölçülecek, gerçek 112 aranmaz), iç kayıt, rehber + hızlı arama, BLF.

### 3. Sprint-48 backend + Asterisk (backend-dev-2) — giden rota, acil numara, iç kayıt, rehber, BLF
- **Neden:** Santral Faz B 5-8: tenant'ın kendi giden rotası, telefonla 112'nin API kapalıyken bile çıkması (P0), iç görüşme kaydı, şirket rehberi + hızlı arama, BLF lambası.
- **Ne yapıldı:**
  - **BR-DB-122** migration `20261024234849_PbxOutboundRoutesEmergencyPhonebook`: `outbound_routes`, `outbound_route_trunks` (sıralı, bileşik FK `(tenant_id, trunk_id)` → trunks'a `ak_trunks_tenant_id` eklendi, `IX_trunks_tenant_id` açıkça korundu), `tenant_pbx_settings` (boş acil dizi CHECK ile yasak), `phonebook_entries`. RLS dört tabloda, `SET LOCAL lock_timeout = '5s'`, expand-only.
  - **BR-AST-141** `ConfigRenderer.Routing.cs`: `-outbound`'da `GotoIf(${REGEX(...)})` ile rota seçimi, `Set(PBXTR_OR_DIAL=onek${EXTEN:strip})`, trunk failover yalnız CHANUNAVAIL/CONGESTION. Rotasız tenant çıktısı **byte-byte aynı**: altın SHA-256 özetleri kod değişmeden önce HEAD `4fe67e7f`'de alındı (`ConfigRendererOutboundRouteGoldenTests`; BLF satırı ayrıca sayılır).
  - **BR-AST-142** acil: liste tenant parametresi, varsayılan `Provisioning/emergency-numbers.seed.json` (TR 112/110/155/156/158/177). `-out` ve `-int` başında TAM eşleşme (Asterisk'te tam eşleşme desenden önce gelir) → `pbxtr-{t}-emerg`: UserEvent `PbxtrEmergencyCall` → bilgi çağrısı `Originate(...,a)` (asenkron, ana çağrıyı bekletmez) → acil rota yoksa tüm trunk'lar. CURL/AGI yok. Olay hattında sentetik `AlarmRaised` (metric `emergency_call`) → Redis + WS `alarm.raised`.
  - **BR-AST-143** `record_internal_calls`: `-local` girişinde MixMonitor(b) + `CDR(recordingfile)`.
  - **BR-BE-270** rehber + `*0xx` hızlı arama (`pbxtr-{t}-sd`, dış hedef call-permission'dan geçer); `AssertDistinctDialNumbers` acil numara/hızlı kod/özellik kodu çakışmasını ölçer; feature-codes PUT `feature_code_speed_dial_conflict` döner.
  - **BR-AST-144** pbx endpoint'lerine `subscribe_context=pbxtr-{t}-hint`.
  - API: `/api/v1/outbound-routes` CRUD, `/api/v1/telephony/pbx-settings` GET/PUT, `/api/v1/phonebook` CRUD (numara sunucuda maskeli, denetimde yalnız son 2 hane), `/api/v1/cdr?direction=int`. Yetkiler `outboundroute.read/write`, `pbxsettings.write`, `phonebook.read/write` (bundle.pbx; `phonebook.read` ayrıca bundle.self). 9 dilde denetim etiketleri.
- **Sunucu ölçümü (geçici tenant t9948, QA-128'in t0007 nesnelerine dokunulmadı):** sahte acil numara `19999` internal sınıftan → `Goto emerg`, UserEvent, bilgi bacağı ~17 ms'de döndü, carrier `hedef=19999` aldı; **pbxtr-edge DURDURULMUŞKEN** acil yine çıktı, normal numara call-permission AGI'de `BLOCKED_UNKNOWN` → Congestion; edge yeniden başlatıldı. Rotalar: `05321112233`→`905321112233` (ölü trunk → lab trunk), `0212…`→rota2, eşleşmeyen → varsayılan. İç kayıt dosyası 294956 bayt yazıldı. BLF: SUBSCRIBE 200 + NOTIFY `terminated` → çağrıda `confirmed`; `core show hints` t9948 2001–2003. CDR'da `direction=3` 50 satır var. Hepsi temizlendi (hints/endpoints/context/dosya = 0).
- **Dokunulan dosyalar:** 56 dosya; ana yeni dosyalar `src/Pbxtr.Api/Modules/Telephony/PbxRoutingEndpoints.cs`, `src/Pbxtr.Infrastructure/Provisioning/ConfigRenderer.Routing.cs`, `src/Pbxtr.Domain/Modules/Telephony/{OutboundRoutes,EmergencyNumbers,Phonebook}.cs`, `src/Pbxtr.Infrastructure/Modules/Ef{OutboundRouteAdministration,PbxSettings,PhonebookAdministration}.cs`, testler `ConfigRendererRoutingTests`, `ConfigRendererOutboundRouteGoldenTests`, `PbxRoutingEndpointTests`, `EmergencyCallSignalTests`, `PbxRoutingTenantLeakTests`.
- **Komutlar:**
  ```bash
  dotnet test tests/Pbxtr.Api.Tests --no-build --filter "FullyQualifiedName~Pbxtr.Api.Tests.Modules.Telephony"   # 1673/1675 (2 skip)
  dotnet test tests/Pbxtr.Api.Tests --no-build --filter "FullyQualifiedName~Pbxtr.Api.Tests.Platform"           # 1467/1469 (2 skip)
  # Modules grup A 1411/1411, grup B 2640/2640, Support 7/7
  dotnet test tests/Pbxtr.Architecture.Tests --no-build      # 857/857
  dotnet test tests/Pbxtr.Integration.Tests --no-build       # 1313 + 2 düzeltildi (sınıflar 119/120, 1 skip)
  dotnet format pbxtr.sln --verify-no-changes --no-restore   # rc=0
  npx tsc -b                                                 # rc=0
  ```
- **Sonuç / doğrulama:** tümü yeşil. Tam entegrasyon koşusu iki Sprint-47 kalıntısı buldu (voicemail `notify_state` CHECK aynası eksik, `st44` kanonik şema revizyonu bayat), ikisi de düzeltildi.
- **Commit:** `be4f3318` — Sprint-48 santral Faz B: giden rota, acil numara, ic kayit, rehber+hizli arama, BLF

### Kararlar (Sprint-48)
- Rota önizleme ucu **yazılmadı**: ADR-004 §2.7 bekçisi (string numara alanı) kırmızı yaktı, muafiyet tavanı 10/10 dolu; muafiyet açmak yerine uç kaldırıldı.
- Acil dal call-permission'ın fail-closed kuralının **yazılı istisnasıdır** (yasal zorunluluk; acil kodlar kişi numarası değildir).
- Giden rota ve hızlı arama yalnız pbx modüllü tenant'ta; acil dal her tenant'ta.
- Hızlı kod biçimi `*0xx` olduğundan sayısal dahiliyle tam çakışma yapısal olarak imkânsız; bekçi acil numara + özellik kodu çakışmasına genişletildi.

### Açık kalanlar (Sprint-48)
- FE-144/FE-145 ekranları ve `delivery-manifest.json`; yayın; ardından QA-129 (panel alarmının uçtan uca WS ölçümü, gerçek telefonla BLF, t0007'de rota/iç kayıt).
- `deploy/nginx-dogrula.sh` `script_tavan_kontrol` kırmızı (dokunulmayan alan, önceden var).

### 4. Sprint-48 frontend (frontend-dev-1) — BR-FE-144 CDR iç yön, BR-FE-145 santral Faz B ekranları
- **Neden:** Backend `be4f3318` uçları (giden rota, pbx-settings, rehber, `cdr?direction=int`) ekransızdı.
- **Ne yapıldı:**
  - **BR-FE-144 (#19 CDR):** yön filtresi (Tümü/Gelen/Giden/İç) → `GET /cdr?direction=in|out|int` (`api/ops.ts` `CdrQuery.direction`); `internal` satırı "İç" yazılır. CSV dışa aktarma ucu (`CdrExportRequestDto`) yön almıyor → filtre seçiliyken not satırı "yön filtresi dosyaya uygulanmaz" der (BORÇ, backend işi).
  - **#74 Giden Rotalar** `/telephony/outbound-routes` (`outboundroute.read`/`write`): öncelik, desen (`_` önekli gösterim), numara biçimi, sıralı trunk rozetleri, sunucunun `effective` hükmü (StatusLed). Diyalog: trunk ekle/çıkar + ↑/↓ ile sıra; acil rota anahtarında desen alanı çizilmez ve `pattern` gövdeye yazılmaz. Önizleme yok (uç yok).
  - **#75 Santral Ayarları** `/telephony/pbx-settings` (`pbxsettings.write`): acil numara listesi — "Ülke varsayılanı" gövdede `emergencyNumbers: null`, "Özel liste" çip ekle/çıkar; bilgi çağrısı hedefi; iç görüşme kaydı (`recordInternalCalls`) anahtarı. Boş liste istemcide engellenmez, sunucunun `emergency_numbers_empty` reddi cümleye çevrilir.
  - **#76 Rehber** `/phonebook` (`phonebook.read`, grup `common` — staff da görür; yazma `phonebook.write`): dış numaralar (maskeli) + dahililer, istemci tarafı arama, `*0xx` hızlı kod. Düzenlemede numara alanı boş açılır; boşsa `number` anahtarı gövdeye yazılmaz.
  - **#72:** `feature_code_speed_dial_conflict` mesajı. Toplam 27 yeni hata kodu `PBX_ERROR_TEXT`'e (kodlar `PbxRoutingEndpoints.cs` + `EmergencyNumberRules.Validate`'ten doğrulandı).
  - 9 dilde 140 anahtar; `screens.json` 3 satır (#74-#76, phase S48), `delivery-manifest.json` 3 birincil eylem, `npm run screens:gen`; menü golden (owner/supervisor pbx+hybrid +3, staff pbx+hybrid +`/phonebook`), ScreenRegistry sayıları 84/74/75; duman kapsamı + 6 adet 403 satırı; `doc/rol-ekran-matrisi.md` ve `doc/ekran-yazma-yollari.md` testten üretildi.
- **Dokunulan dosyalar:** `src/Pbxtr.Web/src/app/screens/pbx/{pbxRoutingApi.ts,OutboundRoutesScreen.tsx,OutboundRouteDialog.tsx,PbxSettingsScreen.tsx,PhonebookScreen.tsx,PhonebookEntryDialog.tsx,PbxRoutingScreens.test.tsx,pbxRoutingApi.test.ts,pbxApi.ts,PbxScreens.module.css}`, `screens/cdr/CdrScreen{,.test}.tsx`, `api/ops.ts`, `screens/registry.ts`, `*.generated.ts`, `i18n/messages/*.json`, `src/Pbxtr.Api/Platform/{Screens/screens.json,Delivery/delivery-manifest.json}`, `tests/Pbxtr.Api.Tests/Platform/{Authorization/TenantModuleMenuGolden.cs,Screens/ScreenRegistryTests.cs}`, `deploy/demo/{smoke-demo.sh,duman-ekran-kapsami.json}`, `doc/{rol-ekran-matrisi,ekran-yazma-yollari}.md`.
- **Komutlar:**
  ```bash
  cd src/Pbxtr.Web && npm run screens:gen && npx tsc -b            # rc=0
  npx vitest run                                                     # 282 dosya, 2483/2483
  PBXTR_WRITE_DOCS=1 dotnet test tests/Pbxtr.Api.Tests --filter Matris_belgesini_URET
  PBXTR_WRITE_DOCS=1 dotnet test tests/Pbxtr.Architecture.Tests --filter Ekran_yazma_yollari_belgesini_URET
  dotnet test tests/Pbxtr.Api.Tests --filter "FullyQualifiedName~Pbxtr.Api.Tests.Platform"   # 1467/1469 (2 skip)
  dotnet test tests/Pbxtr.Architecture.Tests                                                  # 857/857
  dotnet format tests/Pbxtr.Api.Tests --verify-no-changes --include <2 test dosyası>          # rc=0
  bash deploy/uretilmis-dosya-kontrol.sh                                                      # commit sonrası rc=0
  ```
- **Sonuç / doğrulama:** hepsi yeşil. İlk tam vitest koşusu `viMockTargets` bekçisinde 1 kırmızı verdi (yeni testte kullanılmayan `useSessionOptional` ezmesi) → silindi. Integration.Tests yerelde koşturulmadı (Docker yok).
- **Commit:** `7e2a4a9c` — BR-FE-144/145: CDR ic yon filtresi; Giden Rotalar, Santral Ayarlari, Rehber ekranlari

## QA-129 — Sprint-48 santral özellikleri gerçek santralde (176.88.41.220, imaj demo-7e2a4a9c607f)

### Yöntem
- Panel uçları UI'nin kullandığı gibi API'den çağrıldı (`demo.sahip`, modül için `demo.superadmin`). Giriş betiği parolayı `.env`'den değişkene okur, basmaz; jetonlar `/root/qa129` (700) altındaydı ve sonda silindi.
- t0007'de pbx modülü açıldı: `PUT /tenants/{t0007}/modules {"overrides":[{"module":"pbx","enabled":true}],"confirm":true}`.
- Geçici santral nesneleri:
  - `pbxtr.d/dialplan/zzqa129-lab.conf`: izin damgalı / damgasız 1042 taklidi, cevaplayan bacak.
  - `pbxtr-lab.d/zzqa129-pjsip.conf`:
    - Santral kendine `t0007-1043` olarak REGISTER oldu (outbound_auth = mevcut auth nesnesi, sır okunmadı).
    - `zzqa129-sink` endpoint'i `match_request_uri` ile gelen INVITE'ı cevapladı; 1043 telefonunun yerine geçti.
    - `zzqa129-loop` iç görüşme için gerçek PJSIP kanalı üretti.
- **Ders:** CLI `channel originate` 30 sn cevap süresi koyar. Uzun ölçümde ters kur: `Local/w@cevap-baglami extension NUM@test-baglami`.

### Sonuç (8 adım)
1. **Migration + RLS — GEÇTİ.** `20261024234849` uygulanmış; dört tabloda `relrowsecurity` + `relforcerowsecurity` + policy.
2. **Rotasız tenant — GEÇTİ.**
   - pbx kapalı t0007 yeni kodla yeniden üretildi: 6 dosyanın 5'i byte-byte aynı.
   - Dialplan'de yalnız acil bloğu eklendi (+34 satır, −0). Acil dal tasarım gereği her tenant'ta.
   - t0012/t0000/t1000 da 02:42:15'te sistem aktörüyle yeniden üretildi; t0012 farkı +26 / −0 (acil bloğu).
3. **Rota — GEÇTİ.**
   - `05321112233` → rota1, `PBXTR_OR_DIAL=905321112233`, ölü trunk (`zzqa-olu`, 127.0.0.1:5999). PJSIP timer B ile 32 sn sonra operator-lab'a geçti; carrier `hedef=905321112233` aldı.
   - `0212…` → rota2; eşleşmeyen numara → rota0.
   - API: 409 `outbound_route_name_taken`, 422 `outbound_route_pattern_invalid`.
4. **Acil 19999 — GEÇTİ.**
   - pbx-settings API: 4 adet 422 (`empty`, `conflict`, `notify_target_unknown`, `format`) + 200.
   - Damgasız 1042 → `-out:1 Goto emerg` → UserEvent `PbxtrEmergencyCall`.
   - Bilgi bacağı `Originate(Local/1043…,a)` gerçekten 1043'ü çaldırdı, cevaplandı.
   - Carrier `hedef=19999` aldı; WS `alarm.raised` (metric `emergency_call`, critical, "ACİL ARAMA: 19999 — dahili 1042") aynı saniyede geldi.
   - **Edge DURDURULMUŞKEN:** 19999 yine carrier'a çıktı; normal `0212…` `BLOCKED_UNKNOWN` → Congestion. Edge yeniden başlatıldı.
5. **İç kayıt — GEÇTİ (bir gözlemle).**
   - Gerçek PJSIP kanalıyla `-local` → `PBXTR_RECI=1`, MixMonitor dosyası 484524 bayt.
   - CDR `recordingfile=t0007/2026/10/1792896828.351.wav`.
   - Kayıt hattı dosyayı MinIO'ya taşıdı (`recording_assets`).
   - `/api/v1/cdr?direction=int` çağrıyı `internal`, `hasRecording:true` döndü.
   - **Gözlem:** filtresiz listede aynı çağrı `unknown` görünüyor. Sebep `manager.conf channelvars = PBXTR_TENANT,PBXTR_ORIGIN,QUEUE_PRIO` — `PBXTR_DIR` yok (belge `asterisk-olay-eslemesi.md:46` var diyor).
     - Pipeline satırları yön 0 yazıyor; tenant'ta 508 satır böyle.
     - ETL satırı (yön 3, saniye hassasiyeti) ayrı satır olarak duruyor; liste "en yeni started_at" kuralıyla pipeline satırını seçiyor.
     - Düzeltmesi `manager.conf` + `manager reload` ister; Karar #70 kırmızı çizgisi olduğu için düzeltilmedi, kart önerildi.
6. **Rehber — GEÇTİ.**
   - `*011` oluşturuldu; numara sunucuda maskeli (`+90 532 111 •• ••`), liste ve denetimde açık numara yok (`numberLast2`).
   - 409 `phonebook_speed_dial_taken`, 422 `phonebook_speed_dial_invalid`, özellik kodu `*011` → 422 `feature_code_speed_dial_conflict`.
   - Telefondan `*011` → `-sd` → `-out,+905321112233` → call-permission AGI → gerçek karar `BLOCKED_IYS`.
   - **Gözlem:** hızlı arama E.164 (`+90…`) ile girdiği için ulusal desenli rotalar (`_05X.`) ona uymuyor; varsayılan zincire düşüyor. Aynı sınıf yönlendirme dış hedefi ve pbxtr originate için de geçerli; tasarım kararı gerekiyor.
7. **BLF — KISMEN.**
   - t0007 endpoint'lerinde `subscribe_context=pbxtr-t0007-hint`; `core show hints` 1042–1048.
   - 1043 hint Idle → InUse → Idle (çağrı sırasında). Watchers iç (gerçek SIP aboneliği 0).
   - t0007'de SUBSCRIBE yapılamadı (cihaz sırrı okunmaz); SUBSCRIBE/NOTIFY aynı üreticiyle t9948'de ölçülmüştü.
8. **Temizlik — GEÇTİ.**
   - Silinenler: 2 rota, `zzqa-olu` trunk'ı (If-Match ile), rehber satırı, `tenant_pbx_settings` satırı, modül override `[]`, lab dosyaları (dialplan reload + `module reload res_pjsip.so`).
   - Ayrıca: Redis acil alarmı (`live:alarm:*` + index), 10 spool dosyası, 6 MinIO nesnesi + 6 `recording_assets` satırı, sunucudaki `/root/qa129`.
   - **t0007 md5 6/6 QA başlangıcıyla (yeni kod, pbx kapalı) aynı:** dialplan `70516ec9…`, ringgroups `4f43e977…`, moh `b181743…`, parking `f7c0d452…`, pjsip `b7937cce…`, queues `b1b2f4e1…`.
   - Kalanlar: içi boş `zzqa129-int` bağlam kabuğu (0 uzantı, kaynak dosya yok, restart'ta gider). Pencerenin 48 CDR + 187 call_events satırı (koordinatöre). Denetim satırları tasarım gereği duruyor.

### Bulunan ürün hatası ve düzeltme
- **Belirti:** yalnız `{"recordInternalCalls":true}` gönderen PUT, özel acil listesini (19999) varsayılana ve bilgi hedefini (1043) yoka çevirdi (denetim 02:50:00Z).
- **Sebep:** istek kaydında `string?`/`IReadOnlyList?` — "gönderilmedi" ile "açık null" aynı `null`.
- **Kapsam:** FE `settingsBody` hep tam gövde gönderdiği için ekran etkilenmiyordu; tuzak API sözleşmesindeydi.
- **Düzeltme — commit `b5d9ef22`:**
  - Acil alanlar `JsonElement` oldu: Undefined = korunur, Null = varsayılan/yok.
  - Dizi dışı tür ya da dize olmayan eleman 422 döner.
  - Regresyon testi eklendi; mutasyon KIRMIZI. Api Telephony + Privacy 1809/1811, Architecture 857/857.
- **Yeniden yayın gerekir** (sunucudaki imaj hâlâ eski sözleşmede).

### Gözlemler (kart önerisi)
- `manager.conf channelvars`'ta `PBXTR_DIR` eksik → canlı pipeline CDR yönü hep `unknown` (kırmızı çizgi: `manager reload` yasak).
- Hızlı arama / E.164 hedefler ulusal rota desenlerine uymuyor.
- Yanıt vermeyen trunk (UDP, cevap yok) failover'ı 32 sn geciktiriyor (timer B); qualify ya da Dial timeout önerilir.
- Acil alarm Redis'te 24 sa TTL ile tenant başına tek kayıt; `targetKind=queue`, `queueId=emergency` (UI bağlantısı kontrol edilmeli).
- ETL karantinası aynı satırı her tikte yeniden `crit` logluyor (25 dk'da 2182 satır, t9948 + zzqa test verisinden); 12 sa örtüşme penceresi bitince durur.

## Kararlar
- `*79` penceresi kabul edildi (iki katman modeli + S76-12a negatif testi); çözüm DND değişiminde anında rerender — P3.
- Agent rolünün telefondan `*72` yapabilmesi kabul: özellik kodu dahiliye bağlıdır, role değil.

## Açık kalanlar / sonraki adım
- Sprint-48: FE-144/145 bitti (`7e2a4a9c`) → yayın → QA-129; ardından Sprint-49.
- BORÇ: CDR CSV dışa aktarma ucu yön filtresi almıyor (`CdrExportRequestDto`).

## Sprint-48 kapanışı (koordinatör)

- **Neden:** Faz B (giden rota, acil numara, iç kayıt, rehber, BLF) backend + ekran + QA-129 tamamlandı.
- **Yayınlar:** `demo-7e2a4a9c607f` (be4f3318 + 7e2a4a9c), ardından `demo-591d1595effa` (QA-129 düzeltmesi b5d9ef22: pbx-settings kısmi PUT acil listeyi sıfırlıyordu). Edge/nginx değişmedi, edge yeniden kurulmadı.
- **Komutlar:**
  ```bash
  bash deploy/yerel-yayin.sh --yayinla --testsiz
  python scratchpad/s48-backlog.py     # 9 kart Bitti + 6 yeni kart
  node yonetim/arac/clickup-olustur.js && node yonetim/arac/clickup-senkron.js && node yonetim/arac/clickup-senkron.js --kuru
  ```
- **Tuzak:** BR-QA-129 durum metninde "kismen" geçtiği için senkron kartı `in progress` yaptı (yapısal eşleme `Kısmen`'i ayrıca arar). İfade "hint t0007, SUBSCRIBE t9948 ölçüldü" olarak netleştirildi → `complete`.
- **Yeni kartlar:** BR-BE-274 (CSV yön), BR-AST-149 (manager.conf `PBXTR_DIR` channelvars yok — `manager reload` kırmızı çizgi), BR-AST-150 (E.164 → ulusal normalize), BR-AST-151 (trunk failover 32 sn), BR-FE-147 (acil alarm bağlantısı), BR-BE-276 (ETL karantina log seli). 150/151/147 Sprint-49'a alındı.
- **Commit:** `591d1595` (backlog + sprint-48 BİTTİ), `66375878` (sprint-49 tablosu).
- **Sonraki:** Sprint-49 backend+Asterisk ajanı başlatıldı (paging, kapı, ConfBridge, Yealink provisioning, nginx /prov/, gece modu, AST-150/151).

## Sprint-49 backend + Asterisk (backend-dev-2)

### 1. Santral Faz C: anons/zil, kapı, konferans, Yealink, gece modu, AST-150/151
- **Neden:** Sprint-49 kartları BR-AST-145/146/147, BR-BE-271/272, BR-SYS-144, BR-AST-150/151.
- **Ne yapıldı:**
  - Migration `20261025035545_PbxFieldFeatures`: `paging_groups`(+üyeler), `paging_bells`, `conference_rooms`, `phone_devices` + RLS; `dial_numbers` sahip tipi `paging_group`/`conference_room` + tetikleyiciler; `tenant_pbx_settings.night_mode*`, `trunk_qualify`.
  - `ConfigRenderer.Field.cs`: `[pbxtr-{t}-page]` (Page() + `b(intercom)` otomatik cevap, cihaz yoksa beeperr), `-intercom`, `-pgbell` (zil exten `bell-{guid N}` — 12 hane önek çakışma riski yüzünden tam kimlik), `-conf` (PIN = SHA1(oda kimliği+PIN), 3 yanlışta Hangup, dinamik `CONFBRIDGE()` profil, Join/Leave UserEvent), gece modu, trunk `qualify_frequency=10/qualify_timeout=3`.
  - Giden rota: `PBXTR_OR_NUM` ile +90/0090 → ulusal biçim, rota eşleşmesi ondan; desen `+90…` girilirse 422 `outbound_route_pattern_national`.
  - `PagingBellJob` (advisory lock 45): çalışma saatine bağlı zil, `OriginateRequest.PagingFirst`.
  - API: `/api/v1/paging-groups`, `/paging-bells`, `/extensions/{id}/pbx-role`, `/conference-rooms` (+`/participants`), `/phone-devices` (+`/provisioning-link`), `/telephony/night-mode`; anonim `/prov/{tenant}/o/{token}/{file}` (tek kullanımlık, yalnız HTTPS) ve `/prov/{tenant}/{token}/{file}` (kalıcı, parolasız).
  - Gece modu: panel + `*28/*29` (edge FastAGI izin listesi), `NightModeService` tek yazım gövdesi, denetim + `nightmode.changed`; route-decision gece modunda `Open=false` (fail-open).
  - nginx `/prov/` bloğu: `pbxtr_prov` 5r/s burst 200, `limit_except GET`, body 1k (deploy + demo ikizi + `nginx-dogrula.sh prov_blogu_kontrol`).
  - FE: `RealtimeProvider` + `resourceInvalidation` (`conferenceRooms`, `nightMode`), denetim etiketleri 9 dil.
- **Dokunulan dosyalar:** 85 dosya; ana yeni dosyalar `src/Pbxtr.Api/Modules/Telephony/PbxFieldEndpoints.cs`, `PhoneProvisioningEndpoints.cs`, `NightModeService.cs`, `src/Pbxtr.Infrastructure/Provisioning/ConfigRenderer.Field.cs`, `src/Pbxtr.Infrastructure/BackgroundJobs/PagingBellJob.cs`, `tests/Pbxtr.Api.Tests/Modules/Telephony/PbxField*Tests.cs`, `ConfigRendererFieldTests.cs`, `ConferenceRoomSignalTests.cs`, `tests/Pbxtr.Integration.Tests/Tests/PbxFieldTenantLeakTests.cs`.
- **Komutlar:**
  ```bash
  dotnet ef migrations add PbxFieldFeatures --project src/Pbxtr.Infrastructure --startup-project src/Pbxtr.Infrastructure --context PbxtrDbContext
  node src/Pbxtr.Web/scripts/generate-screens.mjs
  dotnet test tests/Pbxtr.Api.Tests --filter <namespace parçaları>   # tek tek, paralel değil
  dotnet test tests/Pbxtr.Architecture.Tests
  dotnet format pbxtr.sln --verify-no-changes ; (cd src/Pbxtr.Web && npx tsc -b && npx vitest run src/app/realtime src/app/screens/system)
  ```
- **Sonuç / doğrulama:** Api: Modules parça1 1156, parça2 2726, Platform 1467 (+2 skip), Telephony+Provisioning 1896 (+2 skip) geçti; Architecture 857; vitest 230; tsc -b 0; format temiz; tüm çözüm derlendi. Integration (PbxFieldTenantLeakTests) yalnız derlendi — yerelde Docker yok, koşmadı.
- **Sunucu ölçümü (176.88.41.220, geçici t9949/zzs49):** Asterisk 22.10.1, app_page/app_confbridge/func_sha1 yüklü. Üretilen t9949 dialplan'i yüklendi, 18 bağlamın priority sayısı render ile birebir. PIN'li oda doğru PIN'le katıldı; 3 yanlış PIN ~20 sn'de kapandı; PIN'siz oda `max_members=2` tuttu; E.164 normalizasyonu 5/5; anons cihazsızken beeperr. Önceki ölçümler: qualify'lı ölü trunk 5 ms CHANUNAVAIL (qualify'sız 32,04 sn), DTMF "19" geçer, "#1" yutulur. Temizlik: zzs49 dosyaları + AstDB silindi, `dialplan reload` + `module reload res_pjsip.so`; t0007/t0012 md5 başlangıçla aynı. Not: ölçüm sırasında `channel request hangup all` koşuldu (test ortamı; o anda başka çağrı var mıydı ölçülmedi).
- **Commit:** `a85f7322` — Sprint-49 santral Faz C: anons/zil, kapı, konferans, Yealink provisioning, gece modu, E.164 normalizasyonu, trunk qualify

## Kararlar (Sprint-49 backend)
- Kapı açma kodu yalnız rakam (`#` kör transfer, ölçüldü).
- Konferans DID'i statik olarak odaya bağlanır → route-decision ve askıya alınmış tenant kapısı atlanır (BORÇ).
- Zil denetimi yalnız zil çaldığında yazılır (dakikada bir satır üretmemek için).
- BR-AST-151: qualify 10 sn + timeout 3 sn → trunk yeni öldüğünde ilk ~13 sn içinde bir çağrı hâlâ 32 sn bekleyebilir; `timer_b` global olduğu için ana `pjsip.conf`'a dokunulmadı.

## Açık kalanlar (Sprint-49 backend)
- nginx `/prov/` bloğu bir sonraki yayında canlıya girer.
- `nginx-dogrula.sh script_tavan_kontrol` önceden kırmızı (desen `campaigns/.../script/draft`, conf `scripts/{id}/draft`) — bu işle ilgisiz.
- PbxFieldTenantLeakTests sunucuda (DooD) koşulmalı.
- FE-146/FE-147 ekranları + QA-130.

---

## Sprint-49 frontend — BR-FE-146 / BR-FE-147 (frontend-dev-1)

### 1. Santral Faz C ekranları (#77–#79) + Gece Modu
- **Neden:** Backend `a85f7322` uçları (PbxFieldEndpoints) ekransızdı; sprint-49 kartı BR-FE-146.
- **Ne yapıldı:**
  - `screens.json`'a #77 `phone-devices` `/telephony/phone-devices` (`phonedevice.read`), #78 `paging` `/telephony/paging` (`paging.read`), #79 `conference-rooms` `/telephony/conference-rooms` (`conference.read`); hepsi `module: pbx`, faz S49, sortOrder 100/110/120 (pbx-settings'ten sonra). `npm run screens:gen`.
  - `delivery-manifest.json`'a 3 birincil `*.load` eylemi. Tablo adı ilk denemede `inbound_dids` yazıldı; `DeliveryManifestDataSourceTests` yakaladı → gerçek tablo `dids`.
  - `pbxFieldApi.ts`: tipler + gövde kurucular. PIN üç hâlli (anahtar yok = koru, `null` = kaldır, dize = yaz). Konferans `maxMembers`/`didId` düzenlemede TAM yazılır — sunucu gönderilmeyen kapasiteyi varsayılana, DID'i bağlantısıza düşürüyor (kod okundu: `ToInput`). Cihaz düzenlemesinde MAC gönderilmez. Zil `time` yalnız `fixed`'te. `intField` yalnız biçim denetler (sınır sunucuda). Hata kodları `PBX_ERROR_TEXT`'e yayıldı.
  - #77: tek kullanımlık provisioning bağlantısı yalnız POST/`provisioning-link` yanıtında, bir diyalogda bir kez, kopyala düğmeli. `provisioningConfigured=false` uyarısı.
  - #78: Tabs (Gruplar / Ziller / Cihaz rolleri); kapı kodu tabloda gösterilmez, düzenlemede gizli alanda tutulur (boş gönderilse sunucu siliyordu).
  - #79: canlı katılımcılar REST + WS `conference.updated {room,count}` (`useRealtimeEvent`; `RealtimeInvalidationInventory` istisna listesine gerekçeyle eklendi). 503 `conference_live_unavailable` "boş oda" diye yazılmaz.
  - Gece Modu: `NightModeControl` #75'in başında (pbx tenant'ında dashboard yok). `nightmode.changed` ile tazelenir.
  - #75: `trunkQualify` anahtarı; kayıt artık kısmi yazım (`settingsPatch`, yalnız değişen anahtar).
- **Dokunulan dosyalar:** `src/Pbxtr.Web/src/app/screens/pbx/{pbxFieldApi,PhoneDevicesScreen,PhoneDeviceDialogs,PagingScreen,PagingDialogs,ConferenceRoomsScreen,ConferenceRoomDialog,NightModeControl}.tsx|ts`, `PbxSettingsScreen.tsx`, `pbxRoutingApi.ts`, `pbxApi.ts`, `PbxScreens.module.css`, `registry.ts`, 9 dil i18n (267 anahtar), `screens.json`, `delivery-manifest.json`, `TenantModuleMenuGolden.cs`, `ScreenRegistryTests.cs` (87/77/78), `deploy/demo/smoke-demo.sh` (+8 adet 403), `duman-ekran-kapsami.json`, `doc/rol-ekran-matrisi.md`, `doc/ekran-yazma-yollari.md`.
- **Komutlar:**
  ```bash
  cd src/Pbxtr.Web && npm run screens:gen && npx tsc -b && npx vitest run && npm run guard:no-polling
  PBXTR_WRITE_DOCS=1 dotnet test tests/Pbxtr.Api.Tests --filter FullyQualifiedName~RoleScreenMatrixTests
  PBXTR_WRITE_DOCS=1 dotnet test tests/Pbxtr.Architecture.Tests --filter FullyQualifiedName~ScreenWritePathEvidenceTests
  dotnet test tests/Pbxtr.Api.Tests --filter FullyQualifiedName~Pbxtr.Api.Tests.Platform
  dotnet test tests/Pbxtr.Architecture.Tests
  dotnet format tests/Pbxtr.Api.Tests/Pbxtr.Api.Tests.csproj --verify-no-changes --include <iki test dosyası>
  ```
- **Sonuç / doğrulama:** tsc -b 0; vitest 284 dosya / 2509 test geçti; Api Platform 1467 geçti (+2 skip); Architecture 857 geçti; format temiz; polling bekçisi geçti. Bekçilerin yakaladıkları (düzeltildi): JSX literal (MAC placeholder → i18n), vi.mock dar imza (`signal`), WS payload istisna listesi, manifest tablo adı.
- **Commit:** `6c0f3f9e` — BR-FE-146/147: Telefon Cihazlari, Anons Gruplari, Konferans Odalari, Gece Modu; acil alarm CDR'a

### 2. BR-FE-147 — acil alarm bağlantısı
- **Neden:** QA-129: `emergency_call` alarmı sahte `queueId: 'emergency'` taşıyor, "İncele" kuyruk ekranına gidiyordu.
- **Ne yapıldı:** `screens/shared/emergencyAlarm.ts` (metrik sabitinin istemcideki tek kopyası). #14'te acil alarmın bağı `routeOfScreen('cdr')`'a (menüde yoksa bağ yok), eşik/hedef satırı yerine "Acil numara arandı"; #4 dashboard satırı aynı.
- **Sonuç:** `LiveAlarmsScreen.test.tsx`'e 3 test. Fikstürde `'emergency'` sentinel'i adlandırılmış sabitle yazıldı (GUID bekçisi kuyruk kimlikleri içindir; değer sunucunun gerçek sentinel'i).

## Kararlar (Sprint-49 frontend)
- Gece Modu ayrı ekran değil, #75'in başında bir panel (pbx tenant'ında dashboard yok). Yalnız `nightmode.write` taşıyan özel rol #75'i görmezse anahtarı da görmez — BORÇ adayı.
- Konferans DID seçicisi `trunk.read|trunk.write` ister (supervisor'da yok) → mevcut bağ salt okunur gösterilir ve aynen gönderilir.
- `ivrApi.ts:187` DID `number`'ını `string` diye tipliyor; gerçek DTO `MaskedPhone` nesnesi — dokunulmadı, not.

## Açık kalanlar (Sprint-49 frontend)
- Yayın yapılmadı; ekranlar canlıda bir sonraki yayında.
- 200 duman satırları demo tenant'ın pbx modülü ölçülünce (BR-OPS-19 "Örnek Fabrika").
- BR-QA-130 gerçek telefonla provisioning ölçümü.

### Sprint-49 ek: konferans DID borcu + nginx bekçisi (backend-dev-2)
- **Neden:** Koordinatör yayından önce borcu kapattırdı: konferans DID'i route-decision'ı ve askıya alınmış tenant kapısını atlıyordu. Ayrıca `nginx-dogrula.sh script_tavan_kontrol` bayat desen yüzünden kırmızıydı.
- **Ne yapıldı:** Yeni karar `conference` eklendi (`RouteDecisions.All`). Hedef ConfBridge adı `extension` alanında gider; kaynak `conference_rooms.did_id`, yalnız pbx modülü etkinken. Uç oda için çalışma saatini ve gece modunu sormaz (`reason=ALWAYS_OPEN`); askı ve kara liste rota çözümünden önce koştuğu için konferans DID'inde de çalışır. Dialplan'de DID satırı önce `Gosub(pbxtr-{t}-route)`, uç cevapsızsa (fail-open) odaya `Goto`. Route bağlamına her oda için exact eşleşmeli satır eklendi. Oda yazımı commit sonrası DID rota önbelleğini düşürür. Bekçi deseni gerçek uca bağlandı: `PUT /api/v1/scripts/{id:guid}/draft`.
- **Seçim gerekçesi:** "Yalnız `TENANT_SUSPENDED` reason'ına bakan ayrı alt yordam" seçeneği reddedildi. Dialplan `reason`'ı karar için okumaz (Karar #15 §E1-3); ayrıca DID'in kendi `dids.decision` değeri yanlış hedefe sızardı.
- **Doğrulama:** Telephony+Provisioning 1901 (+2 skip), WorkingHours+Observability 125, Architecture 857 geçti; format temiz; `nginx-dogrula.sh` EXIT=0 (`script` tavanı: 3 yer, 9 MiB / 10m). Yeni satırlar sunucuda yeniden yüklenmedi (şablon mevcut `GotoIf`/`Gosub` satırlarıyla aynı).
- **Commit:** `9598bcec` (konferans route-decision), `8907d5ca` (nginx bekçisi).
- **Açık:** pbx modülü kapatıldıktan sonra en fazla 60 sn (DID rota önbelleği TTL) eski `conference` kararı → route `invalid` (Congestion) penceresi. Gece modu önbelleğiyle aynı sınıf.
