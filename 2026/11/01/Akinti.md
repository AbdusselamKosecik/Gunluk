# Akinti — 2026-11-01

## Bağlam
Sıfırdan yeni oyun projesi. Hedef: açık denizde enkaz toplayıp salı büyütme/düzenleme türünde
(raft survival) **özgün** bir low-poly mobil oyun. Bu turun kapsamı: giriş ekranı, sonsuz su, sal.
`X:\Oyun` boştu; Unity CLI kurulu değildi. `/unity:new-unity-project` (paved mod) akışı izlendi.

## Yapılanlar

### 1. Unity CLI, giriş, lisans, Editor kurulumu
- **Neden:** Proje oluşturma ve Editor'ü dışarıdan sürme CLI üzerinden yapılıyor.
- **Ne yapıldı:** Resmi betikle CLI 1.0.0-beta.15 kuruldu. Kullanıcı `unity auth login` ile girdi.
  Unity Personal lisansı etkinleştirildi (kullanıcı onayıyla). Editor 6000.6.7f1 + Android + iOS modülleri kuruldu.
- **Komutlar:**
  ```powershell
  irm https://unity.com/install.ps1 | iex          # CLI -> C:\Users\abdus\AppData\Local\Unity\bin
  unity auth login                                  # kullanıcı yaptı (tarayıcı)
  unity license activate --personal --accept-eula
  unity install latest --module android --module ios --yes --accept-eula   # -> 6000.6.7f1
  ```
- **Not:** İlk `unity open`'da "Unity Editor Software Terms" penceresi çıkar; kullanıcı Editor'de kabul etmeli.

### 2. Proje oluşturma + bulut bağlantısı
- **Ne yapıldı:** URP 3D şablonuyla proje. Create, `com.unity.pipeline` ve Cinemachine 3.1.7'yi kendisi ekledi.
  Bulut bağlantısı ilk denemede "no organization" ile düştü; tek org (Tekbirsoft, owner) ile bağlandı.
- **Komutlar:**
  ```powershell
  unity projects create "Akinti" --path "X:\Oyun" --editor-version 6000.6.7f1 --template 3d --non-interactive
  unity cloud orgs --format json
  unity projects link cloud "X:\Oyun\Akinti" --cloud-org 30c01113-5502-4df4-0000-010000369fc2
  ```
- **Sonuç:** cloud project id `8afaebe0-93f9-49bc-b5c3-dd27fdbfe1fb`.

### 3. Paketler (Editor açıkken Pipeline `package add`)
- `com.unity.services.authentication` 3.8.1, `com.unity.services.cloudsave` 3.4.2,
  `com.unity.services.leaderboards` 2.3.4, `com.unity.remote-config` 4.2.5.
- **Tuzak:** Her `package add` domain reload tetikliyor ve bağlantı kopuyor. Çözüm: her ekleme öncesi
  `unity status --until-ready` ile beklemek.
  ```bash
  unity command package add --identifier <id> --confirm true --wait true --project-path X:/Oyun/Akinti
  ```
- TMP Essentials: `TMPro.TMP_PackageResourceImporter.ImportResources(true,false,false)` (script eval).

### 4. Oyun kodu (Assets/_Akinti)
- **Art bible:** `Scripts/Core/Palette.cs`. Low-poly flat-shaded deniz. Palet: deniz #1E5F74, ahşap #9C6B3F,
  ufuk/sis #CFE6E6, gölge #2B3A4A, vurgu #F2A541… Tüm renkler buradan okunuyor.
- **Waves.cs:** 3 sinüs dalgası, hızları derin su dispersiyonu ω=√(g·k) ile. `Height(x,z,t)` hem görsel
  hem fizik için TEK kaynak. `Current(pos,t)` = akıntı (şimdilik sabit (0.35,0,0.6) m/s, TODO kullanıcıda).
- **OceanSurface.cs:** 72×72 hücre × 3 m, kamerayı hücre adımıyla takip eden grid. Yükseklik dünya
  koordinatından hesaplanıyor, desen kaymıyor, sonsuz görünüyor. Paylaşımsız vertex + üçgen başına normal
  = low-poly görünüm (stok URP Lit). Sis 18–92 m kenarı gizliyor.
