# kesimhane — 2026-11-25

## Bağlam
Kullanıcı kesim ekranını açtırdı; "Birden fazla pastal girebiliriz. Sonradan da girebiliriz." Bugüne kadar her Sentez kesim kaydına (Erp_WorkOrderProduction, proses 167) tek pastal (MarkerNo, NumberOfPlies, FabricCode) giriliyordu.

## Yapılanlar

### 1. Pastal ekle — her yeni pastal yeni Sentez kesim kaydı
- **Neden:** Sentez kesim kaydı tek pastal tutuyor; bir order kaleminin zaten birden çok kesim kaydı olabiliyor (canlıda bir kalemde 15). Kullanıcıya iki seçenek soruldu (yeni Sentez kaydı / UZM_Pastal altında liste) → **yeni Sentez kesim kaydı** seçildi: her pastalın kendi Telegram onayı olur, malkabul kumaşı pastal pastal verir, Sentez'de görünür.
- **Ne yapıldı:**
  - `SentezKesimDeposu.YeniPastalGirAsync(kaynakRecId, PastalGirdisi)`: serializable transaction; önce doğrulama (PastalDogrula + bedenler zorunlu → "BedenGerekli"), sonra kaynak kayıttan INSERT…SELECT (WorkOrderId, WorkOrderItemId(s), InventoryId, ProductionSubType, InOut, SourceType, Cutter, FabricType, Explanation1; ProductionType 5, ProcessId 167, Quantity 0, NumberOfPlies 1, marker sayıları 0, StartProductionDate bugün, StartProductionTime 1899-12-30+saat), `DocumentNo` = planlanan (tip 5) kayıtların MAX(TRY_CAST bigint)+1, 8 hane sıfırlı (UPDLOCK, HOLDLOCK). Sonra mevcut `PastalGirAsync` ile pastal no/kat/kumaş/bedenler yeni kayda yazılır. Hata olursa commit yok → boş kayıt kalmaz.
  - `PastalGirisViewModel.YeniPastal(kaynak, gonderici)`: aynı form boş açılır (pastal no, kat, kat başı boş; kaynağın Sentez adetleri alınmaz; kumaş seçimi kaynaktan önerilir; PDF kaynağınki gösterilmez; başlık "Pastal ekle"). İlk kayıttan sonra form oluşan kaydı düzenler (ikinci Kaydet yeni kayıt açmaz). PDF yeni kaydın klasörüne (`pastal/{order}/{yeniRecId}`) yazılır; "Kaydet ve gönder" yeni kaydı onaya gönderir.
  - Liste: pastalı girilmiş satırda (onaylı/beklemede dahil) "Pastal ekle" butonu (`KesimSatiri.PastalEklenebilir`, `PastalEkleCommand`); işlem sütunu 380→400 px. Metin `PastalEkle` (TR/EN/AR).
- **Dokunulan dosyalar:** `Kesimhane/Ekranlar/Veri/SentezKesimDeposu.cs`, `Kesimhane/Ekranlar/PastalGirisViewModel.cs`, `Kesimhane/Ekranlar/KesimListeViewModel.cs`, `Kesimhane/Ekranlar/KesimListeView.axaml`, `Kesimhane/Ekranlar/UygulamaMetinleri.cs`, `Kesimhane.Tests/SentezKesimTestleri.cs`
- **Testler (önce kırmızı, sonra yeşil):** `Yeni_pastal_ayni_order_kalemine_yeni_kesim_kaydi_acar` (DbFact, ROLLBACK: bedensiz giriş kayıt açmaz; yeni kayıt aynı kalem, tip 5, DocumentNo sıradaki, onay boş, listede P-YENI/10 kat/30 adet; kaynak değişmez), `Yeni_pastal_formu_bos_acilir_kaynagin_adetlerini_almaz`, `Yeni_pastalda_kat_basi_zorunlu`.
- **Komutlar:**
  ```bash
  MODFEX_DB_TEST=1 dotnet test Kesimhane.Tests          # 40/40
  MODFEX_DB_TEST=1 MODFEX_TEST_CIKTI=<klasör> dotnet test Kesimhane.Tests --filter Kesimhane_ekranlari_render_edilir
  ```
- **Sonuç / doğrulama:** 40/40 geçti; liste ekran görüntüsünde "Pastal ekle" pastallı satırlarda görünüyor. Uygulama yeniden başlatıldı.
- **Commit:** `9756733` — Pastal ekle: aynı order kalemine yeni Sentez kesim kaydı (birden fazla pastal, sonradan da)

