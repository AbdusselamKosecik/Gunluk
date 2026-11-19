# Techio — 2026-11-19

## Bağlam
17.11'deki SelectInput `enumList` düzeltmesini (bkz. `2026/11/17/Techio.md`) uygulamada çalıştırıp doğrulama. Bu sırada ikinci bir hata bulundu.

## Yapılanlar

### 1. Uygulamayı yerelde ayağa kaldırma
- **Ne yapıldı:** UI dev sunucusu 8080'de çalışırken `apiUrl()` → `http://localhost:44307/` kullanıyor (`ui/src/constants/config.js`). launchSettings 44306 dediği için profil kullanılmadan başlatıldı.
- **Komutlar:**
  ```bash
  cd backend/Techtsio.Presentation && ASPNETCORE_ENVIRONMENT=Development dotnet run --no-launch-profile --urls http://localhost:44307
  cd ui && npx vue-cli-service serve --port 8080 --no-open
  ```
- **Sonuç:** Login olmadı. API `DefaultConnection` → `192.168.1.69 / TechtsioMerkezTest` (appsettings.json) kullanıyor, bu ağdan (Wi-Fi 192.168.90.x) 1433'e erişim yok (Test-NetConnection False). `appsettings.Development.json` içindeki `EsasContext` kodda okunmuyor.
- **Geçici test yöntemi (koda dokunmadan):** Tarayıcıda `localStorage.JwtToken` sahte değer + XHR'ı 44307 için taklit eden JS (boş liste döner) + `__vue_app__.config.globalProperties.$router.push('/app/definitions/card-detail')`. Sayfayı yeniden yüklemeden SPA içinde gezildi; aksi halde 401 → `CheckLoginRefreshToken` login'e atıyor.

### 2. Kart tipi listesi doğrulandı
- Tanımlar > Kart > Yeni Barkot/Kart → Kart Tipi açılır listesi doldu (Personel, Kayıp Zaman, Makine, Model, Operasyon, Sipariş, Sipariş Varyant, Bant, Gün Sonu, Tamir Başlangıç...). 17.11 düzeltmesi çalışıyor.

### 3. İkinci hata: tip seçince alt alanlar açılmıyordu
- **Neden:** `SelectInput.changeEvent` vue-select `@option:selected`'tan gelen seçenek NESNESİNİ (`{value, text}`) `changeMethod`'a geçiriyordu. Tüm çağıranlar (card/card-serial/productivity-entries/lost-time-entries `changeType`, `changeOrderId`, `changeModelId`; ParameterModal `handleParameterChange` argümanı kullanmıyor) DEĞER bekliyor. `event == CardTypeProp.Employee` hiç tutmuyor → Personel/Makine/Sipariş alanları açılmıyor; sipariş→model→varyant zinciri de `fillSpecificData([object Object])` ile bozuk.
- **Ne yapıldı:** `changeEvent` içinde `event[this.valuefield]` ile değer çıkarılıp geçiriliyor (nesne değilse aynen).
- **Dokunulan dosyalar:** `ui/src/components/CoreTeam/SelectInput/SelectInput.vue`
- **Sonuç / doğrulama:** Personel seçildi → Personel alanı göründü, `/api/Employee/Select` isteği gitti. Production build (`npx vue-cli-service build`) başarılı, `ui/dist` güncel.
- **Commit:** yok — `X:\Techio\ui` git reposu değil.

## Kararlar
- Düzeltme 11 çağıran yerine ortak bileşende yapıldı.
- Konsoldaki `itemsValue.reduce is not a function` ve `reading 'Name'` hataları taklit API cevaplarından kaynaklı (boş obje/sahte user) — gerçek hata değil, değerlendirmeye alınmadı.

## Açık kalanlar / sonraki adım
- Gerçek DB ile (şirket ağı/VPN) login + kart kaydetme uçtan uca test edilmeli.
- `ui`/`backend` için git remote yok — bağlanmalı.
- Yeni `dist` sahaya atılmalı.

---

## Tur 2 (01:30–) — "Ekranlar iç içe geçmiş, tüm ekranlara bak"

