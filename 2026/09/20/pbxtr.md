# pbxtr — 2026-09-20

## Bağlam

`Pbxtr.Integration.Tests` ana dalda iki bilinen kırmızı taşıyordu ve bunlar entegrasyon
takımındaki **son** bilinen kırmızılardı. Hedef: `BR-DB-105` ve `BR-DB-106` kartlarını
ölçerek kapatmak. Kurul dağıtılmış durumda — karar sorulmaz, ölçülür ve bitirilir.

Başlangıç HEAD: `59d31085` (BR-SEC-29 turu). Ağaç temizdi (yalnız ilgisiz bir untracked
`RingGroupMemberDelay.test.tsx` duruyordu, ona dokunulmadı).

## Yapılanlar

### 1. `BR-DB-105` — `pbxtr_sys` fonksiyon bekçisinin 3 ihlali

- **Neden:** `SysFunctionGuardTests.Sys_fonksiyon_bekcisi_canli_katalogdaki_driftleri_yakalar`
  → `P0001: PBXTR_SYS FUNCTION GUARD: 3 ihlal`, üçü de `SYS_FUNCTION_PROSRC_CHANGED`
  (`call_data_retention_lag`, `call_data_retention_plan`, `purge_call_data`). Kart bilerek
  kapatılmamıştı: *"körlemesine hash güncellemek bekçiyi kendi kendini onaylayan bir aynaya
  çevirir."* Önce **kim/hangi commit/neden** sorusunun cevaplanması şarttı.

- **Ne yapıldı — üç olasılıktan hangisi çıktı:** **(3) çıpa yanlıştı; sapan bir GÖVDE YOKTU.**

  Kanıt zinciri, tahmin değil ölçüm:
  1. Taban koşusunun **yığın izi** `SysFunctionGuardTests.cs:280` ← `:141` gösterdi.
     Satır 141, `MigrateAsync(LastSysFunctionMigration())` ile **geri sarılmış** ara durumun
     hemen ardındaki `AssertGuardCleanAsync()`'tir — yani kırmızı **tam zincirde değil**,
     rollback hijyeni adımındaydı.
  2. Aynı testin **satır 75'teki** fixture karşılaştırması (`deploy/db/sys-functions.expected`
     ↔ canlı `pg_proc`) tam zincirde **geçiyordu**. Yani `02-guards.sql`, donmuş envanter ve
     canlı gövdeler **birbiriyle tutarlıydı**. Hash tazelemek bu kırmızıyı düzeltmezdi.
  3. Statik ölçüm: `02-guards.sql:1978-1991` ve `sys-functions.expected:7,8,16` zaten
     **YENİ** değerleri (`ed779cc5`, `81f61467`, `82a32f12`) taşıyordu. Hatadaki *beklenen*
     değerler (`72a9e917`, `d758ce05`, `a98191be`) yalnızca iki yerde geçiyordu:
     `20260915120000_TenantColumnWriterGate` ve `20260918233000_…Down()`.

  **Kök sebep:** sys envanterinin **iki yarısı** iki ayrı migration'a düşmüş.
  `20260918230000_CallDataRetentionWebhookOutboxCallback` **gövdeleri** değiştirir;
  `20260918233000_GuardsTemplateRefreshCallDataAllowlist` **beklenti listesini**
  (`pbxtr_sys_function_expectations`, `02-guards.sql` şablonunda) tazeler. O dosyada
  *"SIRA BAGLAYICI"* diye yazılıdır: aralarında **bilerek tutarsız bir pencere** vardır.

  Testin geri sarma hedefi türetimi yalnızca `"FUNCTION pbxtr_sys."` arıyordu (gövde
  yazanlar). Ölçüldü: o filtreye uyan **en yeni** migration tam olarak `20260918230000`.
  Yani hedef **pencerenin içine** düşüyordu → 230000 uygulanmış (gövde YENİ) + 233000 geri
  alınmış (envanter ESKİ) → 3 × `SYS_FUNCTION_PROSRC_CHANGED`.

  Türetimin **kendi yazılı öncülü** — *"o noktanın üstündeki migration'lar sys envanterine
  dokunmaz"* — 2026-09-18'de 233000 inince yanlış oldu. `20260918130000` ve `20260918180000`
  emsalleri `Down()`'u **boş** bıraktığı için bu delik o güne kadar görünmemişti.

- **Dokunulan dosyalar:** `tests/Pbxtr.Integration.Tests/Tests/SysFunctionGuardTests.cs`
- **Düzeltme:** `LastSysFunctionMigration()` → `LastSysInventoryMigration()`. **İki marker**
  taranır (`FUNCTION pbxtr_sys.` = gövde, `pbxtr_sys_function_expectations` = beklenti),
  hedef ikisinin **maksimumudur** (bugün `20260918233000`). Ayrıca bir **vacuity ayağı**:
  hedefin üstünde envantere dokunan migration kalmadığı assert edilir — üçüncü bir dokunma
  biçimi çıkarsa sessiz geçmez, orada kırmızı olur.
- **Hiçbir hash güncellenmedi.** `02-guards.sql`, `sys-functions.expected` ve migration'lar
  bayt-tam aynı kaldı; şablon değişmediği için **refresh migration gerekmedi**.
- **Ölçüldü:** `20260918233000`'in üstündeki 7 migration'ın hiçbiri envantere dokunmuyor
  (`fn=0 exp=0`).

### 2. `BR-DB-106` — down→up yolculuğu `42703`

- **Neden:** `InitialSchemaMigrationTests.InitialSchema_up_bekciler_down_up_yolculugu_yesil`
  → `42703: column "box_id" of relation "public.voicemail_sla_daily" does not exist`.
  Aynı kırmızı `UserRoleScopeConsistencyTests.Up_Down_Up` içinde de görülüyordu.

- **Ne yapıldı:** **Sıra korundu — önce `Down()` denendi ve `Down()` gerçekten
  düzeltilebilirdi**, dolayısıyla ileri yönlü tazeleme migration'ı **seçilmedi**.

  Kusur `20260918190000_VoicemailBoxIdentity.Down()` içindeydi ve **eksik değil, FAZLA** bir
  ifadeydi. Blok sırasıyla şunu yapıyordu:

  ```sql
  ALTER TABLE public.voicemail_sla_daily DROP COLUMN box_id;   -- kolon gitti
  ...
  COMMENT ON COLUMN public.voicemail_sla_daily.box_id IS NULL; -- 42703
  ```

  Yani **az önce düşürdüğü kolona** yorum yazmaya çalışıyordu.

  **Kartın teşhisi yanlıştı:** hata `Up()`'ta değil, **geri alma adımının kendisinde**
  düşüyordu. `Migrator.MigrateImplementationAsync` yığın izi ikisini ayırt etmediği için
  "down sonrası tekrar up" gibi raporlanmıştı. Aday çift doğruydu ama kırılma noktası
  PK/kolon takası değil, ondan **sonraki** `COMMENT` ifadesiydi.

- **Dokunulan dosyalar:**
  `src/Pbxtr.Infrastructure/Persistence/Migrations/20260918190000_VoicemailBoxIdentity.cs`,
  `deploy/migration-contract-onay.blobs`
