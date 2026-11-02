# sentezservis — 2026-11-02

## Bağlam
Kullanıcı: görevlere (zamanlanmış işler) birden fazla zaman eklenebilmeli.

## Yapılanlar

### 1. Bir işe birden fazla zaman
- **Neden:** `CronHesaplayici` `;` ile ayrılmış ifadeleri zaten ayrı ayrı tetikliyordu, ama arayüz tek dar metin kutusuydu
  ve `zamanlamalar.cron` VARCHAR(128) birkaç ifadeden sonra doluyordu.
- **Ne yapıldı:**
  - `web/src/utils/zamanlama.ts`: `cronSatirlari` (`;` → satırlar, boşsa tek boş satır), `cronBirlestir` (boş/tekrar atlanır, `"; "` ile birleşir) + vitest.
  - `ZamanlamaSayfasi.tsx`: her zaman ayrı input, ✕ ile sil, "+ Zaman ekle"; Kaydet birleştirip PUT `/isler/{anahtar}/zamanlama`.
    Salt okunur rolde her zaman ayrı `<code>` satırı. Başlık "Zamanlar (cron)".
  - `CronHesaplayici.Dogrula` (boş / >1000 karakter / "Geçersiz cron ifadesi: <ifade>"); `IsUclari` PUT bunu kullanır. Testler eklendi.
  - Göç `018_cok_zamanli_cron.sql`: `cron` VARCHAR(1000) (idempotent). Mock doğrulaması `;`'lü ifadeleri kabul eder.
- **Komutlar:** `dotnet test tests/SentezServis.Core.Tests` (293 geçti), `npx vitest run` (61 geçti), `npm run build`, `dotnet build src/SentezServis.Host`.
  Mock modda (`VITE_MOCK=1 npx vite --port 5299`) Chrome ile denendi: E-fatura'ya `30 14 * * 1-5` eklendi, kayıt sonrası iki satır duruyor.
- **Commit:** `7786f82` — Zamanlama: bir ise birden fazla zaman (satir satir ekle/sil), cron sutunu 1000 karakter (goc 018)

## Kararlar
- Ayrı tablo (zaman başına satır) yerine mevcut `;` biçimi korundu: zamanlayıcı ve API değişmeden çalışıyor, tüm zamanlar aynı parametrelerle koşar.

## Açık kalanlar / sonraki adım
- Sunucuya yayın yapılmadı (göç 018 açılışta çalışır). `wwwroot/.gitkeep` silinmesi bu işten önceydi, commit'e alınmadı.

---

## Bağlam (akşam, 20:30) — Müşteri sesi
Kullanıcı: tüm ürünlerin yorumları (zamanla), iade sebepleri (zamanla) müşteri bilgisiyle; iptaller 1 yıldız;
yıldıza göre istatistik. Herkes görsün, şirket durumu ve "hangi üründe ne sorun var" analizi. Çözüldü/çözülmedi
önemli değil, HACİM önemli. Konu sınıflandırması (AI) şimdilik yok, kullanıcı yerelde çözecek.
"Bir servis, bir dashboard, bir arama sayfası yeterli — sen düşün yap."

