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

---

## Yapılanlar (ikinci tur) — siparişlerin Sentez'e aktarımı

Kullanıcı: *"Siparişleride ayni pantentle kaydedebilirmisin?"* ve ürün eşleşmesi için
*"Barkoda gore cozmemiz lazim. ornek sp var"*.

### 8. Şema keşfi ve örnek SP

- **Neden:** Fiş yazmadan önce ERP'nin siparişi nasıl tuttuğunu ve mevcut entegrasyonun ne
  yazdığını bilmek gerekiyordu; uydurma alan kümesiyle yazılan fiş eskilerden ayırt edilirdi.
- **Ne yapıldı:** Tablolar `Erp_OrderReceipt` / `Erp_OrderReceiptItem` /
  `Erp_OrderReceiptItemVariant`. Canlıdan tek bir gerçek Trendyol fişi (RecId 1081657) ve
  kalemi XML olarak döküldü, alan kümesi birebir ondan alındı.
- **Kullanıcının işaret ettiği SP bulundu:** `dbo.UZM_FindBarcode`. Kural:
  `Erp_InventoryBarcode.Barcode = @Barcode`, `Erp_Inventory.CompanyId = @CompanyId`,
  `ISNULL(InUse,1)=1`; KDV `Erp_Inventory.VatId → Erp_Tax.Rate`, birim
  `Erp_InventoryUnitItemSize.IsMainUnit=1`. Yazıcı bunu birebir uyguluyor.
- **Ölçüm:** kayıtlı kalemlerde eşleşme — 04/Trendyol 6507/6507, 03/Trendyol 4420/4420,
  Boyner 67/67, Pazarama 35/35. **Shopify 0/10.661** çıktı: barkodu `barkod` alanına değil
  `stok_kodu`na (SKU) koyuyor; oradan bakınca 10.633/10.661. Çözücü iki alanı sırayla deniyor.
- **Komutlar:**
  ```bash
  sqlcmd -d SentezCore2026 -Q "SELECT OBJECT_DEFINITION(OBJECT_ID('dbo.UZM_FindBarcode'))"
  ```

### 9. Göç 014 + iki iş

