# sentezservis — 2026-11-18

## Bağlam
İstek: X şirketinin Y fatura tipindeki Z numaralı fişinin detayını kümülatif (ÜrünKodu, Adet, TL fiyat)
çıkarıp, başka bir şirkette seçilen fişle karşılaştıran ekran. Ek istek: faturada olmayan ve fazla olan
kalemler de görünsün.

## Yapılanlar

### 1. Fiş karşılaştırma ekranı (`/fis-karsilastirma`)
- **Neden:** Şirketler arası (01/03/04) aynı malın fişlerini kalem kalem elle karşılaştırmak yerine.
- **Ne yapıldı:**
  - Kalem yolu: `Erp_Invoice` → `Erp_InventoryReceipt (InvoiceId = i.RecId OR RecId = i.InventoryReceiptId)`
    → `Erp_InventoryReceiptItem` (IsDeleted=0). Kod: `Erp_Inventory.InventoryCode`, yoksa `Erp_Service.ServiceCode`.
  - Ürün koduna göre GROUP BY: `SUM(Quantity)` adet, `SUM(NetItemTotal)` tutar. NetItemTotal = KDV hariç,
    indirim düşülmüş TL; toplamı faturanın `SubTotal`'ına eşit (canlıda 04/121/00507172 ile doğrulandı:
    6 kalem → 1 kod, 2164,49 = SubTotal). `UnitPrice` VatIncluded=1 iken KDV dahil olduğu için kullanılmadı.
  - Birim fiyat = tutar / adet (ağırlıklı ortalama).
  - Fiş no `ReceiptNo`; rakamsa baştaki sıfır önemsiz (507172 = 00507172). Aynı numarada >1 fatura varsa
    hepsi toplanır, ekranda uyarı.
  - Karşılaştırma C#'ta tam dış birleştirme; durumlar: eşit / adet farklı / fiyat farklı (±0,01 TL) /
    adet ve fiyat farklı / "2. fişte yok" / "1. fişte yok". Fark kolonları 2 − 1 (işaretli).
  - Fatura tipi kutusu şirkette kullanılan `ReceiptType`'lar + fiş sayısı (ad tablosu Sentez'de yok;
    `ReceiptTypeMap` bizim stok devir tablomuz, eksik — kullanılmadı).
- **Dokunulan dosyalar:** `src/SentezServis.Core/Fatura/FisKarsilastirma.cs`, `FisKarsilastirmaDeposu.cs`,
  `src/SentezServis.Host/Api/FisKarsilastirmaUclari.cs`, `src/SentezServis.Host/Program.cs`,
  `web/src/api/fisKarsilastirma.ts`, `web/src/pages/FisKarsilastirmaSayfasi.tsx` (+ `.test.tsx`),
  `web/src/App.tsx`, `web/src/components/Layout.tsx` (Operasyon menüsü), `tests/.../FisKarsilastirmaTestleri.cs`
- **Uçlar:** `GET /api/fis-karsilastirma/tipler?sirketId=`,
  `GET /api/fis-karsilastirma/?aSirketId&aTip&aNo&bSirketId&bTip&bNo` (GirisIster, ERP salt okur).
- **Komutlar:**
  ```bash
  dotnet test tests/SentezServis.Core.Tests     # 797/797
  cd web && npx vitest run && npm run build      # 99/99
  ```
- **Sonuç / doğrulama:** SQL canlı ERP'de (192.168.1.3 SentezCore2026) sqlcmd ile denendi, ~3 sn. Ekran
  tarayıcıda canlı veriyle denenmedi.
- **Commit:** `e520156` — Fis karsilastirma ekrani: iki sirketin fisini urun kodu bazinda karsilastirir

### 2. KONS fiyat kontrolü ekranı (`/kons-fiyat`)
- **Neden:** 01/03/04'te barkodlu kartlarda KONS alış/satış fiyatı eksik veya farklı olanları bulmak.
- **Kullanıcı kararları:** üç kontrol de (eksik, alış≠satış, şirketler arası fark); evren = barkodlu tüm kartlar
  (silinmemiş, InUse); ürün seviyesi (varyant değil).
- **Veri:** Kartlar şirket başına ayrı (`Erp_Inventory.CompanyId`), şirketler arası eşleşme `InventoryCode`.
  Fiyat `Erp_InventoryPriceList` `PriceCode='KONS'`, `PriceType` 1=alış 2=satış; kart+tipte RecId en büyük
  satır. KONS fiyatları **USD** (`ForexId=1` → `Meta_Forex`); döviz de karşılaştırılır, kur çevrilmez.
  KDV dahil satır `VatRate` ile hariçe çevrilir. Aynı kart+tipte farklı fiyatlar → "birden çok KONS fiyatı".
