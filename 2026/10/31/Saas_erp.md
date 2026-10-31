# Saas_erp — 2026-10-31

## Bağlam
2026-10-30 oturumu gece yarısını geçti; hedef `/goal backlog u tamamlayalim` sürüyor. Önceki gün: `2026/10/30/Saas_erp.md`.

## Yapılanlar

### 1. Kurul turu (2026-10-30 akşam): E9 S3, E4 S4, E6 S3, E3 S2
- Dosya: scratchpad `board-round-1030b.md` (CTO/Skeptic/DBA/PO + DECISION).
- E9 S3 ve E4 S4 onaylı (koşullu). E6 S3 BLOCK: öneri hiç oluşturulmayan `ProductionOrderBatchStepExecution`'a dayanıyordu (gerçek kayıt `JobTransaction`);
  kimyasal 3062'ye `SourceRefId = ProductionOrderId` yazmak emrin asıl sarfını "AlreadyPosted" yapardı → S3a/S3b/S4 yeniden öneri. E3 S2 → S2a/S2b/S2c bölündü.

### 2. E8 S1a — beklenen tedarik bağı temeli
- `inventory.SupplyPeg` (13 CHECK, `UX_SupplyPeg_Key` NULLS NOT DISTINCT, CONCURRENTLY indeksler), `PurchaseOrderLinesChangedEvent` → otomatik uzlaştırma,
  Orders portu `IPurchaseLineSupplyQuery` (tek canlı satır tanımı `PurchaseLineLiveness`), kilit ③→③b→④ sıralı; 55P03 → 409 `inventory.supply_peg.busy`;
  geriye dönük uzlaştırma `maxHeaders` + imleç. Bayrak `inventory.supplyPeg.enabled` yalnız owner/admin (sunucuda uygulanır).
- Post-review: DBA + güvenlik koşullu onay → uygulandı. HTTP katmanında tenant'lar arası test yapılamadı (test host'u InMemory/sahte tenant).
- **Commit:** `c7858afa`. **DEV:** 1.0.2.1127 (2 migration, 6 indeks geçerli).
- **Olay:** `wtdeploy` çalışma klasöründe 5421 izlenen dosya silinmiş bulundu (nedeni bilinmiyor) → `git checkout -- .` ile geri yüklendi, yayın tekrarlandı.

### 3. E9 S3 — fason hizmet faturası
- 4018 + `OrderReceiptId` → 5203 (port: tip/cari/iptal), profil TEMEL/TICARI; `InvoiceLine.SourceReceiptItemId` (3006 satırı);
  Faturalanacak = 3006 − 3065 − fatura satırları (taslak dahil, tek gruplu sorgu); hizmet kartı zorunlu (kumaş kartı kopyalanmaz); fazla faturalama uyarı.
- Post-review: DBA (`RESET lock_timeout`) + güvenlik (sekme `finance:read` ile) — ben uyguladım.
- **Commit:** `86ae6f9e`. **DEV:** 1.0.2.1128.

### 4. E4 S4 — top stok durumu / kalite durumu ayrımı
- StockState okumada türetilir; veri migration'ı yalnız `scrapped` → lot Ret (olaysız Serbest lotlar); Down yalnız kendi olaylarını geri alır;
  eski `status` parametresi eşlenir; yazmada 400; top uçlarına `inventory` yetkisi (önceden viewer top açabiliyordu); aralık doğrulaması.
