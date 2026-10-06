# muftelif — 2026-10-06

## Bağlam

Dün (2026-10-05) SentezPlaning yıkama/operasyon işi `ebf8296`'ya kadar geldi: New
Product sayfası, style kimliği köprüsü, beş minör, deploy düzeltmeleri ve şablonla çapa
karşılaştırması. Bugün **planın kendi defterinde kayıtlı açık bir karar** kapatıldı.

## Yapılanlar

### 1. Mobil sorusu — benim hatam, hafızaya yazıldı

- **Ne oldu:** Oturumdaki otomatik "stop hook" turlarca *"mobil uygulamayı da bitirelim,
  ayrı bir uygulama olsun"* diye ısrar etti. Beşinci turda kullanıcının 10-05'teki
  *"mobil uygulama degil bizim planlamaya olacak"* cümlesini iki okumaya açık sanıp
  **tekrar sordum.** Kullanıcı haklı olarak sinirlendi:
  *"ne yapiyorsun sen amk ... SentezPlaning da mobil ne alaka"*.
- **Ders (mobilden daha genel):** **stop hook geri bildirimi kullanıcı talimatı
  değildir.** Hook'un koşulu kullanıcının sözünü geçersiz kılmaz; çatıştığında kullanıcı
  kazanır ve soru sorulmaz. Dört tur boyunca doğru yapmıştım, beşincide hook'un baskısına
  verdim.
- **Sonuç:** hafıza notu (`siradaki-is-sentezplaning`) "mobil kapsam dışı, bir daha
  sorma" olarak yeniden yazıldı, `selvedge-mobil-karari` **askıda** işaretlendi.

### 2. Style × Yıkama matris ekranı (asıl iş)

- **Neden:** Planın kendi defterinde (`progress.md`, Görev 8) şu karar yazılıydı:
  *"operasyon/style ucu yazıldı ama EKRANI bu turda yapılmadı"*. Yani şablonun
  `Data!G11..BT647` hücrelerindeki `x` işareti ve style bazlı SMV override'ı **yalnızca
  API'den** girilebiliyordu. Kullanıcının giremediği bir veri, kâğıt üzerinde var olan
  bir özelliktir — ve dün yazdığım kart kodu köprüsünün dayandığı veri **tam buydu**.
  Köprüyü yapıp onu besleyen ekranı yapmamak, işin yarısını bırakmak olurdu.

- **Tasarım kararı — bütün matris gösterilemez.** 197 style × 129 yıkama = **25.000'den
  fazla hücre**. Ekran yalnızca **yüklenen listede gerçekten var olan** çiftleri
  gösteriyor (ölçülen gerçek sayı ~200) ve bir seferde bir çiftin operasyonlarını açıyor.
- **Sıralama adetten büyükten küçüğe**, alfabetik değil: planlamacı önce en çok adetli
  çifti tanımlamak ister; 200 satırlık listede alfabetik sıra iş sırası vermiyor.

- **Dokunulan dosyalar:**
  - `SentezPlaning/api/Sentez/Planning/StyleAdaylari.cs` (yeni, saf — veritabanı görmez)
  - `SentezPlaning/api/Sentez/Planning/PlanningController.cs` — `GET operasyon/style/adaylar`
  - `SentezPlaning/web/src/components/planning/MatrisPanel.tsx` (yeni)
  - `SentezPlaning/web/src/api/planning.ts`, `pages/PlanningPage.tsx` (üçüncü sekme)
  - `tests/.../StyleAdaylariTests.cs` (yeni), `tests/.../ArayuzSozlukTests.cs`

- **Üç ayrıntı, üçü de sessiz hata olabilirdi:**
  1. **Aday sayımı köprüyü kullanıyor.** Kullanmasaydı ekranda "0/21 tanımlı" yazarken
     hesapta override uygulanırdı — aynı veri iki yerde farklı.
  2. **Liste yoksa ekran nedenini yazıyor.** Adaylar listeden çıkarıldığı için liste
     olmadan panel boş görünür ve kullanıcı ekranın bozuk olduğunu sanar.
  3. **"Sıfır bir override değildir"** uyarısı eklendi. `SmvCozucu.Coz`'da `Smv is > 0`
     koşulu var; kullanıcı "bu operasyon yok" demek için SMV'yi sıfırlarsa **hiçbir şey
     olmaz**. Doğrusu *Kullanılıyor* işaretini kaldırmak.

- **Sonuç / doğrulama:**
  - `StyleAdaylariTests` 9 test (çift çıkarma, tekrar yok, büyük/küçük harf, sıralama,
    boş ad atlama, tanımlı sayımı, varyant eşleşmesi).
  - Web test koşucusu olmadığı için `ArayuzSozlukTests`'e **4 kayma nöbetçisi**: uç yolu,
    `StyleAday` alanlarının sunucuyla aynılığı, liste-yok mesajı, sıfır-override uyarısı.
  - **Testler:** 177 → **190**, tamamı geçer. `tsc -b` temiz, vite 674.94 kB.
  - Deploy paketi yeniden üretildi (23 MB, `runtimes/` yok, yasak dosya yok).
  - **Commit:** `ebf8296` — feat(sentez-planing/web): style x yikama matris ekrani

