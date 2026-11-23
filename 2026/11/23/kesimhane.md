# kesimhane — 2026-11-23

## Bağlam
- Kullanıcı: "Kesimhanede PDF yüklediğimiz alanda Sentez varyantlarını gireceğimiz yer gitmiş, ayrıca listede pastal bilgisi ve kumaş bilgisi gözükmüyor."
- Ardından: "Bir pastalda birden fazla kumaş olabilir, ona da bakman lazım."
- Teşhis: 22.11'deki "pastal Sentez'den" yeniden yazımında (`6d90acd`) eski `PastalFormView` silinmişti. Bu formda PDF'teki bedenler Sentez varyantlarıyla eşleşiyor ve kat başı adet giriliyordu. Yeni pastal girişinde yalnız pastal no, kat ve PDF kalmıştı.

## Yapılanlar

### 1. Sentez şeması incelendi (canlı, salt okuma)
- **Neden:** Varyant adetlerinin ve kumaşın Sentez'de nerede tutulacağını bulmak.
- **Komutlar:** Bağlantı `%LOCALAPPDATA%\Modfex\kesimhane\ayarlar.json`'dan okundu. Şifre DPAPI ile çözüldü (CurrentUser, entropi `"Modfex.Ortak.Ayarlar"`), ekrana basılmadı. Sorgular scratchpad'deki bir PowerShell betiğinden `sqlcmd` ile çalıştırıldı (`powershell -ExecutionPolicy Bypass -File q.ps1 a.sql`, Windows yolu ile).
- **Bulgular:**
  - `Erp_WorkOrderProductionVariant`: (`WorkOrderProductionId`, `InventoryId` = model, `WorkOrderItemVariantId`, `Quantity`). Proses 167'deki 1111 kaydın 1092'sinde var.
    - `p.Quantity` her kayıtta varyant toplamına eşit.
    - Tetikleyici yok, `RecId` IDENTITY.
    - Planlanan (tip 5) kayıtlarda order'daki bütün varyantların satırı mevcut.
  - Kumaş: `FabricId` ve `FabricCode` (nvarchar(100)) hiçbir kayıtta dolu değil. `FabricType` her kayıtta "Düz". `Erp_WorkOrderProductionItem` (seri kartı) boş.
  - Order kumaşları `Erp_Requirement.RequirementType = 1` (2 = aksesuar). Bir order kaleminde birden fazla kumaş var (ör. kalem 42987: KMS-0035, 0140, 0214, 0298).

### 2. Pastal girişi: varyant tablosu + çoklu kumaş (`9a04ec7`)
- **Karar (benim):** Kumaşlar `FabricCode` alanına virgülle ayrılmış kodlar olarak yazılıyor. DDL gerekmiyor, Sentez'de de görünüyor. Sınır 100 karakter (`KumasCokFazla`).
- **Ne yapıldı:**
  - `SentezKesimDeposu`:
    - `VaryantlarAsync(recId)`: order varyantları ile kayıttaki adet.
    - `KumaslarAsync`: order kumaş ihtiyaçları ve kayıtta yazılı kodlar.
    - `KumasKodlari`, `PastalDogrula(PastalGirdisi)`.
    - `PastalGirAsync(recId, PastalGirdisi)` tek transaction: MarkerNo, NumberOfPlies, FabricCode, varyant `Quantity` (UPDATE TOP 1, yoksa INSERT), sonra `p.Quantity = SUM(varyant)`.
    - Beden ya da kumaş değişirse onay düşer (`UD_CuttingApprove` NULL). Bekleyen pastal değiştirilemez.
  - `PastalGirdisi(MarkerNo, Kat, Kumaslar, Varyantlar?)`. `Varyantlar` null ise bedenlere dokunulmaz.
  - `PastalGirisViewModel` / `View`:
    - PDF'in altında kumaş onay kutuları var. Kayıtlı kodlar seçili açılır; seçim yoksa ve tek kumaş varsa o seçilir.
    - "Sentez varyantları" tablosu: renk·beden, order, Sentez'de, kat başı, kesilecek (kat başı × kat), fark.
    - Sentez'deki adetler kata tam bölünüyorsa kat başı bu adetlerden doldurulur.
    - Bütün kat başı alanları boşsa Sentez'deki adetler korunur. Birine bile kat başı girilirse boş bedenler 0 yazılır, en az bir beden > 0 olmalı (`BedenGerekli`).
  - Liste:
    - Yeni "Kumaş" sütunu. Pastala kumaş seçilmemişse order kumaşları soluk görünür, ipucu metni de var.
    - Model altında beden dağılımı (`BedenOzet`, ör. "70B 100 · 80B 100").
    - Arama FabricCode'da da yapılıyor.
  - Telegram olayı: açıklamaya "Kumaş …" ve "Bedenler …" satırları, `veri`ye `kumas` ve `bedenler` eklendi.
- **Dokunulan dosyalar:** `Kesimhane/Ekranlar/Veri/SentezKesimDeposu.cs`, `Veri/OnayMerkeziIstemcisi.cs`, `PastalGirisViewModel.cs`, `PastalGirisView.axaml`, `KesimListeView.axaml`, `KesimListeViewModel.cs`, `UygulamaMetinleri.cs`, `Kesimhane.Tests/SentezKesimTestleri.cs`, `EkranGoruntusuTestleri.cs`
- **Komutlar:**
  ```bash
  MODFEX_DB_TEST=1 dotnet test Kesimhane.Tests        # 37/37
  MODFEX_DB_TEST=1 MODFEX_TEST_CIKTI=<klasör> dotnet test Kesimhane.Tests --no-build --filter "FullyQualifiedName~EkranGoruntusu"
  ```
- **Sonuç / doğrulama:**
  - Yeni testler:
    - `Planlanan_kayda_beden_adetleri_ve_birden_fazla_kumas_yazilir`: canlıda, çok kumaşlı planlanan kayıtta ROLLBACK ile.
    - `Pastal_girdisi_dogrulanir`.
    - `Pastal_formu_kat_basini_sentez_adetlerinden_acar_ve_kesilecegi_hesaplar`.
    - `Olay_govdesi_kumaslari_ve_bedenleri_tasir`.
  - Headless render kontrol edildi. TEST01 pastal girişinde 2 kumaş kutusu ve 7 beden (kat başı 50 × 2 kat) görünüyor. Listede kumaş sütunu ve beden satırı var.
  - `dotnet build Kesimhane.Desktop`: kütüphane derlendi, ama açık `Kesimhane.Desktop` (pid 49344) dll'i kilitlediği için kopyalanamadı. Açık pencere eski sürüm.
- **Commit:** `9a04ec7` — Pastal girişi: Sentez varyantları (kat başı) ve birden fazla kumaş; listede kumaş + beden

## Kararlar
- Kumaş → `FabricCode` (kod listesi). `FabricId` tek değerlik olduğu için kullanılmadı.
- Beden adedi = kat başı × kat. Kat başı hiç girilmezse Sentez'deki planlanan adetler değişmez.

## Açık kalanlar / sonraki adım
- Kesimhane masaüstü kapatılıp yeniden derlenmeli ve dağıtılmalı.
- Liste 1440 px genişlikte beden satırını kısaltıyor (ipucunda tamamı görünüyor). Gerekirse sütun genişlikleri ayarlanacak.
- Malkabul kumaşı pastalın `FabricCode`'una göre sınırlamıyor; şu an yalnız onaya bakıyor. İstenirse eklenebilir.
