# warehouse — 2026-10-20

## Bağlam
Kullanıcı ekran görüntüsü gönderdi: https://shipment.mfggiyim.com.tr/Orders (Siparişlerim) listesinde
işlem düğmeleri (Görüntüle / Siparişi Onayla / İptal Et) ekranı taşıyor, satırın sağında beyaz/gri bloklar var.

## Yapılanlar

### 1. Liste işlem düğmeleri taşması düzeltildi
- **Neden:** `<td style="display:flex">` hücreyi tablo hücresi olmaktan çıkarıyor (satır arka planı ve
  yüksekliği uygulanmıyor → beyaz/gri blok); kart `overflow:hidden` olduğu için sağa taşan düğmeler kesiliyordu.
  Aynı kalıp Kullanıcılar sayfasında (kullanıcı + bayi tabloları) da vardı.
- **Ne yapıldı:** td normal kaldı (`.il-actions-cell`: width 1%, nowrap), düğmeler içteki `div.il-actions`
  (flex, sağa yaslı). Kart `.il-table-scroll` (overflow-x:auto). Siparişlerde düğme metni `span.il-btn-label`
  içinde; `@media (max-width:1400px)` altında gizlenir, ad `title`'da.
- **Dokunulan dosyalar:** `src/Warehouse/Views/Orders/Index.cshtml`, `src/Warehouse/Views/Users/Index.cshtml`,
  `src/Warehouse/wwwroot/css/indigo-loom.css`
- **Doğrulama:** Aynı CSS + satır yapısıyla statik sayfa, Chrome'da 1700 px (etiketli, tek satır) ve 1100 px
  (yalnız ikon, sığıyor) ekran görüntüsü. `dotnet publish -p:PublishProfile=FolderProfile -c Release` hatasız.
- **Paket:** yalnız değişen dosyalar — `src/Warehouse/bin/Release/net10.0/win-x64/warehouse-web-yama-2026-10-20.zip`
  (`Warehouse.dll`, `Warehouse.pdb`, `wwwroot/css/indigo-loom.css`); appsettings içermez, sitenin üzerine kopyalanır.
- **Commit:** bkz. warehouse `git log` — fix(web): siparis/kullanici listesinde islem dugmeleri tasmasi

### 2. Sipariş notu alt satıra alındı
- **Neden:** Kullanıcı "sipariş notunu alt satıra alsak" dedi; önizleme (statik sayfa, sitenin CSS'i) onaylandı.
- **Ne yapıldı:** `Orders/Index.cshtml`'de her sipariş `<tbody class="il-order">` (v-for tbody'de):
  ana satır + `v-if="o.notes"` not satırı (`colspan=8`, sticky_note_2 ikonu). "Sipariş Notu" sütunu kalktı;
  not filtresi işlem sütunu başlığında (`.il-actions` içinde, temizle düğmesiyle); alt toplamdaki acil sayısı
  durum sütununa kaydı. CSS: zebra/hover `tbody.il-order:nth-of-type` ile sipariş bazında (satır bazında
  boyayınca notsuz/notlu sıralar karışıyordu — önizlemede görüldü). Excel çıkışı aynı.
- **Paket:** aynı yama zip'i yeniden üretildi (her iki düzeltmeyi içerir).

## Açık kalanlar
- Yamayı sunucuya kopyalamak (kullanıcı); CSS `asp-append-version` ile bağlı, tarayıcı önbelleği sorun olmaz.