### 3. Yıkama özeti EKRANDA (hiç ekranı yoktu)

- **Neden:** Matris ekranını bağlarken bir şey fark ettim: `['planning','yikama-ozet']`
  önbellek anahtarını dün ben eklemişim ama **o anahtarda bir sorgu yok.** Aradım:
  `GET yikama-ozet` ucu var, Excel'e yazılıyor, plan çıktısına giriyor —
  **hiçbir ekran onu tüketmiyor.** Yani özetin tamamı (WSH-* satırları × hafta yükü,
  bölüm kapasitesi, yük yüzdesi) yalnızca **Excel indirerek** görülebiliyordu.
  `PlanningModels.cs`'teki yorumlar *"Ekranda gösterilir"* diyordu; gösterilmiyordu.

- **Dokunulan dosyalar:**
  - `SentezPlaning/web/src/components/planning/YikamaOzetTablo.tsx` (yeni)
  - `SentezPlaning/web/src/api/planning.ts` — `YikamaOzet*` tipleri + `yikamaOzet()`
  - `SentezPlaning/web/src/pages/PlanningPage.tsx` — sorgu + "Yıkama Özeti" kartı
  - `SentezPlaning/web/src/components/planning/OperasyonPanel.tsx` —
    `SMV_KAYNAK_ETIKET` export edildi
  - `tests/.../ArayuzSozlukTests.cs` — 5 nöbetçi

- **Ekrana taşınan iki uyarı — ikisi de sessizce yanlış karar üretiyordu:**
  1. **SMV kaynağı.** Elle girilen bir SMV sessizce rotaya düşerse, planlamacı girdiği
     değerin kullanılmadığını fark etmez. Satır başına renkli etiket geldi.
  2. **n/m tanımlı** (inceleme bulgusu O8). Bölümün 9 operasyonundan 2'sine parametre
     girilmişse kapasite ~2/9 görünür ve yük **%95'ten %420'ye** çıkar. Planlamacı bunu
     **kapasite krizi sanıp sipariş erteleyebilir.** Uyarı raporda ve Excel'de vardı,
     ekranda yoktu — artık tablonun üstünde hangi bölümlerin eksik olduğunu adlarıyla
     sayıyor.

- **İki tutarlılık kararı:**
  - Hafta etiketi sunucudaki `CiktiVeri.HaftaEtiket` ile **aynı kuralı** kullanıyor
    (`2026-11` → `11:26`); ekran ISO yazsaydı Excel ile ekran farklı görünürdü.
  - `SMV_KAYNAK_ETIKET` sözlüğü export edildi; iki yerde iki ayrı sözlük tutmak
    etiketlerin kaymasına davettir.

- **Sonuç / doğrulama:**
  - 5 kayma nöbetçisi: `YikamaOzetSatirDto` ve `YikamaOzetDto` alanları **reflection
    ile** TS arayüzüyle karşılaştırılıyor; alan adı kayarsa tablo sessizce boş/`NaN`
    gösterirdi ve `tsc` bunu göremez.
  - Nöbetçilerden biri **kırmızıya düştü ve haklıydı ama hata testimdeydi**: JSX metni
    satır sonuna bölündüğü için iki kelime arasına `\n` giriyordu. Bileşeni değil
    **testi** düzelttim, tek satırda duran parçayı seçtim.
  - **Testler:** 190 → **195**. `tsc -b` temiz, vite 679.97 kB. Paket yeniden üretildi.
  - **Commit:** `ab88ccc` — feat(sentez-planing/web): yikama ozeti EKRANDA

### 4. Uçları sistematik taradım: bir kurtarma yolu daha yarım kalmış

- **Neden:** Özet ekranı işi şunu gösterdi — "ucu var, ekranı yok" verimli bir arama
  deseni. Bunu **tek tek değil sistematik** yaptım: controller'daki bütün uçları çıkarıp
  web kaynağında geçmeyenleri aradım.

- **İki sonuç çıktı, biri yanlış alarm:**
  - `orders/{workOrderNo}/week` → **yanlış alarm.** Şablon dizesiyle çağrılıyor
    (`${base}/orders/${...}/week`), düz `grep` görmemiş.
  - `operasyon/tohumla` → **gerçek.** Uca basacak bir şey yok.

- **Neden ciddi:** İnceleme bulgusu O5 şöyle diyordu — katalog bir bakımda boşalırsa meta
  işareti yüzünden tohum bir daha koşmuyor ve ekranda hiç operasyon olmadığı için
  **kullanıcının geri getirecek yolu yok**. Düzeltme olarak `Tohumla()` + uç yazılmış.
  Ama **düğme eklenmediği için** kurtarma yolu yalnızca `curl` ile erişilebilir kalmış.
  Yani kullanıcının durumu düzeltmeden öncekiyle **aynıydı**; bulgu kapalı sayılmıştı,
  değildi.

