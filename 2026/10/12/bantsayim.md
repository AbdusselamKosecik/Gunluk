# bantsayim — 2026-10-12

## Bağlam
Kullanıcı 60 maddelik hata listesini (kod, üretim aşaması, tür, açıklama) yapıştırıp "bu hataları Sentez'le günceller misin" dedi.

## Yapılanlar

### 1. Sentez hata kartları (Erp_FaultyCard) — `2d89adc` (paketleme `6f86fa0`)
- **Önceki durum:** 13 kart (01 LEKE … 13 PAKET); bant okutmalarında 7'si 20 kez kullanılmış (`UZM_UretimOkutma.FaultyCardId`).
  Tabloda açıklama kolonu yok, `FaultyName` 50 karakter, `ParentId`/`IsMainFaulty` var.
- **Kullanıcı kararı:** eskilerin üzerine yaz ama kodlar "bizim gibi" (H001…); aşamalar üst kart, ad = hata türü.
- **Ne yapıldı:** `db/hata-kartlari.tsv` (liste + açıklamalar, referans), `db/0002_hata_kartlari.sql` (idempotent, tek transaction):
  7 üst kart HA01..HA07 (IsMainFaulty=1), RecId 1..13 → H001..H013 (üzerine yazıldı; geçmiş okutmalar yeni adları gösterir),
  H014..H060 eklendi, hepsi ParentId ile aşamasına bağlı. **Canlıda çalıştırıldı** (kullanıcı istedi):
  ```powershell
  scratchpad\yaz.ps1 -Sql (Get-Content db\0002_hata_kartlari.sql -Raw)   # → Toplam 67, Asama 7, Hata 60
  ```
- Kod: aşama kartları hata barkodu listelerinde (bantsayim `HataKartlari.ListeAsync`, paketleme `HataEtiketi.KartlarAsync`) ve
  bant okutmasında (`HataKartiBulAsync`) dışlandı (`ISNULL(IsMainFaulty,0)=0`).
- Hata barkodu artık `HK` + yeni kod → ör. `HKH004`. **Eski basılmış HK01…HK13 etiketleri artık okunmaz; yeniden basılmalı.**
- **Testler:** bantsayim `MODFEX_DB_TEST=1` 65/65 (yeni: aşama kartı okutulamaz; eski "04" sabitleri H004'e).
