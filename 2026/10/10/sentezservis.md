# sentezservis — 2026-10-10

## Bağlam
Kullanıcı: "Serviste https://mf-s.uzmanadres.com/karma-koli de kullanımda olmayan varyantları getirmez misin, listede de detayda."

## Yapılanlar

### 1. Karma koli: kullanım dışı varyantlar gizlendi — `f5a0ce3`
- **Neden:** `Erp_InventoryVariant.InUse` (UdtBool) vardı ama sorgular yalnız `IsDeleted`'a bakıyordu.
  Canlı veride (şirket 2) set varyantlarının 8.166'sı InUse=0, 2.725'i InUse=1; bileşenlerde 71.968 / 49.415.
  Tanımlı karma kolilerin hepsi InUse=1 varyantlarda; içerikte InUse=0 varyant yok (salt okuma ile kontrol).
- **Ne yapıldı:** `KarmaKoliDeposu`'na `AktifVaryantKosulu = "ISNULL(iv.IsDeleted,0)=0 AND ISNULL(iv.InUse,1)=1"`;
  kullanıldığı yerler: `SetMamulleriAsync` (liste, varyant sayısı), `MamulVaryantlariAsync` (detay, öneri, toplu
  uygula, bileşen varyantları), `MamulAraAsync` (yalnız kullanımda varyantı olan mamul), `VaryantlarAsync(sadeceAktif)`
  (kaydetme doğrulaması). Kayıtlı içeriği göstermek için kullanılan filtresiz `VaryantlarAsync` değişmedi.
- **Dokunulan dosyalar:** `src/SentezServis.Core/KarmaKoli/KarmaKoliDeposu.cs`,
  `tests/SentezServis.Core.Tests/KarmaKoliDeposuCanliTestleri.cs` (yeni, `SENTEZCORE_TEST` ile salt okuma).
- **Doğrulama:** Canlı testler önce 4/4 kırmızı (InUse=0 varyant dönüyordu), düzeltmeden sonra 4/4 yeşil;
  tüm suite 245 geçti, 4 atlandı. Bağlantı, kesimhane ayarlar.json'daki DPAPI şifresiyle (scratchpad `canlitest.ps1`).
- **Yayın:** `deploy/yayinla.ps1 -AyarlariKoru` → `yayin/`, arayüz tarihi 2026-10-10 00:35.

## Açık kalanlar
- Sunucuya (MODFEXSRV) kurulum: `deploy/uzaktan-yayimla.ps1` ya da paket — kullanıcı onayı bekleniyor.

### Siparişler ekranı → work order ("Order yap")
- **Neden:** Kullanıcı: siparişleri seçip "Order yap" ile, cari bazında karma koli açılımıyla toplanmış
  (EKRU 30+30+30 → 90) `Erp_WorkOrder` oluşturmak. Numara şimdilik `Test-001`'den. **Kayıt yapılmayacak**,
  paket çıkarılıp birlikte kontrol edilecek (karma koli tanımları henüz yapılmadı).
- **İnceleme (salt okuma):** Sipariş `Erp_OrderReceipt` 573123 (ReceiptType 2, cari 16549 `120.01.048`),
  kalem TEST-10 (2'li set), 54 varyant satırı / 2.502 adet, karma koli tanımı 0. Örnek WO 4539: başlık
  WorkOrderType 15, Status/IsChecked/IsApproved 1, PackageQuantity 1, QuantityPerLot = Quantity; kalem
  bileşen mamul+renk (`InventoryVariantIds = "{renkId},"`, `Variant1Id`), `Erp_WorkOrderItemVariant` beden başına.
  TR-4115 eski tip (V1/V2, OperationCode, RouteId) — yalnız referans.
- **Ne yapıldı:**
  - `src/SentezServis.Core/Siparis/WorkOrderToplayici.cs` (saf): set varyantı `UZM_KarmaKoli` içeriğiyle
    açılır, cari → (mamul, renk) → beden toplanır; tanımsız/varyantsız satır `Eksikler`e, `Kaydedilebilir` false.
    `WorkOrderNumarasi.Sonrakiler` (Test-NNN, en büyük + 1).
  - `SiparisDeposu`: liste (açık satış siparişleri, ≤500), önizleme, `OlusturAsync` (tek transaction,
    UPDLOCK/HOLDLOCK numara + takip kontrolü, Erp_WorkOrder/Item/ItemVariant + `UZM_SiparisWorkOrder`).
  - Uçlar `/api/siparisler` (durum, liste, POST onizleme, POST order). **Order yazma `SentezServis:WorkOrderYazmaAcik`
    ile korunur, varsayılan kapalı** → 503; takip tablosu yoksa da 503. `WorkOrderEkleyenId` → InsertedBy.
  - `db/sentezcore/siparis-work-order.sql` (UZM_SiparisWorkOrder, OrderReceiptId UNIQUE) — **çalıştırılmadı**.
  - Web: `pages/SiparislerSayfasi.tsx` (seçim, Önizle, açılamayan satırlar, WO başına renk×beden matrisi,
    Order yap + engel nedeni), `api/siparis.ts`, `utils/siparis.ts` (bedenMatrisi), menü "Siparişler".
  - Yazma sınırı guard testi genişletildi: SiparisDeposu yalnız Erp_WorkOrder* + UZM_SiparisWorkOrder.
- **Sonuç / doğrulama:** Core testleri 257 geçti / 6 atlandı; canlı salt-okuma testleri 6/6
  (`SENTEZCORE_TEST`); vitest 50/50; `npm run build` temiz. Paket `deploy/yayinla.ps1` → `yayin/`
  (arayuzTarihi 2026-10-10 01:06) + `yayin-siparisler-2026-10-10.zip`. DB'ye hiçbir kayıt yazılmadı.
- **Commit:** `4321ca7` — Siparisler ekrani: ... "Order yap"

## Kararlar (siparişler)
- Bir cari = bir work order; kalem = bileşen mamul + renk; header Quantity = kalemlerin toplamı.
- Eksik satır varsa hiç kayıt yok (kısmi WO yok). Kayıtta önizleme sunucuda yeniden hesaplanır.
- Sipariş ↔ WO bağı Erp_WorkOrder.OrderItemId yerine UZM_SiparisWorkOrder (çok sipariş → bir WO).

## Açık kalanlar (siparişler)
- Karma koli tanımları (TEST-10). NUDE, MÜRDÜM, VİZON, LİLA TEST'in kullanımda renkleri değil.
- Birlikte kontrol → `siparis-work-order.sql` çalıştır → `WorkOrderYazmaAcik: true` (+ `WorkOrderEkleyenId`).
- Sunucuya yayın (MODFEXSRV, port 81).
