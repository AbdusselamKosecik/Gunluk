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
