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

### 3. E9 S4a — Rota adımı İç/Fason bayrağı + adımdan fason siparişi
- **Neden:** Backlog E9; kullanıcı kararı 8 (şimdi yap) ve 12 (bayrak kilitli revizyonda da değişir).
- **Ne yapıldı:** RouteItem.SourcingType + DefaultSubcontractorId; dar uç `PUT routes/{id}/items/{itemId}/sourcing` (audit);
  üretim emri detayında fason adımdan 5203 ön-dolu açılır; aynı adım için tek canlı 5203 (`UX_OrderReceipt_SourceStep`, 409 + mevcut sipariş id);
  canlı 5203 varken emir rota değişikliği/revizyon yükseltme/silme engellenir; `POST /orders` artık `order:create` istiyor.
- **Migration'lar:** `20261029224207_Sprint_E9S4a_RouteSourcing`, `20261029224215_Sprint_E9S4a_RouteSourcingIndexes`
  (zaman damgası uygulanmış E4 S2'den eski — EF eksik olanları id sırasıyla uygular, sorun değil; DBA doğruladı).
- **Post-review:** Security PASS; bulgusu (alt-modül süzgeci RouteItem'da uygulanmıyor) düzeltildi: öğe artık `_db.Routes...SelectMany(r => r.Items)` ile bulunuyor.
  DBA: VALIDATE aynı transaction'da (kilit kazancı yok) — tablolar 7/18 satır, bilerek kabul.
- **Doğrulama:** rebase sonrası verify backend rc=0 (7148), frontend rc=0 (2987); has-pending → No changes.
- **Commit:** `917b8b2d`. **DEV:** 1.0.2.1120, 5 CK doğrulanmış, indeks geçerli.

### 4. UX post-check düzeltmeleri (E4 S2 + E9 S4a)
- **Neden:** ux-reviewer DEV'de PASS-WITH-NITS verdi.
- **Ne yapıldı:** Kalite bekletme ipucu kısaltıldı (uyarılar `LoomInfoHint`'te), etiket üst hizalı; "Mal kabul bekleyen" süzgeci
  tablo araç çubuğuna (GenericTable'a eklemeli `toolbarExtra` yuvası); muayene lotlarında birim (`useGetInventoryById`);
  `OrdersOrderCreate.supplier/warehouse/warehouseNone` 11 dilde (başka bir commit'ten kalan ham anahtarlar, 80425795);
  rota İç/Fason başlığında "hemen kaydedilir" ipucu; 5203'te Müşteri Sipariş No gizli.
- **Doğrulama:** verify frontend rc=0 (2991). **Commit:** `bd822bd0`.
- **Doğrulanamayan:** DEV'de bekleyen lot / fason adım olmadığı için Lotlar bölümü, fiş başlık sayıları ve "Fason siparişi aç" canlı görülmedi.

### 5. H8 — Fason / Ham Depo / İplik rapor düzeltmeleri
- **Neden:** Kullanıcı kararları 10–11 (Sentez'den bilerek ayrılma).
- **Kurul:** cto + skeptic + product-owner APPROVE-WITH-CONDITIONS (11 koşul, scratchpad/board-h8.md). Şema yok → DBA gerekmedi.
- **Ne yapıldı:** Kalan = (Giden − Giden iadesi) − (Gelen − Gelen iadesi), Fire % = Kalan / brüt Giden; iade iç parçaları
  Gelen iadesi {3065} / Giden iadesi {3021, 3012}; `SubcontractBucket` değerleri değişmedi (frontend anahtarı).
  Ham Depo müşteri malı {3011, 3006}. İplik raporu: kumaş {3010, 3006} − 3065 (SQL işaretli toplam, net ≤ 0 düşülür),
  iplik tarafında 3006 −1 / 3065 +1 yalnız iplik kartlarında (skeptic'in bulduğu sahte "Verilen" satırı riski).
  İpuçları ve "Müşteri Malı Girişi" etiketi 11 dilde, changelog.
- **Doğrulama:** verify backend rc=0 (7167), frontend rc=0 (2987); golden değerler yeni.
- **Commit:** `ea1e65ca`. **DEV:** 1.0.2.1121, health 200.
- **Bilinen sınır:** boyahane tenant'ında 3006 müşteri kumaşı → İplik raporu anlamsız; ClickUp backlog z8v9xnjrp3.

### 6. D6 — Siparişe bağlı mal kabulde aşım uyarısı
- **Neden:** Kullanıcı kararı 6 (%10 üstü yalnız uyarı). Eski kural (D1 koşul 6, %0 tolerans) her aşımı hata yapıyordu.
- **Kurul:** CTO (S3'ten ayrılıp hemen çıksın, kural tersine dönüşü onaylandı) + Skeptic koşullu onay; PO tenant ayarı istedi, CTO+Skeptic sabit 10m dedi → çoğunluk.
- **Ne yapıldı:** `PurchaseOrderLinkGuard.ValidateAsync` sert hataları korur, aşımı `OrderOverReceiptWarning` listesi olarak döner;
  Create/Update/Approve sonuçlarında ayrı `OrderWarnings`; fiş ekranında kaydet/onayda ayrı uyarı; `order_over_received` hata kodu kalktı.
- **Doğrulama:** verify backend rc=0 (7168); frontend 1 test zaman aşımı (i18n lazy `ka`, tek başına 20/20 geçti — bilinen yük flaky'si).
- **Commit:** `19b14413`. **DEV:** 1.0.2.1122.

### 7. Kurul turları (kod yok)
- **E8 v2** (beklenen tedarik bağı): S2a hepsi koşullu onay → uygulanıyor (wte7). S1 DBA BLOCK (iptal satırında CHECK karşılanamıyordu,
  taban formülü) → v3 (e8-s1a-v3-proposal.md) → DBA + Skeptic koşullu onay; S1a/S1b bölündü, kullanıcıya S4a'ya kadar kapalı (DEV pilot admin görür).
  Bulgu: CreateReceipt ile UpdateReceipt kilitleri ters sırada alıyor (mevcut, düşük-orta: 40P01 geri alma, bozulma yok) → S3 giriş şartı.
- **E2 S4** (dokumada iplik emre çıkış = tüketim): 5 üye koşullu onay; S4a/S4b bölündü; rejim emir başına saklanır (anahtar geri alınca çift düşüm olmasın),
  deploy anında süren emirler Teorik kalır. Uygulanıyor (wte9). Koşullar: scratchpad/board-e2s4.md.

## Kararlar
- Ajanların `verify all` koşuları paralel yapılmayacak (bellek).
- E4 S2 Lotlar sekmesi için Quality→Inventory okuma ucu eklendi (modüller arası doğrudan sorgu yasak olduğu için).

## Açık kalanlar / sonraki adım
- E8 yeniden öneri (S1/S2 BLOCK gerekçeleri + karar 5–6) ve E2 S4 önerisi Plan ajanlarında; sonra kurul.
- Takip maddeleri ClickUp z8v9xnjrp3 (PUT /orders yetki, port alt-modül kısıtı, İplik/boyahane, fiş satırı sayı kolonu, fasoncu lookup süzgeci).
- E5 S2a-2: DEV 1116'dan sonra 3 gün sıfır sapma penceresi (≈ 2026-11-01).
- `_wt-idem` worktree'nin git index'i bozuk (zararsız gürültü; ileride `git worktree remove`).
