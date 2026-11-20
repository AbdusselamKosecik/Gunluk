# malkabul — 2026-11-21

## Bağlam
Gece 20.11'den devam. İstek: Tahsis ekranında siparişi olmayan ihtiyaçlara alım siparişi açılsın. Siparişler Sentez'in tahsisine bağlansın, karantina onayında seriler otomatik tahsis edilsin.

## Yapılanlar

### 1. Eksiklere alım siparişi + ihtiyaca bağlama
- **Kararlar (kullanıcı):**
  - Yer: Tahsis ekranı; düğme seçili order için çalışır.
  - Kapsam: eksik = ihtiyaç − siparişe bağlı.
  - Gruplama: tedarikçi başına bir sipariş, satır = ihtiyaç; order no satır açıklamasına ve `UD_OrderAraligi`'ya yazılır.
  - Tedarikçi stok kartının carisinden (`Erp_Inventory.CurrentAccountId`); boşsa 320.99.999 (RecId 625440). Kart carisi şu an 4197 kartın yalnız 26'sında dolu.
  - Fiyat 0, sipariş başlığı deposu WI01.
  - Tedarikçinin bu order'a bağlı, hareket görmemiş siparişi varsa "mevcuta ekle?" diye sorulur (onay kutusu, varsayılan işaretli).
- **Sentez yazımı:**
  - `Erp_OrderReceipt`: tip 1, UpType 2, ReceiptNo = MAX+1 (8 hane), SpecialCode `UZMTD`.
  - `Erp_OrderReceiptItem`, renk varsa `Erp_OrderReceiptItemVariant`.
  - `Erp_InventoryAllocation` (OrderReceiptType 1, OrderReceiptItemId, RequirementId, WorkOrderItemId).
  - Stok sipariş toplamlarını Sentez tetikleyicileri günceller.
- **Karantina onayı (fiş 17):** Seri, geldiği sipariş satırına bağlı ihtiyaca otomatik tahsis edilir (`TahsisDeposu.OtomatikTahsisAsync`).
- **Ekstra kuralı (`TahsisKurali.Ekstra`):**
  - Ekstra = ihtiyaç zaten dolu, ya da aksesuarda ihtiyacı aşıyor. Kumaşta son top ihtiyacı aşabilir.
  - Ekstra seri otomatik tahsis edilmez.
  - Elle tahsiste `EkstraSeriOnay` hatası döner; ekranda "Evet, tahsis et" onay çubuğu çıkar.
- **İhtiyaç satırı:** "Sipariş X · karantinada Y" bilgisi eklendi.
- **Dosyalar:**
  - Yeni: `Veri/TedarikSiparisDeposu.cs`.
  - Değişen: `TahsisDeposu.cs`, `KarantinaDeposu.cs`, `UretimDeposu.cs`, `TahsisViewModel.cs`, `TahsisView.axaml`, `UygulamaMetinleri.cs`.
  - Tasarım: `docs/superpowers/specs/2026-11-21-tahsis-siparis-acma-design.md`.
- **Testler:**
  - `TedarikSiparisTestleri` 8 test (DB, rollback).
  - `TahsisEkraniTestleri` +4 test.
  - Toplam 232/232.
- **Commit:** `251618f`.

### 2. Yan bulgu: ihtiyacın rengi
- Canlı `Erp_Requirement.InventoryVariantId` hiçbir satırda dolu değil; renk `Variant1Id`/`Variant2Id` alanlarında.
- Bu yüzden Tahsis ekranında gerçek order'larda renk boş görünüyor, uygun seriler renge göre süzülmüyordu.
- Çözüm: `TahsisDeposu.EtkinVaryant` (CROSS APPLY). Tahsis, uygun seri ve üretim eşleştirmesinde kullanılıyor.

### 3. Hata: gece 00:00–01:00 arası her okutma yeni fiş
- **Sebep:** Sunucu saati istemciden 1 saat geride. Mal kabul fiş başlığı istemci tarihiyle yazılıyor, "bugünkü fiş" araması ise `GETDATE()` ile yapılıyordu.
- **Bulunuş:** Gece yarısından sonra çalışan test paketinde 8 test kırıldı.
- **Düzeltme:** Arama `@bugun = DateTime.Today` ile yapılıyor (`MalKabulFisDeposu.BaslikAsync`).
- **Commit:** `251618f`.

## Kararlar
- Sentez sipariş tamamen gelince başlığı ve satırı kendisi kapatıyor (`IsClosed=1`). Mal kabul kapalı siparişi listelemiyor; bu doğru davranış.

## Açık kalanlar / sonraki adım
- Karantinada onaydan önce uygulamadan yapılan anketleri ve resimleri görmek istiyorlar (kullanıcı "haberin olsun" dedi; kaynak belirlenecek).
- PM66'ya yeni APK kurulmadı. Masaüstüne yeni build verilmedi (eski exe açıktı).
- 5a4dee0 kod incelemesi yarım.
