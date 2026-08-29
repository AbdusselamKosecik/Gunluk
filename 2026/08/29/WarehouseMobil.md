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

---

## Tur 2 — Emülatör doğrulaması + beş akış + MSSQL

### 6. Emülatörde çalıştırma (API 23)
- **Neden:** İskeletin gerçekten Android 6'da ayağa kalktığını görmek.
- **Ne yapıldı:** Mevcut `Terminal_API23` AVD'si başlatıldı, APK kuruldu, akış adb `input tap`
  ile sürüldü ve her adımda `screencap` alındı.
- **Komutlar:**
  ```bash
  emulator -avd Terminal_API23 -no-snapshot-load -no-boot-anim
  adb install -r app/build/outputs/apk/debug/app-debug.apk
  adb shell am start -n com.modasima.warehousemobil.debug/...ui.LoginActivity
  adb shell input tap X Y ; adb shell screencap -p /sdcard/s.png ; adb pull ...
  ```
- **Sonuç:** Android 6.0 / API 23'te sorunsuz. Renk kuralları birebir tasarımdaki gibi.
- **Dikkat:** Emülatörde `com.modasima.elterminali` adlı BAŞKA bir uygulama daha kurulu ve
  öne gelebiliyor; ekran görüntüsü alırken `dumpsys activity | mFocusedActivity` ile hangi
  uygulamanın önde olduğu doğrulanmalı. Bir kez yanlış uygulamanın ekranı ölçüldü.

### 7. Emülatörde çıkan iki gerçek hata
- **MaterialButton renk değiştirmiyordu:** Tema `Theme.MaterialComponents` olduğu için
  `<Button>` MaterialButton olarak inflate oluyor ve `setBackgroundColor` yok sayılıyor
  (backgroundTint kullanıyor). RAF OKUT butonu kırmızı olması gerekirken amber kalıyordu.
  → `androidx.appcompat.widget.AppCompatButton`'a çevrildi. Bu ayrıca inset kaynaklı
  hizasızlığı da çözdü.
- **PIN noktaları bitişik/yanlış çiziliyordu:** `ViewGroup.MarginLayoutParams` LinearLayout
  içinde margin uygulamıyor → `LinearLayout.LayoutParams` + `GradientDrawable` ile düzeltildi.

### 8. Beş akış ekranı
- **Neden:** İstek: toplama, mal kabul, sayım, transfer, stok sorgu.
- **Ne yapıldı:** `MenuActivity` (5 kutulu ana menü) + ortak `ScanActivity` tabanı
  (tarayıcı bağlama, manuel giriş, miktar sorma, ses/titreşim). Akışlar tek bir
  `activity_flow.xml` üzerinde: başlık, adım afişi (hangi barkod bekleniyor), bilgi paneli,
  liste, alt buton çubuğu.
- **Dokunulan dosyalar:** `ui/MenuActivity.kt`, `ui/ScanActivity.kt`, `ui/ReceiveActivity.kt`,
  `ui/CountActivity.kt`, `ui/TransferActivity.kt`, `ui/StockQueryActivity.kt`,
  `ui/SimpleAdapter.kt`, `res/layout/activity_menu.xml`, `activity_flow.xml`, `item_simple.xml`
- **Sonuç:** Beşi de emülatörde uçtan uca test edildi (mal kabul: ürün→miktar→raf kaydı;
  sayım: raf→beklenen liste→sayım farkı; transfer: kaynak→ürün→miktar→hedef; stok sorgu:
  toplam + raf kırılımı).

### 9. MSSQL — doğrudan stored procedure
- **Neden:** Kullanıcı kararı: "mssql den çalışacağız direkt sp'ler".
- **Ne yapıldı:** `data/db/Db.kt` (jTDS 1.3.1 ile bağlantı; Microsoft mssql-jdbc Android'de
  çalışmıyor) + `data/db/SpRepo.kt` (tüm SP çağrıları ve dönüş modelleri).
  Her çağrı kendi bağlantısını açıp kapatıyor (el terminali Wi-Fi'sinde uzun ömürlü socket
  güvenilmez), `Dispatchers.IO` üzerinde.
- **SP adları** tek yerde: `SpRepo.kt → object Sp`. Kolonlar **isimle** okunuyor, sıra önemsiz.
- **Doldurulacak iskeletler:** `docs/mssql-sp-sozlesmesi.sql` — 9 SP:
  Login, PickList, PickScan, ReceiptItem, ReceiptPost, CountShelf, CountPost,
  TransferPost, StockQuery (bu sonuncusu 2 sonuç kümesi döner).
