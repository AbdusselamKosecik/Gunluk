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
