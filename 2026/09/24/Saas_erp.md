# Saas_erp — 2026-09-24

## Bağlam
Yerelde commit'lenmemiş halde duran "Stok Kartı bağımsız 2. birim seti" işi vardı (20 dosya). Kullanıcı isteği: commit + push.

## Yapılanlar

### 1. İkincil birim seti özelliği commit'lendi
- **Neden:** Diskte duran iş kayıp risklidir; push edilmeyen iş bitmiş sayılmaz.
- **Ne yapıldı:** Backend (entity + SecondaryUnitSetWriter + Create/Update/GetById), frontend (2. Birim tab, inventory.detail, generic-table-request), migration `20260919205051_InventorySecondaryUnitSet`, testler ve tasarım dokümanı tek commit'te toplandı.
- **Dokunulan dosyalar:** `src/backend/VuoApp.Modules.Inventory/*`, `src/backend/VuoApp.Migrator/Migrations/20260919205051_*`, `MigratorDbContextModelSnapshot.cs`, `src/frontend/src/features/inventory/*`, `src/frontend/src/core/services/generic-table-request*`, `tests/unit/VuoApp.UnitTests/Modules.Inventory/*`, `docs/architecture/inventory-secondary-unit-set.md`
- **Komutlar:**
  ```bash
  git add <yollar> && git commit -F - && git push
  ```
- **Sonuç / doğrulama:** `e7380557..481ad9b0 dev -> dev` push edildi. Bu turda build/test çalıştırılmadı.
- **Commit:** `481ad9b0` — feat(inventory): independent secondary unit set on inventory cards

## Kararlar
- Değişiklikler atılmadı, commit'lendi (kullanıcı onayı ile).

## Açık kalanlar / sonraki adım
- Ortak dev DB'de eski `20260912140914_Sprint014_...` migration'ı hâlâ çakışıyor; yerel API `--skip-migrate` ile çalışıyor. Kurul/dba kararı bekliyor.
- Jenkins deploy URL'si 301 ile https'e yönleniyor, sertifika IP için geçersiz → deploy tetiklenmiyor.
- Jenkins log'unda sızan Docker Hub ve GitHub PAT'leri hâlâ iptal edilmeli.
