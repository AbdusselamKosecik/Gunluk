# sentezservis — 2026-09-24

## Bağlam
23.09 madde 9'un devamı: pazaryeri cari/sipariş aktarımı SentezCore2026Test'e. Kullanıcı sorusu:
"e-arşivlerde EInvoiceAlias boş gelmesi lazım değil mi? e-faturalarda VKN'ye göre e-fatura kontrolü
yapan gerekecek".

## Yapılanlar

### 1. EInvoiceAlias ve e-fatura mükellefiyet kontrolü
- **Neden:** Kullanıcı sorusu (yukarıda).
- **Bulgular:**
  - Kod e-arşivde de e-faturada da `EInvoiceAlias=NULL` yazıyor. Canlı ERP'de 2025'te bu alanda müşterinin
    pazaryeri e-postası vardı (230.966 e-arşiv carisi); Ağustos 2026'dan beri hepsi boş, e-fatura dahil.
  - Mükellefiyet kontrolü (CRS `IsEInvoiceUser`, yalnızca 10 haneli VKN, 12 saat önbellek) zaten vardı,
    ama hiç çalışmıyordu. Yedekteki 4.317 carinin tamamında `vkn_tckn` NULL. Sebep: Trendyol'da kod
    `taxNumber`/`tcIdentityNumber` okuyordu; gerçek alan kökteki `identityNumber` (34.493'ü 11111111111,
    ~40'ı gerçek TCKN), kökteki `taxNumber` ise maskeli "***". 34.535 Trendyol siparişinde `commercial=true` yok.
  - CRS'e ulaşılamazsa cari `bilinmiyor` durumunda e-arşiv olarak yazılıyordu.
  - Canlıda Ağustos'tan beri e-fatura carisi: yalnızca 5 HB/HBT (10 haneli VKN) ve 329.x.
- **Ne yapıldı:**
  - `TrendyolSaglayici.KimlikNo`: ilk tamamen rakamdan oluşan değer (fatura adresi taxNumber → kök
    taxNumber → identityNumber → tcIdentityNumber).
  - `PazaryeriCariAktarJob`: `Bilinmiyor` durumundaki cari yazılmıyor, `bekliyor`'da kalıyor, özet mesajında
    "ertelendi" olarak görünüyor.
  - `docs/pazaryeri-carileri.md` güncellendi.
- **Dokunulan dosyalar:** `src/SentezServis.Core/Pazaryerleri/Saglayicilar/TrendyolSaglayici.cs`,
  `.../Cariler/PazaryeriCariAktarJob.cs`, `tests/.../CariUretimTestleri.cs`, `tests/.../CariYaziciSinirTestleri.cs`.
- **Sonuç / doğrulama:** `dotnet test tests/SentezServis.Core.Tests` → 602/602.
- **Commit:** `8a0ad57` — E-fatura kontrolu: Trendyol kimlik no okunur, CRS cevapsizsa cari ertelenir
- **Not:** Değişiklik, yeniden çekilecek siparişlerde etkili olur; paket henüz yeniden alınmadı.

### 2. E-fatura: TCKN de sorulur, PK etiketi EInvoiceAlias'a yazılır
- **Neden:** Kullanıcı kararı: "1111111111 / 11111111111 / 2222222222 / 22222222222 arşiv, sormayacağız,
  diğerlerini soralım; etiketi kaydedelim."
- **Ne yapıldı:**
  - `EfaturaSorgulanabilirVkn`: 10 veya 11 hane, tamamı rakam, tek rakamın tekrarı değil.
  - CRS WSDL (`https://connect.crssoft.com/Services/Integration?wsdl`, xsd0) incelendi: `GetUserAliasses(vknTckn)`
    → `Value/ReceiverboxAliases@Alias`. Canlı deneme (04 hesabı, VKN 9460457653) →
    `urn:mail:e-faturapk@yedigroup.com`. Mükellef olmayan numarada `IsSucceded=true` ama `Value` yok.
  - `CrsIstemcisi.PostaKutusuEtiketiAsync` + saf `PostaKutusuEtiketiOku`: ilk Enabled, SystemDeleteDate'i boş
    ReceiverboxAliases. GB ve irsaliye etiketleri alınmaz.
  - `BelgeTipiBelirleyici.PostaKutusuEtiketiAsync`; `PazaryeriCariAktarJob` e-faturada etiketi alır ve
    `efatura_etiketi`'ne + ERP `EInvoiceAlias`'a yazar. Sorulamazsa `Bilinmiyor` → ertelenir.
  - Deneme betiği: scratchpad `crs_alias.py` (repo dışı).
- **Dokunulan dosyalar:** `src/SentezServis.Core/Fatura/CrsIstemcisi.cs`, `.../Fatura/BelgeTipiBelirleyici.cs`,
  `.../Cariler/PazaryeriCariAktarJob.cs`, `tests/.../CrsPostaKutusuTestleri.cs` (yeni), `CariUretimTestleri.cs`,
  `docs/pazaryeri-carileri.md`.
- **Sonuç / doğrulama:** 608/608 test.
- **Commit:** `6305259` — E-fatura: TCKN de sorulur, alici PK etiketi EInvoiceAlias'a yazilir
- **Test ERP temizliği tamamlandı:** varyant 904, kalem 904, fiş 607, iletişim 612, adres 678, cari 680, kalan 0.

### 3. Canlıdaki anomali düzeltme işleri (SQL Agent, SentezCore2026) — İNCELEME, dokunulmadı
- **Neden:** Kullanıcı: "anomalileri düzeltmek için çalıştırılan sorgular var, bunları da kontrol eder misin".
- **Komut:** scratchpad `isler.py` (msdb sysjobs/sysjobsteps/sysjobhistory, `sqlcmd -y 0`; `-h` ile birlikte kullanılamaz).
- **İşler (hepsi saatte bir, :00'da, CompanyId 2,5,7):**
  - `Arsiv`: faturada IsEInvoice 1→2, koşul cari `TaxNo='11111111111'` ve SpecialCode listesi (Pazarama yok).
  - `Cari MailM`: ECMCurrentAccountCode=NULL, IsSendMail=1 (Boyner/Pazarama yok; biz zaten IsSendMail=1 yazıyoruz).
  - `EticaretM`: faturada IsETrade=1, SpecialCode'a göre web adresi, ODEMEARACISI, EArchivesSendDate/TermDate,
    EArchivesCargoId=648734. Liste bizim kodları (Trendyol, Hepsiburada, Boyner, Pazarama, web) kapsıyor.
  - `Mikro FaturaM`: IsTaxExempted=1 faturada IsEInvoice=2, istisna kodu 301, EInvoiceTypeCode=ISTISNA, kargo 314926.
    Bizim sipariş başlığındaki IsTaxExempted=1'e dayanıyor (23.09'daki mikro düzeltmesi bu yüzden şart).
  - `KargoTakipNoyu faturaya Yaz` (günlük 00:00): siparişin `UD_KargoTakipNumarası` değerini irsaliye ve faturaya
    kopyalıyor (O.IsETrade=1, ≥2026-06-01). Kolon adı doğru (ı); bizim 23.09'daki kolon düzeltmemiz bu işin çalışması için şart.
- **Bulgular:**
  1. **Gerçek TCKN riski:** Sentez, e-arşiv carisinin faturasını bazen IsEInvoice=1 kesiyor; `Arsiv` bunu yalnız
     yer tutuculu TaxNo'da düzeltiyor. Canlıda düzeltilmemiş 4 fatura var: 1103597 (HB0004920), 1157456
     (HB0005147) — gerçek TCKN'li; 1145945 (PZR0000557), 1150067 (PZR0000566) — Pazarama listede yok.
     Trendyol'dan gerçek TCKN almaya başlayınca bu vakalar artar.
  2. `EticaretM` 9/50, `Mikro FaturaM` 19/50 çalışmada deadlock kurbanı; hepsi aynı anda (:00) başlıyor.
  3. `Rpt_Satis_Yukle` 25/25 hata (kapsam dışı, not edildi).
  4. `Pazarama ` (sonda boşluklu) SpecialCode'lu 4 fatura; hiçbir iş bunları yakalamıyor.
  5. Bu işler SentezCore2026Test'te yok → testte fatura alanları düzeltilmez; karşılaştırmada hesaba katılmalı.
- **Öneri (uygulanmadı, canlıya yazılmaz):** `Arsiv` koşulu `Erp_CurrentAccount.IsEInvoice = 2` olsun ve
  listeye Pazarama eklensin; işlerin başlangıç dakikaları kaydırılsın (:00/:10/:20/:30).

### 4. Kullanıcı kuralı: canlıda e-ticaret düzenlemesi yok
- **Kullanıcı:** SQL Agent işlerinin metinlerini yapıştırdı ve "SentezCore2026 DB'sinde hiçbir düzenleme yapma bu
  e-ticaret konusunda" dedi. Madde 3'teki öneriler (Arsiv koşulu, iş saatleri) geri çekildi, canlıya hiçbir şey yazılmadı.
- **Kontrol (salt okuma):** İşlerin faturada düzelttiği alanların sipariş tarafı bizde yazılıyor:
  IsETrade=1, IsTaxExempted (mikro), UD_KargoTakipNumarası, EArchivesWebAddress/EArchivesPaymentType (hesap
  parametresi). Parametreler canlı siparişlerle aynı: Trendyol/HB/Boyner/Pazarama `www.<pazaryeri>` +
  ODEMEARACISI; Shopify `www.Shopify.com` + DIGER (canlıda 1.487 DIGER, 1 EFT/HAVALE). EArchivesCargoId siparişte
  yazılmıyor; canlıda da siparişlerin çoğunda NULL (Trendyol'da 30.691 NULL, 4.401 dolu (314926)); faturada iş dolduruyor.
- **Sonuç:** Kod değişmedi. Fatura alanları (IsEInvoice, 301, ISTISNA, kargo Id) bizim kapsamımızda değil; test
  ERP'de bu işler çalışmadığı için orada fatura karşılaştırması yapılmayacak.

### 5. Yerel deneme: çek → cari → sipariş, canlıyla karşılaştırma
- **Neden:** Kullanıcı: "localde çalıştırıp deneyelim mi?"
- **Güvenlik kararı:** Paylaşılan SentezServices'e ikinci kopya bağlanmaz. Sebepler:
  - Zamanlayıcıda tetiği tek kopyaya ayıran kilit yok; e-arşiv gönderimi iki kez çalışırdı.
  - Açılışta canlının mükerrerlik kilitleri serbest bırakılırdı (`IsKayitDefteri.EsitleAsync`).

  Bu yüzden:
  - LocalDB `SentezServisYerel` oluşturuldu; migration'lar açılışta koştu.
  - `pazaryeri_hesaplari` kopyalandı (10 hesap; scratchpad `hesap_kopyala.py`).
  - Yeni ayar `ZamanlayiciEtkin` (varsayılan true) eklendi.
  - Yerelde zamanlayıcı, e-posta ve toplayıcı kapalı. Ortam değişkenleri scratchpad `yerel_calistir.sh`'ta;
    `SentezServis.exe` ile çalıştırılır. `dotnet x.dll` içerik kökünü `C:\Program Files\dotnet` yapıyor,
    appsettings okunmuyordu.
  - Adres `http://localhost:81` (Kestrel yapılandırması).
  - API: scratchpad `api.py` (CSRF başlığı `X-CSRF-Token`; Git Bash'te `MSYS_NO_PATHCONV=1`).
- **Çalıştırmalar:**
  - JOB-1 `pazaryeri-siparis-cek` 23.09, kapsam=hepsi → 6.822 sipariş. 23.09 tarihli olanlar 1.575; gerisi
    23.09'da güncellenen eski siparişler. Trendyol'da 6 gerçek TCKN geldi (madde 1 düzeltmesi çalışıyor),
    156 mikro. HB hâlâ 0.
  - JOB-2/3/4 `pazaryeri-aktarim`: 230 cari ve 230 fiş SentezCore2026Test'e yazıldı, hata yok.
- **Karşılaştırma** (scratchpad `karsilastir.py`, eşleşme `ECMOrderNo`): canlıda bulunan 191 fişte birebir tutanlar:
  - sipariş no, tarih, saat (Shopify UTC→TR dahil), genel toplam, KDV, masraf 0;
  - istisna (mikro), IsETrade, özel kod, web, ödeme tipi;
  - cari SpecialCode (web), cari e-fatura durumu, kalem sayısı, KDV oranları.
- **Bulunup düzeltilenler:**
  1. KDV kuruş farkı (22 Shopify fişi). Canlı net tutarları 8 haneyle saklıyor; başlık matrahı = KDV'li toplam /
     çarpan (`1559,60/1,10 = 1417,81818182`). `Toplamlar.NetHane = 8`, başlık oran bazında hesaplanıyor.
  2. Shopify numarası: canlı `DocumentNo=60622` (`#` yok), `MarketPlaceOrderNo=NULL`. `FisSiparisNo` /
     `PazaryeriSiparisNo` eklendi; mükerrer kontrolü `ISNULL(MarketPlaceOrderNo, DocumentNo)`.
  3. İlçe: il `Izmir`, ilçe `İzmir` Türkçe kültürde eşleşmiyordu → invariant + IgnoreNonSpace. `Tuzla/ istanbul`
     → bütün parçalar deneniyor.
- **Bilinçli / bilinen farklar:**
  - Kargo adı `PTT Kargo Marketplace` / `PTT Kargo` (148 fiş).
  - Shopify takip no: canlıda fiş eklendikten saatler sonra başka bir süreç yazıyor.
  - Shopify `UD_EMail`: canlı boş, biz kullanıcı isteğiyle yazıyoruz.
- **Canlıda olmayan 39:** 32 Shopify (16:57 sonrası), 4 geç Trendyol, 1 Boyner "Yeni", 2 **iptal** Trendyol.
- **İptal ölçümü** (23.09 15:00 öncesi Trendyol):
  - IptalEdildi 58 → canlıda 34 fiş var: 29'u irsaliyeli ve kapalı (kargodan sonra iptal), 5'i açık. 24'ü hiç yok.
  - İade 79/79 var; TeslimEdildi 1.344/1.345 var.
  - Bizim hazırlık adımında durum filtresi yok; iptal siparişi de yazıyor. **Kullanıcı kararı bekliyor.**
- **Test verisi temizliği:** Kod değiştikçe `#`'li 20 Shopify fişi, sonra deneme fişlerinin tamamı (210 fiş / 331
  kalem / 331 varyant) SentezCore2026Test'ten silindi, yerel defter `bekliyor`'a çekildi, yeniden yazıldı.
- **Dokunulan dosyalar:** `Ayarlar.cs` (yalnız `ZamanlayiciEtkin` hunk'ı; başka oturumun KuyrukSinirlari
  değişikliği dışarıda), `Zamanlama/ZamanlayiciServisi.cs`, `Cariler/AdresEslestirici.cs`,
  `SiparisAktarimi/SentezSiparisYazici.cs`, `SiparisAktarimi/Toplamlar.cs`, 3 test dosyası,
  `docs/pazaryeri-siparis-aktarimi.md`.
- **Sonuç / doğrulama:** 612/612 test.
- **Commit:** `723ea8a` — Yerel deneme bulgulari: KDV 8 hane, Shopify numarasi, ilce eslesmesi
- **Not:** Live SentezCore2026'da Trendyol fişleri 23.09 23:21'e kadar eklenmiş → eski entegrasyon hâlâ çalışıyor olabilir.

### 6. Arayüzden çalıştırınca 400: boolean parametre
- **Kullanıcı:** "cari üretimlerini neden atlıyorsun; ben çalıştır deyince backend hata veriyor".
- **Cevap 1:** JOB-4'te cari adımlarını ben kapatmıştım (`cariUret=false`, `cariAktar=false`); yalnızca fişleri
  yeniden yazmak içindi.
- **Hata 2:** Yerel log: `BadHttpRequestException ... Path: $.parametreler.cariUret ... token type 'True' as a
  string`. Dinamik form onay kutusunu JSON `true` gönderiyor; `CalistirIstegi.Parametreler` ise
  `Dictionary<string,string?>`. API denemelerimde metin gönderdiğim için görünmemişti.
- **Ne yapıldı:** `src/SentezServis.Host/Api/EsnekParametreDonusturucu.cs`: metin/sayı/boolean/null → metin.
  `CalistirIstegi` ve `CronIstegi` bunu `[property: JsonConverter]` ile kullanıyor.
- **Doğrulama:** JOB-5, arayüz biçimiyle (`"azami":1000, "cariUret":true ...`) → 202. Sonuç: 1.000 cari (195 sn),
  985 fiş (461 sn); parametreler işe `'true'` olarak ulaştı. Bazı barkodlar test ERP'de yok (8699170389422 vb.).
- **Commit:** `2cd81a9` — Is parametreleri: onay kutusu true/false degeri 400 veriyordu

### 7. Tekrar aktarımda güncelleme, iptal, eksik barkod
- **Kullanıcı:** "bulunmayan barkodları nasıl göndermemiz lazım, yoksa eklememiz lazım, tekrar aktar dediğimizde
  güncellememiz lazım, iptalse iptal etmemiz lazım."
- **İnceleme:**
  - "Karşılığı yok" denen 8 barkod test ERP'de yalnız CompanyId 2'de (01) var. Canlıda CompanyId 7 (04) için
    15.09.2026'da **elle** eklenmiş (kullanıcı 12, Ahmet Adalar). Stok kartı 2023'ten beri vardı; eksik olan
    barkod ve varyanttı. Test kopyası bundan eski.
  - Canlıda iptal hiç işlenmiyor: Eylül'de hiçbir e-ticaret fişi ya da kalemi IsCancelled=1 değil, silinen yok.
- **Kullanıcı kararları (AskUserQuestion):**
  - Eksik barkod → beklet ve raporla.
  - Güncelleme → sevk edilmediyse tam.
  - İptal → sevk edilmediyse iptal.
- **Ne yapıldı:**
  - Migration `020_siparis_aktarim_ozeti.sql`: `icerik_ozeti VARCHAR(64)`.
  - Yeni durumlar `iptal_bekliyor` ve `iptal_edildi`.
  - Hazırlık aktarılmış siparişleri de okuyor (defter durumu, özet ve erp_rec_id ile). Karar saf fonksiyonda:
    `PazaryeriSiparisHazirlaJob.DefterKarari`. İçerik özeti `IcerikOzetiHesapla` (SHA-256; başlık, cari/adres,
    parametreler, kalem ürün/fiyat). İptal kontrolü diğer bütün kontrollerden önce yapılıyor.
  - Hazırlık özeti eksik barkodları şirket/barkod olarak tam listeliyor.
  - Yazıcı: `GuncelleAsync` ve `IptalEtAsync`. `IslemGormusSql` fişi işlem görmüş sayar: başlık ya da kalem
    IsClosed, veya kalem Erp_InventoryReceiptItem, InventoryAllocation, BoxItem, Requirement, ExpoItem ya da
    BankCreditItem'a bağlı. Takip no, kargo ve e-posta boşla ezilmiyor (ISNULL). `AyniHedef`: başka veritabanına
    yazılmış fişin RecId'si kullanılmıyor. Başlık parametreleri `BaslikDegerleri`'ne, kalemler
    `KalemleriYazAsync`'e taşındı.
  - Defter: `SonucYazAsync` fiş izini boşla ezmiyor (`ISNULL(@erpRecId, erp_rec_id)`).
  - Aktarım işi iptal, güncelleme ve yazma sayılarını ayrı ayrı raporluyor.
- **Dokunulan dosyalar:** `SiparisAktarimi/{SiparisAktarimModelleri,SiparisAktarimDeposu,PazaryeriSiparisHazirlaJob,
  PazaryeriSiparisAktarJob,SentezSiparisYazici}.cs`, migration 020, `tests/.../SiparisGuncellemeTestleri.cs` (yeni),
  `SiparisYaziciSinirTestleri.cs`, `docs/pazaryeri-siparis-aktarimi.md`.
- **Sonuç / doğrulama:** 626/626 test. Yerelde canlı deneme **yapılmadı**: yerel host'u Claude Code bellek
  sıkışıklığı yüzünden durdurdu; kullanıcı onayı bekleniyor.
- **Commit:** `0e83342` — Siparis aktarimi: tekrar aktarimda guncelleme, iptal, eksik barkod raporu

## Açık kalanlar / sonraki adım
- Güncelleme/iptal akışının yerelde uçtan uca denenmesi (host yeniden başlatılacak, 020 migration'ı koşacak).
- Yerel host çalışıyor olabilir (http://localhost:81, LocalDB `SentezServisYerel`); scratchpad `yerel_calistir.sh`.
- Boyner'de 102 siparişin tamamı `kurumsal_fatura=1`; şüpheli, bakılmadı.
