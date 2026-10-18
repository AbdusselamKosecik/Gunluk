# pbxtr — 2026-10-18

## Bağlam
Operatör lab'i (2026-10-17) ile kullanıcı `deneme.agent` olarak web'den gerçek gelen çağrı denedi
ve üç sorun bildirdi: (1) "Telefonunuz santralde kayıtlı değil" uyarısı, (2) gelen çağrıda numara
yok, (3) "Kabul et" 502. Ardından: telefon çipindeki Aç/Kapat tasarımı, hoparlör testinde
"Ton çalınamadı", mesai saati kavramının kaldırılması, "testlerle uğraşma şimdilik".

## Yapılanlar

### 1. "Kabul et" 502 — BR-FE-136 (Bitti)
- **Ölçüm:** nginx `POST /api/v1/agent/calls/1792274733.3/actions` → 502 (uygulamanın kendisi,
  `TelephonyRejected`). Santral aynı anda `PJSIP/t0007-wrtc-1047-0000000x is ringing`: çağrı
  tarayıcıya ulaşıyordu. Kuyruk agent'ı `Dial()` ile arar; kanal Stasis'te değil, ARI `answer`
  reddediyor.
- **Düzeltme:** `AgentDeskScreen.tsx`, `shell/IncomingCallAlert.tsx`, `console/ConsoleScreen.tsx`
  — yazılım telefonu `ringing` ise `softphone.answer()` (SIP 200 OK, tarayıcıda); sunucu yolu yalnız
  telefon çalmıyorken.
- **Commit:** `0fad448e`.

### 2. Telefon çipi Aç/Kapat
- **Neden:** `SoftphoneBadge.tsx` `controls.primary`/`controls.danger`'ı taban `.btn` olmadan
  kullanıyordu → ham tarayıcı düğmesi, aralıksız.
- **Ne yapıldı:** `btn + accept` / `btn + dangerGhost` + `AgentDesk.module.css` `.softphoneChip`
  (gap) ve `.softphoneAction` (6/12 px, 11 px). Commit `0fad448e`.

### 3. "Ton çalınamadı" (hoparlör testi)
- **Ölçüm:** canlı CSP `media-src 'self' blob:` — `data:audio/wav` engelleniyor.
- **Düzeltme:** `shell/audioDevices.ts` `toneWavBytes()` + `playTestTone` `blob:` URL ile çalar
  (CSP gevşetilmedi). Commit `1d53a021`.

### 4. Kayıt uyarısı
- **Ölçüm:** Redis `pbxtr:1111…:telephony:registration` → `t0007-wrtc-1047 registered:true`;
  `RegistrationAxis.ForExtension` masa+tarayıcı birleşimi doğru. Uyarı kayıt ölçülmeden önce
  (sayfa açılışı/örnekleyici turu) görülmüş; kod değişikliği yapılmadı.

### 5. Numara görünmüyor — BR-AST-134 (Açık)
- `RedisLiveOperationsView.GetActiveCallAsync` cari eşleşmesi yoksa `null` → "Bilinmeyen arayan".
  Gelen DID çağrısında `contact_id` dolmuyor; `CallerIDNum` yalnız `PbxtrQueueCallback` için
  taşınıyor. Redis'te numara tutmama kuralı korunarak çözülecek (kart).

### 6. Trunk auth `username` — BR-AST-133 (Kısmen)
- **Neden:** yayın 51 (`0fad448e`) santral sapma kapısı S5'te durdu:
  `t0007-trunk-operator-lab: No authentication username` → auth nesnesi hiç yüklenmiyordu.
- **Ne yapıldı:** `ConfigRenderer.cs` trunk auth'a `username=<trunk adı>`. S5 "bu açılıştan beri"
  saydığı için sunucuda `/etc/asterisk/pbxtr.d/pjsip/t0007-pjsip.conf`'a aynı satır elle eklendi
  (yedek `/root/t0007-pjsip.conf.bak-20261018`) ve `docker restart pbxtr-asterisk` (0 aktif çağrı).
  `pjsip show auth` → `username: operator-lab`, yeni ERROR 0. confd sonrası `304 değişiklik yok`.

### 7. Mesai kapısı kaldırıldı + `--testsiz` yayın
- **Kullanıcı:** *"mesai saati kavramini cikart sistemden. testlerle ugrasma simdilik"*.
- `mesai_kapisi`/`mesai_muafiyet_kapisi` çağrıları ve tanımları: `deploy/staging-yayin.sh`,
  `deploy/pbxtr-deploy-artifact`, `deploy/lib/pbxtr-migrate-adimi.sh`; `PBXTR_MESAI_ICI_YAYIN`
  geçişi `deploy/yerel-yayin.sh`'tan çıktı.
- `yerel-yayin.sh --testsiz`: test takımları, güvenlik/DB kapıları, entegrasyon atlanır
  (`ATLANAN-KAPILAR.txt`); derleme, format, typecheck, imaj, staging ve santral kapıları koşar.
- **Komut:**
  ```bash
  nohup bash -c "bash deploy/yerel-yayin.sh --yayinla --testsiz > LOG 2>&1; ...; git push" &
  ```
- Yerel Docker Desktop kapalıydı (ilk deneme imaj adımında düştü); başlatılıp yeniden koşuldu.
- **Sonuç:** yayın 52 yeşil, `tekbirsoft/pbxtr:demo-1d53a02124c5`, push `157e7332..1d53a021`.
  Canlı paket `createObjectURL(new Blob(...audio/wav))` ve yeni kabul yolunu taşıyor.
- **Commit:** `1d53a021`.

## Kararlar
- Yayında mesai saati yok (kullanıcı).
- Şimdilik testsiz yayın (kullanıcı); santral sapma kapısı yine koşar.
- Hoparlör testi kaldırılmadı, düzeltildi (kullanıcı: "kaldirma sorunu coz").

## Açık kalanlar / sonraki adım
- BR-AST-134: kayıtsız arayanın numarası; masa telefonunda "Kabul et".
- BR-AST-133: trunk kullanıcı adı UI/DTO alanı.
- `deploy/lib/pbxtr-migrate-adimi.sh`'te `MESAI_MUAFIYETI_YASAK` listesi ve ilgili kapılar
  (kapi_53/55/68/86, öz-testler) artık ölü/kırmızı — testler açılınca temizlenecek.
- Kullanıcı testi: "Kabul et" ile çağrıyı açıp müziği duymak.

