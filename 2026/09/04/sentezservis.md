# SentezServis — 2026-09-04

## Bağlam

03 gecesi başlayan ve gece yarısını aşan tek bir tur. 03'ün defterinde pazaryeri hesap
parametre ekranı ve paketleme var; bu dosya onun devamı olan **cari aktarımı** işini anlatır.

Hedef: pazaryeri siparişlerinden cari kartı üretip Sentez'e yazmak. Kullanıcının koyduğu akış
(onaylandı):

> "goc yok. once bizim sisteme aktarilacak, bizim sistemden Senteze aktarilacak, bizim
> sistemden kullanicilara atama yapilacak ve sentez siparisleri guncellenecek. E faturami,
> e arsif mi biz kara verecegiz"

ve kesin sınır:

> "hicbir sekilde SentezCore2026 db sine birsey yazmayacaksin. bu entegrasyonlar icin.
> parametreye ekle ben istedigimde dbyi degistreyim. entegrasyon db si diye"

## Yapılanlar

### 1. Ayrı bir yazma bağlantısı — `EntegrasyonBaglantiCumlesi`

- **Neden:** Canlı ERP (`SentezCore2026`) Şart B-10 gereği salt okunur ve öyle kalmalı. Cari
  yazımını oraya bağlamak, tek bir yapılandırma hatasıyla canlıya yazmak demekti. Kullanıcı da
  açıkça yasakladı; şimdilik hedef `SentezCore2026Test`.
- **Ne yapıldı:** `Ayarlar.EntegrasyonBaglantiCumlesi` alanı ve
  `BaglantiFabrikasi.EntegrasyonAcAsync` eklendi. Bağlantı tanımsızsa metod açık bir
  `InvalidOperationException` atar — sessizce ERP'ye düşmez.
- **Dokunulan dosyalar:** `src/SentezServis.Core/Ayarlar.cs`,
  `src/SentezServis.Core/Data/BaglantiFabrikasi.cs`,
  `src/SentezServis.Host/appsettings.json` (gitignore'lu).
- **Sonuç:** Canlıya geçmek tek bir bağlantı cümlesi değiştirmek.

### 2. Göç 013 — `pazaryeri_carileri`

- **Neden:** Sipariş → Sentez tek adımda yapılmıyor; araya bizim tablomuz giriyor ki ne
  yazılacağı önce görülebilsin, atama ve e-fatura kararı da orada tutulsun.
- **Ne yapıldı:** Parmak izi `(sirket_kodu, pazaryeri, paket_no)` UNIQUE; `cari_kodu` +
  `sira_no`; iletişim/adres kolonları; `musteri_muhasebe_kodu` / `satici_muhasebe_kodu`;
  `efatura_durumu` (varsayılan `bilinmiyor`) + `efatura_etiketi` + sorgu zamanı; `durum`
  (`bekliyor`/`aktarildi`/`hata`/`atlandi`), `hedef_veritabani`, `erp_rec_id`,
  `erp_adres_rec_id`, `aktarim_mesaji`; `atanan_kullanici_id` + `atama_zamani`.
- **Dokunulan dosyalar:** `src/SentezServis.Core/Data/Migrations/013_pazaryeri_carileri.sql`
- **Sonuç:** Canlıda uygulandı.

### 3. Cari kodu standardı — `PRK-[şirket][7 hane]`

- **Neden:** ERP'deki mevcut önekler kaotik (04/Trendyol'da TTKT 363.814, TKT0 76.097,
  VTKT 22.382, TRY0 72). Kullanıcı tek standart istedi; şirket kodunun içeride durması "bir
  sıkıntı olursa bulalım" içindi.
- **Ne yapıldı:** `CariKodu.Uret / SiraOku / Deseni`. 7 hane seçildi: 04'te 467.312 cari var,
  günde ~1.400 artıyor — 6 hane iki yılda dolardı. Sıra `sp_getapplock` altında, işlem içinde
  verilir; üretim turu **bizim en büyük sıramız ile hedefteki en büyük `PRK-` sırasının
  büyüğünden** devam eder, böylece tablomuz silinse bile kod ikinci kez dağıtılmaz. Biçime
  uymayan eski kodlar hesaba katılmaz.
- **Dokunulan dosyalar:** `src/SentezServis.Core/Pazaryerleri/Cariler/CariKodu.cs`,
  `CariDeposu.cs`

### 4. İki iş: üret ve aktar

- **Neden:** Üretim ağ kullanmaz ve ERP erişilemezken bile çalışır; aktarım dış bir sisteme
  yazar ve ne yazdığı görülmeden koşmamalı.
- **Ne yapıldı:**
  - `pazaryeri-cari-uret` — siparişten cari üretir, **yalnızca bizim** tablomuza yazar. Carisi
    olan sipariş SQL tarafında `NOT EXISTS` ile hiç okunmaz (sıra numarası boşuna harcanmasın).
  - `pazaryeri-cari-aktar` — bekleyenleri entegrasyon DB'sine yazar. **Cron'u yok ve
    olmayacak.** Hedef adı tek satır yazmadan önce okunur. Bir satırın patlaması turu
    durdurmaz; hata satıra yazılır ve devam edilir.
- **Dokunulan dosyalar:** `PazaryeriCariUretJob.cs`, `PazaryeriCariAktarJob.cs`,
  `CariUretici.cs`, `SentezCariYazici.cs`, `src/SentezServis.Host/Program.cs` (DI kayıtları)
