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
