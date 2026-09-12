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

---

## Günün ikinci yarısı — Blok 2, Blok 4 ve ana dalın kırmızıya düşüp geri dönmesi

### 8. Ana dal KIRMIZIYA DÜŞTÜ ve sebebi benim commit'imdi

Sabah `D-01` migration'ını *"yeşil değil"* diye **dürüstçe** commit'lemiştim (`8b79693b`). O commit
zincirin sonuncusu olunca iki mimari test kırıldı (`456/458`):

```
MigrationAssertionSeparationTests.Iddia_migrationi_zincirin_SONUNCUSU_olmali   [FAIL]
GuardAssertSingleSourceTests.Terminal_migration_listesi_tek_kaynakla_AYNI_olmali [FAIL]
```

**Ders: dürüst bir commit mesajı yazmak kırmızıyı meşru yapmıyor.** Mesaj "neden yeşil değil"i
doğru anlatıyordu ama yayın kapısı o gün fiilen kapalıydı.

**Çıkış:** A seçeneği — iddia bataryasını migration zincirinden tamamen çıkarmak. Devir yolu
`Terminal_migration_DEVREDILEMEZ` ile zaten kapalıydı ve gerekçesi ölçülmüş: *17 günde 32 ayrı
dosya sırayla terminal ilan edilmiş, sabit 37 kez değişmiş, bunun 31'i devir.* Kural kendi
ihlalini üretiyordu.

**Bekçi kaldırmadığımı UYGULAMADAN ÖNCE ölçtüm** — batarya iki yolda da duruyor:

| Yol | Kanıt |
|---|---|
| Üretim/açılış | `MaintenanceRunner.cs:237` `MigrateDatabase` → `:238` `RunGuardAssertsAsync` → `:299` `foreach (GuardAsserts)` — **her `migrate`'te 27/27** |
| DB kapısı | `ci-check.sh:258-281` listeyi `MaintenanceRunner.GuardAsserts`'ten **türetiyor**, `DERIVED_COUNT < 25` → fail |

Kalkan yalnızca migration içindeki **kopya**.

### 9. `db-dev` bir mutasyonun yakalanmadığını buldu ve DURDU — doğru davranış

Silinen `Terminal_migration_listesi_tek_kaynakla_AYNI_olmali` **küme eşitliği** ölçüyordu, yani
`GuardAsserts`'ten **herhangi** bir adın silinmesini yakalıyordu. Kaybolunca 27 adın **dördü**
korumasız kaldı (`ci-check.sh`'te elle de çağrılmayanlar), çünkü `DERIVED_COUNT ≥ 25` eşiği iki
adlık silmeye izin veriyordu.

**Kapatma biçimi:** `ci-check.sh`'e **şema taraflı ters yön** adımı — `pg_proc`'ta tanımlı her
`pbxtr_assert_*` fonksiyonu tek kaynakta da olmak zorunda. **İkinci bir elle liste yazılmadı;
ikinci kaynak şemanın kendisi**, yani kopya yok. Eşiği 25→27 çekmek çözüm değildi: yeni bekçi
eklenince aynı devretme döngüsü doğardı.

Gerçek PostgreSQL'e karşı: temiz → **TÜM KAPILAR YEŞİL** + *"semadaki 27 bekcinin tamami tek
kaynakta"*; mutasyon (eskiden **kaçan** ad silindi) → `::error::` ve **RC=1**; geri alma temiz.
Architecture **454/454** — düşüş tam 4, silinen `[Fact]` sayısıyla birebir.

### 10. Blok 2 (`BE-02`→`BE-09` + `D-05`) — kartlarda yazmayan üç şey koşarken çıktı

1. **`MaterializeAsync` transaction'sız koşunca TÜM düğüm paketi düşüyordu** (her tenant
   `render_failed`). Uç `SelfManagedTransaction`, `GetBundleAsync` kendi transaction'ını **commit
   ederek** dönüyor, sonraki okuma `TenantSessionInterceptor`'a takılıyor. **Yalnızca gerçek
   PostgreSQL'e karşı görünür** — fikstür seviyesinde yeşil kalırdı.
2. Bileşik FK EF modelinden çıkarıldı, **kısıt veritabanında duruyor** (asıl kapı o). Migration'a
   dokunulmadı.
