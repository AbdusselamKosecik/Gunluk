# sentezservis — 2026-09-19

## Bağlam

18.09'da yazılan belge kontrol ekranı (UUID → CRS + Sentez) kullanıcıdan **şirket ve tarih
aralığı** istiyordu; sebebi "CRS'te UUID ile tek belge çeken operasyon yok" varsayımıydı.
Kullanıcı şirket bağımsız arama istedi. Ayrıca üç yeni iş açıldı (pazaryeri servislerinin
birleştirilmesi, sipariş çekerken e-fatura/e-arşiv/mikro ihracat kontrolü, e-arşiv
oluştur/gönder ve kontrol servisleri).

## Yapılanlar

### 1. CRS WSDL'i okundu — varsayım yanlışmış

- **Neden:** Ekran şirket+tarih istiyordu ve bu, kullanıcının işini zorlaştırıyordu.
  "CRS'te tekil sorgu yok" bilgisi **koddan** çıkarılmıştı (bizde 3 operasyon kullanılıyor),
  servisin kendisinden değil.
- **Ne yapıldı:** `https://connect.crssoft.com/Services/Integration?wsdl` ve beş XSD indirildi.
- **Sonuç: serviste 65 operasyon var** ve aradıklarımız mevcut:
  - `GetOutboxInvoice(invoiceId)` — tekil belge
  - `QueryOutboxInvoiceStatus(invoiceIds[])` — **toplu** durum
  - `IsEInvoiceUser(vknTckn, alias)`, `FilterEInvoiceUsers`, `GetEInvoiceUsers` — 3. madde için
  - `SendInvoice`, `ValidateInvoice`, `CancelEArchiveInvoice`, `RecoverEArchiveCancel` — 4. madde için
- **Ders:** Dış servisin ne sunduğu, kendi kodumuzdaki kullanımdan değil **servisin
  sözleşmesinden** öğrenilir. Bir gün önceki tasarım bu yüzden gereğinden karmaşıktı.

### 2. Ölçümler

- `GetOutboxInvoice` **ETTN kabul ediyor**, fatura numarasını kabul etmiyor (ikisi de
  denendi; CRS ikisine de "Id" diyor, şemadan ayırt edilemiyordu).
- **CRS hesapları birbirinin belgesini görmüyor:** 01'in ETTN'i 03 hesabından sorulunca
  bulunamıyor. Yani "şirket bağımsız arama" = her hesaba sırayla sormak.
- `QueryOutboxInvoiceStatus` toplu çalışıyor → maliyet **şirket sayısı** kadar, belge sayısı
  kadar değil.
- **`ArrayOfString` CRS'in KENDİ (tempuri) ad alanındadır.** WCF'in alışıldık
  `schemas.microsoft.com/.../Arrays` ad alanı kullanıldığında CRS **hiçbir kimliği
  tanımıyor ve bunu hata olarak da bildirmiyor** — sessizce boş sonuç dönüyor. İlk deneme
  böyle "0 kimlik tanınıyor" verdi.

### 3. Tasarım değişti: şirket ve tarih artık istenmiyor

- `CrsIstemcisi.BelgeGetirAsync` ve `DurumlariSorAsync` eklendi.
- `BelgeSorgulayici` akışı: (1) Sentez'de tüm şirketlerde ara, (2) bulunanların gününü
  CRS'te tara (detay için), (3) **her kimliği her CRS hesabına toplu sor** — şirketi bu
  belirler.
- Tarih aralığı yalnızca **ek detay** için kaldı: durum sorgusu varlığı ve durumu söyler
  ama tutar/unvan taşımaz.
- **Dokunulan dosyalar:** `src/SentezServis.Core/Fatura/{CrsIstemcisi,BelgeSorgulayici,BelgeSorguModelleri}.cs`,
  `tests/SentezServis.Core.Tests/BelgeSorguTestleri.cs`, `web/src/api/fatura.ts`,
  `web/src/pages/BelgeSorguSayfasi.tsx`
- **Commit:** `1bcfa2d`

### 4. Yakalanan tuzak — demet (value tuple) null olmaz

`durumlar` sözlüğünün değeri `(string, CrsBelgeDurumu)` demetiydi ve satır kurulurken
`GetValueOrDefault` kullanılmıştı. **Demet bir değer tipidir**: bulunamayan anahtar için
`null` değil, içi `(null, null)` olan **dolu bir demet** döner ve `?.` bunu "var" sayar.

