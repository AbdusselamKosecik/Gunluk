# depo — 2026-11-22

## Yapılanlar

### 1. Kumaşsız onaylı pastal (`d51f354`)
- **Neden:** Kesimhane kumaşsız pastal yükleyebiliyor (`KumasInventoryId = 0`). Depo, kumaşı yalnız o kumaşa bağlı onaylı pastal varsa veriyordu.
- **Ne yapıldı:** `PastalKontrol.KumasMetresi(metreler, kumas)` eklendi: kumaşa bağlı pastal öncelikli, yoksa kumaşsız (0) pastal. `OnayliAsync` ve `HammaddeDetayViewModel` bunu kullanıyor.
- **Testler:** `Kumassiz_onayli_pastal_her_kumas_icin_gecerlidir` ve `Kumassiz_onayli_pastalla_kumas_verilir` (DB).
- **Sonuç:** 29/30. Kırmızı test `Tutanak_kaydi_ve_pdf_dosyasi_olusur`, değişiklikten önce de kırmızıydı (git stash ile doğrulandı).
  - Canlı veri değişmiş: beklenen `tutanak/4315/T4-Teslim.pdf`, gelen `tutanak/4315-2-iptal/T5-Teslim.pdf`.

## Açık kalanlar
- `Tutanak_kaydi` testi canlı veriden bağımsız hale getirilmeli.
