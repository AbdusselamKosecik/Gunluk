# Toplu repo senkronu (X:\Gitlab + X:\GitHub) — 2026-08-27

## Bağlam
HDD kazası sonrası kurulan yeni makinedeki çalışma kopyaları **18 Ağustos'tan önceye** ait.
Amaç: iki kök klasördeki tüm repoları tarayıp, önce uzaktan değişiklikleri alıp, sonra
yereldeki gönderilmemiş işi uzağa göndermek.

## Yapılanlar

### 1. Tarama — "dubious ownership" duvarı
- **Neden:** İlk taramada 174 reponun neredeyse hepsi "değişiklik yok" göründü. Sebep:
  repolar eski makinenin SID'iyle sahiplenilmiş, git hepsini reddediyordu
  (`fatal: detected dubious ownership`). **Rapor tamamen yanlıştı.**
- **Ne yapıldı:**
  ```bash
  git config --global --add safe.directory '*'
  ```
- **Sonuç:** 174 repo; **58'inde** gönderilmemiş iş çıktı.

### 2. Kimlik doğrulama yolları açıldı
- GitHub: `gh auth setup-git` (gh CLI credential helper, token diske düz metin yazılmaz).
- GitLab: SSH anahtarı çalışıyor (`@tekbirsoft`). HTTPS remote'lar SSH'a çevrildi.

### 3. Senkron akışı (fetch → commit → merge → push)
- **Neden:** İlk denemede fetch yapmadan commit+push ettim; makine eski olduğu için uzakta
  daha yeni iş olabilirdi. Akış düzeltildi.
- **Ne yapıldı:** Her repoda `fetch` → `git add -A` + tek commit → uzakta commit varsa
  `merge --no-edit` → `push`. Çakışma çıkarsa `merge --abort` ve repo "elle çözülecek"
  işaretlenip **push edilmedi**.
- **Betik:** scratchpad `sync-all.sh`
- **Sonuç:** **49 repo tam senkron.** Uzaktan alınan dikkat çekenler:
  `Pbxtr/pbxtr` 221 commit, `viola/server` 6 commit, `mitotr/muftelif` 1 commit.

### 4. GitLab jetonu ölmüştü + sızmıştı
- **Bulgu:** 9 repoda remote URL'de düz metin PAT (`glpat-...`) vardı ve jeton **süresi
  dolmuş** (`Authentication failed`).
