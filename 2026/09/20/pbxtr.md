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