## Kararlar
- Pastalı henüz girilmemiş satırda "Pastal ekle" yok (önce o satıra "Pastal gir").
- Sentez probları: planlanan kayıt DocumentNo'ları 00000001–00000025 benzersiz sıralı; kesilen (tip 1) kayıtlarda DocumentNo dağınık/boş.

## Açık kalanlar / sonraki adım
- Kullanıcı canlıda bir pastal ekleyip Sentez'de yeni kesim kaydını kontrol etmeli.
- İstenirse: pastal formunda order adedine karşı diğer pastallarda zaten girilen adetler (kalan) gösterilebilir.

### 2. Pastal girişinde Kesilen / Kalan; fark kalana göre
- **Neden:** Kullanıcı: "100 kesilecekten kesilen miktarı düşmek gerekir" — birden fazla pastalda her pastal order'ın tamamına göre fark gösteriyordu.
- **Karar (Sentez probu):** Kesilen (tip 1) ile planlanan (tip 5) kayıtlar arasında bağ yok (ParentProductionId hep boş). Kural: beden bazında **Kalan = Order − aynı order kalemindeki diğer kesim kayıtları**; sayılanlar: kesilen kayıtların hepsi + pastalı (MarkerNo dolu) planlananlar. Pastalsız planlanan yalnız plan, sayılmaz. Kalan eksiye düşmez.
- **Ne yapıldı:**
  - `KesimVaryant.DigerKesilen`; `VaryantlarAsync` sorgusuna ikinci OUTER APPLY (Erp_WorkOrderProductionVariant ⨝ Erp_WorkOrderProduction, `op.RecId <> p.RecId`, proses 167, silinmemiş, tip 1 veya pastallı tip 5).
  - `VaryantSatiri.Kesilen / Kalan / KalanSayi`; `FarkMetni`/`FarkVar` artık kesilecek − kalan. Yeni pastal modunda kaynak pastalın adedi de kesilene eklenir.
  - `PastalGirisView.axaml`: sütunlar Order | Kesilen | Kalan | Sentez'de | Kat başı | Kesilecek | Fark; başlıkta toplam Kesilen ve Kalan. Metinler `KesilenAdet`, `Kalan`, `KesilenIpucu`.
- **Dokunulan dosyalar:** `Kesimhane/Ekranlar/Veri/SentezKesimDeposu.cs`, `Kesimhane/Ekranlar/PastalGirisViewModel.cs`, `Kesimhane/Ekranlar/PastalGirisView.axaml`, `Kesimhane/Ekranlar/UygulamaMetinleri.cs`, `Kesimhane.Tests/SentezKesimTestleri.cs`
- **Testler:** `Kalan_orderdan_diger_kesimler_dusulerek_hesaplanir`, `Yeni_pastalda_kaynak_pastal_da_kesilenden_sayilir`, `Kalan_eksiye_dusmez`; DB testinde yeni pastalın 30 adedi kaynağın `DigerKesilen`ine eklenir. `MODFEX_DB_TEST=1 dotnet test Kesimhane.Tests` → 43/43. Ekran görüntüsünde TEST01: order 100, kesilen 100, kalan 0, fark +20.
- **Commit:** `bed6857` — Pastal girişi: kesilen ve kalan sütunları; fark kalana göre

## Açık kalanlar (güncel)
- Canlıda pastal ekle + kalan kontrolü kullanıcıda.
- Kesilen tanımı (pastalsız planlananlar sayılmıyor) kullanıcıyla teyit edilebilir.