3. `PciScopeGuardTests` **"Collect" alt dizesi** arıyor; `SecretBindingCollector` adı kapıyı
   kırmızı yaptı. Kapı **gevşetilmedi**, ad değişti → `BR-QA-62`.

**İki yayın uyarısı, ikisi de ölçülü ve biri sprintin kendi öncülünü doğruluyor:** mevcut
revizyonların bağ satırı yok (bir render tetiklenmeden düzelmez) ve `extension.desk` her zaman
`secret_not_stored` dönüyor; kesme birimi dosya olduğu için **`pjsip` yine withheld kalıyor**.
Yani WebRTC yarısı tek başına canlı semptomu **kapatmıyor**.

### 11. Blok 4 backend — ve "yeşil yalan"ın bir kat yukarıdaki aynısı

`BE-20`/`BE-21`/`BE-22` indi. `BE-22`'nin öncülünün bir parçası **bayattı** (`#680 → #57` zaten
`176bfe64` ile kapanmış) ama asıl öncül doğrulandı ve mekanizması ölçüldü.

**Asıl olay:** ajan kendi raporunda *"yazma yolu uçtan uca ölçülmedi, bu iki satır bugün vacuous
koşuyor olabilir"* dedi. Ölçtüm, **doğruydu**:

```
grep -rn "IProvisioningDeliveryObservations" tests/
  -> TEK isabet: ProvisioningWithheldHealthTests.cs:186   (OKUMA tarafi)
```

Gözlemi **yazan** iki satır hiçbir testte koşmuyordu. Yani `BE-22`'nin kapattığı yeşil yalanın
**bir kat yukarıdaki aynısı**: o satırlar yanlış tenant yazsa ya da hiç çağrılmasa sağlık sonsuza
dek `Ok` derdi.

Kapatıldı ve **mutasyonla ayrıştırdığı kanıtlandı**:

| Mutasyon | Sonuç |
|---|---|
| A — düğüm paketi ucunda `NoteAsync` dalı kapatıldı | **tam 1** kırmızı |
| B — Mod A ucunda `NoteAsync` dalı kapatıldı | **tam 2** kırmızı |
| geri alma | kalıntı 0, temiz koşu **4/4** |

### 12. İki ortam tuzağı, ikisi de "yeşil görünen ölçüm kaybı"

- **`Skipped` yeşil değildir.** İlk koşumda 4 test **atlandı**; sebep Docker Desktop daemon'ının
  düşmesiydi (oturum boyunca konteyner koşturmuştum). `RequiresDockerFact` sessizce atlıyor.
  `PBXTR_REQUIRE_DOCKER_TESTS=1` ile zorlandı, Docker yeniden başlatıldı ve ölçüm **gerçekten**
  yapıldı. Bu bayrağın varlığı deponun bu dersi daha önce de aldığını gösteriyor.
- **`bin` bozuk olabilir ve build yine "0 Error" der.** Kesilen bir koşu
  `Pbxtr.Integration.Tests/bin` içindeki `Pbxtr.Domain.dll`'i yüklenemez bırakmıştı; xunit
  **keşifte** patlıyor ve `dotnet test` *"No test matches"* diyordu. `bin`+`obj` silinip yeniden
  derlendi → keşfedilen test **0 → 736**.

## Kararlar (ek)

- **Kırmızıyı dürüstçe belgelemek, kırmızıyı kapatmak değildir.** Bir commit'in mesajı ne kadar
  doğru olursa olsun, ana dalı kırmızı bırakıyorsa iş yarımdır.
- **Bir bekçiyi kaldırmadan önce, koruduğu şeyin başka nerede koşduğunu ÖLÇ.** Bu turda iki yolu
  da ölçtüm ve ancak ondan sonra uyguladım; ölçmeseydim 27 bekçilik bir bataryayı körü körüne
  taşımış olacaktım.
- **Silinen bir bekçinin bıraktığı boşluk, silme anında ödenmeli.** `db-dev` dört adın korumasız
  kaldığını buldu ve bunu **gizlemedi**; bedeli aynı turda ödendi.
- **"Ajan yeşil dedi" bir ölçüm değildir — ama "ajan boşluk bildirdi" çok değerlidir.** Bugün iki
  ajan da kendi işlerindeki deliği kendileri raporladı ve ikisi de gerçekti.
- **Ortam kaynaklı yeşil/atlama, kod kaynaklı olandan daha sinsi.** `Skipped 4` ve
  *"No test matches"* çıktılarının ikisi de `RC=0` ya da "0 Error" ile birlikte geldi.

