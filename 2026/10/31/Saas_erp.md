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

## Kararlar
- E6 S3/S4 ve E3 S2b/S2c yeni öneri gerektiriyor; E2 S4b, E8 S1b, E6 S3b+S4 önerileri Plan ajanlarında.

## Açık kalanlar / sonraki adım
- E3 S2a (wte7, uygulanıyor); UX kontrolü E9 S3 + E4 S4 (DEV 1128).
- Öneri → kurul: E2 S4b (+Örme/Boyahane), E8 S1b, E6 S3a/S3b/S4.
- Sonra: E3 S2b/S2c, E5 S2a-2 (~11-01) ve S2b-S5, E8 S2b-S4b, E7 S2 (paralel operasyon tasarımı), E2 S3 (transfer tasarım dokümanı), E10, H12.
