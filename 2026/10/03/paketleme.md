# paketleme — 2026-10-03

## Bağlam
Kullanıcı Paketleme uygulamasını yeniden tarif etti: (1) siparişe göre yan yana 2'li Zebra ürün etiketi,
(2) sevkiyat kolisi — ürün barkodu okutulur, set ise koli kapanınca 10 ile girer, bileşenleri 130 ile sarf edilir;
1K/2K ayrımı, stok kontrolü, terazi, koli listesi + yeniden yazdır, (3) sevkiyat (Frederic gibi) — en son, ayrı uygulama.
Bu tur yalnız tasarım (brainstorming → yazılı spec). Kod yok.

## Yapılanlar

### 1. Keşif
- **Referans (Frederic `PaketlemeVeSevkiyat`):** sipariş/ürün etiketi YOK, 130 ve koli tanımı YOK (fiş tipleri 2/10/16/120,
  iş SP içinde: `UZM_Sevkiyat_BarcodeProcess(2)`, `UZM_Sevkiyat_BoxRead`). Tartı: seri port 9600 8N1, V1 `"+ 45.32kg"`,
  V2 `"=  1.12F0"` (F kararlı). Dara 1,1 kg. Koli etiketi ZPL `Output.prn` (warehouse reposunda örnek).
- **Set içeriği:** sentezservis `docs/superpowers/specs/2026-10-03-karma-koli-design.md` →
  `UZM_KarmaKoli(SetVariantId)` + `UZM_KarmaKoliIcerik(IcerikVariantId, Miktar)`. SentezCore'da henüz YOK.
- **SentezCore (salt-okuma, `uzman`, DPAPI ayarlar.json'dan):** depolar 1 General, 40 Reserved, 41 M Product, 42 U Uretim.
  Fiş 130: 3 kayıt, `OutWarehouseId` dolu (çıkış). 120: Out 41. 10: bantsayim'in 1 kaydı (In 42).

### 2. Kullanıcı kararları
- Etiket = ürün etiketi (ürünün Sentez barkodu), **2 × 50×30 mm**.
- Okutulan = ürünün kendi barkodu. Set: 10 → **yeni ayrı paketleme deposu**, 130 → 42'den; kalite `QualityTypeId` ile.
- Tekli ürün: 10/130 yok, aynı ürün koliye girer.
- Koli **yalnız siparişe** bağlı. Siparişte olmayan / 1K'da miktarı aşan **engellenir**. 2K siparişe bağlı ama ayrı sayılır.
- Fişler **koli kapanınca** (günlük tek başlık/tip, kalem koli başına — bantsayim kalıbı).
- Yaklaşım 1: bantsayim kalıbı (C# + Dapper transaction, SP yok, FisYazici tip/yön parametreli, Ortak SURUM 3 ZPL).
- Sevkiyat: en son, ayrı `sevkiyat` uygulamasında.

### 3. Spec
- **Dosya:** `docs/superpowers/specs/2026-10-03-paketleme-etiket-koli-design.md`
  (tablolar `UZM_PaketKoli`, `UZM_PaketOkutma`; koli kodu `PK{K}-{SiparisNo}-{NNN}`; stok = 42 kalite stoğu − açık
  kolilerdeki set bileşenleri − sevk edilmemiş tekli ürünler; ekranlar Etiket / Koli liste / okutma / tartı).
- **Commit:** `7c8cf09` — Paketleme: urun etiketi + sevkiyat kolisi tasarim dokumani (gitlab origin)

## Kararlar
- 15.09 spec'inin paketleme bölümü (Box Aç, siyah/beyaz eşleştirme, UZM_Paket_* SP) geçersiz; eski ekranlar silinecek.

## Açık kalanlar / sonraki adım
- Kullanıcı spec'i inceleyecek → onaylarsa writing-plans.
- Sentez'de paketleme deposu açılacak (RecId → `UZM_Ayar.PaketlemeDepoId`).
- Karma koli tabloları (sentezservis) kurulmadan okutma çalışmaz.
- Ürün ve koli etiketi aynı yazıcı mı? (plan sırasında sorulacak)