- **Ne yapıldı:** `pazaryeri_siparis_aktarimlari` defteri (parmak izi cari tablosuyla aynı
  üçlü). `pazaryeri-siparis-hazirla` (Sentez'e yazmaz, yalnızca okur) ve
  `pazaryeri-siparis-aktar` (cron'suz).
- **Karar:** Fiş numarası **bizim standardımız değil**. Cari kodunda `PRK-` koyabildik ama
  `Erp_OrderReceipt_IX0` (CompanyId+ReceiptType+ReceiptNo) UNIQUE ve numaralar saf rakam,
  8 hane. ERP'nin dizisi devam ettiriliyor; `sp_getapplock` kendi turlarımızı sıraya sokuyor,
  canlıda başka entegrasyon numarayı kaparsa benzersiz indeks yakalıyor ve 5 kez yeniden
  deneniyor.
- **Karar:** Fiyat pazaryerinden, **KDV oranı ERP'den**. Fiyat KDV dâhil; matrah bölünerek,
  KDV toplamdan matrah çıkarılarak bulunuyor ki matrah + KDV daima ödenen tutarı versin.
- **Karar:** Başlık toplamları **daima satırlardan** toplanıyor, pazaryerinin gönderdiği
  tutardan değil. Fark varsa bu satırlarda eksik olduğunun işaretidir.
- **Karar:** `SentezDepoKodu` diye **ayrı** bir parametre anahtarı açıldı. Hesabın mevcut
  `DepoKodu` alanı Shopify'de mağazanın lokasyon kimliğini (`75108548930`) taşıyor; ERP
  deposuyla ilgisi yok. Ödeme carisi için zaten var olan `OdemeAracisiCariHesapKodu`
  kullanıldı — canlı fişlerdeki `PaymentToCurrentAccountId` ile birebir tutuyor.
- **Dokunulan dosyalar:** `src/.../Pazaryerleri/SiparisAktarimi/` (6 dosya),
  `Data/Migrations/014_...sql`, `src/SentezServis.Host/Program.cs`

### 10. Yol boyunca çıkan dört gerçek arıza

1. **`The incoming request has too many parameters`** — Dapper `IN` listesini tek tek
   parametreye açıyor, SQL Server 2.100'de duruyor. 04'ün yedi günlük siparişi bile aşıyordu.
   → 1.000'lik öbekleme.
2. **`Kaynak sipariş bulunamadı`** — Dapper snake_case'i `SirketKodu`'na eşlemiyor ve
   eşleşmeyen kolon **sessizce** null kalıyor; `siparis_id` hiç okunmamıştı. → kolonlara
   takma ad. (Cari tarafı ara tip + elle çevirici kullandığı için bu tuzağa düşmemişti.)
3. **`Invalid column name 'UD_KargoTakipNumarasi'`** — `SentezCore2026Test` canlıdaki bu
   kolonu taşımıyor. Kolonu hiç yazmamak canlıda takip numarasını kaybettirir, koşulsuz yazmak
   testte her fişi patlatır. → varlığı hedef başına bir kez sorulup INSERT ona göre kuruluyor.
4. **`... cannot have any enabled triggers if the statement contains an OUTPUT clause without
   INTO`** — `Erp_OrderReceiptItem` üzerinde tetikleyici var. → `OUTPUT ... INTO @yeni`.

Ayrıca `Erp_Inventory.MarkId` bigint çıktı (modelde int'ti) ve Dapper materyalizasyonu
patlıyordu; düzeltildi.

### 11. Canlı doğrulama

```
SIPARIS HAZIRLA (04, son 10 gun)
  3973 sipariş · 915 barkod adayının 898'i çözüldü
  63 sipariş aktarıma hazır, 3910 atlandı — sebebi: carisi Sentez'e geçmemiş
SIPARIS AKTAR (04, en fazla 3)
  SentezCore2026Test: 3 fiş yazıldı.
```

Hedefte kontrol edildi: `00441518`–`00441520`, `SpecialCode='Trendyol'`, Tokat Depo, ödeme
carisi `120.01.015`, e-arşiv alanları, `PRK-` carileri bağlı. **Başlık toplamı = kalem
toplamı** kuruşuna kadar (795,30/874,82 — 690,84/759,92 — 655,14/720,66); varyant satırları
doğru `InventoryVariantId` ile yazıldı.

### 12. Testler ve belge

- `SiparisAktarimTestleri` (tutar hesabı + hazırlık kararları) ve `SiparisYaziciSinirTestleri`
  (kaynak taramalı: `ErpAcAsync` yok, cron yok, tek işlem, öbekleme, takma adlar).
  372 → **402**, tamamı geçiyor.
- `docs/pazaryeri-siparis-aktarimi.md` yazıldı; `docs/api-kontrat.md`'deki Şart B-10 notu
  sipariş yazıcısını da kapsayacak şekilde güncellendi.
- **Commit:** `0e26f04` — Pazaryeri siparisleri: Senteze fis olarak aktarim

## Açık kalanlar (güncel)

1. CRS `FilterEInvoiceUsers` + `GetUserAliasses` — e-fatura/e-arşiv kararı.
2. Cari ve sipariş aktarımı ekranları + API uçları (depolar hazır, uç/sayfa yok).
3. Siparişin iç kullanıcıya atanması (kolon var, uç/ekran yok).
4. Shopify siparişlerini yeniden çek (il/ilçe düzeltmesi kayıtlı satırlara yansımadı).
5. Hepsiburada'dan hâlâ sıfır sipariş geliyor; eşleme doğrulanmadı.
6. Pazarama 04 için gerçek anahtarlar (bugün 03'ünkiler duruyor).
7. **Devam eden:** FortiGate API anahtarı ve `sa` parolası eski paket zip'lerinde açıkta —
   döndürülmeli. Eski zip'lerin depodan çıkarılma kararı bekliyor.
8. Ekran hâlâ tarayıcıda açılmadı (yönetici girişi yok).
