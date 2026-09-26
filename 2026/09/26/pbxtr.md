# pbxtr — 2026-09-26

## Bağlam
Kullanıcı `yonetim/bekleyen-maddeler.md`'deki 50 açık kartın "Yapılacak" satırlarını doldurdu.
Özet emir: *kod yazılacaksa yaz, testini ben yapacağım; test işi kalanı tamamlandıya çek*;
BR-AST-124 maddesi: *tüm harici dalları main'e al, başka dal bırakma*; BR-C2-1/2, BR-DB-74,
BR-OPS-14 "şimdilik es geç"; BR-10 ve BR-OPS-09 boş bırakıldı. Ardından: *ClickUp'ı güncelle*.
Başlangıç hâli: çalışma ağacı = `wip/is-akisi-20260925` (dünkü durdurulan 14 gruplu akışın
doğrulanmamış yarım işi, içinde `wip/ast124-be221`), 244 dosya commit'siz.

## Yapılanlar

### 0. BR-AST-104 engel ölçümü (soru)
- **Komutlar:** `ssh root@176.88.41.220` → `date -u` (11:46Z); `nsenter -t <pbxtr-asterisk pid> -n ss -lnt`
  → `127.0.0.1:4573` ve `127.0.0.1:8790` DİNLİYOR (pbxtr-edge + pbxtr-edge-fastagi ayakta);
  `psql pbxtr`: `public.dids` = 0, `voicemail_messages` = 0.
- **Sonuç:** kartın yazılı engeli (8790 dinlemiyor) düştü; kalan: voicemail kararlı DID + gerçek çağrı.
- **Tuzak:** `docker ps | grep asterisk` önce `pbxtr-asteriskcdrdb`'yi seçti (5432 gördü) — konteyner adını tam ver.

### 1. Yarım iş akışı derlenir + yeşil yapıldı, main'e alındı
- **Neden:** kartların kodu WIP'teydi ve derlenmiyordu; "kod yazıldıysa tamama çek" ancak main'de anlamlı.
- **Derleme hataları ve düzeltmeler:**
  - BR-AST-79: `HealthComponents.AsteriskExtensionInventory` yoktu → sabit + `All` listesi +
    `SystemHealthProbe`'a satır + FE etiketi `ph.cmpExtensionInventory` (9 dil).
  - `PermissionCatalogTests.cs` fazla `}`; `ErasureRequestTests.cs` `$"""` içinde `'{{}}'::jsonb` → `jsonb_build_object()`.
  - `NoScriptRuntime.GetContentAsync` eksikti (BR-BE-76); `WallboardTiles.Read(... ringGroups = null)`.