- **Düzeltme:** ifade **kaldırıldı** ve yerine neden geri konmayacağı yazıldı: `DROP COLUMN`
  kolonun `pg_description` satırını **zaten** düşürür (`attnum`'a bağlıdır), yorumu ayrıca
  boşaltmak gereksizdir. Eski satır *"Up'ta COMMENT yazdım, Down'da geri alayım"* refleksiydi
  ve sırayı atlıyordu.
- **`BR-SEC-29` emsali bilerek UYGULANMADI:** o kart şablon tazelemesiydi ve `Down()` gerçekten
  bir kusuru geri getirecekti; bu **kolon** işidir ve geri alınamayan bir şey yoktu.
- **kapi_07:** dosyanın blob sha'sı değiştiği için `deploy/migration-contract-onay.blobs:115`
  aynı `Karar#76` numarasıyla yeni blob'a (`0f07bd67…`) taşındı. Yol **tek satır** kalır;
  ikinci onay satırı eklenmedi (defterin 1. kuralı aynı yolun ikinci onayını reddeder).

### 3. Ölçüm

- **Komutlar:**
  ```bash
  dotnet build tests/Pbxtr.Integration.Tests/Pbxtr.Integration.Tests.csproj -c Debug --no-incremental
  dotnet test  tests/Pbxtr.Integration.Tests/Pbxtr.Integration.Tests.csproj --no-build -c Debug \
    --filter "FullyQualifiedName~SysFunctionGuardTests|FullyQualifiedName~InitialSchemaMigrationTests|FullyQualifiedName~UserRoleScopeConsistencyTests"
  dotnet test  tests/Pbxtr.Integration.Tests/Pbxtr.Integration.Tests.csproj --no-build -c Debug \
    --filter "FullyQualifiedName~Migration|FullyQualifiedName~Voicemail"
  dotnet test  tests/Pbxtr.Architecture.Tests/Pbxtr.Architecture.Tests.csproj -c Debug
  python deploy/migration-compatibility-guard.py
  ```

- **Sonuç / doğrulama** (gerçek `postgres:16-alpine` konteyneri, testcontainers):

  | Koşu | Taban | Düzeltme sonrası |
  |---|---|---|
  | `SysFunctionGuardTests` | 1 KIRMIZI (`P0001: 3 ihlal`) | — |
  | `InitialSchemaMigrationTests` | 1 KIRMIZI (`42703`) | — |
  | üç sınıf birlikte | — | **9/9 YEŞİL** |
  | `UserRoleScopeConsistencyTests` tek başına | — | **7/7 YEŞİL** |
  | `~Migration\|~Voicemail` dilimi | — | **18/18 YEŞİL** |
  | `Pbxtr.Architecture.Tests` | — | **755/755 YEŞİL** |
  | `migration-compatibility-guard.py` | OK | **OK (rc=0)** |

- **Mutasyon (her kart için ayrı, `--no-incremental` ile derlenerek):**

  | Mutasyon | Sonuç | Geri alma |
  |---|---|---|
  | `SysFunctionGuardTests`: türetim eski hâline (`target = bodies[^1]`, vacuity ayağı susturulmuş) | **KIRMIZI — birebir eski hata**, aynı 3 md5 çifti | sha256 `e08884fe…` bayt-tam, yeniden YEŞİL |
  | `VoicemailBoxIdentity.Down()`: `COMMENT ON COLUMN … box_id IS NULL;` geri kondu | **KIRMIZI — birebir eski `42703`** | sha256 `a23ac6e8…` bayt-tam, yeniden YEŞİL |

  105 mutasyonunun **birebir eski hatayı** üretmesi, kırmızının sebebinin hash değil **çıpa**
  olduğunun kesin kanıtıdır.

- **Commit:** `086e5100` — *BR-DB-105 + BR-DB-106 KAPANDI: entegrasyon takiminin son iki
  ana-dal kirmizisi*, push edildi (`59d31085..086e5100 main -> main`).

### 4. Kart defteri

- `yonetim/backlog.md` — iki kartın durum hücresi `Kapandı` ile başlıyor, eski metin
  `**Önceki kayıt:**` altına alındı, `Kısmen` kelimesi kullanılmadı (sayaç onu açık sayar).
- `yonetim/kalan-isler.md` elle değil **jeneratörle** tazelendi
  (`node yonetim/arac/kalan-isler.js`): `complete` **676 → 678**, kapalı olmayan **84 → 82**.
  Artış tam olarak iki, yani sayaç iki kartı da gördü.

## Kararlar

1. **Hash tazelemek bir düzeltme değildir.** `BR-DB-105`'te doğru refleks, hatadaki iki hash'i
   karşılaştırmadan önce **hangi adımın** kırmızı verdiğini yığın izinden okumaktı. Tam zincir
   fixture'ı geçiyorsa envanter zaten tutarlıdır ve sorun başka yerdedir.
2. **Bir bekçinin türettiği çıpa da ölçülmelidir.** Türetim, kendi yazılı öncülünü koda karşı
   doğrulamıyordu. Yeni hâlinde bir vacuity ayağı var: öncül bozulursa test kırmızı olur.
3. **Bilerek tutarsız migration penceresi bir tasarım nesnesidir.** Gövde ve envanter ayrı
   migration'lara düşüyorsa, o ikisi arasına **hiçbir rollback hedefi konulamaz**. Bunu bilen
   tek yer şimdilik `LastSysInventoryMigration()`.
4. **Emsal körü körüne uygulanmaz.** `BR-SEC-29`'da boş `Down()` doğruydu (şablon tazelemesi);
   `BR-DB-106`'da yanlış olurdu (kolon işi, geri alınabilir).
5. **Onay defteri satırı taşındı, çoğaltılmadı.** `Karar#76` satırı yeni blob sha ile
   güncellendi; aynı yol için ikinci satır açmak kapıyı kırardı.

## Açık kalanlar / sonraki adım

- **Ölçemediğim:** entegrasyon takımının **tamamı tek koşuda** ölçülmedi; namespace dilimleri
  koşuldu (`~SysFunctionGuard`, `~InitialSchemaMigration`, `~UserRoleScopeConsistency`,
  `~Migration|~Voicemail`). "Entegrasyon takımı tamamen yeşil" iddiası bu turda **yapılmadı**.
- **Ölçemediğim:** `20260918190000_VoicemailBoxIdentity` kurulu (sunucudaki) bir veritabanında
  koşturulmadı. Dosyanın kendi `OLCULMEYEN` notu bu yönüyle aynen durur.
- `20260918233000_GuardsTemplateRefreshCallDataAllowlist.Down()`, zincir **230000'in altına**
  sarılırsa hâlâ 130000/180000 emsalinin taşıdığı ters yönlü deliği taşır (gövde ESKİ,
  envanter YENİ). Bugünkü test bu noktaya inmiyor; ölçülmedi, kart açılmadı.


### Koordinator turu — son iki kirmizi kapandi + COMMIT EDILMEMIS bir test kurtarildi

#### `BR-SEC-29` (ajan: db-dev, 19 Eylul gec saat) — KAPANDI

- `tenants_sys_update` owner yazma yuzeyi **N-1 -> 0 satir**. Tasarim A indi: iki
  `pbxtr_sys` yazicisi fonksiyon duzeyi `SET "app.sys_write"` tasiyor, policy onu **on kosul**
  sayiyor. Iki mutasyon da yakalandi.
- **Olculmemis bir varsayim DOGRU cikti ve engeldi:** `app.sys_write` icin ayri bir
  `GRANT SET ON PARAMETER` gerekiyormus. Temiz PG 16.15'te olculdu (grant yokken
  `CREATE FUNCTION ... SET` **42501** ile duser), `00-roles.sql`'e eklendi ve sunum
  sunucusuna uygulandi. **Yapilmasaydi migration canlida 42501 ile duserdi.**
- **Kalinti zayiflik durustce korundu:** `app.sys_write` duz bir GUC; `pbxtr_owner` onu elle
  de yazabilir. Kapanis metninde "sinir" degil **"daraltma"** yaziyor.

#### Ajanin iki "kartsiz kirmizi" iddiasi DOGRULANDI ve IKISI DE GECERSIZ

