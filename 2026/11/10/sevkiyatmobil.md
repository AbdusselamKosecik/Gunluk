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

## Ek (17:55) — Okutmada yavaşlık incelemesi (kod değişmedi)
- **Neden:** kullanıcı "barkod okutmada yavaşlık var, nedendir izler misin / SQL'de olabilir".
- **SQL (salt okuma DMV):** kilit bekleyen yok. Tarama başına sorgular hızlı: koli bulma ort. 2–8 ms (en çok 14),
  log insert 0–4 ms, Sentez tetikleyicileri `Erp_InventoryReceiptItemInsert` ort. 3 ms. Tek istisna 16:49'da irsaliye
  listesi 10,9 sn `LCK_M_IS` (bir kez).
- **Asıl bulgu:** aynı okutma işleminde kalem `InsertedAt` (işlem başı GETDATE) → `UZM_SevkOkutma.InsertedAt` (işlem sonu)
  0,4–9,8 sn. Sunucu işi ms düzeyinde olduğundan süre gidiş-dönüşlerde. Ping (ev→Tailscale→sunucu→cihaz):
  sunucu 3–11 ms; el terminali 192.168.0.201 min 3, medyan 79, p90 342, en çok 2721 ms, 60'ta 2 kayıp → **Wi-Fi gecikmesi**.
- Bir okutma ≈ 25 sıralı SQL gidiş-dönüşü (`SevkDeposu.OkutAsync`: GETDATE, irsaliye×2, koli×2, applock, içerik,
  `FisYazici.KalemleriYazAsync` kalem/varyant başına 2–3 komut, box update, BoxKalemleri, log, ayrıntı, commit) +
  yenileme ≈ 6 (`SevkSorgulari.AcAsync` her çağrıda `SemaKontrol`). 25 × 80–340 ms = 2–9 sn. Bağlantı ~2–4 dk'da bir yeniden kuruluyor (TLS).
- Operatör yanıt gelmeden tekrar okutuyor: son kayıtlarda çok sayıda Sonuc=2 (KoliZatenOkundu).
- **Öneri:** (1) cihaz Wi-Fi güç tasarrufu kapalı / sinyal-AP kontrolü; (2) kod: okutmayı tek T-SQL toplu komuta indirmek
  (~25 → 1–2 gidiş-dönüş), SemaKontrol'ü oturumda bir kez, listeyi her okutmada baştan çekmemek.
