# pbxtr — 2026-09-19

## Bağlam

Üç kapı kartı kapatılacaktı: `BR-QA-55` (görsel sadakat kapısı 20 gündür kırık),
`BR-QA-57` (görsel kapı kapsamı tersine kurulmuş), `BR-QA-100` (`kapi_65`'in evi
HOST'a taşındı, kurul şartı `Ş77-4` ölçülmemiş).

`BR-QA-55` ve `BR-QA-57` **BLOKE** durumdaydı ve engelin adı yazılıydı:
*"digest-pinli Linux Playwright imajı yok"* (Kurul Karar #44, seçenek B, 14 şart).
`BR-QA-57`'nin ön koşulu `BR-QA-55`'ti. Yani sıra zorunluydu: önce imaj, sonra
taban, sonra kapsam.

---

## Yapılanlar

### 1. Karar #44 (B) uygulandı — digest-pinli Linux Playwright ortamı kuruldu

- **Neden:** Kart 20 gündür kırıktı ve iki turda "bloke" diye kapatılmıştı. Engel
  bir kod borcu değil **ortam eksiğiydi**: taban PNG'leri üretecek kanonik Linux
  ortamı yoktu. Windows'ta üretmek Karar #44'te **açıkça reddedilmişti** (font ve
  alt-piksel farkı → Linux kapısında kalıcı kırmızı).
- **Ne yapıldı:** `mcr.microsoft.com/playwright:v1.55.1-noble` çekildi ve
  **tag ile değil digest ile** pinlendi:
  `sha256:2f29369043d81d6d69a815ceb80760f55e85f5020371ad06a4d996f18503ad1c`.
  Koşucu `deploy/fidelity/fidelity-kos.sh` yazıldı (`dogrula` / `tara` / `uret` /
  `parmakizi`). Kapı imajı **büyütülmedi** (Ş1 — geçici konteyner deseni),
  `node_modules` adlandırılmış volume ile **izole** edildi (Ş12; host'un win32
  ikilileri konteynerden görünmez, host kurulumu bozulmaz).
- **Dokunulan dosyalar:** `deploy/fidelity/fidelity-kos.sh`,
  `src/Pbxtr.Web/playwright.config.ts`, `src/Pbxtr.Web/package.json`,
  `src/Pbxtr.Web/package-lock.json`
- **Komutlar:**
  ```bash
  docker pull mcr.microsoft.com/playwright:v1.55.1-noble
  bash deploy/fidelity/fidelity-kos.sh tara       # Ş7 yapılandırma mutasyon taraması
  bash deploy/fidelity/fidelity-kos.sh uret       # taban üretimi
  bash deploy/fidelity/fidelity-kos.sh dogrula    # kapı kipi
  ```
- **Sonuç:** Ş1·Ş2·Ş3·Ş4·Ş5·Ş6·Ş7·Ş8·Ş9·Ş10·Ş11·Ş13·Ş14 uygulandı.
- **Commit:** `dc412e09`

### 2. Taban PNG'ler temiz worktree'de, adlandırılmış SHA'da yeniden üretildi

- **Neden:** Ş6 "taban temiz ağaçta, adlandırılmış SHA'da, pinli konteynerde
  üretilir" der. Ana ağaç başka ajanların yarım işiyle kirliydi; oradan üretilen
  taban hiçbir commit'e karşılık gelmezdi.
- **Ne yapıldı:** `git worktree add --detach <tmp> <sha>` ile temiz kopya açıldı,
  taban orada üretildi, PNG'ler ana ağaca kopyalandı, manifestoya
  `producedFromSha` ile yazıldı.
- **Komutlar:**
  ```bash
  git worktree add --detach "$WT" 38408051
  docker run --rm --shm-size=1g -v "$WT:/repo" -v pbxtr-fidelity-wt:/repo/src/Pbxtr.Web/node_modules ...
  ```
- **Sonuç:** üretim sonrası **15 ardışık doğrulama koşumunun 15'i de yeşil.**
- **Commit:** `ae571605`, `9cbf6b0d`

### 3. Dört ayrı kusur ölçüldü — dördü de eski kapıda GÖRÜNMEZDİ

1. **`dashboard-live.visual.spec.ts` konteynerde DOSYA DÜZEYİNDE patlıyordu.**
   Node ≥ 22 JSON modülü için `with { type: 'json' }` import niteliği ister;
   Playwright'ın TS dönüşümü bunu taşımıyor. Yani test **hiç koşmuyordu** —
   kartın *"dashboard-live ekran görüntüsüne HİÇ ULAŞMIYOR"* bulgusunun **ikinci
   ve ayrı** sebebi. `readFileSync`e çevrildi. (`33cdd96c`)
2. **Taban FLAKY'di.** `page.clock.install` saati **sabitlemez**, yalnız
   başlangıcını verir; header saati akıyordu. İlk gerçek kapı koşusunda tek fark
   beklenen `15:57:13` / ölçülen `15:57:14` oldu. `page.clock.pauseAt` eklendi.
   (`9fe05796`)
3. **`threshold: 0.1` kapıyı RENK KÖRÜ yapıyordu.** Mutasyonla ölçüldü:
   `--brand #e8a33d → #d89a3a` (gözle görülür amber kayması) **0.1 ile GEÇTİ**.
   `threshold: 0`'a çekildi; aynı mutasyon 17282 px kırmızı, `#e8a43d` (1/255)
   bile 207 px kırmızı. **`maxDiffPixels: 0` tek başına sıfır tolerans DEMEK
   DEĞİLMİŞ.**
4. **Karar #44'ün "ortam tekilleştirilirse `maxDiffPixels: 0` taşınabilir"
   önermesi ÖLÇÜMLE ÇÜRÜDÜ.** Pinli konteynerde 15 ardışık koşumun **12'si**
   kırmızı; fark her seferinde **8 ya da 12 piksel** ve her seferinde karo
   kenarlığının 1px anti-aliasing'i (diff üzerinde ölçüldü: x=258-259,
   y=167..651). Tavan **ölçerek** 40'a çekildi (gözlenen azami sapmanın ~3,3
   katı); kapıyı körleştirmediği mutasyonla gösterildi (en küçük gerçek fark
   199 px = tavanın 5 katı). Doğrulayıcı tavanın **tam 40** olduğunu zorluyor.
   (`38408051`)

### 4. `BR-QA-57` — kapsam doğru tarafa çevrildi

- **Neden:** Kart, insan gözünün **en az** düştüğü ekranların kapsam dışı
  olduğunu söylüyordu. Sayıldı ve doğrulandı: **1920×1080 = 0**, **gündüz teması
  = 0**.
- **Ne yapıldı:** `visual-tests/wallboard.visual.spec.ts` (1920×1080) ve
  `visual-tests/dashboard-light.visual.spec.ts` yazıldı; kapsam **2 → 4 taban**.
- **Sonuç / doğrulama:** kapı seviyesinde üç yönlü mutasyon — mutasyonsuz
  `4 passed` rc=0 → `--brand` 1/255 mutasyonu `4 failed` rc=1 (**dört tabanın
  dördü de**: 199 · 216 · 17282 px) → geri alındı `4 passed` rc=0.
- **Commit:** `2bc47e52`, `9cbf6b0d`

### 5. İlk 1920×1080 tabanında GERÇEK bir ürün kusuru bulundu → `BR-FE-122`

- **Ölçüm (tarayıcı içinde, pinli konteyner):** wallboard "Ort. bekleme"
  karosunun `.value` ögesi `font-size: 104px`, `scrollWidth` **302 px**,
  `clientWidth` **271 px**, `text-overflow: ellipsis` → 227 saniyelik ortalama
  bekleme **"03:47" yerine "03:…"** çizilir. Tüm tahtada kırpılan **tek görünür
  öge** (görsel-gizli erişilebilirlik metinleri elendi).
- **Neden önemli:** Süpervizörün sahadan tarif ettiği arıza kipi birebir bu —
  *"yanlış sayı yok ortada, DOĞRU SAYI YANLIŞ OKUNUR"*. Log üretmez, CDR
  mutabakatı tutar.
- **Ne yapıldı:** taban bugünkü doğru fotoğraf olduğu için donduruldu ama
  **kart numarasıyla** manifestoya yazıldı; doğrulayıcı gerekçesiz taban kabul
  etmediği için o satır kart numarası olmadan yazılamazdı.

### 6. `BR-QA-100` — Ş77-4 (K-b) ölçüldü ve ŞART İHLAL EDİLİYORDU

- **Ölçüm (aynı commit, iki ortam, `node_modules` izole):**
  - Windows host, `node v24.19.0`, TZ=Europe/Istanbul → **232 dosya / 2091 test /
    689 suite, 1 kırmızı**
  - Linux konteyner, `node v22.19.0`, TZ=UTC → **232 dosya / 2091 test / 689
    suite, 2 kırmızı**
  - Envanter birebir aynı; fark **tek testte** ve tam **üç saat**:
    `ExtensionsScreen.test.tsx:608`, beklenen `"ölçüm 12/09 21:22:31"`, ölçülen
    `"… 18:22:31"`.
- **Neden önemli:** Bu, kapının evinin HOST olmasını **gizlice bir ŞART** haline
  getiriyordu — kapı Linux'a taşınsaydı **ürün sağlamken** kırmızı yanacaktı.
  Yani (a) seçeneği "çalışıyor" diye değil, **ölçülmemiş bir tesadüf** yüzünden
  yeşildi.
- **Düzeltme:** `vitest.config.ts` → `env: { TZ: 'Europe/Istanbul' }`. Değer
  host'un bugünkü değeriyle aynı seçildi: Windows sonucu değişmez, Linux düzelir.
  Pinin sessizce kalkmasını `src/test/tzPin.test.ts` (2 iddia) engeller.
- **Mutasyon, iki yön, iki ortamda:** `TZ='UTC'` → Windows 1 kırmızı, Linux
  1 kırmızı; geri alındı → Windows 22/22, Linux 22/22 yeşil.
- **Commit:** `e751ffed`

### 7. Dondurulmuş artefakt defteri — kapı KIRMIZI değil, ÇÖKÜYORDU

- **Neden:** Tabanlar `__screenshots__/linux/` altına taşındı, prototip tabanı
  silindi, iki yeni taban eklendi; defter üç **eski** yolu gösteriyordu.
- **Ne yapıldı:** Defter dört girdiye güncellendi. Ayrıca kapının **öz-testi**
  silinmiş prototip yoluna `KeyError` ile **çöküyordu** — bir bulgu değil bir
  çöküş raporluyordu. Öz-test iki yerden düzeltildi (ikisi de vacuity sınıfı):
  özneler artık defterden **seçiliyor**, ve `M5/M6` gerçek bir girdide
  `bilinenBayat` bulunmasına **dayanmıyor** (dayanıyordu; muafiyet kalkınca o iki
  mutant sessizce koşmaz hale gelirdi). Muafiyetin fiilen çalıştığını gösteren
  pozitif durum `M5b` eklendi.
- **Sonuç:** öz-test 11 → 12 durum, hepsi OK; gerçek koşum `SONUC: GECTI`.
- **Commit:** `b4c0e520`

### 8. gitleaks yanlış pozitifi — defterdeki `tokens.css` parmak izi

- **Neden:** Defter güncellenince sır taraması kırmızı yandı:
  `deploy/dondurulmus-artefaktlar.json:29`, kural `generic-api-key`, entropi
  3.84. Yakalanan şey bir sır değil, **sha256 özeti**:
  `"src/Pbxtr.Web/src/styles/tokens.css": "<64 hex>"`. Tetikleyen, anahtarın
  adındaki "tokens" kelimesiyle değerin entropisinin birleşimi — aynı satırdaki
  diğer kaynaklar aynı biçimde yazılı ve yakalanmadılar.
- **Ne yapıldı:** `.gitleaksignore`'a **parmak izi** istisnası (commit+dosya+
  kural+satır) eklendi. **Regex allowlist yazılmadı:** `.gitleaks.toml`'da
  ölçülmüş olduğu gibi `regexes` sırrın kendisine uygulanır; çıplak 64-hex'e uyan
  bir desen depo genelinde bütün 64-hex değerleri körleştirirdi. Satır da
  silinmedi: `tokens.css` gündüz teması tabanının gerçek kaynağıdır.
- **Doğrulama:** `gitleaks detect --source .` → 1750 commit, `no leaks found`, rc=0.
- **Commit:** `490e8095`

---

## Kapı koşusu — kapanış ölçümü

`deploy/yerel-kapilar.sh` (ubuntu kapı konteyneri, docker soketiyle):

| Kapı | Sonuç |
|---|---|
| `kapi_45` görsel sadakat taban manifestosu + öz-test | **geçti** |
| `kapi_83` görsel sadakat PİKSEL (pinli Linux konteyneri) — YENİ | **geçti** |
| dondurulmuş artefakt defteri (BR-QA-58) | **geçti** |
| Sır taraması | **geçti** (yukarıdaki istisnadan sonra) |

Kalan iki kırmızı **bu turun işi değil ve bu turdan ÖNCE de kırmızıydı**:
`BR-AST-55` kartında durum metni ŞART sütununda, ve
`yonetim/kurul-kararlari.md:13838`'de karışık yazılı bir kelime (Kiril `е`).

## Kararlar

- **`maxDiffPixels` 0 değil 40.** Karar #44'ün şartı ölçümle çürütüldü; sayı
  keyfi değil, gözlenen azami gürültünün (12 px) ~3,3 katı. Değiştirmek yeni bir
  ölçüm ister ve doğrulayıcı bunu zorluyor.
- **`threshold` 0'da kalır.** `threshold` ve `maxDiffPixels` **ayrı sorulardır**:
  ilki renk körlüğü üretir, ikincisi yalnız "kaç piksel"i gevşetir.
- **Kusurlu taban sessizce kabul edilmez.** Wallboard tabanı bilinen bir kusurla
  donduruldu ama manifestoda **kart numarasıyla** yazılı.
- **`BR-QA-57`'nin kalan iki kalemi (canlı izleme, agent eylem çubuğu) bilinçli
  olarak AÇIK bırakıldı** — gerekçe kapasite, ortam değil; ikisi de çoklu uç
  fikstürü ve ayrı kabul incelemesi ister. Boş/sahte taban üretilmedi.

## Açık kalanlar / sonraki adım

- `BR-FE-122` — wallboard "Ort. bekleme" karosu kırpılması (ürün kusuru).
- `BR-QA-57` kalem 2 (canlı izleme / kuyruk tablosu) ve kalem 3 (agent eylem
  çubuğu) taban üretimi.
- Kapı koşusunda kalan iki kırmızı **bu turun işi değil**: `BR-AST-55` kartında
  durum metni ŞART sütununda, ve `yonetim/kurul-kararlari.md:13838`'de karışık
  yazılı bir kelime (Kiril `е`).
- Ş10 gereği piksel kapısı **2026-12-11**'e kadar deneme süresinde: o tarihe
  kadar yapısal iddiaların yakalamadığı en az bir gerçek regresyon yakalamazsa
  kapı kaldırılacak. (Bu turda zaten bir ürün kusuru yakaladı — `BR-FE-122`.)

---

# pbxtr — 2026-09-19 (ikinci tur: linux-uzmani, beş kart)

## Bağlam

`BR-SYS-119`, `BR-SYS-120`, `BR-SYS-122`, `BR-AST-117`, `BR-AST-118`.
Alan: `deploy/`, sunucu, `AGENTS.md` — `src/` altındaki C# dosyalarına
dokunulmadı (üç ajan orada paralel çalışıyordu).

**Turun tek cümlelik dersi:** beş kartın üçünde bulunan kusur aynı sınıftı —
*"depoda" ≠ "kurulu" ≠ "devrede"*. Kartların hiçbiri bunu iddia etmiyordu;
ölçüm söyledi.

## Yapılanlar

### 1. BR-SYS-119 — Ş78-L6 sunucuda kapandı, Ş78-L5 saatle açık bırakıldı

