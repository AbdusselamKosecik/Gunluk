# warehouse — 2026-10-02

## Bağlam
Müşteriden (04/08 depo portalı) talep geldi:
1. Siparişlerim ana sayfasındaki tüm sütunlara filtre satırı ve alt toplam,
2. Sipariş detayında görünen Style numarasının ana listede de görünmesi,
3. Tüm siparişlerin Excel'e aktarılması.

Başlangıç durumu: `Views/Orders/Index.cshtml` sadece sekme (durum) + dönem filtresi vardı;
"CSV İndir" butonu hiçbir şeye bağlı değildi. Style = sipariş satırındaki `InventoryCode`
(detay sayfasında ürün adının altında görünen kod).

## Yapılanlar

### 1. API: Style alanı + ortak filtre metodu
- **Neden:** Liste ve Excel aynı rol kapsamını (SystemUser hepsi / DealerAdmin kendi dealer'ı /
  DealerUser kendi oluşturduğu) ve sekme/dönem filtresini kullanmalı.
- **Ne yapıldı:** `OrdersApiController` içinde rol + status + period filtresi
  `FilteredOrders(status, period)` private metoduna taşındı. `GET /api/orders` cevabına
  `styles` (distinct InventoryCode, ", " ile birleşik) ve `products` (tüm distinct ürün adları) eklendi.
- **Dokunulan dosyalar:** `src/Warehouse/Controllers/Api/OrdersApiController.cs`

### 2. API: Excel dışa aktarma — `POST /api/orders/excel`
- **Neden:** Müşteri tüm siparişleri Excel'de istiyor.
- **Ne yapıldı:** ClosedXML (projede zaten var, Reports'ta kullanılıyor). Body:
  `{ status, period, ids }` — `ids` null ise kapsamdaki tüm siparişler, doluysa ekranda sütun
  filtresiyle görünenler. İki sayfa:
  - `Siparisler`: Sipariş No, Tarih, Cari Kodu, Cari, Style, Ürün, Adet, Durum (TR etiket)
  - `Siparis Satirlari`: + Renk (Variant1), Beden (Variant2), satır adedi
  Her sayfada AutoFilter, ilk satır dondurulmuş, son satırda `SUBTOTAL(103)` satır sayısı ve
  `SUBTOTAL(109)` adet toplamı (Excel'de filtre uygulanınca toplam da değişir).
  POST seçildi çünkü filtrelenmiş id listesi URL'e sığmayabilir.

### 3. Sayfa: filtre satırı, Style sütunu, alt toplam, Excel butonu
- **Ne yapıldı:** `thead` içine ikinci satır: her sütun için `input.il-col-filter`
  (içerir, TR locale küçük harf), Durum için select, Adet için `150`, `>100`, `<=50`, `10-20`
  desteği. Tarih filtresi hem "2 Eki 2026" hem "02.10.2026" biçimiyle eşleşir.
  `tfoot` alt toplam: sipariş sayısı, benzersiz cari/style/ürün sayısı, adet toplamı — filtrelenmiş
  satırlar üzerinden. "CSV İndir" → "Excel İndir" (fetch + blob indirme).
  i18n anahtarları: `styleNo, subtotal, filterPh, unitsFilterPh, exporting` (tr+en).
  CSS: `.il-filter-row`, `.il-col-filter`, `.il-subtotal-row` (`indigo-loom.css` sonuna).
- **Dokunulan dosyalar:** `src/Warehouse/Views/Orders/Index.cshtml`, `src/Warehouse/wwwroot/js/i18n.js`,
  `src/Warehouse/wwwroot/css/indigo-loom.css`
- **Komutlar:**
  ```bash
  dotnet build src/Warehouse/Warehouse.csproj
  ```
- **Sonuç / doğrulama:** Build 0 hata (21 mevcut uyarı, SqlMapper.cs). Uygulama canlı veritabanıyla
  çalıştırılıp tarayıcıda test EDİLMEDİ.
- **Commit:** `3baf54b` — Siparislerim: sutun filtreleri, alt toplam, Style sutunu ve Excel disa aktarma

## Kararlar
- Filtreler istemci tarafında (liste zaten tamamı yükleniyor; sayfalama yok).
- Style sütununda birden fazla ürünlü siparişte tüm kodlar virgülle gösteriliyor (filtre hepsinde arar).
- Excel ekrandaki filtreye uyar; filtre yoksa sekme/dönem kapsamındaki tüm siparişler.

## Açık kalanlar / sonraki adım
- Canlıda tarayıcı testi: filtre satırı, alt toplam, Excel indirme (iki sayfa, SUBTOTAL).
- Yayın (publish) yapılmadı.
- Müşteriye cevap yazılacak.

### 4. Yayın paketi
- **Neden:** Kullanıcı yayın paketi istedi.
- **Komutlar:**
  ```bash
  cd src/Warehouse
  dotnet publish Warehouse.csproj -p:PublishProfile=FolderProfile -c Release
  # Not: CLI'da çıktı profildeki PublishUrl'e değil bin/Release/net10.0/win-x64/publish/ klasörüne gidiyor
  powershell Compress-Archive -Path 'publish\*' -DestinationPath 'warehouse-2026-10-02.zip'   # win-x64 klasöründe
  ```
- **Sonuç / doğrulama:** self-contained win-x64, 400 dosya, 182 MB; zip 84 MB:
  `src/Warehouse/bin/Release/net10.0/win-x64/warehouse-2026-10-02.zip`. Warehouse.dll içinde yeni
  kod (il-col-filter, exportExcel, SUBTOTAL) doğrulandı. Paket `appsettings.json` içeriyor —
  sunucudaki ayar dosyasının üzerine yazılmamalı.
