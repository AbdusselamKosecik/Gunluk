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
