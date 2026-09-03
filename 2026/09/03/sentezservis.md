# sentezservis — 2026-09-03

## Bağlam

Güne, 10 pazaryeri hesabının 7'si açık başlandı: Boyner (uç adresi yok) ve Pazarama (anahtar
yok) kapalıydı, N11 sağlayıcısı hiç yazılmamıştı. Kullanıcı Boyner'in ERP tarafındaki kaynak
kodunun yerini verdi (`Y:\defactor\BoynerModule`), N11'in **iptal** olduğunu söyledi ve güncel
kimlik bilgilerini paylaştı (bu kez Pazarama anahtarları ve Boyner kullanıcı/parolaları da
dolu).

Hedef: Boyner ve Pazarama'yı gerçekten çalışır hâle getirmek.

## Yapılanlar

### 1. Boyner: Trendyol'ın `sapigw` platformu çıktı

- **Neden:** Sağlayıcı "olası alan adlarını sırayla dene" mantığıyla yazılmıştı ve `Adres`
  alanı zorunlu bırakılmıştı çünkü uç adresi bilinmiyordu.
- **Ne yapıldı:** ERP'deki decompile edilmiş `BoynerModule` kaynağı okundu.
  `PresentationModels/BoynerTransferPM.cs:121` şu satırı taşıyordu:

  ```
  https://merchantapi.boyner.com.tr/sapigw/suppliers/{MerchantID}/orders?status=Created
  ```

  Yani Boyner ayrı bir API yazmamış, **Trendyol'ın sapigw sözleşmesini** kullanıyor.
  `Models/Contentt.cs` Trendyol'ın sipariş gövdesiyle birebir aynı (`orderNumber`,
  `shipmentPackageStatus`, `lines`, epoch-ms `orderDate`, `cargoTrackingNumber`...).
- **Komutlar (doğrulama):**
  ```bash
  curl -u "fQrYfS:H8yCBz" -A "2004795303 - SelfIntegration" \
    "https://merchantapi.boyner.com.tr/sapigw/suppliers/2004795303/orders?page=0&size=1"
  ```
- **Üç tuzak bulundu:**
  1. **User-Agent zorunlu.** UA'sız/tanınmayan istek **403 + Cloudflare "Just a moment..."
     HTML'i** alıyor — kimlik doğru olsa bile, üstelik hata JSON'u bile yok. Trendyol'ın
     beklediği biçim gönderiliyor: `{satıcı} - SelfIntegration` (`EntegratorAdi` ile
     değiştirilebilir).
  2. **Durum `shipmentPackageStatus`'tedir.** Eski kod `status`u önce okuyordu; o alan
     satırın/geçmişin durumudur ve canlı veride `Checking`, `supply_waiting`, `cancelFraud`
     gibi paket düzeyinde anlamsız değerler taşıyor.
  3. **Adres alanı `shipmentAddress`.** Eski kod `shippingAddress`/`deliveryAddress`/`address`
     deniyordu — üçü de yok. Adres ve müşteri adı **tamamen boş** kalır ve hata vermezdi.
- **Ayrıca:** `Unpackaged` durumu eşlendi (Trendyol aynı durumu `UnPacked` yazar);
  `vatBaseAmount` alanının adı tutar gibi görünse de **KDV oranı** olduğu doğrulandı (değer 10).
- **Dokunulan dosyalar:** `src/SentezServis.Core/Pazaryerleri/Saglayicilar/BoynerSaglayici.cs`,
  `src/SentezServis.Core/Pazaryerleri/PazaryeriAyarlari.cs`

### 2. Pazarama: dört ayrı hata

Sağlayıcı jeton alabiliyordu ama sipariş tarafı hiç sınanmamıştı. Canlı uçla dört hata çıktı:

1. **Jeton ucu yanlış.** `/api/Token` → **404**. Gerçek uç `/connect/token`
   (form-encoded, Basic, yanıt `data.accessToken`).