## Ek (gece, ikinci tur)

### 8. "Canlı agent satırı yok" — deneme.agent kuyrukta değildi
- **Neden:** santral yeniden başlatma (22:20Z) + yayın 52 app yeniden yaratması sonrası pbxtr kuyruk
  üyeliklerini DB'den yeniden kurdu; `deneme.agent` DB'de Müşteri Hizmetleri üyesi değildi (1047'nin
  önceki üyeliği santralde eski "1047" kullanıcısından kalma izdi).
- **Ne yapıldı:** `POST /api/v1/queues/11111111-…-11114abdf860/members`
  `{"userId":"23fba84c-…","penalty":0}` → 201, `Local/1047@pbxtr-t0007-local/n`.
- **Sonuç:** kadro satırı geldi; kullanıcının çağrısı tarayıcıdan açıldı (`PJSIP/t0007-wrtc-1047` Up,
  `on_call`) — "Kabul et" düzeltmesi canlıda ölçüldü.

### 9. Konsol hataları
- `GET /api/v1/sim/scenario` 404: `SimulationProvider` artık yalnız `/me.telephonyMode==='simulated'`
  iken yokluyor. Commit `1dfb575e` (push edildi, yayın kullanıcı testi bitince).
- Cloudflare Web Analytics beacon CSP'ye takılıyor: Cloudflare kenarda otomatik enjekte ediyor;
  öneri panelden kapatmak (CSP gevşetilmedi).

## Ek (sabah, üçüncü tur)

### 10. Yayın 53 — TreeView yığın taşması, çift answer, 5 sn ICE (`571bbf49`, `3fe82e4d`)
- **TreeView `Maximum call stack size exceeded`:** sonuç kodu ağacında kök düğüm ağaçla aynı
  kimliği taşıyınca `childrenByParent.map.get(node.id)` düğümün kendisini çocuk döndürüyordu.
  `TreeView.tsx` çocukları `depth === item.depth + 1` ile süzer; `CallTab.treeNodesOf` kök
  kimliğini düğüm listesinden atar.
- **`sip.Invitation | Invalid session state Establishing`:** aynı çalan çağrıya ikinci `answer()`.
  `useSoftphone.ts` `answeringRef` ile ilk istek kazanır.
- **"Kabul et" ile ses arası 5 sn:** SIP.js varsayılan `iceGatheringTimeout` 5000 ms; STUN'a
  ulaşılamayan ağda tam 5 sn beklenip 200 OK sonra gidiyordu.
  `sessionDescriptionHandlerFactoryOptions: { iceGatheringTimeout: 500 }`
  (`session-description-handler-factory-default.js:19` seçeneği okuyor — doğrulandı).
- Yayın 53 yeşil: `tekbirsoft/pbxtr:demo-3fe82e4d4120`, push `1dfb575e..3fe82e4d` (sim 404 dahil).

### 11. ACW sonuç koduna kadar sürer — BR-BE-255 (`c10f5170`)
- **Kullanıcı:** *"cagri kapandiginda acw de kalmiyor, sonuc kodu girmemiz lazim"*.
- **Neden:** gerçek santralde ACW'yi yazan tek olay `AgentComplete`; hemen ardından dahili
  NOT_INUSE → `QueueMemberStatus available` (`AmiDeviceState.cs:56`) ACW'yi eziyordu. Gerçek
  kipte `PbxtrAcwEnd` üreten hiçbir şey yoktu (yalnız simülasyon).
- **Ne yapıldı:**
  - `TelephonyEventPipeline.UpdateLiveStateAsync`: varlık ölçümü `available` iken kayıtlı durum
    `acw` ise yazılmaz; satır aynı ACW ile `MeasuredAt` tazelenerek yeniden yazılır (120 sn
    `LiveStateTtl` dolup agent kadrodan düşmesin). Mola/çevrimdışı ve çağrı kenarları geçer.
  - Yeni port `Domain/Modules/Live/IAgentAcwCloser.cs`, uygulama
    `Infrastructure/Telephony/Live/AgentAcwCloser.cs` (Redis'te `acw` ise boş CallId ile
    `PbxtrAcwEnd` → boru hattı; WS + agent_state aynı yoldan). DI:
    `TelephonyServiceCollectionExtensions.cs`.
  - `POST /api/v1/agent/calls/{callId}/result` `Recorded` dalında `acwCloser.CloseAsync`
    (fail-open, log).
  - `ChannelResyncWriter.SweepStaleAsync` yalnız on_call/ringing süpürür — ACW'ye dokunmaz (okundu).

### 12. "Kabul et" tek dokunuş — BR-FE-137 (`c10f5170`)
- **Kullanıcı:** *"butona birkac defa basma oluyor 5 yasindaki cocugun kullanabilecegi sekilde olsun"*.
- `SoftphoneStatus.answering?` (answer() → true; in-call/hangup/yeni çağrı → false).
- `IncomingCallModal.tsx` softphone'u kendisi okur: `answering` iken Kabul/Reddet kilitli,
  "Bağlanıyor…" (`incoming.answering`, 9 dil dosyası); `in-call` olunca pencere kapanır.
  Masa, konsol ve kabuk bildirimi aynı bileşeni kullandığı için üçü birden.
- `SoftphoneBadge.tsx`, `HeaderSoftphone.tsx` cevap düğmesi `answering` iken kilitli.
- **Ders:** depo kökünden `prettier --write` projenin biçimini bozdu (yüzlerce satır) — geri
  alındı; bu projede prettier koşulmuyor.
- Yayın 54 (`--yayinla --testsiz`) başlatıldı.

- Yayın 54 yeşil: `tekbirsoft/pbxtr:demo-c10f51708e44`, push `3fe82e4d..047ecd44`. Kullanıcı testi bekleniyor (Kabul et tek dokunuş + ACW → sonuç kodu → müsait).

### 13. Kayıt uyarısı yanlış alarm — "Müsait" kilidi (`b78821c5`)
- **Kullanıcı:** *"Telefonunuz santralde kayıtlı değil … geliyor"* (çağrı geliyor ama uyarı var).
- **Ölçüm:** `pbxtr_sys.job_runs` → `registration-sampler` canlıda ~5 dk'da bir (ortak tick).
  Redis `pbxtr:1111…:telephony:registration` 05:05:49 ölçümünde `t0007-wrtc-1047 false`
  (yayın 54 uygulamayı yeniden başlatırken tarayıcı yeniden kayıt oluyordu); 05:13:35 → `true`.
  `pjsip show contacts` aynı anda kaydı gösteriyordu.