- **Buoyancy.cs:** Yüzme noktaları; derinliğe orantılı kaldırma + (nokta hızı − akıntı) sürüklemesi.
  Akıntı itmesi bu sürüklemeden doğuyor.
- **RaftGrid.cs:** Sal = tamsayı karo ızgarası (1.5 m). `AddTile/RemoveTile/CanPlace`. Kütle, ağırlık
  merkezi ve yüzme noktaları her değişiklikte yeniden hesaplanıyor. Başlangıç 2×2.
- **GameShell.cs:** Title/Playing/Paused durum makinesi, 0.3 s fade. Başlıkta herhangi bir dokunuş ile oyun başlıyor; Esc/II ile pause.
- **ServicesBootstrap.cs:** UGS init + anonim giriş (RuntimeInitializeOnLoad, bloklamaz).
- **SkyGradient.shader:** Ufuk = sis rengi, zenit, güneş diski.
- **Editor/AkintiSceneBuilder.cs:** `Scenes/Ocean.unity`'yi sıfırdan kodla kuruyor (ışık 38°, trilight ambient,
  sis, Volume: Neutral tonemap, Bloom 0.35@1.1, Vignette 0.22, ColorAdj sat+10/contrast+6; Cinemachine
  CM_Title orbit + CM_Play follow; uGUI Canvas 1920×1080). Mobile kalite kademesini seçiyor.
  ```bash
  unity recompile --project-path X:/Oyun/Akinti
  unity command script eval --code 'Akinti.EditorTools.AkintiSceneBuilder.Build();' --project-path X:/Oyun/Akinti
  ```
- **Tuzak:** PowerShell, `unity command script eval` kodundaki tırnakları bozuyor; Bash + `--code "$(cat file)"` kullan.
  Pipeline parametreleri `--` ayracından SONRA, `--caller/--project-path/--format` ise ÖNCE yazılmalı.

### 5. Doğrulama
- Recompile: 0 hata / 0 uyarı. Play mode: frameCount ilerliyor, 4 karo, 20/20 yüzme noktası suda,
  sal ~0.65 m/s akıntıyla sürükleniyor, `[Akinti] Services ready, PlayerId=…`, konsol 0 hata / 0 uyarı.
- State akışı log'dan doğrulandı: Title → Playing → Paused → Title.
- Ekran görüntüleri: `Docs/baseline-title.png`, `Docs/baseline-play.png`.
- **Tuzak:** Editor odakta değilken `capture --source screen` bayat kare veriyor. UI'lı görüntü için Canvas'ı
  geçici ScreenSpaceCamera yapıp `--source camera` ile yakalandı.

### 6. Git
- `git init -b main`, github/gitignore Unity.gitignore, `core.autocrlf false`. Yollar açıkça eklendi.
- `gh repo create AbdusselamKosecik/Akinti --private --source . --remote origin --push`
- **Commit:** `d3d013e` — Initial Unity project: Akinti

### 7. Variller, karakter, dokunmatik kamera (öğleden sonra)
- **Neden:** Kullanıcı geri bildirimi: su salın üstüne çıkıyordu, kamera dokunarak çevrilebilmeliydi, bir de karakter istendi.
  İleride yelken ve kürekle yön değiştirme planlanıyor.
- **Variller (`RaftGrid.cs`):** Her karonun altında X ekseni boyunca yatan 2 varil var (r=0.31, uzunluk 1.2, y=-0.48), ikişer çember.
  Yüzme noktaları varil uçlarında (y=-0.73), floatDepth 0.45. Su varil merkezinde dengeleniyor.
  Karo başına kütle 110, CoM varil hizasında. Collider 0.86 yüksekliğe uzatıldı.
  **Ölçüm:** güverte sudan 0.55–0.58 m yukarıda, yalpalama 5–9°.