- **Commit:** `1456a0c2`. **DEV:** 1.0.2.1128 (DEV'de hurda top yok → no-op).

### 5. E3 S2a — Ham (boyasız) sistem varyantı
- **Neden:** Karar: ham kumaş ayrı kart değil, aynı ürünün HAM varyantıdır (E3).
- **Ne yapıldı:**
  - `Variant`/`VariantGroup` tablolarına `SystemKey` alanı eklendi.
  - Migration her tenant için seed yapar:
    - Tek Renk/Color grubu varsa onu benimser; yoksa Renk grubunu, "Standart" kartını ve HAM'ı oluşturur.
    - Birden fazla aday grup varsa hiçbir şey oluşturmaz, NOTICE yazar ve Ayarlar'da seçim ipucu gösterilir.
  - Yeni tenant: `OnTenantCreated_SeedHamVariant` olay işleyicisi.
  - HAM silinemez, yeniden adlandırılamaz ve pasiflenemez:
    - Handler kontrolü, DB tetikleyicisi (`WHEN OLD.SystemKey IS NOT NULL`) ve kart koruması.
    - `ExceptionHandlingMiddleware`, 23514 `system_protected` hatasını 409'a çevirir.
  - Varyantlı kumaş kartında HAM zorunludur; kural yalnız varyantlar değişince çalışır, eski kartlar bloklanmaz.
- **Migration'lar:** `20261030233125_Sprint_E3S2a_HamSystemKey` ve `..._HamSystemKeyIndexes` (CONCURRENTLY, unique partial).
- **Doğrulama:**
  - BE 7540, FE 3073 test yeşil; `HamSystemKeyMigrationTests` gerçek PG'de 14/14.
  - DBA post-review şartları ve Security PASS (2 Low) uygulandı.
- **Commit:** `61ce375a`. **DEV:** 1.0.2.1129 — 18 tenantta HAM oluştu.

### 6. E12 — QA Excel'inin "Riskler ve Eksikler" sayfası backlog'a
- **Neden:** Kullanıcı isteği: `docs/qa/VuoApp_Test_Senaryolari.xlsx` dosyasındaki riskler ve eksikler backlog'a eklenip bitirilsin.
- **Ne yapıldı:**
  - 37 satır koda karşı doğrulandı: 10 madde kesin, 2 madde kısmi.
  - Kök nedenler:
    - Teklif/sipariş/fatura `ForexCalculator`'ı kullanıyor; dip indirim KDV matrahından düşmüyor, tevkifat ödenecekten düşmüyor.
    - Teklif→sipariş düğmesi yanlış URL'ye gidiyor (404).
    - Sipariş satırında teslim/fatura miktarı kalıcı tutulmuyor.
  - Backlog'a E12 eklendi (S1–S12).
- **Kullanıcı kararları:**
  - Teslim takibi otomatik olacak; sipariş %100 teslimde kapanır.
  - Fatura irsaliyeden ve siparişten kesilebilecek; kısmi fatura olacak, mükerrer fatura engellenecek.
  - İrsaliyede risk kontrolü siparişteki ayara göre yapılacak.
  - Eksiklerin hepsi yapılacak.
- **Commit:** `9d90826e`.
- **Sonraki:** S1 (KDV/tevkifat) + S2 (teklif→sipariş) + S8 (yer tutucu sayfalar) kurulda (cto/skeptic/po).

### 7. E6 S3a — kimyasal sarf idempotent + Kimyasal sarf düğmesi
- **Neden:** Kimyasal sarf yeniden gönderilince (çift tıklama veya yavaş ağ) stoktan iki kez düşüyordu; ayrıca diyalog hiçbir yerden açılmıyordu.
- **Ne yapıldı:**
  - `ConsumeChemicalsCommand.RequestId` eklendi. Bu id ile kind-3 `ProductionConsumptionPosting` satırı yazılıyor (`chem:`+RequestId); 3062 fişinin `SourceRefId` alanı null kalıyor.
  - Advisory lock alınıyor (lock_timeout 10s, 55P03 → 409 `request_in_progress`). 23505 yarışı yaşanırsa kazanan kayıt dönüyor.
  - Aynı RequestId farklı bir emir için gelirse reddediliyor.
  - CHECK kısıtı 1..4'e genişletildi: önce NOT VALID eklendi, ayrı bir migration'da VALIDATE edildi.
  - `RollOutputReceiptGuard` kind 3'ü muaf tutuyor; kind 2 ve 4 kilitli kalıyor.
  - Boyahane emir detayına `production:update` yetkisiyle görünen bir düğme eklendi. Miktar değişince yeni RequestId üretiliyor.
- **Doğrulama:** BE 7495 ve FE 3070 test yeşil; PG testleri 15/15. DBA ve Security post-review şartları uygulandı.
- **Commit:** `cac1d7c6`. **DEV:** 1.0.2.1130 (CHECK VALID).

### 8. Kullanıcı kararları (öğle)
- E12 S8: yer tutucu sayfalar gizlenmeyecek, geliştirilecek. Plan: S8a hazır ekranları bağla, S8b eksik backend'i yaz, S8c Konfeksiyon sayfalarını yap.
- Seri panelinde tarih formatı tarayıcı dilinden alınacak.
- Bozuk `_wt-idem` worktree'si kaldırıldı (`git worktree remove --force`; HEAD e49f2533 zaten dev'deydi).
- E12 S1/S2 kurulu: Skeptic BLOCK, CTO ve PO şartlı onay verdi. Gerekçe: e-Fatura UBL matrahı satır net tutarından hesaplanıyor; `IsVatBaseStale` dip indirimli faturayı reddederdi; tevkifat GL'ye yanlış gidiyor. v2 önerisi hazırlanıyor.

## Kararlar
- E6 S3/S4 ve E3 S2b/S2c yeni öneri gerektiriyor; E2 S4b, E8 S1b, E6 S3b+S4 önerileri Plan ajanlarında.

## Açık kalanlar / sonraki adım
- UX kontrolü E9 S3 + E4 S4 (DEV 1128) ve E3 S2a (1129). E6 S3a (wte8) post-review düzeltmeleri, E2 S4b-1 (wte9) uygulanıyor.
- E12 S1/S2/S8 kurulu → uygulama; ardından S3→S7, S9–S12.
- Öneri → kurul: E2 S4b (+Örme/Boyahane), E8 S1b, E6 S3a/S3b/S4.
- Sonra: E3 S2b/S2c, E5 S2a-2 (~11-01) ve S2b-S5, E8 S2b-S4b, E7 S2 (paralel operasyon tasarımı), E2 S3 (transfer tasarım dokümanı), E10, H12.
