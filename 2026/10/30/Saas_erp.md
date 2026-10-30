# Saas_erp — 2026-10-30

## Bağlam
`/goal backlog u tamamlayalim` sürüyor (docs/design/analysis/2026-10-28-yonerge-backlog.md, E0–E11).
Gece 29→30: dil düzeltmesi, E4 S2 (dış giriş kalite bekletme) ve E9 S4a (rota İç/Fason bayrağı)
paralel worktree'lerde (scratchpad/wte7, wte8, wte9). Ana checkout'a dokunulmadı (kullanıcının işleri var).

## Yapılanlar

### 1. Arayüz dili yalnız TR/EN arasında değişiyordu
- **Neden:** Kullanıcı "ingilizce ve türkçeden başka dile geçmiyor" dedi.
- **Teşhis:** Üst menüdeki dil seçici 11 dili zaten listeliyor ve çalışıyordu (DEV ve PROD'da Almanca doğrulandı).
  Sorun profil sayfasıydı: sabit `LANGUAGES` yalnız tr/en içeriyordu ve kaydetmek dili uygulamıyordu.
  Genel Ayarlar'da da 5 dil elle yazılmıştı. Kiracı `locale` ayarı hiçbir yerde okunmuyor (not edildi, dokunulmadı).
- **Ne yapıldı:** İki sayfa da `locale-registry`'deki `SELECTABLE_LOCALE_OPTIONS`'ı kullanıyor;
  profil kaydında `await setLocale(language)`; eski `tr-TR` değerleri `normalizeLocale` ile okunuyor.
- **Dokunulan dosyalar:** `src/frontend/src/features/tenant/pages/profile/profile.page.tsx`,
  `src/frontend/src/features/settings/pages/general/general_settings.page.tsx`, `changelog.data.ts`.
- **Commit:** `769afbf8` — fix(i18n): profil ve genel ayarlarda tum diller secilebilir. DEV 1.0.2.1118, health 200.

### 2. E4 S2 — Dış girişte kalite bekletme
- **Neden:** Backlog E4; kullanıcı kararı: "dış giriş" = 3001, 3011, 3006, 3065.
- **Kurul:** cto + skeptic + dba + product-owner + security → APPROVE-WITH-CONDITIONS (scratchpad/board-e4s2-e9s4a.md).
- **Ne yapıldı:**
  - Stok kartında `QualityHoldPolicy` (0 yok / 1 bekle). Açıksa dış giriş fişindeki yeni seriler Bekliyor açılır.
  - Fiş onayında `LotsAwaitingInspectionEvent` → Quality otomatik "Giriş Kontrolü" muayenesi + `QualityInspectionLot` satırları.
  - Muayene onayında lot bazlı karar (Serbest/Bloke/Ret) → `QualityInspectionCompletedEvent` → Inventory
    `OnQualityInspectionCompleted_ApplyLotDecisions` lotlara uygular (kilitli, idempotent, asla throw etmez).
  - Fiş silinince bekleyen muayene temizlenir; kararı verilmiş fişin onayı geri alınamaz / silinemez.
  - Yeni okuma ucu `GET /api/v1/inventory/lots/quality-statuses` (inventory:read, en fazla 500 id) — Lotlar sekmesi için.
  - UI: kartta "Kalite bekletme" alanı, muayene detayında Lotlar sekmesi, listede "Mal kabul bekleyen" süzgeci,
    fiş lot paneli başlığında bekleyen/ret/bloke sayıları.
  - `quality.inspection.completed` webhook'u artık gerçekten gidiyor (önce boş TenantId yüzünden düşüyordu).
- **Migration'lar:** `20261029224841_Sprint_E4S2_IncomingHold`, `20261029225522_Sprint_E4S2_IncomingHoldIndexes`
  (CONCURRENTLY, suppressTransaction). Preflight: tekrar eden muayene/lot olayı ve işlenmemiş outbox varsa durur.
- **Post-review:** Security PASS. DBA koşulları: C2 (NULL InventoryId preflight'ta yanlış abort) düzeltildi,
  C1 yorum düzeltildi, C3 runbook eklendi (`docs/runbooks/e4-s2-incoming-hold.md`, preflight sorgusu içinde).
- **Doğrulama:** verify backend rc=0 (7106 unit). Frontend: golden payload fixture'ı yeni alanla güncellendi
  (`GOLDEN_WRITE=1 npx vitest run …inventory-payload.golden.test.tsx`); 3 yük kaynaklı flaky test tek başına geçti.
  Entegrasyon `IncomingHold` 7/7. `has-pending-model-changes` → No changes.
- **Not:** strip-migration-designers script'i eski 3 migration'ın Designer'ını da kırpmıştı; `git checkout origin/dev --` ile geri alındı.
- **Bellek:** İki ajan aynı anda `verify all` koşunca makine belleği bitti ve koşular öldürüldü → verify'i sırayla, backend/frontend ayrı koşmak.
  `npm ci` kilitli `esbuild.exe` yüzünden EPERM verdi; tekrar denemede geçti.
- **Commit:** `817037da` — feat(quality,inventory): dis giriste kalite bekletme (E4 S2).
- **DEV:** 1.0.2.1119, health 200; iki migration uygulandı, 3 indeks geçerli, CK doğrulanmış, geçersiz indeks 0.

### 3. E9 S4a — Rota adımı İç/Fason bayrağı (devam ediyor)
- wte8'de uygulandı, origin/dev 817037da üstüne alındı (changelog çakışması birleştirildi); verify + security/dba post-review sürüyor.

## Kararlar
- Ajanların `verify all` koşuları paralel yapılmayacak (bellek).
- E4 S2 Lotlar sekmesi için Quality→Inventory okuma ucu eklendi (modüller arası doğrudan sorgu yasak olduğu için).

## Açık kalanlar / sonraki adım
- E4 S2 UX post-check (DEV), ClickUp E4 güncellemesi.
- E9 S4a commit/deploy (1120), UX post-check.
- Sonra H8 rapor düzeltmesi (karar 10–11), E8 yeniden tasarım, E2 S4, E5 S2a-2 (3 gün sıfır sapma penceresi sonrası).