- **Demo modu** (`Prefs.demoMode`, varsayılan açık): SQL olmadan tüm ekranlar örnek veriyle
  çalışır. Ayarlarda kapatılıp SQL bilgileri girilir, "BAĞLANTIYI TEST ET" ile doğrulanır.

- **Commit:** `bbff649` — Bes akis ekrani + MSSQL SP katmani, demo modu ile calisir durumda

## Kararlar (tur 2)

- MaterialComponents teması kalsın ama butonlar AppCompatButton olsun — renk kodla
  değiştirilebilsin diye.
- jTDS seçildi; mssql-jdbc Android'de javax.naming vb. yüzünden çalışmıyor.
  Riski: TLS zorunlu kılınmış yeni SQL Server'larda jTDS takılabilir — sahada test edilmeli.
- Cihaz doğrudan DB'ye bağlandığı için SQL login'i sadece SP EXECUTE yetkili olmalı.
  README ve SP dosyasına not düşüldü.
- Sayımda BİTİR artık özet + onay diyaloğu gösteriyor (yanlışlıkla basıp listeyi silmeyi
  önlemek için).

## Açık kalanlar (tur 2)

- SP gövdeleri müşteri şemasına göre doldurulacak (kullanıcı dolduracak).
- Geçmiş / rapor ekranı, yönetici paneli.
- `PickEngine` birim testleri.
- Gerçek Zebra cihazda DataWedge profil testi + jTDS'in gerçek SQL Server'a bağlanma testi.

---

## Tur 3 — Tasarımı eski uygulamayla eşitleme

### 10. Referans uygulamanın kurtarılması
- **Neden:** İstek: "daha önce yazdığın uygulama var, tasarımları onunla aynı yap".
  Kaynak kod HDD ile silinmiş, diskte yok.
- **Ne yapıldı:** Uygulama emülatörde kurulu olduğu fark edildi
  (`com.modasima.elterminali.debug`). APK emülatörden çekildi ve açıldı.
  ```bash
  adb shell pm path com.modasima.elterminali.debug
  adb pull /data/app/com.modasima.elterminali.debug-2/base.apk
  unzip base.apk
  aapt2 dump resources base.apk
  ```
