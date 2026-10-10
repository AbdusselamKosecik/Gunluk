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

### /telegram 500 — SSR ara çizim
- **Durum:** Kullanıcı kurdu (8087), tablolar kurulu, `Sentez / 1` ile giriş OK; tüm sayfalar 200, yalnız /telegram 500.
  Sunucu event log'una erişim yok (Unauthorized).
- **Teşhis:** Yerelde aynı DB ile çalıştırıldı. Self-contained exe ve `dotnet run` SQL'e "TCP Provider: Access is denied"
  aldı (exe'ye özgü ağ kısıtı); `dotnet bin\Debug\net10.0\OnayMerkezi.dll` (sandbox dışı) bağlandı.
  Hata: `InvalidOperationException: EditForm requires either a Model parameter, or an EditContext`. Blazor SSR,
  OnInitializedAsync'teki ilk gerçek await'te ara çizim yapıyor; TelegramAyar'da A/K formları henüz null.
  BellekDepo Task.FromResult ile anında bittiği için testler görmüyordu. TurDuzenle/GorevDuzenle zaten korumalı.
- **Düzeltme:** `TelegramAyar.razor`: `@if (A is null || K is null) { return; }`.
  Test: `BellekDepo.Bekletsin` (Task.Yield) + `Sayfalar_asenkron_depoyla_acilir` (6 sayfa; RED yalnız /telegram → GREEN);
  `SqlOnayDeposuTestleri.TelegramSayfasiOkumalari` (gerçek DB, TransactionScope geri alınır).
- **Doğrulama:** 118 geçti / 5 atlandı; DB testleri 4/4 (MODFEX_ONAY_DB); yerelde gerçek DB ile /telegram 200, form alanları var.
  Paket 10:55 (`onaymerkezi-2026-10-10.zip`). **Commit:** `6cde27d`

### Hata sürüyor → /api/surum
- Kullanıcı "hata oluştu" dedi; sunucuda /telegram hâlâ 500 (olaylar 200). Sunucunun 10:55 paketini çalıştırıp
  çalıştırmadığı dışarıdan görülemiyordu (BotToken hâlâ boş).
- `OnayMerkezi/Api/SurumUcu.cs`: `GET /api/surum` (anonim, no-store) → derleme (InformationalVersion+commit),
  dllTarihi, makineAdi. Test `Surum_girissiz_derleme_bilgisi_verir` RED(404)→GREEN; 119/5.
- Paket 11:03, derleme `1.0.0+a23df99…`. **Commit:** `a23df99`
