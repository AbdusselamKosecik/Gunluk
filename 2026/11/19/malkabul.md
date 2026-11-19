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
