# malkabul — 2026-11-17

## Bağlam
Seri tabanlı depo işlerinin 2.'si: hareket hâlinde depo sayımı. Kullanıcı: "16 numaralı fiş oluşturacağız, sıfır depo açıp sayımları
oraya girerek hareket hâlinde sayım"; sayım bitince eski depo 130 ile sıfırlanır ("aynen"); "hadi devam et bana sorma".

## Yapılanlar

### 1. Tasarım + plan
- `docs/superpowers/specs/2026-11-17-sayim-design.md`, `docs/superpowers/plans/2026-11-17-sayim.md` (commit `95b7f7e`).
- Canlı (salt okuma): sayım tablosu yok; stok = `Erp_InventoryTotal` tarih satırları toplamı (`SUM(ActualStock)`), NULL varyant satırı = varyant toplamı.

### 2. Uygulama (TDD, canlı ROLLBACK testleri)
- **Ayar:** `SayimDepoId` (0 = tanımsız), `MalKabulDepoId` Ayarlar ekranında. Etikette sipariş yerine "SAYIM" (`altMetin`). `3cb2806`
- **SayimDeposu:** okut (önce seri kodu → bulunduğu depodan fiş 17 ile sayım deposuna; sonra ürün barkodu → malzeme/varyant),
  yeni seri (kart `Explanation 'SAYIM yyyy-MM-dd'` + fiş 16 kalem + seri hareketi), serisiz ekle (fiş 16), bugünkü kalemler.
  Gün başına tek 16 / tek 17 (çıkış deposu başına), SpecialCode 'UZMSY', ana birim, fiyatsız. Fiş yazımı `FisYazimi`'ye ortaklaştı. `9823ed7`
  - Hata: sunucu GETDATE() gece yarısı farklı gün verdi → günlük başlık cihaz tarihiyle aranıyor.
- **Sayımı kapat (Windows):** depo seç → pozitif stok listesi → ikinci basışla tek fiş 130 (+ o depodaki serilerin seri hareketi). `d2f7f28`, `dae09c0`
- **Terminal:** açılış menüsü (Mal kabul / Sayım); sayım ekranı: okut, "Yeni seri / malzeme seç", varyant düğmeleri, miktar (+ adet, lot serili ise), sonuç kutusu, bugünkü liste. `5168e6f`
- **Sonuç:** 102/102 test (DB dahil). Gözden geçirme (opus): Important 1 — kapatmada seri stoğu kalıyordu → düzeltildi (`Kapatinca_depodaki_seriler_de_sifirlanir` RED→GREEN).
- **Dağıtım:** `dagitim/malkabul-2026-11-17.apk` PM66'ya kuruldu (açıldı, çökme yok), `dagitim/malkabul-masaustu-2026-11-17.zip`.

## Kararlar (benim; kullanıcı "sorma" dedi)
- Serili mal 16'ya değil 17 ile taşınır (çift sayım yok); mal kabulde okutulmamış seri sayımda reddedilir.
- Kapatmada yalnız pozitif stok; negatif dokunulmaz. Kilit sırası Fiş → Seri.

## Açık kalanlar / sonraki adım
- **Kullanıcı:** Sentez'de sayım deposunu açıp RecId'sini terminal ve Windows ayarına girmeli (Ayarlar → Sayım deposu).
- Ertelenen küçükler: tükenmiş seriye "zaten sayıldı" mesajı; eski varyantsız kartın 17'si varyantsız; silinmiş varyantlı barkodda takılma;
  kapat ekranında hızlı depo değişiminde liste karışabilir; barkod okumada da fiş kilidi alınıyor.
- Sonraki: 3 tahsisleme, 4 Selvedge inspection, 5 kesimhane seri okutma.

## Ek (gece, kullanıcı istekleri)

### Terminalde ayarlar düğmesi görünmüyordu
- **Neden:** 480 px ekranda üst bardaki üç dil düğmesi ⚙'yi ekran dışına itiyordu (adb screencap ile görüldü).
- **Ne yapıldı:** dar ekranda (Android) dil seçici tek düğme (TR → EN → ع), ayırıcı gizli. `KabukView.axaml`, `KabukViewModel.cs` (`DarEkran`, `DilDongu`).
- **Commit:** `48083d3`. Cihaz kilitli olduğu için yeni üst barın ekran görüntüsü alınamadı; kullanıcı kontrol edecek.

### 10 haneli seri + Excel "Seri no" + tekrar bas
- **İstek:** "Tekrar etiket bas butonu koyar mısın. Serileri de direkt 10 karakterli sıra numarasına göre oluşturur musun, Excel'den aktardıklarımız hariç."
- **Ne yapıldı:** `SonrakiSeriKodu` D10; MAX yalnız 10 haneli kodlardan (eski 8 haneliler sayılmaz, yeni sıra 0000000001'den başlar).
  Excel şablonuna isteğe bağlı 9. sütun "Seri no": doluysa o kod aynen (adet 1, dosyada tekil, Sentez'de yok — `SeriNoAdetBir/Tekrar/Var/Uzun`),
  sıra numarası ilerlemez. Sayım listesinde serili kalemde "Bas" düğmesi.
- **Sonuç:** 108/108 test (DB dahil). APK PM66'ya kuruldu; Windows zip yenilendi.
- **Commit:** `874aaf1`