2. **Sayfa alanı yanlış.** `pageIndex` **sessizce yok sayılıyor** — 0, 1, 2 gönderildiğinde
   üçünde de birinci sayfa döndü. Doğrusu `pageNumber` ve **1'den başlıyor**. Tek sayfaya sığan
   hesapta fark edilmez; hacim büyüyünce aynı siparişler tekrar tekrar okunurdu.
3. **Zarf düz.** Sayaçlar kökte (`totalCount`, `totalPages`), siparişler kökteki `data`
   dizisinde. Kod `data`yı zarf sanıp içinde `totalCount` arıyordu — hep sıfır.
4. **Aralık en fazla 30 gün.** Aşılırsa `ORD105` ile reddediliyor; kısmi değil **sıfır** sonuç.
   Gecelik uzlaştırma turunun penceresi (son 30 gün, gün sonuna kadar açık = 31 gün) tam bu
   sınıra takılıyordu. Sağlayıcı artık aralığı bölüyor.
- **Komutlar:**
  ```bash
  # jeton
  curl -X POST https://isortagimapi.pazarama.com/connect/token \
    -H "Authorization: Basic $B" -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=client_credentials&scope=merchantgatewayapi.fullaccess"
  # sayfa alanı denemesi (page / pageNumber / pageIndex / currentPage)
  ```
- **İki eşleme kararı canlı veriden çıktı:**
  - **Durum başlıkta değil, KALEMDEDİR.** `orderStatus` 63 siparişin 63'ünde de `3`tü — hiçbir
    şey söylemiyor. Gerçek durum `items[].orderItemStatus` sayısal kodu. Kodlar (beş aylık
    pencereden toplandı): 3 alındı · 12 hazırlanıyor · 5 kargoda · 11 teslim · 6 iptal ·
    13 tedarik edilemedi · 8 iade onaylandı. Sipariş durumu kalemlerden türetiliyor: bir kalem
    iade olduysa iade, hepsi iptalse iptal, aksi hâlde **en gerideki** kalem durumu (hepsi
    teslim edilmeden sipariş teslim sayılmaz).
  - **Tutarlar nesnedir** (`{value, valueString, ...}`) — düz sayı olarak okunursa sıfır çıkar.
  - **Tarihler saat dilimsiz** (`"2026-08-05 23:18"`) ve **İstanbul saati**. Ortak çözümleyici
    saat dilimsiz metni UTC varsayıyor; üç saatlik kayma gün sonundaki siparişleri yanlış güne
    düşürürdü. Pazarama tarihleri artık +03:00 ile okunuyor.
- **Dokunulan dosyalar:** `src/SentezServis.Core/Pazaryerleri/Saglayicilar/PazaramaSaglayici.cs`

### 3. Yapılandırma güncellendi

