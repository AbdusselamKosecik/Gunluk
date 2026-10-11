# paketleme — 2026-10-11

## Bağlam
Kullanıcı: etiket ekranında siparişe göre **paket barkodu** ya da order'a göre **ürün etiketi** basılsın; tümü veya istenen adet.
Kararlar (soru-cevap): paket barkodu = sipariş varyantlarının (set/paket) kendi Sentez barkodu (mevcut davranış);
ürün etiketi = work order kalemleri (setler bileşenlere açılmış, sentezservis Test-xxx); adet satır bazında + Tümünü seç.

## Yapılanlar

### 1. Etiket kaynağı seçimi
- **Ne yapıldı:** Etiket sekmesine iki düğme: "Sipariş → Paket barkodu" / "Order → Ürün etiketi". Order modunda sol panelde
  açık iş emri arama (`WorkOrderType=15`, kapalı/silinmiş değil; no / model / müşteri sipariş no), satırlar iş emrinin tüm
  `Erp_WorkOrderItemVariant`'ları (varyant → `Erp_InventoryVariant.InventoryId`), miktar sütunu başlığı "Order".
  Etiket listesi `EtiketListesi.Olustur` (seçili + barkodlu, adet tabanı, ≤0 atlanır) — VM'den ayrıldı, testli.
  Sekme adı "Ürün Etiketi" → "Etiket".
- **Dokunulan dosyalar:** `Paketleme/Ekranlar/Veri/OrderEtiketi.cs` (yeni), `OrderSecici.cs`, `OrderSeciciView.axaml(.cs)` (yeni),
  `EtiketViewModel.cs`, `EtiketView.axaml`, `UygulamaMetinleri.cs`, `Paketleme.Tests/EtiketKaynagiTestleri.cs`.
- **Komutlar:** `dotnet test Paketleme.Tests` → 38 geçti, 24 atlandı (canlı DB, MODFEX_DB_TEST); `dotnet build Paketleme.Android` başarılı.
- **Not:** Ortak `UretimSorgulari.OrderlarAsync` sipariş↔order bağını `Erp_OrderReceiptItem.WorkOrderId` ile arıyor; sentezservis o bağı
  yazmıyor (UZM_SiparisWorkOrder'da) → Order seçimi siparişten bağımsız arama olarak yapıldı (Ortak'a dokunulmadı).
- **Doğrulanmadı:** canlı DB sorgusu ve ekranın görsel kontrolü (sunucuya erişim yok).
- **Commit:** `4e6c130`

## Açık kalanlar / sonraki adım
- Ağa dönünce `MODFEX_DB_TEST=1 dotnet test --filter EtiketKaynagi` ve ekranı canlı deneme.
- Sırada: okutmada barkod + **adet** girişi (tek okuyucu, birden çok kişi).
- sevkiyatmobil önkoşulu: koli kapanışında tekli ürünler de 130/10 ile mamul depoya (sevkiyatmobil spec).