### 3. Pastal girişi Sentez kesim kartı gibi: pastal (Fabric/Desen), renk bazlı giriş, kesilecek %fazla
- **Neden:** Kullanıcı Sentez ekran görüntülerini verdi (`C:\aaaa\a`: Order formu dağılım/kesilecek, model kartı pastal/kumaş, kesim kartı Fabric/Desen) — "pastal seçimi var Sentez'de, TEST-001 üzerinden gidelim; pastal bazlı kesilecek kumaş belirleniyor; renk bazlı kesebiliriz". Cevap: "pastal birden fazla renk olabilir ama tek tek girsin, Sentez'deki gibi".
- **Sentez şeması (canlı TEST01 probları, `sqldene/test01..04.cs`):**
  - Model kartı Pastal sekmesi = `Erp_Inventory.Markers1..10` (TEST-001: 1 Fabric, 2 Desen).
  - Model kartı Kumaş sekmesi = `Erp_RecipeItem` (`OwnerInventoryId` = model, `RecipeType 1`, `ItemType 1`), `GroupNo` = pastal sırası; `Variant1 = '#;@2'` renk bazlı kumaş; `MarkerWidth/MarkerPieces/MarkerM2Gram`.
  - Kesim kaydının pastalı = `Erp_WorkOrderProduction.ProductionSubType` (1 Fabric, 2 Desen). Kesim kartındaki Fabric/Desen seçici bu.
  - Kesilecek % = `Erp_WorkOrder.CuttingExtra` (TEST01: 5), varyantta `Erp_WorkOrderItemVariant.CuttingExtra` (0 = order'ınki).
  - Kesim kartı "Kesim" = yalnız kesilen (tip 1) kayıtlar, pastal bazlı; planlananlar sayılmaz. Her kesim kaydı tek renk.
- **Ne yapıldı:**
  - Depo: `SentezKesim.ModelId / PastalTuru / PastalAdi` (liste sorgusunda CASE ile Markers adı; renk önce kaydın kendi renkleri), `KesimVaryant.Hedef` = CEILING(order × (100 + extra)/100), `DigerKesimlerAsync(recId)` → (varyant, pastal türü, Kesilen = tip 1, Planlanan = pastallı tip 5), `PastallarAsync(modelId)` (Markers + reçete kumaşları), `PastalGirdisi.PastalTuru` → `ProductionSubType` (PastalGirAsync + YeniPastalGirAsync), kumaş seçeneklerine reçete kumaşları eklendi.
  - Form: pastal ComboBox (seçilince o pastalın reçete kumaşları işaretlenir), renk ComboBox (yalnız o rengin bedenleri; girdi yalnız seçili renk → kayıttaki diğer renkler 0'lanır), eski çok renkli kayıtta uyarı. Sütunlar: Order | Kesilecek(+%) | Kesilen | Planlanan | Kalan | Sentez'de | Kat başı | Bu pastal | Fark (bu pastal − kalan). Yeni pastalda kaynak kaydın adetleri kendi pastalının kesilen/planlananına eklenir.
  - Liste: pastal sütunu "Fabric · 1"; Telegram açıklaması "Pastal Desen 1 · Kat …".
- **Dokunulan dosyalar:** `Kesimhane/Ekranlar/Veri/SentezKesimDeposu.cs`, `Kesimhane/Ekranlar/Veri/OnayMerkeziIstemcisi.cs`, `Kesimhane/Ekranlar/PastalGirisViewModel.cs`, `Kesimhane/Ekranlar/PastalGirisView.axaml`, `Kesimhane/Ekranlar/KesimListeViewModel.cs`, `Kesimhane/Ekranlar/KesimListeView.axaml`, `Kesimhane/Ekranlar/UygulamaMetinleri.cs`, `Kesimhane.Tests/SentezKesimTestleri.cs`, `Kesimhane.Tests/EkranGoruntusuTestleri.cs`
- **Testler:** `Kalan_secili_pastalin_kesilen_ve_planlananlari_dusulerek_hesaplanir`, `Kalan_eksiye_dusmez_ve_hedef_yoksa_order_kullanilir`, `Pastal_secimi_pastalin_kumaslarini_secer_ve_girdiye_yazar`, `Renk_secilir_yalniz_o_rengin_bedenleri_girilir`, `Birden_fazla_renkli_eski_kayit_uyarilir`, `Yeni_pastalda_kaynak_kesim_kendi_pastalinin_kesilenine_sayilir`, `Model_kartinin_pastallari_okunur` (DbFact); yeni pastal DB testi pastal türü 2 ve DigerKesimler ile. `MODFEX_DB_TEST=1 dotnet test Kesimhane.Tests` → 47/47. Render: TEST01 Desen·2 → kesilecek 105, kesilen 80, kalan 25 (Sentez kesim kartıyla aynı).
- **Commit:** `534ddba` — Pastal girişi Sentez kesim kartı gibi: pastal (Fabric/Desen) seçimi, renk bazlı giriş, kesilecek %fazla

## Kararlar (3)
- Planlanan (pastallı, henüz kesilmemiş) pastallar ayrı "Planlanan" sütununda ve Kalan'dan düşülür (Sentez "Kesim"e saymıyor; biz ayrı gösteriyoruz).
- Kesilecek yuvarlama CEILING (Sentez'in yuvarlaması doğrulanmadı; TEST01'de tam sayı).

## Açık kalanlar (güncel)
- TEST01 planlanan Fabric kaydı (195041) FabricCode = T-KMS-002 ama reçetede Fabric'in kumaşı T-KMS-0120 — o kayıt yeni kuraldan önce girildi; kullanıcı düzeltebilir.
- Kesilecek yuvarlamasını küsuratlı bir order'da Sentez'le karşılaştır.
