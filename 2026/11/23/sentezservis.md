# sentezservis — 2026-11-23

## Bağlam
- **Kullanıcının isteği:**
  - Sentez'de ana döviz artık USD; paralel USD silindi.
  - TCMB'den yalnız USD/TL alınacak.
  - Mısır Merkez Bankası'ndan günlük kurlar alınacak; TL dışındaki kurlar USD'ye paritelenip Sentez'e yazılacak.
  - Her gün 07:00'de SentezServis çalıştıracak.
- **Kullanıcının sonradan eklediği:**
  - Mısır'ın geçmiş kurları için `Downloads\Exchange Rates Historical.xlsx` dosyası verildi.
  - TCMB geçmişi TCMB'den çekilecek.
  - "Sentez'inkini kapattım": Sentez'in kendi TCMB aktarımı (her gün 10:09'da TL bazlı kur yazıyordu) kullanıcı tarafından kapatıldı.
  - "SentezServis'i düzeltip sunucuya yükler misin."

## Bulgular (canlı SentezCore)
- **Tablolar:**
  - `Meta_ForexRate` (RecId identity, RateDate, ForexId, RateId, Price decimal(28,8)).
  - `Meta_Forex` döviz kodları: USD=1, EUR=2, GBP=3, TL=17, LE=18 (Egypt Pound).
  - `Meta_ForexPrm` kur tipleri: 1 Genel Alış, 2 Genel Satış, 3 Efektif Alış, 4 Efektif Satış.
- **USD kayıtları:** 23.11 08:38'de silinmiş; yedeği `zz_bak_MetaForexRate_USD_20261123` tablosunda (2.388 satır). Silmeyi biz yapmadık.
- **CBE sitesi:** Yalın istekleri F5 duvarı "Request Rejected" ile reddediyor; tarayıcı başlıklarıyla (User-Agent, Accept, Accept-Language, Accept-Encoding) sayfa geliyor.
  - Sayfada "Rates for Date: dd/MM/yyyy" satırı ve Currency | Buy | Sell tablosu var. Efektif kur yok; "Japanese Yen 100" 100 birim üzerinden.
- **Mısır geçmiş Excel'i:** Yalnız US Dollar ve Euro var (2025-01-02 – 2026-11-22, 457 gün); GBP yok.

## Kararlar
- **Kur yönü (kullanıcı, seçenek "A"):** `Price` = 1 birim dövizin USD karşılığı (1 TL = 0,0198 USD, 1 LE = 0,0186 USD, EUR = 1,0967).
- **Benim kararlarım:**
  - Alış alışa, satış satışa bölünür.
  - CBE efektif kur yayımlamadığı için efektif = genel.
  - CBE'de olmayan EUR/GBP için TCMB çapraz kuru kullanılır (geçmişte GBP bu yolla geldi).
  - Bugünün tarihiyle yazılır; kaynak, o günden ÖNCE yayımlanmış son bülten.
  - Kaynak 10 günden eskiyse yazılmaz.
  - Bir kaynak hata verirse diğerininki yazılır, iş hata ile biter ve 3 kez dener.
  - Sentez'e yazma için ayrı bir aç/kapa ayarı konmadı: işin kendisi istek; panelden kapatılabilir.

## Yapılanlar

### 1. Döviz kurları işi (`f17913e`)
- **Dokunulan dosyalar:**
  - `src/SentezServis.Core/Doviz/`:
    - `DovizModelleri.cs`
    - `DovizParitesi.cs`
    - `DovizKaynaklari.cs`: TCMB today.xml ve arşiv `kurlar/yyyyMM/ddMMyyyy.xml` (404 = bülten yok), CBE ayrıştırma.
    - `DovizKuruDeposu.cs`: günü sil + yeniden ekle; yalnız Meta_ForexRate.
    - `DovizKurlariJob.cs`: `doviz-kurlari`, `0 7 * * *`.
  - `Host/Program.cs`: kayıt.
  - Testler: `DovizKurlariTestleri.cs` ve `Veri/` (gerçek CBE sayfası ile TCMB 20.11 bülteni).
  - Kaynak taraması testine eklenenler:
    - `DovizKuruDeposu` → yalnız `Meta_ForexRate`.
    - Salt okuyan `UretimRaporDeposu`: test zaten kırmızıydı.
- **Testler:** 362 geçti, 2 başarısız. Kalan ikisi (`KoliListe…Kullanicinin_ornegi`, `SiparisDeposu…Onizleme`) değişiklik öncesinde de başarısızdı; `git stash` ile denendi, canlı veri kaynaklı.
  - Canlı DB testi `SENTEZCORE_TEST` ile çalıştı, işlem geri alındı.
  - Çalıştırma: scratch `sentestest.cs` bağlantıyı malkabul ayarlarından ortam değişkenine koyar, yazdırmaz.

### 2. Sunucuya kurulum
- `deploy/yayinla.ps1` (ayrı powershell süreci) → `yayin/` (18 dosya, appsettings yok).
- Yedek: `\192.168.0.2\C$\Server\SentezServis\yedek-2026-11-23-78184d6\`.
- Sırası: `sc stop` → kopyala → `sc start`. appsettings tarihi değişmedi.
- `/api/surum` → `1.0.0+f17913e`.
- Yeni iş, servis açılışında `dbo.zamanlamalar`'a `0 7 * * *` aktif olarak girer (IsKayitDefteri).

### 3. Geçmiş kurların yeniden yazılması (tek seferlik betik)
- **Betik:** scratch `doviz/gecmis.cs`, SentezServis.Core'u referans alır.
  - Kaynaklar: Mısır Excel'i, TCMB arşivi (475 bülten, önbellekli) ve `DovizParitesi`.
  - Her takvim günü için önceki son bülten kullanıldı. Aralık 2025-01-02 – 2026-11-22: 690 gün × 16 = 11.040 satır, tek işlemde.
- **Yedek:** Mevcut EUR/GBP (TL bazlı) 4.776 satır → `X:\Gitlab\modfex-apparel\yedek\Meta_ForexRate-EUR-GBP-TL-LE-2026-11-23.csv`.
- **Bugün (23.11):** Canlı kaynaklardan aynı kodla 16 satır yazıldı: EUR 1,09670, GBP 1,30810, LE 0,018395, TL 0,019840.
  - Bu, sunucudaki işin CBE'ye erişebildiğinin kanıtı değildir.
- **Toplam:** Meta_ForexRate 11.056 satır.
- **Geri dönüş:**
  - CSV'deki satırlar geri yüklenir.
  - Kurulan satırlar silinir: `ForexId IN (2,3,17,18)`, InsertedAt 23.11.

## Açık kalanlar
- Sunucudaki işin CBE'ye gerçekten erişebildiği yarın 07:00 çalışmasında ya da panelden "şimdi çalıştır" ile görülmeli.
- Mısır'ın resmi tatillerinde CBE 10 günden uzun yayımlamazsa iş hata verir; gerekirse eşik büyütülür.
- `uzaktan-yayimla.ps1` hâlâ Get-Credential istiyor; kurulum elle yapıldı.
