# mobileverimlilik — 2026-11-20

## Bağlam
Kullanıcı: "Çalışırken hata veriyor, loginden sonra kayıtlar gelmiyor, örnek sicil 3608."

## Yapılanlar

### 1. Teşhis — sorun 3608'e değil tüm sahaya ait
- **Önemli:** Tabletlerin API'si `http://192.168.10.58:81` (VPN; DB sunucusu `SURMEVERIMLILIK`, `TechtsioMerkez`).
  `172.16.1.2:81` / `DIKIMANALIZSRV` başka bir kurulum (KK cihazları, CreatedType=5) — mobil uygulamanın FKK
  kayıtları orada YOK, yanlış yere bakıp vakit kaybetme.
- RunSql üzerinden kontrol (sorgu doğrudan API'ye POST):
  ```bash
  curl -X POST -H "Content-Type: application/json" \
    -d '{"sql":"select ...","parameters":[]}' http://192.168.10.58:81/api/BulkInstall/RunSql
  ```
  - `UZM_BarcodeControl` her gün 08:00'de başlıyor; 20.11'de saat 11:45'te **0 satır**, `Transections` bugün 0.
  - 3608: toplam 41.326 kayıt, son kayıt 19.11 16:53 → kişiye özel bir sorun yok.
  - Uygulamanın tüm okuma sorguları ve okutma sorguları (standart zaman, mükerrer, barkod→sipariş) 200 döndü;
    linked server INSERT yolu (`TOP 0`) ve InsertTransection uç noktası da cevap veriyor → sunucu sağlam.
    Not: RunSql içinde linked server ile `BEGIN TRAN` → 500 (MSDTC); test için kullanma.
- **Tablette yeniden üretme** (geliştirici tableti SM-X110, FortiClient VPN açık):
  ```bash
  JAVA_HOME="C:\Program Files\Android\openjdk\jdk-21.0.8" C:/flutter/bin/flutter.bat build apk --debug
  adb install -r build/app/outputs/flutter-apk/app-debug.apk
  # ayarlar: shared_prefs/FlutterSharedPreferences.xml (flutter.app.server=192.168.10.58:81, ...)
  adb push fp.xml /data/local/tmp/ && adb shell "run-as com.example.mobileverimlilik cp /data/local/tmp/fp.xml shared_prefs/FlutterSharedPreferences.xml"
  adb shell input text 3608 && adb shell input keyevent 66
  ```
  Ekran: operasyon kutusunda kırmızı hata `type 'Null' is not a subtype of type 'String'`.
- **Kök neden:** `Operations` içinde `5304-7` (Id 86ab3222-…, InsertedAt 19.11 09:11) `Name = NULL`; ERP'de de
  `Erp_Process` RecId 5023 `ProcessName = NULL`, `SpecialCode='a'` → uygulamanın operasyon listesine giriyor.
  `_OperationDropdown` → `Text(entry.value["Name"])` çöküyor → operasyon seçilemiyor → okutma yok → kayıt yok.

### 2. Düzeltme
- **Ne yapıldı:** `operationLabel(Map)` fonksiyonu: Name boş/NULL ise Code gösterilir; dropdown bunu kullanıyor.
- **Dokunulan dosyalar:** `lib/features/production/screen/production_screen.dart`, `test/operasyon_etiketi_test.dart` (yeni)
- **Doğrulama:** Yeni test önce derlenmedi (kırmızı), düzeltmeden sonra 4/4 yeşil. `widget_test.dart` (şablon sayaç
  testi) değişiklikten önce de kırmızıydı, ilgisiz. Tablette tekrar giriş → operasyon listesi açıldı, hata yok.
  Test uygulaması tabletten kaldırıldı.
- **Commit:** `055a59b` — Adi bos operasyon listeyi cokertiyordu: kodu goster

## Kararlar
- Üretim verisine (Operations/Erp_Process adı) dokunulmadı; ad ERP'de girilmeli — kullanıcıya bırakıldı.
- Debug'da görülen "RIGHT OVERFLOWED" (uzun operasyon adı) ayrı konu, dokunulmadı.

## Açık kalanlar / sonraki adım
- **Sahadaki FKK tabletlerine yeni APK kurulmalı**; o zamana kadar acil çözüm: ERP'de 5304-7'ye ad girmek
  (sonra Operations.Name dolmalı) — uygulama her girişte listeyi yeniden çektiği için anında düzelir.

---

## Tur 2 (12:08) — Saha APK'sı
- **Ne yapıldı:** `pubspec.yaml` sürüm `1.1.1+3` → `1.1.2+4` (tabletler güncelleme olarak alsın), release derleme.
- **Komut:**
  ```bash
  JAVA_HOME="C:\Program Files\Android\openjdk\jdk-21.0.8" C:/flutter/bin/flutter.bat build apk --release
  ```
- **Çıktı:** `X:\Gitlab\fredericTr\mobileverimlilik-1.1.2-2026-11-20-2f4d09c.apk` (56.3 MB, SHA256 `8f419cb9892ed4d8…`).
  Release, bu makinenin debug anahtarıyla imzalı (build.gradle.kts'de release signingConfig = debug) — önceki
  sürümler de böyle; başka makinede derlenirse imza tutmaz, eskiyi kaldırıp kurmak gerekir.
- **Commit:** `2f4d09c` — Surum 1.1.2+4

---

## Tur 3 (16:03) — "Barkod okutunca bazen silinmeden kalıyor; bekliyorsa bekliyor işareti"

### Kök neden (`production_screen.dart`, eski onBarcode)
1. `await controller.onBarcode(...)` → `_barcodeController.clear()`: alan ancak tüm zincir bitince temizleniyordu.
   Zincir sıralı 5–6 HTTP isteği (_checkBarcode, standart zaman, _getBarcodeData ×2, checkNew→_sendRowToServer,
   _saveBarcodeToControl); `DioClient` connect/receive timeout 10 sn → VPN'de saniyelerce/dakika bekleme, işaret yok.
2. `_checkBarcode` ve `_getBarcodeData` try/catch dışında → ağ hatasında exception, `clear()` hiç çalışmıyor → barkod
   alanda kalıyor ("bazen").
3. Yeniden giriş koruması yok → bekleme sırasında okutulan barkod öncekinin sonuna ekleniyor / paralel işlem.

### Düzeltme
- `lib/features/production/screen/barcode_gate.dart` (yeni): `BarcodeGate.run()` — aynı anda tek işlem,
  `busy` ValueNotifier, try/catch/finally; sonuç `done | rejectedBusy | failed`.
- `production_screen.dart`: `_handleBarcode` alanı Enter'da HEMEN temizliyor; meşgulken gelen okutma işlenmiyor,
  turuncu "Önceki barkod işleniyor… TEKRAR okutun: <barkod>" snackbar; hata → kırmızı "Barkod işlenemedi… tekrar okutun".
  `_BarcodeInput` busy iken turuncu çerçeve + dönen simge + "ISLENIYOR, BEKLEYIN...".
- **Karar:** Meşgulken gelen okutma kuyruğa alınmadı, reddedilip tekrar okutma istendi. Kuyruktaki barkod eski
  operasyon/sipariş bağlamıyla işlenip yanlış sayılabilirdi; reddetme + görünür uyarı daha güvenli.
- Test: `test/barkod_kuyrugu_test.dart` (3 test) önce kırmızı, sonra yeşil. Tüm testler yeşil (şablon `widget_test.dart` hariç, önceden de kırmızı).
- **Cihazda görsel doğrulama YAPILAMADI:** SM-X110 ekran kilidinde kaldı. Test uygulaması kaldırıldı,
  `svc power stayon false` ile geri alındı. Bu sırada bağlı olan PM66 el terminaline (1ed69882) dokunulmadı.
- **Commit:** `98c52fa`; sürüm 1.1.3+5.
- **APK:** `X:\Gitlab\fredericTr\mobileverimlilik-1.1.3-2026-11-20-98c52fa.apk` (SHA256 `a6363fdd28a8be50…`) —
  1.1.2'yi de içerir, sahaya bunu kurmak yeterli.

### Açık kalanlar
- Sahada ilk kurulumda gözle kontrol: okut → turuncu "işleniyor" görünüp kayboluyor mu.
- Okutma süresinin kendisi uzun (sıralı 5–6 istek). Kısaltmak için istekler birleştirilebilir (tek SP) — ayrı iş.
