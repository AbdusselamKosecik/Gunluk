# pbxtr — 2026-09-11

## Bağlam

Gün, **2026-09-10 turunun kesintisiz devamı** olarak başladı: dün gece kapıların tamamı (42/42)
ve web takımı (1725/1725) koşulmuştu; mimari takımda **bugünün kırmızısı** bulunup kapatılmıştı
(SYS-19 ayrıcalık bekçisi, `eb1d643a`). Sıra hiç koşulmamış son takımdaydı: **`Pbxtr.Api.Tests`**.

Dünün tam kaydı: `2026/09/10/pbxtr.md`.

## Yapılanlar

### 1. `Pbxtr.Api.Tests` — `Platform` dilimi yeşil

- **Neden:** dün mimari takımı ayrı koşturmak **bugünün kırmızısını** ortaya çıkarmıştı
  (`DeployPrivilegeTests`). Aynı soru `Api.Tests` için sorulmamıştı ve o takım **380 dosya**
  taşıyor. Defterdeki uyarı da net: *"API testleri parçalanmalı — tek seferde 7 GB'a çıkıp
  takılıyor; CI gibi namespace'e böl."*
- **Ne yapıldı:** takım namespace'e bölünerek koşuldu. İlk dilim:
  ```bash
  dotnet test tests/Pbxtr.Api.Tests/Pbxtr.Api.Tests.csproj --nologo -v q \
      --filter "FullyQualifiedName~Pbxtr.Api.Tests.Platform"
  ```
- **Sonuç:** **1182 test, 0 kırmızı**, 8 dk 9 sn. `Skipped: 0` — yani `RequiresDockerFact`
  atlaması bu dilimde **hiç tetiklenmedi**; ölçüm gerçekten koştu.
- **Sıradaki:** `Modules` dilimi (daha büyük) arka planda koşuyor.

### 2. `Modules` dilimi — **testhost ÇÖKTÜ ve çıkış kodu 0 döndü**

- **Ne oldu:** `--filter "FullyQualifiedName~Pbxtr.Api.Tests.Modules"` koşusu **39 dakika** sonra
  `The active test run was aborted. Reason: Test host process crashed` +
  `MSBUILD : error MSB4166: Child node "3" exited prematurely` ile bitti.
  **Kabuk çıkış kodu `0`.**
- **Defterdeki iki ders aynı anda doğrulandı:**
  *"testhost çökmesi ölçüm kaybıdır — koşu yarıda kesilip başarı gibi görünebilir"* ve
  *"API testleri parçalanmalı; tek seferde takılıyor."* Çıkış kodu `0` olduğu için, çıktı
  okunmasa **"Modules yeşil" denirdi.**
- **Çökmeden önce 6 vaka `[FAIL]` bastı** — ve altısı da isim olarak güvenlik yüzeyinde:
  `RecordingSelfListenEndpointTests.Taninmayan_kip_ERISIM_ACMAZ`,
  `RecordingTargetEndpointTests.Sir_yanitta_DONMEZ_yalnizca_hasSecret_doner`,
  `CallResultEndpointTests.Kart_alanlari_toplanan_veriden_ATILIR`,
  `TenantSettingsEndpointTests.Invalid_values_are_rejected`,
  `SlaConsistencyTests.Uc_ekran_ayni_sla_rakamini_verir`,
  `AgentOriginateEndpointTests.Canli_goruntu_varsa_yapilandirmaya_HIC_bakilmaz`.
- **İLK ÜÇÜ TEK BAŞINA KOŞTURULDU → 51/51 YEŞİL** (4 dk 20 sn, `Skipped: 0`).
  Yani bu üç kırmızı **gerçek kusur değil**, çöken/yüklü koşunun artefaktı (paylaşılan fikstür
  kalıntısı ya da sınıf ortasında ölen host). Kalan üçü ayrıca ölçülüyor.
- **Yöntem notu:** bir çökmüş koşudan çıkan kırmızı, **kanıt değil adaydır**. Her birini yalıtıp
  tekrar koşmadan "kusur" demek, bugün defalarca eleştirdiğim yanlış-kırmızı sınıfının ta kendisi
  olurdu.

### 3. Altı kırmızının **altısı da** yalıtımda yeşil — hepsi çökme artefaktı

- Kalan üç sınıf da tek başına koşuldu: **110/110 yeşil**, 10 dk 40 sn, `Skipped: 0`.
- **Toplam: 161 test, 0 kırmızı.** Yani çöken koşunun ürettiği **altı kırmızının altısı da**
  gerçek kusur değildi.
- **Bunun anlamı iki yönlü:**
  (a) `Modules` diliminde **bugüne kadar bilinen bir kusur yok**;
  (b) ama dilim **hâlâ bir bütün olarak ölçülmedi** — çökmeden önce kaç vaka koştuğu bile
  bilinmiyor. *"161 yeşil"* bir dilim ölçümü değildir.
- **Yöntem kararı:** dilim, deponun kendi yaptığı gibi **parçalara** bölünerek koşulacak
  (`api-test-shards.py` üretimde 4 shard kullanıyor). Burada modül klasörlerine göre dört grup:
  1. `Access, AgentDesk, Analytics, Announcements, Automation, CallHistory, Campaigns`
  2. `Compliance, Contacts, Dashboard, Dialer, Ivr, Leaves, Licensing`
  3. `Live, Media, Messaging, NetworkQuality, Provisioning, Queues, Realtime`
  4. `Recordings, Reports, ResultCodes, Scripter, Security, Support, SystemAdmin, Telephony, Tenancy`
  Grup 1 arka planda koşuyor.

