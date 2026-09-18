# pbxtr — 2026-09-18

## Bağlam

17'sinin gecesinden kesintisiz devam eden tur. Dünkü dosya: `2026/09/17/pbxtr.md`
(bölüm 1–33). Hedef aynı: `yonetim/backlog.md`'deki tüm açıkları bitirmek.
Bu dosya, gün sınırını geçtikten sonraki işi taşıyor.

Güne başlanan durum: BR-9 (sesli mesaj) dalı **merge edilmiş ama commit edilmemiş**
(33 dosya, çatışmalar çözülmüş), kurul tur 5'in 10 oyu + QA denetimi gelmiş ama
karar kaydı yazılmamıştı.

## Yapılanlar

### 34. Kurul tur 5 → Karar #71: onay satırı BU TURDA YAZILMADI

- **Neden:** Sesli mesaj migration'ı (`20260917211340_VoicemailMessages.cs`) contract
  kapısında **rc=1** veriyordu ve geçmesi için onay defterine bir satır gerekiyordu.
- **Ne yapıldı:** Kurul toplandı (tur 5, 4 soru), **10/10 ŞARTLI** çıktı — ama
  **onay satırı yazılmadı** ve bugünkü blob `95d789bd…` **onaylanmamış** ilan edildi.
- **Oyların gövdesi kaybolmuştu ve kurtarıldı:** context sıfırlanınca 11 oyun metni
  bağlamdan düşmüştü. `tasks/*.output` dosyalarının **hepsi 0 bayt** çıktı (sonuçlar
  yalnız bildirimle gelmiş, dosyaya yazılmamış). Oylar transkript JSONL'inden
  `oy_cikar.py` ile çıkarıldı — 11/11 kurtarıldı, 6–19 KB arası.
  **Ders:** ajan sonucu `.output` dosyasında olmayabilir; transkript tek kalıcı kopyadır.
- **Üç bloke edici sebep:**
  1. **Şeytan itiraz 1 (kabul):** Karar #70'in onayı açıkça *"bu dosya hiçbir SQL
     şablonu okumuyor"* ölçümüne dayanıyordu. **Bu dosya ikisini de okuyor**
     (`Read(RlsTemplate)` + `Read(Guards)`). Kapı çıktısında gözle görünür: 6 bulgunun
     **3'ü şablon içeriğinden**. Onay satırı yazılsaydı Ş69-10 deliği (onay `.cs`
     blob'unu çıpalar, o dosyanın **koşturduğu** şablonu çıpalamaz) bu dosya için
     fiilen açılırdı.
  2. **db-lider Ş71-1..Ş71-4** bloke edici.
  3. **Blob zaten değişecek** → bugünküne onay vermek anlamsız.
- **Sunucuda ölçülenler** (`176.88.41.220`, PG 16.14, `BEGIN…ROLLBACK`, geri alma
  doğrulandı; sunucu saati `Thu Sep 17 22:07:14 UTC 2026`):
  - **Q1-b çözüldü.** `IX_result_codes_tenant_id` **ölü değil** (`idx_scan = 431`,
    `stats_reset` NULL yani sayaç hiç sıfırlanmamış). Ama aynı transaction içinde
    plan A/B: `Index Scan using IX_result_codes_tenant_id` → **`Index Only Scan using
    ak_result_codes_tenant_id`**, aynı `Index Cond`. Erişim yolu kaybolmuyor,
    **yükseliyor**. Ve desen zaten üretimde: `queues.ak_queues_tenant_id`
    `idx_scan = 2211`, `queues`/`extensions`'ta ayrı `IX_*_tenant_id` **yok**.
  - **Kilit penceresi 579 ms / 34 ilişki** AccessExclusive — "16 ms" değil. O 16 ms
    DDL'in *işidir*, kilidin *süresi* değildir (EF tek transaction, kilit COMMIT'e
    kadar, arada 01/02 şablonunun 9366 satırı).
  - `lock_timeout = 0` → migration çakışan bir kilide rastlarsa **sonsuza kadar
    bekler** ve 34 tablo üzerinde pending AccessExclusive tuttuğu için arkasındaki
    her okuyucu da kuyruğa girer. 579 ms bir kesinti **garantisi değil**.
  - Kolon listeli `SET NULL` **canlı şemada fiilen kuruldu** (sürüm numarasına
    bakmakla yetinilmedi); `pg_get_constraintdef` kolon listesini geri verdi.
  - **Şeytan itiraz 3 GERİ ÇEKİLDİ** — kendi yazdığı şartla.
- **P0 bulgu (Şeytan 5, kendim doğruladım):** CLAUDE.md §13/2 *"indirme hiçbir koşulda
  yoktur"* **kodda ihlal ediliyor**. `EfRecordingAccess.FindByCallAsync` yalnız
  `LinkedId == callId` bakıyor; tüm `src/` içinde `"vm-"` önekini **reddeden tek satır
  yok** (tek isabet `VoicemailStoredName.KeyPrefix` sabiti); ve kodda atıf yapılan
  **`VoicemailDownloadSurfaceTests` depoda hiç yok**. Yani `recording.download`
  yetkisi olan biri `vm-<linkedid>` yazarak sesli mesajı indirir.
- **Commit:** `740fb6c0` — kapı **bilerek kırmızı** bırakıldı ve sebebi commit
  mesajına yazıldı.

### 35. Q4'ün TAMAMI çürüdü — ve çürüten şey Şeytan'ın sorusuydu

- **Neden:** Gündeme *"üç kart iki kez tanımlı, ClickUp senkronu sessizce birini
  kazanan seçiyor"* diye yazmıştım. Şeytan 11. itirazında **ölçüm istedi**:
  *"toplam `BR-*` satır sayısı ile ayrıştırılan satır sayısı eşit mi?"*
- **Ölçüm (oylamadan sonra):**

  ```bash
  grep -c '^| BR-' yonetim/backlog.md          # 579
  node yonetim/arac/clickup-cikar.js           # rows.json (576 kart), rc=0
  ```

  | Ölçüm | Sonuç |
  |---|---|
  | dosyadaki `\| BR-` satırı | **579** |
  | ayrıştırılan | **576** |
  | fark | **3** — üçü de mezar taşı |
  | **gerçek mükerrer** | **0** |

- **İki ayrı yerde yanılmışım, ikisini de ölçmemiştim:**
  1. **Çıpam dardı.** `^\| (BR-[A-Z0-9-]+) \|` yazmıştım; bu çıpa küçük harf sonekli
     **altı kartı** (`BR-00a`..`BR-00d`, `BR-AST-51a/51b`) hiç görmüyor. Aracın kendi
     çıpası (`startsWith('| BR-')`) **doğru**. Yani araç benden genişti.
  2. **"Sessizce kazanan seçiyor" tamamen yanlış.** `clickup-cikar.js` gerçek bir
     mükerrerde `process.exit(1)` yapıyor ve mezar taşlarını (`Yerini satır N aldı`)
     önce çıkarıyor. Üçü de mezar taşı: `BR-BE-47`→4569, `BR-BE-53`→4608,
     `BR-SYS-45`→4527.
- **Bedeli ölçüldü:** 10 üyelik kurul bu yanlış öncül üzerine oy verdi ve
  **birleştirme** kararı çıkardı. Uygulansaydı *"Yerini satır N aldı"* izi **yok
  edilecekti**. Yanlış sayım yalnız yanlış rapor değil, **zararlı bir karar** üretti.
- **Karar:** Q4-a (birleştirme) **uygulanmayacak**; Q4-b (yeni kapı) **gereksiz** —
  kapı zaten var ve doğru sebeple yeşil.

### 36. Ş71-6 — var olan kapı gerçekten kapıya bağlandı (pozitif + 4 mutasyon)

