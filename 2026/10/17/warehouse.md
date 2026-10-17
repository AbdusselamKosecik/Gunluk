# warehouse — 2026-10-17

## Bağlam
Müşteriden (free stock portal) iki talep geldi:
1. **Sipariş başına not alanı** — free stock siparişinin hangi orijinal siparişe ait olduğunu
   (ilgili sipariş no) yazabilmek.
2. **Sipariş başına acil işareti** — her acil sipariş için ayrıca mail atmak yerine portaldan işaretlemek.

Kullanıcı kararı: web'den girilsin, düzenlemede değiştirilebilsin, Excel'de ve listelerde görünsün;
mobilde (Warehouse.Terminal WPF el terminali ekranları) aciller kırmızı olsun, açıklamalar görünsün.

Başlangıç: `UZM_Order` tablosunda not/acil alanı yoktu. Web'de ayrı bir "sipariş düzenleme"
sayfası yok; detay sayfası (`/Orders/Detail/{id}`) düzenleme yeri olarak seçildi.

## Yapılanlar

### 1. Veritabanı kolonları
- **Neden:** İki alanın da sipariş başlığında tutulması gerekiyor; şema EF migration ile değil
  `sql/` altındaki elle çalıştırılan script'lerle yönetiliyor (canlı DB: SentezLive).
- **Ne yapıldı:** `UZM_Order.Notes NVARCHAR(1000) NULL`, `UZM_Order.IsUrgent BIT NOT NULL DEFAULT 0`
  (constraint adı `DF_UZM_Order_IsUrgent`), `IF NOT EXISTS` korumalı.
- **Dokunulan dosyalar:** `sql/add_UZM_Order_Notes_IsUrgent.sql`
- **Sonuç:** Script canlı DB'de **ÇALIŞTIRILMADI** — yayından önce elle çalıştırılmalı, yoksa
  hem web hem terminal "Invalid column name" hatası verir.

### 2. Web — model + sipariş oluşturma (sepet)
- **Ne yapıldı:** `Order` modeline `string? Notes`, `bool IsUrgent`; `ErpDbContext`'te
  `Notes.HasMaxLength(1000)`. `CheckoutRequest` record'una sona `string? Notes = null, bool IsUrgent = false`
  eklendi (eski istemciler bozulmasın diye varsayılanlı). `CartApiController.NormalizeNotes`
  (trim, boşsa null, 1000 karaktere kırp) — internal static, Orders API de kullanıyor.
  Sepet ekranında cari seçildikten sonra "Sipariş Notu" textarea + "Acil sipariş" kutusu.
- **Dokunulan dosyalar:** `src/Warehouse/Models/Order.cs`, `src/Warehouse/Data/ErpDbContext.cs`,
  `src/Warehouse/Controllers/Api/CartApiController.cs`, `src/Warehouse/Views/Cart/Index.cshtml`

### 3. Web — liste, detay/düzenleme, Excel
- **Ne yapıldı:**
  - `GET /api/orders` ve `GET /api/orders/{id}` cevabına `notes`, `isUrgent`.
  - Yeni `PUT /api/orders/{id}/notes` body `{ notes, isUrgent }` — kapsam `FilteredOrders(null,null)`
    (rol bazlı görünürlük: siparişi görebilen düzenleyebilir), her statüde açık.
  - Detay: başlıkta ACİL rozeti; "Sipariş Notu" kartı (acilse sol kenar kırmızı), Düzenle → textarea +
    acil kutusu + Kaydet/İptal.
  - Siparişlerim: sipariş no yanında ACİL rozeti, acil satırlar kırmızı zemin (`il-row-urgent`),
    yeni "Sipariş Notu" sütunu + sütun filtresi, filtre çubuğunda "Sadece acil (n)" kutusu,
    alt toplamda acil sayısı. Sütun filtresi aktifse Excel yine ekrandakileri alır.
  - Excel: iki sayfaya da sona "Acil" ve "Not" sütunları; acil satırlar kırmızı/kalın/açık kırmızı zemin
    (`WriteUrgentNotes`). Adet `sumColumn` indeksleri değişmedi (7 ve 9).
  - i18n (tr+en): `orderNotes, orderNotesPh, markUrgent, urgent, urgentOnly, notesSaved`.
  - CSS (`indigo-loom.css` sonu): `.il-urgent-toggle`, `.il-urgent-badge`, `.il-row-urgent`, `.il-notes-cell`.
- **Dokunulan dosyalar:** `src/Warehouse/Controllers/Api/OrdersApiController.cs`,
  `src/Warehouse/Views/Orders/Index.cshtml`, `src/Warehouse/Views/Orders/Detail.cshtml`,
  `src/Warehouse/wwwroot/js/i18n.js`, `src/Warehouse/wwwroot/css/indigo-loom.css`