### 4. `Pbxtr.Api.Tests` bir bütün olarak ölçüldü — **4864 vaka, sıfır kırmızı**

Dilim dörde bölünerek koşuldu; çökme **tekrarlamadı** (en yüklü grupta `testhost` 3,9 GB'ta
kaldı — defterdeki *"tek seferde 7 GB'a çıkıp takılıyor"* eşiğinin altında).

| dilim | vaka | süre | atlanan |
|---|---|---|---|
| `Platform.*` | **1182** | 8 dk 09 sn | 0 |
| Modules grup 1 — Access…Campaigns | **577** | 13 dk 25 sn | 0 |
| Modules grup 2 — Compliance…Licensing | **318** | 6 dk 18 sn | 0 |
| Modules grup 3 — Live…Realtime | **551** | 4 dk 19 sn | 0 |
| Modules grup 4 — Recordings…Tenancy | **2071** | 31 dk 23 sn | 0 |
| kalan — Wallboard, WorkingHours, `HealthEndpointTests`, `Support` | **165** | 6 dk 42 sn | 0 |
| **TOPLAM** | **4864** | ~70 dk | **0** |

- **Ve son grup bitmeden kendi filtremi denetledim** — iyi ki: `Modules/` altında **`Wallboard`
  ve `WorkingHours`** dört grubun **hiçbirine** girmiyordu; kök seviyedeki `HealthEndpointTests.cs`
  ile `Pbxtr.Api.Tests.Support` namespace'i de ne `Modules.` ne `Platform.` filtresine giriyordu.
  Dördü ayrı koşuldu (**165/165**). *"Envanter sayacı kendi filtresini ölçmez"* dersi:
  denetlemeseydim **dört alan sessizce ölçülmemiş** kalacak, ben de *"Api.Tests yeşil"*
  diyecektim.
- **`Skipped: 0` her dilimde:** yani `RequiresDockerFact` atlaması hiçbir dilimde tetiklenmedi;
  ADR-012 R-3'ün *"atlama sessizdir"* uyarısı bu koşular için geçerli değil — ölçüm gerçekten
  koştu.
- **Kapanan soru:** dün başlayan tur artık tam: **42/42 kapı**, **web 1725/1725**,
  **mimari 446/446** (bugünün kırmızısı bulunup kapatıldı), **Api.Tests 4864/4864**.
  Ölçülemeyen tek küme: `Pbxtr.Integration.Tests` (gerçek PostgreSQL + Docker ister) ve
  Docker'a bağlı 5 kapı + 2 `gitleaks` kapısı.

## Açık kalanlar / sonraki adım
- `Pbxtr.Integration.Tests` ve Docker'a bağlı kapılar **kullanıcıdaki Docker maddesine** bağlı.
- Dünden devreden kullanıcı işleri değişmedi: `/basla pbxtr sprint-44`, `BR-AST-60` originate
  onayı (ölçüm artık **dahiliye** indirgendi), **A-2** (t0012 düğüm pini), `BR-SEC-16` rotasyon
  kararı (bedeli ölçüldü: tek anahtar).

### 5. Yayın yolunun iki sessiz kapısı: `tsc -b` **yeşil**, `dotnet format` **112 sapma**

- **Neden:** defterde iki not var — *"`tsc --noEmit` yayın kapısı değil; yayın imajı `tsc -b` ile
  kırılır"* ve *"`dotnet format` beş dosyada sapma buldu; **o araç da hiç koşmamış**"*. İkisi de
  yayın yolunda koşan ama gündelik akışta koşulmayan kapılar.
- **`npx tsc -b` → rc=0.** Yani TypeScript proje derlemesi temiz; `tsc --noEmit`'in görmediği
  test `tsconfig`'i dahil.
- **`dotnet format --verify-no-changes` → 112 bulgu, 8 dosya.** Dağılım tamamen **bugünün/dünün
  yeni işi** (Asterisk konsolu + sistem-ops):

  | bulgu | dosya |
  |---|---|
  | 47 | `Tests/AsteriskConsoleTenantQueueTests.cs` |
  | 23 | `Pbxtr.Architecture.Tests/SystemAgentCallSiteTests.cs` |
  | 18 | `SystemAdmin/AsteriskConsoleAuditTests.cs` |
  | 9 | `Telephony/Asterisk/AmiAsteriskConsole.cs` |
  | 5 | `SystemOps/SystemCommandRunner.cs` |
  | 4+3+3 | `SystemFileObservationTests`, `BackupStatusReader`, `SystemObservationCommandRunnerTests` |

- **Değişikliğin cinsi ölçüldü:** `git diff -w` **hâlâ fark gösteriyor** (65/27) — yani düzeltme
  saf boşluk değil: `using` sıralaması ve ayraç yerleşimi de değişti (ör. `BackupStatusReader`'da
  `file = file with { … }` çok satırlı bloğa çevrildi). **Anlamsal değişiklik yok.**
- **Doğrulama:** `dotnet build` → **0 uyarı, 0 hata**; ardından
  `dotnet format --verify-no-changes` → **0 bulgu**.
