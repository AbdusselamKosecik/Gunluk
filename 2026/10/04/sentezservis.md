# sentezservis — 2026-10-04

## Bağlam
Önceki gün PDKS giriş/çıkış maili bitmişti. Yeni hedef: **karma koli tanımlama** ekranı.
Kodu `-1`, `-2` … ile biten set mamullerinin (örn. `MSR-1008-2`) her renk-beden varyantının
hangi tekli ürün varyantlarından kaçar adet oluştuğunu tanımlamak. Şimdilik paketlemede,
sonra Sentez sorgu/raporlarında kullanılacak.

Kullanıcı kararları:
- Tablolar SentezCore içinde `UZM_` önekiyle (seçenek A).
- Tanım renk bazında yapılır, aynı bedenle diğer bedenlere kopyalanır; tek beden elle düzeltilebilir.
- Yalnızca şirket 2 (2025-MODFEX); diğer şirketlerin `InUse`'u kapalı.
- Uygulama: plan dosyası üzerinden inline (tek oturum), sonda bağımsız tam dal incelemesi.

## Yapılanlar

### 1. Spec ve plan
- **Ne yapıldı:** `docs/superpowers/specs/2026-10-03-karma-koli-design.md` (6e259c9, main),
  `docs/superpowers/plans/2026-10-04-karma-koli.md` (2626d87, main). Dal: `karma-koli`.

### 2. Çekirdek mantık (TDD) — f30291e, 3ba4dab
- **Dosyalar:** `src/SentezServis.Core/KarmaKoli/{KarmaKoliModelleri,PaketSayisi,KarmaKoliOnerici,KarmaKoliKopyalayici,KarmaKoliKurallari}.cs`,
  `tests/SentezServis.Core.Tests/KarmaKoliTestleri.cs`.
- **Kurallar:** set kodu `-\d{1,2}$`; ana mamul = son eki ve `MSR-` önekini at (`MSR-1008-2` → `1008`);
  set rengi `-` ile parçalanır (`SİYAH-BEYAZ` → SİYAH + BEYAZ), Türkçe harf duyarsız karşılaştırma;
  ürün adındaki "2'li / 3 LÜ" paket sayısı → içerik toplamı tutmazsa uyarı; bedeni olmayan
  (Variant2Id null) varyantlar birbiriyle eşleşir.

### 3. SentezCore bağlantısı, tablolar, depo — b1d6982
- `Ayarlar.cs`: `SentezCoreBaglantiCumlesi`, `SirketId = 2`. `BaglantiFabrikasi.SentezCoreAcAsync`.
- `db/sentezcore/karma-koli.sql` (idempotent): `UZM_KarmaKoli` (SetVariantId UNIQUE, ElleDuzenlendi,
  Olusturan/Zaman, Guncelleyen/Zaman) ve `UZM_KarmaKoliIcerik` (FK cascade, Miktar ≥ 1, UNIQUE).
- `KarmaKoliDeposu.cs`: okuma Erp_Inventory / Erp_InventoryVariant / Erp_VariantItem (aktif: IsDeleted=0, InUse=1, CompanyId=2);
  yazma yalnızca UZM tablolarına (UPDLOCK,HOLDLOCK). İyimser kilit: sürüm = COALESCE(GuncellemeZamani, OlusturmaZamani), tutmazsa 409.
  Boş içerik kaydı tanımı siler. Yazma sınırı testi: `SentezCoreAcAsync` yalnızca depoda çağrılır.

### 4. API uçları — b1887ee
- `src/SentezServis.Host/Api/KarmaKoliUclari.cs`: `/api/karma-koli/{durum,setler,setler/{id},setler/{id}/oneri,mamuller,mamuller/{id}/varyantlar}`,
  `PUT /varyantlar/{setVariantId}`, `POST /setler/{id}/renkler/{renkId}/uygula`. Yazma `mudahaleEden/yonetici`, denetim kaydı.
  Bağlantı/tablo yoksa 503 `KULLANILAMAZ`.
- Arama `COLLATE Turkish_CI_AS` (SentezCore Turkish_CS_AS, "racerback" boş dönüyordu).