- **Test kırmızıları ve düzeltmeler:**
  - `QueueMembershipSyncJob` (BR-AST-126): yeniden bağlanma turu periyodik turun damgasına takılıyordu
    (gerçek hata) → `_lastReconnectTicks` ayrı damga.
  - `ErasureSubjectRequestDto.Number` string → `PhoneInput` (ADR-004 §2.7).
  - `delivery-manifest.json` `voicemail.redial`: izin listesi sıralı değildi (DM005); sonra
    `asterisk_external` + `high_risk_manual` + `manual_rollback` (DM007/TPI007);
    `telephony-path-inventory.json`'a `voicemail.redial` yolu eklendi.
  - Ekran sayısı 71→72 (#65 Silme Talepleri): `ScreenRegistryTests` 72/63/64; duman matrisi
    `smoke-demo.sh` (agent 200 / bayi 403 / wallboard 403) + `duman-ekran-kapsami.json`.
  - `SampleDataSeederInsertOnlyTests`: K4 2→4 (BR-QA-121 (d) red-çekme silmeleri) + çağrı imzası.
  - Belgeler yeniden üretildi: `doc/rol-ekran-matrisi.md`, `doc/ekran-yazma-yollari.md`
    (üretici test yok; testin içine geçici `File.WriteAllText` satırı eklenip koşulup geri alındı —
    betik: scratchpad `matris.py` / `yazmayol.py`).
  - FE: 17 eksik i18n anahtarı (9 dil, önek grubunun sonuna eklendi — Python ile yeniden sıralama
    156 satır oynattı, geri alındı); `node scripts/generate-screens.mjs`; `IvrGraphCanvas.test.tsx`
    test adında kaçışsız `'`.
- **Doğrulama:** `dotnet build` 0 hata; Architecture 794/794; Api.Tests 4 parça (1307, 1028, 2800,
  1398; sonradan düzeltilen 9 kırmızı dahil Platform+ilgili 1407/1407); `npx tsc -b` 0;
  vitest 67 dosya / 506 test; `dotnet format --verify-no-changes` temiz.
  **KOŞMADI:** Integration.Tests — yerelde Docker kapalı (4 yeni migration dahil).
- **Commit:** `d6356c98` — Durdurulan is akisinin yarim isi main'e alindi ve derlenir/yesil hale getirildi

### 2. Dallar temizlendi (BR-AST-124 maddesi)
- Yerel 7 dal (hepsi main'de, 0 ileride) `git branch -d`; uzak `wip/ast124-be221`,
  `wip/is-akisi-20260925`, `feat/rol-ekran-matrisi` silindi. Kalan: yalnız `main`.

### 3. backlog.md + ClickUp
- 33 kart `Bitti (2026-09-26)` (durum hücresine önek, eski metin "Önceki kayıt" olarak korunur;
  betik scratchpad `durum.py`, durum hücresi = Öncelik hücresi + 2).
- `clickup-senkron.js --kuru` → `clickup-olustur.js` (yeni 0) → `clickup-senkron.js` (yazılan 33)
  → `--kuru`: `fark olan kart: 0, izde olmayan: 0`.
- **Commit:** `09858ac7` — yonetim: 33 kart Bitti

## Kararlar
- Kart bazında commit bölmesi yapılmadı: aynı dosyalar (screens.json, seed, i18n, Program.cs)
  birden çok karta ait; tek commit, mesajda kart listesi.
- WIP kartları kullanıcı emriyle "Bitti" sayıldı; kart bazında içerik denetimi yapılmadı — canlı
  test kullanıcıda.

## Açık kalanlar / sonraki adım
- Kodu hâlâ yazılmamış kartlar: BR-AST-59, BR-AST-62, BR-BE-203, BR-FE-111, BR-SYS-60 (2),
  BR-DB-52 (2), BR-DB-16 (2. adım), BR-DB-67, BR-OPS-11, BR-SYS-51, BR-BE-43-B.
- Integration.Tests Docker'lı ortamda koşulmalı (yeni migration'lar: IysPermissionRefreshIndexes,
  VoicemailCallbackAndResultCodeRequired, ErasureRequests, SlaAutoAnsweredCount).
- BR-10, BR-OPS-09: kullanıcı yapılacak yazmadı.

## İkinci tur — kalan 11 kart sırayla (kullanıcı: "evet sırayla devam et")

### 4. BR-AST-59 — gelen çağrı ARI devralması ayarlardan açılır
- **Neden:** devralma kodu ve `[pbxtr-{t}-ctl]` üretimi depodaydı, ön koşullar (BR-AST-55, BR-SYS-93) Bitti; bayrak yalnız elle SQL ile açılabiliyordu → kullanıcı test edemezdi.
- **Ne yapıldı:** `TenantSettingsView.AriTakeover`, komut `ariTakeover` (yok = DOKUNMA), ayrı `ChangeSet.AriTakeover`, maske yazma kapısı, `EfTenantSettings` → `AriTakeoverEnabled`, değişince `provisioning.RegenerateAsync`, ayrı denetim satırı; #49 Telefon & Ses paneline onay kutusu (9 dil).
- **Testler:** `AriTakeoverSettingTests` (3), `settingsApi.test.ts` (+3).
- **Commit:** `d723a2cc`

### 5. BR-AST-62 — zil grubuna dış numara üyesi (worktree ajanı, backend-dev-2)
- **Tasarım (brifte sabitlendi):** migration `20260926131158_RingGroupExternalMember`; `PhoneInput` giriş, sunucuda maskeli çıkış, düzenlemede `keepMemberId`; dış üye `Local/<e164>@pbxtr-{t}-rg-ext/n`, bu bağlam miras damgaları (`PBXTR_PERM`, `PBXTR_CTL`, `PBXTR_DIALER_MODE`; düz + `__`) silip `-outbound`'un call-permission AGI'sine gider.
- **Neden damga temizliği:** `AsteriskAriProvider.cs:323` originate'te `__PBXTR_PERM=1` basar ve `__` miras alınır; aktarılmış pbxtr çağrısı zil grubuna girerse Local bacak kapıyı atlardı. Mutasyon: satır silinince renderer testi KIRMIZI.
- **Yan kararlar (ajan):** yeni maske yüzeyi `ringgroup`; dış üyeli `Dial()` `t` bayrağı taşımaz.
- **Merge sonrası:** build 0, Architecture 794/794, Api (Telephony+Live+Tenancy+Privacy+Delivery) 2383/0.
- **Commit:** `9349bbbd`, merge `0c273ecc`, kart `9ade36a2`

### 6. BR-FE-111 — "Müsait ama çalmıyor" yedek kademe rozeti
- **Kural (domain `LiveAgentBlockReason`):** müsait + DND açık değil + bekleyen çağrısı olan HER kuyruğunda penalty > kuyruğun min penalty'si + üye sayısı > `penaltymemberslimit`; tek engelsiz bekleyen kuyruk → sebep yok. `skill_mismatch` üretilmez (eşik altı agent üyelikten düşer).
- **Veri:** `RedisLiveOperationsView` zaten okuduğu `queue_members` (penalty eklendi) ve `queues` (`PenaltyMembersLimit` eklendi) — ek sorgu yok. `LiveAgentDto` sona `blockedReason` + `blockedReasonQueueId`.
- **Ekran:** `BlockedReasonBadge` (#12/#13 ortak), `queue.read` varsa `/queues?members=<id>`; `QueuesScreen` bu parametreyle `fetchQueue` + üye diyaloğunu açar.
- **Testler:** `LiveAgentBlockReasonTests` (8), `BlockedReasonBadge.test.tsx` (4).
- **Commit:** `21fb836d`

### 7. Frontend bekçileri — iş akışından kalan 4 kırmızı
- **Bulgu:** ilk turda yalnız dokunulan klasörlerin vitest'ini koşmuştum; TAM koşu 4 kırmızı gösterdi (ajan da bildirdi). Ders: *filtreli test kapıyı görmez* — tam takım koşulmalı.
- **Düzeltme:** #65 tetikleyicilerine `data-pbxtr-action`; ölü `useSessionOptional` mock'u; dar imzalı mock sarmalayıcıları; düzelen satır donmuş listeden çıktı; `MaintenanceBanner` payload tüketicisi izin listesine.
- **Sonuç:** vitest TAM 261 dosya / 2255 test yeşil. **Commit:** `92747f0c`

### 8. Test/ölçüm işi kalan kartlar Bitti (kullanıcı kararı)
- BR-BE-203 (kusur BR-BE-223 ile `79988a24`), BR-SYS-60 (kanarya SAPTI tatbikatı), BR-DB-52 (canlı bütçe koşusu), BR-OPS-11 (yıkıcı ölçümler), BR-DB-16 (2. adım `IdentifierLengthGuardTests` zaten WIP'te), BR-SYS-51 (runbook + `SmsOutageDrillTests` zaten WIP'te).
- Her kapanıştan sonra `clickup-senkron.js`; son `--kuru`: fark 0, izde olmayan 0.

## Kararlar (ikinci tur)
- BR-BE-43-B ve BR-DB-67 kullanıcıya soruldu, yazılmadı: 43-B'de Karar #66 İ2 başlıktan yazımı yasaklıyor ama pinsiz anahtarın sunucuda çözülebilir düğüm kimliği yok (kural ya sahte kimliğe dayanır ya hiç ateşlenmez); 67 model seçimi + 01 şablon tazelemesi (call-permission FAIL-CLOSED pencere).

## Açık kalanlar (güncel)
- BR-BE-43-B, BR-DB-67 — kullanıcı kararı bekliyor (öneriler yanıtta).
- Integration.Tests hiç koşmadı (yerelde Docker kapalı): yeni migration'lar RingGroupExternalMember + dünün dört migration'ı.
- BR-10, BR-OPS-09: yapılacak yazılmadı; BR-C2-1/2, BR-DB-74, BR-OPS-14: es geçildi.
