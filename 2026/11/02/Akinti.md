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

### 2. Kullanıcının 10 maddelik listesi (1. tur)
- **İstek (özet):** inşa menüsüne duvar/kapı, test için sınırsız envanter, yeni paketler (goldfish, sandalye) ve tüm paketlerin incelenmesi, eşya resimleri + isimleri, Kuzey Yıldızı, yerleştirilen parçanın yönünü çevirme, balık tutma, akıntıyla gelen malzemeyi kancayla toplama, üretim menüsü, kişi ile sal arasındaki boşluk. Ayrıca "arayüzü Raft'a benzet" isteği: belirli bir oyunun kopyası yapılmaz dendi; türün ortak dilinde, Akıntı'ya ait tasarım önerildi.
- **Paket taraması (alt ajan):** 26 paket; çoğu Built-in. Goldfish modeli YOK (Sardine paketindeki `Kingyobati.obj` balık kasesi); Emperor Angelfish var ama FBX 27 MB (mobil için ağır). Kapı: `Aletheia/Prefabs/door`, sandalye: `RPGPP_LT/.../rpgpp_lt_chair_01a`, korkuluk: `RPGPP_LT/.../rpgpp_lt_fence_wood_01a`.
- **URP dönüşümü:** `Converters.RunInBatchMode(ConverterContainerId.BuiltInToURP, [ConverterId.Material], Inclusive)` → projedeki tüm Standard malzemeler URP Lit oldu (özel shader'lı paketler hariç: Barrels, Wand and Circles, Abandoned World).
- **Boşluk (10):** model ayakları SkinnedMeshRenderer bounds'una göre oturtuluyordu; bounds şişkin → ~12 cm havada. `SoleY()` baked vertex minimumunu ölçüyor; `deckHeight` 0.01. Sonuç: ayak −0.014 (güverteye değiyor).
- **Duvar/kapı/korkuluk/sandalye (1, 2):** `PieceKind` += Wall, WindowWall, Railing, Door, Chair. Kenar parçaları hücre sınırında ve kat seviyesinde (`AddEdge`, sahibi kurulduğu hücre). Duvar/korkuluk `Standable` ayak izi kontrolünde geçişi engelliyor; kapı engellemiyor, `DoorSwing` yaklaşan karakter/tilkiye göre menteşeden açılıyor. Sandalye hücrenin düz üstünde. Paket modelleri Z boyunca modellenmişse `FitBox(alongX)` 90° çeviriyor (ilk denemede kapı 25 m'ye şişmişti).
- **Yön çevirme (6):** ÇEVİR butonu / R: `_turn` çeyrek tur; merdivenin tırmanma yönü, duvarın hangi kenarda olduğu, sandalyenin bakışı.
- **Sınırsız (1):** `Inventory.unlimited` (Has hep true, Remove ücretsiz); sağ üstte SINIRSIZ butonu / I; sahnede açık başlıyor.
- **Akıntıdaki malzemeler + kanca (8):** `Ocean/DebrisField.cs`: 30 m akıntı yukarısında doğar, şeritler sala yakın kümelenir, `Waves.Current + 0.9 m/s` ile salın yanından geçer, aşağıda geri dönüştürülür. `HookThrower` yüzerken ve sararken menzildekini takar, ele gelince çantaya koyar (sandık: tahta + halat bonusu).
- **Balık (7):** aynı olta; boş ipte 4–9 sn sonra balık vurur (şamandıra batar, buton ÇEK!), 1.6 sn içinde çekersen Çiğ Balık. YE: çiğ +12, pişmiş +40.
- **Üretim menüsü (9):** `Items/Recipes.cs` (11 tarif, 4 kategori) + `UI/CraftingMenu.cs` (U): sekmeler, kartlar, sahip/gerek, ÜRET. İstasyonlar şimdilik çantadaki eşya (Izgara → Pişmiş Balık, Su Arıtıcı → Su Şişesi). Halat ← Hindistan cevizi lifi.
- **İkonlar (4):** `Editor/AkintiIconBaker.cs` (Akinti ▸ Bake Icons): her model izole preview sahnede, şeffaf arka planla 256 px → `Resources/Icons/*.png` (sprite). Slot: resim + altta isim, sayı sağ üstte. İnşa menüsü seçenekleri de resimli.
  - **Tuzak:** bazı paket prefabları INACTIVE kaydedilmiş (WoodPlank_01) → Instantiate sonrası `SetActive(true)` şart (ikon boş, enkaz görünmez çıkıyordu).
- **Kuzey Yıldızı (5):** `SkyGradient.shader` yıldız alanı günde bir tur kutup ekseni etrafında dönüyor (Rodrigues), kutup yıldızı sabit, parlak, hafif göz kırpıyor. `DayNight.NorthStarDir()` = dünya +Z kuzey, 30° yükseklik.
- **Commit politikası:** paketlerin tamamı değil, sadece `AssetDatabase.GetDependencies("Ocean.unity")` çıktısı + .meta + klasör .meta'ları (`scratchpad/addassets.py`). Furniture Mega Pack 1.8 GB → eklenmedi.
- **Doğrulama (Play):** duvar/kapı/korkuluk/sandalye kuruldu, kapıdan geçildi; kanca şişeyi taktı (+1 Su); balık vurdu → ÇEK! → +1 Çiğ Balık; Izgara olmadan pişirme reddedildi, Izgara üretildi, sonra Pişmiş Balık. Görseller: `Docs/build-walls.png`, `Docs/craft-menu.png`, `Docs/north-star.png`.
- **Not:** bir ara Play moduna girmeden çekim yapıldı (sal boş görünüyordu) ve edit modda `Destroy` hatası verip geçici kamera kaldı → silindi, sahne yeniden açıldı. Ders: `editor.playmode start` sonrası `Application.isPlaying` kontrol et.
- **Commit:** `fc639f5` (duvar/kapı/çevir/sınırsız), `1bf33c3` (enkaz/balık/üretim/ikon/kutup yıldızı), `d255443` (builder çıktıları)

## Kararlar
- Kat yüksekliği kitten geliyor (1.5 m); en fazla 2 kat.
- Kat altından yürünemez (1.35 m boşluk karaktere yetmez) → kat dolu blok sayılıyor.
- Hedef her zaman bakılan komşu hücre (mevcut mobil kontrolle uyumlu); merdiven oyuncudan uzağa doğru tırmanıyor.
- Sökme hammer menüsünde de var, balta da aynı kuralla çalışıyor; sadece en üst parça sökülür.

## Açık kalanlar / sonraki adım
- Yüzen süs balıkları (Sardine sürüsü; goldfish modeli yok, Angelfish ağır).
- İstasyonları (Izgara, Su Arıtıcı, Sandık) sala yerleştirme.
- Gelecek büyük hedef: şehirler, kürek/yelkenle yolculuk, takasla ticaret.
- Duvar/korkuluk (kitte Wall2, WallPallete var).
- Tilki merdiveni kendi bulmuyor (sahibi yukarıdaysa altta kalabilir).
- Konsolda Editor açılışından kalma "Cannot import package in play mode" hatası (bizim kodumuz değil).