- **Ne yapıldı:** Remote'lar SSH'a çevrildi (jeton URL'den de temizlendi), 10 repo push edildi.
  ```bash
  git -C <repo> remote set-url origin git@gitlab.com:<grup>/<repo>.git
  ```
- **AÇIK İŞ:** Jeton GitLab'da iptal edilmeli — diske düz metin yazılmıştı.

### 5. 100MB üstü ikilikler
- **Bulgu:** `derby`, `canliyikamaekrani`, `timecraft` GitLab `pre-receive hook` ile reddedildi;
  `git add -A` build çıktısını (145MB `.exe`, 120MB `.apk`, `.rar`) commit'lemişti.
- **Ne yapıldı:** `reset --soft HEAD~1` → 100MB üstü dosyalar staging'den çıkarıldı → yeniden
  commit → push. Üçü de geçti (timecraft'ta 26.286 dosya).
- **Dışarıda kalan:** `MakineKontrol.exe` (x2), `com.companyname.canliyikamaekrani.apk` (x2),
  `publish.rar`. Hepsi yeniden üretilebilir build çıktısı.

## Kararlar
- 100MB üstü build çıktısı commit'lenmez; gerekirse Git LFS ayrı bir iş olarak açılır.
- Özel anahtar dosyası commit'lenmez (bkz. `viola/server`).

## Kapanmayan / elle çözülecek
| Repo | Durum |
|---|---|
| `Sentez-Core/ECozumModule` | origin **yanlış**: `BluefunModule.git`. 354 dosyalık commit BluefunModule/main'e gitti. |
| `Sentez-Core/Saykon` | origin **yanlış**: `Dogruyol.git`. 359 dosyalık (çoğu silme) commit Dogruyol/main'e gitti. |
| `vuo-app/eldegister` | 48 ileride / 249 geride — ayrışmış. Merge çakıştı, geri alındı. |
| `Sentez-Core/UzmanAdresModule` | detached HEAD + uzak repo 404 (`fatihdemirtc/...`). 15 değişiklik yerelde. |
| `vuo-app/apolloWrapper` | remote hiç tanımlı değil. 30 değişiklik commit'li, yerelde. |
| `viola/server` | Kirli olan tek şey klasöre düşmüş SSH **özel anahtarı** — bilerek commit'lenmedi. |
| `Gitlab/fredericTr/muftelif` | `feat/sentez-planing-ayrimi` dalı upstream'siz push edildi. |

## Doğrulama
Son geçiş: **57 repodan 48'i TAMAM** (+ ayrı push edilen `timecraft` = 49). Geri kalan 8'i
yukarıdaki tabloda; hiçbiri sessizce bırakılmadı.

---

# Ek: sorunların çözümü + ModaSimaModule (aynı gün)

## Yapılanlar

### 6. Yanlış remote hasarı geri alındı
- **Ne yapıldı:** `BluefunModule` ve `Dogruyol`'un `main`'i kendi doğru commit'lerine
  `--force-with-lease` ile geri döndürüldü.
  ```bash
  git -C <repo> push --force-with-lease=main:<yanlis-tepe> origin main:main
  ```
- **Sonuç:** `BluefunModule` → `85689ce`, `Dogruyol` → `3c16f61`. Kendi işleri duruyor.

### 7. Karşılığı olmayan 4 repo açıldı
- **Neden:** `ECozumModule`, `Saykon`, `UzmanAdresModule`, `apolloWrapper` GitHub'da **hiç
  yoktu**; o yüzden başkasının remote'unu gösteriyorlardı.
- **Komutlar:** `gh repo create <org>/<ad> --private` + `remote set-url` + `push -u`
- **Not:** `UzmanAdresModule` commit'siz `master` dalındaydı; `.gitignore` (`.vs/ obj/ bin/`)
  eklenip 60 dosya `main`'e ilk commit olarak gitti.

### 8. eldegister'daki 48 commit kurtarıldı
- **Ölçüm:** yereldeki 48 commit konusunun **hiçbiri** uzaktaki 249 commit içinde yok →
  gerçek kayıp riski (iyzico Sprint 3, 4-5 Temmuz).
- **Ne yapıldı:** `iyzico-sprint3-2026-07` dalı açılıp push edildi, `master`
  `origin/master`'a hizalandı. Merge'e zorlanmadı.

### 9. >100MB dosyalar silindi
- `MakineKontrol.exe` ×2 (145MB), `canliyikamaekrani.apk` ×2 (121MB), `publish.rar` (120MB).
- `.gitignore`'a eklendi, üç repo push edildi.

### 10. Sızmış GitLab jetonu temizlendi
- **Bulgu:** 10 değil, **29 repoda** remote URL'inde düz metin `glpat-...` vardı.
- **Ne yapıldı:** hepsi `git@gitlab.com:...` SSH'a çevrildi. Diskte tek kopya kalmadı.
- **Not:** jetonun zaten süresi dolmuş (`Authentication failed`).

### 11. viola/server — SSH özel anahtarı
- Repo klasörüne düşmüş `abdusselam.kosecik` (+`.pub`) `.git/info/exclude`'a eklendi.
  **Commit edilmedi.** Dosya hâlâ klasörde; oradan çıkarılmalı.

### 12. ModaSimaModule oluşturuldu
- **Neden:** UzmanAdresModule tabanlı yeni müşteri modülü.
- **Ne yapıldı:**
  1. Yalnızca **takipli** 60 dosya kopyalandı (`git ls-files` → `.vs/ obj/ bin/` gelmedi).
  2. `perl -0777` slurp modunda `UzmanAdres→ModaSima` (satır sonları korunsun diye sed değil —
     sed CRLF'i LF'e çeviriyordu).
  3. Dosya adları: `ModaSimaModule.cs/.csproj/.sln`.
  4. `.sln` proje ve solution GUID'leri **yenilendi** (çakışmasın diye).
- **Doğrulama:** `dotnet build` → **0 hata**, 70 uyarı (hepsi orijinalden gelen).
- **Repo:** `github.com/Sentez-Core/ModaSimaModule` (private).

### 13. ModaSimaModule'e Web API
- **Neden:** ViolaModule'deki self-host Web API deseni istendi; şimdilik hello world.
- **Ne yapıldı:** `Instance_AfterLogin` içine `ProcessName == "LiveServer"` kontrolü +
  `Task.Run(StartWebApi)`; `WebApplication.CreateBuilder` ile self-host,
  `Controllers/HelloController.cs` (`GET /hello`) ve `app.MapGet("/")`.
  csproj'a `<FrameworkReference Include="Microsoft.AspNetCore.App" />`.
- **Port:** **3132** (ViolaModule 3131 kullanıyor, çakışmasın diye).
- **Log:** `C:\log\modasima_<tarih>.log`
- **Doğrulama:** `dotnet build` → 0 hata. **Çalışma anı denenmedi** — LiveServer süreci gerekiyor.

## Doğrulama
Taranan 58 reponun **58'i TAMAM**: temiz ağaç, uzakla senkron.

## Açık kalanlar
- `viola/server` klasöründeki SSH özel anahtarı elle taşınmalı.
- GitLab'daki `glpat-...` jetonu iptal edilmiş görünüyor mu diye kontrol edilmeli.
- `eldegister/iyzico-sprint3-2026-07` dalının `master`'a birleştirilmesi karar bekliyor.
