# sentezservis — 2026-11-17

## Üretim raporları (salt okuma): workflow adım 20 ve 14
- **Ne yapıldı:**
  - `src/SentezServis.Core/UretimRapor/UretimRaporDeposu.cs`: iki sorgu.
  - `src/SentezServis.Host/Api/UretimRaporUclari.cs`: `GET /api/uretim-rapor/alan42?ara=` ve `GET /api/uretim-rapor/pastal-verimi?ara=`.
  - Web: `web/src/pages/UretimRaporlariSayfasi.tsx`, `web/src/api/uretimRapor.ts`, rota `/uretim-raporlari`, menü Operasyon > "Üretim raporları".
- **42'de bekleyen:** `UZM_PaketKoli` kapanmış (`KapanisAt` dolu) ve `MamulFisId IS NULL` (sevkiyatmobil mamul girişi henüz yapılmamış). Adet `Erp_BoxItemVariant` toplamından; en uzun bekleyen önce; 24 saati geçen kırmızı.
- **Pastal verimi:** Order × kumaş (ihtiyaç tipi 1).
  - Kullanılan = fiş 129 − fiş 29 (kalemde `WorkOrderId`).
  - Kesilen adet ve pastal metresi (`MarkerLength × NumberOfPlies`) `Erp_WorkOrderProduction` proses 167'den.
  - Verim = pastal metre / kullanılan; adet başı = kullanılan / kesilen.
- **Doğrulama:** `dotnet build` ve `tsc -b` temiz. Sorgular canlıda salt okuma çalıştı: 42 listesi dolu (19.10'dan beri bekleyen koliler var). Pastal verimi şimdilik boş, iş emrine bağlı 129 henüz yok.
- **Commit:** `2623d79`. Sunucuya yama kurulmadı.