### 4. Login sonrası tüm ekranlarda yerleşim bozuk (iç içe geçme)
- **Belirti:** İçerik sol menünün altına giriyor, "Copyright" footer tablo satırlarının üstüne biniyor.
- **Neden:** `body.background` sınıfı login'den sonra kalıyor; tema `body.background main { margin:0 !important }` ile main'in tüm boşluklarını sıfırlıyor. `layouts/UserLayout.vue` sınıfı `beforeDestroy`'da kaldırıyordu — **Vue 3 `beforeDestroy`/`destroyed` çağırmaz** (yeni adları `beforeUnmount`/`unmounted`).
- **Ne yapıldı:** 53 dosyada `beforeDestroy` → `beforeUnmount`, `destroyed` → `unmounted` (sed, satır başı hook tanımları + `p-l-balance-screen/index.vue` içindeki `, beforeDestroy()`). Yan etki olarak ekranlardaki `setInterval` yenilemeleri ve `resize` dinleyicileri de artık ekrandan çıkınca temizleniyor (önceden arka planda birikiyordu).
- **Doğrulama:** SPA içinde `/user/login` → `/app/...` geçişinde body sınıfı eklenip kaldırılıyor, `main` margin-left 410px.

### 5. Modallarda metin alanları üst üste biniyordu
- **Neden:** bootstrap-vue-next `BFormGroup` → `class="b-form-group"` basıyor (eski BootstrapVue `form-group`). BS4 temasındaki `.form-group { margin-bottom: 1rem }` uygulanmıyor → `margin-bottom: 0`.
- **Ne yapıldı:** `ui/src/assets/css/sass/_piaf.style.scss` içine `.b-form-group { position: relative; margin-bottom: 1rem; }`.

### 6. Modallarda fazladan Cancel/OK footer'ı
- **Neden:** bootstrap-vue-next'te `hide-footer` yok, adı `no-footer` (`hide-header` → `no-header`).
- **Ne yapıldı:** 49 .vue dosyasında sed ile `hide-footer`→`no-footer`, `hide-header`→`no-header` (dosya listesi: scratchpad `modal-files.txt`; komut: `grep -rlE "\bhide-(footer|header)\b" --include=*.vue . | xargs sed -i -E 's/\bhide-footer\b/no-footer/g; s/\bhide-header\b/no-header/g'`).

### 7. Diğer Vue 3 kalıntıları
- `containers/navs/Topnav.vue`: 4× `<template slot="button-content">` → `<template #button-content>` (üst menü dropdown ikonları çizilmiyordu).
- `containers/navs/Sidebar.vue`: `@click.native` → `@click`.
- Dokunulmayanlar (bilinçli): tablolardaki `slot="Performance"/"status" slot-scope` şablonları ölü kod (yanlarında `v-slot:cell(...)` var); pivot `filters: []` Syncfusion ayarı; `FormWizard` `$children` kullanılmıyor; `ModelDetailTabs` `:model.sync` tek yönlü bağ olarak çalışıyor; eski Notification plugin kullanılmıyor (`@kyvg/vue3-notification` aktif).

### 8. `this.$t is not a function` / `this.parent.$t is not a function` (15 ekranda konsol hatası)
- **Neden:** Önceki ekranın `SelectInput`'u liste isteği atıyor, cevap ekrandan çıktıktan sonra geliyor. vue-i18n legacy mod unmount'ta `this.$t`'yi siliyor → success callback patlıyor → `web-api-connector` `.then().catch()` bunu yakalayıp error callback'i çağırıyor → o da `this.parent.$t` ile patlıyor.
- **Ne yapıldı:** `SelectInput.vue` 4 fetch metodunun 8 callback'ine `if (this.$.isUnmounted) return;`.

### 9. Geniş tablolu ekranlarda yatay sayfa taşması
- **Ekranlar:** productivity-entries, lost-time-entries, frederic-productivity-entries.
- **Neden:** `#app-container > main > .container-fluid > div` zinciri flex, `min-width:auto` → geniş tablo sayfayı genişletiyor; tablolarda `responsive` yok.
- **Ne yapıldı:** 3 ekranın `<b-table>`'ına `responsive`; temaya `#app-container > main, ... > .container-fluid, ... > .container-fluid > div { min-width: 0; }`.
- **Doğrulama:** scrollWidth 1446 ≤ 1462, tablolar kendi içinde kaydırılıyor (ör. 1478/920).