- **Ve asıl bulgu düzeltme değil, tekrar:** `d66684a6`'da (dün) aynı araç *"beş dosyada sapma
  buldu — o araç da hiç koşmamış"* diye kaydedilmişti. Bir gün sonra **112 bulgu**. Yani sapma
  **her yeni işte sessizce birikiyor** ve tek fark eden şey, birinin aracı elle koşturması.
  `BR-QA-54`'ün (bağlanmamış araçlar) kardeşi; oraya not düşülmesi gereken üçüncü araç bu.
- **Commit:** `f1dbbf46`

### 6. Görsel sadakat kapısı **20 gündür kırık** — ve onu ekleyen commit kırmış

- **Neden bakıldı:** `dotnet format`'tan sonra simetrik soru: web tarafında da elle koşulan,
  kapıya bağlanmamış bir araç var mı? `package.json` iki tane gösterdi:
  `test:fidelity:verify` ve `test:fidelity:selftest`.
- **Öz-test yeşil:** *"visual baseline mutants rejected"* — doğrulayıcı **çalışıyor**.
- **Doğrulayıcı KIRMIZI:** `content hash mismatch for
  visual-tests/__screenshots__/dashboard-live-1440x900.png`. Üç tabandan **biri** tutmuyor
  (`0f3d690db218…` ≠ `bcd2256fbad1…`); diğer ikisi eşleşiyor. `git diff --stat HEAD` boş →
  sapma **commit'li durumda**, Windows artefaktı değil, Linux'ta da kırmızı verir.
- **Kronoloji ölçüldü ve öğretici:**

  | saat | commit | ne oldu |
  |---|---|---|
  | 16:07 | `d5fee96d` | *"ci: enforce root trust and **visual fidelity gates**"* — manifesto eklendi |
  | 18:35 | `add3899a` | UI metni işi; ekran görüntüsü **yeniden üretildi**, hash **güncellenmedi** |

  **Kapı, eklendikten iki buçuk saat sonra kırıldı ve 20 gündür kırık.**
- **Neden kimse görmedi:** `test:fidelity:verify` **hiçbir kapıdan çağrılmıyor** —
  `deploy/*.sh` + `deploy/ci/*.py` taramasında **0 isabet**. `BR-QA-54`'ün (bağlanmamış araçlar)
  **dördüncü** kalemi.
- **Tek taraflı düzeltmedim, sebebi kartta:** çare hash'i güncellemek, ama bu **bugünkü ekran
  görüntüsünü doğru taban ilan etmek** demek — ve bu bir **görsel yargı**. Doğrulayıcı yalnız PNG
  imzası, 1440×900 boyut ve >10 KB ölçüyor; görüntünün **doğru render olduğunu** ölçmüyor.
  Playwright akışı tarayıcı istiyor ve bugün koşulamadı.
- **`BR-QA-55` (P2) açıldı**, panoya işlendi (`fark: 0`), atıf denetimi temiz.

### Görsel sadakat kapısı — ikinci ölçüm: Playwright koşuldu, iki iddiam düzeldi

- **Neden devam edildi:** yukarıdaki maddede *"düzeltme görsel yargı ister"* diye bırakmıştım.
  Yargıyı **Playwright'a** verdirmeyi denedim: hash'i tutmayan `dashboard-live` tabanı piksel
  karşılaştırmasından geçerse taban sadıktır, kalırsa değildir.
- **Koşu:** `npx playwright test` (Windows, chromium) → **3/3 kırmızı.**
- **Ve tam da bu yüzden hakemlik edemedi:** kırmızıların **ikisi hash'i TUTAN** tabanlar
  (`dashboard-prototype`, `login`). Hash'i doğru olan bir taban piksel karşılaştırmasında
  düşüyorsa ölçülen şey arayüz değil, **render ortamıdır**.
- **Sebep bulundu — tabanın platformu:**

  | kanıt | değer |
  |---|---|
  | `playwright.config.ts:11` | `snapshotPathTemplate: '{testDir}/__screenshots__/{arg}{ext}'` — varsayılandaki **`{platform}` düşürülmüş** |
  | `d5fee96d:.github/workflows/ci.yml` | Frontend işi **`runs-on: ubuntu-24.04`**, *"Görsel fidelity: baseline ve mutant kapısı"* adımı orada |
  | boyutlar | beklenen/gerçek **ikisi de 1440×900** |
  | bayt farkı | 43024→44049 ve 75677→77154 (**~%2**) → yerleşim değil, **metin rasterizasyonu** |
  | tarayıcı | `playwright-core/browsers.json` chromium **rev 1193 / 140.0.7339.186**, kurulu; her iki taban commit'inde pin `^1.55.1` → **değişken değil** |

  Tek taban + `maxDiffPixels: 0` + platform yok = tabanı üretmeyen her makinede **kalıcı kırmızı.**
- **DÜZELTME 1 — "iki buçuk saat sonra kırıldı" yanlıştı.** `git ls-tree -r d5fee96d` ile
  ölçtüm: o commit manifestoya **üç** taban yazdı ama ağacında **yalnızca
  `login-desktop-dark.png` vardı**. `verify-visual-baselines.mjs:30` eksik dosyada `readFile`
  ile fırlatır (fail-closed) → `test:fidelity:verify` **daha ilk gün `ENOENT`** veriyordu.
  **Kapı doğduğu an kırıktı**; bayat hash sonradan üstüne bindi.
  Yan bulgu: `add3899a`'da gelen iki PNG'den `dashboard-prototype` manifestoyla **tuttu**,
  `dashboard-live` **tutmadı** — hash'ler geliştirici makinesindeki dosyalardan önceden
  alınmış, ikisi yeniden üretimden sağ çıkmış, biri çıkmamış.