- **Dosya:** `src/SentezServis.Host/appsettings.json` (gitignore'da; depoya girmez).
- 03/Boyner, 04/Boyner ve 03/Pazarama açıldı.
- **04/Pazarama BİLEREK kapalı bırakıldı**: verilen bilgiler 03'ünkiyle **birebir aynı**
  (aynı satıcı kimliği, aynı anahtar, aynı sır). İkisi de açılsaydı tek mağazanın siparişleri
  iki şirkete birden yazılırdı — parmak izi şirket kodunu içerdiği için satır çoğalmaz, ama
  **aynı ticari belge iki firmaya düşerdi**.
- N11 satırı yok: entegrasyon iptal.

### 4. Canlı doğrulama

- **Bağlantı turu: 10/10 etkin hesap ✓** (önceki tur 7/7'ydi).
- **Alan eşlemesi (60 günlük pencere, veritabanına dokunmadan):**

  | Hesap | Sipariş | Eşleme |
  | --- | --- | --- |
  | 03 / Boyner | 56 | 55 TeslimEdildi + 1 `Unpackaged` (eşlendi) |
  | 04 / Boyner | 89 | 87 TeslimEdildi + 2 IptalEdildi |
  | 03 / Pazarama | 27 | 22 teslim, 3 kargoda, 1 iptal, 1 karma |

  Üç hesapta da adres, müşteri adı, e-posta, telefon, kalem (barkod/stok/adet/fiyat/KDV) ve
  kargo bilgisi **tam** doldu; `adresi/müşterisi boş: 0`.

### 5. Testler

- `tests/SentezServis.Core.Tests/BoynerPazaramaSozlesmeTestleri.cs` (28 test) — canlı
  doğrulanmış sözleşmeyi sabitler. Bu iki sağlayıcının hatası **sessizdir**: yanlış alan adı
  istisna fırlatmaz, boş/sıfır veri döndürür. Kaynak taraması, davranışsal olarak test
  edilemeyen bu değişmezleri korumak için kullanıldı.
- **Sonuç:** `dotnet build` 0 uyarı/0 hata, **316 C# testi**, 40 arayüz testi, lint temiz.
- **Commit:** `9c5032b` — Boyner ve Pazarama gercek sozlesmelerine gore duzeltildi

## Kararlar

- Boyner sağlayıcısı sapigw'e sabitlendi ama **yollar yapılandırılabilir kaldı**: sipariş ucu
  doğrulandı, gönderim uçları (fiyat/stok/durum/fatura) **doğrulanmadı**.
- Pazarama durumu kalemlerden türetilirken iade yönüne kayılıyor — ekranın varlık sebebi iptal
  ve iadeyi yakalamak, ham JSON zaten satırda saklanıyor.
- Trendyol ve Boyner aynı platformun iki sağlayıcısı olduğu hâlde eşleme **kopyalanmış**
  durumda. Ortak bir `sapigw` okuyucusuna çıkarmak doğru olur; çalışan Trendyol'u bugün
  refaktör etmemek için yapılmadı.

## Açık kalanlar / sonraki adım

- **Boyner ve Pazarama veritabanına hiç yazılmadı.** Okuma ve eşleme doğrulandı, ama o sırada
  `192.168.1.3` erişilemezdi (ping %100 kayıp, 1433 kapalı). Depo yazımı ve durum uzlaştırması
  bu iki pazaryeri için sınanmadı — sunucu döndüğünde ilk iş bu.
- 04'ün ayrı bir Pazarama mağazası var mı? Varsa anahtarları alınıp açılmalı.
- Hepsiburada hâlâ sıfır siparişli; eşlemesi doğrulanamıyor.
- Trendyol/Boyner ortak `sapigw` okuyucusu.
- Ekran hâlâ tarayıcıda açılmadı (giriş bilgisi yok).

---

# 5. tur — parametre ekranı

## Bağlam

Kullanıcı 04/Pazarama'yı açmamı istedi ("sen aç, parametrik yapacağız zaten ya; ben sabah
bulur veririm") ve asıl işi tarif etti: **her şirkette tüm entegrasyonlar, aktif/pasif ve
değerleriyle** düzenlenebilen bir parametre ekranı.

Sorulan üç tasarım sorusu ve cevapları: saklama **veritabanına taşınsın**, ekranda **hesap
ekle/sil serbest**, sırlar **maskeli ama isteyince gösterilsin**.

## Yapılanlar

### 1. Hesaplar veritabanına taşındı — göç 012

- **Neden:** Hesaplar `appsettings.json`'da duruyordu. Parametreleri girecek kişi sunucudaki
  bir JSON dosyasını elle düzenlemek zorundaydı ve her değişiklik servisin yeniden
  başlatılmasını gerektiriyordu. Üç şirket × beş pazaryeri = on bir canlı hesap, her biri
  4-8 alanlı; ikinci mağazalar eklenince dosya elle sürdürülebilir olmaktan çıktı.
- **Tablo:** `pazaryeri_hesaplari` — bağlantı alanları sütun, pazaryerine özgü ek alanlar ve
  ERP eşleme parametreleri `ek` JSON'unda, iz sütunları (kim/ne zaman) ve son bağlantı
  denemesinin sonucu.
- **Tekillik `(şirket, pazaryeri, ad)`** — `(şirket, pazaryeri)` tekil olsaydı aynı
  pazaryerinde ikinci mağaza açılamazdı. N11'in beş ayrı App Key/Secret çifti tam olarak bu
  ihtiyaçtı. Bu yüzden **hesap adı zorunlu**.
- **Pazaryeri ADIYLA saklanır**, sayısal enum değeriyle değil: enum'a ortadan bir üye eklemek
  bütün satırları başka pazaryerlerine kaydırırdı.
- **Saklama politikası YOK** — hesap satırı yapılandırmadır, olay değil; otomatik silinmesi
  entegrasyonun sessizce durması demektir.
- **Dokunulan dosyalar:** `src/SentezServis.Core/Data/Migrations/012_pazaryeri_hesaplari.sql`,
  `src/SentezServis.Core/Pazaryerleri/Hesaplar/` (4 yeni dosya)

### 2. appsettings TOHUM oldu

- **Neden yalnızca boş tabloya:** Her açılışta aktarılsaydı dosyadaki değerler ekrandan
  yapılan düzeltmelerin üzerine yazardı — kullanıcı bir anahtarı düzeltir, servis yeniden
  başlar, düzeltme kaybolur ve kimse sebebini anlamaz.
- **Tohumlama başarısız olursa uygulama DURMAZ:** hesapsız açılmak hiç açılmamaktan iyidir;
  kullanıcı ekrandan elle girebilir.
- **Dosyadan okunmaya devam eden tek şey** `SentezServis:Pazaryeri:Etkin` — o hesap değil,
  **dağıtım** kararıdır (bir kurulumda pazaryeri modülü hiç istenmeyebilir).

### 3. Fabrika artık kaynaktan okuyor

- `PazaryeriFabrikasi` `IOptions<Ayarlar>` yerine **`IPazaryeriAyarKaynagi`** alıyor:
  uygulamada `VeritabaniAyarKaynagi` (30 sn önbellek + yazma yolundan açık tazeleme),
  testlerde/sondalarda `DosyaAyarKaynagi`.
- **Hata hâlinde BOŞ LİSTE DÖNMEZ.** Boş liste "hesap yok" demektir ve iş "sipariş yok" gibi
  sessizce başarılı biterdi. Son bilinen liste kullanılır ve loglanır; hiç liste yoksa hata
  yukarı fırlar.
- `PazaryeriSiparisCekJob` de artık `fabrika.Ayarlar.Hesaplar` okuyor; `IOptions` bağı koptu.

### 4. Sır sözleşmesi

- **Veritabanında açık durur.** Şifreleme anahtarı aynı sunucuda duracağı için gerçek koruma
  sağlamaz, yalnızca yanlış bir güven duygusu verirdi. Kasa modülündeki uçtan uca şifreleme
  burada kullanılamaz: sırrı **sunucunun kendisi** kullanacak, kullanıcı değil.
- **API'den maskeli döner** (`••••••••`, sabit uzunluk — gerçek uzunluk anahtarın kaç karakter
  olduğunu söylerdi). Açık değer ayrı uçtan ve **ayrı bir denetim kaydı** üreterek alınır:
  listeyi açan herkes anahtarı görmüş sayılmasın.
- **Boş sır alanı "sil" demek değildir:** `COALESCE(@ApiGizli, api_gizli)`. Ekran maskeyi geri
  gönderemeyeceği için sır alanlarını boş bırakır; böylece kullanıcı adını düzeltirken parolayı
  kaybetmek imkânsız olur. **Bedeli:** anahtarı ekrandan silmek mümkün değil — üzerine yazılır
  ya da hesap silinir. Bilinçli takas.
- Sır olmayan alanlar (adres, depo kodu, kullanıcı adı) bu korumanın dışında; onları boşaltmak
  meşru.

### 5. Ekran — `/pazaryeri-hesaplari`

- **Şirket şirket gruplanır.** Bakan kişi "04'te neler açık" diye bakar. Tanımlı OLMAYAN
  pazaryerleri de satır olarak görünür — eksik entegrasyon ancak böyle fark edilir.
- **Form ŞEMADAN üretilir** (`GET /semalar` → `PazaryeriSemalari`). Arayüzde elle alan listesi
  tutulsaydı iki yer birbirinden sessizce ayrılırdı.
- Şemada yeri olmayan ama kayıtta duran ek alanlar (ERP eşleme parametreleri) **korunur**:
  form onları göstermezse kaydetmek silerdi.
- Satır başına **Dene / Düzenle / Sil / +** (ikinci mağaza). Bağlantı denemesi sipariş çekmez,
  sonucu satırda kalır.
- Yalnızca **yönetici** (`YoneticiRotasi` + tüm uçlarda `.YoneticiIster()`).
- **Dokunulan dosyalar:** `web/src/pages/PazaryeriHesaplariSayfasi.tsx`,
  `web/src/api/pazaryeriHesap.ts`, `web/src/api/index.ts`, `web/src/App.tsx`,
  `web/src/components/Layout.tsx`, `src/SentezServis.Host/Api/PazaryeriHesapUclari.cs`

### 6. 04/Pazarama açıldı

Kullanıcının isteğiyle açıldı; anahtarlar **geçici** (03'ünkiyle birebir aynı). Doğru
anahtarlar gelene kadar iki şirket aynı siparişleri çeker ve aynı ticari belge iki firmaya
düşer. `appsettings.json`'a bu notu yazdım; doğru anahtarlar girilince silinecek.
**Bağlantı turu: 11/11.**

### 7. Testler

- `PazaryeriHesapKaydiTestleri` (12) — kayıt ↔ hesap çevriminde alan kaybını yakalar. Kaybolan
  alan **sessiz** bir hatadır: sağlayıcı "alan tanımlı değil" der, suç yapılandırmaya atılır.
- `PazaryeriHesapDeposuSinirTestleri` (14) — COALESCE koruması, tekillik, tohumun yalnızca boş
  tabloya yazması, maskeleme, yönetici zorunluluğu, önbellek tazeleme.
- **Sonuç:** build 0 uyarı/0 hata, **342 C# testi**, 40 arayüz testi, lint temiz.
- **Commit:** `f4f1c86` — Pazaryeri hesaplari parametre ekrani; hesaplar veritabanina tasindi

## Açık kalanlar / sonraki adım

- **Göç 012 uygulanmadı, tohumlama koşmadı, ekran tarayıcıda açılmadı** — bu tur boyunca
  `192.168.1.3` erişilemezdi (ping %100 kayıp, 1433 kapalı). Sunucu döndüğünde ilk iş:
  servisi açıp göçü uygulatmak, tohumun 11 hesabı aktardığını ve ekranın onları listelediğini
  görmek.
- 04'ün gerçek Pazarama anahtarları (kullanıcı sabah verecek).
- Boyner/Pazarama siparişlerinin veritabanına yazımı hâlâ doğrulanmadı (4. tur açığı).
- Hepsiburada'da hiç sipariş yok; eşlemesi doğrulanamıyor.

---

# 6. tur — veritabanı geri geldi, açıklar kapatıldı

## Bağlam

4. ve 5. tur boyunca `192.168.1.3` erişilemezdi; iki büyük doğrulama açıkta kalmıştı:
Boyner/Pazarama siparişlerinin depoya yazımı ve göç 012 + tohumlama + parametre ekranının
uçları. Sunucu dönünce ikisi de koşturuldu.

## Yapılanlar

### 1. Göç 012 ve tohumlama

Servis `127.0.0.1:81`'de açıldı. Log:

```
Migrasyon uygulanıyor: 012 — pazaryeri hesaplari
Pazaryeri hesapları appsettings.json'dan veritabanına aktarıldı (11 hesap).
```

Tabloda 11 satır: hepsi etkin, hepsinde sır dolu, `ek` sözlüğü (ERP eşleme parametreleri)
korunmuş, `olusturan = tohum`. Pazarama'nın iki satırında `ek` boş — zaten muhasebe kodu
verilmemişti.

Sonda programı da veritabanı kaynağına çevrildi (`VeritabaniAyarKaynagi`) ve **11/11 hesap**
bağlandı: yani fabrika artık hesapları gerçekten veritabanından okuyor.

### 2. Depo kuralları gerçek veritabanında sınandı

Ekranın dayandığı yazma kurallarının hepsi tek tek koşturuldu (sonda satırları sonra silindi):

| Kural | Sonuç |
| --- | --- |
| Sır alanı boş gönderilince mevcut değer korunur | ✓ `anahtar-1` ve `gizli-1` yerinde |
| Sır olmayan alan güncellenir | ✓ satıcı kimliği `sonda-1` → `sonda-2` |
| Sır olmayan alan boşaltılabilir | ✓ adres `null` |
| Aynı (şirket, pazaryeri, ad) reddedilir | ✓ açıklayıcı hata |
| Farklı adla ikinci mağaza kabul edilir | ✓ |
| Deneme sonucu satıra yazılır | ✓ |
| Önbellek tazelenince kapalı→etkin görünür | ✓ 0 → 1 |

Uçların yetkilendirmesi: oturumsuz istek `/api/pazaryeri/hesaplar`, `/semalar` ve
`/{id}/sir/{alan}` için **401**; `/pazaryeri-hesaplari` sayfası 200.

### 3. Boyner ve Pazarama depoya yazıldı — 4. turun en büyük açığı

Gecelik tur (parametresiz, 11 hesap) koştu: **3.450 sipariş, 149 yeni, 109 durum değişti**,
7,4 dk. Pazarama iki şirkette de 14'er sipariş yazdı.

**Boyner gecelik turda sıfır döndü.** Sebep hata değil: tur yalnızca iptal/iade istiyor ve
Boyner'in 30 günlük penceresinde o durumlarda sipariş yok. 90 günlük **tam** çekim ayrıca
koşturuldu → 03/Boyner 14, 04/Boyner 9.

| Hesap | Yazılan | Dağılım |
| --- | --- | --- |
| 03 / Boyner | 14 | 13 teslim, 1 iade |
| 04 / Boyner | 9 | 9 teslim |
| 03 / Pazarama | 14 | 11 teslim, 3 kargoda |
| 04 / Pazarama | 14 | 11 teslim, 3 kargoda |

Alan kapsamı SQL ile ölçüldü: **51 siparişin tamamında** müşteri adı, teslimat ili, tutar,
sipariş tarihi ve kalemler dolu; boş alan **0**. Eşlenemeyen durum yok, mükerrer parmak izi 0.

03 ve 04 Pazarama'nın aynı 14 siparişi yazması beklenen davranış — iki hesap aynı anahtarları
paylaşıyor. Satırlar çoğalmadı (parmak izi şirket kodunu içeriyor) ama aynı ticari belge iki
firmaya düştü. 04'ün kendi anahtarları girilince düzelecek.

Toplam depo: **8.940 sipariş · 14.601 kalem · 9.255 geçmiş**, mükerrer 0.

- **Commit:** `c47098c` — Goc 012, tohumlama, depo kurallari ve Boyner/Pazarama yazimi canli dogrulandi

## Açık kalanlar

- **Ekran hâlâ tarayıcıda açılmadı** — yönetici giriş bilgisi yok. Uçlar, depo ve göç canlı
  doğrulandı; arayüzün kendisi (form akışı, maskeleme görünümü, "kayıtlı değeri göster")
  gözle görülmedi. Bu, projede sürekli açık kalan tek doğrulama.
- 04'ün gerçek Pazarama anahtarları.
- Hepsiburada'da hiç sipariş yok; eşlemesi doğrulanamıyor.
- Trendyol'da kalan tek `Approved` siparişi ilk tam çekimde düzelecek.

---

# 7. tur — paket

## Yapılanlar

`deploy/yayinla.ps1` ile paket çıkarıldı: arayüz derlendi → `dotnet publish` → kurulum
betikleri kopyalandı → doğrulama. Çıktı `SentezServis-2026-09-03-0332.zip`, **70,2 MB**,
18 dosya (tek dosya kendi kendine yeten `SentezServis.exe` 193 MB açılmış hâlde).

### Paketten appsettings.json çıkarıldı

- **Neden:** Yayım klasöründeki `appsettings.json` canlı veritabanı parolalarını ve **on bir
  pazaryeri hesabının anahtarlarını** taşıyordu. Paket depoya konuyor, e-postayla
  gönderiliyor, USB'ye kopyalanıyor — sırlar bu yolların hiçbirinden geçmemeli. Depodaki
  `src/SentezServis.Host/appsettings.json` zaten tam bu sebeple `.gitignore`'da.
- **Ne yapıldı:** `yayinla.ps1`'e temizlik adımı eklendi. `ApiAnahtari`, `ApiGizli`, `Jeton`,
  `Parola` boşaltılıyor, bağlantı cümlelerindeki `Password=` `<DOLDURUN>` oluyor, dosya
  `appsettings.ornek.json` olarak bırakılıp aslı siliniyor.
- **Temizlik SONRA doğrulanıyor:** dosyadaki gerçek sır değerleri önce toplanıp temiz metinde
  tek tek aranıyor; biri bile kalmışsa paket **üretilmiyor**. Elle yazılmış bir regex sessizce
  bir alanı atlayabilir — bu tam da fark edilmeyecek türden bir hatadır.
- Bu paket için 25 değer boşaltıldı; zip içinden 21 bilinen sır değeri arandı, **sızıntı yok**.

### servis-kur.cmd düzeltildi

Eskiden ilk kurulumda "appsettings.json kopyalandı" diyordu; paket artık o dosyayı
taşımadığı için bu mesaj yanıltıcı olurdu (servis ayarsız açılır, sebebi anlaşılmazdı). Artık:

- yükseltmede sunucudaki `appsettings.json` **korunuyor** (davranış değişmedi),
- ilk kurulumda örnekten oluşturuluyor ve "içi boş, doldurun" uyarısı veriliyor,
- ikisi de yoksa açıkça hata verip duruyor.

- **Commit:** `ab6ae7c` — Paket artik appsettings.json tasimiyor; yerine bos ornek konuyor

## Bulgu — eski paketlerde sızmış anahtar

Depoda **8 adet eski paket zip'i takipli** (toplam 536 MB) ve içlerindeki `appsettings.json`
temizlenmemiş. `SentezServis-2026-08-18-1158.zip` içinde FortiGate cihazının API anahtarı
açık duruyor (`Forti:Cihazlar[0]:ApiAnahtari`) ve üç adet `Password=` içeren bağlantı cümlesi
var. Git geçmişinde oldukları için silmek yetmez — anahtarın **döndürülmesi** gerekir.

Yeni paket depoya **konulmadı**: hem 70 MB daha bindirmemek için, hem de eski zip'lerin
durumu netleşmeden aynı deseni sürdürmemek için. Kullanıcıya soruldu.

## Açık kalanlar

- FortiGate API anahtarı ve veritabanı `sa` parolası — eski paketlerde açıkta, döndürülmeli.
- Eski zip'lerin depodan çıkarılıp çıkarılmayacağı kararı.
- Ekran hâlâ tarayıcıda açılmadı (yönetici girişi yok).