- **Neden:** `clickup-cikar.js` iki şeyi zaten ölçüyordu (çözülemeyen satır, mükerrer
  kimlik) ve ikisinde de `exit 1` yapıyordu — ama **hiçbir kapı onu koşturmuyordu**
  (63 kapı tarandı, 0 isabet). Yalnız koordinatör senkron koşturunca ateşleniyordu.
  Koşmayan kapı insan hafızasıdır.
- **Ne yapıldı:** `deploy/yerel-kapilar.sh` `kapi_43` gövdesine eklendi; ayrıca
  Şeytan'ın istediği **vacuity kontrolü**: `ayrışan == dosya − mezar`.
- **Ölçüm:**

  | # | Mutasyon | Sonuç |
  |---|---|---|
  | 1 | (pozitif, bugünkü backlog) | **YEŞİL** `dosya=579 mezar=3 ayrışan=576` |
  | 2 | gerçek mükerrer kimlik ekle | **KIRMIZI** — `HATA: mukerrer kart kimligi` |
  | 3 | ayrıştırılamaz `\| BR-` satırı ekle | **KIRMIZI** — `1 adet satiri cozulemedi` |
  | 4 | aracın mezar taşı kalıbını değiştir | **KIRMIZI** (mükerrer yoluyla) |
  | 5 | araç bir satırı **sessizce düşürsün** | **KIRMIZI SAYIM** — `ayrışan=575 beklenen=576` |

  5. mutasyon önemli: **eklediğim sayım kontrolünün kendi başına ateşlendiğini**
  gösteren tek mutasyon o. 4'e kadar hep mükerrer kontrolü yakalıyordu, yani kontrolüm
  ölü olabilirdi; var olduğu arıza sınıfını (gelecekte bir filtrenin satır yutması)
  birebir taklit eden mutasyon yazılınca ateşlendi.
- **İkinci düzeltme:** `grep -c` sıfır eşleşmede **1 döner** ve kapı `set -e` altında
  koşuyor → mezar taşı kalmadığı gün kapı **yanlış sebeple** ölürdü. `|| true`
  eklendi. (Aynı tuzak bu kapının üstünde `BR-QA-74` olarak zaten yazılıymış.)
- **Dokunulan dosya:** `deploy/yerel-kapilar.sh`

### 37. Karar #70'in 24 şartı HİÇ karta dönmemiş (ölçüldü)

- **Neden:** Kart numarası tahsisi için önek bazında en büyükleri ölçerken, Karar
  #70'in metninde **rezerve edilen** numaraların karta dönüp dönmediğini yokladım.
- **Ölçüm:** `BR-QA-94`, `BR-BE-169`, `BR-BE-173`, `BR-DB-76`, `BR-DB-77`,
  `BR-SYS-106`, `BR-AST-100`, `BR-SEC-22`, `BR-FE-94`, `BR-FE-96` → **hepsi 0 isabet**.
- **Sonuç:** Karar #70'in 24 şartı bugün **görünmez borç**. `backlog.md`'ye kart olarak
  yazılmayan iş ClickUp'ta hiç yoktur.
