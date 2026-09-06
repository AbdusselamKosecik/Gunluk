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
