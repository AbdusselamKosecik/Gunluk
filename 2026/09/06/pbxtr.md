# pbxtr — 2026-09-06

## Bağlam
`/goal Eksikleri tamamlarmisin?` ile başlandı; kullanıcı ek olarak (a) softphone ve gelen
çağrı karşılama kısmında kullanıcı kolaylığı düzenlemeleri, (b) kullanıcıların yetkileri ve
görmesi gereken ekranların analizini istedi. Demo hesap listesini verdi (t0000/t0007/t0012;
ortak parola paylaşıldı — hiçbir dosyaya yazılmadı). Başlangıç: `ff3a8c82`, yayın 19
(`ff3a8c82`) log'u 5 Eylül 06:00'da imaj adımında kesilmiş; staging hâlâ `b588689b` (18 commit
geride, Sprint-33'ün tamamı yayında değil).

## Yapılanlar

### 1. Yayın 19 neden yarım kaldı → Docker Desktop kapalıydı; yayın 20/21
- **Neden:** yayın 19 tüm kapıları (Architecture 353, Integration 630, 4 shard, DB kapıları
  "TÜM KAPILAR YEŞİL") geçmiş, `docker build` sırasında log durmuş; `docker version` →
  "npipe dockerDesktopLinuxEngine bulunamadı". Docker Desktop kullanıcı-yerel kurulu:
  `C:\Users\abdus\AppData\Local\Programs\DockerDesktop\Docker Desktop.exe` (Program Files'da
  YOK).
- **Ne yapıldı:** Docker Desktop başlatıldı (~90 sn), klonda yayın 20 koşuldu
  (`X:/GitHub/Pbxtr/pbxtr-yayin`, cmd.exe → bash.exe deseni, log scratchpad'de).
- **Sonuç:** yayın 20 API shard 0'da 154 testten sonra **"Test host process crashed: Fatal
  error. Internal CLR error (0x80131506)"** — test hatası değil; aynı anda üç ajan
  dotnet/vitest koşturuyordu (37 GB boş RAM). Ajanlar bitince **yayın 21** (`45852643`)
  başlatıldı — sonucu bu dosyanın sonunda.
- **Komutlar:**
  ```powershell
  Start-Process "C:\Users\abdus\AppData\Local\Programs\DockerDesktop\Docker Desktop.exe"
  # yayın: Start-Process cmd.exe '/c ""C:\Program Files\Git\bin\bash.exe" -lc "cd /x/GitHub/Pbxtr/pbxtr-yayin && git pull --ff-only && bash deploy/yerel-yayin.sh --yayinla; echo EXIT=$?" > yayinN.log 2>&1"'
  ```
- **Hafıza:** `testhost-clr-cokmesi-esz-yuk.md`.

### 2. Canlı ölçüm: softphone + gelen çağrı (staging, demo.agent, Chrome DevTools MCP)
- **Bulgular:**
  1. Başlık "Müsait 00:11" (yeşil) derken masa "DURUMUM Offline / Bu hesabın canlı agent
     satırı yok"; menüden "Molada" seçince yalnızca yerel etiket değişti, istek gitmedi.
     Kaynak: `shell/AgentStatusProvider.tsx` yorumu "SPRINT-01 KAPSAMI: durum YEREL tutulur"
     — 33 sprint boyunca hiç bağlanmamış. Menüde "Çağrıda/Çağrı sonrası/Offline" elle
     seçilebiliyordu.
  2. Yazılım telefonu kayıtlı (`t0007-wrtc-1042` contact var) ama agent çağrı alamıyor:
     santralde `queue show` → t0007'nin üç kuyruğu da **"No Members"**. Provisioning kasten üye
     yazmıyor (`; ---- UYE YOK: uyelik AMI QueueAdd... ----`), `persistentmembers = no`,
     üyelik yalnız CUD anında itiliyor (`QueueMembershipPush`) → restart/ilk kurulumdan sonra
     kimse kuyrukta değil.
  3. `AgentInterventionService.cs` üye adresi `request.UserId.ToString("D")` ("o sprintin
     işidir" yorumu) → gerçek AMI'de `Interface=<guid>` → agent molası ve süpervizör müdahalesi
     "Interface not found".
  4. AMI `QueueMemberStatus/Pause`, `AgentCalled/Connect/Complete` olayları yalnız
     `member_name` taşıyor; pipeline `user_id` yoksa canlı agent satırı yazmıyor
     (`TelephonyEventPipeline.cs:1173`) → gerçek Asterisk'ten Redis satırı hiç oluşmuyor,
     `inRoster=false` kalıcı. Simülasyon `user_id`'yi kendisi yazdığı için testler yeşildi.
  5. Zil sesi yok (`playTestTone` yalnız hoparlör testi). Staging'de yalnız `t0007-wrtc-*`
     endpoint'leri var, masa telefonu endpoint'leri yok (pjsip dizini 30 Ağustos).
- **Hafıza:** `sprint-01-yerel-taslak-hic-baglanmadi.md`.

### 3. Backend: gerçek AMI ile agent varlık zinciri (`backend-dev-2`, TDD + mutasyon)
- **Ne yapıldı:** (1) `QueueMemberIdentityEnricher` + saf `MemberInterfaceParser`
  (`Local/1042@pbxtr-t0007-local/n`, `PJSIP/t0007-[wrtc-]1042`; kanal eki reddedilir) +
  `EfQueueMemberDirectory` (extensions ⋈ users, tenant GUC'lu kendi transaction'ı) +
  `ITenantCache.GetOrSetAsync` 60 sn; `AmiAriEventConsumer` Map → **Enrich** → Ingest.
  (2) `AgentInterventionService` → `AsteriskObjectName.MemberEndpoint(tenantCode, ext)`;
  dahili yoksa sağlayıcıya gitmeden 409 `AGENT_NOT_STAFFED` (önceden 502).
  (3) `QueueMembershipSyncJob` (`queue-membership-sync` = kilit 32): `queue_members × aktif
  kuyruk/kullanıcı/tenant × min(dahili) × suppressed_by_leave=false`; kuyruk başına
  `QueueStatus` okuyup yalnız eksik üyeye `QueueAdd`; asla çıkarmaz; `NotConnected` sessiz.
  (4) `AmiDeviceState`: AST_DEVICE_* → pbxtr (1→available, 2/3/7/8→on_call, 6→ringing,
  4/5→offline, 0/tanımsız→olay yok, Paused=1→break + kapalı küme gerekçe);
  `QueueMember`/`QueueMemberAdded`/`Removed` aynı olay tipine eşlenir → üyelik senkronu
  ekler eklemez canlı satır doğar.
- **Dokunulan dosyalar:** `src/Pbxtr.Infrastructure/Telephony/Asterisk/{MemberInterfaceParser,
  IQueueMemberDirectory,EfQueueMemberDirectory,QueueMemberIdentityEnricher,AmiDeviceState,
  AmiEventMapper,AmiAriEventConsumer}.cs`, `Telephony/Live/{AgentInterventionService,
  ITenantCodeReader}.cs`, `BackgroundJobs/QueueMembershipSyncJob.cs`, `BackgroundJobLocks.cs`,
  DI, `AgentEndpoints.cs`/`LiveEndpoints.cs` (409), testler
  `QueueMemberIdentityEnricherTests` (21), `AmiMemberStatusMappingTests` (26),
  `AgentInterventionTests` (+3), `QueueMembershipSyncJobTests` (8, gerçek PG), bekçi
  allowlist'leri (RawSql, CrossTenantScope, BackgroundJobLocks).
- **Doğrulama:** Api filtre 1120/1120 + 915/915, Architecture 353/353, Integration 18/18,
  `dotnet format` temiz; 16 mutasyon kırmızı (GUID adresi geri koyma, tenant kodu eşitliği,
  `user_id_x`, kanal eki, önbellek atlama, `suppressed_by_leave`, "zaten var" atlaması,
  `NotConnected`, pasif kullanıcı, Paused ezmesi, INUSE→available, ham Status, gerekçe
  kümesi, UNKNOWN→available, Removed→offline).
- **Commit:** `0afaf067`, `45852643`. **Gerçek santralde doğrulanmadı** (yayın 21 sonrası
  `queue show` + `/agent/state.inRoster`).

### 4. Frontend: agent karşılama kolaylığı (`frontend-dev-2` + `frontend-dev-1`)
- **Ne yapıldı:** `AgentStatusProvider` sunucu kaynaklı (`/agent/state`,
  `agent.status.changed`/`call.*` reload 400 ms; `since` = sunucu `sinceAt`);
  `HeaderStatusMenu` yalnız **Müsait** (`end_break`) ve **Mola › gerekçe** (`/me.breakReasons`);
  `inRoster=false` → tıklanmaz "Kadroda değil"; yüklemede "—"; iyimser geçiş yok; 504 sonrası
  gönderim kilidi. `useRingtone` (WebAudio 440+480 Hz, 1 sn/2 sn, 3 dk üst sınır, `setSinkId`,
  `blocked` durumu `role="status"`), `ringtonePreference` (localStorage, varsayılan açık),
  `useTitleFlash` (`useTicker(500)`), modal odak "Kabul et" + Enter; `ConsoleScreen` aynı
  modalı kullandığı için ona da bağlandı. i18n 9 dil × (9 `shell.status.*` + 6
  `incoming.*`/`softphone.ringtone.*`). `AmbientClockGuardTests` baseline
  (`AgentStatusProvider.tsx = 2`) düşürüldü.
- **Doğrulama:** vitest tam 169 dosya / 1492 test, `tsc -b` 0 hata, Architecture 353; mutasyon
  6 kırmızı (iyimser güncelleme, `offline` seçilebilir, cleanup `stop`, sessiz kip, odak,
  TitleFlash).
- **Commit:** `c111ca35`. Sapma defteri §13.2'ye iki satır (`45852643`).

### 5. Rol → yetki → ekran analizi + Karar #30
- **Ne yapıldı:** `doc/analiz/rol-yetki-ekran-analizi-2026-09-06.md` (69 ekran × 7 rol,
  seed'den betikle; `doc/rol-ekran-matrisi.md` ile birebir). Bulgular: 117 tasarım-sapması
  hücresinin 110'u yazılı değildi (2026-08-29 kullanıcı matrisi); R1 admin `bundle.system`'in
  tamamını taşıyor (CLAUDE.md §5 ile çelişki); R7 owner/supervisor `recording.listen` yok
  (`requires phone.unmask`) → #20 duymadan puanlıyor; F6 süpervizör #09/#11 görmez; `operator`
  rolü yok; `demo-kullanicilari.md` açılış ekranları bayat; `ekran-rol-matrisi.json` 9 hücre
  bayat ve testsiz.
- **Kurul (10 üye):** (1) A 6 / B 4 → **Seçenek C bölme** ŞARTLI ONAY (`observe` admin'de,
  `operate` yalnız superadmin; sniff/command `requires phone.unmask`; #63 çıktısı maskeli) —
  2026-08-29 matrisini daraltır, **kullanıcı onayı bekliyor** (BR-SEC-02). (2) 10/10 A′:
  `recording.listen`'ın `phone.unmask` bağı kalkar, hassas kalır, owner+supervisor extras,
  `nonDelegable`, indirme bağı aynen (BR-BE-40, S34). (3) A 4 / B 6 → RED, B kalır BİLİNÇLİ
  (ek Agent rolü yolu; ölçüm kartı BR-QA-05). (4) 10/10 B: CLAUDE.md §1 düzeltildi.
- **Belge:** `prototip-urun-farklari.md` §8.3 (F1–F9 BİLİNÇLİ/KURULA SORULACAK) + §49.1
  DÜZELTME, `demo-kullanicilari.md` açılış sütunu, seed `$comment`, `backlog.md:2520` notu;
  Karar #30 `kurul-kararlari.md`; kartlar BR-SEC-02, BR-BE-40, BR-AST-15 (PCI `MixMonitor`
  pause ölçümü), BR-QA-05, BR-DOC-03, BR-BE-41/42, BR-FE-22/23.
- **Commit:** `d749d420`.

## Kararlar
- Kullanıcı uzakta; açık kararlar kurula götürüldü (hafıza kuralı). Karar #30/1 kullanıcının
  2026-08-29 matrisini daraltır → uygulanmadı, onay bekliyor.
- Agent'a ayrı "Kuyruğa gir" düğmesi eklenmedi: üyelik DB'den senkron job ile; agent'ın
  seçebildiği yalnız Müsait/Mola (Karar #12/4 "durum sunucudan gelir").
- "Maskeli oynatma" terimi kullanılmadı (Şeytan: ses maskelenemez); karar "bağ çözülür".

## Tuzaklar
- `node -e` ve heredoc içinde `\` ve `'` kaçışları yutuldu; betik dosyaya yazılıp regex
  (`/X:[\\\/]GitHub.../g`) ile koşuldu. `python` Windows'ta Store alias'ına gidiyor → yok say.
- Yayın koşarken paralel ajan `dotnet test`/`vitest` → testhost CLR çökmesi (yayın 20).
- Docker Desktop kullanıcı-yerel kurulu; Program Files yolu yok.
- Ölü `tail -f` izleyici: yayın süreci bitince Monitor kendini kapatmıyor, `TaskStop` gerekti.

## Açık kalanlar / sonraki adım
1. **Yayın 21** (`45852643`) sonucu; yeşilse staging'de gerçek doğrulama: `docker exec
   pbxtr-asterisk asterisk -rx 'queue show'` üye listesi (sync job), demo.agent ile
   `/agent/state.inRoster=true`, başlık durumu, zil sesi.
2. **Kullanıcı kararı:** BR-SEC-02 (admin sistem paketinin bölünmesi 2026-08-29 matrisini
   daraltır). BR-SYS-34, BR-SEC-01, BR-6 aynen bekliyor.
3. Sprint-34 "başla" bekliyor; BR-BE-40 (kayıt dinleme bağı) S34'e kondu.
4. BR-FE-23: zil/modal yalnız #09/#15'te; kabuğa taşıma frontend-uzmani kararı.
5. BR-AST-15: IVR kart düğümünde `MixMonitor` pause ölçümü (PCI).

### 6. Yayın 21 kırmızı → düzeltme → yayın 22
- **Yayın 21** (`45852643`): entegrasyon 634/638. (a) `LiveAgentActionHttpTests` 409 — yeni
  `AGENT_NOT_STAFFED` yolu; fikstür dahili tohumlamıyordu, canlı satırda da yoktu.
  (b) `AgentMembershipProductPathHttpTests` ×2 + `DeliveryProofHttpRunnerTests.Agents_save`
  409 — yerelde tek başına 3/3 yeşil; tam takımda **`QueueMembershipSyncJobTests` tohumlarını
  silmiyordu**, kalan dahililer t0007 `agent_limit=10`'u aşınca `ConfigRenderGuard.AssertAgentQuota`
  → `PROVISIONING_BLOCKED` 409 (`extensions.count#-:out-of-range`); ilk temizlik denemesi
  `pbxtr_owner` NOBYPASSRLS olduğu için yalnız `app.tenant_id` ile **sessizce 0 satır** sildi.
- **Düzeltme (`5b26c85c`):** müdahalede dahili önce canlı satırdan, yoksa mevcut
  `IAgentExtensionDirectory.ResolveExtensionAsync` (yeni port açılmadı), o da yoksa 409;
  `LiveAgentActionHttpTests` '7001' tohumlar/siler; sync testleri `ExecuteCrossAsync` ile
  temizler ve kalan satır ≠ 0 ise fırlatır; tohum 4 haneli. Integration TAM 638/638, Api
  `Realtime|AgentDesk` 253, Architecture 353, format temiz.
- **Ders:** paylaşılan fikstür tenant'ında tohum bırakan test, sınıfın kendisinde değil
  *başka* sınıfta ve yalnız tam takımda kırmızı üretir; RLS altında owner ile silme sessizce
  sıfır satır siler — temizlik "kalan = 0" ile ölçülmeli. (`LeaveEnforcementJobTests` aynı
  sınıf, bugün limitin altında — dokunulmadı.)
- **Yayın 22** (`5b26c85c`) koşuda.

### 7. Yayın 22 kırmızı → yayın 23
- **Yayın 22** (`5b26c85c`): entegrasyon 636/638 — `AgentMembershipProductPathHttpTests` ×2,
  `Reset` içinde `pk_dial_numbers` 23505 ('945x'). Tek rastgele kaynak: sync testlerinin
  6000–9999 kuyruk numarası (random+4000) sabit '9451/9452'ye denk gelmiş (~%0,5/koşu);
  belirti yine başka sınıfta. Yerelde tam takım 638/638 yeşildi (rastgele).
- **Düzeltme:** numaralar sayaçlı blok (dahili 2100–2199, kuyruk 3100–3199; entegrasyon
  takımında 2xxx/3xxx sabit numara yok — grep), tohum satırlar yazılmadan önce `_seeds`'e,
  temizlik dahili+kuyruk+`dial_numbers` kalanını sayar. Yerel tam entegrasyon 638/638.
- **Yayın 23** koşuda.

### 8. Yayın 23 kırmızı → yayın 24
- **Yayın 23** (`4d3052c3`): entegrasyon 638/638 yeşil; API shard 0'da 1 kırmızı —
  `LoginEnumerationTests.Unknown_user_and_wrong_password_take_the_same_time`: p95 oranı %48
  (bilinmeyen 7.26 ms, hatalı parola 15.03 ms). Kimlik kodu bugün değişmedi; yayın yolunda 4
  shard paralel koşuyor, p95 kuyruk değeri tek seride şişti. Yerelde 3/3 yeşil.
- **Düzeltme:** oran medyanla (p50) ölçülür, eşik %60 aynı. Mutasyon: `VerifyDummy()`
  kaldırılınca medyan oranı %0 → kırmızı (gerçek açık hâlâ yakalanıyor). Geri alındı.
- **Yayın 24** koşuda.

### 9. Yayın 24 kırmızı → yayın 25
- **Yayın 24** (`06a91fac`): entegrasyon 638/638; frontend 1491/1492 —
  `SessionProvider.test.tsx` "yetki değişti sinyalinde ÖNCE jeton yenilenir": açılışta
  beklenen 1 yenileme, gelen 2. Sebep testin kendi yarışı: sinyal sonrası yenileme
  `Math.random()*400` ms jitter'lı; 0'a yakın düşünce ikinci yenileme ilk iddiadan önce
  geliyor. Yerelde 5/5 yeşil, yayın 23'te aynı kod yeşildi.
- **Düzeltme:** testte `vi.spyOn(Math,'random').mockReturnValue(1)` (400 ms), sonunda
  `mockRestore`; ürün jitter'ı (K1 şart 9) aynen. 5/5 yeşil, `tsc -b` temiz.
- **Yayın 25** koşuda.

### 10. Yayın 25 kırmızı (staging migrate) → onarım migration'ı → yayın 26
- **Yayın 25** (`6d4a7989`): 27 kapı + backend + frontend + 4 API shard + entegrasyon + DB
  kapıları yeşil, imaj `tekbirsoft/pbxtr:demo-6d4a7989ad82` push edildi; **staging migrate
  adımı düştü**: `Sprint33FinalGuard` içindeki `pbxtr_assert_sys_function_guard()` iddiası
  `ensure_future_partitions` için md5 `bec5b0d5…` buldu, kanonik `3e3a3215…`
  (`deploy/db/sys-functions.expected`). Staging otomatik `demo-b588689b0a8c`'e geri döndü
  (pbxtr.com 200); migration geçmişi `20260904193000`'a kadar uygulanmış kaldı.
- **Neden:** `e688099f` (2 Eylül, "partition penceresi bir ay geriye") şablon gövdesini
  `deploy/db/01-rls-template.sql`'de değiştirdi ama onu yeniden uygulayan migration yazılmadı.
  Üretim `migrate` yolu (`MaintenanceRunner`: `Database.Migrate()` + iddialar) şablonu
  kendiliğinden koşmaz; `ci-check.sh`'in "01 her yükseltmede önce koşar" satırı yalnızca yerel
  taze zincir içindir. Taze zincir (`InitialSchema` güncel şablonu okur) yeni gövdeyi aldı,
  staging eskisinde kaldı → 4 gün boyunca yerelde yeşil, sahada kırmızı.
- **Ölçüm:** staging `pg_proc` dökümü (`ssh root@176.88.41.220 docker exec pbxtr-postgres
  psql … md5(prosrc)`) ↔ fixture join: 22 fonksiyondan **yalnızca** `ensure_future_partitions`
  sapmış.
- **Ne yapıldı:** `20260904195000_PartitionWindowTemplateRefresh` — terminalden ÖNCE sıralanır
  (iddia `20260904200000`'de kalır, Karar #23/Ş23-7); `Up` 01+02'yi yeniden uygular (CREATE OR
  REPLACE, emsal `HostMetrics` adım 4) ve `ensure_future_partitions(3)` ile ufku hemen kapatır;
  `Down` e688099f öncesi gövdeyi birebir geri yazar. Expand-only defterine
  (`deploy/migration-expand-legacy.blobs`) gerekçeli blob satırı; `CrossTenantScopeGuardTests`
  SECURITY DEFINER envanterine satır (Down'daki eski gövde SECURITY DEFINER).
- **Dokunulan dosyalar:** `src/Pbxtr.Infrastructure/Persistence/Migrations/20260904195000_PartitionWindowTemplateRefresh.cs`,
  `deploy/migration-expand-legacy.blobs`, `tests/Pbxtr.Architecture.Tests/CrossTenantScopeGuardTests.cs`
- **Komutlar / doğrulama:**
  ```bash
  dotnet test tests/Pbxtr.Architecture.Tests --filter "FullyQualifiedName~Migration|FullyQualifiedName~SysFunction|FullyQualifiedName~CrossTenantScope|FullyQualifiedName~FinalDelivery"   # 25/25
  bash deploy/db-kapilari-docker.sh          # taze zincir + ci-check.sh, EXIT=0
  # staging replikası (postgres:16-alpine, port 55433): 00-roles → `dotnet ef database update 20260904193000_…`
  #   → eski gövde psql ile geri yazıldı (md5 bec5… = staging) → `dotnet ef database update`
  #   → 195000 + 200000 uygulandı, md5 3e3a…, call_events_2026_08 açıldı
  ```
- **Commit:** `6e7aa24f` — fix(db): 01-rls-template govde degisikligi mevcut kurulumlara
  ulasmiyordu — PartitionWindowTemplateRefresh
- **Yayın 26** (`6e7aa24f`) koşuda.
- **Ders (hafızaya yazıldı):** 01/02'de gövde değiştiren her commit yanına refresh migration
  koy; yayından önce "eski gövde → migration → md5" replikasını ölç.

### 11. Yayın 26 yeşil → staging ölçümü → üye olayı tenant çözümü (yayın 27)
- **Yayın 26** (`6e7aa24f`): 27 kapı, mimari 353/353, entegrasyon 638/638, DB kapıları,
  imaj `demo-6e7aa24f107a`, **staging migrate geçti** (`20260904195000` + `20260904200000`
  uygulandı). Staging canlı: `ensure_future_partitions` md5 `3e3a…`, iddia temiz (20 fonksiyon),
  `call_events_2026_08` açıldı, pbxtr.com 200.
- **İlk 5 dk tick:** `QueueMembershipSyncJob` t0007 için 9 üyelik ekledi — `queue show`:
  `t0007-musteri-hizmetleri` 6 üye (1042–1047), `t0007-tahsilat` 3 üye; t0012'nin 3 satırı
  `NO_SUCH_QUEUE` (staging confd yalnız demo.sahip/t0007 anahtarıyla çekiyor; t0012 santralde
  hiç yok) → **BR-AST-17** kart (kurul: düğüm başına N anahtar mı, platform paketi mi).
- **Asıl bulgu:** santralin yolladığı 9 `QueueMemberAdded` olayının 9'u da düşürüldü
  ("tenant'i cozulemedi, context=(null)"); demo.agent ekranı "Kadroda değil / Offline".
  Üye olaylarında kanal, bağlam, kanal değişkeni yok; `AmiTenantCode` yalnız o dördünü
  biliyordu. Birim testleri `Map(frame, tenantId)`'i tenant verilmiş çağırdığı için dalı hiç
  ölçmemişti.
- **Ne yapıldı:** kaynak 5 `Queue` öneki `^(t\d{4})-`, kaynak 6 `Interface/StateInterface`
  `@pbxtr-(t\d{4})-`; oneksiz/lab adları ve `t7-` yine çözülmez (kestirme yasağı). Düşürme
  uyarısı queue/interface basar. Belge `doc/mimari/asterisk-olay-eslemesi.md` §2.2 satır 5/6.
- **Dokunulan dosyalar:** `src/Pbxtr.Infrastructure/Telephony/Asterisk/AmiTenantCode.cs`,
  `…/AmiAriEventConsumer.cs`, `tests/Pbxtr.Api.Tests/Modules/Telephony/AmiEventMappingTests.cs`,
  `doc/mimari/asterisk-olay-eslemesi.md`, `yonetim/backlog.md` (BR-AST-17)
- **Doğrulama:** Api.Tests Telephony/Realtime 908/908; mutasyon (dosya stash): 2 pozitif
  kırmızı, 2 negatif yeşil; `dotnet format --verify-no-changes` temiz.
- **Commit:** `3a4039ad` — fix(telephony): uye olaylarinin tenant'i kuyruk adindan/uye
  arayuzunden cozulur
- **Yayın 27** (`3a4039ad`) koşuda. Bitince ölçülecek: tick sonrası düşürme uyarısı yok,
  demo.agent `inRoster=true` ve başlık menüsü (Müsait/Mola) çalışıyor.

### 12. Yayın 27 yeşil → staging uçtan uca kadro/mola ölçümü
- **Yayın 27** (`3a4039ad`): tüm aşamalar yeşil, imaj `demo-3a4039ad57e9`, staging migrate + sağlık
  geçti. Açılıştan beri "olay DUSURULDU" = **0**.
- **Ölçüm (staging, gerçek Asterisk):**
  1. `queue remove member Local/1042@pbxtr-t0007-local/n from t0007-tahsilat` → 5 dk tick'te
     `QueueMembershipSyncJob` "1 üyelik eklendi", `QueueMemberAdded` işlendi →
     Redis `pbxtr:{t0007}:live:agent:{userId}` = `{"status":"available","extension":"1042"}`.
  2. demo.agent girişi: başlık **"Durum: Müsait 00:50 ▾"** (sunucu `sinceAt`), ekranda
     "Molaya gir" + gerekçe listesi (dün "Kadroda değil / Offline" idi).
  3. "Molaya gir" → santral: iki kuyrukta `paused:break`, Redis `status=break`, ekran
     "Molada 00:04". "Moladan dön" → `paused` 0/2, başlık "Müsait 00:01".
- **Sonuç:** agent kadro → durum → santral eşlemesi uçtan uca gerçek. Kalan tek uyarı
  t0012 `NO_SUCH_QUEUE` (BR-AST-17, kurul).
- **Kullanıcı kararı bekleyenler:** BR-SEC-02 (Karar #30/1), BR-SYS-34, BR-SEC-01, BR-6;
  Sprint-34 "başla" bekliyor.

### 13. Kurul — Karar #31 (BR-AST-17, çok tenant'lı düğüme teslim)
- **Neden:** staging'de t0012'nin santralde olmaması ürün kapsamı sorusuydu; karar kullanıcıya değil kurula.
- **Sonuç:** ŞARTLI ONAY — **(B) düğüm paketi**, ama düğüme pinli anahtarla (t0000 değil); tenant kümesi
  `api_keys.node`'dan, yeni global tablo yok. Oylar B 7 / A 3 / HAYIR 0; (C) oy birliğiyle red.
- **Vetolar:** DB lideri (B için izolasyon) → düğüm anahtarı + keşif denetimli çapraz-tenant sınıfında + render
  tenant kapsamında + paket sır taşımaz ile karşılandı, muhalefet kayda geçti. CTO içerik bekçisi ve Asterisk
  tek-reload vetoları şart oldu. Şeytan'ın 7 itirazı yazılı cevaplandı.
- **Dokunulan dosyalar:** `yonetim/kurul-kararlari.md` (Karar #31), `yonetim/backlog.md` (BR-AST-17 P1, kabul ölçümü).
- **Sonraki adım:** `/sprint-planla pbxtr` (kullanıcı); uygulama "başla" ile.

### 14. Sprint planı — Karar #31 → Sprint-41 / Sprint-42 (EPIC W)
- **Neden:** Karar #31 ŞARTLI ONAY; planlama kullanıcı girdisi gerektirmeyen `yonetim/` işi. Sprint 34–40 zaten
  planlı (EPIC V) → yeni numara **41** (+42 artıklar). Yürütme sırası S34 → S41 → S42 → S35.
- **Ne yapıldı:** 8 ajan paralel (cm-agent, supervizor, ceo, backend-lider, frontend-uzmani, db-lider,
  asterisk-uzmani, linux-uzmani). CEO MVP sınırı: P1 Ş1–Ş6 çekirdek + Ş8; P2 sığarsa (mezar taşı, #53/#57, agent
  şeridi, 2-tick alarm); P3 S42 (#12 rozeti, rapor `—`). 7. gün (A) köprü tetiği.
- **Kod okumasından çıkan düzeltmeler:** sağlık ucu `/api/v1/system/health`; `api_keys`'te tür kolonu yok (node
  zorunluluğu uygulama katmanında); kısmi unique üç dondurma katmanı + yeni terminal `Sprint34FinalGuard`;
  `AlarmEvaluator` yalnız `QueueMetrics`'te koşar → alarm sync işinden; confd systemd birimleri depoda var ama
  hiçbir dağıtım betiği kurmuyor (staging elle).
- **Birleştirmeler:** BR-AST-19..23 → BR-SYS-36/37/40/42/43; BR-FE-41 → BR-FE-40. Çift `BR-AST-15` (PCI) → BR-AST-24.
- **Dokunulan dosyalar:** `yonetim/sprintler/sprint-41.md` (yeni), `sprint-42.md` (yeni), `yonetim/backlog.md`
  (EPIC W, 32 kart; BR-AST-17 → Sprintte S41).
- **Doğrulama:** `deploy/acik-karar-bayatlik-kontrol.sh` 0, `deploy/runbook-sayi-kontrol.sh` 0.
- **Commit:** `f799dc84` — plan(sprint): Sprint-41/42
- **Sonraki adım:** kullanıcı "başla" (`/basla pbxtr sprint-34` sırada; S41 ondan sonra).

## Kullanıcı kararı bekleyenler (bu turda kapatılamaz)
- BR-6 SMS sağlayıcısı · BR-SYS-34 gönderici alanı (`uzmanadres.com` / `pbxtr.com`) · BR-SEC-01 sır rotasyonu
  (yalnız kullanıcı emriyle) · BR-SEC-02 Karar #30/1 admin sistem yetkisi daraltması (kullanıcının 2026-08-29
  matrisini değiştirir).

### 15. Kurul — Karar #32 (kullanıcıya ÖNERİ: SMS sağlayıcısı + posta gönderici alanı)
- **Neden:** dört açık kullanıcı kartından ikisi (BR-6, BR-SYS-34) kurul önerisine çevrilebilirdi; kullanıcıya
  yalnız "evet/hayır" kalsın. (BR-SEC-01 sır rotasyonu emri ve BR-SEC-02 kullanıcı matrisi değişikliği kurulun
  ezemeyeceği kararlar, dokunulmadı.)
- **Sonuç:** ŞARTLI ONAY (öneri). **(1) Netgsm**, tek sağlayıcı, tenant başına başlık + isteğe bağlı tenant hesabı;
  10/10 ŞARTLI. Şeytan'ın kritik bulgusu: **İYS sağlayıcısı da mock** (`IysProviderComposition.cs:49`,
  `IysVerified` daima false) → gerçek SMS mock İYS altında ticari mesajı reddeder (Ş1-1, fail-closed), gerçek
  `IIysProvider` BR-BE-53. `sms_messages` + `sms_provider_accounts` kapsamda; DLR pull birincil, webhook tenant'ı
  satırdan çözer (CTO veto şartı). **(2) `pbxtr.com`**, `raporlar@pbxtr.com`, dönüş yolu `em<N>.pbxtr.com`, selector
  relay `s<N>` CNAME, DMARC `p=none`→`quarantine`; 8/10 (DB `uzmanadres.com`, Şeytan alt alan). Linux DNS ölçümü:
  `pbxtr.com` SPF/MX/DMARC yok; `uzmanadres.com` SPF `redirect`+`~all` bozuk; PTR yok. 8 satırlık DNS seti karar
  kaydında; script `lookupCount`, haftalık timer, staging gerçek-alıcı bekçisi şart (BR-SYS-45), beyaz-etiket
  `From` BR-SYS-44.
- **Dokunulan dosyalar:** `yonetim/kurul-kararlari.md` (Karar #32), `yonetim/backlog.md` (BR-6, BR-SYS-34 durumu;
  BR-BE-53, BR-SYS-44, BR-SYS-45 yeni).
- **Commit:** bkz. `git log` "Karar #32" (aşağıdaki push satırı).
- **Kullanıcıdan istenen:** "Netgsm ve pbxtr.com — onaylıyorum" (ya da alternatif); smtp2go selector + DNS
  kayıtlarını kullanıcı uygular. Kalan iki karar (BR-SEC-01, BR-SEC-02) yalnız kullanıcı emriyle.
