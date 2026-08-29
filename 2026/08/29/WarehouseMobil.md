# WarehouseMobil — 2026-08-29

## Bağlam

Depo el terminali uygulaması için tasarım turu bitti: `tema/Depo Terminali v3.dc.html` (rugged
amber, 1c yönü) onaylandı. Repoda sadece README + .gitignore vardı, kod yoktu. İstek: projeyi
"Android 6.1"e göre kurmak. Android 6.1 diye bir sürüm yok — 6.0 ve 6.0.1 ikisi de **API 23**;
minSdk 23 ile ilerlendi (Zebra TC/MC el terminalleri bu seviyede).

## Yapılanlar

### 1. Gradle projesi kuruldu (API 23 hedefli)
- **Neden:** Kod iskeleti yoktu; hedef donanım eski Android 6 el terminali.
- **Ne yapıldı:** Gradle 8.12 (wrapper başka bir projeden kopyalandı), AGP 8.7.3, Kotlin 2.0.21,
  version catalog (`gradle/libs.versions.toml`). `minSdk 23`, `targetSdk/compileSdk 34`,
  Java 17, `isCoreLibraryDesugaringEnabled = true` (java.time için), ViewBinding.
  `resourceConfigurations += ["tr","en"]` ile APK küçültüldü.
- **Dokunulan dosyalar:** `settings.gradle.kts`, `build.gradle.kts`, `app/build.gradle.kts`,
  `gradle/libs.versions.toml`, `gradle.properties`, `local.properties` (gitignore'da)
- **Sonuç:** `:app:assembleDebug` BUILD SUCCESSFUL, `:app:lintDebug` temiz (NewApi hatası yok).

### 2. Compose değil klasik View kararı
- **Neden:** Günde 3000 okutma hedefi + 1–2 GB RAM'li, zayıf GPU'lu API 23 terminaller.
  Compose bu cihazlarda ilk çizim ve bellek açısından pahalı.
- **Ne yapıldı:** ViewBinding + RecyclerView. `setHasFixedSize`, `itemViewCacheSize=20`,
  `recycledViewPool` 24 — bind maliyetini düşürmek için.

### 3. Toplama motoru (UI'dan ayrı)
- **Neden:** Renk/akış kuralları test edilebilir olsun, UI thread'de karar hesabı olmasın.
- **Ne yapıldı:** `data/PickEngine.kt` — sıradaki satırda önce raf barkodu beklenir (rozet
  kırmızı), doğru okutulunca aynı raftaki tüm bekleyen satırlar `shelfOk` olur (raf tekrar
  sorulmaz); sonra ürün barkodu. Yanlış barkod satırı ilerletmez. Sipariş bitince
  `markExploding` → animasyon → `removeOrder`.
- **Dokunulan dosyalar:** `data/PickEngine.kt`, `data/Models.kt`, `data/DemoData.kt`,
  `ui/PickActivity.kt`, `ui/PickAdapter.kt`

### 4. Barkod okuma köprüsü
- **Neden:** Zebra terminallerde DataWedge standart yol, ama her müşteri profili aynı
  kurmuyor; klavye-wedge yedeği şart.
- **Ne yapıldı:** `scan/ScannerBridge.kt` — açılışta DataWedge'e `SET_CONFIG` broadcast'i ile
  `CREATE_IF_NOT_EXIST` profili gönderir (intent output açık, keystroke kapalı), action
  ayarlardan değişebilir (varsayılan `com.modasima.warehousemobil.SCAN`). Ayrıca
  `dispatchKeyEvent` ile tuş vuruşu barkodlarını ENTER/TAB'a kadar biriktirir.
  `registerReceiver` API 33+ için `RECEIVER_EXPORTED` ile ayrıldı.
- **Geri bildirim:** `scan/Feedback.kt` — ToneGenerator bip + Vibrator; API 26 altı için
  `vibrate(pattern, -1)` yolu korundu.

### 5. Ekranlar
- Giriş: operatör listesi + 4 haneli PIN (keypad kodla üretiliyor).
- Toplama listesi: sipariş renk şeritleri, lejant, ilerleme çubuğu, MANUEL + RAF/ÜRÜN OKUT
  butonu (raf adımında kırmızı, ürün adımında amber).
- Ayarlar: sunucu adresi, depo kodu, DataWedge action, ses/titreşim, cihaz bilgisi.

### Komutlar
```bash
./gradlew :app:assembleDebug   # app/build/outputs/apk/debug/app-debug.apk
./gradlew :app:lintDebug
```

- **Commit:** `19fafa3` — Android 6 (API 23) hedefli proje iskeleti + toplama akisi
  (push edildi: `git@gitlab.com:modasima/warehousemobil.git` main)

## Kararlar

- minSdk 23 / targetSdk 34. "Android 6.1" isteği API 23 olarak yorumlandı.
- Compose kullanılmayacak (eski terminal performansı).
- "Hep online" çalışacağı için offline kuyruk/senkron katmanı yazılmadı; OkHttp timeout'ları
  kısa tutuldu (connect 5s, read/write 10s).
- Ürün görselleri için Coil bağlandı; `imageUrl` sunucudan gelene kadar gri placeholder.
- Şifreli SharedPreferences kullanılmadı (API 23'te gereksiz yük; saklanan veri hassas değil).

## Açık kalanlar / sonraki adım

- Sunucu bağlantısı: `ApiFactory` + `WarehouseApi` hazır, `PickActivity` hâlâ `DemoData` ile
  çalışıyor. Gerçek endpoint sözleşmesi netleşince bağlanacak.
- Mal kabul, sayım, sevkiyat kontrol akışları.
- Geçmiş / rapor ekranı, yönetici paneli.
- `PickEngine` için birim testler (test kaynak seti henüz eklenmedi).
- Gerçek cihazda (Zebra, Android 6) DataWedge profil oluşturma testi yapılmadı.
