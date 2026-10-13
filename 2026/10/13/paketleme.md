# paketleme — 2026-10-13

## Bağlam
Kullanıcı: "paketlemede tezgah işlemleri tamam mı? terazi işlemleri falan" + SerialPort Terminal ekran görüntüsü (hex).

## Yapılanlar

### 1. Terazi veri şablonu doğrulandı — `f4e942e`
- **Görüntüden çözülen akış:** `2B 30 30 30 33 2E 38 30 6B 67 0D 0A` = `+0003.80kg` CR LF; değerler 3.80, 3.85, 3.85, 3.75 … 0.00;
  kararlılık işareti yok (sürüm 1 biçimi).
- Mevcut `TartiOkuyucu.Ayristir(…, 1)` deseni (`^\s*([+-])\s*(\d+(?:\.\d+)?)\s*kg\s*$`) baştaki sıfırlı değeri okur; port
  `NewLine="\r"`, satır başındaki LF `Trim` ile atılır. Kod değişikliği gerekmedi.
- **Testler:** `GercekTeraziTestleri` 7 (gerçek satırlar, yarım satır "70kg" atlanır, dalgalanan akış kararsız, 5 eşit okuma → 3.85
  kararlı, boş terazi 0.00 kararlı sayılmaz) — geçti.
- **Doğrulanmadı:** baud (kod 9600 8N1 varsayar; görüntüde baud yok), gerçek port ile uçtan uca.

## Durum
- Tezgah/mamul/sevk tabloları canlıda hâlâ **yok** (`db/0002_tezgah.sql`, `sevkiyatmobil/db/0001_sevkiyatmobil.sql` çalıştırılmadı).

### 2. "Beş yaşındaki çocuk" okutma ekranı — `f356f13`
- **Neden:** kullanıcı "5 yaşındaki çocuğun anlayacağı gibi yapar mısın ekranları". Seçimler: düzen "Komut + dev sonuç";
  terazi kararlı olunca operatör **TAMAM**'a basar (otomatik kapatma yok).
- **Ne yapıldı:**
  - `Ekranlar/Veri/EkranRehberi.cs` (saf): durum → adım (① box ② ürün ③ adet ④ terazi ⑤ etiket) + tek komut anahtarı;
    hata → `Ipucu_{hata}` "ne yapmalı" anahtarı (21 hata).
  - VM: `Iyi/Kotu` sonuçları büyük alana da yazar; `KomutGuncelle`; `BuKolideSayi`, `KalanSayi`; `Tus` (sayı tuşları),
    `HizliAdet` (6/12/24/kalan), `YanlisOkuttum` (Sil aç/kapa, kenar kırmızı), `DetayGoster`, `YeniKapandi` (⑤).
  - XAML: üstte adım hapları + 34 pt komut + okut kutusu; ortada ✓/✗ 64 pt + 30 pt metin + ipucu; adet paneli (56 pt kutu,
    3×4 tuş takımı, hızlı tuşlar); tam alan terazi (72 pt ağırlık, sarı → yeşil, TAMAM — KAPAT, ETİKET BAS); tablo Detay'da;
    sağda tezgah şeridi; altta BU KOLİDE / SİPARİŞTE KALAN (44 pt) + YANLIŞ OKUTTUM / DETAY / KOLİ BİTTİ.
  - 42 yeni metin TR/EN/AR.
- **Testler:** `EkranRehberiTestleri` 11 + metin kapsama 29 (her komut/ipucu anahtarının çevirisi var); suite 123 geçti.
- **Doğrulanmadı:** ekran görsel olarak açılmadı (giriş şifresi gerekiyor); kullanıcı bakacak.

### 3. Ürün/paket etiketi: kodsuz, sağ etiket sağa — `89218f2`
- **Neden:** kullanıcı "paket ve ürün barkodlarında ürün kodunu kaldırıp…", ardından "sağ taraftaki sağa kayacak, sol taraftaki normal".
- **Ne yapıldı (`UrunEtiketi.cs`):** `UrunAdi(kod, ad)`: yalnız ad; ad kodla başlıyorsa kod ve ayraç kırpılır, ad boşsa kod.
  `SagEtiketKaydirmaMm = 1.5`: sağ sütun `sol + g + ara + 1,5`'ten başlar; sol sütun ve ^PW (736) aynı.
