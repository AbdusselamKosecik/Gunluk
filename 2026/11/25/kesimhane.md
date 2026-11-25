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
