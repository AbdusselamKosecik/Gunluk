# mobileverimlilik — 2026-09-10

## Bağlam

Sahadan iki şikâyet geldi:
1. "Tamir işlemlerinde arka taraf sarı yanıyor mu?" — tamir modunun görsel geri bildirimi.
2. "Gün başında bazı cihazlar sıfırlanmıyor." — ertesi gün sayaçlar dünkü rakamlarla açılıyor.

Repo: `X:\Gitlab\fredericTr\mobileverimlilik` (GitLab, `origin main`).
Flutter + Riverpod + Drift (yerel SQLite) + Hive (tablo cache) + MSSQL (uzak).

## Yapılanlar

### 1. Tamir modu renk kontrolü (sadece inceleme, kod değişmedi)

- **Neden:** Kullanıcı tamir modunda arka planın sarı yanıp yanmadığını sordu.
- **Ne bulundu:** `lib/features/production/screen/production_screen.dart:68-72` —
  `isRepair` true iken `Scaffold.backgroundColor` ve `AppBar.backgroundColor`
  `Color(0xFFFF9800)` (Material Orange 500) oluyor. Yani **turuncu, sarı değil.**
  Sarı (`0xFFFFEB3B`) sadece verimlilik göstergesinde (`_verimlilikColor`, satır ~133,
  verimlilik < 80 koşulu) kullanılıyor.
- **Akış doğru çalışıyor:** `TAMIR` barkodu → `production_service.dart:129-131` →
  `_runTamirBarcode` bayrağı ters çeviriyor → `_loadLocalStats()` yeni state döndürüyor
  → ekran yeniden çiziliyor. Ayrıca "Adet" kutusu `_RepairAdetTile`'a dönüyor (satır ~164).
- **Tespit edilen tuzak:** Operasyon seçili değilken `TAMIR` barkodu hiç servise ulaşmıyor
  (`production_provider.dart:81-84` erken `return`), dolayısıyla tamir moduna geçilemiyor.
- **Karar:** Renk değişikliği yapılmadı, kullanıcıya soruldu (sarıya çevrilirse AppBar
  yazıları okunmaz, `foregroundColor: Colors.black` da gerekir).

### 2. Gün başında sıfırlanmayan sayaçlar — kök neden

