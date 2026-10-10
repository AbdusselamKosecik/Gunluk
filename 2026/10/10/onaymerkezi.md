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
