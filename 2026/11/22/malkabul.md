# malkabul — 2026-11-22

## Bağlam
Satın alma inspection'ına hata girişi eklendi (selvedge 5491a8d); depo masaüstü karantina ekranında da görünmesi istendi.

## Yapılanlar

### 1. Karantina ekranında inspection hataları
- **Ne yapıldı:** `InspeksiyonDeposu`: `InspeksiyonHatasi` (Kod, Ad, Adet, Onem, Aciklama; Baslik, OnemMetni, Metin) ve
  `DetayAsync` içinde `Selvedge.dbo.sv_QaDefect WHERE ReportId=@reportId` okunur. `KarantinaViewModel.Hatalar` + `HataVar`;
  `KarantinaView.axaml`'da toplar ile İnspeksiyon cevapları arasında "Hatalar" listesi (kod, ad, ×adet, önem kırmızı, not).
  Metinler: InspeksiyonHatalar, OnemMinor/Major/Kritik (tr/en/ar). Hata fotoğrafları rapora bağlı olduğundan galeride zaten çıkar.
- **Testler:** InspeksiyonTestleri'ne seçince hatalar gelir/temizlenir, hata metni önem + açıklama; DbFact canlı hatalı raporu okur.
  `dotnet test` 157 geçti; `MODFEX_DB_TEST=1` Inspeksiyon 23/23.
- **Paket:** `publish/MalKabul-Masaustu-2026-11-22.rar` (win-x64 tek exe, pdb hariç).
- **Commit:** `e655fe6`.

## Kesime verme / iade kontrolü (gece)
- **Soru:** "Kesime mal verme ve kesimden fazla top alma işlemlerinde sıkıntı var mı? Kesimhane çalışıyor mu?" + "kesimhane WorkOrderProduction'dan besleniyordu".
- **Canlı veri:** Son 30 günde hiç 129/29 fişi yok (UZMUR hiç yok; tüm zamanlarda 129 son 2026-07-22). Erp_WorkOrderProduction proses 167: 30 günde 45 kayıt, **hepsinde WorkOrderId boş** (WorkOrderItemId/WorkOrderItemIds dolu), **MarkerNo hiçbirinde yok** (tüm zamanlarda 2 kayıt).
- **Bulgu 1 (düzeltildi):** `UretimDeposu.PastalHazirAsync` `WorkOrderId = @workOrderId` arıyordu → gerçek kayıtlar hiç bulunmuyor, kumaşta "Pastal hazır değil". Sorgu Order'ın kalemleri (`Erp_WorkOrderItem.WorkOrderId`) üzerinden + eski WorkOrderId'li kayıtlar.
  - TDD: `TahsisTestleri.PastalEkleAsync` gerçek biçime çevrildi (WorkOrderId NULL, kalem dolu) → 5 test kırmızı (PastalHazirDegil) → düzeltme → 264/264 yeşil (DB dahil, rollback).
  - Commit `f331c67`.
- **Bulgu 2 (karar bekliyor):** MarkerNo kesimhanede girilmiyor; `PastalKontrolu` açıkken kumaş yine verilemez. Seçenekler: kontrolü "167 kaydı var mı"ya gevşetmek ya da ayarı kapatmak.
- **Kesimhane (UZM_*) uygulaması:** UZM_Pastal/KesimGiris boş, hiç kullanılmamış; 0002 migration canlıda yok (UZM_KesimGirisBeden yok). DDL kullanıcının işi.
- Kesimhane testinde 1 kırmızı: test 0002'yi transaction içinde kurarken `SET NOCOUNT ON` oturumda kalıyor, UPDATE -1 dönüyordu (canlı kod hatası değil). Test `SET NOCOUNT OFF` ile düzeltildi, 33/33. Kesimhane commit `08a740f`.