- **Testler:** 6 eski test yeni düzene göre güncellendi (kodsuz ad, sağ etiket ilk metin 400 nokta), 5 yeni; suite 128 geçti.
- Baskı denenmedi; kaydırma miktarı (1,5 mm) baskıya göre ayarlanabilir.

### 4. Koli darası 1,2 kg
- **Neden:** kullanıcı "teraziden net brüt arası 1.2 kg olacak, şimdilik böyle ayarla; biz brüt ölçüyoruz neti kendin al".
- **Ne yapıldı:** canlı SentezCore `UZM_Ayar` (CompanyId 2) `KoliDara` 1.1 → **1.2** (kullanıcı istedi):
  ```sql
  UPDATE dbo.UZM_Ayar SET Deger=N'1.2', UpdatedAt=GETDATE() WHERE CompanyId=2 AND Anahtar=N'KoliDara';
  ```
- Kod değişmedi: kapanışta Net = Brüt (terazi) − KoliDara (`PaketKurallari.Net`); ayar uygulamada 5 dk önbellekte, yeniden açılışta geçerli.

### 5. İş emri seçimi + iş emri bazlı tezgah, etiket listesi, UPC, PO, QR-only etiket — `c1de795`
- **Neden (kullanıcı):** "çıktıdaki alttaki barkodu kaldıralım; okuturken siparişe bağlı workorder seçelim; tezgahta hangi
  workorder'dan var onu da bilelim; başka work order'a okutamayalım". Ayrıca: "etiket listesi karton no ve sipariş no'ya göre
  listelenip yeniden basılabilmeli", "PO gelmemiş", "700083526670'ı bulamadı".
- **Ne yapıldı:**
  - **Şema** `db/0002_tezgah.sql` (henüz canlıda çalıştırılmadı, kullanıcı çalıştıracak): `UZM_TezgahHareket.WorkOrderId`
    (CREATE içinde + eski kuruluma ALTER), `UZM_PaketKoli.WorkOrderId`, `UZM_TezgahHareket_IX2 (CompanyId, WorkOrderId,
    InventoryVariantId, Kalite) INCLUDE (Miktar)`. `TezgahDeposu.KuruluMuAsync` artık bu iki kolonu da arar.
  - **Tezgah** (`TezgahDeposu.cs`): bakiye kovası = varyant + kalite + iş emri (null = iş emirsiz kova). Dökmede hareket box'ın
    `UZM_UretimBox.WorkOrderId`'siyle yazılır; `DuzeltAsync(..., workOrderId)`; `BakiyeListesi` iş emri no'su ile ayrı satır.
  - **Okutma** (`KoliDeposu.OkutAsync`): `KoliOturumu.WorkOrderId`. Siparişin `UZM_SiparisWorkOrder` kaydı varsa iş emri zorunlu
    (`IsEmriSec`); ürün yalnız seçilen iş emrinin sipariş kalemindeyse kabul (yoksa `BaskaIsEmri`); tezgah kontrolü/düşüm/iade o iş
    emrinden; yeni koli iş emrine bağlanır, açık koli başka iş emrindeyse `AcikKoliBaskaIsEmri`. `IsEmirleriAsync` = siparişin iş
    emirleri + tezgahtaki adet.
  - **Ekran:** başlıkta İŞ EMRİ açılır listesi (`IsEmriSecenegi`: no · model · tezgahta); tek iş emri varsa kendiliğinden seçilir,
    açık koli varken kilitli; seçilmemişse komut "① ÜSTTEN İŞ EMRİNİ SEÇ" (`EkranRehberi` `IsEmriBekliyor`). Tezgah şeridinde iş
    emri no; satır stokları seçili iş emrine göre. 9 yeni metin TR/EN/AR.
  - **Koli etiketi:** alttaki Code 128 kaldırıldı, koli yalnız QR; kod düz yazı kaldı (üstüne ayırıcı çizgi).
  - **Etiket listesi** (`KoliListe`): Sipariş no + Karton no filtreleri — verilince tarih aralığı yok sayılır; sayısal sipariş
    no'da baştaki sıfırlar önemsiz ("1" = "00000001"); Karton sütunu. "Etiketi tekrar yazdır" kapalı kolilerde (mevcut).
  - **UPC:** `PaketKurallari.BarkodAdaylari`: 12 hane → `[x, "0"+x]`, 13 hane 0'la başlıyorsa → `[x, x[1..]]`. Sentez
    `0700083526670` saklıyor, okuyucu `700083526670` gönderiyor. `OkutAsync` sorgusu `Barcode IN @adaylar` (tam eşleşme önce);
    VM satır eşlemesi `AyniBarkod`.
  - **PO:** başlık `CustomerOrderNo` boşsa koli kalemlerinin `Erp_OrderReceiptItem.CustomerOrderNo`'ları (STRING_AGG).
    Canlı kontrol: 00000001/00000002 siparişlerinde başlık, kalem ve iş emri PO'su **boş** — Sentez'de girilmemiş.