### 5. Web ekranı — 4d230cc
- `web/src/pages/KarmaKoliSayfasi.tsx`, `web/src/api/karmaKoli.ts`, `web/src/utils/karmaKoli.ts` (+test), menü Operasyon → Karma koli, `theme.css`.
- Sol: set listesi (tanımlı/toplam). Sağ: renk × beden matrisi; renk adı → renk tanımı (öneri, tüm bedenlere uygula);
  hücre → tek beden (✎ elle düzenlendi, toplu uygulamada atlanır); `!` = bileşende o beden yok.

### 6. Doküman — fde60fd
- `docs/karma-koli.md` (kurulum, kullanım, rapor SQL örneği), `docs/api-kontrat.md` "Karma koli" bölümü.

### 7. Bağımsız dal incelemesi ve düzeltmeler — 5e6b99c
- **Neden:** Plan sonunda yeni bağlamla tam dal incelemesi (opus alt ajan). Sonuç: 0 kritik, 4 önemli, 7 küçük.
- **Düzeltilenler (TDD + uçtan uca):**
  - Tek beden kaydında başka şirketin ya da silinmiş/kullanımda olmayan mamulün varyantı kabul ediliyordu →
    `MamullerAsync/VaryantlarAsync(..., sadeceAktif: true)` doğrulamada; `Dogrula` kodu null olan bileşeni reddeder.
    Test `Kurallar_sirket_disi_veya_aktif_olmayan_mamulun_varyantini_reddeder`; E2E: pasif `2633` → 400.
  - "Tüm bedenlere uygula" bileşende olmayan bedende eski tanımı bırakıyordu (✓ görünüyordu) →
    `KopyalamaSonucu.Yazilacaklar` bu bedenlere boş içerik yazar (= siler). Test
    `Bedeni_olmayan_set_varyantinin_eski_tanimi_silinmek_uzere_yazilir`; E2E: AKS-0551 (yalnız 36-42) uygulanınca 34/44/46 silindi.
- **Ertelenen küçükler:** miktar üst sınırı yok; renksiz satırda genel 400; uygulamada sürüm kontrolü yok;
  React'te hızlı set değiştirmede sıra dışı yanıt ve 409 sonrası tazeleme yok; her istekte durum sorgusu.
- **Sonuç:** `dotnet test` 239/239, Host build temiz.

### 8. Yayın paketi, main'e birleştirme, canlı kurulum hazırlığı
- **Neden:** Kullanıcı paket istedi; ardından "main'e birleştir, karma koli SQL'ini çalıştır,
  appsettings'i çalışacak şekilde ayarla — paketi ben yükleyeceğim, ayarı ayrıca hazırla".
- **Paket:**
  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File deploy\yayinla.ps1
  Compress-Archive -Path yayin\* -DestinationPath SentezServis-2026-10-04-0441.zip
  Compress-Archive -Path db\sentezcore\karma-koli.sql -Update -DestinationPath SentezServis-2026-10-04-0441.zip
  git checkout -- src/SentezServis.Host/wwwroot/.gitkeep   # vite build siliyor
  ```
  73,3 MB, 18 dosya, içinde appsettings.json yok. Arayüz tarihi 2026-10-04 04:41.
- **Birleştirme:** `git merge --no-ff karma-koli` → main `42b2506`, push edildi.
- **Canlı SentezCore:** `sqlcmd -S 100.119.104.122 -U uzman -d SentezCore -C -b -i db/sentezcore/karma-koli.sql`
  → `UZM_KarmaKoli`, `UZM_KarmaKoliIcerik` oluştu; `MSR-1008-2` 50 varyant, 0 tanım.
- **Bulgu:** Modfex SQL'de SentezServis'in kendi DB'si yoktu (yalnızca SentezCore, zkbiotime, zkbiotime1).
  Uygulama DB oluşturmaz, yalnızca migrasyon uygular → `CREATE DATABASE SentezServis` +
  `ALTER DATABASE SentezServis COLLATE Turkish_CI_AS` (boş). PDKS verisi `zkbiotime`'da (son kayıt 01.10.2026),
  `zkbiotime1` eski (2025-11).
- **appsettings:** depo dışında `X:\Gitlab\modfex-apparel\SentezServis-Modfex-kurulum\appsettings.json`
  (paket de aynı klasörde). Sırlar içerdiği için git'e girmez. İçerik: Kestrel `http://0.0.0.0:81`;
  `BaglantiCumlesi` / `SentezCoreBaglantiCumlesi` / `PdksBaglantiCumlesi` → `Server=localhost`, `uzman`
  (PDKS ReadOnly); `SirketId` 2; `FirmaAdi` Modfex; `TabanAdres` `http://192.168.0.2:81`;
  Eposta = Modasima'nın SMTP'si (mail.kurumsaleposta.com:465, noreply@modasima.com.tr,
  GonderenAdi "Modfex SentezServis", Alicilar bt@modasima.com.tr); Kasa ve Toplayıcı kapalı;
  SaatDilimi boş (sunucu yerel saati).
