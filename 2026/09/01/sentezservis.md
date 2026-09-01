# sentezservis — 2026-09-01

## Bağlam

Gün, "servisi çalıştırabilir misin" ile başladı. Servis ayağa kalktı ve çalışır durumda
olduğu doğrulandı; ardından asıl iş geldi: **CRS Soft e-fatura karşılaştırması**, şirket
şirket, Sentez'deki UUID (ETTN) üzerinden tutar kıyası.

İnceleyince ortaya çıkan durum: **karşılaştırma çekirdeği zaten yazılmıştı.**
`SentezServis.Core/Fatura/` altında `CrsIstemcisi` (SOAP), `FaturaKarsilastirici` ve
modeller duruyordu; `/api/fatura/sirketler`, `/karsilastir`, `/crs-dene` uçları
`Program.cs`'te kayıtlıydı. **Eksik olan tek şey arayüzdü** — `web/src` altında ne bir
`api/fatura.ts` ne de bir sayfa vardı, menüde ve rotalarda da yoktu.

Hedef: arayüzü eklemek + Excel dışa aktarım.

## Yapılanlar

### 1. Servisin çalıştığının doğrulanması

- **Neden:** Herhangi bir şey eklemeden önce mevcut hâlin ayakta olduğunu görmek.
- **Ne yapıldı:** Host derlendi ve `127.0.0.1:8181`'e bağlanarak koşturuldu (varsayılan
  `0.0.0.0:81` yerine — çakışma olmasın diye).
- **Komutlar:**
  ```bash
  dotnet build src/SentezServis.Host/SentezServis.Host.csproj
  cd src/SentezServis.Host
  ASPNETCORE_ENVIRONMENT=Development Kestrel__Endpoints__Http__Url="http://127.0.0.1:8181" \
    dotnet run --no-build --project SentezServis.Host.csproj
  ```
- **Sonuç / doğrulama:** 7 görev kaydedildi, FortiGate toplayıcısı 5514'te dinlemeye
  başladı, arayüz servis edildi. `POST /api/auth/giris` anında "parola hatalı" döndü —
  bu, `192.168.1.3` üzerindeki `SentezServices` veritabanına **gerçekten ulaşıldığını**
  gösterir (bağlantı kopuk olsa 500/timeout gelirdi).
- **Not:** Bu makinede `D:\UzmanAdres\...json` olmadığı için **kasa modülü kapalı**
  açılıyor; servisin geri kalanı etkilenmiyor.

### 2. Excel yazıcısı — `FaturaExcel`

- **Neden:** Mutabakat raporu muhasebeye e-postayla gidiyor; ekranda kalan rapor işe
  yaramaz.
