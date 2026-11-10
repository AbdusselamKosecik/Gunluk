# sevkiyatmobil — 2026-11-10

## Yapılanlar

### 1. Yeni PM66 cihazına kurulum
- **Neden (kullanıcı):** "Android'e depo uygulamasını yükler misin … Sevkiyat işlemini yapacağımız uygulama".
- **Ne yapıldı:** Cihaz PM66 seri `1ed69882` (Ekim'deki cihaz `39916cf0` idi); paket daha önce kurulu değildi.
- **Komutlar:**
  ```bash
  ADB="/c/Program Files (x86)/Android/android-sdk/platform-tools/adb.exe"
  "$ADB" -s 1ed69882 install -r dagitim/sevkiyatmobil-2026-10-18d.apk   # Success, lastUpdateTime 2026-11-10 14:57:02
  "$ADB" -s 1ed69882 shell monkey -p com.modfex.sevkiyatmobil -c android.intent.category.LAUNCHER 1
  ```
- **Sonuç:** Açıldı, "Bağlantı Ayarları" ekranı (ilk kurulum). SQL bilgilerini kullanıcı cihazda girecek. Kod değişikliği yok
  (APK `ea79798` düzeltmesini içeriyor).

## Açık kalanlar
- Koli listesinden gelen (Erp_Box.SpecialCode = KLY) kolileri mamul girişte reddetme koruması — yapılmadı.