- **Kurulum (kullanıcı yapacak):** zip'i sunucuda aç, appsettings.json'ı yanına koy, yönetici olarak
  `servis-kur.cmd "D:\UzmanAdres\SentezServis" 81`. İlk açılışta `yonetici` için tek kullanımlık parola
  Windows Olay Görüntüleyicisi → Uygulama (kaynak SentezServis) uyarısında. Doğrulama `http://192.168.0.2:81/api/surum`.

### 9. Yönetici zamanlama ekranında kilitliydi — 6acdbd5
- **Neden:** Kullanıcı kurup `yonetici` ile girdi; görevlerde mail alıcısı/zaman değiştirme ve diğer
  işlemler yoktu ("Modasima'daki gibi yap").
- **Kök neden:** Sayfalar `rol === 'mudahaleEden'` diye tam eşitlik arıyordu; sunucu yöneticiye izin
  veriyor ama düğmeler (cron, aç/kapat, Şimdi çalıştır, Parametreler) render edilmiyordu. Modasima'da
  18.09.2026'da `83a5ec2` + `09e8945` ile düzeltilmiş, Modfex'e taşınmamıştı.
- **Ne yapıldı:** `web/tests/yetki.test.ts` Modasima'dan alındı (`tsconfig.node.json` include'a `tests/**/*.ts`),
  RED: 5 dosya (CalistirmaDetay, IsListesi, KarmaKoli, Kaynaklar, Zamanlama). `AuthContext.tsx`
  Modasima'dakiyle aynı (`mudahaleEdebilir = mudahaleEden || yonetici`); sayfalar `useAuth().mudahaleEdebilir`.
- **Sonuç:** web 48/48, `tsc -b` ve lint temiz. Yeni paket
  `SentezServis-Modfex-kurulum\SentezServis-2026-10-04-0507.zip` (arayüz 2026-10-04 05:06).
- **Not:** Kullanıcı ayrıca `SentezService` adlı boş bir DB açtı (05:07); çalışan servis `SentezServis`'i
  kullanıyor (58 tablo, yönetici hesabı orada). Hangisinin kalacağı kullanıcıya soruldu.

## Yerel test kurulumu (tekrar üretmek için)
- LocalDB `SentezServisDeneme` (uygulama DB) + `SentezCoreDeneme`: canlıdan şirket 2 Erp alt kümesi
  (4168 mamul, 131.335 varyant, 1813 varyant öğesi) SqlBulkCopy ile. **DB collation Turkish_CS_AS olmalı**
  (yoksa bulk copy collation hatası verir). Sonra `db/sentezcore/karma-koli.sql` çalıştırılır.
- Host `http://localhost:8563` (launchSettings), uçtan uca betik 16 kontrol: hepsi OK. Tarayıcıda
  `MSR-1008-2` LACİVERT-BEYAZ → 1008 LACİVERT + BEYAZ önerisi, 7 bedene uygulandı, 48/43/Standart `!`.
- **Doğrulama:** `dotnet test` 237/237, web `npm test` 45/45, build ve lint temiz.

## Kararlar
- Host için otomatik test projesi yok; uçlar uçtan uca betikle doğrulandı.
- `!` işareti kalıcı değil (yalnızca son uygulamadan sonra istemcide).
- Canlı SentezCore'da tablo kurulumu kullanıcı onayına bırakıldı.

## Açık kalanlar / sonraki adım
- Sunucu appsettings: `SentezCoreBaglantiCumlesi` (ve önceki günden `PdksBaglantiCumlesi`, Eposta).
- Sunucuya kurulum (kullanıcı yapacak), ardından Zamanlama ekranında PDKS alıcıları.
- Not: listede set olmayan ama kodu `-rakam` ile biten mamuller de görünüyor (AKS-01, E-ASKI-2 …); kural gereği.
