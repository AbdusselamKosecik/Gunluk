# paketleme — 2026-10-13

## Bağlam
Kullanıcı: "paketlemede tezgah işlemleri tamam mı? terazi işlemleri falan" + SerialPort Terminal ekran görüntüsü (hex).

## Yapılanlar

### 1. Terazi veri şablonu doğrulandı — `f4e942e`
- **Görüntüden çözülen akış:** `2B 30 30 30 33 2E 38 30 6B 67 0D 0A` = `+0003.80kg` CR LF; değerler 3.80, 3.85, 3.85, 3.75 … 0.00;
  kararlılık işareti yok (sürüm 1 biçimi).
- Mevcut `TartiOkuyucu.Ayristir(…, 1)` deseni (`^\s*([+-])\s*(\d+(?:\.\d+)?)\s*kg\s*$`) baştaki sıfırlı değeri okur; port
  `NewLine="\r"`, satır başındaki LF `Trim` ile atılır. Kod değişikliği gerekmedi.
- **Testler:** `GercekTeraziTestleri` 7 (gerçek satırlar, yarım satır "70kg" atlanır, dalgalanan akış kararsız, 5 eşit okuma → 3.85
  kararlı, boş terazi 0.00 kararlı sayılmaz) — geçti.
- **Doğrulanmadı:** baud (kod 9600 8N1 varsayar; görüntüde baud yok), gerçek port ile uçtan uca.

## Durum
- Tezgah/mamul/sevk tabloları canlıda hâlâ **yok** (`db/0002_tezgah.sql`, `sevkiyatmobil/db/0001_sevkiyatmobil.sql` çalıştırılmadı).
