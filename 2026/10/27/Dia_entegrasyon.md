# Dia_entegrasyon — 2026-10-27

## Bağlam
25.10'da DIA demodan kartlar, varyantlar ve fişler okunmuştu (`docs/dia-demo-cevaplar/`). Kullanıcı bir VuoApp API
anahtarı verdi ve "kartları ve fişleri içeri aktar" dedi. Kurul süreci dışında, doğrudan talimatla yapıldı.

## Yapılanlar

### 1. Anahtarın ortamı bulundu
- Salt okuma GET denemeleri: `app-dev.vuo.app` 200 döndü (tenant boş), `app.vuo.app` 401 `ApiKey.Invalid`.
- Anahtar yalnızca dev ortamında geçerli. Anahtar repoya ve günlüğe yazılmadı.

### 2. VuoApp API sözleşmesi çıkarıldı (Saas_erp kaynak kodu, Explore ajanı)
- Uçlar: items, items/bulk (≤500, kodla upsert), receipts, warehouses, units, unit-sets, types, kinds, currencies.
- **Varyant uçları API anahtarına kapalı** (`[ApiKeyScope]` yok).
- Fiş kaleminde varyant dizisi yok; kalem başına tek kombinasyon, en fazla 3 slot.
- Transfer onaylanırsa tek tarafı stoka işleniyor.
- Inventory komutlarında idempotency yok.
- Ayrıntılar: analiz §2.1.3.

### 3. Aktarım
- **Betik:** `tools/dia_to_saas.py` (modlar: dry | one | items | receipts)
  ```bash
  VUO_KEY=... python -I tools/dia_to_saas.py docs/dia-demo-cevaplar dry
  VUO_KEY=... python -I tools/dia_to_saas.py docs/dia-demo-cevaplar one       # depolar + ilk kart
  VUO_KEY=... python -I tools/dia_to_saas.py docs/dia-demo-cevaplar items     # 78 kart bulk
  VUO_KEY=... python -I tools/dia_to_saas.py docs/dia-demo-cevaplar receipts  # 14 fiş
  ```
- **Eşleme:** birimler mevcut SaaS birim ve setlerine eşlendi (PK→PKT, TN→TON). Tür eşlemesi TCR/HMD/MML/YMML/KK; fiş türü eşlemesi analiz §2.1.3'te.
- **Sorun:** `LND.BRD.360` kartının DIA açıklaması boş olduğu için bulk aktarımda "Name empty" hatası verdi. Ad olarak kart kodu kullanıldı, tekrar çalıştırıldı (upsert).
- **Sonuç (GET ile doğrulandı):** 2 depo (AI00, AI01), 78 kart (75 Ticari, 2 Hammadde, 1 Mamul), 14 fiş (kalem sayıları DIA ile aynı).
  Hepsi onaysız; stoka işlenmedi. 3 maliyet fişi atlandı. 11 varyantlı kart varyantsız aktarıldı.
- **Commit:** `b0e51b6` — feat(tools): DIA demo -> VuoApp app-dev deneme aktarim betigi; SaaS kisitlari analize eklendi

## Kararlar
- Fiş numarası `DIA-<fisno>`, KDV 0, para birimi TL.
- Devir fişinin SaaS karşılığı yok; 3015 (özel giriş) kullanıldı.
- Fişler onaylanmadı. Transfer tek taraflı işleneceği için onay kararı kullanıcıya bırakıldı.

## Açık kalanlar / sonraki adım
- Fişler onaylanacak mı (transfer hariç)?
- Varyantlar için VuoApp'ta varyant uçlarına ApiKeyScope eklenmesi gerekiyor (Saas_erp işi).
- Transferin iki taraflı işlenmesi için VuoApp tarafında düzeltme gerekiyor.