- **DÜZELTME 2 — `dashboard-live` ekran görüntüsüne HİÇ ULAŞMIYOR.** O koşuda
  `dashboard-live-1440x900-actual.png` **üretilmedi**: test `toHaveScreenshot`'tan **önce**
  düşüyor. `visual-tests/dashboard-live.visual.spec.ts:74` birebir
  `"Widget'ları sürükleyerek düzeni değiştirin"` bekliyor; **bu dize kaynakta hiç yok**
  (`grep "düzeni değiştirin" src/Pbxtr.Web/src` → 0). Bugünkü arayüz
  `dashboard.reorderHint` = *"Widget'ları sürükleyerek ya da tutamağa odaklanıp ok tuşlarıyla
  sıralayın"* çiziyor (`i18n/messages/tr.json:908`) — klavyeyle sıralama erişilebilirlik
  işinden gelen değişiklik. Kırık koşunun `error-context.md:64`'ü satır satır gösteriyor.
  İkinci ve bağımsız uyuşmazlık: test düz `'`, ürün tipografik `'` kullanıyor.
- **Asıl sonuç:** hash'i güncellemek **tek başına yanlış çözüm olurdu.** `dashboard-live`
  tabanı, widget ızgarası **tutamak düğmeleri kazanmadan önce** alınmış; hash'i bugünkü PNG'ye
  çekmek **eskimiş bir arayüzün fotoğrafını "doğru taban" ilan etmek** olurdu.
- **Komutlar:**
  ```bash
  npx playwright test                      # 3/3 kirmizi
  git ls-tree -r --name-only d5fee96d -- src/Pbxtr.Web/visual-tests/__screenshots__/
  git show d5fee96d:.github/workflows/ci.yml | grep -B8 fidelity
  grep -rn "düzeni değiştirin" src/Pbxtr.Web/src        # 0 isabet
  ```
- **`BR-QA-55` kapsamı büyüdü:** (e) sapmış metin iddiası `dashboard.reorderHint`'e çekilir
  — tercihen dizeyi elle yazmak yerine `tr.json`'dan okuyarak, aksi hâlde aynı sapma üçüncü
  kez olur — ve **taban PNG yeniden üretilir**, hash aynı commit'te güncellenir;
  (f) `snapshotPathTemplate`'e `{platform}` geri konur **veya** kapı yalnızca
  `yerel-kapilar.sh`'in ubuntu konteynerinde koşacak biçimde bağlanır.
- **Commit:** `456de0a7` — *olcum: gorsel sadakat kapisi DOGDUGU AN kirikti; piksel farki ise ORTAM*

## Kararlar (ek)

- **"Koşmayan kapı bulgu değildir"in ikizi yazıldı: "hep kırmızı kapı" da kapı değildir.**
  Tek taban + `maxDiffPixels: 0` + platform ayrımı yok bileşimi, kapıyı ya hiç koşulmaz ya da
  koşulduğunda hep kırmızı yapar; ikisi de kapıyı fiilen kaldırır.
