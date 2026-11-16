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

## Ek 2 (gece): tahsis, üretime ver 129, iade 29, karantina onayı 17/122

- **İstek:** "Deponun kesime kumaş vermesi ve iade almasını da mobilden yapmamız lazım. Hepsini yapalım, sırayla, ivedi."
- **Karar (benim, cevap gelmedi):** tahsis hep bütün seri, tek Order'ın tek ihtiyaç satırına; çıkış kısmi olabilir.
- **Tasarım / plan:** `docs/superpowers/specs/2026-11-17-tahsis-uretim-design.md`, `docs/superpowers/plans/2026-11-17-tahsis-uretim.md`.

### Veri katmanı (`MalKabul/Ekranlar/Veri/`)
- `TahsisDeposu.cs`: `Erp_InventoryAllocation` satırı (kaynak = serinin tip 1/16 giriş kalemi, `RequirementId`, `WorkOrderItemId`, `SerialCardId`, `InventoryReceiptSubType` = ihtiyaç tipi). Aktif tahsis = tipi 129/29 olmayan silinmemiş satır. Kaldırma: üretime verilmemişse `IsDeleted = 1`.
- `UretimDeposu.cs`: fiş 129 / 29 günlük tek fiş ('UZMUR'), kalemde `WorkOrderId` + `WorkOrderReceiptItemId`, seri hareketi ve tahsis tablosuna 129/29 satırı. Kısıtlar: başka Order'a tahsisli seri verilmez; tahsissiz seri bu Order'ın ihtiyacına otomatik tahsis edilir; 43'teki seri verilmez; depodakinden fazla verilmez; verilenden fazla iade alınmaz (serili ve serisiz).
- `KarantinaDeposu.cs`: 43'te bekleyenler (seri + serisiz). Onay = fiş 17 (43 → 1); red = fiş 122, sipariş satırına bağlı ve mal kabul fiyatıyla. Serisiz red en yeni irsaliyeden geriye dağıtılıyor, başlık toplamı yazılıyor.
- `FisYazimi.cs`: ortak `GunlukBaslikAsync` (cari dahil), `AnaBirimAsync`, `StokAsync`. Ayar: `HammaddeDepoId = 1`.

### Ekranlar
- **Terminal:** menüye "Üretime ver" ve "Üretimden iade al" eklendi (`UretimViewModel/View`, tek ekran, `iade` bayrağıyla). Akış: Order seç → seri ya da ürün barkodu okut → miktar önerisi → kaydet.
- **Windows:** "Karantina onayı" (`KarantinaViewModel/View`; red ikinci basışla) ve "Tahsis" (`TahsisViewModel/View`; Order → ihtiyaç → seri okut).

### Son inceleme (opus) ve düzeltmeler
- Serisiz iade sınırsızdı → 129 − 29 sınırı eklendi.
- Serisiz onay/red ekrandaki eski miktarla yazıyordu → kilit altında 43 stoğu yeniden okunuyor.
- Serisiz red tek kaleme yazılıyordu → kalemlere dağıtılıyor.
- 122 başlık toplamı yazılmıyordu → yazılıyor.
- Serisiz verme depo stoğuna bakmıyordu → bakıyor.
- 4 elemanlı tuple sınıfa çevrildi (Android trimming).
- Her biri için önce kırmızı, sonra yeşil test.

- **Sonuç:** 132/132 test (DB dahil, ROLLBACK). APK PM66'ya kuruldu; Windows zip yenilendi.
- **Commitler:** `c9a4a15`, `a980959`, `9237836`, `251c197`, `d933f5f`. Workflow dokümanı: Dokuman `81fee72`.

### Açık kalanlar
- Sahada ilk deneme: Order 4547 gibi gerçek bir Order'la tahsis → üretime ver → iade.
- Adım 8 raf yerleştirme, 11 pastal kontrolü, 14 pastal verimi raporu, 16–17 bantsayim kesilen adet kontrolü, 20 "42'de bekleyen" görünümü, Selvedge inspection raporu.