- **Varil dokusu:** Builder `Textures/Barrel.png` (128×64) dosyasını prosedürel üretiyor (seed 1907): Palette.Barrel #4F7A6E boya,
  dikey çizgiler, ortada Accent şerit (v 0.42–0.58), kenarlara doğru pas. Unity silindirinde U çevre, V yükseklik boyunca.
- **Karakter (`Player/CastawayController.cs`):** Primitiflerden kazazede: hasır şapka, turuncu can yeleği, mavi gömlek.
  Salın CHILD'ı, raft-local uzayda yürüyor (fizik yok, dalgayı bedavaya taşıyor). Kamera yönüne göre hareket ediyor.
  4 köşeden `HasTileAtLocal` kontrolüyle kenarda kayıyor, düşmüyor. Prosedürel yürüyüş: bacak/kol salınımı 34°, gövde zıplaması, nefes.
- **Kontroller (`Player/PlayerControls.cs`):** Touch: ekranın sol %40'ında yüzen joystick, sağda kamera.
  İki parmak aynı anda çalışıyor. UI üstünde başlayan dokunuş yok sayılıyor. Masaüstü: WASD + fare sürükleme.
- **Kamera (`Core/TouchOrbit.cs`):** CM_Play artık CinemachineOrbitalFollow (Sphere, r=8.5, pitch 8–65°, WorldSpace binding)
  kullanıyor ve karakterin `CameraFocus`'unu takip ediyor. Bırakınca momentum söner (5/s).
- **Doğrulama:** Recompile temiz. Play'de karakter (1,1) yönünde yürüdü ve köşede (1.97,1.97) durdu (kenar − 0.28).
  Kamera yaw 150° döndü. Konsol 0 hata/uyarı. Görüntü: `Docs/baseline-castaway.png`.
- **Tuzak:** Kullanıcı Editor'de Play açıkken sahne rebuild yapılmaz. Durdurmasını istedim, kendim durdurmadım.
- **Commit:** `e4e46a8` — Barrel-floated raft, castaway character, touch camera orbit

### 8. Eylemsizlik salınımı iskeleti
- **Neden:** Kullanıcı sordu: adam durduğunda denizin tersine hareket etmeli mi? Cevap: sürtünme kaymayı önler (ahşap–ayakkabı ~25–30° sürtünme açısı, sal en fazla 9° eğiliyor). Eylemsizlik gövde salınımı olarak görünür.
- **Ne yapıldı:** `CastawayController.FeltPush` = karakter çerçevesinde (gravity − güverte ivmesi), sonlu fark + low-pass. `SwayStep` yay–sönüm adımı TODO olarak kullanıcıya bırakıldı. Gövde rotasyonu `(6·speed + sway.x, 0, −sway.y)`.
- **Commit:** `1384b3c` — Castaway balance sway scaffold
- **Tuzak:** PowerShell 5.1 `Add-Content` ANSI (cp1254) yazar; günlüğe ekleme için UTF-8 kullanan araç kullan.

### 9. HUD: joystick, envanter, aksiyon butonları, olta, POV
- **Neden:** Kullanıcı istedi: mobil joystick, Minecraft benzeri envanter (hotbar + çanta), yap/vur/olta butonları, 1. şahıs görünüm.
  Ayrıca: kenarda karakter "duvara karşı koşuyor" gibiydi.
- **Kenar düzeltmesi:** Yürüme animasyonu artık gerçekte kat edilen mesafeye bağlı (`moved / (speed·dt)`), joystick girdisine değil.
  Kenara dayanınca bacaklar duruyor. Doğrulama: kenarda Speed01 = 0.00.
- **Joystick (`PlayerControls`):** Sol altta kalıcı (rest 250,250, alpha 0.55). Dokununca parmağın altına kayıyor, bırakınca dönüyor.
- **Envanter (`Items/Items.cs`, `Items/Inventory.cs`, `UI/InventoryUI.cs`, `UI/SlotView.cs`):** 36 slot (0–8 hotbar, 9–35 çanta).
  Add: önce aynı stack, sonra boş. Remove: önce çanta. Swap aynı eşyayı birleştiriyor.
  UI: hotbar alt-orta (92 px slot, 100 adım), ÇANTA butonu, panel 9×3 + hotbar satırı, dokun-dokun ile yer değiştirme.
  İkonlar şimdilik palet renkli kutu + 3 harf. Başlangıç: Olta, Çekiç, 12 Tahta, 4 Halat | çanta: 2 Varil, 5 Hurda.
