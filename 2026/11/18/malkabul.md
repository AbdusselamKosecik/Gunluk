# malkabul — 2026-11-18

## Bağlam
El terminali yazıcı aktarıcısı (`yaziciaktarici.md`) üzerinden basıyor; kullanıcı "çalışıyor" dedi. Bugünkü istekler:
- 99×99 etiket tasarımı
- sayımda depo seçimi
- masaüstünde sayım serilerini görüp tekrar basma ve düzeltme
- etikette TR/EN açıklamalar; kumaşta "Top No", diğerlerinde "Koli No"

## Yapılanlar

### 1. 99 × 99 mm etiket (kullanıcı tasarımı, onaylandı: "Tasarım tamam")
- **Yerleşim** (`SeriEtiketi.cs`, `EtiketIcerigi` record):
  - En üstte MODFEX APPAREL.
  - Ürün kodu, ürün adı (2 satır), renk ve lot.
  - QR (`^BQN,2,9`, `QA,<seri>`) ve yanında okunur kod (kumaşta TOP NO / ROLL NO, diğerlerinde KOLİ NO / BOX NO) ile miktar.
  - Sayımı yapan / Counted by, Sayım zamanı / Count time; mal kabulde Hazırlayan / Prepared by, Hazırlama zamanı / Prepared.
  - Basım zamanı / Printed. Mal kabulde SAS no/satır.
