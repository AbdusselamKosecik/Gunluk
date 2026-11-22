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