### 4. Terminal (mobil) — Sipariş Sevk + Rezervasyon Okutma
- **Ne yapıldı:**
  - `SevkOrderSummary`: `IsUrgent`, `Notes`, `HasNotes`; `Display` başına `!! ACIL !! `, sonuna `| Not: ...`.
  - `GetPendingOrdersForSevkAsync` ve `GetPendingOrdersByBoxAsync`: SELECT/GROUP BY'a `o.IsUrgent, o.Notes`,
    `ORDER BY o.IsUrgent DESC, o.OrderNumber` (aciller üstte).
  - İki pencerede `OrderCombo.ItemContainerStyle`: `IsUrgent=True` → #D32F2F zemin, beyaz kalın yazı.
  - Sipariş seçiminin altına `OrderNoteBanner` (Border) + `OrderUrgentText` ("ACIL SIPARIS") + `OrderNoteText`.
    Yeni `Views/OrderNoteBannerHelper.Show(...)`: acil → kırmızı bant beyaz yazı; sadece not → sarı bant.
    `OnOrderSelected` ve `OnRefreshOrders`'da çağrılıyor.
- **Dokunulan dosyalar:** `src/Warehouse.Terminal/Models/AppModels.cs`,
  `src/Warehouse.Terminal/Services/DatabaseService.cs`, `src/Warehouse.Terminal/Views/OrderNoteBannerHelper.cs`,
  `src/Warehouse.Terminal/Views/SiparisSevkWindow.xaml(.cs)`, `src/Warehouse.Terminal/Views/RezervasyonOkutmaWindow.xaml(.cs)`

- **Komutlar:**
  ```bash
  dotnet build src/Warehouse/Warehouse.csproj
  dotnet build src/Warehouse.Terminal/Warehouse.Terminal.csproj
  ```
- **Sonuç / doğrulama:** İki proje de 0 hata; yeni uyarı yok (mevcut uyarılar SqlMapper, InvoicesApi,
  NuGet Pkcs, RezervasyonOkutma `boxCode.StartsWith`). Canlı DB'ye script uygulanmadığı için
  tarayıcıda/terminalde **test EDİLMEDİ**.
- **Commit:** `33bb70d` — Siparis notu ve acil isareti (web + terminal)

## Kararlar
- Düzenleme yeri: sipariş detay sayfası (ayrı düzenleme sayfası yok). Not/acil her statüde değiştirilebilir.
- Web listesi tarih sırasında kalıyor (aciller rozet + kırmızı satırla ayrışıyor, "Sadece acil" filtresi var);
  terminalde ise aciller listenin en üstünde.
- Not tek alan, 1000 karakter; ayrı "ilgili sipariş no" alanı açılmadı (müşteri serbest not istedi).
- `BoxSilRzvYenileWindow` (rezervasyon yenileme) listesine acil/not eklenmedi.

### 5. Canlı DB script'i + yayın paketleri
- **Neden:** Kullanıcı script'in çalıştırılmasını ve sunucu/terminal paketlerini istedi.
- **Komutlar:**
  ```bash
  # parola appsettings.json'dan okunur, ekrana basılmaz
  sqlcmd -S 192.168.1.22 -d SentezLive -U sa -P "$PW" -C -b -i sql/add_UZM_Order_Notes_IsUrgent.sql
  cd src/Warehouse && dotnet publish Warehouse.csproj -p:PublishProfile=FolderProfile -c Release
  cd src/Warehouse.Terminal && dotnet publish Warehouse.Terminal.csproj -p:PublishProfile=FolderProfile -c Release
  # zip: Compress-Archive (PowerShell)
  ```
- **Sonuç / doğrulama:**
  - DB: `Notes nvarchar(1000)` (max_length 2000 bayt), `IsUrgent bit NOT NULL`; 548 sipariş, hepsi IsUrgent=0.
  - Web: `src/Warehouse/bin/Release/net10.0/win-x64/warehouse-web-2026-10-17.zip` (84 MB, 400 dosya,
    self-contained). i18n.js/indigo-loom.css/Warehouse.dll içinde yeni kod doğrulandı. Paket
    `appsettings.json` içeriyor — sunucudaki ayar dosyasının üzerine yazılmamalı.
  - Terminal: `src/Warehouse.Terminal/bin/Release/net10.0-windows/publish/warehouse-terminal-2026-10-17.zip`
    (61 MB; single-file `Warehouse.Terminal.exe` + 5 native dll). Terminal APK değil, WPF Windows exe.
    Exe sıkıştırılmış bundle olduğundan doğrulama `obj/.../Warehouse.Terminal.dll` üzerinde UTF-16
    string araması ile yapıldı ("IsUrgent DESC", "!! ACIL !!" var).

## Açık kalanlar / sonraki adım
- Sunucuya web paketi, terminallere exe kurulumu (kullanıcı yapacak); canlıda test: sepet → not/acil, detay düzenleme, liste filtreleri, Excel,
  terminalde kırmızı satır ve bant.
- Müşteriye cevap yazılacak.