### Tarama yöntemi (tekrar için)
Tarayıcı konsolunda router'dan yaprak `/app/*` rotaları alınıp (`$router.getRoutes()`, 113 ekran) her birine `push` + 2.2 sn bekleme; kontrol: `body.background`, `.card/table` sol kenarı < menü sağ kenarı, footer üstü < içerik altı, `scrollWidth > innerWidth`, `console.error` + `unhandledrejection`.
- Not: dev server `dist`'i statik servis ettiği için production build sırasında sayfa yenileniyor; taramayı build'den sonra çalıştır.

- **Dokunulan dosyalar (tur 2):** `ui/src/assets/css/sass/_piaf.style.scss`, `ui/src/components/CoreTeam/SelectInput/SelectInput.vue`, `ui/src/containers/navs/Topnav.vue`, `ui/src/containers/navs/Sidebar.vue`, `ui/src/layouts/UserLayout.vue` + 52 dosya (hook adı), 49 dosya (modal prop), 3 data-input ekranı.
- **Build:** `npx vue-cli-service build` başarılı (01:47).
- **Commit:** yok — `ui` git reposu değil.

### 10. Tablo formatter'ları (bootstrap-vue-next imza değişikliği)
- **Neden:** bootstrap-vue-next `field.formatter({ value, key, item })` ile TEK nesne geçiyor (node_modules/bootstrap-vue-next/dist doğrulandı). Eski `(value, key, item)` / `value =>` imzalarında value=nesne, item=undefined. Belirti: Kart listesinde "Kart Tipi" sütunu boş/hatalı, Cihaz listesinde tip sütunları, Tamir "Saat" = "Invalid Date", lost-time-entries `undefined.StartDate` render hatası. `formatter: "assignShift"` (string) yeni sürümde hiç çalışmıyor.
- **Ne yapıldı:** 7 dosyada `formatter: value => {` → `formatter: ({ value }) => {`, `formatter: (value, key, item) => {` → `formatter: ({ value, key, item }) => {` (Card, Devices, repair, QualityControlErrorCard, productivity-entries, lost-time-entries, frederic-productivity-entries). `p-l-balance-screen`: `formatter: ({ value }) => this.assignShift(value)`. Frederic `item.StartDate/EndDate.split` ve repair `dayjs(value)` null-safe.
- **Doğrulama:** Kart listesi Kart Tipi: "Personel", "Operasyon"...; Tamir Saat: 11:28, 17:18...

### 11. Diğer tek tek hatalar
- `reports/Frederic/MachineBreakdown-report/index.vue` mounted: şablonda olmayan `productionSelect/modelSelect/orderSelect` ref'lerine `fillData()` → `?.fillData()`.
- `data-input-screens/order/.../ModelModal/ModelModal.vue`: `modelList: new ModelSelect()` (nesne) vue-select'i bozuyordu (`options.concat is not a function`) → `modelList: []`, kullanılmayan import silindi.
- **Backend/DB (UI değil, dokunulmadı):** `/api/FaultyTypes` → `Invalid column name 'BaseQualityTypeId'` — TechtsioMerkezTest'te bu sütun yok, entity bekliyor. Test DB'ye şema/migration uygulanmalı (Tanımlar > Hata Tipi ekranı açılmıyor).

### Son tarama sonucu
- 111/111 ekran: menü altına girme, footer binmesi, yatay taşma, body.background → **0**.
- Konsol hataları: kalanlar düzeltildi ve tek tek tekrar doğrulandı; geriye yalnız FaultyTypes DB hatası kaldı.
- Production build başarılı (02:0x).

## 12. Saha logu analizi + RunSql sorgu loglama + paket (12:40)