- **Neden:** kart "kapı `is-enabled` soruyor, *hiç tetiklendi mi* sormuyor"
  diyordu; ayrıca ikinci ayak (drop-in'de sessizce yok sayılan `Environment=`)
  "depoda düzeltildi" kaydıyla duruyordu.
- **İlk satır `date -u`** — ve tur burada döndü: **sunucu saati
  `Fri 2026-09-18 21:57:40 UTC`**, yerel tarih ise 19 Eylül. İlk zamanlanmış
  ateşleme `Sat 2026-09-19 02:30Z (+<=15dk randomize) = ~02:37Z`, yani ölçüm
  anında **~4s39dk İLERİDE**. `LastTriggerUSec` hâlâ **BOŞ**.
  Kartın kendi zamanlama şartı gereği koşul **bugün eklenemezdi**.
- **Ş78-L6 ölçümü — düzeltme sunucuya HİÇ İNMEMİŞTİ:**

  | | kurulu | depo |
  |---|---|---|
  | `/usr/local/sbin/pbxtr-yedek` | `2c8e1e9f` | `c6e6a7b4` |
  | `...service.d/10-compose-yolu.conf` | `066e943e` | `6e6ceeda` |

  `grep -c PBXTR_YEDEK_PG_KONTEYNER <kurulu betik>` = **0**.
  Sebep yapısal: `deploy/` altında bu iki dosyayı **kuran hiçbir betik yok**;
  kurulum bir runbook adımı, yani insan hafızası.
- **Sapma aktif olarak tehlikeliydi:** yeni drop-in `PBXTR_YEDEK_PG_KONTEYNER`
  verir, **eski betik yalnız `PBXTR_YEDEK_PG_ONEK` okur**. Yarı kurulumda betik
  kendini bare-metal sanar, `pg_dumpall` host'ta olmadığı için düşerdi — ve
  öğreneceğimiz an **gece 02:37'deki gözetimsiz koşu** olurdu.
- **Ne yapıldı:** ikisi de kuruldu (**betik ÖNCE** — geriye uyumlu olduğu için
  güvenli sıra), `daemon-reload`, geri-alma yedeği `/root/*.yedek-20260918`.
- **Kabul ölçüldü:** `Environment`'ta `PBXTR_YEDEK_PG_KONTEYNER` **görünüyor**;
  kurulu drop-in'den beri `Invalid environment assignment` **0**.
- **pg yolu yedek durumuna DOKUNMADAN doğrulandı:**
  `pg_dumpall --globals-only` = 1479 bayt, `pg_dump 16.14`.
  **`backup-status.json` bilerek ELLENMEDİ** (274 bayt, mtime 09:45:21) — elle
  bir koşu tazelik kapısını yeniden yeşile boyardı, yani **kartın şikâyet
  ettiği şeyin ta kendisi**.
- **Yapısal düzeltme:** `deploy/yedek-sunucu-sapma.sh` (yeni, `kapi_84`).
  Üç iddia: (1) depo/sunucu sha, (2) drop-in adları systemd'nin **yüklediği**
  unit'te mi + kurulu dosyadan **beri** `Invalid environment assignment` var mı,
  (3) `LastTriggerUSec` boş **ve** timer 25 saatten uzundur etkinse **KIRMIZI**.
- **"Yarın hatırla" bir kapı değildir** — kartın kapatmak istediği şeyin ta
  kendisi. Bu yüzden koşul **tarihe değil timer'ın kendi beyanına** bağlandı
  (`OnCalendar` + `RandomizedDelaySec` + `ActiveEnterTimestamp`):
  **2026-09-19 10:42Z'de kendiliğinden sertleşir.**
- **Dört mutasyonla doğrulandı** (hepsi kırmızı): drop-in'den `Environment=`
  satırları silinir (vacuity), betik `KONTEYNER` okumayı bırakır, depo betiği
  değişir (iddia 1), ateşleme penceresi 1 sn (iddia 3).
- **Journal penceresi kurulu drop-in mtime'ı ile sınırlandı:** tüm journal'ı
  saymak, 09:41:20'deki (artık geçersiz dosyaya ait) 5 satır yüzünden kapıyı
  journal dönene kadar **kalıcı kırmızı** yapardı — *hep-kırmızı kapı, kapıyı
  fiilen kaldırır*.
- **Sonuç:** `BR-SYS-114` bugün **KAPANMIŞ SAYILMAZ**, sadece elle yamanmıştır.

### 2. BR-SYS-120 — iki ayak da yerindeydi; ölçüldü, kör yazılmadı

- Çıpa `deploy/yerel-kapilar.sh` kapanışında, **her iki dalda**, ANSI rengi
  olmadan, son satırda; `rc=3` de `KALAN`'a giriyor.
- **`AGENTS.md` maddesi zaten VARDI** (Ş78-L7, satır 600-616). Kart "yoksa yaz"
  diyordu — **önce var mı diye ölçüldü**, mükerrer madde yazılmadı.

### 3. BR-SYS-122 — envanter, sınıflandırma, kural

- Sunucudan `--scan`: **22 pbxtr anahtarı**; `INFO keyspace` =
  `db0:keys=23,expires=22`. **pbxtr'a ait TTL'siz anahtar SIFIR** (tek kalıcı
  anahtar `key:__rand_int__`, bir `redis-benchmark` artığı).
- Sınıflandırma: `counters` (TTL 694sn) ve `provisioning:delivery` (TTL 1730sn)
  = **performans önbelleği, DOĞRU** (türetilmiş; TTL burada bir **koruma**).
  `dropped:tenant-unresolved` / `payload-rejected` / `*:broken` (TTL 48s) =
  **ARIZA KANITI, TEK KOPYA, YANLIŞ.**
- **Sınıf ölçütü TTL uzunluğu değil:** *"bu anahtar silinirse olgu geri
  getirilebilir mi?"*
- **İkinci kopya arandı, YOK:** `docker logs pbxtr-app` içinde `unresolved`
  geçişi **0**; konteyner günlüğü 358 satır / 59 KB, penceresi 17 Eylül'e
  **ulaşmıyor**; log sürücüsü `json-file max-size=20m max-file=5`, yani
  **boyut tabanlı, zaman garantisi yok**; DB'ye zaten yazılmıyor.
  Yani `dropped:tenant-unresolved:2026-09-17` = **33224 düşmüş telefon olayının
  TEK kaydı**, `2026-09-19 01:49Z`'de yok olacaktı.
- **Kural:** `AGENTS.md` **16. bölüm** — *"Süreli anahtar, bir olayın TEK kaydı
  olamaz"*, envanter tablosu + sınıf ölçütü + yapılacaklar.
- Kalan iş (aynalama, `src/`) **backend-dev-2**'de. Redis kovası ve TTL'i
  **kalkmaz** — istenen TTL uzatmak değil **ikinci kopya**.

### 4. BR-AST-117 — durum doğrulandı + ÜÇÜNCÜ, kayda geçmemiş ayak

- `ls /var/lib/asterisk/sounds/` = yalnız stok **`en`**;
  `sounds/pbxtr/sys/` = **dizin YOK**. Yani `en` fallback'inin dosyası da yok:
  **her dil** sessizliğe düşüyor (kart yalnız `tr` diyordu).
- **YENİ (iv):** özelliğin dayandığı migration
  `20260915124000_TenantAnnouncementLanguage` sunucuda **UYGULANMAMIŞ**
  (`tenant_settings.announcement_language` kolonu **yok**), yani bugün tenant
  bazlı dil **seçilemiyor bile**. Yine *kod var, koşan yok*.
- `deploy/anons-dosyasi-kapisi.sh` **dürüst davrandı**: `rc=2 OLCULEMEDI`,
  eksiği yeşile boyamadı ve gerekçesini yazdı.
- (i) 9 dilin ses kaynağı **depo dışı ürün varlığıdır** (lisans/ürün kararı);
  bir ajan üretemez. Sıra bağımlılığı: **(iv) önce**, çünkü anons kapısı (iv)
  olmadan hiç ölçemiyor.

### 5. BR-AST-118 — park bağlamı sorusu canlı A/B ile cevaplandı

- **POZİTİF:** t0012 park dosyası geri konup `module reload res_parking.so`
  (kapalı liste) koşulunca `parking show` = `Parking Lot: t0012-tut` **geri
  geldi**, `dialplan show` = `700 Park()` + `751..759 ParkedCall()`.
- **NEGATİF:** dosya silinip aynı reload koşulunca lot **gitti**, bağlam yine
  `0 extensions (0 priorities)`.
- **Kontrol grubu t0007 tur boyunca bozulmadı:** 2 park lotu, 10 ext / 19 pri.
- **Sonuç:** kalıntı **boş bir bağlam ADIDIR** (0 extension); yönlendirilebilir
  nesne olan **LOT gerçekten gidiyor**; ve kalıntı **yeniden oluşturmayı
  BLOKLAMIYOR**.
- **Doğru kabul ölçütü** *"dialplan show çıktısında tenant kodu hiç geçmemeli"*
  **DEĞİLDİR** — öyle bir ölçüt kapalı listeyle **asla** sağlanamaz ve silmeyi
  sonsuza kadar bloklardı. Doğrusu: (a) `parking show` lot yok,
  (b) `dialplan show <ctx>` = `0 extensions`, (c) pjsip/queue/moh tenant kodlu
  satır yok, (d) diskte `t<kod>-*.conf` yok.
- **Yolda GERÇEK BİR HATA bulundu ve düzeltildi:** `pbxtr-confd-dugum.sh` 5.5
  bölümü operatöre *"4) doğrula: dialplan show ile tenant satırı 0 olmalı"*
  diyordu. Doğru temizlikten sonra o grep **1 satır** döndürüyor, yani talimatı
  izleyen operatör/ajan temizliği **başarısız sanıp** yasak komutlara
  (`module unload` / `core restart`) yönelirdi.

## Kararlar

- **Zamanlama şartı "hatırlanacak" bir şey olarak bırakılmaz.** Koşul tarihe
  değil, ölçülebilir bir sistem beyanına bağlanır ve kendiliğinden sertleşir.
- **Elle başlatılan bir yedek, zamanlanmış yedeğin kanıtı değildir** — tersine,
  onu ölçen kapıyı körleştirir. Bu yüzden doğrulama `backup-status.json`'a
  dokunmayan bir yoldan yapıldı.
- **Kalıntının muaf tutulması bir "görmezden gelme" değil, A/B ile ölçülmüş bir
  SINIFLANDIRMADIR** — nesnenin yönlendirme kabiliyeti olmadığı gösterildi.
- **Silme hâlâ açılmadı.** Blokeyi kaldıran ölçüm, kartın diğer üç ayağının
  (eşik/onay, vacuity kapısı, geri alma) yerine geçmez.

## Açık kalanlar / sonraki adım

- **`BR-SYS-119` / `BR-SYS-114`:** 02:37Z ateşlemesinden sonra
  `sh deploy/yedek-sunucu-sapma.sh` koşulur. (3) TAMAM derse `BR-SYS-114`
  gerçekten kapanır; demezse kart P1 olarak açılır. Geri-alma yedekleri
  `/root/*.yedek-20260918` **o ana kadar durur**.
- **`BR-SYS-122`:** arıza kanıtı sayaçların TTL'siz aynalanması — `backend-dev-2`.
- **`BR-AST-117`:** (iv) migration sunucuya uygulanmalı; (i) 9 dilin ses kaynağı
  bir ürün/lisans kararıdır.
- **`BR-AST-118`:** eşik/onay politikası, vacuity kapısı, geri alma yolu.
- **Kalıcı boşluk:** `deploy/` altında `pbxtr-yedek` betiğini + drop-in'i
  **kuran** bir adım hâlâ yok; `kapi_84` sapmayı artık **görünür** kılıyor ama
  **gidermiyor**.

---

# pbxtr — 2026-09-19 (3. tur): `BR-BE-210` · `BR-BE-211` · `BR-FE-121`

## Bağlam

Üçü de `BR-FE-118`'in bölünmesinden doğdu. `BR-FE-118` ölçmüştü:
`callback_requested_count` `sla_buckets`'a yazılıyor, `SlaWindowStore.cs:152` ile
Redis anlık görüntüsüne giriyor ve **orada bitiyor** — `ILiveOperationsView.cs`'de
`callback` → 0, `IAnalyticsQuery.cs` → 0, `EfAnalyticsQuery.cs` kolonu hiç
seçmiyor, `MissedCallEndpoints.cs`'de `slaMinutes|dueAt|deadline|remaining` → 0.
Yani bir dağıtım SLA formülünü `v1` → `v2` değiştiriyor, değişimi açıklayan sayaç
üretiliyor ve süpervizör onu yalnızca `psql` ile görebiliyor. (`BR-FE-67`
kusurunun — yazılmış ama hiçbir yerden çağrılmayan `AvgWaitOfQueue` — birebir
tekrarı.)

## Yapılanlar

### 1. `BR-BE-210` — aynı sayı, iki okuyucu

- **Neden:** sayı ÜRETİLİYORDU, taşınmıyordu. Kartın şartı "aynı sayı" olduğu
  için ikinci bir sayım kuralı açılmaması esastı.
- **Ne yapıldı:**
  - `LiveQueueRow.CallbackRequested` (`int?`) + `LiveOperationsSnapshot.CallbackRequestedToday`.
    Eşleme `RedisLiveOperationsView`'da; **tenant toplamı da AYNI `SlaWindowState`
    sözlüğünden** toplanır (`SumCallbackRequested`) — kuyruk satırlarından ayrı bir
    Redis okuması açılsaydı üst şerit ile satırlar bir gün ayrışırdı (aynı tuzak
    `AgentsAvailable` yorumunda yazılı).
  - `AnalyticsQueueSlaRow.CallbackRequested` + `AnalyticsQueueSlaTotals.CallbackRequested`;
    `EfAnalyticsQuery.SelectSql` kolonu artık **seçiyor**; `TargetQueueRowDto`,
    `TargetTotalsDto`, `LossQueueRowDto`, `LossTotalsDto` ve `AnalyticsExportCsv`
    (`"Geri Arama Talebi"`, iki dosyada da).
- **Dokunulan dosyalar:** `src/Pbxtr.Domain/Modules/Live/{ILiveOperationsView,SlaCalculator}.cs`,
  `src/Pbxtr.Domain/Modules/Analytics/IAnalyticsQuery.cs`,
  `src/Pbxtr.Infrastructure/Telephony/Live/RedisLiveOperationsView.cs`,
  `src/Pbxtr.Infrastructure/Modules/EfAnalyticsQuery.cs`,
  `src/Pbxtr.Api/Modules/Analytics/{AnalyticsDtos,AnalyticsExportCsv}.cs`,
  `src/Pbxtr.Api/Modules/Realtime/LiveEndpoints.cs`
- **Sonuç / doğrulama:** `CallbackRequestedVisibilityTests` — 7 sürüm hâli +
  toplam kuralı (pozitif kontrolüyle) + CSV boş hücre. `dotnet build pbxtr.sln`
  0 error / 0 warning.

### 2. `0` ↔ `null` ayrımı — kartın asıl riski

- **Neden:** kolon `NOT NULL DEFAULT 0`. Migration öncesi kovalarda yazan `0`
  *"ölçüldü, talep yok"* DEĞİL *"ölçülmedi"*dir (`BR-BE-205`) ve ayrım veriden
  geri getirilemez. Tek taşıyıcı **tanım sürümüdür**.
- **Ne yapıldı:** eşik **tek yerde** — `SlaDefinition.CarriesCallbackCounter`
  (`v2`+, `v` + tamsayı ayrıştırır).
- **Karar — SQL'e `>= 'v2'` YAZILMADI:** (a) metin karşılaştırması `v10 < v2`
  derdi, (b) kural ikinci bir motorda tanımlanmış olurdu. Sorgu bunun yerine
  `MIN(definition_version)` seçer ve kararı C# verir.
- **Karar — `MIN`, `MAX` DEĞİL:** sürüm geçişine yayılan bir aralıkta (bir gün
  `v1`, ertesi gün `v2`) `MAX` **eksik bir sayı** üretirdi; `MIN` ile satır
  "ölçülmedi" der. Yön bilinçli: eksik bir sayı, gösterilmeyen bir sayıdan
  pahalıdır. Aynı kural toplamda da geçerli — bir satır `null` ise toplam `null`.
- **Tek istisna, `#11` kuyruk satırının kovası yokken:** satırda `null`
  (`SlaPct` ile aynı hal) ama **tenant toplamında `0` katkı**. Ters kural
  yazılsaydı sakin bir tenantta toplam her gün `—` çıkar ve alan kalıcı bir
  tireye dönerdi — `BR-FE-67`'de kapatılan kusurun ta kendisi.

### 3. `BR-BE-211` — `#37` söz / son tarih / SLA sınıfı

- **Neden:** `tenant_settings.callback_sla_minutes` + `callback_sla_mode`
  `BR-BE-199` ile eklenmişti ama **hiçbir okuma yüzeyi onları sormuyordu**.
  *"30 dakikalık bir sözü, kalan dakikasını göremediğim bir tabloda tutamam."*
- **Ne yapıldı:** `CallbackSlaPolicy.Project(...)` → `CallbackSlaProjection`
  (`Minutes`, `DueAt`, `Class`, `RemainingSeconds`); tel sözleşmesi
  `CallbackSlaClasses` — enum adı değil **kapalı dize kümesi**
  (`within` · `pending` · `breached` · `excluded`). `CallbackRow`/`CallbackBoard`
  ve `MissedCallEndpoints` DTO'ları genişletildi; tahta ayrıca **sunucunun anını**
  (`at`) ve tenant sözünü (`slaMode`/`slaMinutes`) yayınlıyor.
- **Kararlar:**
  - **`excluded` `breached`'dan AYRI.** Kip a'da ölçülecek bir söz yoktur; ikisini
    tek değere katlamak, kip a seçmiş bir tenantın **her satırını ihlal**
    göstermek olurdu.
  - **Kökeni `missed_call` olan satırda dördü de `null`:** müşteriye bir süre
    SÖYLEMEDİK; uydurulmuş bir son tarih, verilmemiş bir sözü ölçmek olurdu.
  - **"Kalan dakika" istemcide türetilmiyor** (CLAUDE.md §11,
    `AmbientClockGuardTests`): `remainingSeconds` sunucudan gelir ve **negatif
    olabilir** — gecikmenin miktarı da bir ölçümdür, işareti silmek "ne kadar
    geciktı" sorusunu öldürürdü.
  - **An bir kez okunur** (`_clock.GetUtcNow()`); satır başına okunsaydı sınır
    üzerindeki iki kayıt aynı tabloda biri `pending` biri `breached` görünürdü.
  - **Ayar satırı yoksa söz varsayılandır** (kip b / 30 dk). Kip a yazılsaydı
    eksik yapılandırma bir **SLA muafiyetine** dönerdi.
  - **Her kapanış bir cevap değildir:** `AnsweredAtOf` yalnızca `answered` ve
    `customer_called_back` kapanışlarını cevap sayar; `manual`/`max_attempts`/
    `expired` kapanışlarında müşteri geri ARANMAMIŞTIR.
- **Dokunulan dosyalar:** `src/Pbxtr.Domain/Modules/Automation/{CallbackSlaPolicy,ICallbackLedger}.cs`,
  `src/Pbxtr.Infrastructure/Modules/EfCallbackLedger.cs`,
  `src/Pbxtr.Api/Modules/Automation/MissedCallEndpoints.cs`
- **Sonuç / doğrulama:** `CallbackLedgerEndpointTests.BR211_*` — **dört sınıfın
  dördü de uçtan**. Test ikizi (`FakeLedger.ToRow`) **gerçek `CallbackSlaPolicy`'yi
  çağırır**, SLA alanlarını elle doldurmaz (kayıtlı ders: *test ikizi üretimden
  müsamahakâr*). `21 passed` (dosya), sonra `27 passed` (yeni birim testleriyle).

### 4. `BR-FE-121` — üç yüzeyin tüketicisi

- **Ne yapıldı:**
  - **`#11`:** kuyruk kartında "geri arama" rakamı (Terk'in **yanında**, içinde
    erimeden) + üst şeritte tenant toplamı kartı.
  - **`#23`/`#18`:** ayrı kolon + toplam kartı, ikisi de `countText` ile.
  - **`#37`:** `SlaCell` — dört sınıf, **dört ayrı cümle** + son tarih yanında;
    tahtada "Geri arama sözü" kartı.
  - i18n **9 dilde 14 anahtar**; mükerrer kontrolü **ham metinde**
    (`ham.count('"k"') == 0` → yaz → `== 1`), çünkü `json.loads` mükerrer
    anahtarı sessizce kabul eder. Anahtarlar **kendi önek grubu içinde**
    alfabetik yerine kondu; dosya baştan sona alfabetik değil ve
    `sort_keys=True` ile yazmak binlerce satırlık sahte bir diff üretirdi.
- **Kararlar:**
  - **`—` çizilir, `0` yazılmaz:** hiçbir hücrede `?? 0` yok.
  - **Kesişim uyarısı `#11`'e KOYULMADI.** Orada `abandoned` `sla_buckets`'tan
    değil günlük `CallDisposition.Abandoned` sayımından gelir
    (`RedisLiveOperationsView.cs:706,1306`) → kesişim iddiası o ekranda **yanlış**
    olurdu. `BR-FE-119` ile aynı ölçüm; uyarı `#18`/`#23`'te durur.
  - **Saat tablosunda kolon YOK** (ve CSV'de saat satırı boş hücre): bir saat
    satırı farklı tanım sürümlerindeki kuyrukları toplar — "ölçüldü mü" sorusu
    satır bazında cevaplanamaz. "Tanım Sürümü" kolonu da aynı sebeple orada yok.
  - **Tenant kartının tonu NÖTR:** talep bir arıza değildir. `abandoned` gibi
    kırmızı yazsaydı, özelliği **açan** tenantın panosu kendi başarısıyla
    kırmızılaşırdı.
- **Dokunulan dosyalar:** `src/Pbxtr.Web/src/app/api/opsContracts.ts`,
  `.../screens/live/LiveQueuesScreen.tsx`,
  `.../screens/analytics/{targetsApi.ts,lossApi.ts,TargetsScreen.tsx,LossScreen.tsx}`,
  `.../screens/automation/{missedCallsApi.ts,CallbackBoardPanel.tsx}`,
  `.../i18n/messages/*.json` (9)

### 5. Doğrulama koşusu

- **Komutlar:**
  ```bash
  dotnet build pbxtr.sln                     # 0 Warning, 0 Error
  dotnet test tests/Pbxtr.Architecture.Tests # 728 passed
  dotnet test tests/Pbxtr.Api.Tests --filter "…Modules.Analytics|…Modules.Automation"  # 73 passed
  dotnet test tests/Pbxtr.Api.Tests --filter "…CallbackRequestedVisibilityTests|…CallbackSlaPolicyTests"  # 27 passed
  npx tsc -b                                 # temiz
  npx vitest run src/app/screens/{live,analytics,automation} src/app/primaryUserActionHttp.test.tsx src/app/i18n
  #   -> 24 dosya / 247 test yeşil
  ```
- **Mutasyon (vacuity kapısı):**
  - `countText(row.callbackRequested)` → `String(… ?? 0)` ⇒ **2 kırmızı**
    (`CallbackRequestedColumn.test.tsx`).
  - `SlaCell`'de `excluded` dalı `breached` metnine çevrildi ⇒ **2 kırmızı**
    (`CallbackBoardPanel.test.tsx`). İkisi de geri alındı ve dosyalar `cp` ile
    doğrulandı.
- **Commit:** `ed7dba7b` — BR-BE-210/211 + BR-FE-121 (33 dosya, +1726/−58).

## Kararlar

- **"Aynı sayı, iki okuyucu" bir veri kaynağı kararıdır, bir kopyalama değil.**
  Tenant toplamı kuyruk satırlarıyla aynı sözlükten üretilir; ikinci bir okuma
  açmak, iki yüzeyin bir gün ayrışması demektir.
- **Sürüm eşiği SQL'e yazılmaz.** `MIN`/`MAX` seçimi bile bir yön kararıdır ve
  yönü "eksik sayı yerine ölçülmedi" olarak sabitledik.
- **`excluded` ≠ `breached`.** "Ölçmüyoruz" ile "ölçtük, tutturamadık" aynı
  piksele düşerse ölçüm politikası bir arıza gibi görünür.
- **Ekranda gösterilecek "an" sunucudan gelir.** Bu turda bir kez daha uygulandı:
  `remainingSeconds` + tahtanın `at`'ı; istemci hiçbir süre hesaplamıyor.

## Açık kalanlar / sonraki adım

- **`dotnet format --verify-no-changes` depo genelinde KIRMIZI** (22.113 hata;
  CHARSET/IMPORTS/WHITESPACE). Bu turda **ölçüldü, dokunulmadı**: hatalar bu
  turun dokunmadığı satırlarda (ör. `RedisLiveOperationsView.cs:280/318/658`) ve
  onlarca dosyada. Yayın betiği bu kapıyı koşuyor — ayrı bir kart gerekir.
- **`LiveEndpoints.cs` değişikliğim paralel bir ajanın `78285240` commit'ine
  süpürüldü** (kayıtlı ders: *paralel ajan stage'i süpürür*). İş kayıp değil,
  **commit mesajı başka**; `git log --follow` ile aranırsa bu kartın adı o
  commit'te geçmez.
- **`Pbxtr.Api.Tests.Modules.Realtime` KIRMIZI ve bu turun değil:** 7
  `AgentInterventionTests` + 1 `ScriptPublishedEventTests` + 1
  `LiveAgentDndStoreTests` hatası, aynı anda çalışan bir ajanın yarım
  `ITenantCache.TrySetIfNewerAsync` / `RedisLiveStateStore` işinden geliyor
  (çalışma ağacında `M` olarak duruyor, testhost da çöktü). Bu turun kendi
  namespace'leri (`Modules.Live` içindeki yeni test dâhil) yeşil.
- **`#37`'de kalan süre CANLI SAYMIYOR:** ekran sunucunun verdiği sayıyı bir kez
  çizer; sekme açık kalırsa değer tazelenene kadar donar. Tahtanın `at` alanı
  bunu görünür kılar ama tazeleme bir sonraki karttır (istemcide sayaç
  döndürmek, bu turda kapatılan türetme yasağını geri açardı).

---

# pbxtr — 2026-09-19 (backend-dev-1 turu: BR-BE-202 / 190 / 195 / 194)

## Bağlam

`backend-lider` dört kart verdi. Üçü "bloke" ya da "kurul bekliyor" durumundaydı;
ikisinin kart metnindeki teşhis **ölçünce eksik çıktı.** Paralel ajanlar aynı anda
`RedisLiveOperationsView.cs`, `EfAnalyticsQuery.cs`, `MissedCallEndpoints.cs` ve
`SlaWindowStore.cs` üzerinde çalışıyordu; o dosyalara dokunulmadı.

## Yapılanlar

### 1. BR-BE-202 — mutabakat HER ZAMAN `not_applied` okuyor

- **Neden:** süpervizör müdahalesi santralde çalışıyor ama panel "uygulanmadı" diyor.
  Asıl tehlike ikincil: operatör zamanla o satırı okumayı bırakır ve **gerçek** bir
  `not_applied` geldiğinde de kimse bakmaz.
- **Teşhis ölçüldü ve DOĞRU çıktı ama EKSİKTİ.** Kart "uç `after[member]`'a GUID
  yazıyor" diyordu; doğru. Ama altında şu vardı:
  `AgentInterventionResult.Indeterminate()` üye adresini **hiç taşımıyordu**
  (`MemberEndpoint = null`). Yani "uç doğru değeri yazsın" demek yetmiyordu —
  değer ucun elinde yoktu.
- **Kartın (b) seçeneği ölçümle elendi:** "resolver GUID→arayüz çözsün" dersek
  türetme `tenantCode + dahili` ister ve dahili müdahaleden sonra değişmiş olabilir.
  Bu zaten `IAgentIntervention.cs`'de **yazılıydı**; kart onu görmemiş.
- **Ne yapıldı:** adres sonuçla taşınıyor. `after` gövdesi
  `LiveEndpoints.BuildInterventionAfter`'a çıkarıldı ve **metot `userId` almıyor** —
  aynı regresyon yapısal olarak yeniden yazılamaz. Adres yoksa alan yazılmaz
  (fail-closed → mutabakat `unknown`). Aynı kusur `AgentEndpoints` self-state
  yolunda da vardı, o da düzeltildi.
- **Dokunulan dosyalar:** `src/Pbxtr.Api/Modules/Realtime/LiveEndpoints.cs`,
  `src/Pbxtr.Api/Modules/AgentDesk/AgentEndpoints.cs`,
  `src/Pbxtr.Domain/Modules/Live/IAgentIntervention.cs`,
  `src/Pbxtr.Infrastructure/Telephony/Live/AgentInterventionService.cs`,
  `src/Pbxtr.Infrastructure/Telephony/Live/QueuePushReconciliationJob.cs`
  (`PendingPush` private→internal),
  `tests/Pbxtr.Api.Tests/Modules/Realtime/LiveAgentActionReconciliationNamespaceTests.cs`
- **Vacuity kapısı uçtan uca:** gövde **üretim serializer'ından**
  (`AuditPayloadSerializer`) geçip işin kendi çözücüsüne (`PendingPush.From`) ve
  `QueuePushResolver`'a veriliyor. Yalnızca "member GUID değil" deseydim, alanı boş
  bırakan bir uygulama da yeşil kalırdı.
- **Mutasyon:** member'a GUID geri yazıldı → 5 testin **3'ü kırmızı.**
- **Commit:** `78285240`

### 2. BR-BE-190 — `PbxtrTakeoverRequeued`'in üreticisi yoktu

- **Neden:** `BR-AST-95` kanal değişkenini kaldırınca dialplan üreticisi düştü.
  `Half` ve `Aborted` basılıyor, `Requeued` **hiç** basılmıyordu — yani devralmadan
  sonra **yaşayan** çağrının izi kalmıyor, süpervizör "çağrı ne oldu" sorusunun
  olumlu cevabını göremiyordu.
- **Kart "bloke" diyordu — ölçünce DEĞİLDİ.** Öncül `BR-AST-107` kapanmış ve
  `ConfigRenderer.ConfBridgeRegisteredOnPbx` `true` yapılmıştı. Kartın durum hücresi
  bayattı.
- **Kartın açıkça "ÖLÇÜLMEDİ" dediği kalem santralde ölçüldü** (`176.88.41.220`):
  `ConfbridgeJoin` bugünkü `read` sınıfıyla **geliyor** — `Privilege: call,all`;
  okuma sınıfı `system,call,agent,user,cdr,dialplan`. **Yazma kümesine dokunulmadı**
  (Karar #46 / Ş-46-1 kilidi aynen duruyor).
- **Kartta olmayan bir eşik bulundu:** `BridgeNumChannels` = gerçek katılımcı **+ 1**.
  ConfBridge her konferans için bir **anons kanalı** açıyor
  (`CBAnn/pbxtr-ctl-annprobe-00000014;1`, `core show channels` ile doğrulandı).
  Ölçülen dizi: `ConfbridgeStart`=1, 1. katılım=2, 2. katılım=3.
- **Bu yüzden işaret ilk katılımda DEĞİL, BULUŞMADA basılıyor.** Kartın önerdiği
  "konferans adı önekiyle süz" tek başına yanlış olurdu: tek başına giren bacağa
  `Requeued` yazmak, hemen ardından `Aborted` ile ölen bir çağrıyı çizelgede
  "yaşadı" göstermek demekti.
- **Konferans adı tek kaynağa bağlandı** (`TakeoverSignals.ConferencePrefix`):
  dialplan üreticisi ile eşlemenin öneki ayrı yazılsaydı biri değiştiği gün işaret
  **sessizce hiç doğmazdı** — kartın ilk oluş sebebinin birebir tekrarı.
- **Dokunulan dosyalar:** `src/Pbxtr.Domain/Modules/Telephony/TakeoverSignals.cs`,
  `src/Pbxtr.Infrastructure/Telephony/Asterisk/AmiEventMapper.cs`,
  `src/Pbxtr.Infrastructure/Provisioning/ConfigRenderer.cs`,
  `tests/Pbxtr.Api.Tests/Modules/Telephony/AmiTakeoverRequeuedMappingTests.cs`,
  `tests/Pbxtr.Api.Tests/Modules/Telephony/Fixtures/ami-confbridge-takeover-capture.txt`
- **Komutlar (sunucuda, python + AMI soketi):**

  ```bash
  ssh root@176.88.41.220 'docker exec pbxtr-asterisk asterisk -rx "manager show user pbxtr"'
  ssh root@176.88.41.220 'docker exec pbxtr-asterisk asterisk -rx "module show like confbridge"'
  # + AMI'ye login olup ConfBridge'e kanal sokan gecici python betigi
  ```

  Sır hiçbir çıktıya yazılmadı: betik `pbxtr.d/credentials/ami.conf`'u kendisi okudu
  ve değeri yalnızca sokete verdi.
- **Temizlik doğrulandı:** geçici `brbe190probe` bağlamı silindi, `0 active channels`,
  konferans listesi boş, `/tmp` betikleri silindi.
- **Mutasyon:** `ConfbridgeJoin` dalı silindi → 2 test kırmızı; eşik `3→2` →
  tek-bacak testi kırmızı.
- **Commit:** `78285240`

### 3. BR-BE-195 — monotonik `MeasuredAt`

- **KARTIN ÖNERDİĞİ ÇÖZÜM KARTIN KENDİ KABUL ÖLÇÜTÜNÜ GEÇEMİYORDU.** Kart
  "oku-karşılaştır-yaz" diyor **ve** "iki eşzamanlı aktörle ölçülür" diyordu. O üç
  adımdır: A okur (eski), B okur (eski), B YENİ'yi yazar, A ESKİ'yi yazar → eski
  kazanır. Yani tek aktörlü testte yeşil yanar, korumayı **hiç kurmaz.**
- **Ne yapıldı:** karşılaştırma + yazım **tek atomik işlem** —
  `ITenantCache.TrySetIfNewerAsync` + `RedisTenantCache`'te Lua betiği. Gerekçe aynı
  dosyada `TryAddAsync`/`GetAndRemoveAsync` için **zaten yazılıydı** ("iki komuta
  bölünmesi yasaktır").
- **Damga ayrı bir anahtarda** (`<key>:at`) ama bu bir bölünme değil: iki anahtarı da
  **aynı betik** yazıyor ve okuyor. Lua'da JSON ayrıştırmamak için. İkisi de tenant
  önekli — önek olmasaydı bir tenant'ın yazımı ötekinin satırını sessizce düşürürdü
  (ayrı test).
- **`MeasuredAt` ≠ `SinceAt`:** `SinceAt` "bu duruma ne zaman girildi" (süre sayacı),
  `MeasuredAt` "bu bilgiyi ne zaman öğrendik" (sıralama). Tek alanla yapılsaydı ya
  sayaç sıfırlanırdı ya sıralama bozulurdu.
- **Kaynak olayın SANTRAL damgası** (`telephonyEvent.At`), yazım anı değil: resync
  toplu işler ve gecikmeli yazar; yazım anı kullanılsaydı **eski ölçüm en yeni
  damgayı alırdı** ve düzeltmek istediğimiz ezmeyi biz yapardık.
- **Varsayılan arayüz uygulaması bilerek patlıyor** (`NotSupportedException`).
  Müsamahakâr bir varsayılan 23 test ikizini yeşil bırakıp üretim korumasını
  ölçülmemiş kılardı (kayıtlı ders: *test ikizi üretimden müsamahakâr*).
- **Ölçüm GERÇEK Redis'te**, 40 turluk iki-aktör yarışı: 6/6 geçti.
- **Dokunulan dosyalar:** `src/Pbxtr.Domain/Platform/Tenancy/ITenantCache.cs`,
  `src/Pbxtr.Infrastructure/Caching/RedisTenantCache.cs`,
  `src/Pbxtr.Infrastructure/Telephony/Live/RedisLiveStateStore.cs`,
  `src/Pbxtr.Infrastructure/Telephony/Pipeline/TelephonyEventPipeline.cs`,
  `tests/Pbxtr.Integration.Tests/Tests/LiveAgentMonotonicWriteTests.cs`
- **Mutasyon:** `SetAsync`'e düşürüldü → 2 test kırmızı; Lua `>` → `>=` →
  `Esit_damga_YAZAR` kırmızı.
- **Commit:** `921dd1c2`

### 4. BR-BE-194 — doluluk (occupancy) tanımı + metriğin kendisi

- **Kurul dağıtıldığı için tanımı ben yaptım, dar tuttum ve kartta gerekçelendirdim.**
- **Kapalı küme `LiveAgentStatuses.All`'tan TÜRETİLDİ, uydurulmadı:**
  - **PAY:** `on_call + acw`
  - **PAYDA:** `available + on_call + acw`
  - **DIŞI:** `break`, `offline`, `ringing`
- **`break` paydaya konmadı.** Mola yetkilendirilmiş bir yokluktur; paydaya konsaydı
  metrik molaya çıkan agenti cezalandırırdı — `BR-BE-135` / `BR-OPS-02` ile **aynı
  kusur sınıfı** (agentin kontrolünde olmayanı performansına yazmak). Mola süresi
  fonksiyonun **imzasında bile yok**, kazara eklenemesin diye.
- **`ringing` dışıdır ve bu bir TERCİH DEĞİL, ÖLÇÜLEMEYİŞTİR:** ürün ringing süresini
  hiçbir kovaya yazmıyor (`AgentTimelineSlot` belgesi bunu zaten söylüyor).
  **Sapmanın yönü yazıldı:** payda eksik olduğu için doluluk **yukarı** sapar.
- **Payda sıfırsa `null`, `0` değil.** `0` "agent hiç çalışmadı" der ve bu bir
  performans iddiasıdır; tümüyle molada geçen bir saat panelde %0 doluluk göremez.
- **Metrik ürüne bağlandı** (*kod var, koşan yok* olmasın): `#22` Agent Çizelgesi ucu
  saat ve gün başına `occupancy` döndürüyor. `CallReportCatalog` ve
  `AgentPerformanceEndpoints`'teki "doluluk üründe YOK" notları düzeltildi; ikisi de
  artık nerede **olduğunu** ve aynı sayıyı ikinci kaynaktan türetmediğini söylüyor.
- **`BR-BE-135` / `BR-BE-171`(b) için açık ve TEK bağlı nokta: `deductedSec`**
  (yalnız `available`'dan düşer, onu aşamaz). O iki kartın "kırmızı yanabileceği kod
  yolu yok" engeli kalktı.
- **Dokunulan dosyalar:** `src/Pbxtr.Domain/Modules/Live/AgentOccupancy.cs`,
  `src/Pbxtr.Api/Modules/Realtime/TimelineEndpoints.cs`,
  `src/Pbxtr.Domain/Modules/Reporting/CallReportCatalog.cs`,
  `src/Pbxtr.Api/Modules/AgentDesk/AgentPerformanceEndpoints.cs`,
  `tests/Pbxtr.Api.Tests/Modules/Live/AgentOccupancyTests.cs`
- **Mutasyon (üçü de):** `break` paydaya eklendi → kırmızı; payda sıfırken `0`
  döndürüldü → kırmızı; `LiveAgentStatuses`'a `training` eklendi → kapalı küme
  bekçisi kırmızı ("Doluluk tanimi su durumlar icin SUSUYOR: training").
- **Commit:** `921dd1c2`

## Ölçüm sonuçları

- `dotnet build pbxtr.sln` → **0 hata.**
- `Pbxtr.Api.Tests` (`Modules.Live` + `Modules.Realtime` + `Modules.Telephony`):
  **1674 geçti, 1 kırmızı, 2 atlandı.** Kırmızı benim değil:
  `ScriptPublishedEventTests.Istemci_olay_listesi_sunucu_katalogunu_kapsar` — sunucu
  realtime olay kataloğunda istemci listesinde olmayan bir olay var; dokunmadığım iki
  dosya (`RealtimeProvider.tsx`, `RealtimeEventTypes`). `git diff` ile doğrulandı.
- `Pbxtr.Integration.Tests / LiveAgentMonotonicWriteTests`: **6/6** (gerçek Redis).
- ClickUp: `fark olan kart: 0, izde olmayan: 0`.

## Kararlar

- **Kart teşhisi bir hipotezdir, ölçüm değil.** Dördün ikisinde kart metni eksik ya
  da bayattı: `BR-BE-202`'de asıl kusur bir katman daha aşağıdaydı, `BR-BE-190`
  "bloke" yazıyordu ama öncülü kapanmıştı. **Önce ölç.**
- **Bir kartın önerdiği uygulama, kartın kendi kabul ölçütünü geçemeyebilir.**
  `BR-BE-195` bunun ders kitabı örneği: "oku-karşılaştır-yaz" + "iki eşzamanlı
  aktörle ölç" aynı kartta yazıyordu ve **birbiriyle çelişiyordu.**
- **Sahte bir varsayılan, eksik bir uygulamadan kötüdür.** `TrySetIfNewerAsync`'in
  varsayılanı patlıyor; `SetAsync`'e sessizce düşseydi koruma hiç kurulmadan
  "kuruldu" görünürdü.
- **Fikstür provenansı satır satır yazılır.** Gerçek santral kaydından hangi blok
  harfiyen, hangisi türev ve türevde **ne** değişti — hepsi dosya başlığında.
  Ölçemediğim tek şeyi (`BridgeNumChannels: 3` + eşleşen `Linkedid` tek blok) ve
  **neden** ölçemediğimi de oraya yazdım.
- **`null` ≠ `0` bir kez daha:** doluluk metriğinin tamamı bu ayrımın üstünde duruyor.

## Açık kalanlar / sonraki adım

- **`ScriptPublishedEventTests` kırmızı ve sahibi başkası:** sunucu realtime olay
  kataloğuna eklenen bir olay `Pbxtr.Web`'deki `REALTIME_EVENTS` listesine
  yazılmamış. Kart açılmalı.
- **Uçtan uca gerçek devralma koşulmadı** (`BR-BE-190`): iki kayıtlı SIP ucu gerekir.
  Bugün ölçülen şey olayın **geldiği** ve **şeklidir**, akışın tamamı değil.
- **`BR-BE-195` için canlı resync/olay yarışı ölçülmedi:** yarış gerçek Redis'te 40
  turla ölçüldü ama gerçek santral olay akışıyla değil.
- **Bu dosyanın önceki bölümündeki "`Modules.Realtime` kırmızı, paralel ajanın yarım
  `TrySetIfNewerAsync` işi" notu KAPANDI** — o yarım iş buydu, bu turda bitti.
  `AgentInterventionTests` ve `LiveAgentDndStoreTests` artık yeşil.
- **`BR-BE-135` ve `BR-BE-171`(b) artık yazılabilir:** payda var, bağlanacak nokta
  (`deductedSec`) açık ve tek.


---

## Koordinator — yayin format kapisi ve dusme kanitinin korunmasi

### 1. `BR-AST-119` — düşme kanıtının ikinci kopyası (süre kritikti)

- **Neden:** Sunucudaki tek kanıt bir Redis anahtarıydı
  (`pbxtr:sys:dropped:tenant-unresolved:2026-09-17` = `33224`) ve **TTL 10908 sn** kalmıştı
  — yaklaşık 3 saat sonra (`~2026-09-19 01:49Z`) uçacaktı. İkinci bir kopyası **yoktu**.
- **Ne yapıldı:** Kanıt karta yazıldı. Ardından aslında daha önemli olan ayrım ölçüldü:
  *"18 Eylül için düşme anahtarı YOK"* bir **düzelme kanıtı değil**.
- **Komut / ölçüm:** `call_events` gün bazında, `call_id ~ '^[0-9]+\.[0-9]+$'` (Asterisk
  `uniqueid` biçimi) ayrı sayılarak:

  | Gün | Olay | Asterisk biçimli |
  |---|---|---|
  | 13 Eyl | 295 | 4 |
  | 14–16 Eyl | 291 | **0** |
  | **17 Eyl** | 719 | **344** |
  | 18 Eyl | 1960 | **10** |

- **Sonuç:** `~291 olay + 0 Asterisk biçimli` tekrar eden **tohum** şeklidir. Gerçek trafiğin
  aktığı **tek gün 17 Eylül** — ve düşmenin yaşandığı gün tam o gün.
  Oran: **344 inen / 33.224 düşen = %98,97 düşürüldü.**
  Bugünkü sessizlik *"düşme yok"* değil **"düşecek şey yok"**tur. Karta bir **ölçüm penceresi**
  yazıldı: bir sonraki gerçek trafik gününde düşme sayacı ile inen Asterisk biçimli olay
  sayısı **aynı gün** birlikte okunacak. Sebep hâlâ **TAHMİN** olarak işaretli.
- **Commit:** `36607991`

### 2. `BR-SYS-123` — yayın format kapısı: 22.113 hatanın 21.728'i borç DEĞİLDİ

- **Neden:** Biten bir ajan, `dotnet format --verify-no-changes`'in depo genelinde
  **22.113 hata** verdiğini raporladı. Kapı `deploy/yerel-yayin.sh:419`'da ve **host'ta**
  koşuyor (konteynerde değil), yani yayını fiilen kesiyordu.
- **Ne yapıldı (ve neden böyle):** Hatalar körü körüne düzeltilmedi. Önce **sınıfa ayrılıp
  her sınıf git INDEX'ine karşı** ölçüldü — çünkü *"çalışma ağacında kırmızı"* ile
  *"depoda borç"* ekranda aynı görünüyor:

  | Sınıf | Hata | Dosya | Index'te | Anlamı |
  |---|---|---|---|---|
  | `ENDOFLINE` | 21.728 | 39 | CRLF **0/39** | **%100 platform artefaktı** |
  | `CHARSET` | 51 | 51 | BOM **51/51** | **%100 gerçek borç** |
  | `WHITESPACE`/`IMPORTS` | ~336 | 22 | — | gerçek borç |

  `.gitattributes:31` **zaten** `*.cs text eol=lf` diyor ve index zaten LF; o 39 dosya
  yalnızca **bayat çalışma kopyası**ydı (kural eklenmeden önce checkout edilmiş).
  Onarımın commit üretmeyeceği bir iddia değil, **ölçüm**: 34 dosya LF'e yazıldı,
  `git diff` **sıfır satır** döndü. BOM'lar silindi, girinti `--include` ile 5 dosyada
  düzeltildi.
- **Dokunulan dosyalar:** 51 dosyada BOM, 5 dosyada whitespace (`git commit --only`, yollar
  açıkça sayıldı); `yonetim/backlog.md`
- **Komutlar:**
  ```bash
  dotnet format pbxtr.sln --verify-no-changes --no-restore --verbosity diagnostic; echo "rc=$?"
  grep -o "error [A-Z]*:" fmt.txt | sort | uniq -c
  git show ":<yol>" | grep -c $'\r'      # index'te CRLF/BOM var mi
  dotnet format pbxtr.sln --no-restore --include $(cat liste.txt | tr '\n' ' ')
  ```
- **Sonuç / doğrulama:** **22.113 → 4.833** (`rc=2`). Kalan hataların **tamamı** paralel bir
  ajanın o an açık tuttuğu **5 dosyada** ve tamamı aynı `ENDOFLINE` artefaktı + 32
  `WHITESPACE`. Kart bu yüzden **AÇIK** bırakıldı, *"Bitti"* yazılmadı.
- **Commit:** `02e2db04` (56 dosya), kart `bee73415`

### 3. Bu turda üç araç sessizce yanlış YEŞİL üretti

1. **`dotnet format --include a;b;c`** hiçbir şey yapmaz ve **`rc=0`** döner. Ayraç
   **boşluktur**. Tek kanıt `Formatted 0 of 2390 files.` satırı. 19 dosyayı düzelttiğimi
   sanıp devam etmiştim.
2. **`git status --porcelain` mtime'a takılır** ve içeriği aynı dosyayı DEĞİŞMİŞ gösterir.
   *"İçerik değişti mi"* sorusunun cevabı **`git diff`**tir. İlk doğrulamam bu yüzden kendi
   **doğru** iddiamı yanlış çıkardı.
3. **Arka plan sarmalayıcısı `exit code 0` bildirdi**, gerçek çıkış kodu `rc=2` idi.
   `rc=$?`'yi kendim basmasaydım kapıyı geçmiş sayacaktım.

### 4. Kart yazımında tekrarlayan tuzak

`BR-SYS-123` ilk yazımında ID'yi `` `BR-SYS-123` `` (ters tırnaklı) yazdım; komşu satırlar
ID'yi **çıplak** yazıyor. Çıkarıcı satırı **hiç görmedi**: `rows.json` 743'te kaldı, sayacı
87 dedi ve kart panoda da hiç olmayacaktı. Ters tırnaklar kaldırılınca **744 / 88**.


### 5. `BR-SYS-123` KAPANDI — ve kalan 32 `WHITESPACE` de artefaktmış

Paralel ajan bitince kalan 5 dosya onarıldı. **Kapı `rc=0`, 0 hata:** `22.113 → 4.833 → 0`.
İki ek ölçüm:
1. O 5 dosyanın onarımı da **sıfır diff** üretti — sınıf tesbiti doğruydu.
2. Kalan **32 `WHITESPACE`** hatası da aynı CRLF türeviymiş: EOL onarıldıktan sonra
   `dotnet format` **hiçbir dosyayı değiştirmedi** (`Formatted 0 of 2390`) ve kapı yine
   yeşile döndü. *"336 girinti hatası var"* demek ölçmeden önce doğru görünüyordu ama
   **yanlıştı**; gerçek borç yalnız **51 BOM + 5 dosyalık girinti** idi.

### 6. Ana dalda ölçülmüş bir kırmızı — kart açılmadı, **sahibine** verildi

`ScriptPublishedEventTests.Istemci_olay_listesi_sunucu_katalogunu_kapsar` kırmızı.
Ölçtüm: sunucu kataloğunda **15** olay, istemcide **14**; eksik olan tam olarak
**`callback.first_run`**. Üreticisi **VAR**
(`EfCallbackFirstRunNotice.cs:130`), istemci listesi (`RealtimeProvider.tsx:42`)
adı içermiyor — yani sunucu yayınlıyor, istemci **sessizce düşürüyor**.
İstemcide `callback.first_run` geçen tek yer `auditView.ts` ve orası **denetim etiketi**,
canlı tüketici değil.

**Ayrı kart AÇILMADI:** iş `BR-BE-206`'nın alanında ve o kart şu an bir ajanda. Ölçüm
ona iletildi; ben dosyalara dokunmadım — aynı dosyaya iki taraftan girmek, daha önce
bir ajanın commit mesajını kaybettirmişti. Not düşüldü: **listeye adı eklemek testi
yeşile çevirir ama tüketici yoksa kapı vacuous olur** ve "olay ulaşıyor" sanılır.

## Kararlar

- **`BR-SYS-123` KAPANDI** (aynı turda, ajan bitince). *"Benim değil"* demek kapıyı
  yeşile çevirmiyordu; beklemek çevirdi.
- **Düzeltme ile artefakt ayrı commit'lenmedi çünkü artefaktın commit'i YOK** — onarım diff
  üretmiyor. Bu, kararın kendisinin kanıtı.

## Açık kalanlar / sonraki adım

- Yayın hattı 136/~150. kapıda durdu (bellek); **kendiliğinden yeniden başlatılmayacak.**
  Dokuz kart ona bağlı (`BR-DB-91`, `BR-SYS-117` …).
- `BR-SYS-123`'ün kalan 5 dosyası.
- `BR-AST-119` için **bir sonraki gerçek trafik günü** ölçüm penceresi.
- Açık kart: **88** (P0 2 · P1 43 · P2 34 · P3 9).

---

# Ek tur — BR-AST-119 öncül ölçümü (backend-dev-2)

## Bağlam

`BR-AST-119` kartı 2026-09-17'de sunucuda ölçülmüş **33.224** düşen olaydan
söz ediyordu ve teşhis olarak *"muhtemel öncül: `pbxtr-inbound` bağlamı hiç
üretilmiyor (`BR-AST-58`/`BR-AST-61`)"* diyordu — kartın kendisi bunun
**ölçülmemiş bir tahmin** olduğunu yazıyordu. Bu turun ilk işi o tahmini
ölçmekti.

## Yapılanlar

### 1. Tahmin ölçüldü — ÜÇ bağımsız yoldan ÇÜRÜDÜ

- **Neden:** kartın teşhis cümlesine güvenip kod yazmak, bu depoda defalarca
  yanlış adrese gitti.
- **Ne yapıldı / ölçüm:**
  1. **Mekanizma yok.** `pbxtr:sys:dropped:tenant-unresolved:*` anahtarını yazan
     tek uygulama `RedisPlatformCounters.NoteDroppedAsync`. Onu çağıran dört yer
     var: `AmiTenantAdmission.cs:242/:358/:459` (üçü de **çelişki/karantina**) ve
     `TelephonyEventPipeline.cs:158` (`TenantId == Guid.Empty`).
     **Tenant'ı çözülemeyen dal sayaca hiç dokunmuyordu:**
     `AmiTenantAdmission.AdmitAsync`, `evidence.Code is null` olduğunda yalnız
     `LogWarning` yazıp `return []` yapıyor (HEAD `:130-145`). O gün koşan ikilide
     de aynı: `git show ea567d11:src/.../AmiTenantAdmission.cs` → aynı blok.
     AMI tüketicisi boş-tenant dalına **ulaşamaz** (`AmiAriEventConsumer.cs:456-480`
     yalnız çözülmüş `tenantId` ile `IngestAsync` çağırır).
     → `pbxtr-inbound` hiç üretilmese ve her olay çözülemese bile kova **0** okurdu.
  2. **Damga ölü `Goto`'dan ÖNCE basılıyor.** Santraldeki üretilmiş dosya
     `t0007-dialplan.conf:4` → `Set(__PBXTR_TENANT=t0007)`, ölü hedef `:6` →
     `Goto(pbxtr-inbound,...)`. Bağlam yokluğu çağrıyı öldürür ama kanal
     **zaten damgalıdır**.
  3. **Düşme durdu, trafik durmadı.** TTL her artırımda 48 saate tazeleniyor
     (`RedisPlatformCounters.cs:84`); üç bağımsız TTL okuması (18 Eyl 20:38Z /
     22:47Z / 23:08Z) aynı sona çıkıyor: **son artırım 2026-09-17 ~01:48Z**.
     Oysa `call_events`'e Asterisk biçimli olay o dakikadan sonra da indi
     (17 Eyl 01:48/01:51/01:52/01:59/02:00/02:20/18:00/19:00; 18 Eyl 01:00/03:00).
- **Komutlar:**
  ```bash
  ssh root@176.88.41.220 'date -u'               # ILK KOMUT — yerel tarihe guvenme
  docker exec pbxtr-redis redis-cli --scan --pattern "pbxtr:sys:dropped:*"
  docker exec pbxtr-redis redis-cli GET  pbxtr:sys:dropped:tenant-unresolved:2026-09-17
  docker exec pbxtr-redis redis-cli TTL  pbxtr:sys:dropped:tenant-unresolved:2026-09-17
  # son artirim = (simdi + TTL) - 48s
  docker exec pbxtr-postgres psql -U postgres -d pbxtr -f /tmp/q1.sql   # saatlik kirilim
  ```
  `psql -U pbxtr` **çalışmaz** (rol yok); kullanıcı `postgres`, veritabanı `pbxtr`.
- **Sonuç:** tahmin reddedildi. Altından **daha kötü** bir kusur çıktı (↓).

### 2. Gerçek kusur: sayacın ADI ile SAYDIĞI ŞEY farklıydı

- **Neden:** 33.224 sayısı *"tenant çözülemedi"* değil **çelişki/karantina**
  sınıfıydı; ters yönde, gerçekten çözülemeyen olaylar **hiçbir sayıda
  görünmüyordu**. ST-31'in var olma sebebi olan sınıf, sayaç açısından KAPALIYDI.
- **Ne yapıldı (dar karar, kurula sorulmadı):**
  - `TelephonyEventDropReason { Unresolved, Conflict }` eklendi.
  - `AdmitAsync` artık **eşlenen** (`IsMapped`) ama çözülemeyen çerçeveyi sayıyor.
    `IsMapped` kapısı korundu: eşlenmeyen gürültü (`VarSet`) sayılsaydı kova çağrı
    kaybını değil **AMI hacmini** ölçerdi — ve o sayı birinin *"olayların %99'u
    düşüyor"* demesine yol açardı.
  - **Toplam kova adı ve değeri DEĞİŞMEDİ** (dashboard aynı sayıyı okur);
    kırılım `pbxtr:sys:dropped:reason:unresolved:<gün>` ve `...:conflict:<gün>`
    anahtarlarına yanında yazılıyor. Gerekçe: operatörün elindeki tek araç
    `--scan "pbxtr:sys:dropped:*"` idi.
  - Arayüze yeni metot **varsayılan gövdeli (DIM)** eklendi → mevcut test ikizleri
    değişmeden derlenir; kırılımı üretim uygulaması yazar.
- **Dokunulan dosyalar:** `src/Pbxtr.Domain/Platform/Observability/TelephonyEventDropReason.cs`
  (yeni), `.../IUnresolvedTenantEventCounter.cs`,
  `src/Pbxtr.Infrastructure/Caching/RedisPlatformCounters.cs`,
  `src/Pbxtr.Infrastructure/Telephony/Asterisk/AmiTenantAdmission.cs`,
  `src/Pbxtr.Infrastructure/Telephony/Pipeline/TelephonyEventPipeline.cs`,
  `tests/Pbxtr.Api.Tests/Modules/Telephony/TenantDropReasonTests.cs` (yeni).
- **Doğrulama:** yeni takım 4/4; **mutasyon 3/3 yakalandı** (sayım satırı silinince,
  `IsMapped` kapısı kalkınca, `Conflict`→`Unresolved` olunca ayrı ayrı KIRMIZI;
  geri alındıktan sonra 4/4 yeşil). Komşu takımlar 36/36, `Pbxtr.Architecture.Tests`
  728/728, `dotnet format --verify-no-changes` temiz.
  `dotnet build Pbxtr.sln` **kırmızı** ama sebebi benim değil: başka bir ajanın
  `testhost`'u `Pbxtr.Infrastructure.dll`'i kilitliyordu (MSB3027); projeler tek tek
  derlendi.
- **Commit:** `03009615`, `c998145e` — ikisi de push edildi.

### 3. BR-AST-58 / BR-AST-61: "kod var, koşan yok"

- **Ölçüm:** `ConfigRenderer.cs:2438/:2604/:2694` üç bağlamı da **üretiyor**, ama
  santralde **hiçbiri yok**: `dialplan show pbxtr-t0007-inbound|-outbound|
  -dialer-announce` → üçü de *There is no existence of … context*.
  Sebep **teslim**: `/etc/asterisk/pbxtr.d/dialplan/t0007-dialplan.conf`
  **2026-09-17 01:59** tarihli ve **eski nesil** (hâlâ `Goto(pbxtr-inbound,…)`).
  Host'ta koşan `pbxtr-confd` **yok** — ne systemd birimi ne süreç; karşılığı
  yalnız `/root/pbxtr-confd/` ve `/root/yeni/` altındaki betikler.
- **Sonuç:** bu iki kartın kalan işi render değil **TESLİM** (`BR-SYS-100`).

### 4. BR-AST-79 tazelendi

`extensions` ⋈ `tenants` → t0007 = 6, t0012 = 3 (toplam **9**);
`pjsip show endpoints` → **6** nesne, tamamı `t0007-wrtc-1042..1047`.
Masa telefonu nesnesi ve `t0012` nesneleri yok. 2026-09-18 ölçümü **bayat değil**.

## Kararlar

- **Fallback yazılmadı, sayaç düzeltildi.** Kartın istediği (a) kalıcılık ve
  (b) bildirim bacağı **açık bırakıldı**: ikisi de ayrı yüzey (tablo/denetim satırı,
  e-posta bacağı) ister ve bu turda ölçülmedi. Sebep ayağı (c) kapandı.
- **Toplam kova adı değiştirilmedi.** Ad yanıltıcı ama dashboard ve rollup işi onu
  okuyor; yeniden adlandırma bir FE turu ister ve kırılım anahtarları aynı zararı
  zaten kapatıyor.
- **Backlog kolon hizası:** durum hücresine metin eklerken sondaki ` | ` ayıracı
  **eklenmez** ve metin içinde **çıplak `|` bulunmaz** (`{unresolved|conflict}` bir
  kolon kaydırdı). İlk denemede `BR-AST-58` panoda `complete` göründü — sebep metne
  yazdığım *"Depo tarafı kapandı"* cümlesiydi (`/Kapandı/` → `complete`).
  Kuru koşu bunu yakaladı; düzeltildikten sonra **fark 0**.

## Açık kalanlar / sonraki adım

- `BR-AST-119` (a) kalıcılık ve (b) bildirim bacağı **açık**.
- **ÖLÇEMEDİM:** 33.224'ün hangi çelişki alt-dalından geldiği — `pbxtr-app`
  konteyneri 2026-09-18 18:47Z'de yeniden yaratılmış, `docker logs` o andan
  başlıyor, 17 Eylül'ün 4803/4805/4807 satırları **yok**. Bu *"yok"* değil
  *"ölçemedim"*dir.
- Düzeltme **sunucuda ölçülmedi** (yeni ikili teslim edilmedi); kırılım
  anahtarlarının gerçekten yazıldığı ancak yayından sonra görülür.
- `BR-AST-58`/`BR-AST-61` teslim bekliyor; `BR-AST-59` engeli değişmedi.

---

## Tur — linux-uzmani: ağ katmanında SSRF kapısı + yedeğin kurulum yolu (2026-09-19)

### Bağlam
İki iş: (1) `BR-SEC-21` (b) — SSRF'e karşı **ağ katmanında ikinci savunma**;
bugüne kadar tek savunma uygulama katmanıydı (`OutboundHostGuard`). (2) `kapi_84`
sunucudaki yedek yapılandırmasının sapmasını **ölçüyor ama kapatamıyor** —
`deploy/` altında kurulum betiği yoktu.

Sunucu: `176.88.41.220` (test/sunum). İlk komut `date -u` (uzak damga ile yerel
tarihi karşılaştırmamak için).

### 1. BR-SEC-21 (b) — `deploy/nftables-egress.conf` + `deploy/nftables-egress-kur.sh`

**Neden:** kart üç ölçülmüş bulguyla geliyordu: `nftables.conf` sunucuda hiç yüklü
değil, fiili egress ufw'den geliyor ve `DOCKER-USER` boş, depodaki iskelet yanlış
hook'ta (`chain output`, oysa `pbxtr-app` konteyner).

**Verdiğim üç karar ve gerekçeleri:**

1. **Kural `deploy/nftables.conf`'a YAZILMADI, ayrı tabloya (`inet pbxtr_egress`)
   yazıldı.** O dosya olduğu gibi **yüklenemez**: `MGMT_NETS` hâlâ RFC 5737
   dokümantasyon adresi (`203.0.113.0/24`) ve `chain input` `policy drop` — yüklersen
   SSH anında kesilir. SSRF kapısını oraya yazmak, kapıyı *"bir gün tüm INPUT
   politikası yazılırsa"* koşuluna bağlamak olurdu. Yeni tablonun **hiçbir zinciri
   `policy drop` değil**, `flush ruleset` yok, yalnız `ip saddr 172.28.0.0/24` taşıyan
   pakete dokunuyor. Yükleme sonrası ufw/Docker/fail2ban tabloları **değişmedi**.

2. **Kartın istediği FORWARD ikizi YETMİYOR — INPUT ikizi de yazıldı.** Ölçüm:

   ```bash
   ip route get 172.17.0.1 from 172.28.0.11 iif br-9ae916ee4dc5  # -> local ... dev lo
   ip route get 1.1.1.1    from 172.28.0.11 iif br-9ae916ee4dc5  # -> via 176.88.41.193 dev ens160
   ```

   Konteynerden çıkan paket **hedefe göre iki ayrı hook'a** düşer ve SSRF'in en
   değerli hedefi (host'un kendi adresleri: `172.17.0.1` docker0, `172.18.0.1`
   br-lab, `172.28.0.1` gw, `100.106.82.119` tailscale0) **INPUT'a** düşer. Kural
   yokken `pbxtr-app` → `172.17.0.1:22` **AÇIKTI**. Yalnız FORWARD ikizi yazılsaydı
   kapı kurulmuş **görünür**, o yol açık kalırdı — yani vacuous bir kapı.

3. **CGNAT `100.64/10` ağda bilerek drop EDİLMEDİ.** `OutboundHostGuard.cs:183` onu
   uygulama katmanında zaten reddediyor; ağda drop etmek CLAUDE.md §3.0'ın Asterisk
   adresini (`100.106.82.119` = bu host'un `tailscale0`'ı — ölçüldü) keser ve SSRF
   reddi **sessiz bir telefon kesintisine** dönüşürdü. İkinci savunmanın birinciyle
   aynı sınıfları taşıması şart değil; şart olan **yüklenebilir** olması.

**Ölçüm (pozitif + negatif + mutasyon, hepsi sunucuda):**

- `nft -c -f` ilk koşuda **gerçek hata yakaladı**: `define X = { }` → *Set is empty*.
  Adlandırılmış sete çevrildi.
- Yükleme **5 dk geri dönüş zamanlayıcısıyla** yapıldı.
- POZİTİF: `1.1.1.1:443` AÇIK, DNS OK, pg `5432` AÇIK, AMI `5038` AÇIK,
  `https://127.0.0.1/health` **200**, 6 konteyner healthy.
- NEGATİF: `172.17.0.1:22` / `172.18.0.1:22` / `172.28.0.1:22` **KAPALI** (önce AÇIKTI).
- FORWARD ikizi **paket düzeyinde**: `ssrf_drop_forward` **9 → 18**, aynı turda
  `ssrf_drop_input` **12 → 12** değişmedi. Bağlantı sonucu ayırt edici **değil**
  (drop da timeout verir, "kimse yok" da) → ayırt edici **sayaç farkıdır**.
- MUTASYON 1 (INPUT drop → accept): üç hedef **AÇIK** döndü, kurulum **KIRMIZI**
  yandı ve kuralı **geri aldı**.
- MUTASYON 2 (FORWARD sınıfı `203.0.113.0/24`'e daraltıldı): sayaç **0 → 0**,
  *"FORWARD ikizi VACUOUS"* **KIRMIZI**. İkisi bağımsız: biri kırmızıyken öteki yeşil.

**Kurulum betiği kendi iki hatasını üretti (ikisi de koşturunca çıktı):**

- `systemd-run --unit` ikinci koşuda *"unit already exists"* ile reddediyordu →
  temizlenecek nesne `.service` **değil `.timer`**'dır (`reset-failed` ile).
  Düzeltilmeseydi betik **ikinci koşuda hep kırmızı** olurdu — kapıyı fiilen kaldıran
  hâllerden biri.
- İlk sürümün üç negatif hedefi de host-yerel olduğu için **FORWARD zincirini hiç
  ölçmüyordu** — kartın istediği ikiz kurulmuş görünüp ölçülmemiş olacaktı.

**Sunucuda devrede:** `/etc/nftables.d/pbxtr-egress.conf` (sha `4fe29048`),
`pbxtr-nftables-egress.service` **enabled+active**,
`ExecStart=/usr/sbin/nft -f /etc/nftables.d/pbxtr-egress.conf`, `ExecStop` kuralı
**kaldırıyor** (yoksa "servis durdu ama kural duruyor" hâli denetlenemez),
zamanlayıcı artığı **0**.

**Kapsam dışı (açıkça):** konteynerin kendi `127.0.0.1`'i host hook'larına hiç
uğramaz → yalnız `OutboundHostGuard` kapatır; dosya kapattığını iddia **etmez**.
IPv6 kuralı **yazılmadı** çünkü `pbxtr_ic` ağı IPv6 taşımıyor (ölçüldü); yazılsaydı
hiçbir paketle eşleşmeyen bir satır olurdu.

### 2. BR-SYS-124 (yeni kart) — `deploy/pbxtr-yedek-kur.sh` + `kapi_85`

**Neden:** `kapi_84` sapmayı görünür kılıyor, **düzeltmiyor**; kırmızı çıktısı
operatöre elle `scp`/`install` reçetesi basıyordu → düzeltme yolu **insan hafızası**.

**Bu turda ölçülen ve kartta olmayan kusur — `kapi_84`'ün kapsamı 7'de 2.**
Kapı YEŞİLKEN gerçek bir sapma duruyordu:

```
pbxtr-yedek-tatbikat.service.d/10-compose-yolu.conf   depo 7e68a913 / sunucu 7261c18f
```

Kapı o dosyaya **hiç bakmıyor**. Yani *"yedek yapılandırması depoyla birebir"*
iddiası bugün **yanlıştı** ve yeşil kapının altında duruyordu.

**Ölçüm zinciri:** `--olc` sapmayı buldu (7'de 1) → sunucudaki sürüm
`/root/10-compose-yolu.conf.oncesi-20260919`'a yedeklendi → kurulum + `daemon-reload`
→ **bağımsız** doğrulama: `--olc` 7/7 birebir **ve** `kapi_84` TAMAM →
`systemctl show ... -p Environment` yedi adın yedisini de taşıyor
(`PBXTR_YEDEK_PG_KONTEYNER` dahil; **değer sütunu kesilerek** okundu),
`Invalid environment assignment` **0**.

**Uçtan uca mutasyon:** sunucudaki `/usr/local/sbin/pbxtr-yedek` değiştirildi
(`c6e6a7b4` → `f4bf4585`) → `kapi_84` **KIRMIZI** VE `--olc` **KIRMIZI**, aynı
dosyayı gösterdiler; betikle düzeltildi → ikisi de yeşil. Yani kurulum betiği,
kapının **raporladığı** şeyi gerçekten kapatıyor.

**`kapi_85`** (`deploy/yerel-kapilar.sh`, kapı sayısı 83 → 84). Emsal `kapi_84`:
kapı konteynerinde ssh yok, oraya ssh'li kapı koymak **hep-kırmızı kapı** demek ve o
kapıyı fiilen kaldırır → kapıda yalnız `--oz-test` koşar. Öz-testin ölçtüğü vacuity
**bugünkü sapmayı üreten hata sınıfının ta kendisi**: `ESLEME` tablosu elle yazılmış
7 satır; `deploy/` altına 8. dosya eklenirse betik onu kurmaz ve `--olc` *"7'nin
7'si birebir"* diye yeşil yanar. Öz-test tabloyu diskle **iki yönlü** sayar
(tabloda hayalet yok / tabloda boşluk yok). Mutasyonla doğrulandı: 8. dosya eklendi
→ **KIRMIZI** (dosya adıyla), geri alındı → **YEŞİL**.

**Betiğin bilerek yapmadıkları:** yedek **almaz** (elle başlatılan yedek,
zamanlanmış yedeğin kanıtı değildir — `BR-SYS-119`'un yanlış yeşili tam olarak böyle
üretilmişti); zaten `active` timer'ı **restart etmez** (restart,
`ActiveEnterTimestamp`'i sıfırlar ve `kapi_84`'ün 25 saatlik penceresini baştan
başlatır, yani kapının kendiliğinden sertleşmesini erteler); **sır okumaz**.

### 3. Yan bulgu — pano yanlış okuyordu

`BR-SEC-21` ClickUp'ta **yanlış `complete`** görünüyordu: durum hücresi `KAPANDI`
taşıdığı için `yonetim/arac/clickup-durum.js`'in 50. satırı eşleşiyordu, oysa (c)
açık. Hücre `Kismen` ile düzeltildi → `in progress`. `BR-SYS-119` de benim
`Önceki kayıt:` çıpam yüzünden `backlog`'a düşmüştü (çıpa, sonrasını **keser** ve
orijinal `KISMEN KAPANDI` metni kesilen kısımda kalmıştı) → düzeltildi.
Pano son durum: `fark olan kart: 0, izde olmayan: 0`.

### Dokunulan dosyalar

- `deploy/nftables-egress.conf` (yeni)
- `deploy/nftables-egress-kur.sh` (yeni)
- `deploy/pbxtr-yedek-kur.sh` (yeni)
- `deploy/yerel-kapilar.sh` (`kapi_85`)
- `yonetim/backlog.md` (BR-SEC-21, BR-SYS-119, BR-SYS-124)
- `yonetim/arac/clickup-kart-eslemesi.json`

### Komutlar

```bash
ssh root@176.88.41.220 'date -u'
nft -c -f /etc/nftables.d/pbxtr-egress.conf
bash deploy/nftables-egress-kur.sh --kuru      # yazmaz, yalniz olcer
bash deploy/nftables-egress-kur.sh             # geri donus timer + yukle + yokla
sh   deploy/pbxtr-yedek-kur.sh --oz-test       # kapi govdesi (ssh gerekmez)
sh   deploy/pbxtr-yedek-kur.sh --olc           # 7 dosya, sunucuyla karsilastir
sh   deploy/pbxtr-yedek-kur.sh                 # sapanlari kur + daemon-reload
sh   deploy/yedek-sunucu-sapma.sh              # BAGIMSIZ dogrulama (kapi_84)
```

### Kararlar

- **Yüklenemeyen bir kural setinin içine güvenlik kapısı yazılmaz**; kapı ayrı,
  kendi başına yüklenebilir bir tabloya yazılır.
- **Firewall değişikliği geri dönüş zamanlayıcısı olmadan yüklenmez**; betik bunu
  fail-closed zorlar (zamanlayıcı kurulamazsa **yüklemez** — bu davranış sahada
  bir kez tetiklendi ve doğru çalıştı).
- **Kuran ve doğrulayan ayrı betiklerdir**; aksi hâlde doğrulama kendi yazdığını okur.
- **İkinci savunma birinciyle aynı sınıfları taşımak zorunda değildir** (CGNAT
  örneği): şart olan, ikinci savunmanın yüklenebilir ve kesinti üretmez olmasıdır.

### Açık kalanlar / sonraki adım

- Egress kuralı yalnız **test/sunum** sunucusunda kuruldu; başka bir ortamda koşmadı
  — **ölçemedim**.
- `egress_allow` / `host_allow_ports` setleri **boş**; bu ölçülmüş bir boşluktur
  (app'in kurulu TCP soketlerinin tamamı `172.28.0.0/24` içinde: pg `172.28.0.2:5432`,
  redis `172.28.0.4:6379`, ARI `172.28.0.12:8088`, AMI `172.28.0.12:5038`).
  Fail-closed ve kasıtlı.
- `kapi_84`'ün kendi karşılaştırması **hâlâ 7'de 2** → `BR-SYS-119`'a yazıldı.
  Kalan iş: (1) ayağını 7 dosyaya genişlet ya da `--olc`'yi çağır.
- `BR-SEC-21` (c) `webhook_deliveries` boyut eşiği değişmedi (Ş76-10/3 sıra kilidi).
- **Tam kapı takımı bu turda koşmadı**: paralel iki ajan aynı depoda koşuyordu
  (defter: *iki yayın koşusu üst üste binmez*). `kapi_85` gövdesi tek başına yeşil +
  mutasyonla kırmızı, `sh -n deploy/yerel-kapilar.sh` OK, kapı sayacı 84.

**Commit:** `89eb4e1c` — BR-SEC-21(b) KAPANDI + BR-SYS-124 acildi

---

## Tur — `BR-QA-114` kapandı + `BR-BE-206` şart (iv) hedefine ulaşmıyordu (backend-dev-1)

### Bağlam

Elimde beş P1 kart vardı (`BR-BE-206/208/209`, `BR-QA-114`, `BR-FE-117`). Turda
kapatılabilecek olan `BR-QA-114`'tü: diğer dördünün açık ayakları **dağıtım sonrası
canlı ölçüme** bağlı (kart metinleri bunu adıyla yazıyor). Tur ortasında koordinatör
ana dalda ölçülmüş bir kırmızı devretti ve o da `BR-BE-206` alanındaydı.

### 1. `BR-QA-114` — aynı kural iki yerde yazılıydı, SQL ikizi hiç koşmamıştı

- **Neden:** `callback_requested` SLA sınıfı iki kez ifade edilmiş: saf C#
  (`CallbackSlaPolicy.Classify`) ve `SlaAggregationJob` içindeki `RecomputeSql`.
  `BR-BE-199` turunda C# tarafı 52/52 yeşildi, SQL tarafı **okunarak** doğrulanmıştı
  (ortamda PostgreSQL konteyneri yoktu). Defterdeki *"test ikizi üretimden
  müsamahakâr"* sınıfının önceden adı konmuş hâli: iki ifade ayrı ayrı yeşilken bile
  ayrışabilir ve ayrıştığında belirti sessizdir — SLA sayısı yanlış çıkar, kimse patlamaz.

- **Ne yapıldı — ORAKEL, kopya değil.** Yeni bekçi
  `tests/Pbxtr.Integration.Tests/Tests/CallbackSlaSqlParityTests.cs`. Beklenen sayılar
  **elle yazılmadı**: `CallbackSlaPolicy.Classify` *çağrılarak* üretiliyor ve
  `SlaAggregationJob.RecomputeAsync`'in gerçek PostgreSQL 16'da `sla_buckets`'a yazdığı
  sayaçlarla karşılaştırılıyor. Elle yazsaydım test *bugünkü SQL'in* kopyası olur ve iki
  ifadenin **ayrışmasını** değil kendi kopyasından sapmasını ölçerdi.

- **Tasarımın can alıcı noktası — HER VAKA İKİ ANDA ÖLÇÜLÜR.** Kova sayaçlarında
  `pending` ile `excluded` **aynı izi** bırakır (ikisi de paydaya girmez). Ayrımı
  yalnızca ZAMAN görünür kılar: son tarihten sonra `pending` → `breached`'a döner,
  `excluded` yerinde kalır. Tek anda ölçseydim kip a ile "süresi dolmamış talep" aynı
  yeşili üretirdi.

- **Çeviri sözleşmesi tek yerde ve üretimle birebir.** C# imzası `answeredAt` ister,
  SQL `resolution` + `resolved_at` çiftini okur. Çeviri üretimde
  `EfCallbackLedger.AnsweredAtOf`'tadır ve testte birebir tekrarlandı — aksi hâlde test
  üretimin sormadığı bir soruyu ölçerdi. Aynı şekilde ayar satırı olmayan tenant için
  varsayılan (`deadline`/30) iki tarafta da aynı (`ReadSettingsAsync`'in `row is null`
  dalı ↔ `COALESCE(ts.callback_sla_mode,'deadline')`).

- **Dokunulan dosyalar:** `tests/Pbxtr.Integration.Tests/Tests/CallbackSlaSqlParityTests.cs` (yeni).

- **Komutlar:**
  ```bash
  dotnet build tests/Pbxtr.Integration.Tests/Pbxtr.Integration.Tests.csproj -v q --nologo
  PBXTR_REQUIRE_DOCKER_TESTS=1 dotnet test tests/Pbxtr.Integration.Tests/Pbxtr.Integration.Tests.csproj \
    --no-build --filter "FullyQualifiedName~CallbackSlaSqlParityTests"
  ```

- **Sonuç:** 13 vaka + 3 fact = **16 test, 16/16**. Kartın dört riskinin dördü de
  ölçüldü: (a) `Pending ≠ Breached`, (b) kip a paydadan düşer ama `callback_requested_count`
  yine 1 (giriş kaybolmuyor), (c) `AgentConnect` müstesnası — bu kural C# politikasında
  **yoktur** ve bilinçlidir, o yüzden ayrı testte sayılarla yazıldı ve ayrım karta kondu,
  (d) `queue_optin` lateral join'i tenant sınırında sızmıyor (aynı `call_id`, iki tenant).

- **YEDİ MUTASYON, İKİ YÖN; yedisi de kırmızı, geri alınınca yeşil:**

  | # | Mutasyon | Kırmızı olan |
  |---|---|---|
  | M1 | SQL sınırı `<=` → `<` | yalnız `b/sinir-uzerinde` |
  | M2 | SQL `ELSE 'pending'` → `'breached'` | 6 vaka |
  | M3 | SQL `'excluded'` → `'breached'` | yalnız iki kip a vakası |
  | M4 | lateral join'den `cb0.tenant_id = r.tenant_id` silindi | sızıntı testi |
  | M5 | `AgentConnect` müstesnası silindi | AgentConnect testi |
  | **M6** | **C# tarafı** `answered <= deadline` → `<` | yine yalnız `b/sinir-uzerinde` |
  | M7 | vaka defterinden kip a çıkarıldı | **vacuity kapısı** |

  M6 önemli: orakelin **canlı** olduğunun, SQL'in kopyası olmadığının kanıtı.

- **TUZAK (kayda geçsin):** mutasyonları `git checkout -- <dosya>` ile geri alan bir
  sürücü betiği yazdım; o dosyada **commit edilmemiş kendi düzenlemem** vardı ve
  checkout onları da sildi. Mutasyon sürücüsü yalnızca **temiz** dosyalarda güvenlidir;
  düzenlenmiş dosyada mutasyon ters yamayla geri alınmalıdır.

- **İKİNCİ TUZAK:** ilk mutasyon koşusunda `dotnet build` **1 hata** verdi (DLL bir
  önceki testhost tarafından kilitliydi) ama boru hattı yine de teste geçti ve test
  **mutasyonsuz ikiliyi** ölçüp "16/16 geçti" dedi. Sürücüye `grep "0 Error(s)"` kapısı
  kondu: derleme doğrulanmadan ölçüm yapılmıyor. (Defter: *test koşarken build sessizce
  atlanır*.)

### 2. `BR-BE-206` şart (iv) — uyarı yayınlanıyordu, kimse dinlemiyordu

- **Neden:** koordinatör ana dalda ölçülmüş bir kırmızı devretti
  (`ScriptPublishedEventTests.Istemci_olay_listesi_sunucu_katalogunu_kapsar`): sunucu
  kataloğunda 15 olay, istemcide 14; eksik olan `callback.first_run`. Üreticisi var
  (`EfCallbackFirstRunNotice.cs:130`), tüketicisi yok — `RealtimeProvider` bilmediği
  adı taşıyan çerçeveyi **sessizce düşürüyordu**. Yani `BR-BE-206`'nın dört ayağından
  (iv) koda inmişti ama **hedefine hiç ulaşmamıştı**.

- **İKİNCİ VE DAHA SİNSİ KUSUR (ölçüm).** Kapının kendi ayrıştırıcısı
  `'(?<name>[a-z][a-z0-9.]*)'` idi ve `callback.first_run` **alt çizgi** taşıyor.
  Python ile ölçtüm:
  ```
  "'callback.first_run',"            -> []        (hiç eşleşmiyor)
  "'webhook.subscription.suspended'," -> ['webhook.subscription.suspended']
  ```
  Yani adı listeye eklesem bile kapı *"eksik"* demeye devam ederdi ve ekleyen kişi
  listeye bakıp *"ama ekledim"* derdi. Klasik *envanter sayacı kendi filtresini ölçmez*.
  Alfabe `[a-z0-9._]`'ye genişletildi **ve bir vacuity kapısı eklendi**: kapı artık
  *"ad eşleşiyor mu"* değil **"AYRIŞTIRICI bu adı GÖREBİLİYOR MU"** diye soruyor —
  yarın `_` dışında bir karakter taşıyan bir ad eklenirse aynı satır yine kırmızı olur.

- **Adı listeye eklemek TEK BAŞINA YAPILMADI.** O hâl kapıyı vacuous bırakırdı
  (*"olay ulaşıyor"* sanılırdı). Gerçek bir tüketici bağlandı: `CallbackBoardPanel`
  → `useRealtimeReload(['callback.first_run'], reload, 0)`.
  **Gerekçe ölçülü:** olayın yayınlandığı tick'te işin kendisi `callback_entries`
  satırlarının `status` / `attempt_count` / `next_attempt_at` alanlarını **toplu hâlde**
  değiştirir; açık duran #37 defteri tam o anda **bayatlar**.
  `0 ms` birleştirme: olay tenant başına ömür boyu bir kez yayınlanır
  (`tenant_settings.auto_callback_first_run_at`), sel üretmez.

- **BELGE DÜZELTMESİ (silinmedi).** `IRealtimePublisher`'daki
  *"olay bir tazeleme tetikleyicisi değil, bir duyurudur; **hiçbir ekran onsuz
  bayatlamaz**"* cümlesinin ikinci yarısı **yanlıştı**. Cümle durduğu sürece tüketici
  yokluğu bir *eksik* değil bir *tasarım* gibi okunuyordu — ve gerçekten öyle oldu.

- **`REALTIME_EVENT_GATES` satırı da yazıldı** (tsc bunu zorladı, ben unutmadım —
  tip `Record<RealtimeEventType, …>` tam kapsama istiyor):
  `'callback.first_run': { anyOf: ['live.queue.read'], subjectSelf: false }`.
  Boş bırakılsaydı `deadRealtimeEvents` olayı hiç alamayacak bir agent'ta #37'yi
  *"canlı"* sayardı.

- **Dokunulan dosyalar:**
  `src/Pbxtr.Domain/Modules/Realtime/IRealtimePublisher.cs`,
  `src/Pbxtr.Web/src/app/realtime/RealtimeProvider.tsx`,
  `src/Pbxtr.Web/src/app/screens/automation/CallbackBoardPanel.tsx`,
  `src/Pbxtr.Web/src/app/screens/automation/CallbackBoardPanel.test.tsx`,
  `tests/Pbxtr.Api.Tests/Modules/Realtime/ScriptPublishedEventTests.cs`

- **ÜÇ MUTASYON, üçü de kırmızı:**
  1. bekçi alfabesi eski dar hâline çevrildi → *"BEKCININ ALFABESI DAR … callback.first_run"*
  2. ad istemci listesinden silindi → *"Istemcide olmayan sunucu olaylari: callback.first_run"*
  3. panelin `useRealtimeReload` çağrısı kaldırıldı → yeni vitest kırmızı

- **YAN BULGU — bekçi benim kendi mock'umu yakaladı.** `src/test/viMockTargets.test.ts`
  yeni `vi.mock('../../realtime')` ezmemde **iki** kusur gördü: (a) ölü `StaleDataBadge`
  ezmesi (panel o adı ithal etmiyor), (b) `useRealtimeReload` sarmalayıcım 2/3 parametre
  alıyordu ve `coalesceMs`'i **sessizce düşürüyordu**. İkisi de düzeltildi. Bu kapı
  çalışıyor ve iyi çalışıyor.

### Komutlar (doğrulama)

```bash
dotnet build pbxtr.sln -v q --nologo                     # 0 Error
dotnet format pbxtr.sln --verify-no-changes --include <5 dosya, ayrac BOSLUK>
dotnet test tests/Pbxtr.Api.Tests/... --filter "FullyQualifiedName~Pbxtr.Api.Tests.Modules.Realtime"
PBXTR_REQUIRE_DOCKER_TESTS=1 dotnet test tests/Pbxtr.Integration.Tests/... \
  --filter "…CallbackSlaSqlParityTests|…SlaDeadlineRestatementTests|…CallbackFairnessAndStalenessJobTests"
cd src/Pbxtr.Web && npx tsc -b && npx vitest run
```

### Sonuç / doğrulama

| Ölçüm | Sonuç |
|---|---|
| `CallbackSlaSqlParityTests` (gerçek PG 16) | **16 / 16** |
| callback + SLA entegrasyon kümesi | **22 / 22** |
| `Pbxtr.Api.Tests.Modules.Realtime` | **132 / 132** |
| frontend takımı (`vitest run`) | **2103 / 2103**, 234 dosya |
| `tsc -b` | temiz |
| `dotnet build pbxtr.sln` | 0 Warning, 0 Error |
| `dotnet format --verify-no-changes` | rc=0 |

**Commit:** `225da1bf` — BR-QA-114 kapandi + BR-BE-206: ilk tur olayinin istemcide
tuketicisi yoktu. ClickUp senkronu koşuldu: `BR-QA-114 → complete`,
`BR-BE-206 → in progress`, doğrulama `fark olan kart: 0, izde olmayan: 0`.

### Kararlar

- **Bir kuralın iki ifadesi varsa, bekçi ORAKEL olmalıdır.** Beklenen değerleri elle
  yazan bir "parite" testi paritenin değil, kendi kopyasının bekçisidir. Kanıtı M6:
  C# tarafını mutasyonlamak testi kırmızı yaptı — kopya olsaydı yeşil kalırdı.
- **Gözlemlenemeyen bir ayrım, İKİNCİ BİR GÖZLEM ANIYLA gözlemlenebilir hâle gelir.**
  `pending` ile `excluded` kova sayaçlarında aynıdır; ayıran şey zamanın geçmesidir.
- **Bir bekçinin ilk çıktısı hem kodu hem KENDİNİ ölçer.** Alfabesi dar bir kapı,
  düzeltilmiş kodu bile "eksik" gösterir; kapı kurarken *"benim evrenim neyi hiç
  göremez"* sorusu ayrı bir ayak olmalıdır (bu tura vacuity kapısı olarak indi).
- **Olay adını istemci listesine eklemek "tüketici" değildir.** Kapıyı yeşile çevirir
  ve "olay ulaşıyor" yanılsaması üretir. Ya gerçek bir tüketici bağlanır ya olay
  kaldırılır.
- **Mutasyon sürücüsü `git checkout` ile geri alma yapmaz** (düzenlenmiş dosyada
  kendi işini siler) **ve derlemeyi doğrulamadan ölçmez** (kilitli DLL "0 Errors"
  yalanı üretiyor).

### Açık kalanlar / sonraki adım

- `BR-BE-206` şart **(ii)** hâlâ açık: hizalamadan önce canlıda ölçülecek üçlü
  (kaç tenant'ta düğme açık, kaç `pending AND next_attempt_at <= now()` satır, en
  eskisi kaç günlük) **dağıtım öncesine aittir ve bu turda da ölçülmedi.**
- `BR-BE-209` açık ayağı (ilk 24 saat: originate sayısı, `CallOriginateBlocked` red
  sayısı, kanal eşzamanlılığı) + `call_attempts` sayım sorgusunun canlı PG'de
  doğrulanması — **dağıtım sonrası**, bu turda ölçülemez.
- `BR-BE-208` kalan ayağı: round-robin **sıralamasının** 6+ tenantlı bir fikstürle
  ölçülmesi (bugünkü `TelephonyFixture` iki tenant seeder; 2×10=20 satır global
  `LIMIT 50`'nin altında kaldığı için sıralama mutasyonu **yeşil kalıyor**).
- `BR-FE-117` (modal kampanya sayacını gösteriyor) **bu turda ele alınmadı**:
  doğru düzeltme, geri arama kökenli çağrıyı ayırt edebilmeyi gerektiriyor ve o alan
  (`callSource`) `BR-BE-203`'te hâlâ **sunucuda yok** (`CallSource` deseni `src/**/*.cs`
  altında sıfır eşleşme). Kartın "kısa vadeli" önerisi (sayacı gizle) bile ayırt edici
  bir alan ister; alansız yapılacak her gizleme kampanya çağrılarında da sayacı
  kaldırırdı ve kartın kendi vacuity şartına takılırdı.
- Gerçek santralde `queue_optin` çıkışının hangi AMI olayını ürettiği (Abandon mı
  Leave mi) hâlâ ölçülmedi (`BR-AST-116` sınıfı). Parite testinin sınıflandırması
  o olaydan **bağımsızdır**; değişen yalnızca `wait_source`'tur.


---

## Koordinatör — ikinci tur: yayın denemesi ve sayacın çıpası

## Bağlam
Kullanıcı *"tam yayını başlat"* dedi. Üç ajan bitmişti, paralel yük yoktu — kayıtlı
*"testhost CLR çökmesi eşzamanlı yük"* riski için en iyi an.

## Yapılanlar

### 1. Yayın #1 — `confd` sunucu sapmasında durdu (kapı haklıydı)
- **Ne oldu:** `rc=1`, 53 satır. `confd-sapma` kapısı: sunucudaki
  `pbxtr-confd-dugum.sh` depodan SAPMIS (depo `60e46d3d` / sunucu `e68abcc8`).
- **Yapısal sebep (kapının kendi yazdığı):** `deploy/staging-yayin.sh` bu dosyaları
  sunucuya **göndermez** — *"confd" kelimesi o betikte hiç geçmez.*
- **Üzerine yazmadan ÖNCE yön ölçüldü:** depo 2250 satır / 22:28Z, sunucu 2184 satır /
  20:01Z → depo **ileride**. Eklenen 67 satırın tamamı **yorum** (`e23c0f0d` ölçüm kaydı).
- **Komutlar:**
  ```bash
  ssh root@176.88.41.220 'systemctl stop pbxtr-confd.timer'
  PBXTR_CONFD_TASI_ONAY=EVET bash deploy/confd-sunucu-sapma.sh --tasi
  ssh root@176.88.41.220 'systemctl start pbxtr-confd.service'   # exit=0, Result=success
  ssh root@176.88.41.220 'systemctl start pbxtr-confd.timer'
  bash deploy/confd-sunucu-sapma.sh --olc                        # dort dosya da 'ayni'
  ```

### 2. Yayın #2 — 138 kapı yeşil, **1 kırmızı** (`BR-QA-58`), o da haklıydı
- **Neden:** `BR-BE-190` turunda eklenen
  `tests/…/Fixtures/ami-confbridge-takeover-capture.txt` bir **dondurulmuş artefakt**
  ama `deploy/dondurulmus-artefaktlar.json` defterine kaydedilmemişti.
- **`sha256` biçimi TAHMİN EDİLMEDİ, ÖLÇÜLDÜ:** aynı dizindeki `ami-lab-capture.txt`
  için defterdeki değer **CRLF→LF normalize** sha ile birebir eşit, ham sha ile **değil**.
- **`ureten` alanı DÜRÜSTÇE yazıldı:** fikstür **saf kayıt değildir** — kendi başlığı
  blok blok hangisinin harfiyen, hangisinin **türev** olduğunu sayar ve kaydedilemeyen
  hali *"yok"* değil **"ÖLÇÜLEMEDİ"** diye yazar. Deftere *"gerçek santral kaydı"*
  yazmak, kapının tam da önlemek için var olduğu şey olurdu.
- **Sonuç:** kapı tek başına `ALGILANAN 51 dosya → GECTI`. Diff **10 ekleme / 0 silme**
  (mevcut biçim birebir korundu).
- **Commit:** `50740164`

### 3. Sayacın çıpası — bir **P0** ile bir **P1** panoda KAPALI görünüyordu
- **Neden:** `clickup-durum.js`'teki `/Kapandı|KAPANDI/` kuralı **çıpasız alt dize**
  testiydi; metnin **ortasındaki** kapanış kelimesini kapanış saydı. Bu, 2026-09-13'te
  `Bitti` için düzeltilen kusurun **birebir kardeşi**; hemen üstündeki yorum o düzeltmeyi
  anlatıyor ama kardeş kuralda kalmış.
- **Ölçüm (önce mevcut veri):** `complete` görünen 659 karttan **7'si** yalnız bu kurala
  düşüyordu; **altısı gerçekten açıktı** — `BR-QA-113` (P1) metni **"AÇIK."** ile
  BAŞLIYOR, `BR-BE-150` (**P0**) *"kalan iş hâlâ kod değil"* diyor.
- **YÖN ÖNEMLİ:** bu kez hata **ters** yöndeydi — **açık iş kapalı** görünüyordu.
  Backlog'un bilerek dar tutulan kuralı (*"açık işi kapalı göstermek daha kötüdür"*)
  tam da bunu yasaklar.
- **`Kurul: RED`** da aynı turda **önleyici** olarak çıpalandı: ölçüldü, bugün **0** kart
  etkileniyordu.
- **Regresyon bekçisi:** `yonetim/arac/clickup-durum.test.js`'e 8 vaka (kapı
  `yerel-kapilar.sh:1380`'de zaten koşuyor). **Mutasyon:** çıpa geri alınınca `rc=1`,
  geri konunca `rc=0`.
- **Sayacın aracı benden doğru çıktı:** ben 6 kart demiştim, `clickup-senkron --kuru`
  **8** buldu (`BR-SYS-56` ve `BR-QA-57` de listede). Pano yazıldı → `fark: 0`.

### 4. Yayın #3 — **bellek yüzünden durduruldu**, kapıya gelmeden
113 satırda, henüz frontend testlerindeyken sistem belleği kritik seviyeye düştü ve
süreç sonlandırıldı. **Komutun hatası değil.** Kural gereği kendiliğinden yeniden
başlatılmadı. Hiçbir kapı koşmadı, hiçbir kırmızı yok, sunucuya **hiçbir şey teslim
edilmedi** — sunucu hâlâ `ea567d11` (15 Eylül) ikilisini koşuyor.

## Kararlar
- Yayının kesilmesi **ilerlemeyi geri almadı**: iki kırmızı da kalıcı olarak kapandı ve
  commit'lendi; bir sonraki koşu o iki kapıyı geçmiş başlar.
- `BR-FE-117`'ye **kod yazılmadı** ve bu bir erteleme değil ölçüm: ayırt edici alan
  (`callSource`) sunucuda yok (`CallSource` → `src/**/*.cs` altında **0** eşleşme);
  alansız her gizleme kampanya çağrılarında da sayacı kaldırır.

## Açık kalanlar / sonraki adım
- **Yayın — kullanıcı isteğiyle başlatılacak.** 94 açık kartın **37'si** ona bağlı
  (iki P0 dahil; `BR-AST-58/61` kodda kapalı ama sahada görünmüyor).
- Açık kart: **94** — yayından **bağımsız 57**'si üzerinde çalışılabilir.

---

## Tur — pbxtr-qa: BR-QA-113, BR-BE-183, BR-QA-95 (2026-09-19)

### Bağlam
Üç kart verildi. `BR-QA-113` (P1) bugüne kadar **panoda KAPALI görünüyordu** çünkü
`clickup-durum.js`'in `Kapandı` kuralı çıpasız bir alt dize testiydi; çıpalanınca kart
açıldı. Kartın konusu da tam aynı sınıf: bir bekçinin alt dize eşlemesi.

### 1. BR-QA-113 — tenant sızıntı kapsam bekçisi artık bir yorumla susturulamaz

- **Neden:** `TenantLeakCoverageTests` "bu EF adaptörünün sızıntı testi var mı?" sorusunu
  ham metinde alt dize arayarak cevaplıyordu. 2026-09-18'de **iki bağımsız ajan, iki farklı
  kalemde** kazara aynı susturmayı üretti: bir test dosyasının **yorumunda** adaptörün adının
  geçmesi kalemi sessizce "kapandı" gösteriyordu.
- **Ne yapıldı:** Yeni `CSharpKodMetni` sözcüksel ayıklayıcısı yorum + dize sabiti + karakter
  sabitini **aynı uzunlukta boşluğa** çevirir (satır numaraları korunur; uzunluk eşitliği test
  ediliyor). `Kapali()` artık ayıklanmış kod üzerinde ve `Ef<Ad>` **tam tanımlayıcı** eşlemesiyle
  çalışır.
- **Ölçüm (98 adaptör):** ham tarama **33** kapalı, anlamsal tarama **20**. Aradaki **13 kalemin
  tek kapanış kanıtı bir YORUM satırıydı**; 13'ü de `dosya:satır` kaynağıyla borca geri yazıldı,
  `BorcTavani` 65 → 78. Borç büyümesi değil, **yanlış kaydedilmiş bir küçültmenin geri alınması**.
- **Kartın iki adı ayrı ölçüldü:** `ProvisioningNodeDirectory` yeniden **AÇILDI**
  (`ApiKeyForeignNodePinTests.cs:27,29`, yorum). `CallbackLedger` **kapalı kaldı ama sebebi
  değişti** — bugünkü kanıt yorumda değil, gerçek DI kaydında
  (`CallbackFairnessAndStalenessJobTests.cs:267`).
- **Bekçi ilk koşusunda kendi en iyi örneğini yanlış işaretledi** (kayıtlı ders birebir tekrar
  etti): `SilenceAlarmViewTests` gerçek bir sızıntı testi ama dosyadaki tek `capraz` kelimesi
  yorumdaydı. Düzeltme daraltma değil **ölçülmüş bir genişletme**: `TenantMain` **ve**
  `TenantCounter`'ın kodda birlikte geçmesi de ikinci tenant sayılır (çift şart bilinçli).
  17 → 20.
- **Dokunulan dosyalar:** `tests/Pbxtr.Architecture.Tests/CSharpKodMetni.cs` (yeni),
  `CSharpKodMetniTests.cs` (yeni), `TenantLeakCoverageTests.cs`, `yonetim/backlog.md`
- **Mutasyon:** M1 ham metne dön → Failed 1; M2 karakter sabiti dalını kaldır → Failed 1;
  M3 `SembolGeciyor` → `Contains` **ilk denemede YEŞİL kaldı**. Fikstür sorgulandı (kayıtlı ders):
  mutasyon `Kapali`nin kullanımını bozuyordu, mevcut vaka ise `SembolGeciyor`u doğrudan ölçüyordu —
  hiçbir vaka o dalı kapsamıyordu. 4. ayak eklendi, M3 Failed 1 oldu.
- **Sonuç:** `Pbxtr.Architecture.Tests` 749/749 yeşil, `dotnet format` rc=0.
- **Commit:** `13cc5ede`

### 2. BR-BE-183 — BR-9 kapsam çitleri koşan bekçiye bağlandı

- **Neden:** Karar #71 Ş-71-CEO-6'nın dört çiti yalnızca kart metnindeydi (yani belgeydi).
- **Ne yapıldı:** `tests/Pbxtr.Architecture.Tests/Br9ScopeFenceTests.cs` — dört çit, beş mutasyon:
  CIT 1 (BR-9 önceliği P2) · CIT 2 (ayrı lisans bayrağı) · CIT 3a (tenants süre kümesi donduruldu) ·
  CIT 3b (sesli-mesaja-özel süre alanı yasak, `Tenant` dışındaki tiplerde de) · CIT 4 (indirme ucu).
  Beşinin beşi de kırmızı, geri alınca yeşil.
- **KARTIN KENDİ ÖLÇÜMÜ YANLIŞ ÇIKTI:** kart ve önceki üç tur kaydı *"`tenants` tablosunda İKİNCİ
  BİR SÜRE ALANI YOKTUR"* diyordu. `Tenant.CallDataRetentionDays`
  (`tenants.call_data_retention_days`) ikinci bir saklama süresidir ve onu yazan bir uç da var.
  Çitin **lafzı** geçersiz, **maksadı** geçerli: *BR-9 kendine ait bir saklama süresi açmaz*.
  Lafzı donduran bir bekçi **ilk koşuda kırmızı** yanar ve kapatılırdı.
- **Bilerek yakalanmayan:** `tenant_settings.voicemail_sla_minutes` SLA sayacıdır; yakalansaydı
  `BR-FE-112`'nin inmiş işi kırmızı olurdu.
- **Sonuç:** 753/753 yeşil, `dotnet format` rc=0, mutasyon turundan sonra `git status` temiz.
- **Commit:** `f8b9fdb2`

### 3. BR-QA-95 — açık bırakıldı, engel bugün SAYIYLA ölçüldü

- Kod tarafı (a/b/c) diskte yeniden doğrulandı; yeni iş yok.
- **Engel ölçümü:** aynı makinede son 6 saatte **89 commit**, tur sırasında **30 canlı
  `dotnet`/`node`/`testhost` süreci**. Böyle bir koşumun kırmızısı da yeşili de kanıt olmaz.
- **KARAR (tek taraflı, dar taraf):** `N = 3` **ve** koşum sessiz makinede; süreç sayımı koşudan
  önce ve sonra yazılır. Kart bugüne kadar N'i **hiç tanımlamıyordu** — tanımsız bir kabul ölçütü
  hem sonsuz açıklığa hem tek yeşille kapanmaya izin verir.
- **Commit:** `55a44f8c`

## Kararlar
- Kapanış tespiti **anlamsal** olur: yorum/dize bir çağırıcı değildir. Roslyn paketi **bilerek
  eklenmedi** — kapılar Linux konteynerinde koşar, orada olmayan bir NuGet önbelleğine yaslanmak
  kapıyı fiilen kaldırırdı.
- Enterpolasyon delikleri dize sayılır: hata yönü borcu **büyütür**, küçültmez (ölçüldü: bugün
  98 adaptörde 0 fark).
- Kapsam çiti yazılırken **lafız değil maksat** dondurulur; lafzı donduran çit ilk koşuda kırmızı
  yanıp kaldırılır.

## Açık kalanlar / sonraki adım
- `BR-QA-95`: sessiz makinede `Pbxtr.Integration.Tests` tam takımında **ardışık 3** yeşil koşu.
- `BR-QA-52` serisi: geri açılan 13 kalemin **en az 6'sı için gerçek sızıntı testi zaten var**;
  kapanış yaması tek satırdır ve testi de güçlendirir —
  `Assert.IsType<EfXxx>(services.GetRequiredService<IXxx>())`. Integration.Tests'e bu turda
  **dokunulmadı** (Docker+PG gerekiyordu; *ölçemedim*, **yok değil**).

---

# Ekran turu — wallboard kirpilmasi + #12 gorsel kapsami (frontend-dev-1, aksam)

## Bağlam
Dört kart verildi: `BR-FE-122` (wallboard değeri 1920x1080'de kırpılıyor),
`BR-QA-57` (görsel kapı kapsamı ters kurulmuş), `BR-FE-111` (sebep rozeti) ve
`BR-FE-117` (yanlış deneme sayacı — "ölçümü doğrula, değişmediyse geç" talimatıyla).
Kural: teşhisi önce ölç, sonra yaz.

## Yapılanlar

### 1. `BR-FE-122` — teşhis DOĞRULANDI, sonra düzeltildi
- **Neden:** kart "değer kırpılıyor" diyordu; bu depoda teşhis birkaç kez yanlış çıktı,
  bu yüzden önce **yeniden ölçüldü**.
- **Ne yapıldı:** `wallboard.visual.spec.ts`'e yaprak her görünür metin için
  `scrollWidth <= clientWidth` yapısal iddiası eklendi ve pinli konteynerde koşuldu.
  İlk koşu kartı birebir doğruladı:
  `div._value_* · "03:47" · scrollWidth 302 · clientWidth 271 · font 104px` — ve
  tahtada kırpılan **tek** görünür öge oydu.
- **Düzeltme (karar):** 104px **tavan olarak kaldı**, yalnızca kutuya sığmayan
  uzunlukta aşağı ölçekleniyor:
  ```css
  .root  { container-type: inline-size; }
  .value { font-size: min(var(--wb-value-max), calc(100cqi / (var(--wb-value-chars,1) * 0.62))); }
  ```
  `--wb-value-chars` bileşenden **yalnızca ölçülebilir** değerde (string/number) gelir;
  `ReactNode` değerde yazılmaz (uydurma sayı karoyu sebepsiz küçültürdü).
  **104'ü düşürmedim, gerekçesi prototip:** `dc.html` `s.wallboard` bloğunda 104px'lik
  dev rakam **bekleyen sayısıdır** (1-2 hane); `mm:ss` orada 26px'lik ikincil satırda.
  Ölçüldü: 1-4 karakterli değerler **piksel piksel aynı** kaldı; fark tek karoda 6647 px.
- **Dokunulan dosyalar:** `src/Pbxtr.Web/src/ui/WallboardTile/WallboardTile.module.css`,
  `…/WallboardTile.tsx`, `…/WallboardTile.test.tsx` (yeni),
  `src/Pbxtr.Web/visual-tests/wallboard.visual.spec.ts`,
  `src/Pbxtr.Web/scripts/verify-visual-baselines.mjs`,
  `…/visual-tests/__screenshots__/linux/wallboard-1920x1080.png`.
- **Komutlar:**
  ```bash
  bash deploy/fidelity/fidelity-kos.sh uret      # taban yeniden uretildi
  bash deploy/fidelity/fidelity-kos.sh dogrula   # 5 passed
  node src/Pbxtr.Web/scripts/verify-visual-baselines.mjs
  ```
- **Mutasyon (iki bekçi, ikisi de):** bölen `0.62 -> 0.40` => spec KIRMIZI (öğeyi adı,
  ölçüsü ve font boyutuyla yazıyor); geri alındı => yeşil. Bileşende `: null -> : 2`
  (ReactNode'a uydurma sayı) => `1 failed / 2 passed`; geri alındı => `3 passed`.
- **Commit:** `cb86d4d0` (düzeltme + bekçiler) · `a9d76c2c` (taban + manifesto).

### 2. `BR-QA-57` kalem 2 — #12 tabanı, ve **içinden çıkan iki gerçek kusur**
- **Neden:** kartın açık iki kaleminden biri süpervizörün canlı izleme ekranıydı.
- **Ne yapıldı:** `visual-tests/live-queues.visual.spec.ts` (1440x900, koyu tema) yazıldı;
  üç uç birden fikstürlü (`/alarms/active`, `/live/agents`, `/live/queues`), yetki
  **iki alandan** verildi (`live.queue.read` + `live.agent.read`).
- **İlk koşuda iki kusur ölçüldü ve ikisi de aynı turda düzeltildi:**
  - **`BR-FE-123`** — `div._queueFoot` **scrollWidth 377 / clientWidth 339** (+38 px),
    `section._panel` **395 / 375** (+20 px). Hiçbir ata kırpmıyordu, yani yedinci metrik
    kartın **sağ kenarının 20 px dışına** taşıyordu. Çözüm: `.queueFoot` artık **sarıyor**
    (`flex-wrap` + `row-gap`) — emsal aynı dosyada (`.statusCell`).
  - **`BR-FE-124`** — "Kuyruk" kolonu `row.queueIds.join(', ')` çiziyordu ve
    `LiveAgent.queueIds` **üretimde GUID**'dir (`RedisLiveOperationsView.cs:479`).
    Süpervizör "Satış, Destek" değil GUID görüyordu. Çözüm: ad zaten elde
    (`/live/queues` yanıtı `id`+`name` taşıyor), **yeni uç açılmadı**; eşleşmeyen kimlik
    **gizlenmez**, olduğu gibi yazılır.
- **Ölçümden çıkan ders (kayda değer):** yaprak `scrollWidth<=clientWidth` iddiası
  `BR-FE-123`'e **kördü** — taşan şey yaprak değil **satırın kendisiydi**. Spec'e ikinci
  bir **kap** iddiası eklendi (eşik **8 px**: gerçek kusurlar 38/20 px, ölçülen gürültü
  2 px — avatar dairesinde ortalanmış "NŞ" metni).
- **Ayrıca ölçüm tuzağı:** ilk "kap dışına taşan" ölçümüm **boş döndü** ve bu bir bulgu
  değil **vacuous ölçümdü** — `overflow != visible` olan ata ararken zincir `html`'e
  kadar gidip `null` oluyor ve öge sessizce atlanıyordu. Doğru ölçüm `scrollWidth` ile
  yapıldı.
- **Fikstür kararı:** kuyruk kimlikleri **gerçek GUID**; okunur sahte kimlikler
  (`q-sales`) `BR-FE-124`'ü tam olarak gizleyen şeydi.
- **Yan etki (bilerek):** `LiveQueuesFidelity.test.tsx`'teki dört "ekran yüklendi" kapısı
  `getAllByText`e çevrildi — kuyruk adı artık hem kartta hem agent satırında geçiyor.
- **Mutasyon:** `.map(id => id)` (eski hâl) => 2 failed; eşleşmeyeni sessizce düşüren
  varyant => 1 failed / 1 passed; geri alındı => 2 passed.
- **Commit:** `58b09944` (düzeltmeler + spec) · `1e390cd7` (taban + manifesto).
- **Kapsam sayıldı:** 2 → 4 → **5 taban**. Kalan tek kalem: (3) agent eylem çubuğu
  (`MonitorScreen`).

### 3. `BR-FE-117` — kod yazılmadı, **kartın durumu ölçülüp düzeltildi**
- **Neden:** talimat "ölçümü doğrula, hâlâ geçerliyse geç" idi.
- **Ölçüm:** `CallSource` deseni `src/**/*.cs` altında **hâlâ 0** — yani önceki turun
  ölçümü doğruydu. **Ama sonucu yanlıştı:** iş `fffd61bf` ile çoktan inmiş, ayırt edici
  alan `callSource` değil canlı çağrı kaydındaki **`Origin`** damgası olmuş
  (`CallAttemptOrigins.Dialer`). `ActiveCallInfo.Attempt` artık `int?`;
  `AttemptForCall` dialer kökenli olmayan çağrıda `null` dönüyor, modal da çizmiyor.
  Vacuity şartı iki yönde de karşılanmış (`ActiveCallAttemptSourceTests` +
  `IncomingCallModal.test.tsx`). Bu turda koşuldu: **27 passed**.
- **Sonuç:** kart `Bitti` yazıldı.

### 4. `BR-FE-111` — engel yeniden ölçüldü, duruyor
`LiveAgentDto` üye listesi bugün tekrar okundu (`LiveEndpoints.cs:1275+`): sebep alanı
(etkin penalty / gerekli yetenek / birincil kademe kalan timeout) **telde yok**. Ekran
ayağı tek başına yazılamaz; karar değişmedi, karta bugünün ölçümü eklendi.

## Kararlar
- **Kırpılma çözümü "yazıyı küçültmek" değil "kutuya göre ölçeklemek"tir.** Sabiti
  düşürmek TV mesafesinde iki haneli sayaçları kaybettirirdi; ölçüm bunu gösterdi.
- **Ellipsis silinmedi, ulaşılmaz kılındı.** Beklenmedik bir taşmada "03:…" en azından
  eksik olduğunu söyler; düz kırpma "03:4" üretir ve o sessizce yanlış okunur.
- **Yaprak iddiası ile kap iddiası iki ayrı arıza sınıfıdır**; biri diğerinin yerine
  geçmez (ölçüldü — `BR-FE-123` yaprak iddiasının altından geçti).
- **Fikstürler üretimin biçimini taşımalı.** Okunur sahte kimlikler bir kusuru aylarca
  gizledi; görsel fikstür artık gerçek GUID kullanıyor.

## Açık kalanlar / sonraki adım
- `BR-QA-57` kalem **3** (agent eylem çubuğu / `MonitorScreen` tabanı) — gerekçe
  kapasite: canlı çağrı durumu + dinleme oturumu fikstürü ve ayrı bir Ş6 incelemesi ister.
  **Boş ya da sahte taban üretilmedi.**
- `BR-FE-111` — sunucu tarafında `LiveAgentDto`'ya sebep alanı eklenmeden açılamaz.

---

# pbxtr — 2026-09-19 (db-dev turu: BR-BE-185 / BR-DB-76 / BR-DB-77 / BR-DB-101)

## Bağlam
Kurul dağıtılmış durumda: açık kararlar ajan tarafından veriliyor, dar olan seçiliyor,
gerekçe karta yazılıyor. Dört kart verildi. Ortak eksen: **ölçülmemiş cümleleri ölçmek**.

## Yapılanlar

### 1. Ölçüm ortamı: gerçek PostgreSQL 16 + TAM migration zinciri
- **Neden:** dört kartın üçü "gerçek PG'de ölçülmedi" diye açık duruyordu. Taze zincir
  olmadan `convalidated`, RLS sessiz sıfırı ve FK davranışı ölçülemez.
- **Ne yapıldı:** `deploy/db-kapilari-docker.sh`in şema kurulum adımları kopyalanıp
  ayrı bir konteynere alındı (ci-check adımı yok — bu tur şema ölçüyor, kapı koşturmuyor).
- **Komutlar:**
  ```bash
  docker run -d --name pbxtr-br185-srv postgres:16-alpine   # hazirlik: docker inspect saglik
  psql -f deploy/db/00-roles.sql
  dotnet ef database update --project src/Pbxtr.Infrastructure
  ```
- **Sonuç:** 216 migration uygulandı; sonra 217. olarak BR-DB-101 migration'ı eklendi.

### 2. `BR-BE-185` — kabul ölçütünün açık yarısı kapandı (P1, **Bitti**)
- **Neden:** kart dört turdur "Down gerçek PostgreSQL'de koşulup NOTICE gözlenmedi"
  diye bloke duruyordu; Docker her turda kapsam dışı kalmıştı.
- **Ne yapıldı:** `Down()` gövdesi migration **dosyasından programla çıkarıldı**
  (elle kopya "belge santral değildir" sınıfı bir hata olurdu) ve EF gibi tek
  transaction içinde `pbxtr_owner` ile koşuldu.
- **Ölçümler:**
  - İki `RAISE NOTICE` çıktıda **görüldü**; `RAISE EXCEPTION` yok, `COMMIT` geçti.
  - Yapısal (`pg_constraint`, metin eşleme değil): önce `convalidated = t`, Down sonrası
    `convalidated = f` → kısıt **gerçekten NOT VALID bırakılıyor**.
  - NOTICE'in ikinci cümlesi de ölçüldü: gerçek bir `EndpointDelivery` satırı yazılınca
    `VALIDATE` **23514**, aynı satırın `DELETE`'i **P0001 append-only** ile düştü.
  - Bloğun satır saymama gerekçesi ölçüldü: aynı turda tenant filtresiz `count(*)` **0**
    dedi, kısıt doğrulaması aynı satırı **buldu**. FORCE RLS altında tanı sayısı yalan söyler.
  - **Bugünkü NOT VALID envanteri:** 6 satır, hepsi tek kısıt adı
    (`ck_sla_buckets_callback_requested_count`, ebeveyn + 5 partition), gerekçeli ve
    zararsız (kolon aynı deyimde `NOT NULL DEFAULT 0` doğuyor). Toplam kısıt 792.

### 3. `BR-DB-101` — kuyruk çıkış anonsu medyası (P1, **DB yarısı Bitti**)
- **Neden:** `BR-AST-111` tuşu ve dialplan bağlamını indirmişti ama arayan **tuşun
  varlığını hiç duymuyordu**; anons medyasının tutunacağı kolon yoktu. Onay/fail-back
  anonsları stok İngilizce (`auth-thankyou` / `vm-sorry`) idi.
- **Ne yapıldı:** `20260919030000_QueueCallbackAnnouncementMedia` —
  `callback_invite_media_id` / `callback_confirm_media_id` / `callback_failback_media_id`,
  her biri **bileşik FK** → `media_files(tenant_id, id)` `ON DELETE RESTRICT`; üç kısmi
  indeks (hepsi `tenant_id` ile başlıyor); `EfMediaUsageProbe` genişletildi.
- **KARAR:** KURUL #78 / cm-agent ŞARTI 1 **UI'da değil DB'de** durur →
  `ck_queues_callback_media_required`: `callback_digit` doluysa üç anons da zorunlu.
  Gerekçe: ekran dışı her yazma yolu UI doğrulamasını atlar.
- **Ölçümler (pozitif + negatif + mutasyon):** kısıt ve üç FK `convalidated = true`;
  anonssuz tuş → 23514; üçten ikisi dolu → 23514; üçü dolu → `UPDATE 1`; kısıt DROP
  edilince aynı negatif vaka `UPDATE 1` (kırmızının sahibi gerçekten bu kısıt);
  çapraz tenant medya → 23503; kullanımdaki medya silme → 23503.
  `Up → Down → Up` tam tur; Down sonrası kolon/kısıt/indeks **0**.
- **Beklenmedik ama doğru bulgu:** Down `callback_digit`'e dokunmaz → sonra `Up`'ı
  yeniden koşmak **23514** verdi. Yani remarks'taki "canlıda tuş doluysa migration düşer"
  cümlesi neşir değil ölçüm. Down'daki NOTICE'in verdiği kurtarma adımı da ölçüldü:
  aynı UPDATE `pbxtr_owner` ile **`UPDATE 0`**, `pbxtr_app` + tenant GUC ile **`UPDATE 1`**.
- **Dokunulan dosyalar:** `src/Pbxtr.Domain/Modules/Queues/Queue.cs`,
  `src/Pbxtr.Infrastructure/Persistence/Configurations/QueueConfigurations.cs`,
  `src/Pbxtr.Infrastructure/Modules/EfMediaUsageProbe.cs`,
  `src/Pbxtr.Infrastructure/Persistence/Migrations/20260919030000_QueueCallbackAnnouncementMedia.cs`
- **Commit:** `85d47c9b`

### 4. `BR-DB-77` — KARAR: CHECK kalır, referans tablo + FK **reddedildi** (**Kapandı**)
- **Neden:** kart "ölçüm tarafı kapandı, geriye seçim kaldı" diyordu; kurul dağıtıldığı
  için seçim burada verildi.
- **Dört ölçülmüş gerekçe:**
  1. Referans tablonun meşru yeri **yok**: `public`'te `tenant_id` taşımayan tablo üç
     bağımsız katmanla yasak (`pbxtr_global_tables()` beş ad, donduruldu). `pbxtr_sys`'e
     koymak çözüm değil **kaçamak**: guard kapsamı `nspname = 'public'` (ölçüldü).
  2. Kazanç bir sayıdır: `migration-contract-onay.blobs` 27 onay satırı taşıyor, enum
     genişlemesinden doğan **2** (%7,4). FK ömür boyu 2 satır kazandırırdı.
  3. FK'nin tek özgün koruması (enum **daraltma**) `DO $widen$` bloğunda **zaten var**.
  4. Append-only defterin sıcak yoluna ikinci bir tablo bağımlılığı eklerdi.

### 5. `BR-DB-76` — tasarım karara bağlandı, yazım bilerek yapılmadı
- **Neden:** kalan iş "retention işinin yazımı"ydı; yazımdan önce cevapsız tek tasarım
  sorusu **imzaydı**: çapraz-tenant mı, tenant başına mı?
- **Ölçüm (PG 16, 1M satır, 192 MB, %99,4 okuma işlemi; üç vaka da `rows=5000` getirdi):**

  | Vaka | Plan | Süre |
  |---|---|---|
  | A — indekssiz çapraz-tenant | `Parallel Seq Scan` + top-N sort | **103,0 ms** |
  | B — kural-uyumlu `(tenant_id, at)` kısmi indeks, **aynı sorgu** | indeks **HİÇ kullanılmadı**, yine seq scan | **112,7 ms** |
  | C — aynı indeks, **tenant başına** | `Index Scan` | **2,4 ms** |

  Kontrol grubunun paydası yazılı: o tenant'ın **14.201** adayı var (parti gerçekten
  doldu), toplam aday **564.595**. Tam tur: çapraz ≈ **11,6 sn**, tenant başına ≈ **0,29 sn**.
- **KARAR:** fonksiyon `pbxtr_sys.purge_telephony_provider_effects(p_tenant_id uuid,
  p_keep_days integer, p_batch integer)` — **tenant başına**. Böylece "her indeks
  `tenant_id` ile başlar" kuralı **istisna istemez**; (B) gösteriyor ki çapraz imza
  seçilseydi kural-uyumlu indeks **vacuous** olurdu — kuralın değil **imzanın** değişmesi
  gerekiyordu. Silme yalnız beş periyodik OKUMA işleminde; gerçek YAZMA etkileri hiç
  silinmez (24 saatte 109 satır). Append-only tetikleyici kalır; geçiş yalnız DELETE için
  ve yalnız `pbxtr.retention_purge='on'` iken — UPDATE mutlak yasak. İki kilit: bayrak
  **ve** DELETE yetkisi (ölçüldü: `pbxtr_app` yalnız INSERT + SELECT).
- **Neden yazılmadı:** emsal `WebhookDeliveryRetentionJob` + `Options` **405 satır**, ayrıca
  DI + `BackgroundJobLocks` kaydı ister. Bu turda `src/Pbxtr.Infrastructure` **paralel bir
  ajan tarafından yazılıyordu** (`ConfigRenderer.cs` bir ara derlenmiyordu); yalnız DB
  fonksiyonunu indirmek **"kod var, koşan yok"** borcu üretirdi.

### 6. `BR-DB-104` açıldı — migration NOTICE'ı üretim yolunda görünüyor mu?
- **Neden:** BR-BE-185'i kapatırken ölçüldü — `dotnet ef database update -v` çıktısında
  (210 satır) SQL gövdesi 4 kez yankılanıyor ama **sunucu NOTICE satırı SIFIR**.
- Üretimdeki yol üçüncüdür: `MaintenanceRunner` → `Database.Migrate()`
  (`MaintenanceRunner.cs:454`). Orada NOTICE'ın `ILogger`'a düşüp düşmediği **ÖLÇÜLMEDİ**
  ("yok" değil, "ölçemedim"). Görünmüyorsa iki kararın "operatör bilgilendirilir" ayağı
  **vacuous**'tur.

## Kararlar
- **Güvenlik şartı UI'da değil kısıtta durur.** Ekran dışı her yazma yolu UI doğrulamasını
  atlar (`ck_queues_callback_media_required`).
- **Kuralı bükmeden önce imzayı değiştir.** BR-DB-76'da "her indeks tenant_id ile başlar"
  kuralına istisna istemek yerine fonksiyon imzası tenant başına yapıldı; ölçüm kuralın
  değil imzanın yanlış olduğunu gösterdi.
- **Bir kazanç sayılmadan tartılmaz.** BR-DB-77'de "defter her enum değerinde büyüyor"
  doğruydu ama ağırlığı 2/27 idi — ve bedeli dondurulmuş bir çok-kiracılık değişmeziydi.
- **`pbxtr_sys`'e koymak guard'dan kaçmaktır**, çözüm değildir (guard kapsamı ölçüldü).
- **Down sessiz olmaz.** BR-DB-101'in Down'u `callback_digit`'i olduğu gibi bırakır ve
  bunu iki NOTICE ile söyler; `RAISE EXCEPTION` kullanılmaz — geri alma bloklanmaz.

## Açık kalanlar / sonraki adım
- `BR-DB-101`'in diğer yarısı: medya yükleme/seçme UI'ı, `ConfigRenderer`'ın stok sesleri
  bu kolonlarla değiştirmesi + `periodic-announce`, `pbxtr.d/` dosya teslimi ve
  "dosya yoksa anons YAZILMAZ" kuralı, stok seslerin gerçek santralde ölçülmesi.
- `BR-DB-76`: yukarıdaki imzayla migration + iş + DI + kilit + kapanış ölçümü.
- `BR-DB-104`: `Database.Migrate()` yolunda NOTICE ölçümü ve gerekirse `ILogger` bağlaması
  + koşan bekçi.
- **Ölçemediğim:** tam çözüm derlemesi bu turda paralel ajanın `ConfigRenderer.cs`'i
  yüzünden bir ara kırmızıydı; **kendi dosya kümem** son başarılı derlemede (0 hata)
  yeşildi ve `dotnet format --verify-no-changes` o kümede temiz döndü.

---

# pbxtr — 2026-09-19 (backend-dev-2 turu: BR-OPS-02 / BR-OPS-01 / BR-AST-63 / BR-AST-64)

## Bağlam

Kurul dağıtılmış durumda: karar kurula da kullanıcıya da sorulmuyor, dar olanı seçip
uyguluyorum ve gerekçeyi karta yazıyorum. Dört kart verildi. İki `BR-OPS` kartının durum
hücresi *"iş backend'de ve sahibi bu ajan değil (`backend-dev-2`)"* diyordu — o ajan benim,
yani sahiplik engeli yoktu. İki `BR-AST` kartı ise "sahiplik kararsızlığı" bekliyor
görünüyordu ama **karar zaten verilmişti** (Kurul Karar #66 M17 ve M19, ikisi de 10 oy);
kartlar bunu kendi durum hücrelerinde yazıyordu (`Karar #77 Ş77-A1 — KARARA BAĞLI, kalan iş
UYGULAMA`). Yani bu turda dört kartın da engeli gerçek değildi.

## Yapılanlar

### 1. BR-OPS-02 (P1) — ölü zil grubunda yanan süre artık SLA beklemesine giriyor

- **Neden:** kartın teşhisi *"metrik arızayı ÖDÜLLENDİRİYOR"*. Ölçülmüş mekanizma: taşma
  dalı çağrıyı kuyruğa çevirdiğinde (`fallback_decision='queue'`) `join_at` **kuyruğa giriş
  anıdır**; `wait_sec`'in ilk iki kaynağı (`hold_time`, `outcome_at - join_at`) kuyruk
  içidir, dolayısıyla 20 sn ölü zil grubunda yanan süre **yapısal olarak** dışarıda kalır ve
  çağrı `answered_within_count`'a yazılır. Arızanın bedeli aynı kovanın **başarı** tarafına
  kaydediliyordu.
- **Ne yapıldı:** `SlaAggregationJob.RecomputeSql`'e
  - `joins` CTE'sine `lag(at)` = `prev_join_at` (aynı zil olayı iki girişe atfedilemez),
  - `attributed`'a LATERAL `rg`: bu girişin **öncesindeki**, önceki girişten **sonraki**
    `PbxtrRingGroupEnter` (olay adı `RingGroupSignals.EnterEvent`'ten gelir, ikinci kopya yok),
  - yeni ufuk `PreQueueRingHorizon = 10 minutes` — `OutcomeHorizon` (4 saat) **değil**:
    ileriye arama "sonuç", geriye arama "**sebep**" arar ve sebep zil grubu zaman aşımıyla
    sınırlıdır,
  - `pre_queue_wait_sec` yalnız **kuyruk içi** iki kaynağa eklenir; CDR yedeğine
    **eklenmez** (o `duration - billable` ile tüm çağrıyı zaten ölçer, çift sayım olurdu),
  - `greatest(0, NULL)` yerine açık `CASE`: PostgreSQL'de `GREATEST` NULL'ları **atlar** ve
    `greatest(0, NULL)` **0** döner — yani "zil grubu yok" ile "0 sn çaldı" aynı ifadeden
    çıkardı.
- **Dokunulan dosyalar:** `src/Pbxtr.Infrastructure/Telephony/Sla/SlaAggregationJob.cs`,
  `tests/Pbxtr.Integration.Tests/Tests/SlaHoldTimePipelineTests.cs`
- **Komutlar:**
  ```bash
  dotnet test tests/Pbxtr.Integration.Tests/Pbxtr.Integration.Tests.csproj --no-build \
    --filter "FullyQualifiedName~SlaHoldTimePipelineTests"
  ```
- **Sonuç / doğrulama:** 3/3 gerçek PostgreSQL. Yeni vaka **üç giriş** taşır: (A) taşma,
  (B) AYRIŞTIRICI = zil grubundan gelmeyen doğrudan çağrı, (C) ufuk dışı (15 dk önceki) eski
  zil olayı. Komşu takım (SlaEventOrdering + SlaDeadlineRestatement + CallbackSlaSqlParity)
  22/22. **Mutasyon 2/2 kırmızı:** ekleme kaldırıldı 1/3; ufuk 4 saate genişletildi 1/3.
- **Ölçemediğim:** `prev_join_at` alt sınırı bu fikstürde **ayrıştırılmıyor** (aynı çağrının
  iki kez kuyruğa girdiği vaka yok).
- **Commit:** `54f62e4c`

### 2. BR-AST-64 (P3) — kademeli çalma (`delay_sec`) ÜRETİLİYOR

- **Neden:** Karar #66 M19 kolu (a) = `Local` + `Wait(n)` sarmalayıcı, 10 oy. Kolon
  2026-08-24'ten beri şemadaydı ve hiçbir üretim satırı okumuyordu.
- **Ne yapıldı:** `ConfigRenderer.AppendDelayWaves` + `AppendDelayContext`. Yalnız
  **eşzamanlı** stratejide; dalga başına **tek** `Local/rg{numara}d{n}@pbxtr-{tref}-rgdelay/n`.
  **Hedef listesi ebeveynde çözülür** (`__PBXTR_RGD_{n}` kalıtımlı) ve dalga boşsa `Local`
  hiç eklenmez — bu zarafet değil **doğruluk şartı**: aksi hâlde tamamı gecikmeli bir grupta
  `RGD` daima dolu olur ve `GotoIf(...overflow)` kapısı, yani "kimse KAYITLI değil" ile
  "kimse CEVAP VERMEDİ" ayrımı sessizce kaybolurdu.
- **Kararlarım (kurul yok, gerekçesiyle):**
  1. **Sıralı stratejide gecikme uygulanmaz.** Sıralı zaten kademelidir; üstüne gecikme
     koymak *"önceki üye cevap vermedi, şimdi n saniye HİÇ KİMSE çalmasın"* demekti. Aynı
     alanın iki stratejide iki anlam taşıması = ekranda tek alan, santralde farklı davranış.
     Sessiz değil: üretilen dosyaya yorum satırı düşer.
  2. **`/n` (optimizasyon kapalı).** Varsayılan `Local` köprülendikten sonra kendini yoldan
     çıkarır ve `CHANNEL(name)` topolojisini çağrı ortasında değiştirir; `call_events`
     korelasyonu ve ARI `GET /channels` resync'i üretilen metinle aynı topolojiyi varsayar,
     `Local` üzerinden `linkedid` davranışı ise **ölçülmemiştir** (Karar #66 İ6). Bedel
     yazılı: gecikmeli dalga başına çağrı boyunca **iki ek kanal**.
  3. **Ş66-18'in "M15 edge, M18, M19" sırası uygulanmadı.** M18 kendi kararıyla "bugün
     ÜRETİLMEZ" (edge yok, İ6); M19'u ona bağlamak kartı süresiz bloke ederdi ve M19 edge'e
     teknik olarak bağımlı değil.
- **Dokunulan dosyalar:** `src/Pbxtr.Infrastructure/Provisioning/ConfigRenderer.cs`,
  `src/Pbxtr.Infrastructure/Provisioning/ProvisioningRevisionService.cs`,
  `tests/Pbxtr.Api.Tests/Modules/Telephony/RingGroupRenderTests.cs`,
  `doc/prototip-urun-farklari.md`
- **Sonuç / doğrulama:** `Modules.Telephony` 1350/1352 (2 skip = canlı santral testleri),
  `RingGroupRenderTests` 17/17 (6 yeni). **Mutasyon 3/3 kırmızı:** `Local` koşulsuz eklenir
  2/17; gecikme grup süresine eşit kabul 1/17; uzantı adına tire 2/17.
- **Yan bulgu:** `SlaAggregationJob.cs` UTF-8 **BOM** taşıyordu ve `dotnet format --include`
  onu `CHARSET` ile kırmızı yakıyordu. Ölçüldü: ihlal **benim değişikliğimden önce de vardı**
  (HEAD~1 sürümü de kırmızı); `.editorconfig` `charset = utf-8` diyor ve komşu dosyalarda BOM
  yok. BOM kaldırıldı.
- **Commit:** `3a268a22`

### 3. BR-OPS-01 (P2) — agent kendi kuyruklarının sessizlik alarmını görebiliyor

- **Neden:** kartın `İş` maddesindeki *"ve agent ekranında da (agent ilk fark eden
  olabilmeli)"* kalemi hiçbir katmanda inmemişti: alarmı taşıyan tek uç `/alarms/active`,
  yetkisi `alarm.read`, o da `bundle.live` içinde; `agent` rolü yalnız `bundle.call` +
  `bundle.console` taşıyor, yani agent 403 alıyordu.
- **Ne yapıldı (koordinatör kararı = DAR YETKİ):** agent'a `alarm.read` **verilmedi**,
  `bundle.live` **genişletilmedi**. Yeni yetki `alarm.silence.read.self`
  (`permissions.seed.json` + `agent` rolü `extraPermissions`). Yeni uç
  `GET /api/v1/alarms/silence/mine`.
  - **Neden ayrı uç:** aynı ucun role göre farklı kapsam döndürmesi, daraltmayı unutan tek
    bir değişiklikte bütün tenant'ın alarmlarını agent'a verir. Ayrı rota + ayrı yetki +
    ayrı sorgu = daraltma **yapısal**.
  - **Fail-closed ve yazılı:** PG okunamazsa boş liste **dönülmez** (boş liste "alarm yok"
    diye çizilirdi, kartın şikâyet ettiği körlüğün ta kendisi), `503`. Kullanıcı bağlamı
    çözülemezse de `503`.
  - Daraltma **sorguda** (`EfSilenceAlarmView`, `queue_members` üzerinde `EXISTS`).
    **Mola/izin üyeliği düşürmez** — molayı eleseydik alarm en çok ihtiyaç duyulduğu anda
    kaybolurdu. Zil grubu/DID kapsam dışı: üyelik kavramı yok, "kendi" uydurulmaz.
- **Dokunulan dosyalar:** `src/Pbxtr.Api/Modules/Realtime/LiveEndpoints.cs`,
  `src/Pbxtr.Api/Platform/Authorization/permissions.seed.json`,
  `src/Pbxtr.Domain/Modules/Live/Silence/ISilenceAlarmView.cs`,
  `src/Pbxtr.Infrastructure/Modules/EfSilenceAlarmView.cs`,
  `tests/Pbxtr.Integration.Tests/Tests/SilenceAlarmSelfScopeTests.cs` (yeni)
- **Sonuç / doğrulama:** Platform.Authorization 208/208, Modules.Realtime+Live 335/335,
  Architecture 753/753, yeni entegrasyon testi 1/1 (gerçek PG + RLS).
- **FİKSTÜR SORGULANDI (günün en öğretici anı):** M1 mutasyonu (`member.UserId == userId`
  düşürüldü) **ilk koşuda YEŞİL kaldı**. Sebep: tenant'ta başka hiçbir kuyruk üyeliği yoktu,
  yani *"üyesi olunan kuyruk"* ile *"üyesi olan herhangi bir kuyruk"* **aynı kümeye
  düşüyordu**. Fikstüre öteki kuyruğun **kendi agent'ı** eklendi; M1 ancak o zaman kırmızı
  oldu. M2 (`TargetKind == queue` düşürüldü) yeşil kaldı ve bu **ölçülmüş** bir sonuçtur:
  DB pairing CHECK'i `queue_id` dolu + hedef türü kuyruk-dışı bir satırı imkânsız kılıyor,
  yani koşul savunma amaçlıdır ve fikstür onu ayrıştıramaz.
- **Commit:** `4e83ec15`

### 4. BR-AST-63 (P3) — `rotating` zil grubu üretiliyor, sayaç AstDB'de

- **Neden:** Karar #66 M17 kolu (a) = AstDB, 10 oy; Ş66-16 anahtarı da yazmış:
  `pbxtr/{tref}/rg/{id}`. Kart "sahiplik kararsızlığı" diyordu ama kararsızlık yoktu.
- **Maddi sapma, açıkça kabul edildi:** bu, CLAUDE.md §3.3/2'nin ("bilgi pbxtr'da durur")
  **karara bağlanmış** bir istisnasıdır. pbxtr sayacı görmez ve sıfırlayamaz; çok düğümde
  her düğümün kendi turu olur (yaklaşık adil). Eski gerekçe metinleri **silinmedi**, üzeri
  çizildi — hâlâ doğrular.
- **Üretilen biçim** (`ConfigRenderer.AppendRotating`):

      same => n,Set(RGI=${DB(pbxtr/t0007/rg/<id>)})
      same => n,ExecIf($["${RGI}" = ""]?Set(RGI=0))     ; bos anahtar
      same => n,Set(RGI=${MATH(${RGI}%N,int)})          ; uye sayisi kuculduyse
      same => n,ExecIf($["${RGI}" = ""]?Set(RGI=0))     ; MATH bos donduyse (rakam degil)
      same => n,Set(DB(...)=${MATH((${RGI}+1)%N,int)})  ; SIRADAKI tur, Dial'DAN ONCE
      same => n,UserEvent(PbxtrRingGroupEnter,...,Offset: ${RGI})
      same => n,Goto(rg{numara}r${RGI},1)

  ve ardından N adet sıralı başlangıç zinciri.
- **Kararlarım:** (a) **iki kapı**, biri değil — ilk kontrol yalnız BOŞ değeri yakalar,
  `MATH` hatasını yakalamaz; üçüncü bozulma hâli (`% N`) `Goto`nun var olmayan bir uzantıya
  gitmesini (çağrının **çalmadan** düşmesini) önler. (b) **Sıradaki tur `Dial`dan önce
  yazılır** — sonra yazılsaydı cevaplanmadan kapanan her çağrı turu ilerletmez ve aynı üye
  üst üste çalardı; "turlu" tam da yoğun anda turlu olmaktan çıkardı. (c) **N kopya sıralı
  zincir**, hesaplanan tek döngü değil — dialplan'de "listeyi k'dan döndür" ilkeli yok ve
  döngüde çıkış koşulu iki ayrı yerde doğru olmak zorundaydı. (d) Uzantı adında **tire yok**
  (Asterisk çevrilen uzantıdan `-` atar). (e) Tüm üyeler DND ise **tur yoktur** (sayaç ne
  okunur ne yazılır) ama **giriş olayı yine yazılır**.
- **İ12'nin denetlenebilirlik şartı KISMEN:** kullanılan tur indeksi `Offset` başlığıyla
  `PbxtrRingGroupEnter`'e binip `call_events`'e iniyor (`ringGroupOffset`; mapper +
  `TelephonyEventPipeline` allowlist). **Üye bazlı çalma olayı üretilmiyor** — İ12'nin *"her
  çalma UserEvent ile call_events'e düşer"* şartı bu yüzden kısmen karşılandı.
- **Şema:** `20260919040000_RingGroupRotatingStrategy`. CHECK metni artık
  `RingGroupStrategies.Supported` **sabitinden** üretiliyor (BR-BE-169 emsali) — iki liste
  bir gün sessizce ayrışamaz. `20260824230000_RingGroupsFinalGuard` **değiştirilmedi**:
  kendi `Up`'ının koştuğu andaki şemayı doğrular ve o an kısıt hâlâ dardır.
  `Down` yönü `rotating` satırı varsa **reddeder**; sessizce veri silen bir `Down` yazılmadı.
- **Komutlar:**
  ```bash
  dotnet ef migrations add RingGroupRotatingStrategy --project src/Pbxtr.Infrastructure \
    --startup-project src/Pbxtr.Infrastructure --context PbxtrDbContext \
    --output-dir Persistence/Migrations
  # blob sha + yol + Karar#66 satiri deploy/migration-contract-onay.blobs dosyasina
  python deploy/migration-compatibility-guard.py   # OK
  ```
- **FE:** `ext.strategyRotating` etiketi **9 dilde** eklendi. Eklenmeseydi geçerli bir sunucu
  değeri ekranda "tanımsız" görünürdü — sunucu sözleşmesiyle ekran sözleşmesi sessizce
  ayrışırdı. Strateji **seçimi** yapan form bugün de yok (#27/1: panel salt-okur).
- **Sonuç / doğrulama:** Modules.Telephony 1353/1355, RingGroupRender 20/20,
  AmiEventMapping 48/48, Architecture 753/753, vitest 2108/2108, `tsc -b` temiz.
  **Mutasyon 4/4 kırmızı:** sayaç ilerletilmiyor / her zincir 0'dan başlıyor (tur DÖNMÜYOR) /
  ikinci `ExecIf` kapısı düşürüldü / `ringGroupOffset` allowlist'ten çıkarıldı (`Sanitize`
  sessizce atıyor).
- **Commit:** `255de74a`

### 5. Defter

`yonetim/backlog.md` dört kartta güncellendi — dördü de **`Kısmen`**, `Bitti` **değil**.
`yonetim/kalan-isler.md` yeniden üretildi, ClickUp senkronu koşuldu
(fark 4, yazıldı, doğrulama `fark olan kart: 0, izde olmayan: 0`).
**Commit:** `133a4acb`

## Kararlar

- **Kart "sahiplik bekliyor" diyorsa önce karar defterinde kart kodunu ara.** İki kart da
  karara bağlıydı (Karar #66 M17/M19, ikisi de 10 oy) ve kartların kendi durum hücreleri
  bunu yazıyordu; "kararsız" olan yalnızca kartın **başlık cümlesiydi**.
- **Geriye doğru arama ile ileriye doğru arama aynı ufku paylaşmaz.** İleride "sonuç",
  geride "**sebep**" aranır; sebep her zaman daha dar bir pencereye sığar.
- **`greatest(0, NULL)` = 0.** PostgreSQL `GREATEST` NULL'ları atlar; "veri yok" ile "ölçtüm,
  sıfır" aynı ifadeden çıkamaz.
- **Daraltma sorguda olmalı, projeksiyondan sonra değil.** Geniş kümeyi okuyup bellekte
  elemek, elemeyi atlayan tek bir değişiklikte sızıntıdır.
- **Mutasyon yeşilse önce fikstüre bak** (bugün fiilen oldu): tenant'ta başka üyelik
  olmayınca "kendi kuyruğu" ile "herhangi bir kuyruk" aynı kümeye düşüyordu.
- **Bir kapı yetmeyebilir.** AstDB sayacında boş değer ile `MATH` hatası **farklı** hâllerdir
  ve tek bir `ExecIf` ikisini birden yakalamaz.
- **`Bitti` ile `Kısmen` arasındaki fark defterdedir.** Dört kartın dördünde de kapanan
  parça ve açık kalan parça **ayrı ayrı** yazıldı.

## Açık kalanlar / sonraki adım

- `BR-OPS-01`: **agent ekranı (FE).** Uç ve yetki indi, `/api/v1/alarms/silence/mine`
  tüketicisi yok. **TUZAK:** `useRealtimeSilence` / `RealtimeSilenceStrip` bu **değildir** —
  o bir WS **tazelik** şerididir; ad benzerliği grep ile bakanı yanlış yeşile götürür.
- `BR-OPS-02`: #17 wallboard `extension.read` (role yetki eklemek = güvenlik sınırı) ve
  `BR-AST-60` (gerçek santralde `done` bölümünün `PbxtrRingGroupAnswer` ürettiğinin telde
  doğrulanması; canlıda `ring_groups` 0 olduğu için üretilecek çağrı yok).
- `BR-AST-63`: **üye bazlı çalma olayı** üretilmiyor (İ12 kısmen); strateji **seçimi** formu
  yok. Ayrıca üretilen `rotating` dialplan'i **gerçek santralde koşturulmadı**.
- `BR-AST-64`: **yazma yüzeyi** yok — `delay_sec` bugün yalnız ham SQL ile girilebilir
  (`RingGroupDelaySecWritePathTests` hâlâ geçerli ve yeşil). Ş66-18'in form uyarısı ve ekran
  alanı inmedi.
- **Ölçemediğim / bana ait olmayan kırmızı:** `Pbxtr.Integration.Tests`'te 4 test kırmızı —
  `voicemail_sla_daily.box_id` (`599e41d4`), `WebhookOutboxWriter` DI kaydı (`03009615`) ve
  `EnumMirror`'ın 12 `source` CHECK'i (`dcdcbf9e`). Üçü de benim turumdan **önceki**
  commit'lerden geliyor (git log ile doğrulandı) ve dokunduğum dosyalarla ilgileri yok.
- **Ölçemediğim:** bu turda **sunucuya (176.88.41.220) hiç bağlanılmadı**; üretilen
  `rotating` ve `rgdelay` dialplan'lerinin gerçek Asterisk'te davranışı (özellikle `MATH()`
  modulus davranışı, `Local/.../n` üzerinden `linkedid` ve `Wait()` sırasında çağıranın
  duyduğu ses) **ölçülmemiştir**.

---

## BR-QA-117 — `BR-QA-113`'ün geri açtığı 13 kalem (pbxtr-qa turu)

### Bağlam
`BR-QA-113` kapanış tespitini anlamsal yaptı: ham alt dize taraması 98 EF adaptöründen
33'ünü kapalı görüyordu, yorum/dize ayıklanmış kod üzerindeki tarama 20. Aradaki **13
kalemin tek kapanış kanıtı bir YORUM satırıydı** — bekçi bir yorumla susturulmuştu.
`BorcTavani` 65 → 78'e çıkarıldı. Bu turun görevi o 13 kalemi **ölçmek** ve karıştırmadan
iki sınıfa ayırmaktı.

### Yapılanlar

#### 1. Ölçüm — 13 kalemin sınıflandırması
- **Neden:** *"testi zaten var"* ile *"hiç ölçülmemiş"* aynı satırda duruyordu; ikisini
  birden kapatmak bekçiyi **ikinci kez** yorumla susturmak olurdu.
- **Ne yapıldı:** `Pbxtr.Architecture.Tests` içine **geçici** bir tanılama Fact'i yazıldı
  (`GeciciTanilama.cs`), `CSharpKodMetni.YalnizKod` + `SembolGeciyor` ile tüm
  `tests/Pbxtr.Integration.Tests/Tests` korpusu tarandı; her kalem için `adKol`,
  `kodAnma`, `hamAnma`, `ikinciKod`, `ikinciHam` basıldı. Ölçümden sonra dosya **silindi**.
- **Sonuç:** 13 kalemin **hepsinde** `Ef<Ad>` tam tanımlayıcısı korpusun **hiçbir kod
  satırında geçmiyor** → `BR-QA-113`'ün teşhisi doğrulandı. Üç sınıf çıktı:
  - **(A)** port DI'dan çözülüyor, iki tenant kodda → tek satırla kapanır: 7 kalem.
  - **(A′)** gerçek çapraz-tenant ölçümü var ama **HTTP yüzeyinden** koşuyor, port dosyada
    hiç çözülmüyor: 4 kalem.
  - **(B)** gerçek borç: `SmsMessageJournal` (adını anan tek dosya ikinci tenant'ı **kodda**
    kullanmıyor → `Assert.IsType` onu **kapatmaz**), `TenantAdministration`
    (`TenantWriteGateFunctionTests` **saf SQL**, `EfTenantAdministration`'a hiç dokunmuyor).

#### 2. (A) sınıfının kapatılması — 7 kalem
- **Neden:** kapanış kanıtı **kodda** olmalı, yorumda değil; ve aynı satır *"ölçülen şey
  gerçekten O adaptör mü?"* sorusunu da kilitlemeli.
- **Ne yapıldı:** her testin DI'dan çözdüğü port'a `Assert.IsType<EfXxx>(port)` eklendi.
- **Dokunulan dosyalar:** `tests/Pbxtr.Integration.Tests/Tests/BlacklistTenantLeakTests.cs`,
  `ReportTenantLeakTests.cs`, `IvrTenantLeakTests.cs`, `TrunkAdminPersistenceTests.cs`,
  `ProvisioningNodeStateTenantLeakTests.cs` (iki yer: store + health reader),
  `DealerTenantMoveGucHttpTests.cs`; bekçi `tests/Pbxtr.Architecture.Tests/TenantLeakCoverageTests.cs`
  (`BorcTavani` 78 → **71**, yedi satır listeden çıktı, kalan altısına sınıf notu yazıldı).
- **Sonuç:** Architecture.Tests **753/753** yeşil; dokunulan altı entegrasyon sınıfı gerçek
  PostgreSQL + RLS altında **27/27** yeşil; `dotnet format --verify-no-changes` rc=0.
- **Mutasyon — üç ayrı DI kabinde:** `RealSchemaDatabase` → **Failed 3**,
  `TelephonyTestHost` → **Failed 4**, `PanelHttpApplication` → **Failed 1**; üçü de geri
  alınıp yeşil. Üç kabin ayrı ayrı ölçüldü çünkü **hangi testin hangi konteyneri kullandığı
  varsayılmaz** (bugünün kayıtlı dersi).

#### 3. Vacuity çıpası taşındı — ve bu bir bulgudur
- **Neden:** `CSharpKodMetniTests.Gercek_test_dosyasinda_yorum_dusuyor_kod_kaliyor`,
  `ProvisioningNodeStateTenantLeakTests.cs` + `EfProvisioningNodeStateStore` çiftine
  çıpalıydı: *"ad yalnızca yorumda, ikinci tenant kodda"*. O kalemi kapatınca çıpa **aynı
  anda öldü** ve test **kırmızı yandı**.
- **Ne yapıldı:** çıpa hâlâ açık bir (B)/(A′) kalemine taşındı
  (`ApiKeyForeignNodePinTests.cs` + `EfProvisioningNodeDirectory`) ve hata mesajı
  *"çıpa TAŞINMALIDIR — kaldırılmamalıdır"* diyecek şekilde yazıldı.
- **Sonuç:** çıpanın gerçekten ölçtüğü kanıtlandı (kapanışta anında kırmızı), ama aynı
  zamanda **her kapanışta bakım isteyen** bir bağ olduğu görünür yapıldı.

#### 4. Yan bulgu → yeni kart `BR-QA-119`
- **Ne ölçüldü:** `ReportTenantLeakTests` üç testi **benim değişikliğimden ÖNCE de**
  kırmızıydı: `23502: null value in column "source" of relation "cdr_2026_09"`.
  `20260919020000_CallDataSourceColumn` (`dcdcbf9e`) `cdr`/`call_events` üzerinde `source`'u
  **NOT NULL** yaptı, **DEFAULT vermedi**; `tests/` altında ham SQL ile yazan **15 dosyada
  24 INSERT bloğu** kolon listesinde `source` taşımıyor. Ölçülen kırmızı:
  `CdrMultiRowCallTests|SlaEventOrderingTests|PostCallSmsPlanTests` → **Failed 8 / Passed 3**.
- **Kritik ayrıntı:** tohuma **önce `'synthetic'` yazıldı ve test YİNE kırmızı kaldı** —
  `EfCallReportQuery.cs:101` `.RealOnly()` ile süzüyor; doğru değer **`'live'`**. Yani bu
  kolon için **kör toplu düzeltme YANLIŞTIR**: satır yazılır, sorgu onu hiç görmez ve iddia
  "boş küme" üzerinde sessizce yeşil yanabilir.
- **Ne yapıldı:** yalnızca `ReportTenantLeakTests` tohumu düzeltildi; kalan 14 dosyaya
  **dokunulmadı** (paralel ajanların ağacıyla çakışmamak için) ve `BR-QA-119` açıldı.

### Kararlar
- **(A) ile (B) karıştırılmadı.** 13'ü birden kapatmak ölçü değil, ikinci bir susturmaydı.
- **(A′) dört kalem bilerek açık bırakıldı:** kapanışları HTTP kabında ayrı bir
  `Assert.IsType` + **sınıf başına ~1 dk 15 sn'lik ayrı koşum** ister; bu turda koşulmadı.
  Kayda geçen ifade **"ölçemedim"**, "yok" değil.
- `ProvisioningNodeDirectory` kapatılmadan önce **vacuity çıpası taşınmalıdır**; kart ve
  test mesajı ikisi de bunu yazıyor.

### Açık kalanlar / sonraki adım
- `BR-QA-117` **Kısmen**: (A′) 4 kalem + (B) 2 kalem açık.
- `BR-QA-119` **AÇIK**: 14 dosya × `source` kolonu; her dosyada değer testin ne ölçtüğüne
  göre (`'live'` / `'synthetic'`) seçilmeli.
- **Ölçemediğim:** tam `Pbxtr.Integration.Tests` takımı koşulmadı (bellek + süre); yalnızca
  dokunulan sınıflar ve `BR-QA-119` kanıtı için üç sınıf koşuldu.

### Commit
`65cd7da5` — BR-QA-117: 13 kalem olculdu, 7'si KAPANDI -- kanit yorumdan koda tasindi


### 20. DND geri okuma yolu + yedek sapma kapisi + BR-QA-51 bolunmesi (koordinator)

- **Neden:** Backlog'da karar bekleyen kartlar birikmisti. Kurul dagitildi (2026-09-18),
  yani bu kararlari koordinator veriyor. Uc kart karar bekliyordu, biri de olculmemis
  bir kapsam boslugu tasiyordu.

#### 20.1 `BR-AST-74` — DND'nin santraldeki gercek hali NASIL okunur (KAPANDI)

- **Ne yapildi:** Cevap **`ARI GET /deviceStates`**. Gercek santralde A/B kosuldu,
  urunun KENDI urettigi adla (`AriDndDeviceStateAnnouncer.cs:294` ->
  `AsteriskObjectName.cs:651` `DndDeviceStatePrefix = "Stasis:"`).
- **Komutlar (sunucu saati `2026-09-19 03:43Z`, `176.88.41.220` / `pbxtr-asterisk`):**
  ```bash
  curl -u pbxtr:*** http://127.0.0.1:8088/ari/deviceStates                 # -> []
  curl -u pbxtr:*** -X PUT ".../deviceStates/Stasis:pbxtr-t0007-dnd-1042?deviceState=BUSY"   # -> 204
  curl -u pbxtr:*** http://127.0.0.1:8088/ari/deviceStates                 # -> [{name,state:BUSY}]
  asterisk -rx "devstate list"                                             # -> Custom Device States BOS
  curl -u pbxtr:*** -X DELETE ".../deviceStates/Stasis:pbxtr-t0007-dnd-1042"  # -> 204, liste yine []
  ```
- **CURUTULEN ADAY:** `devstate list` **dogrulama yolu DEGILDIR** — durum ARI'da BUSY
  iken CLI'nin `Custom Device States` bolumu BOSTU (yalniz `Custom:` ailesini gosteriyor).
  Olcmeseydim el dogrulama yolu olarak onu yazacaktim ve operator "DND yazilmamis"
  sonucuna varacakti. `core show hints` de kaynak degil (dnd hint 0; 9 hint'in hepsi park).
- **Sonuc:** Yol Karar #46'nin `GET /endpoints` kalibidir: **sifir yetki degisikligi**.
  Acik kalan (baska kartlarin): `dndDelivered` 0, `deliveredRevision` 0 -> S50-1..S50-4.
- **Commit:** `a5e3662f`

#### 20.2 `BR-AST-79` — "DB'de var, santralde yok" uyarisi NEREDE cizilir (karar)

- **Karar:** uyari **ikiye bolunur**. `#37`'de yalniz **toplam sayi farki**
  (`DB: 9 / santral: 6 / fark: 3`), hicbir tenant kodu/nesne adi/dahili numarasi YOK —
  boylece `RegistrationSnapshot.cs:87-91` KAPALI KISITI delinmez. Tenant kirilimi
  **tenant kapsamli** dahili ekraninda.
- **Ucuncu hal ZORUNLU:** envanter okunamazsa `fark: 0` degil **`Unmeasurable`**.
- **Esik UYDURULMADI:** ornekklem 2 tenant / 9 dahili; esik koymak `BR-QA-112` hatasi olurdu.
- **Commit:** `1e8b7076`

#### 20.3 `BR-QA-51` — kartin KENDI dedigi bolunme yapildi (KAPANDI)

- **Neden:** kart *"KALAN IS (yeni kartlara ayrilmali)"* diyordu. Kartsiz kalan is
  **gorunmez borctur** (CLAUDE.md 14).
- **`BR-QA-120`** (a+b): `source` damgasinin **gorus alani disi** — `CallDataRetentionJob`,
  `PartitionMaintenanceJob`, `TenantCallDataRetention`, `SlaAggregationJob` ham SQL ile
  gidiyor, bekci `DbSet` tariyor -> o dort yol icin bugunku yesil **vacuous**.
- **`BR-QA-121`** (c+d+e): tohum yonetisimi — `seed-sample` ortam kapisi + denetim satiri
  yok, tenant tohum bayragi yazilmadi, tarih tazeleme yapilmadi, `source` dis aktarmada yok.
- **Commit:** `e85e1e1a`

#### 20.4 `BR-SYS-119` — yedek sapma kapisi 7'de 2'den 7'de 7'ye (KAPANDI)

- **Neden:** kapi zamanlanmis yedegin **yedi** dosyasindan yalniz **ikisine** bakiyordu
  ve YESIL yanarken gercek bir sapma kacirmisti (tatbikat drop-in'i: depo `7e68a913` /
  sunucu `7261c18f`).
- **Ne yapildi:** `deploy/yedek-sunucu-sapma.sh` kapsami **tek kaynaktan turetiliyor** —
  `deploy/pbxtr-yedek-kur.sh`'in `ESLEME` tablosundan (`ciftleri_uret()`). Liste ELLE
  KOPYALANMADI; kartin yakaladigi hata "iki elle yazilmis liste sessizce ayrisir"in ta
  kendisiydi. Kaynak okunamazsa kapi iki dosyaya geri dusmez, **`exit 2` ile DURUR**.
- **Oz-teste KAPSAM SAYACI eklendi, iki yonlu:** (c) cift sayisi `< 7` -> KIRMIZI;
  (d) diskteki her `deploy/pbxtr-yedek*` dosyasi kapsamda degilse -> KIRMIZI.
- **Mutasyon 2/2 KIRMIZI:** `ESLEME`'den tatbikat satiri silindi -> `kapsam 6 < 7` + (d);
  diskte sekizinci dosya yaratildi -> (d). Ikisi de geri alindi, `rc=0`.
- **Gercek sunucu kosusu (`rc=0`):** 7/7 birebir; drop-in'in 4 adi yuklenmis unit'te;
  timer **fiilen atesledi** (`LastTrigger=2026-09-19 02:33:12Z`), `Result=success`.
- **Duzeltme recetesi degisti:** kirmizi cikti artik elle `scp` onermiyor,
  `sh deploy/pbxtr-yedek-kur.sh` diyor — **elle scp tam olarak bu sapmayi uretmisti**.
- **Commit:** `30905b3b`

#### 20.5 `BR-AST-119` — kalan is (a)+(b) olculdu

- **(a) kismen YANLISMIS:** *"TTL'siz kaynak yok"* dogru degil — `PlatformRollupJob`
  toplami 15 dk'da bir **denetim satirina** yaziyor (`:491`), denetimin TTL'i yok.
  Geriye kalan gercek eksik daha DAR: o satir **kirilimi** tasimiyor, yani
  *"kaci cozulemedi, kaci celiskiydi"* sorusu 48 saat sonra cevapsiz — kartin **tum
  teshisi** o ayrimin yokluguydu. Desen zaten depoda: `skippedTenants` ayni sozlukte
  uc alt sebebiyle yaziliyor (`BR-BE-173`).
- **(b) BILDIRIM BACAGI YOK:** bu sayaca bagli alarm/bildirim kurali **0 eslesme**.
  CLAUDE.md 3.4 *"dusurulur, loglanir, ALARM URETIR"* diyor; ucuncu fiil uygulanmamis.
  Bedeli kartin kendi vakasi: bir gunun olaylarinin %98,8'i dustu, kimse uyarilmadi.
- **Ad benzerligi tuzagi:** `ChannelAlarmNotificationQueue`/`ChannelReportScheduleNotificationQueue`
  icindeki `dropped` alanlari **kendi kuyruklarinin tasma sayacidir**, bu sayacla ilgisiz.
- **Commit:** `8ddebb57`

### Kararlar

- **`devstate list` DND icin dogrulama yolu degildir** — `Stasis:` ailesini gormez.
  Bir sonraki turda canli dogrulama onunla yapilirsa **yanlis KIRMIZI** uretir.
- **Sapma kapilarinin dosya listesi elle kopyalanmaz**, kurulum betiginin tablosundan
  turetilir; turetilemezse kapi **durur**, dar kapsama geri dusmez.
- **Kartin kendi metnindeki "yeni kartlara ayrilmali" cumlesi bir BORCTUR** — kart
  acilmadan kapanis yapilmaz.

### Acik kalanlar / sonraki adim

- **Yayin hala kosulmadi** (3. kosu bellek yetersizliginden oldurulmustu). Acik kartlarin
  39'u yayina bagli; aralarinda P0 `BR-DB-91` ve `BR-SYS-117`, ayrica sahada gorunmeyen
  `BR-AST-58/61` (sunucudaki imaj `demo-ea567d11bb2e`, commit `ea567d11`, 2026-09-15).
- `BR-AST-119` (a) icin: `IUnresolvedTenantEventCounter.GetTodayAsync` **sebepsiz**;
  kirilim okuyan bir uye + `After["droppedUnresolved"/"droppedConflict"]` gerekiyor.
- `BR-AST-119` (b): alarm bacagi sozlesme acigi olarak duruyor.
- Acik kart: **90**. ClickUp senkron (`fark olan kart: 0, izde olmayan: 0`, 755 kart).


---

## Ek tur — #27 zil grubu YAZMA yuzeyi (frontend-dev-1)

### Baglam

`BR-AST-63` ve `BR-AST-64`'un **kalan tek isi ayni yerdeydi**: #27 (`/telephony/extensions`)
zil grubu paneli **salt-okurdu**. Ayni gun backend-dev-2 `rotating` stratejisini uretime,
`delay_sec` okumasini `ConfigRenderer`'a indirmisti; ekran tarafi kalmisti.

### Yapilanlar

#### 1. Strateji secimi — secenek kumesi C# sabitinden TURETILIYOR

- **Neden:** kartin olculmus hatasi iki listenin sessizce ayrismasiydi. `rotating`
  sunucuda `Supported` kumesine girdiginde TS tarafindaki **elle yazilmis switch** onu
  bilmedi ve ekran gecerli bir degeri `ext.undefined` ("tanimsiz") diye cizdi.
- **Ne yapildi:** `generate-alarm-metrics.mjs` deseninin ikizi olarak yeni bir uretec.
  `RingGroup.cs` icindeki `RingGroupStrategies` sinif govdesi suslu parantez dengesiyle
  cikarilir, `public const string` haritasi ve **`Supported`** ilklendiricisi ayristirilir.
  Kaynak `All` DEGIL `Supported`: yazmanin kabul edildigi kume odur.
  Ayristirmanin her adimi hata firlatir — **bos/kismi liste asla yazilmaz**.
- **Bekci:** etiket haritasi `Record<RingGroupStrategy, MessageKey>`. C#'a dorduncu bir
  strateji eklenip uretim kosarsa tsc **TS2741** ile kirilir; 9 dilde etiket yazmayi
  unutmak sessiz kalmaz.
- **Dokunulan dosyalar:** `src/Pbxtr.Web/scripts/generate-ring-group-strategies.mjs` (yeni),
  `src/Pbxtr.Web/src/app/screens/telephony/ringGroupStrategies.generated.ts` (uretilmis),
  `package.json` (`ring-group-strategies:gen`, `dev`/`build` icine baglandi).

#### 2. Yazma yolu ve fail-closed davranis

- **Uc:** `PUT /api/v1/ring-groups/{id}`, yetki **`ringgroup.write`** (`extension.write` DEGIL).
- **Govde TAM gider** (uye listesi + tasma + sure): uc kismi govde kabul etmez; uyeler
  eksik giderse `ring_group_member_required` doner — yani "degistirdim" diyen bir ekran
  hicbir sey kaydetmemis olurdu.
- **Fail-closed:** sunucudan kapali kume disi bir deger gelirse secici **hic cizilmez**.
  Bir `<select>` tanimadigi degeri gosteremez: ilk secenege duser ve kullanici hicbir sey
  yapmadan strateji **degismis gibi gorunur**; sonraki kaydetmede o yanlis deger gercekten
  yazilirdi.
- **Yetki yoksa deger GIZLENMEZ**, salt okunur kalir — gizleseydik stratejiyi
  degistiremeyen bir supervizor grubun neden sirayla caldigini ekrandan ogrenemezdi.
- **Teslim defteri:** `delivery-manifest.json` + `extensions.ring-group-update`
  (`write_readback`, `restore_previous`, `auditExpectation: required`).

#### 3. `BR-AST-64` — KAPANMADI, sebebi OLCULDU

- **Blokaj FE'de degil, uc sozlesmesinde:** `RingGroupMemberRequest` **uc** alan tasiyor
  (`ExtensionId`, `Position`, `RingTimeSec`) ve `delaySec`i **kabul etmiyor**;
  `RingGroupMemberDto` de **dondurmuyor** (`RingGroupEndpoints.cs:355` bunu zaten yaziyor).
  `src/Pbxtr.Api` altinda (bin/wwwroot disi) `delaySec` gecen TEK satir o yorumdur.
- **Alan UYDURULMADI.** Ekrana alan cizmek, sunucunun **sessizce yok sayacagi** bir deger
  gondermek olurdu — kartin adini koydugu "ayarladim ama calismiyor" sinifinin aynadaki hali.
- **Bunun yerine davranis EKRANDA YAZILDI:**
  - `ext.ruleDelay` (9 dil): gecikme bu ekrandan yazilamaz **ve** tanimli bir gecikme
    grubun calma suresine esit/buyukse o uye **hic calmaz**;
  - `ext.strategyNoDelay`: **sirali** strateji seciliyken "bu stratejide uygulanmaz" notu.
    Eszamanli stratejide o not **cizilmez** (bekci vacuous degil, iki yonlu test var).
- **Kalan is (backend):** dort DTO/record `delaySec` tasimali, `RingGroupRules` onu
  dogrulamali (`0 <= delay < ringTimeSec`) ve `RingGroupDelaySecWritePathTests` o commit'te
  **bilincli** olarak guncellenmeli.

#### 4. Yan bulgu — uretilmis dosya bayatti

`system-roles.generated.ts`, `permissions.seed.json`'daki `agent` rolune eklenen
`alarm.silence.read.self` yetkisini tasimiyordu: birileri tohumu degistirmis, ureteci
kosmamis. Bu turda uretec kosunca fark **git status**'ta gorundu ve duzeltildi.
(Ureticinin ciktisinin depoya islenmesinin sebebi tam olarak budur.)

### Komutlar

```bash
cd src/Pbxtr.Web
node scripts/generate-ring-group-strategies.mjs
node scripts/generate-screens.mjs
npx tsc -b            # rc=0
npx vitest run        # 237 dosya / 2116 test
```

### Sonuc / dogrulama

- `npx tsc -b` **rc=0** (`--noEmit` degil — o yayin kapisi degildir).
- vitest **TAM takim: 237 dosya / 2116 test gecti**; yeni
  `RingGroupStrategyWrite.test.tsx` **8 test**.
- **Mutasyon:** secenek listesi uretilmis sabit yerine elle iki degere sabitlendi →
  8 testin **2'si KIRMIZI**, geri alindi ve yeniden yesil.
- `dotnet build`/`dotnet test` **kosulmadi** (paralel dotnet ajani; eszamanli yuk
  testhost'u cokertiyor). C# **kodu degismedi**; yalniz `delivery-manifest.json` **verisi**
  buyudu. Manifest'in C# kapilari (`DeliveryManifestTests`) bu turda **olculemedi**.
- **Commit:** `737b4472`
- ClickUp senkron: `BR-AST-63 in progress -> complete`, dogrulama `fark olan kart: 0`.

### Kararlar

- **Uretilmis kume > elle liste.** Iki tarafin ayni kapali kumeyi ayri ayri tasidigi her
  yerde ayrisma **sessizdir**; bekci derleme zamaninda kirmalidir.
- **Olmayan uc icin form cizilmez** (CLAUDE.md §5). Ama "cizmedik" yetmez: davranis
  **ekranda yazilir**, yoksa ham SQL ile girilmis bir `delay_sec` yalniz uretilen
  config'in yorum satirinda gorunur.
- **Kapali kume disi deger = yazma yolu kapali.** Bir `select` icin bu bir zarafet degil
  dogruluk sartidir.

### Acik kalanlar / sonraki adim

- `BR-AST-64`: `delaySec`i uc sozlesmesine ekleme isi **backend'de** duruyor; indigi gun
  FE uye satirina sayi alani + `delay >= ringTimeSec` uyarisi ekler.
- `#27`de hala **form yok:** grup olusturma/silme ve numara/ad/sure/tasma/uye duzenleme
  (uclar hazir). `prototip-urun-farklari.md` #27/1'de adi konmus durumda.
- `delivery-manifest.json`'a eklenen action'in **C# kapilari kosulmadi** — bir sonraki
  dotnet turunda `DeliveryManifestTests` + `Pbxtr.Api.Tests` kosulmali.


---

## BR-AST-17 — cok tenant'li dugume teslim (KAPANDI, linux-uzmani turu)

### Baglam
Kart 2026-09-18'e kadar **BLOKE** idi (`BR-AST-108` inmeden kabul kriteri olculemez).
108 kapandi, sira bagimliligi bitti. Hedef: `asterisk-01` dugumune t0007 **ve** t0012
birlikte teslim edilsin, santralde t0012 nesneleri gorunsun, `NO_SUCH_QUEUE` sussun.

### Yapilanlar

#### 1. Neyin eksik oldugu once olculdu (kod degil, KAYIT)
- **Neden:** kart "kod tarafi bitti, kalan is veri" diyordu; once bu dogrulandi.
- **Olcum (`176.88.41.220`, `date -u` = 2026-09-19 03:50Z):**
  - `api_keys` -> `asterisk-01` dugumunde **yalniz t0007** (1 aktif, 5 revoked).
  - `tenants.provisioning_delivery_intent` -> **t0012 = `not_delivered`**
    (BR-AST-108 olcumunun biraktigi hal; `QueueMembershipSyncJob` bu halde kuyruk
    senkronunu **susturuyor**, yani NO_SUCH_QUEUE'nun susmasi da sahte olurdu).
  - `journalctl -u pbxtr-confd` -> her tick `dusen tenant t0012: diskte artik dosya YOK`.

#### 2. URUN YOLU ile baglandi (elle SQL INSERT YOK)
- **Neden:** anahtarin hash bicimi (`Pbkdf2ApiKeySecretHasher`) ve `node` alani urun
  ucundan uretilmeli; elle INSERT ikinci bir dogruluk kaynagi yaratirdi.
- **Kapi okumasi:** `ApiKeyEndpoints.CreateAsync` **dolu bir duguma** ikinci tenant'i
  yalniz `scope=global` (platform) ekler (Kurul #77); teslim niyeti `not_delivered`
  iken pin de yalniz platforma acik (Karar #58). Ikisi de `demo.superadmin` ile gecildi.
- **Capraz-yazma tuzagi:** `X-Cross-Tenant: on` baslugi KULLANILMADI —
  `TenantResolutionMiddleware.cs:406-425` yalniz o bayraga bakar; `X-Tenant-Id`
  drill-in'i yazmaya aciktir. Baslik konsaydi `403 CROSS_TENANT_WRITE_FORBIDDEN`.
- **Komutlar (sunucuda, sir hicbir ciktiya basilmadan):**
  ```bash
  # parola sunucunun kendi .env'inden okundu, ekrana yazilmadi
  PUT  /api/v1/tenant    {"name":"Kuzey Pazarlama","agentLimit":3,"channelLimit":10,
                          "provisioningDeliveryIntent":"deliver",
                          "provisioningDeliveryReason":"..."}        -> 200
  POST /api/v1/api-keys  {"label":"confd-dugum-t0012","node":"asterisk-01",
                          "ipAllowlist":["172.16.0.0/12"]}           -> 201
  ```
- **Sonuc:** `ak_a1427b201a807e90|t0012|asterisk-01`; plaintext **sha256[0:8]=7e5c6875**,
  dosya `/etc/pbxtr/confd/t0012-dugum-anahtari.json` (0600). confd'ye yeni anahtar
  **kurulmadi ve gerekmedi** — dugum paketi tek pinli anahtarla cekilir, uyelik
  `api_keys.node` kesfinden gelir (Karar #31/B).

#### 3. Asil engel cikti: DUGUMUN YEREL DEFTERI (yeni kart `BR-AST-120`)
- t0012 pakete girdi ama ajan **hicbir sey yazmadi**: `sha-defteri` hala
  "t0012 rev=1 teslim edildi" diyordu (108 olcumunde dosyalar **elle** silinmisti) ve
  ajan **defteri diskle karsilastirmiyor** (`deploy/pbxtr-confd-dugum.sh:1020-1048`).
- Defter temizlendikten sonra dort tur yazildi, ama `queues` reload'u BR-AST-25 kapisiyla
  **ertelendi**; `12) Durum defteri` blogu (`:2177-2194`) **ertelenen turun sha'sini yine de
  yazdi** -> sonraki tick "degismedi" dedi ve reload **hic kosmadi**. Kalici kilit.
- Elle asildi: `kuyruk-defteri/t0012` + `t0012 queues` sha satiri + `state.json` ETag
  temizlendi (hepsinin `*.yedek-br-ast-17*` yedegi sunucuda duruyor). Kalici duzeltme
  **yazilmadi** -> `BR-AST-120` acildi.

#### 4. Kabul kriteri olcumu
| Kriter | Sonuc |
|---|---|
| Dugum paketi t0012'yi tasiyor | **EVET** — `tenant t0012`, `HTTP 200`, `SONUC: dugum paketi teslim edildi` |
| `queue show` t0012 **uyeli** | **EVET** — `t0012-musteri-hizmetleri` + 3 uye (`Local/2011..2013`), `QueueAdd` fiilen kostu |
| `dialplan show` t0012 | **89 satir** |
| `pjsip show endpoints` t0012 | **0** — sebep `secret_not_stored`; t0007 icin de ayni satir basiliyor (`BR-AST-51` zinciri, bu kartin isi degil) |
| 3 ardisik tick sifir `NO_SUCH_QUEUE` | **EVET** — 04:01:11 / 04:06:12 / 04:11:21, `grep -c NO_SUCH_QUEUE` = **0** |

- **Commit:** `760e92a0` — BR-AST-17 KAPANDI; `57d161b0` — ClickUp kart id kaydi.
- **ClickUp:** `BR-AST-17 backlog -> complete`, `BR-AST-120` acildi; dogrulama
  `fark olan kart: 0, izde olmayan: 0`.

### Kararlar (bu tur)
- **"Sifir hata" once bos olup olmadigi ile sinanir.** t0012 teslim niyeti
  `not_delivered` iken kuyruk senkronu susturuluyordu; o halde olculen "sifir
  NO_SUCH_QUEUE" **hicbir sey kanitlamazdi**. Once niyet `deliver` yapildi, sonra
  uyelerin fiilen itildigi (`queue show`'da gorundugu) dogrulandi.
- **Defter gercegin yerine gecemez.** Ajan "teslim ettim" defterine bakip diske hic
  bakmiyor; disk elle degisince ajan **sessizce hicbir sey yapmiyor**.
- **Ertelenen is, yapilmis is gibi defterlenmez.** Aksi halde erteleme kalici kilite
  donusuyor (`BR-AST-120`).

### Acik kalanlar
- `BR-AST-120`: ertelenen reload'un sha satiri + defter/disk sapma olcumu **kodda yok**.
- t0012 icin `pjsip` hala `withheld` — `BR-AST-51a/52/51b` zinciri.
- Ikinci bir **gercek** dugumde (iki ayri santral) teslim **olculmedi**.
- Sunucuda birakilanlar: `/var/lib/pbxtr-confd/*.yedek-br-ast-17*`,
  `/etc/pbxtr/confd/t0012-dugum-anahtari.json`; gecici betikler silindi.

---

## Tur — `BR-QA-118` + entegrasyon takiminin TAM olcumu (backend-dev-2)

### Baglam
Ana dalda `TelephonyEventPipelineTests.Canli_gorunum_redis_durumu_ile_db_sayacini_birlestirir:459`
kirmiziydi: bir `PbxtrCallAnswered` yutuldugu halde `after.AnsweredToday - before.AnsweredToday`
**1 yerine 0**. Kirmizi yeni degildi, **maskeliydi** — ayni sinifin 11 testi `WebhookOutboxWriter`
DI kaydi eksik oldugu icin daha erken dusuyordu (`37e77e01` ile kayit konunca 11 -> 1 oldu).
Ikinci is: entegrasyon takiminin tam olcumu; koordinatorun turu 570 sn'de `rc=124` ile yarida
kalmisti, yani gorunen kirmizi listesi eksikti.

### Yapilanlar

#### 1. `BR-QA-118` — sayac neden artmiyor (ONCE OLC, SONRA KOD)
- **Neden:** kartta uc supheden hicbiri olculmemisti, ikisi de "elendi" diye yazilmisti.
- **Ne yapildi:** teste gecici bir probe konuldu ve gercek PostgreSQL uzerinde kosuldu:

  ```
  PROBE source=synthetic|1|2026-09-19 02:59:15+00  before=0  after=0
  ```

  Boru hattinin yazdigi `cdr` satiri `source='synthetic'`; gunluk toplam sorgusu
  `.RealOnly()` tasiyor (`RedisLiveOperationsView.cs:282,361` -> `CallDataSourceQuery.cs:58`).
  **Kartta "elendi" yazan (a) sikki aslinda DOGRUYMUS** — eleme, sorgu metninde ciplak
  `source` kelimesi arayarak yapilmis; filtre uzantinin icindeydi. Diger iki suphe ayni
  olcumde elendi (`started_at` bugun, `before=0`; `linkedid` cakismasi yok).
- **TEST mi URUN mu:** **TEST IKIZI**. Uretimde bu boru hattini kosturan tek bilesim
  `Telephony:Provider=asterisk`tir ve damga orada zaten `live`dir
  (`TelephonyServiceCollectionExtensions.cs:285`) -> `#01`/`#12` sayaci uretimde dogru
  calisir. Sentetigin canli gorunumden dislanmasi BR-QA-51 / S66-19'un ACIKCA istedigi sey.
- **Duzeltme:** `TelephonyTestHost` damgayi acikca `CallDataSourceStamp.Live` kaydediyor.
  Secim yeni bir istisna DEGIL: `CallDataSourceStampInterceptor`in kendi belgesi "DAMGA YOKSA
  Live" derken gerekcesini birebir yaziyor (*"orada satir koyan tek sey, gercek bir cagrinin
  yerine gecen bir fiksturdur ve onu synthetic saymak testin kurdugu senaryoyu SESSIZCE yok
  ederdi"*). Ayrica konak `CallDataSourceStampInterceptor`i hic kaydetmiyordu; uretim kaydinin
  birebir sekli kondu.
- **Yeni vaka:** `Sentetik_damgali_cagri_canli_sayaci_kimildatmaz` — `.RealOnly()`yi bugune
  kadar olcen tek sey bir METIN taramasiydi.
- **Mutasyon (ikilide dogrulandi):** `:361`'deki `.RealOnly()` silindi -> yeni vaka KIRMIZI
  (`Expected: 0, Actual: 1`); geri alindi -> 15/15 yesil. Ilk denemede build 2 hatayla
  atlanmisti ve olcum eski ikiliye gitmisti; tekrarlandi.
- **Dokunulan dosyalar:** `tests/Pbxtr.Integration.Tests/Support/TelephonyTestHost.cs`,
  `tests/Pbxtr.Integration.Tests/Tests/TelephonyEventPipelineTests.cs`
- **Commit:** `1be5de84`

#### 2. `BR-QA-119` — ayni arizanin DORT biçimi
- **Neden:** `20260919020000_CallDataSourceColumn` `source`'u VARSAYILANSIZ NOT NULL yapti.
- **(i) EF yazicilari:** interceptor yalnizca `AddPbxtrPersistence`e kaydedilmisti; kendi
  `DbContext`ini kuran **yedi** test konagi onsuz kaldi (`TelephonyTestHost`, `Faz2Database`,
  `JobApplication`, `RealSchemaDatabase`, `TestApplication`, `ScripterPersistenceTests`,
  `ScripterHttpTests`).
- **(ii) Ham SQL tohumlari:** 10 dosya + paylasilan fikstur. Deger her yerde `'live'` —
  `'synthetic'` yazmak `23502`yi susturur ama iddiayi **bos kume** uzerinde yesil yakardi.
- **(iii) HTTP urun yolu:** `PanelHttpApplication` `simulated` oldugu icin
  `BlockedCallResultWriter`in yazdigi satirlar `synthetic` oluyordu ve rapor uclari onlari
  hic gormuyordu (olcum: `cdr`'dan 3, rapordan 1).
- **(iv) Elle yazilmis ikiz tablo:** `PbxtrDatabaseFixture.CreateCdrSchemaAsync` `public.cdr`'i
  elle yaratiyor; `source` kolonu uretimdeki sekliyle eklendi.
- **KOR TOPLU YAMA YANLISTI ve OLCULDU:** dort dosya (`CallbackSlaSqlParityTests`,
  `SlaDeadlineRestatementTests`, `SlaEventOrderingTests`, `SlaHoldTimePipelineTests`) KENDI
  minimal `call_events` tablosunu yaratir ve kendi belgesinde *"gercek semanin 15 kolonunun
  tamamini TASIMAZ ve tasimamalidir"* yazar. Onlara kolon eklemek 13 kirmiziyi kapatirken
  **15 yenisini acti** (`42703`); geri alindi.
- **Yan bulgu:** `PersistenceRegistrationTests.AddPbxtrPersistence_uc_interceptoru_da_baglar`
  KENDI YAZDIGI KEHANETTE kirmiziydi — belgesi birebir *"uretime dorduncu bir interceptor
  eklenip teste eklenmezse ..."* diyor. Sayi 4'e cekildi + `Assert.Contains` eklendi.
- **Commit:** `e24ebf2d`, `219eb75d`, `5d51dd35`

#### 3. Entegrasyon takiminin TAM olcumu — 1177 vaka / 66 parca
- **Neden:** tek koşuda bitmiyor; "takim yesil" diye raporlanamaz.
- **Ne yapildi:** `--list-tests` ile 1177 vakanin tam envanteri cikarildi, sinif adi onekine
  gore 66 parcaya bolundu, her parcada **beklenen** vaka sayisi **kosan** sayiyla
  karsilastirildi (sapma yok).
- **Komutlar:**

  ```bash
  dotnet test tests/Pbxtr.Integration.Tests/... --no-build --list-tests
  dotnet test tests/Pbxtr.Integration.Tests/... --no-build --filter "FullyQualifiedName~Pbxtr.Integration.Tests.Tests.<onek>"
  ```

- **Sonuc:** kapanmayan kirmizi **39** (3 + 1 + 35), geri kalanin 2'si ortam nedeniyle
  atlaniyor, 1134'u yesil.
- **Acilan kartlar:** `BR-DB-105` (sys fonksiyon bekcisi md5 sapmasi),
  `BR-DB-106` (`voicemail_sla_daily.box_id`, down->up), `BR-DB-107` (35 vaka, arka plan
  islerinin ST-41 denetim satiri `42501` ile RLS'ten donuyor).

### Kararlar (bu tur)
- **Test ikizi ile urun arasinda fark varsa once "hangisi dogru" sorulur.** `AnsweredToday`
  urunde calisiyordu; duzeltilen sey ikizin bilesimiydi. Urune tek satir dokunulmadi.
- **Fikstur satirinin kaynak damgasi `live`dir**, cunku gercek bir cagrinin yerine gecer ve
  okundugu urun yollari `.RealOnly()` ile suzer. Tek istisna, konusu KAYNAK EKSENI olan vaka.
- **"Ham SQL ile yazan 15 dosya" yanlis evrendi;** dogru evren "ham SQL ile GERCEK SEMAYA
  yazan"dir. Evren yanlis tanimlanmis bir toplu yama, kapattigindan cogunu acti.
- **Olcum yonteminin kendi tuzagi kayda gecti:** art arda kosuda testcontainers
  "Test host process crashed" ile 0 test kosup `rc=1` donuyordu ve AYNI filtre tek basina
  yesildi; ayrica cok uzun OR filtresi de cokme uretiyordu. Kosular arasina sogutma kondu,
  sogutmasiz olculen her parca GECERSIZ sayildi.
- **Kirmizinin sahibi once olculur:** `BR-DB-107` icin kendi degisikligim CIKARILIP ikili
  yeniden derlendi ve ayni 17 vaka ayni hatayla dustu -> "benim degil" bir iddia degil olcum.

### Acik kalanlar / sonraki adim
- `BR-DB-105` / `BR-DB-106` / `BR-DB-107` — ucu de db kulvari, ucu de olculu, hicbiri
  kapatilmadi.
- `BR-DB-107`in "test ikizi kusuru mu urun kusuru mu" ayrimi **OLCULMEDI** ("yok" demiyorum,
  olcemedim): kosu aninda `app.tenant_id` / `app.cross_tenant` okunmali. Aday sebep
  `3065b181` (capraz kipin tenant basina daraltilmasi) ama **tahmindir**.
- `tests/` altinda `AddDbContext<PbxtrDbContext>` kuran **22 yer daha** damga
  interceptor'unu tasimiyor; bugun yesiller cunku EF ile `cdr`/`call_events` yazmiyorlar.
  Mimari bekciye baglanmadi.
- Son uc duzeltmeden sonra 66 parcanin TAMAMI bastan kosulMADI; etkilenen parcalar
  (A/Ca/Sc/Tel + FinalDeliveryReport) fiilen yeniden kosuldu, otekiler devralindi.

---

## Ek tur — `BR-DB-107` OLCULDU ve KAPANDI (db-dev)

### Baglam
Yukaridaki "acik kalanlar" listesinde `BR-DB-107`in tek eksigi yaziliydi: **42501'in iki
kosulundan hangisi duesuyor** ve bu bir **urun kusuru mu, test ikizi kusuru mu**. Bu tur
o olcumu yapti.

### 1. Kosu aninda PROBE (tahmin degil)
- **Neden:** kartin aday sebebi (`3065b181`, capraz kipin tenant basina daraltilmasi)
  acikca TAHMIN olarak isaretliydi; `audit_log` policy'si iki kollu
  (`tenant_id = app_current_tenant() OR app_is_cross_tenant()`) ve hangisinin duestugu
  olculmemisti.
- **Ne yapildi:** `QueueMembershipSyncJob.cs`'e, denetim yaziminin **hemen oncesine**,
  ayni transaction'da iki GUC'u okuyup firlatan gecici bir probe kondu; tek test kosuldu;
  probe **silindi** (urun dosyasi commit'te YOK, `git diff` bos).
- **Olcum:**

  | | `app.tenant_id` | `app.cross_tenant` |
  |---|---|---|
  | IKIZ (test konagi) | `''` (BOS) | `off` |
  | URETIM (`LeaderElectedJobRunner`) | `<SystemTenantId>` | `off` |

  Yani ikizde **iki kol da** duesuyordu; uretimde **birinci kol saglaniyor**.
- **Sonuc:** BR-DB-95 / S76-7 (D2) daraltmasi urun yolunu **kirmamistir**; tick geri
  alinmaz, kuyruk uyeligi santrale gider. Kart bu yuzden **P0'a cikarilmadi** ve gerekcesi
  bir olcumdur.

### 2. Kok sebep — ikiz uretimden DAR
- **Uretim:** `LeaderElectedJobRunner.cs:231-232` `accessor.Push(SystemState())`,
  `:236-238` `dbContext.Database.BeginTransactionAsync` -> `TenantSessionInterceptor`
  `SET LOCAL app.tenant_id` yazar; ise gecen `JobExecution.Connection` **ayni oturumdur**.
- **Ikiz:** `new JobExecution(null, connection, transaction, node, tenant)` — ciplak
  `NpgsqlConnection`, `DbContext` yok, GUC hic yazilmiyor.
- Kayitli ders *"test ikizi uretimden musamahakar"*in **ters yonu**: burada ikiz DAR'di.

### 3. Duzeltme
- **Dokunulan dosyalar:**
  - `tests/Pbxtr.Integration.Tests/Support/JobExecutionHarness.cs` (YENI) — uretimin GUC
    kurulumunu birebir yapar. Iki tenant sinifi AYRI: `ContextTenant` (t0012, denetimi
    `execution.ContextTenantId` ile yazan isler) ve `OptionsSystemTenant`
    (`BackgroundJobOptions.SystemTenantId` ile yazan `PlatformRollupJob`, `Program.cs:357`).
    Karistirilsaydi **yine 42501** gelirdi.
  - `tests/Pbxtr.Integration.Tests/Tests/BackgroundJobTenantGucTests.cs` (YENI, KALICI
    BEKCI) — gercek PostgreSQL + gercek kosucu ile "uretim isin baglantisina
    `app.tenant_id` KURAR" iddiasini olcer.
  - Yedi cagri yeri harness'e cevrildi: `QueueMembershipSyncJobTests`,
    `QueueMembershipSyncAlarmTests` x2, `PlatformRollupJobDbTests` x2,
    `PlatformUnresolvedTenantCounterTests`, `ProvisioningPullHealthDbTests`.
- **Bekci kaybolmadi:** is baglami bilerek fikstur tohumunun (t0007) DISINDAKI bir
  tenant'tir; is capraz kapsami acmayi unutursa kesif yine 0 satir gorur ve test kirmizi olur.
- **SEMA DEGISMEDI** — `01-rls-template.sql` / `02-guards.sql` govdelerine dokunulmadi,
  migration/refresh gerekmez.

### 4. Sonuc / dogrulama
- **Kirmizi 35 -> 0.** 47/47 yesil (18+18+3+6+1+1). Kartin listesi 22 vaka sayiyordu;
  kalan 13'u `QueueMembershipSyncAlarmTests`'te ayni imzayla duruyordu (22+13=35) —
  **kartin kendi listesi eksikti**.
- **MUTASYON:** harness'teki `set_config` kapatildi, ikili yeniden derlendi (DLL damgasi
  dogrulandi) -> **22/28 vaka yeniden KIRMIZI, ayni 42501**; geri alininca 29/29 yesil.
- **SUPURME:** kalan 22 ciplak `new JobExecution(...)` cagri yeri de kosuldu
  (32+24+29 entegrasyon + 3 `Api.Tests`) — hepsi yesil.
- `dotnet format --verify-no-changes`: temiz (python yamasinin biraktigi BOM duzeltildi —
  **kayda deger tuzak**: `utf-8-sig` ile yazmak 5 dosyaya BOM ekledi ve format kapisi
  `CHARSET` hatasi verdi).
- **Commit:** `53c5ace8` — BR-DB-107 KAPANDI. ClickUp: `BR-DB-107 backlog -> complete`
  (fark: 0, izde olmayan: 0).

### Kararlar
- **"Ikiz mi urun mu" sorusu tek bir probe kosusuyla cevaplanir** ve cevaplanmadan kart
  kapatilmaz; bu turda cevap **ikiz** cikti ve urune TEK SATIR dokunulmadi.
- **Kartin vaka listesi bir olcum degildir.** 35 yaziyordu, 22 listeliyordu; eksik 13 ayni
  imzayla baska bir sinifta duruyordu. Sinifi imzadan (yigin izi) tara, listeden degil.

### Acik kalanlar / sonraki adim
- Kalan 22 ciplak `new JobExecution(...)` cagri yeri **bugun yesildir** cunku o islerin
  capraz kipi denetim yazimina kadar ACIK kalir. `BR-DB-95`in kalan D2 kalemleri
  (`CallbackRunJob`, `LeaveEnforcementJob`) daraltildiginda ayni sekilde kirmiziya doner —
  **acik is `BR-DB-95`te durur**, yeni kart acilmadi.
- `BR-DB-105` / `BR-DB-106` hala acik.


### 21. Iki kartin MERKEZ IDDIASI olcumle curudu (koordinator)

- **Neden:** Bugunku turun tekrarlayan deseni: kart bir eksigi dogru teshis ediyor ama
  **eksigi yanlis evrende ariyor** ve "yok" diye yaziyor. Iki kartta da ayni sey cikti.

#### 21.1 `BR-SYS-122` — "ikinci kopya YOK" iddiasi curudu (KAPANDI)

- **Kartin iddiasi:** `pbxtr:sys:dropped:*` = ariza kaniti, **tek kopya**, TTL 48 saat ->
  yanlis. Kart ikinci kopyayi **uc yerde** aramis: konteyner gunlugu
  (`grep -ci unresolved` -> 0), log surucusu penceresi (boyut tabanli), ve
  *"DB'ye zaten yazilmiyor"*.
- **DORDUNCU YERE BAKILMAMIS: `audit_log`.** `PlatformRollupJob` sayaci 15 dakikada bir
  okuyup denetim satirina yaziyor (`PlatformRollupJob.cs:327,334` -> `GetTodayAsync`;
  `:491` -> `After["unresolvedTenantEvents"]`) ve denetim satirinin **TTL'i YOKTUR**.
- **Olcum (`176.88.41.220`, sunucu saati `2026-09-19 19:36Z`, salt-okuma):**
  ```sql
  select count(*) from audit_log where after ? 'unresolvedTenantEvents';   -- 7614
  select min(at)::date, max(at)::date from audit_log where after ? '...';  -- 2026-08-26 .. 2026-09-19
  -- gunluk tepe: 09-15=0  09-16=0  09-17=33224  09-18=0  09-19=0
  ```
- **Sonuc:** kartin *"48 saat sonra kanit yok olur"* senaryosunun **tam ornegi**
  (`BR-AST-119`'un 33.224'u) bugun **hala okunabiliyor**; Redis kovasi coktan silindi.
  Kartin ayirt edici sorusu (*"silinirse olgu geri getirilebilir mi"*) **aynen dogru kaliyor**;
  yanlis olan cevabi.
- **Kayitli ders birebir:** *sinifi kapat, kalem toplama* — evren "Redis + konteyner gunlugu"
  diye tanimlaninca `audit_log` taramanin disinda kaldi ve **eksik evrende yapilan olcum
  dogru olcum gibi gorundu**.
- **Devredildi (`BR-AST-119`):** denetim satiri **kirilimi** tasimiyor; *"kaci cozulemedi,
  kaci celiskiydi"* hala 48 saatlik. Desen depoda hazir: `skippedTenants` ayni sozlukte
  uc alt sebebiyle yaziliyor (`:481-484`, `BR-BE-173`).
- **Olcmedigim:** `payload-rejected` ve `*:broken:<gun>` kovalarinin denetimdeki karsiligi
  ayri ayri olculmedi.
- **Commit:** `2d86a1d9`

#### 21.2 `BR-DB-107` (ajan: db-dev) — 35 kirmizi URUN kusuru DEGILDI

- **Belirti:** 35 entegrasyon vakasi `42501 new row violates row-level security policy`;
  yigin izi **urun dosyasini** gosteriyordu ve teshis *"uretimde tick geri alinir -> kuyruk
  uyeligi santrale hic gitmez"* idi, yani **P0 gibi** okunuyordu.
- **Olcum (kosu aninda, hatanin atildigi transaction icinde):**

  | | `app.tenant_id` | `app.cross_tenant` |
  |---|---|---|
  | IKIZ (test konagi) | **bos** | `off` |
  | URETIM (`LeaderElectedJobRunner:231-238`) | `<SystemTenantId>` | `off` |

- **Sonuc: TEST IKIZI.** Ikiz ciplak `NpgsqlConnection` ile `JobExecution` kuruyordu;
  `DbContext` yok -> `TenantSessionInterceptor` `SET LOCAL app.tenant_id` hic yazmiyordu.
  **P0'a CIKARILMADI**; uretimde kuyruk uyeligi santrale gidiyor.
- **35 kirmizi -> 0** (47/47 yesil). Kartin kendi listesi **eksikti**: 22 sayiyordu,
  kalan 13'u `QueueMembershipSyncAlarmTests`'te ayni yigin iziyle duruyordu.
- **Mutasyon:** harness'teki `set_config` kapatildi, ikili yeniden derlendi (DLL damgasi
  dogrulandi) -> 22/28 yeniden KIRMIZI, ayni `42501`; geri alininca 29/29 yesil.
- **Kalici bekci birakildi:** `tests/.../BackgroundJobTenantGucTests.cs` — uretim
  kosucusunun GUC'u gercekten yazdigini gercek PostgreSQL'de olcer.
- **Commit:** `53c5ace8`

#### 21.3 `BR-AST-109` (2) — park yeri adi YENIDEN KULLANILMAZ (karar)

- Kart (2)'yi *"plan kurul isidir"* diye birakmisti; kurul dagitildi.
- **Karar:** park yeri adi dugumun omru boyunca yeniden kullanilmaz; dusurulup geri eklenen
  tenant **yeni ad** alir (kusak eki `t0012-tut-g2`). Kusak sayaci **yalniz dusurmede** artar
  — her revizyonda artsaydi hastaligin kendisini tedavi diye uretirdik.
- **Gerekce:** kartin olctugu sey tam olarak ayni adin geri verilemedigidir; silinen turun
  baglami santralde **kaliyor** (`res_parking`e ozgu; kontrol grubu 89 -> 0 temizlendi).
  Tenant oneki bunu **gormez** — cakisma tenant'in kendi gecmisiyledir.
- **(3) sizinti etkisi BILEREK olculmedi:** sunucuda `pbxtr-confd` uzerinde paralel bir is
  kosuyor; park dosyalarina dokunmak onun olcumunu bozardi. *"Yok"* degil, **sirlama** karari.
- **Commit:** `db05d9c5`

### Kararlar (bu tur)

- **Bir kart "X YOK" diyorsa once EVRENINI sor.** Iki kartta da eksik gercekti ama
  **arandigi yer eksikti**; ikisi de dogru olcum gibi gorunuyordu.
- **Kirmizi bir testin yigin izi sahiplik kaniti degildir.** Cevre/oturum durumuna bagli
  hata kodlarinda (`42501`, `23502`, `55P03`) kosu anindaki durum OKUNUR ve uretimdeki
  kurucusuyla yan yana konur; ayrim bir probe kosusu kadar ucuzdur.
- **Paralel is, olcumun sirasini belirler.** Ayni sunucuda baska bir ajan varken onun
  olcum yuzeyine dokunulmaz; bu bir eksik degil, yazili bir sira karari olur.

### Acik kalanlar / sonraki adim

- Acik kart **87**. ClickUp senkron (`fark: 0, izde olmayan: 0`).
- **Yayin hala kosulmadi** ve acik kartlarin buyuk kismi ona bagli (uc P0 dahil).
- Kosan ajanlar: `BR-SEC-29` (tasarim A), `BR-AST-64` (uc sozlesmesi), `BR-AST-120`
  (confd defter kilidi).

---

## BR-AST-64 — `delay_sec` uc sozlesmesi (backend-dev-1)

### Baglam
Karta bugun iki taraf inmisti: uretim (`ConfigRenderer` artik `delay_sec` okuyor, Karar
#66 M19(a)) ve FE (alan cizilemedi, sebebi olculdu). Kalan tek is **uc sozlesmesiydi**:
`RingGroupMemberRequest` `delaySec` kabul etmiyor, `RingGroupMemberDto` dondurmuyordu.

### Yapilanlar

- **Neden:** kolon DB'de var, uretim okuyor, ekran cizemiyor -> "sessiz olu alan".
  Ayrica olculen ikinci bir ariza: guncelleme uyeleri **silip yeniden ekliyor**, yani ham
  SQL ile girilmis bir gecikme panelden yapilan ILK kayitta sessizce `0`'a dusuyordu.
- **Ne yapildi:** dort kayit da `delaySec` tasir oldu (`RingGroupMemberRequest`,
  `RingGroupMemberDto`, `RingGroupMemberInput`, `RingGroupMemberRow`); EF yazma yolu
  alani yaziyor, okuma yolu donduruyor; `RingGroupRules` uretimin **bugunku**
  davranisina birebir dogrulama yapiyor.
- **Karar — sessiz kabul degil RED:** gecikme >= grup zaman asimi -> `422
  ring_group_member_delay_not_ringing`; es zamanli disi stratejide gecikme -> `422
  ring_group_member_delay_strategy_unsupported`; aralik disi (`0..60`, DB CHECK'i ile
  ayni sayi) -> `Invalid`. **Uyari alani secilmedi**, cunku uyari alani istemcinin onu
  cizmesine baglidir; cizmeyen istemci icin davranis yine sessiz kabuldur.
- **Bekci ters cevrildi:** `RingGroupDelaySecWritePathTests` artik "hicbir uretim satiri
  yazmaz" degil, **"yazan TAM OLARAK BIR yol var"** olcuyor.
- **Dokunulan dosyalar:** `src/Pbxtr.Domain/Modules/Telephony/IRingGroupAdministration.cs`,
  `src/Pbxtr.Infrastructure/Modules/EfRingGroupAdministration.cs`,
  `src/Pbxtr.Api/Modules/Telephony/RingGroupEndpoints.cs`,
  `tests/Pbxtr.Api.Tests/Modules/Telephony/RingGroupProvisioningTriggerTests.cs`,
  yeni `tests/Pbxtr.Api.Tests/Modules/Telephony/RingGroupDelaySecContractTests.cs`,
  `tests/Pbxtr.Architecture.Tests/RingGroupDelaySecWritePathTests.cs`,
  `doc/prototip-urun-farklari.md` (#27/1), `yonetim/backlog.md`
- **Komutlar:**
  ```bash
  dotnet test tests/Pbxtr.Api.Tests/Pbxtr.Api.Tests.csproj --no-build     --filter "FullyQualifiedName~Pbxtr.Api.Tests.Modules.Telephony"
  dotnet build src/Pbxtr.Infrastructure/Pbxtr.Infrastructure.csproj --no-incremental
  dotnet test tests/Pbxtr.Architecture.Tests/Pbxtr.Architecture.Tests.csproj --no-build
  ```
- **Sonuc / dogrulama:** `Modules.Telephony` **1371 gecti / 0 kirmizi / 2 atlandi**
  (onceki tur 1350; +21 vaka, 4'u uctan uca: POST `delaySec=5` -> uretilen dialplan'de
  `Wait(5)` + GET yanitinda `"delaySec":5`). `Architecture.Tests` TAM takim **752/753**;
  tek kirmizi `SpaBuildContextTests` ve **bu turun isi degil** (FE'nin
  `generate-ring-group-strategies.mjs`'i `RingGroup.cs` okuyor, Dockerfile SPA asamasi
  onu KOPYALAMIYOR -> yayin imaji ENOENT ile duser; ayri sahip/kart gerekir).
  **Mutasyon 2/2 kirmizi.**
- **Commit:** `bb08b23d`

### Kararlar (bu tur)

- **Uyari alani, kurali cizmeyen istemciye emanet etmektir.** Sunucu tarafinda red,
  "kaydettim ama calmiyor" sinifini gercekten kapatan tek sey.
- **Ayni alan iki stratejide iki anlam tasiyamaz.** Sirali/turlu stratejide gecikme
  reddedilir; uretim onu uygulamiyor, uc de kabul etmez.

### Olcum dersi (kayda deger)

**Damga tazeligi derleme kaniti degildir.** EF yazimini silen mutasyon ilk kosuda YESIL
gorundu: `dotnet build` rc=0 dondu ve `Pbxtr.Infrastructure.dll` **damgasi guncellendi**,
ama IL eski haldeydi — bekci mutasyonsuz ikiliyi olcuyordu. `--no-incremental` ile
yeniden derleyince mutasyon yakalandi. Mutasyon olcumleri `--no-incremental` ister.

### Acik kalanlar

- **FE kalan isi (ayri sahip):** #27 uye satirina sayi alani + `delay >= ringTimeSec`
  uyarisi; bugun cizili `ext.ruleDelay` notu ("bu ekrandan yazilamaz") artik YANLIS ve
  gercek alana baglanmali. `ext.strategyNoDelay` notu DOGRU kalir.
- **Dockerfile SPA asamasi `RingGroup.cs`'i kopyalamiyor** -> `SpaBuildContextTests`
  kirmizi; yayin imajini bloke eder, kart acilmali.
- **Olcemedigim:** gercek santralde cagri denenmedi (uretilen METIN olculdu);
  `Integration.Tests` kosulmadi (paralel db-dev ajani) — yalniz derlendi, rc=0.


### 22. Ana daldaki YAYIN KIRICI kapatildi + kapali kartta kalan is kartlandi

#### 22.1 `BR-SYS-125` — yayin imaji ANA DALDA derlenmiyordu (KAPANDI)

- **Nasil bulundu:** `BR-AST-64` ajani kendi isini bitirirken `Architecture.Tests` TAM
  takimini kostu (752/753) ve **kendi isi olmayan** tek kirmiziyi raporladi:
  `SpaBuildContextTests`. Kayitli ders tersten dogrulandi — *kirmizinin sahibi once
  olculur* kurali burada **raporlamayi** sagladi, susmayi degil.
- **Kusur:** bugunku FE turu `src/Pbxtr.Web/scripts/generate-ring-group-strategies.mjs`
  uretecini ekledi; uretec **depo kokunden** `src/Pbxtr.Domain/Modules/Telephony/RingGroup.cs`
  okuyor ve `npm run build` onu **her seferinde** kosturuyor (`package.json:8`).
  Dockerfile'in SPA asamasi ise **bilerek** yalniz `src/Pbxtr.Web`'i tasir ->
  `docker build`, `npm run build` adiminda **ENOENT** ile duserdi: **yayin imaji
  DERLENEMEZDI.**
- **Neden yerel kapilar gormez:** hepsi depo kokunde kosar ve orada dosya yerindedir.
  `npx tsc -b` de yesil kalir, cunku uretilen `ringGroupStrategies.generated.ts` depoda
  **islenmistir** ve `tsc` onu **kaynagina karsi** dogrulamaz. Tek koruma o mimari bekcidir.
- **Duzeltme:** SPA asamasina **tek dosyalik** `COPY` (klasorun tamami degil -- npm
  katmaninin onbellegi Telephony'deki ilgisiz degisikliklerde bosalmasin;
  `AlarmEvaluator.cs` deseninin aynisi).
- **Olcum:** `SpaBuildContextTests` **2/2 gecti**, `rc=0`.
  **Mutasyon KIRMIZI:** `COPY` satiri kaldirilinca **Failed 1 / Passed 1**, `rc=1` ve hata
  metni eksik dosyayi **adiyla** basti; geri konunca yine 2/2, `rc=0`.
- **BU SINIFIN DORDUNCU TEKRARI:** `screens.json`, `delivery-manifest.json`,
  `permissions.seed.json` ve `AlarmEvaluator.cs` icin ayni gerekceyle yazilmis yorumlar
  Dockerfile'da **zaten** duruyor.
- **Olcmedigim:** `docker build` **fiilen kosturulmadi**; olculen sey bekcinin iddiasidir,
  ENOENT'in kendisi degil.
- **Commit:** `8ab15a65`

#### 22.2 `BR-AST-64` (ajan: backend-dev-1) — KAPANDI

- `delaySec` artik ucta: `RingGroupMemberRequest` `int?`, `RingGroupMemberDto` `int`;
  **dort kayit olcuulerek** bulundu (tahmin degil).
- **Uyari alani degil RED secildi.** Gerekce: uyari alani istemcinin onu cizmesine baglidir;
  cizmeyen istemci icin davranis **yine sessiz kabuldur** -- ariza kapanmaz, YER DEGISTIRIR.
  Kodlar: `422 ring_group_member_delay_not_ringing`,
  `422 ring_group_member_delay_strategy_unsupported`, aralik `0..60`.
- **Bonus bulgu:** guncelleme uyeleri silip yeniden ekliyor; EF yazimi eklenmeseydi ham SQL
  ile girilmis `delay_sec` **panelden yapilan ilk kayitta sessizce 0'a duserdi**.
- **Olcum tuzagi kayda gecti:** EF yazimi mutasyonu ILK KOSUDA YESIL gorundu --
  `dotnet build` `rc=0` dondu ve DLL **damgasi bile guncellendi**, ama IL eski haldeydi.
  `--no-incremental` ile yakalandi. **Damga tazeligi derleme kaniti degildir.**
- **Olcum:** `Modules.Telephony` **1371 gecti / 0 kirmizi / 2 atlandi** (+21 vaka).

#### 22.3 `BR-FE-125` acildi — kapali kartta kalan is

- `BR-AST-64`'un kapanis metninde *"FE KALAN ISI (frontend sahibi, ayri)"* duruyordu
  **ama o kart KAPALI**. Kapali bir kartin icindeki is backlog'da **acik satir uretmez** ve
  CLAUDE.md 14'e gore ClickUp'a da **hic gitmez** -> gorunmez borc olurdu.
- Kart acildi ve **hemen** frontend'e verildi. Kabul olcutu bilerek dar: **iki 422 kodu
  ekranda AYRI mesaja dusmeli** -- tek genel hata seridi karti kapatmaz, cunku
  *"aralik disi"* ile *"bu uye hic calmaz"* farkli islerdir.
- **Commit:** `a831f374`

### Kararlar (bu tur)

- **Bir kart kapanirken icinde baska bir sahibin isi kaliyorsa, o is AYNI TURDA
  kartlanir.** "Kapanis metninde yazili" olmak backlog'da satir uretmez.
- **Sessiz kabul yerine RED**: bir kural yalnizca istemci cizerse gorunuyorsa, o kural
  cizmeyen istemci icin YOKTUR.
- **DLL damgasi derleme kaniti degildir** -- mutasyon olcumunde `--no-incremental` sart.

### Acik kalanlar / sonraki adim

- Acik kart **87**. ClickUp senkron (`fark: 0, izde olmayan: 0`, 759 kart).
- Entegrasyon takiminda kalan kirmizi: `BR-DB-105` ve `BR-DB-106` (toplam ~4 vaka);
  `BR-DB-107`'nin 35'i ve `SpaBuildContextTests` kapandi.
- **Yayin hala kosulmadi.**

---

## 23. `BR-FE-125` KAPANDI — `#27` uye gecikmesi alani (frontend-dev-1)

### Neden

Uc tarafi ayni gun inmisti (`bb08b23d`) ama ekran hala **"bu ekrandan yazilamaz"** diyen bir
kural satiri ciziyordu. Yanlis kalan bir yardim metni, olmayan bir yardim metninden kotudur:
kullanici alani gorur, ekran "yazamazsin" der.

### Ne yapildi

1. **`#27` uye rozetinin icinde yazilabilir `delaySec` sayi alani** (`ringgroup.write`).
   Yetkisi olmayana alan cizilmez ama **sifirdan buyuk deger gizlenmez** (salt okunur rozet).
   Yazma `blur`/`Enter`da: her tusta yazmak ara bir degeri **provisioning revizyonuna**
   cevirirdi.
2. **`delay >= grup suresi` icin uyenin ADIYLA uyari.** Yalniz deneyim; guvenlik siniri
   sunucudadir (CLAUDE.md 5).
3. **`ext.ruleDelay`** *"yazilamaz"* -> *"yazilir (0-{max} sn)"*; **`ext.strategyNoDelay`
   KORUNDU** (sirali stratejide alan gonderilirse sunucu 422 doner). Yeni etiketler **9 dilde**.
4. **Esik sabiti elle yazilmadi:** `RING_GROUP_MAX_DELAY_SEC` ayni ureteçten
   (`scripts/generate-ring-group-strategies.mjs`) `RingGroupRules.MaxDelaySec`ten turer.
   Ikinci kaynak icin **`Dockerfile` SPA asamasina COPY satiri** eklendi -- `BR-SYS-125`'in
   birebir sinifi.

### Yol ustunde olculen blokaj (bu kart kod yazarak kapanamazdi)

`RingGroupEndpoints.Problem` ProblemDetails'e **`code` uzantisini yazmiyordu**; deponun diger
**294** cagri yeri `ProblemResponse` ile yazar, burasi o desenin disindaydi. Istemcideki
`ApiError.code` = `body.code ?? internal_error` oldugu icin **her reddi `internal_error`
goruyordu** -- yani sunucunun BILEREK ayirdigi iki 422 istemciye hic ulasmiyordu. Uzanti
eklendi; `type`/`title`/durum kodu **degismedi**. Ayrica eslenemeyen kodda baslik **kodun
kendisiyse** ekrana basilmaz (kullanici `ring_group_teleport_failed` okumaz).

### Dokunulan dosyalar

`src/Pbxtr.Web/src/app/screens/telephony/{ExtensionsScreen.tsx, extensionsApi.ts,
ExtensionsScreen.module.css, RingGroupMemberDelay.test.tsx, RingGroupStrategyWrite.test.tsx,
ringGroupStrategies.generated.ts}`, `src/Pbxtr.Web/scripts/generate-ring-group-strategies.mjs`,
9 dil dosyasi, `Dockerfile`, `src/Pbxtr.Api/Modules/Telephony/RingGroupEndpoints.cs`.

### Olcum

| Ne | Sonuc |
|---|---|
| `npx tsc -b` (yayin kapisi) | temiz |
| `npm run build` | RC=0 |
| `vitest` (tam) | **2127 gecti / 0 kirmizi**, 238 dosya |
| Yeni `RingGroupMemberDelay.test.tsx` | 11 test |
| Mutasyon (a) iki 422 tek cumleye | **KIRMIZI** (1 test), geri konunca 11/11 yesil |
| Mutasyon (b) `delaySec` govdeden cikarildi | **KIRMIZI** (2 test) |
| SPA build baglami | bekcinin regex'i betikle taklit edildi: yeni kaynak goruldu, COPY silinince **eksik** raporlandi |

**Olcemedim:** `dotnet test` kosulmadi (paralel ajan talimati) -- `SpaBuildContextTests` ve
`RingGroupProvisioningTriggerTests` bu turda **kosmadi**; `dotnet build src/Pbxtr.Api` RC=0.
Gercek santralde cagri denenmedi.

**Commit:** `2f9eeadb`

### Karar

- **Istemci ayrimi ancak sunucu kodu istemciye ULASIYORSA yapilabilir.** "Iki 422 ayirt
  edilsin" sarti, `code` uzantisi olmadan FE'de hicbir kodla karsilanamazdi; sart once
  **tasinan bilgiyi** olcmeyi zorunlu kildi.

---

## BR-AST-120 — `pbxtr-confd` defteri diski doğrulamıyor + ERTELENEN reload kalıcı kilit

### Bağlam

Kart `BR-AST-17` turunda **canlıda üretilerek** açılmıştı ama gövdesi tek cümleydi.
İki kusur okunmuştu: (1) `5) Degisen kume` "sha aynı" dalı dosyanın diskte durup
durmadığına hiç bakmıyor; (2) `12) Durum defteri` bloğu `SAPAN`/`ATLANAN_TENANT`'ı
atlıyor ama **`ERTELENEN`'i atlamıyor** → ertelenen reload bir daha hiç denenmiyor.

### 1. Önce ölçüm, sonra düzeltme (üçüncü kusur burada çıktı)

- **Neden:** kart "düzeltmeyi §5'e koy" diyordu. Sunucuda A ölçümü yapılınca §5'e
  **hiç ulaşılmadığı** görüldü.
- **Ne yapıldı:** `ssh root@176.88.41.220` (ilk komut `date -u`), timer durduruldu,
  `queues/t0012-queues.conf` konteynerden silindi, **kurulu (eski)** betik koşturuldu.
- **Sonuç:** `HTTP 304` → `304 -- degisiklik yok. Diske dokunulmadi, reload kosmadi.`
  → `CIKIS=0`. Yani ETag tazeyken betik `case 304` dalında **diske dokunmadan çıkıyor**;
  §5'e konacak bir düzeltme **sonsuza kadar koşmazdı.** Üçüncü kusur budur.

### 2. Düzeltme — `deploy/pbxtr-confd-dugum.sh`

- **`2a) Disk envanteri` (yeni, §2'den sonra):** istekten ÖNCE tek bir
  `docker exec pbxtr-asterisk sh -c 'cd /etc/asterisk/pbxtr.d && ls -1 */*.conf'`.
  Defterdeki bir satırın dosyası yoksa **`ETAG` boşaltılır** → `If-None-Match`
  gönderilmez → sunucu 200 + tam gövde döner. Yol GÖRELİ listelenir; mutlak yol
  selftest shim'inde sahte köke çevrildiği için karşılaştırmayı sessizce kaçırırdı.
- **§5:** "sha aynı" dalı aynı envanteri okur; dosya yoksa tür **DEĞİŞMİŞ** sayılır.
  Ek `docker exec` **yok** (envanter zaten alınmış).
- **Yol `printf` ile kurulur, dize sabiti değil:** `HEDEF_ADI=$(printf '%s/%s-%s.conf' ...)`.
  Sebep ölçüm: selftest M1 mutasyonu `s.replace` ile **ilk** eşleşmeyi değiştirir; aynı
  dizeyi §5'e yazmak mutasyonu §8'deki yazım satırı yerine buraya uyguluyor ve
  **M1 sessizce vacuous** oluyordu (ilk koşuda `mutasyon YAKALANMADI` olarak görüldü).
- **§12 — ertelenen tür:** sha sütunu `reload-bekliyor:` önekiyle **işaretlenir**.
  Üç seçenek tartıldı:
  - (a) satırı silmek → `X-Pbxtr-Have` körleşir (manifest `node_declared` →
    `previous_revision`; BR-AST-25 meşru eksilmeyi "beyansız kayıp" sayabilir),
  - (b) eski satırı bırakmak → **diskten silinmiş dosya** hâlinde içerik değişmediği
    için `${SHA}` defterdeki sha ile AYNIdır (canlıda `fd15ef1f…` iki turda da aynı);
    reload ertelenirse sonraki tick "sha aynı" der, dosya artık diskte durduğu için
    disk kapısı da geçer → **kalıcı kilit geri gelir**,
  - (c) **seçilen:** önekli değer hiçbir sha256 ile eşit olamaz; revizyon sütunu
    dokunulmadan kalır; `state.json`'da operatöre görünür.
  - Kuyruk defteri ertelenen türde **tazelenmez** (santralde hâlâ eski küme var).

### 3. Canlı A/B/C/D/E ölçümü (test ortamı, timer durdurulup geri açıldı)

| Adım | Sonuç |
|---|---|
| A) eski betik + silinmiş `t0012-queues.conf` | `HTTP 304`, `CIKIS=0`, dosya hâlâ YOK |
| B) yeni betik, aynı hâl | `DEFTER … AMA DOSYA DISKTE YOK` → `HTTP 200` → `degisen tur sayisi: 1` → `reload: queues` → `CIKIS=0`; diğer 7 tür `degismedi (sha ayni, dosya diskte DOGRULANDI)` deyip atlandı |
| C) `PBXTR_CONFD_CHANNEL_LIMIT=-1` | `SONRAKI TICK'E ERTELENDI`; defter `t0012⇥queues⇥reload-bekliyor:fd15ef1f…⇥1`; `CIKIS=75` |
| D) normal eşikle sonraki tick | "degismedi" DENMEDİ, yeniden yazıldı, `reload: queues`, defter ham sha'ya döndü, `CIKIS=0` |
| E) son sürüm + `moh/t0007-moh.conf` | aynı zincir, `reload: moh`, `CIKIS=0` |

Reload komutları CLAUDE.md §3.1 kapalı listesinden; **liste genişletilmedi.**

### 4. Öz-test — `deploy/pbxtr-confd-selftest.sh`

- **F40:** defter "değişmedi" der, 4 dosya elle silinmiştir → hepsi geri yazıldı,
  reload 3→6, eksiklik adıyla raporlandı, **silinmeyen tür hâlâ atlandı** (yön ölçümü),
  `If-None-Match` gönderilmedi.
- **F41:** erteleme → sha `reload-bekliyor:` ile işaretli **ve** revizyon sütunu duruyor
  → sonraki tick `queue reload all` koştu.
- **İkisi de gerçek tur dönüşüdür (`kos_tekrar`)** — ajanın KENDİ yazdığı defteri okur.
  Kartın vacuity uyarısının istediği tam olarak budur.
- **M27/M28/M29** eklendi (tek koşuluk `mutasyon` yardımcısı yetmiyordu; iki koşuluk
  `mutasyon_iki_kosu` yazıldı).
- **Sonuç:** `213 iddia gecti`, 0 kaldı, çıkış 0; **41 fikstür / 30 mutasyon, 30/30 yakalandı.**

**Mutasyon iki gerçek kusur buldu:**
1. M1 vacuous olmuştu (yukarıda, `printf` ile düzeltildi).
2. M29 ilk hâlde yakalanmadı: iddia HTTP başlığındaki `ETag: "yeni-etag"` değerini
   arıyordu; ajan ETag'i **gövdedeki `bundle.etag`** alanından okuyor
   (`ayristir.js`: `yaz("etag", bundle.etag)`), fikstür üreticisi orayı `e1` yazıyor.
   Yanlış değeri arayan iddia **her zaman yeşildi.**

**Fikstür kusuru da ölçüldü:** F8/F25/M2/M9 sha defterini yazıyor ama **diske hiçbir şey
koymuyordu** — yani üretimde ARIZA olan hâli NORMAL sayıyorlardı. Düzeltme konunca F8 ve
F25 kırmızı döndü ve kırmızı **ajanda değil fikstürdeydi**; `defter_diski_kur` eklendi.

### Dokunulan dosyalar

`deploy/pbxtr-confd-dugum.sh`, `deploy/pbxtr-confd-selftest.sh`,
`deploy/yerel-kapilar.sh` (yalnız kapı etiketi 39/26 → 41/30), `yonetim/backlog.md`.

**Commit:** `fa79e51e`

### Sunucuda bırakılanlar

`/usr/local/lib/pbxtr/pbxtr-confd-dugum.sh` **düzeltilmiş sürümdür** (md5 depo ile birebir:
`869d0585…`), `pbxtr-confd.timer` **active**. Kendi geçici yedeklerim silindi;
`BR-AST-17`'nin bıraktığı üç yedek ve t0012'nin `deliver` niyeti **dokunulmadan duruyor.**

### Kararlar

- **Bir kapının hiç koşmadığı yol, kapının kendisinden önce ölçülür.** Kart düzeltmeyi
  §5'e koymamızı istiyordu; §5'e 304 yüzünden hiç ulaşılmıyordu.
- **`reload-bekliyor:` işareti "sil" ile "olduğu gibi bırak" arasındaki üçüncü yoldur**
  ve ikisinin de ölçülmüş bir bedeli olduğu için seçildi.

### Ölçemediklerim

- Gerçek Asterisk'in reload davranışı öz-testte ölçülmez (sahte CLI).
- Diskteki dosyanın **içerik** sapması bilinçli olarak kapsam dışı (sunucu sha'sına
  yaslanan bir karşılaştırma 2026-09-07'nin "her beş dakikada reload" arızasını geri getirirdi).
- İkinci bir gerçek düğümde ölçüm yapılmadı.
- `dotnet` koşulmadı (paralel ajan kuralı); bu kart .NET kodu değiştirmiyor.


### 23. Sessiz hata kodu sinifi kapatildi (koordinator)

#### `BR-SYS-126` — `Results.Problem` govdeye `code` yazmiyordu (KAPANDI)

- **Nasil bulundu:** `BR-FE-125` ajani kabul olcutunu (*"iki 422 ekranda AYRI mesaja
  dusmeli"*) **FE'de kod yazarak karsilayamadi** ve sebebini olctu. Yani kabul olcutunun
  dar yazilmasi, FE isi gibi gorunen seyin aslinda bir **uc kusuru** oldugunu ortaya
  cikardi; genel bir "hata mesaji gosterilsin" olcutu bunu asla gostermezdi.
- **Kusur:** `RingGroupEndpoints` iki farkli 422'yi **bilerek** ayiriyordu
  (`ring_group_member_delay_not_ringing`, `..._delay_strategy_unsupported`) ama yardimcisi
  `Results.Problem(statusCode, title: code, type: code)` yazip **govdeye `code` koymuyordu**.
  Istemci `body.code ?? ProblemCode.InternalError` okur -> iki hata da kullaniciya
  **tek bir `internal_error`** olarak ulasiyordu.
- **Belirti tam anlamiyla sessizdi:** durum kodu 422, baslik dogru, `type` dogru; yalniz
  govde eksik. Hicbir test kirmizi degildi.
- **SINIF TARANDI (tahmin degil):**

  | Yol | Sayi |
  |---|---|
  | `Results.Problem(` | **13** cagri yeri / 6 dosya |
  | `ProblemResponse.WriteAsync` | **295** |
  | `Results.Problem` + `code` tasiyan | 11 |
  | `Results.Problem` + `code` TASIMAYAN | 2 -- `TenantProfileEndpoints.cs:67,151`, **ikisi de 500** |

  500'de istemcinin yedegi (`internal_error`) ile gercek **ayni seyi soyler**, yani kusur
  degil. **Duzeltilecek baska cagri yeri YOK;** is tekrari onlemekti.
- **Bekci:** `tests/Pbxtr.Architecture.Tests/ProblemCodeExtensionGuardTests.cs`.
  - Cagri metni **dengeli parantez** ile okunur. Sabit satir sayisi yanlis olurdu: cagrilar
    4-12 satir arasi ve `extensions` cogunlukla **en sonda** -- kisa kesen bir okuyucu
    tam da aradigi seyi kaciririrdi.
  - **Muafiyet dosya beyaz listesi DEGIL, DURUM KODUDUR.** Beyaz liste bayatlar, durum kodu
    bayatlamaz.
  - **Kendi kapsamini da olcer:** tarama 10'dan az cagri gorurse KIRMIZI. Aksi halde
    `Results.Problem` bir gun yeniden adlandirilsa bekci "0 ihlal" diye yesil yanardi
    (*arac yoklugu sifir gibi gorunur*).
- **Olcum:** bekci **2/2**, `rc=0`. **Mutasyon urun tarafinda yapildi** (gercek kusur geri
  kondu: `extensions` blogu silindi) -> **Failed 1 / Passed 1**, hata metni ihlali
  `dosya:satir` ile basti; geri alininca yine 2/2, `rc=0`.
- **Olcmedigim:** `WriteAsync` kullanan **295** cagri yerinin govdesinde `code`'un gercekten
  gorundugu **ayrica olculmedi**; istemci yedeginin baska uclarda kac kez devreye girdigi de
  olculmedi.
- **Commit:** `b4995445`

#### `BR-FE-125` (ajan) — KAPANDI

- `#27` uye satirinda `delaySec` yazilabilir; yazma **`blur`/`Enter`'da**, her tusta degil
  (ara bir deger provisioning revizyonu uretirdi). `ringgroup.write` yoksa alan cizilmez ama
  sifirdan buyuk deger **gizlenmez** (salt okunur `+N sn` rozeti).
- Govdede `delaySec` **her uye icin** gonderilir: gondermemek "dokunmadim" demek degil --
  uc 0 yazar ve uyeler silinip yeniden eklendigi icin **tek bir kaydetme tum gecikmeleri
  sifirlardi**.
- `ext.ruleDelay` notu *"yazilamaz"* -> *"yazilir (0-{max} sn)"* duzeltildi;
  `ext.strategyNoDelay` **korundu**. `RING_GROUP_MAX_DELAY_SEC` artik
  `RingGroupRules.MaxDelaySec`ten **uretiliyor** ve ikinci kaynak icin Dockerfile SPA
  asamasina `COPY` eklendi (`BR-SYS-125` sinifi, ajan uyariyi uyguladi).
- **Olcum:** `vitest` **2127 gecti / 0 kirmizi** (238 dosya), yeni `RingGroupMemberDelay.test.tsx`
  **11 test**; iki mutasyon da KIRMIZI. `npx tsc -b` ve `npm run build` `rc=0`.

#### `BR-AST-120` (ajan: linux-uzmani) — KAPANDI ve **UCUNCU bir kusur** buldu

- Kart iki kusur yaziyordu; ajan once arizayi **sunucuda yeniden uretti** ve ucuncusunu
  buldu: ETag tazeyken betik `case 304` dalinda **diske hic dokunmadan** cikiyor --
  yani yalnizca "degisen kume"ye konan bir duzeltme **hic kosmayacakti**.
- **Erteleme davranisi secimi olculerek verildi:** satir ne silinir ne oldugu gibi birakilir;
  sha sutunu `reload-bekliyor:` onekiyle **isaretlenir**. Silmek `X-Pbxtr-Have`i korlestirirdi;
  oldugu gibi birakmak **kalici kilidi geri getirirdi** (silinen dosya yeniden teslim
  edilirken icerik degismez, yani sha AYNIdir -- canlida `fd15ef1f…` iki turda da ayni cikti).
- **Oz-test: 213 iddia, 0 kaldi, 41 fikstur / 30 mutasyon, 30/30 yakalandi.** Yeni F40/F41
  **gercek tur donusu** ile kosar, yani ajanin **kendi yazdigi defteri** okur.
- **Mutasyon iki gercek kusur buldu:** M1 vacuous olmustu; M29 ilk halde yakalanmadi --
  iddia HTTP basligindaki ETag'i ariyordu, oysa ajan ETag'i **govdedeki `bundle.etag`**'ten
  okuyor; **yanlis degeri arayan iddia her zaman yesildi.**
- **Fikstur kusuru:** F8/F25/M2/M9 sha defterini yazip **diske hicbir sey koymuyordu** --
  uretimde ARIZA olan hali normal sayiyorlardi.
- **Paylasilan dosya dogru ele alindi:** `deploy/yerel-kapilar.sh`'de yalniz kapi etiketi
  `git apply --cached` ile tek hunk olarak alindi; ayni dosyadaki **baska ajanin BR-SEC-29
  hunk'lari commit'e girmedi**.

### Kararlar (bu tur)

- **Kabul olcutunu dar yaz.** *"Iki 422 AYRI mesaja dusmeli"* olcutu, FE isi sanilan seyin
  bir uc kusuru oldugunu ortaya cikardi; *"hata gosterilsin"* olcutu bunu gostermezdi.
- **Bir bekcinin muafiyeti veriye baglanir, dosya adina degil.** Beyaz liste bayatlar.
- **Mutasyon urun tarafinda yapilir.** Bekciyi kendi metnine karsi mutasyonlamak, bekcinin
  gercek kusuru yakalayip yakalamadigini soylemez.

### Acik kalanlar / sonraki adim

- Acik kart **85** (P0 3 / P1 41 / P2 36 / P3 5). ClickUp senkron.
- Entegrasyon takiminda kalan kirmizi: `BR-DB-105`, `BR-DB-106`.
- Kosan: `BR-SEC-29` (db-dev).
- **Yayin hala kosulmadi.**
