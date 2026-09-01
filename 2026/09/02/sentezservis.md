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