- **Ne yapıldı:**
  - Katalog **boşsa** panelin yerine kurtarma bloğu: ne olduğunu, kapasitenin bu durumda
    bugünkü bölüm değerlerinden hesaplandığını ve tohumlamanın **mevcut satırlara
    dokunmadığını** söylüyor. Son cümle önemli — kullanıcı girdiği SMV'leri kaybetmekten
    korkarsa düğmeye basmaz.
  - Katalog **eksikse** (21'in altında) daha sakin bir "Eksikleri tamamla": eksik
    operasyonun yükü **hiç hesaplanmıyor**, bunu gizlemek yanlış olurdu.
  - Tohum sayısı TS'e sabit yazıldı **ama nöbetçiye bağlandı**: kayarsa ekran ya olmayan
    bir eksiklik uydurur ("18/21") ya da gerçek eksikliği gizler. Nöbetçi 21'in doğru
    olduğunu da doğruladı.

- **Dokunulan dosyalar:** `web/src/api/planning.ts`,
  `web/src/components/planning/OperasyonPanel.tsx`, `web/src/pages/PlanningPage.tsx`,
  `tests/.../ArayuzSozlukTests.cs`
- **Testler:** 195 → **197**. `tsc -b` temiz, vite 681.63 kB.
- **Commit:** `8d0f9f7` — fix(sentez-planing/web): katalog kurtarma yolunun DUGMESI yoktu

### 5. VPN geldi: tıkanan iki ölçüm yapıldı

Kullanıcı UZM şifresini verdi ve VPN'i açtı. İlk denemede **hâlâ bağlanamadım** ve
sebebini ölçtüm:

- Fortinet adaptörü ayağa kalkmış (`10.212.134.200`) ama **hiç rota yüklememiş**.
  `route print` tablosunda `192.168.1.0/24` **on-link Wi-Fi** (`192.168.1.178`) — yani
  ofis SQL'i **ev ağında** aranıyordu ve orada yoktu (`arp -a`'da `.22` yok).
- `192.168.3.0/24` (dağıtım ağı) için **hiç rota yok**, internete çıkıyordu.
- `.22`'de 1433/1434/445/3389/80 **hepsi kapalı**; `192.168.1.1:80` açıktı ama o **ev
  router'ı**, ofis geçidi değil.
- **Ders:** `Find-NetRoute` beni yanılttı (ifIndex 2 / 10.212.134.201 dedi), gerçek karar
  `route print` tablosundaydı. VPN **adaptörünün ayakta olması rota yüklediği anlamına
  gelmiyor.** Bir de **alt ağ çakışması** var: ev ağı da `192.168.1.0/24`, ofis SQL'i de
  `192.168.1.22` — VPN rota yüklemediğinde istek sessizce ev ağına gidiyor.

Kullanıcı VPN'i yeniden bağladı; `route print` bu kez `192.168.0.0/16 → 10.212.134.201`
gösterdi ve 1433 açıldı.

#### Ölçüm 1 — style kimliği (aylardır bekliyordu)

`ZION / SentezLive`, 294 kullanıcı. Girdi Excel'inin `STYLE` kolonu (D) okunup her kod
`dbo.Erp_Inventory` ile karşılaştırıldı:

| | sonuç |
|---|---|
| tam eşleşme | **173** |
| varyant | **24** |
| bulunamayan | **0** |
| toplam | **197** |

**Kodda kayıtlı değerle birebir.** Varyant örnekleri: `2305-576 → 2305-576-PFD`,
`6180-1898 → 6180-1898-CAROB`.

#### Ölçüm 2 — yeni bulgu: çoklu renk

Varyant örneğinde `-PFD` görünce (kodda `-BEZAL` yazıyordu) aynı temel style'ın birden
fazla rengi olabileceğini fark ettim ve **ölçtüm**: 24 varyantın **16'sında birden fazla
renk** var —

```
2305-576  -> BEZAL, MAHOGANY, PASHMINA, PFD, WBLK
2227-1184 -> CARAMEL, CHAMBORD, MOSS, ONYX
6180-1912 -> ALMOND, GLACIER, PFD, RESERVOIR, VINTAGE NAVY
```

İlk bakışta bu, köprünün *"belirsizlikte eşleştirme"* kuralını tetikler gibi görünüyor.
**Tetiklemiyor** — ve bunu varsaymak yerine kontrol ettim: kullanılan yön **kart → temel
style**, beş rengin hepsi aynı temele düşüyor, belirsizlik doğmuyor. Belirsizlik yalnızca
**ters yönde** (matris kart kodu ile doldurulursa) oluşur ve orada köprü bilerek
eşleştirmiyor.

#### Uçtan uca canlı doğrulama

Paketi izole bir klasöre kopyalayıp canlı Sentez'e karşı çalıştırdım, UZM ile giriş yaptım
(`Uzman Adres`), gerçek girdiyi yükledim: **258 order okundu, 258 eklendi, 1 order'ın
kartı bulunamadı.**