- 203 dpi'de 99 mm = 791 nokta. Varsayılan ölçü 99×99; kayıtlı 100×50 olan ayarlar açılışta 99×99'a geçiyor.
- **Kumaş tespiti:** Sentez `Erp_Inventory.InventorySubType = 2` (canlıda kumaş ihtiyaçlarının 147/152'si) ya da kod `KMS` ile başlıyor; okunamazsa koli sayılıyor.
- **Sayımı yapan:** `SayimKalemi.Yapan` = `Meta_User.UserCode` (kalemin InsertedBy'ı).
- Örnek etiketler aktarıcıdan basıldı.

### 2. Sayım ekranında depo seçimi
Üstte depo listesi var. Seçilen depo `SayimDepoId` ayarına yazılıyor ve sonraki açılışta hatırlanıyor.

### 3. Masaüstü "Sayım serileri" (`SayimListesiViewModel/View`, ana menü)
- Sayım deposu + tarih aralığı (varsayılan bugün) + arama (seri / stok / lot / kullanıcı).
- Tekrar bas: tek satır ya da seçililer.
- Düzelt: miktar ve lot (`SayimDeposu.DegistirAsync`).
  - Miktar yalnız fiş 16'da ve seri sonradan hareket görmediyse değişir. Değişince kalem Quantity / NetQuantity, varyant, seri hareketi ve seri kartı birlikte güncellenir; stok toplamlarını Sentez tetikleyicileri düzeltir.
  - Fiş 17'de miktar değişmez, yalnız lot.

### 4. ÖNEMLİ HATA DÜZELTMESİ: stok iki kat okunuyordu
- **Bulgu:** `Erp_InventoryTotal`'da her stok × depo için bir genel toplam satırı (`TotalDate IS NULL`) ve günlük satırlar var (`EditInventoryTotal` → `EditInventoryTotalD` hem NULL hem tarihle çağrılıyor). `SUM(ActualStock)` stoğu iki kat gösteriyordu.
- **Etkisi:**
  - Sayımı kapat depoyu iki kat düşüp eksiye indirirdi (testte 182 satır).
  - Karantina listesinde serisiz miktar iki kat görünürdü.
  - `StokAsync` (serisiz verme ve onay kontrolü) iki kat izin verirdi.
- **Düzeltme:** üç sorguya `TotalDate IS NULL` eklendi. Yeni testler: kapatınca pozitif kalmaz ve yeni eksi oluşmaz; stok genel toplam satırından okunur. Diğer repolarda bu desen yok.
- Sayımı kapat canlıda hiç kullanılmadığı için gerçek veri bozulmadı.

## Sonuç
- 144/144 test (DB dahil, ROLLBACK).
- APK PM66'ya kuruldu: `dagitim/malkabul-2026-11-18.apk`. Windows paketi: `dagitim/malkabul-masaustu-2026-11-18.zip`.
- **Commitler:** `20c3a16` (etiket + depo), `e3eb7de` (stok düzeltmesi), `5b222e5` (sayım serileri + TR/EN + top/koli no).

## Açık kalanlar
- Windows'ta masaüstü paketinin kurulması (yeni ana menü: Sayım serileri).

---

## Öğleden sonra: depo yeri (13:18–13:45)

### 5. Depo yeri ve yer değişimi
- **Neden:** Kullanıcı: "El terminalinde depo yeri eklememiz lazım, depo yeri değişimi de; sayımda depo seçtikten sonra depo yeri seçimini yapmamız lazım." Yer kodlarını depocudan istemişler, Sentez'de tanımlanacak.
  - Dünkü "raf yeri iptal" kararı bununla geri açıldı.
- **Sentez'de bulunanlar (salt okuma):**
  - Yerler `Erp_WarehouseLocation` tablosunda (LocationCode, Explanation, Barcode, Corridor/Shelf/Division, InUse). Şu an yalnız depo 41'de (M) 304 yer var; hiçbir fişte kullanılmamış.
  - Yer kolonları: fiş kalemi ve varyantında `In/OutWarehouseLocationId`, seri hareketinde de aynısı, `SerialCardTotal.WarehouseLocationId`.
  - Toplamları Sentez tetikleyicileri tutuyor: `EditInventoryTotalD` → `EditWarehouseLocationTotal` → `Erp_WarehouseLocationTotal`. Seri × yer toplamını seri hareketi tetikleyicisi tutuyor.
- **Yapılanlar:**
  - **Yazma yardımcıları:** `FisSql` kalem ve varyant insert'lerinde yer kolonları parametre oldu. `FisYazimi.KalemEkle/VaryantEkle/SeriHareketiEkle` isteğe bağlı `girisYer` / `cikisYer` alıyor (varsayılan null, eski çağrılar aynı).
  - **`FisYazimi.SeriYeriAsync`:** serinin depodaki yeri. Depodan çıkan her seri hareketi bunu çıkış yeri olarak yazıyor: üretime ver 129, karantina onayı 17 ve reddi 122, sayım taşıması 17, sayımı kapat 130 (kapatmada seri × yer gruplu). Yoksa yer toplamı hiç düşmezdi.
  - **Sayım:**
    - `SayimDeposu.YerlerAsync(depo)`, `YerKontrolAsync` (hata: YerBuDepodaDegil).
    - Okut / SeriOlustur / SerisizEkle `yer` alıyor.
    - `SayimKalemi.Yer`; listede `wl.LocationCode`.
    - Ayar `SayimYerId`; depo değişince 0'a dönüyor.
  - **Terminal sayım ekranı:** depodan sonra "Depo yeri" seçimi ve "Yersiz" düğmesi; yer yalnız depoda tanımlıysa görünüyor. Raf etiketi (yer kodu ya da barkodu) okutulunca yer seçiliyor, sonraki seriler o yere yazılıyor.
  - **Yer değiştir:**
    - Terminal menüsünde yeni ekran (`YerDegistirViewModel/View`): depo → hedef yer (okut ya da seç) → serileri okut.
    - Veri tarafı `DepoYeriDeposu.TasiAsync`: fiş 17, giriş = çıkış deposu, giriş yeri hedef, çıkış yeri eski yer, özel kod `UZMYR`, günlük başlık.
    - Hatalar: SeriBuDepodaDegil, SeriZatenBuYerde, SeriBulunamadi.
  - **Masaüstü "Sayım serileri":** lotun altında yer kodu görünüyor.
- **Testler:**
  - `DepoYeriTestleri` (8, canlı DB, ROLLBACK, depo 41'in gerçek yerleri): yeni seri yere yazılıyor ve yer toplamı artıyor; başka deponun yeri reddediliyor; okutulan seri yere taşınıyor; yer değişiminde depo stoğu aynı, A −20, B +20, özel kod UZMYR; yersiz seri yere konuyor; aynı yer ya da başka depo reddediliyor; yerdeki seri depodan çıkınca yer toplamı düşüyor.
  - `SayimEkraniTestleri` +3 ve `YerDegistirEkraniTestleri` (4).
  - Toplam **159/159**.
- **Commit:** `33ca24c`.
- **Dağıtım:** APK `dagitim/malkabul-2026-11-18.apk` (PM66 bağlı değildi, kurulmadı), Windows `dagitim/malkabul-masaustu-2026-11-18.zip`.

## Açık kalanlar
- PM66'ya APK kurulumu (cihaz USB'ye bağlanınca `adb install -r`).
- Depocu sayım deposu (ve hammadde) için yerleri Sentez'de tanımlamalı. Barkod alanı doluysa raf etiketi barkodla da okunur, değilse yer kodu barkod olarak basılmalı.
- Serisiz stokta yer değişimi yok (yalnız seri); gerekirse eklenir.

### Raf (depo yeri) etiketi basımı — masaüstü
- **Neden:** Kullanıcı: "depo uygulamasından, Desktop aynı yazıcıya depo yerlerini yazdırma işlemi eklermisin". Terminal (sayım, yer değiştir) raf etiketini okutunca yeri seçiyor; etiketin basılması gerekiyordu.
- **Ne yapıldı:**
  - `Veri/RafEtiketi.cs`: `Zpl(DepoYeri, Depo, genişlikMm, yükseklikMm, dpi)`. Yerleşim 99×99 mm, 792 noktaya göre çizildi, ayardan ölçekleniyor. İçerik: MODFEX APPAREL, "DEPO YERİ / LOCATION", büyük yer kodu (≤8 karakter 150, ≤12 karakter 110, daha uzunsa 76 nokta), açıklama (2 satır), ortada QR (Sentez Barcode doluysa barkod, değilse LocationCode; terminaldeki `DepoYeri.Eslesir` ikisini de tanıyor), altta "DEPO / WAREHOUSE: kod · ad". `SeriEtiketi.Temiz` internal yapıldı (^ ~ temizliği ortak).
  - `EtiketBasici.RafBasAsync(DepoYeri, Depo)`: aynı ZplYazici ve ayarlar (aktarıcı ya da doğrudan Zebra).
  - Yeni ekran `RafEtiketleriViewModel` / `RafEtiketleriView`; ana menüde "Raf etiketleri" girişi.
    - Depo listesi (varsayılan SayimDepoId, yoksa ilk depo); `SayimDeposu.YerlerAsync` (InUse, kod sırası).
    - Arama kod, açıklama ve barkodda anında süzüyor.
    - "Hepsini seç" görünenleri seçiyor. "Seçilileri bas" yalnız görünen seçilileri basıyor; ilk hatada duruyor.
    - Her satırda "Bas" düğmesi. Yer yoksa `DepodaYerYok` uyarısı.
  - Metinler: RafEtiketleriBaslik, RafEtiketleriMenuAciklama, RafEtiketleriAra, RafEtiketleriOzet, YerSecin.
- **Dokunulan dosyalar:** `MalKabul/Ekranlar/Veri/RafEtiketi.cs`, `Veri/SeriEtiketi.cs`, `EtiketBasici.cs`, `RafEtiketleriViewModel.cs`, `RafEtiketleriView.axaml(.cs)`, `AnaMenuView(Model)`, `UygulamaMetinleri.cs`, testler `RafEtiketiTestleri.cs` (3 ZPL + 5 ekran), `UygulamaMetinleriTestleri.cs`, `EkranGoruntusuTestleri.cs` (malkabul-15-raf-etiketleri.png).
- **Sonuç:** 167/167 test (DB dahil). Windows zip yenilendi: `dagitim/malkabul-masaustu-2026-11-18.zip`.
- **Commit:** `a6eee4c` — Masaustu Raf etiketleri ...
- **Açık:** Etiket henüz yazıcıda denenmedi. Kullanıcı yeni zip'i kurup bir raf etiketi basmalı ve terminalde okutarak denemeli.

### Siparişten seri: toplu oluştur (etiketsiz) → düzelt → toplu bas
- **Neden:** Kullanıcı: "siparişten seri oluştur dediğimizde 10 adet oluştursun, etiket basmasın; miktarlarını, lotlarını değiştirebilelim, sonra toplu basabilelim". Toplar tek tek tartılıyor, miktarları farklı çıkıyor.
- **Ne yapıldı:**
  - `MalKabulDeposu.SeriGuncelleAsync(companyId, userId, serialCardId, miktar, lot)`:
    - Kilit `MalKabulFisDeposu.KilitAlAsync` (silmeyle aynı; kontrol ile yazma arasında terminal içeri alamaz).
    - Seri hareketi varsa `SeriIcerideDegismez` hatası.
    - Doğrulama: miktar > 0; lot kırpılır, boşsa NULL, en çok 50 karakter.
    - `UPDATE Erp_InventorySerialCard (Quantity, PartyNo, UpdatedAt/By)`. Sentez tablosunda trigger olduğu için `OUTPUT ... INTO @d` kullanıldı.
  - `SeriGirisViewModel` yeniden yazıldı:
    - DB ve yazıcı çağrıları değiştirilebilir delegeler (testte sahte); toast'lar `Bildir` üzerinden.
    - Adet varsayılanı 10 ve oluşturmadan sonra sıfırlanmıyor.
    - Oluştur etiket basmıyor; yeni seriler listede seçili geliyor.
    - Satır modeli `SeriSatiri`: Secili, MiktarGirdisi, LotGirdisi, Degisti, Duzenlenebilir (= içeri alınmamış).
    - "Değişiklikleri kaydet": önce hepsi doğrulanıyor, biri hatalıysa hiçbiri yazılmıyor.
    - "Seçilileri bas" ve satırdaki "Bas" önce değişenleri kaydediyor, sonra seri kodu sırasıyla basıyor; ilk yazıcı hatasında duruyor.
    - Sil sonrası liste yeniden yüklenmiyor; seçimler ve kaydedilmemiş girdiler korunuyor.
  - View: satırda seçim kutusu, miktar ve lot TextBox (içerideyse kapalı), Bas ve Sil; başlıkta Hepsini seç, Değişiklikleri kaydet, Seçilileri bas.
  - Düğme metni "SERİLERİ OLUŞTUR (etiketsiz)" oldu. Yeni metinler: SerilerGuncellendi, SeriMiktarGecersiz, SeriIcerideDegismez, DegisiklikleriKaydet, SeriTopluAciklama.
- **Testler:**
  - `SeriGirisEkraniTestleri` (6): 10 adet etiketsiz ve seçili; yalnız değişen kaydediliyor; basmadan önce kaydedip kod sırasıyla basıyor; geçersiz miktarda hiçbir şey olmuyor; içeride olan atlanıyor; hepsini seç.
  - DB (ROLLBACK): `Iceride_olmayan_serinin_miktar_ve_lotu_degisir` (MalKabulTestleri), `Iceride_serinin_miktar_lotu_degismez` (MalKabulFisTestleri, gerçek SeriIceriAlAsync ile).
- **Sonuç:** 175/175 (DB dahil). Windows zip yenilendi, uygulama bu makinede yeniden açıldı.
- **Commit:** `72a90a3`

### Tahsis sürükle-bırak; üretime verirken top bütün, aksesuar miktarla
- **Neden:** Kullanıcı istedi:
  - Masaüstünde tahsis, ihtiyaca göre seri sürükleyerek yapılsın.
  - Terminalde seri okutularak üretime sevk ve iade alınsın; iadede alınan miktar girilsin.
  - Toplar parça parça verilmesin, aksesuarlarda miktar yazılsın. Tekli ürünler (= serisiz, kullanıcı cevabı) bunların dışında, değişmez.
  - Sürüklenecek liste için kullanıcı "seçili ihtiyacın serileri" seçeneğini seçti.
- **Ne yapıldı:**
  - `TahsisDeposu.UygunSerilerAsync(b, t, companyId, hammadde, requirementId)` (public sarmalayıcı hammadde = `AyarDeposu.HammaddeDepoId`):
    - İhtiyacın stoğu, ihtiyaçta renk varsa o renk.
    - Hammadde deposunda SerialCardTotal > 0; aktif tahsisi yok (`AktifKosul`).
    - Miktar hammaddedeki miktar, yer en çok miktarın olduğu LocationCode. İlk 500, seri koduna göre.
  - `UygunSeri` ObservableObject (Secili).
  - `TahsisViewModel`:
    - `UygunSerileriGetir` ve `Bildir` delegeleri.
    - İhtiyaç seçilince uygun seriler yükleniyor; sıra sayacıyla eski yanıt atılıyor.
    - `BirakAsync(ihtiyac, kodlar)` (görünümden çağrılıyor) ve `SecilileriTahsisEt` komutu.
    - Okut da aynı `TahsisEtAsync` üzerinden gidiyor: seriler tek tek tahsis ediliyor, reddedilen bildiriliyor, diğerleri devam ediyor. Sonunda `SerilerTahsisEdildi` ve yenileme.
  - `TahsisView`: üç sütun (Order 260, ihtiyaç ve tahsisliler, uygun seriler 360).
    - Seri satırında PointerPressed → `DragDrop.DoDragDropAsync(e, DataTransfer(CreateText(kodlar \n)), Copy)`. Avalonia 12 API: DataTransfer, DataTransferItem, `e.DataTransfer.TryGetText()`.
    - İşaretli seri basıldıysa bütün işaretliler, değilse yalnız o seri taşınıyor; CheckBox'a tıklama sürükleme başlatmıyor.
    - İhtiyaç satırı bırakma hedefi (`DragDrop.AllowDrop`, DragOver, Drop).
  - `UretimDeposu.KumasMiAsync`: InventorySubType = 2 ya da kod KMS% / T-KMS% (etiketteki kuralla aynı).
    - `SeriUretimDurumu.Kumas` eklendi.
    - `UretimeVerAsync`: kumaşta verilecek miktar depodaki miktara eşit değilse `TopBolunmez` hatası (miktar null ise bütün veriliyor).
  - `UretimViewModel`: `TopButunVerilir` (vermede ve kumaşta) → miktar kutusu ReadOnly ve uyarı metni; Kaydet hammaddedeki miktarı gönderiyor. İadede ve aksesuarda miktar düzenlenebilir.
  - Metinler: SerilerTahsisEdildi, UygunSeriler, UygunSeriYok, SurukleBirak, SecilileriTahsisEt, TopBolunmez, TopButunVerilir; TahsisAciklama güncellendi.
- **Testler:**
  - DB: `Kumas_topu_parca_parca_verilmez_butun_verilir`, `Seri_durumu_kumas_mi_bildirir`, `Uygun_seriler_hammaddede_tahsissiz_ayni_stok_renk`.
  - Eski kısmi verme testi T-AKS-001 aksesuarına çevrildi. Test stokları: 87616 T-KMS-001 sub 2, 87617 T-AKS-001 sub 3 serili, 87618 T-IPL-001 serisiz.
  - Ekran: `TahsisEkraniTestleri` (3), `UretimEkraniTestleri` (+2).
- **Sonuç:** 183/183 (DB dahil). APK PM66'ya kuruldu ve açıldı. Windows zip yenilendi, uygulama bu makinede yeniden açıldı.
- **Commit:** `92604ac`
- **Not:** Bir ara `git checkout -- .` çalıştırıldı (geçici probe sonrası). Ağaç zaten temizdi, kayıp yok. Bundan kaçınılmalı.

### Düzeltme: testler kullanıcının ayarlarını siliyordu
- **Belirti:** Kullanıcı: "her açtığında parametreler neden siliniyor". Masaüstü uygulaması her açılışta sunucu, SQL ve yazıcı alanları boş geliyordu.
- **Kök neden:**
  - `%LOCALAPPDATA%\Modfex\malkabul\ayarlar.json` testlerden yazılıyordu.
  - Ekran görüntüsü testi `SayimViewModel.SeciliDepo = 41` yapıyor; varsayılan "son depoyu hatırla" delegesi `AyarDeposu.Kaydet(AyarDeposu.Gecerli)` çağırıyor.
  - Test sürecinde Gecerli boş `Ayarlar` olduğu için dosya boş sunucu ve yazıcıyla, SayimDepoId = 41 olarak eziliyordu.
  - Dosya zamanı (16:11) test turuyla aynı.
- **Düzeltme:**
  - `AyarDeposu.YalnizBellekte` bayrağı: true iken `Kaydet` yalnız `Gecerli`yi değiştiriyor, dosyaya yazmıyor.
  - Test derlemesi `[ModuleInitializer]` ile bayrağı açıyor (`MalKabul.Tests/AyarKorumaTestleri.cs`). DB testleri dosyayı yine okuyor.
  - TDD: önce derleme hatasıyla kırmızı, sonra yeşil.
- **Geri yükleme:**
  - Bozuk dosya `ayarlar.json.bozuk-20261118` olarak saklandı.
  - Sunucu / Veritabani / SqlKullanici / SqlSifreKorumali / SonSirketId / SonKullanici paketleme ayarlarından kopyalandı. DPAPI CurrentUser ve aynı entropi olduğu için şifre çözülmeden korumalı hâliyle taşındı.
  - YaziciIp 192.168.0.184:9100.
  - SayimDepoId 41 kaldı (testin yazdığı değer; kullanıcı kontrol etmeli).
- **Doğrulama:** 184/184 (DB dahil); test turundan önce ve sonra ayarlar.json md5 aynı.
- **Commit:** `cf9f754`
- **Açık:** Aynı kalıp suitin diğer uygulamalarında da olabilir (ekran VM'leri AyarDeposu.Kaydet çağırıyorsa); kontrol edilmeli.

### Terminal mal kabul siparişe göre
- **Neden:** Kullanıcı: "burada siparişe göre gitmesi lazım. mal alım siparişini seçip ona göre el terminalinde serileri okutmamız lazım. barkodları desktoptan yaptık". Önceki akışta yalnızca irsaliye girilip seri okutuluyordu; seri hangi siparişe aitse oraya yazılıyordu.
- **Ne yapıldı:**
  - `IceriAlViewModel`: üç adım — (1) mal alım siparişi seç (`MalKabulDeposu.SiparislerAsync`, aramalı; sıra sayacı eski sonucu atar), (2) irsaliye no (sipariş seçilmeden "SiparisSecin" hatası), (3) seri okut. Okutma `IceriAlIslemi(siparisNo, irsaliye, seri)`; her başarılı okutmadan sonra sipariş satırları (`SatirlarAsync`) yenilenir. "Sipariş değiştir" irsaliyeyi ve listeleri kapatır, "İrsaliyeyi değiştir" siparişi korur.
  - `MalKabulFisDeposu.SeriIceriAlAsync(..., string? siparisNo = null)`: seri kartının Explanation'ındaki sipariş seçili siparişle eşleşmezse (büyük/küçük harf duyarsız) `SeriBaskaSiparis` [seri, serinin siparişi, seçili sipariş] — fiş yazılmadan, kilit altında. Public imza artık sipariş no ister.
  - `SerisizEkleViewModel(irsaliye, siparis?)`: mal kabulden açılınca sipariş listesi atlanır, doğrudan seçili siparişin serisiz satırları gelir.
  - `SiparisSatiri.KabulMetni` (içeri alınan / sipariş) ve `KabulTamam` (satır yeşil).
  - Metinler: SiparisSecin, SeriBaskaSiparis, SiparisDegistir, MalAlimSiparisi, KabulIlerleme.
- **Dokunulan dosyalar:** `MalKabul/Ekranlar/IceriAlView(Model).axaml/.cs`, `SerisizEkleViewModel.cs`, `Veri/MalKabulFisDeposu.cs`, `Veri/MalKabulModelleri.cs`, `UygulamaMetinleri.cs`; testler `IceriAlTestleri.cs` (+3: sipariş seçilmeden irsaliye açılmaz, okutma seçili siparişle + satırlar yenilenir, sipariş değiştir), `MalKabulFisTestleri.cs` (+1 DB: başka siparişin serisi reddedilir, fiş yazılmaz; doğru siparişle alınır), `EkranGoruntusuTestleri.cs` (6 ve 6b sipariş seçili, yeni 6a sipariş listesi).
- **Not:** python düzenleme betiği bash heredoc'ta yine bozuldu (Türkçe/tırnak); betikler scratchpad'e Write ile yazılıp çalıştırıldı.
- **Komutlar:**
  ```bash
  MODFEX_DB_TEST=1 MODFEX_TEST_CIKTI=$TEMP/ekr dotnet test MalKabul.Tests
  dotnet publish MalKabul.Android -c Release -o $TEMP/mk_apk && cp $TEMP/mk_apk/*Signed.apk dagitim/malkabul-2026-11-18.apk
  adb -s 1ed69882 install -r dagitim/malkabul-2026-11-18.apk
  ```
- **Sonuç / doğrulama:** 188/188 (DB dahil); ayarlar.json md5 test öncesi/sonrası aynı. APK PM66'ya yüklendi (Success).
- **Commit:** `b8efeb9` — Terminal mal kabul siparise gore ...

## Açık kalanlar (ek)
- Gerçek siparişle uçtan uca deneme: masaüstünde seri + etiket → terminalde sipariş seç, irsaliye, okut → Karantina onayı.

### Mal kabul irsaliye no'suz + depo yeri
- **Neden:** Kullanıcı: "Tedarikçi irsaliyeyi neden istiyorsun, siparişten irsaliye oluşturacağız zaten; depo yeri varsa depo yeri seçip serileri okutmamız lazım" ve "sipariş kapatarak irsaliye oluşturacağız, irsaliye no'sunu girdirmeyeceğiz".
- **Karar (benim yorumum, kullanıcıya bildirildi):** Fiş = irsaliye, siparişten açılır: **sipariş × gün × depo × cari = bir tip 1 fiş** (UZMMK), DocumentNo boş. Aynı gün aynı siparişe okutmalar aynı fişe, ertesi gün yeni fiş. Yer, depoda tanımlıysa terminalde zorunlu (sunucu yalnız "yer bu deponun mu" denetler — sayım/üretim testleri 43'e yersiz alıyor).
- **Ne yapıldı:**
  - `MalKabulFisDeposu`: `SeriIceriAlAsync(companyId, userId, siparisNo, seriKodu, yer)` / iç `(b,t,..,depoId, seriKodu, siparisNo?, yer?)`; `SerisizEkleAsync(.., orderReceiptItemId, variant, miktar, yer)`; irsaliye parametresi ve `IrsaliyeKontrol` kalktı. `BaslikAsync(.., sip)`: bugünkü (ReceiptDate) aynı depo+cari, kalemi bu siparişe bağlı UZMMK fişi (UPDLOCK/HOLDLOCK, fiş kilidi altında) yoksa yeni. Yer `KalemEkle/VaryantEkle/SeriHareketiEkle` `girisYer` ile; `SayimDeposu.YerKontrolAsync`. `IrsaliyeKalemleriAsync` → `SiparisKalemleriAsync(orderReceiptId)` (son 300, yer kodu dahil). `OkutmaSonucu.Yer`, `AltMetin`.
  - `IceriAlViewModel` baştan: sipariş listesi → seçili sipariş kartı → yer ComboBox (YerVar) → okut. Raf etiketi (kod/barkod `DepoYeri.Eslesir`) okutulunca yer seçilir; yer varsa ve seçilmediyse `MalKabulYerSecin`. Yerler `SayimDeposu.YerlerAsync(MalKabulDepoId)` ile bir kez yüklenir.
  - `SerisizEkleViewModel(SiparisOzet?, DepoYeri?)`: başlıkta yer; kalem yere yazılır.
  - `KarantinaDeposu.BekleyenlerAsync`: IrsaliyeNo = `ISNULL(NULLIF(DocumentNo,''), ReceiptNo)` (eski fişlerde belge no, yenilerde fiş no).
  - Metin: MalKabulYerSecin; OkutulanYok "Bu siparişte henüz okutulan yok".
- **Testler:** IceriAlTestleri baştan (7: sipariş seçilmeden okutma yok, irsaliyesiz okutma + satır yenileme, yer zorunlu, raf etiketi yer seçer → seri o yere, hata, fazla, sipariş değiştir). MalKabulFisTestleri: belge no null; `Ayni_siparis_ayni_gun_ayni_fis_ertesi_gun_yeni_fis` (ReceiptDate düne çekilir), `Secilen_depo_yeri_kalem_ve_seri_hareketine_yazilir` (41 'M' yerli depo), `Baska_deponun_yeri_reddedilir`; irsaliyesiz / başka tedarikçi testleri kalktı. Diğer DB testlerinden irsaliye argümanı regex ile silindi.
- **Sonuç:** 187/187 (DB dahil), ayarlar.json md5 aynı. Desktop zip yenilendi ve uygulama yeniden açıldı. APK derlendi (`dagitim/malkabul-2026-11-18.apk`) ama **terminal adb'de görünmedi, yüklenmedi**.
- **Commit:** `6177bbd` — Mal kabul irsaliye no'suz ...

## Açık kalanlar (ek)
- APK'yı PM66'ya yükle (adb bağlantısı yoktu).
- "Sipariş kapatarak irsaliye": sipariş × gün yorumu kullanıcıyla teyit edilmeli; isterse "Kabulü bitir / siparişi kapat" düğmesi (fişi kapatır, sonraki okutma yeni fiş) eklenebilir.
- `SeriKabulKurallari.IrsaliyeHatasi` ve IrsaliyeGerekli/IrsaliyeBaskaTedarikci metinleri artık kullanılmıyor (temizlenebilir).
