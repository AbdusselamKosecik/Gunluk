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

## Kararlar
- Tür Raft'a benziyor ama oyun özgün: kendi hikâyesi ve kimliği olacak, Raft'a özgü öğeler kopyalanmayacak. Çalışma adı "Akinti".
- Mobil hedef: uGUI + TMP (UI Toolkit değil), Mobile kalite kademesi.
- Okyanus CPU mesh (shader değil): yükseklik C# ile birebir aynı, mobilde ~31k vertex.
- Başlıktan oyuna geçişte siyah fade yerine Cinemachine blend (2.2 s) kullanıldı. Bu, shell floor'undan bilinçli bir sapma.

## Açık kalanlar / sonraki adım
- `Waves.Current()` akıntı davranışı (kullanıcının katkısı bekleniyor).
- ~~Oyuncu karakteri~~ (yapıldı, üçüncü şahıs). Sıradaki: enkaz spawn'ı + toplama (kanca), karo ekleme UI'ı.
- Yelken/kürek: salın Rigidbody'sine kuvvet uygulayan bileşenler olacak. Yön TouchOrbit.Yaw / kamera yönünden gelecek.
- Ses floor'u, game-feel, done-gate scorecard (oynanabilir döngü oluşunca).
- Leaderboard / Remote Config kaynaklarının dashboard'da oluşturulması (insan adımı).
- Template'ten kalan `Assets/Scenes/SampleScene.unity` ve TutorialInfo silinebilir.
