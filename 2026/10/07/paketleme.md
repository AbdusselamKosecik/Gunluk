# paketleme — 2026-10-07

## Bağlam
Paketleme uygulamasında tek Zebra yazıcı vardı; hem 2'li ürün etiketi (50×30) hem 10×10 koli etiketi aynı
IP'ye gidiyordu. İstek: koli etiketi ayrı bir yazıcıdan çıksın, ürün etiketi 45×20 mm ve yeni içerikle basılsın.

## Yapılanlar

### 1. Ayrı koli yazıcısı
- **Neden:** Ürün etiketi (45×20 rulo) ile koli etiketi (10×10 rulo) farklı yazıcılarda.
- **Ne yapıldı:**
  - `Ayarlar`'a `KoliYaziciIp`, `KoliYaziciPort` (9100), `KoliYaziciDpi` (203) eklendi.
  - `ZplYazici.KoliTanimli` ve `ZplYazici.KoliGonderAsync(zpl)` eklendi (mevcut `GonderAsync(ip, port, zpl)` üstüne).
  - `KoliEtiketi.BasAsync` artık `KoliGonderAsync` + `KoliYaziciDpi` kullanıyor.
  - `KoliListeViewModel.EtiketTekrar` ve `KoliOkutmaViewModel` (koli kapatınca otomatik basım) `KoliTanimli`
    kontrol ediyor; tanımsızsa yeni `KoliYaziciTanimsiz` mesajı.
  - Ayarlar ekranına 3 alan (Koli yazıcı IP / port / DPI); mevcut alan etiketleri "Etiket yazıcı ..." oldu (tr/en/ar).
  - Koli IP boşsa etiket yazıcısına **düşülmez** (10×10'u 45×20 rulo üstüne basmamak için) — bilerek.
- **Dokunulan dosyalar:** `Paketleme/Ortak/Veri/Ayarlar.cs`, `Ortak/Donanim/ZplYazici.cs`,
  `Ortak/Giris/AyarlarView(Model)`, `Ortak/Dil/OrtakMetinler.cs`, `Ekranlar/UygulamaMetinleri.cs`,
  `Ekranlar/KoliListeViewModel.cs`, `Ekranlar/KoliOkutmaViewModel.cs`, `Ekranlar/Veri/KoliEtiketi.cs`, `README.md`
- **Sonuç:** Koli etiketi düzeni değişmedi (zaten bantsayim BoxEtiketi ile aynı 10×10).

### 2. Ürün etiketi 45×20, yan yana 2'li
- **Neden:** Yeni etiket rulosu 45×20 mm; içerik sadeleşti, menşe ibaresi gerekli.
- **Ne yapıldı (`Ekranlar/Veri/UrunEtiketi.cs`, `Ciz`):**
  - y=1 mm, 2,4 mm: ürün kodu + ürün adı (ad kodla başlıyorsa kod tekrar yazılmaz).
  - y=3,9 mm, 2,6 mm: `beden · renk`.
  - y=7 mm: EAN-13 (^BE, 95 modül ≈ 23,75 mm @203dpi), yükseklik `max(4, y-14)` = 6 mm; EAN değilse Code128.
  - Altında okunur barkod (2 mm), en altta `MADE IN EGYPT` (y-3,4, 2,2 mm, ortalı).
  - Sipariş no / müşteri etiketten kaldırıldı; `UrunEtiketBilgisi.SiparisNo/Musteri` alanları silindi.
  - Varsayılan `EtiketGenislikMm=45`, `EtiketYukseklikMm=20`; `AyarDeposu.Yukle` eski varsayılan 50×30 görürse
    45×20'ye çeviriyor (elle girilmiş başka ölçüye dokunmuyor).
- **Testler:** `Paketleme.Tests/UrunEtiketiTestleri.cs` 45×20'ye göre: `^PW736` (45+2+45)×8, `^LL160`,
  sağ etiket ilk metin `^FO388,`, içerikte "38 · SİYAH-BEYAZ" ve "MADE IN EGYPT".
- **Komutlar:**
  ```bash
  cd X:/Gitlab/modfex-apparel/paketleme
  dotnet test Paketleme.Tests   # 31 geçti, 22 DB testi atlandı
  ```
- **Sonuç / doğrulama:** Testler geçti. `Paketleme.Desktop` build'i yalnızca exe çalışır/VS kilitli olduğu için kopyalama
  adımında takıldı; kütüphane derlendi. Gerçek yazıcıda baskı denenmedi.
- **Commit:** `5bd374b` — Ayrı koli yazıcısı; ürün etiketi 45x20 (kod+ad, beden·renk, EAN-13, MADE IN EGYPT)

## Kararlar
- Koli yazıcısı tanımsızsa etiket yazıcısına fallback yok; kullanıcıya "Koli yazıcı IP'si tanımlı değil" gösterilir.
- Etiket ölçüleri hâlâ Ayarlar'dan değiştirilebilir; yerleşim mm sabitleriyle 20 mm yüksekliğe göre ayarlı.

## Açık kalanlar / sonraki adım
- Sahada: Ayarlar'a koli yazıcı IP'si girilmeli (güncellemeden sonra koli etiketi basılmaz, uyarı verir).
- 45×20 rulo ile gerçek Zebra'da deneme baskısı; gerekirse `EtiketAra`/`EtiketSol` ince ayarı.
