# sentezservis — 2026-08-29

## Bağlam

Projede pazaryeri entegrasyonu **hiç yoktu** (`grep -ri trendyol` yalnızca
`yonetim/kurul-kararlari.md` içindeki tartışma metinlerini buluyordu). İstenen: Trendyol,
Hepsiburada, Pazarama, Boyner ve Shopify için sipariş çekme, cari çekme, fiyat/stok
gönderme, durum gönderme ve fatura gönderme servisleri. Kısıt: **şirket koduna göre**
çalışacak, her şirketin parametreleri farklı olacak; kimlik bilgileri sonra verilecek,
şimdilik API şemalarına göre iskelet hazır edilecek. İstenen desen: **factory**.

## Yapılanlar

### 1. Modül iskeleti: `src/SentezServis.Core/Pazaryerleri/`

- **Neden:** Beş pazaryerinin altı işini tek tek yazmak, ağ davranışını (kimlik, hız
  sınırı, tekrar deneme, hata sınıflandırma, sayfalama) beş kere yazmak demekti.
  Ortak taban + hesap başına sağlayıcı deseni bunu bir kereye indiriyor.
- **Ne yapıldı:** Ortak modeller, yetenek arayüzleri, hata tipleri, HTTP tabanı, şema,
  fabrika ve şirket düzeyinde orkestrasyon servisi.
- **Dokunulan dosyalar:**
  `Pazaryerleri/PazaryeriModelleri.cs` (sipariş/cari/adres/fiyat/stok/durum/fatura
  modelleri, `SiparisDurumu`, `PazaryeriYetenekleri`),
  `PazaryeriAyarlari.cs` (hesap + şema + `PazaryeriSemalari`),
  `IPazaryeriSaglayici.cs` (ISiparisKaynagi, ICariKaynagi, IFiyatGonderici,
  IStokGonderici, IDurumGonderici, IFaturaGonderici),
  `PazaryeriIstemcisi.cs` (taban HTTP + `HizSinirlayici` + `PazaryeriYaniti`),
  `PazaryeriHatasi.cs`, `JsonOku.cs`, `SiparistenCari.cs`,
  `PazaryeriFabrikasi.cs`, `PazaryeriServisi.cs`,
  `Saglayicilar/{Trendyol,Hepsiburada,Pazarama,Boyner,Shopify}Saglayici.cs`.
- **Sonuç / doğrulama:** `dotnet build SentezServis.slnx` → 0 uyarı 0 hata
  (`TreatWarningsAsErrors` açık).

### 2. Yapılandırmanın birimi: (şirket kodu, pazaryeri) çifti

- **Neden:** Aynı pazaryerinde her şirketin ayrı mağazası, ayrı anahtarı, bazen ayrı uç
  adresi var. "Pazaryeri başına ayar" modeli bunu taşıyamazdı.
- **Ne yapıldı:** `SentezServis:Pazaryeri:Hesaplar[]` — her satır bir hesap
  (`SirketKodu`, `Pazaryeri`, `Etkin`, anahtarlar, `Adres`, `SayfaBoyutu`, `AzamiSayfa`,
  `ToplulukBoyutu`, `SaniyedeIstek`, `AzamiDeneme`, `ZamanAsimi`, serbest `Ek` sözlüğü).
  Arama büyük/küçük harf ve boşluktan bağımsız (CRS modülündeki `Kimlik(sirketKodu)` ile
  aynı davranış).
- **Dokunulan dosyalar:** `src/SentezServis.Core/Ayarlar.cs` (yeni `Pazaryeri` bölümü),
  `src/SentezServis.Host/appsettings.json` (beş örnek hesap, boş anahtarlarla).
  Not: `appsettings.json` **gitignore'da**, örnek yalnızca yerelde; versiyonlanan örnek
  `docs/pazaryeri-entegrasyonu.md` içinde.

### 3. Şema → doğrulama → fabrika zinciri

- **Neden:** "Bilgiler sonra verilecek" olduğu için eksik yapılandırmanın ne zaman ve
  nasıl patlayacağı önemliydi. Yarım hesapla ağa çıkıp anlamsız 401 almak en kötüsü.
- **Ne yapıldı:** Her pazaryerinin istediği alanlar `PazaryeriSemalari` içinde tanımlı
  (ad, başlık, zorunlu mu, sır mı, nereden alınır). Fabrika hesabı kurmadan önce şemayı
  doğruluyor; eksikse `PazaryeriYapilandirmaHatasi`. Servis açılışında
  `PazaryeriFabrikasi.Dogrula()` tüm hesapları tarayıp eksikleri **uyarı olarak**
  günlüğe yazıyor (mükerrer hesap tanımı da yakalanıyor). Şema aynı zamanda arayüzün
  hesap formunu üretecek veri.
- **Dokunulan dosyalar:** `PazaryeriAyarlari.cs`, `PazaryeriFabrikasi.cs`,
  `src/SentezServis.Host/Program.cs`.

### 4. Sağlayıcılar

