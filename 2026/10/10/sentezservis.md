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

### Siparişler: ürün başına work order + alt numara
- **Neden:** Kullanıcı tanımları tamamladı, paketi kurdu; istek: "her ürün (varyant değil) bir order oluşacak,
  oluşan order 1'den fazlaysa -1 -2 -3 diye artacak".
- **Kontrol (salt okuma, kayıt yok):** 573123 önizlemesi eksiksiz: TEST · EKRU 2169 (241/beden), LACİVERT 900,
  SİYAH 585, TEN 1350 = 5004 (= 2502 set × 2). Geçici canlı test dosyasıyla hesaplandı, dosya silindi.
- **Ne yapıldı:** Gruplama (cari) → (cari, bileşen mamul); `WorkOrderTaslagi`'na `MamulId`, `MamulKod`.
  `WorkOrderNumarasi.Sonrakiler`: tek order → `Test-005`, çok → `Test-005-1..n`; ana numara `Test-NNN[-k]`'nın
  NNN'inden (en büyük + 1). Arayüz kart başlığında ürün kodu.
- **Dokunulan dosyalar:** `src/SentezServis.Core/Siparis/{SiparisModelleri,WorkOrderToplayici}.cs`,
  `src/SentezServis.Host/Api/SiparisUclari.cs`, `tests/.../SiparisWorkOrderTestleri.cs`, `web/src/api/siparis.ts`,
  `web/src/pages/SiparislerSayfasi.tsx`
- **Sonuç:** Core 260 geçti / 6 atlandı, vitest 50/50, build temiz. Paket yeniden (arayüz 2026-10-10 02:19),
  `yayin-siparisler-2026-10-10.zip` güncellendi.
- **Commit:** `decf055`
- **Açık:** UZM_SiparisWorkOrder betiği + `WorkOrderYazmaAcik: true` → kullanıcı onayı bekleniyor.

### Order yap kontrolü + "Bağlantıyı kopar"
- **Kontrol (salt okuma):** Kullanıcı UZM_SiparisWorkOrder'ı kurdu (kolonlar/indeksler doğru), 02:19 paketini kurdu
  (`/api/surum` derleme 4321ca7… → aslında 02:19 exe), "Order yap" dedi. **Kayıt oluşmadı:** Erp_WorkOrder'da
  `Test-%` yok, son WO 4539; takip tablosu boş; SentezServis.dbo.denetim_kayitlari'nda `work-order-olusturuldu` yok,
  hata_kayitlari boş. Olası neden: sunucu appsettings'te `WorkOrderYazmaAcik` yok → 503 "yazma kapalı".
  `\MODFEXSRV\D$` erişimi reddedildi, ayar dosyası okunamadı.
- Not: Sentez'in kendi çoklu WO numaraları da `4314-1`, `4314-2` biçiminde — bizim `Test-NNN-k` ile uyumlu.
- **Ne yapıldı:** `SiparisDeposu.BaglantiyiKoparAsync` (DELETE … OUTPUT DELETED.WorkOrderNo, yalnız UZM_SiparisWorkOrder),
  `DELETE /api/siparisler/{id}/baglanti` (MudahaleIster, denetim `work-order-baglantisi-koparildi`), listede
  WO no yanında "Bağlantıyı kopar" düğmesi (onaylı). WO Sentez'de kalır, sipariş yeniden seçilebilir.
- **Sonuç:** Core 260/6 atlandı, vitest 50/50, build temiz; yazma sınırı guard'ı geçiyor. Paket 02:51.
- **Commit:** `0874891`
