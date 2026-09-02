# sentezservis — 2026-09-02

## Bağlam

Dün CRS e-fatura mutabakat arayüzü yazıldı ama canlı doğrulanamadı (giriş bilgisi yoktu).
Bugün konu pazaryerlerine döndü. Kullanıcı 01/03/04 şirketlerinin gerçek pazaryeri
anahtarlarını verdi ve "PTT entegrasyonu da çıktı" dedi.

Karar: **önce elimizdekini bağla, sonra büyüt.** Yeni sağlayıcı (N11) veya yeni alt sistem
(PTT) eklemeden önce, DLL'den kurtarılan pazaryeri katmanının gerçekten çalıştığını görmek.

## Yapılanlar

### 1. Gelen bilgilerin şemayla eşlenmesi

- **Neden:** Kullanıcının alan adları (`TedarikciNumarasi`, `User-Agent`, `MerchatId`, `SiteUrl`)
  şemadakilerle (`SaticiKimligi`, `Kullanici`, `ApiAnahtari`, …) birebir değil.
- **Ne yapıldı:** Her alan `PazaryeriSemalari` ile karşılaştırıldı. Kodda karşılığı olmayan
  üç grup çıktı:
  1. **N11** — sağlayıcısı yok, `Pazaryeri` enum'unda değeri bile yok.
  2. **PTT Kargo** — pazaryeri değil; `IPazaryeriSaglayici` (sipariş/fiyat/stok) sözleşmesine
     uymuyor, kendi soyutlamasını istiyor.
  3. **Muhasebe/cari eşleme alanları** — `CariOndeger`, `MusteriMuhasebeKodu`,
     `SaticiMuhasebeKodu`, `OdemeAracisiCariHesapKodu`, `OdemeTuruTagAlanAdi`. Belge bunların
     katmanın dışında olduğunu zaten söylüyor.
- **Sonuç:** Gerçek hesap sayısı sanılandan az. Her şirket her pazaryerinde satmıyor:
  01 → Trendyol, Shopify. 03 → Trendyol, Hepsiburada, N11, Boyner, Shopify, Pazarama(boş).
  04 → Trendyol, Hepsiburada, Boyner, Pazarama(boş). Yer tutucu 15 satırlık yapılandırma yanlıştı.

### 2. Yapılandırmanın gerçek hesaplarla yazılması

- **Ne yapıldı:** `appsettings.json` → `SentezServis:Pazaryeri:Hesaplar` bloğu (satır 87–330)
  tümüyle değiştirildi. 11 hesap satırı; 7'si `Etkin: true`.
- **Kararlar:**
  - Muhasebe/cari kodları **`Ek` sözlüğüne parametre olarak** yazıldı (kullanıcının tercihi:
    "şimdilik parametre olarak kaydet, ERP'de işlenecek"). Pazaryeri katmanı bunlara bakmaz;
    ERP eşleme işi yazılınca oradan okunacak. Başka hiçbir yerde kaydı olmadığı için burada
    duruyorlar.
  - Boyner ×2 **kapalı**: `Adres` (uç adresi) gelmedi ve şemada zorunlu.
  - Pazarama ×2 **kapalı**: Client ID/Secret henüz alınmadı.
  - N11 hiç yazılmadı: sağlayıcı yok, üstelik verilen 5 App Key/Secret çiftinin hangisinin
    hangi mağaza olduğu da belirsiz (kullanıcı "her çift ayrı bir mağaza" dedi).
  - Shopify hesaplarında `SaniyedeIstek: 2` — REST'te üstü 429 üretiyor.
