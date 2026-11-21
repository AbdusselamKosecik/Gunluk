# sevkiyatmobil — 2026-11-21

## Yapılanlar

### 1. PM66'ya yeniden kurulum
- **Neden:** Kullanıcı terminali "mal kabul ve depo" olarak güncellemek istedi; "depo" = sevkiyat mobil.
- **Ne yapıldı:** `833296d` (main, origin ile aynı) release APK olarak derlendi ve `adb -s 1ed69882 install -r` ile kuruldu; uygulama açıldı.
  ```bash
  dotnet publish SevkiyatMobil.Android -c Release -o <dir>
  ```
- **Not:** Terminaldeki önceki kurulum da 15.11'deki aynı commit'ten yapılmıştı; kod değişikliği yok.
