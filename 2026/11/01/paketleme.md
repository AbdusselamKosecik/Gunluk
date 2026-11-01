# paketleme — 2026-11-01

## Bağlam
Kullanıcı: paket (koli) ve ürün etiketinde ürün kodu yazılsın/yazılmasın parametrik olsun; Kodu/adı satırının yazı boyu
ve kalınlığı da parametrik olsun.

## Yapılanlar

### 1. Etiket kod/ad satırı Ayarlar'dan
- **Neden:** Kod 13.10.2026'da sabit olarak kaldırılmıştı; müşteriye göre açılıp kapanabilmeli, yazı boyu/kalınlığı ayarlanabilmeli.
- **Ne yapıldı:**
  - `Ayarlar` (yerel ayarlar.json, makine başına): `UrunEtiketKodYaz` (false), `UrunEtiketAdPuntoMm` (2.8), `UrunEtiketAdKalin` (true),
    `KoliEtiketKodYaz` (false), `KoliEtiketAdPuntoMm` (3.0), `KoliEtiketAdKalin` (false). Varsayılanlar eski baskıyla birebir.
  - `EtiketYazisi(KodYaz, PuntoMm, Kalin)` record'u (`UrunEtiketi.cs`); `UrunEtiketi.Zpl(..., yazi)` ve `KoliEtiketi.Zpl(e, dpi, yazi)` opsiyonel parametre.
  - `UrunEtiketi.KodAdMetni(kod, ad, kodYaz)`: kodsuzsa eski `UrunAdi` (addaki kod öneki kırpılır), kodluysa "kod ad".
  - Ürün etiketi: kod/ad satırının alt kenarı sabit (6,8 mm); yazı büyüyünce üst 4 mm boşluğa doğru büyür (en çok 6 mm),
    beden ve barkod yerinden oynamaz. Koli: MODEL satırı 3 mm üstünde yukarı büyür (en üst 37,2 mm, en çok 6,5 mm), matris yerinde;
    satıra sığmayan kırpılır (`Sigdir`). Koli etiketinde kod kapalıyken ad eskisi gibi kırpılmadan basılır.
  - Ayarlar ekranı: iki NumericUpDown (yazı boyu) + dört CheckBox; metinler TR/EN/AR (`OrtakMetinler.cs`).
- **Dokunulan dosyalar:** `Paketleme/Ortak/Veri/Ayarlar.cs`, `Paketleme/Ortak/Giris/AyarlarView.axaml`, `AyarlarViewModel.cs`,
  `Paketleme/Ortak/Dil/OrtakMetinler.cs`, `Paketleme/Ekranlar/Veri/UrunEtiketi.cs`, `KoliEtiketi.cs`, `Paketleme.Tests/UrunEtiketiTestleri.cs`
- **Komutlar:** `dotnet test Paketleme.Tests` (166 geçti, 57 DB testi atlandı), `dotnet build Paketleme.Desktop`
- **Sonuç / doğrulama:** Yeni testler: KodAdMetni teorisi, kodlu baskı, 4 mm normal yazı konumu (^FO12,22 ^A0N,32), varsayılan konum değişmedi (^FO12,32), koli 5 mm kalın kodlu.
- **Commit:** `85f2dae` — Etiket: urun ve koli etiketinde kod yazilsin mi, kod/ad yazi boyu ve kalinligi Ayarlar'dan

## Kararlar
- Ayarlar yerel (makine başına) — etiket ölçüleri de orada; UZM_Ayar'a (şirket geneli) taşınmadı.
- "Yazı karakteri" = boy + kalınlık; Zebra'da ölçeklenebilir tek font ^A0 olduğu için font ailesi seçimi eklenmedi.

## Açık kalanlar / sonraki adım
- Gerçek yazıcıda büyük punto (5–6 mm) denemesi; yayın paketi (dagitim/yayinla.ps1) üretilmedi.