- Kart yazımı ajana verildi; **numaralar önceden koordinatör tarafından blok hâlinde
  tahsis edildi** (Karar #71 / Q3-a: ajan numara seçmez).

### 38. Karar #71'in bloke edici şartları kapandı — P0 dâhil

- **Neden:** Kurul onay satırını vermemişti; dört migration şartı + beş ürün şartı açıktı.
  Dört ajana dosya sahipliği çakışmayacak şekilde dağıtıldı.
- **P0 kapandı (Ş71-S1):** `recording.download` yetkisi olan biri `vm-<linkedid>` yazarak
  sesli mesajı indirebiliyordu — CLAUDE.md §13/2'nin (**yazılı kullanıcı kararı**)
  doğrudan ihlali. İki kapı kondu: grant (tazelik kapısından da önce) ve imzalı bilet
  akış ucu. Yanıt **404**, ayrı bir kod değil — ayrı kod *"bu linkedid sesli mesaj
  taşıyor mu"* **oracle**'ı olurdu.
- **Ajan görevden bilerek saptı ve haklıydı:** reddi `IRecordingAccess`e koymadım dedi,
  çünkü **meşru dinleme bileti aynı `FindByCallAsync("vm-…")` çağrısını kullanıyor** —
  oraya koymak bekçiyi değil **özelliği** kapatırdı. Tuzağı sınıf dosyasına yazdı ki bir
  sonraki okuyucu "asıl düzeltme burada olmalıydı" diye geri almasın.
- **Ş71-4'te gündemde olmayan ikinci kusur:** aday sorgusundaki `NOT EXISTS` de yalnız
  `(tenant_id, linked_id)` karşılaştırıyordu. Düzeltilmeseydi `ON CONFLICT` genişlemesi
  **vacuous** kalacaktı: ikinci kutunun mesajı `INSERT`'e **hiç ulaşmadan** elenirdi.
- **`Down` gerçek PostgreSQL'de koştu** (2 satır dolu tabloyla), `lock_timeout` **fiilen
  ateşledi** (`55P03`) ve **yarım şema bırakmadı**; kontrol grubu: engelleyen transaction
  düşürülünce **aynı komut** `Done` verdi.
- **Ölçüm (birleşik HEAD — ajanların hiçbiri birleşimi koşmamıştı):**
  `dotnet build` 0/0 · `Api.Tests` (Voicemail|Modules.Recordings|PermissionManifest)
  **210/210** · `Architecture.Tests` **680/680** (674'ten, yeni bekçilerle).
- **Commit:** `1035bdc1`

### 39. EF modeli ile migration ayrışmıştı — sessiz bir gelecek regresyonu

- **Neden:** Migration kısıtı üç kolona genişletti ama `VoicemailConfiguration.cs` ve
  `PbxtrDbContextModelSnapshot.cs` **hâlâ iki kolon** diyordu. Bugün görünür bir kırmızı
  yoktu (`database update` çalışıyor); risk **bir sonraki** `migrations add`'de: kısıtı
  **sessizce geri daraltan** bir drift migration üretirdi.
- **Ne yapıldı:** ikisi de düzeltildi.
- **Ölçüm:** `has-pending-model-changes` **rc=0**. **Mutasyon:** `BoxRef`'i çıkar →
  **rc=1** *"Changes have been made to the model… Add a new migration."* Geri al → rc=0.
  Yani hem düzeltme yük taşıyor hem kontrol canlı.
- **Geri almanın ikiliye işlediği ayrıca doğrulandı** (yeniden derle + tekrar ölç) —
  `cp` ile geri alma MSBuild'i her zaman tetiklemez.

### 40. Kurul VAR OLMAYAN bir seçeneği tercih etmişti (ölçüldü)

- **Neden:** Karar #71, onay satırı yerine `Read(RlsTemplate)`/`Read(Guards)` çağrılarının
  migration'dan **çıkarılmasını** tercih etmişti. Kurul bunu **ölçmeden** yaptı.
- **Ölçüm:**

  ```bash
  grep -rl "Read(DeployDbScripts.RlsTemplate)" \
    src/Pbxtr.Infrastructure/Persistence/Migrations/*.cs | wc -l
  # -> 41
  ```

  **41 migration** aynı şeyi yapıyor, ve şablon okuması `pbxtr_apply_tenant_rls`'i
  **tanımlayan** şey: dosya `:345-346`'da şablonları okuyor, `:351`'de o fonksiyonu
  **çağırıyor**. Çıkarmak yeni tablonun RLS'ini kırar — yani (ii) şıkkı bir sadeleştirme
  değil, **tenant izolasyonunu kaldırma** önerisiydi.
- **Sonuç:** tek yol **şablon çıpası** = `BR-QA-91`. Onay satırı o kapanmadan **yazılamaz**;
  bu artık bir tercih değil, ölçülmüş bir zorunluluk. Karar kaydına düzeltme olarak işlendi.
- **Ders (üçüncü kez):** gündemin sunduğu *"iki seçenekten biri"* cümlesi de bir
  **öncüldür**.
- **Commit:** `89909d28`

### 41. İki kapı, 47 kart, pano

- **İki yeni kart (bu turun artıkları, ikisini de doğruladım):**
  - **`BR-AST-106` — Ş71-4 YARIM KALDI.** DB'de artık iki satır var ama ses dosyası hâlâ
    `vm-${CHANNEL(linkedid)}.wav`, yani **kutu ayrımı yok**: ikinci mesaj birincinin
    dosyasının **üzerine yazar**. Sessiz kayıp DB'den **diske taşındı**, yok olmadı — ve
    yeni belirti daha sinsi: kutuda **iki mesaj görünür, ikisi de aynı sesi çalar**.
  - **`BR-SEC-24`** — `RecordingSelfEndpoints.cs:183` aynı kapının dışında (serbest
    `callId`, `vm-` reddi yok). `Listen` kipinde olduğu için §13/2 ihlali değil, ama
    §13/1'in tanımına aykırı. **ÖLÇÜLMEDİ.**
- **Kendi komutumda `grep -c` tuzağına düştüm:** `grep -c` sıfır eşleşmede **1 döner**;
  `&&` zinciri kısa devre yaptı ve kart betiği **hiç koşmadı** — ama `node` ayrı satırda
  olduğu için çıktı "621 kart" diyerek **başarılı gibi** göründü. Aynı tuzağı yarım saat
  önce kapıda `|| true` ile düzeltmiştim.
- **Backtick tuzağı da tekrarladı:** `python -c "…"` içindeki backtick'leri bash yorumladı
  ve karar kaydına **bozuk metin** yazıldı. `git checkout` ile geri alındı, betik dosyaya
  yazılarak tekrarlandı. Kayıtlı ders: yamayı `Write` ile `.py` dosyasına yaz.
- **ClickUp:** `izde olmayan: 55` çıktı — 47 yeni kart **artı** önceki turda BR-9 için
  yeniden numaralanıp **panoda hiç açılmamış 8 kart**. Elli beşi açıldı.
  Doğrulama: **`fark olan kart: 0, izde olmayan: 0`**.
- **Commit:** `dea1b5b0`, `8466ace4`, `341841d6`

### 42. `BR-QA-91` — Ş69-10 deliği kapandı, onay satırı yazıldı

- **Neden:** Karar #71 onay satırını vermemişti çünkü onay defteri `.cs` blob'unu çıpalıyor
  ama o dosyanın **koşturduğu şablon içeriğini** çıpalamıyordu. Delik iddia değil, Karar
  #69'da **ölçülmüştü**: onaylı satır varken `01-rls-template.sql`'e
  `DROP TABLE public.audit_log` enjekte edilince kapı **rc=0** kalıyordu.
- **Çözüm — şablon başına TEK satır:**

  ```
  Sablon deploy/db/01-rls-template.sql sha256:<64 hex> Karar#NN
  ```

  Migration onay satırlarının biçimi **hiç değişmedi**.
- **Asıl tasarım kararı:** çıpanın değeri **dosyanın tamamı değil**, o dosyadaki **yıkıcı
  ifadelerin** (`DROP`/`ALTER`/`RENAME`/`SET NOT NULL`) normalize metinlerinin sıralı
  listesinin sha256'sı — ve **satır numarası çıpaya girmiyor**.
  - Yorum/zararsız fonksiyon ekle, satırları kaydır → çıpa **değişmez**, kapı yeşil.
  - Yeni bir `DROP` ekle, mevcut birinin hedefini değiştir, birini sil → **kırmızı**.

  Gerekçe ölçülü: tam dosya sha'sı kullanılsaydı şablona **her dokunuşta 13 onay satırı
  birden** kırmızıya düşerdi — yani kapı **HEP KIRMIZI** olur ve fiilen kaldırılmış
  sayılırdı. **Operasyonel bedel:** yıkıcı küme meşru olarak değişince elle güncellenen
  satır **şablon başına 1**; 13 migration satırına dokunulmaz.
- **Ş69-10 mutasyonunu bağımsız tekrarladım:**

  | Ölçüm | Önce | Şimdi |
  |---|---|---|
  | `01-rls-template.sql` + `DROP TABLE public.audit_log` | **rc=0** | **rc=1** |

  Ve kapı artık enjekte edilen satırı **adıyla** basıyor:
  `SABLON CIPASI TUTMADI … satir 3887: drop table public.audit_log`.
- **Beş şart da kapandığı için onay satırı yazıldı:**

  ```
  48d8aa7d5c85ecc1bb8af8ffaece730014e4f318 …/20260917211340_VoicemailMessages.cs Karar#71
  ```

  **Son ölçüm:** kapı **rc=0** · `ONAYLI` **14** (13→14) · `OLCULEMEDI` **0** ·
  `SABLON CIPASI TUTMADI` **0** · öz-test **rc=0** (14 yeni T-vakası + 4 T-mutasyonu) ·
  mutasyon (onay satırını çıkar) **rc=1**, geri koy **rc=0**.
- **CEO'nun Ş-71-CEO-2 şartı karşılandı:** *"BR-QA-91'in kabul ölçütü karşılanmadan defter
  14. satırı alamaz."* 14. satır o ölçüm **yapıldıktan sonra** alındı. Şeytan'ın 2. itirazı
  (*"kart açmak borcu kapatmıyor"*) bu turda **kart kapatılarak** karşılandı.
- **Kapılar gerçek sarmalayıcıda da koştu:** `kapi_43` gövdesi `( set -e; … )` içinde
  **rc=0**; iki yeni kontrolüm de yeşil satırını bastı (`backlog envanteri: dosya=626
  mezar=3 ayrisan=623 ✓`, `mezar tasi isareti: 3 adet ✓`). Gövdeyi tek başına ölçmek
  yetmiyordu — `kapi()` alt kabuğu `set -e` ile açıyor.
- **Kart durumları gerçeğe çekildi:** 8 kart `Bitti`, **2 kart `Kısmen`** — `BR-DB-82`
  (kalan iş `BR-AST-106`) ve `BR-SEC-23` (kalan iş `BR-SEC-24`). Pano eşlemesi ölçüldü:
  ikisi `in progress`, yani **kısmi satırlar kapalı sayılmıyor**.
- **ClickUp:** 8 kart güncellendi, doğrulama **`fark olan kart: 0, izde olmayan: 0`**.
- **Commit:** `71562e67` (çıpa + onay satırı), `a161b336` (kart durumları)

### 43. Aynı iki tuzağa üç kez düştüm — ikisi de hafızada yazılıydı

- **`grep -c` sıfırda 1 döner.** Üç ayrı komutta `&&` zincirini kısa devre ettirdi:
  1. kart betiği **hiç koşmadı** ama `node` ayrı satırda olduğu için çıktı "621 kart"
     diyerek **başarılı göründü**;
  2. şablon mutasyonu **hiç uygulanmadı** ama `echo rc=$?` yine bir sayı bastı.

  İkisinde de belirti **sessizdi**: komut başarısız değil, **yarım** koştu. Yarım saat önce
  aynı tuzağı `deploy/yerel-kapilar.sh`'ta `|| true` ile düzeltmiştim.
- **`python -c "…"` içindeki backtick'leri bash yorumluyor.** Karar kaydına **bozuk metin**
  yazıldı (`Read(RlsTemplate)` → boş, `pbxtr_apply_tenant_rls: command not found`).
  `git checkout` ile geri alındı; betik `Write` ile `.py` dosyasına yazılıp tekrarlandı.
- **Ders (kayda geçti):** çok adımlı bir ölçümde `&&` kullanma — her adımı **ayrı satıra**
  yaz ve çıkış kodunu **kendi satırında** oku. `grep -c`/`grep -q` bir **koşuldur**, bir
  sayaç değil.

### 44. KİP DEĞİŞTİ — kullanıcı hızdan şikâyetçi oldu, ekran teslimine geçildi

- **Kullanıcı ne dedi:** önce *"neden bu kadar yavaşsın"*, ardından kipi birebir sabitledi:
  *"ekranları öncelik alarak maddeleri test etmeden çıkarır mısın. çalışsın ama asterisk
  hariç diğer entegrasyonları kontrol etmeye çalışma."*
- **Haklıydı ve sebebi ölçülebilir:** o ana kadar bir turda **üç kurul oturumu, beş mutasyon
  turu ve iki kapı** yapmıştım — hiçbiri kullanıcıya **ekran** olarak görünmedi.
- **Ne yapıldı:**
  1. Saatlerdir asılı duran **iki ssh döngüsü** kesildi — ikisi de sunucuda hiç ateşlenmeyen
     bir retention job'ını bekliyordu ve hedef değerlendirmesini **125 dakika** erteletmişlerdi.
  2. Az önce başlatılan **dört backend/ölçüm ajanı durduruldu** (yeni talimatın tersini
     yapacaklardı).
  3. Yerine **dört frontend ajanı ayrı worktree'lerde** başlatıldı; görevlerinde açıkça
     *"test yazma, mutasyon koşma, Asterisk dışı entegrasyonu kurcalama"* yazılıydı.
- **Worktree kararı doğruydu:** dört ajan aynı `src/Pbxtr.Web` ağacında çalışsaydı sürekli
  çakışırlardı; ayrı worktree'de çakışma **merge anına** ertelendi ve orada tek elden çözüldü.

### 45. Dört ekran dalı indi — 13 kart bitti, 7'si bilerek KISMEN

| Ne | Sonuç |
|---|---|
| **Ekran #64 Sesli Mesaj Kutusu** | Yeni ekran, `/voicemail`. **70 → 71 ekran.** FIFO, `overdue`/`havuz` süzgeçleri, satır içi Dinle/Geri ara/Bana al/Havuza iade/Kapat. İndirme yok (§13/2), bedeli oynatıcıda geri-sar 10sn + 0,75x–1,5x |
| **#49 Entegrasyonlar sekmesi** | Webhook'un **8 ucu vardı, hiçbir yüzeyi yoktu** — teslim arızası müşterinin telefonundan öğreniliyordu. İki kapı birden: `integration.read` **ve** `useHasFeature('integrations')` |
| Otomatik mola anahtarı | Sunucu ayağı haftalardır hazırdı, **ekranı yoktu** |
| Realtime sessizlik | `useRealtimeSilence` yalnız wallboard'daydı → #12, #13, canlı kuyruklar ve #15'e yayıldı |
| 12 glif | Self-host fontların `unicode-range`i **dışındaydı** → webfonttan hiç çizilmiyordu; 6'sı inline SVG, 6'sı 9 dilde Latin-1 karşılığı |
| DND, alarm kaynak ekseni, "Üretildi" yalanı, kısmi agent sessizliği | İndi |

**İki kart ölçüldü ve iş YAPILMADI** (`BR-FE-87`, `BR-FE-57`) — zaten bitmişlerdi; bayat olan
kartın kendisiydi. Ajanlar önce ölçtüğü için boşuna iş üretilmedi.

**Yedi kart bilerek `Kısmen`:** UI ayağı bitti ama **veri sunucudan gelmiyor** (`dnd`,
`presentOnPbx`, `registration`, teslim tarihi). Ajanlar **uydurmadı, ekranı susturdu** ve
bildirdi. `Bitti` yazmak panoda kapalı gösterir ve kalan yarıyı kaybederdi → `BR-BE-186/187/188`
ve `BR-FE-103` açıldı.

### 46. Turun en pahalı bulgusu: bayat üretilmiş dosya ekranları GÖRÜNMEZ yapıyordu

- **Neden:** Canlı izleme ajanı kapsam dışı bir şey fark etti ve **kendi commit'ine almayıp
  bildirdi**: `src/Pbxtr.Web/src/app/screens/system-roles.generated.ts` **bayat**.
- **Ölçüm:** üreticiyi koşturdum, fark **yalnızca ekleme**:

  ```
  + integration.read   + integration.write
  + voicemail.read     + voicemail.manage
  ```

  **Hiçbir izin kaybolmuyor.**
- **Sonucu:** sunucu rol tohumu ilerlemiş ama üretilmiş dosya commit edilmemiş → o izinlere
  bağlı ekranlar **SPA'da hiç çizilmiyordu**. Belirti sessiz: hata yok, **ekran yok**. Aynı
  turda açtığımız #64 ve #49 Entegrasyonlar sekmesi bunsuz **görünmeyecekti**.

### 47. i18n çatışma çözücümün kuralı YANLIŞTI ve fiilen hata üretti

- **İlk sürüm:** paylaşılan anahtarda *"dalınkini al"*. Glif düzeltmesi dalını merge ederken
  doğruydu.
- **Sonraki merge'de patladı:** sesli mesaj dalı glif düzeltmesinden **önce** dallanmıştı, yani
  "dalın tarafı" **eski glifi geri getirdi** — `« Listeye dön` → `← Listeye dön`. Yani
  `BR-FE-74`'ü **sessizce geri aldım.**
- **Nasıl yakalandı:** çıktıya baktım. `tr.json`'da dört anahtarı elle okudum ve eski glifleri
  gördüm. Betiğin kendisi "22 glif ikamesi" diyordu ve **yanlış yöne** ikame ediyordu.
- **Düzeltme:** kural **taraf** değil **içerik** seçiyor artık — *kötü glif taşımayan taraf
  kazanır*. Ve doğrulama çıktıya eklendi: her dil için **`KALAN kötü glif: 0`**.
- **Ders:** bir merge çözücüsünde "hangi taraf" bir **konum** ifadesidir ve dalların yaşına
  göre anlamı değişir. Doğru çözücü **içeriğe** bakar. (Aynı sınıf: `[[backlog-durum-sutunu-cipayla-bulunur]]`
  — `h[4]` de `h[-1]` de yanlıştı, çıpa gerekiyordu.)

### 48. İki tarafı ayrı ayrı doğru olan bir çift, birleşince yanlış rapor üretti

- Ajan *"`limit` sunucuda doğrulanmıyor olabilir, DoS yüzeyi"* diye bildirdi. Ölçtüm:
  **endişe yersiz** — `EfWebhookAdministration.cs:336` `.Take(Math.Clamp(limit, 1, 200))`.
- **Ama altından gerçek bir kusur çıktı:** istemci `MAX_PAGE = 500` gönderiyordu, sunucu
  **200'e kırpıyor** ve istemci bunu **hiç görmüyordu**. Sonuç: *"sayfa doldu mu"*
  karşılaştırması 500'e bakıp **daima "dolmadı"** diyordu → *"en eski bekleyen teslimin yaşı"*
  satırı `en az` önekini **hiç basmıyor** ve ölçülen değer **kesin sanılıyordu**.
- İki taraf da kendi içinde doğruydu; **sözleşme** yanlıştı. `MAX_PAGE` 200 yapıldı ve sebebi
  koda yazıldı. Kalanı `BR-FE-103`.
- Bu, `[[kart-onculu-olculmeden-yazilmaz]]`ın birebir tekrarı: **teşhis yanlış çıktı ama
  altından daha kötü, gerçek bir kusur çıktı.**

### 49. Ölçüm

- `npx vitest run` → **220/220 dosya yeşil** (tur başında 3 kırmızıydı, 218 dosyaydı).
- `npx tsc -b` rc=0, `npm run build` rc=0.
- ClickUp: 5 yeni kart, 19 durum güncellemesi → **`fark olan kart: 0, izde olmayan: 0`**.
- **Commit:** `661e343d`, `4eb48550`, `d76887ae`, `8d7168ef`, `3f5b8985`, `27570109`, `d7f77451`

### 50. Karar #70 backend dalı indi — onay satırı körü körüne değil, diff'lenerek güncellendi

`BR-BE-184/185/167/166/168/165/112` tek commit'te indi (kart bunu **şart koşuyordu**: ayrı
inerlerse migration sözleşme defterindeki blob iki kez değişir ve satır arada kırmızı kalır).

**Onay satırını güncellerken durdum ve ölçtüm.** `01fc9ebb → 6adb189d` değişmişti. İki blob'u
diff'ledim: değişikliğin **tamamı** `Down` gövdesinde (satır 146-158, bir `RAISE NOTICE` bloğu) ve
XML yorumlarda. `Up` **birebir aynı** — yani kapının okuduğu sözleşme değişmedi, `Karar#70`
geçerliliğini koruyor.

**Yazılı sınır:** kapı `Down`'ı **hiç okumuyor** (`up_body()` yalnız `Up`'ı tarar), yani bu `Down`
değişikliği onayın kapsamında **değil**. Karar #71'de kayıtlı; burada tekrar edildi çünkü
"blob değişti, demek ki onay tazelenmeli" refleksi tam olarak bu körlüğü **onay** sanır.