### 2. Araştırma: hangi pazaryeri ne veriyor
- **Trendyol iade:** `GET https://apigw.trendyol.com/integration/order/sellers/{sellerId}/claims`
  (`startDate`/`endDate` epoch ms, **lastModifiedDate**'e uygulanır; `size` ≤ 200). Şema:
  `curl -sL https://developers.trendyol.com/reference/getclaims.md` (içinde OpenAPI JSON).
  Alanlar: `claimId, orderNumber, orderDate, claimDate, customerFirstName/LastName, lastModifiedDate,
  items[].orderLine{barcode, productName, merchantSku, productColor, productSize, price, productCategory},
  items[].claimItems[]{id, customerClaimItemReason{name, externalReasonId, code}, trendyolClaimItemReason, claimItemStatus{name}, customerNote}`.
- **Trendyol yorum:** resmi satıcı API'sinde YOK (`https://developers.trendyol.com/llms.txt` dizininde yalnızca müşteri soruları).
- Hepsiburada dokümanı bot korumalı (okunamadı); Pazarama/Boyner/Shopify için doğrulanmış yorum/iade ucu yok.
- İptaller zaten `pazaryeri_siparisleri.durum = 'IptalEdildi'` (pazaryeri-siparis-cek, her gece 03:00, son 30 gün iptal/iade).

### 3. Uygulama
- **Ne yapıldı:**
  - `PazaryeriYetenekleri.IadeCekme/YorumCekme`, `IIadeKaynagi`, `IYorumKaynagi` (`IPazaryeriSaglayici.cs`),
    modeller `Pazaryerleri/MusteriSesiModelleri.cs` (`IadeSorgusu`, `PazaryeriIadesi` kalem bazında, `PazaryeriYorumu`).
  - `TrendyolSaglayici.IadeleriGetirAsync` (14 günlük pencere, sayfalı) + `public static IadeOku(JsonElement, sirket)`:
    müşteri sebebi öncelikli, yoksa Trendyol sebebi. Şemada (`PazaryeriAyarlari.cs`) Trendyol'a `IadeCekme` eklendi
    (test sağlayıcı yetenekleri ile şemayı eşit ister).
  - Göç `022_musteri_sesi.sql`: `musteri_sesi_iadeler` (tekil: sirket+pazaryeri+iade_kalem_no),
    `musteri_sesi_yorumlar` (yildiz CHECK 1–5, boş `konu`), görünüm `v_musteri_sesi` (tur yorum/iptal/iade;
    iptal kalem bazında yildiz=1, zaman=COALESCE(degisiklik_tarihi, durum_degisiklik_zamani, siparis_tarihi); iade yildiz NULL).
  - `MusteriSesi/MusteriSesiDeposu.cs`: UPDATE+IF @@ROWCOUNT=0 INSERT upsert (yorumda `konu`'ya dokunmaz),
    `OzetAsync` (QueryMultiple: sayılar, 1–5 dağılım hep 5 eleman, ortalama iptal dahil/yalnız yorum, günlük (+3 saat sabit TR),
    ilk 50 ürün şikâyet = iptal+iade+≤2★ yorum + en sık sebep, ilk 15 sebep), `AraAsync` (sayfalı, LIKE kaçışlı).
  - `MusteriSesi/MusteriSesiToplaJob.cs`: `musteri-sesi-topla`, cron `30 3 * * *`, `sonGun` varsayılan 3 (max 365), şirket/pazaryeri süzgeci,
    hesap patlarsa diğerleri sürer.
  - `Host/Api/MusteriSesiUclari.cs`: `GET /api/musteri-sesi/ozet`, `GET /api/musteri-sesi/kayitlar` — `GirisIster()` (herkes).
    `Program.cs`: depo singleton, iş transient, uçlar.
  - Web: `api/musteriSesi.ts`, `pages/MusteriSesiPanosu.tsx` (/musteri-sesi), `pages/MusteriSesiAramaSayfasi.tsx`
    (/musteri-sesi/ara, süzgeçler URL'de), `pages/MusteriSesi.css`; menü (Layout'ta alt yolu olan bağlantıya `end`), rotalar.
    Renkler yorum #2a78d6 / iptal #eb6834 / iade #1baf7a (dataviz validator: CVD ΔE 9.2 PASS; iade kontrast WARN → değerler yazılı + tablo görünümü).
- **Dokunulan dosyalar:** yukarıdakiler + `tests/SentezServis.Core.Tests/MusteriSesiTestleri.cs`, `web/src/pages/MusteriSesi.test.tsx`.
- **Komutlar:**
  ```bash
  dotnet build SentezServis.slnx          # 0 uyarı
  dotnet test tests/SentezServis.Core.Tests   # 722 geçti
  cd web && npx tsc -b && npx vitest run && npm run build   # 78 test geçti
  # SQL doğrulama: LocalDB'de ms_dene oluşturuldu, 011 + 022 iki kez uygulandı (idempotent),
  # scratchpad'de Core'a referanslı konsol ile depo çağrıldı, sonra DB silindi.
  ```
- **Sonuç / doğrulama:** LocalDB'de upsert güncelliyor, 9★ yorum eleniyor, iptal 1★, ort 2,50 / yorum ort 4,00, `%` jokersiz, boş aralık null-güvenli.
  Tarayıcıda gözle bakılmadı (mock katmanında müşteri sesi yok).
- **Commit:** `f1b3013` — Musteri sesi: iade/yorum toplama servisi, dashboard ve arama sayfasi

## Kararlar (müşteri sesi)
- İptal ayrı çekilmez; sipariş tablosundan görünümle okunur. Kalem bazında sayılır (ürün istatistiği için).
- İade yıldız sayılmaz, sebebiyle sayılır. Ortalama iki türlü gösterilir (iptal dahil / yalnız yorum).
- Yorum altyapısı hazır ama kaynağı yok — resmi API olmadan kazıma yapılmadı.

## Açık kalanlar (müşteri sesi)
- Sunucuya yayın yapılmadı. Yayından sonra `musteri-sesi-topla` bir kez elle `sonGun=365` ile çalıştırılmalı.
- Yorum kaynağı: pazaryeri yorum API'si açarsa sağlayıcıya `IYorumKaynagi` eklenecek.
- Hepsiburada iade ucu doğrulanamadı (doküman bot korumalı) — erişim bulunursa `IIadeKaynagi` eklenir.
- **Tutarsızlık:** yukarıdaki 1. bölümdeki `7786f82` / göç `018_cok_zamanli_cron.sql` bu repoda ve GitLab origin/main'de YOK
  (repoda 018 = `018_rayic_hesaplari.sql`). Başka bir klonda kalmış olabilir.