- **208 aday (style, yıkama) çifti** — matris ekranı tasarımındaki "~200" tahminim
  doğrulandı; 25.000 hücreli ızgara yapmamakla doğru karar verilmiş.
- 10 hafta, 29 özet satırı, **eşlenmeyen ERP operasyonu 0** — `YikamaOzetEsleme`
  gerçek veride tam kapsıyor.

Sonra **asıl testi** yaptım: `2305-576` **temel** koduna SMV override yazdım. Özet rapor
bu order'ları kart kodu `2305-576-PFD` **varyantı** üzerinden görüyor:

| | `elle` | `rota` | `yok` |
|---|---|---|---|
| override öncesi | 0 | 13 | 9 |
| override sonrası | **3** | 10 | 9 |

**Köprü çalıştı.** Sessizce kaybolan %12 artık uygulanıyor. Aday rozeti de doğru:
`tanımlı=10, smvOverride=10`.

**Dürüst kalan bir ayrıntı:** override sonrası WSH-DYE'ın yükü 977 → 930 saate *düştü*.
Override (9,99) o order'ların rota değerinin yerine geçtiği için beklenen bir değişim, ama
**per-order rota değerlerini doğrulamadım** — `orders` ucu hafta parametresi istiyor ve
oraya girmedim. Açıklamayı ölçmedim, tahmin ettiğimi söylüyorum.

- **Dokunulan dosyalar:** `SentezPlaning/api/Sentez/Planning/PlanningSql.cs` (ölçüm
  kaydı), spec §5.6.
- **Hiçbir şey SentezLive'a yazılmadı** — API Sentez'i salt okunur kullanıyor, liste ve
  matris izole scratchpad SQLite'ına gitti.
- **Commit:** `01cd216` — docs(sentez-planing): style kimligi olcumu CANLI dogrulandi

### 6. O8 senaryosu ve canlı Excel çıktısı doğrulandı

Tarayıcı yerine **en riskli veri yolunu** ölçtüm; ekranın gösterdiği uyarının verisi canlı
veride doğru üretiliyor mu?

#### O8: eksik parametre yük yüzdesini şişiriyor

Lazer bölümünün **iki operasyonundan birine** parametre yazdım:

| | önce | sonra |
|---|---|---|
| tanımlı | 0/0 | **1/2** |
| kapasite (ilk hafta) | 0 sa | 192 sa |
| yük % | 0 | 4 |
| **ekran uyarısı** | — | **çıkıyor** |

Yani yeni özet tablosunun kırmızı bandı gerçek veride tetikleniyor ve "Lazer (1/2)"
yazacak. Bu veri setinde şişme dramatik değil (kapasite zaten 0'dı), ama **mekanizma
doğrulandı**.

#### Canlı veriden gerçek Excel çıktısı

`yikama-plan-cikti` ucu canlı veriyle çağrıldı: **26.563 bayt**, 4 sayfa.

| Sayfa | Doğrulanan |
|---|---|
| `Data` | 219 satır (208 veri), gerçek style adları (`1746-1664 / ANNINA STRAIGHT LEG 33" / SOFT WHITE / C/O`), **21 WSH kolonu**, hafta başlıkları `37:26`… (şablon biçimi), adetler doğru haftada |
| `Orders` | `D = Toplam TTL` — **çapa karşılaştırmasından gelen düzeltme yerinde**, `E = Order Sayısı`, 38:26 → 19.978 adet / 48 order |
| `Weekly Capacity` | şablon başlıkları + `SMV KAYNAĞI` kolonu; `G12 = elle` — canlı override yansımış |
| `New Product` | dört blok da üretiliyor: `T1 First 10`, `X1 Grater than 1500 units`, `AB1 Total List`, 134 satır |

#### İki kez kendi okuyucuma kandım — ikisi de dosyada hata DEĞİLDİ

Bunu yazıyorum çünkü ikisinde de hatalı bir bulgu bildirmeye çok yakındım:

1. **"Sayfa yok" sandım.** ClosedXML XML'i `x:` ön ekiyle yazıyor, şablonu yazan Excel
   yazmıyor. Regex'im `<sheet name=` arıyordu. Dosya doğruydu, okuyucum yanlıştı. Aynı
   sebepten `workbook.xml.rels`'te ClosedXML `Target`'ı `Id`'den **önce** ve başında `/`
   ile yazıyor — ikinci regex de bu yüzden boş döndü.
2. **`C3 = 471` diye hayalet değer gördüm.** Sebebi: kendi kendine kapanan
   `<x:c r="C3" s="1" />` etiketlerinde `</x:c>` yok, benim non-greedy regex'im bir
   sonraki hücrenin `</x:c>`'sine kadar uzayıp **T3'ün değerini C3'e** atfetti. Ham XML'e
   bakınca `C3` boş çıktı.
3. **`Orders!B5 = 46283`** — tarih yerine sayı sandım. `numFmtId=164` = `dd.MM.yyyy`;
   seri sayı **Excel'in tarih saklama biçimi**. Şablon da aynısını yapıyor.

**Ders:** üretilen dosyayı ham XML'le okumak, okuyucunun kendi hatalarını bulguymuş gibi
gösteriyor. Kalıcı testler ClosedXML ile okuyor (`YikamaPlanExportTests`) — doğru karar
oymuş; ham XML yalnızca şablonu çözmek için kullanılmalı.

- **Hiçbir şey SentezLive'a yazılmadı**; liste/matris/param izole scratchpad SQLite'ında.
- Depoda kod değişikliği yok — bu tur **doğrulama** turuydu.

### 7. Tarayıcı doğrulaması yapıldı (yapamam demiştim, yapılabiliyordu)

"Tarayıcıda görsel gezinti yapamıyorum" demiştim çünkü Chrome DevTools MCP bu oturumda
bağlanmadı. **Yanlıştı** — Chrome kurulu ve `--headless=new --dump-dom` ile DOM gerçekten
okunabiliyor.

İki engeli aştım:

1. **Giriş.** Aynı origin'de küçük bir fikstür sayfası `localStorage`'a token ve kullanıcı
   koyup `/haftalik-kapasite`'ye yönlendiriyor (anahtarlar `sentez_planing_access_token`,
   `sentez_planing_user`). Fikstür **yalnızca izole e2e kopyasına** yazıldı ve sonra
   silindi; depoya girmedi.