- **Testler:** yeni `KoliIsEmriTestleri` (7), `KoliEtiketiPoTestleri`, `KoliListeTestleri`, rehber/metin, barkod adayları.
  Test dünyası (`TestVerisi`) canlıda karma koli tanımı olan varyantları artık seçmez (canlıya tanım eklenince 28 test kırılmıştı).
  ```bash
  MODFEX_DB_TEST=1 dotnet test Paketleme.Tests   # 186/186 (rollback transaction)
  ```

## Kararlar
- İş emri koli başına tek; açık koli bitmeden iş emri değiştirilemez.
- Sipariş iş emrine dönmemişse (bağlantı yok) eski davranış: iş emirsiz kova.
- Box dökme her iş emrine açık (tezgah ortak), yalnız okutma seçilen iş emrine kısıtlı.

## Açık kalanlar
- `db/0002_tezgah.sql` canlıda çalıştırılmalı (iş emri kolonları dahil) — kullanıcı.
- PO'lar Sentez'de sipariş "Müşteri Sipariş No" alanına girilmeli.
- Set ürünün bileşenleri farklı iş emirlerinden geliyorsa tek iş emri kuralı engeller — gerekirse konuşulacak.
- Etiket basım loglaması (UZM_EtiketBaski) cevap bekliyor.

### 6. Koli etiketi yazı boyutları + yer/iletişim satırları — `25c7876`
- **Neden (kullanıcı):** "cari adı %75'e küçültelim, cari adresini %50, model de %75; mahalle, il, ülke de eklensin altına,
  telefon ve maili de ekleyelim". Ayrıca "PO gene gelmemiş"; "tek koli tek iş emri, karışık yok" (mevcut kural, değişiklik yok).
- **Ne yapıldı (`KoliEtiketi.cs`):** cari 4,5 → 3,375 mm (27 nokta), adres satırları 3,1 → 1,55 mm (12 nokta, 2,1 mm aralık,
  y=11'den), model 4 → 3 mm. Adres satırlarının altına `YerSatiri` (Neighborhood ya da Meta_Town.TownName, Meta_District,
  Meta_City, Meta_Country; boşlar atlanır) ve `IletisimSatiri` ("TEL {Phone} · {EMail}"). Adres sorgusu bu tablolara LEFT JOIN.
- **PO kontrolü (canlı, salt okunur):** 00000001'in tüm metin kolonları tarandı: başlık/kalem CustomerOrderNo boş, DocumentNo boş;
  tek dolu alan UD_Explanation, o da içi boş RTF. PO Sentez'de hâlâ girilmemiş.
- **Testler:** 3 yeni (boyutlar + satırlar, YerSatiri, IletisimSatiri); suite 193/193. Canlı adres sorgusu PK1-00000001-001 için
  "Çekmeköy, Istanbul, Türkiye" + telefon + e-posta döndürdü.

### 7. Koli üstünde iş emri + etiket düzeni ikinci tur — `936096d`
- **Neden (kullanıcı):** "box'ı oluştururken üstünde workOrderId olması lazım veya workOrderItemId"; "adres %50 büyütelim, posta
  kodunu ilçenin önüne alalım, matrisi biraz küçültelim, total quantity ve ağırlıkları biraz daha aşağıya alalım. PO gene gelmiyor".
