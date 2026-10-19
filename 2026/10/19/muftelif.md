# muftelif (SentezSelvedge) — 2026-10-19

## Bağlam
Hedef: SentezSelvedge, modfex-apparel/selvedge gibi tamamen Sentez'den çalışacak.
İstek: "Sentez'den çalışmayan ne var" analizi. Kod değişikliği yapılmadı.

## Yapılanlar

### 1. Sentez'den çalışmayan noktaların analizi
- **Neden:** Modfex selvedge'de QA/anket dışındaki her şey SentezCore view'leri (`0028_sentez_canli.sql`); SentezSelvedge'de neyin hâlâ yerel olduğunu çıkarmak.
- **Ne yapıldı:** `SentezSelvedge/db/000*.sql`, `api/Sentez/SentezSql.cs`, `api/Selvedge/*`, spec `docs/superpowers/specs/2026-10-03-sentezselvedge-design.md` ile modfex `db/migrations/0028/0029` karşılaştırıldı.
- **Bulgular:**
  1. `UZM_Selvedge_Firm` yerel CRUD tablo (Sentez carisinin kopyası değil, `SentezCurrentAccountId` opsiyonel). Anket cevabı ve KK raporu `FirmId` ile buna bağlı; KK'da ayrıca `SentezCurrentAccountId` var → çift kaynak. Modfex: `sv_Firm`/`sv_Supplier` = tüm cariler view.
  2. `UZM_Selvedge_Brand` yerel, API/seed yok → KK `BrandId` hep NULL. Modfex: marka = siparişi olan cari.
  3. `UZM_Selvedge_Defect` tablo var ama API/seed/ekran yok; KK hata satırı serbest metin. (Modfex'te de yerel — Sentez işi değil ama ölü.)
  4. Sezon hiç okunmuyor (`Erp_Season`, `Erp_Inventory.SeasonCode`/`UD_WashName` spec'te var, SQL'de yok).
  5. Order sorgusunda `WorkOrderType = 15` filtresi yok (modfex'te var) → üretim iş emirleri de listeye düşebilir. CompanyId filtresi de yok.
  6. Modfex'teki yerel ek alanların karşılığı yok: `sv_OrderQc` (Status/FinalQc/Supplier/Notes), `sv_StyleQa`.
- **Sonuç:** Kullanıcıya rapor edildi, karar bekleniyor.

## Açık kalanlar / sonraki adım
- Firma → Sentez cari mi, yerel mi kalacak (saha "Sentez'de olmayan firma" gerekçesi) kararı.
- Marka kaynağı, WorkOrderType filtresi, sezon okuma.
