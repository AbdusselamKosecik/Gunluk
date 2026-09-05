# pbxtr — 2026-09-05

## Bağlam

Kullanıcı ikinci kez "devam edelim" dedi (Boşluk Raporu hedefi). Sprint-31/32 kapanmış, yayın 14
staging'deydi (`demo-b588689b0a8c`). Sıradaki iş Sprint-33 (Karar #28 A — Scripter faz 1 / 1. yarı)
ve bir gün önce yayın ölçümünde bulunan üç P1 kart (BR-BE-35/36/37). Sır rotasyonu, SMS sağlayıcısı
ve gönderici alanı yine kullanıcı kararı olarak bekletildi. Günün büyük kısmı 00:00–04:00 UTC arası
(Türkiye 03:00–07:00).

## Yapılanlar

### 1. Sprint-33 açılışı ve tasarım

- **Neden:** `/basla pbxtr sprint-33` ön koşulları tamam (Karar #28 A ŞARTLI ONAY, sprint dosyası var).
  BR-BE-35 kapanmadan hiçbir yayın santral yapılandırmasını değiştirmediği için üç P1 kart sprinte
  eklendi (`fd6c84b5`).
- **Ne yapıldı:** iki tasarım paralel — `yazilim-mimari` → `doc/mimari/tasarim/scripter-faz1.md`
  (JSONB v1 şeması, 20 kurallı doğrulayıcı, `ScriptAnswerGate` PCI kapısı, `RecordResultAsync`
  tek transaction, sabitleme "ilk POST'ta", `tenant_license_features` bayrağı, FE sözleşmesi) +
  `provisioning-yeniden-uretim.md` (renderer parmak izi SHA-256(MVID|InformationalVersion),
  `provisioning_render_stamps`, kilit 31); `db-lider` → `scripter-sema.md` (üç ölçülmüş tuzak:
  satır içi RLS policy `purge_call_data`'ya 0 satır gösterir; bileşik FK `SET NULL` iki kolonu
  NULL'lar → PG15 kolon listesi ham SQL; `sys-functions.expected` + seed + md5 üçlüsü).
- **Dokunulan dosyalar:** `doc/mimari/tasarim/{scripter-faz1,scripter-sema,provisioning-yeniden-uretim}.md`
- **Commit:** `38309143`

### 2. DB — BR-DB-05/06 + provisioning damgası

- **Ne yapıldı (`db-dev`):** `20260904190000_ScripterFaz1` (`scripts`, `script_publications`
  append-only, `script_responses`, `script_answers` — `value_kind` **`yes_no`**, tek `value_*`,
  PCI regex `{12,18}` + `numeric(16,4)`, `jsonb_path_exists` ile sonuç kodu yasağı, adım ≤ 200;
  `tenant_license_features`), `20260904191500_ProvisioningRenderStamps`,
  `20260904193000_CallDataRetentionScripter` (`purge_call_data` satır dalı, 20k/tenant parti,
  Down md5 birebir), `20260904200000_Sprint33FinalGuard` (26 devir + 10 madde).
- **Doğrulama:** up→down→up 159 migration; `deploy/db-kapilari-docker.sh` yeşil; bekçi 12/12
  mutasyon; 20k cevap seti purge 1,93 sn.
- **Tasarımdan sapma:** "günde bir parti" plan tarafında da uygulandı (UNIQUE ihlali tüm purge
  transaction'ını geri alırdı); `users` FK'ları yalnız migration'da (EF indeks üretmesin).
- **Commit:** `face55bd` (BR-BE-35 ile birlikte)

### 3. Backend

- **BR-BE-36/37** (`38183fe5`): kuyruk Create/Update/Delete → `RegenerateAsync`, yalnız render'a
  giren alan değişince (`RenderedQueue` projeksiyonu; aynı değer 0, strateji/pasif/silme 1);
  `PlatformRollupJob` tenant okuması `IUnitOfWork.BeginAsync` + `SET LOCAL` içinde — gerçek
  PG+Redis testi mutasyonda `SkippedTenants=3` ile canlı bulguyu birebir yeniden üretti.
- **BR-BE-35** (`face55bd`): `ProvisioningRerenderJob` kilit 31, `ReportScheduleJob` deseni;
  damga `ok|blocked` (1 sa yeniden), denetim `provisioning.rerendered`; 3-tenant gerçek PG
  senaryosu (biri bozuk, biri askıda), ikinci tick yazmaz. Rolling deploy'da parmak izi
  ping-pong uyarısı kayda geçti (tek node'da oluşmaz).
- **BR-BE-07…11** (`95bda458`, `backend-dev-1`): `ScriptDefinition` v1 kapalı şema + kanonik
  JSON; `DirectedGraph` çekirdeği IVR'dan çıkarıldı; `ScriptAnswerGate` saf (Luhn Domain'de,
  değer hiçbir yere girmez, sayaç); `OwnedCallResolver` 3 kopya → 1; ilk POST'ta sabitleme, 409;
  `CarryOverAsync` (90 sn redial); `POST /campaigns/{id}/script/publish` (`campaign.write` +
  If-Match, denetim, WS commit sonrası); agent GET/POST uçları. Mutasyon: PCI 9+2, dallanma 2+1,
  tek tx 1 kırmızı.
- **Lisans bayrağı** (`backend-junior`, aynı commit): `LicenseFeatures.Scripter`,
  `ILicenseFeatureGate` (satır yok = kapalı, mutasyon 3 kırmızı), `RequiresLicenseFeatureAttribute`
  + **middleware `UnitOfWork`'ten SONRA** (authorization handler'da DB okuması RLS 0 satır
  verirdi), 403 `LICENSE_FEATURE_DISABLED` `meta.feature`, `/me.license.features`,
  `PUT /tenants/{id}/license-features/{feature}` (`tenant.license`), `RealtimeEventTypes.ScriptPublished`.
- **Komutlar:**
  ```bash
  dotnet build pbxtr.sln -c Debug
  dotnet test tests/Pbxtr.Api.Tests --no-build --filter "Scripter|AgentDesk|Ivr|License"
  dotnet test tests/Pbxtr.Integration.Tests --no-build --filter "Scripter|License|ProvisioningRerender|PlatformRollup"
  dotnet test tests/Pbxtr.Architecture.Tests --no-build
  dotnet format pbxtr.sln --verify-no-changes
  ```

### 4. Frontend

- **BR-FE-12** (`a8e7b784`, `frontend-dev-2`): `IncomingCallModal` "Script var" rozeti,
  WS `script.published` (aktif çağrıda hiçbir şey yapılmaz), `useHasFeature('scripter')`,
  `isLicenseFeatureDisabled` sessiz düşüş; 105 test.
- **BR-FE-10/11** (`62977d57`, `frontend-dev-1`): `ScriptRunner` `CallerFacts.extra` yuvasında
  (prototipte script alanı yok; kart token'larıyla), sonraki adım yalnız sunucunun `nextStepKey`'i,
  `script` hotkey kapsamı (Enter/1-9/E/H/Esc, giriş alanında sessiz), 409 → GET ile tazele,
  PCI 400 → alan temizlenir + `console` yok, kapanışta cevaplar + yaprak kod tek istek, yarım kayıt
  uyarısı; 329 test; hotkey mutasyonu kırmızı.
- **Sıra kararı:** frontend backend'i beklemedi — sözleşme tasarım dokümanından; QA çapraz
  sözleşme ölçümünde uyumsuzluk 0.

### 5. QA (BR-QA-03) ve düzeltme turu

- **Bulgular:** KRİTİK yok; ORTA: O-1 lisans kapısının middleware sırası hiçbir testle korunmuyor
  (mutasyon 479 testte yeşil kaldı — `FixedLicenseFeatureGate` ikizi + `EfLicenseFeatureGate`
  `NoAmbientTransactionException`'ı yutuyordu), O-2 FK adı 71 kr → PG 63'te kesti, snapshot ≠ DB,
  O-3 kapanışta kampanya bağı düşerse 409 döngüsü (sonuç kodu asla yazılamaz), O-4
  `ThrowsAnyAsync<Exception>` zayıf iddia. 8 mutasyon kırmızı.
- **Düzeltmeler:** `df5bcde9` (web: `scriptDropped` bilgi satırı, 409'da tek seferlik cevapsız
  yeniden gönderim, `scriptReport` idle'da sıfır; lisans yokken GET atılmaz; **D-2 bilinçli
  sapma** — cevap tavanı 500 doğru, QA adım metni 2000 ile karıştırmış) ve `8bff66e1`
  (`LicenseGatePipelineOrderTests` + gerçek gate HTTP testi; `EfLicenseFeatureGate` artık
  fırlatır; `fk_script_responses_publication` 31 kr + bekçi [11] "63 karakterlik ad varsa kır" —
  **ölçüm:** `public`'te üç eski 63'lük ad var (`dids`, `tenant_ledger_entries`,
  `telephony_provider_effects`), hepsi snapshot ile tutarlı → kural bu sprintin altı tablosuyla
  sınırlandı, eskiler BR-DB-16; kapanışta `campaign_unresolved|publication_missing` düşürme;
  23503/42501 iddiaları; pasif script sabitlenmez).
- **Yeni kartlar:** BR-BE-38 (403 lisans denetimsiz — karar), BR-BE-39 (redial carry-over
  originate sonrası), BR-DB-16.
- **Commit'ler (yönetim):** `a68e73d8`, `2bb943dd`, `272a46d5`, `b5dfaf05`.

## Kararlar

- Sprint-33 üç P1 kartla genişletildi; gerekçe: yayın santrali değiştirmiyordu.
- Lisans bayrağı kontrolü authorization policy değil, `UnitOfWork` sonrası middleware (RLS).
- `tenant_license_features` satırı yok = kapalı; staging'de hiçbir tenant'ta scripter açık değil.
- Bekçi [11] yalnız bu sprintin tabloları; eski 63'lük adlar ayrı kart (vacuous/kırıcı dengesi).
- `value_kind` `yes_no` (kurul kaydı), sprint metnindeki `yesno` değil.

## Tuzaklar

- `node -e '...'` içinde iç içe tırnak/backtick → kabuk takıldı; betikler dosyaya yazılıp koşuldu.
- Sprint tablosunda "Görev" hücresi `|` içerebiliyor → durum regex'i satırı sondan ayrıştırmalı.
- Aynı dosyaya (ProblemResponse, AuditActions, DI, Program.cs) iki ajan yazınca commit ikisi
  bitene kadar bekletildi; frontend dosyaları backend'den bağımsız olduğu için erken alındı.

## Açık kalanlar / sonraki adım

1. Yayın 15 (`8bff66e1`) koşuda → yeşilse staging'de `tenant_license_features` boş kalacak;
   scripter'ı açmak Süper Admin PUT'u ister (FE yüzeyi Sprint-34).
2. **Sprint-34** (yönetici editörü #06, alan raporu, gizli rota) kullanıcı "başla" der.
3. Kullanıcı kararları değişmedi: BR-SYS-34 gönderici alanı, BR-SEC-01 rotasyon, BR-6 SMS,
   santral davranış ölçümleri için bakım penceresi.
4. Ölçülmeyenler: gerçek Redis lisans önbelleği düşürme, WS gerçek soket, `phone.unmask` dalı,
   gerçek tarayıcı klavye.

### 6. Yayın 15/16/17

- **Yayın 15** (`8bff66e1`): entegrasyon 629/630 — `FinalDeliveryReportTests` kanonik
  `databaseSchemaRevision` bayat (yeni terminal migration). Bilinen kapı; kanonik dosya
  `Sprint33FinalGuard`'a çekildi, rapor klonda `PBXTR_WRITE_DOCS=1 … --filter Canonical_report_documents_URET`
  ile yeniden üretildi (`aba17131`).
- **Yayın 16**: frontend 1461/1462 — `viMockTargets` bekçisi: `CallTabScript.test.tsx`'teki
  `vi.mock` `useSessionOptional`'ı eziyor ama modül grafında kimse ithal etmiyor (ölü mock).
  Satır silindi (`2e96b2fb`). Ders: QA düzeltme ajanı yalnız kendi filtresini koştu; bu bekçi
  yalnız tam `vitest run`da görünüyor.
- **Yayın 17** (`2e96b2fb`) koşuda.
