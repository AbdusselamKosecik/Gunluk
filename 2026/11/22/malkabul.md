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