- **Hakem seçerken önce hakemi ölç.** Piksel karşılaştırmasını taban sadakatine hakem yaptım;
  hakemin kendisi ortamdan etkileniyordu. Kontrol grubu (hash'i **tutan** iki taban) olmasaydı
  `dashboard-live`'ı haksız yere "sapmış" ilan edecektim.

### CI göçünün tam farkı — kalemleri tek tek keşfetmeyi bıraktım, envanteri bir kerede aldım

- **Neden:** `BR-QA-54` (bağlanmamış araçlar) üç kalemle açılmıştı, `BR-QA-55` dördüncüyü ekledi.
  Beşinciyi de keşifle bulmak yerine **bütün envanteri** ölçtüm: hangi doğrulayıcı hangi
  kapıdan çağrılıyor?
- **Yöntem:** `5bc08dd9` (*"ci: GitHub Actions kaldirildi, 27 kapi depoya tasindi"*) öncesindeki
  `ci.yml`'de anılan depo betiklerini çıkardım, bugünkü `yerel-kapilar.sh` + `yerel-yayin.sh` +
  `test-kos.sh` + `yerel-kapilar.Dockerfile` metniyle karşılaştırdım.

  | | |
  |---|---|
  | eski CI'da anılan depo betiği | **30** |
  | bugünkü kapılarda anılan | **21** |
  | taşınmayan | **9** — biri kasıtlı silinmiş (`integration-workflow-contract-test.rb` → `integration-yayin-contract-test.py`), **8'i duruyor ve çağrılmıyor** |

  Beşinin adı depoda **başka hiçbir dosyada geçmiyor** — belge dâhil. **13 gündür ölçüm yok.**
- **Beş öz-test koşturuldu: 2 yeşil, 3 kırmızı — ve üçü aynı şey değil.**
  - `s30-live-proof-test.py` → `AttributeError: os.geteuid`
  - `s30-build-live-config-test.py` → `ValueError: canonical journal path drift`; sebebi
    `s30-build-live-config.py:31`'in `str(pathlib.Path(base)/run/"resource.json")` ile POSIX
    dizesini karşılaştırması — **Windows'ta ayraç ters döner.**
  - **İkisi de ortam artefaktı, kusur değil.** *"Araç yokluğu bulgu değildir"* dersinin bir
    örneği daha; bunlar konteyner kapısı olarak işaretlenmeli, atlanmamalı.
- **Üçüncüsü gerçek: `st44-role-matrix.json` ölü bir fotoğraf.** Son üretim **2026-08-22**
  (`5d6bfce3`). Üreticinin bugünkü çıktısıyla tutmuyor (20142 vs 15734 bayt) ve dosyanın
  **kendi içine gömdüğü üç kaynak hash'inin ÜÇÜ DE** sapmış: `screens.json` (09-06),
  `permissions.seed.json` (09-10), `delivery-manifest.json` (09-06).
- **Öncülü ölçmeden yazmadım — ve iyi ki:** rol→ekran sayıları korkutucu görünüyordu
  (superadmin **55→22**, admin 38→25, bayi 19→4). "Superadmin 33 ekran kaybetti" diye
  yazacaktım. Sebebi ölçtüm: seed'de bundle sayısı **17→27**, superadmin'in bundle listesi
  **17 kalemden 6'ya** indirilmiş — **en az yetki işinin kasıtlı sonucu.** Fikstür o işten
  **önceki** dünyayı fotoğraflamış. **Ürün regresyonu değil, ölü fikstür.**
- **İkinci ve ayrı kusur — üretici yetki kuralını eksik uyguluyor.**
  `s30-canonical-fixtures.py` görünür ekranı yalnız `x["permission"] in granted` ile seçiyor.
  Ama `screens.json`'da **9 ekran `permissionsAll` taşıyor** ve o alan **ek bir VE koşulu**
  (`agent-desk`: `permission=call.handle` **+** `permissionsAll=['agent.self.read']`).
  Fazla-sayım ölçüldü: **owner 39→38, süpervizör 34→33**. Bugün küçük, ama **kural yanlış** —
  ve defterdeki *"ekran yetkisi iki alanda durur"* dersinin **üçüncü** örneği.
  Önce düzeltilmezse, bayat fikstürü **doğru sanılan** bir fikstürle değiştirmiş oluruz.
- **Komutlar:**
  ```bash
  git show 5bc08dd9~1:.github/workflows/ci.yml   # eski kapi listesi
  python deploy/st44/s30-canonical-fixtures-test.py
  git log -1 --format=%ad --date=short -- deploy/st44/st44-role-matrix.json
  ```
- **`BR-QA-56` (P2) açıldı** ve panoya işlendi (`377 kart`, `fark: 0`). Kapsam: (a) üreticiye
  `permissionsAll` + negatif test; (b) sonra fikstürleri yeniden üret; (c) 8 betik ya kapıya
  bağlanır ya ST-44 izi kapandıysa kaldırılır; (d) POSIX bağımlı ikisi konteyner kapısı olur.
- **Commit:** `8e867c46` — *olcum: CI kaldirilirken 8 ST-44 betigi sahipsiz kaldi (BR-QA-56)*

### Dersi hemen uyguladım: yetki kuralını çoğaltan yerleri taradım

- **Neden:** yukarıdaki bulguda hafızaya *"bu kuralı kendi ölçümümde uygulamak yetmez,
  depodaki her yetki okuyucusunu taramak gerekir"* diye yazdım. Yazıp bırakmak, kararı
  yazıp uygulamamanın ta kendisi olurdu — bu projenin baskın hata deseni.
- **Tarama:** `permissionsAll`'ı **bilen** 20 dosya ile `screens.json`'dan rol→ekran kararı
  **veren** dosyaları kesiştirdim.
- **Sonuç — kuralı çoğaltan yalnız iki yer var:**
  1. `deploy/st44/s30-canonical-fixtures.py` (yukarıda; **etkin** fazla-sayım)
  2. `tests/Pbxtr.Integration.Tests/Delivery/RoleScreenProofPlan.cs:161` — gizli
     (`inMenu:false`) ekranlar için `screen.Permission is null || identity.Permissions
     .Contains(screen.Permission)` diye **elle** hesaplıyor, `ScreenRegistry.IsVisible`
     yerine. O metodun **kendi belge yorumu** (`ScreenRegistry.cs:115-118`, Karar #23
     §Ş23-5) tam da bunu yasaklıyor: *"Yalnızca `Permission`'a bakan bir dal bırakılırsa
     menü ile 403 kararı ayrışır."*
- **Ve etkiyi ölçtüm — bugün SIFIR.** `permissionsAll` taşıyan **gizli** ekran iki tane
  (`tenant-documents` → `tenant.self.read`, `dealer-tickets` → `ticket.inbox.dealer`) ve
  **yedi rolün hiçbirinde** iki kural ayrışmıyor. Yani **gizil** bir kusur: bir role
  `tenant.read` verilip `tenant.self.read` verilmediği gün plan "görünür" der, ürün 403
  döner ve kanıt koşusu **yanlış tarafı** suçlar. "Bugün sıfır" ile "sorun yok" aynı şey
  değil; kartta ikisi de yazılı.
- **İyi haber de kayda geçti:** `AppSidebar.tsx` yetki kararı **hiç vermiyor** — menüyü
  `/me/menu`'den hazır alıyor (doğru mimari), ve `RoleScreenMatrixTests.cs:149` zaten
  `ScreenRegistry.IsVisible` kullanıyor.
- **`BR-QA-56` kapsamına (e) eklendi.**
- **Commit:** `8f00b8a3` — *olcum: yetki kuralini cogaltan ikinci yer bulundu — bugun zararsiz, gizil*

### Sınıfı kapattım: envanter artık depo geneli — ve tarayıcım iki kez yanıldı

- **Neden:** bağlanmamış araç kalemleri üç turdur tek tek çıkıyordu (3 → 4 → 8). Kalem
  toplamayı bırakıp **sınıfı kapatmak** gerekiyordu.
- **Kapsam hatam:** `BR-QA-56`'nın taraması `deploy/` + `src/Pbxtr.Web/scripts` ile sınırlıydı;
  **`yonetim/arac/` hiç görünmüyordu.** Depo geneline çıkardım (`node_modules`/`obj`/`bin`/`doc`
  hariç).

  | | |
  |---|---|
  | adı `test\|verify\|dogrula\|kapi\|guard\|check\|olc` içeren çalıştırılabilir doğrulayıcı | **51** |
  | kapıdan çağrılan | **29** |
  | hiçbir yerde anılmayan | **8** |

- **Yeni çıkanlar:** `yonetim/arac/clickup-durum.test.js` ve `clickup-kart-farki.test.js` —
  **bugün koşuldu, 6/6 ve 4/4 YEŞİL**, yani sağlam ama sahipsiz. ClickUp durum eşlemesi
  (CLAUDE.md §14) bir daha bozulursa kimse ölçmez. Bir de `deploy/e09-yuk-olcum.sh`
  (yük ölçüm aracı, öz-test değil — elle koşulması meşru).
- **Kendi tuzağıma da düşmüşüm:** `yonetim/arac/kart-atif-dogrula.js` **yalnız `backlog.md`
  ve `rows.json`'da anılıyor** — yani bir **kartta yazılı**, hiçbir yerden **çağrılmıyor**.
  *Belgede anılmak bağlanmak değildir.*
- **TARAYICIM İKİ KEZ YANILDI — ikisi de kayda değer:**
  1. **`.cs` dosyalarını çağırıcı saymamıştım.** `s28-acceptance-preflight-test.sh` ve
     `st48-kilit-test.sh` "sahipsiz" göründü. Yanlış: **ikisi de C# mimari testinden koşuyor**
     (`S28AcceptancePreflightTests.cs:14`, `St48EgressDeployTests.cs`).
  2. **"Dosya kendi adını anar" varsayıp `>1` eşiği koymuştum.** Bir `.sh` kendi adını anmaz;
     tek gerçek çağırıcısı olan dosyalar **sıfır** sayıldı. Düzeltme: dosyanın kendisini
     metinden çıkar, `>0` ara.
- **Bunun bir yan faydası var:** **kabuk kapısını xunit'ten koşmak meşru ve mevcut bir bağlama
  yolu.** `dotnet test` zaten yayın yolunda koşuyor; `BR-QA-56`'nın (c) maddesi uygulanırken
  `yerel-kapilar.sh` yerine bir `*Tests.cs` de seçenek olarak yazıldı.
- **Komut:**
  ```bash
  node yonetim/arac/clickup-durum.test.js        # pass 6  fail 0
  node yonetim/arac/clickup-kart-farki.test.js   # pass 4  fail 0
  ```
- **Commit:** `4403a1ba` — *olcum: baglanmamis arac sinifi KAPATILDI — envanter artik depo geneli*

## Kararlar (ek 2)

- **Kalem toplamayı bırak, sınıfı kapat.** Aynı sınıftan üçüncü kalem çıktığında doğru hamle
  dördüncüyü aramak değil, **evreni tanımlayıp tamamını ölçmek**tir. Üç turda 3→4→8 diye
  büyüyen liste, tek ölçümde 51/29/8 diye kapandı.
- **Bir envanter aracının kendi evreni de ölçülmelidir.** Tarayıcım iki kez yanlış "sıfır"
  üretti ve ikisi de **yeşile benziyordu** — defterdeki *"araç yokluğu sıfır gibi görünür"*
  ile aynı sınıf. Kontrolü, sonucu bildiğim bir dosyayla (`s28`) yaptım; o olmasaydı iki
  yanlış envanter karta girecekti.

### `BR-AST-40`'ın önkoşulunu ölçtüm — ve bir kartın iddiası çürüdü

- **Neden bu kart:** "karar bekleyen" kartlar arasında **kendi önkoşulunu yazan** tek kart buydu:
  *"Önce ölç: confd bugün hangi biçimi gönderiyor?"* Kararı tıkayan şey bir onay değil, bir
  **ölçüm eksiğiydi** — ve onu ben yapabilirim.
- **Depoda iki üretici, iki ayrı biçim:**

  | üretici | biçim | yol |
  |---|---|---|
  | `pbxtr-confd-cek.sh:145` | **öneksiz** — `queues=1` | tek tenantlık `/bundle` |
  | `pbxtr-confd-dugum.sh:370` | **tenant önekli** — `t0007/queues=12` | çok tenantlı `/node-bundle` |

  Yani **daraltmanın hedefi olan öneksiz girdiyi, çok tenantlı istemci zaten hiç üretmiyor.**
- **Canlı ölçüm (salt-okuma, `root@176.88.41.220`):** birim `ExecStart` **`pbxtr-confd-cek.sh`**
  gösteriyor; kurulu o dosya **225 satır** ve içinde `X-Pbxtr-Have` **0 eşleşme**. Fiilen
  gönderdiği başlık **üç tane**: `X-Pbxtr-Key`, `X-Pbxtr-Node`, `X-Pbxtr-Asterisk-Version`.
  `/etc/pbxtr/confd/revizyonlar` defteri de **yok**.
- **Sonuç: karar ucuzladı.** Bugün daraltmak **hiçbir istemcinin davranışını değiştirmez**;
  kart bir davranış değişikliği değil, bir **sürpriz kaldırma** işi ve ajan sürümü gerektirmiyor.
- **KEŞİF GİBİ SUNMADIM — bu üçüncü kez düştüğüm tuzak.** Yazmadan önce backlog'a baktım:
  kurulu betiğin `X-Pbxtr-Have` taşımadığı **`BR-SYS-73`'te zaten yazılı** (*"altısı da SIFIR
  eşleşme"*), `BR-SYS-76`/`BR-SYS-80`/`BR-SYS-86` aynı sapmayı taşıyor. Karta *"bu bir keşif
  değil, teyit"* diye yazdım; yeni olan yalnızca bugünkü doğrulama ve başlıkların tam listesi.
- **Ama bir kartın ölçülmüş iddiası ÇÜRÜDÜ:** `BR-SYS-86` *"`pbxtr-confd-dugum.sh` sunucuda
  YOK"* diyor (07 Eylül ölçümü). **Bugün VAR:** 1743 satır / `9561d431` — depodaki 1745 satır /
  `0399fafc`'den hâlâ **2 satır sapıyor**. Yani birileri 07 Eylül'den sonra taşımış.
  **Ama devreye alınmamış:** birim hâlâ eski istemciyi koşuyor. Bugünkü hâl *"ajan yok"* değil,
  **"ajan var, kimse açmamış"** — ve bu hiçbir yere yazılmamıştı.
- **`BR-SYS-80`'in rakamı da tazelendi:** kart *"depo 560 satır"* diyor, bugün **654**.
- **Komutlar:**
  ```bash
  ssh root@176.88.41.220 'systemctl cat pbxtr-confd | grep ExecStart'
  ssh root@176.88.41.220 'grep -c X-Pbxtr-Have /usr/local/lib/pbxtr/pbxtr-confd-cek.sh'   # 0
  ssh root@176.88.41.220 'grep -o "X-Pbxtr-[A-Za-z-]*" /usr/local/lib/pbxtr/pbxtr-confd-cek.sh | sort -u'
  ```
- **Commit:** `3bb500d4`

## Kararlar (ek 3)

- **"Karar bekleyen" kartların bir kısmı onay değil ÖLÇÜM bekliyor.** `BR-AST-40` kararı
  kilitleyen şeyi kendi metnine yazmıştı ve o iş bana açıktı. Karar kuyruğunu tararken ilk
  soru "kim onaylayacak" değil, **"bu karar hangi ölçüm gelmeden verilemez"** olmalı.
- **Sunucu ölçümlerinin bir tazelik ömrü var.** `BR-SYS-86`'nın 07 Eylül ölçümü dört günde
  çürüdü, çünkü sunucuya **depo dışından** dokunuldu. Sunucuya dayanan her kart iddiası
  tarihiyle yazılmalı ve ona dayanıp iş planlamadan önce **yeniden ölçülmeli.**

### Tazelik dersini uyguladım: üç kartın imaj önkoşulu düştü, bir ölçüm yöntemi kusurlu çıktı

- **Neden:** bir önceki maddede *"sunucuya dayanan her kart iddiası yeniden ölçülmeli"* diye
  yazdım. `BR-AST-49` (07 Eylül ölçümü, "karar bekleyen") ile başladım.
- **`BR-AST-49` — belirti değişti, sapma duruyor.** 07 Eylül'de *"her tick
  `Rejected/NO_SUCH_QUEUE` tekrarlıyor"* yazıyordu. **Bugün o satır yok.** Yerine bir **teşhis**
  var (`QueueMembershipSyncJob.cs:863`, `baf8d3b6`, 2026-09-06):

  > *t0012 hiçbir pbxtr-confd düğümüne ATANMAMIŞ (pinli aktif API anahtarı yok). Config
  > üretiliyor ama HİÇBİR santrale teslim edilmiyor; kuyruklarının santralde olmaması
  > BEKLENEN SONUÇTUR. Müdahale: #57 ekranından düğüme pinli bir anahtar üretin.*

  24 saatte **5 satır**, "her tick" değil. Sağlıklı taraf da ölçüldü: *"santralde eksik olan
  9 kuyruk üyeliği eklendi"*. Santralde 3 kuyruk var, üçü de `t0007-*`; `t0012` **0 eşleşme**.
  **Sapmanın kendisi duruyor; değişen şey görünürlüğü** — kartın sınıfı "sessiz sapma"dan
  "kullanıcı işlemi bekleyen teşhis edilmiş durum"a (A-2) geçti.
- **Sonra bir çelişki yakaladım.** Çalışan imajın o kodu taşıyıp taşımadığına baktım:
  `grep -ac ATANMAMIS /app/Pbxtr.Infrastructure.dll` → **0**. Ama o satır **canlı günlükte
  basılıyor.** İki şeyden biri yanlıştı; kontrol grubu koştum.
- **Yöntem kusurlu çıktı — ve sebebi öğretici:**

  | dize | ASCII `grep` | NUL-sıyırmalı | gerçek |
  |---|---|---|---|
  | `ATANMAMIS` (dize sabiti) | **0 / 0** | 1 / 1 | VAR |
  | `queue-membership-sync` (dize sabiti) | **0 / 0** | 4 / 0 | VAR (günlükte) |
  | `RemovedBasis` (özellik adı) | 1 / 1 | 2 / 2 | VAR |
  | `ZZZ_OLMAYAN_DIZE` (negatif kontrol) | 0 / 0 | 0 / 0 | YOK ✓ |

  .NET ikilisinde **tip/üye adları** `#Strings` yığınında ve **UTF-8**'dir — ASCII `grep`
  görür; **dize sabitleri** `#US` yığınında ve **UTF-16**'dır — ASCII `grep` **hiç göremez**.
- **VE BUNUN ÜÇ KARTA DOKUNAN BİR SONUCU VAR.** `BR-SYS-80`/`BR-SYS-86`'nın dayandığı
  *"koşan imaj `RemovedBasis` taşımıyor (sayım 0)"* iddiasını yeniden ölçtüm — **artık doğru
  değil.** Çalışan imaj `tekbirsoft/pbxtr:demo-d66684a676ce`, **2026-09-08T07:58Z** üretimi,
  yani kartlar yazıldıktan **bir gün sonra**. Doğrulayıcılar: `ProvisioningRemovalManifest`
  1/1, `AcknowledgedRevisions` 1/0, `removedBasis` + `previous_revision` + `node_declared`
  Infrastructure'da 1/1/1.
  **`BR-SYS-80`'in tarif ettiği DÖNGÜ KIRILDI:** (1). adım (`RemovedBasis` taşıyan imajı
  yayınla) **zaten yapılmış**; kalan yalnız (2) betiği taşı + `ExecStart`'ı çevir. Kapının
  bloklama dalı (`sayım = 0`) artık ateşlemiyor, `PBXTR_CONFD_SAPMA=0` atlama gerekçesi de düştü.
