# malkabul — 2026-11-16

## Bağlam
Kullanıcı seri tabanlı depo akışını 5 işe böldü (1 mal alım seri, 2 sayım, 3 tahsis, 4 Selvedge inspection, 5 kesimhane seri okutma).
Bugün 1. iş: Windows'ta seri oluştur (siparişten / Excel'den), el terminalinde seri okutarak içeri al (fiş 1 → depo 43).
15.11 tarihli malkabul tasarımı (seri terminalde üretiliyordu) bununla değiştirildi.

## Yapılanlar

### 1. Tasarım + plan
- **Neden:** seri ve etiket mal gelmeden masada hazırlansın; stok yalnız okutulunca girsin.
- **Kararlar (kullanıcı):** yaklaşım A (her şey malkabul içinde: Desktop = seri hazırlama, Android = okutma); fiş fiyatlı ("Siparişteki neyse o").
- **Kararlar (benim):** bir irsaliye = bir fiş (SpecialCode 'UZMMK', cari + DocumentNo), seri başına kalem, okutmada fazla teslim engellenmez,
  Excel şablonu bizim (`Sipariş no | Satır | Stok kodu | Renk | Beden | Miktar | Lot | Adet`), depo ayardan (`MalKabulDepoId`, 43).
- **Dosyalar:** `docs/superpowers/specs/2026-11-16-seri-olustur-okutarak-al-design.md`, `docs/superpowers/plans/2026-11-16-seri-olustur-okutarak-al.md`
- **Commit:** `2262a1c`, `205cf60`

### 2. Uygulama (7 görev, satır içi, TDD)
- **Kurallar:** `SeriKabulKurallari` (Explanation "SAS no/satır" çözümleme, irsaliye no ≤ 30, fiyat ölçekleme — canlı fiş 721454 ile aynı sonuç),
  `ExcelSeriKurallari` (ayrıştırma, Türkçe/büyük-küçük/boşluk duyarsız eşleşme, 500 satır / 2000 seri sınırı, fazla uyarısı).
- **Depo:** `MalKabulDeposu` — `SiparisleriGetirAsync`, `SeriliStoklarAsync`, `ExceldenOlusturAsync` (tek transaction, tek applock),
  `SeriSilAsync` (yalnız içeride değilse), satırlarda `HasSeries` + `IceriAlinan`, serilerde `Iceride`.
- **Fiş:** `MalKabulFisDeposu` — `SeriIceriAlAsync`, `SerisizEkleAsync`, `IrsaliyeKalemleriAsync`. Kilit `UZM_MalKabulFis`.
  `FisSql.cs` sevkiyatmobil'den üretildi (scratchpad `fissql.py`: VALUES listesinde DocumentNo/ReceiptUpType ve 24 fiyat kolonu `@param`).
  Seri hareketi: ItemType 1, TransactionType 1, InWarehouseId 43; başlık toplamları kalemlerin SUM'ı.
- **Ekranlar:** Windows: `AnaMenu`, `ExcelSeri` (şablon indir, dosya seç, önizleme, oluştur+bas), seri listesinde durum + Sil (ikinci basış).
  Android: `IceriAl` (irsaliye → okut → yeşil/sarı/kırmızı sonuç kutusu), `SerisizEkle`. ClosedXML yalnız `MalKabul.Desktop`'ta (`ClosedXmlExcel`, `ExcelDosyasi` kancaları).
- **Komutlar:**
  ```bash
  MODFEX_DB_TEST=1 dotnet test MalKabul.Tests        # canlı SentezCore, tek transaction + ROLLBACK
  MODFEX_TEST_CIKTI=<klasör> dotnet test MalKabul.Tests --filter EkranGoruntusu
  dotnet publish MalKabul.Android -c Release -o $TEMP/mk_apk
  dotnet publish MalKabul.Desktop -c Release -r win-x64 --self-contained -p:PublishSingleFile=true -o $TEMP/mk_win
  ```
- **Sonuç:** 80/80 test (DB dahil). Dağıtım: `dagitim/malkabul-2026-11-16.apk`, `dagitim/malkabul-masaustu-2026-11-16.zip` (gitignore'da). Windows exe açılıyor.
- **Commit:** `8dc1c51` … `ebb39e7`

### 3. Son gözden geçirme düzeltmeleri
- Seri silme ile okutma farklı kilitteydi (yarış: silinen karta stok girebilirdi) → silme de `UZM_MalKabulFis` alır.
- Silinmiş (IsDeleted) seri hareketi "içeride" sayılıyordu → filtre eklendi.
- **Commit:** `34ffe1a`

## Kararlar
- İlk sürümde terminalde geri alma yok; yanlış okutma Sentez'den silinir (silinen hareket artık içeride sayılmaz).
- Onay pencereleri yerine ikinci basış (fazla onayı, silme).

## Açık kalanlar / sonraki adım
- PM66 bağlı değildi: APK kurulmadı. Kullanıcı canlıda T-00000001 ile ilk denemeyi yapacak (Windows'ta seri → terminalde okut → Sentez'de fiş).
- Ertelenen küçükler: Excel oluşturma anında yeniden doğrulama, başlık üstü boş satır, "1,250" binlik, silme onayı süresiz, fiyatsız kalemde ForexRate 0.
- Sonraki işler: 2 sayım, 3 tahsis, 4 Selvedge inspection, 5 kesimhane seri okutma.
