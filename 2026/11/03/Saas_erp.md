# Saas_erp — 2026-11-03

## Bağlam
11-02 gecesinden devam: `/goal backlog u tamamlayalim`. 13+ dilim kodlu ve unit/frontend kapıları yeşil, ama
PostgreSQL (Testcontainers) entegrasyon testleri Docker kapalı olduğu için koşmamıştı; kullanıcı kuralı "test etmeden
gönderme". Docker Desktop `%LOCALAPPDATA%\Programs\DockerDesktop\Docker Desktop.exe` altında bulundu ve başlatıldı.

## Yapılanlar

### 1. PG test akışı (dilim başına, origin/dev ile karşılaştırmalı)
- **Neden:** origin/dev'de zaten kırmızı PG testleri var (Inventory'de 13: IHttpContextAccessor kaydı yok,
  `FK_InventoryReceiptItem_Unit_UnitId`); dilimin getirdiği hatayı ayırmak için baseline farkı gerekiyor.
- **Ne yapıldı:** scratchpad `pgtest.sh <wt> <filtre>` (integration build + filtreli test) ve
  `pgcmp.sh <wt> <tag> <filtre>` (aynı filtreyi origin/dev worktree'sinde koşup yalnız dilimde kırmızı olanları basar).
- **Komut:** `bash pgcmp.sh wte9 inv "FullyQualifiedName~IntegrationTests.Inventory"`

### 2. E5 S2a-2 — üretime çıkışta seriden kısmi çıkış
- **Bulgu (PG):** `SalesDispatchLockOrderPostgresTests` kırmızı. (a) Eski senaryo aynı 10'luk lottan iki taslak sevk
  açıyordu; kurul C6 kararıyla bu artık bilerek reddediliyor → test iki ayrı lot (A/B) ve aynı sipariş satırıyla yeniden
  yazıldı. (b) Bunun ardından GERÇEK deadlock (40P01): `ApproveReceipt` içinde `LotIssueRecheck.EnsureAsync`
  (lot kilidi) sipariş satırı kilidinden ÖNCE alınıyordu; `UpdateReceipt` ters sırada (sipariş satırı → lot).
  origin/dev'de aynı test 3/3 geçti → dilimin getirdiği hata.
- **Düzeltme:** recheck, `SalesOrderLinkGuard.ValidateAsync` sonrasına taşındı (emir → sipariş satırı → lot), yorumla.
- **Doğrulama:** deadlock testi 3/3; Inventory PG 194 test, 13 kırmızı = baseline ile aynı; unit 8584; vitest 3420.
- **Commit:** `76f86ffa` — feat(inventory): E5 S2a-2 uretime cikista seriden kismi cikis (anahtarli, varsayilan kapali)

## Kararlar
- Kısmi çıkış yalnız 3061 (Üretime Çıkış) ve kiracı anahtarı açıkken; satış sevkinde lot tamamıyla çıkar.
- Gece yarısından sonra push edilen dilimlerin changelog maddeleri yeni `2026-11-03` kaydına taşınıyor
  (scratchpad `clday.py <wt> 2026-11-03`).

## Açık kalanlar / sonraki adım
- Sırayla PG + push: S5b/S6, E2 S3 (E5 S3'ten sonra), SEPA, H12 (DEV sayımı önce), E10-1, E5 S5, E10-3, E7 S3a,
  H7, E7 S4, E7 S5, E10-3b, E10-5 Y1.
- E5 S3 lot bölme kodlanıyor (wte20).
- Arda: `orders.variant.no_inventory` iki farklı mesajla tanımlı → katalogdan düşüyor.
