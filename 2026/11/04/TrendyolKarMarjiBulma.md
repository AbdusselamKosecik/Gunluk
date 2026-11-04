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