O hâliyle **her belge "CRS'te var" görünecekti** — ekranın verebileceği en kötü cevap.
Canlı denemede `NullReferenceException` olarak patladı; patlamasaydı sessizce yanlış sonuç
üretirdi. `TryGetValue`'ya çevrildi ve sınır testiyle kilitlendi.

### 5. Canlı doğrulama

Şirket ve tarih **verilmeden**:

```
3e9c3536-…7eda [ikisindeDe] 01 Approved  CRS MOD2026000002272 / Sentez 00002276
28951e33-…ffba [ikisindeDe] 03 Approved  CRS MOD2026000125843 / Sentez 00317401
1ace225f-…d13b [ikisindeDe] 04 Approved  CRS VME2026000193487 / Sentez 00453779
00000000-…0001 [hicbirindeYok]
```

508 .NET + 63 web testi geçti.

### 6. Paket

`SentezServis-2026-09-19-0215.zip`, arayüz tarihi **2026-09-19 02:15**.

## Kararlar

- **Dış servisin yetenekleri sözleşmesinden (WSDL/XSD) öğrenilir**, kendi kullanımımızdan
  değil. 18.09 tasarımı bu adım atlandığı için gereğinden karmaşıktı.
- Şirket bağımsızlık, her CRS hesabına **toplu** sormakla kurulur.

## Açık kalanlar / sonraki adım

Kullanıcının verdiği 4 maddeden **yalnızca 1.'si yapıldı.** Kalanlar tasarım kararı bekliyor:

- **2. Pazaryeri servislerinin birleştirilmesi.** `pazaryeri-cari-aktar`,
  `pazaryeri-cari-uret`, `pazaryeri-siparis-hazirla`, `pazaryeri-siparis-aktar` kaldırılıp
  tek servis olacak, içi sonra yazılacak. Bunlar canlı `zamanlamalar` tablosunda kayıtlı
  (cron'ları NULL, yani zamanlanmamış). **Sorulacak:** eski iş anahtarları ve çalıştırma
  geçmişi silinsin mi, yoksa kayıt kalsın mı? Göç yazılması gerekir.
- **3. Sipariş çekerken e-fatura / e-arşiv / mikro ihracat kontrolü.** CRS'te `IsEInvoiceUser`
  var (VKN/TCKN + alias ile sorar) — e-fatura mükellefi mi, değilse e-arşiv. Mikro ihracatın
  kuralı belirsiz. **Sorulacak:** karar nereye yazılacak (sipariş kaydına mı, ayrı tabloya mı)?
- **4. E-arşiv oluştur/gönder ve kontrol servisleri**, şimdilik boş iskelet. CRS tarafı
  hazır: `SendInvoice`, `ValidateInvoice`, `QueryOutboxInvoiceStatus`. **Dikkat:** bu ilk
  kez CRS'e YAZAN modül olacak; şimdiye kadar fatura modülü salt okunurdu ve bu bir kurul
  kararıdır — Karar yazılmadan uygulanmamalı.

---

## Ek tur — 2., 3. ve 4. maddeler

### 7. Menü doğrulaması (1. madde)

Kullanıcı "menüde bulamadım" dedi. Sebep: ekran 18.09 17:56 paketindeydi ve o paket
kurulmamıştı. Kod ve paket içeriği doğrulandı — `Layout.tsx:37` menü satırı,
`App.tsx:237` rota, ve `app.js` içinde hem `/belge-sorgu` hem "Belge kontrol" metni var.

### 8. Dört pazaryeri işi tek servise indirildi (2. madde)

- **İstek:** `pazaryeri-cari-aktar`, `pazaryeri-cari-uret`, `pazaryeri-siparis-hazirla`,
  `pazaryeri-siparis-aktar` kaldırılsın, tek servis olsun, içi sonra yazılacak.
- **Yapılmayan:** sınıfları silmek. `PazaryeriSiparisHazirlaJob.Hazirla` **12 testi olan
  gerçek iş mantığı** taşıyor; cari üretim kuralları da öyle. Silmek "içi boş servis"
  isteğinin gerektirdiğinden fazlasıydı.
- **Yapılan:** Dört sınıftan `IJob` kaldırıldı → iş listesinde görünmüyorlar. Yerlerine
  `PazaryeriAktarimJob` (`pazaryeri-aktarim`) geldi ve dördünü **sırayla** çağırıyor.
- **Kararlar kayda geçti:**
  - Sıra zorunlu: cari üretilmeden aktarılamaz, sipariş carisi yazılmadan aktarılamaz.
  - Bir adım patlarsa sonrakiler koşmaz — yarım aktarım, hiç aktarım yapmamaktan kötüdür
    (cari yazılıp siparişi yazılmayan müşteri ERP'de sahipsiz kalır).
  - `MaxAttempts = 1`: iki adım yazıyor, tekrar mükerrer cari/sipariş üretir. Dört işin en
    katı ayarı geçerli.
  - Adımlar parametreyle kapatılabilir, sıraları değişmez.
- **Göç GEREKMEDİ.** `IsKayitDefteri` açılışta tüm işleri `kayitli = 0` yapıp yalnızca kodda
  var olanları 1'e çekiyor; eski kayıtlar ve çalıştırma geçmişi duruyor. Dördü de canlıda
  **zamanlanmamıştı** (cron `NULL`), yani üretim etkilenmiyor.

### 9. E-arşiv iskeletleri (4. madde)

`earsiv-gonder` ve `earsiv-kontrol` eklendi. **Gövdeleri boş** ve bunu her turda **uyarı
olarak** bildiriyorlar; zamanlanmıyorlar (`DefaultCron = null`).

Boş bir işin sessizce "başarılı" görünmesi en tehlikeli hâlidir: kimse belgelerin
gitmediğini fark etmez. Bu yüzden `JobSummary.Warnings` her çalıştırmada doluyor.

**Sınır uyarısı kayda geçti:** `earsiv-gonder` yazıldığında bu modülün **CRS'e ilk yazma**
işlemi olacak. Bugüne kadar fatura modülü salt okunurdu. Gönderilen e-arşiv geri alınamaz
(iptali ayrı işlem: `CancelEArchiveInvoice`). Gövde yazılmadan önce kurul kararı ve
idempotency anahtarı gerekir (Karar #03).

### 10. Belge tipi kararı (3. madde) — ve iki dürüst sınır

**Sorun:** Kullanıcı "siparişleri çekerken" kontrol istedi, ama sipariş modelinde
**VKN/TCKN yok** (`SiparisModelleri.cs`: müşteri adı, il, ilçe var). VKN cari tarafında
(`MusteriVknTckn`). Yani karar doğal olarak cari üretimi anında verilebilir.

**Yapılan:** `CrsIstemcisi.EFaturaMukellefiMiAsync` (`IsEInvoiceUser`) +
`BelgeTipiBelirleyici`.

**Canlı doğrulama:** İlk denemem başarısızdı — VKN'leri ezberden yazmıştım ve hepsi `false`
döndü. Gerçek veriden alınca doğrulandı:

```
[eInvoice] 9251182063 VIUMOD DİJİTAL ...  -> IsEInvoiceUser=True
[eInvoice] 9250958912 VIUMA DİGİTAL ...   -> True
[eArchive] 11111111111 AZRA KAYA          -> False
```

**Ders:** dış servisi sınarken girdiyi de gerçek veriden al; uydurma girdiyle alınan
"çalışmıyor" sonucu yanlıştır.

**Bulgu:** e-arşiv belgelerinin tamamı yer tutucu TCKN `11111111111` ile kesilmiş. Bu değer
CRS'e hiç sorulmadan "bireysel" sayılıyor.

**Açıkça yapılmayan iki şey:**

1. **Mikro ihracat tahmin edilmiyor.** Kuralı tanımlanmadı **ve veri yok**: `CariUretici`
   ülkeyi sabit `"Türkiye"` yazıyor, pazaryeri siparişinde ülke hiç taşınmıyor. Tahmin
   edilseydi yurt içi satışlar ihracat sayılıp beyan hatası doğardı. Ülke açıkça
   verilirse `MikroIhracat` döner; bugün bu yol hiç tetiklenmiyor.
2. **Kararın nereye yazılacağı belirlenmedi.** Saklamak için cari veya sipariş tablosunda
   kolon gerekir; şu an karar hesaplanıyor ama kalıcı değil.

`Bilinmiyor`, `EArsiv`'den ayrı bir durumdur: CRS'e sorulamadığında "e-arşiv" demek tahmindir.
Önbellek 12 saat — sonsuz saklamak, sonradan mükellef olan firmaya aylarca yanlış belge
kestirir.

- **Commit:** `f3db881` — 529 test geçiyor
- **Paket:** `SentezServis-2026-09-19-0237.zip`, arayüz tarihi **2026-09-19 02:37**

## Açık kalanlar (güncel)

- **Mikro ihracat kuralı** ve ülke verisinin nereden geleceği.
- **Belge tipi kararının nereye yazılacağı** (kolon gerekiyor).
- `earsiv-gonder` gövdesi → önce kurul kararı (CRS'e ilk yazma).
- Mahsup bağlantısı hâlâ doğrulanmadı; `efatura-tetikle` 6 saatlik zaman aşımına takılıyor.

---

## Ek tur — e-arşiv durum sorgulama servisi (type=1)

### 11. Sözleşme ölçüldü, tahmin edilmedi

Kullanıcı uçları ve akışı tarif etti. Kod yazmadan önce ikisi de canlıda ölçüldü:

| Uç | Sonuç |
| --- | --- |
| `GET /EArsiv/GetList?type=1` | `{success, count, data[], at}` — **86.864 kayıt / 19,4 MB / 20 sn** |
| `POST /EArsiv/Run/?type=1` | Aynı zarf; `createStatus` 0→1, `eInvoiceStatus` **değişmez** |

Kayıt modeli (GET ve POST'ta aynı): `companyId, companyCode, recId, receiptNo,
receiptType, receiptDate, eInvoiceStatus, eInvoiceStatusName, createStatus, createError`.

Liste dağılımı: 04 → 66.205, 03 → 20.336, 01 → 323. Tamamı `receiptType=121`, biri hariç
hepsi `eInvoiceStatus=3` ("Dosya Gönderildi"). Tarih aralığı 01.07 → 18.09.

**Kullanıcının tarifi doğrulandı:** dönüşte yeni durum gelmiyor. Bu yüzden iş "durumları
güncelledim" demiyor; "şu kadar kaydı işlettim, şunlar hata verdi" diyor ve özete
"yeni durumlar bir sonraki listede görünür" notunu koyuyor.

**POST denemesi bilerek küçük tutuldu:** önce 2, sonra 3 kayıt. Tam tur (869 öbek)
çalıştırılmadı — dışarıdaki servise iş tetikleyen, geri alınamaz bir çağrı.

### 12. Ölçüm sırasında görülen: işlenen kayıt listeden düşüyor

İkinci `GetList` **86.862** döndü (önce 86.864). Denemede işlenen 2 kayıt kuyruktan
çıkmış. Bu, işi tekrar koşmayı güvenli kılıyor: kalanlar işlenir, işlenmişler tekrar
gelmez.

### 13. Yazılanlar

- `EArsivModelleri.cs` — `EArsivAyarlari`, `EArsivKaydi`, `EArsivYaniti`. Alan adları
  `JsonPropertyName` ile **sabitlendi**: ad değişirse JSON sessizce boş nesnelere çözülür
  ve iş "0 kayıt" deyip başarılı görünür.
- `EArsivIstemcisi.cs` — `ListeAsync`, `CalistirAsync`. Ağ hataları anlaşılır mesaja çevrilir.
- `EArsivKontrolJob.cs` — iskelet gerçek gövdeyle değiştirildi. `type=1` sabit.
- `Ayarlar.cs` + `appsettings.json` — `SentezServis:EArsiv` bloğu (adres, öbek boyutu,
  zaman aşımları).
- `EArsivTestleri.cs` — 6 test; canlıdan alınmış **gerçek yanıt** üzerinden çözümleme,
  hata alanının okunduğu ve POST'ta aynı alan adlarının yazıldığı doğrulanıyor.

### 14. Kararlar

- **Bir öbek patlarsa tur durmaz.** 869 öbeklik bir turda tek ağ hatası yüzünden yapılan
  işin tamamını çöpe atmak, hiç çalışmamaktan kötüdür. Kalanlar işlenir, hata uyarı olur.
  **Listeyi hiç alamamak farklıdır** — o durumda iş başarısız olur.
- `MaxAttempts = 1`: iş dışarıdaki servise yazma tetikler.
- Zamanlanmaz (`DefaultCron = null`): sıklık operasyon kararı.
- `type` **1'de sabit**; diğer tipler ele alınmadı, uydurulmuş bir tip yanlış işi tetikler.
- Hata örnekleri özette **20 ile sınırlı**; binlerce satır özeti okunamaz kılar.

- **Commit:** `e046149` — 535 test geçiyor
- **Paket:** `SentezServis-2026-09-19-0523.zip`, arayüz tarihi **2026-09-19 05:23**

## Açık kalanlar (güncel)

- **Canlı `appsettings.json`'a `SentezServis:EArsiv` bloğu eklenmeli** (paket taşımıyor).
- `earsiv-gonder` gövdesi hâlâ boş; yazıldığında CRS'e ilk yazma olacak → kurul kararı.
- Diğer `type` değerleri (gönderim vb.) ele alınmadı.
- Mikro ihracat kuralı ve ülke verisi; belge tipi kararının nereye yazılacağı.
- Mahsup bağlantısı doğrulanmadı; `efatura-tetikle` 6 saatlik zaman aşımına takılıyor.

---

## Ek tur — e-arşiv/e-fatura gönderim işi

### 15. Uçlar ölçüldü (yalnızca okuma)

| Uç | Sonuç |
| --- | --- |
| `GET GetList?type=2` | **1.942 kayıt** — gönderilecekler. Hepsi `eInvoiceStatus=0` ("Yok"). Dağılım 04:1843, 03:92, 01:7 |
| `GET GetList?type=3` | **1 kayıt** — hatalılar. `eInvoiceStatus=11` ("Hata") |

**`POST Run/?type=3` HİÇ DENENMEDİ.** Bu uç gerçek e-fatura/e-arşiv gönderir ve gönderim
geri alınamaz; yasal belge üretir. Durum sorgulamada (type=1) 2–3 kayıtlık deneme yapmak
makuldü, burada değil.

**Ölçülen ayrıntı:** type=3 listesinde `createError` **boş**; hata sinyali durumun kendisi
(`eInvoiceStatus=11` / "Hata"). Mail bu yüzden hem durum adını hem `createError`'ı gösteriyor
— yalnızca `createError`'a bakılsaydı hata listesi boş görünürdü.

### 16. Akış

1. `GET GetList?type=2`
2. `POST Run/?type=3` — **20'şerli** (kullanıcı kararı; durum sorgulamanın 100'ünden ayrı,
   gönderim ağır iş)
3. Gönderim bittikten **sonra** `GET GetList?type=3`
4. Hatalı liste maille bildirilir

**Liste tipi 2, gönderim tipi 3** — kasıtlı olarak farklı. Sınır testi ikisinin eşitlenmesini
engelliyor: eşitlenirse ya yanlış liste gönderilir ya hiçbir şey.

### 17. Güvenlik ayarları ve gerekçeleri

| Ayar | Gerekçe |
| --- | --- |
| `DefaultCron = null` | Belge göndermek operasyon kararıdır; açılışta kendiliğinden başlamaz |
| `MaxAttempts = 1` | Yarım kalan tur baştan başlarsa aynı belgeler ikinci kez gönderilmeye çalışılır |
| `RetrySafety.Unsafe` | Mükerrer belge riski açıkça beyan edilir |
| `SingleInstance = true` | İki tur aynı listeyi paylaşırsa aynı belge iki kez gider |
| `azami` parametresi | İlk koşuda küçük bir sayı verilebilsin diye; ipucunda yazılı |

Sınır testi bu dördünün kaynakta durduğunu doğruluyor.

- **Bir öbek patlarsa tur durmaz** (kalanlar gönderilebilir), **liste alınamazsa iş başarısız
  olur** (yapacak bir şey yok).
- **Hata yoksa mail gitmez.** Her tur "0 hata" maili, gerçek hata mailini gürültüye boğar.
- Mail alıcıları işin `alicilar` parametresinden; boşsa `Eposta:Alicilar`.
- Mailde en fazla 200 satır; tamamı çalıştırma kaydında.

- **Commit:** `9ca8cb2` — 538 test geçiyor
- **Paket:** `SentezServis-2026-09-19-0537.zip`, arayüz tarihi **2026-09-19 05:37**

## Açık kalanlar (güncel)

- **Gönderim işi hiç çalıştırılmadı.** İlk koşunun `azami` ile küçük başlaması ve kullanıcının
  başlatması gerekiyor.
- Canlı `appsettings.json`'a `SentezServis:EArsiv` bloğu eklenmeli.
- Diğer `type` değerleri ele alınmadı.
- Mikro ihracat kuralı; belge tipi kararının nereye yazılacağı.
- Mahsup bağlantısı doğrulanmadı; `efatura-tetikle` 6 saatlik zaman aşımına takılıyor.
