# pbxtr — 2026-09-12

## Bağlam

Dün (2026-09-11) sprint-44 Blok 0 production'a indi: `transport-ws` canlıda açıldı,
`maxfiles = 32768` / `maxcalls = 150` host'a yazıldı, rollback provası 20 sn ile ayırt edici
çıktı. Kullanıcının bağlayıcı emri bugün de geçerli:

> *"canlidan hicbir onay alma ben test edecegim sana soyleyecegim zaten. onay almadan kalan tum
> maddeleri bitir."*

Yani bugünün kuralı: **canlı sunucuya dokunulmaz, kullanıcıya soru sorulmaz; karar gereken her
şey kurula gider.** Gün, sprint-44'ün `AST-53-b`'yi kilitleyen tek karar maddesiyle açıldı.

## Yapılanlar

### 1. Karar #45 — `AST-53-x`: yerel bağlama giren **dış** çağrıda DND ve otomatik cevaplama

- **Neden:** sprint-44 satırı birebir şöyleydi: *"Karar yazılı; **çıkmadan AST-53-b
  birleştirilmez**"*. Yani tek bir kurul kararı, sprintin en büyük kod bloğunu tutuyordu.
  Ve karar kullanıcıya değil kurula ait (defter: *"kararı kullanıcıya değil kurula sor"*).
- **Ne yapıldı:** 10 üye paralel toplandı. Her üyeye **ölçülmüş** bağlam verildi
  (`ConfigRenderer.cs:745-762` DND `Busy(20)`, `:1477` `DialAutoAnswer`, granülarite farkı:
  `Dnd` dahili başına ama `AutoAnswer` tenant genelinde) ve dört seçenek soruldu:
  (A) kaynağa göre ayır · (B) aynen kalsın · (C) DND dışta da geçerli + otomatik cevaplama
  yalnız dahilide · (D) tenant parametresi.
- **Sonuç: (C′) ŞARTLI ONAY, 10/10 ŞARTLI, 18 şart, 5 kart doğdu.**

**Ama asıl olay oylamanın sonucu değil, oylamanın SORUYU ÇÜRÜTMESİ oldu.**

#### Ö1 — sorunun öncülü yanlıştı

Şeytan buldu, CTO ve Asterisk uzmanı **bağımsız olarak** doğruladı:

```
AsteriskObjectName.MemberEndpoint (:489-490)
  -> Local/{no}@pbxtr-{kod}-local/n
```

Kuyruk üyeliği **zaten** `-local`'a gidiyor ve kuyruk çağrılarının ezici çoğunluğu **dıştan**
gelir. Yani DND `Busy(20)` ve `b(...autoanswer)` **bugün de dış çağrılara uygulanıyor** —
kimse bunu seçmedi, `MemberEndpoint` biçiminin yan ürünü olarak oldu.

Doğru soru *"dış çağrıda ne olsun"* değil, **"bugün olan doğru mu"**ydu. Karar metni bu hâliyle
yeniden yazıldı. Bu, `A-5`'in üç tur yanlış eksende sorulmasıyla **aynı desen** ve Şeytan bunu
açıkça o desene bağladı.

#### Ö2 — `__PBXTR_DIR` hiçbir yerde tüketilmiyor (ben ölçtüm)