- **Bulgular:** Compose ile yazılmış (12 dex, kendi layout'u yok, renkler kod içinde).
  `res/font` altında 7 TTF: Barlow Condensed Bold/SemiBold, Barlow Regular/Medium/SemiBold,
  IBM Plex Mono Medium/SemiBold. **Fontlar bu APK'dan alındı** — tek kalan nüsha buydu.
- **Ekranları** adb ile sürülüp tek tek screencap alındı: giriş, ana menü (2 sütun modül
  kartı), toplama listesi, mal kabul (irsaliye + TAM/EKSİK/FAZLA), sayım (sistem/sayılan/fark
  tablosu), transfer (kaynak→hedef kartları), stok sorgu.
- **Renkler** ekran görüntülerinden piksel örneklemesiyle çıkarıldı (PowerShell + System.Drawing):
  bg `#1B1712`, kart `#211D18`, çerçeve `#2A2620`, metin `#F2EDE4`, muted `#9C9384`,
  amber `#F2B341`, yeşil `#3FD18B`, mor `#C792D6`, mavi `#6BAEDB`, kırmızı `#E5484D`.

### 11. Tasarımın uygulanması
- **Tipografi:** `values/themes.xml` içinde Text.Display / Title / Item / Body / Mono / Label /
  Number stilleri. Başlıklar Barlow Condensed Bold, kod-sayı-etiket IBM Plex Mono.
  AppCompat `android:fontFamily="@font/..."` API 23'te sorunsuz çalıştı.
- **Giriş:** durum noktası + `DEMO · MERKEZ DEPO · v0.1.0`, amber çerçeveli operatör seçimi,
  çerçeveli PIN kutuları; PIN dolunca ipucu "GİR TUŞUNA BASIN" ve GİR tuşu amber'e dönüyor.
- **Ana menü:** iki sütunlu modül kartları — üst vurgu şeridi (modül rengi), ikon, sayaç,
  ad, alt açıklama. Seçili kart amber çerçeve. Alt: SUNUCU / SON SENK. / BUGÜN şeridi +
  ÇIKIŞ / "AÇ ▸ MODÜL" butonu. İlk dokunuş seçer, ikinci açar (yanlış modül açmayı zorlaştırır).
- **Ortak gövde:** `ui/FlowChrome.kt` + `view_flow_header.xml` + `view_scan_bar.xml`.
  Beş ekran da aynı üst bar (geri kutusu, modül renginde başlık, sağda sayaç) ve aynı alt
  bar (ikincil aksiyon + barkod ikonlu ana buton) kullanıyor.
- **Adım kartı** (`activity_flow.xml`): sol vurgu şeridi, üstte küçük etiket, altta büyük mono
  değer, sağda sayı. Mal kabul/sayım/transfer/stok sorgu bunu kullanıyor.
- **Toplama listesi:** ürün resmi kaldırıldı (referansta yok), satır yoğunluğu referansa
  getirildi, lejant çipleri kutulu.
- **Vektör ikonlar** elle yazıldı: barkod, geri, backspace, toplama, mal kabul, sayım, transfer.

### 12. Emülatörde çıkan düzeltmeler
- Tuş rakamları soluk kalıyordu → açık renk atandı.
- Giriş alt başlığı iki satıra taşıyordu → kısaltıldı, tek satır.
- Kart alt yazıları sarıyordu → `maxLines=1` + harf aralığı düşürüldü.
- Mor/mavi butonlarda beyaz yazı okunmuyordu → açık zeminlerde koyu yazı
  (`FlowChrome.primary`: sadece kırmızı üzerinde açık yazı).

- **Commit:** `54cc24e` — Tasarim: referans el terminali uygulamasiyla ayni gorsel dil

## Kararlar (tur 3)

- Referans uygulama Compose, bizimki View kalmaya devam ediyor (API 23 performans kararı
  değişmedi); eşitlenen şey görsel dil, teknoloji değil.
- Fontlar APK'dan alındı. Barlow ve IBM Plex Mono ikisi de OFL lisanslı, dağıtımı serbest.
- Modül renkleri: toplama amber, mal kabul yeşil, sayım mor, transfer/stok sorgu mavi —
  referanstaki eşleme birebir korundu.

## Açık kalanlar (tur 3)

- Referans mal kabul ekranı **irsaliye bazlı** (İRS no, tarih, kalem, TAM/EKSİK/FAZLA
  durumları); bizimki hâlâ tek tek ürün→raf. Aynı modele geçmek `sp_WM_Receipt*`
  sözleşmesini de genişletmeyi gerektirir.
- Referans sayım ekranında satır seçip −/+ ile miktar düzeltme var; bizde her okutma +1.
- Referans transferde bekleyen hareket kuyruğu var; bizde anlık kayıt.

---

## Tur 4 — Kalan üç model farkının kapatılması

Tur 3'te "birebir olmayan üç yer" olarak bırakılan farklar kapatıldı.

### 13. Mal kabul → irsaliye bazlı
- **Neden:** Referans uygulamada mal kabul tek tek ürün→raf değil, bir irsaliyenin
  karşılanması. Sahada gelen mal irsaliyeyle geliyor; eksik/fazla tespiti orada oluyor.
- **Ne yapıldı:** Bekleyen irsaliyeler `sp_WM_ReceiptOpen` ile gelir (tek ise otomatik açılır,
  çoksa seçim listesi). Satırlar `sp_WM_ReceiptLines`. Her okutma satırın "okutulan"ını
  1 artırır; durum uygulamada hesaplanır:
  `0 → BEKLİYOR`, `= beklenen → TAM`, `< → EKSİK`, `> → FAZLA`.
  Üstte künye (İRSALİYE / TARİH / KALEM), ilerleme çubuğu ve durum sayaçları.
  Satıra dokununca miktar elle düzeltilir (`sp_WM_ReceiptScan` mutlak değer yazar).
  Tüm satırlar okutulunca ana buton "İRSALİYEYİ KAPAT"a döner; raf okutulup
  `sp_WM_ReceiptClose` çağrılır — böylece orijinal "mal kabul → raf ata" isteği de korunmuş oldu.
- **Dokunulan dosyalar:** `ui/ReceiveActivity.kt`, `ui/ReceiptAdapter.kt`,
  `res/layout/activity_receive.xml`, `item_receipt_line.xml`, `data/db/SpRepo.kt`
- **SP değişikliği:** `ReceiptItem` / `ReceiptPost` kaldırıldı; yerine
  `ReceiptOpen` / `ReceiptLines` / `ReceiptScan` / `ReceiptClose`.

### 14. Sayımda satır seçip miktar düzeltme
- **Neden:** Paketli üründe 28 adet için 28 kez okutmak saçma; referansta −/+ var.
- **Ne yapıldı:** Liste artık tablo: `ÜRÜN | SİSTEM | SAYILAN | FARK`. Satıra dokununca
  seçilir (amber çerçeve), altta "SEÇİLİ SATIR" paneli açılır: `− <miktar> +`.
  Miktarın üstüne dokununca klavyeden girilir. Okutma da satırı seçili yapıyor,
  böylece okut→düzelt akışı kesintisiz.
  Sistemde olmayan ürün okutulursa `SİSTEMDE YOK` rozetiyle 0 beklenenle ekleniyor.
- **Dokunulan dosyalar:** `ui/CountActivity.kt`, `ui/CountAdapter.kt`,
  `res/layout/activity_count.xml`, `item_count_row.xml`

### 15. Transferde kuyruk
- **Neden:** Her hareket için SQL'e gidip beklemek koridorda yavaş; referansta kuyruk var.
- **Ne yapıldı:** Kaynak raf → ürün (+miktar) → hedef raf okutulunca hareket **kuyruğa**
  giriyor ve akış aynı kaynak rafla ürün adımından devam ediyor (seri çıkış için).
  İkincil buton `GÖNDER (n)` olup kuyruğu tek seferde iletiyor; başarısız hareket
  kuyrukta kalıp tekrar denenebiliyor.
- **Dokunulan dosyalar:** `ui/TransferActivity.kt`, `res/layout/activity_transfer.xml`

### Teknik not — ViewBinding + `<merge>`
`view_qty_pad.xml`'i `<include>` ile eklemek işe yaramadı: ViewBinding, kökü `<merge>` olan
include edilen layout'un id'leri için alan üretmiyor. Panel doğrudan `activity_count.xml`
içine gömüldü. (`view_flow_header` / `view_scan_bar` sorun çıkarmıyor çünkü onlara
`FlowChrome` findViewById ile erişiyor.)

- **Commit:** `ec00023` — Mal kabul irsaliye bazli, sayimda miktar duzeltme, transferde kuyruk

## Kararlar (tur 4)

- `sp_WM_ReceiptScan` ve `sp_WM_CountPost` **mutlak miktar** alır (topla değil, üzerine yaz).
  Elle düzeltme bu şekilde tek çağrıyla ifade ediliyor.
- İrsaliye kapanışında eksik/fazla varsa reddetme kararı SP'ye bırakıldı (`Ok = 0` + `Mesaj`).
- Transfer kuyruğu bellekte; uygulama kapanırsa kaybolur. "Hep online" kararı gereği
  kalıcı kuyruk yazılmadı — gönderim anlık.

## Açık kalanlar (tur 4)

- SP gövdeleri hâlâ boş, kullanıcı dolduracak (11 SP).
- Geçmiş / rapor ekranı, yönetici paneli.
- `PickEngine` birim testleri.
- Gerçek Zebra cihazda DataWedge + jTDS testi.

---

## Tur 5 — Sürüm numarası

### 16. Sürüm ekranda
- **Neden:** Sahada hangi APK'nın yüklü olduğunu telefona bakmadan görebilmek gerekiyor.
- **Ne yapıldı:** `BuildConfig.VERSION_NAME` üç yerde:
  - **Giriş**: alt başlıkta zaten vardı — `DEMO · MERKEZ DEPO · v0.1.0`
  - **Ana menü**: üst bardaki operatör satırı — `AHMET K. · MERKEZ · v0.1.0`
  - **Ayarlar**: cihaz bilgisi bloğunun ilk satırı — `Sürüm: v0.1.0 (build 1)`
- **Not:** `buildConfig = true` gerekti (AGP 8'de BuildConfig üretimi varsayılan kapalı).
- **Denenip vazgeçilen:** Sürümü alt durum şeridine "SUNUCU · v0.1.0" olarak koymak —
  sütun dar, iki satıra sarıyordu. Operatör satırı 11sp + letterSpacing 0 ile tek satırda
  rahat sığdı.

### 17. Ayarlar ekranında Türkçe karakter düzeltmesi
- **Neden:** Etiketler layout içine düz metin yazılmıştı ve Türkçesiz kalmıştı:
  "VERITABANI", "SIFRE", "Sesli uyari", "Titresim", "Demo modu (SQL'siz calis)".
- **Ne yapıldı:** Hepsi `strings.xml`'e taşındı ve düzgün yazıldı.
- **Dokunulan dosyalar:** `res/layout/activity_settings.xml`, `res/values/strings.xml`

- **Commit:** `a942668` — Surum numarasi ekrana eklendi + ayarlarda Turkce karakter duzeltmesi
