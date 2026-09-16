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
- **Bir bekçinin mesajı, bekçinin yarısıdır.** Ne yapılacağını söylemeyen kırmızı,
  "geçsin diye" güncellenen bir listeye dönüşür.
- **"Kuyruğa girdi" bir teslim kanıtı değildir.** Denetim iddiaları, incelemecinin
  okuyacağı yerden — tablodan — geri okunmalı.
- **Paylaşılan bir önbellek, bekçilerin en sessiz düşmanıdır.** Hız kazancı alınır ama
  "üç ayrı soru" iddiası ölçülmezse kapılar tek kapıya çökebilir ve bunu kimse görmez.
- **Parite bekçisinin yönü tutucudur.** Kaçan ölü satır riski alınır, yanlış alarm
  alınmaz — çünkü yanlış alarm veren bir kapı kaçınılmaz olarak silinir.

## Açık kalanlar / sonraki adım

- Backlog'da kalan kartlara devam (`yonetim/backlog.md`); büyük kısmı canlı PBX/sunucu
  işi (bu oturumda erişim salt-okunur) veya kurul kararı bekliyor.
