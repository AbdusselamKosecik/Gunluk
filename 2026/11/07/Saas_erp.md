# Saas_erp — 2026-11-07

## Bağlam
Hedef: "backlog'u tamamlayalım". Kurul onaylı dilimler paralel worktree'lerde (`X:/GitHub/vuo-app/wt/wteNN`) ajanlarla yazıldı. Her dilim, tek bir otomatik hattan (`autoship.sh`) geçti. Kural şu: testler en sonda koşulur, test edilmeyen iş push edilmez, RAM korunsun diye kapılar seri çalışır.

## Yapılanlar

### 0. Kurtarma: Temp worktree'leri silindi
- **Neden:** Windows Storage Sense, `%TEMP%` altındaki worktree'lerde değişmemiş takipli dosyaları sildi (worktree başına ~7000 dosya).
- **Ne yapıldı:**
  - Silinen dosyalar `git ls-files -d -z | git checkout-index -z --stdin -f` ile geri getirildi.
  - Worktree'ler `X:/GitHub/vuo-app/wt` altına taşındı. Sürücüler arası `worktree move` çalışmadığı için şu yol izlendi: eski ağaçta `git stash push -u`, `git worktree add <X: yolu> <aynı HEAD>`, sonra `stash pop`.
  - Yardımcı betikler (`rebase.sh`, `regen.sh`, `gates.sh`, `prep.sh`, `autoship.sh`, `ship.sh`, `pgcmp.sh`, `clday.py`, `fixcat.py`, `jsonmerge.py`, `resolve_*.py`, `nulscan.py`) de aynı klasöre taşındı.
- **Karar:** Worktree'ler bir daha Temp'te tutulmayacak (hafıza notu: `worktrees-not-in-temp`).

### 1. Dilim hattı (`autoship.sh`)
- `prep.sh` adımları:
  1. Rebase: stash, ardından origin/dev üstüne pop.
  2. Çakışmaların otomatik çözümü:
     - api-errors JSON → `jsonmerge.py`
     - excluded/inscope → `theirs`
     - changelog → `resolve_both`
     - `TenantSettingKeys.cs` → `resolve_both`
  3. Migration yeniden üretimi (`regen.sh`).
  4. Changelog satırlarının bugünün sürümüne taşınması (`clday.py`).
  5. Hata kataloğu (`fixcat.py`). İngilizce metinlerin eksikleri `en_overrides.json` ile tamamlanır.
  6. Kapılar: unit, typecheck, lint, vitest (maxWorkers=2).
  7. PG entegrasyon karşılaştırması: dilim ile temel (wte14) yan yana koşulur; yalnız dilimde kırılan test varsa durulur.
- `ship.sh`: HEAD == origin/dev kontrolü, açık dosya listesi (`git add -A` yok), NUL taraması, commit ve `push origin HEAD:dev`.

### 2. Push edilen dilimler (hepsi kapılardan ve PG karşılaştırmasından temiz geçti)

| Commit | Dilim | Özet |
|---|---|---|
| `82c5ac9a` | E10-5 Y1 | Toplu parça işçilik sevkinde operasyon doğrulaması (fix) |
| `acf28f47` | E7 S4 | Konfeksiyon kolisi kapanınca otomatik mamul girişi, iptalde geri alma |
| `f7068e93` | E7 S5 | Koli okutmada paketleme talimatı asorti kontrolü (DEV sayımı: 0 etkilenen kayıt) |
| `96cd93f1` | E10-3 | Lot/seri satırında SKT ve çıkışta SKT rozetleri (yol B, uyarı) |
| `71d95add` | E10-3b | Kimyasal partisinde SKT ve kontrol modu: Kapalı / Uyar / Engelle (tenant ayarı `InventoryChemicalExpiryMode`) |
| `b04b0cde` | E5 S3 | Lot bölme. Çocuk lotlar `Origin=Split`, `ParentLotId` alır. Marj sayımı Split'i canlı sayar. Unapprove koruması: `has_split_children`. PG `LotSplitPostgresTests` 9/9; tahsis testi `StockAllocationDocument` seed'i ile düzeltildi. |
| `727e51ca` | H7 | Konfeksiyon numune onayı ve onaylı numuneye bağlı üretim emri. Parametreli; tenant ayarı `OrdersApparelRequireApprovedSample`. |

### 3. Kurul kararları
- **E7 S3b:**
  - `inventory.ReceiptItemBox` tablosu (IsClaimed filtreli unique index).
  - Ortak `BoxShipLock` advisory lock ve `IBoxShippedQuery` portu.
  - Logistics void/cancel/delete/reopen yolları kapsanır.
  - S3b-1 uygulaması sürüyor (wte21). S3b-2, UX tasarım notu çıkana kadar bekliyor.
- **E10-2:**
  - `OutputKind` smallint + CHECK, `WasteQuantity`.
  - Tüm toplamlar yalnız Main satırlardan.
  - Fire limiti port içinde.
  - UI'da ↳ alt satır.
  - Uygulama sürüyor (wte22).