- **Ne yapıldı:**
  - `KoliDeposu.OkutAsync`: yeni kolide `Erp_Box.WorkOrderId = seçili iş emri` (bant box'ları gibi). Kalem yazılırken iş emri kalemi
    (`Erp_WorkOrderItem` + `Erp_WorkOrderItemVariant`, `WorkOrderId` + `InventoryVariantId`) bulunursa
    `Erp_BoxItem.UD_WorkOrderItemId` ve `Erp_BoxItemVariant.UD_WorkOrderItemVariantId` dolar (bulunamazsa NULL).
  - `KoliEtiketi`: adres 1,55 → 2,325 mm (19 nokta), 2,9 mm aralık, y=10,6; adres satırı en çok 3 (posta kodu çıktı).
    `YerSatiri(mahalle, posta, ilçe, il, ülke)` → "Mahalle, 34782 Çekmeköy, İstanbul, Türkiye"; posta kodu `a.PostalCode`,
    boşsa `Meta_Town.PostalCode`. Matris 44,5–68 mm, satır en çok 4,5 mm, yazı 1,8–2,25 mm. TOTAL QTY y=78 (sayı 76,5),
    GW 77, NW 81.
- **PO (canlı, salt okunur):** şirket 2'de hiçbir satış siparişinde `CustomerOrderNo` dolu değil (başlık/kalem); iş emri ve iş emri
  kalemi `CustomerOrderNo` da boş; 00000001 en son 15:28'de güncellenmiş. PO Sentez'in bu alanlarına girilmiyor — kullanıcıya
  hangi alana yazdığı soruldu.
- **Testler:** `Koli_ve_kalemleri_is_emrini_tasir` (RED: null → GREEN), etiket boyut/konum testleri; suite 197/197.

### 8. Tezgah sıfırlandı (canlı, kullanıcı istedi) + bant box'larında iş emri kontrolü
- **Neden (kullanıcı):** "tüm bu tezgaha okutulmuşları iptal eder misin, tekrar okutalım; bant sonu kolilerinde workorder eklememiş
  miyiz, ona bakar mısın".
- **Durum:** `db/0002_tezgah.sql` kullanıcı tarafından canlıda çalıştırılmış (WorkOrderId kolonları dahil). Tezgahta 2 döküm —
  URT1-261013-001-0001 (70) ve -0002 (35), iş emri 71533 — ve PK1-00000001-001 için 2 paketleme hareketi (−6, −6). Hareketler
  WorkOrderId kolonu gelmeden önceki kodla yazıldığı için WorkOrderId NULL'dı.
- **Yapılan (tek transaction, `UZM_Tezgah` kilidiyle):**
  ```sql
  UPDATE dbo.UZM_TezgahHareket SET IsDeleted=1, DeletedAt=GETDATE(), DeletedBy=1,
         Sebep=ISNULL(Sebep, N'Kullanici istegi 13.10: tezgah sifirlandi, yeniden okutulacak')
  WHERE CompanyId=2 AND RecId IN (1,2,3,4);          -- 4 satır (soft delete, iz kalır)
  DELETE FROM dbo.UZM_TezgahBox WHERE CompanyId=2 AND RecId IN (1,2);   -- 2 satır; BoxId unique, box tekrar dökülebilsin
  ```
  Doğrulama: UZM_TezgahBox 0 satır, aktif bakiye 0, açık koli 0.
- **Bant box'larında iş emri:** var. Son 15 box'ta `UZM_UretimBox.WorkOrderId`, `Erp_Box.WorkOrderId` ve
  `Erp_BoxItem.UD_WorkOrderItemId` dolu (71533 = Test-005-2 → sipariş 00000001; 71531 = 4315-2 → sipariş 00000002).
  Eski sistemden kalan BoxType 1 box'ların çoğunda boş (13838'de 22 dolu) — onlar bantsayim öncesi.
- **Dokunulmayan:** kapalı test kolileri PK1-00000001-001 ve -002 (fiş 10/130 yazılmış: 733120/733121, WorkOrderId yok).

### 9. Dökümde iş emri görünür — `6770df7`
- **Neden (kullanıcı):** "tezgaha alırken work order'larını da alalım; bant sonunda work order açıkça çıkıyor".
- **Durum:** iş emri dökümde zaten `UZM_TezgahBox` + `UZM_TezgahHareket.WorkOrderId`'ye yazılıyordu (silinen 4 hareket eski sürümle
  yazıldığı için NULL'dı).
- **Ne yapıldı:** `TezgahDeposu.DokAsync` iş emrini `COALESCE(UZM_UretimBox.WorkOrderId, Erp_Box.WorkOrderId)` ile alır ve sonuç mesajı
  "Tezgaha alındı: {box} · {adet} adet · İş emri {no}" (TR/EN/AR).
