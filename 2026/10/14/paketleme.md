# paketleme — 2026-10-14

## Bağlam
13.10'daki koli etiketi düzenlemeleri sürüyor (bkz. 2026/10/13/paketleme.md §5–14). Tezgahta 105 adet (iş emri 71533), PK kolisi yok.

## Yapılanlar

### 1. Koli etiketinde paket içi adet + toplam üretim adedi
- **Neden (kullanıcı):** "son koli barkoduna paket içindeki paket kapasitesi ve toplam adet lazım, quantity'nin altına küçük olsa da
  olur: Total Quantity 16, paket içi miktar 2, total production quantity 32; birden fazla olmuyor".
- **Ne yapıldı (`KoliEtiketi.cs`):**
  - `KoliEtiketBilgisi.PaketIciAdet` / `UretimToplami`. `BilgiAsync` kolinin varyant adetlerini okur, `KarmaKoliOkuyucu.TopluAsync` ile
    set tanımı varsa paket içi = bileşen miktarları toplamı, yoksa 1.
  - Saf `PaketHesabi(satırlar)` → (tek paket içi değeri ya da farklıysa null, Σ adet × paket içi).
  - ZPL: TOTAL QTY sayısının altında y=85, 2,4 mm, sağa yaslı: `QTY/PACK 2 · TOTAL PRODUCTION QTY 32`.
- **Testler:** `Toplamin_altinda_paket_ici_ve_uretim_toplami`, `Paket_ici_ve_uretim_toplami` (3 durum),
  `Etiket_bilgisinde_paket_ici_ve_uretim_toplami` (DB: S = A×1 + B×2, 2 set → 3 ve 6). Suite 209/209.
- **Not:** bash'te `cat > /tmp/x;` stdin bekledi, komut zaman aşımına düştü; durduruldu, düzenleme betikle tekrarlandı.

### 2. Mobil depo (sevkiyatmobil) açıldı — mal kabul bekliyor
- Desktop derlendi, açıldı (ayar: 100.119.104.122). `db/0001_sevkiyatmobil.sql` canlıda **çalıştırılmamış**
  (UZM_SevkIrsaliye/UZM_SevkOkutma yok) → `SemaKontrol` her işlemde "VeritabaniHazirDegil". Kullanıcı çalıştıracak (DDL, onay gerekli).
  Kabul bekleyen 1 kapalı koli vardı.

## Açık kalanlar
- `sevkiyatmobil/db/0001_sevkiyatmobil.sql` çalıştırılmalı, sonra mal kabul (fiş 17, 42 → 41).
- Koli etiketi yazıcıda denenmedi.

### 3. Windows yayını
- **Neden (kullanıcı):** "paketlemeye publish çıkartır mısın" (sunum).
- **Ne yapıldı:** `dagitim/yayinla.ps1` (UTF-8 BOM'lu; PS 5.1 BOM'suz betikte Türkçeyi bozuyor): `dotnet publish Paketleme.Desktop -c Release
  -r win-x64 --self-contained true -p:PublishReadyToRun=true -o dagitim/paketleme-win-x64`, sonra `paketleme-win-x64-<tarih>.zip`.
  Çıktılar `.gitignore`'da. Kalıp: onaymerkezi/dagitim/yayinla.ps1.
  ```powershell
  powershell -ExecutionPolicy Bypass -File dagitim/yayinla.ps1
  ```
- **Sonuç:** `dagitim/paketleme-win-x64-2026-10-14.zip` (89 MB). Yayınlanan `Paketleme.Desktop.exe` başlatıldı, pencere "Modfex - Paketleme".
- Uyarı: NU1903 System.Security.Cryptography.Pkcs 9.0.11 (bilinen yüksek önemli açık) — paket güncellemesi ayrıca ele alınmalı.
- Aynı gün: tezgahekrani ve bantdurumekrani Windows'ta açıldı (sunum); tezgahekrani'ye bantdurumekrani ayarlar.json'u kopyalandı.