**Ajanın kendi testi ilk yazımını kırdı** ve bu iyi bir şeydi: denetim satırı `IAuditSink.TryEnqueue`
ile gidiyor, çünkü `Rejected` satırı istek transaction'ında **geri alınmamalı**. Rol/IP bu dikişte
okunamıyordu (Infrastructure'da `HttpContext` yok) → **uydurma boş rol yazılmadı**, satır
`correlation_id` ile aynı isteğin `agent.call.controlled` satırına bağlandı.

### 51. Asterisk dalı indi — ve iki dalın birleşimi kod okumasıyla görünmeyen bir boşluk açtı

| Kart | Sonuç |
|---|---|
| `BR-AST-103` | Kayıt yolu `tenant/yyyy/MM/linkedid`; ayrıştırıcı tenant **kodu** kabul ediyor, CDR değeri ile MixMonitor yolu **aynı** göreli adı taşıyor, boş `__PBXTR_TENANT`'ta hiçbir kayıt satırı koşmuyor |
| `BR-AST-95` | `Bridge(${PBXTR_CTL_PEER})` ve onu yazan iki `Setvar` **kaldırıldı** → `ConfBridge(pbxtr-ctl-${CHANNEL(linkedid)})` + yalnız bacak için `TIMEOUT(absolute)` |
| `BR-AST-98` | `ControlIntent.Recording` — kayıt niyetinde devralma **denenmez** |
| `BR-AST-106` | Dosya adı + asset anahtarı kutu ayırt edicisi taşıyor; üretici ve tüketici **birlikte** değişti |
| `BR-AST-96 / 99 / 104` | **Dokunulmadı** — üçü de saf santral ölçümü |

**Üç çatışma elle çözüldü.** İkisi mekanikti; biri değildi:

- `ConfigRenderer` — iki dal **aynı** devralma satırına dokunmuştu. Çözüm "birini seç" değildi:
  **buluşma mekanizması** `BR-AST-95`'in (`ConfBridge`), **iz** `BR-BE-167`'nin (`Half` +
  `Aborted` `UserEvent`). Çelişmiyorlardı; `BR-BE-167`'nin **iki satırı** kaldırılan değişkene
  dayanıyordu, o kadar.
- `AsteriskAriProvider` — `JournalAsync` kaldı, `SetPeerAsync` gitti (çağıranı kalmamıştı).
- `backlog.md` — her kart **`Bitti` diyen taraftan** alındı: `BR-AST-106` daldan, `BR-SEC-24`
  HEAD'den. "Bizimkini al" deseydim biri sessizce geri açılırdı — `[[js-replace-dolar-tirnak-yutar]]`
  değil ama aynı sınıf: çözücü **konum** değil **içerik** seçmeli.

**Merge'in açtığı gerçek boşluk (`BR-BE-190`):** `Requeued` işaretinin dialplan **üreticisi düştü**.
`Half` ve `Aborted` basılıyor, ama devralmadan sonra çağrının **yaşadığı** artık hiçbir yerde
yazılmıyor. Belirti sessiz **ve yönlü**: `PlatformEnded` `Aborted`i içeriyor, yani geri bağlanıp
yaşayan bir çağrı yalnızca `Half` bırakıyor ve süpervizör olumlu cevabı göremiyor. Sabit
**silinmedi** — `CallTimelineLabels` onu hâlâ çözüyor ve `call_events`'te geçmiş satırlar var.
Yeni üretici `ConfbridgeJoin` AMI olayı; **santralde ölçülmeden bağlanmayacak.**

### 52. Merge sonrası derleme: yalnız BİRLEŞİMDE kırmızı olan sınıf yine çıktı

`VoicemailStoredName.AssetKey` imzası iki dalda ayrıştı (HEAD 1 argüman, dal 2). **İki dal da kendi
içinde yeşildi**; kırmızı yalnız birleşimde doğdu. Kayıtlı ders
(`[[merge-sonrasi-tum-projeler-derlenmeli]]`) birebir tekrarladı — bu yüzden merge'den sonra
**çözülen dosyalar değil, çözüm `dotnet build`** ile ölçüldü: 0 hata, devralma testleri 38/38.

**Ölçüm:** `dotnet build` rc=0 / 0 hata, `dotnet test` 38/38 Skipped 0, ClickUp
`fark olan kart: 0, izde olmayan: 0` (631 kart).

**Commit:** `92cc65ea` (Karar #70 backend), `8bb6bd2c` (Asterisk merge)

### 53. Turun en öğretici bulgusu: "ürün 500 veriyor" raporu yanlıştı, altındaki kayıp daha büyüktü

QA ajanı kendi işinin dışında bir kırmızı gördü ve **kendi commit'ine almayıp bildirdi**:
`IfMatchGateBranchTests`'in üç dalı kırmızı, `queue` ucu 404/409 yerine **500** dönüyor. Teşhis
şuydu: *"olmayan bir kuyruğa `If-Match` ile PUT → istemci 'sunucu patladı' görür, 'böyle bir kaynak
yok' görmez."*

**Ölçtüm ve teşhis yanlış çıktı — ama altından daha kötü bir şey çıktı.** 500 handler gövdesine
**girilmeden** oluşuyordu:

- `PUT /queues/{id}` yetenek mutabakatı için `ITelephonyProvider` enjekte ediyor.
- Üretim DI'ı onu `PersistentTelephonyProvider` ile sarıyor.
- O kurucu `ApiKeySecurityOptions.Pepper`i **fail-closed** doğruluyor (`missing or low entropy`).
- Bu test bileşiminde biber ayarlanmamıştı → kurucu patlıyor → ASP.NET 500.

Yani **`If-Match` kapısının kuyruk dalı hiç koşmuyordu.** Test yeşil değildi, *"yanlış sebeple
kırmızı"*ydı — ve asıl kayıp kapının kendisiydi, 500'ün değil. Üretimde aynı 500 **yok**: biber
yapılandırmadan gelir ve eksikse uygulama fail-closed açılmaz, yani "açılmış ama 500 veren" hâl
üretilemez.

Biber emsalden (`UserAdminEndpointTests`) kondu, sebep koda yazıldı: **9/12 → 12/12, Skipped 0.**

Bu `[[kart-onculu-olculmeden-yazilmaz]]`ın bugünkü **üçüncü** tekrarı. Desen artık şu kadar net:
*teşhis ölçülmeden yazıldıysa çoğu kez yanlış çıkıyor, ama kazma yerini doğru gösteriyor.*

### 54. Panelde hiç olmayan bir yönetim yüzeyi bulundu (BR-FE-53)

Kart **`Bitti`** yazıyordu. Metninin **ikinci maddesi** ise açıktı: *"diğer ikisinin istemcisi de
hiç yok."* 2026-09-06'da yalnızca birinci madde yapılmış, durum satırı bütünü kapalı göstermişti —
`[[sayac-kismi-satiri-kapali-sayar]]`ın birebir tekrarı.

Ölçüm: `inbound-format|inbound-screening` → `src/Pbxtr.Web/src` içinde **sıfır satır**. Sunucuda
ise 1 GET + 2 PUT **aylardır** hazır (`TrunkAdminEndpoints.cs:181,208,212`). Yani gelen numara
biçim profili ve **gelen kara liste kapısı panelden hiç yönetilemiyordu**.

`TrunkInboundDialog` (496 satır), üç API ucu, 44 anahtar × 9 dil indi. Üç bilinçli sapma yazılı:

1. Profil trunk formuna **gömülmedi** — `PUT /trunks/{id}` PUT semantiğindedir; alan eklenseydi
   profili göndermeyen her trunk düzenlemesi profili **sessizce silerdi**.
2. Yazma sonrası diyalog kapanmaz — iş iki adımlı (önce profil, sonra operatör onayı).
3. Her başarılı yazmadan sonra kayıt yeniden okunur: üç uç **tek damgayı** paylaşıyor, aksi hâlde
   ikinci adım 409 alırdı.

### 55. Üç kart daha bayat çıktı, bir kart daha gerçek kusur verdi

- `BR-FE-49/51/52` (kuyruk, IVR, çalışma saatleri `If-Match`) — **üçü de bitmiş.** Kod yazılmadı.
- `BR-FE-22/23/59/60/63` — **beşi de bitmiş.** Zil/modal `AppShell.tsx:65`'te route ağacının
  **dışında**; "zil YOK" teşhisi bayattı.
- `BR-FE-42/43/44/45/46` — **beşi de bitmiş.**
- **Ama `BR-FE-47`'de gerçek bir CLAUDE.md §5 ihlali çıktı:** sunucu `Simulated` alanını
  gönderiyordu, istemci sözleşmesi onu **hiç taşımıyordu** ve #49 SMS sekmesi kapatılamaz
  *"SİMÜLASYON — mesaj gerçekten gönderilmedi"* şeridini **çizmiyordu.** Somut bedel: mock ile
  koşan kurulumda yönetici gönderen başlığını kaydeder, yeşil "Kaydedildi" görür ve sistemin SMS
  gönderdiğini sanardı.
- İkinci kusur (`BR-BE-191`, ben düzelttim): PUT yanıtı `Simulated`i **sabit `false`** kuruyordu,
  GET dalı doğru okuyordu. Görünür arıza yoktu (istemci kaydettikten sonra GET'i yeniden okuyor)
  ama alan **telde yalan** duruyordu ve yanıta bakan bir sonraki istemci şeridi sessizce
  kaldırırdı.

**Dersin özeti:** bu turda 14 kart ölçüldü, **11'i zaten bitmişti.** Bayat olan kod değil,
**kartların kendisiydi.** Ajanlar önce ölçtüğü için boşuna iş üretilmedi — ve tam da o ölçüm
sırasında üç gerçek kusur çıktı.

### 56. Ölçüm

- `dotnet build` 0 hata · `npx tsc -b --force` rc=0 · `IfMatchGateBranchTests` **12/12**
- ClickUp: **`fark olan kart: 0, izde olmayan: 0`** (633 kart)
- Kapalı: **432** (tur başında 428) · açık **201**
- **Commit:** `8bb6bd2c` (Asterisk), QA + iki ekran dalı, `BR-BE-191`/`BR-QA-28` düzeltmesi,
  trunk gelen-arama yüzeyi

### 57. OPS/belge turu: bir kartın öncülü çürüdü, bir kartta yazmayan tuzak çıktı

| Kart | Sonuç |
|---|---|
| `BR-OPS-15` | `deploy/santral-recreate-kapisi.sh` + `kapi_67`, 5 mutasyon kırmızı |
| `BR-OPS-13` | Down'ın sildiği lisans satırları denetim günlüğüne + geri dönüş runbook'u |
| `BR-OPS-14` | Kısmen — (a)(c) indi, (b) yayın anına bağlı |
| `BR-OPS-09` | Kısmen — (1) indi |
| `BR-DOC-17/18/19` | Bitti |

**`BR-OPS-15`'in öncülü çürüdü.** Kart *"`staging-yayin.sh:587` her yayında koşuyor"* diyordu.
**Koşmuyor:** satır `if [ -n "${PBXTR_SANTRAL_IMAJ:-}" ]` içinde ve dosyanın kendi yorumu
*"VARSAYILAN: DOKUNMAZ … santral imajı ayda bir değişir"* diyor. Yani Karar #70 Q3-a'nın reddi
sandığımızdan **zayıf**: `ari.conf` "bir sonraki yayında" değil, **bir sonraki santral imajı
yayınında** geçiyor. Karar #70'e öncül düzeltmesi işlendi; kapı yine de kuruldu.

**`BR-OPS-13`'te kartta yazmayan bir tuzak çıktı.** `audit_log` partition'lıdır.
`pbxtr_create_partition` çağrısı olmadan Down `no partition of relation` ile **yarıda kalır** —
yani **denetim eklemek migration'ı geri alınamaz yapardı.** Gerçek PG 16.15'te ölçüldü. Kartın
istediği şey (izlenebilirlik) tam tersini üretecekti.

**`BR-DOC-17`'de kart eksikti, asıl kusur başka yerdeydi.** Kart iki dosya sayıyordu, üçüncü yer
`permissions.seed.json:681` idi. Ama asıl kusur not metniydi: `StorageScreen` dokuz dilde
*"webhook aboneliği bu üründe YOKTUR"* diyordu ve bu cümle `BR-C2-2` teslim edilince **yanlış**
oldu. Kullanıcıya **var olan** bir özelliğin yok olduğu söyleniyordu.

**İki yan bulgu kart oldu:**
- `BR-DB-86` — `BR-OPS-11` ile `BR-OPS-14` `lock_timeout` için farklı değeri "doğru" sayıyor
  (2s vs 10s). Kurulan kapı değeri `00-roles.sql`'den **okuduğu** için çelişkiyi **görmüyor**.
- `BR-SYS-110` — `pbxtr_role_settings_guard` **canlıya uygulanmamış**: canlıda
  `statement_timeout=0`, bekçi 30s bekliyor. `[[kod-var-kosan-yok]]`ın birebir tekrarı.

### 58. Onay defterinde çözülmemiş çatışma — ve onu yakalayan şey kapının kendisiydi

Merge `backlog.md` çatışmasını bildirdi; **`migration-contract-onay.blobs` çatışmasını çıktının
kuyruğunda kaçırdım.** Dosyada `<<<<<<<` işaretleri kaldı. Yakalayan: `kapi_07`.

```
deploy/migration-contract-onay.blobs:82: bicim bozuk … '<<<<<<< HEAD'
deploy/migration-contract-onay.blobs:86: ayni yol iki kez onaylanamaz: …WebhookOutboxAndDelivery.cs
```

Kapı üç ayrı ağızdan bağırdı: biçim bozuk, aynı yol iki kez, ve blob eşleşmiyor. **Kapının
kurulma sebebi tam olarak buydu** ve bu sefer beni yakaladı, kodu değil.

Çözüm körü körüne değildi: `Webhook` satırı **daldan** (BR-OPS-13 `Down`'a denetim ekledi, gerçek
blob `18d7c6e8`), `Telephony` satırı **HEAD'den** (Karar #70). Webhook blobunu onaylamadan önce
`97549c51 → 18d7c6e8` diff'lendi: değişen satırlar **3** (using) ve **494-505**. `Up` **137-461**
arasında ve **dokunulmamış** — yani kapının okuduğu sözleşme aynı, Karar #69 geçerli.

### 59. Turun sayısal özeti — bayat olan kod değil, kartlardı

Bugün **28 kart ölçüldü, 25'i zaten bitmişti.** İki ajan (10 + 4 kart) hiç kod yazmadı.

Ama tam o ölçüm sırasında **dört gerçek kusur** çıktı:

1. Trunk gelen-arama yönetimi **panelde hiç yoktu** — sunucuda 1 GET + 2 PUT aylardır hazır.
2. #49 SMS sekmesinde zorunlu **simülasyon şeridi çizilmiyordu** (CLAUDE.md §5 ihlali).
3. `Simulated` alanı PUT yanıtında **sabit `false`** idi.
4. `If-Match` kapısının **kuyruk dalı hiç koşmuyordu.**

Bu, "önce ölç" kuralının ne için var olduğunun en temiz kanıtı: **kartın teşhisi yanlıştı ama
kazma yerini doğru gösterdi.**

**Ölçüm:** `dotnet build` 0 hata · `tsc -b --force` rc=0 · `kapi_07` rc=0 / ONAYLI 15 ·
ClickUp `fark olan kart: 0, izde olmayan: 0` (635 kart) · kapalı **432**, açık **203**

### 60. Turun en pahalı bulgusu: BUGÜN MERGE ETTİĞİMİZ KOD ÇAĞRIYI ÖLDÜRÜYORDU

Sabah `BR-AST-95`'i merge ettim: `Bridge(${PBXTR_CTL_PEER})` → `ConfBridge(pbxtr-ctl-${CHANNEL(linkedid)})`.
Gerekçe sağlamdı, testler yeşildi, kod incelemesi temizdi. **Gerçek santral reddetti:**

```
WARNING pbx.c:2957 pbx_extension_helper:
    No application 'ConfBridge' for extension (pbxtr-mmtest, cb, 3)
== Spawn extension (pbxtr-mmtest, cb, 3) exited non-zero
module show like confbridge -> app_confbridge.so ... Not Running
```

Modül diskte var, `autoload = yes`, noload'da değil — ama **`/etc/asterisk/confbridge.conf` yok**,
bu yüzden uygulama hiç kayıt olmuyor. Kartın *"yerleşik `default_bridge`/`default_user`
kullanılır"* öncülü de **yanlıştı**: yerleşik profil de yok (`confbridge show profiles` →
`No such command`).

**Neden P0:** eski `Bridge()` yarışı kaybettiğinde çağrı **bazen** kurtuluyordu. Kayıtlı olmayan
bir uygulama **her seferinde** öldürür. Yani bu, *"düzelttik"* etiketli bir **regresyon** olurdu.

**Önlem bayrak, geri alma değil.** Kod doğru; eksik olan santral tarafı. Geri almak
`BR-AST-95`'in ölçümle çürüttüğü `Bridge()` yolunu geri getirirdi.
`ConfBridgeRegisteredOnPbx = false` → buluşma satırı **üretilmiyor**, yerine sebep yorumu
basılıyor. Davranış bugün aynı (ikisi de çağrıyı düşürür) ama **nedeni yazılı** ve santral günlüğü
her yarım kalmada WARNING ile dolmuyor.

**Test iki dallı yazıldı ve ikisi de koşuldu** (bayrak `true` → 4/4, `false` → 4/4). Bugünkü hâli
çivilemiyor: bayrağı açan kişi testi **değiştirmek zorunda kalmayacak** — yoksa o an "test neyi
koruyordu" bilgisi kaybolurdu. `PBXTR_CTL_PEER` yasağı **iki dalda da** geçerli.

`[[belge-santral-degildir]]` bugün üçüncü kez, ve en pahalı biçimde doğrulandı.

### 61. Ölçüm tarifini yazan ajan ölçemeyen ajandı — ve tarif işe yaradı

Santral turunu önce `asterisk-uzmani`'na verdim. Ajan 99k token harcayıp *"Bash bu oturumda devre
dışı"* diyerek döndü. Sebep oturum değil **ajan tanımıydı**: o tipin araçları
`Read, Grep, Glob, Write`. Rol'e göre seçmiştim, **araç kümesine bakmamıştım.**

Ama tur tamamen kayıp değildi: ölçemediği yerde **ölçüm tarifini** üretti ve dördü de ölçümün
tasarımını değiştiriyordu:

1. `Record()` değil **`MixMonitor`**, ve **mutlak yolla** — labdaki D-14 ayrı bir kod yoluydu.
2. **`b` seçeneği ölçümü sessizce sabote eder** — cevaplanmayan çağrıda dosya zaten oluşmaz.
3. `ls -ln` ile **uid/gid** okunmalı, yoksa `docker cp root:root` sınıfı arıza tekrarlar.
4. **İki ayrı soru**: `yyyy` yokken ve `yyyy` varken `MM` yokken.

Bash'li ajan bu tarifle koştu ve **ikinci uyarı fiilen kurtardı**: ilk turda `Local ;1/;2` ile
originate etti, `bridge show all` **boş** döndü, `b` hiç tetiklenmedi ve **kontrol dâhil** üç dosya
da 44 bayt (salt WAV başlığı) kaldı. **Kontrol grubu olmasaydı bunu "dizin açılmadı" diye
okuyacaktık** ve `BR-AST-103`'ü haksız yere kırmızı yazacaktık. Tur geçersiz sayıldı, `Dial()` ile
gerçek köprü kuruldu.

### 62. Ş2-4 YEŞİL — yayın önü açık

`MixMonitor` var olmayan ara dizinleri **mutlak yolla açıyor**:

| Durum | Sonuç |
|---|---|
| `yyyy` **ve** `MM` yok | ikisi de açıldı, 229420 bayt |
| `yyyy` var, `MM` yok | açıldı, 229420 bayt |
| kontrol (hepsi var) | 229420 bayt |
| **kök dâhil hiçbiri yok** | dört seviyenin tamamı açıldı |

Üçü **eşit** → ay sınırında "ayda bir gün sessiz kayıp" riski **yok**. Sahip/izin:
`asterisk:asterisk` (1000:1000), mod 0755, dosya 0644.

**Yan bulgu:** yapılandırılmış kök `/var/spool/asterisk/recording` sunucuda **hiç yoktu**, ve
`/var/spool/asterisk` asterisk konteynerinde **anonim volume**dür, `pbxtr-app`'e bağlı değildir →
dosya ETL'e yalnız ARI `recordings/stored/{ad}` ile ulaşır. Ayrıca provizyonlu
`t0007-dialplan.conf` içinde `MixMonitor` satırı **hiç yok** — bugünkü kod henüz sahaya inmemiş.

### 63. İki kırmızı daha: sesli mesaja giden yol yok, ARI `channelvars` yok

- **`BR-AST-104`** — `[pbxtr-inbound]` context'i **yok** (`grep` → 0). `[pbxtr-t0007-vm]` **var** ve
  `Record(...,5,180,k)` taşıyor; eksik olan ona **giden** dal. Kartın öngördüğü sessiz belirti
  gerçek: müşteri mesaj bırakır, kutuda hiçbir şey oluşmaz, hiçbir hata satırı yazılmaz.
- **`BR-AST-105`** — `GET /ari/channels` → 200, **kanal 8**, `linkedid` geçen **0**, `channelvars`
  geçen **0**; aynı anda `core show channels concise` → **8** (aynı evren, boş liste değil).
  `ari.conf`'ta **`channelvars` hiç yok** → Karar #70 Q3 yeniden açılır.
- **`BR-AST-106`'nın "ölçülmedi" öncülü ölçüldü:** aynı `linkedid`, farklı `uniqueid`,
  `PBXTR_VM_SENT` ikinci kanalda **boş** (`__` öneki yok → kalıtılmıyor). Karar #71'in aradığı
  "çağrı başına tek kutu" garantisi **yoktur** — yani bugünkü düzeltme **gerekliydi**.

### 64. QA'nın bulduğu iki güvenlik açığı (QA rolü kod yazamaz; koordinatör kapattı)

**`BR-SEC-12` — yetki reddi satırı düşürülebiliyordu.** `CaptureEndpoints`'teki yedi denetim
çağrısının ikisi `PermissionDenied` yazıyordu ve üçü de `TryEnqueue` ile gidiyordu; `TryEnqueue`
kuyruk doluyken `false` döner ve **dönüş değeri atılıyordu**. Somut: `ChannelAuditSink` kapasitesi
(10.000) doluyken yetkisiz `.pcap` indirme denemesinin **hiçbir izi kalmıyor** — ve tam kuyruğun
dolu olduğu an, yani sistemin en yüklü olduğu an, bir saldırı denemesinin en görünmez olduğu
andır. **İzleme açısından en kötü sıra.**

Başarılı eylemler için aynı şey **yapılmadı ve sebebi yazıldı**: `started`/`deleted` eylemlerinin
**kendi izi** vardır (dosya oluşur ya da kaybolur); bir yetki reddinin denetim satırından başka
izi **yoktur**.

**`BR-SEC-15` — RTCP snaplen ulaşılamaz bir hâle göre türetilmişti.** 128, IPv6'lı başlığa (66) +
52 = 118'e göre seçilmişti. Ama RTCP ayracı `udp[8]`/`udp[9]` indeksi kullanıyor ve
`pcap-filter(7)` BUGS'un yazdığı gibi o indeks **yalnızca IPv4**'e bakar — sablonun **kendi
açıklaması** da *"medya IPv6 ise 0 paket getirir"* diyor. Yani türetimin dayandığı hâl **hiç
yakalanmıyor** ve aradaki **30 baytın tamamı** RTCP yükünde rapor bloğundan sonra gelen alana,
pratikte **SDES/CNAME**'e gidiyordu. CNAME `user@host` biçimindeyse `user` bir **dahili numara**
olabilir ve `.pcap` çok-tenantlı bir dosyadır. Yeni sabit 46; snaplen 104; **teşhis kaybı sıfır.**

**Testteki asıl eksik üst sınırdı:** önceki hâl yalnızca **alt** sınırı ölçüyordu, yani snaplen'i
**büyütmek** testi hiç kırmıyordu. *"İlişki kilitli, sayı elle seçilmez"* ifadesi bu hâliyle
**yalandı**. Üst sınır eklendi.

### 65. Benim iki hatam

1. **Commit mesajını `-m "..."` ile yazdım**, bash backtick'li adları komut ikamesi sanıp
   **sildi** (`conflict: command not found` çıktıda duruyordu ama commit yine de atıldı). İçerik
   `backlog.md`'de duruyordu; kaybolan **git kaydıydı**. Düzeltme commit'iyle geri kondu.
   `[[heredoc-icinde-backtick-yutulur]]` birebir tekrar.
2. **Kendi testimin çıpası fazla genişti:** `"Set(TIMEOUT(absolute)="` dinleme bağlamındaki
   `${PBXTR_SPY_TIMEOUT}` satırını yakalayıp **yanlış sebeple** kırmızı yandı. Çıpa sabit saniyeye
   daraltıldı. `[[backlog-durum-sutunu-cipayla-bulunur]]` ile aynı sınıf — ve aynı turda SEC ajanı
   da o dersin birebir tekrarını yaşadı (`BR-SEC-09` satırının durum hücresi boru taşıyordu).

### 66. Ölçüm

- `dotnet build` 0 hata · migration kapısı rc=0 / ONAYLI 15 · ConfigRendererTakeover+Renderer 26/26 ·
  CaptureTemplate 20/20 · AsteriskCommandCatalog 8/8
- ClickUp **`fark olan kart: 0, izde olmayan: 0`** (637 kart)
- Kapalı **450** (turun başında 432) · açık **188**
- Sunucu temiz bırakıldı: `zz-*` dosyaları yok, `pbxtr-mmtest` context'i yok, `core show channels`
  → 0 aktif; yalnız `dialplan reload` kullanıldı, demo tenant verisine dokunulmadı

## Kararlar

- **Karar #71 — ŞARTLI ONAY, onay satırı YAZILMADI.** Sesli mesaj migration'ının
  contract onayı, Ş71-1..Ş71-5 kapandıktan sonra hesaplanacak **yeni** blob için ve
  **ayrı bir kararla** verilir.
- **Q2 — düzeltmenin yönü ters çevrildi.** Kayıt yolu ayrıştırıcısı GUID bekliyor, yol
  parçası ise **tenant kodu**. Düzeltme **ayrıştırıcıda** yapılacak, üreticide değil:
  dialplan GUID'i hiç bilmez; oraya GUID basmak kanalda **ikinci bir tenant kimliği**
  yaratır.
- **Q3-a — (c)+(b).** Ajanlar `BR-YENI-<slug>` yazar, numarayı **yalnız koordinatör**
  verir. `backlog.md`'yi tarayıp "en büyük + 1" alma kuralı **kaldırıldı** — tarama,
  paylaşılan durumdan numara türetmektir ve iki ajan aynı anda tararsa aynı sekiz
  numarayı alır (bu turda oldu).
- **BR-SYS-107'nin systemd-timer yolu REDDEDİLDİ** (linux-uzmanı, dördü ölçülü):
  `pbxtr-confd` `ProtectSystem=strict` altında `/etc/systemd/system`'e **yazamaz**;
  bundle **veri** taşır, **kod** değil (bir unit `ExecStart=` ile root olarak koşar);
  `-mtime +7` **ikinci bir saklama süresi otoritesi** kurar (migration'ın kendi
  `COMMENT`'i bunu yasaklıyor); ve `find -delete` teslim/ack'e bakmadığı için
  **tek kopyayı sessizce** siler. Doğru ev: mevcut `MediaRetentionJob`.

## Açık kalanlar / sonraki adım

- **Ş71-1..Ş71-4** (migration), **Ş71-S1/S2/S4/S5/S7** (ürün) üç ajanda **uygulanıyor**.
  Bitince blob yeniden hesaplanacak, sonra onay satırı ayrı kararla yazılacak.
- **Ş71-S3 — KVKK:** `voicemail_messages` `purge_call_data()` allowlist'inde **yok** ve
  `recording_retention_days = 0` olan tenant'ta satırlar **süresiz** kalıyor.
- **Şeytan itiraz 9 — ÖLÇÜLMEDİ:** sonuç kodları `result_codes`'ta gerçekten siliniyor
  mu, yoksa pasifleştiriliyor mu? Siliniyorsa `closed_result_code_id` dalı `SET NULL`
  değil `RESTRICT` olmalı.
- **Ş2-4 — ÖLÇÜLMEDİ, Ş2-1'in önkoşulu:** `MixMonitor` var olmayan ara dizini açar mı?
  `Record()` için labda ölçüldü (D-14), `MixMonitor` için **ölçülmedi**. Açmıyorsa
  tarih dizinine geçiş kaydı **tamamen susturur** — üstelik "düzelttik" etiketiyle.
- **`__PBXTR_TENANT`'ın santraldeki gerçek değeri — ÖLÇÜLMEDİ** (Q2; iki uzman da
  ölçmedi, bütçe Q1'e gitti).
- **Ş71-7:** mezar taşı işaretlerindeki satır numaraları bayat (`4569`→4578,
  `4608`→4617, `4527`→4536; üçü de 9 kaymış). Kart yazımı bitince düzeltilecek.
- Merge bekleyen dallar: BR-7 (`worktree-agent-a7f867731097389e5`), SYS/confd
  (`worktree-agent-a64865e7419068cf7`), BR-AST-59 (`worktree-agent-ad5f7ead59c16fb69`).
- `dotnet test tests/Pbxtr.Api.Tests --filter "~Modules.Telephony"` tam koşusu hâlâ
  **ÖLÇÜLMEDİ** (eşzamanlı ajan yükü altında testhost çökme riski).
- BR-SEC-16 sır rotasyonu: ajanlar bitince.