---

## Günün üçüncü yarısı — OPS-01 "koşan" hâle geldi, homoglif kapısının evreni açıldı

### 13. `OPS-01` artık üretimde bir şey yapıyor

Sabahki commit (`92b12017`) kendi kendine dürüst bir uyarı taşıyordu:

> *"OPS-01 BUGÜN ÜRETİMDE HİÇBİR ŞEY YAPMAZ: tablo yok, iş yok, uç yok, çağıran yok."*

`SilenceMetric` çağıranı olmayan bir kütüphaneydi — defterdeki **"kod var, koşan yok"** sınıfı.
Bu turda üçü de indi.

- **Neden:** `OPS-01-a`'nın kabul kriteri *"çapraz-tenant hedef imkânsız"*dı ve **karşılanmıyordu**;
  `OPS-01-d`'nin `400`'ü hiç ölçülmemişti.
- **Ne yapıldı:**
  - **Migration** `20260912162924_SilenceThresholds` — üç hedef kolonunun üçü de **bileşik FK**
    (`(tenant_id, queue_id) → queues(tenant_id, id)` ve zil grubu/DID için aynısı). `dids` için
    gereken `ak_dids_tenant_id` aynı adımda açıldı.
  - RLS **elle yazılmadı**: `SELECT pbxtr_apply_tenant_rls(...)`. **Bayi scope'u verilmedi.**
  - `last_open_minutes` **NULLABLE, `DEFAULT 0` yok** → *null = ölçülemedi*, `0` değil.
  - **Örnekleyici** `SilenceSamplerJob`: `IBackgroundJob` + advisory lock 34, ayrı worker/cron yok.
    Akış canlılığı `pbxtr_sys.job_runs`'taki son *leader* satırından okunuyor; tolerans
    `3 × ReconcileEvery` ve bu sayı **tek yerden türetiliyor** — iki yerde yazılsaydı biri
    değişince öteki sessizce anlamsızlaşırdı.
  - **Uç** `/api/v1/silence/thresholds`, `Program.cs:948`'e **fiilen bağlı**. `1..1440` dışı → `400`,
    `Math.Clamp` **yok**. Ürün **seed etmez**; opt-in bedeli `enabledCount` olarak görünür (#26).
- **Komutlar:**
  ```bash
  dotnet build pbxtr.sln --no-incremental        # 0 Warning / 0 Error, PIPESTATUS[0]=0
  dotnet test tests/Pbxtr.Architecture.Tests/... # 454/454
  PBXTR_REQUIRE_DOCKER_TESTS=1 dotnet test tests/Pbxtr.Integration.Tests/... \
    --filter "...Silence...|...ReconcileTick...|...BackgroundJobLocks..."   # 12/12, Skipped 0
  dotnet test tests/Pbxtr.Api.Tests/... --filter "~SilenceThresholdEndpointTests"  # 18/18
  python3 deploy/migration-compatibility-guard.py  # OK
  ```
- **Sonuç / doğrulama:** yukarıdakilerin hepsi **ajan raporuna güvenilmeden** yeniden koşuldu.
- **Commit:** `1c918ba9`

#### Kendi koştuğum mutasyon — `OPS-01-d`'nin `400`'ü

Geçen bir test, bekçinin **taşıdığını** göstermez. Uçtaki `IsValid` kapısını etkisizleştirdim:

| Adım | Sonuç |
|---|---|
| çıpa `grep` önce/sonra | `1 → 0` (mutasyon **uygulandı**) |
| koşu | **tam 4 kırmızı** — `1441`, `10000`, `-5`, `0` |
| geri alma + **yeniden derleme** | 18/18 yeşil, kalıntı 0 |

`if (false)` **derlenmedi** (CS0162, uyarılar hata sayılıyor). Mutasyonu sabit olmayan ama
hep-yanlış bir koşulla yazmak gerekti — bu, bu depoda mutasyon yazarken tekrar edilecek bir not.

#### Ajanın kendi bulduğu iki kusur — ikisi de defterde zaten yazılı

1. **"Test ikizi üretimden müsamahakâr"** birebir tekrarladı: ilk e2e koşuda iş `processed = 0`
   dedi ve **hiç hata üretmedi**. Sebep: test DI'sinde `TransactionGuard`/`TenantSession`/
   `TenantStamp` yoktu → `app.tenant_id` GUC'u yazılmıyor → RLS fail-closed → 0 satır; ve işin
   *"bir tenant'ın hatası diğerlerini düşürmez"* `catch`'i onu **yutuyordu**.
2. **"Sahip rolü RLS bypass'ı değil"**: `ReadObservationAsync` owner bağlantısıyla GUC'suz okuyor
   ve 0 satır dönüyordu.

### 14. `BR-QA-61` — homoglif kapısı bozuk değildi, **dardı**

- **Neden:** kapı `yonetim/backlog.md`'den başka **hiçbir şeyi** taramıyordu ve bu darlık hiçbir
  yerde yazılı değildi. Buldukları kadarıyla "temiz" diyordu — bir ölçüm değil, bir yanıltma.
- **Ne yapıldı:** tarama `yonetim/arac/homoglif-tara.js`'ye taşındı, eski yerde **kopya
  bırakılmadı** (iki tarayıcı olsaydı biri gevşerken öteki yeşil kalırdı).
  Kural **kelime bazlı**: bir kelime hem Latin hem Kiril harf taşıyorsa kaçaktır.
  - **Dil-farkında:** kartın korktuğu `bg.json` seli **olmadı** (0 kaçak) — JSON anahtarları saf
    Latin, değerleri saf Kiril; kelime birimi eşik gerektirmeden ikisini ayırıyor.
  - **Çift yönlü:** Kiril kelime içindeki Latin `o` da görülüyor. O yön bugüne kadar **hiç**
    ölçülmemişti.
- **Kaçış farkındalığı zorunlu çıktı:** ilk geniş koşuda `bg.json` **üç sahte** kaçak verdi — JSON
  satır sonu kaçışının `n` harfi Kiril kelimeye yapışıyordu. Ayıklanmasaydı kapı **ilk günden hep
  kırmızı** olurdu.
- **Tarayıcı ilk koşuda kendini yakaladı:** 12 bulgunun 7'si kendi kaynağıydı. Dosyayı evrenden
  **muaf tutmadım** — muafiyet tam da kapatmaya çalıştığım kör noktayı geri açardı. Bunun yerine o
  dosyada Kiril harfler `String.fromCharCode` ile üretiliyor; karakter sınıfları da öyle, çünkü düz
  yazılmış bir aralığın iki ucu (`U+1EFF` + `U+0400`) bitişik durunca "karışık kelime" görünüyordu.
- **Bulunan gerçek kaçak: 5 — kart yalnız ikisini biliyordu.** Üç yenisi darlığın bedeli:

  | Dosya | Kelime | Kaçak |
  |---|---|---|
  | `deploy/pbxtr-confd-dugum.sh:16` | `dugume` | U+043C, U+0435 |
  | `az.json:1549` | `kova` | U+0430 *(biliniyordu)* |
  | `az.json:3892` | `mükəlləfi` | U+04D9 → U+0259 *(biliniyordu)* |
  | `ContactTransfer.test.tsx:90` | `Ice` | U+0435 |
  | `CallDataRetentionRowFairnessTests.cs:332` | `deftere` | U+0435 |

- **Dört mutasyon, dördü de kırmızı:** düz yön, **ters yön**, evren çökertme (→ `VACUITY: KALDI`),
  kural etkisiz (→ **iki** pozitif kontrol de kaldı).
- **Commit:** `b49018d5`

#### Ölçüm kaybı — dürüstçe

M3 ve M4'ü ilk denemede `git checkout` ile **geri alamadım**: dosya henüz izlenmiyordu, komut
sessizce hiçbir şey yapmadı. M4 böylece M3'ün kalıntısıyla ölçüldü ve kırmızıyı **yanlış sebepten**
aldı. M4'ü yalıtılmış olarak yeniden koştum ve o koşuda vacuity'nin **geçtiğini** ayrıca doğruladım
— yani kırmızı çöküşten değil pozitif kontrolden geldi.

**Ders:** `git checkout --` **izlenmeyen dosyada bir geri alma aracı değildir** ve başarısızlığını
çıkış koduyla bağırmaz. Yeni dosyada mutasyon yapılacaksa önce `cp` ile yedek alınır.

### 15. İki sözleşme belgesi

- **`asterisk-dugum-paketi-sozlesmesi.md`** (commit `9ccc1dd7`): `files[].sha256` **tel sha'sıdır**
  ve `revision` ile **bağımsız** değişir. Bağlayıcı istemci kuralı yazıldı: *"değişti mi" kararı
  `sha256`'dan verilir, `revision`'dan değil* — ters kuran istemci **sır rotasyonunu kaçırır** ve
  kaçırdığını hiçbir yerde göremez (belirti *"telefon kayıt olmuyor"*).
- **`asterisk-transport-ve-kayit-gozlemi-sozlesmesi.md`** (commit `360f18b2`, 489 satır): C ekseni.
  Başlıkta **"SÖZLEŞME — henüz uygulanmadı"** diyor; kardeş belgenin tersi ve bu fark bilerek orada.

Üç bulgusu kart oldu; ikincisi **`BR-AST-69`**: `#37`'nin kayıt sayısı bugünkü okuma portundan
**çıkamaz**, çünkü port aktif tenant'ın anahtarını okur ve `#37`'yi açan `superadmin`'in aktif
tenantı **sistem tenantı**dır. Kart, öncülünün **ölçüm değil çıkarım** olduğunu açıkça taşıyor.

## Kararlar (ek)

- **Bir kapı "bozuk mu" diye değil, "evreni ne" diye sorulur.** `BR-QA-61`'de kapı çalışıyordu;
  sorun ölçtüğü kümenin yazılı olmamasıydı. Evreni yazılmamış her tarama, bulduğu kadarıyla
  "temiz" der.
- **Bir tarayıcıyı kendi kuralından muaf tutmak, kapatmaya çalıştığın kör noktayı geri açar.**
- **Geçen bir test bekçinin taşıdığını göstermez.** `OPS-01-d`'nin `400`'ü yeşildi; mutasyon
  koşulana kadar taşıyıp taşımadığı bilinmiyordu.
- **Ölçüm kaybını sonuç diye raporlamak, yanlış sonuç raporlamaktan farksızdır.** M4 kirlendiğinde
  tabloya "kırmızı" yazmak kolaydı; doğru olan yeniden koşmaktı.

## Açık kalanlar / sonraki adım

- **C ekseni sunucu zinciri koşuyor:** `M1 → LX-18 → LX-19 → D-10 → LX-20`. Bu zincir bitince
  Blok 4 UI (`FE-01`..`FE-16`) **tek turda** yazılabilir (Ş-FE8).
- **`BR-BE-126`** (yeni): sessizlik alarmı **ekranda otomatik yanmıyor** — WS yayını yok. Kesme
  bilinçliydi: `AlarmRaised` payload allowlist'i **kuyruk anahtarı** istiyor ve üç hedef türünü
  oraya sokmak #14'ün alarm **kimliğini** değiştirir; bu bir **kurul** işi.
- **`BR-QA-62`** .NET yuvasını bekliyor (PCI kapısının ham alt-dize taraması → sembol bazlı).
- `OPS-01`'in `ring_group`/`did` dalları **gerçek veriyle koşmadı** (canlıda 0 zil grubu / 0 DID).
- **Canlıya dokunulmadı** — ne örnekleyici ne uç staging/üretimde koşturuldu.

---

## Günün dördüncü yarısı — C ekseni uçtan uca: sunucu, ön yüz, ve aradaki eksik halka

### 16. C ekseni sunucu zinciri (`LX-18`/`19`/`20`/`21` + `D-10`)

- **Neden:** Blok 4 ön yüzü `FE-01`'in *"sunucu alanları gelmeden başlamaz"* şartı yüzünden
  başlayamıyordu; ölçüm netti — `registeredContacts`/`transportWs` → `src/` içinde **0 isabet**.
- **Ne yapıldı:** `RegistrationSamplerJob` (`IBackgroundJob` + `LeaderElectedJobRunner` → `job_runs`
  kanıtı, kilit 35), `AmiTenantCode` kaynak 7 + öneksiz nesnenin **düşürülmesi**,
  `RegistrationSnapshotStore` + özet deposu (`ITenantCache` arkasında), `#37`'ye iki bileşen ve
  `RegistrationSingleSourceTests`.
- **Commit:** `b4ca6b93`

#### `BR-AST-69`'un öncülü artık çıkarım değil, **ölçüm**

`TenantResolutionMiddleware.cs:172-179` → `requested := header X-Tenant-Id ?? homeTenantId`.
`#37` hiçbir tenant argümanı almıyor, `SystemHealthProbe` tenant bağlamını kendisi kurmuyor ve
`superadmin`'in ev tenantı `t0000` — onun hiç PJSIP nesnesi yok. Yani aktif tenant anahtarını
okuyan bir port orada **her zaman boş dönerdi**. Ajan teşhisi bir adım genişletti: `X-Tenant-Id`
gönderilirse port *o tenant'ı* okur, ki bu da "santral geneli toplam" değildir.

#### İki kırmızıyı ben kapattım — ikisi de dersin tekrarı

1. **`HealthComponentLabelPairingTests` kırmızıydı** (456/457): sunucuda tanımlı iki bileşenin
   istemcide etiketi yoktu. Ajan `src/Pbxtr.Web/` sınırı yüzünden girmedi — **doğru davranış**, ama
   *kırmızıyı dürüstçe belgelemek kırmızıyı kapatmak değildir*. İki etiket + dokuz dil eklendi;
   diff 9 dosyada 18 satır (JSON anlamsal düzenlendi, girinti/satır sonu ham dosyadan ölçüldü).
   **Mutasyon:** bir etiket silindi → 456/457; geri alındı → **457/457**. Bekçi çift yönlü.
2. **`BackgroundJobLocksTests.Kilit_listesi_birebir` kırmızıydı:** kilit 35 tanımlanmış, altın liste
   güncellenmemişti. Bu, ajanın **koşmadığı** testte çıktı — Docker gerektirdiği için atlamıştı.
   *"`Skipped` yeşil değildir"* bir kez daha ısırdı: atlanmasaydı ajan kendi kırmızısını görürdü.

### 17. Blok 4 ön yüzü — tek turda, 13 kart

- **Neden:** Ş-FE8 UI'ı **tek turda** istiyor; bölmek, yarım bir eksen bırakmak demekti.
- **Ne yapıldı:** kayıt ekseninin **tek sözlüğü** (`REGISTRATION_TEXT`, 4 hâl, 9 dil), üç değerli
  alanlar için `TRISTATE_FIELDS`, `configStatus` artık union, softphone rozetine altıncı hâl
  (`unmeasured`), sınırlı backoff, `registered === false` → **yalnız "Müsait"** kapanır.
- **Sonuç / doğrulama:** `tsc -b` RC=0 (yayın kapısı, `--noEmit` **değil**), vitest
  **1764/1764 · 0 atlanan**, Architecture **457/457**.
- **Commit:** `273937d3`

> Sprint-44'te **`FE-12`/`FE-13`/`FE-14` diye kart yok** — tablo `FE-11`'den `FE-15`'e atlıyor.
> Var olan 13 kartın hepsi indi.

**Ajanın yol üstünde kapattığı kırmızı benim ürettiğimdi:** `auditTargetParity.test.ts`.
`git stash` ile **temiz HEAD'de de** kırmızı olduğunu ölçmüş — sebep akşamki `OPS-01` commit'imdi
(sunucuda yeni denetim hedefi türü açıldı, `#38` filtresi güncellenmedi). Fark etmemiştim.

### 18. Aradaki eksik halka — ve bugünün en öğretici anı

Ön yüz indi, sunucu indi. **Arada tek bir okuma yolu eksikti:**

```
grep -rn "IRegistrationView" --include=*.cs src/ tests/
  -> arayüz · depo · DI kaydı · mimari bekçi        (HTTP tüketicisi YOK)
```

`/users/extensions` ve `/agent/state` `registration` alanını üretmiyordu. Yani bu akşam yazılan
`registered`/`registeredDevices`/`notRegistered` dallarının **üçü de üretimde hiç koşmuyordu**;
her yüzey "Ölçülemedi" diyordu. **Bu, aynı günün sabahında `OPS-01` için kapattığım
"kod var, koşan yok" sınıfının bir kat yukarıdaki aynısıydı.**

- **Ne yapıldı:** `RegistrationAxis` (domain birleştirme), `AsteriskObjectName.IsExtensionObject`,
  `RegistrationAxisDto` (**tek DTO iki yüzeyde**), iki uca opsiyonel `IRegistrationView?`
  enjeksiyonu — tenant başına **tek** Redis okuması, N+1 yok, santral çağrısı yok.
- **Birleştirme önceliği `true > null > false`** ve bu bir tercih değil: bir cihazı **ölçemediysek**
  "kayıt yok" denmez, çünkü o cümle `FE-11`'de agent'ı **Müsait olmaktan alıkoyar**. Yanlış taraf
  seçilseydi bir ölçüm boşluğu agent'ı sessizce çağrı dışı bırakırdı.
- **Sonuç / doğrulama:** `RegistrationAxisHttpTests` gerçek `Program.cs` + gerçek PostgreSQL + **gerçek
  Redis** + gerçek HTTP; anahtarı test elle yazmıyor, **örnekleyicinin kendisi koşuyor**.
- **Commit:** `a619391e`

#### Kendi koştuğum mutasyon — turun en sinsi riski

Risk: sunucu alan adı ön yüzün beklediğinden saparsa ön yüz **sessizce** "ölçülemedi" demeye devam
eder ve **hiçbir test kırılmaz**.

| Adım | Sonuç |
|---|---|
| DTO alanı `ContactCount` → `ContactCountX` (çıpa 1→0) | derleme **0 hata** — yani sessiz sapma gerçekten mümkün |
| koşu | `RegistrationWireContractTests` **iki** testi kırmızı (460 → 458) |
| geri alma + yeniden derleme | **460/460** |

Bekçinin kendi vacuity kapısı da yerinde: `Assert.NotEmpty(client)` + `server.Count == 3`.

**Ajan kendi bekçisinin bir kolunun vacuous olduğunu kendisi buldu:** `M2` (`?? 0` düzleştirmesi)
ilk koşuda mimari bekçiyi **kırmıyordu**, çünkü test DTO'yu elle kuruyor ve `From`'u hiç
çağırmıyordu. Bekçiyi `From` üzerinden geçecek şekilde düzeltip `M2`'yi **tekrar** ölçtü.

#### Bir sayı farkı ve nasıl çözüldü

Ajan Integration tabanını 22 sanıp benim "19" dediğimi düzeltmeye çalıştı. Ölçtüm: toplam **22**,
yeni sınıf **3** → taban gerçekten **19**'du. Ajanın "25" ölçümü yanlıştı; **düşen test yok.**
Ders: bir ajanın düzeltmesi de bir iddiadır, ölçülene kadar doğru değildir.

## Kararlar (ek)

- **Bir eksen üç parçadan oluşur: üretici, taşıyıcı, tüketici.** İkisini yazıp üçüncüyü atlamak,
  "bitti" hissi veren ama üretimde hiçbir dalı koşturmayan bir sonuç üretiyor. Bugün bu hata **aynı
  gün içinde iki kez** (OPS-01 ve C ekseni) ortaya çıktı ve ikisi de aynı `grep` ile görüldü:
  *bu arayüzün tüketicisi kim?*
- **Ölçüm boşluğunda hangi tarafa yuvarlandığı bir güvenlik kararıdır.** `null → false` yuvarlaması
  burada agent'ı çağrı dışı bırakırdı; `false → null` yuvarlaması gerçek bir kopuşu gizlerdi.
  İkisi de "küçük bir varsayılan" gibi görünüyor.
- **Bir ajanın "senin sayın yanlış" demesi, sayının yanlış olduğunu göstermez.** Ölçtüm, benimki
  doğruydu — ama ölçmeden kabul etseydim sahte bir taban yazmış olacaktım.

## Açık kalanlar / sonraki adım

- **`BR-QA-62`** hiç başlamadı: PCI kapısı ham alt-dize arıyor, sembol bazlı olmalı.
- **`BR-AST-70`** (yeni): örnekleyicinin gruplama dalı **yalnız `asterisk` bileşiminde** var;
  `simulated` konakta DI hatasıyla düşüyor. Bugün üretimde zararsız (`simulated` sağlayıcı `null`
  döndüğü için dal hiç girilmiyor) ama **gerçek santrale karşı hiç koşmadı**.
- **`BR-BE-126`**: sessizlik alarmı ekranda otomatik yanmıyor (WS yayını yok).
- **`M1-a..d` laboratuvar bekliyor** → `contactCount` üretimde hâlâ daima `null`, yani
  *"Kayıtlı — n cihaz"* metni hiç çizilmiyor; `transportWs`'in `Down` dalı **erişilemez**.
- **Gerçek Asterisk'e karşı bu akşam hiçbir şey doğrulanmadı; canlıya hiç dokunulmadı.**
