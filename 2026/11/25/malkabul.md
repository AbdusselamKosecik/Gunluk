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

### 2. Telegram bildirimi + silmede hareket kuralı
- **Neden:** Kullanıcı: "silme işleminde bildirim yapmamız lazım, telegrama. ahmet abi şu ürünün şu serisini sildi diye"; "silinme işlemi
  kesime verilmediyse yani sadece sayım veya sadece 1 numaralı mal alımda yapıldıysa başka hareket yoksa silinebilsin. değişiklikte de bildirim gitsin."
- **Bildirim:** `OnayMerkeziIstemcisi` (malkabul) → Onay Merkezi `POST /api/olay`, `tur = "seri-degisiklik"`, `isteyen = "malkabul"`,
  kaynakRef `SeriSil:<seri>` / `SeriDegistir:<seri>`; metin "<UserCode> <stok> · <renk> ürününün <seri> serisini sildi" / "…değiştirdi" +
  renk/miktar değişimi + fiş sayısı. Bağlantı UZM_Ayar `OnayMerkeziAdres` / `OnayMerkeziAnahtar` (kesimhane Telegram ayarlarıyla ortak;
  `UzmAyar` sınıfı malkabul'a kopyalandı). **Karar (benim):** bildirim işlem içinde, commit'ten önce — gidemezse ya da ayar yoksa kayıt
  geri alınır (`TelegramGonderilemedi` / `TelegramAyarsiz`); habersiz silme olmasın. Bedeli: Onay Merkezi kapalıyken değişiklik yapılamaz.
- **Kural:** silme yalnız seri hareketleri 1 (mal alım) ve 16 (sayım) ise; 17 (karantina onayı/transfer), 129, 130… varsa `SeriBaskaHareketli`.
  Sonuç: karantinadan onaylanmış seri silinemez (yalnız değiştirilir).
- **Testler:** 172 geçti / 135 DB atlandı. DB testleri yeni kurala göre yeniden yazıldı (yalnız mal kabullü seri fixture'ı), sunucu erişimi yok (hata 64) — koşulmadı.
- **Commit:** `3b1d12d`

## Açık kalanlar (güncel)
- Onay Merkezi panelinde `seri-degisiklik` türü (gereken onay 0, Telegram grubu) tanımlanmalı — yoksa kayıt `TurBulunamadi` ile durur.
- DB testleri (sunucu gelince), sonra yeni masaüstü paketi ("yayınla" isteği bekliyor).
