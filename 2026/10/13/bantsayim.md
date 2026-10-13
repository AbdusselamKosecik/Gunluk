# bantsayim — 2026-10-13

## Bağlam
Paketlemede 700083526670 barkodu bulunamadı; aynı arama bantta da var.

## Yapılanlar

### 1. 12 haneli UPC-A ↔ başında 0 olan EAN-13 — `2c73a84`
- **Neden:** Sentez barkodu `0700083526670` (EAN-13) saklıyor; okuyucu UPC-A olarak `700083526670` gönderiyor; arama tam eşleşme.
- **Ne yapıldı:** `UretimKurallari.BarkodAdaylari` (12 hane → `[x, "0"+x]`; 0'la başlayan 13 hane → `[x, x[1..]]`). Kullanıldığı yerler:
  `UretimDeposu.VaryantBulAsync` (`Barcode IN @adaylar`, tam eşleşme önce), `IsEmriOnbellegi.Bul`, `BantKabulDeposu.VaryantBulAsync`,
  `UretimSorgulari.BarkodCozAsync`.
- **Testler:** `UretimKurallariTestleri.Barkod_adaylari_upc_ve_ean13` (4 durum). Suite 72/73;
  `IsEmriOnbellegiEntegrasyonTestleri.Onbellekten_okutma_ayni_yazimi_yapar_ve_kesim_asimi_reddedilir` **değişiklikten önce de** düşüyor
  (`KesimAsildi`, canlı veriye bağlı) — ayrıca bakılacak.
- **Dağıtım:** Linux terminal paketi yeniden üretilmedi.