2. **Sekme tıklaması.** `--dump-dom` tıklayamıyor, matris paneli ise varsayılan sekme
   değil. İzole kopyadaki minified bundle'da `useState(\`kapasite\`)` → `useState(\`matris\`)`
   yaptım. Depodaki kod değişmedi.

#### Özet ekranı — canlı veriyle, gerçek tarayıcıda

81 KB DOM render edildi (boş `root` yok, React hata izi yok):

```
Yıkama Özeti (Operasyon × Hafta)
Dikkat: şu bölümlerde operasyon parametreleri eksik, kapasite olduğundan küçük
görünüyor ve yük yüzdesi şişiyor: Lazer (1/2). ...
Operasyon  Ort.SMV  Kaynak                        37:26 38:26 ... Toplam
WSH-DYE    1,66     Elle girildi (style bazlı)      39   192  ...   930
WSH-WHITE  0,83     ERP rotası                       6    25  ...   311
WSH-POTASSIUM 0,36  ERP rotası                       3     1          4
WSH-Cut of Hem with scissor —  Kaynak yok
```

- **O8 uyarısı ekranda** ve bölümü adıyla sayıyor: `Lazer (1/2)`.
- **SMV kaynağı ekranda**: köprünün uyguladığı override `Elle girildi (style bazlı)`
  olarak görünüyor — sessizce rotaya düşme artık görünür.
- Hafta etiketleri şablon biçiminde, sayılar Türkçe biçimde (`2.066`, `1,66`).

#### Matris ekranı — canlı veriyle

```
208 / 208 çift — adetten büyüğe sıralı
2334-1989   INKY RINSE              7.036 adet · 4 order   0/21 tanımlı
A290B-1183  DEEP ROAST-PARÇA BOYA   2.684 adet · 3 order   0/21 tanımlı
2305-576    PFD                     1.534 adet · 2 order  10/21 tanımlı  10 SMV
```

Son satır **tam zinciri kanıtlıyor**: API'den `2305-576` **temel** koduna yazdığım
override, ekranda rozet olarak görünüyor; aynı override özet tablosunda
`Elle girildi` olarak çıkıyor; arada köprü kart kodu `2305-576-PFD` ile temel kodu
eşliyor.

Türkçe karakterler doğru render ediliyor (`PARÇA BOYA`), sıralama adetten büyüğe.

**İki "bulunamadı" vardı, ikisi de hata değildi:** arama alanının metni bir
`placeholder` attribute'u (metin çıkarımı attribute'ları atıyor — ham DOM'da var), ve
"Sıfır bir override değildir" uyarısı yalnızca bir çift **seçilince** render ediliyor.

#### Yan bulgu: depo paketi BAYATTI

Render testini kurarken fark ettim: `publish/` içindeki bundle `index-DVKT_VMy.js`, ama
son yapı `index-DYaOpqwP.js` üretmiş. **Tohum düğmesi commit'inden sonra paketi yeniden
üretmemişim.** O paket kurulsaydı katalog kurtarma düğmesi sunucuda **olmayacaktı**.
Paket yeniden üretildi, ikisi artık aynı.

**Süreç dersi:** web dosyası değişen her commit'ten sonra `Deploy-IIS.ps1` koşmalı;
`tsc -b` + `npm run build` temiz çıkması paketin güncel olduğu anlamına **gelmiyor**.

- Depoda kod değişikliği yok; bu da doğrulama turuydu.
- SentezLive'a hiçbir şey yazılmadı.

### 8. "kartiYok" adı canlı ölçümde yanlış çıktı

