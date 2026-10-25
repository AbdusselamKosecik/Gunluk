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