- **`BR-SYS-96` (P2) açıldı** — kapı bugün doğru cevabı **doğru sebeple değil**, seçtiği
  kelimenin türü sayesinde veriyor: `RemovedBasis` bir **özellik adı**. Kontrol bir gün bir
  **mesaj metnine** çevrilirse kapı sessizce hep `0` der ve `BR-SYS-83`'ün kapattığı tuzağın
  aynısını yeniden açar — o kart `strings` yokluğunu ve `grep -c` çıkış kodunu düzeltti,
  **kodlamayı** hiç ele almadı. Bu bir regresyon değil, o kartın **kapsam boşluğu**.
- **Komutlar:**
  ```bash
  ssh root@176.88.41.220 'docker exec pbxtr-app sh -c "tr -d \"\000\" < /app/Pbxtr.Api.dll | grep -c RemovedBasis"'
  ssh root@176.88.41.220 'docker logs --since 24h pbxtr-app 2>&1 | grep -c queue-membership-sync'
  ssh root@176.88.41.220 'docker exec pbxtr-asterisk asterisk -rx "queue show"'
  ```
- **Commit:** `988ba551`

## Kararlar (ek 4)

- **Bir ikiliyi `grep` ile sorgulamak bir KODLAMA sorusudur.** .NET'te ne aradığın (üye adı mı,
  dize sabiti mi) hangi yığında olduğunu ve hangi kodlamada durduğunu belirler. Bundan sonra
  her ikili ölçümü **pozitif + negatif kontrolle** koşulacak; ikisi beklendiği gibi çıkmazsa
  sonuç "imaj taşımıyor" değil **"yöntem bozuk"** diye okunacak.