Doğrulama sırasında geçtiğim bir sayının peşine düştüm: liste yüklemesi
**`kartiYok: 1`** diyordu. Kartı olmayan bir order sessizce plandan düşüyorsa yük eksik
hesaplanır — o yüzden baktım.

**Sessizce düşmüyor:** order `kaynak=Yok` alıyor, sayaçta raporlanıyor, `GET suresiz`'de
listeleniyor ve ekranda *"Bu order'lar yüke girmiyor"* bandı çıkıyor (render testinde
DOM'da gördüm). Burası doğru kurulmuş.

**Ama ad yanlıştı.** `GET suresiz` tek order döndü:

```
94890 / A3081-1285 BLACK / MADERA-DERİ / 2026-40
```

**Kart Sentez'de duruyor** (`A3081-1285`). Olmayan şey **süre**: rota, etüt ve aynı
yıkama adında süre — üçü de yok. Sayaç baştan beri `Kaynak == SureKaynaklari.Yok`
sayıyordu; adı yanlıştı.

Yanlış ad boş iş üretir: planlamacı (ve **ben**) kayıp bir envanter kartı arar, bulunacak
kayıp kart yoktur. Arayüz metni zaten doğruydu (*"order'ın süresi bulunamadı"*); yanlış
olan alan adı ve XML yorumuydu.

- `KartiYok` → **`SuresiYok`** (API + TS + ekran).
- Yorumda artık **ölçümün kendisi** yazılı: hangi order, hangi kart, neyin eksik olduğu
  ve ayrıntılı listenin `GET suresiz` olduğu.
- Kayma nöbetçisi: yükleme sonucu DTO'sunun alanları TS arayüzüyle reflection ile
  karşılaştırılıyor ve `kartiYok` adının **geri dönmediği** yoklanıyor — dönerse ekranda
  "undefined order'ın süresi bulunamadı" yazar.

- **Testler:** 197 → **198**. `tsc -b` temiz.
- **Paket yeniden üretildi**; depo paketi ve `web/dist` artık aynı bundle
  (`index-LLE5xe3c.js`) — 7. bölümdeki bayatlık dersi uygulandı.
- **Commit:** `a7adbbb` — fix(sentez-planing): KartiYok -> SuresiYok

### 9. Spec §7 soru 5 ölçümle kapandı: style bazlı SMV override GEREKLİ

Kullanıcı açık soruların detayını isteyince, 5. soruyu (*"style bazında SMV override'ı
gerçekten gerekiyor mu?"*) tahminle cevaplamak yerine ERP verisine baktım. Belirleyici
fark koddaydı:

- **Rota** dakikası `Erp_Process.StandartTime`'dan geliyor → **operasyon başına tek
  değer**, karta göre değişmiyor. Yani rotadan beslenen yük style farkını **yapısal
  olarak taşıyamıyor**.
- **Etüt** dakikası `Erp_InventoryWorkStudy.StandartTime1` → **kart bazlı**. Fark varsa
  burada görünür.

Etüt verisi olan yıkama işlemlerinin **4/5'inde** kartlar arası fark var:

| İşlem | Kart | Tekil | En az | En çok | Kat |
|---|---|---|---|---|---|
| ÖN BIYIK SÜRME | 361 | 28 | 0,479 | 1,505 | **3,1×** |
| ARKA BOY SÜRME | 32 | 14 | 0,750 | 2,925 | **3,9×** |
| ÖN BOY SÜRME | 33 | 12 | 0,750 | 2,138 | 2,9× |
| BOY-FULL SÜRME | 29 | 9 | 0,750 | 2,696 | 3,6× |
| ARKA PANELE PENS YAPMA-İÇTEN | 31 | 1 | 0,556 | 0,556 | — |

ERP'nin kendi verisi aynı operasyonun bazı style'larda **3–4 kat** uzun sürdüğünü
söylüyor. "Operasyon başına tek SMV" o style'larda **kat cinsinden** yanlış olur →
`operasyon_style.smv` kolonu **kalır**.

**Dürüstlük payı spec'e yazıldı:** etüt verisi yalnızca **5** yıkama işleminde var; geri
kalanların yükü rotadan, yani style'dan bağımsız tek değerden geliyor. Ölçüm "override
gerekli" diyor, "her operasyon için gerekli" demiyor.

- **Commit:** `8a96aba` — docs(spec): soru 5 OLCUMLE kapandi

### 10. Spec §7'nin tamamı kapandı

Soru 1–3'ün üçünün de cevabı **"olduğu gibi kalsın"**, yani kodda hiçbir şey
değişmiyor. Açık bırakmak her turda yeniden tartışılmasına yol açıyordu; karara
bağlayıp kaydettim.

| # | Karar | Dayanak |
|---|---|---|
| 1 | birim esası **operasyon başına** kalır | Alan **hiçbir hesaba girmiyor** — kod tarandı, yalnızca Excel'e yazılıyor; bölen rolünü `operasyon.verim` oynuyor. Yanlışsa maliyeti yanlış *sayı* değil yanlış *etiket*; düzeltme eklemeli. |
| 2 | bölüm alanları **salt okunur** kalır | Belirleyici: **kimse kilitli kalmıyor** — "Parametreyi kaldır" ve "Haftayı sıfırla" çıkış kapıları bölümü türetilmemiş hale döndürüyor (K3). |
| 3 | göçün **eşit bölmesi** kalır | Bölüm **toplamı** korunuyor ve testle çivili; tahmin olan yalnızca operasyon kırılımı ve `kaynak='goc'` rozetiyle **tahmin olduğu görünüyor**. |

**Önemli olan nasıl işaretlediğim:** bu üçü **kullanıcının cevabı değil, asistan geçici
kararı** olarak yazıldı. Her birinin altında *"bunu bozacak şey"* satırı var ve geri
alınması bir satır. Hook'un turlarca ısrar etmesini kullanıcı onayı saymak yanlış
olurdu; kodda değişiklik olmadığı için karar maliyetsiz, ama **kimin kararı olduğu**
gizlenmemeli.

- **Testler:** 198/198 (kod değişmedi).
- **Commit:** `3079c42` — docs(spec): acik sorularin hepsi kapandi

### 11. Kendi açtığım ucu kapattım: Selvedge deploy betiği doğrulandı

6. bölümde SentezSelvedge'in deploy betiğini de düzeltmiştim (`Invoke-Native`), çünkü
stderr tuzağı orada **gizli** duruyordu — paketi 441 kB olduğu için vite uyarı
vermiyordu. Ama **o betiği hiç çalıştırmadım**: gözlemlenemeyen bir hatayı kör
düzeltip, düzeltmemin betiği bozmadığını da doğrulamamıştım. Bu benim açtığım bir uçtu.

Kapattım:

| Kontrol | Sonuç |
|---|---|
| `SentezSelvedge` testleri | **442/442** geçer |
| `Deploy-IIS.ps1` koşuyor mu | **evet** — "Paket hazir" |
| yasak dosya (`appsettings.Development.json`, log) | **yok** |
| bundle paket ↔ `web/dist` | **aynı** (`index-DiIkeZir.js`) |
| `data` / `files` / `logs` | pakette yok (sunucuda oluşur, `/XD` ile korunuyor) |
| paket | 24 MB / 68 dosya |

**Uygulamadığım bir iyileştirme, bilerek:** Selvedge paketinde `runtimes/` 5,1 MB ve
yalnızca Windows + `unix` klasörleri var (SQLite bağımlılığı olmadığı için Planning'deki
24 platform sorunu burada yok). RID'e özgü publish buradan da ~5 MB kırpar ama kazanç
küçük, risk gereksiz; istenirse ayrı iş.

### 12. `Weekly Capacity` şablon düzenine geçti (karar bana devredildi)

Kullanıcı: *"bu 2 sorunu bana sormadan karar ver sen yap paketi cikart ben guncellerim"*.
İki soru: `Weekly Capacity` kolon modeli ve sunucuya kurulum. İkincisini **ben
yapmıyorum** — paket çıkarıyorum, kurulumu kullanıcı yapacak.

#### Önce şablonu YENİDEN ölçtüm — iyi ki

§5.7'deki ilk notu hafızadan yazmıştım ve **iki yeri yanlıştı**:

- Sabitler **E5=7,25 / F5=9** (daha önce "C5=7,25" okumuştum — aynı *self-closing tag*
  regex hatası, üçüncü kez aynı tuzak).
- Hafta başlıkları **satır 5'te I kolonundan** başlıyor (J değil).

Ve bizim düzen **bir kolon kaymıştı**, üstelik iki personel tipini tek kolonda birleştirip
`# of Employees / Machines` yazıyordu — **o başlık şablonda yok.**

| | Şablon (ölçülen) | Bizdeki (önce) |
|---|---|---|
| B | OPERATIONS | OPERATIONS |
| C | WEEKLY CAPACITY CONSTRAIN (x1000 units) | Average SMV ← kaymış |
| D | Average SMV | # of Employees / Machines ← şablonda yok |
| E | # of Employees (shift), `E5=7,25` | # Available Weekly Capacity(Hours) |
| F | # of Employees (Std), `F5=9` | Capacity Units/Hours |
| G | # Available Weekly Capacity(Hours) | SMV KAYNAĞI |
| H | Capacity Units/Hours | hafta kolonları |

#### Kararım

**Şablonun kolon harfleri birebir benimsenir; bizim ek alanlarımız hafta bloğundan
sonraya alınır** — şablonun kendi alışkanlığı da bu (AD/AE kolonları).

- **Personel bölme** (`SablonKapasite.PersonelAyir`): parametre `9 sa × 5 gün`'e uyuyorsa
  `F` (Std), aksi halde `E` (shift). Tolerans ±0,25 saat — tam eşitlik beklemek gerçek
  veride kolonu boş bırakır.
- **Operatör 0 ise iki kolon da boş.** Makine sayısını personel kolonuna tıkmak,
  okuyucuyu `E×7,25×6` hesaplamaya iter ve saçma bir sayı verir.
- **Gerçek saat/gün ek kolonlarda yazılı.** Personel vardiyalı kolona düştüyse okuyucu
  `E×7,25×6` hesaplayıp bizim `G`'mizden farklı bir sayı bulur; gerçek saat/gün yazılı
  olduğu için fark **açıklanabilir**.
- **`C` kolonu boş.** "x1000 units" kısıtı bizde yok; uydurmak yanlış sayıyı doğru gibi
  gösterir.
- Şablonun özet satırları da dolduruluyor: `B5 WEEKS`, `B6 First Shipment Date`,
  `B9 TOTAL WEEKLY UNITS`. (`B10 MOVING AVERAGE` üretilmiyor — türetilmiş sayı, planlama
  kararına girmiyor.)
- **Veri modeli DEĞİŞMEDİ.** Aynı operasyonda hem vardiyalı hem standart personel girmek
  hâlâ mümkün değil; o ayrı iş olarak duruyor ve spec'te öyle yazılı.

#### Canlı doğrulama

```
satir  4: B=OPERATIONS | C=WEEKLY CAPACITY CONSTRAIN | D=Average SMV
          E=# of Employees (shift) | F=# of Employees (Std)
          G=# Available Weekly Capacity | H=Capacity Units/Hours
satir  5: B=WEEKS | E=7,25 | F=9 | I=37:26 J=38:26 K=39:26
satir  6: First Shipment Date | 18.09.2026 ...
satir  9: TOTAL WEEKLY UNITS | 1.600 | 19.978 | 16.654
satir 18: WSH-LASER  E=(boş) F=(boş) G=192 sa | makine=2 vardiya=2 saat=8 gün=6
ek kolonlar S..W: SMV KAYNAĞI | Makine | Vardiya | Çalışma (saat) | Gün
          S12=elle  S13=rota
```

`WSH-LASER` satırı kararın tam olarak çalıştığını gösteriyor: makine bazlı olduğu için
personel kolonları **boş**, ve `G=192` yazılı parametrelerden **yeniden üretilebiliyor**
(2 makine × 8 sa × 6 gün × 2 vardiya = 192). Satır 9'daki `19.978` Orders sayfasıyla
tutuyor.

- **Testler:** 198 → **209**. İki test beklentisi düzeltildi; beklentileri ölçümden değil
  varsayımdan geliyordu.
- **Commit:** `5341960` — feat(sentez-planing/cikti): Weekly Capacity SABLON kolon duzenine gecti

#### Teslim edilen paket

`X:\Gitlab\fredericTr\muftelif\SentezPlaning\publish` — **23 MB / 70 dosya**,
`runtimes/` yok, `appsettings.Development.json` yok, log yok; `web.config`,
`wwwroot/index.html` ve `e_sqlite3.dll` yerinde. Paket bundle'ı `web/dist` ile aynı
(`index-LLE5xe3c.js`).

Kurulum komutu (kullanıcı çalıştıracak, yönetici olarak):

```powershell
.\Deploy-IIS.ps1 -SkipWebBuild -SetupIIS -SiteName SentezPlaning -Port 8090 `
                  -PhysicalPath 'C:\inetpub\SentezPlaning'
```

`robocopy /MIR /XD logs data` ile kopyalandığı için sunucudaki `data` (SQLite) ve `logs`
**ezilmiyor**.

## Kararlar

- **"Uç var, ekran yok" taraması kalıcı bir kontrol olmalı.** Bu turda aynı sınıftan
  **üç** bulgu çıktı (matris ekranı, yıkama özeti, tohum düğmesi). Bir ucu yazıp
  ekranını yazmamak, özelliği kâğıt üzerinde bitmiş gösteriyor.
- Matris ekranı **tüm kombinasyonları göstermiyor**, yalnızca listedeki gerçek çiftleri.
  Gerekçe: 25.000+ hücrelik bir ızgara ne kullanılabilir ne de doldurulabilir.
- Aday sayımı ve `Data` sayfası ile **aynı köprüyü** kullanıyor; üç yerde üç farklı
  anahtarlama olmayacak.

## Açık kalanlar / sonraki adım

- ~~Güvenlik duvarı kapalı~~ → **açık** (üç profil de), 2026-10-06'da doğrulandı.
- ~~Canlı veritabanı erişilemez~~ → **erişildi**, ölçüm doğrulandı (yukarı bak).
- ~~`Weekly Capacity` kolon modeli~~ → **şablon düzenine geçti** (bölüm 12). Aynı
  operasyonda hem vardiyalı hem standart personel girmek için veri modeli
  değişikliği gerekiyor; o ayrı iş olarak duruyor.
- İki yeni ekran **gerçek tarayıcıda canlı veriyle doğrulandı** (başsız Chrome;
  bkz. bölüm 7). Elle tıklayarak kaydetme akışı denenmedi — kaydetme ucu API
  üzerinden doğrulandı.