- **Test kancası:** canlıda tezgah kurulduğu için eski 42-stok yolunu sınayan 13 test (KoliOkutma 5, KoliKapat 8) tezgah moduna
  düşüp kırıldı. `TezgahDeposu.TezgahsizBaglantilar` (ConditionalWeakTable<SqlConnection>) eklendi; `KoliOkutmaTestleri.HazirlaAsync`
  kendi bağlantısını ekler → yalnız o bağlantıda `KuruluMuAsync` false. Paralel testler etkilenmez.
- **Testler:** `Dokumde_is_emri_alinir_ve_gosterilir` (RED: IndexOutOfRange → GREEN); suite 198/198.

### 10. PK test kolileri silindi (canlı, kullanıcı istedi) + PO başa — `1568490`
- **Neden (kullanıcı):** "pk barkodlarını siler misin"; "PO başa alalım, OrderReceiptNo'yu sonraya alalım".
- **Ön kontrol (salt okunur):** PK1-00000001-001 (Box 313091, 6 set) ve -002 (Box 313388, 11 set), ikisi kapalı, mamul girişi yok.
  Fiş 10 #733120 (No 00000006, 42'ye 6+11) ve 130 #733121 (No 00000004, 42'den 12+22) yalnız bu iki kolinin kalemlerini içeriyordu.
  `Erp_InventoryReceiptItem(Variant)` Update/Delete trigger'ları IsDeleted'i işliyor (stok toplamı geri alınır).
  `Erp_Box_IX0` (CompanyId, BoxType, BoxCode) unique, filtresiz → koli kodunun yeniden kullanılabilmesi için box hard delete.
- **Yapılan (tek transaction, beklenmeyen kalem/koli varsa ROLLBACK):** betik `scratchpad/pk_sil.sql`:
  fiş varyant 6 + kalem 4 (BoxId=NULL) + fiş 2 → `IsDeleted=1, DeletedAt, DeletedBy=1` (soft, Sentez gibi);
  `UZM_PaketOkutma` 12, `UZM_PaketKoli` 2, `Erp_BoxItemVariant`/`Erp_BoxItem`/`Erp_BoxTotal`/`Erp_Box` 2 → DELETE.
  Doğrulama: PK box 0, UZM_PaketKoli 0, UZM_PaketOkutma 0, iki fiş IsDeleted=1. Yeni koli numarası 001'den başlar.
- **Etiket:** PO solda (x=5), ORDER (sipariş no) x=39'da. Test `Po_once_siparis_no_sonra` (RED → GREEN); suite 199/199.

### 11. Yeni PK kolisi silindi (canlı) + etikete iş emri no — `422cc1a`
- **Neden (kullanıcı):** "PK'ları silelim. PK oluştururken work order ya gelmemiş ya da etikete yazmamış".
- **Teşhis (salt okunur):** PK1-00000001-001 (Box 313587) `UZM_PaketKoli.WorkOrderId` ve `Erp_Box.WorkOrderId` = 71533 → iş emri **geliyor**;
  etikete basılmıyordu (alan yoktu). `UD_WorkOrderItemId` boş: koliye giren set (Inventory 87600) iş emrinde yok, iş emri
  bileşen ürününün (87601) — set varyantı iş emri kalemiyle birebir eşleşmez; başlıkta iş emri yeterli.
- **Silme (tek transaction, `scratchpad/pk_sil2.sql`, `UZM_Tezgah` kilidi):** fiş 735515/735516 kalem+varyant+başlık `IsDeleted=1`;
  koliye ait tezgah paketleme hareketleri (3 satır, Islem 2/4) `IsDeleted=1` → tezgaha iade (bakiye yine 105, iş emri 71533);
  UZM_PaketOkutma 2, UZM_PaketKoli 1, Erp_Box(+Item/Variant/Total) 1 DELETE. Mamul girişi olan koli varsa ROLLBACK koşulu.
- **Etiket:** üst satır PO (x5) · ORDER (x32) · WO (x56) · CARTON NO (x80, sağa); değerler 4 mm. `BilgiAsync`:
  `IsEmriNo = Erp_WorkOrder.WorkOrderNo` (`COALESCE(UZM_PaketKoli.WorkOrderId, Erp_Box.WorkOrderId)`).
- **Test düzeltmeleri:** `KoliIsEmriTestleri` artık canlıda aktif tezgah bakiyesi olan iş emrini seçmez (71533 105 adet tutuyordu);
  iki regex'te Python'un yazdığı gerçek satır sonu `\n` yapıldı. Suite 201/201.