- **Dokunulan dosyalar:** `src/SentezServis.Host/appsettings.json` (`.gitignore`'da, repoya girmez)
- **Yedek:** Değiştirmeden önce scratchpad'e `appsettings.yedek.json` olarak kopyalandı.

### 3. Canlı bağlantı koşturucusu

- **Neden:** `BaglantiDeneAsync` için ne bir uç ne de arayüz var; ayrıca tüm API uçları
  oturum istiyor ve elimde kullanıcı yok.
- **Ne yapıldı:** Scratchpad'de tek seferlik bir konsol projesi (`baglantidene`) —
  `appsettings.json`'ı okur, `PazaryeriFabrikasi`'nı kurar, `Dogrula()` çıktısını basar ve
  her etkin hesap için `BaglantiDeneAsync` çağırır. **Depoya girmedi.**
- **Sonuç (ilk koşu): 5/7.** Trendyol ×3 ve Shopify ×2 tamam; Hepsiburada ×2 → 401.

### 4. Hepsiburada — iki ayrı kimlik hatası

İkisi de 401 üretiyordu ve Hepsiburada sebebini söylemiyor.

- **Hata 1 — User-Agent.** `HepsiburadaSaglayici.cs:66` şunu gönderiyordu:
  `$"SentezServis/{_magaza}"`. Hepsiburada yalnızca **kendisine kayıtlı entegratör adını**
  kabul eder (burada `sentezyazilim_dev`); tanımadığı adı kimlik denetimine varmadan
  reddeder. Ad artık hesabın `EntegratorAdi` alanından okunuyor.
- **Hata 2 — Basic auth kullanıcı adı.** Kod entegratör adını kullanıcı adı sanıyordu.
  Doğrusu **Merchant ID**. Teşhis curl ile üç denemede yapıldı:
  ```bash
  # 1) prod, kullanici=sentezyazilim_dev   -> 401
  # 2) sit  (test ortami), ayni            -> 401
  # 3) prod, kullanici=merchantId          -> 200   <-- dogrusu
  curl -u "$MERCHANT_ID:$PAROLA" -A "sentezyazilim_dev" \
    "https://oms-external.hepsiburada.com/orders/merchantid/$MERCHANT_ID?offset=0&limit=1"
  ```
  `Kullanici` artık isteğe bağlı; boşsa merchant kimliğine düşüyor. Ayrı bir entegrasyon
  kullanıcısı tanımlı hesaplar için alan duruyor.
- **Dokunulan dosyalar:** `Pazaryerleri/Saglayicilar/HepsiburadaSaglayici.cs`,
  `Pazaryerleri/PazaryeriAyarlari.cs` (şema: `Kullanici` zorunlu değil, `EntegratorAdi` eklendi),
  `tests/.../HepsiburadaKimlikTestleri.cs` (yeni, 6 test), `docs/pazaryeri-entegrasyonu.md`
- **Testlerin biçimi:** Giden istek sahte bir `HttpMessageHandler` ile yakalanıp başlıklarına
  bakılıyor. İki sızıntı ayrıca test ediliyor: entegratör adı Basic kimliğe, merchant kimliği
  User-Agent'a karışmamalı.
- **Sonuç (ikinci koşu): 7/7.**
  ```
  01 / Trendyol      TAMAM — satıcı 1225364 (43 sipariş)
  01 / Shopify       TAMAM — Pierre Cardin Wholesale
  03 / Trendyol      TAMAM — satıcı 4664 (2852 sipariş)
  03 / Hepsiburada   TAMAM — a4fb14a8-…
  03 / Shopify       TAMAM — Pierre Cardin Lingerie
  04 / Trendyol      TAMAM — satıcı 327733 (7109 sipariş)
  04 / Hepsiburada   TAMAM — 08b76dde-…
  ```
- **Doğrulama:** `dotnet build SentezServis.slnx` 0 uyarı/0 hata; `dotnet test` **246 geçti**.
- **Commit:** `0327d1d` — Hepsiburada kimligi duzeltildi: merchant ID + ayri entegrator adi

## Kararlar

- **Önce bağlan, sonra büyüt.** N11 ve PTT eklemeden önce mevcut dört sağlayıcının kimliğini
  canlı doğrulamak. Doğru karar çıktı: Hepsiburada iki ayrı hatayla hiç çalışmıyormuş ve bu
  ancak gerçek hesapla görülebilirdi.
- **Muhasebe kodları `Ek` sözlüğünde bekliyor.** Şemaya resmi alan olarak eklenmedi; bu,
  pazaryeri katmanına ERP kavramı sokar ve belgenin "bu katman ERP'ye dokunmaz" kuralını bozardı.
- **PTT pazaryeri katmanına sokulmayacak.** Kargo firması sipariş çekmiyor, fiyat/stok
  göndermiyor; barkod tahsisi ve gönderi oluşturma başka bir sözleşme.

## Açık kalanlar / sonraki adım

- **Anahtarlar sohbete yapıştırıldı.** Trendyol secret'ları, Hepsiburada parolaları, Shopify
  token'ları, Boyner ve PTT parolaları panellerden **yenilenmeli**.
- **Boyner ×2** uç adresi bekliyor (şemada zorunlu). **Pazarama ×2** Client ID/Secret bekliyor.
- **N11** sağlayıcısı yok; ayrıca 5 App Key/Secret çiftinin şirket eşlemesi bilinmiyor.
- **PTT Kargo** kendi katmanını bekliyor. Verilen barkod aralığı **ters**
  (`2791859800001` başlangıç > `2791852299999` bitiş) ve **üç şirket aynı hesabı ve aynı
  aralığı paylaşıyor** — koordinasyon olmazsa barkodlar çakışır.
- **Shopify 03'ün jetonu `shppa_`** (eski private app parolası) — şu an çalışıyor ama
  Shopify private app'leri kaldırdı; `shpat_` custom app jetonuna geçilmeli.
- Doğrulanan şey **kimlik ve taban adres**. Sipariş/fiyat/stok uçlarının gövde eşlemesi
  hâlâ gerçek veriyle sınanmadı. ERP eşlemesi ve işler de hâlâ yok.
- Dünden devreden: CRS fatura modülü canlı doğrulanmadı (giriş bilgisi yok).

---

## Ek tur — gerçek siparişlerin çekilmesi

### 5. Sipariş sondası

- **Neden:** Kimlik doğrulandı ama sipariş **eşlemesi** hiç sınanmamıştı. ERP'ye yazan iş
  yazmadan önce alanların doğru dolduğunu görmek gerekiyordu.
- **Ne yapıldı:** Scratchpad'deki koşturucu genişletildi: her etkin hesaptan son 7 günün
  siparişleri çekiliyor, örnek sipariş açılıyor ve **alan kapsamı** ölçülüyor — bir alanın
  kaç siparişte dolu olduğu. Aranan şey tek sipariş değil; **%0 dolu bir alan**, tek kayda
  bakarak görülemeyecek bir eşleme hatasıdır. Ayrıca tutar denetimi:
  kalemler + kargo − indirim = başlık tutarı.
- **Sonuç:** 193 sipariş, 316 kalem. **Tutar denetimi hepsinde kuruşu kuruşuna tuttu.**
  Trendyol'da kalem alanlarının (barkod, stok kodu, adet, fiyat, KDV oranı, kalem no)
  tamamı %100 dolu.

### 6. Yanlış alarm — "tarih filtresi tutmuyor"

- Sonda önce **29/43 sipariş aralık dışı** dedi ve bunu hata olarak işaretledi.
- **Sondanın hatasıydı, kodun değil.** Filtre son değişiklik tarihine göre çalışıyor; ben
  oluşturma tarihiyle karşılaştırmıştım. Nisan'da açılıp dün durumu değişen bir sipariş,
  dünkü pencereye düşer — doğru davranış budur.
- Ham API ile kanıtlandı: 1 saatlik pencere `totalElements: 0`, 2020 penceresi `0`,
  1 günlük pencere `1671`. Filtre çalışıyor.

### 7. Trendyol'un gerçek davranışı (belgeye yazıldı)

- **`orderByField` yalnızca sıralar, filtrelemez.** Aynı pencerede `CreatedDate` ve
  `PackageLastModifiedDate` birebir aynı sonucu (1671, aynı ilk kayıt) döndürdü. Yani
  `SiparisSorgusu.DegisiklikTarihiyle` bir sıralama tercihi; "oluşturma tarihine göre çek"
  diye okunmamalı.
- **Geniş pencerede `totalElements` güvenilmez.** 7 günlük pencere filtresiz sorguyla aynı
  sayıyı bildirdi (2858 ve 7117); 1 günlük pencere 1671'e düştü. Tek güvenilir işaret
  `SayfaliSonuc.Kesildi`.
- **Commit:** `e911293`

### 8. Veri bulguları (kod değil, mağaza tarafı)

- **01 Trendyol'da satıcı stok kodu yok:** `merchantSku` 55 kalemin 55'inde de düz metin
  `"merchantSku"` dönüyor. 03'te 37, 04'te 16 farklı değer var. **ERP eşlemesi barkoda
  dayanmalı** — barkod üç mağazada da %100 dolu.
- Trendyol alıcı telefonunu vermiyor (maskeli); bireysel siparişlerde VKN/TCKN yok.
- Shopify sipariş kaleminde `barcode` alanı hiç yok; barkod `sku` içinden geliyor
  (`StokKodu`). Kargo firması/takip no ancak fulfillment açılınca doluyor.
- Shopify adres eşlemesi doğru (`province` → `Il`); örnek siparişte il boş çünkü mağazanın
  verisinde boş.
- **Hepsiburada'nın iki hesabında da son 7 günde sipariş yok** → sipariş eşlemesi orada
  hâlâ doğrulanmadı.

## Ek — açık kalanlar

- Hepsiburada sipariş eşlemesi doğrulanmayı bekliyor (sipariş gelince).
- ERP eşlemesi ve işler hâlâ yazılmadı. Eşleme anahtarı **barkod** olacak.

---

## Üçüncü tur — sipariş deposu ve ekranı

Kullanıcı istedi: seçilen aralıkta **tüm sağlayıcılardan, tüm şirketlerden** siparişleri çekip
kendi veritabanımızda bir tabloya kaydetmek; ikinci çekimde iptal/iade durumlarını güncellemek.

Mimari iş olarak ele alındı (yeni tablo + kalıcılık + uzlaştırma + ekran). Üç karar kullanıcıya
soruldu, üçünde de önerilen seçenek onaylandı: ekran + arkada iş, durum değişikliği geçmişi
tablosu, kalemler + ham JSON.

### 9. Şema — `011_pazaryeri_siparisleri.sql`

- **Parmak izi (şirket, pazaryeri, PAKET NO).** Sipariş numarası değil: Trendyol'da bir sipariş
  çok pakete bölünür, paketler ayrı kargolanır ve **durum paket üzerinden yürür**. Sipariş no
  anahtar olsaydı bir paketi teslim diğeri iptal olan sipariş tek satırda ezişirdi.
- **Kalemler her çekimde silinip yeniden yazılır** — kısmi iptalde kalem düşer; upsert düşen
  kalemi bırakır ve sipariş toplamı kalem toplamını tutmaz.
- **Durum geçmişi yalnızca gerçek değişimde yazılır.** Her çekimde yazılsaydı tablo aynı durumun
  kopyalarıyla dolar, "ne zaman iptal oldu" yine cevapsız kalırdı.
- **Saklama politikasına bilerek eklenmedi**: ticari kayıt, otomatik silinmemeli.

### 10. Depo, iş ve ekran

- `SiparisUzlastirma` saf mantık (12 test), `SiparisDeposu` Dapper deposu,
  `PazaryeriSiparisCekJob` iş, `PazaryeriSiparisUclari` API, `PazaryeriSiparisleriSayfasi` ekran.
- Ekran işi kuyruğa atar ve **canlı log** akıtır (mevcut `useJobLogStream` + `LogPaneli`).
  Senkron çekim tarayıcıyı zaman aşımına sokardı.
- `SiparisDeposuSinirTestleri`: ERP bağlantısının açılmadığı ve pazaryerine gönderim
  yapılmadığı **kaynak taramasıyla** korunuyor (EksiStokTestleri'nin deseni).

### 11. Canlı doğrulama ve çıkan üç hata

**5.879 sipariş / 8.286 kalem** gerçek hesaplardan yazıldı.

- Aynı aralık ikinci kez çekildiğinde **hiçbir satır çoğalmadı** (0 yeni, mükerrer parmak izi 0).
- Bir siparişin durumu elle bozulup yeniden çekildi: değişim görüldü, geçmişe **tam bir** satır
  yazıldı, `durum_degisiklik_zamani` ilerledi, satır gerçek duruma döndü.
- Kapalı pazaryeri (Boyner) seçildiğinde iş "sipariş yok" demedi, "etkin hesap yok" dedi.

Yolda üç hata çıktı, üçü de ancak gerçek veriyle görülebilirdi:

1. **Trendyol `totalElements` her sayfada toplanıyordu.** 2.066 siparişlik çekim "22.726 kayıt
   bildirildi" diye görünüyordu — liste eksik sanılırdı. Pencere başına bir kez alınacak şekilde
   düzeltildi. (Liste aslında tamdı: 2066 × 11 sayfa = 22726.)
2. **İsteğe bağlı parametreler `GetString` ile okunuyordu.** `sirket`/`pazaryeri` boş
   bırakıldığında — yani "tüm şirketler", asıl kullanım — iş `JobParameterException` ile
   patlıyordu. `GetStringOrDefault`'a çevrildi.
3. **Trendyol `ReadyToShip` durumu eşlenmemişti**, `Bilinmiyor` düşüyordu. `Hazirlaniyor`'a
   eşlendi.

Ayrıca projedeki `TurkceHarmanlamaParametreTestleri` koruması kodumu yakaladı ama **yanlış
alarmdı**: `eski.Id` bir çağrı argümanıydı, anonim nesne üyesi değil; dedektörün regex'i ikisini
ayıramıyor. Kod yine de daha temiz hâle getirildi (metoda çıplak `long` yerine satırın kendisi
veriliyor).

### 12. Yazma hızı

İlk ölçüm **~8,75 sipariş/sn** — sipariş başına ayrı transaction. Öbekli işleme geçildi
(100 sipariş/transaction) → **~12/sn**. Beklenenden az iyileşme: darboğaz commit değil, sipariş
başına dört ağ turu ve uzak veritabanı gecikmesi. Toplu yazmaya (TVP / `SqlBulkCopy`)
geçilmedi — 90 günlük çekim yoğun mağazalarda 45 dakikalık iş zaman aşımına yaklaşabilir.

- **Doğrulama:** `dotnet build` 0 uyarı/0 hata, **260 C# testi**, **40 arayüz testi**, lint temiz.
- **Commit:** `f850746` — Pazaryeri siparisleri: cekme isi, depo ve ekran

## Ek — açık kalanlar (3. tur)

- **Ekran tarayıcıda hiç açılmadı**: giriş bilgisi yok. Uçlar 401/404 ile kayıtlı olduğu
  doğrulandı, iş ve depo doğrudan koşturuldu; ama "Çek"e basılıp canlı log akışı görülmedi.
- Yazma hızı için toplu yazma (TVP) düşünülebilir.
- Hepsiburada'da hâlâ sipariş yok; o pazaryeri için eşleme doğrulanamadı.

---

# 4. tur — gecelik uzlaştırma

## Bağlam

3. tur sonunda ekran ve iş hazırdı ama **zamanlaması yoktu**: aralık hep kullanıcıdan
geliyordu. Soru şuydu — iptal ve iade geç geldiğine göre (müşteri üç gün sonra iptal eder,
kargo bir hafta sonra iade döner), bir kez çekilen sipariş hiçbir zaman "bitmiş" değildir.
Hedef: geceleri kayan pencereyle (son 30 gün) otomatik uzlaştırma.

## Yapılanlar

### 1. Kayan pencere + kapsam parametreleri

- **Neden:** Zamanlanmış çalıştırmaya parametre verilemez. `ParametreDogrulayici.Dogrula`,
  boş gelen değerin yerine alanın `DefaultValue`'sunu koyar — **zamanlanmış turun tek
  ayar mekanizması budur.** Bu yüzden varsayılanlar ekranın değil, gecelik turun ihtiyacına
  göre ayarlanmalıydı.
- **Ne yapıldı:**
  - `DefaultCron = "0 3 * * *"`.
  - `baslangic`/`bitis` → `Required = false`. İkisi de boşsa kayan pencereye düşülür.
    **Yalnızca biri** verilirse doğrulama reddeder (kullanıcı aralık istemiş, yarısını yazmayı
    unutmuştur — sessizce 30 güne düşmek yanlış olurdu).
  - Yeni `sonGun` (Number, varsayılan **30**, 1–90).
  - Yeni `kapsam` (Select, varsayılan **`iptalIade`**): `iptalIade` → `Durumlar` süzgeci
    `[IptalEdildi, Iade]`; `hepsi` → süzgeç yok.
  - Ekrandaki **Çek** düğmesi `kapsam: TUM_KAPSAM` (`'hepsi'`) göndererek varsayılanı
    açıkça ezer — ekrandan yapılan çekim tam olmalı.
- **Karar — neden gecelik tur tam çekim değil:** 30 günlük tam pencere yoğun mağazalarda on
  binlerce sipariş demek ve 45 dakikalık iş zaman aşımına yaklaşır. Ölçüldü: Trendyol 04,
  14 gün → **tüm durumlar 3.656, iptal/iade 139** (26 kat).
- **Uyarı (belgeye de yazıldı):** durum süzgecini sunucu tarafında **yalnızca Trendyol**
  uygular. Diğerleri `Durumlar`'ı yok sayıp penceredeki her siparişi getirir. Veri açısından
  zarar yok (yazma idempotent) ama gecelik turun süresi onların hacmine bağlı kalıyor —
  Shopify 03 tek başına 30 günde 2.298 sipariş döndürüyor.
- **Dokunulan dosyalar:** `src/SentezServis.Core/Pazaryerleri/Siparisler/PazaryeriSiparisCekJob.cs`,
  `web/src/api/pazaryeriSiparis.ts`, `web/src/pages/PazaryeriSiparisleriSayfasi.tsx`

### 2. Gecelik tur GERÇEK olarak koşturuldu

- **Neden:** "Varsayılanlar doğru mu" sorusu ancak parametresiz koşarak cevaplanır.
- **Ne yapıldı:** Sonda programı (`scratchpad/baglantidene`) `ParametreDogrulayici.Dogrula`'yı
  **boş sözlükle** çağırıp sonucu işe veriyor — zamanlanmış çalıştırmanın birebir kendisi.
- **Sonuç:**

  | Tur | Sonuç | Süre |
  | --- | --- | --- |
  | 1. | 3.389 sipariş: 2.886 yeni, 493 değişmedi, 10 durum değişti | 7,4 dk |
  | 2. | 3.392 sipariş: **2 yeni**, 3.194 değişmedi, 196 durum değişti (1 iptal, 195 iade) | 5,6 dk |

  7/7 etkin hesap bağlandı, hiçbiri hata vermedi. Mükerrer parmak izi **0**.

### 3. Trendyol `UnDeliveredAndReturned` eşlenmemiş — canlı veride bulundu

- **Neden bulunabildi:** Çekimden sonra `durum = 'Bilinmiyor'` satırlarının `ham_durum`
  dağılımı sorgulandı. Bu hata **hiçbir istisna fırlatmıyor**; sipariş kaydediliyor ama
  iptal/iade sayacına girmiyor. Yani ekranın varlık sebebini deliyor ve ancak veriye bakınca
  görülüyor.
- **Bulgu:** `UnDeliveredAndReturned` → **195 sipariş** `Bilinmiyor` durumundaydı. Bunlar
  gerçek iadeler. Dahası bu ad **süzgeç listesinde de yoktu**, yani gecelik tur onları
  sunucudan hiç istemiyordu. Ayrıca `Approved` (1 sipariş).
- **Ne yapıldı:** `DurumCevir`'e `"UNDELIVEREDANDRETURNED" => Iade` ve `"APPROVED" => Onaylandi`;
  `TrendyolDurumlari`'na `Iade => ["Returned", "UnDelivered", "UnDeliveredAndReturned"]` ve
  `Onaylandi => ["Created", "Approved"]`.
- **Doğrulama:** Düzeltmeden sonraki turda 195'i de yerine oturdu — 04/Trendyol iade
  **59 → 229**, 03/Trendyol **18 → 44**. Kalan tek `Bilinmiyor` o `Approved` siparişi; gecelik
  tur yalnızca iptal/iade istediği için bu turda kapsam dışıydı, ilk tam çekimde düzelecek.
- **Dokunulan dosyalar:** `src/SentezServis.Core/Pazaryerleri/Saglayicilar/TrendyolSaglayici.cs`

### 4. Testler

- `tests/SentezServis.Core.Tests/PazaryeriSiparisCekJobTestleri.cs` (9 test) — **varsayılanları**
  doğruluyor, yalnızca doğrulama kurallarını değil. Varsayılan bozulursa gecelik tur sessizce
  yanlış pencereyi koşar ve kimse fark etmez.
- `tests/SentezServis.Core.Tests/TrendyolDurumEslemeTestleri.cs` (14 test) — canlı veride
  görülmüş her durum adının eşlendiğini kaynak taramasıyla doğruluyor (`DurumCevir` private).
- **Sonuç:** `dotnet build` 0 uyarı/0 hata, **289 C# testi**, **40 arayüz testi**, lint temiz.
- **Commit:** `7f0211d` — Gecelik uzlastirma turu: kayan 30 gunluk pencere + iptal/iade kapsami

## Hesap hesap durum (soru: "hangilerinde sorunsuz çektik")

| Şirket / pazaryeri | Sonuç |
| --- | --- |
| 01 / Trendyol, 01 / Shopify | ✅ sorunsuz |
| 03 / Trendyol, 03 / Shopify, 03 / Hepsiburada | ✅ sorunsuz |
| 04 / Trendyol, 04 / Hepsiburada | ✅ sorunsuz |
| Boyner ×3 | ⛔ kapalı — uç adresi yok |
| Pazarama ×2 | ⛔ kapalı — anahtar yok |
| N11 | ⛔ sağlayıcı hiç yazılmadı |

Hiçbir etkin hesap hata vermedi. Sipariş dönen yalnızca Trendyol ve Shopify;
**Hepsiburada bağlanıyor ama 30 günde tek siparişi yok — eşlemesi hâlâ doğrulanmadı.**

## Yerel adres

`appsettings.json` → Kestrel `http://0.0.0.0:81`. Ekran:
**`http://localhost:81/pazaryeri-siparisleri`** (giriş gerekiyor).

## Açık kalanlar

- Ekran hâlâ tarayıcıda açılmadı — giriş bilgisi yok.
- Hepsiburada sipariş eşlemesi doğrulanmadı (veri yok).
- Boyner uç adresi, Pazarama anahtarları, N11 sağlayıcısı.
- Gecelik turun süresi Shopify'ın hacmine bağlı; Shopify tarafında durum süzgeci uygulanmıyor.
