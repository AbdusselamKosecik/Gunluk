# malkabul — 2026-11-25

## Bağlam
24.11'deki Seri Değiştir ekranına devam (bkz. `2026/11/24/malkabul.md`). Kullanıcı: "silmede ekler misin, seri kodu okuttuktan sonra bir QR
kod okutmasını isteyelim"; kararlar: Seri Değiştir'e Sil (seri fişlerden tamamen çıkar), onay QR'ı "rastgele rakamlı uzun".

## Yapılanlar

### 1. Seri sil + onay QR'ı
- **Akış:** seri okut → Sil → turuncu bant "onay QR'ını okutun" → sonraki okutma onay sayılır; yanlışsa silinmez ve seri araması yapılmaz;
  Vazgeç beklemeyi kaldırır; bağlantı koparsa `KayitBelirsiz`.
- **Onay kodu:** 24 haneli rastgele sayı (python `secrets`), QR PNG `segno` ile (scratchpad'e `pip --target`). Repoda yalnız SHA-256 özeti
  (`SeriSilOnayi.GecerliOzet`); kod ve QR yalnız yerelde: `malkabul/dagitim/seri-sil-onay-qr.png`, `dagitim/seri-sil-onay-kod.txt`
  (gitignore). Kod değişecekse yeni sayı → özet sabiti güncellenir.
- **Veri (`SeriDegistirDeposu.SilAsync`):** kilit; 129/29 hareketi varsa `SeriUretimde`; yalnız bu seriyi taşıyan kalemler varyant
  satırlarıyla DELETE (tetikleyiciler toplamları geri alır), paylaşımlı kalemde serinin payı düşülür (renk satırı ≤0 → DELETE); fiyatlı
  fişlerde `ToplamlariGuncelleAsync`; tahsis IsDeleted + silinecek kalemlere bağı NULL; kart IsDeleted=1 (kesim bilgileri kalır).
  Kaleme/varyant satırına başka kayıt bağlıysa (sys.foreign_keys taranır) `SeriKalemBagli`. Canlı veride serili kalemlere yalnız varyant
  satırları ve seri hareketleri bağlıydı (salt okuma sorgusu); hareket tipleri 1 ve 16.
- **Dokunulan:** `SeriDegistirDeposu.cs`, `SeriSilOnayi.cs` (yeni), `SeriDegistirViewModel.cs`, `SeriDegistirView.axaml`, `UygulamaMetinleri.cs`, testler.
- **Testler:** 5 ekran + 1 onay testi geçti (169 geçti / 134 DB atlandı). 5 yeni DB testi (`Sil_*`, `Uretime_verilmis_seri_silinemez`,
  `Silinen_serinin_tahsisi_kalkar`, `Baska_kayda_bagli_kalem_silinmez`) yazıldı ama SQL sunucusuna erişim kesildi (hata 53) — koşulmadı.
- Masaüstü uygulaması açıkken DLL kilitli; testler `--artifacts-path <scratchpad>/mkart` ile derlendi.
- **Commit:** `8e23edf` — Seri değiştir: onay QR'ı ile seri silme

## Açık kalanlar
- DB testlerini sunucu erişimi gelince koş: `dotnet run <scratchpad>/sqldene/sentestest.cs -- test MalKabul.Tests --artifacts-path <scratchpad>/mkart --filter FullyQualifiedName~SeriDegistir`
- Yeni masaüstü paketi (24.11 paketi silmeyi içermiyor), PM66 APK.