- **Çelişkiyi görmezden gelme.** "Günlükte var ama ikilide yok" cümlesi imkânsızdı; onu
  kovalamak üç kartı düzeltti. Ölçüm birbirini tutmuyorsa hikâye yazma, yöntemi ölç.

### `BR-SYS-96` (c): kalıp tek yerde — ve aynı sınıftan iki homoglif kaçağı

- **(c) maddesi ölçüldü:** depoda ikili içeriği tarayan **başka betik yok**. `deploy/` altındaki
  tüm `.sh`/`.py`/`.rb` içinde `strings` / `grep -a` / `.dll` geçen satırlar tarandı;
  `RemovedBasis` ölçümü dışındaki her isabet ya bir **yorum** (`module reload res_pjsip.so`
  açıklamaları), ya bir **çalıştırma** (`dotnet Pbxtr.Api.dll migrate`), ya bir **fikstür yolu**
  (`test-kos-yayin-test.py:83`). Kusur tek noktada; (a)+(b) kapsamı tamamen kapatıyor.
- **Yan bulgu — aynı sınıf, farklı yüzey: Kiril homoglif kaçakları.** `backlog.md` tarandı,
  **iki** kaçak bulundu ve düzeltildi:

  | dize | kaçak | nerede |
  |---|---|---|
  | `bosluguдur` | Kiril **`д`** | bugün **benim** yazdığım `BR-SYS-96` metninde |
  | `iki blogа` | Kiril **`а`** | önceden var olan bir kartta |

  Bu, kartın ana bulgusuyla birebir aynı sınıf: aranan dize ile depodaki dize **göze aynı
  görünüyor**, bayt olarak farklı, ve arama **sessizce 0** dönüyor. Ucuz kapı bir satır:
  `[\u0400-\u04FF]` taraması.
- **Kendi metnimde çıkması ders:** bu tur boyunca kart metinlerini `node` heredoc'larıyla
  yazıyorum; klavye/kopyalama yoluyla bir Kiril harf sızdığında **hiçbir şey uyarmıyor** ve o
  kart bir daha `grep` ile bulunamıyor.
- **Commit:** `8e65783e`
