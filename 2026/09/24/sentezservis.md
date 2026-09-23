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

## Açık kalanlar / sonraki adım
- Kullanıcı kararı: `Arsiv` işinin koşulu (TaxNo yer tutucu → cari IsEInvoice=2) ve iş saatlerinin kaydırılması.
- Boyner'de 102 siparişin tamamı `kurumsal_fatura=1`; şüpheli, bakılmadı.
