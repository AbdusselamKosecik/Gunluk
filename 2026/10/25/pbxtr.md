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

## Kararlar
- `*79` penceresi kabul edildi (iki katman modeli + S76-12a negatif testi); çözüm DND değişiminde anında rerender — P3.
- Agent rolünün telefondan `*72` yapabilmesi kabul: özellik kodu dahiliye bağlıdır, role değil.

## Açık kalanlar / sonraki adım
- Sprint-48 → FE-144/145 → yayın → QA-129; ardından Sprint-49.