- **Aksiyonlar (`Player/PlayerActions.cs`):** Butonlar sağ altta (sol başparmak joystick'te). YAP: karakterin baktığı eksende ilk boş
  hücreye karo ekliyor (4 Tahta + 2 Halat, pop-in animasyonu). VUR: kol savurma. OLTA/SAR: `HookThrower`.
- **Olta (`Player/HookThrower.cs`):** Balistik atış (9 m/s ileri + 5 m/s yukarı). Suya düşünce Waves.Height'ı takip edip Current ile sürükleniyor.
  SAR ile 9 m/s geri geliyor. 18 m'yi geçince otomatik sarılıyor. LineRenderer halat sarkma ile çiziliyor (URP/Unlit Rope.mat).
- **POV (`Core/CameraModes.cs`, `Core/FirstPersonLook.cs`):** PlayRig altında CM_Play (orbit) + CM_FirstPerson
  (HardLockToTarget → kafadaki Eye, PanTilt World, FOV 68). Geçişte bakış yönü korunuyor, 0.45 s blend.
  POV'da kafa ShadowsOnly (gölgesi kalıyor).
- **Tuzak:** Pasif GameObject'te Awake çalışmaz. `TouchOrbit`/`FirstPersonLook` bileşen referansını lazy alıyor.
- **Görsel düzeltmeler:** Sea smoothness 0.6→0.35 (alçak güneşte beyaz parlamalar). Seçili slot çerçevesi Foam
  (Accent, Olta ikonuyla karışıyordu). Oltayı sarma etiketi "SAR" (Çekiç'in "ÇEK"iyle karışıyordu).
- **Doğrulama:** Kenarda Speed01 = 0. YAP → 5 karo, Tahta 12→8, Halat 4→2. Olta 11 m'de suya düştü. Konsol 0 hata/uyarı.
  Görüntüler: `Docs/hud-thirdperson.png`, `Docs/hud-pov.png`, `Docs/hud-inventory.png`.
- **Klavye:** WASD, sürükle, V POV, E/Tab çanta, 1–9 hotbar, B yap, Space vur, Q olta/sar, Esc pause.
- **Commit:** `6fe6f49` — HUD: joystick, hotbar + bag inventory, action buttons, hook, POV

### 10. Tek bağlamsal buton, Balta, dik duran karakter
- **Neden:** Kullanıcı: "karakter tekneyle birlikte direk gibi sallanıyor"; "yap/vur/olta olmaz, tek buton:
  elde çekiç → yap, balta → kır, olta → olta at / atılmışsa çek".
- **Dik durma (`CastawayController`):** Ayaklar güvertede (raft-local konum), ama `transform.rotation` dünyaya göre
  yalnızca yaw (`LookRotation(flatForward, up)`). Eğimi bilekler alıyor. **Ölçüm:** sal 9.6° → gövde 0.00°.
- **Tek buton (`PlayerActions`):** Seçili hotbar eşyasına göre: Hammer→YAP, Axe→KIR, FishingHook→OLTA AT / ÇEK, diğer→VUR.
  Olta dışına geçilirse kanca otomatik sarılıyor. Klavye: Space/F.
- **KIR:** Baktığı yöndeki komşu karo (üstünde durulan değil). `RaftGrid.CanRemove` flood-fill ile salın tek parça
  kaldığını kontrol ediyor. Yarısı iade (2 Tahta + 1 Halat). **Test:** 4→3 karo, Tahta 12→14.
- Yeni eşya: Balta (`ItemId.Axe`, "BLT"). Çekiç kısaltması "ÇKÇ" (buton "ÇEK" ile karışmasın).
  Başlangıç hotbar: Olta, Çekiç, Balta, 12 Tahta, 4 Halat.
- **Asset Store:** Kullanıcı Toon Fox (pet) ve Low Poly Medieval Peasants (karakter) paketlerini aldı. CLI'da Asset Store
  indirme komutu yok, `%APPDATA%/Unity/Asset Store-5.x` boş. Kullanıcı Package Manager ▸ My Assets ▸ Download/Import yapacak.
- **Commit:** `6064c9c` — Single context action button, Axe, upright castaway

### 11. Köylü karakter + tilki pet (Asset Store)
- **Neden:** Kullanıcı iki ücretsiz paket aldı: Toon Fox (pet) ve Low Poly Medieval Peasants (karakter). Birini seçip kullanmak istedi.
- **İndirme:** CLI ile yapılamıyor. Kullanıcı Package Manager ▸ My Assets ▸ Download/Import yaptı → `Assets/Fox`, `Assets/Polytope Studio`.
- **İnceleme:** Köylüler Humanoid rig ama HİÇ animasyon yok. Shader Built-in surface shader (URP'de pembe olur).
  Tilki Generic rig, 30 klip, controller'da parametre yok. Malzemesi `Standard (Specular)` (URP'de pembe olur).
- **URP düzeltmesi (köylü):** Paketin içindeki `Lowpoly_Characters/URP/PT_Peasants_Free_URP_17.unitypackage`
  (sadece shader'lar) import edildi: `AssetDatabase.ImportPackage(path, false)`. Shader tag'i artık UniversalPipeline.
- **Karakter:** `PT_Male_Peasant_01` seçildi. Builder prefab'ı Castaway altına instantiate ediyor, 1.75 m'ye ölçekliyor,
  tabanı güverteye oturtuyor. Eye = Head bone child. Hand = RightHand bone. POV'da `*_head` renderer gizleniyor.
- **Prosedürel humanoid animasyon (`CastawayController`):** LateUpdate'te kemikler bind (T-poz) rotasyonuna resetleniyor,
  sonra karakter eksenlerinde (right/forward/up) parent→child sırasıyla döndürülüyor. Kollar fwd ekseninde ±72° aşağı;
  bacak salınımı ±32°; diz max(0, ±cos)·50°; kol salınımı ters; gövde eğilmesi + sway. Aksiyon: sağ kol +35° → −140°.
  Animator kapalı (yalnızca avatar/kemik bulmak için).
- **Tilki (`PetFollower`):** Raft-local. Hedef: sahibinin 0.75 m arkası + 0.55 m sağı; güverte dışındaysa yedek noktalar.
  0.9 m'den uzaksa yürü (1.3 m/s), 2.4 m'den uzaksa koş (3.2 m/s). 4 s durursa `Fox_Sit1` → `Fox_Sit2_Idle`.
  `CrossFadeInFixedTime(stateName)`. Kendi URP Lit malzemesi `Fox.mat` (BC + normal + AO). Boy 0.75 m (ölçek 0.25).
- **Ortak:** `RaftGrid.IsWalkable(local, margin)` (4 köşe).
- **Doğrulama:** Konsol 0 hata. Köylü ve tilki URP'de doğru renkte, tilki oturma durumuna geçti. Görüntüler: `Docs/peasant-fox*.png`.
- **Repo:** Asset paketleri (123 MB, en büyük dosya 23 MB) LFS'siz commit edildi (private repo).
- **Commit:** `040a434` — Peasant character model + fox pet (Asset Store packs)

### 12. İlk Android APK
- **Neden:** Kullanıcı APK istedi.
- **Eksik modüller:** `android` modülü kuruluydu ama `AndroidPlayer/SDK|NDK|OpenJDK` boştu. Kuruldu:
  ```bash
  unity install-modules -e 6000.6.7f1 -m android-sdk-ndk-tools -m "android-open-jdk-17.0.18+8" --accept-eula
  ```
- **Build (`Editor/AkintiBuild.cs`, menü Akinti ▸ Build Android APK):** com.tekbirsoft.akinti, 0.1.0 (code 1), IL2CPP,
  ARM64, landscape auto-rotate, debug imza, `Builds/Android/Akinti.apk`. Sonuç satırı `build-result.txt`'ye yazılıyor.
- **Nasıl çalıştırıldı:** Proje açık Editor'de kilitli olduğu için `unity build` (batch) kullanılamadı. Eval ile
  `EditorApplication.delayCall += AkintiBuild.BuildAndroid` çağrıldı, sonuç dosyası arka planda beklendi.
  Gerçek Editor log'u: `X:/Oyun/Akinti/Logs/Editor.log` (%LOCALAPPDATA%'daki değil).
- **Sonuç:** Succeeded, 288 s, 0 hata. APK 46 MB (rapordaki 929 MB sıkıştırılmamış toplam).
  `aapt2 dump badging`: targetSdk 36, arm64-v8a. `apksigner verify` OK.
- `.gitignore`: Polytope URP shader `.unitypackage`'ları istisna yapıldı (`*.unitypackage` kuralı yüzünden dışarıdaydı).
- **Commit:** `48358e4` — Android APK build
- **Not:** Aktif build target artık Android. Editor'de Play çalışmaya devam ediyor.

### 13. Raft Builder Kit (Asset Store, Anni) — inceleme, henüz import YOK
- **Neden:** Kullanıcı paketi indirdi; projeye almadan önce uyumu ölçmek.
- **Ne yapıldı:** `.unitypackage` (tar.gz) scratchpad'e açıldı, `pathname` dosyalarından liste çıkarıldı; binary FBX'ler küçük bir Python parser'la (Vertices / PolygonVertexIndex dizileri, zlib) üçgen sayısı + ölçü için okundu.
- **Konum:** `%APPDATA%/Unity/Asset Store-5.x/Anni/3D ModelsProps/Raft Builder Kit.unitypackage` (151 MB)
- **Komutlar:**
  ```bash
  tar --force-local -xzf "<paket>" -C <scratch>   # Git Bash'te C: yolu için --force-local şart
  ```
- **Bulgular:**
  - 95 prefab, 91 FBX, 18 materyal, 54 PNG; **hiç C# script yok** (saf art paketi).
  - Materyaller zaten **URP Lit** (shader guid 933532a4…) → pembe olmaz. Tek istisna kullanılmayan `New Material.mat`.
  - Dokular 2048² Albedo + Normal + MetallicSmoothness, stilize el boyaması; toplam 144 MB PNG.
  - `SkyboxHDRI HAVEN/autumn_field_puresky_4k.exr` 70 MB + `SampleScene` → import'ta hariç tutulmalı (repo şişer, GitHub 50 MB uyarısı).
  - Birim cm: Floor modülü **2.0 × 2.0 m**, duvar 2 m × 1.5/3 m, merdiven 2 m. Bizim `RaftGrid.TileSize` 1.5 m → uyuşmuyor.
  - Poligon: zemin 1–2.2k tri, eşyalar 200–3.8k tri, toplam ~80k → mobil için makul.
  - Yiyecek/balık/FloatingRoll/WoodFloor gibi 34 prefabta Rigidbody + Collider hazır → denizde yüzen enkaz için doğrudan kullanılabilir.
  - Yelken (Sail/SailBase/SailFull) ve Paddle var → planlanan yelken/kürek yönlendirmesine model hazır.
- **Sonuç:** Proje değişmedi, commit yok. Karar kullanıcıda: grid 2 m'ye mi geçilir, kit 0.75'e mi ölçeklenir.

### 14. Raft Builder Kit entegrasyonu: 2 m karo, kit zemini, elde aletler
- **Neden:** Kullanıcı "karoyu 2 m'ye çıkar, kiti kullan" dedi.
- **Ne yapıldı:**
  - Kit import edildi (`AssetDatabase.ImportPackage(path, false)`). Play modundayken reddediyor ("Cannot import package in play mode") → önce `editor.playmode stop`.
  - 150 MB / 54 adet 2K doku Android için sıkıştırıldığı için ~15 dk sürdü; komut 30 sn'de 504 verir ama Editor'de devam eder. İlerleme Unity penceresinin başlığında görünür ("Importing - Compress 54%").
  - Sonra `SkyboxHDRI HAVEN/`, `SampleScene/` ve `New Lighting Settings.lighting` silindi; klasör 150 → 82 MB.
  - `RaftGrid.TileSize` 1.5 → 2.0, `MassPerTile` 110 → 195 (alanla orantılı). Yüzdürme ağırlığa oranlı olduğu için su çizgisi değişmedi.
  - Yeni alanlar `floorPrefab` (kit `Floors/Floor`) ve `floatPrefab` (`LargePlatform1/FloatingRoll`, karo başına 2 adet). `Fit()` pivota güvenmiyor, renderer sınırlarını ölçüp ölçekliyor ve oturtuyor. Kit prefablarındaki Rigidbody ve Collider siliniyor. Kit yoksa eski primitif tahtalar kullanılıyor.
  - `HeldItems.cs`: seçili hotbar eşyası sağ elde görünüyor. Builder, bind pozunda (T-pose) aleti sap ileri bakacak şekilde ele yerleştiriyor.
    - Uç tespiti: kesiti geniş uç baş sayılıyor; oltada tersi (`gripAtWide`).
    - Olta ipi artık oltanın ucundan çıkıyor (`RodTip`).
- **Dokunulan dosyalar:** `Scripts/Raft/RaftGrid.cs`, `Scripts/Player/HeldItems.cs`, `Editor/AkintiSceneBuilder.cs`, `Assets/Raft Builder Kit/**`, `CLAUDE.md`
- **Sonuç / doğrulama:** Güverte sudan 0.61 m yüksekte, eğim 6°, 0 hata. Yakın plan görüntüler: `Docs/tool-*.png`, `Docs/raftkit-hammer.png`.
- **Not:** Kullanıcı `Assets/Barrels/` paketini kendisi ekledi; commit edilmedi. `Assets/Scenes/SampleScene.unity` ve TMP fallback değişiklikleri de bilerek dışarıda bırakıldı.
- **Commit:** `297a9ca` — Raft Builder Kit: 2 m tiles with kit floor + floats, tools in hand

### 15. Gün-gece + ay evresi, rüzgâr bayrağı, gölgelik, su/açlık barları
- **Neden:** Kullanıcı istedi: rüzgârı gösteren küçük bayrak, başlangıçta gölgelik, su ve açlık barları, ay evresine göre gece aydınlığı.
- **Asset Store önbelleği tarandı:** gökyüzü, gün-gece ya da gölgelik paketi yok. O yüzden hepsi kodla yazıldı (palete bağlı kalması için zaten doğrusu bu).
- **Ne yapıldı:**
  - **`Core/DayNight.cs`** (Sun objesinde):
    - Saat: gün 12 gerçek dakika; güneş 06–18 arası, 28° eğik yörüngede (öğlen 62°).
    - Ay: aynı yörüngede faz × 24 saat geriden geliyor (8 günlük çevrim), yani dolunay gün batımında doğuyor. Aydınlık = (1 − cos(2π·faz)) / 2.
    - Işık: tek directional light gündüz güneş, gece ay (mobilde tek gölge haritası). Gökyüzü, sis, trilight ambient ve `reflectionIntensity` paletten karıştırılıyor; gece deniz gündüz gökyüzünü yansıtmasın diye yansıma kısılıyor.
    - Sky.mat çalışma anında kopyalanıyor (asset dosyası değişmesin diye).
  - **`SkyGradient.shader`:** ay diski bir küre olarak gerçek `_SunDir` ile aydınlatılıyor, yani evre sahte değil, ışıkla birebir tutarlı. Hash'le üretilen yıldızlar `_Stars` ile geceleri beliriyor. Güneş diski ufkun altında gizleniyor.
  - **`Ocean/Wind.cs`:** tek rüzgâr fonksiyonu. Yön 35° etrafında ±70° Perlin ile geziniyor, şiddet 0.3–1 × 7 m/s. Yelken de bunu okuyacak.
  - **`Raft/WindFlag.cs`:** prosedürel çift yüzlü bayrak (10×4 vertex, yürüyen sinüs dalgası). Görünen rüzgârı gösteriyor (rüzgâr − sal hızı); rüzgâr hafifken uç sarkıyor.
  - **`Raft/Canopy.cs`:** 4 direk, 2 kiriş, halat sargıları ve sarkan bez (7×7). Çatıda tetik collider var; `Canopy.Shades()` güneşe ışın atıyor, böylece gölge güneşle birlikte kayıyor.
  - **`Raft/RaftProp.cs`:** sahnede raft altında duran prop, Start'ta kendi karosuna geçiyor (karo kırılınca onunla gidiyor). `RaftGrid.TileTransform(cell)` eklendi.
  - **`Player/Survival.cs`:**
    - Su 10 dk'da, açlık 16 dk'da biter. Susama güneşte ×1.5, gölgede ve gece ×0.6.
    - Bar boşalınca hız %60'a düşer; düşük seviyede toast uyarısı çıkar.
    - Yeni eşyalar Su Şişesi (20) → İÇ (+35 su) ve Hindistan Cevizi (21) → YE (+25 açlık, +10 su). Elde kit modelleri (`Bottle`, `Coconut`) görünüyor.
  - **`UI/SurvivalHUD.cs`:** sol üstte SU ve AÇLIK barları (Filled Image, yumuşak geçiş, %20 altında yanıp söner), altında "Gün N · hh:mm", gece ay evresinin adı, gölgedeyken "gölgede" yazısı.
  - Palete yeni renkler: DuskGlow, NightZenith, NightHorizon, MoonLight, Canvas, Flag, Thirst, Hunger.
- **Sorun:** Builder'a eklenecek uzun Python yaması bash heredoc içinde tırnak hatası verdi ("unexpected EOF"). Çözüm: yamayı dosyaya yazıp `python -I dosya.py` ile çalıştırmak.
- **Sonuç / doğrulama:**
  - Altı saat ve evrede görüntü alındı: `Docs/daynight.png`.
  - Öğlen gölgelik altında `InShade=True`, dışarıda `False`.
  - Yeme: su 57 → 67, tokluk 63 → 88. İçme: su → 100.
  - HUD görüntüsü: `Docs/hud-survival.png`. Konsolda 0 hata.
- **Commit:** `2972349` — Day/night with moon phases, wind flag, canopy, thirst/hunger bars

## Kararlar
- Tür Raft'a benziyor ama oyun özgün: kendi hikâyesi ve kimliği olacak, Raft'a özgü öğeler kopyalanmayacak. Çalışma adı "Akinti".
- Mobil hedef: uGUI + TMP (UI Toolkit değil), Mobile kalite kademesi.
- Okyanus CPU mesh (shader değil): yükseklik C# ile birebir aynı, mobilde ~31k vertex.
- Başlıktan oyuna geçişte siyah fade yerine Cinemachine blend (2.2 s) kullanıldı. Bu, shell floor'undan bilinçli bir sapma.

## Açık kalanlar / sonraki adım
- `Waves.Current()` akıntı davranışı ve `CastawayController.SwayStep()` (kullanıcının katkısı bekleniyor).
- Asset Store importu sonrası: köylü modeliyle karakteri değiştirmek, tilkiyi pet olarak takip ettirmek.
- Kancaya enkaz takılması (enkaz spawn sistemi), VUR'un hedefleri, gerçek eşya ikonları.
- ~~Oyuncu karakteri~~ (yapıldı, üçüncü şahıs). Sıradaki: enkaz spawn'ı + toplama (kanca), karo ekleme UI'ı.
- Yelken/kürek: salın Rigidbody'sine kuvvet uygulayan bileşenler olacak. Yön TouchOrbit.Yaw / kamera yönünden gelecek.
- Ses floor'u, game-feel, done-gate scorecard (oynanabilir döngü oluşunca).
- Leaderboard / Remote Config kaynaklarının dashboard'da oluşturulması (insan adımı).
- Template'ten kalan `Assets/Scenes/SampleScene.unity` ve TutorialInfo silinebilir.