### 12.1 Saha hataları
- **Neden:** Kullanıcı sahadaki API logunu yapıştırdı (yerel logda bu connection id'ler yok → saha sunucusu).
- **Bulgular:**
  - `BulkInstall/RunSql` → `SqlException Named Pipes [53]`, `Class:16`, hata `ExecuteReader → TryRun` içinde
    (Open'da değil) → SQL Server'ın kendisi başka bir sunucuya gidemiyor (gönderilen SQL/SP'de uzak sunucu).
    Kullanıcı linked server'larda sorun görmedi → gönderilen sorguyu görmek gerekiyor; RunSql SQL'i loglamıyordu.
  - `BadHttpRequestException ... MinRequestBodyDataRate` → istemci gövdeyi çok yavaş gönderiyor (ağ). Kod değişikliği yapılmadı.
- **Karar:** RunSql'in yetkisiz (no `[Authorize]`) olduğu kullanıcıya söylendi; kullanıcı "öyle kalacak" dedi.

### 12.2 RunSql hata loglama
- **Ne yapıldı:** `con.Open()` + `ExecuteReader` `try/catch` içine alındı; catch'te
  `Log.Error(ex, "RunSql hatası. Sql: {Sql} | Parametreler: {Parameters}", ...)` ve `throw;` (davranış aynı).
- **Dokunulan dosyalar:** `backend/Techtsio.Presentation/Controllers/BulkInstallController.cs`
- **Doğrulama:** Paket exe'si 44399'da çalıştırıldı; `SELECT 1` → 200; `SELECT * FROM Tablo_Yok_Test WHERE Id=@p` → 500 ve
  logda `RunSql hatası. Sql: "SELECT * FROM Tablo_Yok_Test WHERE Id=@p" | Parametreler: [{"Key":"@p","Value":5}]`.

### 12.3 Paket
- **Komutlar:** (2026-11-12 tarifinin aynısı)
  ```bash
  cd X:/Techio/backend && dotnet publish Techtsio.Presentation/Techtsio.Presentation.csproj \
      -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -o <staging>/api
  cd <staging>/api && rm -rf wwwroot && cp -r X:/Techio/ui/dist wwwroot && rm -f *.pdb appsettings.Development.json
  unzip -q X:/Techio/Techio-paket-2026-11-12.zip "sql/*" -d <staging>/api
  tar.exe -a -c -f X:\Techio\Techio-paket-2026-11-19.zip -C <staging>\api *
  ```
- **Sonuç:** `X:\Techio\Techio-paket-2026-11-19.zip` (58.2 MB, SHA256 `CDF9E934…6712`). İçinde bugünkü UI düzeltmeleri
  (ui/dist 02:04 build) + RunSql loglama + `sql/` (11-12 paketindeki eksik SP scripti). Açılıp test: `GET /` 200.
- **Dikkat:** `appsettings.json` TEST DB'yi gösteriyor (`192.168.1.69/TechtsioMerkezTest`) — sahada mevcut appsettings korunmalı.
- **Commit:** yok — `ui` ve `backend` git deposu değil, kod uzak depoya gitmedi.

## 13. MinRequestBodyDataRate hatası sahada sürüyor → tolerans + loglama (16:07)
- **Neden:** Yeni paket kurulduktan sonra sahada `BadHttpRequestException: Reading the request body timed out ... MinRequestBodyDataRate`
  tekrar geldi (16:03, 16:05). Log uç noktayı/cihazı söylemiyordu.
- **Ne yapıldı:**
  1. `Program.cs` → `.ConfigureKestrel(k => k.Limits.MinRequestBodyDataRate = new MinDataRate(50, TimeSpan.FromSeconds(30)))`
     (varsayılan 240 B/sn, 5 sn tolerans). Tamamen kapatılmadı: takılı kalan istemci 30 sn sonra yine kesilir.
  2. `Startup.cs` → mevcut 404 fallback middleware'inde `next()` `try/catch (BadHttpRequestException)`; catch'te
     `Log.Warning("Eksik/yavaş istek gövdesi: {Method} {Path}{Query} | IP | Content-Length | UA | mesaj")`,
     cevap başlamadıysa `StatusCode = ex.StatusCode` (408/400). Artık "unhandled exception" EROR yok.
- **Dokunulan dosyalar:** `backend/Techtsio.Presentation/Program.cs`, `backend/Techtsio.Presentation/Startup.cs`
- **Doğrulama:** Paket exe'si 44399; ham TCP ile `POST /api/BulkInstall/InsertTransection` Content-Length 2000, 6 bayt gönderip bekleme:
  - 20 sn bekleyen → kesilmedi (eskiden ~5 sn'de kesilirdi); istemci kapanınca WARN "Unexpected end of request content".
  - 45 sn bekleyen → ~30 sn'de `HTTP/1.1 408`, WARN satırı path + IP + UA ile.
- **Paket:** `X:\Techio\Techio-paket-2026-11-19.zip` yeniden üretildi (58.2 MB, SHA256 `1EAC4FAB…5C6C`), tarif §12.3 ile aynı.
- **Commit:** yok — backend git deposu değil.
- **Sonraki adım:** Sahada WARN satırlarındaki IP/UA'dan hangi cihazın ağı sorunlu bakılacak; 30 sn de yetmiyorsa cihaz gerçekten kopuyor.