## Hedef (gece 04:06): kesime ver / kesimden al + serisiz mal kabul ve sayım kontrolü
- **İstek:** Kesim plan/kesim kayıtları ve pastal bilgisi Sentez `Erp_WorkOrderProduction`'da (proses 167); kesime verme / kesimden alma fişle (129 / 29); kesim miktarı yalnız WOP'tan girilir. Verilecek serili ve serisiz malzeme tahsisten olur, tahsis miktarı esas, eski kurallar geçerli. Serisiz mal kabul ve sayımda sorun var mı?
- **Canlı veri:** 167 kayıtlarında MarkerNo yok, WorkOrderId boş (kalem bağlı); ayrı plan tablosu yok (35 ProcessId'li tablo tarandı). Canlıda serili tahsis 0; serisiz tahsisler Sentez'in stok tahsisleri (InventoryReceiptType 1/16, RequirementId'li). Uygulamanın yazdığı yalnız 3 fiş var, hiçbirinde serisiz kalem yok.

### 1. Pastal / kesim kaydı kontrolü (`8523d95`)
- `UretimDeposu.PastalHazirAsync`: Order kalemlerinde silinmemiş 167 kaydı (planlanan ya da kesilen) yeter; MarkerNo aranmaz. Mesaj ve ayar etiketi "kesim kaydı" oldu.
- Test fixture gerçek biçimde (WorkOrderId NULL, ProductionType 5, MarkerNo boş); canlı Order'ın 167 kayıtları testte gizlenir (`KesimKayitlariniGizleAsync`).

### 2. Tahsis kuralı (`8523d95`)
- Serili: `UretimeVerAsync` → verilecek ≤ seri tahsisinin kalanı (tahsis − verilen + iade), yoksa `TahsisFazla`. Harici (nedenli, otomatik tahsis) yolu korundu.
- Serisiz: `SerisizVerAsync` → Order'ın bu stok/renkteki stok tahsisi (fiş tipi 0/129/29 hariç) − serisiz verilen net; tahsis yoksa `MalzemeTahsisliDegil`, fazlası `TahsisFazla`. Yardımcı `SerisizTahsisAsync`.
- Testler: `Serisiz_tahsis_yoksa_verilmez_tahsisten_fazla_verilmez_iade_geri_acar`, `Seri_tahsis_kalanindan_fazla_verilmez` (RED → GREEN). Fixture `SerisizTahsisEkleAsync`.

### 3. Serisiz mal kabul / karantina / sayım incelemesi (`4048ee5`)
- Bağımsız inceleme ajanı (yalnız okuma) bulguları; doğrulanıp düzeltilenler:
  - **Serisiz karantina siparişleri karıştırıyordu** (tek satır, en yeni siparişin adıyla; red onaylanmış miktarı da iade edebiliyordu). Artık mal kabul KALEMİ bazında: bekleyen = kalem − bağlı 17 (`TransferOutReceiptItemId`) − bağlı 122 (`ReturnReceiptItemId`). Liste sipariş × stok × renk; dağıtılamayan eski stok siparişsiz satır. Onay/red `OrderReceiptId` ile yalnız o siparişten. Bu iki kolon canlıda hiç kullanılmıyordu (kontrol edildi); `FisSql.KalemEkle` VALUES'a parametre olarak eklendi (ilk denemede bir kayık yazıldı, test yakaladı, kolon-değer eşlemesi betikle doğrulandı).
  - **Mal kabulde renk kontrolü yoktu** → `SayimDeposu.MalzemeKontrolAsync` (internal yapıldı) çağrılıyor: varyantlı stokta renk zorunlu.
  - **Sayım düzeltmesi başka terminalin girişini eziyordu** → `DegistirAsync(..., ekrandakiMiktar)`; değiştiyse `KalemDegisti`. Masaüstü gördüğü miktarı gönderiyor.
- Açık bıraktıklarım (rapor edildi): sipariş birimi ≠ ana birim olan serisiz stokta birim karışıklığı; çıkış yer (lokasyon) bilgisi serisizde yazılmıyor; serisiz onayda otomatik tahsis yok; wifi kopmasında çift gönderim.
- **Sonuç:** 269/269 (DB dahil, rollback).