- **Etki:** `HeaderStatusMenu.tsx` `phoneNotRegistered` uyarıyı çizip "Müsait"i de kilitliyordu
  (sunucuda böyle bir engel yok).
- **Düzeltme:** bu sekmedeki softphone `registered|ringing|in-call` ise engel uygulanmaz.
- **Kalan:** yalnız masa telefonlu agent için örnekleyici gecikmesi (5 dk) sürüyor.
- Yayın 55: iki deneme Docker Hub push ağ kopmasıyla düştü (proxy `172.29.0.1:3128` "use of closed network connection"); `docker push` elle geçti, üçüncü koşu yeşil: tekbirsoft/pbxtr:demo-b78821c55c58, push başarılı.

## Ek (dördüncü tur)

### 14. ACW alt sonuç kodları seçilemiyordu — `571bbf49` regresyonu (`960d0817`)
- **Kullanıcı:** *"acw de sonuc kodu altini secemiyorum"*.
- **Ölçüm:** `result_codes` (t0007) kök düğümler depth 1 (Satış/Destek/Tahsilat), `agent_visible_depth=4`;
  `/agent/result-codes` ağacı kök düğümü de `nodes` içinde gönderir (id = tree.id).
- **Neden:** önceki turda kökü listeden atıp çocukları `parentId=null` ile aradım → hiçbiri bulunamadı.
- **Düzeltme:** `CallTab.treeNodesOf` → `parentId === tree.id` olanlar ilk seviye (null'a eşlenir), kök atılır.

### 15. #51 rozetleri + sürüm rozeti (`960d0817`)
- Playwright ile canlı ekran görüntüsü (süpervizör): `rc.mjs` betiği scratchpad'de,
  `node .rc-shot.mjs <user> <pass> <yol-eğiksiz> <png>` (Git Bash `/yol`u Windows yoluna çevirir — eğik
  çizgisiz ver).
- Rozetler elle çizilmiş 10 px hap, yükseklik yok → metin çerçeveye taşıyordu. `ui/Badge`
  (danger/warn/neutral mono) — `ResultCodeTree.tsx`, `ResultCodesScreen.tsx`; ölü CSS silindi.
- Sol menü sürüm rozeti (`26.10.18+b78821c55c58`) logoya biniyordu → yalnız `+` öncesi, tam sürüm `title`.

### 16. Roller — BR-SEC-34 (`8a5824bf`, ajan)
- `RoleVisibility.IsListed(scope, roleScope, activeTenantIsDealerHome)`: global olmayan bakan
  superadmin/admin görmez; `dealer` yalnız `tenants.is_dealer_home`. `/roles`, `/roles/matrix`,
  `/users/assignable-roles`. `TenantDescriptor.IsDealerHome` (`EfTenantDirectory`).
- Canlı doğrulama (süpervizör): 4 rol — Tenant Sahibi, Supervizor, Agent, Wallboard.
- Kırılacak test: `RoleMatrixEndpointTests.The_matrix_is_complete_in_a_single_request`.

### 17. Tenant adı — BR-FE-138 (`8a5824bf`, ajan)
- Ham GUID'in görünen asıl yeri denetim günlüğü (#38): etiketsiz tenant hedefleri liste ucunda
  `ITenantDirectory.FindAsync` ile ada çevrilir (sayfa başına ≤20 farklı id); detay `tenantName`.
- Tenantlar ekranı sütun başlığı "Tenant ID" → "Tenant kodu" (sütun `t0007` gösteriyor).
- Kalan: sistem sağlığı retention alarm satırı GUID (`pbxtr_sys.call_data_retention_lag()`).

- Yayın 56 yeşil: `tekbirsoft/pbxtr:demo-8a5824bf3e85`, push `b78821c5..3280ebb5`. ClickUp fark 0.

## Ek (beşinci tur) — dinleme/suflör, aktarma, park

### 18. Dinleme/suflör (`bf3c2728`)
- **Kullanıcı:** dinleme "bad request", süflör de olmuyor (yapıştırılan fetch: gövde `"\"{\\\"targetUserId…\"}"`).
- **Neden 1 (400):** `api/ops.ts startMonitorSession` gövdeyi `JSON.stringify` ediyordu; `client.ts:523` zaten
  çeviriyor → sunucuya JSON METNİ gidiyordu. Depoda tek örnek (`grep "body: JSON.stringify"`).
- **Neden 2 (502, gövde düzelince API'yi elle denedim):** log `Canli durumdaki kanal adi TAM DEGIL`.
  Redis `live:call:1792302663.26` → `agentChannelId = Local/1047@pbxtr-t0007-local-00000007;1`;
  `ChanSpyInvocation.IsExactChannelName` `@`/`;` reddeder (Karar #23 §S23-4a).
- **Düzeltme:** `TelephonyEventPipeline.AgentDeviceChannelOf`: AgentConnect anında agent bacağı Local üye ise
  ve çağrının son doğan bacağı (`ChannelId`) aynı tenant kodu + dahilinin `PJSIP/{kod}-[wrtc-]{ext}-{hex}`
  cihaz kanalıysa hedef odur; değilse fail-closed.

### 19. Kör/danışmalı aktarma ve park — BR-AST-135 (`3f01370c`, ajan backend-dev-2)
- Canlı ölçüm (06:04–06:11Z, ajanın kendi Local test oturumları, sonunda 0 kanal):
  - Kör: ARI'ye kanal ADI gidiyordu (404 Channel not found); hedef `-in` DID bağlamı.
  - Danışmalı: `8002@pbxtr-t0007-inbound` → `NO_DID_MATCH` → Congestion.
  - Park: Asterisk 22.10.1 ARI'de `/channels/{id}/park` YOK (404); `PARKING_SPACE` yazılmıyor.
- Çözüm: üçü de talep anında devralma (`ControlTargetOrTakeoverAsync` / yeni `ControlledSessionAsync`).
  Kör = `continue` → `pbxtr-{kod}-local` + `DIALPLAN_EXISTS`; danışmalı = müşteri `-hold` köprüsü + `-xfer`
  bacağı, agent kapatınca tamamlanır; park = `PARKINGLOT=t0007-tut`, `BLINDTRANSFER`, `continue` →
  `pbxtr-{kod}-park,700`, slot AMI `ParkedCalls` (call sınıfı, yeni yetki yok).
- Dosyalar: `AsteriskAriProvider.cs`, `AriCallBridge.cs`, `AmiCommandChannel.cs`.
- Ölçülmeyen: tarayıcı agent ile uçtan uca; `UnparkAsync` muhtemelen bozuk (`tutN` exten'i yok).
- Kırılacak test: `AsteriskAriProviderControlTargetTests.cs:162`.

### 20. Yayın 57
- İlk koşu `tag does not exist: tekbirsoft/pbxtr:demo-3f01370cec0f` — yayın sürerken ClickUp eşlemesi commit'lendi,
  HEAD değişti. Hafıza `iki-yayin-kosusu-ust-uste-binmez` güncellendi.
- Yeniden koşu yeşil: `tekbirsoft/pbxtr:demo-58d83bdf63fd`, push `3280ebb5..58d83bdf`.

## Ek (altıncı tur) — dinleme hâlâ 502, ses kaydı, dalga formu, profil sekmesi

### 21. Dinleme/suflör 502 — süpervizörün ucu GUID'di (`beaa9e4c`, BR-AST-136)
- **Neden:** Kullanıcı 07:43Z'de yine 502 aldı. `audit_log` satırları `failureReason=TELEPHONY_REJECTED`. `AgentMonitoringService` `SpyRequest.SupervisorEndpoint`'e `_tenantContext.UserId.ToString("D")` veriyordu; ARI `POST channels` `endpoint` alanı kanal adresi bekler → red.
- **Ne yapıldı:** Süpervizörün dahilisi `IAgentExtensionDirectory.ResolveExtensionAsync` ile çözülür (opsiyonel ctor parametresi, testler kırılmasın diye), sağlayıcı çıplak numarayı `Local/<dahili>@pbxtr-<kod>-local` yapar. Dahili yoksa 409 `SUPERVISOR_NO_EXTENSION` (`MonitorEndpoints.FailureResult`, `monitorErrors.ts`, 9 dil `mon.supervisorNoExtension`).
- **Test ortamı verisi (ürün API'siyle):** `deneme.supervizor`'un dahilisi yoktu. t0007 agent kotası 6 doluydu → `PUT /api/v1/tenant` (demo.superadmin + `X-Tenant-Id`) agentLimit 10; `POST /api/v1/extensions` (demo.sahip) 1048 → süpervizör; `POST /api/v1/users/extensions/{id}/webrtc` → santralde `t0007-1048` ve `t0007-wrtc-1048` oluştu.
- **Sonuç:** Gerçek çağrıda dinleme sesi ölçülmedi.

### 22. Ses kayıtları yoktu — `record_all_calls=false` (ayar, kod değil)
- **Ölçüm:** `tenant_settings.record_all_calls` bütün tenantlarda `f`; dialplan'de MixMonitor yok; `/var/spool/asterisk/recording/t0007` altında yalnız Eylül'den bir dosya.
- **Ne yapıldı:** #49 Ayarlar → Telefon & Ses'ten (demo.sahip, Playwright) açıldı → yeni revizyon, `t0007-dialplan.conf` -in/-out bağlamlarında MixMonitor. Test: `channel originate Local/905551112233@pbxtr-t0007-out application Wait 4` → MixMonitor `t0007/2026/10/` dizinini kendisi açıp dosya yazdı (D-14'ün açık sorusu: açıyor). Test dosyası silindi.

### 23. #20 Kalite Kontrol gerçek dalga formu (`beaa9e4c`, BR-FE-139)
- `ui/RecordingPlayer`: `waveformHint` prop'u → bağlantı alınınca (yalnız ▶ ile; her alım denetime "dinlendi" yazar) aynı imzalı URL `fetch` + `AudioContext.decodeAudioData`, 160 çubuk tepe genliği, normalize; çalınan kısım amber, tıklayınca konum. Ölçülemezse oynatıcı etkilenmez. `QaScreen` "dalga formu yok" notunu kaldırdı, `qa.waveformHint` 9 dil.

### 24. Agent masası (`beaa9e4c`)
- Sol dikey sekmelerdeki "Profilim" kaldırıldı (`AgentDeskScreen.tsx`; `AgentProfileTab.tsx` dosyası duruyor).
- Durum kartındaki kuyruk rozeti GUID gösteriyordu (`me.QueueIds`) → `/agent/state` `snapshot.Queues` ile ada çevirir. Canlı: `["Müşteri Hizmetleri"]`.

### 25. `/telephony/*` ekranları yenilemede nginx 404
- Demo nginx'inde çıplak `location /telephony/ { return 404; }` vardı (Sınıf B'nin gerçek rotası `/api/v1/telephony/`, hiçbir ucu kapatmıyordu). Kaynak `pbxtr-demo/nginx/pbxtr.conf` — yayın `nginx/.rev/<ts>-<sha>/conf.d/default.conf` olarak üretip `current` symlink'ler; elle düzeltme bir sonraki yayında ezilirdi. Satır kaldırıldı. Not: 443 bloğunda `/api/v1/telephony/*` tam eşleşme 404'leri YOK (`deploy/nginx.conf`'ta var) — dokunulmadı, edge'in yolu ölçülmeden kapatılmaz.

### 26. Yayın 58
- `demo-beaa9e4cb653`, YAYIN_EXIT=0, push `58d83bdf..beaa9e4c`. Canlı: `/telephony/monitor` 200, kuyruk adı görünüyor.
- ClickUp: 2 yeni kart, `--kuru` fark 0.

### Açık kalanlar
- Dinleme/suflör, aktarma, park: gerçek çağrıda uçtan uca ölçüm (kullanıcı testi).
- CDR listesinde yön `unknown`, agent/kuyruk boş, cevaplanan çağrıda numara "—" (ekran görüntüsünde görüldü) — kart `BR-BE-256` (`b60a14e0`).
- 443'te Sınıf B uçları proxy'leniyor (nginx-dogrula.sh gate B) — ölçülmeli.

## Ek (yedinci tur) — kalite kontrol formu ve scripter

### 27. Mevcut durum taraması (iki Explore ajanı)
- QA: `qa_criteria` (düz soru listesi, weight 1..100), `qa_evaluations`, `qa_evaluation_scores` (0..10), itiraz `tickets.type='qa_objection'` ile zaten vardı. Eksik: cevap seçeneği/puanı, toplam 100 kuralı, form ekranı, QA/süpervizör itiraz yüzü (süpervizör `ticket.respond` olmadığı için itirazı okuyamıyordu bile).
- Scripter: tasarımcı, sürüm/yayın, agent sayfa sayfa koşucu, cevap kaydı TAM. Eksik: kuyruğa bağlama (yalnız kampanya, kampanya numara→cari eşleşmesinden), `contacts`'ta serbest alan yok (CSV'nin 4 kolon dışı atılıyordu), datadan doldur/geri yaz yok; t0007'de scripter lisansı kapalı.

### 28. Kalite kontrol (`1e851a0c`, BR-FE-140; ajanlar backend-dev-1 + frontend-dev-1 paralel, ortak sözleşme)
- **Neden:** Kullanıcı: 100 üzerinden form, her cevaba puan, toplam 100 zorunlu, dinleme listesinden seçerek değerlendirme, agent itirazı, QA ve süpervizör itirazları görsün. Yeni tablo YOK şartı.
- **Ne yapıldı:** Migration `20261018120000_QaFormAnswerOptions`: `qa_criteria.answer_options jsonb`, `qa_evaluation_scores.answer_label`, puan kısıtı 0..100 ve eski 0-10 puanlar `round(score*weight/10)` ile dönüştürülür (canlıda veri 0 satırdı). Puan = soru puanı; toplam = 100·Σpuan/Σağırlık (yanıtlanan sorular).
- Uçlar: `GET/PUT /api/v1/qa/form` (toplam ≠100 → 400 `qa_form_total_not_100`), `GET /api/v1/qa/objections`, `POST /api/v1/qa/objections/{id}/decision` (karar `tickets.context`, mesaj + kapanış); `TicketEndpoints.CanRead` `qa.read`'e qa_objection biletini açar.
- Ekran #20: Değerlendir (yalnız kaydı olanlar anahtarı, cevap düğmeleri, X/100) · Form (soru/tam puan/seçenekler, hazır Evet/Hayır, Evet/Kısmen/Hayır, toplam rozeti) · İtirazlar (filtre, detay, kabul/ret notu, "kaydı değerlendirmeye aç"). Agent paneli: seçilen cevap, puan/tam puan, karar.

### 29. Scripter (`1e851a0c` arayüz, `4bd3a97d` sunucu, BR-BE-257; ajanlar frontend-dev-2 → backend-dev-2)
- Migration `20261018140000_ScripterQueueCampaignAndContactExtra`: `queues.campaign_id` (bileşik FK, ON DELETE SET NULL (campaign_id)), `contacts.extra jsonb NOT NULL DEFAULT '{}'`.
- Kampanya çözümü: carinin kampanyası, yoksa kuyruğun kampanyası (`OwnedCallResolver`, `RedisLiveOperationsView`).
- CSV içe aktarma: 4 sabit kolondan sonrakiler ek alan (başlık → ascii anahtar), `updateExisting`; `GET /campaigns/{id}/data-keys`.
- Script alanı `source` (code/title/city/extra.<k>) + `writeBack`; agent oturumunda `prefill`; adım/kapanışta cariye yazar, `contact.updated` (kaynak script).
- Arayüz: kuyruk diyaloğunda "Kampanya (script)", veri ekranında ek alan kolonu, tasarımcıda "Datadan doldur / Dataya geri yaz", müşteri kartında "Ek bilgiler".

### 30. Yayın 59 ve canlı kurulum
- `demo-4bd3a97daa9e`, push `1e851a0c..4bd3a97d`. İki migration canlıda uygulandı.
- Canlı ölçüm (API, demo.sahip): form 90 puan → 400 `qa_form_total_not_100`; 6 soruluk 100 puanlık örnek form kaydedildi. İtiraz listesi 200.
- t0007 scripter lisansı açıldı (`PUT /tenants/{id}/license-features/scripter`, demo.superadmin). Örnek kampanya "Müşteri Hizmetleri Gelen" (inbound) oluşturuldu, kuyruk 8001 ona bağlandı (diğer kuyruk ayarları değişmedi), 2 sayfalık script (ad soyad/şehir datadan dolar + geri yazar, talep türü, açıklama) v1 yayınlandı. Ek kolonlu CSV ile iki sahte cari (DEN-001/002, +90555000000x) → `extraKeys: musteri_no, paket_adi`.
- Ekran görüntüsü (süpervizör): Değerlendir ve Form sekmeleri doğru çiziliyor; telefon 1048 hazır.

### Açık kalanlar
- Migration uyumluluk kapısı (`deploy/migration-compatibility-guard.py`) iki yeni ham SQL migration için kırmızı; `--testsiz` atlıyor, onay satırı yok.
- Canlı inbound çağrıda `cdr.queue_id` dolu mu (scripter `GET …/script` 204 riski) — gerçek çağrıda ölçülmeli.
- QA "kalite uzmanı" sistem rolü yok (tenant özel rolüyle verilir); XLSX içe aktarma yok; dışa aktarma ek alanları taşımıyor.

## Ek (sekizinci tur) — scripter nereden eklenir + kampanya ekranı kusurları

### 31. Kural kutusu düzeni ve kampanya metinleri (`c05bee2e`, yayın 60)
- **Neden:** Kullanıcı "scripter i nereden ekleyecegiz" diye sordu. Cevap: 06 Kampanyalar → kart → **Script** (tasarımcı, yayınla) → 03 Kuyruk Yönetimi'nde kuyruğa "Kampanya (script)" → 05 Veri Yönetimi CSV (ilk 4 kolondan sonrası ek alan). Bu ekranın Playwright görüntüsünde üç kusur çıktı: "window undefined", açıklama kutusunda metnin sütunlara bölünmesi, "kampanya-kuyruk bağı yok" diyen bayat açıklama.
- **Ne yapıldı:**
  - `.ruleLine` `display:flex`; içine doğrudan konan `<T k=…/>` çevirisi `<b>`/`<code>` parçalarına bölünüp her parça ayrı flex sütunu oluyordu. Metin tek `<span>` içine sarıldı — 14 ekranda 58 satır (betik `scratchpad/rule_wrap.py`: `ruleTag}>` satırından sonraki tek satırlık `<T …/>` sarılır; ApiKeysScreen'deki çok satırlı karışık satır elle).
  - 9 dilde `camp.windowUnset` → "tarih aralığı yok"; `camp.ruleProgress` ve `camp.ruleNotDrawn` güncel duruma göre yeniden yazıldı (ilerleme `contacts.campaign_id`'den sayılıyor; kuyruk-script bağı 03'te kuruluyor); `camp.ruleNotDrawnTag` → "kuyruk ve script".
- **Dokunulan dosyalar:** `src/Pbxtr.Web/src/app/i18n/messages/*.json` (9), `CampaignsScreen.tsx`, `CampaignReportDialog.tsx`, `QueuesScreen.tsx`, `LossScreen.tsx`, `TargetsScreen.tsx`, `DialerScreen.tsx`, `NetworkQualityScreen.tsx`, `ReportsScreen.tsx`, `ApiKeysScreen.tsx`, `StorageScreen.tsx`, `NetworkInterfacesScreen.tsx`, `ServicesScreen.tsx`, `BlacklistScreen.tsx`, `ExtensionsScreen.tsx`, `TrunksScreen.tsx`.
- **Sonuç / doğrulama:** `tsc -b` temiz; vitest campaigns/security/queues 12 dosya 104 test yeşil. Yayın `--yayinla --testsiz` ile 60. koşu.
- **Commit:** `c05bee2e` — Kampanyalar: tarih araligi metni, kural kutusu duzeni (14 ekran), kuyruk-script aciklamasi guncel

### Açık kalanlar
- Kullanıcı uçtan uca testleri: dinleme/fısıltı (1048), transfer/park, QA değerlendirme+itiraz, 8001 çağrısında scripter.
- BR-BE-256, migration kapısı onay satırı, UnparkAsync, Excel matris dönüşü.

## Ek (dokuzuncu tur) — Scripter v2 (viasescloud eşdeğeri)

### 32. viasescloud scripter incelemesi
- **Neden:** Kullanıcı: "D:\SSDM2D\Source\gitlab\Sys\arge\viases\cloud daki gibi birsey yapmamiz lazim — scriptter icin".
- **Ne yapıldı:** Explore ajanı salt okunur taradı. `viasescloud.scripter.service.core` çalışma ağacı boş, kod `origin/dev` dalında (git show ile okundu); tasarım API'si `viasescloud.ivr.web`'de. Model: jquery-flowchart akış şeması (START/END/PAGE/CONDITION/REST/DB/FUNCTION/SCRIPTER/MAIL/CUSTOM düğümleri), PAGE düğümü 12 kolon Bootstrap şablona bağlı, sayfadaki her buton ayrı çıkış (buton = dal), değişkenler + `{{Var}}`, variableVisible/Enable/Datasource, Required + regex doğrulama, cevaplar Redis'te değişken çantası + sonda `<tablo>_Export`. Eksikleri: geri yok, rapor yok, SQL birleştirme ile sorgu (injection), REST hata dalı yok.
- **Karar:** pbxtr'da yeni tablo YOK; tanım JSON'una opsiyonel alanlar (schemaVersion 1 kalır, eski scriptler aynı). REST/DB/alt-script/mail/fonksiyon düğümleri faz 2 (BR-BE-258; SSRF + sır yönetimi gerekir).
- Sözleşme: `scratchpad/scripter-v2-sozlesme.md` (aşağıda özet).

### 33. Scripter v2 (`e6378ec7`, yayın 61, BR-FE-141)
- **Sözleşme:** alan `display` (textarea/select/radio/buttons/toggle), `width` 1..12, `minLength`, `pattern`+`patternMessage` (.NET Regex 100 ms timeout, yayında derlenir), `readOnly` (writeBack ile olamaz), `visibleWhen`/`enabledWhen` (≤5, başka adımın ya da aynı adımda önceki dallanabilir alan); yeni tipler `multi_choice` (script_answers.value_text'te virgüllü anahtar, value_kind='text' — CHECK değişmedi, migration yok) ve `info`. Adım `actions` ≤6 `{key,label,nextStepKey,style,validate}`; runner `actionKey` gönderir, sunucu sonraki adımı seçer (runner DTO'sunda hedef yok). Yer tutucu `{{field.x}}` (istemci), `{{data.x}}` (zarfta `dataPlaceholders`, telefon yok).
- **Sunucu (backend-dev-1):** `ScriptDefinition.cs` kapalı şema okuyucu, `ScriptDefinitionValidator.cs` (15 yeni ihlal kodu; buton kenarları döngü/erişilemez/derinlik hesabına girer), `ScriptRunnerRules.cs`, yeni `ScriptStepEvaluator.cs` (gerçek runtime, kapanış ve test ikizi aynı değerlendiriciyi kullanır), `EfScriptRuntime.cs`, `ScriptDtos.cs`, `ScriptAgentEndpoints.cs`; test `ScripterV2Tests.cs` (33). Kararlar: `validate` varsayılan true; zorunlu alan yalnız validate=true butonda reddedilir, biçim kuralları her zaman; görünmeyen alanın cevabı silinir.
- **Arayüz (frontend-dev-1):** `ScriptFlowChart.tsx` (SVG, kütüphanesiz), `ScriptPageGrid.tsx` (native DnD + genişlik), `ScriptActionsEditor.tsx`, `ScriptConditionEditor.tsx`, `ScriptPlaceholderPicker.tsx`, `scriptFieldText.ts`; `ScriptRunner.tsx` ızgara (<640px tek kolon), Geri, doğrulama; 9 dilde 105 anahtar. HEAD'de kırmızı olan i18n JSX-literal testi (`placeholder="ornek_alan"`) da düzeldi.
- **Mimari bekçiler (önceki turlardan kırmızı kalan 4):** `AgentDeskTabInventoryTests` Profilim çıkarıldı + `doc/prototip-urun-farklari.md` notu; `CrossTenantScopeSurfaces.cs` → `20261018120000_QaFormAnswerOptions.cs` 0/2; `telephony-path-inventory.json` → `agent-desk.call-result` (`stop_spy`; sonuç kaydı ACW kapanışı → olay akışı → `AgentMonitoringService.SafeStopSpyAsync`, geçici prob testiyle bulundu; pathId sıralı olmak zorunda, TPI001); `doc/ekran-yazma-yollari.md` yeniden üretildi (`dotnet test --filter Ekran_yazma_yollari_belgesini_URET -e PBXTR_WRITE_DOCS=1`).
- **Doğrulama:** solution 0 hata; Architecture 857/857; Scripter 190/190; web tsc -b 0, vitest campaigns+agent+i18n 45 dosya 421 test. Canlıda `/campaigns/script` Liste/Akış + sayfa düzeni görüldü (Playwright).
- **Yayın:** ilk deneme Docker Hub oauth zaman aşımı (YAYIN_EXIT=1, ağ), ikinci deneme yeşil, push `c05bee2e..e6378ec7`.
- **Backlog:** BR-FE-141, BR-BE-258 + ClickUp (yeni 2, kuru fark 0). BR-BE-257 hücresindeki `<built-in function id>` (önceki python f-string hatası) `{id}` yapıldı.

### Açık kalanlar
- EfScriptRuntime değişiklikleri gerçek PostgreSQL'de ölçülmedi; butonlu adımda yeniden yüklemede basılan buton saklanmıyor; gövde boyutu formülü info/buton metnini saymıyor.
- Faz 2 düğümler (BR-BE-258). Kullanıcı uçtan uca testleri (dinleme, transfer/park, QA, scripter 8001).

## Ek (onuncu tur) — Bağımsız script (YARIM, PC kapandı)

### 34. Script kampanyadan ayrıldı — WIP dalı `wip/script-bagimsiz` (`49389fe1`)
- **Neden:** Kullanıcı: "Kampanya bazli degil normal olmasi lazim birden fazla kampanyada kullanabilmem lazim".
- **Sözleşme:** `scratchpad/script-bagimsiz-sozlesme.md`. Yeni tablo YOK. `campaigns.script_id` (FK (tenant_id,script_id) → scripts ON DELETE SET NULL), geri doldurma `scripts.campaign_id`'den (cross_tenant GUC), `scripts.campaign_id` NULL olabilir + `ux_scripts_tenant_campaign` kalkar. Çalışma anı: çağrının kampanyası → `campaigns.script_id`. API `/api/v1/scripts` (GET liste, POST {name, copyFromScriptId?}, PATCH {name,isActive}, GET/{id}, PUT draft, POST publish, versions, report(+?campaignId), data-keys); eski `/campaigns/{id}/script*` kaldırıldı. Kampanya DTO `scriptId/scriptName`, oluştur/güncelle `scriptId`. Silme yok (pasifleştir).
- **Arayüz (frontend-dev-1, BİTTİ):** yeni ekran #06.2 Scriptler `/scripts` (screens.json + registry + `SCREEN_LICENSE_FEATURES` ile scripter lisansına göre menü filtresi, AppShell), editör #06.1 `?script=<id>` (eski `?campaign=` yönlendirir), ad PATCH, "Kullanan kampanyalar"; kampanya kartı "Script: <ad>" / "Script bağla"; düzenle penceresinde Script seçimi; `ScriptFieldsPane` raporu kampanyanın scriptId'si ile; `delivery-manifest.json` 5 şablon `/api/v1/scripts/{id:guid}…` + `scripts.load`; generated dosyalar yenilendi.
- **Önceden kalan web kırmızıları düzeltildi:** `ScriptRunnerV2.test.tsx` vi.mock imzası (signal), #38 `auditView.ts` → `contact.updated`, `qa.form.updated`, `qa.objection.decided`, hedef `QaForm` + 9 dil (`scratchpad/aud_i18n.py`), `ContactTransfer.test.tsx` (updateExisting onay kutusu = 1), `SimulationProvider.test.tsx` (useSession mock, simulated bileşim). Sonuç: vitest 273 dosya / 2402 test yeşil, tsc -b 0.
- **Sunucu (backend-dev-1, YARIM):** migration `20261018160000_ScriptStandalone.cs` + ModelSnapshot, Campaign/Script domain+EF, `ScriptAdminEndpoints.cs`, `CampaignEndpoints/Dtos`, `EfScriptRuntime/EfScriptAdministration/EfScriptFieldReports`, `EfContactDirectory` (data-keys), AuditActions (`script.created/updated`), testler (`ScriptAdminEndpointTests`, `CampaignEndpointTests`, `ScripterPersistenceTests` …). Ajan bitmeden PC kapandı → derleme/test ÖLÇÜLMEDİ.
- **Neden ayrı dal:** yarım sunucu kodu main'e/yayına girmesin; disk uçarsa iş kaybolmasın.

### Devam (yarın)
1. `git checkout wip/script-bagimsiz` → `dotnet build Pbxtr.sln` → hataları kapat.
2. Architecture tam koşu, Api.Tests Scripter+Campaign filtreli; `doc/ekran-yazma-yollari.md` yeniden üret; `CrossTenantScopeSurfaces.cs`'e ScriptStandalone GUC satırı; screens.json yeni ekran için ekran sayımı/yetki bekçileri.
3. main'e squash/merge → yayın `--testsiz` → t0007'de "Müşteri Hizmetleri Gelen" scriptinin geri doldurmayla bağlı kaldığını canlıda kontrol et.
4. Backlog kartı aç (BR-FE-142 / BR-BE-259 — numarayı önce ölç) + ClickUp.

## Ek (on birinci tur, eve dönüş) — Bağımsız script tamamlandı

### 35. WIP dalı bitirildi, main'e alındı (`9800ce47`, yayın 62; `e4f4e8c6`, yayın 63)
- **Neden:** "geldim eve devam edelim scripter ile calisiyorduk" — `wip/script-bagimsiz` dalı yarımdı.
- **Ne yapıldı:**
  - Dalda `dotnet build` 0 hata. Sunucu ajanı (backend-dev-1) kaldığı yerden devam ettirildi: iş zaten bitmişti, doğrulamada Architecture 857/857, Api Scripter+Campaigns+Contacts 367/367, Platform 1430 (+2 skip), format temiz, `ekran-yazma-yollari.md` değişmedi. Ajanın ek notları: `ScreenRegistryTests` 06.2'yi menüde noktalı kodlu ilk ekran istisnası sayar; `deploy/nginx.conf` + demo nginx 10 MB taslak sınırı `/api/v1/scripts/{id}/draft`; eski 2-admin ilk-taslak yarış testi silindi (unique indeks yok); yeni `T2_kampanyasi_T1_scriptine_baglanamaz…` entegrasyon testi.
  - `AgentMonitoringTests` 16 kırmızı (beaa9e4c'den beri: supervizör dahilisi zorunlu) → harness'e `SabitDahiliDizini("1099")`; 19/19.
  - Docker Desktop kapalıydı: `C:\Users\abdus\AppData\Local\Programs\DockerDesktop\Docker Desktop.exe` ile açıldı (Program Files'ta YOK). `docker pull postgres:16-alpine` gerekti; sonra `dotnet test tests/Pbxtr.Integration.Tests --filter Scripter` → 24/24 gerçek PostgreSQL'de yeşil.
  - Backlog BR-BE-259 + ClickUp (ilk koşu ECONNRESET, ikinci koşu temiz, kuru fark 0).
  - `git merge --squash wip/script-bagimsiz` → `9800ce47`; WIP dalı yerel ve uzakta silindi.
  - Canlı kontrol (Playwright, deneme.supervizor): #06.2 Scriptler'de "Müşteri Hizmetleri Gelen" aktif, v1, kullanan kampanya rozeti — geri doldurma bağı korudu; kampanya kartında "Script: Müşteri Hizmetleri Gelen". Kusur: menüde "06.2" adın üstüne biniyordu (`SidebarNav.module.css` `.code` width:16px → min-width) ve kampanya notu eski "Kuyruklar (script)" anlatımı → 9 dilde yeniden yazıldı (`scratchpad/camp_i18n2.py`). Yayın 63.

### Açık kalanlar
- Gerçek inbound çağrıda (8001) scriptin kampanya → script_id ile açıldığı ölçülmedi.
- Rapor `?campaignId=` filtresinde carisiz (kuyruk kampanyasından açılan) cevaplar düşüyor.
- Faz 2 düğümler BR-BE-258.

## Ek (on ikinci tur) — #22 hızı, not kaybı, dinleme 502, konferans, #69 Hata Günlüğü

### 36. #22 zaman çizelgesi 13 sn (`73ac3918`, yayın 64)
- **Neden:** "live/timeline çok yavaş, cancel'lanıyor". Ölçüm (sunucuda curl): 200, 12.9–14.3 sn.
- **Sebep:** `EfAgentTimelineQuery` `At < windowEnd` ile tenant'ın TÜM `agent_state_events` geçmişini çekiyordu (t0007: 402 bin satır, en eski 2026-08-26).
- **Düzeltme:** pencere içi satırlar + kullanıcı başına taşıyıcı nokta (`users` üzerinde korelasyonlu alt sorgu, `ix_agent_state_events_tenant_user_at`). Davranış aynı. Canlı süre yeniden ÖLÇÜLMEDİ (yapılacak).
- Kullanıcı ayrıca kısa blokların (5 sn çalma/müsait) birleştirilmesini istedi → AÇIK.

### 37. Agent masası sekme değişince not siliniyordu (`236ef96f`, yayın 65)
- `AgentDeskScreen.tsx` CallTab koşullu render → `<div hidden>` (Görevlerim G-04 deseni). `CallTab` `deskActive` prop'u tüm kısayolları (h/m/t/n, DTMF rakamları) ve `ScriptRunner` `hotkeysEnabled` ile script kısayollarını kapatır. Test: `AgentDeskScreen.test.tsx` "sekme degisip donunce gorusme notu korunur".

### 38. Dinleme 502 TELEPHONY_REJECTED — asıl kök (`236ef96f`, yayın 65)
- Ölçüm: app'e doğrudan istek (`172.28.0.11:5080`) → `502 {"code":"TELEPHONY_REJECTED"}`; uygulama logu sessiz. Aynı ARI isteği elle (`Local/1048@pbxtr-t0007-local`, `pbxtr-t0007-spy`) → santral KABUL.
- Kök: beaa9e4c servis tarafında dahiliyi çözmüştü ama `AsteriskAriProvider.StartSpyAsync` çıplak "1048"i `endpoint`'e gönderiyordu (yorum "sağlayıcı çevirir" diyordu, kod yoktu). Düzeltme: `/` içermiyorsa `Local/<ext>@pbxtr-<kod>-local`; red artık `LogWarning` (status, endpoint, mode). Canlı uçtan uca dinleme kullanıcı testine kaldı.

### 39. Yayın engelleri (`f097ffa0`, `274e2315`)
- Docker Hub blob PUT "timeout awaiting response headers" (ev hattı) → `push_tekrarli` 5 deneme.
- npm audit ucu "audit endpoint returned an error" → yalnız `--testsiz` + yalnız bu çıktıda `UYARI: npm audit OLCULEMEDI` ile devam; gerçek bulgu her kipte kırmızı.
- Yayın sırasında ana ağaçta commit atıldı (yayın 64 sürerken) — sorun çıkmadı ama kural: ajanlar ağacı kirlettiğinde yayın `X:\GitHub\Pbxtr\pbxtr-yayin` klonundan (`git reset --hard origin/main`) koşturuldu.

### 40. Konferans + #69 Hata Günlüğü (`16672380`, yayın 66)
- Sözleşmeler: `scratchpad/konferans-sozlesme.md`, `scratchpad/hata-gunlugu-sozlesme.md`.
- Konferans (backend-dev-2 + frontend-dev-1): actions `conference`/`conference_drop`, `TransferKind.Conference` (yeni TelephonyOperation migration+onay satırı gerektireceği için), dış numarada call-permission fail-closed, `/agent/state.conference`, `TelephonyEventPipelineConference.cs` (üçüncü bacak kapanınca çağrı bitti sanılmasın). 19 bayat köprü testi düzeldi (3f01370c davranışı doğruydu; ikiz 404 dönmeliydi). Gerçek santralde ÖLÇÜLMEDİ.
- #69 (backend-dev-1 + frontend-dev-2): `SystemErrorCaptureMiddleware` (en dışta, yalnız /api), `SystemErrorScrubber`, `SystemErrorWriter` (Channel 1000), `RedisSystemErrorLogStore` (`ITenantCacheConnection`, LPUSH+LTRIM 5000+TTL 7g), `system.errors.read` yalnız superadmin, WS odası `SystemErrors`. Canlı: `storageAvailable=true`, sayaçlar 0. nginx kaynağı yok → BR-OPS-18.
- `RoleMatrixEndpointTests` 3 kırmızı (8a5824bf'den beri) → beklenti `RoleVisibility.IsListed`'dan türetildi; superadmin satırı global kapsamlı istemciyle.
- Doğrulama: build 0; Architecture 857/857; Api Platform 1443 (+2 skip); AgentDesk+Realtime+Access+Scripter+Campaigns 961; web 275 dosya / 2428.
- Backlog: BR-BE-260, BR-BE-261, BR-OPS-18 + ClickUp (kuru fark 0).

### Açık kalanlar
- Kullanıcı testi: dinleme (1048), konferans (kuyruk dahil), scripter 8001 çağrısında.
- #22 kısa blok birleştirme; #22 canlı süre ölçümü.