- **E2 S3 (lot transferi):**
  - E5 S3'ün üstüne uyarlanıyor: split çocuğu da transfer edilebilir.
  - Kısmi transfer "önce böl" mesajıyla reddedilir.
  - Transfer edilmiş lot sonradan bölünmüşse transferin geri alınması reddedilir.

## Hatalar ve dersler
- **E5 S2a-2'de 40P01 deadlock:** `LotIssueRecheck`, sipariş satırı kilidinin arkasına alındı. Kilit sırası: üretim emri → satış satırı → lotlar.
- **Eski `<tag>-mig` kopyaları yanlış migration üretti:** `prep.sh` artık eski mig klasörlerini kenara alıyor.
- **Komutta kalan `py -3 -` stdin bekledi (~45 dk):** yama betikleri artık dosyaya yazılıyor.
- **TURKISH_IN_EN kapı hatası** (başkasının yeni kodları): `en_overrides.json` ile çözüldü.
- **Arda'nın `orders.variant.no_inventory` kodu** mükerrer mesaj yüzünden katalogdan düşüyor. Arda'ya bildirilecek.

## Açık kalanlar / sonraki adım
- E7 S3b-1 (wte21) ve E10-2 (wte22) bitince: commit mesajı, `autoship.sh` (filtre: Inventory|CrossModule|Production), ardından UX post-check (yerel yığın, yalnız push edilmiş ref).
- E2 S3 (wte7): çakışma çözümü ve split uyarlaması bitince `prep` ve `ship`.
- E5 S3 bölme diyaloğu için UX post-check.
- E7 S3b-2, E6 S3b/S4 ve E2 S4b-2 kurul koşullarını bekliyor.

## Akşam (18:30–22:00)

### 4. Kayıp migration olayı ve düzeltme
- **Ne oldu:**
  - E7 S4 (`UX_InventoryReceipt_PackingBox`) ve E10-3b (`InventoryReceiptItem.ExpiryDate`) dev'e migration'sız gitmişti.
  - Sebep: `prep.sh` yeniden koşuda kaydedilmiş `<tag>-mig` klasörünü kenara alıyordu.
  - Gözden kaçtı, çünkü PG testleri şemayı `EnsureCreated` ile modelden kuruyor.
- **Düzeltme:** `d415070e`. Orijinal elle yazılmış gövdeler geri kondu:
  - `E10_3b_ChemicalExpiryDate`
  - `E7S4_ApparelFinishedGoodsSourceUnique` (CONCURRENTLY + suppressTransaction)
- **Doğrulama:** boş `postgres:17` konteynerine (port 55432) tüm zincir `dotnet ef database update` ile uygulandı; indeks ve kolon mevcut. Unit 8989 geçti.
- **Hat değişiklikleri:**
  - `prep.sh` mig klasörünü yalnız worktree'de yeni migration varsa kenara alıyor.
  - Her dilimde `PENDING_CHECK:` satırı basılıyor.
  - `autoship.sh`, "No changes have been made" görmeden push etmiyor.

### 5. Push edilen dilimler (akşam)

| Commit | Dilim | Not |
|---|---|---|
| `e48bf677` | E10-2 | Paketleme ve sarımda atık / yan ürün satırları (`OutputKind` + CHECK, `WasteQuantity`, Ana-only raporlar). PG testi seed düzeltmesi: `StockAllocationDocument` FK; `Receipt` navigasyonu yüklenmediği için toplam SQL'de. |
| `ecde6651` | E7 S3b-1 | `inventory.ReceiptItemBox`, `BoxShipLock`, `IBoxShippedQuery`. Logistics'te sevk edilmiş koli void/iptal/silme reddi. Sunucu tarafı koli doğrulaması. `CreateReceipt` çakışması: `ExpiryDate` + `BoxIds` birlikte. |
| `a655e6c9` | E2 S3 | Depolar arası transferde lot/seri taşıma (Direction 0). E5 S3 uyumu: split çocuğu transfer edilebilir; transferden sonra bölünen lotun transferi geri alınamaz. CHECK `(-1,0,1,2)`. Testler 2 parçalı bölmeye çevrildi (bölme en az 2 parça ister). |

- Her dilim için kapılar: unit, typecheck, lint, vitest, PENDING_CHECK, PG karşılaştırması (yalnız dilimde kırılan yok). Ayrıca boş PG17'ye tüm migration zinciri uygulandı.

### 6. RAM olayı
- Arka plandaki autoship, düşük bellek yüzünden sistem tarafından öldürüldü.
- Asılı kalan `testhost` (5,2 GB) ve `VBCSCompiler` kapatıldı (`taskkill`, `dotnet build-server shutdown`).
- Dilimler tek tek yeniden geçirildi.

## Açık kalanlar (akşam sonu)
- UX post-check: E5 S3 bölme diyaloğu, E10-2 paketleme alt satırları, E2 S3 transfer lot seçici (yerel yığın, yalnız push edilmiş ref).
- E7 S3b-2: UX tasarım notu gerekli. E6 S3b/S4 ve E2 S4b-2: önceki kurul koşulları bekleniyor.
- Arda: `orders.variant.no_inventory` mükerrer mesaj.
