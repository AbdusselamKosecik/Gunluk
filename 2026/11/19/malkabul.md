# malkabul — 2026-11-19

## Bağlam
18.11'de terminal mal kabul siparişe göre, irsaliye no'suz (sipariş × gün = bir fiş) ve depo yerli hâle getirildi (`6177bbd`). Kullanıcı denemede her serinin ayrı fiş kalemi açtığını gördü.

## Yapılanlar

### 1. Mal kabul fişi kümülatif kalem
- **Neden:** Kullanıcı: "Her seri için yeni satır oluşturuyor. Aynı Inventory, aynı varyant, aynı fiyat, aynı orderReceiptId ise InventoryReceiptItem ve InventoryReceiptItemVariant alanlarını kümüle etmek lazım."
- **Ne yapıldı (`MalKabulFisDeposu.KalemYazAsync`):**
  - `KumuleKalemAsync`: fişte (UPDLOCK) aynı `OrderReceiptItemId` + `InventoryId` + `UnitId` + `UnitPrice` + `ISNULL(InWarehouseLocationId,0)` olan ve varyant durumu aynı (varyantsızsa hiç varyant satırı yok; varyantlıysa tek varyant satırı = bu varyant) kalem.
  - Varsa `KalemMiktariniGuncelleAsync`: yeni toplam miktarla `SeriKabulKurallari.Olcekle(sip, eski + yeni)` → Quantity, NetQuantity ve tüm tutar alanları (Vat/ItemTotal/Discounts/NetItemTotal + Forex) UPDATE; varyant satırı `Quantity += miktar`. Yoksa eskisi gibi yeni kalem + varyant.
  - Seri hareketi (`SeriHareketiEkleAsync`) her seri için ayrı, aynı kaleme (`ReceiptItemId`) bağlı.
  - **Benim eklediğim anahtar:** giriş yeri de anahtarda (kalemin tek `InWarehouseLocationId`'si var; farklı rafa okutulan seriler ayrı kalem). Kullanıcıya bildirildi.
  - `SiparisKalemleriAsync` (terminaldeki okutulanlar listesi): artık seri hareketi başına satır (miktar `st.Quantity`, yer `st` ya da kalem), kümülatif kalemde her seri ayrı görünür.
- **Doğrulama (canlı DB, ROLLBACK):** `Ayni_satirin_serileri_tek_kaleme_ve_varyanta_kumule_olur` — 10 + 15 → tek kalem 25 (NetQuantity 25, ItemTotal = sipariş ItemTotal × 25 / sipariş miktarı), tek varyant satırı 25, iki seri hareketi [10, 15] aynı kaleme; **Sentez tetikleyicileri UPDATE'i de topluyor**: Erp_InventoryTotal (43, stok, varyant) +25, Erp_OrderReceiptItem.ReceivedQuantity +25. `Farkli_depo_yeri_ayri_kalem` (41 'M', iki yer: [15, 15]). `Serisiz_ekleme_ayni_satira_kumule_olur` (10 + 5 → 15). `Fis_toplamlari` testi artık 1 kalem bekliyor. `UretimIncelemeTestleri.Serisiz_red_giris_kalemlerine_dagitilir...` → 3 + 7 tek giriş kalemi olduğu için red tek satır [10] (beklenti güncellendi).
- **Dokunulan dosyalar:** `MalKabul/Ekranlar/Veri/MalKabulFisDeposu.cs`, `MalKabul.Tests/MalKabulFisTestleri.cs`, `MalKabul.Tests/UretimTestleri.cs`
- **Komutlar:**
  ```bash
  MODFEX_DB_TEST=1 dotnet test MalKabul.Tests            # 190/190
  dotnet publish MalKabul.Android -c Release -o $TEMP/mk_apk && cp $TEMP/mk_apk/*Signed.apk dagitim/malkabul-2026-11-19.apk
  ```
- **Sonuç:** 190/190, ayarlar.json md5 değişmedi. APK derlendi; **PM66 adb'de görünmedi, yüklenmedi.**
- **Commit:** `3d11d49` — Mal kabul fisi kumulatif ...

## Kararlar
- Kümülatif anahtar: fiş + sipariş satırı + stok + birim + birim fiyat + giriş yeri + varyant.
- Eski (18.11 öncesi) fişlerde ayrı kalemler olduğu gibi kalır; yalnız yeni okutmalar kümüle olur.

## Açık kalanlar / sonraki adım
- APK'yı PM66'ya yükle (`dagitim/malkabul-2026-11-19.apk`).
- Sentez'de kümülatif fişi açıp kalem/varyant/seri görünümünü kullanıcıyla kontrol et.
- "Sipariş kapatarak irsaliye" yorumu (sipariş × gün) teyit; gerekirse "Kabulü bitir".

### Location Code.xlsx — 23 konteyner + Sentez depo/depo yeri planı
- **Neden:** Kullanıcı `C:\aaaa\Location Code.xlsx` dosyasındaki konteyner sayısını 23 yapmamı ve satırların Sentez'e depo / depo yeri olarak aktarılmasını planlamamı istedi.
- **Ne yapıldı:**
  - Dosyada 586 yer vardı: WI01, WS01, WH01 (Z01–Z04 raf/kat/göz + F00) ve CT01–CT13 (her biri Z05-IN / Z05-OUT).
  - CT14–CT23 eklendi; yeni dosya `C:\aaaa\Location Code - 23 konteyner.xlsx` (606 satır). Excel tablosunun aralığı A1:G607 yapıldı. Orijinal dosyaya dokunulmadı.
  - Sentez tabloları salt okunur incelendi:
    - Erp_Warehouse: RecId identity; (CompanyId, WarehouseCode) unique.
    - Erp_WarehouseLocation: RecId identity; (WarehouseId, LocationCode) unique; Corridor / Shelf / Division / ShelfCompartment / Barcode alanları var.
    - Mevcut depolar: 1, 2, 41 M (304 PA- yeri), 42 U, 43 K (1 yer: "01"), 44 01.
- **Plan önerisi:**
  - Excel'deki depo kolonu (A) → Erp_Warehouse; FollowUpWarehouseLocation = 1.
  - Kolon F → LocationCode, G → Explanation.
  - Zone → Corridor, Rack → Shelf, Level → Division, Pocket → ShelfCompartment; Barcode = kod.
  - Yükleme tek transaction'da, var olan koda dokunmadan yapılacak; önce geri alınarak denenecek.
- **Açık:** Kullanıcı kararı bekleniyor:
  - konteyner başına ayrı depo mu, tek konteyner deposu mu;
  - WH01 / WI01 mevcut 41 / 43'e mi eşlenecek;
  - WI00-Z01 / WS00-S01 kod tutarsızlıkları.
  - Sentez'e henüz yazılmadı.

### Sentez depo/yer aktarım betiği (kararlar alındı)
- **Kullanıcı kararları:**
  - konteynerler ayrı depo;
  - bugünkü depolara dokunulmayacak;
  - kod düzeltmeleri aynen yapılacak: WI00-Z01 → WI01-Z00, WS00-S01 → WS01-Z00, "Arena" → "Area".
- **Ne yapıldı:** `malkabul/sentez/depo-yerleri/` klasörü:
  - `Location Code.xlsx` (düzeltilmiş, 23 konteyner); `C:\aaaa\Location Code - 23 konteyner.xlsx` da güncellendi.
  - `uret.py`: Excel'den `depo-yerleri.sql` üretir.
  - `depo-yerleri.sql`:
    - tek transaction; `-- GOVDE BASLA / BIT` arası test için;
    - NOT EXISTS ile yalnız ekler; Excel sırasını korumak için Sira kolonu ve ORDER BY.
  - Depo: CompanyId 2, FollowUpWarehouseLocation 1, InsertedBy 1.
  - Yer: BarcodeType 1, Barcode = LocationCode, Zone / Rack / Level / Pocket → Corridor / Shelf / Division / ShelfCompartment.
  - `README.md`.
- **Önceden kontrol edildi:** Sentez'in UI'dan açtığı depo 44'te depo tablosu dışında yan kayıt yok; yalnız Erp_Warehouse + Erp_WarehouseLocation yeterli.
- **Test `DepoYeriAktarimTestleri`** (canlıda, ROLLBACK):
  - +26 depo, +606 yer;
  - mevcut depo ve yer imzası (CHECKSUM_AGG) değişmez;
  - WH01 558 yer, CT01–CT23 2'şer yer;
  - terminal `YerlerAsync` / `Eslesir` raf kodunu bulur;
  - ikinci çalıştırma bir şey eklemez.
- **Canlı veri kayması, test düzeltmesi:**
  - Bugün 10:48'de terminalden gerçek fiş 00000025 açılmış (10 kalem, eski APK). Fiş testleri bu fişi kullanıyordu. `MalKabulFisTestleri.AcAsync`, bugünkü UZMMK fişlerini transaction içinde düne alıyor.
  - Karantina 43'e 07:47'de "01" yeri eklenmiş. `DepoYeriTestleri` yersiz depo olarak artık 42'yi kullanıyor.
- **Sonuç:** 191/191; ayarlar.json md5 değişmedi.
- **Commit:** `08bd082`.
- **Açık:** Kalıcı yükleme için kullanıcı onayı bekleniyor; Sentez'e henüz yazılmadı.

### Kalıcı yükleme (kullanıcı onayı 16:07)
- **Nasıl:** `depo-yerleri.sql` tam haliyle (BEGIN TRAN / COMMIT dahil) çalıştırıldı.
  - Geçici bir xunit runner kullanıldı: `_Yukle.cs`, `MODFEX_DEPO_YUKLE=1`, bağlantı `Veritabani.AcAsync`. Runner çalıştırıldıktan sonra silindi, commit edilmedi.
- **Sonuç:**
  - Erp_Warehouse 6 → 32, Erp_WarehouseLocation 305 → 911.
  - Yeni depolar: WI01=175, WS01=176, WH01=177 (558 yer), CT01–CT23=178–200 (2'şer yer).
  - Hepsinde FollowUpWarehouseLocation=1. Eski depolar (1, 40–44) aynı.
- **Test:** `DepoYeriAktarimTestleri` yükleme sonrası duruma uyarlandı: beklenen ekleme = 26 − var olan, 606 − var olan. 191/191.
- **Commit:** son malkabul commit'i.
- **Not:** Sentez kullanıcı arayüzünde görünmüyorsa depo listesini yenilemek ya da yeniden giriş yapmak gerekebilir.
