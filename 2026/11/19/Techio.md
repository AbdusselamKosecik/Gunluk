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