- **Canlı sayılar:** 1.824 kod; alış yok 01:416, 03:245, 04:1.095; alış≠satış ~9/şirket. Sorgu ~1,5 sn.
- **Dosyalar:** `src/SentezServis.Core/Stok/KonsFiyatKontrolu.cs`, `KonsFiyatDeposu.cs`, `KonsFiyatExcel.cs`,
  `src/SentezServis.Host/Api/KonsFiyatUclari.cs`, `web/src/api/konsFiyat.ts`, `web/src/pages/KonsFiyatSayfasi.tsx`(+test)
- **Commit:** `576517e` — KONS fiyat kontrolu ekrani

### 3. Mahsup ön kontrol ekranı (`/mahsup-on-kontrol`) + "01 fişinde boş satır" teşhisi
- **Neden:** Kullanıcı: gece mahsup sorgusunu çalıştırıp 01'de olmayan barkodları görmek; 01 fişinde boş
  satırların sebebini bulmak.
- **Teşhis (`OBJECT_DEFINITION` ile okundu):** `UZM_MahsubBarcode` → `UZM_FindBarcode(2, @Barcode)`;
  barkod 01'de yoksa `@InventoryId` NULL kalır, yordam DURMAZ, 01 tip 120 fişe stoksuz kalem yazar. Fiyat
  `PriceType=1, IsPriceDiscount=1, ItemType=1, PriceCode=KONS` bulunamazsa fiyatsız kalem. Ana birim
  (`IsMainUnit=1`) yoksa UnitItemId NULL. Ayrıca `@Barcode nvarchar(25)` → uzun barkod kesilir.
- **Canlı:** Konsinye 01 fişleri (19 fiş, 7.652 kalem): 36 stoksuz, 757 fiyatsız; 04 hedef: 1.167 fiyatsız,
  03 hedef: 99 fiyatsız. Örn. 01 fiş 00006798 (15.11, Konsinye-46) stoksuz kalemler.
- **Ne yapıldı:** Aday taraması gece işinin kendi metodu (`MahsupDeposu.AdaylariGetirAsync`, kopya değil) ERP
  salt okur bağlantıda; her aday için 01 ve hedefte FindBarcode ölçütleriyle barkod/birim/fiyat kontrolü
  (STRING_SPLIT ile toplu). İkinci tablo: son N gün Konsinye-%/KonsinyeHR-% 120/1 fişlerinde stoksuz/fiyatsız kalemler.
- **Dosyalar:** `src/SentezServis.Core/Stok/MahsupOnKontrolu.cs`, `MahsupOnKontroluDeposu.cs`,
  `src/SentezServis.Host/Api/MahsupOnKontrolUclari.cs`, `web/src/api/mahsupOnKontrol.ts`,
  `web/src/pages/MahsupOnKontrolSayfasi.tsx`(+test)
- **Doğrulama:** .NET 817/817, UI 106/106; SQL'ler sqlcmd ile canlıda denendi. Ekran tarayıcıda denenmedi;
  aday taraması gece işi kadar sürer (dakikalar).
- **Commit:** `d3bf1de` — Mahsup on kontrol ekrani

## Kararlar
- TL fiyat = NetItemTotal (KDV hariç net). KDV dahil gerekirse ItemTotalVatIncluded'a geçilir.
- Kod eşleşmesi büyük/küçük harf + boşluk duyarsız.

## Açık kalanlar / sonraki adım
- Canlı paket + tarayıcıda gerçek iki fişle deneme.
- Yordama koruma önerisi: `UZM_MahsubBarcode` içinde FindBarcode sonrası `@InventoryId`/`@Price` NULL ise
  fiş kesmeden çık (ERP'de yordam değişikliği — kullanıcı onayı gerekir).
- KONS ekranı tüm KONS satırlarına bakıyor; FindBarcode yalnız `IsPriceDiscount=1, ItemType=1` olanları
  kullanıyor — gerekirse KONS ekranı aynı süzgece çekilebilir.
- Fiş karşılaştırmada eksik kalemleri karşı fişe aktarma isteği: ERP'ye YAZMA (B-10 istisnası), soru bekliyor.