| Pazaryeri | Kimlik | Not |
| --- | --- | --- |
| Trendyol | Basic + User-Agent'ta sellerId | Sipariş aralığı 2 haftaya bölünüyor; fiyat/stok tek uç, asenkron (`batchRequestId`) |
| Hepsiburada | Basic | İki alan adı: OMS (sipariş) + listing (fiyat/stok); yükleme asenkron |
| Pazarama | OAuth2 client credentials | Jeton bellekte, bitiminden 1 dk önce yenileniyor; fatura ucu yok |
| Boyner | Basic veya Bearer | **Tümüyle yol-yapılandırmalı**: adres + 5 yol `Ek` alanlarından |
| Shopify | X-Shopify-Access-Token | Link başlığıyla imleçli sayfalama; barkod→varyant GraphQL ile çözülüyor (REST'te barkod filtresi yok) |

- **Karar:** Cari ucu olmayan dört pazaryerinde cari, sipariş başlığından türetiliyor
  (`SiparistenCari`) ve `CariKaynagi.SiparistenTuretildi` ile işaretleniyor. Tekilleştirme
  anahtarı sırayla müşteri no → VKN → e-posta → telefon → ad+ilçe; **maskeli** değerler
  (`a***@t.com`) anahtar olarak kullanılmıyor, yoksa iki farklı kişi birleşirdi.

### 5. Pazarlıksız davranış kuralları (koda gömüldü)

- Durum ve fatura gönderiminde **tekrar deneme yok** — 5xx'te istek karşı tarafta işlenmiş
  olabilir; ikinci deneme paketi yanlış duruma taşır veya mükerrer fatura üretir.
- Sayfa tavanı dolarsa `SayfaliSonuc.Kesildi = true` — eksik listeyi tam sanmak yok.
- Asenkron gönderimde dönen kimlik "kabul edildi" demek, "işlendi" demek değil;
  `ToplulukDurumuAsync` / `YuklemeDurumuAsync` ile sorgulanıyor.
- Barkodsuz satır gönderilmiyor, sebebiyle birlikte `GonderimReddi` olarak dönüyor.
- İstek başlığı/gövdesi loglanmıyor (anahtarlar sır).
- Bir hesabın hatası diğerlerini durdurmuyor (`PazaryeriServisi` hesap bazında sonuç
  topluyor); iptal (`OperationCanceledException`) yutulmuyor.

### 6. Testler

- **Ne yapıldı:** `tests/SentezServis.Core.Tests/PazaryeriTestleri.cs` — 18 test: şema
  doğrulaması (üç eksik alanın hepsi tek seferde), şirket çözümleme, kapalı modül/kapalı
  hesap, mükerrer hesap, desteklenmeyen yetenek, yetenek süzgeci, cari tekilleştirme,
  maskeli veri, JSON okuma (epoch ms/sn, metin tutar, eksik alan), Link başlığı, sonuç
  birleştirme, şema-sağlayıcı yetenek eşleşmesi. Hiçbiri ağa çıkmıyor.
- **Komutlar:**
  ```bash
  dotnet build SentezServis.slnx
  dotnet test tests/SentezServis.Core.Tests/SentezServis.Core.Tests.csproj
  ```
- **Sonuç:** 231 test geçti (öncesinde 213).

## Kararlar

- **Ad alanı `SentezServis.Core.Pazaryerleri`, klasör de öyle.** İlk hâli `Pazaryeri`ydi;
  `Pazaryeri` enum'u ile ad alanı çakışınca (`Pazaryeri.Trendyol` dışarıdan ad alanı
  olarak çözülüyor) modül dışından kullanılamıyordu. Testler bunu derleme hatasıyla
  gösterdi.
- **Yetenekler ayrı arayüzler + bayrak.** Fabrika `Yetenek<IFaturaGonderici>(...)`
  isteyince desteklenmeyen pazaryeri örneği hiç kurulmuyor. Sessiz "başarılı" dönmek
  gönderilmemiş faturayı gönderilmiş sandırırdı.
- **Tipli DTO yerine `JsonElement` + hoşgörülü okuyucular.** Pazaryerleri alan ekliyor,
  büyük/küçük harf değiştiriyor, aynı alanı bazen metin bazen sayı gönderiyor; tipli
  bağlama tek bozuk kayıtta **tüm sayfayı** düşürürdü. Ham JSON sipariş kaydında saklanıyor.
- **Boyner yol-yapılandırmalı.** Adresi ve yolları sözleşmeye göre değiştiği ve elimde
  doğrulanmış belge olmadığı için sabit yol yazmak yerine hepsi `Ek` alanlarından
  okunuyor. Uydurma sabit yazıp "hazır" demektense yapılandırılabilir bırakmak dürüst.
- **ERP eşlemesi bu katmanın dışında.** Sipariş → `Erp_Order`, cari → cari kartı yazımı
  yok; katman veritabanı bilmiyor. Sözleşme değişiklikleri iki tarafı birbirine
  bulaştırmasın diye.

## Açık kalanlar / sonraki adım

- **Anahtarlar bekleniyor.** Beş pazaryeri × şirket için `appsettings.json` doldurulacak;
  her hesap `BaglantiDeneAsync` ile sipariş çekmeden sınanacak.
- **Uç teyidi:** Hepsiburada durum/fatura yolları, Pazarama uç yolları ve Boyner'in
  tamamı entegrasyon belgesiyle karşılaştırılmadan canlıya çıkmamalı. Trendyol ve Shopify
  açık belgeye göre yazıldı ama canlı doğrulanmadı.
- **İşler (job) yazılacak:** `pazaryeri-siparis-cek`, `pazaryeri-stok-gonder`,
  `pazaryeri-fiyat-gonder`, `pazaryeri-durum-gonder`, `pazaryeri-fatura-gonder`.
  Yan etkili olanlar `JobRetrySafety.Unsafe` + mükerrerlik anahtarı **zorunlu**.
- **Arayüz:** hesap formu `PazaryeriSemalari` üzerinden üretilebilir; sır alanları
  maskelenmeli.

## Commit

`5243c83` — Pazaryeri entegrasyon katmani: fabrika + 5 saglayici
(remote: `git@gitlab.com:modasima/sentezservis.git`, push edildi)
