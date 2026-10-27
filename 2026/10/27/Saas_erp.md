# Saas_erp — 2026-10-27

## Bağlam
Kullanıcı `/goal goal2.txt'i uygula` verdi (repo kökü `goal2.txt`, 13 madde). Çalışma worktree'si: `scratchpad/wtd` (origin/dev üstünde detached). Önceki gün işleri (satır indirimleri, kutucuklar, oturum kilidi) önce doğrulanıp push edildi (bkz. 2026/10/26 §12).

## Yöntem
- Keşif: 3 Explore ajanı (fiş Detay standardı haritası; lookup/reçete/rota/proje; iplik makine hatası).
- Öneri → `scratchpad/goal2-proposal.md`; kurul: CTO, Skeptic, PO, DBA (P6'da Skeptic BLOCK → kanıtla kaldırıldı: "partiyi açan" = üretim emrindeki **Partiyi Açan** alanı, `ProductionOrderDetailForm.fields.openedBy`); bağlayıcı koşullar `scratchpad/goal2-board-decisions.md`.
- Uygulama paralel şeritlerle (aynı worktree, ayrık dosyalar, şerit başına kendi i18n dosyası `g2a/g2b/g2c/g2d/g2e/g2a2.json` 11 dil; changelog + snapshot yalnız entegratörde).

## Yapılanlar

### 1. P1 — İplik emri makine (BUG)
- **Neden:** Y-0000000032 (tip 6) makine panosu/planlamada yoktu. Kök neden (DEV verisiyle kanıt): başlık `PlannedQuantity=0`, kalem 1.000.000 → `Free=0` → plansız listeye düşmüyor; emirdeki Makine Select'i hiç kaydedilmiyordu.
- **Ne yapıldı:** `QueueRules.EffectivePlanned` + `EffectivePlannedQuery` (tek gruplu sorgu): başlık >0 ise o; değilse boyahanede tüm kalemler, ürünlü başlıkta o ürünün kalemleri, aksi halde yalnız tek malzeme+tek birimse toplam; girilen miktar ezilmez. Free/pano/atama/GetById ortak. Miktarsız emir plansız listede uyarıyla, atama `machine_ops.planned_quantity_missing` ile reddedilir. Emir makine alanı = kuyruk ekle/taşı (iplik/örme/boyahane), dokumada tezgah kuyruğu; bölünmüş emirde salt okunur "N makinede"; kuyruk hatası emri geri almaz ("Tekrar dene").
### 2. P5 — Reçete tipi + standart lookup + rota tipe göre
- `ProductionRecipe.Type` + `(TenantId,Type)` index, backfill `COALESCE(rota tipi, 5)`; reçete seçimi GridLookupDialog+fixedType (el yapımı picker silindi); rota/reçete tip uyuşmazlığı backend'de reddedilir (yalnız değişen bağlantı kontrol edilir); tip değişince onayla temizlenir.
### 3. P6 — Üretim emri Proje + Partiyi Açan lookup
- `ProductionOrder.ProjectId`, `OpenedByEmployeeId` (FK yok); tenant doğrulaması `IFinanceProjectQueryService` (yeni) / `IHrmQueryService`; yetki/modül yoksa alan salt okunur.
- Migration: `20261026215205_RecipeTypeAndOrderProject`.
### 4. Dokuma son kullanıcı testi bulguları (tester, DEV)
- Üretim Tipi ve reçete kayıtta kayboluyordu → düzeltildi; CreatedAt 0001 → düzeltildi; varsayılan tarih İstanbul günü; `ManufacturingTypes.columns.*` çevirileri (`g2f.json`).
- **Backend kolonu olmadığı için hâlâ kaydedilmeyen form alanları** (kullanıcı kararı bekliyor): Müşteri Parti No, Belge No, Planlama tarihi, Tamir Tipi/Sayısı, Numune, Kapalı, Durum detayı, Saat, Birim Fiyat, Döviz, Kapasite, Hesaplama yöntemi, Özel/Erişim kodu, Alt tip, satır Malzeme Türü, Mik.(Top).
- Test kayıtları DEV'de: TEST-DK-OP1, TEST-DK-R1, Y-0000000033, ÇA-0002.
### 5. P2 — Talep/Teklif/Sipariş/Fatura Detay = fiş
- Barkod çubuğu (varsa miktar artar), malzemenin kendi birimleri, ekran+tip başına kalıcı kolon düzeni (localStorage `document-workspace.column-layout.v1:*`), varyant paneli ("Satırlara dağıt"), sipariş/talep satır deposu; `receipt-screen-standard.md` §2'ye tarihli istisna notu.
### 6. P4 — Lookup içinden Yeni → iç içe modal
- `common/components/shared/lookup/record-dialog/` (`RecordDialog`, `useRecordDialog`); detay sayfaları `props.id ?? params.id`, embedded'da onSaved/onCancel; kaydedince otomatik seçim; fixedType aktarılır. Dönüştürülen: Rota (pilot), Operasyon, Makine, Program kartı, Model, Ön maliyet, Dokuma analiz, Personel. Rota→Operasyon→Yeni 3. seviye çalışıyor.
### 7. P7 — Yönetici panosu
- 6 sayaç (Gridify totalCount pageSize=1, izole query, 403 gizli), listeler URL filtresi (`?status=open` vb.). Fatura tarih filtresi DEV'de 500 verdiği için bu ay sayısı son 100 faturadan istemcide.
### 8. P8 — Stok kartı yeniden tasarım (2. kurul turu: CTO/Skeptic/PO/UX/Security)
- Önce altın payload fixture + `buildInventoryPayload`; gruplu sol bölüm menüsü, özet başlık, kaydet çubuğu (değişiklik sayacı, Vazgeç, Ctrl+S), Genel çekirdek(20)/Gelişmiş(22), `ent` kaldırıldı, sınıfa göre bölüm gizleme, PLU Barkod bölümüne. Payload birebir aynı.
- Güvenlik bulgusu (önceden var): stok kartı yazma uçlarında `[RequirePermission]` yok → kurulda Skeptic BLOCK (varsayılan matriste user rolü edit'e sahip değil; bulk tek attribute). Bu turda yapılmadı, kullanıcı kararına.
### 9. P3 — Üretim emri Detay = fiş
- El yazımı tablo → `ReceiptDetailControl`; Stok Kartları lookup'ı satır malzeme türüne göre systemType filtresi (DEV'de doğrulandı: Kumaş 8115, Aksesuar 912, İplik 110, Kimyasal 3); malzemenin birimleri; payload snapshot testi.
### 10. Post-check düzeltmeleri
- UX (DEV): sipariş/teklif/fatura 1440px'te sayfa yana taşıyordu (Kaydet ekran dışı) → `ReceiptDetailControl` dış kutusuna `contain: inline-size` (kök neden: flex zincirinde min-width:auto, tablo min-content'i yukarı sızıyor; DEV'de canlı denendi 1594→1434). Gömülü kayıt diyaloğunda ilk odak "…'a Dön" düğmesine düşüyordu → ilk alana.
- Güvenlik post-check: PASS (düşük: `GET production-recipes` read izni yok — eski).

## Komutlar
```bash
bash tools/verify.sh all            # her birleştirmede; son: backend 6245, frontend 2709 test yeşil
git push origin HEAD:dev
git -C scratchpad/wtdeploy checkout --detach <sha>
DEPLOY_DIR=wtdeploy bash scratchpad/deploy-dev2.sh 1.0.2.<n>   # temiz worktree'den yayın
```
- Not: deploy betiği çalışma ağacından build ediyor → yarım işler imaja sızmasın diye ayrı temiz worktree (`wtdeploy`) kullanıldı.

## Commit'ler
- `b32957c4` feat goal2 (P1,P2,P4,P5,P6,P7,P8 + dokuma bulguları)
- `d2673d36` feat(production) P3 + taşma/odak düzeltmeleri
- DEV: 1.0.2.1075 (b32957c4), 1.0.2.1076 (d2673d36) — ikisi de health 200

## Kararlar
- "partiyi açan" = alan adı; "Order" = üretim emri; satış siparişine Proje eklenmedi.
- Stok kartı Kaydet yetki kilidi bu turda yok (rol matrisi kararı gerekiyor).
- Tarih filtresi 500 (Gridify DateTime Kind) ayrı backend işi.

## Açık kalanlar / sonraki adım
- Kullanıcı kararı: üretim emrinde backend kolonu olmayan alanlar (liste yukarıda); stok kartı/inventory yazma yetki kapısı; auth rate limiter kalıcı düzeltmesi (IP başına + refresh ayrı limit).
- Reçete, üretim emri listesi, sipariş/fatura listesi, stok kartı sayfalarının iç içe modal dönüşümü (P4 2. tur).
- Y-0000000032'de RCT01 Yıkama reçetesi duruyor; iplik tipinde reçete yok → kullanıcı iplik reçetesi tanımlamalı.
- Fatura tarih filtresi 500 → yönetici panosu fatura kutucuğu gerçek sayım.
- Dokuma testinde ulaşılmayan: Kumaş Teknik Analiz Formu kaydet, levent oluşturma, tezgah panosu işlemleri.

### 11. P4 2. tur + dokuma testi 2. bölüm
- **Ne yapıldı:** Lookup içinden Yeni → iç içe modal: reçete, üretim reçetesi, üretim emri, sipariş, fatura listeleri de dönüştürüldü (fixedType / fiş tipi aktarılır, kaydedince otomatik seçim). Stok kartı ve personel zaten modalda açıyordu.
- **Dokuma testi 2 (DEV 1076):** Kumaş Teknik Analiz Formu oluştur/kaydet/yeniden yükle/düzenle PASS (KA-0004), Çözgü Planlama analiz bağla + 9 levent oluştur PASS (Y-0000000033-C01..C09), üretim emri yeni Detay ızgarası (yazarak arama + F2 kumaş filtreli + uzunluk birimleri, kaydet/yeniden yükle) PASS. Sürtünmeler (rapor `scratchpad/weaving-test-report-2.md`): lookup seçiminden sonra odak satıra dönmüyor; analiz formunda malzeme/iplik lookup'ları türe göre süzülmüyor; çözgü planlama emir satır toplamı yerine başlık miktarını (1200) kullanıyor; emir detayında bağlı analiz görünmüyor.
- **Sonuç / doğrulama:** verify all yeşil (backend 6245, frontend 2722).
- **Commit:** `e8b45c8b` — DEV 1.0.2.1077 (health 200).

### 12. Reçete ayrımı (kullanıcı: "iplikte/dokumada neden işletme reçeteleri geliyor")
- **Neden:** `ProductionOrder.RecipeId` yalnız İşletme Reçetesi'ne (Boyahane kavramı, program+kimyasal) FK; P5 tip filtresi çalışıyordu ama Dokuma/İplik'te "İşletme Reçeteleri" sayfası açılıyordu. Kullanıcı kararı: Boyahane dışı = ürün reçetesi (`Recipe`); sonra "Dokuma'da reçeteyi kaldır".
- **Ne yapıldı:** `Recipe.Type` (§3.10) + `ProductionOrder.ProductRecipeId` (FK SetNull), migration `20261027042145_RecipeTypeAndOrderProductRecipe` (backfill rota tipi, rotasız NULL — 5'e düşme yok). OrderTypeGuard: Boyahane'ye ürün reçetesi / diğerine yeni işletme reçetesi red, eski kayıt değişmedikçe korunur. Ürün reçetesi silme/tip değişimi bağlı emir varken red. ResolveBarcode fallback, MRP `product-recipe-not-supported`. Frontend: tipe göre lookup, Dokuma'da alan yok, eski işletme reçetesi salt okunur + Temizle, localStorage reçete eşlemesi silindi, `orme-recipes`/`iplik-recipes` rotaları, reçete detayında tip + rota lookup'ı tipe sabit.
- **Kurul:** CTO/Skeptic/DBA APPROVE-WITH-CONDITIONS. Öneri/sözleşme: scratchpad `recipe-split-proposal.md`, `recipe-split-contract.md`.
- **Sonuç:** verify all yeşil (backend 6280, frontend 2734). DEV 1.0.2.1078 health 200, `?type=` filtresi doğrulandı. Not: Örme `recipes` → `orme-recipes`, eski menü yetki override'ı varsa yeniden verilmeli.
- **Commit:** `0524804f`.

### 13. Dokuma + Çözgü emri tasarımı (kullanıcı istekleri, sırayla)
- İstekler: satırda kumaş teknik analizi (KA, kumaşta birden çok olabilir); Çözgü üretim emri, satırda ÇA; sarfiyat/Reçete Detayı/tahsis analizden; reçete yok; malzeme türü Çözgü; menüde Dokuma / Çözgü emirleri ayrı; **bir çözgüden birden çok kumaş** (5700 m çözgü → A 1000, B 1000 farklı atkı, C 3000) → çözgü tahsisi; "bu kumaş emirleri için 1 çözgü emri oluşturacağım" ekranı. Kullanıcı kararları: bağlantı = çözgü tahsisi, leventler çözgü emrine.
- Tasarım v1 → v2 (Şüpheci BLOCK: tahsis anahtarı SyncItemAllocations çakışması kodla doğrulandı, `== Dokuma` 16 yer tablosu, tip-13 seed, tip değişimi CHECK) → v3 (WarpAllocation tablosu, Parent yok). Kurul v3: CTO/Şüpheci/DBA/PO APPROVE-WITH-CONDITIONS, **yalnız Faz 1** (planlama+tahsis; tezgaha dokunmaz). Faz 2 (levent çözgü emrinde, tezgahta sıradaki kumaş, kesimde yalnız atkı) ayrı kurul.
- Kararlar: WeavingKind = mevcut WeavingAnalysisKind (Warp=1, Fabric=2); çözgü metresi = Σ kumaş m × (1+çekme) + ilave BİR KEZ (Şüpheci); Faz 1'de çözgü emrinde iplik tahsisi yok (CTO/PO); tahsis metresi dondurulur, değişince stale.
- Dosyalar (scratchpad): `weaving-warp-requirements.md`, `weaving-warp-proposal{,-v2,-v3}.md`, `warp-f1-contract.md`. Uygulama iki şeritte başladı (backend + frontend).

### 14. Ürün reçetesi listesi 500 (kullanıcı URL'si: recipes?Filter=type=4&OrderBy=name)
- **Neden:** GetRecipes Gridify'ı konumsal DTO projeksiyonundan SONRA uyguluyordu (gridify-after-projection) → Postgres 500; in-memory testler yakalamaz.
- **Ne yapıldı:** filtre/sıralama entity üzerinde GridifyMapper ile, sonra Count/Skip/Take/Select; geçersiz alan → 400 `Production.InvalidQuery` (11 dil).
- **Sonuç:** DEV 1.0.2.1079'da aynı URL 200. **Commit:** `e1fb201a`.

### 15. CRM Leads kırılımı + tenant sızıntısı (kullanıcı: "crm/leads tenant kırılımını eklemeyi unutmuşsun" → AskUserQuestion: tenant içi kırılım)
- **Bulgu (DEV'de doğrulandı):** `Lead.cs`/`Opportunity.cs` kendi `HasQueryFilter(!IsDeleted)` tanımı, CrmDbContext'te base.OnModelCreating SONRA ApplyConfigurations çalıştığı için BaseDbContext tenant filtresini eziyordu → aynı lead Admin ve MitoTex tenant'ında görünüyordu. Satırlar kaldırıldı, izolasyon testleri. Lead/fırsat uçlarında RequirePermission yoktu → crm read/create/edit/delete (varsayılan matriste tüm rollerde var).
- **Özellik:** kırılım şeridi (Aşama/Kaynak/Sorumlu; adet, toplam, ağırlıklı, para birimi ayrı, kaybedilen=0, Atanmamış/Belirtilmemiş), tıkla-süz, sorumlu atama (`PUT crm/leads/{id}/assignee`, aktif üye kontrolü, ad sunucuda), Olasılık alanı. Şube/departman sistemde yok → ClickUp z8v9xnjjye.
- **Kurul:** CTO/Skeptic/PO koşullu onay; security PASS-WITH-FINDINGS (fırsat yetkileri aynı commit'te). **Commit:** `acec0827`, DEV 1.0.2.1080 (sızıntı kapandı, canlı doğrulandı).

### 16. Dokuma/Çözgü Faz 1 uygulandı
- Kumaş/Çözgü türü (WeavingKind, backfill Kumaş + CHECK), satır analizi, WarpAllocation + Çözgü Tahsis ekranı (yeni çözgü emri / mevcut çözgüye ekle; metre = Σ m×(1+çekme) + ilave bir kez), analiz-ihtiyaç ucu + MRP aynı servis (eski emirde sonuç aynı), çözgü emri tezgah/levent/top/kontrolde reddedilir, tip-3 stok tahsisi kuralları. Migration `20261027051657_Sprint_WarpAllocationAndWeavingKind`.
- Son kontroller: DBA onay (silmede log), security PASS-WITH-FIXES (purge tenant koşulu, analysis-requirements production:read) → `127085f6`. verify all yeşil (6420/2828).
- **Commit:** `76da4c71` + `127085f6`, DEV 1.0.2.1081. Canlı: Y-0000000033 weavingKind=2, analysis-requirements 200, liste filtreleri 200.
- **Ek düzeltme:** Çözgü sistem stok tipi DEV'de yoktu — `SeedSystemDataAsync` yalnız Development/--seed'de çalışıyor (DEV/PROD Production ortamı). İdempotent veri migration'ı `20261027054449_Sprint_SeedWarpInventoryType` → `8bdea1a9`, DEV 1.0.2.1082'de COZGU var.

### 17. DIA entegrasyon istekleri (kullanıcının yapıştırdığı not)
- **A (acil):** vats, variant-groups(+id), variant-cards, variants, lookups/variants → `[ApiKeyScope(inventory, read)]`; POST variant-groups/cards/variants → create; PUT/DELETE kapalı (test). Sınır testi (InventoryReferenceCatalogRollout) yeni sınıra güncellendi. CreateVariant grubu kartın grubundan alır. Security PASS. `234949e7`, DEV 1.0.2.1082.
- **B1 transfer tek taraflı:** UI de transfer bacak miktarlarını göndermiyor → ekrandan yapılan transferler de tek taraflıydı. `ReceiptLineDirection` tek kural (builder + detaylı stok raporu); Transfer tipleri (3014/3067/3102) Quantity-only → çıkış+giriş; 3014/3067 depo eksik/aynı → `inventory.receipt.transfer_warehouse_invalid`; 23505 → Conflict. 3067 iki taraflı (CTO kanıtı). DEV ölçümü: onaylı transfer 0 → onarım gerekmedi. Kurul CTO/Skeptic/DBA koşullu onay. `ac4b5134`, DEV 1.0.2.1083.
- **C5:** `GET inventory/receipt-types` kodda yok (yalnız /{code}/profile, /layout).
- **Açık:** B2 (5 varyant slotu + kart slot doğrulama), B3 (varyant bazında stok bakiyesi), C4 (inventory idempotency), C6 (items/bulk gerçek toplu yazım) — ayrı kurul.

### 18. B1 sonrası UX düzeltmeleri + Çözgü tahsis uçtan uca testi (DEV 1084)
- **Neden:** UX post-check APPROVE-WITH-CONDITIONS (çözgü listesi başlığı, taşmalar, erişilebilirlik); başlıkta analiz seçili kumaş emirleri aday listesine düşmüyordu.
- **Ne yapıldı:** Aday/komutlar "etkin analiz" kullanıyor (satır analizi yoksa başlık analizi, `fromHeaderAnalysis`); kendi levendi olan kumaşa tahsis reddi (`production.warp_allocation.fabric_has_own_beams`); Leads ve Çözgü Tahsis sayfalarında taşma, aria-pressed, htmlFor, tooltip düzeltmeleri.
- **Doğrulama (DEV Postgres, `scratchpad/warp-e2e.cjs`):** TEST-E2E-01 (KA-0004, 1000 m) → aday çıktı (ÇA-0002, çekme %8) → create-warp-order → Y-0000000035, 1080 m; iki yönlü bağlar ve ihtiyaç ekranı doğru; fazla tahsis `exceeds_fabric_line` ile red. Test kayıtları DEV'de duruyor: TEST-CZ-01, TEST-E2E-01, Y-0000000035.
- **Commit:** `fad6fe0f` → DEV 1.0.2.1084.

### 19. DIA: KDV oluşturma + fiş tipi listesi API anahtarına açıldı (DEV 1085)
- **Neden:** DIA test sonucu: GET vats açık ama boş, POST vats 403, GET receipt-types (liste) kapalı. Kullanıcı: "bunlar lazim".
- **Neden GET vats boş:** KDV tenant'a özel (`Vat : SoftDeletableTenantEntity`), sistem tohumu yok; DIA anahtarının tenant'ında kayıt yok. Artık POST ile kendileri açabilir.
- **Ne yapıldı:**
  - `InventoryController.CreateVat`: `[ApiKeyScope("inventory","create")]` + `[RequirePermission("inventory","create")]`; Update/Delete Vat'a `edit`/`delete` yetkisi (önceden viewer dahil her üye yazabiliyordu — güvenlik bulgusu).
  - Yeni `GET api/v1/inventory/receipt-types` → `ReceiptTypeRegistry.StockProfiles()` (İrsaliye ailesi katalog profilleri, koda göre sıralı, statik; tenant verisi yok), `inventory:read`.
  - Create/UpdateVat validator: oran 0–100, tutar ≥ 0, SpecialCode/UniversalCode ≤ 15 (kolon boyu).
- **Dokunulan dosyalar:** `Inventory/Features/InventoryController.cs`, `Features/Vats/CreateVat.cs`, `UpdateVat.cs`, `Services/Stock/ReceiptTypeRegistry.cs`, testler `Modules.Inventory/ReceiptTypeListTests.cs`, `VatIntegrationHardeningTests.cs`.
- **Kurul:** security-reviewer APPROVE-WITH-CONDITIONS (yetki + validator) → uygulandı. Tenant izolasyonu: tenant anahtardan, X-Tenant-Id anahtarda yok sayılıyor, gövdede TenantId/Id yok.
- **Doğrulama:** ilgili 744 birim testi yeşil; `verify.sh all` rc=0; canlı: receipt-types 200 / 52 tip; POST vats rate=150 → 400 `validation.invalid_range`.
- **Not:** ilk deploy denemesi "tag does not exist" ile düştü (buildx o an docker-container sürücüsünü seçmiş, imaj yüklenmemiş); ikinci denemede normal.
- **Commit:** `153335ad` → DEV 1.0.2.1085.

### Açık kalanlar (güncel)
- DIA: B2 (5 varyant slotu + slot doğrulama), B3 (varyant bazlı bakiye — büyük), C4 (stok idempotency), C6 (gerçek toplu upsert) — her biri kurul ister.
- Çözgü Faz 2 (levent, tezgâhta sıradaki kumaş, yalnız atkı sarfı).
- Düşük güvenlik bulguları: çözgü tahsisinde warpInventoryId tenant kontrolü; üretim emri GetById/listede RequirePermission; CRM CurrentAccountId/LeadId tenant kontrolü.
- DEV test kayıtlarının silinmesi kullanıcıya soruldu/bekliyor.
