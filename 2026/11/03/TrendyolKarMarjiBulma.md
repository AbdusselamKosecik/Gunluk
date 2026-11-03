# TrendyolKarMarjiBulma — 2026-11-03

## Bağlam
Kullanıcı: "Bir Chrome extension yazar mısın, proje yapar mısın, GitLab'a atar mısın: TrendyolKarMarjiBulma". Kapsam sorusuna "Chrome'a ekler misin" dedi → varsayılan tasarımla başlandı; yolda "fiyatın altına Mahmutcan yazmak istiyorum" eklendi.

## Yapılanlar

### 1. Chrome uzantısı (Manifest V3, derlemesiz düz JS)
- **Neden:** Trendyol ürün sayfasında net kâr / marj görmek; formül şirketin Sentez Servis rayiç hesabıyla aynı olmalı.
- **Formül kaynağı:** `sentezservis/src/SentezServis.Core/Rayic/RayicHesaplayici.cs` + `RayicModelleri.cs` varsayılanları
  (kargo 67, iade %10, hizmet 5,49, komisyon %10 → `kdvli × oran / 1,2`, stopaj %2 KDV'siz üzerinden, KDV %10, hedef %40; hedef fiyat kapalı formül).
- **Sayfa yapısı (canlı, Chrome DevTools MCP ile):** ana ürün kabı `.product-details-product-details-container`; fiyat `.price-wrapper .new-price` (müşterinin ödediği, sepet indirimi dahil, ör. 1.091 TL) ve `.old-price` (liste, 1.146 TL); JSON-LD `Product.offers.price` = 1091.00. Benzer ürün kartlarında da `.new-price` var → arama ana kap içinde.
- **Dosyalar:** `manifest.json`, `src/hesap.js` (saf hesap + `tutarOku`, node'da da yüklenir), `src/ayarlar.js` (chrome.storage: ayarlar sync, ürün maliyeti local `urun:<id>`), `src/sayfa.js` (fiyat/ürün okuma), `src/icerik.js` (fiyat altı satırı + Shadow DOM panel, SPA adres/yeniden çizim izleme), `src/arkaplan.js`, `popup.html` + `src/popup.js` (hızlı hesap), `ayarlar.html` + `src/ayarlar-sayfasi.js` (fiyatAltiYazi varsayılan "Mahmutcan"), `stil.css`, `araclar/simge-uret.js` (bağımlılıksız PNG simgeler), `test/hesap.test.js`, `README.md`.
- **Komutlar:**
  ```bash
  npm test            # node --test → 7/7 (not: Node 24'te `node --test test/` klasör kabul etmiyor)
  node araclar/simge-uret.js
  ```
- **Doğrulama:** uzantı otomasyon tarayıcısına yüklenemediği için 4 içerik betiği sahte chrome.storage ile canlı ürün sayfasına enjekte edildi (ürün 1209922103, maliyet 250): fiyatın altında "Mahmutcan" + "Kâr 551,88 TL · marj %55,6"; panel dökümü elle hesapla tutarlı, ekran görüntüsüyle bakıldı.
- **GitLab:** `git@gitlab.com:modasima/trendyol-kar-marji-bulma.git` (push ile oluşturuldu, gizli), dal `main`.
- **Commit:** ilk commit — Trendyol kar marji Chrome uzantisi (Manifest V3)

## Kararlar
- Varsayılan satış fiyatı = müşterinin ödediği (sepet indirimi dahil); liste ve elle seçenekleri var (indirimi kimin karşıladığı sayfadan anlaşılmıyor).
- Maliyet KDV hariç TL, ürün bazında tarayıcıda saklanır; dışarı veri gitmez.
- `innerHTML` yalnızca kendi biçimlendirdiğimiz sayılar için; sayfa metni `textContent`.

## Açık kalanlar
- Kullanıcının Chrome'una kurulum elle: `chrome://extensions` → Geliştirici modu → Paketlenmemiş öğe yükle → `X:\Gitlab\Modasima\TrendyolKarMarjiBulma` (sayfa açıldı, yol panoya kopyalandı).
- İleride: maliyetin Sentez Servis/ERP'den barkodla otomatik gelmesi; kategori bazlı komisyon tablosu.