- **Neden:** "Bazı cihazlar sıfırlanmıyor" şikâyeti.
- **Kök neden (kod okuyarak, tahmin değil):**
  - Ekrandaki tüm rakamlar yerel `transections` tablosunun **toplamı**;
    `_loadLocalStats()` sorgusunda **tarih filtresi yoktu** (`where employee_id=...` sadece).
    Yani "sıfırlanma" ayrı bir işlem değil, sadece tablo boşaldığı için oluyordu.
  - Tabloyu temizleyen tek yer `_loadTodayOperations` (login'de çalışıyor):
    `delete ... where is_send = true`. **`is_send = 0` satırlar asla silinmiyordu.**
  - `is_send = 0` satır iki yoldan kalıyor:
    (a) `_sendRowToServer`'daki `catch` hatayı sessizce yutuyor, yeniden gönderme kuyruğu yok;
    (b) gün sonunda açık kalan satır (`is_closed = 0`) — cihaz kapanır/uygulama öldürülürse
    `closeOpenRowsOnLogout` hiç çalışmıyor.
  - (b) daha kötü: `_calculateRow` açık satırın bitişini `DateTime.now()` kabul ediyor,
    dolayısıyla dünkü açık satırın mesaisi bütün geceyi kapsıyor → mesai/verimlilik şişiyor.
    Üstelik `_getOpenedRows()` tarihe bakmadığı için dünkü satır **bugünün aktif satırı**
    olarak kabul edilip 10 sn'de bir güncellenmeye devam ediyordu.
  - "Bazı cihazlar" olmasının sebebi: sadece elinde gönderilememiş satır kalan cihazlar etkileniyor.

### 3. Düzeltme

- **Dokunulan dosyalar:**
  `lib/features/production/service/production_service.dart`,
  `lib/core/database/app_database.dart`,
  `test/gunluk_sifirlama_test.dart` (yeni),
  `analysis_options.yaml` + `pubspec.lock` (flutter analyze/pub get otomatik güncelledi).

- **Ne yapıldı:**
  1. Top-level `String get _bugunFiltresi` eklendi; `_loadLocalStats` (alt sorgu dâhil) ve
     `_loadOperationDayStats` bunu kullanıyor.
  2. `_getOpenedRows()` sadece bugünün açık satırlarını döndürüyor
     (`is_closed = false AND start_date >= bugün 00:00`).
  3. `closeStaleOpenRows()` eklendi: önceki günlerden kalan açık satırları **kendi gününün**
     takvimdeki en geç mesai bitişinde kapatıyor, sunucuya gönderiyor.
     Takvim bulunamazsa `endDate = startDate` (hayali mesai üretmiyor).
     `load()` içinde `_loadLostTimes` sonrası, `_loadTodayOperations` öncesi çağrılıyor
     (takvim cache'i o noktada yüklü).
  4. `_calendarEndOfDay()` yardımcısı — Hive'daki `Calendar` cache'inden o günün/hattın
     en geç `EndTime`'ını buluyor.
  5. Takvim okuma hataları artık `try/catch` ile yutuluyor; Hive patlarsa satırın
     kapatılması/gönderilmesi engellenmiyor.
  6. `_audioPlayer` `late final` yapıldı — servis kurulur kurulmaz platform kanalı açmıyor,
     böylece `flutter test` içinde `ProductionService` kurulabiliyor.
  7. `AppDatabase.forTesting(QueryExecutor)` constructor'ı eklendi (bellek içi DB).

- **KRİTİK ARA BULGU:** İlk denemede filtre olarak mevcut koddaki idiom kullanıldı:
  `date(start_date,'unixepoch','localtime') = date('now','localtime')`.
  Test bunu yakaladı — bu sqlite yapısında **`date('now','localtime')` NULL dönüyor**,
  dolayısıyla `WHERE ... AND NULL` tüm satırları eliyor. `_loadOperationDayStats`
  zaten bu idiomu kullanıyordu; bazı cihazlarda operasyon listesinin boş gelmesinin
  sebebi bu olabilir. Filtre sınırları Dart tarafında unix saniyeye çevrilerek
  saat dilimi bağımlılığı tamamen kaldırıldı.

- **Komutlar:**
  ```bash
  # flutter PATH'te değil, tam yol gerekiyor:
  C:/flutter/bin/flutter.bat analyze lib test
  C:/flutter/bin/flutter.bat test test/gunluk_sifirlama_test.dart
  ```

- **Sonuç / doğrulama:**
  - `flutter test test/gunluk_sifirlama_test.dart` → 3/3 geçti.
  - `flutter analyze lib test` → 35 issue, hepsi info; tek `warning` (`unused_local_variable`,
    satır 230) önceden vardı. Yeni koddan **error/warning yok.**
  - `flutter test` (tüm suite) → `test/widget_test.dart` başarısız; bu Flutter'ın
    şablon "Counter increments smoke test" dosyası, `MyApp`'in artık olmayan sayaç UI'ını
    arıyor. **Önceden de kırıktı, bu turda dokunulmadı.**

- **Commit:** `963a684` — "Gun basi sifirlanmayan sayaclari duzelt" (push edildi, `origin/main`).

## Kararlar

- Sıfırlama işini "tabloyu sil" yerine "sorguyu filtrele" olarak çözdük: veri kaybı riski yok,
  gönderilemeyen satırlar yerelde durmaya devam ediyor ve ileride kuyruktan gönderilebilir.
- Dünkü açık satır `DateTime.now()` ile değil, kendi gününün mesai bitişiyle kapatılıyor —
  aksi hâlde gece boyu mesai yazılıyordu.
- SQL'de `'localtime'` modifier'ına bir daha güvenilmeyecek; gün sınırları Dart'ta hesaplanacak.
- Tamir modu rengi (turuncu → sarı) kullanıcı onayı beklendiği için değiştirilmedi.

## Açık kalanlar / sonraki adım

1. **Gönderilemeyen satırlar için tekrar deneme kuyruğu** (ilk analizdeki 3. madde, yapılmadı):
   açılışta `is_send = 0 AND is_closed = 1` satırları sunucuya yolla, başarılıysa sil,
   N günden eskiyse logla ve sil. Aksi hâlde yerel tablo sürekli büyüyor.
2. `_sendRowToServer`'daki `catch` sadece `debugPrint` yapıyor — hata tamamen sessiz.
   Sorunun aylarca fark edilmemesinin sebebi bu; görünür bir iz (sayaç/uyarı) bırakmalı.
3. `_loadOperationDayStats`'ın eski `localtime` filtresi yüzünden sahada boş liste dönüp
   dönmediği cihazda doğrulanmalı.
4. Operasyon seçili değilken `TAMIR` barkodunun işlenmemesi — istenen davranış mı?
5. `test/widget_test.dart` şablon dosyası ya silinmeli ya gerçek bir teste dönüştürülmeli.
6. Tamir modu rengi sarı istenirse: `0xFFFF9800` → `0xFFFDD835` + `foregroundColor: Colors.black`.
