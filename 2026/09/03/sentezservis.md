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