- **Ne yapıldı:** `ClosedXML` ile (zaten `Core`'da vardı, `RafExcel` kalıbı izlendi) iki
  sayfalı kitap üreten yazıcı. **Özet** sayfası: şirket/aralık/yön, sayaçlar, tutar
  toplamları ve **uyarılar**. **Faturalar** sayfası: 21 sütun, otomatik filtreli,
  dondurulmuş başlık, sorunlu satırlar zemin rengiyle işaretli.
- **Dokunulan dosyalar:** `src/SentezServis.Core/Fatura/FaturaExcel.cs` (yeni)
- **Kritik kararlar (kod içinde de yazılı):**
  - **ETTN ve fatura no METİN (`@`) biçiminde yazılır.** Excel bunları sayıya çevirirse
    baştaki sıfırlar düşer, uzun numaralar `1,23457E+14` olur ve dosya bir daha
    eşleştirilemez.
  - **Sentez karşılığı olmayan satırda tutar hücreleri BOŞ kalır** — sıfır değil.
    Sıfır yazılırsa "Sentez'de 0 TL kayıtlı" diye okunur ve sütun toplamı yanlış çıkar.
  - **Uyarılar özet sayfasına yazılır.** "Liste EKSİKTİR" uyarısı ekranda görünüp dosyada
    görünmezse, dosyayı alan kişi eksik raporu tam sanar.
- **Sonuç / doğrulama:** `FaturaExcelTestleri` (9 test) üretilen kitabı ClosedXML ile
  **geri okuyarak** doğruluyor — sayfa adları, satır sayısı, metin biçimi, boş hücreler,
  uyarının varlığı, boş sonuçta geçerli dosya, dosya adı.

### 3. `/api/fatura/excel` ucu

- **Neden:** Dosyayı tarayıcıda kurmak, ekranda görünen sütunlarla dosyanın içeriğini
  birbirine bağlardı.
- **Ne yapıldı:** `karsilastir` ile aynı parametreleri alan bir GET ucu.
  **Karşılaştırmayı yeniden çalıştırır** — içerik ekrandaki tablodan değil kaynaktan gelir.
  Bedeli bir CRS turudur; mutabakat ayda birkaç kez alınan bir rapordur, tutarsız dosyaya
  göre defter kapatmaktan ucuzdur. Yön/tarih-alanı çözümlemesi iki uç arasında
  `SecimHatasi` yardımcısında ortaklaştırıldı (biri değiştirilip diğeri unutulamasın).
- **Dokunulan dosyalar:** `src/SentezServis.Host/Api/FaturaUclari.cs`

### 4. Arayüz — `/fatura`

- **Ne yapıldı:**
  - `web/src/api/fatura.ts` (yeni) — uçlar, tipler, etiket sözlükleri.
  - `web/src/pages/FaturaSayfasi.tsx` (yeni) — filtre + özet şeridi + durum sekmeleri +
    tablo.
  - `web/src/utils/fatura.ts` + testi (yeni) — saf biçimleyiciler.
  - `web/src/api/index.ts`, `App.tsx`, `components/Layout.tsx` — bağlama.
- **Kararlar:**
  - **Sorgu kendiliğinden çalışmaz.** Her karşılaştırma CRS'e giden gerçek bir SOAP
    turudur; filtre değişince otomatik tetiklenseydi tarih kutusunda gezinen kullanıcı
    farkında olmadan onlarca çağrı başlatırdı.
  - **CRS kullanıcısı tanımsız şirket listede görünür ama seçilemez.** "Şirket yok" ile
    "yapılandırılmamış" farklı sorunlardır; ikincisini gizlemek yapılandırma hatasını
    görünmez kılar.
  - **Durum süzgeci istemci tarafındadır** — satırlar zaten elde, sekmeye basınca yeni
    CRS turu başlatmak saçma olurdu.
  - **Rota yönetici kısıtlı değil.** Modül ne CRS'e ne ERP'ye yazar. Tek istisna
    "CRS bağlantısını dene" düğmesi: yanıtında yapılandırılmış kullanıcı adı geçtiği için
    yalnızca yöneticiye çıkar (sunucuda da `YoneticiIster`).
  - **`utils/fatura.ts`'teki `faturaTarihi` saat dilimi ÇEVİRMEZ.** `format.ts`'teki
    biçimleyicilerden bilerek ayrı durur: fatura tarihi bir takvim günüdür, bir an değil.
    `2026-08-01T00:00:00`'ı UTC sayıp Europe/Istanbul'a çevirmek tarihi bir gün geriye
    kaydırır ve **ay sonu faturaları yanlış aya düşer**. Aynı sebeple `gunMetni`
    `toISOString()` kullanmaz.
- **Komutlar:**
  ```bash
  cd web && npm run build && npm run lint && npm test
  dotnet build SentezServis.slnx
  dotnet test tests/SentezServis.Core.Tests/SentezServis.Core.Tests.csproj
  ```
- **Sonuç / doğrulama:**
  - `dotnet build SentezServis.slnx` — 0 uyarı, 0 hata (`TreatWarningsAsErrors` açık).
  - `dotnet test` — **242 test geçti** (9'u yeni).
  - `npm test` — **40 test geçti** (12'si yeni). `npm run lint` yeni dosyalarda temiz.
  - Servis yeniden koşturuldu: `/api/fatura/{sirketler,karsilastir,excel,crs-dene}`
    kimliksiz istekte **401**, var olmayan yol **404** → uçlar kayıtlı. `app.js` içinde
    "E-fatura mutabakat" geçiyor → sayfa pakete girmiş.
- **Commit:** `76b63c7` — CRS e-fatura mutabakat arayuzu + Excel disa aktarim

## Kararlar

- Ekran **tek şirket seçer**, hepsini birden taramaz. Backend ucu tek `sirketId` alıyor;
  üç şirketi paralel çağırıp özet kartları göstermek de masadaydı, kullanıcı basit olanı
  seçti. Sonradan istenirse üstüne eklenebilir (uç değişmeden, üç paralel çağrı ile).
- Excel **sunucuda** üretilir. Projede zaten `RafExcel` + `ClosedXML` vardı; istemci
  tarafında xlsx kurmak yeni bir bağımlılık ya da elle ZIP yazmak demekti.
- Kapsam dışı bırakılanlar: birden çok şirketi tek seferde tarayan özet, sonuçların
  veritabanına kaydı.

## Açık kalanlar / sonraki adım

- **CANLI VERİYLE DOĞRULANMADI.** Tüm uçlar kimlik doğrulaması istiyor, elimde geçerli
  bir kullanıcı yok (admin/admin çalışmıyor). Gerçek bir girişle şu üçü denenmeli:
  1. `/fatura` ekranında 01/03/04 şirketleri için karşılaştırma,
  2. "CRS bağlantısını dene" ile unvan eşleşmesi (yanlış hesap bağlı mı),
  3. Excel dosyasının Excel'de açılması (özet + faturalar sayfaları, sütun genişlikleri).
- `FaturaKarsilastirici`'nin kendisi hâlâ canlı doğrulanmış değil — 2026-08-27'de
  decompile'dan kurtarılıp sıralaması yeniden yazılmıştı (bkz. o günün günlüğü).
- Bu makinede kasa modülü kapalı açılıyor (`D:\UzmanAdres\...json` yok). Sunucuda sorun
  değil, ama yerelde kasa ekranı denenemez.
