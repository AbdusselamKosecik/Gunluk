# TrendyolKarMarjiBulma — 2026-11-04

## Bağlam
Uzantı (v1.0.0, 0db8a64) kullanıcı tarafından Chrome'a eklendi. Yeni istek: partner panelinde
`/pricing/rate-card` ve `/pricing/ty-plus` sayfalarında her radyo düğmesinin altına model kodu,
price-value ve commission-value JSON olarak yazılsın.

## Yapılanlar

### 1. Partner fiyatlandırma sayfalarına JSON kutusu
- **Neden:** Fiyat/komisyon seçeneklerini model koduyla birlikte kopyalanabilir veri olarak görmek.
- **Ne yapıldı:**
  - `src/partner.js` (yeni içerik betiği, `partner.trendyol.com/*`, yol kontrolü
    `^/pricing/(rate-card|ty-plus)(/|$)` betik içinde — panel SPA olduğu için tüm alan adına eklenir).
  - Her `span.radio-button` için: radyodan yukarı çıkılır, `.price-value`/`.commission-value`
    içeren ilk ata = seçenek kabı; birden çok radyo içeren ataya gelinirse durulur (başka seçeneğin
    fiyatını almamak için). Model kodu: radyodan yukarı doğru ilk `Model Kodu: X` yazan `<span>`.
  - Değerler sayıya çevrilir ("1.091,50 TL" → 1091.5, "%21,5" → 21.5), çevrilemezse ham metin.
  - Radyonun hemen arkasına `<pre class="tkm-radyo-json">` eklenir; aynı JSON ise DOM'a dokunulmaz
    (MutationObserver döngüsü olmasın), tıklama radyoya geçmez.
  - MutationObserver + 300 ms erteleme ile SPA geçişi ve tablo yeniden çizimi izlenir.
  - `manifest.json`: v1.1.0, host_permissions'a partner, ikinci content_scripts girdisi.
  - README'ye bölüm.
- **Dokunulan dosyalar:** `src/partner.js`, `manifest.json`, `README.md`
- **Sonuç / doğrulama:** Partner sayfası giriş istediği için otomasyon tarayıcısında açılamadı.
  Kullanıcının verdiği radyo HTML'iyle sahte sayfa (2 ürün, 4 seçenek) kurulup gerçek
  `src/partner.js` yüklendi: 4 kutu, doğru model kodu/fiyat/komisyon; iki kez taramada çift kutu yok.
  `npm test` 7/7.
- **Commit:** `c4f57e3` — Partner rate-card / ty-plus: radyo altina model kodu, fiyat, komisyon JSON

## Kararlar
- Fiyat/komisyon seçenek kabından, model kodu daha geniş satır/karttan aranır (ortak bilgi).
- JSON anahtarları kullanıcının dediği adlarla: `modelKodu`, `price`, `commission`.

## Açık kalanlar / sonraki adım
- Gerçek panel DOM'unda doğrulanmadı; seçici tutmazsa kullanıcıdan satırın HTML'i istenecek.
- Kullanıcının mesajı "ilk basta" diye yarım kaldı — sonraki adım (muhtemelen bu veriyle kâr hesabı) bekleniyor.

## Ek: v1.2.0 — kutu seçeneğin altına, rate-card için iframe/shadow DOM

### 2. ty-plus çalıştı, rate-card çalışmadı; kutu radyonun yanında kalıyordu
- **Neden:** Kullanıcı: ty-plus'ta geldi ama "altına getirsek iyiydi"; rate-card'da hiç gelmedi.
  rate-card DOM'u görülemedi (giriş gerekli). En olası sebepler: içerik iframe'de (içerik betikleri
  varsayılan olarak yalnız üst çerçevede çalışır) ya da shadow DOM'da (querySelectorAll inmez).
- **Ne yapıldı:**
  - Kutu artık seçenek kabının (fiyat+komisyon içeren ata) arkasına konur → seçeneğin altında;
    `width:100%; flex:0 0 100%; grid-column:1/-1` ile flex/grid içinde de satır kaplar.
  - `manifest.json` v1.2.0: partner betiği `https://*.trendyol.com/*` (www hariç) + `all_frames: true`.
  - iframe'de yol kontrolü üst pencereden; başka kökense yalnız veri bulunan radyolara kutu yazılır
    (model kodu/fiyat/komisyonun hepsi boşsa yazılmaz).
  - Açık shadow root'lara inen arama (`hepsi`), shadow sınırını aşan üst (`ust`); shadow
    değişiklikleri gözlemciye düşmediği için 2 sn yoklama.
  - Konsola `[Kâr Marjı] radyo sayısı: N <url>` (debug) — teşhis için.
- **Sonuç / doğrulama:** Sahte sayfada 4 normal + 1 shadow DOM seçenek: 5 kutu, hepsi seçenek kabının
  hemen arkasında. npm test 7/7. Gerçek rate-card'da doğrulama kullanıcıda.
