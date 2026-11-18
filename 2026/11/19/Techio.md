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
