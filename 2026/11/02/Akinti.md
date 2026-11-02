# Akinti — 2026-11-02

## Bağlam
Dünkü (2026-11-01) iş: kit entegrasyonu, gün-gece, bayrak, gölgelik, su/açlık barları. Bugün hedef: inşa sistemine ön izleme, açılır menü, kat çıkma ve sökme.

## Yapılanlar

### 1. İnşa menüsü + ön izleme (hayalet), kat çıkma ve sökme
- **Neden:** Kullanıcı: "Tekne geliştirmelerde ön izleme olsun, açılan menüden seçim olsun. Kat çıkma, kaldırma da da."
- **Kit incelemesi:** `Floors/ElevatedFloor` 2×1.5×2 m ayaklı platform (üstü 1.5 m), `Stairs/Stairs1` 2×1.5×2 m ve prefab'ın **−Z** yönüne doğru tırmanıyor (mesh tepe noktalarından ölçüldü). İkisi de 1.5 m → kat yüksekliği `RaftGrid.LevelHeight = 1.5`.
- **Ne yapıldı:**
  - `Raft/BuildPieces.cs`: `PieceKind {Floor, Deck, Stairs}`, `BuildChoice {Floor, Deck, Stairs, Remove}`, Türkçe adlar ve maliyetler (Zemin 4T+2H, Kat 6T+2H, Merdiven 4T+1H; sökünce yarısı geri).
  - `RaftGrid`: her hücre bir sütun. Slot 0 = yüzen zemin, slot 1–2 = Kat veya Merdiven (`MaxLevels = 2`). `CanStack`, `AddPiece`, `Top`, `CanRemoveTop`, `RemoveTop`. Parçalar zeminin altına bağlanıyor (zemin kırılırsa gider). Kütleye Kat 120 kg, Merdiven 70 kg ekleniyor.
  - `CreateArt(kind, cell, slot, dir)`: gerçek parça ve ön izleme aynı fonksiyondan çıkıyor → görünen = yapılacak olan. Merdiven `LookRotation(-dir)` ile döndürülüyor.
  - Yürüme yüksekliği: `SurfaceAt(local)` zemin/kat üstü/merdiven eğimini veriyor. `Step()` 0.3 m adım sınırı + ayak izi köşe kontrolüyle hareket ettiriyor; 1.5 m'lik kenar ve merdiven yanı, salın kenarı gibi davranıyor. Yanına kat dikilip sıkışan yürüyüşçü için kaçış kuralı var. Karakter ve tilki aynı fonksiyonu kullanıyor; tilkinin altı sökülürse sahibinin yanına atlıyor.
  - `RaftProp` kendi hücresini `Block()` ediyor (gölgelik ve bayrak hücresine kat yapılamaz).
  - `Raft/BuildGhost.cs` + `Shaders/BuildGhost.shader`: önce sadece derinlik yazan geçiş (iç yüzler üst üste binmesin), sonra kenar parlamalı, nabız gibi atan saydam renk. Yeşil (`Palette.Ghost #8FE3C9`) = yapılabilir, kırmızı (`Palette.Flag`) = yapılamaz / sökülecek (sökmede %4 büyütülmüş kılıf).
  - `UI/BuildMenu.cs`: aksiyon butonunun üstünde seçici ("inşa menüsü"); dokununca ZEMİN/KAT/MERDİVEN/SÖK listesi maliyetle açılıyor, karşılanamayan soluk. Masaüstü: Q aç/kapa, R sıradaki.
  - `PlayerActions`: her karede bir `Plan` (hücre, slot, yön, uygun mu, neden) hesaplanıyor; buton yazısı (YAP/SÖK/KIR), hayalet ve eylem hep bu plandan. Balta da kırmızı ön izlemeyle en üst parçayı söküyor.
  - Builder: `deckPrefab`/`stairsPrefab` atanıyor, `BuildGhost.mat` ve menü UI'ı kuruluyor.
- **Dokunulan dosyalar:** `Scripts/Raft/{RaftGrid,RaftProp,BuildPieces,BuildGhost}.cs`, `Scripts/UI/BuildMenu.cs`, `Scripts/Player/{PlayerActions,CastawayController,PetFollower}.cs`, `Scripts/Core/Palette.cs`, `Shaders/BuildGhost.shader`, `Editor/AkintiSceneBuilder.cs`, `Scenes/Ocean.unity`, `CLAUDE.md`
- **Sorun:** Bash heredoc içinde uzun C#/Python yine "unexpected EOF" verdi → dosyaları Write ile scratchpad'e yazıp `python -I` ile çalıştırmak.
- **Sonuç / doğrulama (Play modu):**
  - Zemin (2,1) → Kat (2,1) → Merdiven (1,1, +x yönünde). Malzeme 42→28 Tahta, 14→9 Halat doğru düştü.
  - Yüzey örnekleri x=0…4.4: 0 → 0.15 → … → 1.35 → 1.50 (merdiven eğimi).
  - Karakter merdivenden 1.55'e çıktı, kat kenarında 4.72'de durdu (kenar − 0.28); yandaki alçak zemine düşmedi; geri inişte 0.05'e döndü. Tilki de çıktı.
  - Sök: kat kalktı, +3 Tahta, üstündeki tilki sahibinin yanına indi.
  - Görüntüler: `Docs/build-kat.png` (menü açık, 2. kat yeşil hayaleti), `Docs/build-sok.png` (kırmızı sökme ön izlemesi). Konsolda oyun hatası yok.
- **Commit:** `27236ba` — Build menu + ghost preview; storeys (deck, stairs) and take-apart

## Kararlar
- Kat yüksekliği kitten geliyor (1.5 m); en fazla 2 kat.
- Kat altından yürünemez (1.35 m boşluk karaktere yetmez) → kat dolu blok sayılıyor.
- Hedef her zaman bakılan komşu hücre (mevcut mobil kontrolle uyumlu); merdiven oyuncudan uzağa doğru tırmanıyor.
- Sökme hammer menüsünde de var, balta da aynı kuralla çalışıyor; sadece en üst parça sökülür.

## Açık kalanlar / sonraki adım
- Duvar/korkuluk (kitte Wall2, WallPallete var).
- Tilki merdiveni kendi bulmuyor (sahibi yukarıdaysa altta kalabilir).
- Konsolda Editor açılışından kalma "Cannot import package in play mode" hatası (bizim kodumuz değil).