- **Commit:** `faa4e46` — Partner: JSON kutusu secenegin altina; iframe ve shadow DOM destegi

### Açık
- rate-card hâlâ gelmezse: kullanıcıdan konsoldaki "[Kâr Marjı]" satırları (Ayrıntılı/Verbose seviye)
  ve bir seçeneğin outerHTML'i istenecek.

### 3. v1.3.0 — barkod (satırı aç, ilk barkodu oku)
- **Neden:** Kullanıcı: her satırda `<div data-testid="expanded-toggle" class="expanded-wrapper">`
  düğmesine basıp altındaki ilk `<span class="barcode-info-item-value">` barkodu JSON'a eklensin.
- **Ne yapıldı (`src/partner.js`):**
  - `satirAcici(radyo)`: radyodan yukarı, içinde tam 1 açıcı olan ilk ata → o satırın açıcısı
    (>1 ise belirsiz, null).
  - `barkodBul(acici)`: kök düğümde `ACICI, BARKOD` belge sırasıyla taranır; açıcıdan sonra, bir
    sonraki açıcıdan önceki ilk barkod. Ayrıntı satırın içinde de kardeşinde de olsa çalışır.
  - Kuyruk tek tek işlenir: barkod DOM'da yoksa `click()`, 150 ms aralıkla 3 sn'ye kadar beklenir,
    tekrar `click()` ile kapatılır. Sonuç WeakMap önbellekte (açıcı → barkod|null), tekrar basılmaz.
    Her barkoddan sonra kutular yeniden yazılır.
  - JSON: `{"modelKodu","barkod","price","commission"}`.
- **Sonuç / doğrulama:** Sahte sayfa: 2 satır (ayrıntı biri kardeş, biri iç; 400 ms gecikmeli, 2.
  satırda 2 barkod). 3 kutu doğru barkodla, 4 tıklama (aç+kapat ×2), sonda açık ayrıntı yok. npm test 7/7.
- **Commit:** `98b83c2` — Partner: satiri acip ilk barkodu oku, JSON'a barkod ekle (v1.3.0)

### 4. v1.4.0 — tıklama yerine API yanıtlarını yakalama
- **Neden:** Kullanıcı: "dur veya ... buradan değerleri yakalayabilir misin, tüm değerleri JSON
  getir". Panel ürün listesini şu uçlardan alıyor (kullanıcı örnek yanıt yapıştırdı):
  - `https://apigw.trendyol.com/partner/sellereng-scout-scw-ty-plus-scout-bff/products?page=0&size=10&sortFilter=FAVORITE_COUNT&stockFilter=IN_STOCK&scheduledFilter=ALL&tyPlusGroupId=…&divisionType=SECOND_SECTION`
  - `https://apigw.trendyol.com/partner/sellereng-scout-scw-rate-card-scout-bff/products?page=0&size=10&sortFilter=ORDER_COUNT&stockFilter=IN_STOCK&scheduledFilter=ALL&rateCardPriceGroup=…&divisionType=SECOND_SECTION`
- **Yanıt biçimleri:** `content[]` → ürün (`code` = model kodu, `imageUrl`, `barcodePriceStockDetails[]`,
  `productPriceStockDetails.rateCardPrices` barem tablosu).
  - ty-plus kalem: `priceCommissionDto{sellingPrice, discountedPrice, sellerCoveredDiscountedCommission}`,
    `tyPlusPrices[0]{plusPrice, plusCommission, active}`; `id` metin, `contentId` sayı.
  - rate-card kalem: `commission`, `price{sellingPrice, discountedPrice, buyerDiscountedPrice, displayPrice}`,
    `scheduledPrice.scheduledPrice`, `rateCardPrices[].active`; `id` = contentId (sayı).
  - Her ikisinde `finalPrice{discountedPrice, buyboxOrder, scheduledPrice.name}`.
