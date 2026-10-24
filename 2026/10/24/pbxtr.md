# pbxtr — 2026-10-24

## Bağlam
Sprint-46 (santral-hizmeti-plani §1 Faz A) backend'i: tenant tipine göre modül maskesi,
dahili limiti, Personel rolü. Kullanıcı: "bütün sprintleri bitir, soru sorma". Kapsam dışı:
BR-BE-267 (ConfigRenderer kapısı + tip değişim uyarısı) ve BR-FE-142 (frontend ekranı).

## Yapılanlar

### 1. Modül altyapısı (BR-BE-263/264/265)
- **Neden:** `TenantKinds` (call_center/pbx/hybrid) hiçbir şeyi açıp kapamıyordu.
- **Ne yapıldı:** `TenantModules` (core/callcenter/pbx) + `ModulesFor(kind)`; boş tip = core+callcenter.
  `permissions.seed.json` → `permissionModules` (her yetki tam bir modülde, açılışta doğrulanır).
  `bundle.queue` → `bundle.routing` (core) + `bundle.campaign` (callcenter); 7 rolün etkin yetkisi
  değişmedi (rol başına SHA-256 testte sabit). Maske tek noktada: `TenantResolutionMiddleware` →
  `PermissionCatalog.MaskToModules`, çapraz-tenant'ta HEDEF tenant'ın modülleri. `/me.modules`.
  `screens.json` her ekranda `module` (77 aktif: 50 core, 27 callcenter).
- **Dokunulan dosyalar:** `src/Pbxtr.Domain/Modules/Tenancy/TenantModules.cs`,
  `src/Pbxtr.Api/Platform/Authorization/{PermissionCatalog.cs,permissions.seed.json}`,
  `src/Pbxtr.Api/Platform/Tenancy/TenantResolutionMiddleware.cs`, `src/Pbxtr.Infrastructure/Identity/EfTenantDirectory.cs`,
  `src/Pbxtr.Api/Platform/Screens/screens.json`, `src/Pbxtr.Web/src/app/shell/tenantModules.ts`.
- **Karar:** modül için Redis önbelleği YOK — descriptor'ın aynı tek sorgusunda okunur (ek round-trip yok, invalidasyon yok).

