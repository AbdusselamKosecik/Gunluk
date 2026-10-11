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

### 2. Ürün etiketi baskı düzeltmeleri (ilk gerçek baskıdan sonra)
- **Neden:** kullanıcı: (1) çok siyah, (2) kod ve ad birbirine girmiş, (3) barkod enine büyüyebilir, kod/ad bir tık küçülebilir.
- **Ne yapıldı:** `ZplEtiket.Karartma` (^MD, -30…30) + barkodlara isteğe bağlı `modul` + `Ean13GenislikMm`;
  `UrunEtiketi`: `Karartma=-10`; kod+ad 2,4 → 2,0 mm ve `AzamiKarakter` (≈0,6×yükseklik) ile kırpma — Zebra tek satırlık ^FB'ye
  sığmayanı aynı satıra bindiriyordu; beden·renk 2,6 → 2,4 mm; barkod sığarsa 1,5 kat modül (203 dpi 2 → 3 nokta, EAN-13 23,8 → 35,6 mm).
- **Dokunulan dosyalar:** `Paketleme/Ortak/Donanim/ZplEtiket.cs`, `Paketleme/Ekranlar/Veri/UrunEtiketi.cs`, `Paketleme.Tests/UrunEtiketiTestleri.cs`
- **Sonuç:** 41 test geçti; canlı DB etiket sorgusu testi de geçti (MODFEX_DB_TEST=1). Baskı sonucu kullanıcıdan bekleniyor.
- **Commit:** `e53ca25`

### 3. Ürün etiketi — ikinci baskı düzeltmesi (fotoğraflı geri bildirim)
- **Bulgu:** EAN-13 koruma çubukları (baş/orta/son) aşağı uzanıp kendi bastığımız rakamların üstüne biniyordu (ortadaki rakam
  okunmuyordu); üst satır besleme kaymasıyla kesiliyordu; isimler sola yaslıydı.
- **Ne yapıldı:** `ZplEtiket.BarkodEan13(..., yorum)` → `^BEN,h,Y,N` (rakamları yazıcı standart düzende basar), EAN'da ayrı metin yok;
  Code 128'de okunur metin bizde (2,2 mm). `UstBoslukMm=2`, isim ve beden·renk satırları ortalı (^FB …,C).
  Düzen (20 mm): isim 2,0 · beden 4,4 · barkod 7,4 (6 mm) + rakamlar · MADE IN EGYPT 17,4.
- **Sonuç:** 44 test geçti. Baskı kontrolü kullanıcıda.
- **Commit:** `43d6bc4`

### 4. Ürün etiketi — üçüncü ayar
- **İstek:** biraz aşağı; barkod yazısıyla birlikte bir tık küçük; biraz daha koyu.
- **Kısıt:** 203 dpi'da EAN-13 eni yalnız 95×modül: 23,8 mm (^BY2) ya da 35,6 mm (^BY3) → en 35,6 mm kaldı, yükseklik küçüldü.
- **Ne yapıldı:** `UstBoslukMm` 2 → 3; barkod yüksekliği 6 → 4,4 mm; EAN'da yazıcının rakamları (^BY3'te büyük) yerine
  kendi rakamlarımız 1,8 mm, koruma çubuğu uzantısının (5 modül) altında; MADE IN EGYPT 1,8 mm; `Karartma` -10 → -5.
- **Sonuç:** 44 test geçti; baskı kullanıcıda.

### 5. Ürün etiketi — kayma ve rakamlar
- **Bulgu:** etiket gittikçe kayıyordu (yazıcı sürekli modda: her etiket ^LL=20 mm sayılıyor, aradaki boşluk eklenmiyor → birikir);
  1,8 mm rakamlar çok küçük kaldı.
- **Ne yapıldı:** `ZplEtiket.BosluklaHizala()` → her sıraya `^MNY` (boşluk algılama; kullanıcının "her etikette kâğıt sonu" önerisi);
  EAN rakamları yeniden yazıcıdan (`^BEN,h,Y,N`, standart düzen). Üst boşluk 3 mm, barkod 4,4 mm, koyuluk -5 kaldı.
- **Sonuç:** 45 test geçti. Hâlâ kayarsa yazıcı bir kez kalibre edilmeli (besleme tuşu / `~JC`).

### 6. Ürün etiketi — alt satır, kalın yazı, kayma teşhisi
- **Yazıcı teşhisi (192.168.0.251, ^XA^HH^XZ ile salt okuma):** MEDIA TYPE GAP/NOTCH (zaten boşluk modunda → ^MNY etkisiz),
  SENSOR TRANSMISSIVE, WEB 055 / MEDIA 080 (fark düşük → boşluk kaçırma → birikimli kayma şüphesi), 6 IPS, DARKNESS +15,
  LABEL LENGTH 159, THERMAL-TRANS, 2,5 M etiket sayacı.
- **Ne yapıldı:** etikette `^PR3` (yalnız bu baskı); alt satır: barkod numarası solda (2,2 mm), MADE IN EGYPT sağda (2,0 mm),
  koruma çubuğu uzantısının altında; ürün 2,4 mm + beden 2,8 mm **kalın** (`ZplEtiket.Metin(kalin)` = 1 nokta kaydırmalı ikinci baskı);
  karakter tahmini 0,6 → 0,5×yükseklik (baskıda ölçülen ≈ 0,43).
- **Sonuç:** 46 test geçti. Kalibrasyon (`~JC`, birkaç boş etiket ilerletir) kullanıcı onayı bekliyor.

### 7. Kalibrasyon, eski şablon (PRN), koyuluk 15, ürün adı büyük
- **Kalibrasyon (kullanıcı onayıyla):** `~JC` gönderildi → LABEL LENGTH 159 → 155 nokta, WEB 052 / MEDIA 080. Not: etiketteki `^PR3`
  yazıcının çalışan hızını 3.0 IPS gösteriyor (kalıcı kaydedilmedi; güç kesilince döner).
- **Eski sistem PRN** (`X:\Gitlab\modfex-apparel\aaaaaaaaa.prn`, kullanıcı verdi): sürücü bitmap'i (^GFA 704×160 nokta), başlık
  `^MNW ^MTT ^LL0160 ^PR6,6 ~SD15 ^JUS ^PQ10`; şablon: üstte model (küçük), TB kalın, barkod, altta Barkod solda / Ac + Made in Egypt sağda.
  Dikey ayarlar bizimkiyle aynı → `^LL` değiştirilmedi (kayma için asıl şüpheli sensör kalibrasyonuydu).
- **Ne yapıldı:** `ZplEtiket.Koyuluk` (~SD) ile mutlak 15 (kullanıcı: "koyuluk 15 olacakmış"), `^MD` kaldırıldı;
  ürün adı 2,4 → 2,8 mm kalın; karakter tahmini 0,45×yükseklik (33 karakter sığar).
- **Sonuç:** 47 test geçti. **Commit:** bkz. git log (Urun etiketi: koyuluk ~SD15 …)