- **Ne yapıldı:**
  - `src/partner-yakala.js` — `world: "MAIN"`, `document_start`, `all_frames`: `fetch` ve
    `XMLHttpRequest` sarılır, `/scout-bff\/products/` yanıtının kopyası (`res.clone().json()`)
    `window.postMessage({tkm:'partner-urunler', url, veri}, location.origin)`. Son 30 yanıt tamponda;
    içerik betiği geç yüklenirse `{tkm:'partner-iste'}` mesajıyla yeniden gönderilir.
  - `src/partner-veri.js` (UMD, saf): `yanitCevir(url, veri)` → `{kaynak, urunler:[{ozet, ham}]}`;
    özet: kaynak, contentId, modelKodu, ad, renk, kategori, toplamStok, baremler[{barem 1-4,
    komisyon, min, max, aktif?}], barkodlar[{barkod, beden, stok, stokKodu?, satisFiyati,
    indirimliFiyat, komisyon, (ty-plus) plusFiyat/plusKomisyon/plusAktif | (rate-card) aliciFiyati/
    gorunenFiyat/planlananFiyat, sonFiyat, fiyatTuru?, buybox?}], gorselAnahtari.
  - `src/partner.js`: ürün ↔ satır eşleme `imageUrl` son klasörü (uuid) ile `<img src>` içinde;
    satır = görselden yukarı, başka dsmcdn ürün görseli içermeyen en üst ata. Satırın arkasına
    `div.tkm-urun-json` (TR ise yeni `tr>td colspan`): özet JSON (barkod başına bir satır, geçerli
    JSON) + "JSON kopyala" + `<details>` Ham JSON. Radyo kutusu barkodu artık API'den
    (satırın ilk barkodu). Satır açıp kapatma (v1.3.0 kuyruğu) tamamen kaldırıldı.
  - `manifest.json` v1.4.0: 3 content_scripts girdisi (www; partner MAIN yakala; partner veri+partner).
- **Dokunulan dosyalar:** `src/partner.js`, `src/partner-veri.js`, `src/partner-yakala.js`,
  `manifest.json`, `README.md`, `test/partner-veri.test.js`, `test/ornek/{ty-plus,rate-card}.json`
- **Sonuç / doğrulama:** `npm test` 12/12 (5 yeni: iki biçim, barem, görsel anahtarı, tanınmayan
  yanıt). Uçtan uca: yerel http sunucuda sahte sayfa, sahte panel fetch'i gerçek ty-plus yanıtını
  döner → yakalama mesajı geldi, panel yanıtı bozulmadan aldı, kutu doğru satırın altında, radyo
  `{"modelKodu":"6800","barkod":"8699170321323","price":829.8,"commission":11.2}`. İlk denemede kutu
  listenin sonuna düşmüştü (yalnız eşleşen görseller sınır sayılıyordu) → tüm dsmcdn görselleri sınır.
- **Commit:** `05f7d9c` — Partner: scout-bff/products API yanitlarini yakala, satir altina urun/barkod JSON (v1.4.0)

### Açık
- Gerçek panelde doğrulama kullanıcıda. Tek ürünlük sayfada satır sınırı bulunamaz (kutu en dışa düşer).
- Görsel eşleşmezse (panel başka CDN/küçültme adresi kullanıyorsa) kutu çıkmaz → konsol
  `[Kâr Marjı] {"radyo":…,"urun":…,"eslesen":…}` satırına bakılacak.

### 5. v1.5.0 — satır eşleme: ad + model kodu + renk
- **Neden:** Kullanıcı: "bulmadı" (görsel uuid eşlemesi gerçek panelde tutmadı). Önerisi: model kodu +
  renk ya da ürün adı (`<span class="overflow-text overflow-text-link">Pierre Cardin 6234 Premium …</span>`,
  ekranda marka önekli).
- **Ne yapıldı:**
  - `partner-veri.js`: `norm` (tr küçük harf, tek boşluk, tüm tire türleri "-"), `eslesmePuani(ozet,
    {ad, modelKodu, metin}, marka)`: ad eşit / marka+ad eşit / ekran adı " "+ad ile bitiyor → +4,
    model kodu → +2, (biri tuttuysa) renk satır metninde → +1. `ata(urunler, satirlar)`: tüm çiftler
    puana göre azalan, açgözlü; her satır ve ürün en çok bir kez. Ürüne `marka` (= `brand`) eklendi.
  - `partner.js`: çapa = "Model Kodu:" yazan en içteki span (yoksa `.overflow-text-link`);
    satır = çapadan yukarı içinde tek çapa kalan en dış ata. Ürün havuzu sayfa türüne göre
    (rate-card / ty-plus) süzülür, anahtar `kaynak:contentId`. Görsel eşleme kaldırıldı.
  - Sol altta sabit rozet: "Kâr Marjı · N ürün yakalandı · M/K satır eşleşti" (teşhis konsolsuz).
- **Sonuç / doğrulama:** npm test 15/15 (3 yeni: puan, aynı ad 3 renk, yalnız model kodu).
  Sahte panel (görselsiz, 3 × "Kadın 6216 Balenli…" Pudra/Siyah/Ekru, marka önekli ad):
  3/3 doğru renk ve barkod (SİYAH↔Siyah tr küçük harfle), radyolar doğru barkodla.
- **Commit:** `e702cec` — Partner: satiri ad + model kodu + renk puaniyla esle, durum rozeti (v1.5.0)
- **Açık:** rozet "0 ürün yakalandı" derse sorun yakalamada (MAIN world betiği / iframe); "N ürün, 0 satır"
  derse çapa (Model Kodu span'ı) bulunamıyor.
