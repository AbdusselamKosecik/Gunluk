# Techio — 2026-11-17

## Bağlam
Kullanıcı bildirimi: "Yeni kart eklemede kart tipi gelmiyor" (Tanımlar > Kart > Yeni). Kart Tipi açılır listesi boş geliyordu.

## Yapılanlar

### 1. SelectInput `enum-list` prop'u Vue 3'te hiç ulaşmıyordu
- **Neden:** `ui/src/components/CoreTeam/SelectInput/SelectInput.vue` prop'u `EnumList` (PascalCase) olarak tanımlıyordu, tüm çağıranlar ise `:enum-list="..."` geçiyor. Vue 2 prop eşlemesinde `EnumList` hyphenate edilip `enum-list` ile eşleşiyordu; Vue 3 (projede `vue ^3.5`) attribute'u camelize edip `enumList` arıyor → `EnumList` ile eşleşmiyor, değer `$attrs`'a düşüyor, `dropDownList` boş kalıyor. Vue 3 geçişinden kalan hata.
- **Ne yapıldı:** Prop adı `enumList` yapıldı, tüm `this.EnumList` referansları `this.enumList`. Ayrıca liste sonradan değişirse (asenkron dolum/dil) dropdown güncellensin diye `watch: { enumList }` eklendi.
- **Etki alanı (hepsi aynı hatadan etkileniyordu, hepsi düzeldi):** card FormModal (kart tipi), devices FormModal (cihaz/bağlantı/protokol tipi), calendar FormModal, quality-control-error-card FormModal, OrderDetails (StatusTypes), MonitoringGroupItem (screenTypes), p-l-control-and-management-screen/screen2 ParameterModal, quality-control-manuel-entry-screen ParameterModal.
- **Dokunulan dosyalar:** `ui/src/components/CoreTeam/SelectInput/SelectInput.vue`
- **Komutlar:**
  ```bash
  sed -i 's/EnumList: {default: undefined},/enumList: {default: undefined},/; s/this\.EnumList/this.enumList/g' SelectInput.vue
  npx vue-cli-service build   # production, başarılı
  ```
- **Sonuç / doğrulama:** Production build hatasız. Tarayıcıda canlı test yapılmadı (backend ayakta değildi).
- **Commit:** yok — `X:\Techio\ui` git reposu değil.

## Kararlar
- Çağıran 11 yeri `:EnumList` yapmak yerine bileşendeki prop adı düzeltildi (tek nokta, Vue 3 isimlendirme kuralına uygun).

## Açık kalanlar / sonraki adım
- `X:\Techio\ui` ve `backend` için remote/git yok — HDD riskine karşı repo bağlanmalı.
- Ekranda Tanımlar > Kart > Yeni ile kart tipi listesinin dolduğu elle doğrulanmalı; yeni `dist` sahaya atılmalı.