### 2. Override tablosu ve uçlar (BR-DB-119, BR-BE-266)
- **Ne yapıldı:** `tenant_modules` (RLS, CHECK `callcenter|pbx`, FK). `GET/PUT /api/v1/tenants/{id}/modules`
  (tenant.read/tenant.write, bayi yalnız kendi tenant'ları, denetim `tenant.modules.changed`).
  `PUT .../license-features/{feature}` artık `tenant.write` ile de açık.
- **Migration:** `20261023201118_TenantModulesAndExtensionLimits` (Down'da `tenants_dealer_quota`
  tetikleyicisi kolondan önce düşürülür — yoksa 2BP01).

### 3. Dahili limiti (BR-DB-120)
- `tenants.extension_limit`, `dealers.extension_quota`; dahili oluştururken 409 `EXTENSION_LIMIT_EXCEEDED`
  (`meta {limit, used}`, advisory lock), bayi kotası DB tetikleyicisinde `DEALER_EXTENSION_QUOTA_EXCEEDED`.

### 4. Personel rolü (BR-BE-268)
- `staff` + `bundle.self` (self.settings, self.calls.read, voicemail.read); `/api/v1/me/extension`,
  `/me/extension/dnd`, `/me/calls`. Personel başkasının dahilisine yazamaz (403 testi).

### 5. Testler (BR-QA-127)
- Menü golden 4 tip × 8 rol, pbx `POST /campaigns` 403, boş tip regresyonu, çapraz-tenant maske,
  ekran↔yetki modül tutarlılığı + iki mutasyon, iki sızıntı testi (gerçek PG).
- **Komutlar:**
  ```bash
  dotnet build pbxtr.sln -m:1
  dotnet test tests/Pbxtr.Architecture.Tests            # 857/857
  dotnet test tests/Pbxtr.Api.Tests --filter <namespace> # Platform+Access+Tenancy 1982, Telephony 1559, diğer Modules 2354, kök 9
  dotnet test tests/Pbxtr.Integration.Tests             # 1310: 1302 geçti; düzeltme sonrası 5 tekrar yeşil
  dotnet format pbxtr.sln --verify-no-changes           # temiz
  npx tsc -b && npx vitest run ...                      # temiz, 332 + 44
  ```
- **Commit:** `7b76f8cd` — Sprint-46: tenant modulleri (core/callcenter/pbx), dahili limiti, Personel rolu

## Kararlar
- Modül maskesi önbelleksiz (aynı descriptor sorgusu).
- `phonebook.read` eklenmedi (bağlanmamış yetki açılışı durdurur) → Faz B.
- pbx tenant'ta `agent` rolü çağrı merkezi ekranlarının tamamını kaybeder; santral kullanıcısı `staff`'tır.

## Açık kalanlar / sonraki adım
- BR-BE-267 (ConfigRenderer modül kapısı, tip değişim uyarısı) ve BR-FE-142 (tenant ekranında modül bölümü).
- `MonitorRejectionAuditHttpTests.Monitor_start_roster_gate...` bu işten bağımsız kırmızı:
  `beaa9e4c` süpervizör dahilisi şartı ekledi, test dahili tohumlamıyor (`SUPERVISOR_NO_EXTENSION`).
- `deploy/st44/st44-role-matrix.json` HEAD'de zaten kaynaklarla uyumsuzdu (imzalı artefakt, yeniden üretilmedi).

---

## BR-FE-142 — #53 Modüller sekmesi, pbx'te agent gizli, dahili limiti/kotası (frontend-dev-1)

### Bağlam
`7b76f8cd` modül uçlarını (`GET/PUT /tenants/{id}/modules`, `license-features` PUT) ve
`extensionLimit`/`extensionQuota` alanlarını backend'e getirdi; ekran tarafı yoktu.
Paralelde backend-dev-2 BR-BE-267 (tip değişimi 409 onayı) üzerinde çalışıyordu.

### Yapılanlar
- **Neden:** tenant tipine göre modül açma/kapama ve santral tenant'ında dahili sınırı
  ekrandan yönetilebilsin (santral-hizmeti-plani §1 A.2b, §4 Kota).
- **Ne yapıldı:**
  - `TenantEditDialog` → yeni **Modüller** sekmesi (`TenantModulesPanel.tsx`): tür varsayılanı +
    etkin anahtar, "Varsayılandan farklı" rozeti, `core` kilitli, "Varsayılana dön", lisans
    ek paketleri. Okuma tembel (sekme açılınca). Tür seçimi değişince varsayılan **kaydetmeden**
    önizlenir — istemci aynası `KIND_DEFAULT_MODULES` (`shell/tenantModules.ts`), C#
    `ModulesFor` switch'ine karşı parite testi (`tenantModuleCatalog.test.ts`).
  - Kaydet zinciri: limitler → profil → modüller (yalnız dokunulduysa) → değişen bayraklar.
  - Tür `pbx` → agent limiti alanı gizli (düzenlemede kayıtlı değer, yeni tenant'ta 1 gider),
    dahili limiti alanı her zaman görünür; `extensionLimit` üç durumlu (yok/null/sayı).
  - Bayi oluştur/düzenle: `extensionQuota` alanı.
  - 409 `EXTENSION_LIMIT_EXCEEDED` dahili formunda sayılı Türkçe cümle (`extensionLimitMessage`);
    `QUOTA_EXCEEDED kind=extension` → "dahili".
  - 409 `TENANT_KIND_CHANGE_REQUIRES_CONFIRM` → satır içi onay (`role=alertdialog`, Modal üst
    üste binmediği için), `meta` esnek okunur (`impact` iç içe/düz/dizi), tekrar `confirm: true`.
  - 45 metin anahtarı × 9 dil. Bir anahtar (`tnt.impactQueueMembers`) ilk yamada mevcut
    anahtarın üstüne yazılmıştı; fark `git diff | grep '^-'` ile yakalandı, geri alındı, yeni
    anahtarlar `tnt.kindImpact*` adına taşındı.
- **Dokunulan dosyalar:** `src/Pbxtr.Web/src/app/screens/tenant/{TenantEditDialog,TenantCreateDialog,DealerEditDialog,DealerCreateDialog,TenantModulesPanel}.tsx`,
  `tenantModulesApi.ts`, `TenantModulesPanel.module.css`, `api/{problem,ops,opsContracts,index}.ts`,
  `screens/telephony/ExtensionsScreen.tsx`, `shell/tenantModules.ts`, `i18n/messages/*.json`, testler.
- **Komutlar:**
  ```bash
  cd src/Pbxtr.Web
  npx tsc -b                 # temiz
  npx vitest run             # 278 dosya, 2458 test geçti
  npm run -s guard:no-polling
  ```
- **Sonuç / doğrulama:** yeni testler mutasyonla doğrulandı (agentHidden=false, confirm
  kaldırma, core kilidi, override işareti, önizleme türü → 5 test kırmızı).
- **Commit:** `f39b6911` — BR-FE-142: #53 Moduller sekmesi, pbx'te agent gizli + dahili limiti, bayi dahili kotasi

### Kararlar
- Tip onayı ikinci Modal değil, düzenleme modalı içinde satır içi diyalog (Esc yalnız onayı kapatır).
- Sunucunun 409 `detail` metni çizilmez (API kullanıcısına talimat taşıyor); ekran kendi cümlesini yazar.

### Açık kalanlar
- BR-BE-267 sözleşmesi kesinleşince `kindChangeConfirmationOf` ve `confirm` alanı teyit edilecek.

---

## BR-BE-267 — tip değişimi onayı + callcenter kapalıyken kuyruk/dialer üretilmez (backend-dev-2)

### 1. Onay kapısı (tek yer)
- **Neden:** `call_center` → `pbx` geçişi veri taşıyan `callcenter` modülünü sessizce kapatıyordu; plan §1 A.3/6 onay istiyor.
- **Ne yapıldı:** `TenantModuleChangeGate.EnsureConfirmedAsync` (Domain) — kapanan modül + `ITenantModuleCloseImpactQuery` sayacı (`EfTenantModuleCloseImpactQuery`: queues, openCampaigns, queueTargetedDids, queueMembers; query filter altında). İki yol aynı fonksiyonu çağırır: `PUT /api/v1/tenant/profile` (`company.kind`; tip yolu `TenantEndpoints` değil `TenantProfileEndpoints`'tedir) ve `PUT /api/v1/tenants/{id}/modules`. Veri varsa ve `confirm: true` yoksa 409 `TENANT_KIND_CHANGE_REQUIRES_CONFIRM`, hiçbir şey yazılmaz. Onaylı istekte `tenant.modules.changed` denetimi (`closing`, `impact`, `confirmed`, tip yolunda `source=kind`), etkin küme değiştiyse `IProvisioningRegenerator` aynı transaction'da. Veri silinmez.
- **Dokunulan dosyalar:** `src/Pbxtr.Domain/Modules/Tenancy/TenantModuleChangeGate.cs`, `ITenantModuleAdministration.cs` (`ToAuditState`, `Confirmed`), `src/Pbxtr.Infrastructure/Modules/EfTenantModuleAdministration.cs`, `src/Pbxtr.Api/Modules/Tenancy/{TenantModuleEndpoints,TenantProfileEndpoints,TenantModuleChangeProblem}.cs`, `ProblemResponse.cs`, `doc/mimari/api-kontrat-v1.md`.

### 2. ConfigRenderer kapısı
- **Ne yapıldı:** `ProvisioningSource.EnabledModules` (`null` = bugünkü metin). `callcenter` yokken: `queues` boş (yalnız `[general]`), dialer-announce / geri arama / qexit bağlamları ve kuyruk MOH sınıfları yok, `-out`'taki dialer-mode `GotoIf` yok; kuyruk adı `[pbxtr-dialer]`'da `[pbxtr-{t}-cc-off]`'a bağlanır (IVR yayın metni ve zil grubu taşması o adı taşıdığı için exten silinmedi), `UserEvent PbxtrModuleDisabled` + erken medya `vm-sorry`. Kuyruk hedefli DID statik dalda kendi kapalı-saat kararına düşer. `ProvisioningRevisionService` modülleri hedef tenant'tan okur (resolver ile ortak `EfTenantModuleResolver.ReadAsync`); queue-target anlık görüntüsü yalnız üretilen kuyruklar için.
- **Ölçüm:** `ConfigRendererCallCenterModuleTests` 7 test; mutasyon (`CallCenterEnabled => true`) 5'ini kırdı, kalan 2'si regresyon/vacuity.

### 3. AMI QueueAdd
- `QueueMembershipSyncJob` callcenter kapalı tenant'ı keşiften düşürür (`CallCenterModuleInputsSql`, karar `TenantModules.Effective`'te). Entegrasyon testi + kontrol grubu. Diğer `QueueAdd` yolları (HTTP) modül maskesiyle 403; `LeaveEnforcementJob` ve `AgentInterventionService` kapatılmadı (rapora yazıldı).

### 4. Monitor testi
- `MonitorRejectionAuditHttpTests`: süpervizöre `4791` dahilisi fikstürde eklendi, DisposeAsync siler ve ölçer.

### Komutlar / sonuç
```bash
dotnet build                                   # 0 hata 0 uyarı
dotnet test Api.Tests --filter Modules.Telephony/Tenancy/Provisioning/Queues/Ivr/Dialer, Platform  # 1566/351/169/128/139/39/1467 geçti
dotnet test Architecture.Tests                 # 857/857
dotnet test Integration.Tests (Provisioning|Tenant|ConfigRender|QueueMembership|Monitor)  # 459/459; son ikiliyle hedefli 49/49
dotnet format pbxtr.sln --verify-no-changes    # temiz
```
- **Commit:** `595272f7` — Sprint-46 BR-BE-267: tip degisimi onayi + callcenter kapaliyken kuyruk/dialer uretilmez

### Kararlar
- Onay alanı iki uçta da gövdede `confirm: true` (bool?); 409 meta bileşik değil iç içe: `impact.<modül>.<sayaç>`.
- Verisiz modül kapanışı ve modül açma onay istemez.
- `PUT /tenant/profile` ve `PUT /tenants/{id}/modules` If-Match tablosunda `Acik` borç (damga yüzeyi yok).

### Açık kalanlar
- route-decision çalışma anında pbx tenant'ı için hâlâ `queue` kararı üretebilir; dialplan bunu `cc-off`'a düşürür ama karar metni ve `call_events` "queue" der.
- `LeaveEnforcementJob` / `AgentInterventionService` QueueAdd'i modülü sormuyor.
- Profil PUT'u `tenant.manage` ile owner'a açık: owner kendi tipini `hybrid` yapıp modül açabiliyor (lisans konusu, kapsam dışı).

## Sprint-46 kapanışı — yayın + canlı ölçüm (koordinatör)

### 1. Yayın
- **Neden:** Sprint-46 kapanış şartı canlıda `/me/menu` ölçümü.
- **Ne yapıldı:** İlk `deploy/yerel-yayin.sh --yayinla --testsiz` koşusu `npm audit` kapısında durdu (vite ≤6.4.3 high: GHSA-9jrq-w75r-8gcw + launch-editor). `src/Pbxtr.Web` içinde `npm audit fix` → vite 6.4.5; `npx tsc -b`, `vite build`, tenant vitest (128/128) yeşil. Yeniden yayın.
- **Commit:** `7a33d6fb` — web: vite 6.4.3 -> 6.4.5. Yayın: `tekbirsoft/pbxtr:demo-7a33d6fb7919`, migration `20261023201118_TenantModulesAndExtensionLimits` canlıda.

### 2. Canlı ölçüm (176.88.41.220, app.pbxtr.com)
- Sunucuda canlı tenant'ların hepsi boş tipli (pbx tipli tenant yok; "Örnek Fabrika" BR-OPS-19'da açılacak). Ölçüm, t0007'de `callcenter` override'ını kapatıp açarak yapıldı (gerçek yazma yolu, BR-BE-267 kapısı dahil).
- Komut: betik scp ile `/root/m2.sh`, `bash /root/m2.sh; rm`. Parola `.env`'den değişkene okunur, basılmaz. Akış: login (demo.superadmin/sahip/agent/supervizor) → `GET /me/menu` kod listesi → `PUT /tenants/{id}/modules {"overrides":[{"module":"callcenter","enabled":false}],"confirm":true}` → tekrar ölç → `{"overrides":[]}` ile geri al → `cmp`.
- **Sonuç:**
  - onaysız PUT → 409 `TENANT_KIND_CHANGE_REQUIRES_CONFIRM`, `meta.impact.callcenter = {queues:1, queueMembers:3, ...}` (t0012)
  - sahip menü 41→17, süpervizör 38→14, agent 5→2; `GET /campaigns` 200→403
  - geri alınca üç rolün menüsü **birebir aynı**; santralde `queue show` t0007 kuyrukları (2) geri geldi; `audit_log` `tenant.modules.changed` 4 satır
- Tuzak: `users` tablosunda `tenant_id` yok, `home_tenant_id` var; tenant tipi `tenant_company_info.kind`'da.

### 3. Backlog + ClickUp
- Sprint-46'nın 10 kartı `Bitti (2026-10-24, …)`; `sprint-46.md` durum BİTTİ.
- Yeni kart **BR-BE-273** (sprint-47): owner `PUT /tenant/profile` ile kendi tipini `hybrid` yapıp modül açabiliyor (BE-267 raporundan) → 403 `TENANT_KIND_FORBIDDEN` olacak.
- ClickUp: olustur (yeni 1) → senkron (yazılan 10) → `--kuru` `fark olan kart: 0, izde olmayan: 0`.
- **Commit:** `66f4957f` — yonetim: Sprint-46 kapandi.

### Sonraki adım
- Sprint-47 (özellik kodları, yakalama, yönlendirme, sesli mesaj, BR-BE-273).
