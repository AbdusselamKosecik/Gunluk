# pbxtr — 2026-09-17

## Bağlam

Dokuzuncu turun devamı: `/goal Kalan tum maddeleri bitir` altında backlog'dan kalan
kartlar sırayla kapatılıyor. Canlı sunucuya erişim bu oturumda **salt-okunur**;
gün 09-17'ye `BR-FE-84` ile giriliyor.

## Yapılanlar

### 1. `BR-FE-84` — kural reddi artık **gerekçesini söylüyor**

- **Neden:** `#47`/`#48` kullanıcı ekranlarında sunucunun `meta.rule` ile gönderdiği
  bazı redler ekrana **genel "İşlem tamamlanamadı"** olarak düşüyordu. Kullanıcı neden
  reddedildiğini göremediği için **aynı formu tekrar gönderiyordu.**
- **Ölçüm (kartın öncülü doğrulandı ve genişledi):** `userErrorRule`
  (`usersApi.ts:541-544`) `meta.rule`'u **kod anahtarından ÖNCE** okuyor. Dolayısıyla
  `RULE_KEY` içindeki `PERMISSION_ESCALATION` / `TENANT_SCOPE_DENIED` **kod**
  anahtarlarına, kural taşıyan bir redde **hiç ulaşılmıyor.** Sunucu tarafı
  (`src/Pbxtr.Api/Modules/Access/UserAdminEndpoints.cs:2005-2019`, `RuleOf`) **11
  adlandırılmış kural** + `denied` üretiyor; istemcide **üçü eksikti**:
  `permission_escalation`, `scope_denied`, `role_not_delegated`.
