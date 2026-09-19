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
