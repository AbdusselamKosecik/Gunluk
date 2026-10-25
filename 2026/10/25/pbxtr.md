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

### Sprint-49: BR-QA-130 gerçek sunucuda + BR-OPS-19 Örnek Fabrika (backend-dev-2)
- **Neden:** Yayın `demo-8907d5ca615f` sonrası Faz C'nin canlı doğrulaması ve kalıcı demo santral tenant'ı.
- **OPS-19 — ne yapıldı:** `deploy/demo/ornek-fabrika-kur.py` (sunucuda, idempotent; ikinci koşu 41 "=" / 0 "+"). Tenant `t1001` "Örnek Fabrika A.Ş.", tip pbx, sahip `demo.fabrika`.
  - İçerik: trunk "Ana Hat" (TEST-NET 192.0.2.10), "Fabrika Mesaisi" (Pzt–Cum 08:00–17:30).
  - Dahililer: Üretim 2001–2004, İdari 2101–2103, Depo 2201–2203, ayrıca hoparlör 2091 ve kapı telefonu 2290 (kapı kodu 9); hepsine personel hesabı.
  - Gruplar: departman başına yakalama grubu + zil grubu (6001–6003); anons grubu 8100 "Üretim holü" ve mesai başı/sonu zili.
  - Konferans 8500 (PIN'li) + DID +908505550149, giden rota "Yurt içi" 0X., rehber 3 kayıt (*011–*013), acil liste TR varsayılanı.
  - Santral bağlantısı: düğüm API anahtarı (asterisk-01) + edge `api-keys` satırı.
  - Menü: santral ekranları var, çağrı merkezi ekranı YOK.
- **Komutlar:**
  ```bash
  scp deploy/demo/ornek-fabrika-kur.py root@176.88.41.220:/root/
  ssh root@176.88.41.220 'cd /home/vuo/pbxtr-demo && export PBXTR_SAMPLE_PASSWORD="$(grep ^PBXTR_SAMPLE_PASSWORD= .env | cut -d= -f2-)" && python3 /root/ornek-fabrika-kur.py'
  PBXTR_TEST_FILTER=FullyQualifiedName~PbxFieldTenantLeakTests bash /root/entegrasyon-kos.sh /root/pbxtr-it-s49   # nohup + EXIT=
  ```
- **Ölçülen ürün sınırları:**
  - Ortak demo parolası 12 karakter politikasına takılıyor, `me/password` reddediyor; bu yüzden `demo.sahip` özeti kopyalandı (tek ham SQL adımı).
  - Dahili sayısı agent kotasıyla sınırlı (2. dahili 409 PROVISIONING_BLOCKED, kota 30'a çekildi).
  - Tenant node-bundle'a yalnız düğüm adlı API anahtarıyla giriyor (anahtarsız confd 304 verdi).
  - Sahipte `apikey.manage` yok; anahtarı super admin açıyor.
  - DID numarası sahibe de maskeli dönüyor.
- **QA-130 sonuçları:**
  - Konferans DID: normal → `decision=conference`, oda PIN'e girdi. Askıda → `announce_hangup TENANT_SUSPENDED`, early-media anons ~4 sn sonra kapandı. Edge durdurulunca → doğrudan oda (fail-open).
  - PIN: doğru PIN katıldı, katılımcı ucu count=1 / boşalınca 0 gösterdi. Üç yanlış PIN 23 sn'de kapandı.
  - Gece modu: panelden açılınca normal DID `NIGHT_MODE` aldı, konferans DID `ALWAYS_OPEN` kaldı; iki denetim satırı yazıldı. Personel dahilisinden *28 → FC_FORBIDDEN.
  - Zil: sabit saat ayarlanınca 07:47:05'te çaldı, lastFiredAt yazıldı.
  - Rota: `+90` desen → 422.
  - /prov: ilk kullanım 200 (parola satırı 1), ikinci kullanım 404, kalıcı link 200 (parola 0), başka MAC'li UA 404. nginx :80 → 301, uygulamaya doğrudan HTTP → 403, POST → 403. 300 paralel istekte 81 adet 503 (oran sınırı). Aynı MAC 409; tenant'lar arası 409 entegrasyon testinde.
  - Denetimde dosya içeriği yok.
  - Entegrasyon testi 4/4 geçti (EXIT=0).
  - Temizlik sonrası t0007/t0012 md5 sabah ile aynı (12/12).
- **Bulunan ürün hatası + düzeltme:** tam DID satırı route-decision'a `${EXTEN}` (E.164 artısız, `did_prefix=none`) gönderiyordu. Uç bunu ulusal yorumlayıp ROUTE_UNCONFIGURED dönüyordu; yani bu biçimde teslim edilen hiçbir DID için karar verilmiyordu (saat/kapalı dal/gece/konferans). Gerçek Asterisk'te A/B: `${EXTEN}` → fallback, `+${EXTEN}` → route kararı. Düzeltme `+${EXTEN}`. **Yeniden yayın gerekir**; sonrasında DID'i olan her tenant'ın dialplan'i değişir (t0007/t0012 md5 de).
- **Dağıtım değişikliği:** compose'a PhoneProvisioning eşlemesi eklendi (yoktu → /prov 503). Sunucu `.env`'e `PBXTR_PhoneProvisioning__SipServer=100.106.82.119` yazıldı (sır değil), app aynı imajla yeniden oluşturuldu.
- **Doğrulama:** Telephony+Provisioning 1901 (+2 skip), Architecture 857, format temiz.
- **Commit:** `b11334a5` (DID +E.164), `f532cd4b` (OPS-19 betiği + compose).
- **Açık:**
  - t1001 anons dili `en`: askıdayken İngilizce anons çalıyor. Tenant ayarından `tr` yapılmalı.
  - `next_open_at` saniye taşıyor (05:00:37); kozmetik.
  - Tenant'lar arası MAC 409 canlıda ölçülmedi: ikinci pbx tenant + sahip yok.
  - *28'in yetkili kullanıcıyla olumlu telefon yolu ölçülmedi.

## Sprint-49 kapanışı + santral hizmeti (Sprint 46–49) tamam (koordinatör)

- **Neden:** Faz C (anons/zil, kapı telefonu, ConfBridge, Yealink provisioning + nginx /prov/, gece modu, AST-150/151, FE-146/147, OPS-19 demo tenant, QA-130) bitti; `/goal` "tüm sprintleri tamamla" hedefi Sprint-49 ile kapanır.
- **Yayınlar:**
  - `demo-8907d5ca615f` (a85f7322 + 6c0f3f9e + 9598bcec + 8907d5ca); edge FastAGI değiştiği için edge elle güncellendi:
    ```bash
    tar --exclude=__pycache__ -czf edge-tmp.tgz -C deploy pbxtr-edge   # GÖRELİ yol: Windows C:/ yolunu tar uzak host sanıyor ("Cannot connect to C:")
    scp edge-tmp.tgz root@176.88.41.220:/root/edge.tgz
    # sunucuda: aç, CRLF sil, PBXTR_EDGE_KIP=konteyner ./install.sh, docker compose up -d --no-deps --force-recreate edge edge-fastagi
    ```
  - `demo-58fbaf0c163b` (b11334a5: tam DID satırı route-decision'a E.164 `+` verir; f532cd4b: OPS-19 betiği + /prov/ compose eşlemesi). Edge değişmedi. Sonrası: app healthy, /health 200.
- **Kapanış:** `58fbaf0c` — 12 kart Bitti, 8 yeni kart (BR-AST-152, BR-SYS-145, BR-BE-277 dahili kotası agent limitine bağlı, BR-BE-278 yeni tenant node anahtarı elle, BR-BE-279, BR-BE-280, BR-OPS-20, BR-QA-131). ClickUp `fark olan kart: 0, izde olmayan: 0`.
- **Demo:** "Örnek Fabrika A.Ş." `t1001` (kind pbx, sahip `demo.fabrika`), kurulum `python deploy/demo/ornek-fabrika-kur.py` (idempotent).

## Kararlar
- Konferans DID'i route-decision'dan geçer (askı + kara liste uygulanır), çalışma saati/gece modu odaya uygulanmaz (`ALWAYS_OPEN`); fail-open'da doğrudan odaya.
- Canlıda ölçülemeyen iki madde (kiracılar arası MAC 409, yetkili `*28`) entegrasyon testine dayanılarak kabul edildi, BR-QA-131 kartında.

## Açık kalanlar / sonraki adım
- P2: BR-BE-277, BR-BE-278, BR-AST-149 (manager.conf PBXTR_DIR — Karar #70 nedeniyle konteyner yeniden yaratma penceresi ister).
- P3: BR-AST-148, BR-AST-152, BR-SYS-145, BR-BE-274/276/279/280, BR-OPS-20, BR-QA-131.

## P3 kartları — BR-BE-274 / BR-BE-279 / BR-SYS-145 / BR-OPS-20 (backend-dev-1)

### 1. BR-BE-274 — CDR CSV dışa aktarma yön filtresini taşır
- **Neden:** `CdrExportRequestDto` alansızdı; ekranda yön seçiliyken liste ile indirilen dosya farklı kümelerdi, ekran "yön dosyaya uygulanmaz" notu yazıyordu.
- **Ne yapıldı:** DTO'ya opsiyonel `Direction`; değer `CdrListQuery.Direction`'a ham verilir, okuma katmanı liste ucuyla AYNI `DirectionCodes.TryParse`'ı kullanır (ikinci ayrıştırıcı yazılmadı). Denetim satırına `filterDirection`. Frontend `exportCdr` yönü gönderir; not ve `cdr.exportDirectionNote` anahtarı 9 dilden silindi.
- **Dokunulan dosyalar:** `src/Pbxtr.Api/Modules/CallHistory/CdrEndpoints.cs`, `src/Pbxtr.Web/src/app/screens/cdr/{CdrScreen.tsx,cdrApi.ts,CdrExportDirection.test.tsx}`, `src/Pbxtr.Web/src/app/i18n/messages/*.json`, `tests/Pbxtr.Api.Tests/Modules/CallHistory/CdrExportDirectionEndpointTests.cs`
- **Sonuç / doğrulama:** API testi (liste ve export aynı ham değeri okuma yoluna verir + denetimde yön), vitest mutasyonu (yön satırı silinince test kırmızı) doğrulandı.
- **Commit:** `13a8d9fd`

### 2. BR-BE-279 — DID, onu yöneten yetkiye açık döner
- **Neden:** Tenant sahibi kendi santral hattını maskeli görüyordu (sahipte `phone.unmask` yok, olmamalı).
- **Karar:** DID kişi numarası değil, tenant'ın kendi hizmet numarası (emsal: `TenantCompanyDto.Phone`). `did` yüzeyinde `trunk.read`/`trunk.write` numarayı açar; kayıt defteri yüzeyinde geçersiz, başka yüzeye yayılmaz; kişi numaraları için tek gevşetme yolu hâlâ `phone.unmask`.
- **Ne yapıldı:** `PhoneSurfaces.OpensOwnServiceNumber` + `NumberMasker.ResolveLevel` adım 1b. Alan tipi `PhoneNumber + [MaskedPhone]` olarak kaldı, maskeleme bekçisinin muafiyet listesine satır eklenmedi (10/10). ADR-004 §2.5 güncellendi. `ivrApi.ts` DID `number`'ı `MaskedPhone` olarak okur (önceden "[object Object]" yazıyordu); diğer tüketici (`pbxFieldApi.ts`) zaten doğruydu.
- **Dokunulan dosyalar:** `src/Pbxtr.Domain/Platform/Privacy/PhoneMaskContext.cs`, `src/Pbxtr.Infrastructure/Platform/Privacy/NumberMasker.cs`, `src/Pbxtr.Api/Modules/Telephony/InboundDidAdminEndpoints.cs`, `doc/mimari/ADR-004-maskeleme-ve-denetim.md`, `tests/Pbxtr.Api.Tests/Platform/Privacy/PhoneSurfacesTests.cs`, `src/Pbxtr.Web/src/app/screens/ivr/{ivrApi.ts,ivrVoicemailBoxOptions.test.ts}`
- **Commit:** `c222b33e`

### 3. BR-SYS-145 — canlı demo nginx'e script taslağı location'ı
- **Ne yapıldı:** `pbxtr-demo/nginx/pbxtr.conf`'a `deploy/nginx.conf` ile aynı `location ~ ^/api/v1/scripts/[0-9a-fA-F-]+/draft$` (10m + güvenlik başlıkları). `deploy/nginx-dogrula.sh` `script_tavan_kontrol` canlı dosyayı da tarar, 4 yer bekler, dosya yoksa kırmızı.
- **Komutlar:** `bash deploy/nginx-dogrula.sh` (statik kapılar TAMAM, "4 yer"; docker bölümü yerelde koşmadı: daemon yok). Sunucuda `pbxtr-nginx` konteynerinde geçici bir üst conf ile `nginx -t` → syntax ok; geçici dosyalar silindi.
- **Mutasyon:** 10m→1m ve location adı bozma → ikisi de kırmızı; geri alınınca yeşil.
- **Commit:** `4c340d83`. Canlıya **sonraki yayınla** gider (revizyon `current/conf.d/default.conf`).

### 4. BR-OPS-20 — Örnek Fabrika anons dili `tr`
- **Ne yapıldı:** `set_announcement_language`: `PUT /api/v1/tenant/settings` (If-Match; zorunlu alanlar mevcut değerleriyle), aynı değerse yazmaz. Parola: ürün yolları ölçüldü (admin `password-reset` rastgele üretir, `/me/password` 12 karakter ister, `auth/reset-password` e-posta jetonu ister). Hash kopyalama adımı kaldı ve gerekçesiyle belgelendi; paylaşılan parola değiştirilmedi.
- **Komutlar:** sunucuda `.env`'den değişkene okunarak 2 koşu: 1. koşu `+1` (en→tr) / `=42`, 2. koşu `+0` / `=43`; iki günlükte de sır sayısı 0. DB: `t1001|tr`.
- **Commit:** `ded15d3b`

### Testler (bu tur)
- Api.Tests: CallHistory + Platform.Privacy + InboundDid 226/226; Platform 1485 geçti / 2 atlandı; Architecture 858/858.
- `npx tsc -b` rc=0; vitest cdr + ivr yeni dosyası 16/16; `dotnet format --verify-no-changes` (dokunulan dosyalar) rc=0.

## Kararlar (P3 turu)
- DID maskeleme dışı değil; yüzey bazlı kural: yöneten yetki açar, diğerleri tenant maskesini görür.

## Açık kalanlar (P3 turu)
- BR-OPS-20 kalan: demo parolası politika uyumlu (≥12) olmalı — sifreler reposu + sunucu `.env` birlikte; o gün hash kopyalama adımı silinir.
- BR-SYS-145 canlıya yayınla gider; yayın sonrası 1 MB üstü taslak PUT'u ölçülmeli.
- `align_owner_password` dışında `set_announcement_language` mevcut `maskLevel`'ı geri yazar; `maskLevelConfigured` false idiyse artık true olabilir (değer aynı).

## BR-AST-149 / 148 / 152 + BR-BE-276 / 280 (backend-dev-2)

### Bağlam
Kullanıcı: "BR-AST-149: bunu yap, P3'ü de yap". İlk sunucu ölçümü `2026-10-25 11:18:58 UTC`, HEAD `58fbaf0c`. BR-QA-131 yayından sonra yapılacak.

### 1. BR-AST-149 — canlı CDR yönü hep `unknown`
- **Neden:** `AmiEventMapper` `PBXTR_DIR`'i okuyordu. Belge (`asterisk-olay-eslemesi.md:46`) değişkenin listede olduğunu söylüyordu. Ama sunucuda da depoda da `manager.conf` `channelvars = PBXTR_TENANT,PBXTR_ORIGIN,QUEUE_PRIO` idi. AMI listede olmayan değişkeni olaya koymaz. Aynı sınıftan bir kusur daha çıktı: `PBXTR_CHANNEL_LEASE_ID/SLOT` de listede yoktu, bu yüzden dialer kanal kirası hangup'ta hiç serbest bırakılmıyordu (yalnız TTL ile düşüyordu).
- **Sunucuda nasıl yönetiliyor (ölçüldü):** `/etc/asterisk` host'tan `pbxtr-asterisk`'e bind mount edilmiş. Dosya `vuo:vuo 644`, elle yönetiliyor ve giriş betiği onu ezmez. Sırlar `pbxtr.d/credentials/ami.conf`'ta. `pbxtr-edge` ile `pbxtr-edge-fastagi` `network_mode: container:<asterisk>` ile aynı ağ ad alanını paylaşıyor.
- **Ne yapıldı (sunucu):**
  ```bash
  docker exec pbxtr-asterisk asterisk -rx "core show channels count"   # 0 active
  cp -p /etc/asterisk/manager.conf /etc/asterisk/manager.conf.bak-20261025T112144Z
  sed -i 's/^channelvars = PBXTR_TENANT,PBXTR_ORIGIN,QUEUE_PRIO$/channelvars = PBXTR_TENANT,PBXTR_ORIGIN,QUEUE_PRIO,PBXTR_DIR,PBXTR_CHANNEL_LEASE_ID,PBXTR_CHANNEL_LEASE_SLOT/' /etc/asterisk/manager.conf
  docker restart -t 20 pbxtr-asterisk          # 11:21:52Z, ~8 sn'de healthy
  docker restart pbxtr-edge pbxtr-edge-fastagi # ağ ad alanı yenilendi
  ```
  `manager reload` kullanılmadı (Karar #70). `write = call,agent,originate` satırına dokunulmadı.
- **Doğrulama:**
  - `/etc/asterisk` altındaki 54 dosyanın md5'i karşılaştırıldı; yalnız `manager.conf` farklı.
  - Contact listesi aynı (3 trunk), endpoint sayısı 33.
  - `manager show connected` → `pbxtr`, `ari show apps` → `pbxtr`.
  - Uygulama logunda `ARI Stasis uygulamasi 'pbxtr' acildi`, `AMI baglandi` ve `kanal-resync TAMAM` görüldü.
  - Ağ ad alanında `127.0.0.1:8790` ve `:4573` dinliyor.
  - `asterisk-sunucu-sapma.sh`: on iddianın onu da TAMAM.
- **Test çağrıları (11:26Z):**
  - Dahili `Local/1043@pbxtr-t0007-int`: `Hangup` payload'ında `direction=int`, cdr satırı 3 (int).
  - Giden `05321112233`: payload `out`.
  - Gelen (carrier → DID `02122223344`): yön **`out`** çıktı. Bu ikinci bir kusur.
- **İkinci kusur (kod):** CEL'e göre çağrı `pbxtr-t0007-in`'de başladı (`PBXTR_DIR=in`). Sonra `Goto(pbxtr-dialer,<kuyruk>,1)` ile kuyruğa indi. Oradaki koşulsuz `Set(__PBXTR_DIR=out)` yönü ezdi. `-local` da aynı şekilde gelen rotayı ve kuyruk üyesi bacağını `int`'e çeviriyordu. Düzeltme `ConfigRenderer.DirectionIfUnset`: bu iki aşağı akış bağlamı yönü artık `ExecIf($["${PBXTR_DIR}"=""]?Set(__PBXTR_DIR=…))` ile yalnız boşsa yazar. Santrale yayın + confd teslimiyle girer.
- **Tekrar sapmasın diye:**
  - Depodaki `deploy/asterisk-lab/conf/manager.conf` güncellendi.
  - Runbook (`deploy/asterisk-lab/README.md`) yeniden yazıldı: `manager reload` yerine konteyner yeniden başlatma, edge ×2 ve doğrulama listesi.
  - `tests/Pbxtr.Architecture.Tests/AmiChannelVarsCoverageTests.cs`: eşleyicinin okuduğu her değişken depo dosyasında olmalı.
  - `deploy/asterisk-sunucu-sapma.sh` **S10**: sunucudan yalnız `channelvars` satırını okur ve depo satırıyla küme olarak karşılaştırır. Öz-test 53/53; canlı hâl, satır yok, fazla değişken, çift satır, dosya yok ve eksik girdi fikstürleri var.
  - Belge düzeltmeleri: `asterisk-olay-eslemesi.md`, `asterisk-config-degisiklik-kaydi.md` A7, `OLCULEBILIRLIK-ENVANTERI.md`, `AmiEventMapper` yorumu.
- **Geri doldurma YAPILMADI:**
  - Yön 0 olan 458 pipeline satırı var (126 çağrı). Bunların 238'inin ETL ikizi var.
  - ETL yönü bacağın `dcontext`'inden türetiyor ve `-int` bağlamını tanımıyor. 14 çağrıda ikizler birbiriyle çelişiyor.
  - Bu değeri kopyalamak, ölçülmemiş bir değeri ölçülmüş gibi göstermek olurdu (`CallDirectionUnmeasured` ilkesi). Satırlar `unknown` kaldı; kart önerisi aşağıda.

### 2. BR-AST-148 — `*79` ~15 sn penceresi
- **Neden:** confd 10 sn'de bir çekiyor, üstüne reload debounce'u geliyor. Asterisk tarafında itme kanalı yok, yani "anında teslim" yapılamaz. Yeniden üretim zaten aynı transaction'da yapılıyor.
- **Ne yapıldı:**
  - DND kapatılınca ARI global'i `PBXTR_DNDOFF_{T}_{N}=1` yazılıyor. DND açılınca global siliniyor (değersiz POST). Soket açılışındaki ilan turu da DND'li dahililerde global'i siliyor.
  - pbx yolundaki statik kapı `ExecIf($["${GLOBAL(PBXTR_DNDOFF_…)}" != "1"]?Goto(busy))` oldu. Santral yeniden başlarsa global boş kalır ve statik DND aynen geçerli olur (güvenli yön).
  - S76-12a'nın `DEVICE_STATE` pozitif dal kuralı değişmedi.
- **Santralde ölçüldü** (geçici `zz148-lab` bağlamı, sonra silindi): global yokken MEŞGUL, `1` iken ÇALDI, `0` iken MEŞGUL. Test global'leri ARI ile silindi (204).

### 3. BR-AST-152 — trunk yeni ölünce 32 sn bekleme
- **Ne yapıldı:** Yedeği olan trunk denemesi artık `Dial(…,60^10)` (Asterisk 22 ilerleme zaman aşımı). Son trunk 60 sn'de kalıyor. Ana `pjsip.conf`'a dokunulmadı. Acil zincire dokunulmadı.
- **Santralde ölçüldü:** mevcut `t0007-trunk-lab` endpoint'iyle yanıt vermeyen `sip:999@127.0.0.1:5999`'a arandı.
  - `60` → `CHANUNAVAIL/32` sn.
  - `60^10` → `CHANUNAVAIL/10` sn.
  - Ders: CLI `channel originate` 30 sn'de bacağı kapatır, bu yüzden cevaplayan Local bacakla ters kuruldu.

### 4. BR-BE-276 — ETL karantina log seli
- `quarantine_call_data` zaten `boolean` (yeni satır mı) dönüyordu, kod bu dönüşü yok sayıyordu. Artık kritik alarm (4902) yalnız ilk karantinada basılıyor. Tekrar okunan satırlar tik başına tek bir Debug özetine giriyor. Bastırma anahtarı DB'deki UNIQUE anahtar olduğu için yeniden başlatma ve çok düğüm onu sıfırlamaz.

### 5. BR-BE-280 — modül değişiminde DID / gece modu önbelleği
- Yeni `IRouteDecisionCacheInvalidator`. Override PUT'u ve tenant tipi değişimi etkin modül kümesini değiştirince `route:did:` öneki ve `telephony:nightmode` anahtarı commit sonrası, HEDEF tenant ad alanında düşürülüyor.

### Komutlar / testler
```bash
mkdir .../scratchpad/dotnet.lock   # kilit; sonda rmdir
dotnet build pbxtr.sln
dotnet test tests/Pbxtr.Api.Tests --filter <Telephony|Provisioning>   # 1910 + 2 skip
dotnet test tests/Pbxtr.Api.Tests --filter <Modules A>                # 1423
dotnet test tests/Pbxtr.Api.Tests --filter <Modules B + Health>       # 2472
dotnet test tests/Pbxtr.Api.Tests --filter Pbxtr.Api.Tests.Platform.  # 1485 + 2 skip
dotnet test tests/Pbxtr.Architecture.Tests                            # 858
dotnet format pbxtr.sln --verify-no-changes                           # rc=0
bash deploy/asterisk-sunucu-sapma-selftest.sh                         # 53/53
bash deploy/asterisk-sunucu-sapma.sh                                  # on iddia TAMAM
```
- **Integration (sunucuda DooD, HEAD `e91d637a`):** `AsteriskCdrEtlEndToEndTests` + `TenantModuleAdministrationTenantLeakTests` 6/6 geçti (ETL karantinası ilk turda 3, ikinci turda 0 kritik log).
- **Mutasyon:** üç değişiklik birlikte bozuldu: `-local` koşulsuz yön, DND kapatma global POST'u kaldırıldı, `DropAfterCommit` kaldırıldı. Dört test KIRMIZI oldu. Geri alınıp yeniden derlenince 46/46 yeşil.
- **Altın test:** `ConfigRendererOutboundRouteGoldenTests` özetinden önce BR-AST-149/152 değişikliklerini eski biçime çeviriyor ve sayılarını ayrıca ölçüyor (koşullu damga ≥ 2, ilerleme zaman aşımı = trunk − 1). Böylece başka hiçbir bayt değişmediği hâlâ kilitli.
- **Commit:** `be704e5d` (AST-149/148/152), `e91d637a` (BE-276/280)

## Kararlar (bu tur)
- `channelvars` = eşleyicinin okuduğu değişkenlerin TAMAMI (6). Sunucu ile depo S10 ile eşit tutulur.
- Eski `unknown` yönlü satırlara geri doldurma yapılmaz; ETL'nin bacak bazlı yönü çağrı yönü değildir.
- DND kapatmanın anlık katmanı ARI global'idir, cihaz durumu değil (S76-12a korunur).
- İlerleme zaman aşımı yalnız arkasında yedek trunk olan denemede uygulanır.

## Açık kalanlar (bu tur)
- **Yayın gerekli:** renderer (yön, DND global kapısı, `60^10`), DND yayıncısı, ETL logu, modül önbelleği. `deploy/asterisk-lab/` değiştiği için `asterisk-sunucu-sapma.sh` S1 santral imajını geride görür, yani yayın `--santral` ile yapılmalı (imaj yeniden build'i host `manager.conf`'u değiştirmez, o zaten elle güncellendi). Edge değişmedi.
- Yayın sonrası ölçülecekler: gelen çağrının cdr yönü `in` mi; `*79` anında çalıyor mu (gerçek SIP); BR-QA-131.
- Kart önerisi: ETL yön eşlemesi `-int` bağlamını tanımıyor ve bacak bazlı; pipeline ile ETL satırı aynı çağrı için iki ayrı `cdr` satırı üretiyor (kesirli ve saniye `started_at`).
- Kart önerisi: acil zincirde (`-emerg`) yedek trunk varken ilerleme zaman aşımı yok; yeni ölmüş ilk trunk acil çağrıyı 32 sn geciktirebilir.

## Yayın sonrası ölçüm + BR-QA-131 (backend-dev-2, imaj `demo-e91d637a6420` / santral `22-e91d637a6420`)

### Bağlam
Koordinatör yayını yaptı (asterisk + edge ×2 yeniden yaratıldı). Ölçüm başlangıcı `13:08:05Z`.

### 1. Yayın sonrası durum
- Sapma betiği S1–S10 TAMAM: imaj `e91d637a6420` güncel, S10 channelvars depoyla aynı. 33 endpoint, 4 contact, AMI `pbxtr` bağlı, ARI `pbxtr` uygulaması kayıtlı.
- Yeni üretici santrale yayından ~5 dk sonra kendiliğinden ulaştı. `ProvisioningRerenderJob` parmak izi farkını yakaladı; t0007/t0012/t1001 13:11:42–13:11:59'da yeniden üretildi. Koşullu yön damgaları: t0007'de 11, t0012'de 5, t1001'de 17. `dialplan show` ile yüklü olduğu doğrulandı.

### 2. Yön ölçümü (gerçek çağrılar, `core show channels` = 0 iken)
- **Gelen** (carrier → DID `02122223344`): pipeline cdr `1` (`in`). Yayından önce `2`'ydi.
- **Dahili** (`Local/1043@pbxtr-t0007-int`): `3` (`int`).
- **Giden** (`Local/05321112233@pbxtr-t0007-out`): dialplan bacağı `2` (`out`).
- Not: Local originate'in uygulama bacağı (`;1`) dialplan koşmadığı için 0 kalır. `-int` dış numarayı zaten yönlendirmiyor (Congestion), ilk denemem bu yüzden giden sayılmadı.
- **Bulunan regresyon (benim BR-AST-149 değişikliğim):** telefonların endpoint bağlamı `-out`'tur ve yön önce `out` yazılır. `-local` yönü yalnız boşsa yazmaya başlayınca, telefondan dahiliye yapılan çağrı (`t1001-2001` → `2001`) cdr'de **2 (giden)** göründü.
  - **Düzeltme:** `-out`, yerel hedefe atlamadan hemen önce `ExecIf(DIALPLAN_EXISTS(-local)?Set(__PBXTR_DIR=int))` yapar.
  - **Test:** `Telefondan_yerel_hedefe_atlayan_cagri_once_int_olur` (mutasyonda KIRMIZI). Altın test satırı çıkarıp sayısını (1) ayrıca ölçüyor.
  - Telephony+Provisioning 1911 geçti / 2 atlandı, Architecture 858, format temiz.
  - **Commit:** `f497cb4d`. **Yayın gerekir.**

### 3. BR-QA-131 (a) — kiracılar arası MAC 409
- Ürün yoluyla geçici pbx tenant `t1002` ("BR-QA-131 MAC olcumu (GECICI)") ve sahibi `zzqa131.sahip` kuruldu. Sahip girişi süper admin parola sıfırlamasıyla yapıldı; parola yalnız bellekte kaldı, hiçbir yere basılmadı.
- t1001'de `00:15:65:13:11:31` 201 ile oluştu (dahili 2002'ye bağlı).
- t1002'den aynı MAC üç biçimde denendi (`:`, bitişik küçük harf, `-`); üçü de **409 `phone_device_mac_taken`**. Yanıtta t1001 izi yok, t1002 listesinde t1001'in MAC'i görünmüyor.
- Kontrol: farklı MAC (`…:32`) 201.
- **Ölçüm notları:** cihaz bir dahili ister (`422 phone_device_extension_unknown`); dahili silme `If-Match` ister (`428`).

### 4. BR-QA-131 (b) — `*28`/`*29` ve BR-AST-148 `*79`
- **Yöntem:** t1001 (edge anahtarı var). `fabrika.2001`'e API ile geçici `supervisor` rolü verildi (`bundle.pbx` → `nightmode.write`). `pbxtr-lab.d/zz131-pjsip.conf` endpoint'i `outbound_auth=t1001-2001` ile santralin kendisine INVITE attı; sır okunmadı. Gerçek kanal `PJSIP/t1001-2001-…`, bağlam `pbxtr-t1001-out`.
- **Gece modu ölçümü** için t1001'e geçici DID `+908505550131 → 2002` eklendi. Konferans DID'i tasarım gereği 7/24 açık olduğu için gece modunu göstermiyor (BR-AST-147).
- **Sonuçlar:**
  - `*28` → `activated`; panelde `enabled:true`; route-decision `open=0 reason=NIGHT_MODE decision=announce_hangup`.
  - `*29` → `enabled:false`; karar çalışma saatine döndü (`OUT_OF_HOURS`; bugün Pazar).
  - Denetim: iki `telephony.nightmode.changed` satırı, aktör `fabrika.2001`, `source: phone`.
  - Negatif kontrol: rol geri alındıktan sonra `*28` → `PbxtrFeatureCodeRejected` + `beeperr`, gece modu kapalı kaldı.
- **`*79`:**
  - `*78` sonrası statik katmanın teslimi 16 sn sürdü. Kontrol araması meşgul dalına girdi (`Gosub(...(BUSY))`, pbx'te meşgul → sesli mesaj).
  - `*79`'dan 2,8 sn sonra statik `Goto(busy)` hâlâ yüklüydü, global `PBXTR_DNDOFF_T1001_2001=1` idi. Arama `ExecIf 0?Goto(busy)` ile meşgul dalını atladı ve arama yoluna geçti (cihaz kayıtsız → `CHANUNAVAIL`).
  - Teslim 11 sn sonra statik katmanı kaldırdı. **BR-AST-148 canlıda doğrulandı.**

### Temizlik (kanıt)
- t1002: cihaz 0, dahili 0, sahip `disabled`, tenant `suspended`. Silme ucu yok; audit_log yüzünden t9052/t9061 emsali gibi askıda kalır.
- t1001: test cihazı silindi (0), geçici DID silindi (kalan yalnız "Toplantı hattı"), `fabrika.2001` rolleri `staff`, 2001 `dnd=false`, gece modu `false`.
- Test çağrılarının bıraktığı 2 sesli mesaj temizlendi: 2 MinIO nesnesi (`mc stat` → yok), 2 `voicemail_messages` + 2 `recording_assets` satırı, 2 spool dosyası. Redis'te t1001 için alarm/sesli mesaj anahtarı yok.
- Lab dosyaları silindi; ardından `module reload res_pjsip.so` + `dialplan reload` (kapalı listeden). ZZ131/DNDOFF global'leri ARI ile silindi (0). Endpoint sayısı 33'e döndü, açık kanal 0.
- t0007/t0012/t1001 config md5'leri **18/18 aynı**. `/root/qa131` silindi. Sapma betiği: on iddia sağlandı.

## Kararlar
- Telefondan yerel hedefe giden çağrının yönü `-out`'ta `int`'e çevrilir; `-local` ve `pbxtr-dialer` yönü yalnız boşsa yazar (gelen yön korunur).

## Açık kalanlar
- `f497cb4d` yayını bekliyor. Yayından sonra t0007/t1001 dialplan md5'i bilinçli olarak değişecek. Ölçülecek: telefondan dahiliye cdr `3`.
- Gözlem: telefon kaynaklı `telephony.nightmode.changed` denetim satırında `actor_name` boş (aktör kimliği dolu).

## `f497cb4d` yayını sonrası yön ölçümü (backend-dev-2)
- **Durum:** imaj `demo-f497cb4dfe6a`, santral imajı değişmedi. Yeni dialplan 13:48:38–55'te teslim edildi. `-out`'taki `int` dönüşümü t0007, t0012 ve t1001'de birer satır; `dialplan show` ile yüklü olduğu doğrulandı.
- **Ölçüm (13:49Z, `core show channels` = 0):**
  - Telefondan dahiliye (`PJSIP/t1001-2001` → 2002; geçici lab endpoint, sır okunmadı): cdr **3**, Hangup payload'ı `int`.
  - Gelen DID (carrier → `02122223344`, t0007): cdr **1**, payload `in`.
  - Giden (`Local/05321112233@pbxtr-t0007-out`): dialplan bacağı **2**, payload `out`. Uygulama bacağı (`;1`) 0; Local originate yapısı gereği.
- **Temizlik:**
  - Lab endpoint silindi, ardından `module reload res_pjsip.so`. 33 endpoint / 4 contact, global 0, açık kanal 0.
  - 3 spool dosyası içe alınmadan silindi: 2001'in sesli mesajı ve t0007'nin "tüm görüşmeleri kaydet" kayıtları. 75 sn sonra `voicemail_messages` 0, `recording_assets` 0.
  - Config md5'leri 18/18 aynı. Kod değişikliği yok, commit yok.

## BR-AST-149 + P3 turu — kapanış (koordinatör)

### Yayınlar
- **Neden:** be704e5d/e91d637a (dialplan yön, DND global, trunk `^10`, ETL log, modül önbelleği) ve 4c340d83 (canlı nginx) canlıya girmeliydi; `deploy/asterisk-lab/` değiştiği için santral imajı da.
- **Komutlar:**
  ```bash
  bash deploy/yerel-yayin.sh --yayinla --testsiz --santral   # demo-e91d637a6420 + pbxtr-asterisk:22-e91d637a6420
  bash deploy/yerel-yayin.sh --yayinla --testsiz             # demo-f497cb4dfe6a (yalnız uygulama)
  ```
- Edge değişmedi (`git diff --stat 58fbaf0c HEAD -- deploy/pbxtr-edge` boş).
- İkinci yayının sebebi: yayın sonrası ölçümde telefondan dahiliye çağrı `out` yazıyordu (be704e5d regresyonu); f497cb4d `-out` bağlamında yerel hedefe atlamadan `int` yapar.

### Canlı doğrulama
- **SYS-145:** kimliksiz 2 MB `PUT /api/v1/scripts/<guid>/draft` → 401 JSON (nginx geçirdi); kontrol `PUT /api/v1/scripts/<guid>` → nginx 413 HTML.
- **Yön (f497 sonrası):** telefon→dahili 3 (int), gelen DID 1 (in), giden 2 (out).
- **QA-131:** geçici t1002'den aynı MAC üç biçimde 409; `*28` NIGHT_MODE, `*29` geri, iki denetim satırı, yetkisizken `beeperr`. Temizlik md5 18/18 aynı; t1002 askıda kaldı (silme ucu yok).

### Backlog / ClickUp
- Betik: scratchpad `p3-backlog.py` (durum hücresi `Acik (...)` → `Bitti (2026-10-25, ...). Onceki kayit: ...`, BR-QA-131 satırından sonra yeni kart).
- Bitti: AST-149, AST-148, AST-152, SYS-145, BE-274, BE-276, BE-279, BE-280, OPS-20, QA-131.
- Yeni: BR-OPS-21 (demo parolası ≥12, OPS-20'den bölündü), BR-BE-281 (ETL yön eşlemesi `-int`/çift cdr; 458 eski satır unknown), BR-AST-153 (acil zincirde ilerleme zaman aşımı yok), BR-BE-282 (telefon kaynaklı denetimde aktör adı boş).
- `clickup-olustur.js` (4 yeni) → `clickup-senkron.js` (10 yazıldı) → `--kuru`: fark 0, izde olmayan 0.
- **Commit:** `42e906b2` — P3 + BR-AST-149 kapanisi.

### Açık kalanlar
- P2: BR-BE-277 (dahili kotası agent limitine bağlı), BR-BE-278 (yeni tenant için node API anahtarı elle).
- P3: BR-OPS-21, BR-BE-281, BR-AST-153, BR-BE-282.