- **Ne yapıldı:**
  - `RULE_KEY`'e üç satır eklendi. İlk ikisi **mevcut metinleri paylaşır** — biri HTTP
    kodu, öteki kural adıdır; aynı redde iki farklı cümle yazmak yanlış olurdu.
    Üçüncüsü için yeni `usrE.roleNotDelegated` metni **9 dile** eklendi.
  - **`denied` bilerek eşlenmedi.** O sunucunun `_ =>` dalıdır, yani *adlandırılmamış
    red*; ona özel bir cümle yazmak **ölçülmemiş bir gerekçeyi ölçülmüş gibi**
    gösterirdi. Metin genel yetki cümlesine düşer ve bu bir **kontrol grubu testiyle**
    kilitlendi.
  - Yeni **parite bekçisi** `src/app/screens/users/userRuleParity.test.ts`: sunucunun
    `RuleOf` gövdesini **C# kaynağından** okur (emsal: `auditActionParity.test.ts`) ve
    her adlandırılmış kuralın istemcide bir metni olduğunu ölçer. Ters yön bilerek
    **gevşektir** ("ad sunucu dosyasında hiç geçmiyor"), çünkü kural adları tek yerden
    gelmiyor: doğrulama kuralları (`invalid_login`, `extension_taken` …) aynı dosyada
    ama `RuleOf` dışında, `Meta("…")` ile üretiliyor — ilk sıkı sürüm bu yüzden
    **dokuz yanlış bulgu** verdi.
  - `vitest.config.ts` → `server.fs.allow` yalnızca `../Pbxtr.Api/Modules/Access` ile
    genişletildi (`..` yazılmadı; geliştirme sunucusu C# ağacını servis edemesin).
- **Dokunulan dosyalar:** `src/Pbxtr.Web/src/app/screens/users/usersApi.ts`,
  `…/usersApi.test.ts`, `…/userRuleParity.test.ts` (yeni),
  `src/Pbxtr.Web/vitest.config.ts`, `src/app/i18n/messages/*.json` (9 dil),
  `yonetim/backlog.md`
- **Komutlar:**
  ```bash
  npx vitest run src/app/screens/users/usersApi.test.ts src/app/screens/users/userRuleParity.test.ts
  npm run typecheck && npx vitest run
  ```
- **Sonuç / doğrulama:** **Mutasyon 3/3 kırmızı** — üç eşlemenin her biri tek tek
  silindiğinde **ikişer** test kırmızı (tam metin eşitliği **ve** parite bekçisi),
  geri alınınca kontrol yeşil. Tam takım **214 dosya / 1934 test yeşil**, `tsc -b` temiz.
- **Commit:** `38ec93b9` — BR-FE-84 bitti: kural reddi ARTIK gerekcesini soyluyor

### 2. `BR-FE-69` — kuyruk satırı artık **tenant geneli** bir sayı çizmiyor

- **Neden:** `#12 Canlı Kuyruklar`da agent çifti `müsait/açık` olarak **kuyruk satırında**
  çiziliyordu. Sağ yan (`agentsOnline`) **tenant genelidir** —
  `RedisLiveOperationsView` aynı yerel değişkeni hem tenant özetine hem **her** kuyruk
  satırına yazar. Sonuç: her satırda **aynı "4"** duruyor ve süpervizör bunu *"bu kuyruğun
  4 agenti var"* diye okuyordu.
- **Karar:** kart iki seçenek sunuyordu (satırdan çıkar **veya** görsel olarak ayır).
  **Çıkarma seçildi:** "tenant geneli" diye küçük harfle not düşmek, aynı yanlış okumayı
  daha küçük yazmaktan başka bir şey olmazdı. Sayı **silinmedi**, yeri değişti — tenant
  geneli çift **üst şeritte** `müsait / açık` notuyla zaten duruyor.
- **Ne yapıldı:** satırda yalnızca kuyruğa özel `agentsAvailable` kaldı (`countText`);
  üç değerli okuma korundu (`null` → "—", `0` → `0` — BL-QA-41). Etiket dokuz dilde
  `müsait agent` olarak yeniden yazıldı (yeni anahtar açılmadı; mevcut anahtar artık
  doğru şeyi adlandırıyor, böylece ölü anahtar da birikmedi).
- **Dokunulan dosyalar:** `src/app/screens/live/LiveQueuesScreen.tsx`,
  `…/LiveQueuesFidelity.test.tsx`, `src/app/i18n/messages/*.json` (9 dil),
  `yonetim/backlog.md`
- **Sonuç / doğrulama:** anti-vacuity **iki kuyrukla** kuruldu: müsait sayıları
  **farklı** (2 ve 5), tenant geneli **aynı** (4) → satırda "4" görünüyorsa yalnızca eski
  çiftin kalıntısı olarak görünebilir. Çift geri konulduğunda **3 kırmızı**, geri alınınca
  kontrol yeşil. Tam takım **1936/1936 yeşil**, `tsc -b` temiz.
- **Commit:** `2720648d`

### 3. `BR-QA-54` — Türkçe regex sınırı tarayıcısı artık **bir kapı**

- **Neden:** JS'te `\b` sınırı yalnız `[A-Za-z0-9_]` üzerinden tanımlıdır; Türkçe harfle
  biten bir sözcüğün sonunda sınır **üretilmez** ve kalıp **hiç eşleşmez**. Arıza sessizdir —
  çıktı `0` olur, yani kusur bir hata gibi değil **temiz bir sonuç** gibi görünür. Tarayıcı
  2026-09-10'da yazılmıştı ama **hiçbir kapıya bağlı değildi**: koşmayan kapı bulgu değildir.
- **Ne yapıldı:** `deploy/yerel-kapilar.sh` → yeni **`kapi_56`**. Araç önce **her zaman 0 ile
  çıkıyordu**; artık bulguda 1 döner ve içinde üç ölçüm taşır: **vacuity eşiği** (dosya ≥ 400,
  kalıp ≥ 1000 — bugün 621/1779), **POZİTİF** kontrol (Türkçe harfe bitişik sınır
  yakalanmalı) ve **NEGATİF** kontrol (ASCII sınır işaretlenmemeli). Kapı bu üç satırı **ayrı
  ayrı** okur; `RISKLI: 0` satırına tek başına güvenmez. Aracın bilinen sınırı (regex
  literallerini kaba bir kalıpla ayıklar, `new RegExp(değişken)` görmez) kapı metnine yazıldı.
- **Kartın diğer iki kalemi ölçüldü ve ZATEN BAĞLIYDI** — kart bayattı:
  `kart-atif-dogrula.js` **`kapi_43`** içinde koşuyor; `dotnet format --verify-no-changes`
  **`deploy/yerel-yayin.sh:292`**'de, backend adımının içinde.
- **Format kapısı bilerek TAŞINMADI:** kapı konteyneri `ubuntu:24.04` ve .NET SDK yok —
  taşınsaydı her koşuda *"ölçemedi"* derdi, yani çalışan bir kapıyı **işlevsiz** yapardı.
- **Dokunulan dosyalar:** `deploy/yerel-kapilar.sh`, `yonetim/arac/regex-turkce-sinir-tara.js`,
  `yonetim/backlog.md`
- **Sonuç / doğrulama:** **mutasyon 3/3 kırmızı** — (1) gerçek bir dosyaya tuzak kalıp
  konuldu → kapı kırmızı, aday listesi basıldı; (2) bitişiklik şartı kaldırıldı (gürültülü
  tarayıcı) → **NEGATİF kontrol** kaldı; (3) eşik çökmüş tarama gibi ayarlandı → **VACUITY**
  kaldı. Üçü de geri alındı, kontrol yeşil (`rc=0`).
- **Commit:** `58ba5c7f`

### 4. `BR-QA-64` — ortak graf üç kapıyı **tek kapıya indirmedi** (ölçüldü)

- **Kartın kalıcı işi zaten inmişti:** ithal grafiği `BR-QA-70` ile bir kez kurulup
  paylaşılıyor (`mockGraph.ts` içinde `memoBySource` / `GRAPH_CACHE` / `RESOLVE_CACHE`),
  geçici `120_000 ms` muafiyeti geri alınmış. **Bugün ölçüldü:** en ağır kapı testi
  **297 ms**, dosya toplamı **< 1 sn** — kart "20 sn eşiğinin %95'i" diyordu.
- **Kalan iş kartın kendi vacuity uyarısıydı:** *"ortak graf, üç kapıyı sessizce tek kapıya
  indirmenin en kolay yoludur"* — ve bu çöküş **görünmez** olurdu, üç yeşil satır aynen
  kalırdı.
- **Ne yapıldı:** yeni test ayrımı **ölçüyor**. Aynı dosyaya iki mutasyon uygulanır ve her
  seferinde **yalnızca bir** kural kırmızı olur: ölü ezilen isim → yalnız `deadOverrides`;
  `...actual` yayılımının silinmesi → yalnız `unspreadGaps`. Üçüncü kural (`arityGaps`) için
  iddia **"sıfır" değil "DEĞİŞMEDİ"**: o dosyada dondurulmuş iki bilinen daralma var ve
  cebren sıfır yazmak testi kırmızı doğar bir hâle sokardı.
- **Dokunulan dosyalar:** `src/test/viMockTargets.test.ts`, `yonetim/backlog.md`
- **Sonuç / doğrulama:** testin kendisi **mutasyonla** doğrulandı — birinci kural
  susturulunca **2 kırmızı**; ikinci kural birincinin cevabını döndürünce (çökme senaryosu)
  **3 kırmızı**; kontrol yeşil. Tam takım **1937/1937**, `tsc -b` temiz.
- **İki tuzak bu turda ısırdı ve ikisi de ölçümle bulundu:** (1) düz dize ile satır eşleme
  CRLF'te **sessizce hiçbir şey değiştirmedi** → mutasyon uygulanmamış olduğu hâlde test
  kırmızı verdi (regex'e çevrildi, emsal aynı dosyadaki eski test); (2) girinti tahmini
  (4 boşluk) tuttu sanıldı, gerçekte 2'ydi.
- **Commit:** `c5475d58`

### 5. `BR-DOC-16` — sessizlik alarmının iki **bilinçli** asimetrisi yazıldı

- **Neden:** Karar #47 iki asimetriyi bilinçli kabul edip `doc/prototip-urun-farklari.md`'ye
  yazılmasını istemişti (ADR-016 **AÇIK-7**); dosyada sessizlik alarmına ait **tek satır
  yoktu**. Orada yazılı olmayan bir sapma "unutulmuş"tur.
- **Ne yazıldı:** (i) takvim **kural başına seçilemez** — yalnız `did` kendi profilini
  (`dids.working_hour_profile_id`), **kuyruk ve zil grubu tenant varsayılanını** kullanır
  (`SilenceSamplerJob.cs:457-470`); (ii) `silence_*` tablolarında **bayi kapsamı yok**, RLS
  yalnız `_tenant_isolation` taşır → bayi kullanıcısı `#14`'te sessizlik alarmlarını görmez.
- **Kayıtlar ADR'nin cümlesini tekrar etmiyor, gerekçeyi taşıyor:** kuyruğun kendi çalışma
  saati kavramı **üründe yoktur** (kolon açmak, karşılığı olmayan bir ayar eklemek olurdu);
  bayi dalı bir **okuma genişlemesidir** ve ayrı bir yetki kararı ister (§4 `dealers` notu:
  izolasyon bayide ilişki üzerinden kurulur).
- **Ayrıca kayda geçen ayrım:** *"varsayılan takvim"* ≠ *"takvimi uydurmak"* — snapshot yoksa
  ya da saat dilimi çözülemezse ölçüm `null` olur, sessizce UTC'ye düşülmez (`:472-490`).
- **Dokunulan dosyalar:** `doc/prototip-urun-farklari.md`,
  `doc/mimari/ADR-016-kuyruk-sessizligi-alarmi.md` (AÇIK-7'ye **KAPANDI** notu),
  `yonetim/backlog.md`
- **Sonuç / doğrulama:** vacuity kapısı yok (belge işi). Durum **iki yerde tutulmuyor**: ADR
  geri işaret ediyor, içerik tek dosyada.
- **Commit:** `59c6b482`

### 6. `BR-QA-85` — çapraz kip reddi artık **gerçek PostgreSQL'de** ölçülüyor

- **Neden:** `BR-BE-152` turunda iki boşluk kalmıştı. (i) Çapraz kipte yazım reddinin
  **denetim satırı** yalnızca **bellek içi yakalayıcı bir sink** ile ölçülüyordu — yani
  *"kayıt kuyruğa girdi"* ölçülüyordu, *"tabloya indi"* değil. Güvenlik incelemesinin okuduğu
  şey ise **o tablodur**. (ii) `03-smoke` TEST 10/10b yalnız **okuma** ölçüyordu; çapraz
  kipte **yazmanın** DB katmanında ne yaptığı hiçbir yerde kayıtlı değildi.
- **Ne yapıldı (1):** yeni entegrasyon testi 403'ten sonra `audit_log`'ta
  `tenant.crosstenant.write.denied` satırını **artış** olarak ölçüyor ve `result='denied'`
  doğruluyor — enum adı (`Forbidden`) değil, `AuditLogWriter.ResultOf` sözleşmesi.
- **Ölçüm sırasında iki şey öğrenildi ve teste yazıldı:** fikstür arka plan işlerini **DI'dan
  kaldırıyor** (teşhis: kuyrukta `pending=3` kayıt bekliyordu, `audit_log` boştu) — bu yüzden
  **üretimin kendi `AuditDrainService` sınıfı**, üretimdeki bağımlılıklarıyla elle kuruluyor;
  davranış ikizi yazılmadı ("test ikizi üretimden müsamahakâr" dersi). Ayrıca başarısızlık
  mesajı artık kuyruk sayaçlarını (`dropped/repaired/pending`) basıyor: *"yazılmadı"* ile
  *"kuyruğa hiç girmedi"* ayrılabiliyor.
- **Ne yapıldı (2):** `03-smoke` **TEST 10c** — çapraz kipte `UPDATE`/`INSERT`'in RLS
  tarafından **reddedilmediği** (CLAUDE.md §4 / Karar #65 Ş65-4.5) kayda bağlandı, **kontrol
  grubuyla**: kip kapalıyken aynı iki yazım **reddediliyor**. Test bir onay değil bir
  **kayıt**tır; `BR-SEC-19` kararı daraltma getirirse sessizce geçmez, **adıyla** kırmızı yanar.
- **Dokunulan dosyalar:** `tests/Pbxtr.Integration.Tests/Tests/CrossTenantVersionGateOracleTests.cs`,
  `deploy/db/03-smoke-tenant-isolation.sql`, `yonetim/backlog.md`
- **Komutlar:**
  ```bash
  dotnet test tests/Pbxtr.Integration.Tests --filter "FullyQualifiedName~CrossTenantVersionGateOracleTests"
  docker run -d --name pbxtr-qa85-pg -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=pbxtr postgres:16
  psql -f /db/00-roles.sql ; -f /db/01-rls-template.sql ; -f /db/03-smoke-tenant-isolation.sql
  ```
- **Sonuç / doğrulama:** **Mutasyon 4/4.** Middleware'in çapraz-yazım dalındaki `EnqueueAudit`
  silinince **yalnız yeni test** kırmızı (1 kırmızı / 7 yeşil) — iddia gerçekten denetimi
  ölçüyor. Şablonun `WITH CHECK` dalı daraltılınca TEST 10c **teşhisli** kırmızı;
  `app_is_cross_tenant()` hep açık yapılınca TEST 1 kırmızı; kontrol grubu çapraz kipte
  bırakılınca kontrol iddiası kırmızı. Kontrol koşuları yeşil: **8/8** test, smoke **40 OK**,
  `dotnet format` temiz.
- **Yol boyunca ısıran tuzak:** `docker cp deploy/db <konteyner>:/db` ikinci kez koşunca
  `/db/db` üretti; mutasyon uygulanmış dosya konteynere **hiç gitmedi** ve kapı **yeşil**
  kaldı. "Mutasyon yeşilse önce fikstürü sorgula" defterdeki hâliyle tekrar doğrulandı.
- **Commit:** `5a3cb96e`

### 7. `BR-QA-63` — kırmızı artık **iki listeyi de adıyla** söylüyor

- **Neden:** bir migration eklemek **iki ayrı mimari envanterini** birden istiyor ve biri
  ötekini yeşil yapmıyor. Bu bir kusur değil **tuzaktı**: eksik adı gören geliştirici
  kırmızıyı *"bekçi bozuk"* diye okur ve en kolay çözüme — listeyi *"geçsin diye"*
  güncellemeye — gider. O anda bekçi bir **onay kutusuna** döner.
- **(a) Ne yapıldı:** `RaporlaVeKarsilastir` yardımcısı; kırmızı artık hangi listenin **hangi
  dosyada** olduğunu, **eksik** ve **fazla** adları ayrı ayrı, iki listenin **ayrı ayrı**
  güncellenmesi gerektiğini ve *"listeyi geçsin diye güncellemek bu bekçiyi bir onay
  kutusuna çevirir"* uyarısını **mesajın içinde** yazıyor.
- **(b) Türetilebilirlik ölçüldü → TÜRETİLEMEZ:** `ExpectedMigrationSecurityDefiners` **37**
  satır ve anahtarı `dosya:ad`; `ElevatedFunctionNames` **32** ad ve anahtarı yalnız `ad`.
  Aynı fonksiyon birden çok migration'da **yeniden tanımlanıyor**
  (`pbxtr_write_license_notices`, `ticket_purge_candidates`). Kümeler de tutmuyor:
  `upsert_sms_provider_account` **SECURITY DEFINER'dır ama çapraz kip AÇMAZ**; tersine
  `SET app.cross_tenant` ile kapsam açan **definer olmayan** bir gövde definer listesine
  girmez, `DatabaseSites`'a girer. **Neden ayrı oldukları iki listenin de başına yazıldı.**
- **Kartın sınırına uyuldu:** listeler **otomatik doldurulmadı** — bekçinin bütün değeri, bir
  insanın o migration'ı çapraz-tenant açısından **okuduğunu** zorlamasıdır.
- **Dokunulan dosyalar:** `tests/Pbxtr.Architecture.Tests/CrossTenantScopeGuardTests.cs`,
  `…/CrossTenantScopeSurfaces.cs`, `yonetim/backlog.md`
- **Sonuç / doğrulama:** **mutasyon 2/2** — her listeden bir satır silindiğinde o listenin
  **adıyla** teşhisli kırmızı. Architecture takımı **615/615** yeşil, `dotnet format` temiz.
- **Commit:** `98d1b26c`

### 8. `BR-QA-66` — kırmızının **sahibi** artık çıktıda okunuyor

- **Neden:** paralel ajan turlarında *"takım yeşil"* bir **tarih iddiasıdır**. Ölçülmüş vaka
  (2026-09-13): bir koşu `RedisLiveStateStore.cs(404,20): CS0103` ile kırmızı geldi; hata o
  ajanın değişikliği **değildi** — dosya ölçümden **5 saniye önce** başka bir ajan tarafından
  yazılıyordu. Çıktı sha ve kirlilik taşımadığı için kırmızının **sahibi okunamıyordu**.
- **(b) İndi:** `deploy/test-kos.sh` artık her koşuda **ağaç kimliğini** basıyor ve **özete de
  taşıyor**: `agac sha`, `kirli` (değişmiş dosya sayısı) ve **`son yazim`** — `src/` + `tests/`
  altındaki **en yeni** kaynak yazımının kaç saniye öncesi olduğu. Üçüncüsü ölçülmüş vakanın
  **tam imzasıdır**.
- **Bunlar kapı değil KİMLİK:** kirli bir ağaçta ölçüm yapmak meşru bir iştir; satırlar koşuyu
  kırmızı yapmaz, sonucu **okunabilir** kılar. **Pozitif kontrol:** bir kaynak dosyaya
  dokunulunca satır `0 sn once` oldu.
- **Kartın diğer yarısı zaten kapalıydı:** koşan test **sayısı** `--list-tests` beklenen vs
  `Total:` karşılaştırmasıyla ölçülüyordu (`TOPLAM >= BEKLENEN`).
- **(a) Worktree izolasyonu değerlendirildi — ve ölçümü çözmüyor:** `git worktree list` bu
  kurulumda **zaten** bir ajan ağacı gösteriyor (`.claude/worktrees/agent-*`, ayrı dal, 11
  kirli dosya) ama orada **`bin/` yok**: yani ajanlar düzenlemeyi izole ağaçta yapıp **ölçümü
  ana ağaçta** koşmuş. Ayrıca izole ağaç **paylaşılan kaynakları ayırmaz** — Docker
  PostgreSQL/Redis konteynerleri, `artifacts/` logları ve testhost belleği ortaktır.
  **Karar:** zorunlu worktree ölçümü **önerilmiyor**; okunabilirlik (b) ile sağlanır.
- **Dokunulan dosyalar:** `deploy/test-kos.sh`, `yonetim/backlog.md`
- **Commit:** `1794d06e`

### 9. `BR-QA-78` — fikstür yardımcısı artık **yazdığını kalıcı yazıyor**

- **Neden:** `TelephonyFixture.ScalarInTenantAsync` kendi transaction'ını açıp **commit
  etmiyordu**. Salt okuma için zararsız; ama yardımcı **keyfi SQL** koşar ve onunla `DELETE`
  yapan çağırılar vardı. Arıza sessiz **ve yanıltıcıdır**: sayım aynı transaction'da okunduğu
  için `Assert.Equal(1, …)` **geçiyor**, bağlantı kapanınca silme geri alınıyor ve satır
  **yerinde kalıyordu**.
- **Önce ölçüldü (kartın şartı):** yeni `FixtureWriteVisibilityTests`, silmeyi **ayrı bir
  bağlantıdan** sayıp **1 satır** gördü — kusur gerçek.
- **Düzeltme:** yardımcı okuyucuyu kapatıp **commit ediyor**. *"Adı salt-okuma olduğunu
  söylesin, yazan çağıranlar taşınsın"* alternatifi **reddedildi** ve sebebi yazıldı: **ad bir
  kapı değildir**; bir sonraki çağırı yine keyfi SQL yazar ve aynı sessiz arızayı üretir.
- **Kalıntı bırakan iki sınıf da kapandı:** `TelephonyEventPipelineTests` artık `call_events`
  satırlarını da siliyor; `TrunkAdminPersistenceTests` kendi trunk host'larını siliyor
  (fikstür trunk'ı listede **yok**).
- **Kendi hatamı kendi kapım yakaladı:** `call_events` temizliğinin kimlik evrenini önce
  `_cdrLinkedIds` üzerinden kurdum — vacuity kapısı **hiçbir satır görmeyince** evrenin yanlış
  seçildiği anlaşıldı (o liste yalnız `cdr` bekleyen vakaların alt kümesi). Evren `NewCallId`
  içinde **tek kapıda** toplandı. İkinci düzeltme: `visible > 0` iddiası üç vakayı haksız yere
  kırmızı yaktı (tenant'ı çözülemeyen olay **bilerek** satır yazmaz) — iddia kaldırıldı,
  gerekçesi yazıldı.
- **Sonuç / doğrulama:** **mutasyon 3/3** — commit kaldırılınca yalnız yazma vakası kırmızı
  (okuma kontrolü yeşil); `call_events` silmesi kaldırılınca **10/14**; trunk silmesi
  kaldırılınca **6/6**. Tam Integration takımı: **1013/1015** (25 dk 25 sn).
- **Kalan iki kırmızı bu işin dışında ve ikisi de karta bağlandı:** `FinalDeliveryReportTests`
  → **BR-QA-67** (bayat kanonik şema; **baseline'da da kırmızı**, stash ile ölçüldü) ve tam
  koşuda görülen `AuthLoginHttpTests` boş gövdesi → **yeni BR-QA-88**. İkincisi **atfedilmedi**:
  filtreli koşu değişiklikle de değişiklik olmadan da yeşil verdi, tam koşu baseline'ı
  alınmadı — yani "benim değil" demek için de ölçüm yok.
- **Commit:** `30804d10`

### 10. `BR-QA-67` — kanonik şema artefaktı tazelendi **ve kuralı yazıldı**

- **Neden:** `doc/st44-final-delivery-canonical.json` içindeki `databaseSchemaRevision`
  zincirin sonuncusu değildi; fark tam koşuda **2 migration**'a çıkmıştı ve
  `FinalDeliveryReportTests` **kırmızı** yanıyordu. Bayat kaldığında rapor, üreten kişinin
  **hiç görmediği** bir şemayı *"doğrulanmış"* gösterir.
- **Ne yapıldı:** revizyon `20260916200000_CallDirectionUnmeasured`'a çekildi; türeyen
  `doc/st44-final-delivery-report.json` **`PBXTR_WRITE_DOCS=1`** ile yeniden üretildi (elle
  düzenlenmedi).
- **Kartın asıl istediği — "yenilemenin ne zaman zorunlu olduğu" teste yazıldı:** `Migrations`
  altına `^[0-9]{14}_` desenli **yeni bir migration** eklendiğinde; kural **tarih sırasıdır**
  ve migration'ın *"küçük"* olması, yalnız veri güncellemesi taşıması ya da `Down()`'unun boş
  olması bu yükümlülüğü **kaldırmaz**.
- **Ve yenilemenin bir ONAY olmadığı yazıldı:** artefaktı güncellemek *"bu migration
  incelendi"* demez; yalnızca teslim iddiasının **hangi şemaya bağlı** olduğunu tazeler.
  Migration'ın kendisi ayrı bekçilerle ölçülür (BR-QA-63).
- **İki kırmızı mesajı da teşhisli hale getirildi:** hangi dosya, hangi revizyon, ondan sonra
  gelen migration'lar ve ne yapılacağı.
- **Sonuç / doğrulama:** **vacuity 2/2** — artefakt eski revizyona çekilince *"KANONİK ARTEFAKT
  BAYAT"*, var olmayan bir revizyona işaret edince *"KANONİK REVİZYON ZİNCİRDE YOK"* ile
  kırmızı. Kontrol **26/26**, `dotnet format` temiz.
- **Tuzak tekrar ısırdı:** heredoc içindeki `\n` kaçışları tek seviye yenildi ve C# kaynağına
  **gerçek satır sonu** yazıldı (CS1039). Build kırmızıyken `--no-build` koşusu yine
  *"Passed!"* dedi — defterdeki **"test koşarken build sessizce atlanır"** dersi birebir.
  Kaçış içeren yamalar artık heredoc yerine dosyaya yazılıp çalıştırılıyor.
- **Commit:** `af8338ec`

### 11. `BR-QA-65` — fikstür `job_runs` SELECT'ini artık **üretim gibi** veriyor

- **Neden:** ikiz üretimden **KATIYDI**. Fikstür `REVOKE ALL ON pbxtr_sys.job_runs FROM
  pbxtr_app` yapıp **SELECT'i de** alıyordu; üretimde ise `20260814141500_JobRunsHealthRead`
  2026-08-14'ten beri `GRANT SELECT` veriyor ve `SystemHealthProbe` o tabloyu **bugün okuyor**.
- **Belirti sessiz:** sağlık yoklaması okuyamadığı bölüme *"SORAMADIM"* der ve **gri** çizer —
  kırmızı değil. Bu fikstürle yazılacak her sağlık ölçümü **vacuous** olurdu ve bunu hiçbir
  kırmızı söylemezdi. Defterdeki ders (*test ikizi üretimden müsamahakâr*) burada **ters
  yönde**; kökü aynı: ikiz gerçek yetkiyi taşımalı.
- **Ne yapıldı:** `REVOKE` artık yalnız yazma yetkileri; `GRANT SELECT` açıkça yazıldı ve
  gerekçesi fikstürün içine kondu.
- **Vacuity kapısı kartın istediği biçimde:** yeni `JobRunsHealthReadGrantTests` **üretimin
  kendi sorgusunu** (`SystemHealthProbe.JobSql` — metin **yeniden yazılmadı**) **üretimin
  kendi rolüyle** (`pbxtr_app`) koşturuyor. İkinci vaka yazma yetkilerinin geri verilmediğini
  **ve** SELECT'in gerçekten açık olduğunu ölçüyor — pozitif kontrol olmasaydı ilk iddia
  *"hiçbir yetki yok"* hâlinde de yeşil kalırdı.
- **Sonuç / doğrulama:** eski hâl geri konunca **2 kırmızı** (biri ham `42501 permission
  denied`, öteki adıyla); aşırı düzeltme (`GRANT SELECT, INSERT`) konunca yine **2 kırmızı**.
- **Yan bulgu (ölçüldü, mutasyonum yeşil kaldığı için araştırıldı):** yalnızca `REVOKE`
  satırını silmek **hiçbir şeyi değiştirmiyor** — `pbxtr_app`'in zaten yazma yetkisi yok; o
  satır bir **kemer-askıdır** (ileride biri `pbxtr_sys`'e default privilege tanımlarsa).
  *"Mutasyon yeşilse fikstürü sorgula"* dersi yine işe yaradı: mutasyonu düzelttim, kapıyı değil.
- **Tam Integration takımı: 1016/1017.**
- **Commit:** `1c19c9dc`

### 12. `BR-QA-88` — forgot-password boş gövdesi **tekrarlandı**, teşhis eklendi

- İki **bağımsız** tam koşuda (25 dk) aynı vaka aynı yerde (~23. dakika) kırmızı yandı — yani
  belirti **kalıcı** ve *"bir kez göründü"* itirazı kapandı.
- `ComparableAsync` artık boş gövdede ham `JsonReaderException` yerine **durum kodunu adıyla**
  basıyor: `429` (hız sınırı) / `5xx` / `204` ayrımı bir sonraki tam koşuda **çıktıdan**
  okunacak.
- **Kod değiştirilmedi** — sebep ölçülmeden değiştirmek bu kartın kendi yasağı. Kart
  **Kısmen**.

### 13. `BR-BE-125` — teslim ekseni projeksiyonu **gerçek PG'de** ölçülüyor

- **Neden:** birim testleri `ExtensionDeliveryStatus` sınıfının **kendisini** ölçüyordu
  (`bool?` → üç değerli çıktı). Ölçülmeyen şey **projeksiyonun satıra ne yazdığıydı**: kesme
  birimi **dosyadır**, yani karar **tür bazında** okunup **her dahili satırına** dağıtılır —
  bu dağıtım yanlışsa ekran **her** dahiliyi yanlış gösterir ve sınıf testlerinin hiçbiri
  bunu görmez.
- **Ne yapıldı:** `ExtensionDeliveryProjectionTests` (3 vaka): gözlem **kesilmiş** derse her
  satır `withheld` + doğru sebep kodu; gözlem **yokken** `unknown` (**`delivered` değil**);
  tür `ServedKinds`'te ise `delivered` ve sebep `null` (pozitif kontrol — bu olmasaydı
  "her zaman unknown dönen" bir projeksiyon da yeşil kalırdı).
- **Ne gerçek, ne ikiz:** EF, interceptor'lar, RLS ve `EfUserAdministration` **üretimdeki**
  sınıflar; yalnızca gözlemin **kaynağı** ikiz — ve ikiz **hiçbir kural taşımıyor** (kural
  projeksiyondadır; ikiz karar verseydi ölçülen şey ikizin kararı olurdu).
- **Sonuç / doğrulama:** kartın yazdığı **iki mutasyon** — projeksiyon sabit `delivered`
  dönünce **2 kırmızı**; `Of` içinde `null => Delivered` (üç değerliliğin ezilmesi) yapılınca
  **1 kırmızı**. Kontrol 3/3, `dotnet format` temiz.
- **Aynı turun dersi hemen uygulandı:** vaka kendi dahililerini siliyor **ve silmeyi
  ölçüyor** — silme satırı kaldırılınca 3 kırmızı. (İlk hâlinde silme vardı ama iddiası
  yoktu; mutasyon yeşil kalınca iddia eklendi.)
- **Commit:** `20d18c4a`

### 14. `BR-BE-127` — `provisioning.updated` kapısı **çalışma zamanında** ölçülüyor

- **Neden:** mevcut bekçi bir **site** bekçisiydi — üç uçta yayın çağrısının *var olduğunu*
  doğruluyordu. Çağrıyı **koşullu** etkisizleştiren bir değişikliği (değişiklik kapısının
  daima `false` dönmesi) **görmüyordu**: çağrı yeri yerinde durur, bekçi yeşil kalır, ekran
  sessizce tazelenmez olur. Bu, *"kod var, koşan yok"* deseninin bir kat aşağısı.
- **Ne yapıldı:** kaydeden bir `IRealtimePublisher` ikizi + üç çekimlik vaka:
  1. **Çekim 1** (önceki gözlem yok) → kapı **bilerek** sessiz; gözlem yazılır. *(Bu bir iddia
     değil, bir kayıt: ilk çekim bir değişiklik değil, bir tanışmadır.)*
  2. **Çekim 2** (hiçbir şey değişmedi) → **sıfır olay**. Kartın asıl iddiası bu; **ETag
     bilerek gönderilmiyor**, çünkü ölçülen şey 304 kısayolu değil **kapının kendisi**.
  3. **Çekim 3** (temiz tenant'a yeni tür eklendi) → **olay var**. Pozitif kontrol olmasaydı
     *hiçbir şey yayınlamayan* bir kod da "ikinci çekimde 0 olay" iddiasını geçerdi.
- **Yan düzeltme (ölçüldü):** `RecordingObservations.ReadAsync` koşulsuz `null` dönüyordu — o
  hâlde kapının B kolu **hiç ölçülemezdi** (önceki gözlem hep yok → kapı hep kapalı). İkiz
  artık üretimdeki Redis gibi **yazdığını geri okuyor** ve hâlâ hiçbir **karar** vermiyor.
- **Sonuç / doğrulama:** **mutasyon 2/2** — kapı daima `false` → kırmızı (site bekçisi bunu
  görmez); kapı daima `true` (koşulsuz yayın) → kırmızı. Kontrol **5/5**, `dotnet format` temiz.
- **Tuzak yine ısırdı:** ilk mutasyon `if (1 == 1) return false;` idi, **CS0162 ile derlenmedi**
  ve `--no-build` koşusu eski ikiliye giderek **yeşil** dedi. Derleme çıktısı sayılmadan
  mutasyon sonucu okunmaz.
- **Commit:** `554de240`

### 15. `BR-QA-53` — query filter artık **gerçek model** üzerinde ölçülüyor

- **Neden:** ADR-012 §G2 iki şey istiyordu; (i) kapalıydı
  (`TenantIsolationSurfaceTests`), (ii) **hiç yapılmamıştı**. Filtrenin fiilen takıldığı
  tek yer `TenantIsolationPersistenceTests`'ti ve oradaki model **sentetiktir**
  (`TenantRow`/`GlobalRow`). Yani "arayüzü uyguladın mı" sorusu gerçek model üzerinde,
  "filtre gerçekten takıldı mı" sorusu **sahte** model üzerinde cevaplanıyordu — aradaki
  boşluk tam olarak `OnModelCreating`'in kendisi, yani kusurun oluşabileceği tek yer.
- **Ne yapıldı:** `TenantQueryFilterModelTests` gerçek `PbxtrDbContext` modelini kurar
  (`UseNpgsql` yalnızca sağlayıcı kurallarını yükler — **hiçbir bağlantı açılmaz**, bu
  yüzden bekçi mimari takımında ve Docker'sız koşar) ve her `ITenantOwned` kök için
  `GetDeclaredQueryFilters()` okur. Beş vaka: (1) her kök filtreli, (2) döngünün
  **atladığı** dallar (TPH türevi / sahipli tip) kök veya sahip üzerinden korumalı,
  (3) vacuity tabanı, (4) dedektörün **pozitif kontrolü**, (5) global tabloların filtre
  **taşımadığı** — negatif kontrol.
- **Ölçüm:** gerçek modelde **87 varlık**, **80** filtre bekleyen `ITenantOwned` kök,
  **80/80 filtreli**. Muafiyet yok → onay listesi de yazılmadı (boş bir onay listesi,
  ileride oraya gerekçesiz satır atmayı kolaylaştırır). ADR'nin "33 tip" sayısı **bayat**;
  kartın "tip sayısı bugün ayrıca sayılmadı" maddesi böylece kapandı.
- **Aday kümesi bugün boş:** modelde TPH türevi **0**, sahipli tip **0**. Bu yazılmasaydı
  2. vaka "yeşil" görünür ve bir şey ölçtüğü sanılırdı. Vaka bir ölçüm değil **tetiktir**;
  dedektörün çalıştığını ayrı bir pozitif kontrol kanıtlar — sentetik, kasten kusurlu bir
  model (kök `ITenantOwned` **değil**, türev `ITenantOwned`, ikisi de filtresiz) kurulur ve
  dedektör orada **1 yetim** bulur.
- **Dokunulan dosyalar:** `tests/Pbxtr.Architecture.Tests/TenantQueryFilterModelTests.cs`
  (yeni), `yonetim/backlog.md`
- **Mutasyon (2 kırmızı):**
  1. Döngüye `ClrType.Name.StartsWith("Contact")` atlaması eklendi →
     `Bulunanlar: Contact, ContactNote` ile kırmızı.
  2. Filtre çağrısı tamamen atlandı → kırmızı.
  Her ikisinde de diğer dört vaka yeşil kaldı.
- **Sonuç / doğrulama:** Mimari takım **620/620 yeşil** (önceki 615 + 5 yeni).
  `dotnet format --verify-no-changes` temiz.
- **Commit:** `ee2db51a` — BR-QA-53 bitti: query filter artik GERCEK model uzerinde olculuyor

### 16. `BR-QA-52` — `TenantLeakCoverageTests` **kuruldu**, ADR-012'nin R-1 riski kapandı

- **Neden:** ADR-012 §G1 bu bekçiyi "KURAL, kurulacak" diye tanımlıyordu ve kendi R-1
  riskinde şunu yazıyordu: *"Kurulum kartları açılmalı; açılmazsa bu belge projenin baskın
  hata deseninin yeni bir örneği olur."* **Kart açılmadı ve öyle oldu** — kart
  (`BR-QA-52`) ancak 2026-09-10'da, bir ADR taraması sırasında açıldı.
- **Ne yapıldı:** `tests/Pbxtr.Architecture.Tests/TenantLeakCoverageTests.cs`.
  `src/Pbxtr.Infrastructure/Modules/**/Ef*.cs` sayılır; her adaptör için ya bir sızıntı
  testi bulunur, ya da borç listesinde kaydı olur. Dört vaka: (1) kapsam ya da borç,
  (2) ölü/artık kapanmış kayıt yok, (3) **kilitli sayı** — borç yalnızca küçülür,
  (4) vacuity + pozitif kontrol.
- **Bekçi yasaklamaz, dondurur.** 66 adaptörün sızıntı testi bugün yok; bunları kırmızı
  yakmak bekçiyi ilk günde silinecek bir engele çevirirdi. Kazanç: bundan sonra eklenen
  her `Ef*.cs` ya sızıntı testiyle gelir, ya da bu dosyayı değiştirmek zorunda kalır ve
  borcun büyümesi **review'da görünür**.
- **66 ayrı gerekçe yazılmadı.** ADR "gerekçe + kart kimliği" istiyordu; hiçbiri
  ölçülmemişken 66 ayrı cümle yazmak *gerekçe değil dolgu* üretirdi — ve bu deponun baskın
  hata deseni tam olarak budur. Gerçek tek cümledir: bu 66 adaptörün tenant sızıntısı
  bugüne kadar ölçülmedi. Ortak gerekçe ve tek kart kimliği `BR-QA-52`'dir.
- **TANIM ÖLÇÜMLE DÜZELTİLDİ — turun asıl dersi.** İlk tanım yalnızca **dosya adına**
  bakıyordu ve borç **83** çıktı. Sonra görüldü ki `BlacklistTenantLeakTests`,
  `CampaignTenantLeakTests`, `CrmBridgeTenantLeakTests`, `IvrTenantLeakTests`,
  `ReportTenantLeakTests` ve `SmsTemplateBindingTenantLeakTests` **gerçekten vardı** —
  dosya adları adaptörün tam adını taşımıyordu (`Blacklist` ≠ `BlacklistDirectory`). Dar
  tanım **16 kalemi yok yere borça yazıyordu** ve böyle bir liste, ilerlemeyi gizlediği
  için kendi amacını bozardı. Tanıma "gövdede `Ef<Ad>` anma" dalı eklendi; borç **83 → 66**.
- **Dokunulan dosyalar:** `tests/Pbxtr.Architecture.Tests/TenantLeakCoverageTests.cs`
  (yeni), `doc/mimari/ADR-012-tenant-izolasyonu-kanit-katmanlari.md`, `yonetim/backlog.md`
- **Mutasyon (3 kırmızı):**
  1. Borçta olmayan yeni bir `Ef*.cs` eklendi → `MutasyonDenemesi` ile kırmızı.
  2. Borç listesine ölü kayıt (`EfOlmayanAdaptor`) → kırmızı.
  3. Kapsam dedektörünün regex'i körleştirildi → vacuity vakası `kapali = 0` diyerek
     kırmızı (pozitif kontrol çalışıyor).
- **ADR güncellendi:** G1/G2/G3 üçü de artık **KURULDU**; §2 ve §5'in ilgili maddeleri
  ÖNERİ değil **KURAL**. R-1 kapandı — ama *geç* kapandığı ve sebebi ADR'de kayıtlı
  bırakıldı.
- **Sonuç / doğrulama:** Mimari takım **624/624 yeşil**.
  `dotnet format --verify-no-changes` temiz.
- **Commit:** `0cae9596` — BR-QA-52 bitti: TenantLeakCoverageTests kuruldu (ADR-012 G1)

### 17. `BR-QA-81` — güven dalı Linux root altında **gerçekten** koşuyor

- **Neden:** üç test koşul sağlanmayınca `return;` ile sessizce yeşil dönüyordu; üretim güven dalı (uid 0 / 0600 / `O_NOFOLLOW`) hiçbir yerde ölçülmüyordu.
- **Ne yapıldı:** `tests/Shared/` (iki test paketine `Compile Include` ile bağlı) `LinuxRootEnvironment` + `RequiresLinuxRootFact` / `RequiresSignedFixtureFact` / `RequiresLiveAriFact`, Integration'da `RequiresSeederTrustFact`. `deploy/yerel-kapilar.sh` **`kapi_57`**: `mcr.microsoft.com/dotnet/sdk:10.0` konteyneri `--user 0`, `--artifacts-path /kok` (ortak `BaseIntermediateOutputPath` MSB4006 verdi), iki proje / 3 test, ~35 sn; `Skipped: 0` şart.
- **Kartın vacuity öngörüsü çürütüldü:** `st.Uid != 0` silindi, root hedefi yeşil kaldı — root iken her dosyanın sahibi zaten root. Yeni vaka `Root_olmayan_sahipli_dosya_ve_ust_dizin_REDDEDILIR` `chown nobody` yapar. Mutasyon 3 kırmızı (dosya uid, ata dizin uid, `IsLinuxRoot => false` → kapı "beklenen 2 geçen test YOK").
- **Yayın kapıları:** `integration-trx-gate.py`, `api-test-shards.py`, `test-kos.sh` atlamayı yasaklıyordu (bu yüzden testler `return;`e itilmişti). Artık **sayılı**: `deploy/ci/skip_izinleri.py` kapalı liste, tavan 5; liste dışı atlama kırmızı. Kapı testleri: 13/13 ve 8/8.
- **Komut:** `MSYS_NO_PATHCONV=1 docker run --rm --user 0 -v "$(cygpath -m "$PWD"):/repo" -v pbxtr-root-nuget:/nuget -v pbxtr-root-artifacts:/kok -w /repo -e NUGET_PACKAGES=/nuget mcr.microsoft.com/dotnet/sdk:10.0 dotnet test <proje> --filter ... --artifacts-path /kok`
- **Sonuç:** Api.Tests filtreli 1366 geçti / 3 görünür atlandı. `deploy/ci/test-kos-yayin-test.py`'deki 1 hata önceden vardı (stash ile doğrulandı).
- **Commit:** `ca0bf355`

### 18. Paralel ajan turu + kullanıcı kararları

- **Kullanıcı kararları (2026-09-17):** sunucu `176.88.41.220` **canlı değil, test/sunum ortamı** — originate/yazma/reload serbest (hafızaya yazıldı). BR-AST-60 için **köprüleme** (pbxtr ARI ile yönetir). BR-SYS-95: **24 ay kalır**. BR-SYS-34/44/90: **rapor postası şimdilik yok** → kapsam dışı. BR-SEC-16: sırlar ajanlar bitince döndürülecek. Büyük özellik epikleri (BR-7/8/9/A3/C2) **şimdi yapılacak**.
- **Düzen:** sekiz ajan ayrı worktree'lerde (ARI köprüleme, dialplan üretimi, AMI olay hattı, DB, SYS/confd, BE, QA/FE/SEC, OPS/karışık). Ajanlar `backlog.md`'ye dokunmaz, commit eder ama push etmez; birleştirme, backlog, push, günlük ve ClickUp koordinatörde. Sunucuda yazma adımları `flock /tmp/pbxtr-agent.lock` içinde.
- **Birleşenler:** `463b31d0` BR-BE-150 (taklit genişlik kuralı rol kapsamını da sayar; 4 mutasyon kırmızı; kalan: yayın + enforce kararı). `af1ba5d8` BR-AST-60 köprüleme (`AriCallBridge`; santralde gerçek C# kodu geçici `t9060` bağlamında 4 senaryo geçti; 10/10 mutasyon kırmızı; kalan: yayın, kör aktarma, çağrı sesi, kayıt).
- **Kurula gidecek sorular (birikiyor):** BR-BE-81, 43-B, 119, 136, 159; BR-AST-59 gelen yönde bekletme yolu (Stasis'siz AMI Redirect mi, `AgentConnect` sonrası devralma mı); Ş43-13 (soket kapanışı köprülü çağrıyı düşürmüyor — boşaltma şartı değişsin mi).

## Kararlar

- **Aynı reddi iki kez adlandırma.** Kod anahtarı ile kural adı aynı şeyi söylüyorsa
  **aynı metni** paylaşırlar; ayrı cümle yazmak kullanıcıya iki farklı gerekçe gösterirdi.
- **Adlandırılmamış red için cümle yazılmaz.** `denied` eşlenseydi, sunucunun "bilmiyorum"
  dediği yerde ekran **kesin bir sebep** göstermiş olurdu.
- **Yanlış yerde duran doğru sayı, yanlış sayıdır.** Tenant geneli rakam satıra
  konduğunda okuyan kişi onu satırın konusu sanıyor; çözüm rakamı silmek değil, ait
  olduğu seviyede bırakmaktır.
- **Bir aracın "yazılmış" olması ölçüm değildir.** Üç kalemden ikisi zaten bağlıydı ve
  kart bunu bilmiyordu; kalan bir kalem ise bugüne kadar hiç koşmamıştı.
- **Kapıyı ölçülemeyeceği yere koymak, kapıyı kaldırmaktır.** `dotnet format` gate
  konteynerine taşınsaydı sonsuza kadar "ölçemedi" derdi.
- **Bir çağrı yerinin varlığı, çalıştığının kanıtı değildir.** Site bekçisi ucuzdur ve
  gereklidir, ama koşullu bir susturmayı yalnızca çalışma zamanı ölçümü yakalar.
- **Bir "temizledim" iddiası, temizliğin dışından ölçülmeli.** Aynı transaction'dan
  okunan sayım, kendi yazdığını görür ve hiçbir şey kanıtlamaz.
- **Bir bekçinin mesajı, bekçinin yarısıdır.** Ne yapılacağını söylemeyen kırmızı,
  "geçsin diye" güncellenen bir listeye dönüşür.
- **"Kuyruğa girdi" bir teslim kanıtı değildir.** Denetim iddiaları, incelemecinin
  okuyacağı yerden — tablodan — geri okunmalı.
- **Paylaşılan bir önbellek, bekçilerin en sessiz düşmanıdır.** Hız kazancı alınır ama
  "üç ayrı soru" iddiası ölçülmezse kapılar tek kapıya çökebilir ve bunu kimse görmez.
- **Bir kapsam ölçümünün ilk sayısı, tanımın ölçümüdür; kapsamın değil.** "83 modülün
  sızıntı testi yok" cümlesi ölçüm gibi duruyordu; gerçekte altı test **vardı** ve tanım
  onları göremiyordu. Borç listesi yayımlanmadan önce, listenin **kapalı** tarafı da ayrıca
  doğrulanmalı.
- **Bekçi borcu yasaklamaz, dondurur.** 66 kalemi kırmızı yakan bir kapı ilk gün silinir;
  kilitli sayı ise borcu görünür kılar ve büyümesini review'a taşır.
- **Bir ADR kendi uygulama kartını açamaz.** Kartı açılmayan "kurulacak" bekçi, ADR'nin
  kendi uyardığı hata deseninin örneği olur — ADR-012 bunu yazmıştı ve öyle oldu.
- **Boş bir aday kümesi, yeşil bir testin en sessiz hâlidir.** "0 TPH türevi" ölçüldüğünde
  seçenek ikidir: vakayı silmek ya da tetik olduğunu **yazmak** ve dedektörü ayrı bir
  pozitif kontrolle kanıtlamak. Yazılmayan üçüncü yol — sessizce yeşil bırakmak — bu
  deponun baskın hata deseninin ta kendisidir.
- **Bir bekçi "veritabanı ister" diye mimariden kaçırılmaz.** EF modeli kurmak bağlantı
  açmaz; soru gerçek modele sorulabiliyorsa sentetik modele sorulmaz.
- **Boş onay listesi yazılmaz.** Muafiyet yokken açılan liste, ilk gerekçesiz satırın
  davetiyesidir.
- **Parite bekçisinin yönü tutucudur.** Kaçan ölü satır riski alınır, yanlış alarm
  alınmaz — çünkü yanlış alarm veren bir kapı kaçınılmaz olarak silinir.

### 19. Kurul Karar #66 — 27 açık sorunun toplu karara bağlanması

- **Neden:** Gün boyu koşan paralel ajan turları (AMI, dialplan, SYS, DB, OPS) 27 açık
  soru biriktirdi. Bunlar tek tek kullanıcıya sorulacak sorular değildi (bellek kuralı:
  "kararı kullanıcıya değil kurula sor"); hepsi bir oturumda karara bağlandı.
- **Ne yapıldı:** Gündem `yonetim/kurul-gundem-2026-09-17.md` yazıldı (M1–M27; her madde
  seçenekler + koordinatör önerisi). 10 kurul üyesi ajanı **aynı mesajda paralel** koştu.
  Oylar toplandı, eşik (7/10, ŞARTLI = EVET) hesaplandı, Şeytan'ın 12 itirazının her
  birine yazılı cevap üretildi ve karar kaydı eklendi.
- **Dokunulan dosyalar:** `yonetim/kurul-gundem-2026-09-17.md` (yeni),
  `yonetim/kurul-kararlari.md` (Karar #66 eklendi)
- **Sonuç / doğrulama:** **ŞARTLI ONAY**, 27 maddenin tamamı. Hiçbir maddede 4+ HAYIR yok
  (en fazla 1 — Şeytan M1/M9/M18/M23). Veto şartları: CTO (M1, M15, M16, M21),
  DB Lideri (M21), Asterisk Uzmanı (M9, M15, M18).

  **Kurulun koordinatör önerisini DÜZELTTİĞİ dört madde** (asıl değer bunlarda):
  1. **M12 — teslim kanıtı.** Öneri "ARI `GET /endpoints` listesinde görünmek" diyordu.
     Asterisk Uzmanı çürüttü: BR-AST-87'de ölçüldü, o liste **silinmiş nesnelerin bayat
     kopyalarını** da döndürüyor (509 hayalet kayıt). Kanıt nesne bazında
     `GET /asterisk/config/dynamic/res_pjsip/endpoint/{ad}` 200 olmalı.
  2. **M23 — owner yazma yüzeyi.** Öneri "definer fonksiyon kendini GUC işaretiyle
     tanıtsın" diyordu. Şeytan (İ7), CTO ve DB Lideri aynı şeyi söyledi: **GUC bir kimlik
     değildir** — `SET LOCAL` yapabilen her oturum kendini definer diye tanıtabilir. Karar
     değişti: önce `pbxtr_owner`'ın `tenants` UPDATE yetkisi REVOKE edilir ve iki definer
     fonksiyon `pbxtr_sys` sahipliğinde koşar; GUC yolu yalnız o ölçüm başarısızsa.
  3. **M21 — RLS yüklemi.** Öneri "çapraz kip için ayrı policy" diyordu. DB Lideri ve CTO
     aynı tuzağı gösterdi: **PostgreSQL aynı rol/komut için iki PERMISSIVE policy'yi OR
     ile birleştirir** — plan yine satır başı Filter'a döner, 13 ms ölçümü üretimde
     çıkmaz. Şart: ya ayrı DB rolü (`TO ...`) ya OR'suz tek ifade; EXPLAIN'de `Index Cond`
     görülmeden `01-rls-template.sql`'e dokunulmaz.
  4. **M14 — `ari.conf` `channelvars`.** Öneri kapalı reload listesini genişletmekti.
     Asterisk Uzmanı üçüncü bir seçenek getirdi: `channelvars` tenant verisi değil,
     santral geneli sabit ayar → imaj/host tabanına yazılır, liste hiç genişlemez.
     Karar: (a) yalnız A/B ölçümü `module reload res_ari.so`'nun açık Stasis soketini ve
     köprülü çağrıyı düşürmediğini gösterirse; düşürürse (c).

  **Bağlayıcı uygulama sırası** (çoğu üyenin ayrı ayrı vardığı sonuç):
  `M10 (state_interface) → M3 (resync) → M9 (devralma)` — sırası bozulursa kuyruk,
  görüşmesi süren agent'a ikinci çağrı çaldırır ve resync bugünkü "0 müsait" yalanını
  "9 müsait" yalanına çevirir. `M15 (edge) → M18 (dış üye) → M19`; edge kurulmadan dış
  numara yolu fail-closed kapalı kalır (toll-fraud). `M20 (source) → M9 rapor kaynağı`.
- **Commit:** `c45171fd` — Kurul Karar #66: toplu karar oturumu (M1-M27) — ŞARTLI ONAY

### 20. QA/FE/SEC ajan dalının birleştirilmesi (10 kart Bitti)

- **Neden:** Paralel ajan turlarından biri (QA + frontend + güvenlik) 11 commit'le bitti;
  worktree dalı ana dala alınmalıydı.
- **Ne yapıldı:** `worktree-agent-a4df1acfd61f0df68` merge edildi, üç çakışma çözüldü.
- **Dokunulan dosyalar:** `deploy/yerel-kapilar.sh`,
  `src/Pbxtr.Web/src/app/screens/system/auditView.ts`,
  `src/Pbxtr.Web/src/app/screens/system/auditActionParity.test.ts`, `yonetim/backlog.md`
- **Çakışmalar ve çözümleri:**
  - **Kapı numarası çakışması.** Paralel ajanlar aynı numarayı aldı: bu dal `kapi_57` ve
    `kapi_58` açmış, ama o numaraları başka dallar (BR-QA-81 linux-root, BR-SYS-91) çoktan
    almıştı. Bu dalınkiler **59** ve **60** olarak yeniden numaralandı; `bash -n` temiz.
    *Ders: paralel ajanlara kapı numarası dağıtılmalı, "en büyük + 1" kuralı paralelde
    çalışmıyor.*
  - **`auditActionParity.test.ts` — testin kendi bekçisi merge hatamı yakaladı.** Borç
    listesi bir **manda**ldır (yalnız küçülür). Çakışmayı "iki tarafı da koru" diye
    çözdüm; test kırmızı oldu: `privileged.stale.denied` bu dalda **etiketlenmişti**, yani
    borç listesinden silinmeliydi. Elle "ikisini de koru" refleksi yanlıştı, mandal kuralı
    doğruydu.
- **Sonuç / doğrulama:** `tsc -b` temiz (rc=0), **vitest 1948/1948** (217 dosya).
- **Devralınan kırmızı (bu dalın işi değil):** `kapi_07` HEAD'de kırmızı —
  `20260916200000_CallDirectionUnmeasured.cs` ham SQL onay satırı eksik. `kapi_44` ise bu
  dalda **düzeldi**: `bf645efb` (BR-FE-79) `delivery-manifest.json`'u değiştirmiş ama
  `st44-role-matrix.json`'u yeniden üretmemişti — tam da BR-QA-58'in kurduğu dondurulmuş
  artefakt defterinin var olma sebebi olan sınıf.
- **Yeni bulgu (BR-QA-58):** yalnız dashboard-live değil **giriş ekran görüntüsü de
  bayat**; ikisi de BR-QA-55 altında 2026-12-11'e kadar "bilinen bayat" işaretlendi.
- **Kartlar:** BR-QA-60/45/59/58/35/39/47 + BR-SEC-13 **Bitti**; BR-QA-40 ve BR-FE-86
  **Kısmen**; BR-SEC-14 ölçüldü (kapı zaten yerinde, kalan iş yok).
- **Commit:** `26d828aa` (merge), `b149ffcc` (backlog)
- **ClickUp:** 10 kart güncellendi, doğrulama `fark olan kart: 0, izde olmayan: 0`.

### 21. BE ajan dalının birleştirilmesi — ve "ölçülmemiş öncül" üç kez çürüdü

- **Neden:** Backend ajan turu bitti (5 commit).
- **Ne yapıldı:** `worktree-agent-ac10edc113b2433b4` merge edildi (çakışma yok).
- **Dokunulan dosyalar:** `src/Pbxtr.Api/Modules/**` (monitor, audit, sms template),
  `tests/Pbxtr.Api.Tests/**`, `tests/Pbxtr.Integration.Tests/**`, `yonetim/backlog.md`
- **İnen iş:**
  - **BR-BE-113 (Bitti):** monitor/sufle/araya girme kendini hedeflemeyi 403 + denetim
    satırıyla reddediyor, sağlayıcıya hiç ulaşmıyor. Mutasyon: kapı kapalı → 3 kırmızı.
  - **BR-BE-131 (Kısmen):** `/audit` çoklu `?action=`. **Ölçüm kararı değiştirdi:** tek
    değer yolu bilerek `=` kaldı — canlı EXPLAIN'de `=` 0,35 ms (Index Cond), `ANY(3)`
    38 ms (Filter, 50.825 satır elendi). Tek değeri de `Contains`'e çevirmek mevcut
    aramayı ~100× yavaşlatırdı.
  - **BR-BE-143 (Kısmen):** bilinmeyen SMS değişkeni 400, kullanımdaki şablonu
    pasifleştirme 409, kampanya editörü için dar seçici. Seçicinin kümesini **bağlama
    kapısının kendisi** üretiyor — yani seçici ile kayıt kapısı ayrışamaz.
- **ÜÇ KARTTA KOD YAZILMADI, ÇÜNKÜ ÖNCÜL ÖLÇÜMDE ÇÜRÜDÜ** (asıl değer bu):
  1. **BR-BE-142** kilit yenileme istiyordu. Ölçüm: 22 günlük `job_runs`'ta en uzun lider
     tik 11,5 sn ve o da sabit bir timeout'tu, 09-13'te kayboldu; 09-14'ten beri ortalama
     0,11–0,14 sn. 15 sn timeout'a çarpan tik **hiç yok**, 6 günde 0 idle-in-transaction
     sonlandırması. Ölçülmüş bir arıza olmadan kilit yenileme yazılmadı.
  2. **BR-BE-76** ETag istiyordu. Ölçüm: ETag o uçta **çalışamaz** — URL çağrı başına
     değişiyor, 60 çağrı 60 ayrı URL, HTTP önbelleği hiç devreye girmiyor. Yarım çözüm
     yazmak yerine kontrat kararı gündeme alındı.
  3. **BR-BE-121** AMI-DB üyelik farkı varsayıyordu. Ölçüm: teslim edilen tenant'ta iki
     taraf birebir aynı (6+3=9); 3 satırlık fark teslim edilmeyen ikinci tenant'tan.
- **"Atlanan, geçmiş değildir":** ajan raporunda dört integration sınıfı **Skipped**
  görünüyordu (Docker o an kapalıydı). Docker geri gelince koşuldu: **21/21, Skipped 0**,
  gerçek PG'ye karşı. Bu olmadan BR-BE-113 "doğrulandı" denemezdi.
- **Yol üstünde bir tuzak:** testleri yanlış projede (`Api.Tests`) filtreyle koştum;
  `dotnet test` **"No test matches the given filter" deyip rc=0 döndü** — vacuous yeşil.
  Sınıflar `Integration.Tests`'teydi. *Ders: filtreli koşuda "geçen test sayısı" da
  okunmalı; rc=0 tek başına "koştu" demek değildir.*
- **Commit:** `625d3850` (merge), `3a3febe3` (backlog)

### 22. OPS/QA/AST dalı — ve main'in kırmızısı: iki dalın ANLAMSAL çarpışması

- **Neden:** Takip turu (3 madde) bitti; ajan raporunda "main şu anda kırmızı" uyarısı vardı.
- **Ne yapıldı:** Önce **merge etmeden main ölçüldü** (dürüst yön): `Architecture.Tests`
  **648/650, 2 kırmızı**. Yani iddia doğrulandı — ama ajanın gördüğü 1 değil **2** taneydi.
  Sonra dal merge edildi ve ikinci kırmızı da kapatıldı → **650/650, Skipped 0**.
- **Dokunulan dosyalar:** `src/Pbxtr.Infrastructure/Platform/Jobs/PlatformRollupJob.cs`,
  `src/Pbxtr.Api/Platform/Health/SystemHealthProbe.cs`,
  `tests/Pbxtr.Architecture.Tests/TenantLeakCoverageTests.cs`, `tests/**`
- **Kırmızı #1 — bekçi ile yeni alan çarpıştı.** Ş-46-9 bekçisi (`ff95be52`) *"sistem özeti
  yalnız SAYI taşır"* diyor; BR-AST-14 (`1c6b9dd1`) özete `bool? StasisApplicationRegistered`
  ekledi. **İkisi de tek başına yeşildi; kırmızı yalnız merge'den sonra doğdu.** Çözüm:
  izinli tür kümesine `bool` bilinçle eklendi — Ş-46-9'un çizdiği sınır *"sayı mı"* değil
  **anahtar uzayı olan bir tür mü**; `bool?` üç değerlidir, içine nesne adı ya da tenant
  kodu yazılamaz. Karşıt kontrol dosyada duruyor: `string` ve `string` anahtarlı sözlük
  hâlâ reddedilir (mutasyonla doğrulandı).
- **Kırmızı #2 — kendi mandalım beni yakaladı.** `TenantLeakCoverageTests` borç listesi
  (bu sabah BR-QA-52'de kurulmuştu) `SmsTemplateAdministration`'ı borç sayıyordu; BE dalı
  o adaptöre sızıntı testi eklemişti. Mandal kuralı gereği borçtan çıkarıldı ve
  `BorcTavani` 66 → 65 indirildi. *Liste yalnızca küçülür — kapanan borcu listede
  bırakmak sayıyı yalan yapar.*
- **BR-QA-88 (Bitti) — "boş gövde" bulmacasının sebebi:** vacuity vakası paylaşılan fikstür
  DB'sine `pbxtr_sys.mail_settings` yazıp **silmiyordu** → notifier operasyonel oldu → uç
  503 JSON yerine 202 + boş gövde döndü. Temizlik artık **geri okunuyor** (0 değilse sınıf
  kırmızı biter). Bu, bellekteki "tohum bırakan test başka sınıfı kırar" deseninin aynısı.
- **BR-OPS-01 (Kısmen) — ölçüm bir vacuity buldu:** `t0007`'nin çalışma saati profili yok →
  sessizlik metriği açık dakika saydığı için `null` kalıyor ve alarm **eşik ne olursa olsun
  yanmıyor**; buna rağmen kapsam satırı o tenant'ı "kurulu" sayıyordu. #26'ya onuncu sayı
  eklendi (açık kuralı olan ama aktif profili olmayan tenant), sağlık satırında üç cevap
  (ölçülemedi / 0 / >0 → **sarı**), müdahale metni #07 takvim tanımlama.
- **Commit:** `8a581a5d` (merge + main düzeltmesi), `61ffd417` (backlog + gündem tur2)
- **ClickUp:** doğrulama `fark olan kart: 0, izde olmayan: 0`.
- **Sonraki tur için gündem:** `yonetim/kurul-gundem-2026-09-17-tur2.md` (N1–N11) —
  QA turundan 4, BE turundan 6 soru + BR-BE-142'nin kapsam sorusu.

### 23. Köprüleme dalı — "redirect 204 döndü ama hiçbir şey yapmadı"

- **Neden:** BR-AST-60 (ARI köprüleme) turu bitti; kör aktarma, Ş43-3/14/15 ve geri-çağrı
  tonu inmişti.
- **Ne yapıldı:** `worktree-agent-ad5f7ead59c16fb69` merge edildi (12 dosyada çakışma),
  iki yeni kusur kartı açıldı, BR-AST-59'un durumu düzeltildi.
- **Dokunulan dosyalar:** `src/Pbxtr.Infrastructure/Telephony/Asterisk/{AriCallBridge,AriStasisApp,AriStasisDiagnostics,AsteriskAriProvider}.cs`,
  `src/Pbxtr.Api/Platform/Health/SystemHealthProbe.cs`,
  `src/Pbxtr.Domain/Platform/Observability/ISystemHealthProbe.cs`,
  `src/Pbxtr.Web/src/app/screens/system/platformApi.ts`, 9 dilin i18n dosyası,
  `yonetim/backlog.md`, `yonetim/kurul-gundem-2026-09-17-tur2.md`
- **ASIL BULGU — sessiz başarı yalanı.** Kontrol grubu olarak ham ARI çağrıldı:
  `POST channels/{cust}/redirect` → **HTTP 204** döndü ve köprü üyeleri **iki ölçümde
  birebir aynı** kaldı. Yani aktarma hiç olmadı; panel "aktarıldı" derdi, müşteri agent'la
  konuşmaya devam ederdi. Bu, bellekteki "belge santral değildir" ve "kod var, koşan yok"
  desenlerinin üçüncü yüzü: **uç 2xx döndüğü hâlde hiçbir şey yapmıyor.** Kör aktarma bu
  yüzden köprü üzerinden yeniden yazıldı ve ölçüldü: `Accepted=True`, 2 sn içinde köprü
  `{X}-cust,{X}-xfer1`, aktaran agent kanalı yok; meşgul hedefte 3 sn içinde 0 kanal
  (müşteri köprüde yalnız kalmıyor).
- **Önceki turun kırmızısının sebebi:** canlı test `AriStasisApp`'i **uygulama adı vermeden**
  kuruyordu; aktarma bacağı üretim `pbxtr` uygulamasına kaydolup testin soketine hiç
  gelmiyordu. Dikiş: `application: App`.
- **Çakışma — iki dal AYNI SORUYA iki sağlık satırı ekledi.** BR-AST-14
  `asterisk-stasis-app` (kaynak: registration-sampler → Redis özeti) ve Ş43-14(i)
  `asterisk-stasis-registration` (kaynak: süreç içi gözlem döngüsü) ikisi de *"Stasis
  uygulaması kayıtlı mı"* diye soruyor, ikisi de aynı ARI ucundan. **Birleşim alındı** —
  ikisi de ölçülmüş iş, kaynakları ayrışabilir (örnekleyici bayatlar; gözlem döngüsü soket
  kapalıyken `Unmeasurable` döner) ve hiçbir sinyal atılmadı. Hangisinin kalacağı bir UI
  kararı olduğu için kurul gündemine **N12** yazıldı. Birleşim doc yorumunu bozdu
  (`/// <summary>` açıcısı kayboldu), derlemede yakalandı ve düzeltildi.
- **Sonuç / doğrulama:** Architecture **650/650**, Api.Tests Telephony+Health **1296 geçti /
  1 görünür Skip** (canlı ARI testi, izin listesinde), `tsc -b` temiz, **vitest 1948/1948**,
  `dotnet format` temiz.
- **İki gerçek kusur kart oldu** (numaralar önce ölçüldü: BR-AST max 92, BR-SYS max 103):
  - **BR-AST-93 (P1):** köprülemede **aynı dosyaya iki `MixMonitor` yazıcısı**. Müşteri
    bacağı da `-out` bağlamından geçiyor ve `PBXTR_REC` aynı `linkedid`. Agent kanalındaki
    `b` seçeneği iki yönü de kaydediyor, yani ikinci yazıcı gereksiz. Düzeltme provizyon
    çıktısını değiştirdiği için bilinçle kapsam dışı bırakıldı.
  - **BR-SYS-104 (P2):** Ş43-14(iii) fd/`maxfiles` **üç yolun üçünden de** okunamıyor:
    ARI'de uç yok, AMI `command` Karar #46 ile kilitli, host ajanı katalogunda
    `core show settings`/`core show fd` yok.
- **BR-AST-59 düzeltmesi:** ajan bunu "kurula soru" diye bıraktı, ama Karar #66 **M9**
  seçeneği (2)'yi zaten seçmişti. Kart "kurul bekliyor"dan çıkarıldı; Ş66-8 şartlarıyla
  uygulama bekliyor ve sıra şartı ajana yazıldı (**M10 `state_interface` önce** — yoksa
  kuyruk, konuşan agent'a ikinci çağrı çaldırır).
- **Temizlik dersi:** sunucuda adı **iki CR taşıyan** bir artık dosya kalmıştı
  (`t9060-olcum60.conf\r\r`). `rm -f <temiz ad>` ve `stat` onu **bulmuyor**, `ls`
  gösteriyordu; Asterisk `*.conf` glob'una uymadığı için hiç yüklenmemişti. `find -delete`
  ile silindi. *CRLF'li betikten `docker cp`/`touch` yapılan dosya adları sessizce CR taşır
  ve "sildim" iddiası doğrulanamaz.*
- **Commit:** `5d72444c` (merge), `8ea17dae` (backlog + iki kart + N12)
- **ClickUp:** 2 yeni kart açıldı (539), doğrulama `fark olan kart: 0, izde olmayan: 0`.

### 24. Epik BR-A3 — Scripter faz 2 (Bitti)

- **Neden:** Kullanıcı kararı: büyük özellik epikleri "hepsi şimdi yapılsın".
- **Ne yapıldı:** `worktree-agent-a820255300181aaaf` merge edildi. Kapsam backlog'da
  yazılıydı ve **büyütülmedi**: `BR-A3 = BR-FE-16` (koşullu adım görünürlüğü) `+ BR-FE-17`
  (adım başına katlanır bilgi notu — Karar #29 (11)'in "ayrı bilgi bankası modülü YOK"
  karşılığı). Faz 1'in teslim ettiği her şey yerinde bırakıldı.
- **Dokunulan dosyalar:** `src/Pbxtr.Domain/Modules/Scripter/{ScriptRunnerRules,ScriptDefinition,ScriptDefinitionValidator,ScriptRules}.cs`,
  `src/Pbxtr.Api/Modules/Scripter/ScriptDtos.cs`,
  `src/Pbxtr.Web/src/app/screens/agent/{ScriptRunner.tsx,scriptApi.ts}`,
  `src/Pbxtr.Web/src/app/screens/campaigns/{ScriptStepEditor,ScriptPreview,CampaignScriptScreen}.tsx`,
  `tests/Pbxtr.Api.Tests/Modules/Scripter/ScriptConditionalStepTests.cs` (yeni, 31 test),
  `deploy/nginx.conf`, `deploy/demo/nginx-demo-cloudflare.conf`, `deploy/nginx-dogrula.sh`,
  `doc/prototip-urun-farklari.md`
- **Tasarım kararı — görünürlük sunucuda:** `step.visibleWhen[]` agent DTO'suna **hiç
  inmiyor**; koşulu tutmayan adım `ScriptRunnerRules.NextStepKey` içinde atlanıyor ve iki
  çağıran (GET oturum + POST adım) **aynı metottan** geçiyor, yani kural tek yerde. Hamle
  tavanı adım sayısı kadar — bozuk bir yayın masayı döngüye sokamaz.
- **En kritik yeni kural `condition_field_unreachable`:** koşulun okuduğu cevap o adıma
  gelmeden verilemiyorsa adım **hiçbir zaman** görünmez. Bu tamamen sessiz bir kayıp olurdu;
  yayın kapısı artık reddediyor (`DirectedGraph.Reaches`).
- **GÖVDE TAVANI DEĞİŞTİ ve elle doğrulama betikle değiştirildi.**
  `ScriptRules.MaxDefinitionBytes` 8 → 9 MiB, nginx taslak yolu 9m → 10m (3 dosya). Sebep:
  bilgi notu tanımın parçası; sayılmasaydı *"doğrulamayı geçen her script kaydedilebilir"*
  şartı (BR-BE-65'in kendisi) sessizce yalan olurdu. Ajan aritmetiği **elle** doğrulamıştı
  (`deploy/nginx-dogrula.sh` Windows'ta koşmuyor). Koordinatör betiği **ubuntu
  konteynerinde** koşturdu ve betiğin kendisi doğruladı: *"script taslak tavanı kod ile
  bağlı (uygulama 9 MiB, nginx 10m, 3 yer) TAMAM"*. Betiğin son adımı iç içe docker
  olmadığı için **ölçülemedi** (rc=2) — o adım nginx'in kendi ayrıştırıcısını ister ve ilk
  yayın koşusunda görülecek.
  *Yol üstünde:* `docker run -w /repo` Git Bash'te `C:/Program Files/Git/repo`'ya çevrildi;
  `MSYS_NO_PATHCONV=1` ile aşıldı (bellekteki "Git Bash yol çevrimi kapıyı öldürür" deseni).
- **Sonuç / doğrulama:** Scripter **152/152** (yeni sınıf 31/31), Architecture **650/650**,
  `tsc -b` rc=0, **vitest 217 dosya / 1959 test** (taban 1948 → +11), `dotnet format` temiz.
  Mutasyon **7/7** kırmızı: görünürlük atlaması kaldırıldı (7 kırmızı), erişilebilirlik
  kuralı kapatıldı, `visibleWhen` DTO'ya sızdırıldı, not tavanı düşürüldü, `useEffect`
  bağımlılığı boşaltıldı, `/` kısayoluna `whileTyping` verildi, tel biçiminden alan düştü.
- **Bilinçli borç A3-6 (fark belgesinde yazılı):** bir alanın anahtarı değişince **başka**
  adımların o alana bakan koşulları editörde temizlenmiyor; sunucu
  `condition_field_not_found` ile **reddediyor** ve engel ilgili adımın üstünde görünüyor —
  yani sessiz kayıp yok. Adım **silmede** temizlik yapılıyor. Tam çözüm alan düzenlemesini
  ekran seviyesine taşımayı gerektiriyor.
- **Ajanın bildirdiği "ilgisiz kırmızı" zaten kapanmıştı:** dalının tabanında Ş46-9 bekçisi
  kırmızıydı; o çarpışma bu turda main'de çözülmüştü (madde 22), yani dalı bayat tabandan
  bakıyordu. Yeni bir kart gerekmedi.
- **Fark belgesi:** Scripter satır 4 BORÇ → "VAR ve KAPANDI"; madde (11) bilgi bankası
  **KAPANDI** (karşılık adım notu olarak teslim edildi, kayıt defterine yeni satır
  eklenmedi); yeni tablo **A3-1..A3-6**.
- **Commit:** `c94c645d` (merge)
- **ClickUp:** `BR-A3 → complete`, doğrulama `fark olan kart: 0, izde olmayan: 0`.

### 25. Kurul Karar #67 - ikinci toplu oturum: koordinatorun DORT hatasi curutuldu

- **Neden:** Karar #66'dan sonra ajan raporlarinda 12 soru daha birikti.
- **Ne yapildi:** Gundem `kurul-gundem-2026-09-17-tur2.md` (N1-N12), 10 uye paralel oylandi,
  Karar #67 yazildi.
- **Sonuc:** SARTLI ONAY. Seytan **2 HAYIR** verdi ve **ikisinde de hakli cikti.**
  **Asil cikti, gundemi yazan koordinatorun (benim) dort hatasinin curutulmesidir:**
  1. **N2 - kapanmis bir karari geri aliyordum.** `BR-FE-66` Karar #36 (5) ile SARTLI ONAY
     almis ve **dorduncu** secenege baglanmisti; gundemin sundugu iki secenek o oturumda
     **son kullanicilar tarafindan adiyla reddedilmisti** (agent: "tire gorunce kimse
     beklemiyor sanirim", supervizor: "yanlis sayi beni yanlis yone goturur"). Dort uye
     (CTO, FE, cm-agent, Seytan) **bagimsiz olarak** yakaladi. Karar #36 aynen yururlukte.
  2. **N4 - cevap zaten inmis.** (a) Karar #37'yi geri alir, (b) kullanicinin 2026-09-06
     reddine carpar, (c)'nin regex ayagi A11'de reddedilmis ve `.pcap` icin imkansiz oldugu
     olculmus. `BR-SEC-03`(a) **kapatildi**; kalan is tespit (`BR-QA-89`).
  3. **N9 - karti yanlis aktariyordum.** `BR-BE-130` `trigger=null`'i "yalniz elle" diye
     **tanimlamamis**; tersini yazmis (**baglama aninda** NULL reddedilir). Iki ayri yuzeyi
     karistirdim. Yeniden cercevelendi: satirda NULL kalir (elle gonderim kipi korunur),
     baglamada reddedilir, S52-3 metni duzeltilir.
  4. **N1 yasak listesi - liste oldugu gibi gecseydi kapi ilk kosuda kirmizi dogardi.**
     Taban uc kisi tarafindan ayri ayri olculdu (db-lider, backend-lider, ben):
     `SECURITY DEFINER` **75**, `DROP FUNCTION` **102**, `DO` blogu **30**,
     `DISABLE ROW LEVEL SECURITY` **0**, `GRANT ... TO PUBLIC` **1**. Naif `TO PUBLIC`
     taramasi 53 satir esliyor, **52'si** `INSERT INTO public.` yanlis pozitifi.
     Liste **bolundu**: 2 desen simdi DENIED, 3'u onay-gerektiren sinifa ve ancak bicim
     indikten **sonra**.
- **Uyelerin buldugu, gundemde olmayan uc gercek kusur:**
  - **Supervizor:** mudahale `penalty: 0` ile ekliyor -> **`BR-BE-164`** (asagida olculdu).
  - **Seytan I6:** `QueueMembershipSyncJob` mudahale uyesi icin **`QueueRemove` atmiyor** ->
    uye santralde suresiz kaliyor, DB'de hic gorunmuyor -> **`BR-BE-165`**.
  - **Frontend Uzmani:** **S47-4 yazilmis ama koda inmemis** - `LiveAlarmsScreen`
    `ruleSource`'a hic bakmiyor, kural yalnizca *kazara* dogru -> **`BR-FE-89`**.
- **Yan cikti - bayat belge satiri gereksiz bir indeks karari uretmek uzereydi.**
  `IAuditLogQuery.cs` iki yerde "actor_user_id'de indeks YOKTUR" diyordu; migration
  `20260816130000` o indeksi bir ay once yaratmis. N7 "38 ms yavas, dorduncu indeks
  ekleyelim mi" diye oylaniyordu; db-lider olcumun **aktorsuz** alindigini ve KVKK
  sorusunun daima aktorlu oldugunu gosterdi (aktor indeksinde 0,21-4,7 ms). Satir
  duzeltildi (`042baa26`).
- **Commit:** `c422ba89` (Karar #67 + 4 kart), `042baa26` (bayat satir)

### 26. `penalty: 0` - oylama sirasinda bulunan, canlida dogrulanan kusur

- **Neden:** Supervizor N8'i oylarken koda bakti ve `AgentInterventionService.cs:197`'de
  mudahalenin `QueueAddAsync(..., penalty: 0, ...)` ile gittigini gordu.
- **Ne yapildi / olcum:** Once yapi dogrulandi - diger **her** yol (uyelik senkronu, izin
  isi, kuyruk yonetimi) uyenin **saklanan** `Penalty` degerini geciriyor; yalniz mudahale
  sifir sabitliyor. Asterisk'te **dusuk penalty once cagrilir**. Sonra canli olcum:
  `queue_members` 12 satir - **9 satir penalty 0, 3 satir penalty 1**.
- **Sonuc:** Penalty fiilen kullaniliyor, yani mudahaleyle eklenen kisi o 3 uyenin
  **onune geciyor**. Kusur gizli degil, bugun gorunur. Supervizorun tarif ettigi belirti:
  SLA duzelir ama FCR/donusum duser ve bu ancak vardiya sonunda fark edilir.
- **Kart:** `BR-BE-164` (P2), olcum kartin durum hucresinde yazili.
- **Commit:** `83eeefb3`

### 27. `main` benim yuzumden derlenmiyordu - ve bunu bir ajan buldu

- **Neden:** DB ajani kendi isini kosarken `Pbxtr.Integration.Tests`'in **hic
  derlenmedigini** bildirdi.
- **Olcum:** Dogrulandi - `RegistrationAxisHttpTests.cs` `AriStasisApplicationProbe` ve
  `AsteriskOptions` kullaniyor ama `using Pbxtr.Infrastructure.Telephony.Asterisk;` yok
  -> **CS0246 x2**, projenin tamami kirmizi.
- **Sebep bende:** O dosya `8a581a5d` (OPS merge) ile geldi. Merge'den sonra
  `Architecture.Tests` ve filtreli `Api.Tests` kostum, yesil gordum, push ettim -
  **`Integration.Tests`'i hic derlemedim.** Kirmizi saatlerce gorunmedi.
- **Duzeltme:** Tek satir `using` (`d4b9e62e`). Bellege yazildi: *merge sonrasi her test
  projesi en az DERLENMELI*; artik her merge'de ucu de derleniyor ve commit mesajina
  hangi takimin kostugu yaziliyor.

### 28. DB dali + Karar #68 (db-lider yazili onayi)

- **Ne yapildi:** DB dali merge edildi: `kapi_07` onay satiri, `BR-DB-62` (tenants degismez
  kolon tetikleyicisi + refresh migration), `BR-DB-65`, `BR-DB-50/46`.
- **Onay satiri dogrulandi:** Yeni migration `Karar#62`'ye dayaniyor. Karar #62'nin
  **secenek (c)**'si birebir "pbxtr_app icin yazilamaz kolonlara rol bazli BEFORE UPDATE
  tetikleyicisi + 02-guards bekcisi" diyor ve Asterisk Uzmani'nin "id de tetikleyiciye
  girsin" sarti da karsilaniyor. Onay satiri ham SQL'i geciren mekanizma oldugu icin bu
  kontrol atlanamaz.
- **Canli olcumler:** `BR-DB-50` DETACH kilidi - uzun transaction'da eszamanli INSERT
  **7.020 ms** bekledi, kisa transaction kolunda **5,7 ms** (kontrol grubu farki gosterdi).
  `BR-DB-52` retention kosusu atilir tenant'ta (demo verisine dokunulmadi, oncesi/sonrasi
  sayimla dogrulandi): 343 ms, 20000/20000 + 60000/60000, partition'lar dustu.
- **Karar #68 (kurul degil, db-lider):** `ci-check.sh:491-493` kapisinin **kendi gerekcesi**
  db-lider yazili onayi + karar kaydi istiyor. db-lider SARTLI ONAY verdi ama gerekceyi
  duzeltti: envanter "kismi olan her indeks" degil **"yuklemi garantinin parcasi olan
  indeks"** listesidir. En kritik sart **S68-5**: kismi tekil indeks, yuklemsiz
  `ON CONFLICT`'te **42P10** verir (S36-14'te PG16'da olculmus) ve taslakta yuklem yazili
  degil. Karsi-kontrol: kartin "ikiye katlar" cumlesi **bugun turetimdir, gozlem degildir**
  - iki eszamanli aktorle olculmeden `BR-DB-44` "Bitti" sayilmaz.
- **Commit:** `d324c299` (merge), `62ddf08f` (Karar #68)

### 29. BR-8 - ajan gorev metnimi duzeltti

- **Ne yapildi:** Calisma saati disi otomatik mola merge edildi (`c3576e3e`).
- **KAPSAM DUZELTMESI (ajan hakliydi):** Ben "vardiya planindan mola uretimi" yazmistim.
  Kartta yazili olan bu degil: **WFM/vardiya plani Karar #29 ile ERTELENDI**; gercek kart
  tek bir borc satiri (tenant parametresi + `working_hours` + `QueuePause` + DST testi).
  Vardiya tablosu **yazilmadi** ve bu bilincli. Ayrica gorev metnimde bir uyariyi Karar #66'ya
  atfetmistim; o uyari Karar #29'da - yanlis atif, ajan duzeltti.
- **DST olcumu (asil kabul kriteri):** Europe/Berlin, kapanis penceresi yerel 02:00-03:00:
  ileri alinan gunde kapali tick **0**, geri alinan gunde **8**, kontrol gununde **4**.
  Bu uclu anti-vacuity kontroludur - gecisin gercekten olculdugunu gosterir. Ikinci gecisde
  ikinci mola dogmamasinin sebebi bir DST ozel dali degil, istenen-durum karsilastirmasi.
- **Tasarim notu:** `suppressed_by_leave` **yeniden kullanilmadi** - ikisi ayni anda dogru
  olabilir ve tek kolon paylasilsaydi biri otekinin izini silerdi. Fail-safe: canli durum
  okunamazsa **duraklatma yapilmaz** ("bilmiyorum" = "cagrida").
- **Yeni kart:** `BR-FE-90` - sunucu hazir, #49'da anahtar yok (deponun baskin hata deseni).
- **ClickUp:** 544 -> 545 kart, dogrulama "fark olan kart: 0".

### 30. SYS/confd dali - ajan talimatimdan bilincle sapti ve hakliydi

- **Ne yapildi:** 12 commit merge edildi (`91611d48`). M26, M11, M25,
  `BR-SYS-52-B`, `BR-AST-28` Bitti; M27, `BR-SYS-58/66` Kismen.
- **M26 canli kanit:** `pbxtr-t0007-in` artik **tek dosyadan** geliyor
  (`t0007-dialplan.conf`); elle yazilmis `8001` gitti ve urunun `_X.` deseni gelen
  yolun tek sahibi. Sapma bekcisi S6 **SAPMA -> TAMAM**. Lab trafigi kesilmedi
  (CDR 2351->2353, yeni satirlarin baglamlari `pbxtr-lab-*`). Bu, dialplan
  ajaninin `BR-AST-58` (M16) isini acan on kosuldu.
- **M11 canlida fiilen atesledi:** cok tenant'li dugumde tek-tenant araci
  `ExecMainStatus=78` ile durdu ("bu dugum COK TENANT'LI (3 tenant)"). Sabit
  `t0007` kalkti; elle onek bu kapiyi asmiyor.
- **`BR-AST-28`:** CLAUDE.md §3.1'in laboratuvar olcumu **gercek santralde**
  tekrarlandi - uretimde `pjsip reload` komutu HIC YOK; kontrol grubu
  (`dialplan reload`) ayni turda yeni dosyayi ALDI.
- **Kendi olcum araci sessizce gecersizmis (`BR-SYS-87`):** sahte `wget`
  kurulmuyordu, ajan exit 69 veriyordu; yani arac bir sayi uretiyor ama hicbir
  sey olcmuyordu (*arac yoklugu sifir gibi gorunur*). Duzeltilince oncul yeniden
  dogrulandi: N=50 -> 2.270 cagri, T~301 s > `TimeoutStartSec` 240, yani
  **38-tenant isletme kurali duruyor**.
- **AJAN TALIMATIMI REDDETTI VE HAKLIYDI.** "Yeni kapin 61'den baslasin" demistim.
  Ama `kapi_58`'i onceki turda **main almisti** (merge `1d1596cb`); 61'de birakmak
  ayni kapiyi iki kez tanimlardi ve **merge'de biri sessizce kaybolurdu**. Ajan
  58'i oldugu yerde birakip 62/63/64 kullandi. Merge'de catisma yine kapi
  numarasindan cikti; dalin GUNCEL `kapi_58`'i (7 iddia etiketi) alindi, HEAD'in
  59/60'i korundu, dalin 62/63/64'u eklendi ve **mukerrer tanim olmadigi
  programla dogrulandi** (63 kapi, 0 mukerrer).
- **Sapma bekcisinin kendi durustlugu:** selftest'i git'siz konteynerde kosturdum
  -> "git YOK - bu YESIL DEGILDIR", exit 2. Sessiz yesil uretmiyor. git kurulunca
  23/23 iddia gecti.
- **Ajanin urun acigi iddiasini DARALTTIM.** "Asterisk yeniden baslarsa dinamik
  kuyruk uyeligi TAMAMEN kaybolur ve hicbir kod geri itmez" dedi. Olctum:
  `QueueMembershipSyncJob` **once `QueueStatus`, sonra yalniz eksik icin
  `QueueAdd`** yapiyor - yani `queue_members`'ta kayitli uyelik geri itiliyor.
  Bosluk dar ve zaten `BR-BE-165`'in konusu: **DB'de hic gorunmeyen** (mudahale)
  uyelik. Mukerrer kart acilmadi, duzeltme mevcut karta yazildi (`41e6b2de`).

### 31. BR-AST-59 devralma - queue_log gorusme suresini SIFIR yaziyor

- **Ne yapildi:** M9 devralma mekanizmasi merge edildi (`b15a2229`); tenant
  bazinda opt-in, **varsayilan KAPALI**, bayrak kapaliyken uretilen dialplan bayt
  bayt ayni.
- **ASIL OLCUM - bir sarti tercihten zorunluluga cevirdi:** devralmadan sonra
  `queue_log` **`COMPLETEAGENT|0|0`** yaziyor, yani **gorusme suresi 0**. Ne
  `TRANSFER` ne `COMPLETECALLER`. Sonuc: **AHT ve SLA `queue_log`'dan okunamaz.**
  Karar #66 S66-8/7 "sureler `call_events`+`linkedid`'den hesaplanir" diyordu;
  bu olcumden sonra o bir tercih degil, tek secenek.
- **Dogrulanan diger sartlar:** `linkedid` KORUNUYOR (korelasyon bozulmuyor,
  ikinci "cevaplandi" satiri yok); MixMonitor **kesilmiyor** (44 -> 165.484 bayt,
  ~16 KB/sn); kontrol grubu - devralmadan ONCE ham ARI `hold` **409
  NotUnderControl**, SONRA kabul ediliyor.
- **Iki varsayim canlida curudu ve kod olculene gore duzeltildi:**
  1. *"ARI'de `POST bridges/{id}` idempotenttir"* -> **degil**: ikinci bacak 409
     alip dialplan'e dondu ve devralma yarim kaldi. Artik once varlik sorulur.
  2. *"Dialplan'deki `Bridge(${PBXTR_CTL_PEER})` yarim kalmayi kurtarir"* ->
     **kurtarmiyor**. Bu, Karar #66 S66-8/4'un metniyle celisiyor (asagida).
- **KOORDINATOR DUZELTMESI - migration ham SQL ile yazilmisti.** Dal kolonu
  `migrationBuilder.Sql("ALTER TABLE ...")` ile ekliyordu; bu,
  migration-compatibility kapisini **RED** ediyordu ve bu migration icin bir kurul
  onay satiri **yok**. Dogru cozum onay satiri yazmak **degildi** - kolon ekleme
  EF API'siyle ifade edilebiliyor (emsal ayni gunun `OffHoursAutoBreak`'i). Ham
  SQL kaldirildi: `AddColumn<bool>(..., comment:)` + `DropColumn`; yorum metni
  kaybolmadi cunku Npgsql `comment:`i `COMMENT ON COLUMN`'a ceviriyor.
  Kapi **RED -> OK**.
- **Catisma:** iki dal da `tenant_settings`'e kolon ekledi
  (`auto_break_outside_hours` / `ari_takeover_enabled`). Birlesim alindi ama
  birlesim bir **fluent zinciri ortasindan boldu** (CS1002); zincir tamamlandi.
- **Olcum:** uc test projesi de derleniyor, Architecture **667/667**, Api.Tests
  Telephony **1278 gecti / 2 gorunur Skip** (ikisi de canli test, izin listesinde),
  migration guard OK; ajanin mutasyonu 13/13 kirmizi.
- **Kurula gidecek tek madde:** **S66-8/4'un metni olcumle celisiyor.** Sart
  "biri duserse cagri dusmez, musteri bacagi kuyruga ya da onceki kopruye doner"
  diyor; olcum, yalniz bir bacak tasindiginda cagrinin **tamamen dustugunu**
  gosterdi. "Cagri dusmez" garantisi dialplan'den **gelmiyor**; bugun tek eylem
  (`ExtraChannel`) + "Stasis uygulamasi kayitli mi" on kosulu ile saglaniyor.
  Sart bu olcume gore yeniden mi yazilsin, yoksa ek kurtarma yolu mu isteniyor?
- **Saha kapali kaliyor:** S66-8/1 sira sarti geregi `BR-AST-55` inmeden bayrak
  acilmaz. Kod hazir, bayrak bugun yalnizca SQL ile acilabiliyor (ekran/uc yuzeyi
  yok - bilincli, ayri kart).

## Açık kalanlar / sonraki adım

- Backlog'da kalan kartlara devam (`yonetim/backlog.md`); büyük kısmı canlı PBX/sunucu
  işi (bu oturumda erişim salt-okunur) veya kurul kararı bekliyor.
