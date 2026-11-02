# sentezservis — 2026-11-02

## Bağlam
Kullanıcı: görevlere (zamanlanmış işler) birden fazla zaman eklenebilmeli.

## Yapılanlar

### 1. Bir işe birden fazla zaman
- **Neden:** `CronHesaplayici` `;` ile ayrılmış ifadeleri zaten ayrı ayrı tetikliyordu, ama arayüz tek dar metin kutusuydu
  ve `zamanlamalar.cron` VARCHAR(128) birkaç ifadeden sonra doluyordu.
- **Ne yapıldı:**
  - `web/src/utils/zamanlama.ts`: `cronSatirlari` (`;` → satırlar, boşsa tek boş satır), `cronBirlestir` (boş/tekrar atlanır, `"; "` ile birleşir) + vitest.
  - `ZamanlamaSayfasi.tsx`: her zaman ayrı input, ✕ ile sil, "+ Zaman ekle"; Kaydet birleştirip PUT `/isler/{anahtar}/zamanlama`.
    Salt okunur rolde her zaman ayrı `<code>` satırı. Başlık "Zamanlar (cron)".
  - `CronHesaplayici.Dogrula` (boş / >1000 karakter / "Geçersiz cron ifadesi: <ifade>"); `IsUclari` PUT bunu kullanır. Testler eklendi.
  - Göç `018_cok_zamanli_cron.sql`: `cron` VARCHAR(1000) (idempotent). Mock doğrulaması `;`'lü ifadeleri kabul eder.
- **Komutlar:** `dotnet test tests/SentezServis.Core.Tests` (293 geçti), `npx vitest run` (61 geçti), `npm run build`, `dotnet build src/SentezServis.Host`.
  Mock modda (`VITE_MOCK=1 npx vite --port 5299`) Chrome ile denendi: E-fatura'ya `30 14 * * 1-5` eklendi, kayıt sonrası iki satır duruyor.
- **Commit:** `7786f82` — Zamanlama: bir ise birden fazla zaman (satir satir ekle/sil), cron sutunu 1000 karakter (goc 018)

## Kararlar
- Ayrı tablo (zaman başına satır) yerine mevcut `;` biçimi korundu: zamanlayıcı ve API değişmeden çalışıyor, tüm zamanlar aynı parametrelerle koşar.

## Açık kalanlar / sonraki adım
- Sunucuya yayın yapılmadı (göç 018 açılışta çalışır). `wwwroot/.gitkeep` silinmesi bu işten önceydi, commit'e alınmadı.