- **Karar:** Unvan sırası fatura unvanı → müşteri adı → teslimat adı; üçü de boşsa cari
  **üretilmez** (adsız bir kart ERP'de aranamaz). `SpecialCode` = pazaryeri adı, ERP'deki
  mevcut sözlükle birebir.

### 5. Kırılma — "String or binary data would be truncated"

- **Neden:** İlk canlı denemede 04 için 5 cariden 2'si düştü. Sebep sanılan unvan değildi:
  düşen satırların unvanı 11 ve 13 karakterdi, **adresleri** 59 ve 60 karakterdi.
- **Ne yapıldı:** Gerçek kolon genişlikleri sorgulandı — `CurrentAccountName` nvarchar(**50**),
  `Erp_Address.Line1/Line2/Line3` ve `Explanation` nvarchar(**50**), `SpecialCode` 15,
  `CurrentAccountCode` 25, `TaxNo` 25, `EInvoiceAlias` 100, `PostalCode`/`Phone` 50.
  `SentezAlanSinirlari` yazıldı: **unvan kırpılır, adres BÖLÜNÜR** — üç satıra ve kelime
  sınırında, 150 karaktere kadar hiçbir şey kaybolmaz. Eski ERP kayıtları da aynı deseni
  kullanıyor. Yazıcı `Line3`'ü de INSERT'e aldı.
- **Dokunulan dosyalar:** `SentezAlanSinirlari.cs`, `SentezCariYazici.cs`
- **Komutlar:**
  ```sql
  UPDATE dbo.pazaryeri_carileri SET durum='bekliyor', aktarim_mesaji=NULL WHERE durum='hata';
  ```
  ```bash
  dotnet run --no-build cari 04   # scratchpad/baglantidene sondası
  ```
- **Sonuç / doğrulama:** `SentezCore2026Test: 5 cari yazıldı.` — hatasız. Hedefte
  `PRK-040000009..013` kontrol edildi: kod, unvan, `SpecialCode='Trendyol'`, üç satıra bölünmüş
  adres, çözülmüş `CityId`/`DistrictId` doğru.

### 6. Shopify il/ilçe düzeltmesi

- **Neden:** Canlı veride 2.608 siparişin **2.608'inde de** `province` null; mağazanın adres
  formu il alanını toplamıyor. Şehir `Ilce`'ye düşüyor, `Il` boş kalıyordu — ERP adresleri ilsiz
  yazılırdı.
- **Ne yapıldı:** `province` boşsa `city` il olarak kullanılır, ilçe null bırakılır.
- **Dokunulan dosyalar:** `src/.../Saglayicilar/ShopifySaglayici.cs`
- **Açık:** Bu düzeltmenin kayıtlı 2.608 satıra yansıması için Shopify siparişleri **yeniden
  çekilmeli**; henüz yapılmadı.

### 7. Testler ve belge

- **Ne yapıldı:** `CariUretimTestleri` (kod biçimi, unvan sırası, adsız sipariş, alan sınırları,
  adres bölme) ve `CariYaziciSinirTestleri` (kaynak taramalı: yazıcıda `ErpAcAsync` yok, cron
  yok, hedef yazmadan önce okunuyor, adres bölünerek yazılıyor). 342 → **372**, tamamı geçiyor.
- **Dokunulan dosyalar:** `tests/SentezServis.Core.Tests/CariUretimTestleri.cs`,
  `CariYaziciSinirTestleri.cs`, `docs/pazaryeri-carileri.md`, `docs/api-kontrat.md`
- **Commit:** `5db3a30` — Pazaryeri carileri: uretim ve Senteze aktarim (PRK- kodu)

## Kararlar

- **Cari başına sipariş** (müşteri başına değil). Veri destekliyor: 462.366 satıra karşı
  460.711 ayrı e-posta, `TaxNo` alanında 9 ayrı değer (462 binde `11111111111`).
  Tekilleştirilecek gerçek bir kimlik yok.
- **E-fatura/e-arşiv kararını biz veriyoruz**, kaynak CRS. WSDL'de `FilterEInvoiceUsers` ve
  `GetUserAliasses` mevcut. Varsayılan `bilinmiyor` bırakıldı, `earsiv` değil: sorulmamış bir
  soruyu cevaplanmış göstermek, yanlış senaryoyla kesilmiş faturayı kimseye fark ettirmezdi.
  Bugün ERP'deki 462.470 pazaryeri carisinin tamamı e-arşiv.
- **Göç yok.** Eski TTKT/TKT0/VTKT kayıtları dönüştürülmüyor; yeni standart yalnızca yeni
  kartlara uygulanıyor.

## Açık kalanlar / sonraki adım

1. CRS `FilterEInvoiceUsers` + `GetUserAliasses` çağrısı — e-fatura/e-arşiv kararı (kolonlar
   hazır, çağrı yazılmadı).
2. Cari ekranı + API uçları (`CariDeposu.ListeleAsync`/`SayaclarAsync` var, `CariUclari.cs` ve
   React sayfası yok).
3. Siparişin iç kullanıcıya atanması (kolon var, uç/ekran yok).
4. Sentez siparişlerinin güncellenmesi (4. aşama, hiç başlanmadı).
5. Shopify siparişlerini yeniden çek (madde 6).
6. **Devam eden:** FortiGate API anahtarı ve `sa` parolası eski paket zip'lerinde açıkta —
   döndürülmeli. Eski zip'lerin depodan çıkarılma kararı bekliyor.
7. Ekran hâlâ tarayıcıda açılmadı (yönetici girişi yok).
