# onaymerkezi — 2026-10-10

## Bağlam
Plan tamamlanmış (6391fc3); kullanıcı sisteme kurmak için paket istedi.

## Yapılanlar

### Kurulum paketi
- **Neden:** Kullanıcı: "Telegram'ı da paketler misin, kuralım sisteme".
- **Ne yapıldı:** `dagitim/yayinla.ps1` self-contained (`--self-contained true`; SentezServis de öyle, sunucuda .NET 10
  olduğu bilinmiyor) + pakete `servis-kur.ps1`, `db/0001_onaymerkezi.sql`, `appsettings.Local.ornek.json`, `KURULUM.txt`
  kopyalanır. `servis-kur.ps1` `-Klasor` varsayılanı betiğin klasörü. `.gitignore` `*.zip`. dagitim/ gitignore'da →
  `git add -f`. ps1 dosyaları UTF-8 BOM'lu kaldı (PS 5.1).
- **Doğrulama:** 112 geçti / 4 atlandı. Pakette appsettings.Local.json yok, token/anahtar deseni yok.
  Paket: `onaymerkezi/yayin/` + `onaymerkezi/onaymerkezi-2026-10-10.zip` (~56 MB).
- **Durum:** SentezCore'da UZM_Onay*/UZM_Olay* tabloları henüz yok → kurulum adım 1 (db betiği) gerekli.
- **Commit:** `a361d82`

## Açık kalanlar
- DB betiği, sunucuya kurulum, token panelden, gruplarda /kayit, görev/tür tanımları, kesimhane entegrasyonu.

### Port çakışması → 8087
- **Belirti:** Kullanıcı kurdu, http://MODFEXSRV:8086 "Modfex / Türkçe / Servis Planlama" girişi açtı.
- **Neden:** ServisPlanlama (`ServisPlanlama/src/ServisPlanlama/appsettings.json` Url 0.0.0.0:8086) aynı sunucuda 8086'da.
  Yoklama: 8087 cevapsız (boş), 8088 302 (dolu), 8089 cevapsız.
- **Ne yapıldı:** `OnayMerkezi/appsettings.json` Urls, `dagitim/servis-kur.ps1` güvenlik duvarı kuralı, `KURULUM.txt`,
  README → 8087. Paket yeniden (`onaymerkezi-2026-10-10.zip`), testler 112/4.
- **Commit:** bkz. git log (Port 8086 -> 8087).
- **Kullanıcıya:** yeni zip'i üzerine kopyala + servis-kur.ps1 (servisi silip yeniden kurar, 8087 kuralı ekler);
  eski 8086 güvenlik duvarı kuralı "Modfex Onay Merkezi 8086" silinebilir.