| | Bulgu |
|---|---|
| Üretim | `ConfigRenderer.cs:659` — **tek** satır, koşulsuz `Set(__PBXTR_DIR=int)` |
| Tüketim | `src/Pbxtr.Infrastructure/Telephony/` altında `PBXTR_DIR` → **0 isabet** |
| `AmiEventMapper` okuduğu değişkenler | yalnız `PBXTR_ORIGIN` (`:53`), `QUEUE_PRIO` (`:55`) |
| Yön kaynağı | `TelephonyEventPipeline.cs:760` `DirectionOf(direction)`, payload'dan |
| `DirectionOf` (`:1415-1421`) | `"inbound"`/`"outbound"`/**`"internal"`**, `_ =>` **`Inbound`** |

İki ayrı sonuç çıktı ve ikincisi daha kötü:

1. Dialplan **`int`** yazıyor, sözlük **`internal`** bekliyor — **bağlansaydı bile eşleşmez**,
   `_ =>` dalından `Inbound` dönerdi.
2. Gerçek AMI yolunda yön **hiç üretilmiyor** → **bugün her çağrı `Inbound` yazılıyor, dahili
   dâhil.**

Yani Karar #42'nin BLOKLAYICI `Ş42-10` şartı — *"dış çağrı `call_events`'e `int` yazamaz"* —
**hiç var olmayan bir değeri koruyordu**: klasik vacuous bekçi. `Ş42-10` yürürlükten kaldırıldı,
yerine `Ş45-2` (yön damgası `-local`'den çıkar, giriş bağlamlarına taşınır) geçti ve gerçek kusur
`BR-AST-67` olarak kartlaştırıldı.

#### Seçilen (C′) ve iki düzeltme

- **Eksen "dahili/dış" değil, "pbxtr dağıtımı ↔ ham giriş"**. *"Yalnız dahili"* literal alınsaydı
  otomatik cevaplamayı **bugün üretimde çalıştığı tek senaryoda** (kuyruk dağıtımı) kapatırdı —
  yani davranış eklemek yerine mevcut davranışı geri alıp bunu "yeni ayrım" diye sunardı.
- **DND `Busy(20)` kalır.** Süpervizörün *"zincirde atla"* talebi reddedildi (taşma tek hedeflidir,
  atlanacak ikinci hedef yok) ama asıl itirazı — *"çağrı orada mühürleniyor ve hiçbir yerde
  sayılmıyor; `Busy` çalan çağrı terk oranına girmez, yani metrik arızayı ödüllendirir"* —
  kabul edildi: `${DIALSTATUS}` okunur, `UserEvent` ile sayılır, tanımlı bir terminale düşer.

**Elenenler:** (B) arayüzü **dokuz dilde** yalancı yapardı (`set.autoAnswerCheck` dokuz dilde
"Dahili çağrılarda" diyor). (A) `ext.ruleDnd`'yi dokuz dilde zayıflatmayı gerektirirdi.
(D) üretim seed'inde bu bayrakları açan **tek satır yok** (DB ve Backend liderleri ayrı ayrı
ölçtü); varsayılanı yine biz seçeceğiz ve o varsayılan (C′) — yani (D) bugün **adı değişmiş
(C′)**.

**Şeytan'ın 10 itirazının hepsi yazılı cevaplandı.** `Ş-Ş1`/`Ş-Ş2`/`Ş-Ş5`/`Ş-Ş7` kabul;
`Ş-Ş4` (ayrım iki ayrı `exten` olsun) **ölçülü gerekçeyle** reddedildi —
`AssertDistinctDialNumbers`'ın koruduğu tek çevirme alanı değişmezini yıkar ve ikinci bir
`-local` varyantı `MemberEndpoint` adını değiştirdiği için **her mevcut kuyruk üyeliğinin**
revoke+grant göçünü gerektirir. `Ş-Ş6` ise bir şart değil **karşılanmış bir şart**:
`maxfiles`/`maxcalls` dün canlıya yazıldı.

- **Dosyalar:** `yonetim/kurul-kararlari.md` (+284 satır), `yonetim/backlog.md`,
  `yonetim/sprintler/sprint-44.md`
- **Commit:** `73aeef97`

### 2. Doğan beş kart — ve üç kimlik çakışması

`BR-AST-61`, `BR-AST-62`, `BR-SEC-09` yazmak üzereydim; **üçü de doluydu**. Defterdeki
*"kart numarası önce ölçülür"* kuralı tam olarak bunu yakaladı. Ölçülen tavanlar:
AST 66, SEC 16, OPS 02, FE 74. Kaydırıldı:

| Kart | Ne |
|---|---|
| `BR-AST-67` (P1) | Ö2: yön hiç ölçülmüyor, `int` ≠ `internal`, bugün her çağrı `Inbound` |
| `BR-AST-68` (P2) | Zil grubu üyeleri DND'yi **hiç** dinlemiyor (`:1019`, `:1055`) — (C′) sonrası kalan tek çelişkili yüzey |
| `BR-OPS-03` (P2) | Kuyrukta oto-cevaplama açık kalıyor → rıza anonsu sırası + terk oranı paydası ölçülmedi |
| `BR-SEC-17` (P1) | `Dial(…,tT…)` — `T` **arayana** transfer yetkisi veriyor, dış arayan bugün de bu satırdan geçiyor; toll fraud yüzeyi ölçülmedi |
| `BR-FE-75` (P1) | DND canlı izlemede ve agent masasında **hiç yok**; panel "Müsait" derken santral `Busy` basıyor |

- **Commit:** `db1d4158` (ClickUp), `8ae56391` (`BR-QA-61`)

### 3. `S45-17` — `ext.ruleDnd` metni dokuz dilde dürüstleşti

Ö1 sayesinde bu iş **bugün** yapılabilir hâle geldi: davranış zaten dış çağrıları kesiyor, yani
cümle bugün de doğru. `frontend-junior`'a verildi.

- Kapsam ölçüldü: **9 dosya, 9 satır, tek anahtar** (`git diff -U0 | grep '^+  "'` → 9 kez ve
  yalnızca `ext.ruleDnd`). `set.autoAnswerCheck`/`Hint`'e dokunulmadı — o metinlerdeki "Dahili"
  kelimesi `Ş45-17` ile bilinçli olarak **taşıyıcı** ilan edildi.
- `python3 -m json.tool` 9/9; anahtar sayısı önce=sonra (9/9).
- **Commit:** `f94904eb`

### 4. `BR-QA-61` — homoglif kapısının evreni tek dosyaymış

Ajan `az.json`'da iki Kiril homoglifi buldu. Önce **eski mi yeni mi** diye ölçtüm
(`git show HEAD`): **ikisi de önceden vardı**. Sonra kapının neden görmediğini ölçtüm:

```
kapi_43 -> yonetim/arac/kart-atif-dogrula.js
  fs.readFileSync('yonetim/backlog.md')   // :44 ve :118 — TEK kaynak
```

Kapı **bozuk değil, dar** — ve darlığı hiçbir yerde yazılı değil.

Kartın ikinci ayağı birincisinden önemli: evreni genişletirken naif bir *"U+0400–04FF varsa
kırmızı"* kuralı **`bg.json`'u anında kırmızı yapar** (Bulgarca meşru olarak baştan sona Kiril,
179.041 karakter ölçüldü). Kural **dil-farkında** olmak zorunda; bu aynı zamanda ters yönü de
açar (Kiril metin içinde Latin homoglifi bugün **hiç** ölçülmüyor).

### 5. `BE-30` — ADR-018, kartın üç öncülünden ikisi çürüdü

- *"`ContactStatus`/`PeerStatus` 0 isabet"* → **doğru**.
- *"`job_runs` tablosu yok"* → **yanlış**. `pbxtr_sys.job_runs` var ve üretimde kullanılıyor
  (`01-rls-template.sql:1402`, `LeaderElectedJobRunner.cs:255-257`, `SystemHealthProbe.cs:619`).
  `QueueMetricDeriver`'ın iz bırakmamasının sebebi tablonun yokluğu değil, **o koşucudan
  geçmemesi** (`AmiAriEventConsumer.cs:246` içinde yaşıyor). Bu, *"turun kanıtı ne olacak"*
  sorusunu ücretsiz çözdü.
- *"`pjsip show contacts` iki yere eklenmeli"* → **zaten iki yerde de var**; eksik olan yalnız
  `pjsip show transports`.
- **Commit:** `637acfdc`

### 6. `D-01`/`D-02` — şema yazıldı, **yeşil değil**, ve sebebi benim işim değil

`provisioning_secret_bindings` migration'ı yazıldı, gerçek PG16'da **7/7 davranış** ölçüldü
(mükerrer jeton `23505`, kapalı küme dışı `23514`, CRLF enjeksiyonu `23514`, çapraz-tenant
`23503`, CASCADE 0 kalan). `provisioning_revisions`'a **hiçbir kolon eklenmedi**.

Ama iki **önceden duran** kilit var:

- **B-1:** terminal migration kilidi (`BR-DB-34`) — yeni bir migration dosyası eklendiği an
  kırmızı, ve *"sabiti güncelle"* çıkışı aynı dosyadaki `Terminal_migration_DEVREDILEMEZ` ile
  kapalı. Testin kendi dokümantasyonu tek meşru çıkışı (A seçeneği) madde madde yazıyor.
- **B-3:** `MaintenanceRunner` `02-guards.sql`'i **uygulamıyor** (`:237-240` yalnız `Migrate()`
  + `GuardAsserts`). Eskiden bunu her seferinde bir migration yapıyordu; o yol
  `migration-compatibility-guard.py:47` ile kapandı. Yani `D-03`'ün fonksiyonu taze zincirde
  var, staging'de yok olur — defterdeki *"şablon gövdesi kurulu DB'ye ulaşmaz"* sınıfı.

Dosya diskte bırakılmadı; push edilmeyen iş kaybolmuş iştir. Commit mesajı yeşil olmadığını ve
neden olmadığını **açıkça** söylüyor.

- **Commit:** `8b79693b`

### 7. `LX-08` — santral imajı yayın yolunun bir adımı oldu; **iki eski kusur çıktı**

`LX-06`'da santral imajı dağıtıcıyla değil **elle compose** ile yayınlanmıştı, çünkü sunucudaki
**kurulu** dağıtıcı 26 Ağustos'ta kalmıştı. Bu turda yol kapatıldı: `--santral` ayrı kod yolu,
`staging-yayin.sh` asterisk dalını taşıyor, dağıtıcı kurulumu yayının **0. adımı** ve
kurulu↔depo sha kapısı `kapi_47` olarak bağlandı (46 → **47 kapı**).

**Kusur 1 — `pbxtr-artifact-validate-selftest.py` Windows'ta HEP kırmızıydı.** Fikstür
`write_text` ile checksum yazıyor, Windows `\n` → `\r\n` çeviriyor, doğrulayıcının katı
`re.fullmatch` deseni tutmuyor. Üretimde o dosyayı `sha256sum` yazar (LF) — yani **katılık
doğru, platforma bağımlı olan fikstürdü**. `newline="\n"` eklendi. Düzeltmenin kapıyı
**zayıflatmadığı** mutasyonla kanıtlandı: `fail(...)` → `pass` yapılınca öz-test kırmızı,
geri alınca yeşil.

**Kusur 2 — bir önceki LX-08 turu `BR-QA-38(a,b)` kapısını kırmızı bırakmıştı** ve bu ancak
**47 kapının tamamı** koşturulunca görüldü. Sebep: banner satırı

```
adim "1/7 Guvenlik kapilari ($(grep -c '^kapi \"' deploy/yerel-kapilar.sh) kapi)"
```

bash'te geçerli ama `deploy/ci/test-inventory-contract-test.py:20` bu betiği `shlex.split()`
ile ayrıştırıyor ve iç içe tırnak `No closing quotation` veriyor. Ölçüldü: kırık satır **1**,
`HEAD~6`'da **0** — yani kırmızı **yeniydi**. Sayım ayrı satıra (`KAPI_SAYISI`) alındı; dinamik
sayı korundu.

- **Commit:** `1a05eeac`

## Kararlar

- **Bir kurul oylaması, kararın kendisinden çok SORUYU düzeltebilir.** Bugün iki öncül çürüdü ve
  ikisi de karar metnini değiştirdi. Öncülü çürüyen bir soruya verilen oy, yanlış soruya verilmiş
  oydur — Şeytan bunu açıkça şart olarak yazdı (`Ş-Ş3`) ve haklıydı.
- **Bir BLOKLAYICI şart, hiç var olmayan bir değeri koruyor olabilir.** `Ş42-10` on gün boyunca
  bloklayıcıydı; ölçüm, koruduğu şeyin bugün mevcut olmadığını gösterdi. **Şart yazarken de
  "önce mevcut veriyi ölç" geçerli** — yalnızca bekçi yazarken değil.
- **Kimlik çakışması körü körüne yazarsan sessizdir.** Beş karttan **üçü** doluydu. Kimlik
  ölçümü her seferinde yapılmalı; "max + 1" yetmez (aradaki boşluklar dolu olabilir).
- **"Ajan yeşil dedi" bir ölçüm değildir.** LX-08 ajanı üç öz-testi konteynerde koşturup yeşil
  dedi; ben host'ta koşturunca biri kırmızı çıktı ve **eski bir kusur** olduğu anlaşıldı. Ayrıca
  47 kapının tamamını koşturmadan görülmeyen ikinci bir kırmızı vardı.
- **Kapılar kendi konteynerinde koşulmalı.** Windows host'ta ~10 kapı "araç yok" der ve bu bir
  **bulgu değil ölçüm kaybıdır** (`yerel-yayin.sh:245-258` bunu zaten yazıyor). İlk denememde
  ayrıca kendi koyduğum `timeout 300` koşuyu kesti ve `RC=124` verdi — o da bir sonuç değil,
  ölçüm kaybıydı.
- **Commit mesajında yazdığım "47/47" iddiası yanlıştı ve düzeltildi.** Tam koşu düzeltmeden
  **önceydi** ve 46/47'ydi; düzeltme sonrası yalnız tek testi koşmuştum. Defterdeki *"yeşil takım
  hangi commit'i kapsıyor"* maddesi birebir bu: **"takım yeşil" bir tarih iddiasıdır.**
- **Heredoc backslash çiftlerini yiyor — ikinci kez ısırdı.** `sed`/python yaması çıpayı
  tutturamadı; mutasyonun uygulandığını ayrıca ölçtüğüm için yakalandı. Bu tür düzenlemeler
  `Edit` ile yapılmalı.

## Açık kalanlar / sonraki adım

- **`backend-dev-1` hâlâ koşuyor** (`BE-15` WebRTC üretim bekçisi + `AST-53-e` mimari bekçi);
  .NET yuvasını o tutuyor. Bitince Blok 2 (`BE-02`…`BE-09`) açılıyor.
- **`D-01` için P-0 kararı gerekiyor:** terminal migration bataryasının A seçeneğiyle
  taşınması. Testin kendi dokümantasyonu yolu yazmış ve maliyetinin ödendiğini söylüyor;
  ama bu bir bekçi taşıma işlemi ve ölçülerek yapılmalı.
- **`Ş45-7` kullanıcının kendi testinde:** (a) dahili, (b) kuyruk (`Call-Info` başlığının
  telefona **fiilen** ulaştığı `pjsip set logger on` ile), (c) taşma. Ayrıca `__PBXTR_AA_OK`'in
  `Dial(Local/…/n)` sınırından **kalıtıldığı** ölçülmeli — tüm tasarım bu varsayıma dayanıyor ve
  depoda hiçbir yerde ölçülmemiş.
- **Canlıda 0 zil grubu var**, yani `Ş45-7`(c) ancak kullanıcı bir zil grubu + taşma hedefi
  tanımladıktan sonra ölçülebilir.
- `LX-08`'in 4b santral dalı, dağıtıcı kurulumu ve gölgeleme raporu **gerçek sunucuda henüz
  koşmadı**; ilk koşu izlenerek yapılmalı.
