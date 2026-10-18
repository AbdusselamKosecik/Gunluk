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
- CDR listesinde yön `unknown`, agent/kuyruk boş, cevaplanan çağrıda numara "—" (ekran görüntüsünde görüldü) — ayrı kart açılmalı.
- 443'te Sınıf B uçları proxy'leniyor (nginx-dogrula.sh gate B) — ölçülmeli.