- `SpaBuildContextTests` **yesil** — ajanin tabani benim `8ab15a65` duzeltmemden onceki
  **bayat bir worktree**'ydi. Kontrol etmeseydim zaten kapali bir sorun icin ikinci kart
  acilacakti. (*Yesil takim hangi commit'i kapsiyor* dersi, ters yonden.)
- Ikinci kirmizi (`voicemail_sla_daily.box_id`, `42703`) zaten `BR-DB-106`'ydi.

#### `BR-DB-105` (ajan) — UC OLASILIKTAN **(3)**: capa yanlisti, sapan bir GOVDE YOKTU

- Brifingte uc olasilik sayilmisti (govde bilerek degisti / kurulu DB sapmis / capa hic dogru
  olmamis) ve **korlemesine hash tazelemek yasaklanmisti**. Olcum (3)'u gosterdi.
- Kanit zinciri: kirmizi **tam zincirde degildi** (yigin izi geri sarilmis **ara duruma**
  isaret ediyordu); tam zincirde `sys-functions.expected` <-> canli `pg_proc` **gecti`;
  `02-guards.sql` ve `expected` zaten **YENI** degerleri tasiyor, eski degerler yalnizca bir
  `Down()` icinde yasiyor.
- **Kok sebep:** envanterin iki yarisi iki ayri migration'a dusmus (`230000` govdeler,
  `233000` beklenti listesi) ve arada **bilerek tutarsiz bir pencere** var. Testin hedef
  turetimi tek marker ariyordu ve tam o pencerenin **icine** dusuyordu.
- **Duzeltme:** iki markerli `LastSysInventoryMigration()` + **vacuity ayagi**.
  **Hicbir hash guncellenmedi**, refresh migration gerekmedi.

#### `BR-DB-106` (ajan) — `Down()` duzeltildi; **kartin teshisi yanlisti**

- Hata `Up()`'ta degil, **geri alma adiminin kendisinde**ydi. `Down()` icinde **eksik degil
  FAZLA** bir ifade vardi: `DROP COLUMN box_id`'nin hemen ardindan
  `COMMENT ON COLUMN … box_id IS NULL` -> `42703`. `DROP COLUMN` zaten `pg_description`
  satirini dusuruyor. Ifade kaldirildi.
- `BR-SEC-29`'un bos-govde emsali **bilerek uygulanmadi** (o sablon tazelemesiydi, bu kolon
  isi ve geri alinabilirdi).
- **Mutasyon:** ikisinde de **birebir eski hata** geri geldi (105'te ayni uc md5 cifti,
  106'da ayni `42703`); dosyalar sha256 ile **bayt-tam** geri alindi.
- **Olcum:** uc sinif birlikte 9/9, `UserRoleScopeConsistencyTests` 7/7,
  `~Migration|~Voicemail` 18/18, `Architecture.Tests` **755/755**.
- Ajan *"entegrasyon takimi tamamen yesil"* iddiasini **yapmadi** (dilimler kosuldu).

#### KOORDINATOR BULGUSU — 11 testlik yeni dosya COMMIT EDILMEMISTI

- `BR-FE-125` kapali, ama `src/Pbxtr.Web/src/app/screens/telephony/RingGroupMemberDelay.test.tsx`
  (**307 satir, 11 test**) `git status`'ta **`??`** duruyordu. Ajanin *"vitest 2127 gecti"*
  olcumu **dogruydu** -- dosya diskte vardi; eksik olan **teslimdi**. Taze bir klonda o 11
  test **hic yoktu**.
- **Nasil kacti:** *"`git add -A` yasak, yollari acikca say"* kurali dogrudur ama **yeni**
  dosyada ters yonde bir bosluk birakiyor: degisen dosya goze carpar, yeni dosya sayim
  listesine yazilmazsa **sessizce** disarida kalir ve **hicbir sey kirmizi olmaz**.
  Ertesi turdaki ajan onu *"ilgisiz untracked"* diye **dogru sekilde** atladi -- yani kural
  herkesi dogru yonde calistirdi ve dosya yine de kayboluyordu.
- **Silmeden once kosuldu:** `11 tests / 11 passed`. Sonra commit edildi (`cf0705a7`).
- Depoda baska `??` satiri **kalmadi** (tarandi).

### Kararlar

- **Bir ajan "bitti" dediginde `git status --porcelain` OKU.** `??` satiri varsa sahibini
  sor; ozellikle `tests/`, `src/`, `deploy/` altinda. Bu, *kod var kosan yok* deseninin bir
  adim oncesidir: **kod var, depoda yok**.
- **Ajan brifingine ekle:** *"YENI dosya olusturduysan commit yol listesinde onu ADIYLA say;
  `git status --porcelain` ciktinda `??` birakma."*
- **Bir ajanin "HEAD'de de kirmizi" iddiasi bir TARIH iddiasidir** -- tabanini guncel `main`
  uzerinde dogrula.

### Acik kalanlar / sonraki adim

- Acik kart **82** (P0 3 / P1 38 / P2 36 / P3 5). ClickUp senkron.
- Entegrasyon takiminda **bilinen kirmizi kalmadi**; ama "takim tamamen yesil" iddiasi
  **yapilmiyor** (dilimler kosuldu, tam kosu yok).
- `20260918233000.Down()` ters yonlu deligi (govde ESKI + envanter YENI) **olculmedi**,
  bugunku test oraya inmiyor.
- **Yayin hala kosulmadi** -- uc P0 ve acik kartlarin buyuk kismi ona bagli.

---

## Ek tur - BR-SEC-21 (backend-dev-2, SSRF)

### 1. `OutboundHostGuard` evreni iki uctan olculdu

- **Neden:** kartin (c) ayagi *"negatif test yok"* diyordu; kartin KENDI olcumu ise
  (a)'yi *"kapali, mutasyonla dogrulanmis"* sayiyordu. Iki iddia celisiyordu, once
  hangisinin dogru oldugu olculdu.
- **Ne yapildi:** evren **iki uctan** tanimlandi -- taranan: `src/` altinda giden
  baglanti acan her yol; **cagiran sayilan**: `OutboundHostGuard.Validate` ya da
  `OutboundConnectGuard.Create` cagiran `.cs` dosyasi (belge cagiran **sayilmadi**).
  Gecen **7 yol**, gecmeyen **3 yol** (`AriClient`, `AriStasisApp`,
  `UnixSocketSystemAgent`) -- ucu de **bilincli** disarida: hedefleri yapilandirmadan
  gelir ve ic agdadir, kapidan gecirilseydi **santral baglantisi reddedilirdi**.
- **Sonuc:** kartin (a) iddiasi dogruydu (12 test vardi), ama evren eksikti.

### 2. BULGU - dorduncu bir yol kapidan gecmiyordu: Netgsm

- **Neden:** evren sayimi `NetgsmOptions`'i "gecen" tarafa koyuyordu; cagiranin
  **ne zaman** cagirdigi sorulunca delik cikti.
- **Ne yapildi:** `EnsureUsable` `BaseUrl`'i kapidan geciriyor ama **yalnizca
  acilista, bir kez**. Gonderim anindaki istemci ham `new HttpClient()` idi
  (`SmsServiceCollectionExtensions.cs:193` handler vermiyor) -> (i) her gonderimdeki
  DNS cozumlemesi **hic siniflandirilmiyordu**, (ii) ham `HttpClient`'ta
  `AllowAutoRedirect` **varsayilan olarak ACIK** -- tek bir `302` istegi kapidan
  gecmemis hedefe tasirdi. **Netgsm arayuzunde kullanici adi ile parola sorgu
  dizesindedir**: yonlendirilen sey kimlik bilgisinin kendisi olurdu.
- **Dokunulan dosyalar:** `src/Pbxtr.Infrastructure/Modules/Messaging/NetgsmSmsClient.cs`
- **Sonuc:** `CreateDefaultHandler()` artik `OutboundConnectGuard.Create` dondurur.

### 3. Negatif testler (6 yeni vektor) + Netgsm bekcisi (6 test)

- **Ne yapildi:** V9 belirsiz adres (`connect(0.0.0.0)` Linux'ta **127.0.0.1**'e
  baglanir ve `IsLoopback` buna **false** doner -- onceki 12 vektorun hicbiri bu
  adresi olcmuyordu), V10 baglanti-yerel araligin TAMAMI (eski V3 yalniz
  `169.254.169.254`'tu; `169.254.170.2` = ECS meta verisi aciktaydi), V11
  ayrilmis/coklu gonderim, V12 IPv6 ULA'nin **iki yarimi** (eski V4 yalniz `fd`),
  V13 gomulu yazim, V14 cozumleme yolu (literal yoldan **ayri bir daldir**).
  **Hepsi sinir ikiziyle** ve **pozitif ayak her iki dosyada da var**.
- **Dokunulan dosyalar:** `tests/Pbxtr.Api.Tests/Platform/Mail/OutboundHostGuardTests.cs`,
  `tests/Pbxtr.Api.Tests/Modules/Messaging/NetgsmOutboundHardeningTests.cs` (YENI)
- **Sonuc / dogrulama:** taban **30** -> **36** -> **42 gecti / 0 dustu**;
  `OutboundHostGuardSurfaceTests` **3/3**; `Netgsm|Sms` regresyonu **164/164**.
  Gercek aga cikilmadi (cozumleyici enjekte edilebilir).

### 4. Mutasyon - bes mutasyon, besi de kirmizi

```bash
# hepsi --no-incremental ile YENIDEN DERLENDI
M1 unspecified kolu       -> 5 KIRMIZI
M2 link-local v4 kolu     -> 5 KIRMIZI
M3 reserved (>=224) kolu  -> 3 KIRMIZI
M4 AllowAutoRedirect=true -> 2 KIRMIZI
M5 Netgsm duzeltmesi geri -> 5 KIRMIZI, 1 gecti (gecen tek test POZITIF olandir)
```

- **Sonuc:** besi de geri alindi, guard dosyalarinda `git diff` bos, tekrar **42/42**.
- **Commit:** `08d285a2`

## Kararlar (ek tur)

- **Asterisk yollari kapidan GECIRILMEZ ve bu bilinclidir.** `AriClient`/`AriStasisApp`
  hedefleri `172.28.x` ve tailscale `100.106.82.119`'dur; kapidan gecirilseydi
  `private`/`cgnat` ile reddedilirdi -- ag katmaninda CGNAT'in bilerek drop
  EDILMEME gerekcesinin birebir ikizi.
- **(c) ayagi yapilmadi, DEVREDILDI** (`BR-SYS-127`): is `src/Pbxtr.Web` altina
  (FE etiket cifti + 9 dil metni) yazmayi gerektiriyor, o yol bu turda **baska bir
  ajanin calisma agacindaydi**. Kart **yazildi** -- yoksa gorunmez borc olurdu.

## Ogrenilen (ek tur)

- **MSBuild `MSB4166` bir TEST SONUCU DEGIL, KAYIP OLCUMDUR.** M3 ilk kosusunda
  cocuk dugum coktu; `-m:1` ile tekrarlandi. Tekrarlanmasaydi "olctum" denen sey
  hic kosmamis bir mutasyon olacakti.
- **"Kapidan geciyor" bir ZAMAN iddiasidir.** Netgsm cagirani listede **gecen**
  tarafta duruyordu; delik, cagiranin *ne zaman* cagirdigi sorulunca cikti.
  Acilista bir kez cagirmak, gonderim anini olcmez.
- **Mutasyonda gecen testi de oku.** M5'te gecen tek test **pozitif** olandir --
  bu, mutasyonun dogru testleri oldurdugunun kaniti; hepsi kirmizi olsaydi
  fikstur ayrismiyor demekti.

## Acik kalanlar (ek tur)

- `SmtpMailSender` kendi soketini acar (`SmtpMailSender.cs:268`) ve
  `OutboundConnectGuard`'i **kullanmaz**; kapidan gecen adrese baglanip
  baglanmadigi **olculmedi** (ADR-019 §4'te yazili borc).
- Duzeltilen Netgsm yolu **gercek saglayiciya karsi kosmadi**; kanit yalnizca testtir.
- `BR-SYS-127` (`webhook_deliveries` boyut esigi) acildi, hic baslanmadi.

---

## BR-QA-57 KAPANDI — gorsel kapi kapsami 5 -> 6 taban (frontend-dev-1)

### Baglam
Kartin son acik kalemi (3) vardi: **agent eylem cubugu** (dinleme/sufle/araya
girme). Kalem 1 (wallboard 1920x1080), 2 (#12 canli kuyruk) ve 4 (gunduz temasi)
onceki turlarda inmisti.

### 1. #28 `MonitorScreen` piksel tabani
- **Neden:** kartin cumlesi — *"dugme kaymasi BURADA yetki hatasina donusur:
  supervizor musterinin duydugu hatta konusur"*. Uc eylem dugmesi (Dinle · Sufle ·
  **Araya gir**) yan yana ve ayni kutuda (`.actions`).
- **Dokunulan dosyalar:** `src/Pbxtr.Web/visual-tests/monitor.visual.spec.ts` (YENI),
  `src/Pbxtr.Web/visual-tests/__screenshots__/linux/monitor-1440x900.png` (YENI),
  `src/Pbxtr.Web/scripts/verify-visual-baselines.mjs` (manifesto satiri).
- **Fikstur bilerek cok sey soyluyor:** iki uc (`/live/agents`, `/monitor/sessions`),
  yetki IKI ALANDAN (`monitor.listen` + `live.agent.read`) + `monitor.whisper` +
  `monitor.barge` (yalniz `listen` verilseydi taban EN DAR cubugu dondururdu),
  saatlik sure `1:11:11`, `currentCallQueue: null` -> `—`, baska supervizorun
  oturumu (rozet + ad), ortada kalan (stranded) oturum, **gercek GUID kuyruk
  kimlikleri**.

### 2. ILK KOSU GERCEK KUSUR OLCTU -> `BR-FE-126` (ayni turda kapandi)
- **Olcum:** uyelik satiri `agent.queueIds.join(", ")` yaziyordu; `LiveAgent.queueIds`
  uretimde **GUID**'dir (`RedisLiveOperationsView.cs:479`). Sayfada ham GUID
  **3 satirda birden**; uc uyelikli agent'ta hucre **110 karakter**, satirin ortasini
  kapliyor ve sayac + eylem cubugunu saga itiyordu.
- **Neden bugune kadar gorunmedi:** fiksturler `"satis"`/`"destek"` gibi **okunur**
  sahte kimlikler kullaniyordu — `BR-FE-124`'u (#12) gizleyen sebebin aynisi.
- **Cozum #12'ninkinden FARKLI olmak zorundaydi:** #12 adi kendi `/live/queues`
  yanitindan cozer; #28 o ucu **cagiramaz** (kayit defteri satiri `live.queue.read`
  istemez). Ad **uydurulmadi**, olculmus olan yazildi: **SAYI** ("Uyelik: 3 kuyruk").
  Yeni anahtar **9 dilde** (`monitor.membershipCount.one/.other`; Arapca alti cogul
  sinifiyla), eski `monitor.membership` kaldirildi.
- **Taban kusurlu haliyle DONDURULMADI** — once duzeltildi, sonra uretildi.

### 3. Mutasyon (iki bekci, iki yon)
Mutasyon: satiri `` `Uyelik: ${queueIds.join(", ")}` `` ile geri al.
- `MonitorScreen.test.tsx` (GERCEK GUID fiksturuyle): **3 failed / 19 passed**
  -> geri alindi **22 passed**.
- `monitor.visual.spec.ts` (pinli konteyner): GUID 3 esleme -> **KIRMIZI**
  -> geri alindi **yesil**.
Ikisi ayri sey olcer: piksel kapisi SABIT fiksturu, birim testi "hangi veriyle
olursa olsun kimlik yazilmaz"i.

### 4. Olcumler
```bash
deploy/fidelity/fidelity-kos.sh dogrula   # S4 parmak izi TUTTU, 6 passed, rc=0
node scripts/verify-visual-baselines.mjs  # "verified 6 visual baseline(s)" rc=0
node scripts/verify-visual-baselines.test.mjs  # 27 iddia, rc=0
npx tsc -b && npx tsc -p tsconfig.visual-tests.json  # rc=0 / rc=0
npx vitest run                            # 238 dosya / 2128 test passed
```

### 5. Commit'ler
- `1fd86841` — spec + PNG + `BR-FE-126` duzeltmesi + 9 dil + birim bekcisi
- `2076bc0c` — manifesto satiri (S6 gerekce + `producedFromSha`)
- `9686b587` — ClickUp kart id kaydi (`BR-QA-57` panoda `backlog` -> `complete`)

## Kararlar (BR-QA-57 turu)
- **Kaynagi olmayan ad uydurulmaz, olculmus sayi yazilir.** #28'de kuyruk ADI
  cozulemez; secenekler (a) yeni uc, (b) ekranin yetkisini genisletmek,
  (c) sayi. (a) yetkisiz supervizore kesin 403 attirirdi, (b) bir **yetki**
  kararidir — bir yerlestirme ayrintisi degil. (c) secildi.
- **Yetkiler TAM verildi ki taban EN DAR cubugu dondurmesin.** `monitor.whisper` +
  `monitor.barge` olmadan uc dugmeli cubuk hic cizilmezdi.

## Ogrenilen (BR-QA-57 turu)
- **Okunur sahte kimlik bir kusuru ortadan kaldirmaz, GIZLER.** Ayni kusur ucuncu
  kez ayni sebeple bulundu (#12 -> `BR-FE-124`, #28 -> `BR-FE-126`, #13 ->
  `BR-FE-127`). Fikstur kimligi **uretimdeki bicimde** tasimali.
- **Ilk kosuda otomatik yazilan taban TUZAKTIR.** Playwright eksik snapshot'i
  "writing actual" diyip yazdi; o dosya **kusurlu** hali tasiyordu. Silinip
  duzeltmeden sonra yeniden uretilmeseydi kapi kusuru "dogru" diye kilitlerdi.

## Acik kalanlar (BR-QA-57 turu)
- `BR-FE-127` — ayni kusurun **ucuncu kopyasi** #13 `LiveAgentsScreen.tsx:536`'da
  duruyor. `BR-QA-57`'nin kalemleri arasinda degildi; gorunmez borc olmasin diye
  kart acildi, **duzeltilmedi**.
- `S10` — piksel kapisi hala 3 aylik deneme suresinde (son tarih 2026-12-11).


### Koordinator turu — bosuna acik duran kartlar + RAISE NOTICE olcumu + SSRF sinif taramasi

#### 1. BOSUNA ACIK DURAN IKI KART — yeni bir hata sinifi

- **`BR-QA-86` ve `BR-7` kapandi**, ikisinde de **uzerinde kalan is YOKTU**. Isleri baska
  kartlara **devredilmisti** ve o kartlar **bitmisti**; devralan kapaninca kaynak kart
  **kendiliginden kapanmiyor**.
- **`BR-7`** kapanisini kendi metninde bir **sarta** baglamisti (*"`BR-QA-109` kapanmadan
  kapali sayilamaz"*). Sart **olculdu**, yaziyla degil kosan bekciyle:
  `dotnet test --filter "FullyQualifiedName~TenantLeakCoverage"` -> **Failed 0 / Passed 6**.
  (Kart yazildiginda o bekci ana dalda KIRMIZIYDI: `Failed 1, Passed 3`.)
- **`BR-QA-86`**'nin devrettigi madde `BR-QA-111`'deydi ve o kart 18 Eylul'de kapanmis:
  dort desen yalniz `TEMPLATE_ONLY_DENIED`'a eklenmis, `SQL_DENIED` dokunulmamis,
  `deploy/db/*.sql` govdeleri degismemis (bulgu 398 -> 398, dosya 168 -> 168).
- **SINIF TARANDI:** 81 acik karttan **5**'i devir dili tasiyor, 2'si baska karta atif
  yapiyor, ikisinin atiflari **karisik** (bir kismi acik). Yani **baska bosuna acik kart
  yok**. Tarama bir **aday listesi** uretir, karar uretmez -- her aday elle okundu.
- **KURAL (buradan cikan):** bir kart isini baska bir karta devrediyorsa devralanin kart
  kodu yazilir ve **kaynak kart AYNI TURDA kapatilir**.
- **Commit:** `b2b81a96`, `eaf0f7f6`

#### 2. `BR-DB-104` — `RAISE NOTICE` uretim yolunda GORUNMUYOR (KAPANDI)

Kart *"`Database.Migrate()` yolu olculmedi"* diyordu. **Iki katman ayri olculdu.**

- **(1) Npgsql katmani — gercek kosu** (tek kullanimlik `postgres:16-alpine`, Npgsql 10.0.0):

  ```
  MinimumLevel=Information (uretimin appsettings degeri) -> ReceivedNotice satiri YOK
  MinimumLevel=Debug -> [Debug] Npgsql.Connection (1301/ReceivedNotice): Received notice: ...
  KONTROL GRUBU (Notice olayina abone) -> her iki seviyede de 1 olay
  ```

  Yani bildirim **istemciye geliyor**; mesele gunluge yazilmasi ve seviyesi **Debug**.

- **TUZAK — kartin ilk yarisiyla BIREBIR AYNI SEKIL:** `Information`'da damga yine
  gorunuyor, ama `ReceivedNotice` olarak degil, `CommandExecutionCompleted` satirinin
  **SQL metnini yankilamasi** yuzunden. *"Ciktida `RAISE NOTICE` geciyor"* demek
  *"uyari goruldu"* demek **degildir**.

- **(2) Urun yolu — DAHA SERT:** `MaintenanceRunner.MigrateDatabase` (`:469-481`,
  cagiran `:330`) **taze bir `DbContextOptionsBuilder`** kurar ve yalniz `.UseNpgsql(...)`
  der; **`UseLoggerFactory` YOKTUR** ve depo genelinde o cagri **0 eslesme**
  (`src/` + `tests/`). Yani seviye Debug'a cekilse bile o satir **hicbir yere yazilmaz**.
  Sorun bir ayar degil, **baglanmamis bir boru**.

- **Sonuc:** `Karar #70 S70-4` (`BR-BE-185`) ve `BR-DB-101`'in `Down`'u operatorun uyariyi
  **okuyacagini** varsayiyor. O varsayim `psql`'de dogru, `dotnet ef`te yanlis,
  **uretimde imkansiz**.
- **Olcmedigim -> `BR-DB-108` acildi:** (a) `RAISE NOTICE`'a yaslanan kararlarin **sayimi**;
  (b) migrate baglamina gunlukcu baglanmali mi **karari** -- o baglam **bilerek ciplaktir**
  (interceptor'lar da yok, gerekce `:474-476`'da yazili), yani otomatik "evet" degil.
- **Commit:** `38a0c00e`

#### 3. `BR-SEC-21` (ajan) — gercek bir guvenlik kusuru cikti, ben SINIFINI taradim

- **Ajanin bulgusu:** Netgsm SMS istemcisi **ham `new HttpClient()`** kullaniyordu ->
  `AllowAutoRedirect` **varsayilan acik**, ve Netgsm arayuzunde **kullanici adi ile parola
  SORGU DIZESINDE**. Tek bir `302`, kimligin kendisini kapidan gecmemis bir hedefe tasirdi.
  Ayrica gonderim anindaki DNS cozumlemesi hic siniflandirilmiyordu (rebinding penceresi).
- Ajan guard'in evrenini **iki uctan** yazdi: kapidan gecen **7** yol, gecmeyen **3** yol
  (`AriClient`, `AriStasisApp`, `UnixSocketSystemAgent`) ve ucu de **bilincli** -- hedefleri
  yapilandirmadan gelir ve ic agdadir; kapidan gecirilseydi santral baglantisi
  `private`/`cgnat` ile **reddedilirdi**.
- **Ben sinifi taradim (koordinator):** `src/` altinda ham `new HttpClient(` **TAM OLARAK
  IKI** yerde -- duzeltilen Netgsm ve `AriClient.cs:46`. `new HttpClientHandler` /
  `new SocketsHttpHandler` yalniz `OutboundConnectGuard.cs:76`; `AddHttpClient` **0**.
- **`AriClient` OLCULDU, SIZDIRMIYOR:** kalibi birebir kurup gercek bir `302` kosuldu ->
  farkli kokene yonlendirmede `Authorization` **DUSUYOR**, ayni kokene de dusuyor.
- **ARAC SINAMASI:** ilk kosuda **kontrol grubu da bos geldi** ve sonucu **kabul etmedim**.
  Yonlendirmesiz dogrudan bir istek ekledim, baslik orada **gorundu**; ancak ondan sonra
  olcumu gecerli saydim.
- **AYIRT EDICI (asil ders):** Netgsm'de kimlik **sorgu dizesinde**ydi ve sorgu dizesi
  yonlendirme hedefine **TASINIR**; `AriClient`'ta **basliktadir** ve baslik **DUSER**.
  *"Ham `HttpClient`"* tek basina kusur **degildir**; **kimligin nerede tasindigiyla**
  birlesince kusurdur.
- **Kural:** kimligi sorgu dizesinde tasiyan her giden cagri, handler'i sertlestirilmis
  olmasa bile **`AllowAutoRedirect = false`** istemek zorundadir.
- **Olcmedigim:** `AriClient` `3xx` alinca yonlendirmeyi **izliyor** (kimliksiz de olsa) --
  bozuk bir santral pbxtr'a baska adrese **istek attirabilir**; tehdit degeri olculmedi.
- **Commit:** `6196c917`

#### 4. `BR-QA-57` (ajan) — gorsel kapi 6 tabana cikti, UCUNCU GUID kopyasi bulundu

- Kalem (3): **#28 agent eylem cubugu** (Dinle / Sufle / **Araya gir**) -- dugme kaymasi
  burada **yetki hatasina** donusur. Yetkiler **tam** verildi; yalniz `monitor.listen`
  verilseydi taban **en dar** cubugu dondururdu ve olculmek istenen sinif hic olculmezdi.
- **Ilk kosu kusur gosterdi (`BR-FE-126`):** uyelik satiri `queueIds.join(', ')` yaziyordu
  ve `queueIds` uretimde **GUID**; uc uyelikli agent'ta hucre **110 karakter** olup sayaci
  ve eylem cubugunu saga itiyordu -- yani kartin tarif ettigi kayma arizasini **besliyordu**.
- **Taban kusurlu haliyle DONDURULMADI:** Playwright eksik snapshot'i sessizce
  *"writing actual"* diye yazmisti; o dosya silindi ve duzeltmeden sonra yeniden uretildi.
- **Ad uydurulmadi:** #28'in yetki kumesinde kuyruk adini cozecek kaynak yok, o yuzden
  **sayi** yazildi ("Uyelik: 3 kuyruk"), 9 dilde (Arapca alti cogul sinifiyla).

#### 5. GUID KUSURU UCUNCU KEZ CIKTI — sinif bekciye baglaniyor

`BR-FE-124` (agent seridi) -> `BR-FE-126` (#28) -> `BR-FE-127` (#13). **Ucu de ayni sebeple
gizliydi:** fikstlerler `"satis"`/`"destek"` gibi **okunur sahte kimlikler** kullaniyordu;
uretimde o alan **GUID**. Kusur kodda degil, **fiksturun yalaninda** sakliydi. Uc kez
tekrarlayan bir kusuru dorduncu kez elle aramak kabul edilemez -- `BR-FE-127` frontend'e
**bekci sartiyla** verildi (fikstur ayagi + ekran ayagi, borc tavani kalibi, vacuity + mutasyon).

### Kararlar (bu tur)

- **Devredilen is bitince kaynak kart da kapatilir.** Aksi halde **bitmis is acik gorunur**
  ve her sayimda yeniden incelenir -- "kapali kartin icindeki is gorunmez olur"un tersi ve
  ayni derece maliyetli.
- **Bir olcumun kontrol grubu dustuyse SONUC KABUL EDILMEZ**, once arac sinanir.
- **"Ham istemci" tek basina kusur degildir**; kimligin nerede tasindigiyla birlesince
  kusurdur. Sinif taramasi bu ayrimi yapmadan "hepsi ayni" derdi.

### Acik kalanlar / sonraki adim

- Acik kart **80** (P0 3 / P1 37 / P2 34 / P3 6). ClickUp senkron.
- Kosan: `BR-SEC-26` (db-dev), `BR-SYS-60` (linux, santral sahiplik penceresi),
  `BR-FE-127` + GUID sinif bekcisi (frontend-dev-2), `BR-AST-114`/`115` (backend-dev-2).
- **Yayin hala kosulmadi** -- uc P0 ve acik kartlarin buyuk kismi ona bagli.

---

## Ek tur — `BR-SEC-26` KAPANDI (db-dev)

### Baglam

Kart dort kalemliydi; (1) ve (2) 2026-09-18'de, (3) aynı gün koordinatör tarafından
inmisti. Bu turda kalan **(4)** ve — asıl iş — **(2)'nin ADIYLA YAZILI kör noktası**
bitirildi. Kör nokta `CLAUDE.md` §4'te birebir yazılıydı:

> test **taze zincir** ölçer. **Canlı kurulumda ELLE verilmiş bir `GRANT` bu testten
> geçmez**; o hâl `02-guards.sql` içine bir `pbxtr_public_function_acl_guard()` +
> `MaintenanceRunner.GuardAsserts` satırı ister ve o iş **açıktır** (`BR-SEC-26`).

### Yapilanlar

#### 1. KURULU DB BEKÇİSİ — `pbxtr_public_function_acl_guard()`

- **Neden:** `20260919010000_PublicCrossTenantFunctionAclRevoke` iki `public.*`
  fonksiyondan `PUBLIC EXECUTE`'u kaldırdı. Bekçisiz bir `REVOKE` iki yoldan sessizce
  geri alınır: (a) imza değişiminde `DROP`+`CREATE` ACL'i sıfırlar, (b) operatör
  **kurulu veritabanında elle `GRANT EXECUTE ... TO PUBLIC`** verir. (b) yolunu
  taze-zincir testi **hiçbir zaman göremez**.
- **Ne yapıldı:** `deploy/db/02-guards.sql` içine iki fonksiyon yazıldı
  (`pbxtr_public_function_acl_guard()` + `pbxtr_assert_public_function_acl_guard()`),
  `MaintenanceRunner.GuardAsserts`'e kaydedildi → **her açılışta** koşuyor.
  Beş ayak: `PUBLIC_EXECUTE_RESTORED`, `LEDGER_UNKNOWN_MEMBER`,
  `LEDGER_MISSING_MEMBER`, **vacuity** `SCAN_EMPTY` (tarama < 3 satır) ve
  **vacuity** `SCAN_TOO_BROAD` (kontrol grubu `pbxtr_index_guard()` taramaya girerse).
  Filtre bilerek dar: *"her public fonksiyon"* değil, **fonksiyon düzeyi `app.*` SET
  taşıyan ve `RETURNS trigger` OLMAYAN** fonksiyonlar. Defter CLAUDE.md §4 ile birebir:
  tam olarak iki ad.
- **Dokunulan dosyalar:** `deploy/db/02-guards.sql`,
  `src/Pbxtr.Infrastructure/Persistence/Seeding/MaintenanceRunner.cs`

#### 2. (4) — `01-rls-template.sql`'deki YANLIŞ cümle düzeltildi

- **Neden:** `app_is_cross_tenant()`'ın `COMMENT`'i *"SADECE `tenant.manage` + açık
  `[CrossTenant]` işareti ile SET LOCAL edilir ve HER SEFERİNDE audit_log'a yazılır"*
  diyordu. Sunucuda ölçülerek yanlışlandı (ayrıştırıcı ölçüm, tek işlem + ROLLBACK):
  A=0 doğrudan okuma, **B=0 aynı gövde SET'siz sarmalayıcı (kontrol grubu)**, C=5 aynı
  gövde + `SET "app.cross_tenant"='on'`, D=5 sahip rolü gerçek toplam. B→C arasındaki
  **tek değişken fonksiyon düzeyi `SET`**tir ve o hem yetki kontrolünü hem denetim
  yazımını atlar.
- **Ne yapıldı:** Eski metin **silinmedi**; üstüne ölçümü taşıyan bir blok yazıldı ve
  `COMMENT` gövdesi düzeltildi.
- **Dokunulan dosya:** `deploy/db/01-rls-template.sql`

#### 3. TAZELEME MIGRATION'I — şarttı, yazıldı

- **Neden:** EF uygulanmış bir migration'ı bir daha koşmaz. `02`'yi en son uygulayan
  `20260919050000_TenantsSysUpdateWriteMark`'tı. Yeni tazeleme yazılmazsa bekçi taze
  kurulumda gelir, **yükseltilen veritabanında gelmez** — ve fark sessiz değil
  **FAIL-CLOSED**: açılış kapısı `pbxtr_assert_public_function_acl_guard()` çağırır,
  fonksiyon yoksa 42883 → **uygulama hiç açılmaz**. `01` de uygulanır çünkü
  **`COMMENT` KATALOGDA yaşar**: kaynak dosyayı düzeltmek kurulu DB'deki metni
  değiştirmez.
- **Bedel yazılı:** `01`'in koşumu `tenants` + `call_attempts` üzerinde ACCESS EXCLUSIVE
  alır ve `call-permission` FAIL-CLOSED olduğu için o pencerede **giden arama durur**;
  bu yüzden `SET LOCAL lock_timeout = '5s'` tavanı kondu ve 55P03 hâli bilinçli
  (yayın durur, retry döngüsü yok).
- **Yeni dosya:**
  `src/Pbxtr.Infrastructure/Persistence/Migrations/20260920010000_GuardsTemplateRefreshPublicFunctionAcl.cs`

#### 4. Ölçüm

```bash
dotnet test tests/Pbxtr.Integration.Tests/... --filter "FullyQualifiedName~PublicFunctionAclRuntimeGuardTests"
dotnet test tests/Pbxtr.Integration.Tests/... --filter "FullyQualifiedName~PublicCrossTenantFunctionAclGuardTests"
dotnet test tests/Pbxtr.Architecture.Tests/Pbxtr.Architecture.Tests.csproj
python3 deploy/migration-compatibility-guard.py            # kapi_07
bash deploy/sablon-refresh-kapisi.sh                       # kapi_71 (K5+K6)
```

| Ölçüm | Sonuç |
|---|---|
| `PublicFunctionAclRuntimeGuardTests` (YENİ) | **7/7** |
| `PublicCrossTenantFunctionAclGuardTests` | **4/4** |
| `MigrationStartupGateTests` | 2/2 |
| `TemplateRefreshReachesUpgradedDatabaseTests` | 2/2 |
| `InitialSchemaMigrationTests` / `MigrationLoginFlowTests` | 1/1 + 1/1 |
| `Pbxtr.Architecture.Tests` | **755/755** |
| `kapi_07` | rc=0 (onay satırı eklendikten sonra) |
| `kapi_71` | TEMİZ — `[K6: gövde …, d8b19ce6 eklendiğinde de aynıydı]` |

**MUTASYON — ürün tarafında, `--no-incremental` ile yeniden derlenerek:**

- **M1** sızıntı ayağı `AND false` ile etkisizleştirildi → kurulu DB'de elle `GRANT`
  verilince bekçi **sustu** → ilgili test **KIRMIZI** (`Collection: []`).
- **M2** vacuity eşiği `< 3` → `< 0` → `SCAN_EMPTY` testi **KIRMIZI**
  (ilginç yan bulgu: `LEDGER_MISSING_MEMBER` yine de ateşledi — ayaklar birbirini
  örtüyor, yani bekçi tek ayaklı değil).
- İkisi de geri alındı, yeniden derlendi, **11/11 yeşil** ve `02-guards.sql` sha256'sı
  defterdeki değerle **birebir** aynı (`44597d9c…`) — geri alma **bayt düzeyinde**
  doğrulandı, DLL damgasına güvenilmedi.

**Ölçemedim (açıkça):**

- `deploy/db/ci-check.sh` yerelde koşmadı — `psql` yok (rc=127). Aynı SQL gerçek
  PostgreSQL'e karşı entegrasyon testlerinden geçti.
- `deploy/ci/rls-predicate-mirror-guard.py` **KIRMIZI ama benim değil**: `git stash`
  ile ölçüldü, değişiklikten **önce de** aynı tek bulguyla kırmızıydı
  (`01:1070` → bugün `01:1106`, satır kayması eklediğim bloktan). Kayıtlı `BR-QA-99`.

- **Commit:** `d8b19ce6` — BR-SEC-26 KAPANDI (bekçi + migration + defterler)
- **Commit:** `262f162d` — durum hücresi kelime düzeltmesi (aşağıdaki karar)

### Kararlar

- **`02-guards.sql` gövdesine dokunan her iş bir tazeleme migration'ı borçludur** ve
  `01` de dokunuluyorsa bedeli (`call-permission` penceresi) migration belgesinde
  **adıyla** yazılır. "Küçük bir COMMENT düzeltmesi" diye geçilemez: `COMMENT`
  katalogda yaşar ve kurulu DB'ye ancak tazeleme ile ulaşır.
- **Bir bekçinin "gördüğü" kadar "görmediği" de yazılır.** Taze-zincir testi ile
  açılış-kapısı bekçisi **aynı sorunun iki ayrı ayağıdır**; biri diğerinin yerine
  geçmez. Kartın kalan işi tam olarak bu ayrımdı.
- **Durum hücresinde "bitti" kelimesi tuzaktır.** `durumEsle` bilerek muhafazakârdır:
  metin `bitti` içerip `Bitti` ile **başlamıyorsa** kart kısmi sayılır → `in progress`.
  Güncel parçadaki *"bu turda bitti"* yüzünden **kapanmış bir P1 kart panoda AÇIK**
  görünüyordu. Kapanış hücresi yazarken `Kapandı`/`Bitti` ile **başla** ve gövdede
  o kelimeleri **kullanma**.

### Açık kalanlar / sonraki adım

- `BR-SEC-26` listede **kapalı**; ClickUp doğrulandı (`fark olan kart: 0`).
- **`BR-QA-99`** (`rls-predicate-mirror-guard` `01:1106` bayat yorum) hâlâ kırmızı —
  bu turda dokunulmadı, sahibi ayrı kart.
- `02-guards.sql` içine **üçüncü** bir `app.cross_tenant` SET'li doğrudan çağrılabilir
  fonksiyon eklemek artık **iki yerden birden** kırmızı yakar (SQL bekçisi +
  entegrasyon testi) — bu bilinçlidir, CLAUDE.md §4: *listeye üçüncü bir fonksiyon
  eklemek bir GÜVENLİK KARARIDIR*.


---

## KAPANIS — 2026-09-20 (kota siniri, koordinator)

### Nerede kaldik

- **Acik kart: 79** (P0 3 / P1 36 / P2 34 / P3 6). Oturum **94** ile basladi.
- Toplam kart **764**. **ClickUp senkron:** `fark olan kart: 0, izde olmayan: 0`.
- 19-20 Eylul'de **36 commit** basliginda "KAPANDI" tasiyor.
- Depo **push edilmis** durumda; koordinatorun hicbir isi yerelde kalmadi.

### YARIM KALAN — DORT AJAN KOSARKEN KESILDI

Kesildigi anda dort ajan **commit edilmemis** isle calisma agacindaydi. **Onlarin
dosyalarini commit ETMEDIM** -- yarim isi ana dala itmek tam olarak yasakli desendir
([[ajan-calisirken-git-add-a-yapma]]).

| Kart | Ajan | Agactaki izi |
|---|---|---|
| `BR-SYS-60` (kanarya + frozen kip) | linux-uzmani | `deploy/pbxtr-confd-dugum.sh` |
| `BR-DB-44` (provisioning boslugu defteri) | db-dev | `deploy/db/02-guards.sql`, `partial-unique-indexes.expected`, `sys-functions.expected` |
| `BR-AST-114` / `BR-AST-115` (fail-back) | backend-dev-2 | `ConfigRenderer.cs`, `SlaAggregationJob.cs`, `TelephonyEventPipeline.cs`, `AgentEndpoints.cs`, `RedisLiveOperationsView.cs` |
| `BR-FE-127` + GUID sinif bekcisi | frontend-dev-2 | `src/Pbxtr.Web/.../i18n/messages/*.json` (9 dil) |

**SONRAKI TURUN ILK ISI:** `git status --porcelain` oku, bu dort kumeyi **sahibine gore
ayir** ve her birini **kendi kartiyla** commit et. Ayirmadan toplu commit **yapma** --
kime ait oldugu bir daha okunamaz.

### Bu iki gunun tekrarlayan uc dersi

1. **Bir kart "X YOK" diyorsa once EVRENINI sor.** `BR-SYS-122` ikinci kopyayi uc yerde
   aradi, `audit_log`'a bakmadi; kopya oradaydi ve **25 gun** tasiyordu. `BR-QA-51`,
   `BR-DB-105` ve `BR-AST-119`(a) ayni sekilde eksik evrende olculmustu. Eksik evrende
   yapilan olcum **dogru olcum gibi gorunur**.
2. **Bir olcumun kontrol grubu dustuyse SONUC KABUL EDILMEZ.** `AriClient` yonlendirme
   olcumunde kontrol grubu da bos geldi; araci ayrica sinadim (yonlendirmesiz istek) ve
   ancak ondan sonra sonucu gecerli saydim. Ayni sekilde `BR-QA-99`'da M13 `bulgu=0`
   dondu ve bu **benim capamin yanlis oldugunu** soyledi.
3. **Devredilen is bitince KAYNAK KART DA kapatilir.** `BR-QA-86` ve `BR-7` bosuna acikti;
   bitmis is acik gorununce her sayimda yeniden incelenir -- "kapali kartin icindeki is
   gorunmez olur"un tersi ve ayni derece maliyetli.

### Acik kalan tek buyuk tikac: YAYIN

Acik 79 kartin buyuk kismi ve **uc P0'in tamami** (`BR-DB-91`, `BR-SYS-117`, `BR-BE-150`)
yayin penceresinde olculmeyi bekliyor. Sunucudaki imaj hala `demo-ea567d11bb2e`
(commit `ea567d11`, 2026-09-15). Yayin hatti 3. kosuda **bellek yetersizliginden**
oldurulmustu ve kendiligimden yeniden baslatmadim.

**Yayin oncesi bugun kapatilan iki gercek engel:**
- `BR-SYS-125` — SPA asamasi `RingGroup.cs`'i kopyalamiyordu; `docker build`
  **ENOENT** ile duserdi, yani **yayin imaji derlenemezdi**.
- `BR-QA-99` — ayna bekcisi ana dalda **KIRMIZIYDI** (tarihce muafiyeti ile kapatildi,
  mutasyonla kilitli).

Yani yayin **artik bu iki hatayla dusmeyecek**.

---

## BR-FE-127 — #13 uyelik satiri ham GUID yaziyordu + SINIF BEKCISI (frontend-dev-2)

### Baglam

`BR-FE-124` (#12 agent seridi) ve `BR-FE-126` (#28 MonitorScreen) gorsel taban ilk
kosusunda bulunmustu; ucuncusu (`#13 LiveAgentsScreen.tsx:536`) ELLE fark edilmisti.
Ucu de ayni sebeple gizliydi: fiksturler `'satis'` / `'destek'` gibi **okunur sahte
kimlikler** kullaniyordu, oysa uretimde `LiveAgent.queueIds` **GUID**'dir
(`RedisLiveOperationsView.cs:479`). Yani kusur kodda degil, **fiksturun yalaninda**
sakliydi ve hicbir yesil test onu gormedi.

### 1. Duzeltme

- **Neden:** `agent.queueIds.join(', ')` gercek veriyle satira 36 karakterlik kimlikler
  basardi; `BR-FE-126`'da olculmustu ki uc uyelikli agent'ta hucre **110 karakter** olup
  eylem cubugunu saga itiyor.
- **Ne yapildi:** satir `t('liveAgents.membershipCount.one', { count: agent.queueIds.length })`
  oldu. **Ad UYDURULMADI ve bu bir olcumun sonucudur:** #12 adi kendi `/live/queues`
  yanitindan cozer; `screens.generated.ts:61` #13'u `permission: 'live.agent.read'`,
  `permissionsAll: []` ile tanimlar ve `live.queue.read` **ISTEMEZ** -> adi cozecek kaynak
  yok -> #28 kalibi (SAYI). Yeni anahtar **9 dilde** (Arapca alti cogul sinifi). Eski
  `liveAgents.queueMembership` anahtari **dokuz dilden de silindi** -- kalsaydi "kimlikleri
  bas" bicimindeki sablon bir sonraki ekranda geri kullanilirdi.
- **Dokunulan dosyalar:** `src/Pbxtr.Web/src/app/screens/live/LiveAgentsScreen.tsx`,
  `.../LiveAgentsScreen.test.tsx`, `src/Pbxtr.Web/src/app/i18n/messages/*.json` (9),
  `doc/prototip-urun-farklari.md` (FID-SCR-13 / 13.1 satir 5, **BILINCLI**).

### 2. ASIL IS — sinif bir bekciye baglandi

- **Neden:** uc kez tekrarlayan bir kusuru dorduncu kez elle aramak kabul edilemez.
- **Ne yapildi:** `src/Pbxtr.Web/src/app/screens/rawIdentityRender.test.ts` (YENI, 6 iddia).
  Kaynak metnini tarar; GUID'i degil **GUID'i YAZAN IFADEYI** arar. Iki dal: JSX ifadesi
  (`{...chain.field...}`, `=` ile baslamayan sus parantezi) ve `t()` enterpolasyon
  parametresi. Sablon enterpolasyonu (`${row.actorUserId}`) da kapsamda.
- **ONCE MEVCUT VERI OLCULDU** (kapi kurmadan once):
  - kimlik alani evreni **uydurulmadi**: .NET `Guid` property adlari (**169**) kesisim
    FE `api/**` `string` alan adlari (**195**) = **25**; `id` + `idempotencyKey`
    gerekceyle cikti -> **23 alan**.
  - **296 ekran `.tsx`** tarandi -> ham kimlik cizen **7 ifade**: 2 IZINLI (`AuditScreen`
    -- denetim satirinin URUNU ham kimliktir), 5 **BORC** -> `BR-FE-128` (#09 QueuesTab),
    `BR-FE-129` (#14 LiveAlarmsScreen), `BR-FE-130` (SilenceThresholdPanel),
    `BR-FE-131` (CommandPaletteScreen x2).
  - Defter **ciplak sayi tavani DEGIL, KIMLIKLI**: defterde olmayan yeni cizim KIRMIZI,
    defterde olup kodda kalmayan satir da KIRMIZI (defter sapmasi).
- **FIKSTUR AYAGI OLCULDU VE KURULMADI (gerekce yazili):** 241 test/fikstur dosyasinda
  **19 GUID bicimli / 571 okunur sahte** literal (`id=226 userId=101 activeTenantId=66
  homeTenantId=46 tenantId=25 dealerId=19 queueId=19 ...`). 571'lik tavan **VACUOUS**
  olurdu -- `BR-FE-127`'nin kendi fiksturu o 571'in **icindedir**, yani tavan kapatmak
  icin yazildigi kusuru gecirirdi. Ayrica evrenin yarisi (`id`) mesru bicimde GUID
  degildir. Sinif bunun yerine **CIKTI tarafindan** kapatildi (GERCEK GUID fikstur +
  "ciktida hicbir GUID deseni yok"). Dar fikstur ayagi = `BR-FE-132` (bugun 29 literal).
- **BEKCI KENDINI DE OLCTU:** ilk genis taslak `MonitorScreen:360`'i ve
  `ReportSchedulesPane:163`'u -- yani sinifin **EN OZENLI** cozumlerini
  (`queueIds.length`) -- kusur sayiyordu. Bir bekci dogru cozumu kusur sayiyorsa
  **deseni yanlistir**; `` siniri (`queueId` deseni `queueIds` icinde esliyordu) +
  `.length`/`===`/`:`/`;` elemesi eklendi. `t('silence.targetId')` ve
  `errors['filter.queueIds']` yanlis pozitifleri icin **dize govdeleri bosaltildi**.
- **VACUITY AYAGI:** evren > 200 dosya, alan sayisi, defter dolulugu + dedektorun
  **pozitif VE negatif** oz-testi (`join()` -> 1 bulgu; `.length` / `key={}` / `===` -> 0).

### 3. Mutasyon

| Mutasyon | Bekci | Birim testi |
|---|---|---|
| izole (anahtar AYNI, yalniz ifade `join()`) | **2 failed / 4 passed** | **1 failed / 30 passed** |
| geri alindi | 6 passed | 31 passed (birlikte **37 passed**) |
| tam (anahtar da geri) | — | **29 failed / 8 passed** |

Ikisi **bagimsiz** yakaladi: bekci KAYNAGI, birim testi CIKTIYI olcer.

### 4. Olcum

```bash
npx tsc -b                                  # rc=0
npx tsc -p tsconfig.visual-tests.json       # rc=0
npx vitest run                              # 239 dosya / 2136 test passed, rc=0  (once 238/2128)
node scripts/verify-visual-baselines.mjs    # 6 taban, rc=0
node scripts/verify-visual-baselines.test.mjs  # 27 iddia
node yonetim/arac/homoglif-tara.js          # KARISIK YAZILI KELIME: 0
node yonetim/arac/regex-turkce-sinir-tara.js # RISKLI: 0
```

### Kararlar

- **Bekci `.cs` OKUMAZ.** Alan listesi olculup **sabit** yazildi. `.cs` okuyan bir uretec
  Dockerfile'in SPA asamasina `COPY` ister; unutulursa **yayin imaji ENOENT ile duser**
  (`BR-SYS-125` sinifi) ve yerel `tsc`/`vitest` bunu **gormez**.
- **Ekran ayagi kuruldu, fikstur ayagi kurulmadi** -- ikisi farkli sey yakalar ve biri
  digerini kapsamaz; kurulmayanin gerekcesi **olculmus sayiyla** karta ve test dosyasina
  yazildi (`BR-FE-132`).
- **Ad uydurulmaz.** Kaynak yoksa SAYI yazilir; bu #28'de verilen kararin aynisidir.

### Commit'ler

- `09b60111` — BR-FE-127 KAPANDI: #13 uyelik satiri ham GUID yaziyordu + SINIF BEKCISI kuruldu
- `ab8fd800` — ClickUp: BR-FE-128..BR-FE-132 kart id kaydi
- (backlog satirlari koordinatorun `4615632b` commit'iyle gitti -- paylasilan dosya)

### Acik kalanlar

`BR-FE-128` · `BR-FE-129` · `BR-FE-130` · `BR-FE-131` (ayni sinifin dorduncu-yedinci
kopyalari, bekciyle bulundu) ve `BR-FE-132` (dar fikstur ayagi).
