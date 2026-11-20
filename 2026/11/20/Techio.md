# Techio — 2026-11-20

## Bağlam
Kullanıcı: "Arama ve sıralama çalışmıyor, özellikle Cihaz ve Makinelerde." (Vue 3 / bootstrap-vue-next 0.43 göçü kalıntısı.)
Not: 19.11'deki "kuyruk (al-işle, karşı taraf beklemesin)" tasarımı soruları cevapsız kaldı, kod yazılmadı.

## Yapılanlar

### 1. Arama ve sıralama düzeltmesi (sunucu taraflı listeler)
- **Neden / kök sebepler:**
  1. `containers/datatable/DatatableHeading.vue`: `<b-input @input="(val) => searchChange(val)">` — bsvn `BFormInput` sadece
     `update:modelValue` yayıyor; `@input` native olaya düşüyor → `val` = `InputEvent` → arama metni `[object InputEvent]`.
  2. Arama kolonu seçilmezse `table.searchColumn` boş → store'da `q = ""` → filtre hiç gitmiyordu
     (ekranlardaki `const searchColumn = "Code"` varsayılanı sadece "Temizle"de uygulanıyordu).
  3. Başlığa tıklama: hiçbir `b-table`'da sıralama bağlı değildi (Vue2'deki `:sort-by.sync/:sort-desc.sync` göçte düşmüş).
     bsvn 0.43'te `b-table` tıklamada `sorted` olayını `{ key, order: 'asc'|'desc'|undefined }` ile yayıyor.
- **Ne yapıldı:**
  1. `@input` → `@update:modelValue`.
  2. `DatatableHeading` `mounted()` → `this.searchTypeChange(undefined)` (ekranın varsayılan arama kolonu set edilir).
  3. `:no-local-sorting="true"` olan 30 ekrana sed ile:
     `@sorted="(s) => { sortBy = s.order ? s.key : ''; sortDesc = s.order === 'desc'; }"` — mevcut `sortBy/sortDesc`
     watcher'ları `handleTableRefresh()` → `SET_SORT_BY/DESC` → `fetchTableItems` (Sieve `sorts=-Code`).
  4. Kendi `search()`'ü olan 3 ekran (productivity-entries, lost-time-entries, frederic-productivity-entries) store'a sort
     yazmıyordu → `search()` başına `this.SET_SORT_BY(this.sortBy); this.SET_SORT_DESC(this.sortDesc);`.
- **Dokunulan dosyalar:** `ui/src/containers/datatable/DatatableHeading.vue`; `no-local-sorting` içeren 30 `.vue`
  (`grep -rl ':no-local-sorting="true"' ui/src --include=*.vue`).
- **Komutlar:**
  ```bash
  cd X:/Techio/ui/src
  sed -i 's|@input="(val) => searchChange(val)"|@update:modelValue="(val) => searchChange(val)"|' containers/datatable/DatatableHeading.vue
  for f in $(grep -rl ':no-local-sorting="true"' --include=*.vue .); do
    sed -i "s|:no-local-sorting=\"true\"|:no-local-sorting=\"true\"\n                   @sorted=\"(s) => { sortBy = s.order ? s.key : ''; sortDesc = s.order === 'desc'; }\"|" $f; done
  ```
- **Doğrulama (Chrome, test DB, dev server 8080 + API 44307):**
  - Cihazlar: Cihaz Kodu artan → `--------------, 2c:f4:…`; azalan → `KKTablet1, KK8, KK7…`; kolon seçmeden "KKTa" ara → 1 satır.
  - Makineler (`/app/definitions/machine-detail`): artan `001,002…`, azalan `Mahmut1, KKTablet1…`; "Mah" → 1 of 1; Temizle → 1-20 of 386.
  - Makine Tipleri: sıralama ok; "Yak" → 2 of 2; Temizle → 1-20 of 83.
- **Build:** `npm run build` → DONE.

### 2. Paket
- `X:\Techio\Techio-paket-2026-11-20.zip` (58.2 MB, SHA256 `85627A1A…799F`): 19.11 API publish'i (RunSql loglama +
  MinRequestBodyDataRate toleransı) + yeni `ui/dist` + `sql/`. Tarif: 2026/11/19 §12.3 (sadece wwwroot değişti).
- `appsettings.json` test DB'yi gösteriyor — sahada mevcut dosya korunmalı.
- **Commit:** yok — `ui`/`backend` git deposu değil.

## Açık kalanlar
- Kuyruk tasarımı (BulkInstall/Post, InsertTransection) kullanıcı kararı bekliyor.
- Ekranlarda arama kolonu seçimi aynı zamanda sıralama kolonunu da değiştiriyor (DatatableHeading `searchType` watcher) — eski davranış, dokunulmadı.

## 3. Saha logu analizi (14:19) + InsertTransection tarih kontrolü
- **Bulgular (saha logu, RunSql loglaması sayesinde sorgular görünür oldu):**
  1. `7391 ... linked server "SENTEZ" was unable to begin a distributed transaction` — `SET XACT_ABORT ON; BEGIN TRAN; INSERT INTO [SENTEZ]...; ROLLBACK`
     (Barcode `TEST-ROLLBACK`, test isteği). Linked server'a açık transaction içinde yazmak MSDTC ister; iki sunucuda DTC kapalı.
     Çözüm: ya MSDTC (Network DTC Access, Inbound/Outbound, firewall 135+dinamik port) her iki sunucuda açılır, ya sorgu
     `BEGIN TRAN` olmadan atılır (tek INSERT zaten atomik). 19.11'deki Named Pipes [53] da SENTEZ linked server'ına aynı sorgulardan geliyordu.
  2. `select 1/0` — test, sorun değil.
  3. `InsertTransection` → `SqlDateTime overflow` — DTO `StartDate` (non-nullable) cihazdan gelmeyince 0001-01-01.
  4. `RunSql` "Unexpected end of request content" — Dart istemciler 192.168.9.53, 192.168.10.69, 516 B gövde: cihaz bağlantısı yarıda kopuyor (Wi-Fi).
  5. `Arithmetic overflow ... bigint` — `@OrderId = "1220440138131373733615"` (22 hane > bigint). Cihaz uygulaması OrderId yerine
     yanlış değer (muhtemelen okutulan barkod/kart) gönderiyor → Dart uygulamasında düzeltilmeli (kaynak bu makinede yok).
- **Ne yapıldı:** `BulkInstallController.InsertTransection` başına: StartDate/EndDate/ChangedDate/Date < 1753 ise
  `Log.Warning("InsertTransection geçersiz tarih | IP | Veri(JSON)")` ve 400 `{success:false, message:"Geçersiz tarih ..."}`.
- **Dokunulan dosyalar:** `backend/Techtsio.Presentation/Controllers/BulkInstallController.cs`
- **Doğrulama:** Paket exe (44399), tarihsiz gövde → 400 + WARN satırı; `GET /` 200.
- **Paket:** `X:\Techio\Techio-paket-2026-11-20.zip` yenilendi (58.2 MB, SHA256 `C9F296E4…FEC8`), tarif 19.11 §12.3.
- **Commit:** yok — backend git deposu değil.
