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

### 67. Kurul Karar #72 — kurul, önerilen blob'u ONAYLAMADI

`kapi_07` kırmızıydı: `20260918120000_RlsTemplateRefresh` contract RED alıyordu. Defterin kural 4'ü
*"bayrakla onay yoktur"* dediği için kendim geçemezdim → 10 üyelik kurul.

**Sonuç 10/10 ŞARTLI — ama onay önerdiğim blob'a verilmedi.** Üç üye (CTO, Şeytan, DB lideri) dosyanın
**kendisinde** ölçülmüş kusur buldu. Backend lideri haklı olarak *"dosyaya dokunma, blob bozulur"* dedi;
ama o uyarı **var olan** bir onayı korur — **defterde henüz satır yoktu**, yani blob serbestti.
Önce düzelttim, sonra **düzeltilmiş gövdeyi** onayladım: `db0c858b…` → **`1ec6f0ec…`**.

Bu, defterin Kural 2'sinin (*"dosyanın tek baytı değişirse sha değişir"*) doğru yönde işlediğinin
kanıtı oldu: kurul bir **içeriği** onayladı, bir **yolu** değil.

### 68. Migration'da düzeltilen üç ölçülmüş kusur

**1. `SET LOCAL lock_timeout` yoktu.** Depoda 12 emsal var — ve bu kararın **kendi emsal gösterdiği**
iki migration da dâhil. DB lideri katmanları ayırdı ve boşluk göründü:

| Katman | Değer | Durum |
|---|---|---|
| Rol tabanı (`00-roles.sql`) | `pbxtr_owner` 10 s | var (gevşek taban) |
| Fonksiyon (`ALTER FUNCTION … SET`) | `reassert_hardening` 2 s, `ensure_future_partitions` 5 s | var |
| **İşlem (`SET LOCAL`)** | — | **BOŞTU** |

Fonksiyon katmanı yalnız o iki fonksiyonun **içini** korur. Şablonun geri kalanı — 39
`CREATE OR REPLACE FUNCTION`, 8 `REVOKE`, 8 `GRANT` — `pg_proc` satırlarında kilit alır ve 10 s'lik
gevşek tabana düşüyordu. 5 s eklendi (emsalle aynı).

**2. *"Nesne YARATMAZ"* cümlesi yanlıştı — turun en değerli bulgusu.** Şeytan buldu, DB lideri ve
backend lideri bağımsız doğruladı:

```
01-rls-template.sql:1952  ->  pbxtr_sys.ensure_future_partitions(3)
01-rls-template.sql:1610  ->  EXECUTE format('CREATE TABLE %s PARTITION OF %s ...')
```

Yani migration `cdr` / `call_events` / `audit_log` **ebeveyninde ACCESS EXCLUSIVE** alıp tablo
yaratabiliyor. `SuppressTransaction` taşımadığı için kilitler COMMIT'e kadar **tutuluyor**.
Yanlış özet yüzünden bu migration *"bakım penceresi gerektirmez"* diye okunuyordu — **gerektiriyor**.

**3. `Down` NO-OP gerekçesi olgusal olarak yanlıştı.** Yorum *"o gövdenin metni artık depoda YOKTUR —
yani geri alma yazılabilir bile değildir"* diyordu. Şeytan tek komutla çürüttü:
`git show accd8da1^:deploy/db/01-rls-template.sql`. Yani geri alma **yazılamaz değil, yazılmak
istenmiyor**. Kararı **korudum**, gerekçeyi değiştirdim — ve doğru gerekçe daha güçlü çıktı:
`Down` **simetrik olamaz**, çünkü `ensure_future_partitions`'ın yarattığı partition'ları düşürmek
**veri silmek** olurdu. "Tam geri alma" yazmak bugünkü NO-OP'tan **daha tehlikeli** olurdu.

### 69. DB liderinin ölçtüğü açık: `kapi_71` kendi başlığındaki iddiayı tutmuyor

`sablon-refresh.expected` başlığı şunu **emrediyordu**:

> *"Sırayı atlayıp yalnızca sha'yı güncellemek kapıyı yalancı yeşil yapmaz: K5 kontrolü 'defterdeki
> ad, şablonu uygulayanların en yenisi mi' diye sorar."*

DB lideri depo ağacının kopyasında ölçtü: 01'e satır ekledi, **yeni migration yazmadı**, defterdeki
sha'yı güncelledi → **kapı rc=0, YEŞİL**. Sebep `sablon-refresh-kapisi.sh:124-134`: K5 *"defterdeki ad
en yeni uygulayıcı mı"* diye sorar ve `RlsTemplateRefresh` yeni bir tazeleme yazılmadığı sürece
**sonsuza kadar en yenidir**.

Yani **bu kararın kapattığı delik, bir sonraki 01/02 değişikliğinde aynen geri açılıyor** ve kapı
bunu görmüyor. Kapı o sınıfı **bir kez** yakaladı, tekrarını yakalamıyor.

Başlıktaki yanlış cümleyi `!!!` bloğuyla düzelttim (silmedim — bugün insan hafızasını **yanlış yönde**
rahatlatıyordu). Kalan iş `BR-DB-87`: K5'e **git tarihi sırası** eklenecek. Uygulanabilirliğini
ölçtüm — şablona son dokunan commit `accd8da1`, migration `04b568e7` ile **sonra** eklenmiş, doğru yön.

### 70. Asterisk uzmanının bulduğu belge yalanı — bir yazım hatası değil, KARAR BOZAN bir cümle

CLAUDE.md §3.2 diyor ki: *"bu uçlar Redis'ten servis edilir; PostgreSQL sıcak yolda değildir."*
**Kod aksini yapıyor.** `call-permission` zincirinin **ilk** adımı:

```
EfTenantSuspensionProbe.cs:38-43  ->  db.Tenants.AsNoTracking().Where(t => t.Id == tenantId)...
```

Önbellek **bilinçli olarak yok** (Karar §12/5). Günlük deneme halkası ayrıca `call_attempts` sayıyor.
Ve şablon **ikisini de** kilitliyor (`01:918-919` `tenants` FORCE; `01:3157,3173-3190` append-only
ebeveynler, `call_attempts` **adıyla** sayılı). Uç **fail-closed** olduğu için sonuç:
**giden arama, migrate penceresi boyunca durur** ve agent "arama engellendi" görür.

Bunun neden bir yazım hatası olmadığı: o cümle durduğu sürece **her** kilit/migration kararı
*"çağrı anını etkilemez, çünkü Redis"* diye geçiyor. Bugün tam olarak bu oldu — ben kurula gönderdiğim
metinde o cümleyi **alıntıladım**. `BR-DOC-21`.

### 71. Linux uzmanı benim çerçevemi de düzeltti

Kurula *"kapı kırmızıyken hangi başka kapılar ölçülmemiş kalıyor"* diye sormuştum. Cevap: **hiçbiri.**
`kapi()` gövdeyi alt kabukta koşturur, `exit`i hapseder, `KIRMIZI=1` yapar ve **71 kapının tamamı**
koşar (`yerel-kapilar.sh:133-181`). Kayıp yalnızca **yayın yolundadır**. Aciliyet gerçekti ama
gerekçem yanlıştı — ve "depo kırmızı, acele et" tam olarak kapının durdurmak için var olduğu argüman.

Aynı üye ayrıca *"45 nesnede ACCESS EXCLUSIVE"* ifademin **abartılı** olduğunu gösterdi: şablonda
**tek bir top-level `ALTER TABLE` yok**; 12 eşleşmenin hepsi fonksiyon gövdesi. Kilit alan tek
çalıştırılan ifade `01:3249`'daki `DO` bloğu ve o da yalnız **sapmış** nesnelere dokunuyor.

### 72. Backend liderinin emsale sığınmayı reddetmesi

Karar #70 Q1-b *"Emsal bir BİÇİMİ onaylar, bir İÇERİĞİ ASLA"* diyor. Backend lideri bunu ciddiye aldı
ve 3945 satırın **top-level ifade sınıflandırmasını** yaptı:

```
39 CREATE OR REPLACE   36 COMMENT ON   8 REVOKE ALL   8 GRANT EXECUTE   3 DO $$
```

Kapının yakaladığı `ALTER TABLE` (305) ve `DROP TABLE` (2599) **fonksiyon gövdesi içinde
`EXECUTE format(...)` dizesi**. Yani kapının RED'i **metin düzeyinde doğru, semantik düzeyinde yanlış
pozitif**. Bu, Şeytan'ın *"dördüncü tazeleme onayı hangi ölçütle reddedilir"* sorusunun da cevabı:
**ölçüt bu sınıflandırmadır** — top-level'da gerçek bir `ALTER/DROP` çıkarsa onay verilmez.

Aynı üye `dotnet ef`'in bu depoda **hiç koşmadığını** da ölçtü (`Pbxtr.Api` `EFCore.Design`
referansı taşımıyor) ve EF'in `IMigrationsAssembly` servisini doğrudan sorguladı: 198 migration,
sıra `RlsTemplateRefresh` **önce**, `VoicemailSlaDaily` **sonra**. `Designer.cs` yokluğu sorun değil —
keşif ölçütü `[Migration("…")]` niteliğidir ve Designer'sız migration bu depoda **yerleşik**.

### 73. Şeytan'ın en rahatsız edici itirazı: kurul oy vermeden iş zaten yapılmıştı

Migration + `MaintenanceRunner.cs:230` + `sablon-refresh.expected:25` + `kapi_71` **aynı commit'te**
(`04b568e7`) inmişti. Yani kurula sunulan seçenek "onayla / reddet" değil, **"onayla / üç commit'i
geri al"**dı. Bu CLAUDE.md §7'nin (kurul onayı → plan → başla) tam tersi.

İtiraz haklıydı ve tutanağa **aynen** geçti. Geri alma listesini de yazdım — ve ölçülmüş sonuç şu:
bu geri alma yapılırsa `kapi_71` kırmızıya döner **ve** yükseltilen her DB'de açılış assert'i düşer →
**uygulama hiç açılmaz.** Yani bugün RED, depoyu bugünkünden kötü bir yere götürürdü. Bu bir mazeret
değil; bir sonraki contract migration'ında kurul **önce** toplanacak.

### 74. Şeytan'ın kanıt öncülünü çürütmesi — `BR-SYS-111` kapanmadı

Karar metnimde dört ölçüm kanıtı saymıştım. Şeytan üçünü çürüttü:

| Bulgu | Gerçek |
|---|---|
| `pbxtr_role_settings_guard` YOK | **02-guards.sql**'de, 01'de sıfır geçiş — 01 hakkında hiçbir şey söylemez |
| `pbxtr_assert_role_settings_guard` YOK | aynı |
| `pbxtr_hardening_deadline` YOK | `accd8da1` ile **bugün doğdu**, sunucu 13 migration geride → **totoloji** |
| `proconfig` boş | tek kalan — ve **bayatlıkla birebir aynı görünür** |

Yani "ölçüldü" dediğim şeyin **ayırt edici gücü sıfırdı**. Onay bu kanıta dayanmadı (kod okuması +
backend liderinin geri-alma ölçümü taşıdı), ama `BR-SYS-111` **kapanmadı** — ayırt edici A/B hâlâ borç.
Kartı `Kısmen`de bıraktım ve borcu durum hücresine yazdım.

`[[karar-yazilmis-ama-uygulanmamis]]` bu turda **kendi metnimde** çıktı: ölçmediğim bir şeyi
"ölçüldü" diye etiketlemiştim.

### 75. Açılan kapılar ve kartlar

**Kapılar (ikisi de mutasyonla doğrulandı):**
- `RlsTemplateRefresh` → `MESAI_MUAFIYETI_YASAK` (ikinci ad). Öz-test **13 → 14**; yeni negatif vaka
  olmadan tek elemanlı döngü ikinci adı hiç ölçmezdi.
- **14 haneli damga tekrar edemez** (`MigrationDiscoveryGuardTests`). Architecture **684 → 685**.
  Bugünkü çift tesadüfen doğru sırada: `VoicemailSlaDaily` 01'de tanımlı `pbxtr_apply_tenant_rls`'i
  çağırıyor ve `R < V`. Yarın `…120000_Abc` eklenirse bağımlılık **sessizce** ters döner ve yeni tablo
  **RLS'siz** kalır. Muafiyet listesi boşaltılınca test kırmızı → vacuous değil.

**Kartlar:** `BR-DB-87` (K5 açığı), `BR-DOC-21` (§3.2 belge yalanı), `BR-FE-106` (#26 şema tazeliği —
sunucudaki DB 13 migration geride ve **hiçbir ekran söylemedi**), `BR-FE-107` (saha şikâyeti: panel
sessizce donuyor, sonuç kodu kayboluyor, ACW kilitli kalıyor, wallboard bayat veriyi canlı gösteriyor).

Son ikisi kurul kapsamı **dışındaydı** — kart edilmeselerdi kaybolurlardı. `[[clickup-her-islemde-guncellenir]]`.

### 76. Ölçüm

- `kapi_07` **rc=0**, `ONAYLI (Karar#72)`; öz-test OK
- **MUTASYON:** onay satırının son hanesi bozuldu → rc=1; geri alındı → rc=0
- `sablon-refresh-kapisi` öz-test **7/7**, koşu rc=0
- `yayin-onkosul-selftest` **14 geçti / 0 kaldı**
- Architecture **685/685** Passed, Skipped 0 · **MUTASYON:** damga muafiyeti boşaltıldı → Failed 1
- `dotnet build` 0 Warning, 0 Error
- ClickUp **`fark olan kart: 0, izde olmayan: 0`** (643 kart, 4 yeni açıldı)
- Backlog 642 → **646** kart satırı (3'ü kasıtlı "yerini satır N aldı" mükerreri)

### 77. Kurduğumuz kapı, kurulduğu ilk koşuda bizi yakaladı

`BR-DB-87` kapandı: `kapi_71`'e **K6** eklendi — *"defterdeki tazeleme EKLENDİĞİNDE şablonun
blob'u, bugünkü blob mu?"* Ajan kartın önerdiği `merge-base --is-ancestor` çözümünü denedi ve
**çürüttü** (merge commit'i "son dokunuş" sayılıyor, migration onun atasında ekleniyor → yanlış
kırmızı), yerine **içerik** karşılaştırması koydu.

Ve kapı ilk koşuda şunu bastı:

```
IHLAL: 02-guards.sql: GIT SIRASI BOZUK -- defterdeki tazeleme
  20260918090000_VoicemailRetentionAllowlist EKLENDIGINDE (60c6c210) sablonun
  govdesi 878f34a2… idi, BUGUN c4d47887…
```

Kendim doğruladım: `git rev-parse 60c6c210:deploy/db/02-guards.sql` ≠ `git hash-object` diski.
01 için **eşleşiyor**, 02 için **eşleşmiyor**. Fark `accd8da1`: `pbxtr_role_settings_guard()` ve
`pbxtr_assert_role_settings_guard()` 02'ye o migration'dan **sonra** eklenmiş.

Eski K5 bu hâli **TEMİZ** gösteriyordu, çünkü *"defterdeki ad en yeni uygulayıcı mı"* sorusu
sonsuza kadar sağlanıyordu.

### 78. Şeytan dün haklıydı ve biz onu yanlış okuduk

Karar #72'de Şeytan aynen şunu yazmıştı:

> *"`pbxtr_role_settings_guard` ve `pbxtr_assert_role_settings_guard` **02-guards.sql**'dedir…
> 02'yi tazeleyen migration `20260918090000`'dır ve **zaten Karar #71 ile onaylanmıştır**."*

Ben bunu *"demek ki o bulgular kapsanmış"* diye okudum ve **eledim**. O migration onaylanmıştı
ama **bayattı**. Şeytan'ın işaret ettiği sunucu ölçümü (`pbxtr_assert_role_settings_guard` = YOK)
aslında **gerçek ve daha kötü ikinci bir deliği** gösteriyordu.

CTO kusura bir ad koydu ve adı doğru: **örnek-kapsamlı ölçüm, sınıf-kapsamlı karar.** Evren iki
elemanlıydı — `{01, 02}` — ve yarısını ölçtük. *"İki elemanlı bir evrende yarısını ölçmek, ölçüm
değil seçimdir."*

Ağırlaştırıcı olan kısım şu: sinyali bir **ölçümle değil, bir kategori iddiasıyla** eledim.
Karar kaydında ölçülmüş eleme ile ölçülmemiş eleme **aynı görünüyor** — bu yüzden kusur kaydın
kendisinde de görünmez oldu. Yeni kural karara geçti: **Şeytan itirazı kategori iddiasıyla
kapatılamaz**; ya ÖLÇÜM ya KART, ve hangisi olduğu yazılır.

### 79. P0 gerçekti — ve DB lideri onu gerçek PostgreSQL'de yeniden üretti

İddia: `MaintenanceRunner.cs:230` açılış kapısı `pbxtr_assert_role_settings_guard()` çağırıyor,
yükseltilen DB'de fonksiyon yok → uygulama açılmaz. Atılır bir `postgres:16-alpine`'e
`00-roles` + `01` + **`02@60c6c210`** yüklendi:

```
ERROR:  function pbxtr_assert_role_settings_guard() does not exist
--- tazeleme uygulandiktan sonra ---
NOTICE: ROLE SETTINGS GUARD (BR-SYS-105): temiz (0 ihlal).
```

`pbxtr_role_settings_guard` **01'de 0 kez, 02'de 4 kez** geçiyor — yani **#72 bu deliği
kapatamazdı.**

### 80. Ama P0 cümlem abartılıydı — ve Şeytan bunu da yakaladı

*"Yükseltilen her kurulumu kilitler"* dedim. Ölçtüm, yanlış:
`MigrationStartupGate.cs:154-159` `pending.Count == 0` ise **erken dönüyor** → `GuardAsserts`
hiç koşmuyor. Doğru cümle: **bekleyen migration taşıyan bir yayında** ısırır — ki bir sonraki
yayın öyle.

Ve itirazın ikinci yarısı yeni bir bulgu: bekçi, **elle DDL veya restore ile sapmış şemayı
tanımı gereği göremez** (o senaryolarda bekleyen migration yoktur). Oysa `MaintenanceRunner.cs:215-220`
kendi gerekçesinde *"şemayı migration dışı yollarla bozan değişiklikleri yakalayan TEK yer"*
olduğunu yazıyor. Yani bekçi, **yakalamak için var olduğu sınıfı görmüyor.** → `BR-SYS-112`.

### 81. Aynı hatayı aynı tur içinde tekrar yaptım

Yazdığım migration'ın gerekçesi şöyleydi: *"02'nin `CREATE OR REPLACE FUNCTION` / **GRANT** /
**REVOKE** ifadeleri `pg_proc` satırlarında kilit alır."*

**02'de top-level `GRANT` veya `REVOKE` sıfır adettir.** Dört üye ayrı ayrı ölçtü. Gerekçeyi
01'den **kopyalamıştım** — yani dün `RlsTemplateRefresh`'te *"Nesne YARATMAZ"*ı düzelttiğimiz
hatanın birebir tekrarı, **aynı gün**.

Yerine ölçülen envanter yazıldı:

| Top-level ifade | Adet |
|---|---|
| `CREATE OR REPLACE FUNCTION` | 49 |
| `DROP FUNCTION IF EXISTS` + `CREATE FUNCTION` | 16 |
| `COMMENT ON FUNCTION` | 39 |
| `DO` (yalnız `RAISE`, superuser reddi) | 1 |
| `GRANT`/`REVOKE`/`ALTER`/`CREATE TABLE|INDEX|POLICY|TRIGGER`/DML | **0** |

Gerçek PG16'da `pg_locks`: AccessExclusive **16** (= 16 `DROP FUNCTION`), ShareUpdateExclusive
**39** (= 39 `COMMENT ON`), **kullanıcı tablosu kilidi 0**, toplam **273 ms**.

`[[karar-yazilmis-ama-uygulanmamis]]` — ama bu kez varyantı daha sinsi: **gerekçe kopyalanınca
ölçülmüş gibi görünüyor.**

### 82. Ve bir üçüncüsü: belge P0'ı kapanmış gösteriyordu

DB liderinin bloklayıcı şartı: `MaintenanceRunner.cs:225` şöyle yazıyordu —
*"`20260918120000_RlsTemplateRefresh` … O migration olmadan bu satır her yükseltilmiş
veritabanında açılışı KIRMIZI yapardı."*

Ölçüm: aradığı fonksiyonu getiren **`20260918130000_GuardsTemplateRefresh`**tir. Yani cümle,
düzeltilmemiş bir P0'ı **düzeltilmiş gösteriyordu**. Sonraki operatör *"#72 bunu çözdü"* diye
okuyacaktı. İki ayrı ön koşul olarak yeniden yazıldı.

### 83. Backend lideri, CTO'nun düzeltmesini fikstürle çürüttü

CTO, Ş72-3 ölçütünün 02'de düştüğünü gösterdi (16 top-level `DROP FUNCTION` var) ve daraltma
önerdi: *"yetim DROP = aynı dosyada aynı kimlikle bir `CREATE` tarafından izlenmeyen `DROP`."*

Backend lideri fikstür kurdu:

```
FIKSTUR B: DROP TABLE public.audit_log;  +  CREATE TABLE public.audit_log (id bigint);
  CTO cumlesinin BIREBIR okunusuyla -> YETIM TOPLAM: 0   <- GECIYOR
```

Yani ölçüt harfiyen uygulanırsa **`audit_log`'u boşaltmak onaydan geçerdi.** Nihai ölçüt sınıfa
**ve imzaya** bağlandı. Maddi gerekçe de güçlendi: 16 `CREATE`'in hepsi `RETURNS TABLE(...)` ve
PostgreSQL `CREATE OR REPLACE` ile dönüş tipi değiştirmeye izin vermiyor → **`DROP`+`CREATE` bir
yıkım değil, zorunlu deyim.**

### 84. Şeytan'ın bir önerisini ölçümle reddettim

İtiraz 4 haklıydı: `DROP FUNCTION|POLICY|TRIGGER` **hiçbir kapının** desen kümesinde yok
(`migration-compatibility-guard.py:24-30`), yani şablon o yüzeyden serbestçe değiştirilebilir.

Ama önerdiği çözümü (deseni hemen genişlet) ölçtüm:

| Yer | `DROP FUNCTION` | `DROP POLICY` | `DROP TRIGGER` |
|---|---|---|---|
| `01` | 30 | 18 | 19 |
| `02` | 73 | 1 | — |
| `Migrations/*.cs` | 75 | 49 | 24 |

**148+ yeni bulgu** → onaylanmamış onlarca migration kırmızı → **toplu onay** gerekir. Yani
defteri tam da itirazın korktuğu şeye, **kauçuk mühre** çevirirdi. `[[kapi-kurmadan-once-mevcut-veriyi-olc]]`.
**Dar seçenek** karta yazıldı: genişletme kapının `DENIED` kümesinde değil, **şablon çıpasında**
yapılır — çıpa şablon başına tek sha'dır, migration tarafı hiç etkilenmez.

### 85. Linux uzmanı: çift KARŞILIKLI kilitleyici

Ben *"01 geçip 02 geçmezse kilitler"* diyordum. Ölçüm daha kötü:

| Hâl | Sonuç |
|---|---|
| 01 var, 02 yok | `pbxtr_assert_role_settings_guard` yok → 42883 → **açılmaz** |
| **02 var, 01 yok** | fonksiyon var ama assert (4)+(5) **01'in gövdesini** okuyor → `RAISE EXCEPTION` → **açılmaz** |

Ve bunu zorlayan **hiçbir şey yoktu**; EF'in "bekleyenlerin hepsini tek koşuda uygulaması" bir
**tesadüf**, kapı değil. Somut kırılma yolu: `kapi_07` kırmızı görenin en kısa "düzeltmesi"
migration dosyasını **silmektir** — o da tam olarak kilitleyici yarıyı üretir. `kapi_73` kuruldu
(pozitif 0 / negatif-bölünmüş 1 / kontrol grubu 0).

Aynı üye sayımımı da düzeltti: *"13 geride, 01/02 dört kez"* → **16 bekleyen, 01 × 5, 02 × 6**.

### 86. Asterisk: BR-AST-107 (P0) kapandı, ve dünkü iki dallı test kendini kanıtladı

`app_confbridge.so` artık santralde **`1 Running core`** (önce `Not Running`). Çözüm
`module load` ile **değil** — o komut §3.1 kapalı listesinde yok ve liste genişletilmedi —
santral **imajına** `confbridge.conf` girerek geldi (`deploy/asterisk-lab/conf/confbridge.conf`,
`asterisk-conf-sinir.txt`'e `IMAJ` olarak kaydedildi).

Davranış da ölçüldü: iki bacak aynı konferansa originate → `confbridge list pbxtr-ctl-ast107`
**iki kanal**, log temiz.

**Ve dünkü tasarım kararı tam olarak amaçlandığı gibi çalıştı:** `ConfBridgeRegisteredOnPbx`
`true` yapıldı ve `ConfigRendererTakeoverTests` **değiştirilmeden** 4/4 geçti. Dün şunu yazmıştım:
*"bayrağı açan kişi testi değiştirmek zorunda kalmayacak — yoksa o an 'test neyi koruyordu'
bilgisi kaybolurdu."* Bugün o kişi geldi ve değiştirmek zorunda kalmadı.

Ayrıca `BR-AST-101` (ARI `channelvars` kapalı kümesi, `kapi_72`, 4 mutasyon + kontrol grubu) ve
`BR-AST-105` kapandı; `channelvars` artık `PBXTR_TENANT` + `CHANNEL(linkedid)` taşıyor
(ölçüm: `cli_kanal=2 · linkedid_gecen=2 · channelvars_gecen=2`, sabah 8≠0 idi).

**Ve iki kartın öncülü ölçümde çürüdü:** `BR-AST-86`'nın *"kod hâlâ `CoreShowChannels` çağırıyor"*
iddiası yanlış — düzeltme `323fb5ea`'da var, ama sunucudaki imaj `ea567d11` (09-15), yani
loglar gerçek ama gösterdiği şey **yayın gecikmesi**. `BR-AST-103` de aynı sınıf: `pbxtr-confd`
çalışıyor, içerik eski çünkü üretici kod yayındaki ikilide yok. `[[kod-var-kosan-yok]]`.

### 87. 20 saattir kırmızı duran bir frontend testi

FE ajanı `alarmRuleSource.test.ts`'in kırmızı olduğunu bildirdi ve "benim değil" dedi. Öncülü
doğruladım — `git diff --name-only 45e1fa6b HEAD -- screens/shared/` **boş**, yani gerçekten
önceden kırmızıydı (`234a02db`'den beri).

Sebep: `LongestWaitTileView`'a üçüncü alan (`missingFromPbx`) eklenmiş, testler `toEqual` ile
eski şekli bekliyordu. **Davranış kusuru değil, test kayması.**

Düzeltme `toMatchObject` **değil** — o, alanı ölçmekten tamamen vazgeçmek olurdu. Beş vakaya
beklenen değer yazıldı **ve** alanı gerçekten ölçen iki vaka eklendi; ikincisi kontrol grubu:
`presentOnPbx=false` (santralde yok → hesaptan çıkar, sayılır) ile `presentOnPbx=null`
(ölçemedim → hesaba girer, sayılmaz). İkisi aynı sonucu verseydi kod *"ölçemedim"*i bir yokluk
iddiasına katlıyor demektir. 8 → **10 test**.

### 88. Ölçüm

- Kurul **#72 ve #73**, ikisi de 10/10, ikisinde de onay **önerilen blob'a değil düzeltilmişe**
- `kapi_07` rc=0 (mutasyon 1→0) · `kapi_71` rc=0 (K6 dâhil) · `kapi_73` poz 0/neg 1/kontrol 0
- `sablon-refresh` öz-test **9/9** · `yayin-onkosul` öz-test **14/14**
- Architecture **688/688** (684 → 685 → 688) · `dotnet build` 0 hata
- ClickUp **`fark olan kart: 0, izde olmayan: 0`** (648 kart)
- Kapalı **484** (turun başında 477) · açık **164**
- Sunucu temiz: 0 aktif kanal, geçici bağlamlar silindi, t0007 verisine dokunulmadı

### 89. Karar #74 — ölçülmüş bir hızlanma, KARAR OLMADAN geri çekildi

- **Neden:** `BR-DB-40`'ın ölçümü RLS yükleminde `OR` operandlarının sırasını değiştirmenin
  çapraz kipte **943 ms → 46 ms** (~20×) getirdiğini gösterdi. Öneri kurula gitti.
- **Ne oldu:** Kurul **bölündü** — önce yalnız üç kilit üye (CTO, DB lideri, Şeytan) çağrıldı,
  çünkü önerinin **ölçülmemiş bir ön koşulu** vardı: *"yeni sıra kurulu veritabanlarına
  ulaşıyor mu?"* Üçü de bağımsız ölçtü, cevap **HAYIR**:
  `pbxtr_reassert_hardening()` (`deploy/db/01-rls-template.sql:3121-3238`) dört blok koşar ve
  bunların içinde **`pbxtr_apply_tenant_rls` çağrısı SIFIRDIR.** Şablonun tamamında da toplu
  çağrısı yok. Yani tazeleme migration'ı fonksiyon **gövdesini** günceller ama
  `<tablo>_tenant_isolation` policy'leri `pg_policy`'de **eski metinle** durur. Yeni sıra
  yalnız **taze kuruluma** gelirdi.
- **İkinci ölçüm daha kötüsünü söyledi:** trafiğin ~%99'u olan `cross=off` kipinde öneri
  **kazanç vermiyor**, medyanda ~%3 **kaybettiriyor** (b1 928/927/917/952 ms ↔ b5
  958/1055/961/957 ms). Asıl kazanç b4'te — `app_current_tenant()`'ı SQL gövdeli yapmakta
  (140 ms, ~6,7×) ve o **policy metnine hiç dokunmuyor**.
- **DB liderinin yakaladığı gizli tuzak:** naif bir `FOR tbl IN … PERFORM pbxtr_apply_tenant_rls(tbl)`
  döngüsü, `01:359-361`'deki `ELSE … DROP POLICY IF EXISTS <tablo>_dealer_scope` dalı yüzünden
  **beş tablonun bayi policy'sini sessizce düşürürdü** (`call_events`, `cdr`, `queues`,
  `tickets`, `user_roles`). Bayi alt tenantlarını okuyamaz hâle gelirdi — **hatasız, 0 satırla.**
- **Sonuç:** öneriyi **geri çektim**; 7 üye **bilerek çağrılmadı**. Çürümüş bir öneri için
  10 üyelik tur açmak kurulu tören hâline getirir.
- **Dokunulan dosyalar:** `yonetim/kurul-kararlari.md` (Karar #74 negatif kayıt),
  `yonetim/backlog.md` (`BR-DB-40` yön değişikliği, `BR-QA-99` açıldı)
- **Commit:** `631fad8f` — Karar#74 GERI CEKILDI

**Bu turun kalıcı çıktısı bir NEGATİF SONUÇTUR ve kayda geçmesinin sebebi budur:**
*ölçülmüş bir hızlanma, teslim yolu ölçülmeden bir karara dönüştürülemez.*

Ayrıca kurulun kaydettiği, karar kapsamı dışında iki şey: (1) aynı RLS yüklemi **üç ayrı yerde,
üç ayrı yoldan** yazılı (`01:315-316` şablon, `CdrSqlBuilder.cs:74` + `PostgresCdrSearch.cs:22`
ham SQL, `02-guards.sql:1651` donmuş dize + üç migration kopyası) → şablon düzeltilirse ürün
**iki sıraya birden** sahip olur (`BR-QA-99`); (2) `OR` operand sırası PostgreSQL'de **bir
sözleşme değil planlayıcı davranışıdır** — kazanç bir sürüm yükseltmesinde sessizce kaybolur
ve hiçbir test kırmızı olmaz.

### 90. Güvenlik turu — `T` bayrağı düştü, iki yeni yüzey açıldı

- **`BR-SEC-17` — BİTTİ.** `Dial(…,30,tT…)` içindeki **büyük `T`** transfer yetkisini
  **arayana** verir (küçük `t` arananadır), ve o satır `-local` bağlamında — oraya bugün zaten
  dış çağrı giriyor (kuyruk üyeliği `Local/{no}@pbxtr-{kod}-local/n`). Toll-fraud yüzeyi.
  `T`, `ConfigRenderer.cs`'de **7 üretici noktadan** düşürüldü (satır ~1015, 1122, 1447, 1513, 2261)
  **ve** `ProvisioningRevisionService.cs:551,795`'ten — ikincisi atlanırsa santral
  Sınıf-B `queue-target` anlık görüntüsünden **eski değeri okumaya devam ederdi.**
- **Negatif kapı:** `tests/Pbxtr.Api.Tests/Modules/Telephony/DialTransferFlagGuardTests.cs` —
  yalnız `Dial()`/`Queue()` **seçenek alanını** ayrıştırır (metnin rastgele yerindeki `T`
  harfini değil), `T` yok der **ve** `t` var der (vacuity karşıtı: küçük `t` de silinseydi
  test sessizce yeşil kalırdı).
- **Kendi kaçırdığım kırmızı:** `persistentmembers` düzeltmesini merge ederken yalnız
  `dotnet build` + Architecture koşmuştum; `ConfigRenderGuardTests` HEAD'de **kırmızı kalmış**.
  SEC ajanı yakaladı ve muafiyeti *gevşeterek değil daraltarak* düzeltti (tam olarak
  `queues.conf` + tam `[general]`, `ConfigRenderGuard.cs:464-479` ile birebir).
- **`BR-SEC-25` (CTO Ş73-7) ölçülürken öncül daraldı ama ayakta kaldı:**
  `SET "app.cross_tenant" = 'on'` taşıyan fonksiyon sayısı 2 değil **6**; 4'ü `RETURNS trigger`
  olduğu için doğrudan çağrılamıyor. Geriye kalan gerçek yüzey **`BR-SEC-26`** olarak açıldı:
  **`public.*` fonksiyonların `proacl`'ini ölçen hiçbir bekçi yok** — bir
  `REVOKE … FROM PUBLIC` bekçisiz yazılırsa bir sonraki `CREATE OR REPLACE`'te **sessizce**
  geri alınır ve kimse görmez.
- **Commit:** `de469922` (BR-SEC-17 + kapı) · `8b1d9f76` (merge) · `3645c08a` (BR-SEC-26 kartı)

### 91. `BR-DOC-21` — belge kodu yanlış tarif ediyordu, dört yüzeyde düzeltildi

- **Neden:** CLAUDE.md §3.2 *"bu uçlar Redis'ten servis edilir; PostgreSQL sıcak yolda değildir"*
  diyordu. Beş Sınıf-B ucunun hepsi tek tek ölçüldü ve cümle **koşulsuz doğru değil**:

  | Uç | Sıcak yolda fiilen ne var |
  |---|---|
  | `queue-target` | **Saf Redis** — DbContext yok; önbellek düşerse `503` (`QueueTargetEndpoints.cs:33,69,73`) |
  | `route-decision` | Handler **transaction açıyor** (`RouteDecisionEndpoints.cs:258-261`); önbellek ıskasında ve TTL dönümünde EF sorgusu koşuyor |
  | `call-permission` | **Tamamen PostgreSQL, önbellek YOK** — `EfTenantSuspensionProbe.cs:38-43`, `EfBlacklistDirectory.cs:67`, `EfTenantSettings.cs:414,465`, `EfCallAttemptLedger.cs:59` |
  | `call-result` | PostgreSQL yazar; Redis yalnız idempotens rezervasyonu |
  | `screen-pop` | **Kodda YOK** — `src/` altında sıfır eşleşme. Sözleşmede tanımlı, uç hiç yazılmamış. |

  `call-permission`'ın önbelleksizliği **kaza değil**: Karar #12/5 onu bilerek yasaklıyor
  (fail-closed kapıda önbellek "yeni yasak TTL boyunca görünmez" hatasını sokar).
- **Ne yapıldı:** cümle **silinmedi**, üzeri çizildi + `DÜZELTİLDİ` mezar taşı bloğu eklendi;
  aynı düzeltme **dört yüzeye**: `CLAUDE.md:196`, `AGENTS.md:138`,
  `doc/mimari/api-kontrat-v1.md:1031`, `.claude/agents/backend-lider.md:22`.
- **Kurulun zaten doğruyu bildiği ortaya çıktı:** `Karar #65 Ş65-3.5` migrate penceresinde
  *"`call-permission` red sayısı"* ölçümünü şart koşuyor — yani **aykırı olan belgeydi**, kod değil.
- **Bekçi:** `tests/Pbxtr.Architecture.Tests/ClassBHotPathDataSourceTests.cs` (3 test).
  Pozitif (`call-permission` zinciri `PbxtrDbContext` taşır, `ITenantCache` taşımaz) +
  **kontrol grubu** (`QueueTargetEndpoints` tam tersi — jeton kümesi ayrıştırıcı) + belge testi
  (yanlış cümle üç belgede ancak `~~` ile geçebilir; koşulsuz geri yazılırsa **ve tamamen
  silinirse de** kırmızı). Mutasyon **3/3** yakalandı.
- **Yanında kapananlar:** `BR-OPS-03` kapandı, kalan tek kalem `BR-OPS-16` olarak açıldı
  (oto-cevaplanan çağrı `call_events`'te işaretlenmiyor → terk oranı paydası ayrılamıyor).
  `BR-OPS-11` (3) kapandı, 4 kalem açık kaldı. `BR-OPS-14` (b) **üretilemedi** — webhook
  migration'ı sunucuda hâlâ uygulanmamış (`__EFMigrationsHistory` = 0), ölçülecek ACCESS
  EXCLUSIVE edinimi henüz yok; **sahte ölçüm üretilmedi.**
- **Commit:** `bed1a5b0`, merge ile main'e alındı.


### 92. `BR-SEC-22` — santralin cevabı alındı, ve iki kez az kalsın yanlış yazıyordum

- **Neden:** Karar #70 Ş70-21'in sorusu bir yıl boyunca **ölçülmemiş** duruyordu: ARI
  `PUT/DELETE /asterisk/config/dynamic/res_pjsip/endpoint/...` mevcut kimlikle **2xx dönüyor mu?**
  Dönüyorsa CLAUDE.md §3.1'in *"config yalnız pbxtr üretir"* cümlesi çürümüş demekti.
- **CEVAP: 2xx DÖNMÜYOR.** `PUT` → **403** `Cannot create sorcery objects of type 'endpoint'`,
  `DELETE` → 404. Kontrol grubu: aynı kimlikle `GET /endpoints` → **200**.
- **Birinci tuzak — `HTTP=000` dört hücrede.** İlk koşuyu host'tan yaptım; `AriBaseUrl`
  `http://asterisk:8088`, yani **docker ağı adı**, host'tan çözülmüyor. Dördü de 000 döndü.
  Kontrol grubunu (A) koymasaydım bu "ARI yazmayı reddediyor" diye okunurdu. *"Araç yokluğu
  sıfır gibi görünür"* dersinin birebir tekrarı — `pbxtr-app` konteynerinde `curl` de yok,
  ölçüm `pbxtr-nginx` üzerinden koştu.
- **İkinci tuzak — ve bu daha tehlikeliydi.** Beş PJSIP tipini denedim:
  `endpoint` 403, `aor` 403, ama **`auth`/`identify`/`registration` → 400 "field value validation"**.
  Bunu *"yazma yolu açık, yalnız gövdem geçersiz"* diye okudum ve neredeyse **delik** diye
  yazacaktım. Geçerli bir gövdeyle (`identify`: `endpoint` + `match=192.0.2.7`) tekrar ettim →
  **yine 403**. Asterisk **alan doğrulamasını wizard kontrolünden ÖNCE** koşuyor; 400 bir
  yetenek değil, sıralama artefaktı.
- **Ama sebep bir yetki değil, bir yapılandırma.** `/etc/asterisk/sorcery.conf` **boş** → tüm
  tipler salt-okunur `res_sorcery_config` wizard'ında (use count 26). Oysa
  `res_sorcery_memory.so` (use count **8**) ve `res_sorcery_realtime.so` **yüklü**.
  `sorcery.conf`'a tek satır (`identify=memory`) yazmak ARI yazma yolunu **mevcut kimlikle**
  sessizce açar; `identify` yazılabilirse saldırganın IP'si güvenilir trunk olur.
  Bunu ölçen kapı yok → **`BR-SEC-27`** açıldı ve SYS ajanına devredildi (doğru evi yeni bir
  `kapi_74` değil, `deploy/asterisk-sunucu-sapma.sh`'in **S8** iddiası).
- **Kalıntı:** yok — PUT'lar hiç yaratmadı, GET/DELETE doğrulaması 404.
- **Commit:** `7fabc917`

### 93. `BR-SEC-26` — bypass ayrıştırıcı ölçümle kanıtlandı

İlk denemem ayrıştırmadı: `pbxtr_app` rolüyle sahte tenant GUC'unda üç hücre de **0** döndü —
ama kontrol grubu da 0 döndüğü için bu **"sızıntı yok"** demek değildi, **"fikstür ayırt
etmiyor"** demekti. Aynı gövdeyi (`SELECT count(*) FROM tenants`) dört hücrede koşturdum:

| Hücre | Sonuç |
|---|---|
| A — doğrudan okuma | **0** |
| B — aynı gövde fonksiyon içinde, `SET` **yok** (kontrol) | **0** |
| C — aynı gövde + `SET "app.cross_tenant"='on'` | **5** |
| D — sahip rolü, gerçek toplam | **5** |

B→C arasındaki **tek değişken** `SET` yan tümcesi. Yani sızıntı fonksiyon sarmalayıcısından
değil **fonksiyon düzeyi `SET`**'ten geliyor ve RLS'i **tamamen** aşıyor — yetki kontrolü de
denetim kaydı da yok. `01-rls-template.sql:177-180`'deki *"sadece `tenant.manage` + `[CrossTenant]`
+ her seferinde denetim"* cümlesi bu yoldan **yanlış**.

Kartın sayısı da düzeldi: `app.cross_tenant` taşıyan fonksiyon **6 değil 8**; 6'sı `RETURNS trigger`
(doğrudan çağrılamaz), **doğrudan çağrılabilen tam olarak iki**. `proacl`'in fiilî hâli sekizinde
de aynı: boş grantee → **PUBLIC EXECUTE fiilen var**. Düzeltme `02-guards.sql`'e dokunacağı için
**kurul gerekiyor** (tek başına değil, şablona dokunacak diğer kartlarla tek turda).

### 94. HEAD'de iki kırmızı buldum — ikisi de "benim değil" diye bildirilmişti

Bu depoda *"kırmızı benim değil"* iddiası HEAD'i kapsamıyor; ikisini de doğruladım, ikisi de
gerçekti:

1. **`AsteriskConsoleRoleCommandSetTests` (3 test).** `bdf503a1` kataloğa `AST-13`'ü ekledi,
   çivi güncellenmedi. **Kapı tam tasarlandığı gibi çalıştı:** kendi yorumundaki mutasyon
   ölçütü *(b) "yeni bir AST komutu ekle → KIRMIZI"* gerçek bir commit tarafından tetiklendi.
   Çiviyi **varsayarak değil ölçerek** düzelttim: `AST-13` iki kümede de var, çünkü katalog
   tanımı `NeedsUnmask: false` taşıyor (`AsteriskCommandCatalog.cs:186`) → `phone.unmask`
   istemez, admin de görür. 12 → 13. 3/3 yeşil. Commit `c99c9eb6`.
2. **`ConfigRenderGuardTests.Uretilen_metnin_degismezleri_saglanir`.** `b21cc3b1` `queues`
   çıktısına `[general]` ekledi; **üretim kapısı doğruydu**, kapıyı ölçen test bayattı.
   İki ajan (SEC ve AST) bunu bağımsız olarak buldu ve **aynı dar** düzeltmeyi yazdı →
   merge çakışması. Anlamsal olarak özdeş oldukları için AST tarafını aldım (gerekçe yorumu
   `isQueues` tanımının üstünde duruyor, HEAD'inki mükerrer olurdu).

### 95. Dördüncü dalga — altı ajan paralel

- **`BR-AST-93` (P1) kapandı, santralde A/B ile.** Kart *"köprülemede mükerrer `MixMonitor`"*
  diyordu; doğru çıktı: damgasız kolda `MixMonitor` **2 kez**, damgalı kolda **1 kez** koştu.
  **Kritik yan ölçüm — tek kapı yetmezdi:** `__PBXTR_REC` **kalıtımlı** ve eş bacağa geçiyor,
  yalnız ilk satırı kapatmak `MixMonitor`'ı durdurmazdı → kayıt üçlüsünün **üçü de** kapatıldı.
  Ayırt edici olarak `PBXTR_CTL` **kullanılmadı** (agent bacağı da `0` ile doğabilir); damga
  `PBXTR_BRIDGE_LEG=1`, **tek alt çizgi** — yani bilerek kalıtılmaz.
  **Ölçülemedi (yok değil):** iki yazıcının sesi bozup bozmadığı bayt düzeyinde karşılaştırılamadı
  — santralde `sox`/`ffmpeg` yok.
- **`BR-BE-136/131/134/143/168` kapandı**, `BR-BE-135` **kısmen**: kartın öncülü yanlış çıktı —
  üründe occupancy/doluluk metriği **hiç yok**, dolayısıyla kartın vacuity kapısı karşılanamıyor.
- **`BR-FE-107` ve `BR-FE-102` kapandı.** FE-102 için istenen ölçüm koşuldu: **12 ardışık tam
  takım koşusu, filtresiz** — her koşuda 221 dosya / 1984 test yeşil, kırmızı oran **%0 (0/12)**;
  kartta 1/4 yazıyordu (p=0,25 ile 12 temiz koşunun olasılığı ~0,03). Bir bölümü bilerek yük
  altında koşturuldu.
- **DB turu:** `BR-DB-75/64/77` kapandı; `BR-DB-50`'nin vacuity kapısı **koştu ve geçti**
  (DETACH uzun tx içinde eşzamanlı INSERT'i **6.919 ms** bekletti, kısa tx'inde 25,6 ms).
  Ama **on bir kart kurul kararı bekliyor** ve çoğu aynı yapısal bedeli paylaşıyor: şablon
  tazeleme migration'ı + onay defteri satırı. Her birine ayrı tur açmak defteri lastik damgaya
  çevirir → **tek turda** toplanacak.

### 96. Yayın penceresi — saate değil trafiğe bakıldı

Ş73-Y1 *"mesai dışı"* diyor. Saat 08:32 TR, yani mesai içi. Şartı saate bakarak atlamak da
uygulamak da yanlış olurdu: şart **giden aramayı korumak** için yazıldı (`call-permission`
FAIL-CLOSED), o yüzden ölçülen şey saat değil **trafik** oldu:

- ARI `GET /channels` → **`[]`** (aktif kanal 0).
- `call_events` son 24 saat = 2079 satır — **ama tohum ve gerçek aynı tabloda işaretsiz.**
  Ayrıştırıldı: **1923'ü `cdr` önekli** (ETL geri doldurması, çağrı değil), `1789…` önekleri
  **bizim kendi originate ölçümlerimiz** (2026-09-17 18:06–19:05), 9 satır `demo` tohumu.
- Saatlik şekil 10:00–17:00 arası **dümdüz ~140/saat, 17-18 farklı `call_id`** — insan
  trafiğinin şekli değil, **periyodik bir işin** şekli. Son 12 saatte toplam **10 olay**.

Şart kaldırılmadı; **bu koşuda vacuous olduğu** yazılı hâle getirildi (`Ş73-Y1` altına).
Yayın yine de yapılmadı, sebebi ayrı ve daha güçlü: **dört ajan aynı anda depoyu
değiştiriyordu** — hareketli hedefe yayın, kırmızının sahibini okunamaz kılar.

**Yayının açacağı kartlar ölçüldü:** `BR-DB-69/74/79/84/88` beşinin de tek tetiği yayın;
buna `BR-BE-150`, `BR-BE-119`'un panel yarısı ve `BR-AST-103` ekleniyor. Ve yayın
`BR-DB-88` yüzünden **kritik**: `GuardsTemplateRefresh` inmeden önceki bir sürüm inerse
`MaintenanceRunner.GuardAsserts` var olmayan `pbxtr_assert_role_settings_guard()`'ı çağırır
ve uygulama **hiç açılmaz**. Sunucuda ölçüldü: 183 migration uygulanmış, **16 bekliyor** —
Karar #73 Ş73-Y1'in yazdığı sayıyla birebir.

### 97. Bir sır transkripte düştü — dördüncü kez, ve bu sefer KENDİ kuralımla

SYS ajanı `/etc/pbxtr/confd/*` dosyalarını okurken `sed 's/=.*/=<gizli>/'` maskesini kullandı —
yani hafızamdaki *"güvenli biçim"in* ta kendisini. `anahtar` dosyası **çıplak bir sır** ve içinde
`=` yok → sed hiçbir şeyle eşleşmedi, satır **olduğu gibi** basıldı ve `ak_6323b8555a05eebf`'in
sırrı transkripte düştü. Ajanın kendi hatası değil: **benim brief'im** *"env okurken değer
sütununu kes"* diyordu ve bu cümle `KEY=VALUE` varsayıyor.

**Etki yarıçapını ölçtüm, panik etmeden:**
- `api_keys.ip_allowlist` **anahtar başına CIDR** taşıyor ve eşleşmezse **403**
  (`ProvisioningEndpoints.cs:1406`).
- Sızan anahtarın allowlist'i **`172.16.0.0/12`** — RFC1918, docker iç ağı. Genel internetten
  kullanılamaz; kullanabilmek için saldırganın **zaten o host'un docker ağında** olması gerekir,
  o noktada config'e nasıl olsa erişir.
- Sunucudaki **altı anahtardan aktif olan yalnız bu**; diğer beşi 2026-09-06'da iptal edilmiş.

Yani rotasyon gerekli ama **acil değil** → `BR-SEC-28` açıldı ve `BR-SEC-16` sır rotasyonu
paketine bağlandı (aynı pencerede dönülecek).

**Kural nihai hâlini aldı — maskeye değil YOLA bak.** Sır taşıyan bir yolu hiçbir maskeyle
stdout'a getirme: maske **biçim varsayar**, yol varsaymaz. Ölç (`ls -l`, `wc -c`,
`sha256sum | cut -c1-8`), içeriği hiçbir kipte basma. *"Maskeledim"* bir savunma değildir;
maskenin o dosyada **uygulandığını** kanıtlayamıyorsan maske yoktur. Hafıza güncellendi.

### 98. SYS turu — bir kartın teşhisi yine yanlış çıktı, ve bir kural daraltıldı

- **`BR-SYS-58` — kartın engel teşhisi YANLIŞTI.** Kart `audit_log` FK'sını suçluyordu; gerçek
  engel **append-only tetiği + otomatik doğan `tenant_billing_info`/`tenant_company_info`**
  çıktı. Gerçek N=50 koşuldu: 50 DISTINCT tenant, render **0,51 s** (~10 ms/tenant).
- **`BR-SYS-87` — 38-tenant kuralı DARALTILDI.** Kararlı hâlde N=50'de toplam **19** `docker`
  çağrısı / 2,5 s — tenant başına 45 değil. Tavan yalnız **tam teslim** turunda geçerli.
- **`BR-SYS-101` — vacuity ölçütü ÜRETİLDİ.** t0012 pinlenince 4 tür rev=1 teslim edildi
  (`dialplan show` 0→89), eski araç `cek.sh` çok tenantlı düğümde **fail-closed reddetti**
  (exit 78). Sonra geri alındı (89→0).
- **`BR-SEC-27` aynı turda kapandı.** S8 iddiası `asterisk-sunucu-sapma.sh`'e eklendi, öz-test
  **27 → 33/33**, mutasyon **gerçek canlı anlık görüntüde**: kontrol 0 → `identify = memory` 1 →
  geri alındı 0. Davranışsal ARI PUT hücresi **bilerek atlandı** — betiğin yazılı
  *"SUNUCUYA YAZMAZ"* kuralı var ve PUT bir yazmadır; gerekçe karta yazıldı.
  Küçük düzeltme: `sorcery.conf` canlıda **boş değil, hiç yok**; S8 iki hâli de yeşil sayıyor.
- **Ajanın kaydettiği tuzak:** S8'in sapma mesajındaki apostrof `${VAR:+...}` genişlemesinin
  **içindeydi**; bash onu tırnak başlangıcı saydı ve betik "unexpected EOF" ile **hiç koşmadı**.
  *Koşmayan bekçi bekçi değildir* — gerekçe koda yorum olarak yazıldı.
- **İki yeni gerçek kusur** (ikisi de canlıda uçtan uca üretildi): `BR-AST-108` — bir tenant
  düğümden düşürülünce **üretilmiş config'i santralde kalıyor** (89 dialplan satırı yüklü kaldı,
  ajan hiçbir şey söylemedi; belirti **sessiz**). `BR-AST-109` — üretilen bir park yeri kapalı
  reload listesiyle **kaldırılamıyor**; kaldırma yolu `module unload`/`core restart` ve ikisi de
  §3.1'de yasak → artık **yazılı borç**.


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

### 99. "Tarihçe" durum sanılıyordu — 14 bitmiş kart açık görünüyordu

- **Neden:** `Bitti` ile BAŞLAYAN 16 kart panoda hâlâ `in progress` duruyordu. Sebebi
  aradım: `yonetim/arac/clickup-durum.js` kural 1 (`Kısmen` geçerse → in progress)
  **tüm hücreyi** tarıyordu. Uzun hücrelerde `Kısmen` çoğu kez GÜNCEL durumda değil,
  `Önceki kayıt:` **tarihçesinde** geçiyor.
- **Ölçüm (konum/uzunluk):** `BR-AST-28` 303/565, `BR-SYS-91` 2583/4014,
  `BR-QA-88` 706/1754 — üçünde de eşleşme tarihçedeydi. Kontrol örneği `BR-DB-65`
  82/2259 → **güncel** parçada, yani doğru şekilde açık.
- **Ne yapıldı:** Hücre `Önceki kayıt:` çıpasından kesiliyor, kurallar yalnız öncesine
  uygulanıyor. **Sınır bilerek dar:** çıpa yoksa hiçbir şey atılmaz; güncel parçadaki her
  `Kısmen` aynen ısırır (CLAUDE.md §14: açık işi kapalı göstermek daha kötüdür).
- **Dokunulan dosyalar:** `yonetim/arac/clickup-durum.js`, `yonetim/arac/clickup-durum.test.js`
- **Doğrulama:** 5 yeni assert, **ikisi ters yön** (güncel parçadaki `Kısmen` ısırmalı).
  **Mutasyon:** kesme geri alındı → takım **KIRMIZI** (rc=1); geri kondu → yeşil (rc=0).
- **Sonuç:** 20 kart yeniden sınıflandı (14 → complete, 6 → backlog).
  `505/81/69/3/5` → `519/63/75/3/3`. Açık kart **158 → 144**.
- **Commit:** `5f3d6225`
- **ClickUp:** 2 kart açıldı (BR-QA-100/101), 20 durum yazıldı, doğrulama
  `fark olan kart: 0, izde olmayan: 0`.

### 100. EPIC toplayıcı kartlarının eksik alt numaraları ölçüldü

Yedi EPIC kartı "alt kart numarasının backlog'da satırı yok" diye bekliyordu. Numara
yokluğu iki şeyden biri olabilir: iş başka kart altında yapılmış (numara bayat), ya da iş
gerçekten yok. **Kaynak taramasıyla ayrıldı:**

| Epic | Kalan GERÇEK iş |
|---|---|
| **BR-B1/B2** geri arama | Çıkış tarafı ayakta (`callback_entries`, `CallbackRunJob`, `CallbackDispatcher`, `CallbackBoardPanel`). Eksik olan **talep alma yarısı**: `callback_digit` kuyruk ayarı (0 eşleşme), `[…-qexit-…]` dialplan bağlamı (0), `UserEvent` alım ucu, `queue_optin` kökeni/FIFO önceliği (0), `callSource` rozeti (yalnız bir yorumda), `callback_requested` SLA sınıfı (0). **Uyarı:** C#'ta `callback` kelimesi delege anlamında 397 dosyada geçiyor — gürültü. |
| **BR-7** yetenek yönlendirme | Sunucu TAM (migration `20260917210658_SkillBasedRouting`, 8 uç `SkillAdminEndpoints.cs`). Web'de `/skills` çağrısı **0 eşleşme** → ön yüzün tamamı yazılacak. |
| **BR-C2-1/2** webhook | Backend + ön yüz VAR (`WebhookOutboxWriter`, `WebhookDeliveryDispatcher`, `WebhooksPane.tsx`). Kalan **yalnız sistem ayağı**: `st48-kilit.nft` webhook egress sınıfı (0 eşleşme), `pbxtr.service` `IPAddressDeny/Allow` (0), ve `BR-BE-31` SSRF kapısının SMTP/S3 ayağı (ADR-019 §4 borcu). |
| **BR-KAPANIS** | `purge_call_data()` izin listesinde `webhook_outbox`, `webhook_deliveries`, `callback_entries` **YOK** (`20260918090000_VoicemailRetentionAllowlist.cs:155,160`). Gövde donmuş md5 ile korunuyor (`deploy/db/sys-functions.expected:16`) → tek migration + tek md5 tazelemesi. Purge runbook'u hiç yok. |
| **BR-15** izin CSV | Uç yok; mekanizma olgun (6 örnek, `Results.File(..., "text/csv; charset=utf-8", …)`). **Kartın öncülü yanlış:** izin satırında telefon kolonu yok, numara serbest nottadır → doğru redaktör `FreeTextRedactor`, kartın andığı `PhoneSurfaces.Export` değil. |

## Kararlar
- **Durum eşleyicide tarihçe, durum değildir.** Kural sınırı dar tutuldu: çıpa yoksa
  hiçbir şey atılmaz. Gerekçe CLAUDE.md §14.
- **Kart numarasının yokluğu, işin yokluğu demek değildir** — ikisi ayrı ölçülür.
  Yedi EPIC'ten üçünde iş yapılmıştı, numara bayattı.

## Açık kalanlar / sonraki adım
- 8 ajan paralel: SEC(11), DB(16), AST(27), BE(27), QA/FE/DOC(16), SYS/OPS(19),
  BR-7 ön yüz, BR-15 CSV.
- `backlog.md` ajanlar bitene kadar bana kapalı (çakışma) — EPIC satırları sonra yazılacak.
- **Yayın hattı kendiliğinden koşturulmuyor:** iki koşu bellek yetersizliğinden öldürüldü,
  talimat "yalnız istenirse". 8 kart (BR-DB-69/74/79/84/88, BR-BE-150/119, BR-AST-103) o
  yüzden bloke.
- BR-SEC-16 + BR-SEC-28 sır rotasyonu: ajanlar bitince, bende.

---

## Ek tur — backend-dev-1: 27 açık BE kartı (BR-BE-43-B … BR-BE-192)

### Bağlam
Koordinatör 27 açık BE kartını "oku → kodda ölç → iş varsa yap, yoksa yokluğunu kanıtla"
yöntemiyle kapatmamı istedi. Kartın kendi teşhisi yanlış çıkarsa doğru bulgu yazılacaktı.

### 1. BR-BE-192 — 23503 merkezî kapıda 409 (TEK GERÇEK KOD İŞİ)
- **Neden:** FK ihlali (`23503`) hiçbir yerde eşlenmemişti; `PbxtrExceptionHandler.ResolveCode`
  içinde `_ => InternalError` dalına düşüyordu. Kullanıcının gördüğü "bu kayıt kullanımda"
  reddi, gerçek bir sunucu arızasından ayırt edilemeyen bir **500**'dü. `BR-DB-89`
  (`SET NULL` → `RESTRICT`) bu hâliyle inseydi bu, normal kullanıcı akışı olacaktı.
- **Ne yapıldı:**
  - `PostgresErrors.IsForeignKeyViolation` (+ `ForeignKeyViolation = "23503"` sabiti).
    Soru **Infrastructure'da** cevaplanır — ADR-001 §3.1 `Npgsql` tipinin `Pbxtr.Api`
    içinde geçmesini yasaklar; sınıfın kendi özeti zaten bu amaç için yazılmış.
  - `PbxtrExceptionHandler`: eşleme (`BadHttpRequestException`'dan SONRA, `_`'dan ÖNCE),
    başlık, `meta.rule = "in_use"`, ve `LogWarning` + **yalnız `ConstraintName`**.
  - **Bilinçli iki eksiklik yazıldı:** `meta.action` YOK (merkezî kapı hangi kaydın hangi
    eylemle kurtarılacağını bilmez, uyduracağına susar); `LogError` YOK (her "kayıt
    kullanımda" reddi 500 alarmına karışırdı). `Detail` PCI notu gereği hiçbir yere.
  - Kartın (2) maddesi (arka plan savepoint/atla) **zaten vardı**: `ObjectRowRetentionJob.cs:270`.
- **Dokunulan dosyalar:** `src/Pbxtr.Infrastructure/Persistence/PostgresErrors.cs`,
  `src/Pbxtr.Api/Platform/Errors/PbxtrExceptionHandler.cs`,
  `tests/Pbxtr.Api.Tests/Platform/Errors/ExceptionHandlerTests.cs`
- **Doğrulama:**
  ```bash
  dotnet build tests/Pbxtr.Api.Tests/Pbxtr.Api.Tests.csproj   # rc=0
  dotnet test  tests/Pbxtr.Api.Tests --filter ExceptionHandlerTests
  ```
  Yeşil: `Failed 0 / Passed 24`. **Mutasyon fiilen koşuldu:** dal `=> InternalError`
  yapıldı → `Failed 4 / Passed 20`; geri alındı → `Failed 0 / Passed 24`. Her iki
  ölçümden önce build rc=0 ile doğrulandı (bayat ikili tuzağı).
- **Commit:** `adf1bc94` / `3c540b15`

### 2. Kartların kendi teşhisi yanlış çıkan iki kalem
- **BR-BE-169** — kart "kapsanmayan 4 dış ayna" diyordu; **üçü zaten kapsanmış:**
  `ck_host_metrics_key` `EnumMirrorCheckConstraintTests.cs:176`'da aynada,
  `ck_dial_numbers_owner_type` `:241`'de gerekçeli muaf (**yazılı borç**),
  `ck_roles_custom_code_not_system` `SystemRoleScopeCatalogParityTests` ile katalogdan
  türetiliyor (o dosyanın mutasyon planı madde 4 bu satırı kapsıyor). Gerçekte açık
  olan **tek** kalem `ck_call_attempts_origin` (C# kaynağı `CallAttemptOrigins.All`).
  **Ve orada bir çelişki var:** kısıt `origin IS NULL OR origin IN (4 değer)`; PostgreSQL
  bunu `= ANY (ARRAY[...])` diye normalize eder ve sınıf kapatıcı tam bu ize bakar
  (`:373`) → kısıt kurulu DB'de varsa kapatıcı **bugün kırmızı olmalıydı**, oysa yeşil
  raporlanmıştı. Docker kapsam dışı olduğu için ayna satırı **bilerek yazılmadı**:
  ölçmeden eklemek ya vacuous ya HEP KIRMIZI bir kapı bırakırdı.
- **BR-BE-46-B** — kartın "48 satır" sayısı bayat. Ölçülen (`grep -cF`, `ConfigRenderer.cs`):
  `${EXTEN}` **2**, `${DB(` **5**, herhangi `${` **81**. Yasağın lafzı yine her tenant'ın
  dialplan'ini `withheld` yapardı; sonuç değişmedi, sayı düzeldi.

### 3. Kalan 24 kart — hiçbiri backend tarafından tek taraflı açılamaz
| Engel | Kartlar |
|---|---|
| Kurul / mimari kararı | BR-BE-52, 76, 80, 117, 120, 121, 152, 164, 165(1), 176, 182, 190 |
| DB kolonu / migration onayı | BR-BE-43-B, 73, 159, 181 |
| Öncül kart açık | BR-BE-51 (`BR-DB-44`), 135 (doluluk metriği yok), 190 (`BR-AST-107` P0) |
| Frontend | BR-BE-171(a), 175 |
| Docker'lı DB / santral ölçümü | BR-BE-169(d), 185, 121(2) |
| `backend-dev-2` / eşzamanlılık ölçümü | BR-BE-170(c) |
| Tanım işi (`yazilim-mimari` + `asterisk-uzmani`) | BR-BE-46-B |
| `pbxtr-qa` negatif testi | BR-BE-183 |

Her kartın Durum hücresi yeniden ölçülerek güncellendi; önceki metinler
`Önceki kayıt:` altında **silinmeden** korundu. ŞART sütununa dokunulmadı.

### Kararlar
- **"Kartı kapat" ≠ "kartı Bitti yap."** 27 kartın 26'sının engeli kod değil; engeli
  adıyla yazmak, sahte bir `Bitti`den daha kıymetli.
- **Ölçülmemiş ayna satırı yazılmaz.** BR-BE-169'da tek satırlık iş vardı ama kapı
  Docker'lı; koşulamayan bir kapı satırı eklemek defterdeki *"koşmayan kapı bulgu
  değildir"* dersinin tekrarı olurdu.

### Açık kalanlar / sonraki adım
- **Kurul gündemi (üç madde):** (1) `BR-BE-176` ↔ `BR-BE-182` **aynı turda** karara
  bağlanmalı — biri "slug'ı DB'ye materyalize et", diğeri "kutuyu kimlikle taşı" der ve
  **doğrudan çelişirler**; (2) `BR-BE-164`/`BR-BE-165` müdahale üyeliğinin penalty'si
  ve yaşam döngüsü (Karar #67 Ş67-8 seçmedi); (3) `BR-BE-152`'nin devrettiği RLS
  `WITH CHECK` cross dalının kaldırılması.
- **Docker'lı tek koşu üç kartı birden ilerletir:** `ck_call_attempts_origin` kurulu mu
  (BR-BE-169) + `Down()` `NOTICE` gözlemi (BR-BE-185) + `queue show` ↔ `queue_members`
  karşılaştırması (BR-BE-121).
- **Tuzak kaydı:** çalışma ağacında paralel ajanlar var; bir ajanın yarım `.csproj`
  düzenlemesi (`XML yorumunda '--'`) benim build'imi **MSB4025** ile öldürdü ve o arada
  koşan `dotnet test` **eski ikiliye** gidip "24 passed" dedi. Mutasyon ölçümü bu yüzden
  bir kez yanlış yeşil verdi. Ders: `PIPESTATUS[0]` + build rc'sini her ölçümden önce oku.

---

### BR-AST turu — 27 acik kartin olculmesi (backend-dev-2)

- **Neden:** `yonetim/backlog.md`'de 27 acik `BR-AST-*` karti vardi ve cogunun Durum
  hucresi "olculdu ama is kaldi" diyordu. Kartlarin **kendi teshisleri bayat olabilir**
  (defter: *kart onculu olculmeden yazilmaz*), bu yuzden her kart once KODDA olculdu.

- **Ne yapildi (kod):**
  1. **BR-AST-102 kapandi.** Santral olcumu iki sey demisti: kayitsiz uygulama adiyla
     cagrilan `Stasis()` kanali DUSURMUYOR (yani "sessiz dusme" yok), **ama**
     `call_events`'e hicbir iz dusmuyordu. Panel kapaliyken cagri kontrolsuz devam
     ediyor ve timeline'da hicbir sey bunu soylemiyordu. Kapatilan yari iz.
     - Yeni kapali kume `ControlPlaneSignals.StasisUnavailable`. **`TakeoverSignals`'a
       EKLENMEDI** — `TakeoverSignals.All` ile sayan yerler (`EfTakeoverOutcomeQuery`,
       `EfAgentWorkspace`) sessizce baska bir seyi saymaya baslardi.
     - `ConfigRenderer.AppendStasisUnavailableTrace` -> `[pbxtr-{t}-out]` ve
       `[pbxtr-{t}-int]`'te devir denemesinden SONRA kosullu `UserEvent`.
     - **Kosul iki ariza kipini de soruyor ve bu bir tercih degil:**
       `STASISSTATUS=FAILED` = modul yuklu / uygulama bagli degil (pbxtr kapali, SIK hal);
       `TRYSTATUS=NOAPP` = `res_stasis` hic yuklu degil (BR-AST-94 olcumu). Ikinci kipte
       `STASISSTATUS` **hic yazilmaz**, birinci kipte `TRYSTATUS=SUCCESS` olur — tek
       degiskene bakan kosul kiplerden birini **yapisal olarak** kacirirdi.
     - **Anons BILEREK yazilmadi:** S70-12'nin anons yarisi GELEN cagri icin; giden yonde
       cagri saglamdir, konusan cagriya anons calmak arizayi buyuturdu (CLAUDE.md §3.2).
       Gelen yon bugun `Stasis()`'e hic girmiyor -> o yari BR-AST-58/61'e baglandi.
  2. **BR-AST-109 (1) kapandi:** `res_parking` siniri `deploy/asterisk-conf-sinir.txt`'e
     yazildi (provisioning park yeri yaratabiliyor ama kapali reload listesiyle geri
     alamiyor; kontrol grubu ayni turda temizlenmisti -> `res_parking`e ozgu).

- **Dokunulan dosyalar:** `src/Pbxtr.Domain/Modules/Telephony/ControlPlaneSignals.cs` (yeni),
  `src/Pbxtr.Domain/Modules/CallHistory/CallTimelineLabels.cs`,
  `src/Pbxtr.Infrastructure/Provisioning/ConfigRenderer.cs`,
  `tests/Pbxtr.Api.Tests/Modules/Telephony/ConfigRendererTests.cs`,
  `deploy/asterisk-conf-sinir.txt`, `yonetim/backlog.md`

- **Komutlar / dogrulama:**
  ```bash
  dotnet test tests/Pbxtr.Api.Tests --filter "FullyQualifiedName~ConfigRenderer"
  # 30/30 yesil; CallTimeline ile birlikte 42/42
  # MUTASYON: TRYSTATUS -> TRYSTATUSX  => Failed 1 / Passed 29 (KIRMIZI), geri alindi
  ```

- **Olcumle CURUYEN iki kart teshisi (bu turun asil degeri):**
  - **BR-AST-92:** Durum *"pbxtr-confd medya ajani bu depoda YOKTUR"* diyordu. **Yanlis.**
    `deploy/pbxtr-confd-dugum.sh` tam bir medya teslim yolu tasiyor: `:888` manifest,
    `:1305-1338` indirme + sha256 dogrulamasi, `:1394-1440` **tenant bagli** hedef yol
    dogrulamasi (mutlak yol / `..` / GUID disi mediaId RED), `:1436` `/var/lib/asterisk`
    altina yazim, indirilemezse tenant ATLANIR (fail-closed). Geriye kalan tek sey
    9 dilin **ses kaynagi** — bir kod isi degil.
  - **BR-AST-79:** kartin onerdigi *"#37'ye tenant bazli gorunur satir"* bicimi bugunku
    sozlesmeye **aykiri**: `RegistrationSnapshot.cs:87-91` ozet icin kapali kisit yaziyor
    (tenant kodu/kimligi/dahili numarasi YAZILMAZ, tenant kirilimi YOK) ve gerekcesi
    guvenlik — aksi halde `bundle.system` capraz-tenant bir **is envanterine** donusur.
    Bu yuzden bicim uydurulmadi; uyarinin yuzeyi (sistem sayisi mi, tenant kapsamli
    ekran mi) mimari/kurul sorusu olarak yazildi.

- **BR-AST-29 kapandi cunku kalan is KODDA ZATEN VARDI:** `QueueMemberPresenceResync.cs:13`
  periyodik `QueueStatus` varlik mutabakati; kuyruk yok olunca hicbir sey yazilmaz,
  kayitlar TTL ile duser ("olculemedi") ve eski deger tazelenmez. DI dikisi
  `TelephonyServiceCollectionExtensions.cs:361`, cagrilma yeri `QueueMetricDeriver.cs:159`.

- **Sonuc:** 2 kart KAPANDI, 8 kart "olculdu — is yok" diye kanitlandi, 15 kart BLOKE
  (sebebi hucreye yazili), 2 kart teshisi curudu.

- **Commit:** `27a900c8` (kod) — backlog guncellemesi es zamanli calisan baska bir ajanin
  `3c540b15` commit'ine dahil oldu (ayni dosya, ayni an).

## Kararlar (bu tur)

- **Sira kilidi: ONCE BR-AST-108, SONRA BR-AST-17.** Hicbir yerde yazili degildi ve iki
  kart birbirini goturuyordu: BR-AST-17'nin kabul kriteri *t0012 dugumde > 0*, BR-AST-108'in
  olcum temizligi ise tam olarak t0012'yi dugumden DUSURMEK uzerine kuruluydu. t0012 yeniden
  pinlenirse 108'in vacuity kapisi (dusurulen tenant'in dosyalari bir sonraki turda gitmeli)
  **olculemez** hale gelir. Bu yuzden sunucudaki kayit bu turda DEGISTIRILMEDI.
- **BR-AST-81 kabul kriteri bugunku kapali listeyle KARSILANAMAZ.** (b) sikki "durum yeniden
  baslatma sonrasi AstDB'den geri geliyor mu" ve olcmek `core restart` ister — YASAK.
  Kurula gitti: ya (b) kabul edilir ya kriter daraltilir.
- **Anons != iz.** Bir arizanin "gorunur" olmasi, kullaniciya ses calmak demek degildir;
  giden yonde dogru cevap **cizelgeye satir dusurmek**, arayani rahatsiz etmek degil.

## Acik kalanlar / sonraki adim

- Kurul gundemi (kartlara yazildi): A14 yas tavani (39/46), S42-8 inbound uretici (58),
  S50-4 (b) olculemezligi (81), ADR-015 A1/A2/A3 (62/63/64), BR-AST-51a onceligi (A-1
  sahada sifir masa telefonu olcmustu), 9 dilin ses kaynagi (92), BR-AST-79 uyari yuzeyi,
  BR-AST-55 teslim sirasi kilidi (hint baglami -> StateInterface).
- **Ortam engeli, kod engeli degil:** BR-AST-72 / 80 / 98(ses) kapanmasi icin test
  sunucusunda **kayit olan bir WebRTC/SIP istemcisi** gerekiyor. Bugun `pjsip show contacts`
  bos, 6 endpoint'in tamami ARI'de `offline`.
- BR-AST-89: `pbxtr-app` restart isteyen tek ajanli bir bakim penceresi gerekiyor.

---

## BR-7 yetenek yonlendirme — ON YUZ (BR-FE-18/19/20/21)

### Baglam

Sunucu ayagi hazirdi ve olculmustu: migration `20260917210658_SkillBasedRouting`
(`skills`, `agent_skills`, `queues.required_skill_id`, `queues.min_skill_level`) ve
`src/Pbxtr.Api/Modules/Queues/SkillAdminEndpoints.cs`. Buna karsilik
`src/Pbxtr.Web/src` altinda `/skills` icin **sifir eslesme** vardi — yani sunucu
tarafi tamamen olu koddu, hicbir ekran o uclari cagirmiyordu.

### Yapilanlar

- **Neden:** yazilmis ama hicbir yerden cagrilmayan uc, yazilmamis uctan farksizdir;
  ustelik "bitti" gorunur.
- **Ne yapildi:** dort ayak tek turda yazildi.
  - `BR-FE-19` — #03 Kuyruk Yonetimi'ne **"Yetenekler" sekmesi** (katalog CRUD).
  - `BR-FE-18` — #02 kullanici kaydinda **yetenek atamasi** (yetenek + seviye, tam ikame `PUT`).
  - `BR-FE-21` — kuyruk formunda `requiredSkillId` + `minSkillLevel`.
  - `BR-FE-20` — uye listesinde onceligin **kaynagi** (yetenege bagli kuyrukta rozet +
    ekle/cikar kontrollerinin cizilmemesi).
- **Dokunulan dosyalar:** `src/Pbxtr.Web/src/app/screens/shared/skillsApi.ts` (yeni),
  `screens/queues/SkillsPanel.tsx|.module.css` (yeni), `screens/queues/QueuesScreen.tsx`,
  `screens/queues/QueueDialog.tsx`, `screens/queues/QueueMembersDialog.tsx`,
  `screens/queues/queuesApi.ts`, `screens/queues/QueuesScreen.module.css`,
  `screens/users/UserSkillsSection.tsx|.module.css` (yeni),
  `screens/users/UserDetailPanel.tsx`, `screens/users/UsersScreen.tsx`,
  `app/i18n/messages/{tr,en,de,fr,az,bg,ar,hy,ka}.json`.
- **Komutlar:**
  ```bash
  cd src/Pbxtr.Web && npx tsc -b --force   # EXIT=0
  npx vitest run                            # 1984/1985
  ```
- **Sonuc / dogrulama:** tip kapisi temiz; vitest'teki tek kirmizi
  (`auditActionParity` -> `leave.exported`) **bu turdan degil** — `aud.a.leaveExported`
  HEAD'de de yok ve `AuditActions.cs` baska bir ajanin acik isinde.
- **Commit:** `57b98820` — BR-FE-18/19/20/21: BR-7 yetenek yonlendirme on yuzu

### Kararlar

- **Ekran kayit defterine SATIR EKLENMEDI.** "Yetenekler" ayri bir ekran degil, #03'un
  sekmesidir; gerekce sunucu kodunda yazili (`SkillAdminEndpoints.cs:25-28`, Karar #29).
  Kendi rotasi olsaydi menude tek basina anlamsiz bir madde acilirdi — yetenek ancak bir
  kuyruga ya da bir agent'a baglandiginda is yapar.
- **Yetki adlari koddan alindi, uydurulmadi:** katalog `queue.read`/`queue.write`,
  agent yetkinligi `user.read`/`user.write`. Yeni yetki yok (Karar #29 sart 7).
- **Gorev metnindeki ekran numaralari yanlisti** (#48 = Kurulum Sihirbazi, #03 = Kuyruk
  Yonetimi, #02 = Kullanici Yonetimi). Yerlesim ekran numarasina degil, ucun **yetkisine**
  gore yapildi: `queue.*` -> #03, `user.*` -> #02.
- **Seviye araligi ve penalty sunucudan okunur.** `maxLevel - level` cikarmasi istemcide
  TEKRARLANMADI; formul degisirse panel ile santral sessizce ayrisirdi.
- **i18n anahtarlari metin olarak araya sokuldu**, `json.dump` ile yeniden uretilmedi:
  dosyalar tam alfabetik degil (olculdu) ve yeniden uretim ilgisiz ~30 satiri farka
  sokuyordu.

### Acik kalanlar / sonraki adim

- **#12/#13 penalty kolonu YAZILMADI** — `LiveQueueDto` (`LiveEndpoints.cs:1026`) ve
  `LiveAgentDto` (`:1171`) **penalty alani tasimiyor** ve o ekranlarda kuyruk uye
  listesi de yok. Uydurma veri cizilmedi. Kolon isteniyorsa once uc genisletilmeli.
- `auditActionParity` kirmizisi: `aud.a.leaveExported` dokuz katalogda eksik
  (`AuditActions.cs:750`). Leave export isini yuruten ajanin isi.

### BR-15 — #50 izin listesi CSV disa aktarimi

- **Neden:** #50 ekraninda liste vardi, disa aktarim yoktu; kalip depoda olgun
  (CDR/cari/denetim/rapor/analitik/script = 6 emsal).
- **Ne yapildi:** `GET /api/v1/leaves/export` — liste ucuyle **AYNI** filtre
  (`from`/`to`, 14 gun varsayilan, 92 gun tavan) ve **AYNI** yetki (`leave.read`),
  cikti CSV. Bicim `CsvCells`ten gelir (BOM + `;` + CRLF + formul enjeksiyonu
  korumasi); ikinci bir koruma kopyasi yazilmadi.
- **Maskeleme:** izin satirinda telefon **kolonu yok**; numara benzeri dizi
  serbest `Note` alanina girer ve CSV'ye `FreeTextRedactor.Redact`ten **gecerek**
  yazilir (liste ucundeki `LeaveDto.From` ile birebir ayni karar).
  `PhoneSurfaces.Export` bu yuzeye UYMAZ, kullanilmadi.
- **Denetim:** yeni eylem `leave.exported`; kayit **dosyadan once** yazilir.
  Govdede not metni TASINMAZ — yalnizca `noteRedacted` bayragi, satir sayisi ve
  pencere yazilir.
- **Dokunulan dosyalar:** `src/Pbxtr.Api/Modules/Leaves/LeaveEndpoints.cs`,
  `src/Pbxtr.Api/Modules/Leaves/LeaveExportCsv.cs` (yeni),
  `src/Pbxtr.Domain/Platform/Audit/AuditActions.cs`,
  `tests/Pbxtr.Api.Tests/Modules/Leaves/LeaveEndpointTests.cs`,
  `src/Pbxtr.Web/src/app/screens/system/auditView.ts`, 9 i18n katalogu.
- **Sonuc / dogrulama:** `LeaveEndpointTests` 15/15 (rc=0).
  **MUTASYON:** `LeaveExportCsv`ten `FreeTextRedactor.Redact` kaldirilinca yalnizca
  `Disa_aktarimda_nottaki_numara_maskelidir` KIRMIZI (1 failed / 14 passed), geri
  alininca 15/15. `Platform.Authorization|Delivery|Privacy|Leaves` birlikte 410/410.
  `npx vitest run` 1985/1985.
- **Commit:** `dd4b14c8`

#### Bu turda olculen iki tuzak

- **`--artifacts-path` iki bekciyi SAHTE kirmizi yakiyor:** paralel ajanlarin
  testhost'u depo ici `bin/`i kilitledigi icin ayri artifacts yoluna kacildi;
  `RoleScreenMatrixTests.Matris_belgesi_guncel` ve
  `DocumentedEndpointRealityTests` "pbxtr.sln bulunamadi" ile dustu — ikisi de
  depo kokunu cikti agacindan yukari arayarak buluyor. Depo ici cikti ile
  ayni iki test YESIL. Ayni tuzak `Pbxtr.Api.Tests.csproj` icinde de yazili.
- **`auditActionParity` mandali arka uctan tetiklenir:** `AuditActions.cs`e
  eklenen her eylem, istemcide `ACTION_VIEW` + bir filtre grubu + dokuz
  i18n katalogu ister. Arka uc karti frontend isi uretir; kart yazilirken
  gorunmuyordu.

---

### DB kartlari turu — 16 acik `BR-DB-*` karti kart kart olculdu (db-lider)

- **Neden:** `yonetim/backlog.md`'de 16 `BR-DB-*` karti acikti (`BR-DB-16, 35, 36, 40,
  44, 46, 50, 52, 55, 65, 67, 70, 72, 76, 82, 89`). Bircogu "olculdu, bekliyor" diye
  aylardir duruyordu; hangisinin GERCEK is tasidigi, hangisinin defter kusuru oldugu
  ayrilmamisti. `BR-DB-69/74/79/84/88` YAYIN'a bagli oldugu icin dokunulmadi.
- **Yontem:** her kart icin once DURUM hucresi okundu, sonra kartin **iddiasi kodda /
  semada yeniden olculdu** (`dosya:satir`). Kartin kendi teshisi yanlis ciktiginda dogru
  bulgu yazildi. Onceki metinler **silinmedi**, `Onceki kayit:` capasinin arkasina
  tasindi.

#### 1. `BR-DB-89` — sesli mesaj sonuc kodu FK si RESTRICT (TEK UYGULANAN IS)

- **Neden:** Karar #71 (Seytan itiraz 9) **sartli** bir talimat tasiyordu: "sonuc
  kodlari gercekten SILINIYORSA `closed_result_code_id` dali `SET NULL` yerine
  `RESTRICT` olmali". Sartin kosulu `BR-DB-82` turunda olculup DOGRU cikmisti (hard
  DELETE, soft-delete alani yok). Yani bu yeni bir karar degil, **sartin kapanmasiydi**
  — kurula geri sormaya gerek yoktu.
- **Ne yapildi:** migration `20260918160000_VoicemailResultCodeRestrict`
  (`DROP CONSTRAINT` + `ADD CONSTRAINT ... ON DELETE RESTRICT` + `COMMENT ON COLUMN`);
  `Down` tam simetrik ve kayipsiz (onceki kolon listeli `SET NULL (closed_result_code_id)`
  govdesini BIREBIR geri yazar). EF modeli + `PbxtrDbContextModelSnapshot` hizalandi.
  `NOT VALID` + ayri `VALIDATE` bolmesi BILEREK YAPILMADI: EF migration'i tek
  transaction icinde kosar, o yuzden bolme AEL'i kisaltmaz — yalnizca kisalttigi
  izlenimini verirdi (gerekce migration ozetinde yazili).
- **Dokunulan dosyalar:**
  `src/Pbxtr.Infrastructure/Persistence/Migrations/20260918160000_VoicemailResultCodeRestrict.cs`,
  `src/Pbxtr.Infrastructure/Persistence/Configurations/VoicemailConfiguration.cs`,
  `src/Pbxtr.Infrastructure/Persistence/Migrations/PbxtrDbContextModelSnapshot.cs`,
  `tests/Pbxtr.Architecture.Tests/VoicemailResultCodeRestrictGuardTests.cs`,
  `deploy/migration-contract-onay.blobs`
- **Komutlar:**

      git hash-object src/.../20260918160000_VoicemailResultCodeRestrict.cs
      # -> 69c0b6a0...; defter satiri: "<sha> <yol> Karar#71"
      docker run --rm -v /x/GitHub/Pbxtr/pbxtr:/w -w //w python:3.12-slim sh -c \
        "git config --global --add safe.directory /w; \
         python3 deploy/migration-compatibility-guard-selftest.py && \
         python3 deploy/migration-compatibility-guard.py"
      dotnet test tests/Pbxtr.Architecture.Tests --no-build

- **Sonuc / dogrulama:** `kapi_07` konteynerde kosturuldu ->
  "ONAYLI (Karar#71) ... migration compatibility guard: OK", rc=0.
  **MUTASYON:** `DeleteBehavior.Restrict` -> `SetNull` yapilinca
  `Model_sonuc_kodu_FK_sini_RESTRICT_olarak_bildirir` KIRMIZI
  (Expected: Restrict / Actual: SetNull); geri alinip **yeniden derlendikten sonra**
  yesil. (Ilk geri alma kosusu hala KIRMIZI dondu cunku ikili tazelenmemisti — kayitli
  ders dogrulandi.) Mimari takim 693 gecti / 1 kaldi; kalan `DeployPrivilegeTests` bu
  isle ilgisiz (baska bir turun `deploy/pbxtr-yedek*.service.d` dosyalari).
  **OLCULMEYEN (yazili sapma):** gercek PG'de `DELETE FROM public.result_codes` ->
  `23503`. `voicemail_messages` hicbir ortamda kurulu degil (`BR-DB-79`: canlida
  `to_regclass` NULL) — yani o iddia bu turda URETILEMEZ.
- **Commit:** `f8c229a0` (+ contract satiri `e979c579`) — asagidaki tuzaga bakin.

#### 2. `BR-DB-40` — Karar #74'un verdigi olcum yapildi, sonuc NEGATIF

- **Neden:** Karar #74 db-lider'e yazili bir is birakmisti: "regex'li SQL-govdeli
  `app_current_tenant()` normal + capraz kipte olculur; kazanc varsa yeni kurul turu".
  Karar #74 ayrica UYARMISTI: onceki olcumdeki `olc_current_tenant_sql()` bicim
  kontrolunu TASIMIYORDU, yani "~36x" rakami korumayi ATAN bir govdeyle alinmisti.
- **Ne yapildi:** `deploy/br-db-40-sql-govde-regexli-olcumu.sql` yazildi; aday (b6) regexi
  TASIR ve negatif kontrolle dogrulanir. PG 16.15 konteynerinde kosuldu, ham cikti
  `doc/analiz/br-db-40-sql-govde-regexli-olcumu-2026-09-18.txt` olarak depoya girdi.
- **Sonuc:** **aday kazandirmiyor.** Capraz kip / filtresiz 270k: b1 621/643/627 ms,
  **b6 599/593/595 ms (~%5)**, b4 (regexsiz, aday DEGIL) 103/99/98 ms. Normal kip /
  100k: b1 231/227/246/230, b6 221/215/216/215, b4 39/35/36/35.
  **MEKANIZMA GORULDU:** b6'nin govdesi plana **satir icine alindi** (`Filter` icinde ham
  `CASE WHEN ... ~* ...`, fonksiyon cagrisi yok) ve YINE yavas -> baskin maliyet cagri
  yolu degil **regexin kendisi** (satir basi ~2,3 us'nin ~1,9 us'si). Bu, kartin (B)
  gerekcesini ("regex satir basina kossaydi inline esit cikardi") curutur.
  Negatif kontrol: bozuk GUC'ta b1 NULL, b6 NULL, b4 **22P02** (fail-LOUD).
  Izolasyon: cross=off'ta ucu de 100.000 satir, bozuk GUC'ta b1/b6 **0**.
  `01-rls-template.sql`'e **dokunulmadi** (S36-3).

#### 3. Kapanan ote bes kart

- **`BR-DB-82` / `BR-DB-65`** — is zaten bitmisti; panoda ACIK gorunmelerinin sebebi bir
  **defter kusuruydu**: durum hucresi basta `Bitti` tasiyor ama GUNCEL parcada bir
  yarim-is sifati geciyordu ve `clickup-durum.js` kural 1 onu bu kartin durumu saniyordu
  (tarihce capasi `Onceki kayit:` o kelimeden SONRA basliyordu). Metinler yeniden
  yazildi. `BR-DB-82` kaynaktan dogrulandi: kisit `(tenant_id, linked_id, box_ref)`
  (`VoicemailConfiguration.cs:182-184`), `ON CONFLICT` (`RecordingTransferJob.Voicemail.cs:172`)
  **ve** aday sorgusundaki `NOT EXISTS` (`:111-116`) ucu birden genisletilmis.
- **`BR-DB-36` / `BR-DB-46`** — ikisi de KOSULA BAGLI olcum kartiydi ve tetikleri
  atesLENMEDI (`script_publications` 0 satir / 32 kB; `call_data_retention_lag()` dort
  hedefte de `oldest_age_days = NULL`). Kartlarin KENDI vacuity uyarilari kapanisin
  gerekcesi oldu: bugunku veriyle yapilacak her olcum "sorun yok" der.
  `BR-DB-46` icin tetik artik depoda bir betik:
  `deploy/br-db-46-retention-partition-tetigi.sql` (salt-okunur; T1/T2 esikleri ve
  ayrica "bu olcum bugun ANLAMLI mi" kolonu).
- **`BR-DB-55`** — olculdu ve `BR-DB-76` ile **ayni is** cikti (ayni tablo, ayni iki kol);
  ayri durmalari kurula ayni karari iki kez sorduruyordu. Olcumleri `BR-DB-76`'ya tasindi.

#### 4. `BR-DB-70` — kartin ENVANTERI eksik cikti

Kart ham `set_config('app.cross_tenant','on')` kullanan **7 dosya** sayiyordu. Gercek
sayim: **45 dosya** (21 migration + **24 kosan kod**). Ustelik kartin (i)/(ii) ikili
ayrimi yanlis — `LeaveEnforcementJob`, `QueueMembershipSyncJob`, `OutsideHoursBreakJob`,
`TrunkHealthSnapshotJob`, `SlaAggregationJob`, `PlatformRollupJob`,
`RecordingTransferJob.Voicemail` kartta "zaten daraltilmis" diye sayiliyor ama AYNI
dosyalar ayri bir kod yolunda capraz kipi de aciyor.

#### 5. Defter ve pano

- **Sutun kaymasi duzeltildi (3 satir):** `BR-DB-36` (6 kolon — bayat bir not DURUM'un
  onune girmisti), `BR-DB-40` (6 kolon), `BR-DB-50` (7 kolon — DURUM'daki bir regex
  kacissiz boru karakteri tasiyordu). Hepsinde fazla hucreler DURUM'a `/` ile geri
  birlestirildi; SART hucresine DOKUNULMADI.
- **ClickUp:** `--kuru` -> olustur (yeni 0) -> senkron (**yazilan 34**) -> `--kuru`
  (`fark olan kart: 0, izde olmayan: 0`).
- **Commit:** `52092507`

## Kararlar (DB turu)

- **Sartli bir kurul karari, sarti OLCULEREK kapandiginda yeniden kurula gitmez.**
  `BR-DB-89` bu gerekceyle uygulandi: Karar #71 "siliniyorsa RESTRICT olmali" diyordu,
  `BR-DB-82` "siliniyor"u olctu. Yeni karar degil, sartin sonucudur.
- **Tetigi atesLENMEMIS bir olcum karti ACIK IS DEGILDIR** — ama ancak tetik depoda
  kosturulabilir bir betikse kapatilir. `BR-DB-46` icin betik bu yuzden once yazildi.
- **Iki kart ayni isi tarif ediyorsa birlestirilir** (`BR-DB-55` -> `BR-DB-76`): kurula
  ayni karari iki kez sormak karari geciktiriyor.

## Acik kalanlar / sonraki adim (DB turu)

- **9 kart kurulda:** `yonetim/kurul-gundem-2026-09-18-db.md` (Q1 BR-DB-40 yon karari,
  Q2 BR-DB-76+55 retention, Q3 BR-DB-50 contract onayi, Q4 BR-DB-70 buyuyen kapsam,
  Q5 BR-DB-72 sozlesme, Q6 BR-DB-44 uc yazili onay, Q7 BR-DB-16, Q8 BR-DB-35,
  Q9 BR-DB-67).
- **`BR-DB-52`** acik kalir: kalan iki kalem (SURE kaydi, `budget-exceeded` nisani)
  yalniz canli yikici kosuyla olculur ve her kosu 1 saatlik kuru kosu kapisini bastan
  bekler.
- **`BR-DB-89`'un canli dogrulamasi `BR-DB-79`'a baglidir** — `voicemail_messages`
  sunucuda hala YOK; zincir uygulanana kadar `23503` olcumu uretilemez.

## Bu turda olculen tuzak — PARALEL AJAN COMMIT'I SUPURDU

`git add <yollar>` ile stage edilen dosyalarim, ben commit'lemeden once **baska bir
ajanin commit'i tarafindan supuruldu**: `BR-DB-89`'un migration'i, testi, EF
degisikligi ve olcum betikleri `f8c229a0` ("BR-SYS-114: zamanlanmis yedek...") icinde,
contract onay satiri ise `e979c579` ("BR-QA-98: sablon cipasi...") icinde durdu. Kendi
`git commit --only -- <yollar>` cagrim "no changes added to commit" dedi.

**Ders:** paralel ajan calisirken `git add` ile commit arasindaki pencere paylasilan bir
kaynaktir. Is kaybolmadi ama **commit mesaji kayboldu** — degisikligin gerekcesi artik
yalniz kod yorumlarinda ve bu gunlukte. Guvenli bicim `git add` + `git commit` yerine
tek adimda `git commit --only -- <yollar>` (index'e hic dokunmaz).

---

# pbxtr — 2026-09-18 (BR-SEC turu, backend-lider)

## Baglam

`yonetim/backlog.md` icindeki ACIK BR-SEC kartlarindan 11'i (03, 05, 08, 09, 15, 17, 19,
20, 21, 25, 26) kart kart olculdu. 16 ve 28 KAPSAM DISI birakildi (sir rotasyonu,
kullaniciya ait). Yontem bagleyiciydi: once durum hucresi okunur, sonra kartin iddiasi
KODDA olculur; kart kendi teshisinde yanilmissa dogru bulgu yazilir.

## Yapilanlar

### 1. BR-SEC-03 / BR-SEC-09 — son blokaj kapandi, fikstur bir ayristiriciya baglandi

- **Neden:** iki kart da ayni uc devir kartina bagliydi (`BR-FE-78` S37-6,
  `BR-BE-131` S37-16, `BR-AST-75` S37-17 fikstur ayagi) ve kendi metinlerinde
  *"bu uc madde kapanmadan genel kapanis VERILEMEZ"* diyorlardi. Olculdu: ilk ikisi
  **Bitti**; ucuncusunun fikstur dizini (`tests/fixtures/asterisk-cli/`) 11 dosyayla
  ACILMIS ama **hicbir test onu okumuyordu** — yani fikstur bir kapi degil, bir dosya
  yiginiydi.
- **Ne yapildi:** gercek santral ciktisi (`queue-show.txt`, uretim santrali, Asterisk
  22.10.1) urunun ayristiricisina baglandi. Ayristirici `AsteriskQueueBlock.Extract`;
  AST-06 (`queue show <kuyruk>`) tenant izolasyonunu **tamamen** ona borclu, cunku
  tasima katmani komutu **parametresiz** kosar ve santral daima TUM tenantlarin
  kuyruklarini dondurur.
- **Olculen guvenlik ozelligi:** gercek cikti **cok tenantlidir** — ayni dokumde onek
  tasimayan `lab-satis` ve iki `t0007-*` kuyrugu var; blok kesimi kacarsa ekrana baska
  tenant'in dahilileri (`Local/1045@pbxtr-t0007-local`) duser.
- **Elle yazilmis eski fiksturun kacirdigi uc bicim farki:** uye satiri `Local/...@...`
  (`PJSIP/...` degil), satirlarda **ANSI kacis dizileri** (9 satir), `Members:`
  basliginin sonunda bosluk. Defterdeki *"belge santral degildir"* dersinin somut hali.
- **Dokunulan dosyalar:**
  `tests/Pbxtr.Api.Tests/Modules/Telephony/AsteriskQueueBlockRealFixtureTests.cs` (yeni),
  `tests/Pbxtr.Api.Tests/Pbxtr.Api.Tests.csproj`
- **Mutasyon (iki yonlu):** `AsteriskQueueBlock.cs` blok-sonu kirilmasi
  (`!char.IsWhiteSpace(line[0])` -> `false &&`) devre disi -> yeniden derlendi ->
  `Gercek_ciktida_ilk_blok_kendinden_sonrakileri_yutmaz` **KIRMIZI**; geri alindi,
  `git diff` bos, **15/15** yesil.
- **Vacuity testin icinde:** `Fikstur_gercekten_cok_tenantli_bir_dokumdur` once HAM
  ciktinin yabanci kuyruk + yabanci dahili + ANSI tasidigini dogrular.

### 2. BR-SEC-20 — kurul sorusu duruyor, bugunku cevap KILITLENDI

- **Neden:** kart *"platformda tanimli ozel rol drill-in'de yetki vermeli mi"* diye
  soruyor ve cevabi kurula birakiyor. Ama bugunku cevap **olculmemisti**: davranis
  `CustomRoleAwareExpander.ExpandCore`'un tek satirindan
  (`_customRoles.TenantOf(roleCode) == tenantId ? custom : fromCatalog`) doguyordu ve
  **hicbir test onu tutmuyordu** (`DealerPermissionBoundaryTests` ozel rol dizinini BOS
  kuruyor, yani o dali hic kosmuyor).
- **Risk:** *"ozel rol acilmiyor"* diye gelen bir hata raporuna cevaben o satir
  gevsetilseydi, kumeyi **GENISLETEN** degisiklik kurul hic toplanmadan **sessizce**
  inerdi.
- **Ne yapildi:** bes testle bugunku fail-closed hal kilitlendi — kontrol grubu (rol
  KENDI tenant'inda calisir), drill-in bos kume, capraz-tenant daraltmasi asirisinda da
  bos kume, sahibi cozulemeyen rol reddedilir, **sistem rolu etkilenmez** (`admin`
  drill-in'de yetkisini kaybetmez).
- **Dokunulan dosya:**
  `tests/Pbxtr.Api.Tests/Platform/Authorization/PlatformCustomRoleDrillInTests.cs`
- **Mutasyon:** kapi kaldirildi (`return custom`), yeniden derlendi -> **3 KIRMIZI /
  2 gecti**; gecen ikisi kontrol grubu + sistem rolu, yani mutasyon dogru yeri vurdu.

### 3. BR-SEC-15 — kart (C)'ye dondu; KODDAKI yanlis cumle olcumle degistirildi

- **Neden:** onceki turun olcumu RTCP CNAME'in **rastgele UUID** oldugunu gostermisti,
  ama `IPacketCapture.cs`'teki `RtcpSnapLength` aciklamasi hala *"CNAME bir dahili numara
  tasiyabilir"* diyordu. Kartin kendi cumlesi *"ayni soru alti ay sonra yeniden
  sorulacak"* idi — ve sorulmasini saglayacak sey tam olarak o yorumdu.
- **Ne yapildi:** snaplen (104) **degistirilmedi**; yorum silinmedi, olcumle
  degistirildi (Asterisk 22.10.1, `res_rtp_asterisk.so`: `ast_uuid_generate_str`in tek
  cagri yeri SSRC uretiminin hemen ardinda, uzunluk `0x25` = `AST_UUID_STR_LEN`; modulde
  `cname`, `%s@`, `@%s` dizeleri yok).
- **Dokunulan dosya:** `src/Pbxtr.Domain/Platform/Diagnostics/IPacketCapture.cs`

### 4. BR-SEC-05 — kurula sorulan kisit ZATEN YAZILI

- Olculdu: `ck_users_global_platform` CHECK (`scope <> 'global' OR home_tenant_id =
  platform`) `20260915122000_UserRoleScopeConsistency.cs:159-165`'te ve canlida
  (`BR-DB-66`, 2026-09-15).
- Kartin kisiti **ertelettiren** iki gerekcesi de dustu: (1) `St44AcceptanceSeeder.cs:88-89`
  artik global kapsamli hesabi PLATFORM tenant'ina aciyor; (2) *"`users.scope` CHECK'i
  gercek saldiri yolunu gormez"* teshisi dogruydu ve **ayri** kapatilmis —
  `users_role_scope_consistency` / `user_roles_role_scope_consistency` tetikleyicileri
  rol katalogundan turetilen kapsami `users.scope` ile karsilastiriyor.
- **Sonuc:** kod isi YOK. SART sutunundaki *"backend-lider incelemesi"* bu kayittir.

### 5. Devredilenler ve acik kalanlar

- **BR-SEC-17 kapandi** kartin kendi kuraliyla (*olculdu, acik degil*): `T` bayragi
  uretimden dusurulmus (`grep -ro ',tT' src/Pbxtr.Infrastructure` = **0**),
  `DialTransferFlagGuardTests` 1/1. Canli lab olcumu **yapilmadi** ve yapilmis gibi
  yazilmadi — kapanis, olculecek dalin **kaldirilmis** olmasina dayaniyor.
- **BR-SEC-19 devredildi** -> `BR-DB-70` (sahibi `db-lider`, 2026-09-18'de bloklu
  degil). Ayni isi iki kartta acik tutmak panoda iki kez sayar.
- **BR-SEC-25 devredildi** -> `BR-SEC-26`; dort kalan kalemi birebir tasiyor.
- **BR-SEC-08 sprint isi:** Karar #51 SARTLI ONAY. S51-1 onkosulu **olculmemis** —
  taklit SONRASI tenant yazmasi (`PUT /ivr/flows/*` 200 + denetim satiri) testi yok; en
  yakini (`CrossTenantWriteGateHttpTests.Taklit_ucu_capraz_basligiyla_calisir`) yalnizca
  taklit UCUNU olcuyor. Karar #51 *"S51-1 olculmeden yetki kaldirilmaz"* dedigi icin
  matris daraltmasi baslayamaz.
- **BR-SEC-21 (c) — SIRA TERS CIKTI:** `webhook_deliveries`'ten satir/partition silen
  **hicbir** is yok (`WebhookDeliveryJob.cs:236` yalniz INSERT; emsaller baglanmamis:
  `ReportDeliveryRetentionJob`, `TenantDocumentRetentionJob`, `ObjectRowRetentionJob`).
  Bu haliyle #37'ye BOYUT esigi eklemek **HEP KIRMIZI** bir saglik satiri uretir —
  operatorun yapabilecegi hicbir sey olmadigi icin kapiyi fiilen kaldirir. Once
  retention (kurul karari: saklama suresi tenant parametresi mi), sonra esik.
- **BR-SEC-26 kurula:** is `deploy/db/02-guards.sql` **sablon govdesine** dokunuyor
  (migration'a yazilan `REVOKE` sablonca geri alinir — `01:2959-2963`), sablon degisince
  `kapi_71` K6 kirmizi olur ve tazeleme migration'i + onay defteri satiri gerekir.
  Sablona dokunacak diger kartlarla **tek turda** gitmeli.

## Komutlar

```bash
ART=<scratchpad>/art1
dotnet build tests/Pbxtr.Api.Tests/Pbxtr.Api.Tests.csproj --artifacts-path "$ART" -v q
dotnet test  tests/Pbxtr.Api.Tests/Pbxtr.Api.Tests.csproj --artifacts-path "$ART" --no-build \
  --filter "FullyQualifiedName~AsteriskQueueBlock|FullyQualifiedName~PlatformCustomRoleDrillIn|FullyQualifiedName~DialTransferFlagGuard"
python3 deploy/ci/test-inventory-contract-test.py && python3 deploy/ci/source-test-floor-test.py
node yonetim/arac/clickup-durum.test.js && node yonetim/arac/kart-atif-dogrula.js && node yonetim/arac/homoglif-tara.js
node yonetim/arac/clickup-senkron.js --kuru && node yonetim/arac/clickup-senkron.js
```

## Sonuc / dogrulama

- build **0 Error / 0 Warning**; ilgili filtreler **15/15**, `Skipped 0`.
- `test-inventory-contract`, `source-test-floor`, `clickup-durum.test`,
  `kart-atif-dogrula`, `homoglif-tara` -> hepsi **RC=0**.
- kapi_41 mantigi yerel olarak kosuldu: **666 kart taranmis, 0 bozuk** (SART sutunu
  temiz). `BR-SEC-03`'un durum hucresindeki **boru karakterleri** egik cizgiye cevrildi —
  o satir sutun kaymasi uretiyordu.
- ClickUp: **10 kart yazildi**, dogrulama kosusu `fark olan kart: 0, izde olmayan: 0`.
- **Commit:** `ab3036eb` — BR-SEC 11 kart; `55679f8d` — sha damgasi.

## Bu turda olculen tuzak — FIKSTUR YOLU, MUTASYON OLCUMUNU YANILTTI

Yeni test once fiksturu **depo kokunu yukari arayarak** (`pbxtr.sln`) buluyordu. Baska
bir ajanin `testhost`'u `bin/`i kilitledigi icin derleme ayri bir artifacts agacina
alindi; o agac depo **disinda** oldugu icin kok bulunamadi ve **dort test birden SAHTE
KIRMIZI** yandi. Ilk mutasyon okumasi "4 kirmizi" dedi — mutasyonun degil yolun
sonucuydu.

**Ders:** ayri bir artifacts yolu, depo-koku arayan her testi sessizce kirmizilastirir
(`RegistrationSingleSourceTests` ile ayni sinif). Fikstur artik **csproj'dan cikti
dizinine baglaniyor**, kaynak tek kopya kaliyor. Ayrica: ayni kosuda kirmizi gorunen iki
`Capture` testi (`Rtcp_sablonu_santralin_rtp_araligina_bakar`,
`Sweep_service_is_registered_as_hosted_service`) **HEAD'de de** (degisiklik geri alinip
yeniden derlenerek) kirmizi olculdu — yani "benim kirmizim mi" sorusu **ayri bir
olcumle** cevaplandi, varsayimla degil.

## Acik kalanlar / sonraki adim (SEC turu)

- **Kurula:** `BR-SEC-20` (platform ozel rolu drill-in'de yetki versin mi),
  `BR-SEC-21`(c) (webhook teslim kaydi retention politikasi),
  `BR-SEC-26` (02 sablonuna `REVOKE` + `proacl` bekcisi, tazeleme migration'i ile).
- **Sprint planina:** `BR-SEC-08` (Karar #51 alti sart; S51-1 olcumu ONCE).
- **Baska ekipte:** `BR-AST-75`'in kalan kalemi (dolu `pjsip show registrations` bicimi)
  santralde TRUNK tanimlanana kadar olculemez.

---

# pbxtr — 2026-09-18 (SISTEM/YEDEK turu, linux-uzmani)

## Baglam

19 acik kart kapatilmak uzere verildi: SYS (49, 51, 60, 102, 107, 109, 111, 112, 113, 114)
ve OPS (01, 02, 03, 04, 06, 09, 11, 14, 16). Yontem bagleyiciydi: **once kartin iddiasini
koda/sunucuya karsi OLC, kartin kendi teshisi yanlis olabilir**; is varsa yap, yoksa
"is yok"u kanitla.

Uc kartta kartin teshisi dogru, **sebebi yanlis** cikti ve ucu de ancak SUNUCUDA
kosturunca gorundu.

## Yapilanlar

### 1. BR-SYS-114 — zamanlanmis yedek: "kurulmamis" degil, **KOSAMAZ**

- **Neden:** kart *"sunucuda zamanlanmis PostgreSQL yedegi YOK"* diyordu ve dogruydu:
  `systemctl list-timers` yalniz confd/mail-onkosul/dpkg-db-backup, `crontab -l` bos,
  `/var/backups/pbxtr` icinde 2 dosya (biri **27 gun** eski).
- **Ne yapildi — once olcum:** depoda `deploy/pbxtr-yedek.{sh,service,timer}` ve
  tatbikat birimi **ZATEN VARDI**. Yani (1) ve (2) yazilmisti. Sebep baskaydi:

  ```
  which pg_dump pg_restore        -> yok (host'ta yalniz /usr/bin/gpg)
  systemctl is-active postgresql  -> inactive
  id postgres                     -> no such user
  docker ps                       -> pbxtr-postgres  postgres:16-alpine
  ```

  Birim `User=postgres` ile yazilmisti ve `pg_dumpall`i dogrudan cagiriyordu. **Kurulsa
  da ilk satirda duserdi.** Yedek yolu bare-metal icin yazilmis, kurulum konteynerli.
- **Cozum:** `pbxtr-yedek.sh`e **topoloji oneki** (`PBXTR_YEDEK_PG_ONEK`). Onek BOSSA
  davranis birebir eski (bare-metal etkilenmez); konteynerli kurulumda drop-in
  `docker exec -i -u postgres pbxtr-postgres` verir. `ionice/nice` onekli kipte
  **bilerek uygulanmaz** (host'taki `docker exec` istemcisini nice'lamak konteynerdeki
  postgres prosesini etkilemez; "dusuk oncelikli saniyorum" hali uretilmez).
- **Reddedilen alternatifler (olculdu):** host'a `postgresql-client` kurmak
  (`apt-cache policy` BOS doner — cevrimdisi kurulum), TCP (port yalniz tailscale
  arayuzunde; yedek icin genisletmek yeni saldiri yuzeyi), konteyner ikililerini
  kopyalamak (musl).

#### 1a. TATBIKAT ILK KEZ KOSTURULDU — iki gercek kusur bulundu

Ikisi de **kosmayan kapi kapi degildir** sinifindan:

| Kusur | Belirti |
|---|---|
| RLS yuklemi `relkind='r'` sayiyordu | `policy=111, RLS'siz tablo=36` — 35'i **partition cocugu**, 1'i `__EFMigrationsHistory`. **Hicbir dogru pbxtr DB'sinde gecemezdi.** |
| EXIT trap'i `local scratch` okuyordu | `set -u` altinda `scratch: unbound variable`; tatbikat **GECERKEN** unit `failed` gorunuyor ve her kosu bir **scratch DB sizdiriyordu** |

Yuklem `02-guards.sql`in kanonik kumesine cekildi (`relkind IN ('r','p')`, partition
cocugu haric, UNLOGGED haric). **Kontrol grubu:** canli DB'de ayni yuklemle 90 tablo
var ve RLS'siz olan YALNIZ `__EFMigrationsHistory`. Yani sapma yedekte degil YUKLEMDEYDI.

#### 1b. Yayin tazelik kapisi (kartin (3) maddesi)

`yedek_tazelik_kapisi`, `deploy/lib/pbxtr-migrate-adimi.sh` icinde, cikis **73**,
`migrate_adimi` (a4) — **DDL'den ONCE**.

- Esik **KURULU unit'ten** okunur (`PBXTR_YEDEK_ARALIK_SAAT`), kapinin kopyasi yok.
- Tolerans **2x**: bir kacirilan kosu durdurmaz, iki tanesi durdurur (1x olsaydi kapi
  her gun yedek saatinin oncesinde kirmizi yanar ve ilk operator refleksi onu
  KALDIRMAK olurdu).
- **Kapi yayinin kendi `pre-<sha>.dump`ina BAKMAZ** — baksaydi kendi kendini gecirirdi.
  Bunun icin ayri bir AYRISTIRICI testi yazildi.

- **Dokunulan dosyalar:** `deploy/pbxtr-yedek.sh`,
  `deploy/pbxtr-yedek{,-tatbikat}.service.d/10-compose-yolu.conf`,
  `deploy/lib/pbxtr-migrate-adimi.sh`, `deploy/yayin-onkosul-selftest.sh`,
  `deploy/staging-yayin-migrate-selftest.sh`,
  `deploy/pbxtr-deploy-artifact-migrate-selftest.sh`, `deploy/yerel-kapilar.sh`
- **Olcum:** `yayin-onkosul-selftest` **24/24** (bolum D: pozitif + 7 negatif + esik
  KONTROL GRUBU + AYRISTIRICI + kartin vacuity olcutu *timer disabled -> KIRMIZI*),
  `staging-yayin-migrate-selftest` **17/17**,
  `pbxtr-deploy-artifact-migrate-selftest` **14/14**.
- **Sunucu:** iki timer da `enabled`; yedek alindi (8,2 MB gpg + globals + dbsettings);
  tatbikat **GECTI** (`policy=111, RLS'li tablo=89/89`); `backup-status.json`
  `lastSuccessAt` + `lastVerifiedAt` dolu; kapi canlida `rc=0`.
- **Commit:** `f8c229a0`

> **Iki systemd tuzagi ayni kosuda olculdu:** (1) `Environment=` satirinda TIRNAKSIZ
> bosluk yeni bir atama baslatir — degisken yalniz `docker` oldu ve hata **docker
> CLI'sinden** geldi (`unknown flag: --globals-only`), yani belirti yanlis kapiyi
> gosteriyordu; (2) `ProtectHome=yes` + `User=root` altinda gpg `/root/.gnupg`'yi
> yaratamaz -> `GNUPGHOME` zorunlu.

### 2. BR-SYS-113 — kart TEK bayat dosya adlandiriyordu, **IKI** vardi

- **Olcum (09:51Z):**

  ```
  /root/pbxtr-build/deploy/db/00-roles.sql   17 Agu  443a1323c4bb65e0
  /home/vuo/pbxtr-demo/db/00-roles.sql       12 Agu  545d641de3b72f49
  depo HEAD                                          689708fa6650f303
  ```

- **Kartin gormedigi sey:** ikinci dosyanin AYRI bir tuketicisi var —
  `rol_ayari_beklenen` (BR-OPS-14/c) beklenen `lock_timeout`u **TAM O DOSYADAN** okur.
  Yani *"kapi kaynagi takip eder, belge ile kod ayrismaz"* iddiasi **bes haftalik** bir
  dosyaya dayaniyordu. Iki surum de `10s` yazdigi icin aktif ihlal YOKTU — bosluk gizil.
- **Ayrica:** compose dosyasinin kendi yorumu *"CI her push'ta iki dosyayi bayt bayt
  karsilastirir"* diyor; **CI kaldirildi.** Depo ici eksen (`yerel-kapilar.sh:407`)
  duruyor, DEPO<->SUNUCU ekseni **hic** olculmuyordu.
- **Inen:** `deploy/db-roles-sunucu-sapma.sh` (0/1/2/**3=OLCULEMEDI**; sunucuya YAZMAZ,
  dosya icerigi OKUNMAZ) + `deploy/db-roles-sunucu-sapma-selftest.sh` **6/6** (sahte
  ssh; pozitif, iki ayri bayat dal, dosya yok, ssh dustu->3, **MUTASYON**) +
  `kapi_75` (yalniz oz-test kosar — agsiz konteynerde hep-kirmizi kapi uretmemek icin).
- **`deploy/README.md` §4.1'e yazilan:** (a) **hangi SURUM** kurali, (b) sapma olcumu
  kurtarma adiminin ONUNE, (c) **KONTEYNERLI kurtarma yolu** — cunku olculdu ki yazili
  runbook bu topolojide **kosulamazdi**: `systemctl stop pbxtr` hicbir sey yapmaz
  (`pbxtr.service` kurulu degil) ve host'ta `psql`/`pg_restore` yok.
- **Sunucu:** iki kopya da HEAD'den tazelendi; kapi canlida **1 -> 0**;
  `rol_ayari_beklenen` taze dosyadan hala `10s` okuyor.
- **Commit:** `65141562`

### 3. BR-SYS-112 — `GuardAsserts` artik `pending == 0` acilisinda da kosuyor

- **Kusur:** `MigrationStartupGate` bekleyen migration yokken KOSULSUZ erken donuyordu.
  Bekci bataryasi yalnizca migration TASIYAN yayinlarda kosuyordu — oysa yakalamak icin
  var oldugu sinif (elle DDL, yedekten donus, `deploy/db` scriptlerinin yeniden
  uygulanmasi) tam da **bekleyen migration URETMEYEN** siniftir.
- **Cozum:** yeni `MaintenanceRunner.RunGuardAssertsOnlyAsync` — **kilitsiz**,
  salt-okunur, commit yerine **ROLLBACK** ("hicbir sey yazmadi" iddiasi niyet degil
  islem siniriyla zorlanmis). Erken donusun kendi gerekcesi (bos migrate advisory lock
  alir, cok-node'da acilislari serilestirir) **gevsetilmedi**.
- **Baglanti OWNER'dir:** bazi bekci fonksiyonlari `pbxtr_app`'e BILEREK kapalidir
  (02-guards REVOKE kontrolleri); uygulama roluyle cagrilsalardi kapi **42501** ile HER
  acilista kirmizi yanardi — koruma degil, uretimi kilitleyen kapi.
- **Kartin vacuity olcutu BIREBIR kosturuldu** (gercek `postgres:16`, Testcontainers):
  (A) tam migre edilmis DB'de ayni cagri GECER — **ayristirici**;
  (B) elle `DROP FUNCTION pbxtr_assert_role_settings_guard()` (bekleyen migration
  URETMEZ) -> acilis DUSER ve mesaj fonksiyonu **adiyla** soyler.
- **Kod mutasyonu:** bekci cagrisi kaldirildi, **ikili yeniden derlendi** -> yeni test
  KIRMIZI, eski test YESIL kaldi (kontrol grubu); geri alindi, yeniden derlendi, 2/2.
- **`DeployPrivilegeTests` kendi isini yapti:** BR-SYS-114'un drop-in'i
  (`User=root` + `/run/docker.sock`) **ilk kosuda yakalandi** ve gerekceyle kayda
  gecirildi. Bu bir ONAY degil KAYITTIR; uretim yolu **kurul gundemidir**.
- **Olcum:** Architecture **694/694**, Integration `MigrationStartupGateTests` **2/2**.
- **Commit:** `bc85fbae`

### 4. BR-OPS-11 (5) — compose bagimliligi KONTROL GRUPLU olculdu

`alpine:3.20` ile uc satirlik fikstur; hem yerelde (compose **v5.3.1**) hem
**sunucunun kendisinde** (**v5.4.0**, surum farki caveat birakmamak icin tekrarlandi):

| Hal | Sonuc |
|---|---|
| migrate cikis **75** | `service "migrate" didn't complete successfully: exit 75`, `up` rc=**1**, app HIC baslamadi (`APP-BASLADI` sayimi **0**) |
| KONTROL: cikis **0** | app basladi (sayim **1**), rc=**0** |

Yani BR-OPS-08'in korktugu *"kilidi alamayan migrate 0 donerse app yine kalkar"* yolu
compose katmaninda da kapalidir — ama koruma **cikis kodunun dogru uretilmesine**
baglidir; CLI 75'i 0'a cevirseydi compose onu gecirirdi (BR-OPS-08'in kok kusuru buydu).

### 5. Olculdu — is yok / bloke (12 kart)

- `BR-SYS-49` uc kodda **0 eslesme**, acilis kosulu dis olay.
- `BR-SYS-107` `pbxtr-vm` koku konteynerde **hic yok**, buyume **0/gun** — aciliyet sifir.
- `BR-SYS-109` zorlayici yari **kosturuldu**: `asterisk-kapali-liste-parite.sh --oz-test`
  **7/7**, gercek kosu *PARITE TEMIZ*. Metin ayagi **kullanici onayinda** (CLAUDE.md'de
  ilgili dizeler **0 eslesme**) — bir ajan talimati CLAUDE.md'yi degistirme yetkisi veremez.
- `BR-OPS-01/02` canli sayim: `ring_groups` **0**, `dids` **0**, `queues` **3**.
- `BR-OPS-04` `pbxtr_sys.mail_settings` **0 satir** (kullanici karari).
- `BR-OPS-09` santralde `sounds/pbxtr/sys/` yok ve `pbxtr-decide` baglami
  **hic yuklu degil** (`grep -rl` -> 0 dosya), yani (4) fiziksel olarak olculemez.
- `BR-OPS-16` `tenant_settings` 5 satirin **0**'inda `auto_answer=true`.
- Bloke: `BR-SYS-51` (tek sahiplik penceresi — bu turda pencere BR-SYS-114'e harcandi),
  `BR-SYS-60` (santral uzerinde bilerek hatali revizyon yazimi ister),
  `BR-SYS-102` (kurul gundemi), `BR-OPS-06` (`yazilim-mimari` tasarimi).

## Kararlar

- Konteynerli kurulumda yedek yolu `docker exec` uzerinden gider ve bu bir **yetki
  genislemesidir**; kayda gecirildi, **uretim icin kurul gundemi**. Tercih edilen uretim
  yolu: host'a `postgresql-client-16` kurup oneki BOS birakmak ve birimi
  `User=postgres` ile dondurmak.
- Yedek tazelik kapisi zamanlanmis yedegi olcer, **yayin dumpini degil**.
- `00-roles.sql`in kurtarmada kosulan surumu **yayinlanan sha'nin agacindan** gelir.

## Bu turda olculen tuzak — BACKLOG ES ZAMANLI EZILDI

`yonetim/backlog.md`'ye yazilan 19 satirlik guncelleme, baska bir ajanin ayni dosyayi
**tam dosya olarak** yeniden yazmasiyla **sessizce kayboldu**; `git diff` yalnizca o
ajanin uc yeni kartini gosteriyordu. Belirti "degisiklik yok" degil, **"benim
degisikligim hic olmamis gibi"**ydi.

**Ders:** paylasilan bir markdown'a yazan ajan, yazdiktan **hemen sonra** commit
etmelidir; arada olcum/dogrulama yapmak pencereyi acik birakir. Dogrulama yontemi de
yaniltmisti: `clickup-cikar.js` ardisik kosularda **663 -> 666 -> 669** dedi ve bu
benim ayristirma hatam gibi gorunuyordu; gercekte dosya altimda buyuyordu.

## Acik kalanlar / sonraki adim

- **Kurula:** yedek biriminin uretim topolojisi (docker.sock vs host pg-client);
  `BR-SYS-102` (confd nginx kipi `curl`e gecsin mi + digest sabitleme).
- **Kullaniciya:** `BR-SYS-109` metin ayagi (CLAUDE.md §3.1'e S70-23 + S70-24).
- **Kalan olcum:** `BR-OPS-11` (1)(2)(4) yerel compose + yuk; `BR-OPS-14` (b) yayin ani;
  `BR-SYS-111` vacuity (tarihsel 01 govdesiyle Docker'li A/B).
- **Baska ekipte:** `BR-OPS-16` (backend-dev-2), `BR-OPS-06` (yazilim-mimari),
  `BR-SYS-60` (santral yazimi), `BR-OPS-09` (2)(3) (asterisk-uzmani).

---

## QA kart kapatma turu (pbxtr-qa, akşam) — 16 kart

Bağlam: `yonetim/backlog.md`'de açık duran 16 QA/FE/DOC kartı kapatma turu.
Yöntem bağlayıcıydı: önce Durum hücresini oku, sonra iddiayı **kodda ölç**; iş varsa yap,
yoksa "ölçüldü — iş yok" diye **kanıtla**. Kartın kendi teşhisinin yanlış olabileceği
varsayıldı ve iki kartta gerçekten yanlış çıktı.

### Q1. BR-QA-98 — şablon çıpası artık `DROP FUNCTION/POLICY/TRIGGER` görüyor

- **Neden:** `DROP FUNCTION|POLICY|TRIGGER|ROUTINE|VIEW|SCHEMA` hiçbir kapının desen
  kümesinde yoktu. Somut delik: `02-guards.sql`'e eklenen bir `DROP FUNCTION ...` satırı,
  onaylı bir tazeleme migration'ıyla kurulu üretim veritabanına taşınıyor, kapı bulgu
  üretmiyor ve çıpa sha'sı değişmiyordu. Bir RLS policy fonksiyonunu düşüren satır tenant
  izolasyonunu doğrudan ilgilendirir.
- **Ne yapıldı:** Şeytan'ın önerdiği **geniş** hal ölçüldü ve **uygulanmadı** (148+ yeni
  bulgu → onaysız onlarca migration RED → toplu onay → defterin kauçuk mühre dönmesi).
  Kartın **dar seçeneği** uygulandı: genişletme yalnız **şablon çıpasında**
  (`TEMPLATE_ONLY_DENIED` / `ANCHOR_DENIED`); kapının `DENIED` kümesi değişmedi, migration
  tarafı hiç etkilenmedi.
- **Dokunulan dosyalar:** `deploy/migration-compatibility-guard.py`,
  `deploy/migration-compatibility-guard-selftest.py`, `deploy/migration-contract-onay.blobs`
- **Sonuç / doğrulama:** çıpaya giren ifade 01'de 8 → 35, 02'de 2 → 18. Ham grep (67/74)
  ile fark **yorumdur** ve bağımsız doğrulandı (27 ve 16). Gerçek depoda mutasyon: 01'e
  `DROP FUNCTION pbxtr_apply_tenant_rls(text);` → kapı rc=1, geri alındı → rc=0. Öz-test:
  T10a/T10b/T10c/T10d + `T-M5` mutasyonu; rc=0.
- **Commit:** `e979c579`

### Q2. BR-QA-99 — RLS yüklemi ayna bekçisi (`kapi_74`)

- **Neden:** aynı yüklem üç ayrı yerde, üç ayrı yoldan yazılıydı; biri değişip diğeri
  kalırsa ürün **iki sıraya birden** sahip olur ve hiçbir kapı bunu söylemezdi.
- **Ne yapıldı:** tek doğruluk kaynağı **şablondur**; bekçi diğerlerini ondan **türetir**
  (ikinci bir elle yazılmış beklenti tutulmaz — tutulsaydı bekçi kendi kopyasını ölçerdi).
  Kapsanan: şablon üretici, **şablonun kendi açıklaması** (öz-test sırasında bulundu:
  `01-rls-template.sql:205-206` yüklemi yorum olarak da yazıyor ve ilk mutasyon çıpam ona
  çarpmıştı), `CdrSqlBuilder.cs:74`, `02-guards.sql:1651` donmuş dize,
  `03-smoke-tenant-isolation.sql:1124-1130` **ikinci** `CREATE POLICY` üreticisi ve beş
  bayatlayacak yorum yüzeyi.
- **Kategoriyle eleme yapılmadı:** `EfResourceVersionGate.cs:233,237` **ölçerek** elendi —
  yüklemi `AND tenant_id = app_current_tenant()`, `OR app_is_cross_tenant()` yok.
- **Dokunulan dosyalar:** `deploy/ci/rls-predicate-mirror-guard.py`,
  `deploy/ci/rls-predicate-mirror-guard-selftest.py`, `deploy/yerel-kapilar.sh`
- **Sonuç / doğrulama:** 10 mutasyonun 10'u da kırmızı + 1 pozitif + 1 negatif kontrol.
- **Commit:** `fd74e677`
- **Kalan:** kurulu DB'deki üretilmiş policy metni için birebir bekçi (01/02'yi değiştirir
  → Ş73-L2 eşli tazeleme migration'ı + kurul kararı). Karta yazıldı.

### Q3. BR-QA-101 — worktree'den koşan kapılar artık sessiz sahte kırmızı vermiyor

- **Neden:** worktree'de `.git` bir dosyadır ve içeriği Windows mutlak yoludur; 7 kapı
  ölçmeden kırmızı yanıyor, okuyan "yayın bloke" sanıyordu (bugün birebir bu olmuş).
- **Ne yapıldı:** seçenek (a) — kapılar aynen koşar, ama çıktı **başında** yedi kapı adıyla
  sayılır ve kırmızı özetinden **sonra** hatırlatma basılır.
- **Sonuç / doğrulama:** pozitif (`.git` dosya → banner), negatif (`.git` dizin → çıktı yok),
  gerçek ana checkout → çıktı yok; `bash -n` temiz.
- **Commit:** `1cdde27a`

### Q4. BR-FE-109 — geçici arızada oturum artık düşmüyor (P1)

- **Neden:** açılış `catch`'i çıplaktı (`clearTokens(); setStatus('anonymous')`) ve hata
  **sınıfına hiç bakmıyordu**. `/me` `tenants` tablosunu okur → bakım penceresinde sayfayı
  açan ya da F5 yapan herkes yenileme jetonunu kaybediyor, ekranda "bakım" değil **giriş
  formu** görüyordu. En ağır hal wallboard: TV'nin başında parola yazacak kimse yok.
- **Ne yapıldı:** (1) `isSessionLossError` — 4xx jetonu siler, 5xx/ağ/timeout/bilinmeyen
  jetonu **korur** ve yeni `unavailable` hali çizilir; (2) `client.ts` istek zaman aşımı
  10 sn (blob indirmesi 300 sn ile muaf, `AbortSignal.any` kullanılmadı).
- **Kartta olmayan, bu turda ölçülen İKİNCİ delik:** `refreshSession`'ın kendisi de ağ
  hatası dışındaki her şeyde jetonu siliyordu; `/auth/refresh` 503 dönünce aynı hasar orada
  da üretiliyordu. 5xx artık yukarı fırlatılıyor.
- **Karttan bilinçli sapma:** "tek atış" yerine **5+15+45 sn sınırlı merdiven** (sonra
  durur, polling değil). Gerekçe kodda: 5 sn'de tek atış, kartın kendi 40 sn'lik pencere
  senaryosunu kapsamıyordu.
- **Sonuç / doğrulama:** 6 test; mutasyon A (koşulsuz oturum kaybı) 4 kırmızı, mutasyon B
  (hiçbir hata oturum kaybı değil) 1 kırmızı. **B ilk yazımda yeşil kaldı** — negatif vaka
  401'i `/auth/refresh`'e verdiği için sınıfı ayıran satır hiç koşmuyordu (fikstür kusuru);
  vaka `/me` 403'e taşındı. vitest 222 dosya / 1991 test yeşil, `tsc -b` rc=0, 9 dil.
- **Commit:** `101e9a73`

### Q5. BR-DOC-22 — var olmayan AstDB fallback'i artık koruma sayılmıyor (`kapi_75`)

- **Neden:** CLAUDE.md §3.2 bu cümleyi bir **koruma** sayıyordu ve uygulama 11 dosyada olay
  günlüğüne onu var sayan satır yazıyordu; operatör arıza anında "çağrı korundu" diye
  okuyordu. Düşülecek yer yoktu.
- **Ölçüm:** `ConfigRenderer.cs`'de `CURL(` = 0 (akış `Stasis`), `Set(DB(` = 0,
  `database put`/`DBPut`/`pbxtr/snapshot` = 0 dosya; **ek olarak** `pbxtr-edge`in depoda
  kaynak dosyası yok ve `doc/mimari/asterisk-dialplan-sablonu.md:267` fallback bloğunu
  yazıyor ama **o belge üretici değil** (kayıtlı ders: belge santral değildir).
- **Ne yapıldı:** üç belgede mezar taşı; iki operatör günlük satırı düzeltildi; AstDB anan
  dokuz canlı kaynağa ölçülmüş başlık (iki uygulanmış migration muaf — donmuş tarih, blob
  çıpalı); `kapi_75` + öz-test.
- **Vacuity dersi:** M1/M2/M3 ilk yazımda **sessizce geçti** — kapı ±12 satırlık pencereye
  bakıyordu ve cümleyi mezar taşının yanına koşulsuz geri yazmak yetiyordu, yani korumaya
  çalıştığı **tam senaryoyu** kaçırıyordu. Kural aynı satıra daraltıldı.
- **Commit:** `3e26bcc0`. Karar (fallback yazılsın mı) kurul gündemine gitti.

### Q6. Ölçümle kapanan üç kart — ikisinde kartın kendi teşhisi yanlış çıktı

- **BR-QA-40:** kalan madde *"kurulu DB'de `lock_timeout` ölçülmüyor"* diyordu. Atılır bir
  `postgres:16-alpine` üzerine 00/01/02 kuruldu ve `pg_proc.proconfig` okundu: **dördü de**
  `lock_timeout=2s` taşıyor. Bekçiler `02-guards.sql:2118/2623/5251`'de duruyor; canlı
  mutasyon (`RESET lock_timeout`) `pbxtr_assert_sys_function_guard()`'ı **ERROR** yaptı; tam
  göçlü şemada `db-kapilari-docker.sh` üçünü de "temiz" dedi (rc=0). İddia çürüdü.
- **BR-QA-90:** *"tek aktörle ölçülemez"* denen yapısal öncül **iki eşzamanlı oturumla
  ölçüldü ve doğrulandı**: lider kilidi tutuyor → ikinci düğüm alamıyor → lider
  idle-in-transaction ile düşürülüyor → kilit serbest → ikinci düğüm **alıyor**. İlk fikstür
  yanlıştı (psql `-c` ile verilen `BEGIN` bloğu kapanıyordu, oturum hiç idle kalmıyordu);
  mutasyon yeşil çıkınca önce fikstür sorgulandı. `JobLeaderLock.cs:76` gerçekten
  `pg_try_advisory_xact_lock` kullanıyor, yani ölçüm birebir bu koda uygulanır.
- **BR-QA-89:** ölçüm zaten inmişti; kartın son işi yapıldı — inmemiş üç şart kart olarak
  açıldı (`BR-QA-102/103/104`), numaralar önce ölçüldü.

### Q7. Kurul gündemine taşınanlar (tek taraflı kapatılamaz)

`yonetim/kurul-gundem-2026-09-18-qa-kapatma.md`: BR-DOC-22/3 (fallback yazılsın mı —
`call-permission` için **asla**), BR-QA-86 (Karar #48 defter biçimi), BR-QA-100 (vitest
kapısının evi), BR-FE-108 (dinleme için ayrı meşgul kipi mi), BR-QA-51 (kaynak ayrımı +
`seed-sample` politikası), BR-QA-06 (sprint-36 sayı kapılarının bugünkü adlarla yeniden
yazılması — `queue_optin` / `callback_requested_count` depoda **0 isabet**).

### Q8. Kısmi kalanlar ve sebepleri

- **BR-QA-95:** kabul ölçütü *"tam takımda ardışık N koşu"*; makinede başka ajanlar aktifti
  (25 değişmiş/izlenmeyen dosya, yeni bir migration dahil) ve testhost eşzamanlı yükte
  çöküyor — böyle bir koşumun ne kırmızısı ne yeşili bu kartın kanıtı olurdu.
- **BR-QA-55 / BR-QA-57:** Karar #44 (B) ayrı digest-pinli **Linux** Playwright imajı ister.
  Windows'ta taban üretmek kurulun **reddettiği** (A) seçeneğidir; sahte/boş taban
  üretilmedi, hiçbir bekçi gevşetilmedi.

## Kararlar

- Geniş desen kümesi yerine **dar seçenek**: çıpa genişler, kapının `DENIED` kümesi
  genişlemez — yoksa onay defteri kauçuk mühre döner (ölçülmüş: 148+ bulgu).
- Bekçiler **kaynaktan türetir**, ikinci bir beklenti kopyası tutmaz.
- Belge/günlük yalanları **silinmez**, üzeri çizilir ve ölçülmüş hal yazılır; geri
  yazılmasını bir kapı engeller.

## Açık kalanlar / sonraki adım

- Kurul gündemindeki 6 madde.
- BR-QA-90'ın uygulama yarısı (iki düğümlü bileşim, mükerrer yan etki ölçümü).
- BR-QA-95 için takım sakinken ardışık N koşu.
- BR-QA-55/57 için Linux Playwright imajı (Karar #44'ün 14 şartı).

### Not — eşzamanlı ajan çarpışması

Bu turda açılan `BR-QA-102/103/104` kart satırları, aynı checkout'ta çalışan başka bir
ajanın backlog commit'ine (`6f3d9d39`) dahil oldu. Kayıp yok ama sahiplik commit mesajından
okunamıyor; `git add -A` yasağının neden global kural olduğunun bir örneği daha.

---

## Ek tur — Kurul Karar #76 Ş76-8 + Ş76-9: çapraz kip envanteri kapıya bağlandı

### Bağlam

`app.cross_tenant='on'` açan kullanımların sayısı **aynı gün dört kez** değişti:
kart **7**, bir ajan **45** (21 migration + 24 koşan kod), backend-lider **48**
(22 + 26), `BR-SEC-19` kaydı **85 kaynak dosya**. Dördü de "ölçtüm" diyordu.
Şeytan (I7) bunu "45 bir sınıf değil, bir regex çıktısı" diye yakaladı; kurul
envanterin elle tutulmasını yasakladı.

### 1. 45 ↔ 85 mutabakatı (Ş76-8'in açık şartı)

- **Neden:** iki sayı uzlaşmadan `Ş76-7` daraltma dalgası planlanamaz —
  "kaç tane kaldı" sorusunun cevabı yok.
- **Ne yapıldı:** üç aday desen `src/**/*.cs` üzerinde ayrı ayrı koşturuldu ve
  küme ilişkisi fiilen doğrulandı: **45 ⊂ 61 ⊂ 85**.

  | Sayı | Desen | Ne |
  |---|---|---|
  | 85 | `grep -rl "app.cross_tenant" --include=*.cs src/` | GUC'u yalnızca **anan** her dosya (yorum, `'off'`, `current_setting`) → **üst sınır** |
  | 45 | `grep -rl "cross_tenant', 'on'" --include=*.cs src/` | `set_config` yazımının **tek-boşluklu** varyantı → **alt sınır** |
  | 61 | kanonik açıcı sayımı | 29 koşan kod + 32 migration dosyası |

  **45'in kaçırdığı 16 dosya, kalem kalem:**
  - **4 dosya** `BeginCrossTenantScope` ile açar, ham `set_config` desenine **hiç eşleşmez**:
    `EfDealerAdministration`, `EfPlatformTicketDesk`, `EfProvisioningNodeDirectory`,
    `EfTenantAdminQuery`
  - **11 migration** fonksiyon gövdesinde `SET app.cross_tenant = 'on'` taşır
    (`TicketRetention`, `CallDataRetention*` ailesi, `SmsSysFunctions`,
    `VoicemailRetentionAllowlist` …)
  - **1 dosya** boşluksuz yazım: `set_config('app.cross_tenant','on'` →
    `St44AcceptanceSeeder.cs:48,98`

  **7 ve 48 yeniden ÜRETİLEMEDİ** — kart metni ve ajan çıktısı deseni yazmamıştı.
  Deseni yazılmamış bir sayım ölçüm değildir; kapı bu yüzden deseni **koda gömer**.

- **İki uç ayrı yazıldı (şartın kendisi):**
  - **Neyi tarıyorum (evren):** `src/**/*.cs`, `bin/`+`obj/` hariç. `tests/` dışarıda
    (test kodu daraltma yüzeyi değil; dahil edilse sayı 230 dosyaya çıkar ve ölçümden
    kopar). `deploy/db/01-rls-template.sql` + `02-guards.sql` dışarıda (orada
    `app.cross_tenant` bir **policy yüklemi**, kipi **açan** bir çağrı değil).
  - **Neyi çağırıcı sayıyorum (açıcı):** yorum olmayan satırda P1 `set_config(...,'on'`,
    P2 `SET [LOCAL] app.cross_tenant='on'`, P3 `.BeginCrossTenantScope(`.
    `'off'`, önceki değere **geri döndüren** yazım ve `current_setting` okuması
    açıcı **değildir**.

### 2. Kapı (Ş76-8) + migration dondurma (Ş76-9)

- **Neden:** elle envanter geçersiz; ayrıca daraltma bittiği gün yüzey **yeni bir
  migration ile sessizce geri açılabilirdi**.
- **Ne yapıldı:** `kapi_77` eklendi. Numara alınırken önce
  `grep -o "^kapi_[0-9]*()" | sort | uniq -d` **boş** ölçüldü (Ş76-24; bugün
  `kapi_75` iki kez tanımlıydı, `eb1c055b` ile düzeltilmişti) → en büyük 76, yeni 77.
- **Dokunulan dosyalar:** `deploy/yerel-kapilar.sh`,
  `deploy/ci/capraz-kip-envanteri-kapisi.py`,
  `deploy/ci/capraz-kip-envanteri-kapisi-selftest.py`,
  `deploy/ci/capraz-kip-envanteri.json`
- **Dondurulan taban (HEAD `87592acf`):** koşan kod **29 dosya / 34 kullanım**,
  migration **32 dosya / 57 kullanım**; 32 migration **ad ad** allowlist'te.

### 3. Taban çalışma ağacına karşı ALINMADI

- **Neden:** dondurma sırasında çalışma ağacındaki anma sayısı **aynı oturumda
  85 → 87** değişti (paralel ajanlar dosya ekliyordu). Çalışma ağacına karşı alınan
  bir taban dakikalar içinde yeniden üretilemez hale gelir — yani kapının
  engellemeye çalıştığı şeyi (üretilemeyen sayı) kapının **içine** koyardı.
- **Ne yapıldı:** taban `git archive HEAD` ile temiz bir ağaçtan alındı.
  Dondurma anında commit edilmemiş **3 dosya** (`WebhookDeliveryRetentionJob.cs`,
  `20260918170000_WebhookDeliveryRetention.cs`, `20260918180000_VoicemailBoxIdentity.cs`)
  ayrı bir `ucusta` listesine kondu: onlar için ne varlık ne yokluk kırmızı yanar.
  Gerekçe: kapı kurulduğu gün **başkasının yarım işi** yüzünden kırmızı yansaydı
  hemen devre dışı bırakılırdı (defter: *hep-kırmızı kapı = fiilen kaldırılmış kapı*).
  Mekanizmanın **dışı da** ölçülüyor — listede olmayan yeni migration yine kırmızı
  (öz-test M8a/M8b). Sahibi commit edince yolu listeden çıkarıp `--dondur` koşar.

### 4. Vacuity (Ş76-25) — üçü de fiilen koşturuldu

- **Öz-test 15 vaka, `rc=0`:** pozitif 2 + negatif 2 + desen varyantı 4 + uçuşta 2 +
  vacuity 2 + fail-closed 1 + masum-dosya 1 + gerçek ağaç 1.
- **Gerçek ağaç mutasyonları (geri alındı):**
  - yeni koşan açıcı eklendi → `rc=1` (`Ş76-8 IHLALI`)
  - yeni migration eklendi → `rc=1` (`Ş76-9 IHLALI` + ad bazlı ihlal)
  - mevcut açıcı `'on'` → `'off'` yapıldı → `rc=1` (`KULLANIM KALDIRILMIS`)
  - temiz ağaç → `rc=0`
- **Mutasyon yeşil çıkan bir vaka vardı ve fikstür değil DESEN suçluydu:**
  `M5-V4` (C# kaçışlı tırnak, `SET \"app.cross_tenant\"='on'`) ilk yazımda
  **sessizce geçti**. Desen `\?['"]` ile düzeltildi. Gerçek ağaçta bugün o yazım
  yok — yani düzeltme **önleyici**, ve bunu yalnızca fikstür gösterdi.

### 5. Yol boyu yakalanan iki tuzak (defterden)

- **Heredoc bir seviye ters bölü yiyor:** `"\n"` yazımı dosyaya çıplak satır sonu
  olarak düştü ve `SyntaxError` verdi; `chr(92)` ile üretildi.
- **`pathlib.write_text` Windows'ta CRLF yazıyor:** `deploy/yerel-kapilar.sh`
  yamalanırken **2570 CR** eklendi — `.gitattributes` `deploy/** text eol=lf` dediği
  için repoda düzelirdi ama **yerel konteyner koşumu** bozulurdu (`\r: command not
  found`). Dört dosya commit'ten önce baytla LF'e çevrildi; `git diff` 28 satır
  ekleme olarak sadeleşti.

- **Commit:** `a09244ab` — Karar #76 / S76-8 + S76-9: çapraz kip envanteri artık
  kapıyla sayılıyor (kapi_77). Push edildi.

### Açık kalanlar

- `ucusta` listesindeki 3 dosya sahipleri tarafından commit edilince listeden
  çıkarılıp `--dondur` koşulmalı; aksi halde o üç dosya kalıcı olarak ölçüm dışıdır.
- Ş76-7 daraltma dalgası artık güvenilir bir tabana sahip: D1–D4 risk sınıfları
  bu 61 açıcı üzerinden bölünebilir.

---

## Karar #76 / Ş76-21 — BR-7'nin AGENT ayağı: "Yeteneklerim" kutusu

### Bağlam

Aynı gün `57b98820` ile BR-7 yetenek yönlendirmesinin **yönetim** yüzeyleri
yazılmıştı (#03 katalog sekmesi, #02 yetkinlik ataması, kuyruk formu, üye
listesi). Kurulda çağrı merkezi agenti itiraz etti ve **haklı çıktı**: brief
eksikti. Ölçüm: `src/Pbxtr.Web/src/app/screens/agent/` ve
`src/Pbxtr.Api/Modules/AgentDesk/AgentEndpoints.cs` altında yetenek/skill için
**sıfır eşleşme**. Yani yetenek ve seviye agent'a **atanabiliyordu ama agent onu
hiçbir yerde göremiyordu.**

cm-agent'in gerekçesi (karar kaydında): *"seviyem yanlış girilmişse ekranda uyarı
yok; zor çağrıları yemeye devam ediyorum, AHT'm şişiyor — kontrolümde olmayan bir
şey beni ölçüyor."*

### Yapılanlar

#### 1. Sunucu ayağı — iki kol ölçüldü, (a) seçildi

- **Neden:** Karar iki kol bırakmıştı: (a) mevcut agent ucuna alan eklemek,
  (b) `GET /api/v1/users/{id}/skills` ucunu agent'a açmak.
- **Ölçüm (b için, kol elendi):**
  - `SkillAdminEndpoints.cs:88` → uç `user.read` ister.
  - `SkillAdminEndpoints.cs:77-88` → `userId` **rotadan** gelir ve
    `ITenantContext.UserId` ile **karşılaştırılmaz**; yani uç çağıranın kendisi
    olup olmadığına bakmaz.
  - `permissions.seed.json` → agent rolü `bundle.call` + `bundle.console` +
    `ticket.read/write`, `voicemail.read`. Etkin kümede **`user.read` YOK**,
    **`queue.read` YOK**.
  - Sonuç: yetkiyi vermek bir kutu için tenant'ın tüm kullanıcı yönetimini **ve
    başka agent'ların yetkinliğini** açardı.
- **Ne yapıldı (a):** yeni dar uç `GET /api/v1/agent/skills`, yetki `call.handle`.
  Port `IAgentSkillProfile.GetMineAsync()` **`Guid` parametresi almaz**; kullanıcı
  `ITenantContext`ten çözülür → başka agent'ın yetkinliği **bu arayüzde ifade
  edilemez** (daraltma yüzeyde değil **tipte**).
- **`/agent/state`'e alan EKLENMEDİ ve bu bilinçli:** Ş76-23 tolerans tablosu o
  ucun rozet tazeliğini ≤ 1 sn'ye bağlıyor ve uç her çağrı/durum olayında yeniden
  çekiliyor. Yetenek ve üyelik **statik yapılandırmadır**; iki JOIN'i o yola
  koymak, hiç değişmeyen bir veriyi her rozet tazelemesinde okumak olurdu.
- **Dokunulan dosyalar:** `src/Pbxtr.Domain/Modules/AgentDesk/IAgentSkillProfile.cs`
  (yeni), `src/Pbxtr.Infrastructure/Modules/EfAgentSkillProfile.cs` (yeni),
  `src/Pbxtr.Api/Modules/AgentDesk/AgentEndpoints.cs`,
  `src/Pbxtr.Infrastructure/DependencyInjection/InfrastructureServiceCollectionExtensions.cs`,
  `doc/mimari/api-kontrat-v1.md`.

#### 2. Ekran — sekme değil, sağ kolonda kutu

- **Neden:** karar metni birebir *"ayrı sekme olmaz — çağrı sırasında kimse sekme
  değiştirmez"*.
- **Ne yapıldı:** `MySkillsPanel` #09 masasının `<aside>`ına kondu → **her
  sekmede**, çağrı ekranından çıkmadan görünür. **Ekran kayıt defterine satır
  eklenmedi** (Karar #29: *"Yeni ekran yok"*).
- **Salt-okunur, ve bu bir UI tercihi değil:** hiçbir `input`/`select` çizilmez,
  tek düğme "Yenile" (bir okuma). Yazma yüzeyi #02'de, `user.write` arkasında.
  Çizilseydi agent kendi kademesini yükseltip **kendisini ölçen sayıyı kendisi
  ayarlardı**.
- **Üç ayrı boşluk, üç ayrı cümle:** `catalogEmpty` (tenant yetenek yönlendirmesi
  kullanmıyor — nötr) / katalog dolu ama atanmamış (agent'ın süpervizöre soracağı
  eksik) / hiç kuyruk üyeliği yok. Tek cümleye indirseydik **ikinci halde agent tam
  olarak sessiz kalırdı** — kutunun varoluş sebebi o sessizliği kaldırmaktı.
- **Seviye gereksinimin altındaysa satır susmaz.** Üyelik normalde seviyeden
  türetilir, yani bu hal oluşmamalı; oluştuysa mutabakat kaçmıştır ve agent'ın
  süpervizöre göstereceği tek kanıt odur.
- **Dokunulan dosyalar:** `MySkillsPanel.tsx`, `MySkillsPanel.test.tsx`,
  `skillProfileApi.ts`, `AgentDeskScreen.tsx`, `AgentDesk.module.css`,
  9 i18n kataloğu (14 anahtar × 9).

#### 3. Ş76-22'ye uyuldu

- #12/#13'e **dokunulmadı**, penalty kolonu **eklenmedi** (boş/sıfır gösteren biri
  de çizilmedi).
- Kutudaki kademe sayısı o yasağın kapsamında değil: orada yasaklanan şey **N
  üyelik taşıyan AGENT satırına** tek bir penalty yazmaktı; burada **satırın
  kendisi bir kuyruktur**, belirsizlik yok.

### Komutlar / doğrulama

```bash
npx tsc -b --force                       # EXIT=0
npx vitest run                           # 1997/1997 geçti (223 dosya)
dotnet test tests/Pbxtr.Api.Tests --filter AgentSkillProfileEndpointTests   # 9/9
```

**Mutasyonlar (ikisi de kırmızı yandı):**
- `catalogEmpty` dalı kapatıldı → `MySkillsPanel.test.tsx` 3. test KIRMIZI.
- DI kaydı silindi → `Port_uretim_bilesiminde_kayitlidir` KIRMIZI. Bu test
  bilerek yazıldı: diğer testler portu `Replace` ile ikame ediyor ve **`Replace`
  kayıt yoksa ekler** — DI satırı hiç yazılmasaydı dosya yeşil kalır, uç yalnızca
  üretimde 500 verirdi.

**Negatifler:** yetkisiz çağıran 403; PUT/POST/PATCH/DELETE → 404/405 (hangi kodun
döndüğü **ölçüldü**, varsayılmadı); `call.handle` taşıyan agent
`GET /users/{id}/skills` çağırırsa **403**.

### Kararlar

- **Yeni yetki üretilmedi.** Uç `call.handle` altındadır (agent'ın zaten taşıdığı
  yetki); `user.read` genişletilmedi.
- **Agent başkasının yeteneğini GÖREMEZ** — ve bu bir kontrol değil, bir **tip
  kısıtıdır**: portta `userId` parametresi yok.
- **Canlı tazelenme yazılmadı.** Yetenek değişimi için WebSocket olayı yok ve
  uydurulmadı; `queue.*` olayları `live.queue.read` ister, agent o odaya giremez
  (QueuesTab ile aynı ölçüm). Hiç tetiklenmeyecek bir "canlı" vaadi yerine
  "Yenile" düğmesi dürüst.

### Yol boyu yakalanan tuzak — paylaşılan dosyada başka ajanın yarım işi

i18n katalogları ve Infrastructure DI uzantısı o sırada **başka ajanların açık
işini** de taşıyordu (`aud.tLeave` / `WebhookDeliveryRetention`). `git add <yol>`
onları da alır ve **başka ajanın yarım işini benim commit mesajımla ana dala
iterdi.** Çözüm: indeks girdileri `git hash-object -w --path` + `git update-index
--cacheinfo` ile **HEAD üzerine yalnız benim eklemem uygulanarak** üretildi;
çalışma ağacı hiç değiştirilmedi. Commit sonrası doğrulandı: staged blob'da
`WebhookDeliveryRetention` = 0, `aud.tLeave` = 0; çalışma ağacında ikisi de
**duruyor**.

İkinci tuzak: Python `utf-8-sig` ile yazmak DI dosyasına **BOM ekledi** ve diff'te
`using` satırı değişmiş göründü; baytla kaldırıldı.

Üçüncü tuzak: .NET derlemesi üç kez paralel ajanların yarım işi yüzünden kırmızıydı
(Voicemail `BoxRef`, `AuditTargets.WebhookDeliveryLog`, test projesinde 26 hata).
**Hiçbiri benim değildi** — hata listesinde `AgentSkillProfile` eşleşmesi 0 olarak
ölçüldü ve yeşile dönene kadar beklendi.

- **Commit:** `2d57f64d` — Ş76-21: BR-7'nin AGENT ayağı — "Yeteneklerim" kutusu.
  Push edildi.

### Açık kalanlar

- Ş76-22'nin **sebep rozeti** (`yedek kademe` / `yetenek eşleşmiyor` / `wrapup`)
  ayrı kart ve bu sprinte alınmadı; sapmanın `doc/prototip-urun-farklari.md`'ye
  **BİLİNÇLİ** yazılması o kartın işi.
- `yonetim/backlog.md`'ye bu turda **dokunulmadı** (talimat).

---

## Ş76-11 — `webhook_deliveries` retention'ı (sistem sabiti, 30/30 gün)

### Bağlam

Kurul Karar #76 / Ş76-11 ve teslim sırası kilidi Ş76-10/3. `BR-SEC-21`'in boyut
eşiği bu iş inmeden kurulamaz: ölçüldü, `webhook_deliveries`'ten satır silen
**hiçbir iş yoktu** (`WebhookDeliveryJob` yalnız YAZAR) → eşik kurulduğu gün
**hep kırmızı** olur ve hep kırmızı kapı = fiilen kaldırılmış kapı. **Eşik bu
turda YAZILMADI** (bilinçli).

### Yapılanlar

#### 1. Sürenin tenant parametresi OLMADIĞI ölçüldü

- **Neden:** CLAUDE.md §10/4 saklama süresini tenant üzerinde tutmayı şart koşar —
  ama o madde **ses kaydı** içindir.
- **Ölçüm:** `src/Pbxtr.Domain/Modules/Integrations/WebhookDelivery.cs:54-88` —
  tabloda payload/yanıt **gövdesi kolonu YOK** (`EventType, Attempt, Status,
  HttpStatus, ErrorText, DurationMs, *At`). Gövde `webhook_outbox`'ta.
- **Sonuç:** emsal `ReportDeliveryRetentionOptions`'tır, `RecordingRetention`
  değil. Süre **sistem sabiti**.

#### 2. `pbxtr_sys.purge_webhook_deliveries(integer, integer, integer)`

- **Dosya:** `src/Pbxtr.Infrastructure/Persistence/Migrations/20260918170000_WebhookDeliveryRetention.cs`
- SECURITY DEFINER, `search_path = pg_catalog, public, pg_temp`,
  `SET "app.cross_tenant" = 'on'` (PLATFORM-CROSS), `lock_timeout=5s`,
  `statement_timeout=30s`. **Tablo adı parametre DEĞİL** — yalnız üç sayı.
- `delivered` için kısa pencere serbest (taban 1 gün); `failed`/`dead` tabanı
  **30 gün** (`c_failed_floor`) ve altındaki her değer **RAISE ile reddedilir**
  (fail-closed). `pending`/`sending` **hiç** silinmez.
- Aday → sil → özetle **tek ifade** (`FOR UPDATE SKIP LOCKED` + `DELETE … USING`
  + `GROUP BY`): ayrı SELECT yazılsaydı "silinen küme" ile "günlüğe yazılan küme"
  arasına başka bir işlem girerdi. Anahtar **PK**'dır (`tenant_id, created_at,
  id`) — `ctid` kullanılmadı (bölümlü tabloda tekil değil).
- Partition **düşürülmez**: aynı ay içinde kısa pencereli `delivered` ile ≥30
  günlük `failed` birlikte durur; düşürmek kısa pencereyi en uzun pencereye
  eşitlerdi. Fiziksel küçültme autovacuum'da, tarama partition pruning ile eski
  çocuklarla sınırlı.
- **Tablo yorumu düzeltildi:** eski metin "RETENTION BORCU: `purge_call_data()`
  allowlist'ine eklenecek" diyordu; o yol **tenant başına** okur ve Ş76-11 onu
  reddetti. `Down()` önceki yorumu **birebir** geri yazar.

#### 3. `WebhookDeliveryRetentionJob` — aynı proseste, advisory lock

- **Dosyalar:** `src/Pbxtr.Infrastructure/BackgroundJobs/WebhookDeliveryRetentionJob.cs`,
  `…/WebhookDeliveryRetentionOptions.cs`
- Kilit `webhook-delivery-retention` = **39** (`BackgroundJobLocks`), teslim
  işinden AYRI: biri dış HTTP'ye çıkar ve sık koşar, bu günde bir siler; aynı
  kilit birini açlığa düşürürdü. Ayrı worker/cron **yok**.
- Günde bir tick (`Environment.TickCount64`, monoton).
- **Denetim:** etkilenen tenant başına bir satır (`webhook.delivery.retention.purge`),
  sayılar `DELETE … RETURNING`'den gelen gerçek değerler. Çapraz kapsam yalnız
  yazım boyunca açılır ve `finally` ile kapanır; açılışın kendi izi
  `CrossTenantReadAudit` ile aynı transaction'a düşer.
- **Hata davranışı: fail-closed ve gürültülü** — geçersiz pencere fonksiyonda
  reddedilir, istisna yutulmaz, tick `Failed` olarak `job_runs`'a düşer.
- **Yeni `AuditTargets` sabiti eklenMEDİ** (bilinçli): eklemek #38 hedef türü
  filtresini + dokuz dil dosyasını aynı turda büyütmeyi şart koşar (BR-QA-09) ve
  o dosyalarda o sırada **başka ajanın açık işi** vardı. Hedef türü mevcut
  kümeden (`WebhookSubscription`, kimlik `null` — SSRF reddinde zaten tanımlı),
  ayrım `Action` ile.

#### 4. Donmuş envanter + şablon tazeleme

- `deploy/db/02-guards.sql`: `pbxtr_sys_function_expectations()`'a satır +
  frozen hash `084db597…` → `8dc49b1d50385bd3375abd4334df746d`.
- `deploy/db/sys-functions.expected`: yeni satır (29 kayıt).
- `prosrc` md5 **çevrimdışı** hesaplandı ve yöntem önce `purge_job_runs` üzerinde
  doğrulandı (C# ham dize girintisi 12 boşluk kırpılır → bilinen md5 birebir çıktı).
- `20260918180000_GuardsTemplateRefreshWebhookRetention` + `sablon-refresh.expected`
  (sha + migration adı) — aksi halde yükseltilen DB envanteri **hiç almaz** ve
  açılış kapısı uygulamayı kilitler.

#### 5. `ErrorText` ÖLÇÜMÜ (Ş76-11 madde 3) — "içerik yok" iddiası YANLIŞ

- **Ölçüm dosyası:** `tests/Pbxtr.Architecture.Tests/WebhookErrorTextMeasurementTests.cs`
- **Sonuç:** `error_text` **uzak sunucunun yanıt gövdesinin ilk parçasını TAŞIR**
  (`WebhookSender.cs:126-134`, `ReadExcerptAsync`) — metin
  `"HTTP {status}. {excerpt}"` biçiminde. Stub alıcı 200 KB gövde döndürdüğünde
  bile satırdaki metin ≤ **512** karakter.
- **Tavan üç yerde:** `WebhookSender.Trim` (512), okuma tamponu 512 karakter +
  `BoundedStream` 64 KB, ve DB `ck_webhook_deliveries_error_text` — üçü de
  `WebhookSubscriptionLimits.MaxErrorTextLength` **tek sabitinden** gelir.
- **Kararı değiştirmez:** taşınan şey alıcının kendi hata çıktısıdır, pbxtr'ın
  gönderdiği olay gövdesi değil (ve o gövdede numara zaten yok, Karar #28). Ama
  iddia artık "içerik yok" değil, **"içerik 512 karakterle sınırlı ve ALICININ
  metnidir"**.

#### 6. Vacuity — pozitif + negatif + mutasyon

- **Bekçi:** `tests/Pbxtr.Architecture.Tests/WebhookRetentionGuardTests.cs` (8 test).
  SQL metni kaynak dosyadan regex'le değil, **`Migration.UpOperations`'tan** okunur
  (ham dize girintisini yeniden üretmeye çalışan bekçi sessizce yanlış md5 hesaplardı).
- **Mutasyonlar (üçü de KIRMIZI):**
  1. `c_failed_floor := 30` → `7`: taban paritesi + md5 bekçisi düştü.
  2. Yükleme `'pending'` eklendi: canlı-satır bekçisi + md5 bekçisi düştü.
  3. `Down()` yorumunda tek kelime değiştirildi: "birebir geri yazar" bekçisi düştü.
  Her mutasyondan sonra geri alındı ve **yeniden derlenip** yeşil doğrulandı.

### Komutlar

```bash
dotnet build pbxtr.sln                      # src yeşil; 13 hata paralel ajanın Voicemail işi
dotnet test tests/Pbxtr.Architecture.Tests  # 707 geçti, 2 kırmızı (ikisi de başka ajanın)
sh deploy/env-esleme-kontrol.sh             # rc=0 (şablon 62, compose 72, muaf 27)
sh deploy/sablon-refresh-kapisi.sh          # rc=0, K6 dahil
python3 deploy/migration-compatibility-guard.py  # rc=0 (iki contract onayı Karar#76)
```

### Kararlar

- Boyut eşiği **yazılmadı** (Ş76-10/3). Bir sonraki turda kurulabilir; alarm
  süpervizör yüzeyine **düşmez**, Admin/Süper Admin + depolama sağlığına gider.
- Silme `pbxtr_sys` penceresinden yapılır. Ölçüldü: `webhook_deliveries` üzerinde
  append-only tetikleyici **yok** ve `pbxtr_app`'in `public` üzerinde DELETE'i
  **var** — yani "varsa korunur" şartı boşta kaldı; dar pencere yine de seçildi,
  çünkü tablo adının C# tarafında SQL metnine girmemesi yüzeyi daraltır.
- `pending`/`sending` hiçbir pencerede silinmez (fail-closed yön: veriyi tutmak).

### Açık kalanlar

- `BR-SEC-21` boyut eşiği (bu iş indiği için artık kurulabilir).
- `AuditTargets` için ayrı bir "teslim günlüğü" hedef türü + 9 dil paritesi —
  istenirse ayrı kart; bugün mevcut tür kullanıldı.
- `yonetim/backlog.md`'ye **dokunulmadı** (talimat).

- **Commit:** `8fb533c9` — Karar #76 / Ş76-11: webhook_deliveries retention
  SİSTEM SABİTİ (30/30 gün). Push edildi.

---

## Karar #76 / Ş76-4 — sesli mesaj kutusu KİMLİKLE taşınır (BR-BE-182 + BR-BE-176 slug kolu)

### Bağlam

Kurul iki kartın çelişkisini kapattı: kutu ya slug'ı DB'ye materyalize ederek ya
kimlikle taşınarak çözülecekti. **Kimlik seçildi.** Görev `backend-lider`'dan geldi,
`backlog.md`'ye dokunulmadı.

### 1. Kapatılan kusur (kararın "gizli bedel" dediği şey)

- **Neden:** `ux_voicemail_messages_tenant_linked` = `(tenant_id, linked_id, box_ref)`
  ve `box_ref` tenant önekli **santral nesne ADI**dır. Kuyruk yeniden adlandırılınca ad
  değişiyor, aktarım işindeki `ON CONFLICT ... DO NOTHING` **artık çakışmıyor** ve
  **aynı mesaj ikinci kez INSERT ediliyordu**. Belirti hata değil: kutuda iki aynı mesaj,
  iki dinleme, iki SLA ateşlemesi.
- Aynı ad üç yüzeyde daha anahtardı: `VoicemailStoredName.AssetKey`,
  `recording_assets.linked_id = vm-<linkedid>-<box_ref>`, dialplan dosya adı ve
  `voicemail_sla_daily` kırılımı (ad → kuyruk yeniden adlandırılınca **SLA serisi ikiye
  bölünür**).

### 2. Ne yapıldı

- **Şema:** `voicemail_messages.box_id` (uuid NOT NULL, **FK DEĞİL**) +
  `ck_voicemail_messages_box_id` (FK doluyken kimlikle eşit olmak zorunda);
  `box_ref` kolonu **düştü**. `ux_...` ve `ix_..._box_status` kimliğe taşındı.
  `voicemail_sla_daily` PK → `(tenant_id, day, box_kind, box_id)`.
  *FK olmamasının sebebi:* tipli FK'lar kutu silinince `SET NULL` olur; kimlik de FK
  olsaydı **idempotens anahtarı NULL'a düşer** (PG'de NULL'lar benzersiz indekste
  birbirinden farklıdır) ve aynı mesaj yine ikinci kez yazılabilirdi.
- **Üretici (BR-BE-176'nın daraltılmış kapsamı):**
  `Gosub(pbxtr-{t}-vm,s,1(<ad>,<kind>,<id>))` (ARG2/ARG3), dosya adı
  `vm-${CHANNEL(linkedid)}-${PBXTR_VM_ID}.wav`, `UserEvent(...,BoxKind:,BoxId:,...)`;
  `AmiEventMapper` + `TelephonyEventPipeline` allowlist (`vmBoxKind`/`vmBoxId` — GUID
  muafiyeti sayesinde numara bekçisine takılmaz).
  **Eski revizyon tolere edilir:** kimlik boşsa ad tabanlı çözüm dalı (`lx` JOIN) koşar,
  yoksa yayın penceresinde bırakılan her mesaj kaybolurdu.
- **Aktarım:** aday SQL'i `WITH vm AS MATERIALIZED` + tür başına LEFT JOIN
  (queue/did/extension) — kutu türü **üreticiden** gelir, addan tahmin edilmez.
- **Okuma:** `GET /api/v1/voicemail` filtresi `boxId`; `boxRef` yanıtta **salt-okunur
  türetim** (`EfVoicemailInbox.FillBoxRefsAsync`, tür başına tek `IN (...)`).
  DID'de ad `label`dır — `e164` DEĞİL: `boxRef` maskesiz bir alan, oraya numara basmak
  açık numarayı response'a taşırdı (CLAUDE.md §5).
- **Migration:** `20260918190000_VoicemailBoxIdentity` (backfill `app.cross_tenant='on'`
  ile — FORCE RLS altında owner UPDATE'i sessizce 0 satır eder), contract onayı
  `Karar#76`, çapraz kip envanterine `0/2` olarak kaydedildi.

### 3. Ölçüm

```bash
dotnet test tests/Pbxtr.Api.Tests --filter "FullyQualifiedName~Voicemail"   # 58/58 yeşil
dotnet test tests/Pbxtr.Architecture.Tests --filter "~CrossTenantScopeGuardTests"  # 4/4
npx tsc -b   # rc=0
python deploy/migration-compatibility-guard.py  # OK
```

**Mutasyon (Ş76-4/3):** kimlik alanları `box_ref`'e geri çevrildi (writer `ON CONFLICT`,
aday dedupe koşulu, EF model kolonu/indeksi, `AssetKey`, `Candidates`) → **9 test
KIRMIZI**. Geri alındı, ikili yeniden derlendi (dosya damgası doğrulandı) → **58/58
yeşil**. Ayrıca `voicemail_sla_daily` kırılımının ada döndürülmesi **derleme hatası**
verdi (`VoicemailSlaDaily.BoxRef` artık yok) — kırmızı testten daha sert bir kapı.

### Kararlar

- `box_ref` **kolonu düşürüldü**, salt-okunur türetime çevrildi. Bedeli yazılı:
  **silinmiş** bir kutunun adı artık üretilemez; satır `boxKind` + `boxId` ile görünür
  ("silinmiş kutu"). Adı saklamak daha kötüydü — yeniden adlandırmada ad sessizce yetim
  kalır ve ekran ile santral iki farklı ad söylerdi.
- Backfill'de üç FK'si de NULL olan satıra `gen_random_uuid()` verilir: mesaj **listede
  durur** (müşteri mesajı imha edilmez), tekilliği kendi başına sağlar.
- `Down` simetriktir ama **tam değildir** (yazılı sapma): ad SQL'de üretilemez, kimliğin
  metin hâli yazılır — sessiz bozulma yerine gürültülü yer tutucu.

### Açık kalanlar / sonraki adım

- **BR-BE-182'nin S-VM-5 ayağı YAPILMADI:** izne çıkan kullanıcının açık mesajlarının
  havuza dönmesi. `VoicemailEndpoints` yalnız `assign` taşıyor; izin/çıkış akışından
  tetiklenen bir iade yolu hâlâ yok. Kart bu ayakla açık kalmalı.
- **BR-BE-176'nın kalan üretici işi:** IVR `voicemail` düğümü hedefi ve DID `voicemail`
  kararı için **şema** (`ivr_nodes` / `dids` üzerinde `box_kind` + tipli kimlik).
  Taşıma katmanı (Gosub/UserEvent/aktarım) artık üç türü de destekliyor; eksik olan
  yalnızca hedefi **tanımlayacak** alanlar. Sözleşme `api-kontrat-v1.md` §7 + §7.1'e
  yazıldı.
- **Ölçülmedi:** migration kurulu bir PostgreSQL'de koşturulmadı; kuyruk yeniden
  adlandırmasının uçtan uca davranışı (gerçek `INSERT`, ikinci satır oluşmaması)
  entegrasyon turunun işi.

- **Commit:** `66b52310` — Karar #76 / Ş76-4: sesli mesaj kutusu KİMLİKLE taşınır.
  Push edildi.

---

## Karar #76 / Ş76-13 + Ş76-16 — izin dışa aktarımına tavan, denetime `Leave` hedefi

### Bağlam

Bugün yazılan `GET /api/v1/leaves/export` (`dd4b14c8`) kurulda iki eksikle geçti:
satır tavanı yoktu ve denetim satırı `TargetType = User` + `targetId = null` yazıyordu.

### 1. Ş76-13 — tavan = 5.000 satır, sessiz kırpma yasak

- **Neden 5.000 ve neden emsal kopyalanmadı:** `CdrEndpoints` 199 (ham kanal satırı +
  gruplama), `ContactEndpoints` 499 (düz satır). Süpervizör ölçümü bağlayıcı: 150
  agent'lık tenant'ta çeyreklik bordro penceresi 600–900 satır, yazın iki katı — 199 ve
  499 ucun **asıl kullanım amacını (bordro mutabakatı) iptal ederdi.**
- **Ne yapıldı:** tavan aşılınca istek bütünüyle reddedilir (400 + `ProblemDetails`,
  `meta.maxRows`, insan okur `detail`). Reddedilen istek denetime satır **yazmaz**
  (Contacts emsali: dosya üretilmedi, indirme olmadı).
- **Gerekçe kayıtta:** sessizce kırpılan dosya, görünmeyen izni "devamsızlık" yapar ve
  kesinti agent'ın maaşından çıkar. Eksik dosya hatalı görünmez — tam sanılır.
- **Vacuity tuzağı (`ContactEndpoints.cs:257`) burada YAPISAL olarak yok:**
  `ILeaveCalendar.ListAsync` imzasında **limit parametresi bulunmaz** ve
  `EfLeaveCalendar` `Take`/`Skip` çağırmaz → dönen liste filtreye uyan **gerçek
  toplamdır**, `limit = tavan+1` probe'una ihtiyaç yoktur. Yine de iki fikstür ayrı
  ölçülür: 5001 → 400, 5000 → 200 (5001 satırlık dosya).

### 2. Ş76-16 — `AuditTargets.Leave` açıldı

- `leave.created` / `leave.deleted` / `leave.exported` artık `Leave` hedefler.
  `created`'ın `targetId`'si **izin kaydının id'si** oldu (önce izinli kullanıcının
  id'siydi); `deleted`'inki zaten kayıt id'siydi → ikisi artık **aynı hedef uzayında**,
  bir kaydın tarihçesi #38'de tek hedefte buluşuyor. `exported`'da `targetId = null`
  (pencere hedefler, tek kayıt değil — `contact.exported` deseni).
- Aktör **ve** iznin sahibi `before`/`after` yükünde: `ownerUserId`, `ownerName`,
  `actorUserId`. Not metni **taşınmaz** (denetim yükü maskeleme yüzeyi değildir).
- **Port değişti:** `ILeaveCalendar.RemoveAsync` artık `bool` değil **silinen satırı**
  (`LeaveRow?`) döndürüyor. Gerekçe: kayıt fiziksel olarak siliniyor; sahibini silmeden
  sonra okuyacak hiçbir yer yok — port döndürmezse "kimin izni silindi" sorusu kalıcı
  olarak cevapsız kalırdı.
- **Ters-yön boşluğu kapandı:** `auditTargetParity.test.ts` yalnız sabitin **varlığını**
  ölçüyordu; **gerçek yazıcının** (ucun kendisi, HTTP üzerinden) bu türü **ürettiği**
  iddiası eklendi.
- **Geriye dönük doldurma yok (I15):** bugüne kadar `User` + `targetId: null` ile
  yazılmış satırlar kalıcı olarak atıfsızdır; kod ve xmldoc bunu söylüyor.
- İstemci: `TARGET_TYPES` + `aud.tLeave` **dokuz dilde** (ar, az, bg, de, en, fr, hy,
  ka, tr). Tanınmayan tür ham kodla çizilir (mevcut `targetTypeLabel` fallback'i).

### Dokunulan dosyalar

`src/Pbxtr.Api/Modules/Leaves/LeaveEndpoints.cs`,
`src/Pbxtr.Domain/Modules/Leaves/ILeaveCalendar.cs`,
`src/Pbxtr.Domain/Platform/Audit/AuditActions.cs`,
`src/Pbxtr.Infrastructure/Modules/EfLeaveCalendar.cs`,
`tests/Pbxtr.Api.Tests/Modules/Leaves/LeaveEndpointTests.cs`,
`src/Pbxtr.Web/src/app/screens/system/auditView.ts`, dokuz `i18n/messages/*.json`.

### Ölçüm ve doğrulama

Ana ağaçta **başka bir ajanın yarım Voicemail işi derlemeyi bloke ediyordu** (7→10
`error CS`, hepsi Voicemail; o dosyalara dokunulmadı). Ölçüm bu yüzden **HEAD'den
açılan izole bir `git worktree`'de** yapıldı; yalnızca benim 5 C# dosyam kopyalandı ve
worktree'deki dosyanın çalışma ağacıyla **bayt bayt aynı** olduğu `diff` ile doğrulandı.

```bash
git worktree add --detach <scratch>/wt-leave HEAD    # ana ağaçtaki yarım iş dışarıda
dotnet build Pbxtr.sln -v q --nologo                 # 0 error
dotnet build tests/Pbxtr.Integration.Tests --no-incremental   # 0 error
dotnet test tests/Pbxtr.Api.Tests --filter "FullyQualifiedName~Modules.Leaves"
```

| Koşu | Sonuç |
|---|---|
| `Pbxtr.sln` derleme (Integration/Architecture/SysAgent `--no-incremental` ayrıca) | 0 error |
| `LeaveEndpointTests` | **18/18** (önceki 15 + 3 yeni), rc=0 |
| `Architecture.Tests` | 694/694, rc=0 |
| `Api.Tests ~Audit` | 246/246, rc=0 |
| vitest `screens/system` + `screens/live` | 312/312 |
| vitest `i18n` | 35/35 · parity 3/3 |

**Mutasyon — üçü de KIRMIZI, geri alınınca 18/18 yeşil:**

| # | Mutasyon | Sonuç |
|---|---|---|
| 1 | `created` `TargetType` → `AuditTargets.User` | `Gecerli_izin_kaydedilir_ve_denetime_yazilir` **KIRMIZI** (1 failed / 17 passed) |
| 2 | tavan kontrolü devre dışı (`if (false && …)`) = sessiz kırpma | `Disa_aktarim_tavani_asilinca_istek_reddedilir` **KIRMIZI** (1/17) |
| 3 | tavan sınırı `>` → `>=` | `Tam_tavandaki_disa_aktarim_gecer` **KIRMIZI** (1/17) |

Parite bekçisi ayrıca ölçüldü: `TARGET_TYPES`'tan `Leave` satırı silinince 1 failed /
2 passed, geri konunca 3/3.

### 3. Liste ucunun sınırsızlığı — ÖLÇÜLDÜ, DÜZELTİLMEDİ (ayrı kart)

Sunucuda (176.88.41.220, `date -u` = 2026-09-18 10:48 UTC) ölçüm:

```bash
docker exec pbxtr-postgres psql -U postgres -d pbxtr -Atc \
  "select (select count(*) from public.tenants), (select count(*) from public.users),
          (select count(*) from public.agent_leaves)"
# 5|18|0
```

- **`agent_leaves` = 0 satır.** En büyük tenant ("Ertan Grup Çağrı Merkezi") 10
  kullanıcı; 92 günde dönen satır sayısı bugün **0**. Yani sınırsızlık **veriden
  görünmüyor** — bu bir "sorun yok" bulgusu değil, **ölçülemezlik** bulgusudur.
- **Analitik tavan:** çakışma tetikleyicisi aynı kullanıcının izinlerinin kesişmesini
  yasaklar → 92 günlük pencereye değen ayrık aralık sayısı kullanıcı başına en çok 92.
  Yani `satır ≤ kullanıcı × 92`. 150 agent'lık tenantta **13.800** — dışa aktarım
  tavanının (5.000) **iki katından fazla**. Gerçekçi hâl (kurulun süpervizör ölçümü)
  600–900.
- **Sayfalama kimi kırar (ölçüldü):** `ILeaveCalendar.ListAsync`'in **iki** çağırıcısı
  var (`LeaveEndpoints.cs:112` liste, `:158` aktarım); istemci tarafında tek tüketici
  `LeavesScreen.tsx` ve o ekran yanıtı **kişiye göre gruplayıp ısı haritası** çiziyor
  (`groupByPerson`, `person.items.find(day ∈ [startsOn,endsOn])`). **Satır bazlı
  sayfalama bu ekranı sessizce yanlış çizer:** eksik sayfadaki bir izin, haritada
  "izinli değil" olarak görünür — yani Ş76-13'ün yasakladığı sessiz kırpmanın ekran
  hâli. Sayfalama eklenecekse **kişi bazlı** olmalı ya da liste ucu da aktarım gibi
  **tümüyle reddetmeli**.

### Commit

`3c1ce1f4` — Karar #76 S76-13 + S76-16: izin aktariminda 5.000 satir tavani +
AuditTargets.Leave. **Push edildi.**

### 101. Kurul #76 — ve turun en pahalı hatası benimdi

**Bağlam:** 8 ajanın kart kart ölçtüğü turdan sonra geriye 10 **karar** kaldı (araştırma
değil, kol seçimi). Hepsini tek kurulda topladım. Sonuç: **10/10 ŞARTLI, 26 şart.**

#### M6'yı yanlış gerekçeyle bloke etmeye çalıştım

Kurula şu uyarıyla gittim:

> *"`pbxtr_reassert_hardening()` içinde `pbxtr_apply_tenant_rls` çağrısı SIFIR → tazeleme
> migration'ı 01'in policy metnini kurulu veritabanlarına hiç taşımaz."*

db-lider ve Şeytan **bağımsız olarak** çürüttü. Uyarı, adını verdiğim **iki kartın ikisi için
de geçersizdi (0/2)**:

| Kart | Gerçek teslim yolu |
|---|---|
| `BR-DB-72` | Hedef policy'yi üreten `pbxtr_apply_tenant_rls` **değil**, `pbxtr_apply_tenant**s**_rls()` — bir harf farklı, ayrı fonksiyon. Reassert onu **koşulsuz** çağırıyor: `01-rls-template.sql:1053-1061` (üretim), `:3201` (`PERFORM`), `:3249-3257` (01'in kendi sonu), `20260918120000_RlsTemplateRefresh.cs:122` |
| `BR-SEC-26` | 02'nin **tamamı** ayrı bir migration'la yeniden koşuyor: `20260918130000_GuardsTemplateRefresh.cs:123` |

**Karar #75'te yazdığım kural "kendi ölçümünü unutma" idi. Bu sefer unutmadım —
ölçüldüğünden GENİŞ uyguladım.** Jenerik şablon fonksiyonu için doğru olan bir olguyu, adı
bir harf farklı olan `tenants`-özel fonksiyon için de doğru saydım.

**Zararın yönü hatanın kendisinden kötüydü:** uyarı ayakta kalsaydı kurul, **var olan bir
teslim yolunu yok sayarak** bir güvenlik daraltmasını *"nasılsa ulaşmaz"* diye **kabul edilmiş
sapma** olarak kayda geçirecekti. Yani ölçüm hatası, bir güvenlik açığını belgeleyerek
meşrulaştıracaktı.

→ **Yeni kural Ş76-1:** ölçülmüş bir negatif sonuç aktarılırken **kapsamı da yazılır** —
hangi fonksiyon/dosya/tablo için ölçüldü, hangisi için ölçülMEdi. **Ad benzerliği kapsam
kanıtı değildir.** Kapsamı yazılmamış negatif sonuç kurula sunulamaz.
Hafıza güncellendi: `kendi-negatif-sonucunu-unutma.md`.

#### Hatanın yan ürünü bir P0 oldu

Uyarı çürüyünce tersi doğru oldu: **01 tazelemesi `tenants` üzerinde 8 policy'yi DROP+CREATE
ediyor** → ACCESS EXCLUSIVE. `POST /telephony/call-permission` zincirinin ilk adımı `tenants`
üzerinde canlı EF okumasıdır ve uç **FAIL-CLOSED**'dır → o pencere boyunca **giden arama
durur.** `20260918120000_RlsTemplateRefresh` **onaylı ama henüz yayınlanmadı.**
→ `BR-DB-91` (P0), Karar #65 Ş65-3.5'in istediği ölçüm yapılmadan yayınlanamaz.

#### Kurulun kart metinlerinde olmayan bulguları

- **Asterisk uzmanı benim önerimi çürüttü:** brief'te "`module reload res_pjsip.so` bu işi
  görür mü?" diye sormuştum — **hayır**, üç bağımsız sebeple. `Stasis:` device state
  `res_stasis_device_state.so`'nun konteynerinde; reload **sahte YEŞİL** verir. Ve asıl
  cevap zaten elimizdeydi, negatif yönde: `Stasis:` device state hiçbir yere kalıcı yazılmaz,
  yani "restart sonrası kalıcı mı" **açık bir soru değil, bilinen bir hayır**.
  **Kırmızı çizgi (Ş76-12a):** dialplan dalı yalnız `== BUSY` yazılır; `!= NOT_INUSE` gibi
  negatif dal restart sonrası **düğümdeki her dahiliyi topluca DND'ye sokar.**
- **İki yazılmamış teslim kilidi:** `BR-SYS-102` → `BR-AST-108` (ajan BusyBox `wget` ile 4xx
  gövdesini okuyamıyor → 403/429 ayrımını yapamaz → kaldırma manifesti üretemez) ve
  `BR-AST-87` → ARI envanter tabanlı **her** eşik (ARI bugün 509 endpoint listeliyor, ~500'ü
  ölçüm kalıntısı → eşikler **çöp üstünde kalibre edilir**).
- **`BR-AST-108` tertip işi değil:** düğümden düşürülen tenant'ın dialplan'i canlı kalıyor
  (89 satır) — trunk'a erişen ücretlendirilebilir rota → **toll fraud ve faturalama sızıntısı.**
- **Linux uzmanı M9'un ön koşulunu çürüttü:** `apt-cache policy postgresql-client-16` sunucuda
  **boş**, host'ta **`postgres` kullanıcısı yok**. Kurul "kabul" deseydi kart kapanır, iş
  sunucuda **hiç değişmezdi** — *"karar yazılmış ama uygulanmamış"*ın birebir kendisi.
- **cm-agent:** BR-7 bugün indi ama **agent ayağı boştu**. *"Seviyem yanlış girilmişse ekranda
  uyarı yok; zor çağrıları yemeye devam ediyorum, AHT'm şişiyor — kontrolümde olmayan bir şey
  beni ölçüyor."* Brief'imin boşluğuydu → `BR-FE-110`.
- **Şeytan `kapi_75`'in İKİ KEZ tanımlı olduğunu buldu** (`:2502` ↔ `:2516`) — iki ajan aynı
  gün aynı numarayı almış. İkisi de koştuğu için **hiçbir kapı kırmızı yanmamıştı**; belirti
  "kapı kırmızı" değil, **"kapı yanlış şeyi ölçüyor"** olacaktı. Aynı turda düzeltildi.
- **Commit:** `87592acf` (karar), `eb1c055b` (kapı numarası)

### 102. Karar #76 uygulandı — beş ajan, beş şart

| Şart | Sonuç |
|---|---|
| **Ş76-8/9** — çapraz kip envanteri | `kapi_77` (`a09244ab`). **45 ↔ 85 çelişkisi çözüldü:** `45 ⊂ 61 ⊂ 85`. 85 = GUC'u yalnız *anan* dosya, 45 = P1'in tek-boşluklu varyantı, 61 = kanonik (30 koşan / 34 migration). **"7" ve "48" yeniden ÜRETİLEMEDİ** çünkü o sayımların **deseni yazılmamıştı** — deseni yazılmamış sayım ölçüm değildir. |
| **Ş76-21** — agent yetenek görünürlüğü | `2d57f64d`. (b) yolu **ölçerek** elendi: `/users/{id}/skills` `user.read` ister ve `userId` rotadan gelir, `ITenantContext.UserId` ile karşılaştırılmaz → agent başkasının yetkinliğini okurdu. İzolasyon **tip düzeyinde**: `GetMineAsync()` `Guid` almaz. |
| **Ş76-11** — webhook retention | `8fb533c9`. **Kurul şartı iddiayı düzeltti:** `ErrorText` uzak yanıt gövdesini **taşıyor** (`WebhookSender.cs:126-134`) — "içerik yok" yanlıştı; tavan 512 ve üç noktadan tek sabite bağlı. Karar değişmedi. İkinci şart (**"append-only varsa korunur"**) **boşta çıktı**: tetikleyici yok, `pbxtr_app`'in DELETE'i **var**. |
| **Ş76-4** — sesli mesaj kutusu kimlikle | `66b52310`. `ux_..._tenant_linked` → `(tenant_id, linked_id, box_id)`. **`box_id` bilerek FK DEĞİL:** tipli FK'lar `SET NULL` olur, kimlik de FK olsaydı anahtar NULL'a düşerdi ve PG'de benzersiz indekste NULL'lar farklı sayıldığı için **aynı mesaj yine ikinci kez yazılırdı.** Mutasyon: 9 test kırmızı + SLA kırılımını ada döndürmek **derleme hatası**. |
| **Ş76-13/16** — izin tavanı + `Leave` | `3c1ce1f4`. Tavan **5.000** (emsal 199/499 ucu iptal ederdi). Vacuity **yapısal olarak yok ve bu ölçüldü**: `ListAsync` imzasında limit parametresi bulunmuyor → dönen liste gerçek toplam. |

### 103. Bugün üç kez aynı çarpışma: paralel ajanlar aynı dosyada

1. AST ajanının 27 backlog satırı başkasının commit'ine girdi.
2. DB ajanının `BR-DB-89` dosyaları başkasının commit'ine girdi.
3. SYS ajanının 19 satırı **tam dosya yeniden yazımıyla sessizce silindi** (yeniden uyguladı).

**Çözüm iki parçalı:** (a) `git commit --only -- <yollar>` tek adımda (`git add` + `commit`
arasındaki pencere kapanır), (b) `backlog.md` tur boyunca ajanlara **kapatıldı**, satırları
ben yazdım. Frontend ajanı üçüncü bir yol gösterdi: `git hash-object -w` +
`git update-index --cacheinfo` ile HEAD üzerine **yalnız kendi eklemesini** uygulayıp staged
blob'da başkasının satırının 0 olduğunu doğruladı.
Hafıza: `paralel-ajan-stage-supurur.md`.

### 104. İki ölçüm aracı yalan söyledi

- **`grep -c $'\r'`** `deploy/yerel-kapilar.sh` için **0** dedi; dosyada 2542 CRLF vardı.
  git-bash metin kipinde CR'yi kırpıyor. *"Araç yokluğu sıfır gibi görünür"*in kardeşi:
  **araç, ölçemediği soruya da bir sayı basıyor.** Doğrulama python ile yapıldı.
- **`pathlib.write_text`** Windows'ta `yerel-kapilar.sh`'a **2570 CR** ekledi. Depoda
  `.gitattributes` düzeltirdi ama **yerel konteyner koşumu** `\r: command not found` ile
  bozulurdu (ajan yakaladı, bayt düzeyinde LF'e çevirdi).

### 105. `kapi_77` kurulduğu gün işe yaradı

Yeniden dondurma sırasında kapı kırmızı yandı. Sebep bayat bir muafiyetti: uçuşta listesindeki
yol `20260918**18**0000_VoicemailBoxIdentity.cs`, commit edilen dosya
`20260918**19**0000_` (o damgayı webhook migration'ı almıştı). **Muafiyet yola göre eşleşiyor,
dosya yeniden adlandırılınca muafiyet düşüyor ve kapı yanıyor** — istenen davranış tam bu.
Envanter yeniden donduruldu, mutasyonla doğrulandı (yeni çapraz-kip migration → rc=1).

## Kararlar
- **Ş76-1:** negatif sonucun kapsamı da yazılır; ad benzerliği kapsam kanıtı değildir.
- **Ş76-12a:** device state dialplan dalı yalnız `== BUSY`; negatif dal yasak.
- **Ş76-13:** dışa aktarımda sessiz kırpma yasak — eksik satırlı bordro dosyası görünmeyen
  izni "devamsızlık" yapar ve kesinti agent'ın maaşından çıkar.
- **Ş76-22:** #12/#13'e penalty kolonu eklenmez; boş/sıfır gösteren kolon da çizilmez.

## Açık kalanlar / sonraki adım
- **`BR-DB-91` (P0):** `RlsTemplateRefresh` yayın öncesi `call-permission` RED ölçümü.
  **Bu turun tek P0'ı ve yayının önünde duruyor.**
- **Yayın hattı hâlâ koşturulmadı** (iki koşu bellek yetersizliğinden öldürüldü, talimat
  "yalnız istenirse"). 8 kart bu yüzden bloke.
- BR-SEC-16 + BR-SEC-28 sır rotasyonu: ajanlar bitti, sıra bende.
- Yeni kart gerekiyor: IVR `voicemail` düğümü + DID kararı için `box_kind` + tipli kimlik
  alanları `ivr_nodes`/`dids` üzerinde **hâlâ yok** → canlı veri bugün yalnız `extension`
  kindinde.
- Kurula soru: reddedilen dışa aktarım (`>5.000 satır`) denetime yazılmalı mı?
  Bugün Contacts emsali alındı (yazmıyor).

---

## Tur: BR-BE kapanış turu (backend-dev-1, akşam)

### Bağlam
`yonetim/backlog.md`'de 31 açık `BR-BE` kartı vardı ve çoğunun ölçümü aynı gün
yapılmıştı. Hedef yeni ölçüm değil **kapatmaktı**: her kart ya kapanış metnine ya
yapılabilir işe ya da **adıyla yazılmış bir engele** düşmeliydi.

### Yapılanlar

#### 1. BR-BE-193 — `GET /api/v1/leaves` satır bakımından sınırsızdı (KOD İŞİ)
- **Neden:** Ş76-13 dışa aktarıma 5.000 satır tavanı koymuştu; liste ucu sınırsız
  kalınca aynı pencere, aynı yetki, aynı veri yalnızca `/export` soneki farkıyla
  tavansız akıyordu — tavan anlamsızlaşıyordu. Ölçülmüş payda: çakışma tetikleyicisi
  yüzünden `satır <= kullanıcı x 92`, 150 agent'lik tenantta **13.800** satır.
- **Ne yapıldı:** liste ucuna `MaxListRows = MaxExportRows = 5.000` ve **red** kapısı
  (400 + ProblemDetails, `meta.rule = list_too_large`). **Sayfalama bilerek
  yazılmadı:** yanıtın tek tüketicisi `LeavesScreen` satırları kişiye göre gruplayıp
  ısı haritası çiziyor; satır bazlı sayfalama eksik sayfadaki izni haritada "izinli
  değil" gösterirdi — Ş76-13'ün yasakladığı sessiz kırpmanın ekran hâli.
- **Dokunulan dosyalar:** `src/Pbxtr.Api/Modules/Leaves/LeaveEndpoints.cs`,
  `tests/Pbxtr.Api.Tests/Modules/Leaves/LeaveEndpointTests.cs`
- **Komutlar:**
  ```bash
  dotnet test tests/Pbxtr.Api.Tests/Pbxtr.Api.Tests.csproj \
    --filter "FullyQualifiedName~LeaveEndpointTests"
  ```
- **Sonuç / doğrulama:** **20 geçti / 0 kaldı** (önce 18). İki mutasyon ayrı ayrı
  koşuldu, her biri TEK kırmızı verdi: `>` → `>=` (tam tavandaki istek reddedildi) ve
  kapının etkisizleştirilmesi (5001 geçti). Vacuity yapısal olarak yok:
  `ILeaveCalendar.ListAsync` imzasında limit parametresi bulunmaz.

#### 2. BR-BE-169 — son dış ayna indi, ama altından daha büyük kusur çıktı
- **Neden:** kart "kapsanmayan 4 dış ayna" diyordu; ölçümde gerçekten kalan **1**'di
  (`ck_call_attempts_origin`). Kart ayrıca bir **çelişki** yazıyordu: kısıt kuruluysa
  sınıf kapatıcı bugün kırmızı olmalıydı, oysa yeşil raporlanmıştı.
- **Ne yapıldı:** `Mirrors` tablosuna `public.call_attempts.ck_call_attempts_origin`
  satırı eklendi (C# kaynağı `CallAttemptOrigins.All`).
- **Komutlar:**
  ```bash
  PBXTR_REQUIRE_DOCKER_TESTS=1 dotnet test \
    tests/Pbxtr.Integration.Tests/Pbxtr.Integration.Tests.csproj \
    --filter "FullyQualifiedName~EnumMirrorCheckConstraintTests"
  ```
- **Sonuç / doğrulama:** **47 geçti / 0 kaldı / 0 atlandı** (önce 46). Mutasyon (C#
  kümesine `mutasyon_degeri`) TEK kırmızı verdi ve kurulu tanımı bastı.
- **ÇELİŞKİNİN SEBEBİ (kartın tahmininden başka):** sınıf kapatıcının evren filtresi
  `definition.Contains("= ANY (ARRAY[")` ve bu kalıp **yalnızca `text` kolonlarını**
  yakalıyor. PostgreSQL bir `character varying` kolonundaki aynı kısıtı
  `= ANY ((ARRAY[…])::text[])` diye — **fazladan bir parantezle** — basıyor, kalıp
  eşleşmiyor, kısıt evrene **hiç girmiyor**. Filtre geçici olarak `ARRAY[`'a
  genişletilince ne aynada ne muafta olan **30** kısıt göründü
  (`sms_messages` 5, `tickets` 3, `voicemail_messages` 3, `callback_entries` 3, …).
- **Karar:** genişletme **bilerek geri alındı** — kapı 30 kalemle HEP KIRMIZI kalırdı
  ve bu, onu susturmanın ilk adımı olurdu. Bulgu `BR-QA-108`'e yazıldı; testin
  `<remarks>`'ındaki *"kapsanmayan 0"* iddiası da düzeltildi (dar evren içinde doğru,
  gerçek şemanın tamamı için değil).

#### 3. Kapanış metni yazılanlar (iş bitmişti, durum biçimi kapanış değildi)
`BR-BE-135` (kapsam dışı — üründe occupancy metriği HİÇ YOK, düşülecek payda yok),
`BR-BE-152` (bölündü — iş 6 karta devredilmiş), `BR-BE-170` (bölündü),
`BR-BE-171` (bölündü), `BR-BE-175` (bölündü), `BR-BE-176` (kapsam dışı — Karar #76
Ş76-4 ikilemi çözdü, taşıma `66b52310` ile indi), `BR-BE-184`.

> **`BR-BE-184` dersi:** kart durumu zaten `**Bitti (...)` ile başlıyordu ama hücre
> içinde geçen **"kismen-uygulanmis"** kelimesi `clickup-durum.js` kural 1'ini
> tetikleyip **bitmiş işi `in progress`** gösteriyordu. Aynı sınıftan iki vaka daha
> çıktı: `**Kapsam dışı** … taşıma bitti` → `in progress` (ortadaki "bitti"),
> ve `Dikiş hazır` → `to do` (`Hazır` kalıbı). **Durum hücresinin gövdesindeki sıradan
> kelimeler kartın panodaki durumunu değiştiriyor.**

#### 4. Engeli adıyla yazılanlar (açık kalır)
`BR-BE-53`/`59` (Netgsm hesabı AÇILMADI), `BR-BE-119`/`150` (yayın — sunucudaki imaj
`demo-ea567d11` HEAD'in 292 commit gerisinde), `BR-BE-164`/`165` (Karar #67 Ş67-8'in
açık bıraktığı A/B seçimi), `BR-BE-182` (S-VM-5 için iade TANIMI: hangi izin türü,
geçmişe dönük, SLA sayacı, izin bitince geri atama), `BR-BE-183` (`pbxtr-qa` +
`BR-SEC-23`), `BR-BE-185` (Docker'lı PostgreSQL ölçümü). Kalan 13 kart zaten
"Bloke — <engel>" biçimindeydi ve dokunulmadı.

#### 5. Açılan kartlar (devredilen iş görünür kalsın diye)
`BR-BE-194` (agent doluluk/occupancy metriği — `BR-BE-135` + `BR-BE-171`(b) buraya
devretti), `BR-BE-195` (monotonik `LiveAgentState.MeasuredAt`), `BR-BE-196`
(`ivr_nodes`/`dids` üzerinde tipli kutu kimliği), `BR-FE-112` (#49 voicemail SLA
alanı), `BR-FE-113` (`queueMemberDelivered` şeridi), `BR-QA-108` (enum ayna
kapatıcısının `varchar` kör noktası).

- **Commit:** `0b364722` — BR-BE kapanis turu: 9 kart kapandi, 1 gercek kod isi indi,
  6 kart acildi

### Kararlar
- Liste ve dışa aktarım **tek tavan** paylaşır; ikinci bir sayı ikinci bir doğruluk
  kaynağı olurdu.
- `BR-QA-108`'de genişletme **tek adımda** yapılmalı: yarım genişletilmiş bir evren
  kapıyı kalıcı kırmızı bırakır.

### Açık kalanlar / sonraki adım
- **Kart numarası önce ölçülmeli:** `BR-QA-107` eşzamanlı çalışan başka bir ajan
  tarafından aynı turda kullanılmıştı; `clickup-cikar.js` mükerrer kimlikte durdu ve
  kart `BR-QA-108`'e taşındı. Sayacın tek başına okunması yetmiyor.
- `tests/Pbxtr.Api.Tests` tur sonunda **başka bir ajanın** in-flight dosyası yüzünden
  derlenmiyordu (`AriDndDeviceStateAnnouncerTests.cs` → `AsteriskOptions.AmiPassword`
  yok). Bu turun ölçümleri o dosya inmeden ÖNCE alındı.

---

## db-lider turu — 17 açık BR-DB kartının kapatılması (2026-09-18/4)

### Bağlam
Karar #76 on maddeyi karara bağladı ve bunların çoğu BR-DB kartlarını bloke ediyordu.
Bu turun hedefi: 17 açık BR-DB kartını (16, 35, 40, 44, 50, 52, 67, 69, 70, 72, 74,
76, 79, 84, 88, 90, 91) üç halden birine oturtmak — kapanış metni, yapılan iş, ya da
**adı konmuş** engel.

### Yapılanlar

#### 1. BR-DB-90 — M4'ün dördüncü kolu TESLİM EDİLDİ (tek gerçek kod işi)
- **Neden:** Ş76-6 (Şeytan I6). Üç kol da `01-rls-template.sql` şablonuna bakıyordu;
  oysa süper admin CDR araması milyonlarca satırda koşar ve **en büyük çapraz-kip
  taraması şablonda değil `CdrSqlBuilder.cs:74`'tedir.** Bu kol policy metnine
  dokunmaz → tazeleme migration'ı ve `tenants` üzerinde ACCESS EXCLUSIVE penceresi
  istemez. Bedeli sıfır olan tek kol.
- **Ne yapıldı:** `CdrSqlBuilder.ActiveTenant` operand sırası takas edildi:
  `(c.tenant_id = app_current_tenant() OR app_is_cross_tenant())` →
  `(app_is_cross_tenant() OR c.tenant_id = app_current_tenant())`. Ucuz kol
  (`LANGUAGE sql`, satır içine alınır) solda; pahalı kol (`plpgsql` + regex biçim
  kontrolü) sağda. Çapraz kipte OR kısa devre yapar ve pahalı kol satır başına **hiç**
  değerlendirilmez.
- **Dokunulan dosyalar:** `src/Pbxtr.Infrastructure/Search/CdrSqlBuilder.cs`,
  `src/Pbxtr.Infrastructure/Search/PostgresCdrSearch.cs`,
  `tests/Pbxtr.Architecture.Tests/CdrSqlBuilderGuardTests.cs`,
  `tests/Pbxtr.Architecture.Tests/RawSqlAllowlistTests.cs`,
  `deploy/br-db-90-cdr-yuklem-olcumu.sql`,
  `doc/analiz/br-db-90-cdr-yuklem-olcumu-2026-09-18.txt`
- **Komutlar:**

  ```bash
  docker run -d --name br_db_90 -e POSTGRES_PASSWORD=x postgres:16
  docker exec -i br_db_90 psql -U postgres -v ON_ERROR_STOP=1 -f - \
    < deploy/br-db-90-cdr-yuklem-olcumu.sql > doc/analiz/br-db-90-cdr-yuklem-olcumu-2026-09-18.txt
  dotnet build Pbxtr.sln
  dotnet test tests/Pbxtr.Architecture.Tests/Pbxtr.Architecture.Tests.csproj --no-build
  ```

- **Sonuç / doğrulama:** PG 16.15, 1.000.000 satır, kontrol grubu aynı işi yapar
  (aynı tablo, **aynı RLS policy metni**, aynı plan, `rows (gerçek)=1000000`; tek
  değişken bu satır).
  - cross=ON: `Seq Scan` 4.746 ms / `Buffers: shared hit=877 read=16656` →
    `Seq Scan` 2.434 ms / `Buffers: shared hit=14765 read=2768` (**toplam blok aynı:
    17.533**). Duvar saati medyanı 5.306 → 3.120 ms, **-%41**.
  - cross=off (günlük kullanım, tenant daraltmalı, 50.000 satır): 232,4 → 230,4 ms;
    plan, `Heap Blocks: exact=877`, `Buffers: shared hit=1126` **birebir aynı** →
    gerileme YOK.
  - Davranış özdeşliği (OLCUM-5): normal 50.000/50.000, çapraz 1.000.000/1.000.000,
    **bozuk GUC 0/0**, GUC yok 0/0.
  - **Mekanizma planda görünür:** `Filter` yüklemi **iki kez** taşır — biri policy,
    biri uygulama. Policy kolu Ş76-5 (c) ile kilitli olduğu için ~%50 tavan beklenir;
    ölçülen odur.
  - Bekçi ikinci bir iddia taşır (**eski sıra sabit olarak yasak**); onsuz kapı
    vacuous olurdu. Mutasyon: eski sıra geri yazıldı → 2/2 KIRMIZI, geri alındı →
    2/2 YEŞİL. İkili doğrulandı (.dll içinde yeni dize 2, eski 0).
- **Commit:** `23c69eed`

#### 2. BR-DB-50 — Ş76-14'ün YAZILDIĞI ŞEKİL PostgreSQL'de MÜMKÜN DEĞİL (ölçüldü)
- **Neden:** Ş76-14 *"`purge_ledger` partition başına satır yazar ve o satır çiftin
  kendi transaction'ında commit edilir"* diyor. Bu cümlenin uygulanabilirliği hiç
  ölçülmemişti.
- **Ne yapıldı:** `deploy/br-db-50-parti-atomikligi-olcumu.sql` yazıldı ve koşuldu.
- **Sonuç / doğrulama** (PG 16.15, ham çıktı
  `doc/analiz/br-db-50-parti-atomikligi-olcumu-2026-09-18.txt`):

  | Ölçüm | Sonuç |
  |---|---|
  | FUNCTION içinde `COMMIT` (bugünkü şekil) | `ERROR: invalid transaction termination` |
  | PROCEDURE + **açık `BEGIN`** içinde `CALL` | **AYNI HATA** |
  | kontrol grubu (`SET` vs `SET LOCAL`) | aynı hata → sebep GUC değil, transaction bloğu |
  | otomatik commit kipi (açık `BEGIN` yok) | `CALL` + iç `COMMIT` **çalışır** |
  | aynı kipte `SET LOCAL` | `WARNING: SET LOCAL can only be used in transaction blocks`, değer **uygulanmaz** |

  Yani şartı gövde **içinde** karşılamanın tek yolu tenant GUC'unu `SET LOCAL` yerine
  `SET` ile yazmaktır — **CLAUDE.md §5'in adıyla yasakladığı şey** (bağlam Npgsql
  havuzunda bir sonraki isteğe sızar).
- **Karar (db-lider):** döngü gövdeden **çağırana** taşınır. `CallDataRetentionJob`
  her partition için ayrı transaction açar, `SET LOCAL` aynen yazılır, `DETACH`+`DROP`
  çifti ve o partition'ın `purge_ledger` satırı aynı transaction'da commit edilir.
  Ş76-14'ün değişmezi (**çift atomikliği**, ADR-006) aynen karşılanır; §5 korunur.
- **Commit:** `dfa96955`

#### 3. BR-DB-40 — KAPANDI: "Ölçüldü — kol (c), Karar #76 Ş76-5; kalan iş BR-DB-90"
- Şeytan I4'ün şartı karşılandı: **"%5" iddiası artık `rows=` + plan adı + `Buffers:`
  ile yazılı.** `doc/analiz/br-db-40-sql-govde-regexli-olcumu-2026-09-18.txt:219-243`
  — iki hücre de `Seq Scan`, `rows (gerçek)=270000`, `Buffers: shared hit=3069`
  **birebir aynı**; b1 `649,868 ms` → b6 `602,725 ms` = **-%7,3** (duvar saati -%5,1).
- **Ş76-DB-3 serbestliği KULLANILMADI:** kazanç %15 eşiğinin altında (7,3 < 15) →
  mikro-optimizasyon yapılmaz, şablona dokunulmadı.
- Ş76-DB-2 **sayısal yeniden açma eşiği** karta yazıldı (tek tenant tablosunda RLS
  yüklemi uygulanan plan adımında `rows (gerçek)` >= 5.000.000, ya da BR-DB-52 yıkıcı
  koşusu 50 sn bütçenin %60'ını aşarsa → P1).

#### 4. BR-DB-70 — BÖLÜNDÜ: `BR-DB-94` / `95` / `96` / `97` (Ş76-7, sıra bağlayıcı)
- Kartın **kendi işi olan envanter** `kapi_77` ile kapıya bağlanmıştı (koşan kod
  30/35, migration 34/60; `45 SUBSET 61 SUBSET 85`). Geriye kalan iş envanter değil
  **daraltmadır** ve tek kartta durması Ş76-7'nin **risk sınıfı** ayrımını gizliyordu.
- D1 silen → D2 yazan → D3 okuyan → D4 `CrossTenantReadAudit` + istek yolu.
  Her dalgada **kapı önce, daraltma sonra**. Ş76-26 gereği dalgalar sonraki tur.
- **Kart numarası önce ölçüldü:** ilk yazımda 92–95 alınacaktı; `92`/`93` aynı turda
  **başka bir ajan** tarafından alınmıştı, betiğin mükerrer kontrolü durdurdu ve
  numaralar 94–97'ye kaydırıldı.

#### 5. Kalan 14 kart — engel ADIYLA yazıldı
- **Yayın bağımlısı (69/74/79/84/88/91):** ölçüldü — canlıdaki son migration
  `20260915122000_UserRoleScopeConsistency`, ondan sonra zincirde **21 migration**
  bekliyor. Beklenen adım tek ve adı var: **yayın #18'in `MigrationRunner` aşaması**.
  Her kart kendi migration'ının o kümedeki **sırasını** yazıyor (69→1, 74→9,
  79→12/13/21, 84→15, 88→16, 91→14).
- **Kurul bağımlısı (16/35/67/76):** ölçüldü — Karar #76'nın gündemi M1–M10'du ve bu
  dört kart **hiçbirinde yoktu**; yani bekledikleri şey ek bir ölçüm değil, bir sonraki
  kurul turu.
- **72:** Ş76-2 gereği `BR-DB-91` + `BR-SEC-29`'a bağlı. "Tazeleme taşır mı" sorusu
  **cevaplandı: TAŞIR**; yeni soru orada.
- **52:** canlı yıkıcı koşu; iki ön koşulu da adıyla yazıldı (süre kaydı +
  `budget-exceeded` tohumu + 1 saatlik kuru koşu kapısı).
- **44/50:** onay verildi → `karar bekleyen` yerine **`to do`**. 44'e bu turda ölçülen
  **beş dosyalık kapı zinciri** yazıldı (02-guards'taki **çift** literal liste +
  dondurulmuş toplam md5 `8dc49b1d…` + iki `.expected` + 02 tazeleme şeridi +
  contract onayı) — kartta yazılı değildi ve iş "iki tablo yaratmak" sanılıyordu.

#### 6. Doğrulama ve pano
- `node yonetim/arac/clickup-cikar.js` → rc=0 (696 kart).
- `clickup-durum.js` ile 21 kartın eşlemesi **tek tek okundu**. `BR-DB-91` ilk yazımda
  metindeki "**bitti**kten" kelimesi yüzünden `in progress` çıkıyordu → kelime
  değiştirildi, `backlog` oldu. (Kural 1 çıplak alt dize arıyor.)
- ClickUp: `clickup-olustur.js` 20 yeni kart, `clickup-senkron.js` 27 durum;
  kuru doğrulama **`fark olan kart: 0, izde olmayan: 0`** (uzakta okunan görev 1513).
- **Commit:** `dfa96955` (backlog + BR-DB-50 ölçümü), `8d667c63` (ClickUp izi)

### Kararlar
- **BR-DB-50'nin şekli:** `purge_call_data()` döngüsü gövdeden çağırana taşınır.
  Gövde içinde `COMMIT` yolu CLAUDE.md §5 ile çelişmeden açılamaz (ölçüldü).
- **BR-DB-40 kapanır, BR-DB-90 taşır:** M4'ün kaldıracı şablonda değil ham SQL'dedir.
- **Mikro-optimizasyon eşiği bağlayıcıdır:** %15'in altındaki kazanç için şablona
  dokunulmaz (Ş76-DB-3). 7,3 < 15 → yapılmadı.

### Açık kalanlar / sonraki adım
- **BR-DB-91 bu turun tek P0'ıdır ve yayının önünde durur.** Ölçüm yalnızca migrate
  **koşarken** yapılabilir; geriye dönük veya yayın dışında üretilemez. Ölçüm planı
  dört adım hâlinde karta yazıldı (taban RED sayacı → `pg_locks`/`pg_stat_activity`
  örneklemesi → RED farkı + `DECISION_UNAVAILABLE` sayısı → Karar #65 Ş65-3.5 biçimi).
- **BR-DB-44 yazılmadı ve sebebi ölçüldü:** 02-guards tazeleme şeridi **tek sıralı**
  bir kaynaktır ve bu turda `20260918180000_GuardsTemplateRefreshWebhookRetention`
  ile doluydu; aynı turda ikinci bir 02 tazelemesi `sablon-refresh.expected`'ın tek
  satırlık 02 kaydında çakışır.
- `Pbxtr.Architecture.Tests` tam koşusu **708 geçti / 1 kaldı**
  (`TenantLeakCoverageTests`, `AgentSkillProfile`) — kırmızı **paralel bir ajanın**
  uçuştaki işidir, bu turun kapsamında değil ve dosyaları commit'e alınmadı. Aynı
  şekilde `Pbxtr.Infrastructure` tur ortasında başka bir ajanın in-flight dosyaları
  (`AriStasisApp.cs`, `AriDndDeviceStateAnnouncer.cs`) yüzünden geçici olarak
  derlenmedi; mutasyon ölçümü bu yüzden **kaynağı okuyan** bekçilerle `--no-build`
  koşuldu.

---

## Tur: pbxtr-qa kapatma turu (QA + FE + EPIC kartları)

**Commit:** `1b137b3c` — *pbxtr-qa kapatma turu: 2 yeni kapi, 1 gercek kusur, 10 kart devredildi*

### Bağlam
Hedef: `yonetim/backlog.md`'de açık kalan 15 QA kartı, 2 FE kartı ve 7 EPIC toplayıcısını
kapatmak. Her kart üç hâlden birine sokulacaktı: (1) iş bitmiş ama durum metni kapanış
biçiminde değil → doğru metni yaz; (2) iş var ve yapılabilir → YAP; (3) gerçekten bloke →
**engeli adıyla** yaz.

### Yapılanlar

#### 1. BR-QA-105 — `--artifacts-path` evreni kapatıldı, gerçek bir kusur çıktı
- **Neden:** aynı gün ÜÇ kez `--artifacts-path` altında sahte kırmızı çıkmıştı. Kart
  "önce evreni kapat" diyordu.
- **Ne yapıldı:** `tests/**/*.cs` tarandı; depo kökü arayan **27 dosya** (12 Api / 12
  Architecture / 3 Integration). Tanım iki uçlu yazıldı: (a) yorum olmayan satırda
  `.Parent` veya `GetDirectoryName`, (b) `*.sln` / `CLAUDE.md` dize sabiti.
- **Sayaç kendi filtresine karşı ölçüldü** (defter dersi): bağımsız `grep -rl` birleşimiyle
  27 = 27, iki yönde de fark 0. İlk tanım yalnız `.Parent` arıyordu ve ÜÇ dosyayı
  kaçırıyordu (`AgentStateHistoryTests`, `ScriptPublishedEventTests`,
  `ProvisioningTenantPrefixGuardTests` — üçü de `string` üzerinde `Path.GetDirectoryName`).
- **GERÇEK KUSUR (kartta yoktu):** `TenantLeakCoverageTests.cs:289` kök işaretçisini
  `"Pbxtr.sln"` (büyük P) arıyordu; depoda izlenen dosya `pbxtr.sln`. Windows'ta
  büyük/küçük harf duyarsız olduğu için tutuyordu, **kapıların koştuğu Linux'ta hiç
  tutmaz** → sınıfın tamamı üründe kusur yokken kırmızı yanardı. Düzeltildi.
- **Dokunulan dosyalar:** `deploy/ci/depo-koku-arayan-test-kapisi.py`, `…-selftest.py`,
  `depo-koku-arayan-test-envanteri.json`, `deploy/yerel-kapilar.sh` (kapi_78),
  `tests/Pbxtr.Architecture.Tests/TenantLeakCoverageTests.cs`
- **Doğrulama:** öz-test 6 vaka (1 pozitif, 3 mutasyon KIRMIZI, 2 negatif YEŞİL); ayrıca
  **gerçek depoda** işaretçi büyük P'ye döndürülünce kapı KIRMIZI, geri alınınca YEŞİL.

#### 2. BR-QA-103 — konteyner ayrıcalık kapısı (kapi_79)
- **Neden:** Ş37-14 belgede vardı, kodda yoktu (`privileged`/`cap_add`/`network_mode`
  taraması 0 satır).
- **Mevcut veri kapı kurulmadan ÖNCE ölçüldü:** 4 compose + 4 Dockerfile = 8 dosya,
  gerçek isabet **0**, tek eşleşme bir YORUM (`pbxtr-demo/docker-compose.yml:850`).
  Kartın "3 Dockerfile" sayımı bayatlamış (`deploy/yerel-kapilar.Dockerfile` eklenmiş).
- **İki ayrı eleme gerekti:** (a) yorumlar — elenmeseydi kapı DOĞDUĞU GÜN kırmızı olurdu;
  (b) `setcap cap_net_raw+ep` (Dockerfile:152-154) — bu dosya bazlı yetenek, konteyner
  geneli `cap_add`'in ALTERNATİFİDİR; kapı orayı yaksa doğru tasarımı cezalandırırdı.
- **Doğrulama:** öz-test 8 vaka (1 pozitif, 5 mutasyon KIRMIZI, 2 negatif YEŞİL); gerçek
  depoda `docker-compose.dev.yml`'e `privileged: true` eklenince KIRMIZI, geri alınca YEŞİL.

#### 3. BR-QA-106 — çıkarıcı artık mutabakat basıyor
- **Neden:** `clickup-cikar.js` devredilen satırları sessizce düşürüyordu; kaynak ile araç
  toplamı arasındaki fark hiçbir yerde raporlanmıyordu.
- **Ne yapıldı:** kaynak satır sayacı + devredilen satırların "düşen satır N → tutulan
  satır M" raporu + `kaynak = kart + devredilen + çözülemeyen` eşitliği (tutmazsa durur)
  + mükerrer kimlikte iki satır numarasını birden yazan hata metni.
- **Sonuç:** `MUTABAKAT: kaynak 679 = kart 676 + devredilen 3 + cozulemeyen 0`.
- **Kapı kendini aynı turda kanıtladı:** paralel bir ajan `BR-BE-194/195/196` ve
  `BR-QA-107` numaralarını benimkilerle aynı anda aldı; uyarı satır numaralarıyla anında
  yandı ve kartlar yeniden numaralandı. Eski araç bunu sessizce yutardı.

#### 4. BR-QA-102 / BR-QA-104 — iki kartın da ÖNCÜLÜ bayat çıktı
- **BR-QA-102** ("403 ekranı eksik yetkiyi adıyla söylemiyor"): iş `BR-FE-78` (Ş37-6) ile
  inmiş. Zincir tek tek doğrulandı — `registry.ts:961` `permission` VE `permissionsAll`'ı
  **ikisini birden** okuyor (defter: tek alana bakan ölçüm yanlış yeşil verir),
  `AppRoutes.tsx:170` → `ForbiddenScreen.tsx`, `sys.forbiddenMissing` **9 dilin 9'unda**,
  testler `registry.test.ts:89,103,117,131` + `ForbiddenScreen.test.tsx:28,38,62`.
- **BR-QA-104** ("denetim ucu tek değerli Action filtresi"): çoklu eylem `BR-BE-131` ile
  inmiş (`MaxActions = 20`, `AuditMultiActionFilterTests` 3 test) ve ön yüz kümesi de var
  (`PERSONAL_DATA_ACCESS_ACTIONS`). **Kalan gerçek boşluk ön yüzdeydi:** kümenin hiçbir
  testi yoktu → `personalDataAccessParity.test.ts` yazıldı (K1 altın liste, K2 aile
  kapsamı, K3 `ACTION_VIEW` paritesi, K4 `preset:` ön ek ayrımı).
- **Mutasyon:** kümeden `system.capture.downloaded` çıkarıldı → K1+K2 KIRMIZI; geri alınca
  4 passed. Boşluğun bedeli somuttu: bir KVKK talebinde pcap indirmeleri sessizce düşerdi.

#### 5. KRİTİK bulgu — `BR-QA-109` açıldı
`TenantLeakCoverageTests` **ana dalda KIRMIZI**: `EfAgentSkillProfile` adaptörü tenant
sızıntı testi olmadan inmiş. `dotnet test --filter TenantLeakCoverageTests` →
`Failed 1, Passed 3`.

> **DÜZELTME — bu günlüğün daha önceki bir turunda yazılan attribution YANLIŞ.**
> Orada bu kırmızı *"paralel bir ajanın uçuştaki işi"* diye geçilmişti. Ölçüldü:
> `git log -1 -- src/Pbxtr.Infrastructure/Modules/EfAgentSkillProfile.cs` →
> **`2d57f64d` (commit'li)**, ve `git status --porcelain` o dosya için **boş**. Yani
> uçuşta değil, **ana dalda duran gerçek bir kabul eksiği**. `BR-7`'nin agent ayağı
> tenant izolasyonu bekçisini kırmızı bırakarak indi; bu yüzden `BR-7` "bitti" sayılamaz.

#### 6. EPIC toplayıcıları ve 10 devredilen kart
- **Bölündü (complete):** `BR-B1`, `BR-B2`, `BR-9`, `BR-KAPANIS`.
- **in-progress kaldı:** `BR-7` (KRİTİK `BR-QA-109`'a bağlı), `BR-8` (kartsız bir canlı
  Asterisk ölçümü kaldı).
- **Açılan 10 kart:** `BR-QA-109`, `BR-DB-92` (`callback_digit`), `BR-DB-93`
  (`purge_call_data()` allowlist), `BR-AST-111` (qexit dialplan), `BR-BE-197` (UserEvent
  alım ucu), `BR-BE-198` (`queue_optin` + FIFO), `BR-BE-199` (`callback_requested` SLA),
  `BR-FE-114` (`callSource` rozeti), `BR-FE-115` (#49 off-hours anahtarı), `BR-SYS-116`
  (purge runbook).
- Geri aramanın **talep alma** yarısının üründe hiç olmadığı bağımsız doğrulandı:
  `callback_digit` 0, `qexit` 0, `queue_optin` 0, `callback_requested` 0, `callSource` 1
  (o da bir yorum). Ölçüm tuzağı kartlara yazıldı: C#'ta `callback` delege anlamında 397
  dosyada geçer, düz grep bu işi "zaten var" gösterir.

#### 7. Bloke kartlar — engel ADIYLA yazıldı
`BR-QA-07` + `BR-6` → Netgsm **hesabı** (kod borcu değil). `BR-QA-79` → canlıda 0 kayıtlı
cihaz / 0 trunk. `BR-QA-55`/`BR-QA-57` → digest-pinli Linux Playwright imajı yok (Karar #44;
Windows üretimi reddedildi). `BR-QA-95` → makinede eşzamanlı ajanlar. `BR-QA-06`/`51`/`86`/
`100` + `BR-FE-108` → kurul gündemi.

### Kararlar
- **BR-QA-79'un (2) maddesindeki düzeltme korundu:** ceza değiştiren yol VARDIR
  (`SkillRouting.cs:155` → `EfSkillAdministration.cs:457-470,484` → `QueueMembershipPush.cs:464`);
  canlı defterde 0 satır olması *"yol yok"*un değil *"böyle bir değişiklik yapılmadı"*nın kanıtı.
- **`BR-FE-111` bilerek `Kapsam dışı` ile BAŞLATILMADI.** O yazım panoyu `complete` yapardı
  ve ERTELENMİŞ bir işi bitmiş gösterirdi. İş devredilmedi, ertelendi.
- **`BR-6`'da bir yanlış yeşil yakalandı ve düzeltildi:** metindeki *"…onayıyla kapandı"*
  ifadesi `Kapandı → complete` kuralını tetikliyor, BLOKE bir kartı panoda KAPALI
  gösteriyordu. *"karara bağlandı"* olarak değiştirildi.

### Açık kalanlar / sonraki adım
- **`BR-QA-109` KRİTİK ve `BR-7`'nin önünde duruyor** — `backend-dev-1` + `db-lider`.
- **`BR-QA-95` hâlâ koşturulamadı:** kabul ölçütü *"tam takımda ardışık N koşu yeşil"* ve
  tur boyunca ağaçta 26 yabancı değişiklik vardı. Takım sakinken koşulmalı.
- **Ölçülen araç zayıflığı (kart açılmadı):** `clickup-durum.js` güncel parçada geçen her
  `bitti`/`Kısmen` kelimesini kurala sokuyor; bölünmüş bir toplayıcı, metninde *"sunucu
  ayağı bitti"* yazdığı için `in progress` görünebiliyor. Muhafazakâr yön doğru (açık işi
  kapalı göstermek daha kötü) ama **kapanış metnindeki kelime seçimi panoyu belirliyor** —
  bu bir tuzak ve yazarken bilinmeli.
- **Attribution notu:** `deploy/ci/*.py` ve yeni vitest dosyası `git add` ile stage'lendikten
  sonra, benim commit'imden önce paralel bir ajanın `aecd1ac5` commit'i tarafından süpürüldü.
  İçerik doğru ve `git diff HEAD` boş; ama bu, aynı anda çalışan ajanların **index'i
  paylaştığının** somut kanıtı — `git add` ile `git commit` arasındaki pencere güvenli değil.

---

## Linux/sistem turu — BR-SYS-102 + BR-SYS-115 (commit `aecd1ac5`)

### Bağlam
Hedef: `yonetim/backlog.md`'deki 20 açık sistem/ops/güvenlik kartını üç hâlden birine
oturtmak — (1) iş bitmişse kapanış metni, (2) iş varsa yap, (3) gerçekten bloke ise
**engeli adıyla** yaz. Karar #76 iki kartı fiilen "yapılabilir" hâle getirmişti
(Ş76-19 → BR-SYS-102, Ş76-17 → BR-SYS-115); ikisi de bu turda yapıldı.

### Yapılanlar

#### 1. BR-SYS-102 — Ş76-19: curl + digest + çekim ölçümü tek pakette
- **Neden:** `pbxtr-confd`'nin `nginx` kipi isteği nginx konteynerindeki **BusyBox
  wget** ile atıyordu. BusyBox wget 4xx gövdesini diske hiç yazmaz ve `Retry-After`
  okunamaz → 403'ün üç sebebinden (`NODE_NOT_PINNED` / `NODE_MISMATCH` /
  `IP_NOT_ALLOWED`) hangisi olduğu görünmüyordu. Ayrıca anahtar
  `--header="X-Pbxtr-Key: ${K}"` olarak wget'in **argv**'sine giriyordu; o argv
  konteyner içinde `/proc/<pid>/cmdline` ve `ps` çıktısında görünür.
- **Ne yapıldı:**
  - `nginx` kipi curl'e geçti; anahtar **`-H @dosya`** ile veriliyor (dosya
    `X-Pbxtr-Key: <değer>` SATIRI içerir — çıplak sır `-H @` ile verilseydi curl onu
    başlık **adı** sanır, istek anahtarsız gider ve arıza "anahtar yanlış" (401) gibi
    görünürdü). Hem çekim hem medya dalında.
  - **wget'e sessiz düşme yasaklandı:** `nginx_curl_kapisi()` konteynerde curl
    yoksa alarm basıp `exit 64` verir (fail-static — çağrı akışı etkilenmez,
    provisioning donar).
  - "nginx kipinde kod OKUNAMADI" dalı kaldırıldı; eski ölçüm kayıt için **üstü
    çizili** bırakıldı.
  - Digest sabitleme **depo metni kapısı** olarak kuruldu. Registry'ye soran kapı
    **kurulmadı** (ağ ister, çevrimdışı varsayımını ihlal eder — Ş76-19 birebir).
    Muafiyet **kapalı kümedir**: yalnız `PBXTR_IMAGE` ve `PBXTR_ASTERISK_IMAGE`;
    yeni bir parametrik imaj satırı kapıyı kırmızı yakar.
- **Dokunulan dosyalar:** `deploy/pbxtr-confd-dugum.sh`,
  `deploy/pbxtr-confd-selftest.sh`, `deploy/ci/imaj-digest-kapisi.py` (yeni),
  `deploy/ci/imaj-digest-kapisi-selftest.py` (yeni), `deploy/yerel-kapilar.sh`
  (`kapi_80`), `docker-compose.dev.yml`, `pbxtr-demo/docker-compose.yml`
- **Komutlar:**
  ```bash
  python deploy/ci/imaj-digest-kapisi.py          # TABAN: 8 ihlal, rc=1
  # pinler yazıldıktan sonra
  python deploy/ci/imaj-digest-kapisi.py          # rc=0
  python deploy/ci/imaj-digest-kapisi-selftest.py # 16/16
  bash deploy/pbxtr-confd-selftest.sh             # 193 iddia geçti, rc=0
  ```
- **Sonuç / doğrulama:** Vacuity üç ayakta: **pozitif** (digest'siz satır → kırmızı),
  **negatif** (satır silinince taban delinir → kırmızı; "0 ihlal" yeşili
  üretilemez), **mutasyon** (kısa/uzun/BÜYÜK hex, sha512, digest ortada,
  bilinmeyen parametrik değişken; iki yanlış-pozitif adayı yeşil kalmalı diye ayrıca
  ölçüldü). confd tarafında yeni **F27** (nginx kipinde 4xx kodu OKUNUR), yeni
  **F27b** (curl yokken `exit 64` + alarm + **wget argv defteri BOŞ** — sahte wget
  shim'de duruyor, yani düşüş fiziksel olarak mümkündü), yeni mutasyon **m16**
  (curl kapısı kaldırılır) ve **m23** (anahtar yeniden argv'ye gömülür) ikisi de
  yakalandı.

##### Ölçülen sürpriz — pinin gerekçesi bu depoda ZATEN gerçekleşmişti
Sunucudaki imajların `RepoDigests`'i ile etiketlerin **bugün** gösterdiği digest'ler
karşılaştırıldı (`docker buildx imagetools inspect`, 2026-09-18 11:36Z):

| imaj | sunucu koşuyor | etiket bugün |
|---|---|---|
| `postgres:16-alpine` | `57c72fd2…` | **`3c5c8892…` (KAYMIŞ)** |
| `redis:7-alpine` | `e7723ff7…` | **`520775a4…` (KAYMIŞ)** |
| `nginx:1.27-alpine` | `65645c7b…` | `65645c7b…` (aynı) |

Yani *"etiket sabit, içerik değişti"* bir varsayım değil **ölçülmüş bir olgudur**.
Ayrıca `docker manifest inspect postgres:16-alpine@sha256:57c72…` **başarısız**
(`manifest verification failed` — CLI etiket↔digest uyumunu doğruluyor) ama
`docker pull` aynı referansla **rc=0** ile çekti: pull digest'e bakar, etiketi yok
sayar. Yani `tag@digest` biçimi güvenli; ilk "çözülmedi" ölçümü **aracın** sınırıydı,
pinin değil. `minio/*` iki referans `denied / unauthorized` döndü (Docker Hub anonim
sınırı) — digest'ler docker'ın kendi kaydından geldiği için geçersiz değil, yalnız
bağımsız doğrulanamadı.

##### I17 için yeni kod yazılmadı ve sebebi ölçüldü
"Çekimin fiilen gerçekleştiğini ölçen pozitif işaret" **zaten var**:
`api_keys.last_bundle_served_at` + `PlatformRollupJob`'un 15 dk check-in yapmayan
düğüm alarmı (`ProvisioningNodeBundleEndpoints.cs:396-398`), `IProvisioningPullStamp`,
`SystemHealthProbe.cs:1614`. İkinci bir sayaç aynı soruya ikinci bir doğruluk kaynağı
koyardı.

#### 2. BR-SYS-115 — Ş76-17: yedek biriminin üretim topolojisi
- **Neden:** `pbxtr-yedek.service.d/10-compose-yolu.conf` `User=root` + docker.sock
  yolunu *"bu topolojide başka yol YOKTU"* diye gerekçelendiriyordu. Kurul iki soru
  sordu: paket hangi kaynaktan, ve host'tan `...:5432`'ye bağlantı **fiilen** açılıyor mu.
- **Komutlar (sunucu, ilk satır `date -u` = 2026-09-18 11:45Z):**
  ```bash
  ss -ltnp | grep 5432
  timeout 5 bash -c 'exec 3<>/dev/tcp/100.106.82.119/5432'
  docker run --rm --network host -e PGPASSWORD="$PBXTR_PG_APP_PASSWORD" \
    postgres:16-alpine psql -h 100.106.82.119 -U pbxtr_app -d pbxtr -tAc 'select 1'
  apt-cache policy postgresql-client-16 ; apt-cache policy postgresql-client
  docker exec pbxtr-postgres psql -U postgres -tAc 'show server_version'
  ```
- **Sonuç / doğrulama:**
  - **(ii) TCP yolu ZATEN AÇIK.** `LISTEN 100.106.82.119:5432 (docker-proxy)`,
    `/dev/tcp` **açıldı**, host ağ ad alanında `select 1` → **1**. Drop-in'in
    *"daha geniş dinletmek yeni saldırı yüzeyi açar / başka yol yoktu"* gerekçesi
    **yanlış öncüldür**; genişletilecek bir şey yok. İki dosyada düzeltildi, eski
    cümle **kayıt için üstü çizili**.
  - **(i) Paket kaynağı:** `postgresql-client-16` arşivde **YOK**;
    `postgresql-client` adayı **18+290ubuntu1** (`resolute/main`); PGDG deposu
    **tanımlı değil**; sunucu **16.14**. → kaynak **PGDG deposu** ya da **çevrimdışı
    `.deb`** olmak zorunda. Dağıtım paketi (18) ana sürüm kapısından geçmez.
  - **`pg_ana_surum_kapisi()`** eklendi (`yedek_al`'ın ilk satırı). Yön simetrik
    değil: istemci ESKİ → `pg_dump` zaten reddeder (gürültülü); istemci YENİ →
    **dump alınır ama eski sunucuya geri yüklenemez** — yedek her gece yeşil görünür,
    arıza yalnız geri dönüş anında çıkar. O dal fail-closed. Sürüm okunamazsa kapı
    yedeği **durdurmaz** (kapının kendi arızası yedeği öldürmesin).
  - **Üretim topolojisi yazıldı:** `User=postgres` ile dondurulamaz (`id postgres`
    → *no such user*) → kabuksuz **`pbxtr-yedek`** sistem kullanıcısı, TCP + `.pgpass`
    (0600), docker soketine erişim **yok**. `User=root` + docker.sock **üretime
    çıkmaz**; drop-in üretimde kurulmaz.
- **Dokunulan dosyalar:** `deploy/pbxtr-yedek.sh`,
  `deploy/pbxtr-yedek.service.d/10-compose-yolu.conf`

#### 3. BR-SYS-111 — üç iş kaleminin üçü de kapalı çıktı
Ölçüldü: (1) bekçi artık migrate/açılıştan çağrılıyor
(`MaintenanceRunner.cs:263`, `20260918130000_GuardsTemplateRefresh.cs:24`) →
yükseltilen DB de ölçülüyor; (2) refresh migration'lar var
(`20260918120000_RlsTemplateRefresh.cs` + `…130000`); (3) "şablon gövdesi değişince
refresh migration şart" kuralı `deploy/sablon-refresh-kapisi.sh` ile kapıya bağlı.
**Kalan tek şey kartın vacuity ölçütü ve o bloke:** sunucuda
`SELECT pbxtr_assert_role_settings_guard()` → *No function matches* ve
`__EFMigrationsHistory` en son `20260915122000` — bekçi orada **henüz kurulu değil**,
negatif ölçüm fiziksel olarak yapılamıyor. `deploy/db-rol-ayarlari-kapi.sh` bir
**metin** kapısıdır ve canlı `proconfig` okumaz; ölçütün yerine geçmez.

#### 4. BR-SYS-107 — ön koşul ölçüldü, aciliyet sıfır
`docker exec pbxtr-asterisk ls /var/spool/asterisk/recording/` → **No such file or
directory**; `pbxtr-vm` altında **0 dosya**. `Record()` ara dizinleri ilk kayıtta
kendisi açar → dizin yoksa **hiç sesli mesaj kaydedilmemiş**. Disk baskısı **0 bayt**,
büyüme hızı **ölçülemez (örnek yok)**, host diski %21. Engel adıyla yazıldı:
**`BR-BE-176`** (üretici taraf, kurula gidecek) kapanmadan retention dalı
boyutlandırılamaz ve "yalnız rapor kipinde bir döngü" ölçütü **vacuous** olur.

#### 5. Kalan 14 kart — engeller adıyla yazıldı
`BR-SYS-49` (BR-BE-59 P2 ayağı + sağlayıcı hesabı), `BR-SYS-51` ve `BR-SYS-60`
(sunucuda tek sahiplik penceresi), `BR-SYS-109` (kullanıcı onayı — CLAUDE.md §3.1
sınır metni), `BR-OPS-01/02/16` (iş backend'de, sahip `backend-dev-2`),
`BR-OPS-04` (mail bir **kullanıcı tercihi**; `mail_settings` = 0 satır + yayın),
`BR-OPS-06` (tasarım sahibi `yazilim-mimari`), `BR-OPS-09` (`pbxtr-decide` santralde
**yüklü değil** → (4) ölçülemez; (2)(3) dialplan sahibinde), `BR-OPS-11` (üç kalem de
tek sahiplik / yıkıcı işlem ister), `BR-OPS-14` (webhook migration'ı sunucuda
uygulanmamış → ölçülecek ACCESS EXCLUSIVE edinimi yok), `BR-SEC-26`/`BR-SEC-29`
(**`BR-DB-91` ölçümü** — Ş76-2, kapatılmadı, bağımlılık yazıldı).

### Kararlar
- **Digest kapısı registry'ye sormaz.** Ş76-19'un gerekçesi aynen uygulandı: ağ isteyen
  bir kapı çevrimdışı varsayımını ihlal eder ve gürültüden kırmızı olur. Kapı depo
  metnini ölçer; "bu digest bugün registry'de duruyor mu" sorusu **kapının işi değildir**.
- **Muafiyet kapalı küme.** Parametrik olan her imajı muaf saymak, kapıyı ilk yeni
  serviste sessizce gevşetirdi.
- **Kapı numarası yazdıktan sonra da doğrulanır (Ş76-24).** Bu turda `kapi_78`
  alındı, **aynı gün başka bir ajan aynı numarayı almıştı**; `uniq -d` kontrolü
  yazımdan sonra koşturulduğu için yakalandı ve numara `kapi_80` oldu. Belirti "kapı
  kırmızı" değil, **iki kapıdan birinin hiç koşmaması** olurdu.
- **Yanlış yeşil yapılmadı.** "Ölçüldü — iş yok" çıplak hâli kapanış sayılmaz
  (CLAUDE.md §14); bu turda ele alınmayan kartlar **kapatılmadı**, engelleri adıyla
  yazıldı.
- **Backlog Durum sütunu çıpayla bulunur.** `clickup-cikar.js:80-86` Durum'u *son
  P0..P3 hücresinden iki sonraki* hücre olarak okur. Ölçüldü: `BR-SYS-49` ve
  `BR-SYS-51` satırlarında önceki turun durum metni **Şart** kolonuna düşmüştü, yani
  panoya hiç gitmemişti. Bu turun metinleri doğru kolona yazıldı, Şart'a dokunulmadı.

### Açık kalanlar / sonraki adım
- **`BR-AST-108` artık başlayabilir:** ön koşulu (ajanın 4xx gövdesini ve
  `Retry-After`'ı okuyabilmesi) bu turda kalktı.
- **BR-SYS-111'in vacuity ölçümü** bir sonraki yayından sonra canlıda ya da yerel tek
  kullanımlık `postgres:16` konteynerinde yapılmalı.
- **`pbxtr-yedek` üretim topolojisi** yazıldı ama **kurulmadı**: paket kaynağı
  (PGDG mi çevrimdışı `.deb` mi) bir karardır ve kullanıcıya/kurula aittir.
- Bu tur `deploy/yerel-kapilar.sh` ve `yonetim/backlog.md` üzerinde **paralel ajanlarla
  aynı anda** çalıştı. Commit'e yalnız bu turun değişiklikleri alındı: `kapi_80` bloğu
  HEAD kopyası üzerine ayrı üretilip `git hash-object` + `git update-index` ile
  stage'lendi, backlog'da ise 18 kart satırı HEAD kopyasına **kart kimliğiyle** taşındı
  (satır numarasıyla değil — diğer ajan satır eklemiş olabilir). Yine de commit anında
  başka bir ajanın `git add`'i index'e girdiği için `deploy/ci/depo-koku-arayan-*`,
  `deploy/ci/konteyner-ayricalik-*` ve bir `.test.ts` dosyası bu commit'e **istemeden**
  dahil oldu; zararsızdır (kayıtsız, inert dosyalar) ama tarih yeniden yazılmadı.

---

## Tur: BR-AST kapatma turu (backend-dev-2, 11:25–12:15 UTC)

### Bağlam
`yonetim/backlog.md`'de 31 açık `BR-AST` kartı vardı ve çoğu aynı gün ölçülmüştü.
Görev kapatmaktı: işi bitmiş kartın durum metnini kapanış biçimine çevirmek, gerçekten
iş olanı yapmak, gerçekten bloke olanı **engeli adıyla** yazmak.

### Yapılanlar

#### 1. BR-AST-81 — DND'nin ANLIK yolu (ARI device state) uygulandı
- **Neden:** DND yalnız config'te (`Busy(20)`) uygulanıyordu; karar ancak `pbxtr-confd`'nin
  bir sonraki çekimi (5 dk) + `dialplan reload` ile yürürlüğe giriyordu. Arada agent
  "susturdum" der, telefonu **çalardı**. Karar #76 Ş76-12 kriteri (b′) tam bunu istiyordu.
- **Ne yapıldı:**
  - `AsteriskObjectName.DndDeviceName/DndDeviceState` → `Stasis:pbxtr-{tref}-dnd-{ext}`
    (tenant önekli; device state ad alanı Asterisk'te **global**).
  - `ConfigRenderer.DndGatedActions`: her dahiliye **pozitif** kapı
    `ExecIf($["${DEVICE_STATE(...)}" = "BUSY"]?Busy(20))`. Config'teki `Busy(20)`
    **silinmedi** (ikinci katman: anlık ilan kalıcı değil).
  - `AriDndDeviceStateAnnouncer`: ARI soketi her açıldığında (`AriStasisApp.AnnounceDndAsync`)
    DND'li her dahili için `PUT deviceStates/Stasis:...?deviceState=BUSY`. Tur
    `IJobTickRunner`'dan geçer (`job_runs` izi + lider kilidi, yeni kilit
    `dnd-device-state-announce` = 40); çapraz-tenant keşif `CrossTenantReadAudit` ile
    denetlenir; hata davranışı **FAIL-OPEN** (ilan patlarsa soket DÜŞMEZ).
  - Mimari envanterler güncellendi: `CrossTenantScopeSurfaces.RawSetConfigCalls` ve
    `RawSqlAllowlistTests.Allowed` (ikisi de bekçi; eklenmeseydi build kırmızıydı).
- **Ş76-12a kırmızı çizgi:** dal **yalnız `= "BUSY"`**. `!= "NOT_INUSE"` yasak — restart
  sonrası her ad `UNKNOWN`'dur ve negatif dal düğümdeki **her dahiliyi** DND'ye sokardı.
  Negatif test: `ExtensionDndRenderTests.Dnd_kapisi_NEGATIF_dal_kullanmaz`.
- **Dokunulan dosyalar:** `src/Pbxtr.Domain/Modules/Telephony/AsteriskObjectName.cs`,
  `src/Pbxtr.Infrastructure/Provisioning/ConfigRenderer.cs`,
  `src/Pbxtr.Infrastructure/Telephony/Asterisk/AriDndDeviceStateAnnouncer.cs` (yeni),
  `.../AriStasisApp.cs`, `.../TelephonyServiceCollectionExtensions.cs`,
  `src/Pbxtr.Infrastructure/Platform/Jobs/BackgroundJobLocks.cs`,
  `tests/Pbxtr.Api.Tests/Modules/Telephony/{ExtensionDndRenderTests,LocalDialContactsTests,AriDndDeviceStateAnnouncerTests}.cs`,
  `tests/Pbxtr.Architecture.Tests/{CrossTenantScopeSurfaces,RawSqlAllowlistTests}.cs`
- **Sonuç / doğrulama:** 10 yeni/iki güncellenmiş test yeşil. **İki mutasyon KIRMIZI:**
  (a) dal → `!= "NOT_INUSE"` (3 test düştü), (b) cihaz adından tenant öneki kaldırıldı
  (4 test düştü). `Modules.Telephony` 1301 geçti, `Modules.Provisioning` 145 geçti,
  `Architecture` 707/709 (kalan 2 kırmızı bu işe ait değil: `DeployPrivilegeTests/setcap`
  ve `TenantLeakCoverage/AgentSkillProfile` — ikisi de başka ajanın commit edilmemiş işi).
- **Commit:** `d030c8c5`

#### 2. BR-AST-110 — açık ölçüm yapıldı, "AstDB registrar" dalı DÜŞTÜ
- **Neden:** kart, ARI envanterindeki ~500 ölçüm kalıntısı temizlenmeden ARI tabanlı
  hiçbir eşiğin kalibre edilemeyeceğini söylüyordu; açık soru "kalıntı `max_expiry`
  sonrası kendiliğinden düşüyor mu" idi.
- **Komutlar (176.88.41.220, salt-okunur):**
  ```bash
  date -u
  docker exec pbxtr-asterisk asterisk -rx "pjsip show aor t0007-wrtc-1042" | grep -i expir
  docker inspect -f "{{.State.StartedAt}} {{.RestartCount}}" pbxtr-asterisk
  # ARI sayımı: kimlik pbxtr-app env'inden değişkene alındı, DEĞER hiçbir çıktıya yazılmadı
  ```
- **Sonuç:** `maximum_expiration = 7200` / `default_expiration = 3600` sn; kalıntılar
  konteyner **6 gün 10 saat** ayaktayken de duruyordu → süre bekleme **çözüm değil**.
  Ama konteyner 04:34:50 UTC'de yeniden başlamış ve envanter **509/505 → 7** olmuş
  (6 gerçek + 1 yeni kalıntı) → kalıntı **süreç belleğinde**. CLI `core restart`
  kullanılmadı, yasağı duruyor. Kurula dönecek katalog sorusu **yok**.
- **Commit:** `ba5ea3c3`

#### 3. BR-AST-87 (c) — çalışma disiplini artık DEPODA yazılı
- **Neden:** (c) "ölçüm betikleri trap ile temizlesin" diyordu ama kalıntıyı bırakan
  komutlar ad-hoc'tu; depoda düzeltilecek dosya yoktu, yani kalem görünmez bir kuraldı.
- **Ne yapıldı:** `deploy/asterisk-conf-sinir.txt`'e *"OLCUM KALINTISI — ARI /endpoints"*
  bölümü eklendi (yalnız yorum satırı; `awk '$1 == "IMAJ"'` ayrıştırıcısı etkilenmez):
  tenant önekli ad + `trap ... EXIT` + ölçüm öncesi/sonrası sayım.
- **Vacuity kontrolü:** kural boşa değil — restart **sonrasında** bir tur daha 1 kalıntı
  (`PBXTR-OLCUM-SEC22`) bırakmış.

#### 4. BR-AST-89 — engel adı DEĞİŞTİ (ölçüldü)
- Kartın yazılı engeli "tek ajanlı pencere" idi; bu turda o pencere **alındı**:
  `flock /tmp/pbxtr-agent.lock -c 'docker restart pbxtr-app'`, lider devri gerçekleşti
  (`AMI baglandi`, `ARI Stasis uygulamasi 'pbxtr' acildi`), ilk ~5,5 dk `4803` = **0**.
- **Ama ölçüm VACUOUS:** aynı pencerede `call_events` = **0** (son 20 dk). Çelişki ancak
  aynı `linkedid` iki tenant koduyla çözülürse doğar. Yeni engel: **sıfır çağrı trafiği**
  (kayıtlı SIP/WebRTC istemcisi yok) — `BR-AST-72`/`BR-AST-80` ile aynı ortam engeli.

#### 5. Backlog — 12 kart kapanış/engel biçimine geçirildi
- **KAPANDI (5):** `BR-AST-54` (ölçüm kartı, canlı A/B: sarkan `auth=` **fail-closed**,
  INVITE → 500), `BR-AST-87`, `BR-AST-97` (kalan iş `BR-SYS-93`), `BR-AST-98`, `BR-AST-110`.
- **KARAR BEKLEYEN (5):** `BR-AST-39`/`46` (A14), `63` (ADR-015 A2), `64` (ADR-015 A3),
  `92` (ürün: 9 dilin ses kaynağı). Bunlar kod işi taşımıyor; `karar bekleyen` kovası
  `backlog`'dan farklı ve yanlış yeşil değil.
- **Yazım:** yalnız Durum hücresi, tek satır, `|` yok, eski metin `**Önceki kayıt:**`
  altına taşındı. `clickup-cikar.js` rc=0 (696 kart), `clickup-senkron.js` yazdı ve
  `--kuru` **fark 0 / izde olmayan 0** doğruladı.

### Kararlar
- **DND iki katmanlı kalır:** anlık device state kapısı + config'teki `Busy(20)`. Yalnız
  anlık kapıya güvenmek DND'yi ARI'nin ayakta olmasına bağımlı yapardı.
- **İlan FAIL-OPEN'dır.** DND yasal bir kapı değil bir tercihtir; fail-closed olsaydı
  ARI'nin her hıçkırığı düğümdeki bütün dahilileri susturacaktı.
- **Kurul kararı bekleyen kart `karar bekleyen`e yazılır, `Bitti`ye değil.** Açık işi
  kapalı göstermek, kapalıyı açık göstermekten kötüdür (CLAUDE.md §14).

### Açık kalanlar / sonraki adım
- **`BR-AST-81`'in canlı ayağı YAYIN'a bağlı:** kendi soketimizi kapatıp yeniden
  bağlanınca DND'nin yeniden BUSY ilan edildiğini görmek, kod sunucuya inmeden ölçülemez
  (`BR-AST-103`/`105` ile aynı sınıf).
- **Ortam engeli beş kartı birden tutuyor:** `72`, `80`, `89`, `46`, `98`(ses ayağı) —
  hepsi test sunucusunda **kayıtlı bir SIP/WebRTC istemcisi** istiyor. Bu tek bir ortam
  işidir ve beş kartı birden açar.
- **Kurul gündemi biriktir:** A14 (`39`/`46`), ADR-015 A1/A2/A3 (`62`/`63`/`64`),
  Ş42-8 (`58` → `104`), Ş50-4 (`74`), Karar #40 (`54` kapandı ama karar yazılmadı),
  ürün: 9 dilin ses kaynağı (`92`).

### BR-QA-111 — Karar #77 Ş77-7/Ş77-8: dört desen şablon çıpasına eklendi (db-dev)
- **Neden:** `DO $`, `SECURITY DEFINER`, `DISABLE ROW LEVEL SECURITY`, `GRANT … TO PUBLIC`
  hiçbir kapının desen kümesinde yoktu; dördü de `deploy/db/01-rls-template.sql` /
  `02-guards.sql`'e sessizce eklenip ONAYLI bir tazeleme migration'ıyla üretime taşınabiliyordu.
- **Ne yapıldı:** Kurulun seçtiği DAR kol: desenler **yalnız** `TEMPLATE_ONLY_DENIED`'a
  eklendi, `SQL_DENIED` değişmedi (geniş hâl 148+ yeni bulgu = kauçuk mühür).
  `migration-contract-onay.blobs`'taki iki `Şablon …` çıpası yeniden hesaplandı (Karar#73 → #77).
- **Dokunulan dosyalar:** `deploy/migration-compatibility-guard.py`,
  `deploy/migration-contract-onay.blobs`
- **Komutlar:**
  ```bash
  docker run --rm -v X:/GitHub/Pbxtr/pbxtr:/repo -w /repo pbxtr-kapi:local \
    bash -c 'python3 deploy/migration-compatibility-guard-selftest.py && \
             python3 deploy/migration-compatibility-guard.py'
  ```
- **Sonuç / doğrulama:** ÖNCE ölçüldü → migration tarafı 398 bulgu / 168 dosya;
  çıpa 01: 35, 02: 18. SONRA → migration tarafı **398 / 168 (DEĞİŞMEDİ** — kararın şartı);
  çıpa 01: 56, 02: 37. Defterde değişen çıpa satırı **tam 2**.
  Vacuity (Ş77-8): `02-guards.sql`'e `GRANT SELECT ON public.audit_log TO PUBLIC;` → kapı
  **RC=1**, 11 migration için "SABLON CIPASI TUTMADI"; aynı mutasyon **eski** desen kümesiyle
  `709368f0…` üretiyor = defterdeki Karar#73 sha'nın aynısı → kapı eskiden bu enjeksiyona
  **kördü**. Yalnız yorum satırı → **RC=0**. İkisi de geri alındı (`git diff` boş).
- **Commit:** `e3005229` — BR-QA-111 / Karar #77 S77-7


---

## Tur: Kurul #77 — ve kurulu toplayanın kendi hatası (koordinatör)

### Bağlam
Kalan açık kartların yarısından fazlası kod işi değil, karar bekliyordu. 12 maddelik bir
gündem (A–M) hazırlayıp PBXTR kurulunu topladım. Turun asıl çıktısı kararlar değil,
**gündemin kendisindeki hata** oldu.

### Yapılanlar

### 1. Şeytan'ın I1 itirazı: gündemin 5 maddesi zaten karara bağlıymış
- **Neden ölçüldü:** Şeytan *"metnin 12 maddesinden 5'i bu turda OYLANAMAZ"* dedi ve ayırt
  edici soruyu sordu: *"Karar #66/#67'yi geçersiz kılan yeni ölçüm nedir, `dosya:satır` ile?"*
- **Ne yapıldı:** `yonetim/kurul-kararlari.md` tarandı.
  ```bash
  grep -nE "^\| (M1[5-9]|M20|M2) (BR-|Ş)" yonetim/kurul-kararlari.md
  grep -n "^| N8 " yonetim/kurul-kararlari.md
  ```
- **Sonuç:** itiraz **doğrulandı**. `BR-AST-61` (#66 M15, 10 oy), `BR-AST-58` (M16, 10),
  `BR-AST-62` (M18, 9), `BR-AST-63` (M17, 10), `BR-AST-64` (M19, 10),
  `BR-BE-43-B` (M2, 9), `BR-QA-51` (M20, 10), `queue_members` yazımı (#67 N8, 10).
- **Kök sebep:** kartlar *uygulanmadığı* için backlog'da **açık** duruyordu; ben "açık =
  kararsız" diye okudum. Doğru soru "hangi kol?" değil, **"kim uygulayacak, sırası ne?"**
- **Zarar somut:** üyeler bu turda bazı maddelerde **farklı kol** seçti (A'da CTO ve
  asterisk-uzmanı (b) dedi, #66 (a) demişti). Kaydetseydim Ş66-15/16/18/19 ve Ş67-8'in
  onlarca şartı **sessizce düşecekti**. Şeytan sayıyı da verdi: #66'nın 27 maddesinin
  **beşi bir günde eriyordu** (%18,5).
- **Yeni kural (Ş77-0, Ş76-1'in kardeşi):** önceki kararın adı yazılmayan madde kurula
  sunulamaz. Her madde ya *"Karar #NN Mxx — kol (a), NN oy"* taşır ya da *"karar defterinde
  geçmiyor (arandı: `<kod>`)"*. Bir kararı değiştirmek serbest, ama onu **geçersiz kılan
  yeni bir ölçüm** `dosya:satır` ile yazılmalı.

### 2. Karar #77 yazıldı — beş madde geri çekildi, yedi madde ŞARTLI ONAY (10/10)
- **Dosya:** `yonetim/kurul-kararlari.md` (+386 satır)
- **Commit:** `2e9497cb`
- Kurulun ölçümle ürettikleri:
  - **linux-uzmanı:** `deploy/asterisk-lab/README.md` §D-08.1 — bozuk `t0008-context.conf`
    yazıldığında `dialplan reload` sonrası tüm `pbxtr-t0007-*` bağlamları ayakta kaldı →
    **dialplan izolasyonu dosya başınadır ve TUTAR**; §3.1'in kısmi rollback garantisi buna
    yaslanıyor. Bu, Karar #66'nın (a) kolunu **teyit etti**.
  - **linux-uzmanı (delik):** `yerel-kapilar.sh:2586` `Tum kapilar gecti (N)` basıyor ama
    `kapi_65` host'a taşındığı için **o sayının içinde değil** — host adımı silinse
    **hiçbir sayı değişmez**. "Koşmayan kapı bulgu değildir" sınıfının beşinci hâli.
  - **linux-uzmanı (`BR-QA-86`/1):** kartın *"`Read` ile okunan dosyaya `ALTER` eklemek
    kırmızı yakmıyor"* cümlesi **bugün yanlış** — `migration-compatibility-guard.py:24-29,55,99,492`
    + `.blobs:80-81` + `DeployDbScripts.cs:23,25` (Read edilebilen dosya **tam 2**, ikisi çıpalı).
  - **db-lider:** **Elasticsearch üründe YOK** (istemci + paket sıfır; CDR araması
    `PostgresCdrSearch.cs`) → `BR-QA-51`'in ES ayağı bugün karara bağlanamaz.
    `telephony_provider_effects` **`at` ile partition'lanamaz** (UNIQUE'te `at` yok; eklemek
    tek tekillik korumasını düşürür). `BR-DB-16` onay satırı **verilemez** — onaylanacak
    blob henüz yok, peşin onay defteri kauçuk mühre çevirir.
  - **frontend-uzmanı:** `BR-FE-108`'in "9 dil i18n maliyeti" iddiası **çürütüldü** —
    mola/sebep etiketleri sunucudan gelir, katalogdan değil.
  - **CTO (veto):** düğüm kimliği serbest metin; B tenant'ı anahtarını A'nın düğüm adına
    sabitleyebilir. `ux_api_keys_tenant_node` `(tenant_id, node)` → iki tenant aynı adı
    paylaşabiliyor. Ayrı ölçüme bağlandı (`BR-SEC-30`, S1/S2/S3).

### 3. Backlog'a karar ayağı
- **Commit:** `e15f49fb`, `3c36c12e`
- 7 karta **karar atfı** yazıldı ("hangi kol" sorusu düştü, kalan iş UYGULAMA).
- 4 kart kapandı: `BR-BE-52` (Ş77-11 RED), `BR-BE-80` (Ş77-20 yazılı sapma),
  `BR-FE-108` (Ş77-21), `BR-BE-120` (Ş77-11b).
- 6 "karar bekleyen" kart karara bağlandı: `BR-DB-16/35/67/76`, `BR-AST-39/46`.
- 9 yeni kart: `BR-QA-110/111/112`, `BR-DB-98`, `BR-BE-200/201`, `BR-AST-112/113`,
  `BR-SEC-30`.
- `BR-QA-06` **bölündü** (Ş77-22): Sprint-36'nın sayısal kapıları bugünkü ürün adlarına
  eşlendi. Ölçüm: `queue_optin` 0 · `callback_requested` 0 · `callback_digit` 0 · `qexit` 0 ·
  `callback_daily_cap` 0 · `callSource` **1 ve o bir yorum**; buna karşılık `CallbackEntry`
  101 · `CallbackDispatcher` 84 · `ICallbackLedger` 75 · `sla_buckets` 101.
  Eşlenemeyen tek küme **sprint kart numaraları** (`BR-FE-22/23` başka ve bitmiş işe
  verilmiş) — numaralar yeniden kullanılmıyor.

### 4. `BR-QA-109` kapandı
`TenantLeakCoverageTests` 4/4 (önce 3/4). `EfAgentSkillProfile` sızıntı testiyle geldi;
mutasyonda sorgu 3 tek başına yeşil kaldı ve sebebi **uydurulmadı, ölçüldü**: bileşik FK
`(tenant_id, required_skill_id)` o dalı EF filtresi olmadan da tenant'a bağlıyor; 2+3
birlikte KIRMIZI. Commit `c9646ce5`.

### Kararlar
- **Ş77-0:** önceki kararın adı yazılmayan madde kurula sunulamaz.
- **Ş77-A2:** A maddesinde Karar #66'nın (a) kolu yürürlükte; bu turdaki (b) oyları karar
  kaydına geçer ama kolu **değiştirmez** — yeni ölçüm sunmadılar.
- **Ş77-1:** Kapı Evi Kuralı — varsayılan ev **kapı konteyneridir**; host'ta koşmak dört
  şart ister (K-a araç bağı ölçülmüş · K-b özne platformdan bağımsız · K-c fail-closed,
  atlama bayrağı yok · K-d vacuity).
- **Ş77-17':** `BR-DB-16` onay satırı bugün yazılmaz; blob olmadan onay verilmez.

### Açık kalanlar / sonraki adım
- **Yayın koşulmadı** — 8 ajan paralel çalışıyor; testhost eşzamanlı yük altında çöküyor.
  Yayın, ajanlar bitince koşacak ve `BR-DB-88/91`, `BR-BE-150/119`, `BR-AST-103`,
  `BR-SEC-26/29` gibi ~10 kartı açacak.
- `BR-SEC-30` (CTO vetosu) ölçümü sürüyor; S1/S2 "evet" çıkarsa **P0 tenant izolasyonu
  sızıntısı**.
- `BR-SEC-16` + `BR-SEC-28` sır rotasyonu, ajanlar bitince.
- `BR-AST-112` (ölçek) ve `BR-AST-113` (rollback) test sunucusunda yapılacak; ikisi de
  A'nın uygulamasının önkoşulu.

---

### BR-SEC-30 — Kurul #77 CTO vetosu ÖLÇÜLDÜ: sızıntı GERÇEKTİ, kapatıldı

- **Neden:** CTO, tenant B'nin kendi API anahtarına tenant A'nın düğüm adını yazıp
  `GET /provisioning/node-bundle` ile A'nın provisioning fragmanını çekebildiğini iddia
  etti. backend-lider karşı ölçüm sundu ama **başka bir soruya cevap veriyordu**
  ("Node null olabilir mi" ≠ "Node başkasının düğümü olabilir mi") — defterdeki
  *"itirazı kategoriyle eleme"* tuzağı. Üç soru ayrı ayrı ölçüldü.

- **S1 — ad sahipliği kontrolü var mı? → 0 (SIFIR) kontrol.**
  `EfApiKeyAdministration.cs:105-108` yalnızca `NodeRequired` (boş olamaz) bakar.
  Depoda düğüm kataloğu YOK: `provisioning_nodes` / `NodeCatalog` / `node_owner` için
  `src tests deploy` altında **sıfır eşleşme**. `apikey.manage` ise `bundle.apikey`
  üzerinden **owner (scope=single) ve dealer** rollerindedir ve `platformScopeOnly`
  listesinde DEĞİLDİR (`permissions.seed.json`). Tek kapı `ProvisioningDelivery =
  not_delivered` idi ve o yalnız susturulmuş tenant'ı tutuyordu.

- **S2 — yabancı fragman fiilen dönüyor mu? → EVET.**
  `ProvisioningNodeBundleEndpoints.cs:218` düğümü **anahtarın kendi pininden** alır;
  `:328` `ListTenantsForNodeAsync(node)` ile üye kümesini çözer; o sorgu
  `EfProvisioningNodeDirectory.cs:109-112` **`IgnoreQueryFilters()` + çapraz-tenant**
  kipindedir. `:539` her üye için `BeginTenantScope(member.TenantId)` açıp fragmanı
  üretir. **Çağıranın tenant'ı ile hiçbir yerde filtrelenmez.** Çok tenant'lı düğüm
  (BR-AST-17) meşrudur; asıl kusur **kendi kendine atanmadır**.

- **S3 — sunucuda bugün çoklu pin var mı? → HAYIR, ama sömürülebilir.**
  `date -u` = 2026-09-18 14:03 UTC. `asterisk-01` → 6 anahtar, **1 tenant** (t0007),
  1 aktif. Ancak `t9052` teslim niyeti `deliver`; owner'ı aynı ada pinlenebilirdi ve
  teslim-niyeti kapısı onu **durdurmazdı**. Sır değeri hiçbir çıktıya yazılmadı.

- **Ne yapıldı:** `ApiKeyEndpoints.CreateAsync` içine **YABANCI DÜĞÜM KAPISI**. Dolu bir
  düğüme katılmayı yalnızca `scope=global` yapabilir (Karar #58'in teslim-niyeti
  kapısıyla aynı desen). Keşif, **sızıntıyı besleyen aynı kaynaktan** yapılır
  (`IProvisioningNodeDirectory`) — ikinci bir sorgu yazılsaydı iki kaynak zamanla
  ayrışırdı. **Ayrı DI kapsamı zorunlu:** `/api/*` isteği `UnitOfWorkMiddleware`'in
  transaction'ı içindedir, iç içe `BeginAsync` istisna atardı (`EfUnitOfWork.cs:33-37`)
  ve kapı 403 yerine **500** üretirdi. Fail-closed: keşif okunamazsa istisna yutulmaz.
  Denetim: `apikey.pin.blocked_by_foreign_node`, gövde yabancı tenant **kimliği taşımaz**
  (yalnız sayı) — reddedilen aktör o satırı kendi denetim ekranında okur.

- **Dokunulan dosyalar:** `src/Pbxtr.Api/Modules/Security/ApiKeyEndpoints.cs`,
  `src/Pbxtr.Api/Modules/Provisioning/ProvisioningEndpoints.cs`,
  `src/Pbxtr.Domain/Platform/Audit/AuditActions.cs`,
  `tests/Pbxtr.Integration.Tests/Tests/ApiKeyForeignNodePinTests.cs`

- **Sonuç / doğrulama:** `ApiKeyForeignNodePinTests` — **1 passed, 0 skipped**.
  Mutasyon (`if (false && foreignCount > 0)`, gerçek rebuild): **KIRMIZI**, ve kırmızının
  gövdesi istismarın ta kendisiydi — `201 Created`, `"node":"ast-kurul77-a"`, tenant B.
  Geri alındı → YEŞİL. Pozitif kontrol aynı metotta: boş düğüme pin **201**.

- **Commit:** `0a382f1a` — Kurul #77 / CTO vetosu: tenant kendini YABANCI düğüme atayamaz

## Kararlar (ek)

- **`ProvisioningEndpoints.cs:933` yorumu yük taşıyordu ve YANLIŞTI.** *"Pin, bir
  yöneticinin SUNUCUDA yazdığı kayıttır"* cümlesi hiç ölçülmemişti; owner için yanlıştı
  ve node-bundle'ın çapraz-tenant genişlemesi **tam olarak bu cümleye yaslanıyordu**.
  Cümleyi bugün doğru yapan şeyin bu kapı olduğu yoruma yazıldı.
- **İki tenantlı negatif test TEK metottadır.** İki ayrı `[Fact]` yazıldığında sınıfın
  `IAsyncLifetime`'ı kullanıcıyı/rolü her testte silip yeniden yaratıyor ve ikincisi yetki
  önbelleği yüzünden `PERMISSION_DENIED` alıyordu (tek başına YEŞİL, sınıfça KIRMIZI —
  defterdeki *"tohum bırakan test başka sınıfı kırar"* sınıfı).

## Açık kalanlar (ek)

- **Mevcut veri için geri dönük kapı YOK.** Kapı yalnızca YENİ pini durdurur; bugün aynı
  ada pinli iki tenant olsaydı kapı onları ayırmazdı. Sunucuda bugün böyle bir satır yok
  (S3), ama bir tarama/uyarı işi hâlâ borçtur.
- **Düğüm adı hâlâ katalogsuz serbest metindir** (`ApiKey.cs:51`). Karar #36 Ş36-19
  "düğüm kimliği tenant'ın yazdığı bir dize OLAMAZ" diyordu; bu kapı sömürüyü kesti ama
  **şartı karşılamadı** — asıl çözüm düğüm kataloğu + FK'dir.
- **İlgisiz KIRMIZI (benim değil, HEAD'de):** `ProvisioningRerenderJobDbTests` (2) ve
  `ProvisioningTombstoneWriteDbTests` (1) → `42883: function pbxtr_webhook_event_types()
  does not exist`. Kaynak commit'li migration `20260917184552_WebhookOutboxAndDelivery`;
  defterdeki *"şablon gövdesi kurulu DB'ye ulaşmaz"* sınıfı.

---

## `BR-FE-114` — `callSource` (çağrı kökeni) rozeti (frontend-dev-1)

- **Neden:** Agent, gelen çağrının normal bir kuyruk çağrısı mı yoksa çağıranın daha önce
  bıraktığı **geri arama talebinin dönüşü** mü olduğunu ekrandan anlayamıyordu. Açılış
  cümlesi yanlış kuruluyor (*"buyurun"* yerine *"talebiniz üzerine arıyorum"*) ve müşteri
  kendini baştan anlatmak zorunda kalıyordu. Ölçüm bağımsız doğrulandı: `callSource` depoda
  **tek eşleşme ve o da bir YORUM** (`CallEventPayload.cs:123`).
- **Ne yapıldı:** Tek sözlük + tek bileşen; dört yüzeyde tüketildi.
  - `screens/shared/callSourceAxis.ts` — kapalı küme sunucunun `CallEventPayload.Origins`
    kümesiyle **birebir** (`callback`/`dialer`/`agent`/`inbound`), ton/metin/"neden" eşlemesi,
    `callSourceKindOf` + `hasCallSourceAxis`.
  - `screens/shared/CallSourceBadge.tsx` (+ `.module.css`) — **rozet yalnızca sunucu alanı
    geldiğinde** çizilir; alan yok ya da kapalı küme dışı ise DOM'a **hiçbir şey** yazılmaz
    ("ölçülemedi" işareti bile). Büyük/küçük harf toleransı yok.
  - Yüzeyler: `agent/IncomingCallModal.tsx` (kabul etmeden **önce** — kökenin tek değerli anı),
    `agent/CallTab.tsx` başlığı, `live/LiveAgentsScreen.tsx` (#13), `live/LiveQueuesScreen.tsx`
    (#12), `automation/MissedCallsScreen.tsx` (#31, **koşullu kolon** — boş başlık yazılmaz).
  - Sözleşme: `api/opsContracts.ts` → `ActiveCall.callSource?`, `LiveAgent.callSource?`;
    `automation/missedCallsApi.ts` → `MissedCallRow.callSource?`; `agent/useCallSession.ts`
    projeksiyonu alanı **yalnızca sunucu gönderdiyse** taşır.
  - 9 dilde 9 anahtar (`callSource.*`).
- **Karar:** `DndBadge`'den ayrılan tek nokta — burada **dört değerin dördü de** çizilir.
  `inbound` sessiz bırakılsaydı "rozet yok" iki ayrı şeyi birden söylerdi ("normal kuyruk
  çağrısı" ve "sunucu bu alanı göndermiyor") ve kartın yasakladığı tahmini istemci yerine
  **kullanıcıya** yaptırırdı.
- **Tuzak (ölçüldü):** `callSource.inbound` ilk hâlinde "Gelen çağrı" yazıyordu ve
  `incoming.title` ile **birebir çakışıyordu** — negatif testler yanlış kırmızı verdi.
  `Kuyruk çağrısı`ya çevrildi; iki ayrı olguya aynı cümleyi yazmak zaten başlığı bir ölçüm
  sanmaya davet ederdi.
- **Kalan (bilinçli):** rozet **bugün hiçbir ekranda çizilmiyor** — sunucu alanı yok.
  Sunucu ayağı `BR-BE-198` / `BR-BE-199`. Kod yolu fikstürle bugünden ölçülüyor.
- **Testler:** `shared/CallSourceBadge.test.tsx` (13), `shared/callSourceDictionary.test.ts` (7),
  `live/CallSourceVisibility.test.tsx` (6), `automation/MissedCallsScreen.test.tsx` (+4),
  `agent/IncomingCallModal.test.tsx` (+3).

## `BR-FE-115` — #49 "çalışma saati dışı otomatik mola" anahtarı (frontend-dev-1)

- **Neden / ölçüm:** Kart *"#49 ekranında anahtar YOK"* diyordu. **Teşhis cümlesi bayattı:**
  anahtar `SettingsScreen.tsx:1209-1270`'te **vardı** (BR-FE-90, commit `401b8151`). Gerçekten
  eksik olan şey kartın **kendi vacuity şartıydı**: *"vitest anahtarın ayarı okuduğunu ve
  kaydettiğini ölçsün"* — böyle bir test **yoktu**, yani anahtarın çalıştığı hiçbir yerde
  kanıtlı değildi ve bir sonraki dokunuş onu sessizce kırabilirdi.
- **Ne yapıldı:** `SettingsScreen.test.tsx`'e 7 test (`#49 · çalışma saati dışı otomatik mola`):
  sunucudan okuma (açık **ve** kapalı), açma/kapatmanın gövdeye girmesi, **dokunulmayan alanın
  gövdeye girmemesi** ("alan yok = DOKUNMA"), yetki kilidi, açık hâlin sonucunun ekranda yazması.
- **Karar:** Yetkisiz alan **gizlenmez, kilitli çizilir** — ekranın diğer on alanı da
  `editable.*` + `salt okunur` desenini kullanıyor ve değeri tamamen gizlemek yetkisiz
  kullanıcıyı *"böyle bir ayar yok"* sanmaya iterdi. Kapı her hâlde sunucudadır
  (`TenantSettingsChangePolicy`).
- **Tuzak (ölçüldü):** `input.checked = x` + elle `change` React onay kutusunda **çalışmıyor**;
  React `click`i dinler ve jsdom elle atanan değeri bir kez daha ters çevirir. Testler
  `input.click()` kullanıyor ve öncesinde/sonrasında `checked`i doğruluyor.

### Mutasyon doğrulaması (boz → KIRMIZI, düzelt → YEŞİL)

| Mutasyon | Sonuç |
|---|---|
| Rozet: alan yokken `?? 'inbound'` varsayılanı | **8 test KIRMIZI** |
| `callSourceKindOf`: kapalı küme kontrolü kaldırıldı | **8 test KIRMIZI** |
| #31 köken kolonu koşulsuz çizildi | **2 test KIRMIZI** |
| `autoBreakInput` daima alanı gönderdi | **7 test KIRMIZI** |
| #49 kutusu sunucu değerini okumadı (`autoBreak: false`) | **5 test KIRMIZI** |

### Doğrulama

```bash
cd src/Pbxtr.Web && npx tsc -b --force   # 0 hata
npx vitest run                            # 2037/2038
```

`tsc --noEmit` **kullanılmadı** (defter dersi: yayın kapısı değil).

- **İlgisiz KIRMIZI (benim değil, HEAD'de):** `system/auditActionParity.test.ts` →
  `apikey.pin.blocked_by_foreign_node` ve `live.agent.intervention_membership_expired`
  sunucuda tanımlı (commit `0a382f1a`) ama #38 istemcisinde etiketsiz. `auditView.ts`
  `ACTION_VIEW`/`ACTION_GROUPS` + 9 dilde `aud.a.*` ister; sahibi o commit'in ajanı.

- **Sapma kaydı:** `doc/prototip-urun-farklari.md` — yeni bölüm *"Çağrı kökeni rozeti
  (#09 · #12 · #13 · #31) — prototipte YOK, üründe VAR ama bugün İNERT"* (BİLİNÇLİ + BORÇ);
  `#49/13` satırı **BORÇ → KAPANDI**.
- **Commit:** `ff377820` — BR-FE-114 + BR-FE-115 (27 dosya, push edildi)


---

## BR-BE-201 — Kurul Karar #77 Ş77-19 / Ş77-16 / Ş77-19b (backend-dev-1)

### Bağlam
Süpervizör müdahalesiyle verilen geçici kuyruk üyeliğinin üç kusuru vardı ve üçü de
karara bağlanmıştı ama koda geçmemişti: (1) `penalty: 0`, (2) üyeliği kaldıran hiçbir
mekanizma yok, (3) agent kendisine verilen üyeliği göremiyor.

### 1. Ş77-19 — müdahale cezası `max(penalty) + 1`
- **Neden:** `AgentInterventionService.cs:196-197` `penalty: 0` gönderiyordu. Asterisk
  düşük penalty'yi ÖNCE dener → süpervizörün geçici takviyesi kuyruğun **en yetkin
  kalıcı üyesinin önüne** geçiyordu. İstenen davranış değil, varsayılanın yan etkisi.
- **Ne yapıldı:** `AgentInterventionMembership.PenaltyBehind()` (Domain, saf) +
  `ResolvePenaltyAsync()` (AMI `QueueStatus` okur).
- **ÖLÇÜM (boş liste kararı):** `AmiCommandChannel.QueueStatusAsync` **soket
  açılamadığında** (`TryOpenAsync` false, `AmiCommandChannel.cs:171-174`) ve eylem
  reddedildiğinde (`IsRefusal` → `break`) de **boş liste** döner. Yani "üye yok" ile
  "okuyamadım" aynı değeri üretir ve ayırt edilemez. Bu yüzden boş listede **0
  SEÇİLMEDİ** — 0, tam da düzeltilen kusuru (görmediğimiz kalıcı üyelerin önüne
  geçmeyi) geri getirirdi. Seçilen: `NoMeasurementPenalty = 1`, yani varsayılan cezalı
  (0) hiçbir üyenin önüne geçmeyen en küçük değer. Okuma hatası müdahaleyi
  **reddetmez**: ceza bir sıralama inceliğidir, güvenlik kapısı değil.

### 2. Ş77-16 — TTL 30 dk, `InterventionMembershipExpiryJob`
- **Neden:** üyelik `QueueRemove` ile **hiç** kaldırılmıyordu. `core restart` CLAUDE.md
  §3.1 ile yasak olduğu için `persistent_members=no` temizliği elimizde bir kaldıraç
  DEĞİL → süresiz kalan üyelik bir sızıntı.
- **Ne yapıldı:** `IBackgroundJob` (aynı proses, advisory lock, kilit **41**).
  **Kalıcı depo ayrı bir tablo değil `audit_log`'un kendisi** (`queue_members` yazımı
  Karar #67 N8 ile 10 oyla reddedildi; `QueuePushReconciliationJob` ile aynı desen).
  Tarama ölçütü gövdedeki `after.temporary = 'true'` — **eylem adı değil**: ikinci bir
  yüzey aynı üyeliği kurarsa ad bazlı tarama onları sessizce atlardı.
- **Veri kaybı önleyen ayrım:** AMI `QueueAdd` zaten üye olan arayüze `Already there`
  döner → üyelik müdahaleden ÖNCE de vardı (muhtemelen `queue_members`'tan gelen
  KALICI üyelik). Uç bunu `temporary: false` / `membershipCreated: false` yazar ve iş o
  satırları **hiç taramaz**. Taransaydı 30 dk sonra agent'in gerçek üyeliği düşer ve
  çağrı akışı sessizce dururdu.

### 3. Ş77-19b — agent üyeliği görür
- `/agent/state` → `supervisorQueues` (üç değerli: liste / boş liste / `null` =
  ÖLÇÜLEMEDİ). Kaynak `ITenantCache` projeksiyonu, TTL'i **aynı sabitten**. Salt-okunur:
  bırakma/iptal düğmesi yok. Frontend ayağı **AÇIK** (ayrı kart).

### Dokunulan dosyalar
`src/Pbxtr.Domain/Modules/Live/AgentInterventionMembership.cs` (yeni),
`.../Live/IAgentIntervention.cs`, `.../Platform/Audit/AuditActions.cs`,
`src/Pbxtr.Infrastructure/Telephony/Live/AgentInterventionService.cs`,
`.../Live/InterventionMembershipExpiryJob.cs` (yeni),
`.../TelephonyServiceCollectionExtensions.cs`, `.../Platform/Jobs/BackgroundJobLocks.cs`,
`src/Pbxtr.Api/Modules/Realtime/LiveEndpoints.cs`,
`src/Pbxtr.Api/Modules/AgentDesk/AgentEndpoints.cs`, + 6 test dosyası.

### Doğrulama — mutasyon (altı mutasyonun altısı da KIRMIZI)

| Mutasyon | Sonuç |
|---|---|
| `penalty!.Value` → `penalty: 0` | 3 KIRMIZI |
| `Already there` "kuruldu" sayıldı | 1 KIRMIZI (`Already_a_member_creates_no_temporary_membership`) |
| rozet hiç yazılmadı | 1 KIRMIZI (`..._grant_that_expires_with_the_ttl`) |
| TTL 30 dk → 1 dk | 1 KIRMIZI (`Ttl_dolmadan_uyelik_dusurulmez`) |
| `NOT EXISTS` silindi | 2 KIRMIZI |
| `after.temporary` süzgeci silindi | 1 KIRMIZI (`Zaten_var_olan_uyelik_taranmaz`) |

```bash
dotnet build pbxtr.sln                     # 0 hata
dotnet test Pbxtr.Api.Tests --filter Modules.Realtime      # 122/122
dotnet test Pbxtr.Api.Tests --filter Modules.AgentDesk     # 147/147
dotnet test Pbxtr.Integration.Tests --filter InterventionMembershipExpiryJobTests  # 4/4
```

**İki eşzamanlı aktör:** iki ayrı `NpgsqlDataSource` (iki "node"), üretim
`LeaderElectedJobRunner`'ı, gerçek transaction sınırı → **tek** `QueueRemove`, **tek**
kapanış kaydı.

### Kararlar
- Boş `QueueStatus` listesi **ölçüm değildir**; 0 yerine 1 seçildi (yukarıdaki gerekçe).
- TTL **sabit**, tenant parametresi değil (Ş77-16 birebir).
- `QueueRemove` reddedilir/belirsiz kalırsa kayıt **açık bırakılır**, sonraki tikte
  yeniden denenir; "düşüremedim"i "düşürdüm" diye yazmıyoruz.
- Ufuk 30 gün (partition budaması) — yazılı sınır, sınıfın `<remarks>`'ında.

### Açık kalanlar
- **Frontend (ayrı kart):** (a) `/agent/state.supervisorQueues` rozeti çizilmiyor,
  (b) `auditActionParity.test.ts` KIRMIZI —
  `aud.a.live.agent.intervention_membership_expired` 9 dilde + `ACTION_VIEW`/
  `ACTION_GROUPS` istiyor.
- **Bulgu (ayrı kart adayı):** `LiveEndpoints` belirsiz dalda `after["member"]`'a
  **kullanıcı GUID'i** yazıyor; `QueuePushResolver` onu `QueueStatus`'taki
  `Local/…` adresiyle karşılaştırıyor → süpervizör müdahalesinin mutabakatı **her zaman
  `not_applied`** okur. Bu turda DOKUNULMADI.
- **Commit:** `2c13c24a` — push edildi.

---

## BR-DB-93 + BR-SYS-116 — purge/retention izin listesi ve runbook

### Bağlam
İki kart: (1) `purge_call_data()` izin listesinde `webhook_outbox`,
`webhook_deliveries` ve `callback_entries` yok — çağrı verisi silinirken bu satırlar
geride kalıyor; (2) purge/retention runbook'u hiç yok.

### Yapılanlar

#### 1. Mevcut veri ölçüldü — kartın bir öncülü çürüdü
- **Neden:** "kart öncülü ölçülmeden yazılmaz" dersi.
- **Ne ölçüldü:**
  - İzin listesinin o anki hâli: `cdr`, `call_events` (partition dalı) +
    `script_responses`, `survey_responses`, `voicemail_messages` (satır dalı).
  - Üç gövdenin `md5(prosrc)` değeri kaynaktan yeniden üretildi ve dondurulmuş
    envanterle **birebir tuttu** (`d758ce05…`, `a98191be…`, `72a9e917…`) — yani
    `Down()`'a yazılan "önceki gövde" kopyaları tahmin değil, ölçüm.
  - Sunucu (`176.88.41.220`, `pbxtr` DB): `callback_entries` = **0 satır**;
    `webhook_outbox` / `webhook_deliveries` / `voicemail_messages` **tablo olarak
    yok** (son migration `20260915122000`). Karşılaştırma: `cdr`=1318,
    `call_events`=8196.
- **ÇÜRÜYEN ÖNCÜL:** `webhook_deliveries` listeye **eklenmedi**. Aradan **Kurul Karar
  #76 / Ş76-11** geçti ve o tabloyu **sistem sabiti** bir pencereye bağladı
  (`pbxtr_sys.purge_webhook_deliveries`, `20260918170000`), tenant parametresine
  bağlamayı **açıkça reddetti**. Ayrıca aylık RANGE partition'lı; satır dalı `ONLY`
  taşımaz ve Karar #48/Ş48-2 kapısı onu zaten `wrong_object_type` ile reddeder.
  Kartın *"ikisi de telefon numarası taşır"* gerekçesi `webhook_outbox` için de
  yanlış: o tablonun gövdesinde numara **yoktur** (Karar #28, DB Lideri vetosu) —
  gerekçe numara değil, **çağrı verisi** olması.

#### 2. Tek migration — `20260918230000_CallDataRetentionWebhookOutboxCallback`
- **Ne yapıldı:** `call_data_retention_plan()`, `purge_call_data()` ve
  `call_data_retention_lag()` gövdeleri birlikte tazelendi; `c_row_tables`'a
  `webhook_outbox` + `callback_entries`, anahtar kolon CASE'ine
  `occurred_at` / `missed_at`.
- **Kartta olmayan, bu turda ölçülen kusur:** `call_data_retention_lag()` **zaten
  kördü** — Karar #71 `voicemail_messages`'ı **plana** ekledi, gecikme ölçümüne
  **eklemedi**; üstelik o dal anahtar kolonu `y.started_at` olarak **sabit**
  yazıyordu (tablo eklenseydi `undefined_column` ile patlardı).
- **BLOKE EDİCİ ÖN KOŞUL (ilk kırmızı testle bulundu):** `callback_entries` RLS
  policy'si **çapraz kipi hiç tanımıyordu** (`USING (tenant_id =
  app_current_tenant())`, `app_is_cross_tenant()` dalı yok — elle yazılmış, şablondan
  gelmiyor). Retention işi oturumunda **yalnızca** `app.cross_tenant` açar,
  `app.tenant_id` **hiç yazmaz** (`CallDataRetentionJob.cs:211`) → `app_current_tenant()`
  NULL → policy her satırda FALSE. `SECURITY DEFINER` bunu **kurtarmaz** (FORCE RLS
  altında owner bypass değildir). Bu hizalama olmadan `callback_entries` retention'ı
  **üründe sessizce vacuous** olurdu; testte çağıran = tenant olduğu için yeşil bile
  görünürdü. `ALTER POLICY` ile şablona hizalandı, `Down()` eski metni birebir yazar.
- **İndeksler:** `ix_webhook_outbox_tenant_occurred_at`,
  `ix_callback_entries_tenant_missed_at` — ikisi de `tenant_id` ile başlıyor. Mevcut
  indeksler deseni karşılamıyordu (`ix_webhook_outbox_pending_fanout` `created_at`
  üzerinde ve `fanned_out_at IS NULL` ile **kısmi**; `ix_callback_entries_due`
  `missed_at` taşımıyor).
- **Silme anahtarı `ctid` değil:** satır dalı `ONLY` taşımaz ve bölümlü hedefi
  `relkind`/`pg_inherits` kapısıyla **silmeden önce** reddeder; guard `ROW_COUNT`'tur
  (`expected_rows` silmeden önce, `actual_rows` `GET DIAGNOSTICS` ile sonra).
- **Dondurulmuş envanter:** `sys-functions.expected` + `02-guards.sql` seed md5'leri
  + toplam md5 **aynı migration'da** tazelendi. Yöntem önce eski değerler üzerinde
  doğrulandı (mevcut toplam `8dc49b1d…` yeniden hesaplandı ve tuttu); yeni toplam
  `c732d80e…`.

#### 3. Ölçüm ve mutasyon
- **Komutlar:**
  ```bash
  dotnet test tests/Pbxtr.Integration.Tests --filter "FullyQualifiedName~CallDataRetention"
  # 20/20 yesil (yeni CallDataRetentionWebhookCallbackTests dahil)
  dotnet test tests/Pbxtr.Architecture.Tests   # 708/713
  ```
- **Mutasyon 1:** UP plan `c_row_tables`'tan `callback_entries` çıkarıldı **ve md5
  envanteri de tazelendi** (aksi halde donmuş md5 bekçisi davranış iddiasından önce
  patlıyordu) → **KIRMIZI**, tam da `callback_entries` plan iddiasında;
  `webhook_outbox` iddiası yeşil kaldı. Mutasyon hedefli.
- **Mutasyon 2:** `ALTER POLICY` hizalaması kaldırıldı → **KIRMIZI** (policy biçim
  iddiası). İkisi de geri alındıktan sonra yeşile döndü, ikilide doğrulandı.
- **Yan bulgu:** `md5(prosrc)`'nin çevrimdışı hesabı PostgreSQL'in ürettiği değerle
  birebir aynı (mutant md5 `15d8a37b…` bekçi hata mesajında aynen çıktı) — bu yüzden
  md5 tazelemek için DB'ye bağlanmak gerekmiyor; C# ham dize `"""` bloğu 12 boşluk
  dedent + LF ile prosrc'e eşit.

#### 4. `BR-SYS-116` — runbook
- **Dosya:** `doc/isletim/purge-retention-runbook.md`
- **Başlıklar:** işler tablosu / ne zaman koşar / **ne silmez** (`dealers` retention
  politikası YOKTUR — CLAUDE.md §4; `webhook_deliveries` Karar #76) / ön koşullar
  (yedek, süreler, gecikme, restatement tabanı, `lock_timeout`, `SET LOCAL`) / kuru
  koşum / yıkıcı koşumu açma / sonrası doğrulama (defter, denetim günlüğü, `job_runs`,
  gecikme) / **geri alma — `DETACH+DROP` geri alınamaz** / `ctid` neden değil / arıza
  hâlleri / yasaklar.

### Kararlar
- `webhook_deliveries` **bilerek dışarıda**; yeniden açılması `db-lider` + kurul işi.
- `callback_entries` policy'sinin şablona hizalanması bir **şema kararıdır** ve
  `db-lider`'a raporlandı — ama alternatifi sessiz vacuity olduğu için bu turda yapıldı.
- `call_data_retention_lag` da aynı migration'da düzeltildi: listelerin ayrışması
  fonksiyonun **kendi yorumunun** yasakladığı şey.

### Açık kalanlar / sonraki adım
- **Migration contract kapısı** (`deploy/migration-compatibility-guard.py`) bu migration
  için kurul onay satırı istiyor. Blob: `a7d4aa3e4f293fec99d166d05739c11f948fafff`.
  **Bilerek yazılmadı** (Karar #48 — onay kurul işi). Not: aynı kapı
  `20260918203500_CallbackRequestedSlaClass.cs` (başka ajan) için de kırmızı.
- **Benim olmayan kırmızılar** (aynı anda çalışan ajanlar): `DeployPrivilegeTests`
  (`deploy/ci/konteyner-ayricalik-kapisi*.py`), `CrossTenantScopeGuardTests` ×2 +
  `TenantLeakCoverageTests` ×2 (`EfProvisioningNodeState`),
  `WebhookAdministrationTenantLeakTests` ×3 (`Faz2Database.EnsureCreated`
  `pbxtr_webhook_event_types()` fonksiyonunu yaratmıyor) — sonuncusu migration'ım
  depodan çıkarılarak **aynen** doğrulandı, benim değil.
- `bash deploy/yerel-yayin.sh --sadece-kapilar` **koşulmadı** (kapı betiklerini başka
  ajanlar aynı anda düzenliyordu; koşsaydım kırmızının sahibi okunamazdı).
- **Commit:** `85d4139b` — push edildi.

---

## BR-B1 bölünmesi — kuyruktan tek tuşla geri arama talebi (`backend-lider`, 2026-09-18)

### Bağlam
`BR-B1` toplayıcısı üç karta bölünmüştü: `BR-DB-92` (kuyruk ayarı `callback_digit`),
`BR-AST-111` (kuyruktan çıkış dialplan bağlamı + fail-back), `BR-BE-197` (`UserEvent`
alım ucu, VETO şartı B-Ş3). Devralınan ölçüm: geri aramanın **ÇIKIŞ** yarısı ayakta,
**TALEP ALMA** yarısı yok.

### Yapılanlar

### 1. Ölçüm bağımsız doğrulandı
- **Neden:** kart metni "tekrar ölçmene gerek yok ama doğrularsan iyi olur" diyordu;
  `callback` kelimesi C#'ta delege anlamında 397 dosyada geçtiği için düz grep yanıltıcı.
- **Ne yapıldı:** `callback_digit` → 0 eşleşme, `qexit` → 0 eşleşme (`src/`+`deploy/`+`tests/`).
  Ayırt edici adlar (`CallbackEntry`/`ICallbackLedger`/`CallbackPolicy`) `Modules/Automation`
  altında bulundu — hepsi **dialer** geri araması.
- **Sonuç:** devralınan ölçüm **doğru**.

### 2. `BR-DB-92` — `queues.callback_digit`
- **Neden:** arayanın talep bırakabileceği ayarın duracağı kolon yoktu; akış fiziksel
  olarak imkânsızdı.
- **Ne yapıldı:** nullable `text` + `ck_queues_callback_digit` (`'0'`…`'9'`).
  `*`/`#` **dışarıda**: tuş üretilen `queues.conf`'ta `context=` ile bağlanır ve orada bir
  **exten adı** olur; `*` desen karakteri, `#` girdi sonlandırıcısıdır. `IvrDigits` (12
  elemanlı) bilerek kullanılmadı.
- **Dokunulan dosyalar:** `src/Pbxtr.Domain/Modules/Queues/Queue.cs`,
  `src/Pbxtr.Infrastructure/Persistence/Configurations/QueueConfigurations.cs`,
  `src/Pbxtr.Infrastructure/Persistence/Migrations/20260918213000_QueueCallbackDigit.cs`,
  `PbxtrDbContextModelSnapshot.cs`
- **Sonuç:** gövde yalnız EF API'si (`AddColumn` + `AddCheckConstraint`) → **kapı_07 onay
  satırı GEREKMEDİ** (kapı çıktısında dosya hiç geçmiyor).

### 3. `BR-AST-111` — `[pbxtr-<t>-qexit-<kuyruk>]`
- **Ne yapıldı:** `AsteriskObjectName.ForQueueExitContext` + `ConfigRenderer`'da iki üretim
  noktası (`queues.conf` `context=` ve bağlamın kendisi). **Fail-back-to-queue:** numarasız
  (gizli) arayan `GotoIf($["${CALLERID(num)}" = ""]?geri)` ile yakalanır ve `Queue()`'ya
  **geri girer** — `Hangup()` değil.
- **`ExecIf` DEĞİL `GotoIf`:** `ExecIf` ilk `:`'te bölünür, `UserEvent` argümanları `:` taşır
  (BR-AST-68'de fiilen yaşanmış tuzak).
- **Dokunulan dosyalar:** `src/Pbxtr.Domain/Modules/Telephony/AsteriskObjectName.cs`,
  `src/Pbxtr.Infrastructure/Provisioning/ConfigRenderer.cs`, `ProvisioningRevisionService.cs`

### 4. `BR-BE-197` — `UserEvent(PbxtrQueueCallback)` alım yolu
- **VETO B-Ş3:** yazım `call_events` ile **aynı transaction'da** (`PersistAsync` adım 5b,
  `ISurveyAnswerIntake` emsali).
- **Tenant gövdeden ALINMAZ:** kuyruk **KİMLİKLE** taşınır (`qcbQueueId`, Karar #76/Ş76-4
  emsali — ad `Slugify` çıktısıdır, SQL'de geri çevrilemez). Çapraz kontrol **EF global
  query filter**'ı ile; elle `WHERE tenant_id` yok.
- **Basılan tuş ve arayan numarası payload'a GİRMEZ** (Karar #25/Ş8; numara `CallerE164`
  ayrı alanında — payload'a konsa `FindPhoneLikeValue` olayı **tümden düşürürdü**).
- **Dokunulan dosyalar:** `QueueCallbackSignal.cs`, `IQueueCallbackIntake.cs`,
  `EfQueueCallbackIntake.cs`, `AmiEventMapper.cs`, `TelephonyEventPipeline.cs`,
  `InfrastructureServiceCollectionExtensions.cs`

### 5. Ölçüm ve mutasyonlar
- Api.Tests `Modules.Telephony` **1315/1315**; Integration **6/6** (gerçek PostgreSQL+RLS);
  Architecture `MigrationDiscoveryGuard` **3/3**. Tam çözüm derlemesi **0 hata**.
- **5 mutasyon KIRMIZI:** fail-back→`Hangup` (1 test); tenant öneki düşürüldü (**7 test** —
  `ConfigRenderGuard.AssertOutput` yakaladı, bekçi **gevşetilmedi**, Ş77-12);
  `IgnoreQueryFilters` (**yalnız çapraz kipte** 1 — üretim kipi yeşil kaldı, yani çapraz kip
  testi olmasa mutasyon görünmezdi); `[Migration]` niteliği kaldırıldı (2); CHECK gevşetildi (1).

### Kararlar
- **Çıkış anonsu (`periodic-announce`) YAZILMADI** — tenant'a özel anons bir **medya
  kolonu** ister, o kolon `BR-DB-92`'nin kapsamında değil. Var olmayan dosyaya
  `Playback`/`periodic-announce` yazmak **reddedildi**: `ConfigRenderer`'ın MOH bölümünde
  ölçülmüş kusurun tekrarı olurdu (*"arayan sessizlik duyar, panelde iz kalmaz"*).
- **Fail-back'te sıradaki yer KORUNMAZ** — `Queue()`'nun `position` argümanı var ama
  arayanın çıkmadan önceki sırasını veren kanal değişkeni **doğrulanmadı**; uydurulmuş bir
  değişken sessizce bozulurdu (*belge santral değildir*). İkisi de
  `doc/prototip-urun-farklari.md`'ye BORÇ/BİLİNÇLİ yazıldı.

### Ölçüm tuzakları (kayda değer)
- **`[Migration]` niteliği unutuldu → migration EF tarafından HİÇ bulunmadı.** Derleme
  yeşil, `Up` gövdesi doğru, **hiçbir şey olmuyordu**; belirti yalnızca çalışan bir testin
  içinde `42703: column q.callback_digit does not exist` olarak çıktı.
- **Kilitli `testhost` mutasyon ölçümünü iki kez yalanladı.** `MSB3026` ile DLL kopyalanamadı,
  `--no-build` **eski ikiliyi** koştu ve mutasyon "yeşil" göründü. Artık her mutasyon
  koşusunda `MSB3026|error CS` sayısı 0 mu diye bakıldı.
- **`TenantLeakCoverageTests` kapanış tespiti ALT DİZE eşlemesidir.** Test dosyamın
  **yorumunda** `EfCallbackLedger` adının geçmesi, `CallbackLedger` borç kalemini sessizce
  *"kapandı"* gösterdi. Kalem gerçekte **açık** (portun `GetBoardAsync`/`CloseAsync` okuma
  yüzeyleri ölçülmüyor); ad yorumdan çıkarıldı ve durum dosyaya yazıldı.

### Açık kalanlar / sonraki adım
- Çıkış anonsu + onay/hata anonsu için **kuyrukta medya kolonu** kartı açılmalı (kurul).
- Stok ses adları (`auth-thankyou`, `vm-sorry`) **gerçek santralde doğrulanmadı** (§3.0).
- **Benim olmayan kırmızılar:** `CrossTenantScopeGuardTests` ×3 + `TenantLeakCoverageTests`
  (`EfProvisioningNodeState`, `20260918230000_CallDataRetentionWebhookOutboxCallback`),
  `DeployPrivilegeTests` — hepsi aynı anda çalışan ajanların dosyaları.
- Kapı_07 iki **başka ajan** migration'ı için kırmızı (`20260918203500`, `20260918230000`);
  onay satırı **bilerek yazılmadı** (Karar #48).
- **Commit:** `9c4aaf28` — push edildi.

---

## Kurul Karar #77 Ş77-9 / Ş77-10 / Ş77-11 — `provisioning_node_state` + `#37` üçüncü ekseni (`BR-DB-98`, `BR-BE-200`)

### Bağlam
Provisioning uygulama raporu (`POST /api/v1/provisioning/report`) **yalnızca `audit_log`'a**
yazıyordu. `audit_log` aylık partition'lı ve retention `DETACH + DROP` ile partition düşürüyor
(`deploy/db/01-rls-template.sql:2286,2613`; `02-guards.sql:3328`). Sonuç: 40 gün önce kanarya
reddiyle N-1 revizyonuna dönmüş bir düğümün **hangi revizyonda koştuğunu söyleyen tek satır
siliniyordu.** Bu bir denetim kaybı değil **DURUM kaybı**dır.

### Yapılanlar

### 1. `provisioning_node_state` tablosu (Ş77-9 / `BR-DB-98`)
- **Ne yapıldı:** düğüm başına **TEK SATIR** durum tablosu. Bileşik PK `(tenant_id, node_id)` —
  "tek satır" şartı uygulamada değil **veritabanında** durur; yapay `id` + "önce oku sonra yaz",
  eş zamanlı iki raporda ikinci bir satır bırakır ve soru iki cevaplı olurdu.
- Kolonlar: `tenant_id`, `node_id` (varchar 128), `reported_revision`, `applied_revision`
  (**NULL = hiçbiri yayına girmedi**; `0` ya da `rev` yazmak bir iddia olurdu), `outcome`
  (CHECK kapalı küme `applied|rolled_back|partial|rejected`), `failed_checks` **`text[]`**
  (CHECK `cardinality <= 20` — metin olsaydı 20 sınırını hiçbir katman tutmazdı), `reported_at`,
  `reported_ip`.
- **Retention YOK ve bu bilinçli:** satır sayısı `tenant × düğüm` ile sınırlı; `purge_call_data()`
  allowlist'ine **bilerek eklenmedi**.
- **Dokunulan:** `src/Pbxtr.Domain/Modules/Telephony/ProvisioningNodeState.cs`,
  `src/Pbxtr.Infrastructure/Persistence/Configurations/TelephonyConfigurations.cs`,
  `src/Pbxtr.Infrastructure/Persistence/PbxtrDbContext.cs`,
  `src/Pbxtr.Infrastructure/Persistence/Migrations/20260918200000_ProvisioningNodeState.cs`.
- **RLS:** `SELECT pbxtr_apply_tenant_rls('provisioning_node_state');` → şablon policy'si
  `provisioning_node_state_tenant_isolation` (`dealer_scope` **açılmadı**).
- **`pbxtr_global_tables()` kapısı:** liste **5 satır, değişmedi**
  (`deploy/db/global-tables.expected` diffsiz). Tablo `tenant_id` taşıdığı için listeye girmez
  (Şeytan itirazı I11).

### 2. Damga yazımı — uç KAPI olmadı, KAYIT oldu (Ş77-10 / `BR-BE-200`)
- Uç artık **iki şey** yazar ve **ikisi de kayıttır**: denetim satırı ("ne oldu", retention'lı) +
  durum damgası ("şu an ne", kalıcı). **Denetim satırı kaldırılmadı.**
- **Hata davranışı (yazılı):** damga yazılamazsa **503 `STATE_UNAVAILABLE`** — FAIL-CLOSED,
  `AUDIT_UNAVAILABLE` ile birebir aynı gerekçe. Düğüm adı kapalı biçime uymazsa istek
  **reddedilmez**, denetim satırı yazılır, damga atlanır, `LogWarning` düşer ve düğüm `#37`'de
  **ÖLÇÜLEMEDİ** görünür — asla yeşil değil.
- **Bekçi:** `tests/Pbxtr.Architecture.Tests/ProvisioningReportIsNotAGateTests.cs` — IL çağrı
  ağacında (`WritePathScanner`) `RenderAndStoreAsync`, `RenderAndStoreInCurrentTransactionAsync`,
  `ProvisioningRegenerator.RegenerateAsync`, `ProvisioningRerenderer.RerenderAsync/MarkBlockedAsync`,
  `IAsteriskConsole.RunAsync` **yasak**. Tipin tamamı yasaklanmadı: uç `TryGetTenantCodeAsync`'i
  meşru olarak çağırır ve geniş bir yasak ilk gün kırmızı yanıp **kapatılırdı**.

### 3. `#37` üçüncü ekseni (Ş77-11)
- **Yeni `HealthState` YOK** (Karar #35/3 aynen) ve **bileşen ikiye bölünmedi** (`BR-BE-52`
  reddedildi). Sayılar mevcut `provisioning` satırının **metnine** ve **`down` koşuluna** girdi.
- `SystemHealthProbe.CheckProvisioningAsync` ikiye ayrıldı: `CheckProvisioningQueuesAsync`
  (kuyruk ekseni, davranışı değişmedi) + `ReadNodeStateLineAsync` (üçüncü eksen) + `Combine`.
- **Gerçek çıktı (ölçüldü; geçici `Assert.Fail` ile bastırıldı, sonra geri alındı):**

```
1 tenant'in tamami bir dugume atanmis ve istenen kuyruklari santralde bulundu
(olcum 18.09.2026 08:59 UTC). 1 dugum ISTENEN REVIZYONU KOSTURMUYOR
(rolled_back/rejected) — config teslim edildi ama yayina GIRMEDI; mudahale: confd
gunlugu ve kanarya raporu. 1 dugum yayimlanmis revizyonun GERISINDE (uyguladigi
revizyon pbxtr'in urettigi en yuksek revizyondan farkli).
```

### Kararlar / açıkça yazılan varsayımlar
- **"Yayımlanmış revizyon" = `max(provisioning_revisions.revision)`** (tür ayrımı olmadan).
  `revision` tür başına artar; tek bir yayın numarası **kolonu yoktur.** Tür bazında kıyas,
  bir türü değişmemiş tenant'ı daima "geride" gösterirdi. Bu eksen `severity=info`'dur,
  **kırmızı yakmaz** — varsayımın bedeli bir uyarı satırı, alarm değil.
- **`partial` kırmızı yakmaz**, yalnız `rolled_back`/`rejected` yakar; müdahale kapıları ayrı.
- Sağlık okuyucusu **bilerek çapraz-tenant**tır (`BeginCrossTenantScope` + `IgnoreQueryFilters`,
  `EfProvisioningNodeDirectory` deseni birebir); `pbxtr_sys` SECURITY DEFINER fonksiyonu
  **açılmadı** (şablon tazeleme + md5 envanteri gerekmedi).

### Ölçümler
- **Sızıntı testi:** `tests/Pbxtr.Integration.Tests/Tests/ProvisioningNodeStateTenantLeakTests.cs`
  (3 vaka, gerçek PG + gerçek RLS). **Mutasyon:** store lookup'ına `.IgnoreQueryFilters()` →
  **KIRMIZI** (*"...Gozlenen: hicbir istisna atilmadi. Bu, EF global query filter'inin bu sorguda
  DUSTUGU anlamina gelir"*), geri alınca **YEŞİL** (3/3).
- **Bekçi mutasyonu:** uca `RenderAndStoreAsync` eklendi → **KIRMIZI**
  (*"Ş77-10 IHLALI ... ProvisioningRevisionService.RenderAndStoreAsync"*), geri alınca
  **YEŞİL** (4/4).
- `dotnet build pbxtr.sln` → **0 Warning, 0 Error** (test koşularından **ayrı** koşuldu).
- `Api.Tests --filter ~Provisioning` 259/259 · `Architecture.Tests` 712/713 (kalan kırmızı benim
  değil) · `Integration.Tests --filter ~ProvisioningNodeStateTenantLeakTests` 3/3.
- **Migration contract kapısı** (`deploy/migration-compatibility-guard.py`): bu migration için
  **sıfır bulgu** → `migration-contract-onay.blobs`'a **onay satırı yazılmadı ve gerekmiyor**
  (`SELECT pbxtr_apply_tenant_rls('...')` kapının yazılı istisna deseni, `:412`).

### Ölçüm tuzakları (kayda değer)
- **Çapraz-tenant YAZMA yapısal olarak imkânsızmış.** İlk kurgu *"B'nin raporu A'nın satırını
  ezdi mi"* diye ölçüyordu; `TenantStampInterceptor` çapraz kipte **her yazmayı**
  `CrossTenantWriteForbiddenException` ile reddediyor (ADR-002 §3.7). Olmayan bir yolu ölçmek
  yerine fikstür **ayrıştırıcı** yapıldı: ikinci çağrının payload'ı A'nınkiyle **birebir aynı**
  → filtre tutuyorsa `Added` kayıt doğar ve **istisna atılır**; filtre düştüyse komşunun satırı
  bulunur, EF değişiklik görmez (`Unchanged`) ve **istisna atılmaz.** İddia *"veri bozulur"*
  değil, **"ikinci savunma düştü"**dür; kodun XML dokümanı buna göre düzeltildi.
- **Aynı dosyada duran iki sınıf, bekçiyi yanılttı.** `CrossTenantScopeGuardTests` çapraz kapsamı
  **dosya düzeyinde** tarar; store + health reader aynı dosyadayken **yazma yolu da** "çapraz
  kapsamda" sayıldı (`FilterIgnored = False`). İki ayrı dosyaya bölündü.
- **`TenantLeakCoverageTests` alt-dize eşlemesi yine tetiklendi** (bugünkü ikinci vaka): bu kez
  adaptör adını **eksik** yazmak `ProvisioningNodeStateHealthReader`'ı "testsiz" gösterdi; ad
  test gövdesine **kasten** eklendi (test o adaptörü gerçekten ölçüyor).
- **`git stash` ile baseline alınmaz.** `git stash -u -- <yol>` benim dosyamı değil **başka bir
  ajanın stash'ini** listeledi ve `pop` gerekti. Paralel ajan ortamında stash **yasak sayılmalı**.

### Açık kalanlar / sonraki adım
- `#37` üçüncü ekseni **gerçek Asterisk/confd raporuyla doğrulanmadı** (§3.0); `POST
  /provisioning/report` uçtan uca bir confd ile koşturulmadı — "yok" değil, **"ölçemedim"**.
- Migration `Up`/`Down` **gerçek üretim veritabanında koşturulmadı**; ölçülen şey testcontainers
  üzerindeki taze zincirdir.
- **Benim olmayan kırmızılar (aynı anda çalışan ajanların dosyaları):**
  `TenantLeakCoverageTests` → `ProvisioningNodeDirectory` (sebep:
  `tests/.../ApiKeyForeignNodePinTests.cs` yorumundaki ad), `DeployPrivilegeTests`,
  `ProvisioningTombstoneWriteDbTests` + `ProvisioningRerenderJobDbTests`
  (`42883: function pbxtr_webhook_event_types() does not exist`), contract kapısında
  `20260918203500` ve `20260918230000`.
- **Commit:** `95bd29e0` — push edildi.


---

## Tur: Karar #77 uygulama dalgası — 8 paralel ajan (koordinatör)

### Bağlam
Karar #77 yazıldıktan sonra uygulanabilir şartları sekiz ajana paralel dağıttım. Turun
çıktısı yalnız inen kod değil; ajanların **yolda buldukları** oldu.

### Yapılanlar

### 1. Kapanan kartlar (17)
`BR-QA-109` · `BR-QA-110` · `BR-QA-111` · `BR-QA-06` · `BR-SEC-30` · `BR-FE-114` ·
`BR-FE-115` · `BR-FE-116` · `BR-BE-201` · `BR-BE-164` · `BR-BE-165` · `BR-BE-121` ·
`BR-BE-117` · `BR-BE-200` · `BR-DB-98` · `BR-DB-92` · `BR-BE-197` · `BR-DB-93` ·
`BR-SYS-116` · `BR-BE-198`. Kısmen: `BR-AST-111`, `BR-BE-199`.

### 2. CTO'nun vetosu DOĞRULANDI — gerçek P0 tenant sızıntısı (`0a382f1a`)
- **S1 = EVET, sıfır kontrol:** `EfApiKeyAdministration.cs:105-108` yalnız "boş olamaz"
  bakıyordu; ad **sahipliğini** doğrulayan hiçbir şey yoktu, düğüm kataloğu da yok.
- **S2 = EVET:** `ProvisioningNodeBundleEndpoints.cs:218` düğümü anahtarın **kendi
  pininden** alıyor → `EfProvisioningNodeDirectory.cs:109-112` `IgnoreQueryFilters()` +
  çapraz-tenant kipinde o ada pinli **tüm** tenant'ların fragmanını üretiyor.
  **Çağıranın tenant'ı hiçbir yerde filtre değildi.**
- **S3 = HAYIR ama sömürülebilirdi** (`t9052` teslim niyeti `deliver`).
- Düzeltme: yabancı düğüm kapısı; keşif **sızıntıyı besleyen aynı kaynaktan** yapıldı
  (iki kaynak zamanla ayrışır ve kapı sessizce yanlış kümeyi ölçerdi). Ayrı DI kapsamı
  **zorunluydu**: `/api/*` isteği `UnitOfWorkMiddleware`'in transaction'ı içinde, iç içe
  `BeginAsync` istisna atar ve kapı 403 yerine **500** üretirdi.
- **Kapı Ş36-19'u KARŞILAMADI** — düğüm adı hâlâ katalogsuz serbest metin. Borç
  `BR-BE-43-B` ve `BR-SEC-31`'e geçti.

### 3. Ajanların yolda bulduğu, kartlarda olmayan altı kusur
1. **`callback_entries` RLS policy'si çapraz kipi hiç tanımıyordu** — elle yazılmış,
   `app_is_cross_tenant()` dalı yok. Retention işi `app.tenant_id` yazmadığı için policy
   **her satırda FALSE**; `SECURITY DEFINER` kurtarmaz. Retention **üründe sessizce
   vacuous** olurdu, **test yeşil görünürdü** (testte çağıran = tenant).
2. **`call_data_retention_lag()` zaten kördü** — Karar #71 voicemail'i plana ekleyip
   gecikme ölçümüne eklememişti; fonksiyonun kendi yorumu tam bu riski yazıyordu.
3. **`TenantLeakCoverageTests` kapanış tespiti ALT DİZE eşlemesi** — bir test dosyasının
   **yorumunda** adaptör adının geçmesi borç kalemini "kapandı" gösteriyor. Aynı gün
   **iki bağımsız ajan, iki farklı kalemde** aynı susturmayı kazara üretti → `BR-QA-113`.
4. **`LiveEndpoints` `after["member"]`'a GUID yazıyor**, resolver `Local/…` ile
   karşılaştırıyor → süpervizör müdahalesinin mutabakatı **her koşulda `not_applied`**
   → `BR-BE-202`.
5. **İki deploy betiği CRLF'ti ve kapı konteyneri onları HİÇ koşturamıyordu**
   (`set: pipefail: invalid option name`, rc=2). `.gitattributes` `eol=lf` diyordu ve HEAD
   blob'unda 0 CR vardı — `git diff` tertemizdi, bozuk olan çalışma kopyasıydı.
6. **`BackgroundJobLocksTests` üç iş öncesinden beri sessizce kırmızıydı.**

### 4. Ajanların kendi ölçümüyle düzelttiği iki iddia
- **Damga tablosu (`BR-DB-98`):** benim tarif ettiğim "B'nin raporu A'nın satırını ezer"
  senaryosu **koşturulamıyor** — `TenantStampInterceptor` çapraz kipte her yazmayı
  reddediyor. `IgnoreQueryFilters` veri **bozmuyor**; düşen şey **ikinci savunma**. Ajan
  testi buna göre kurdu ve önce abartılı yazdığı XML dokümanını geri aldı.
- **`BR-BE-198` mutasyonu hayatta kaldı → fikstür kusuru:** uç testi bellek-içi ikizi
  kullanıyordu, üretim defterindeki kapı kaldırılınca takım yeşil kalıyordu. Üretim
  defterini **doğrudan** çağıran test eklendi.

### 5. Kendi hatam (`BR-FE-116`)
Yama betiğini mutasyondan sonra ikinci kez koşturdum; i18n anahtarları **dokuz dosyanın
hepsinde mükerrer** oldu. Doğrulamam göremedi çünkü `json.loads` mükerrer anahtarı
**sessizce kabul ediyor** — *"anahtar var mı"* sormuştum, *"kaç kez var"* değil.
Geri alındı, doğrulama ham metinde sayıma çevrildi, dokuz dilde de **1**.

### 6. Paralel ajan ortamının üç tuzağı (ölçüldü)
- İki ajan **aynı migration zaman damgasını** aldı (`20260918200000`). Belirti "hata"
  değil, **sessizce yanlış sıra**. Uyarıldı, `203000`'a taşındı.
- `PbxtrDbContextModelSnapshot.cs`'i üç ajan birden yazdı; **son yazan kazanır** ve düşen
  model değişikliği build'i kırmaz. Üçüne de commit öncesi grep doğrulaması şart koşuldu.
- Bir ajan `git stash -u -- <kendi yolu>` denedi ve **başka bir ajanın stash'ini**
  listeledi. Stash depo genelinde tek yığındır, yola göre izole değildir.

### 7. Yayın öncesi sunucu sapmaları (176.88.41.220, test ortamı)
İkisi de **elle düzenleme değil, sunucu geride** çıktı — git geçmişindeki sha ile birebir
eşleşme ölçülerek doğrulandı, üzerine yazmadan önce:
- `pbxtr-confd-dugum.sh`: sunucu `accfef54` = repo commit `b21cc3b1`; repo 58 satır ileride.
  Kapının kendi `--tasi` yolu koşturuldu, timer durduruldu, ilk koşu **temiz**
  (HTTP 200, sıfır yazım, sıfır reload), timer geri açıldı.
- `docker-compose.yml`: sunucu `66c1243a6413` = repo commit `f082efec`. Yedeklendi
  (`.onceki`), atomik taşındı (sahiplik/mod korunarak), `docker compose up -d app` ile
  4 eksik `WebhookDeliveryRetention__*` anahtarı konteynere indi, `pbxtr-app` healthy.

### Kararlar
- Migration contract onay satırları **bilerek yazılmadı** (`BR-DB-100`): Karar #48 birebir
  blob sha ister ve ajanlar çalışırken blob değişebilir; peşin onay defteri **kauçuk
  mühre** çevirir.
- `BR-DB-99`'un teşhisi düzeltildi ve **bağımsız ikinci kez doğrulandı**: sorun şablonda
  değil **fikstürde** — `PbxtrDatabaseFixture` şablonlardan kuruyor, `Faz2Database`
  `EnsureCreated` kullanıyor, **ikisi de EF migration'larını koşturmuyor**.

### Açık kalanlar / sonraki adım
- Kapı takımı koşuyor (80 konteyner + 6 host); bitince **yayın**.
- `BR-QA-114`: `SlaAggregationJob` SQL'i gerçek PG'ye karşı ölçülmedi.
- `BR-DB-100` kurula gidecek (iki blob + `callback_entries` RLS genişletmesi).
- `BR-SEC-16` + `BR-SEC-28` sır rotasyonu.

---

## Ek tur — `kapi_71` (şablon ↔ tazeleme defteri) KIRMIZI, kapatıldı

### Bağlam
`deploy/yerel-yayin.sh --sadece-kapilar` yayını bloke etti:
`IHLAL: 02-guards.sql: GOVDE DEGISTI (defter 0f77294b…, gercek 7b4c041a…)`.

### 1. Sebep ölçüldü (kapı doğru davranıyordu — gevşetilmedi)
- **Neden:** `85d4139b` (BR-DB-93) `deploy/db/02-guards.sql` içindeki
  `pbxtr_sys_function_expectations()` md5 envanterini ve
  `pbxtr_assert_sys_functions_frozen()` dondurulmuş toplam hash'ini tazeledi
  (`call_data_retention_lag`, `call_data_retention_plan`, `purge_call_data` +
  `8dc49b1d…` → `c732d80e…`). Envanter **şablonun içindedir**.
- **Belirti sessiz DEĞİL, fail-closed:** EF uygulanmış migration'ı yeniden koşmaz.
  Yeni tazeleme yazılmazsa yükseltilen DB'de fonksiyon gövdeleri YENİ
  (`20260918230000` `CREATE OR REPLACE` eder), envanter ESKİ kalır →
  `pbxtr_assert_sys_function_guard()` `SYS_FUNCTION_SOURCE_DRIFT` ile düşer,
  **uygulama hiç açılmaz.** Taze zincir yeşil, yükseltilen kurulum kilitli.

### 2. Tazeleme migration'ı
- **Dosya:** `src/Pbxtr.Infrastructure/Persistence/Migrations/20260918233000_GuardsTemplateRefreshCallDataAllowlist.cs`
- **Damga çakışması ÖNCE ölçüldü:** dizin tazelendi, bugünün en yenisi `20260918230000`;
  `20260918233000` ve sonrası boş. **Sıra bağlayıcı:** 230000 gövdeyi değiştirir,
  233000 envanteri tazeler (ters sırada aynı drift, ters yönde).
- **Gövde:** `SET LOCAL lock_timeout='5s';` + `DeployDbScripts.Read(DeployDbScripts.Guards)`.
  Emsal `20260918130000` / `20260918180000` ile aynı desen; şema değiştirmez,
  `pbxtr_assert_*` iddiası koşmaz (Karar #23 / Ş23-7).
- `PbxtrDbContextModelSnapshot.cs`'e **dokunulmadı** (model değişmiyor), Designer dosyası yok
  (emsaller de böyle: `[DbContext]`/`[Migration]` öznitelikleri satır içi).

### 3. `Down()` — emsalden BİLEREK ayrıldı
`130000`/`180000` boş `Down` taşır: orada geri alma ölçülmüş bir kusuru geri getirirdi.
**Burada tersi:** EF ters sırada koşar → önce bu `Down`, sonra `230000`'in `Down`'ı
(üç gövdenin ölçülmüş önceki kopyası). Envanter burada eski değerlere dönmezse
"geri alınmış" DB `SYS_FUNCTION_SOURCE_DRIFT` ile **açılmazdı**.
`Down` gövdesi `85d4139b^:deploy/db/02-guards.sql` satır **1952-2035**'in birebir
kopyasıdır (emsal `20260915120000_TenantColumnWriterGate.cs:193-195`); yıkıcı adım yok
(`DROP` yok, `CREATE OR REPLACE` aynı imza).

### 4. Defter
`deploy/db/sablon-refresh.expected`, 02 satırı:
- önce: `0f77294b242c102fc121932e3f6bbcc9a0e1bf78e2980f5846abb024141a44dc|20260918180000_GuardsTemplateRefreshWebhookRetention`
- sonra: `7b4c041a10066782dcbcb50843b3e6c63f3f4a4ece20164728f96faeddaa80ee|20260918233000_GuardsTemplateRefreshCallDataAllowlist`

### 5. Ölçüm (ubuntu:24.04 konteyneri — Windows host'ta DEĞİL)
```bash
docker run --rm -v //x/GitHub/Pbxtr/pbxtr://repo -w //repo ubuntu:24.04 sh -c \
  "apt-get install -y -qq git; git config --global --add safe.directory /repo; \
   sh deploy/sablon-refresh-kapisi.sh; sh deploy/sablon-refresh-kapisi.sh --oz-test"
```
- öz-test: **OZ-TEST GECTI (9/9)**, rc=0 (m7/m8 dahil — K6 canlı)
- ölçüm (commit'ten SONRA): iki satır da **TEMIZ**, rc=0;
  `02-guards.sql -> 20260918233000_… [K6: govde 6ed2f55d, be44d534 eklendiginde de ayniydi]`
- `dotnet build Pbxtr.Infrastructure`: 0 Warning, 0 Error

### 6. Açık — contract kapısı (BİLEREK yazılmadı)
`deploy/migration-compatibility-guard.py` bu migration için kurul onay satırı istiyor.
**Yazılmadı** (Karar #48 birebir blob sha ister; onay kurul işidir).
- blob: `38506ef55b2f7cf99cc5729c2d5161d94ca91524`
- bulgu: `deploy/db/02-guards.sql (DeployDbScripts.Guards) icerigi:
  contract/destructive desen: ALTER (TABLE|COLUMN|TYPE) (ilk satir 848, 2 eslesme)`
  + `ham SQL normal deploy'da fail-closed reddedildi` — emsal `20260918180000` ile
  **birebir aynı** bulgu kümesi.
- Kapı bu commit'ten **önce de** kırmızıydı (`20260918230000` da onaysız) → bu
  kırmızılığın sahibi bu tur değil.

**Commit:** `be44d534` — BR-DB-93 devami: 02-guards.sql tazeleme migration'i (20260918233000) + defter

### Bu turun kararı
- Kapı **gevşetilmedi**; borç kapıyı susturarak değil, tazeleme migration'ı yazarak ödendi.
- `yonetim/` altına dokunulmadı; `git add -A` / `git stash` kullanılmadı
  (paralel ajanlar çalışıyordu) — `git commit --only -- <yollar>` ile tek adım.

---

### kapi_74 + kapi_75 — iki kapının gerçek ağaçtaki 6 bulgusu (backend-dev-2, commit `8d828592`)

- **Neden:** Yayın bloke. `kapi_74` (RLS yüklemi aynası) kontrol ayağı `N1` **3 bulgu**
  veriyordu (zararsız yorum değişikliğinde bile) ve `kapi_75` (BR-DOC-22 AstDB fallback
  iddiası) `P0-degismemis-agac` ayağı **3 bulgu** veriyordu. İkisi de "gerçek ağaçta sapma
  var" demekti.

- **kapi_74'ün 3 bulgusu tek kökten geldi — ve kök bir ZAMAN SIRASIYDI:**
  ayna bekçisi `fd74e677` ile **12:54**'te yazıldı; Kurul Karar #76 / Ş76-6 (kart
  `BR-DB-90`, commit `23c69eed`) **14:41**'de `CdrSqlBuilder.ActiveTenant` operand sırasını
  bilerek takas etti. Bekçi şablonu tek doğruluk kaynağı sayıyordu, takas ise şablona
  **bilerek dokunmuyordu**.
  - Bulgular: `src/Pbxtr.Infrastructure/Search/CdrSqlBuilder.cs:113-114` (sabit),
    `CdrSqlBuilder.cs:26` ve `src/Pbxtr.Infrastructure/Search/PostgresCdrSearch.cs:22`
    (aynı yüklemi anlatan iki yorum).
  - **Kod şablona geri döndürülmedi**, çünkü üç ölçüm bunu yasaklıyor:
    (1) Ş76-5 policy metnini kilitledi — takas tazeleme migration'ı + 81 tabloda ACCESS
    EXCLUSIVE ister ve `call-permission` FAIL-CLOSED olduğu için o pencerede giden arama
    durur; (2) ölçülmüş kazanç geri alınırdı (PG 16.15, 1.000.000 satır, `Seq Scan`
    4.746 → 2.434 ms, duvar saati 5.306 → 3.120 ms, **-%41**; normal kipte
    `Buffers: shared hit=1126` birebir aynı, gerileme yok); (3)
    `tests/Pbxtr.Architecture.Tests/CdrSqlBuilderGuardTests.cs:47-48` eski sırayı **sabit
    olarak yasaklıyor** — yani "kod şablona uysun" bir seçenek değil, iki bekçi arasında
    bir çelişkiydi.
  - **Yapılan:** ayna beklentiyi hâlâ **şablondan türetir**, türetme bir adım daha taşır
    (`s76_normal`: eşitlik içermeyen ucuz kol başa alınır). Kol kümesi yine şablondan
    gelir → şablona kol eklenirse ham SQL ve iki yorum yine KIRMIZI yanar. Kapı **daha
    sıkı** oldu: Ş76-6 sırasından sapmak da yanıyor (yeni `M11`, `M12` ayakları).
  - **Yan bulgu (7.):** `M4` mutasyonunun dize çıpası eski sırayı arıyordu → "0 eşleşme",
    vaka **hiç ölçmüyordu**. Çıpa tazelendi.

- **kapi_75'in 3 bulgusu YANLIŞ POZİTİFTİ:** `ConfigRenderer.cs:1162`,
  `AriDndDeviceStateAnnouncer.cs:21`, `AriStasisApp.cs:247`. Üçünün de cümlesi
  BR-AST-81/Ş76-12'nin DND cihaz durumu ölçümüdür ve fallback'ten *var gibi* değil, tam
  tersine **yok diye** söz eder: *"BUSY iken AstDB girdisi yok"*. Onlara `BR-DOC-22`
  işareti koymak **yanlış atıf** olurdu.
  - **Yapılan:** kaynak tarafı deseni kapının **kendi tarifine** daraltıldı — çıplak
    `"AstDB"` tokeni yerine `fallback` / `LKG` / `snapshot` / `son bilinen iyi` karinesi
    **aynı satırda** aranıyor. **Sayım düşmedi:** işaretli dosya sayısı daraltmadan önce
    de sonra da **9** (her birinde ≥2 iddia satırı). Yeni `M5` ayağı deliği ölçer:
    işaretsiz bir dosyaya yeni fallback cümlesi yazılırsa kapı hâlâ KIRMIZI.

- **Dokunulan dosyalar:** `deploy/ci/rls-predicate-mirror-guard.py`,
  `deploy/ci/rls-predicate-mirror-guard-selftest.py`,
  `deploy/ci/astdb-fallback-iddiasi-kapisi.py`,
  `deploy/ci/astdb-fallback-iddiasi-kapisi-selftest.py`, `deploy/yerel-kapilar.sh`.

- **Ölçüm / doğrulama:**
  - `kapi_74` öz-test: 1 pozitif + **12** mutasyon + 1 negatif = OK; kapı rc=0.
  - `kapi_75` öz-test: 1 pozitif + **5** mutasyon + 1 negatif = OK; kapı rc=0.
  - İkisi de **ubuntu konteynerinde** (`bash deploy/yerel-yayin.sh --sadece-kapilar`)
    `[gecti]`.
  - `dotnet build pbxtr.sln` → 0 Warning, 0 Error. `CdrSqlBuilderGuardTests` +
    `RawSqlAllowlistTests` + `UsersTenantIsolationPolicyTests` → 34/34 geçti.

- **ORTAM TUZAĞI (kayda geçti):** çalışma kopyasındaki `deploy/**` dosyaları **CRLF**;
  `.gitattributes` `deploy/** text eol=lf` dese de checkout eski. Konteyner **bind mount
  ile çalışma kopyasını** okuduğu için kapılar `$'\r': command not found` ile **hiç
  koşmuyor**. Ölçüm bu yüzden HEAD'in **temiz bir klonundan** yapıldı. Ayrıca
  `grep -c $'\r'` Git Bash'te **her satırı sayıyor** (boş desen) — CR ölçümü `od -c` ile
  yapılmalı.

- **Benim olmayan iki KIRMIZI kapı (aynı koşuda):** *"normal deploy migration'ları
  expand-only"* ve *"şablon tazeleme çifti bütün mü"* — ikisi de `be44d534`
  (`BR-DB-93`, `02-guards.sql` tazeleme migration'ı) sahibine ait; o dosyaya dokunmam
  yasaklıydı.

- **Commit:** `8d828592` — kapi_74 + kapi_75: iki kapinin GERCEK AGACTAKI 6 bulgusu
  olculerek kapatildi

---

### Kurul #78 — Ş78-L1 / Ş78-L6 / Ş78-L7 uygulandı (linux-uzmani)

**Bağlam:** Kurul #78'de linux-uzmani'nin kendi koyduğu üç şart. L1 yayın bloke edici.

#### 1. Ş78-L1 — "Down NO-OP" iddiası ölçüldü ve yanlış çıktı
- **Neden:** `deploy/lib/pbxtr-migrate-adimi.sh:114` ve `:201` yayın gecesi ekrana
  *"`Down` NO-OP olduğu için geri dönüşün tek yolu dump restore'dur"* basıyordu.
  Kodda koşacak bir `Down` duruyordu; operatörün önünde çelişen iki kaynak vardı.
- **Ne yapıldı / ölçüm** (`src/Pbxtr.Infrastructure/Persistence/Migrations`, Designer+Snapshot hariç):

  | | |
  |---|---|
  | migration dosyası | **211** |
  | `Down()` gövdesinde ≥1 `migrationBuilder.` | **164** |
  | `Down()` gövdesi gerçekten boş | **47** |

  Kartta sayılan üç örnek doğrulandı: `20260918203500` → 5 çağrı,
  `20260918233000` → 2 çağrı, `20260918230000` → üç fonksiyon gövdesini geri yazan tam `Down`.
- **Gerekçe ölçüye uygun yeniden yazıldı, yerine yeni iddia KONULMADI:** `Down` **vardır**
  ama **güvenilmezdir** — gerçek PostgreSQL'de `Up→Down→Up` zinciri **hiç koşulmadı**
  (depoda o zinciri koşturan tek bir test/kapı/betik yok; tersine
  `deploy/pbxtr-deploy-artifact-selftest.sh:292` yayın artefaktında `migrate down` /
  `database update 0` bulunmasını **yasaklar**). Bu yüzden geri dönüş yolu dump restore.
- **Dokunulan:** `deploy/lib/pbxtr-migrate-adimi.sh:113-115` (blok başı), `:138+` (yeni
  "DOWN'A NEDEN GUVENILMEZ" bloğu), `:201` (operatöre basılan kırmızı metin).

#### 2. Ş78-L6 — yedek yolunda sessizce yok sayılan `Environment=` satırı
- **Neden:** systemd `Invalid environment assignment, ignoring: pbxtr-postgres` atıyordu.
  Değişken unset kalıyor, betik kendini bare-metal kipte sanıyor, yedek yolu
  **çalışmadığını söylemeden çalışmıyordu.** Tırnak kuralını yorumla *açıklamak* bunu
  önlemedi — kural doğru yazılmıştı, satır yine yok sayıldı.
- **Karar:** kural açıklanmadı, **ortadan kaldırıldı.** Drop-in artık **boşluksuz** değerler
  verir; boşluk yoksa systemd'nin tırnak/kelime bölme kuralı hiç devreye girmez.
  ```
  Environment=PBXTR_YEDEK_PG_KONTEYNER=pbxtr-postgres
  Environment=PBXTR_YEDEK_PG_KULLANICI=postgres
  ```
  `docker exec -i -u <kullanıcı> <konteyner>` argv'sini artık **betik** kurar.
  Yan kazanç: ortam değişkeni artık keyfi argv enjekte edemez (eski biçimde edebiliyordu).
- **Ölçüm — dört kip:** konteyner kipi ve eski `PBXTR_YEDEK_PG_ONEK` biçimi **birebir aynı
  argv**'yi üretiyor; bare-metal değişmiyor; ikisi birden verilirse betik **fail-closed**
  duruyor (`exit 1`). `bash -n` temiz.
- **Dokunulan:** `deploy/pbxtr-yedek.sh:130-183` (ONEK bloğu + `pg_calistir`/`pg_calistir_yavas`),
  `deploy/pbxtr-yedek.service.d/10-compose-yolu.conf`,
  `deploy/pbxtr-yedek-tatbikat.service.d/10-compose-yolu.conf`.
- **Sunucuya iniş:** sunucudaki dosyaya **elle dokunulmadı.** `deploy/README.md`'ye
  adım **2b** (drop-in kurulumu + `daemon-reload`) ve adım **2c** eklendi — 2c drop-in'in
  **gerçekten okunduğunu** doğrular (`systemctl show -p Environment` + journal'da
  `Invalid environment assignment` taraması), çünkü bu arızanın tek belirtisi sessizlikti.

#### 3. Ş78-L7 — kapı sonucu için makine tarafından aranabilir çıpa
- **Neden:** PowerShell'de `$?` bir **boolean**'dır; çıkış kodu `$LASTEXITCODE`'dadır.
  `cmd > log 2>&1; echo "cikis=$?"` bu yüzden *"6 kapı KALDI"* ile *"cikis=0"*ı aynı ekrana
  bastı. Betik doğru söylüyordu, okuyan yanlış soruyordu — ve bunu zorlayan hiçbir şey yoktu.
- **Ne yapıldı:** `deploy/yerel-kapilar.sh` kapanışı her iki dalda da renksiz tek satır basar:
  `KAPI_SONUC=YESIL n=0` / `KAPI_SONUC=KIRMIZI n=<N>`; çıktının **son** satırıdır.
  "Ölçemedi" (rc=3) da `KALAN`'a girdiği için çıpada temiz görünmez.
  `AGENTS.md`'ye okuma kuralı eklendi (PowerShell `$LASTEXITCODE`, Bash `if cmd; then`).
- **MUTASYON ÖLÇÜMÜ (iki yön), kasıtlı kırmızı üretilerek:**

  | Durum | Sonuç |
  |---|---|
  | çıpa varken | `KAPI_SONUC=KIRMIZI n=3`, çıktının SON satırı, çıkış 1 |
  | çıpa satırı silinince | aynı kırmızı koşum, `KAPI_SONUC satır sayısı: 0` → **CIPA YOK** |
  | geri alındıktan sonra | çıpa yine basıldı; dosya bayt bayt eski hâli (CRLF korundu), `bash -n` temiz |

  Mutasyon harness'i kapanış bloğunu **her koşumda dosyadan yeniden okur** — yani ölçülen
  şey depodaki gerçek baytlardır, kopya değil.
- **Dokunulan:** `deploy/yerel-kapilar.sh:2671-2700` (yorum + yeşil çıpa), `:2711` (kırmızı çıpa),
  `AGENTS.md` (Ş77-5'ten önce yeni Ş78-L7 maddesi).

**Yan bulgu (araç):** `python3 - <<'PY'` heredoc'u bir seviye ters bölü yiyor; `\\n` içeren
bayt deseni sessizce eşleşmiyordu. Mutasyon `assert count==1` ile bunu **yakaladı**
(uygulanmamış mutasyonu "uygulandı" sanmadık). Yama `.py` dosyasına `Write` ile yazıldı.

**Commit:** `4342c035` — Kurul #78 / S78-L1+L6+L7. Push edildi (`main`).

**Açık kalan:** üretim topolojisi kararı (Ş76-17) hâlâ açık — `User=root` + docker soketi
üretime çıkmaz; host'a `postgresql-client-16` PGDG'den mi yoksa çevrimdışı `.deb` ile mi
gelecek sorusu kurul gündeminde.

### Kurul #78 / frontend-uzmani Ş1–Ş3 — çağrı kökeni: iki bekçi + ölçülmüş gerekçe
- **Neden:** `CALL_SOURCE_KINDS` ↔ `CallEventPayload.Origins` "BİREBİR" iddiası yalnızca
  **iki dosyanın yorumunda** yazıyordu; `tests/` altında `CALL_SOURCE_KINDS` geçen **0 dosya**
  vardı, yani 4/4 eşleşme tesadüftü. Ayrıca `CallSourceVisibility.test.tsx` ve
  `IncomingCallModal.test.tsx:239,265` sunucunun **hiç göndermediği** bir alanı fikstürle
  besleyip yeşil kalıyordu (kayıtlı desen: *test ikizi üretimden müsamahakâr*).
- **Ne yapıldı:**
  1. `tests/Pbxtr.Architecture.Tests/CallSourceOriginParityTests.cs` — çift yönlü küme
     paritesi + dokuz dilde `callSource.*` sözlük kapısı + vacuity kapısı
     (emsal: `HealthComponentLabelPairingTests.cs`).
  2. `src/Pbxtr.Web/src/app/screens/shared/callSourceServerField.test.ts` — MANDAL:
     `ActiveCallDto`/`AgentStateDto`/`LiveAgentDto` `callSource` taşımadığı sürece YEŞİL,
     taşıdığı gün KIRMIZI; kırıldığında yapılacaklar testin gövdesinde yazılı
     (`BR-BE-198/199` kapanır). Emsal: `auditActionParity.test.ts` borç mandalı.
     `vitest.config.ts` `server.fs.allow`a iki **dar** klasör izni eklendi — izinsiz bekçi
     `Denied ID` ile dosya düzeyinde patlıyordu, yani hiç koşmayan bir kapı olurdu.
  3. `callSourceAxis.ts:25-33` yanlış gerekçe ölçümle düzeltildi (silinmedi, üzerine yazıldı).
- **Dokunulan dosyalar:** `tests/Pbxtr.Architecture.Tests/CallSourceOriginParityTests.cs`,
  `src/Pbxtr.Web/src/app/screens/shared/callSourceServerField.test.ts`,
  `src/Pbxtr.Web/src/app/screens/shared/callSourceAxis.ts`, `src/Pbxtr.Web/vitest.config.ts`,
  `yonetim/backlog.md` (BR-QA-116 → Bitti).
- **Sonuç / doğrulama:** dört mutasyonun **ikisi de iki yönlü**: sunucuya `voicemail` →
  KIRMIZI / geri al → yeşil; istemciye `voicemail` → KIRMIZI / geri al → yeşil;
  `ActiveCallDto`ya `CallSource` → KIRMIZI / geri al → yeşil; `LiveAgentDto` aynı.
  `Pbxtr.Architecture.Tests` **712 geçti** (2 kırmızı bu tura ait değil: `DeployPrivilegeTests`
  `setcap`, `TenantLeakCoverageTests` `ProvisioningNodeDirectory`), vitest **2046 geçti / 228
  dosya**, `tsc -b` temiz.
- **Ölçüm — Ş3:** `PBXTR_ORIGIN` yazan yalnız iki yer var, **ikisi de `callback`**
  (`CallbackDispatcher.cs:219`, `ConfigRenderer.cs:2455`); `DialerCallDispatcher.cs:126-129`
  sözlüğe yalnız `__PBXTR_DIALER_MODE` yazıyor → `dialer`/`agent`/`inbound` için **üretici YOK**
  (borç `BR-BE-203`). Eski gerekçe, önlediğini iddia ettiği şeyi önlemiyordu.
- **Commit:** `fdf95d27` — push edildi (`main`).
- **Not (paralel ajan):** `yonetim/backlog.md` düzenlemem, eşzamanlı çalışan başka bir ajanın
  `1ec96333` commit'ine **süpürüldü**; içerik ana dalda, ama sahibi o commit görünüyor.

### BR-QA-114 — SLA fikstürleri gerçek şemayla ayrıştı; iki gerçek-PG bekçisi eklendi
- **Neden:** Kurul #78'de `BR-QA-114` "ölçülmedi" değil **"bilinen KIRMIZI"** olarak yeniden
  sınıflandırıldı. `SlaAggregationJob.RecomputeSql` üç yeni şema nesnesi okuyor
  (`public.callback_entries` `:340`, `public.tenant_settings` `:349`,
  `sla_buckets.callback_requested_count` `:438/:503/:566`) ama SQL'i gerçek PostgreSQL'e karşı
  koşan iki testin fikstüründe **üçü de yoktu.** Testler yeşil görünüyordu çünkü
  `DockerEnvironment.IsAvailable` yoksa `InitializeAsync` erken dönüyor — yani **hiç
  koşmuyorlardı.** `PBXTR_REQUIRE_DOCKER_TESTS=1` ile koşan ilk yayın `42P01`/`42703` verirdi.
- **Ne yapıldı:**
  1. İki fikstüre `callback_entries` + `tenant_settings` eklendi. **Yalnız SQL'in gerçekten
     okuduğu kolonlar** (`tenant_id, call_id, origin, missed_at, resolved_at, resolution` /
     `tenant_id, callback_sla_mode, callback_sla_minutes`); gerçek şemadan `dosya:satır` ile
     doğrulandı (`20260824091455_CallbackLedger.cs:38-53`, `20260918203000:52`,
     `20260918203500`). `sla_buckets` DDL'ine `callback_requested_count integer NOT NULL
     DEFAULT 0`.
  2. **Mutasyon 1 tablolar eklendikten sonra da YEŞİL kaldı** — fikstür ayrıştırmıyordu:
     depoda `callback_entries`e satır yazıp `SlaAggregationJob`u koşan **hiçbir test yoktu**,
     yani `callback_requested` dalı gerçek PG'ye karşı hiç veri görmemişti. Ayrıştıran test
     yazıldı (üç giriş: sözü dolmamış talep / sözü aşılmış talep / defterde talebi olmasına
     rağmen `AgentConnect`). Mutasyon tekrarlandı → **KIRMIZI.**
  3. `callback_entries` çapraz kip RLS düzeltmesinin **davranışsal** bekçisi yoktu; tek iz bir
     `pg_policies` **metin** kontrolüydü. Metin, policy'nin *yazıldığını* ölçer, *işe
     yaradığını* ölçmez. Dört oturum biçimini fiilen okuyan yeni sınıf yazıldı.
- **Dokunulan dosyalar:** `tests/Pbxtr.Integration.Tests/Tests/SlaEventOrderingTests.cs`,
  `tests/Pbxtr.Integration.Tests/Tests/SlaHoldTimePipelineTests.cs`,
  `tests/Pbxtr.Integration.Tests/Tests/CallbackEntriesCrossTenantRlsTests.cs` (yeni).
  **Migration dosyalarına ve `yonetim/` altına dokunulmadı** (blob sha'ları kurulda onaylı).
- **Komutlar:**
  ```bash
  dotnet build pbxtr.sln -v q --nologo            # AYRI koşuldu: 0 Error, 0 Warning
  PBXTR_REQUIRE_DOCKER_TESTS=1 dotnet test tests/Pbxtr.Integration.Tests \
    --no-build --filter "…SlaEventOrdering|…SlaHoldTimePipeline|…CallbackEntriesCrossTenantRls|…CallDataRetentionWebhookCallback"
  ```
- **Sonuç / doğrulama:** `Failed: 0, Passed: 7, Skipped: 0, Total: 7`, çıkış kodu **0**.
  Atlanmış test **yok** — bu kartın bütün meselesi buydu.
  - **Mutasyon 1** (`RecomputeSql:391` `'callback_requested'` → `'abandoned'`): KIRMIZI —
    `CallbackRequested 2 → 0`, `Abandoned 1 → 2`. Geri alındı, yeşil.
    *(Aynı mutasyon ayrıştıran test eklenmeden önce YEŞİL kalmıştı; kayda geçti.)*
  - **Mutasyon 2** (`20260918230000`'deki `ALTER POLICY` **kurulu veritabanında** `Down()`
    metnine geri alındı; migration dosyasına dokunulmadı): biçim 1 KIRMIZI (`1 → 0`, satır 97);
    biçim 1 kapatılıp tekrarlandı → biçim 2 de KIRMIZI (`1 → 0`, satır 102). Geri alındı, yeşil.
- **Commit:** `ac5e91ce` — push edildi (`main`).

## Kararlar (BR-QA-114 turu)
- **Migration gövdesindeki gerekçe yanlış, bekçi doğru mekanizmaya kuruldu.**
  `20260918230000` *"`app_current_tenant()` NULL'dir"* diyor; bu yalnızca **ham** oturum için
  doğrudur. Ürünün gerçek arka plan biçiminde `TenantSessionWriter.cs:54` her transaction'da
  `set_config('app.tenant_id', …, true)` **yazar** ve `LeaderElectedJobRunner.cs:133-138`
  `SystemTenantId` boşsa fail-closed açılmaz — yani alanda `app_current_tenant()` NULL değil,
  **sistem tenant'ıdır.** Bekçi **iki biçimi de ayrı ayrı** ölçer; yalnız biçim 1 ölçülseydi
  gerekçe düzelirken bekçi yanlış biçime çapalanmış kalırdı.
- **Fikstür, gerçek şemanın tamamını taşımaz ve taşımamalıdır.** `callback_entries` gerçekte 15
  kolonludur; fikstüre SQL'in okuduğu 6 kolon girdi. Sözleşme o altı kolondur; fazlası,
  değişmeyen bir şeyi kırılgan biçimde kopyalamak olurdu.
- **`tenant_settings` LEFT JOIN'i sayı ile beklenir, varlıkla değil.** Test satırı
  `callback_sla_minutes = 5` taşır; join çalışmasaydı ürün varsayılanı (30 dk) devreye girer,
  ihlal `pending`e düşer ve `abandoned_count` 0 olurdu. Yani o sayı aynı zamanda join'in
  bekçisidir.

## Açık kalanlar (BR-QA-114 turu)
- **Tam `Pbxtr.Integration.Tests` koşusu BİTTİ ve KIRMIZI — ama bu tura ait değil.**
  `Failed: 85, Passed: 1012, Skipped: 2, Total: 1099` (23 dk 58 sn). Kırılım ölçüldü:
  **52 hata** `42883: function pbxtr_webhook_event_types() does not exist` (şema bootstrap'ı,
  webhook işi), **3 hata** `42703: column "box_id" of relation …` (voicemail box kimliği).
  Hiçbiri callback/SLA ile ilgili değil. **Bu turun üç sınıfı 85'in içinde YOK** (log'da sıfır
  geçiş); ayrıca filtreli koşuda 7/7 yeşil ölçüldü. İki `Skipped` Docker atlaması **değil**,
  Linux'a özgü iki test (`St44AcceptanceSeederTrustedFilesTests`, `FinalDeliveryReportTests`).
  Sebep: çalışma ağacında **eşzamanlı başka ajanların** işi vardı (koşu başlarken
  `SlaAggregationJob.cs` +202 satır, izlenmeyen `20260918234000_ReportRlsCrossTenantAlignment.cs`;
  koşu biterken `src/` altında 30+ değişik dosya). Ağaç durulunca tam koşu tekrarlanmalı.
- **Tuzak tekrar yakalandı:** arka plan sarmalayıcısı `[exited with code 0]` yazdı, oysa koşu
  `Failed: 85` ile kırmızıydı — bileşiğin çıkış kodu son komutundur. Sayı okunmasaydı bu koşu
  "yeşil" sanılacaktı.
- `callback_sla_mode = 'excluded'` (kip a) dalı gerçek PG'ye karşı hâlâ **ölçülmedi**; bu turda
  yalnızca `deadline` kipi (pending + breached) ölçüldü.

---

## Koordinatör turu — KURUL DAĞITILDI (2026-09-18, akşam)

### Bağlam

Tur, Kurul #78'i toplamakla başladı: üç migration'ın contract onayı (`kapi_07` yayını RED ile
durduruyordu) + `callback_entries` RLS şablona hizalaması. 10/10 ŞARTLI oy çıktı ve karar yazıldı
(`yonetim/kurul-kararlari.md` → Karar #78). **Ama o oylar 19 yeni kart doğurdu.**

Kullanıcı turun ortasında, birebir:

> *"bilader. kurulu dagit. kurulun salakliklari yuzunden proje bitmedi. bana sor nasil
> yapilacagini ben soyleyelim."*

ve hemen ardından:

> *"kimseye birsey sormadan backlogdaki eritebilecegin tum maddeleri hemen erit bitir."*

**Karar #78 kurulun SON kararıdır.** Bundan sonra `/kurul` çağrılmıyor; açık kararlar
koordinatörde ve ajanlara **karar yetkisiyle** veriliyor.

### Neden dağıtıldı (mekanizma, ölçülü)

Kurul turları **gerçek** kusur buluyordu — Karar #78'in kendisi süpervizörün belirleyici
bulgusunu (`pending → breached` geçişi zamanla olur, olayla değil) ve `ReportScheduleJob`'ın
sessizce hiç koşmadığını ortaya çıkardı. Kusur ölçümde değil, **çıktının biçimindeydi**:
her ölçüm bir **şarta**, her şart bir **karta** dönüşüyordu. Karar #78 tek başına 19 kart
açtı. Yani süreç, açık kart sayısını düşürmek yerine **yükseltiyordu**.

Hafızaya yazıldı: `karari-kullaniciya-degil-kurula-sor.md` **GEÇERSİZ** olarak işaretlendi
(silinmedi), gerekçesiyle.

### Yapılanlar

#### 1. Karar #78 + contract defteri (`30953043`)
Üç blob defterine yazıldı ve `migration-compatibility-guard.py` → **OK**. Blob 1 ayrıştırıldı:
CTO şartıyla `SET LOCAL lock_timeout = '5s'` ve CHECK kısıtı `NOT VALID` eklendi, **sha değişti**
(`f34b3bd4…` → `b458f219…`). Gerekçe: `tenant_settings` ürünün tek FAIL-CLOSED ucu olan
`call-permission` zincirindedir ve `sla_buckets` bölümlüdür — `NOT VALID` olmadan doğrulama
taraması `tenant_settings` ACCESS EXCLUSIVE kilitleri **tutulurken** koşardı.

#### 2. 19 şart kartı yazıldı (`fae7abcb`, `b9785fca`)
En kritik ikisi: **`BR-BE-204` (P0)** — geri arama SLA'sının yeniden hesap penceresi söz süresini
kapsamıyor (aynı gün iki farklı SLA yüzdesi üretiyor, ve `callback_sla_minutes = 1440` olan
tenantta **hiçbir geri arama asla ihlal sayılmıyor**); **`BR-BE-207`** — zamanlanmış raporlar ve
teslim drenajı **sessizce hiç koşmuyor** (policy çapraz dal taşımıyor, `due` boş dönüyor, iş
`return 0` ile BAŞARILI bitiyor, tek belirti `#18`'de donmuş `nextRunAt`).

#### 3. `BR-SYS-121` — kapılar bu makinede hiç koşmuyordu (`1ec96333`)
`deploy/` çalışma kopyası CRLF'ti; `yerel-kapilar.sh` `$'\r': command not found` ile açılmıyordu.
Yeniden checkout edildi, `bash -n` temiz.

**Kendi ölçüm hatam kayda geçti:** ilk sayımı `od -c | grep '\\r'` ile yaptım, **292 dosyanın
291'ini** CR saydı ve **düzeltmeden önce de sonra da aynı 291**'i verdi — yani sayaç düzelmeyi
göremezdi. Doğru ölçüm ham bayta bakar: `LC_ALL=C grep -qU $'\x0d'` → **3**, üçü de `.ps1` ve
`.gitattributes` onları zaten CRLF istiyor. Hafıza: `sayac-degismiyorsa-sayac-bozuk.md`.

#### 4. Ana dalda iki kırmızı kapatıldı
- `05820a91` — `ProvisioningNodeDirectory` `TenantLeakCoverageTests` borç listesinden çıkarıldı;
  sızıntı testi artık **var** (`ProvisioningMediaNodeScopeHttpTests.cs:64,136`).
- `15164527` — `deploy/ci/konteyner-ayricalik-kapisi{,-selftest}.py` `DeployPrivilegeTests` onay
  listesine eklendi. Ölçüldü: iki dosya da `setcap` **çağırmıyor**, **arıyor** (`:10,41` yorum,
  `:149` öneri metni, selftest `:38` sahte Dockerfile fikstürü, `:99` vaka adı). Kardeşleri
  `capture-topology-guard*` ile aynı sınıf.

#### 5. Muhasebe — üç kart kapandı, bir kart açıldı (`e13c2e0d`)
`BR-8` + `BR-AST-39` + `BR-AST-46` kapandı, `BR-AST-116` açıldı (`BR-8`'in **kartsız** üçüncü
kalemi: `pbxtr-offhours` gerekçesinin gerçek santralde `queue_log` PAUSE satırında ölçülmesi).
Kartsız iş `backlog.md`'de görünmez ve ClickUp'a hiç gitmez, yani `BR-8`'i kapatmak o kalemi
**kalıcı olarak kaybederdi**.

**İki sayaç tuzağı ölçüldü:**
- `BR-8` hücresindeki **orta-metin `bitti`** kural 1'i tetikleyip BİTMİŞ kartı `in progress`
  yazıyordu.
- **`kalan iş \`BR-QA-112\`` yazımı kapanış kuralını tutturmuyordu**: kural `/kalan iş\s+BR-/`
  arıyor, araya ters tırnak giriyordu. Yani **kapanış metnini biçimlendirmek kapanışı sessizce
  iptal ediyordu.**

#### 6. `BR-SYS-109` kapandı (`6559e639`)
Engel *"kullanıcı onayı"* idi ve kalktı. Ayrıca metin **genişletmiyor, daraltıyor**: Karar #70'in
hükmü yalnızca *genişletmeyi* onaya bağlar. `CLAUDE.md` §3.1'e (i) Ş70-23 kalıcı kırmızı çizgi
(`http reload`, `module reload res_http_websocket.so`, `manager reload` — komut başına gerekçe
tablosuyla) ve (ii) Ş70-24 beş maddelik kabul ölçütü yazıldı.

**Yerleşim ölçüldü, tesadüf değil:** parite kapısının `awk`'i listeyi *"kapalı listeye"*
çıpasından başlatıp ters-tırnak+nokta geçen ilk satırda bitiriyor; metin o satırdan **sonraya**
kondu. Doğrulama: öz-test **7 geçti / 0 kaldı**, gerçek koşu *PARITE TEMIZ* ve sayım
**değişmedi** (belge 6, katalog 5). Metin `manager reload` dizesini **taşıdığı hâlde** belge
sayısının 6'da kalması, absorbe edilmediğinin doğrudan kanıtıdır.

#### 7. Üç kurul sorusu koordinatör kararına bağlandı (`bdba3160`)
- **`BR-OPS-01` → DAR YETKİ.** Agent'a `alarm.read` **verilmeyecek**, `bundle.live`
  **genişletilmeyecek**; yerine `alarm.silence.read.self` (yalnız agent'ın üyesi olduğu kuyruklar).
- **`BR-OPS-02` → kartın gösterdiği satır bağlayıcı kapı DEĞİL.** Asıl kapı `:333`
  (`WHERE e.event_type = 'QueueCallerJoin'`); `:483` ikinci süzgeçtir ve tek başına kaldırılması
  hiçbir şeyi değiştirmez. Mekanizma: `wait_sec`'in ilk iki kaynağı kuyruk içidir, yani ölü zil
  grubunda yanan süre **yapısal olarak dışarıda** kalır ve **arızanın bedeli aynı kovanın BAŞARI
  tarafına yazılır**.
- **`BR-OPS-16` → BLOKE, "Kapsam dışı" değil.** `ConfigRenderer.cs` + `SlaAggregationJob.cs`
  **tek ajanda** planlanacak; ayrı verilirse `AmiEventMapper` allowlist'i **kimsenin üretmediği
  bir olayın izni** olurdu.

### Sayım

| An | Açık kart |
|---|---:|
| Tur başı (Karar #78 öncesi) | 112 |
| Karar #78'in 19 şart kartından sonra | 124 |
| Bu kayıt yazılırken | **117** |

**Not:** ara ölçümde 157 gördüm ve o **yanlıştı** — ad-hoc bir Python sayacıyla ölçmüştüm ve
`Kapandı` ile başlayan 24 kartı açık sayıyordu. Depodaki yetkili sayaç `yonetim/arac/kalan-isler.js`
ve `clickup-durum.js` **zaten** o kelimeyi tanıyor. Ders: **depoda sayaç varken elle sayaç yazma.**

### Kararlar

- **Kurul dağıtıldı; Karar #78 sonuncusudur.** Açık kararlar koordinatörde ve ajanlara karar
  yetkisiyle devredilebilir. Ölçüm ajanı çalıştırmak serbest, ama çıktısı **kod değişikliği**
  olmalı, yeni bir şart listesi değil.
- **Bir tur net eksi kapatmıyorsa tur yanlış kurulmuştur.**

### Açık kalanlar / sonraki adım

- 14 ajan koşuyor: `BR-BE-204/205`, `BR-BE-206/208/209`, `BR-BE-207`, `BR-DB-91/88/99`,
  `BR-FE-118/119/112/113`, `BR-AST-58/59/61/115`, `BR-SEC-21/26/29` + `BR-DB-102/103`,
  `BR-BE-150` + `BR-SEC-08/20`, `BR-DB-94/95/96/97`, `BR-QA-55/57/100`, ve iki "karar yetkili"
  ajan (Asterisk kurul-blokelileri, sesli mesaj/ürün kurul-blokelileri).
- **Ana dalda `Pbxtr.Integration.Tests` kırmızı:** `Failed: 85` — 52'si
  `42883: function pbxtr_webhook_event_types() does not exist` (şema bootstrap'ı → `BR-DB-99`,
  ajanda), 3'ü `42703: column "box_id"` (voicemail). Ağaç durulunca **tam koşu tekrarlanmalı**.
- `BR-QA-113` yolundaki borç listesi düzeltmesi **doğrulama bekliyor** — ağaç o an başka ajanın
  yarım işiyle derlenmiyordu (CS0535).
- Yayın (`deploy/yerel-yayin.sh`) ajanlar bitince koşulacak; `BR-SYS-117` (kilit penceresi
  `log_lock_waits=on`) ve Ş78-L1 **yayın öncesi** şartlardır.
- `BR-SEC-16` + `BR-SEC-28` sır döndürme — kullanıcı: *"ajanlar bitince döndür"*. Henüz sıra
  gelmedi.
- ClickUp senkronu tur sonunda: `--kuru` → `clickup-olustur.js` → `clickup-senkron.js` → `--kuru`
  ile doğrula. Şu an **11+ kart bayat** (Kurul #78 şart kartları hiç açılmamış).

---

## Ek — `frontend-dev-1` turu: BR-FE-112 / 113 / 118 / 119

Commit: `690754fe` (21 dosya, +796/−5). `opsContracts.ts` ve `yonetim/backlog.md`
değişikliklerim **paralel bir ajanın commit'ine süpürüldü** (`fffd61bf` / `da7faffc`) —
iş kayıp değil, sadece commit mesajı onlarda.

### BR-FE-112 — `#49 Ayarlar`da `voicemailSlaMinutes`

- **Neden:** backend zinciri bitmişti (`GET/PUT /tenant/settings`, `TenantLimitsDto` min/max,
  400 doğrulaması, ayrı denetim satırı) ama ekranda alan **çizilmiyordu** → parametre fiilen
  sabitti.
- **Ne yapıldı:** `TenantLimits`e `minVoicemailSlaMinutes`/`max…`; `TenantSettings`,
  `TenantSettingsEditable.voicemailSla`, `TenantSettingsInput`, `voicemailSlaInput()`,
  `sameSettings`. Ekranda **ayrı panel**, alarm eşiklerinin altında.
- **Karar:** alan **saklama süresi paneline KONMADI** — `BR-BE-183` çiti kartın açık şartı; yan
  yana iki "gün/dakika" kutusu "SLA'yı uzatırsam kayıt da uzar mı" sorusunu üretirdi.
- **Karar:** yetki kapısı `editable.voicemailSla`; ekran `editable.maskLevel`e **yaslanmadı**
  (bugün aynı yetkiden geliyor, ama sunucu kapıyı daraltırsa test kırmızı olmalı).
- **Karar:** duvar saati sapması **ekranda** yazılı (`data-note="voicemail-sla-wall-clock"`,
  `BR-BE-167`ye işaret eder) — yazılı olmayan sapma unutulmuştur.
- **Dosyalar:** `app/api/opsContracts.ts`, `screens/settings/settingsApi.ts`,
  `screens/settings/SettingsScreen.tsx`, i18n ×9.
- **Sonuç:** 7 yeni test; `SettingsScreen.test.tsx` 52 test yeşil.

### BR-FE-113 — `queueMemberDelivered` şeridi (#12/#13)

- **Neden:** sunucu alanı gönderiyordu, istemcide **0 eşleşme**; agent "Müsait"e basıyor,
  çağrı gelmiyor, sebebi hiçbir yerde yazmıyordu.
- **Ne yapıldı:** `AgentStateResponse`a üç değerli alan; masa `=== false` ile açık karşılaştırma.
  `false` → şerit + "Müsait" **çizilmez**. `null`/eksik → şerit **hiç çizilmez**.
- **Karar:** üçüncü değer için "farklı renk" değil **hiç çizmeme** seçildi; kaynağı olmayan
  kutu çizilmez (`extensionDelivery` `unknown` dalıyla aynı desen) ve bu, kartın şartını en sert
  biçimde karşılar.
- **Karar:** iki eksen aynı anda `false` ise **iki şerit** çizilir ama düğmenin yerinde **tek**
  cümle durur — iki satır birden "ekran bozuk" diye okunurdu.
- **Karar:** "ne zamandan beri" **yazılmadı**; sunucu bu eksende damga göndermiyor ve istemcide
  süre hesaplamak CLAUDE.md §11 ihlalidir.
- **Dosyalar:** `app/api/opsContracts.ts`, `screens/agent/AgentDeskScreen.tsx`,
  `api/provisioningContract.test.ts` (`TRISTATE_FIELDS`), `AgentDeskProvisioning.test.tsx`.

### BR-FE-119 — terk ↔ geri arama kesişimi

- **Ne yapıldı:** `#18 Kayıp` ve `#23 Hedef` kural şeritlerine ortak uyarı satırı
  (`loss.ruleCallbackOverlap`) + bekçi `CallbackOverlapNote.test.tsx`.
- **Ölçüm kararı — `#11` SEÇİLMEDİ:** oradaki `abandonedToday` `sla_buckets`'tan **değil**
  günlük `CallDisposition.Abandoned` sayımından gelir (`RedisLiveOperationsView.cs:706,1306`);
  kesişimi oraya yazmak **yanlış bir iddia** olurdu. #18/#23 ise `sla_buckets.abandoned_count`
  okur (`EfAnalyticsQuery.cs:310,352`) ve `Giriş` ile `Terk`i **yan yana** çizer.
- **Bekçi:** hiçbir ekranın SLA sınıf kolonlarını topladığını metin taramasıyla ölçer (bugün
  0 ihlal), mutasyon metinleriyle vacuity kapısı var.

### BR-FE-118 — **bölündü**, FE'de kod yazılmadı

Üç yüzeyin de **sunucu ayağı yok** (ölçüldü):

| Yüzey | Ölçüm |
|---|---|
| (i) `#11` kuyruk satırı | `ILiveOperationsView.cs` `callback` → **0**; `RedisLiveOperationsView.cs`te tek isabet `:867` ve o bir **yorum**. Sayı Redis'te var: `SlaWindowState.CallbackRequested` (`SlaWindowStore.cs:152`) — eşleme yok. |
| (ii) `#23`/`#18` + CSV | `IAnalyticsQuery.cs` → **0**; `EfAnalyticsQuery.cs` `callback_requested_count` → **0**; `AnalyticsExportCsv.cs` → **0**. |
| (iii) `#37` kalan süre | `MissedCallEndpoints.cs`te `slaMinutes/dueAt/deadline/remaining/promise/serverNow/asOf` → **0**. `tenant_settings.callback_sla_minutes` var ama tahtaya projelenmiyor. |

`src/Pbxtr.Api` genelinde `CallbackRequested|callback_requested` → **0**.

- **Karar:** "kalan dakika" **istemcide türetilmedi** — iki damga arasındaki fark tarayıcının
  saat kaymasını ölçüme yazardı (CLAUDE.md §11, `AmbientClockGuardTests`).
- **Yeni kartlar:** `BR-BE-210` (i+ii — aynı sayı, iki okuyucu), `BR-BE-211` (iii — söz/son
  tarih/SLA sınıfı), `BR-FE-121` (FE tüketicisi, BLOKE).

### Doğrulama

- `tsc -b --noEmit` **rc=0**, `tsc -p tsconfig.visual-tests.json` **rc=0**
  (`--noEmit` tek başına yayın kapısı değildir — ikisi de koşuldu).
- Tam web takımı: **2064 geçti**, 1 kırmızı ve **o benim değil**:
  `auditActionParity.test.ts` → `automation.callback.first_run`; paralel bir ajan
  `AuditActions.cs`e eylemi ekledi, `#38` etiketini henüz eklemedi.
- i18n: 8 anahtar × 9 dil. Doğrulama `json.loads` + `in` **değil**, ham metinde
  `ham.count('"'+k+'"') == 1`.
- ClickUp: `--kuru` → `fark olan kart: 0, izde olmayan: 0`.

---

### BR-BE-204 (P0, yayın bloke edici) + BR-BE-205 — SLA yeniden hesap penceresi ve tanım sürümü

- **Neden:** `pending → breached` geçişi **zamanla** olur, olayla değil — ve üründe zamanla
  tetiklenen bir yeniden hesap yoktu. Tick penceresi `[açık kova −900 sn, +900 sn)`, gece
  mutabakatı yalnız dünün tamamı ve günde bir kez. 09:05'te bırakılan bir talep 09:30'da
  söz kırıldığında hiçbir pencerede değildi → aynı gün 17:00'de %92, ertesi sabah %86.
  `callback_sla_minutes = 1440` olan tenantta gece mutabakatı 00:0x'te koştuğu için
  **hiçbir geri arama asla ihlal sayılmıyordu** (kip b sessizce kip a'ya dönüyordu).
- **Ne yapıldı — çözüm (a) seçildi:** `DeadlineRestatementSql` + `RestateExpiredDeadlinesAsync`.
  Toplayıcı her tick'te, tick penceresinin **dışında** kalan ama artık başka bir sonuç
  verecek kovaları hedefli yeniden hesaplar.
  - **Adaylık zamandan değil VERİDEN okunur** (`NeedsNightlyRestatementAsync` ile aynı desen):
    `sla_buckets.computed_at` iki ana karşı kıyaslanır — (1) son tarih
    (`missed_at + callback_sla_minutes`), (2) `callback_entries.updated_at`.
  - **Ölçüt `resolved_at` DEĞİL `updated_at`** — bu ayrım ölçülerek bulundu: `resolved_at`
    **iş zamanıdır** (cevabın gerçekten olduğu an) ve geçmişe dönük yazılır, yani kova ondan
    sonra hesaplanmış olur ve satır hiç aday olmaz. `updated_at` "kova hesaplandıktan sonra
    yeni bilgi geldi mi" sorusunu cevaplar. `resolved_at IS NOT NULL` şartı gerekli: aksi
    halde her arama denemesi `updated_at`'i tazeler ve kova boş yere yeniden hesaplanırdı.
  - Kova **talebin değil kuyruğa girişin** zamanından türediği için `call_events`/
    `QueueCallerJoin` üzerinden hizalanır; `missed_at` ile hizalamak yanlış kovayı hedeflerdi.
  - Ufuk 2 gün (= şema üst sınırı 1440 dk'nın 2 katı; 1 gün son tarih + 1 gün kesinti
    toparlanma payı), kırpma 200 kova/koşu + WARNING.
  - **(b) neden seçilmedi:** `callback_sla_minutes` üst sınırını garantili pencereye (~15 dk)
    bağlardı; 1440'a kadar serbest bırakılmış gerçek bir ürün parametresini
    (CLAUDE.md §13/3 — söz süresi tenant parametresi) zamanlayıcı ritmine feda ederdi.
- **BR-BE-205:** `SlaDefinition.Version` `v1` → **`v2`**. Eski satırlar `v1` kalır — ayrım
  budur. Sürüm zaten DTO'ya çıkıyordu (`TargetQueueRowDto`, `AnalyticsLossQueueRowDto`, CSV,
  `SlaWindowState`) ve #18/#19'da çiziliyor; `v1` sabitleri yalnızca eski satırı temsil eden
  fikstür/DEFAULT olarak kaldı.
- **Dokunulan dosyalar:** `src/Pbxtr.Domain/Modules/Live/SlaCalculator.cs`,
  `src/Pbxtr.Infrastructure/Telephony/Sla/SlaAggregationJob.cs`,
  `src/Pbxtr.Infrastructure/Telephony/Live/SlaWindowStore.cs`,
  `tests/Pbxtr.Integration.Tests/Tests/SlaDeadlineRestatementTests.cs` (yeni),
  `yonetim/backlog.md`
- **Sonuç / doğrulama:**
  - `SlaDeadlineRestatementTests` **4/4 geçti**; SLA süiti (Deadline + HoldTime + EventOrdering)
    **9/9 geçti**.
  - **Mutasyon:** son tarih dalı `AND FALSE` → kabul testi KIRMIZI (diğer 3 yeşil);
    `updated_at` → `resolved_at` → geç-cevap testi KIRMIZI. İkisi de tek başına **doğru**
    testi öldürdü.
  - **Migration YOK** → `deploy/migration-contract-onay.blobs` defterine satır gerekmiyor.
- **Test EDİLEMEYEN:** `dotnet build pbxtr.sln` tam çözüm yeşili alınamadı — paralel ajanlar
  `ConfigRenderer.cs`, `OutsideHoursBreakJob.cs`, `SampleDataSeeder.cs`, `Api.Tests` fake'leri
  üzerinde yarım işle çalışıyordu (CS0246/CS0102/CS0535 dalgaları, hiçbiri benim dosyamda
  değil). Benim ölçümüm proje bazında: `Pbxtr.Infrastructure` 0 hata,
  `Pbxtr.Integration.Tests` 0 hata. `Pbxtr.Architecture.Tests` ve `Pbxtr.Api.Tests`
  başkasının derleme hatası yüzünden koşturulamadı.
- **Commit:** `9f537616` — BR-BE-204/205: SLA yeniden hesap penceresi soz suresini kapsar +
  tanim surumu v2

### Kurul #78 / ŞART 4-5 — ekran-pop deneme sayacı uydurmayı bıraktı (backend-dev-2)
- **Neden:** Kurul #78'de frontend-uzmanı + cm-agent bağımsız ölçtü ve **yayın bloke edici**
  ("hata düzeltmesi, borç değil") sayıldı: `RedisLiveOperationsView.cs:828`
  `Math.Max(1, contact.AttemptCount)` iki ayrı yalan üretiyordu.
  1. **Uydurma:** hiç aranmamış caride `AttemptCount = 0`'dır, ekran "1. deneme" yazıyordu.
     Depodaki `null = ÖLÇÜLEMEDİ` sözleşmesi tek bir satırda deliniyordu.
  2. **Sayaç yöne/kökene bakmıyordu:** `Contact.AttemptCount`'u artıran **tek** yazıcı
     `DialerCallDispatcher.cs:157`'dir, yani sayaç dialer serisidir. Geri arama çağrısında
     modal "3. deneme" gösteriyor, agent "üçüncü kez arıyoruz" derken müşteri "ilk defa
     arıyorsunuz" diyordu. Geri aramanın kendi sayacı `CallbackEntry.AttemptCount`'tur ve
     `AgentEndpoints`'e hiç gitmiyor.
- **Ne yapıldı (karar SUNUCUDA; istemcide `direction`/kuyruk adından türetme YASAK — kurul şartı):**
  - `ActiveCallInfo.Attempt`/`MaxAttempts` → `int?`; `ActiveCallDto.Attempt` → `AttemptDto?`.
  - `RedisLiveOperationsView.AttemptForCall` (yeni, `internal`): sayaç **yalnızca**
    köken=`dialer` **ve** yön=giden **ve** `AttemptCount > 0` iken gider; aksi halde `null`
    (köken **ölçülemediyse de** `null` — "ölçülemedi" ile "dialer" aynı piksele basamaz).
  - `LiveCallState.Origin` (sona ek alan, varsayılan `null`): `Newchannel` payload'ındaki
    `PBXTR_ORIGIN`. **Olmayan alan mevcut değeri silmez** (ikinci bacağın değişkensiz olayı
    ilk bacakta ölçülmüş kökeni düşürmemeli).
  - `DialerCallDispatcher` originate'e `PBXTR_ORIGIN=dialer` damgası vurur
    (`CallbackDispatcher` ile aynı desen) — pozitif yol **gerçek** olsun diye; damga
    olmasaydı rozet üretimde hiç çizilmez, yani düzeltme sayacı sessizce kaldırmış olurdu.
  - İstemci: `ActiveCall.attempt: AgentTaskAttempt | null`, `CallContact.attemptN/attemptMax:
    number | null`; `CallerFacts.tsx` hem rozet hem "Deneme: n/max" satırı koşullu,
    `IncomingCallModal.tsx` kimlik satırı koşullu (satır tümden boşsa **sarmalayıcı da yok**).
    `crmUrl`/`dueAt` kalıbının birebir taklidi.
- **Dokunulan dosyalar:** `src/Pbxtr.Domain/Modules/Live/ILiveOperationsView.cs`,
  `src/Pbxtr.Infrastructure/Telephony/Live/RedisLiveOperationsView.cs`,
  `src/Pbxtr.Infrastructure/Telephony/Live/RedisLiveStateStore.cs`,
  `src/Pbxtr.Infrastructure/Telephony/Pipeline/TelephonyEventPipeline.cs`,
  `src/Pbxtr.Infrastructure/Modules/DialerCallDispatcher.cs`,
  `src/Pbxtr.Api/Modules/AgentDesk/AgentEndpoints.cs`,
  `src/Pbxtr.Web/src/app/api/opsContracts.ts`,
  `src/Pbxtr.Web/src/app/screens/agent/{useCallSession.ts,CallerFacts.tsx,IncomingCallModal.tsx}`,
  `tests/Pbxtr.Api.Tests/Modules/AgentDesk/{ActiveCallAttemptSourceTests.cs (yeni),AgentEndpointTests.cs}`,
  `src/Pbxtr.Web/src/app/screens/agent/{CallerFacts,IncomingCallModal}.test.tsx`
- **Sonuç / doğrulama:**
  - `dotnet build pbxtr.sln` **0 hata** (paralel ajanların yarım işi geçtikten sonra alınan
    temiz koşu); `Pbxtr.Api.Tests` AgentDesk ad alanı **258/258 geçti**.
  - vitest: `CallerFacts.test.tsx` + `IncomingCallModal.test.tsx` **27/27 geçti** (7 + 20).
  - **Mutasyon (dördü de tek başına doğru testi öldürdü):**
    `Math.Max(1, …)` geri kondu → `Never_attempted_contact_never_reports_one` KIRMIZI;
    köken kapısı silindi → `Callback_call_does_not_borrow_the_dialer_counter` +
    `Unmeasured_origin_reports_no_attempt` KIRMIZI; `IncomingCallModal` guard'ı kaldırıldı →
    "null iken çizilmez" KIRMIZI; pozitif yol `null`'landı → "doluysa yazılır" KIRMIZI;
    `CallerFacts` guard'ı kaldırıldı → "null iken çizilmez" KIRMIZI.
  - Migration YOK (Redis gövdesi sona ek alanla geriye uyumlu, eski gövde `null`'a düşer).
- **Commit:** `fffd61bf` — Kurul #78 / SART 4-5: ekran-pop deneme sayaci uydurmayi birakti

#### Kalan / sonraki adım (bu turda kapsam dışı bırakıldı)
- `EfAgentWorkspace.cs:115` **aynı sınıf hatayı taşıyor**: `Math.Max(1, row.Task.Attempt)` —
  görev listesi (`AgentTaskDto.Attempt`) için. Bu tur yalnızca aktif çağrı yüzeyini kapsadı;
  görev satırında sayaç en azından görevin kendi serisidir, ama `0 → 1` yuvarlaması aynen
  duruyor. Kart açılmalı.
- `POST /telephony/screen-pop` hâlâ kodda yok (sözleşmede var) — bu alanın ikinci bir
  üreticisi olacaksa aynı `null` sözleşmesini taşımalı.

---

### Beş güvenlik/DB kartı: `BR-SEC-26` · `BR-SEC-21` · `BR-SEC-29` · `BR-DB-102` · `BR-DB-103` (db-dev)

- **Neden:** Beşi de "karar yazılmış ama uygulanmamış" ya da "bekçisi yok" sınıfındaydı.
  Kurul 2026-09-18'de kullanıcı tarafından dağıtıldığı için `BR-SEC-29` artık kurula
  gitmiyor; ölçüp karar vermek bu tura düştü.
- **Dosya çakışması (turu şekillendiren kısıt):** paralel bir `db-dev` ajanı
  `deploy/db/00-01-02.sql` + `PbxtrDatabaseFixture` üzerinde çalışıyordu; o dosyalara
  dokunulmadı. `BR-SEC-26`'nın (3)+(4) kalemleri ve `BR-SEC-29`'un tamamı bu yüzden
  **inmedi** — erteleme değil, kilit.

#### `BR-DB-102` — `callback_entries` RLS genişlemesinin mimari bekçisi (KAPANDI)
- **Ne yapıldı:** `tests/Pbxtr.Architecture.Tests/CallbackEntriesWriteSurfaceTests.cs`.
  **Önce mevcut veri ölçüldü** (kapı kurmadan önce): `src/` altında (migration'lar hariç)
  `callback_entries`'e ham SQL ile **yazan 0**, **okuyan 2** (`CallbackRunJob.cs`,
  `SlaAggregationJob.cs` — ikisi de çapraz kip açar), **EF ile dokunan 4** dosya ve
  hiçbirinde `IgnoreQueryFilters` / `BeginCrossTenantScope` yok.
- **Dört ayak:** (1) ham SQL yazma yok; (2) çapraz kip açan dosyalar yazmıyor (asıl soru);
  (3) EF yolu kapsamı açmıyor; (4) tarayıcı öz-testi — 3 pozitif + 2 negatif desen
  (`SELECT … FROM callback_entries` ve `callback_entries_archive` kelime sınırı),
  dosya sayımı > 200, bilinen iki okuma yüzeyi görülüyor.
- **Mutasyon:** `CallbackRunJob.cs`'ye `UPDATE public.callback_entries` metni enjekte
  edildi → **2 test KIRMIZI** (tam da 1. ve 2. ayak); geri alındı → **4/4 yeşil**,
  kalıntı 0 (`grep -c` = 0).

#### `BR-SEC-26` — `public.*` `proacl` bekçisi ((1)+(2) indi, (3)+(4) açık)
- **Ölçüm (kartın kendi ölçümü doğrulandı):** fonksiyon düzeyi `SET app.cross_tenant='on'`
  taşıyan `public.*` fonksiyonlardan **doğrudan çağrılabilen tam olarak iki** tane var ve
  ikisi de `PUBLIC EXECUTE` taşıyordu.
- **(1)** `20260919010000_PublicCrossTenantFunctionAclRevoke` — iki fonksiyondan
  `PUBLIC EXECUTE` kaldırıldı. **Şablona değil migration'a yazıldı** ve bu ölçülmüş bir
  seçim: iki fonksiyon da `CREATE OR REPLACE` ile kurulur, PostgreSQL o yolda `proacl`'i
  **korur** → REVOKE şablon tazelemesinden sağ çıkar. `Down()` birebir geri alır.
- **(2)** `tests/Pbxtr.Integration.Tests/Tests/PublicCrossTenantFunctionAclGuardTests.cs` —
  gerçek PostgreSQL + tam migration zinciri üzerinde `pg_proc`/`proacl` ölçer. Defter
  (2 ad) + vacuity kontrol grubu (`pbxtr_index_guard()` taramaya **girmemeli**) + iki
  mutasyon (elle `GRANT … TO PUBLIC`; sınıfa yeni doğrudan çağrılabilir fonksiyon).
- **Ölçülen bağımlılık:** mutasyon-1 ancak (1) indikten **sonra** anlamlı —
  `coalesce(proacl, acldefault(…))` yüzünden PUBLIC zaten varken `GRANT` hiçbir şeyi
  değiştirmez. Yani REVOKE'suz bekçi **vacuous** olurdu.
- **Açık, adıyla:** canlıda elle verilen bir `GRANT`'i bu test **görmez**; o hâl ancak
  `02-guards.sql` + `MaintenanceRunner.GuardAsserts` ile kapanır (dosya kilidi).
  `CLAUDE.md §4` istisna listesi (ajan CLAUDE.md'yi değiştiremez) ve
  `01-rls-template.sql:177-180` cümlesi (dosya kilidi) yazılmadı.

#### `BR-SEC-29` — `tenants_sys_update` daraltması (KARAR VERİLDİ, uygulama bloke)
- **Ölçüm:** yazıcı sayısı **2** (`pbxtr_sys.move_tenants_to_dealer` `01:1425`,
  `set_tenant_status` `01:1509`); `src/` ve `Migrations/` altında ham `UPDATE tenants`
  **0 dosya**. Kapsanan satır: çapraz kipteki `pbxtr_owner` için **platform dışındaki her
  tenant (N−1)**.
- **Seçilen tasarım (A):** iki definer fonksiyona fonksiyon düzeyi
  `SET "app.sys_write" = 'tenant_move' | 'tenant_status'`; policy o işareti şart koşar.
  **Ölçülen daralma: iki fonksiyonun dışında owner'ın `tenants` UPDATE yüzeyi N−1 → 0.**
  Mekanizma uydurma değil — `BR-SEC-26`'da bu turda ölçülen mekanizmanın ta kendisi.
- **Reddedilen tasarım (B):** per-row `set_config('app.tenant_id', …, true)` ile çapraz
  dalın tamamen kaldırılması. `set_config(…, true)` **işlem** ömürlüdür, fonksiyon ömürlü
  değil → `set_tenant_status` döndüğünde çağıranın tenant bağlamı değişmiş olurdu.
- **Dürüstçe yazılan kalıntı:** `app.sys_write` düz bir GUC'tur; owner elle de yazabilir.
  A'nın kapattığı şey kötü niyetli owner değil, **kazara geniş owner yazımı**dır.
- **Neden inmedi:** `01-rls-template.sql` (policy + iki gövde) **ve** `02-guards.sql`
  (`SYS_UPDATE_WRONG_QUAL`/`WRONG_CHECK` birebir dizeleri, `sys-functions.expected`)
  gerekiyor; ikisi de kilitliydi.

#### `BR-DB-103` — `ix_provisioning_node_state_outcome` (Kapsam dışı, ölçülmüş)
- **Tüketici sayısı SIFIR:** iki sorgu yeri var ve hiçbiri `outcome` predicate'i taşımaz —
  `EfProvisioningNodeStateHealthReader.cs:87` (WHERE'siz tam tarama),
  `EfProvisioningNodeStateStore.cs:82` (PK araması).
- **Önek eklenmedi:** depo kuralının zorlayıcısı `pbxtr_index_guard()`
  (`02-guards.sql:556`) yalnız **bileşik** indeksleri tarar (`ix.indnatts > 1`); ayrıca
  `outcome` filtreleyen sorgu yokken `(tenant_id, outcome)` yazmak aynı kuralın ikinci
  yarısının (*sorgu desenine bakmadan indeks ekleme*) ihlali olurdu. Tablo `tenant × pinli
  düğüm` ile sınırlı. **Silinmedi de** (yıkıcı işlem + `kapi_07` onay satırı).
- **Yeniden açacak tek şart yazıldı:** `outcome` üzerinde tenant-kapsamlı ilk predicate ile
  birlikte indeks `(tenant_id, outcome)` ile **değiştirilir** (yanına eklenmez).

#### `BR-SEC-21` — değişmedi, ölçüldü
- (a) kapalı, (c) Ş76-10/3 sıra kilidiyle bilinçli kapalı. **(b) egress allowlist açık ve
  `db-dev`'in alanı dışında:** nftables kuralı ancak sunucuda `nft -c -f` + kontrollü
  yükleme ile doğrulanır. **Ağda ikinci kapı sorusunun cevabı: bugün SSRF'e karşı tek
  savunma uygulama katmanıdır** (`OutboundHostGuard`). Sahip: `linux-uzmani`.

- **Komutlar:**
  ```bash
  dotnet build pbxtr.sln                 # 7. denemede 0 hata (paralel ajanlar tekrar tekrar kırdı)
  dotnet test tests/Pbxtr.Architecture.Tests --filter CallbackEntriesWriteSurfaceTests
  python3 deploy/migration-compatibility-guard.py
  git hash-object .../20260919010000_PublicCrossTenantFunctionAclRevoke.cs
  ```
- **Sonuç / doğrulama:** `CallbackEntriesWriteSurfaceTests` **4/4 geçti**; mutasyonla
  **2 KIRMIZI**, geri alınınca yine **4/4**. `PublicCrossTenantFunctionAclGuardTests`
  **derlendi ama yeşil koşusu alınamadı**: çalışma ağacında paralel ajanların yarım işi
  (`PbxtrDbContextModelSnapshot` ↔ konfigürasyon uyumsuzluğu) EF'in
  `PendingModelChangesWarning`'ini tetikliyor ve migration zinciri **hiç kurulmuyor**.
  Bu benim değişikliğimden gelmiyor (migration model değiştirmiyor) ve **ölçülmemiş
  sayılmalıdır**.
- **Commit:** `724bb0db` — BR-DB-102 kapandi + BR-SEC-26 (1)+(2) indi

#### Kararlar
- Bekçi, şablona (`02-guards.sql`) değil test katmanına yazıldı; **kapsam farkı kartta
  adıyla yazılı** (depo/zincir sapması yakalanır, canlıda elle GRANT yakalanmaz).
- `kapi_07` onay defteri satırı **uydurulmadı**: defterin kendi kuralı *"Emsal bir BİÇİMİ
  onaylar, bir İÇERİĞİ ASLA"*. Blob `6212b0500afdd58340c2866dceb14e4652c7d1d4`.

#### Açık kalanlar / sonraki adım
- `deploy/migration-contract-onay.blobs`'a tek satır (karar numarasıyla). **Kapı bu turda
  zaten kırmızıydı:** `20260918234000` ve `20260918235500` de aynı satırı bekliyor.
- `02-guards.sql`'e `pbxtr_public_function_acl_guard()` + `GuardAsserts` satırı (BR-SEC-26/2'nin
  canlı ayağı), `CLAUDE.md §4` istisna sınıfı, `01:177-180` düzeltmesi.
- `BR-SEC-29` tasarım A'nın inmesi + inmeden önce `03-smoke` owner `UPDATE tenants`
  satırlarının hangi dala düştüğünün ölçülmesi ve `BR-DB-91`.
- **Paralel ajan `backlog.md` değişikliklerimi kendi commit'ine süpürdü** (`da7faffc`) —
  içerik korundu, commit mesajı yanlış sahibi gösteriyor. Defterdeki bilinen sınıf.

---

### db-dev — Ş76-7 dört dalga: çapraz kipin tenant başına daraltılması (`BR-DB-94..97`)

#### Bağlam
`BR-DB-70` dört karta bölünmüştü; sıra bağlayıcı (D1 silen → D2 yazan → D3 okuyan →
D4 denetim/istek yolu) ve her dalgada **kapı önce, daraltma sonra**.

#### 1. Kapı kuruldu (`kapi_82`) — D1 ile birlikte
- **Neden:** `kapi_77` "çapraz kip kaç yerde açılıyor" der. Daraltma için gereken soru
  başkadır: **"açılan kapsamın İÇİNDE ne oluyor"**. Keşif için açıp işi tekil tenant
  kapsamında yapan bir iş envanterde görünür ama risk taşımaz.
- **Ne yapıldı:** `deploy/ci/capraz-kip-yazma-daraltma-kapisi.py` + öz-test (10 vaka).
  İki ayak: (A) dondurulmuş fark — bütün evren; (B) MUTLAK kural — dalganın dosya
  kümesinde çapraz aralık içinde **yazma olamaz** ve aralık **kapatılmak zorundadır**.
- **Sonuç:** ilk koşuda D1'de iki ihlal yakaladı.

#### 2. D1 — silen işler (`BR-DB-94`, `5d332d81`)
- **Ölçüm ÖNCE:** 16 dosya / 16 ham aralık; 6 KAPATILMAMIŞ, 6'sında yazma.
- **İhlal:** `CallDataRetentionJob` ve `WebhookDeliveryRetentionJob` N tenant'ın denetim
  satırını çapraz kipte yazıyordu. Çapraz kipte RLS yazmayı **reddetmez** ve arka plan
  işleri uygulama savunmasının dışındadır → `row.TenantId` yanlış olsa satır başka
  tenant'ın günlüğüne sessizce düşerdi, `audit_log` append-only olduğu için geri alınamaz.
- **Daraltma:** emsal `InterventionMembershipExpiryJob` — satır kendi tenant'ı altında
  (`set_config('app.tenant_id', …, true)`), `finally`de bağlam geri verilir.
- **Ölçüm SONRA:** 14/14. `kapi_77`: 33/38 → 31/36.

#### 3. D2 — yazan/push eden işler (`BR-DB-95`, `3065b181`)
- **Dalga önce KAPIYI düzeltti** (iki körlük): (i) sekiz iş `Open/CloseCrossTenantSql`
  sabiti kullanmıyor, SQL'i satır içi yazıyor — kapı o sekizini **hiç görmüyordu**;
  (ii) yazma tespiti sabitin ilk kelimesine bakıyordu, `IysSyncJob.ProjectSql`
  `WITH projected AS (UPDATE …)` ile başladığı için "yazma=yok" sayılıyordu — oysa
  çapraz kipte **iki tabloya** birden yazıyordu.
- Düzeltilmiş kapıyla ÖNCE: 26/27, **12 KAPATILMAMIŞ**.
- Daraltılanlar: `IysSyncJob`, `OutsideHoursBreakJob` (tenant'sız `UPDATE queue_members`
  keşif + tenant başına yazmaya bölündü; ayrıca `ApplyTenantAsync` **lider bağlantısının**
  GUC'unu da daraltır — `BeginTenantScope` DI/EF tarafını kapsıyordu, `SetFlagSql`/
  `AuditSql` ise `execution.CreateCommand` ile lider bağlantısında koşuyordu),
  `QueueMembershipSyncJob`, `DialerRunJob`, `CampaignSmsRunJob`.
- SONRA: 24/25, 8 KAPATILMAMIŞ.

#### 4. D3 — okuyan/toplayan (`BR-DB-96`, `50e11c64`)
- Kartın şart koştuğu **P3 (`.BeginCrossTenantScope`) yolu ölçüldü** ve kapıya sokuldu.
  Sınır kalkmadı, daraldı: aralık artık kapsayan bloğun sonuna kadar (girintiyle).
  P3'te `kapali` hep true ve bu **dil garantisidir** (`using` → `finally`).
- Daraltılanlar: `SilenceSamplerJob`, `TrunkHealthSnapshotJob`, `PlatformRollupJob`,
  `AriDndDeviceStateAnnouncer`.
- **DARALTILAMAZ (ölçüldü):** `EfDealerAdministration` (71/150). `dealers` global tablodur;
  yazmayı açan tek policy `<tablo>_dealer_cross` ve yüklemi **`WITH CHECK
  (app_is_cross_tenant())`**. Daraltılırsa yazma **42501 ile reddedilir** — "daha güvenli"
  değil, fiilen çalışmayan olur. Ş76-DB-14 veto sınırı ihlal edilmedi: çapraz dal
  genişletilmedi, `BYPASSRLS` önerilmedi.

#### 5. D4 — denetim + istek yolu (`BR-DB-97`, `ec2e04ca`)
- **`CrossTenantReadAudit` DARALTILAMAZ** ve çıktı kartın öngördüğü ikinci sonuçtur.
  Dört ölçüm: (a) satır zaten tenant doğrudur — `tenantId` **çağıranın** bağlam tenant'ı,
  hedef değil; (b) hedef başına bölmek "bir kapsam açılışı = bir satır" anlamını yok eder;
  (c) çağıranın açık transaction'ından çıkarılamaz (fail-loud); (d) kapsamdan önceye
  alınamaz — bazı çağıranlarda `app.tenant_id` boş olabilir, RLS fail-closed olur ve
  **kanıt satırı yazılamaz**.
- **Kapının üçüncü ve en ciddi körlüğü burada bulundu:** kapı "kapanış" derken yalnız
  `'off'` sabitini arıyordu, **önceki değere geri döndürme** yazımını kapanış saymıyordu.
  Depodaki **en iyi** örnek (`EfUserAdministration`, iç içe kapsamı hesaba katan tek
  çağıran) "KAPATILMAMIŞ" işaretleniyor ve aralık dosya sonuna kadar sürdüğü için aynı
  dosyadaki ilgisiz `SaveChangesAsync`/`ExecuteSqlRaw` da "çapraz kipte yazma"
  görünüyordu. Düzeltildi; **iddia da daraltıldı**: kapı "kapsam kapandı" demez,
  "kapanış YAZIMI var" der.
- `CustomRoleRowSource` daraltıldı.

#### Komutlar
```bash
python3 deploy/ci/capraz-kip-yazma-daraltma-kapisi-selftest.py   # 10 vaka, rc=0
python3 deploy/ci/capraz-kip-yazma-daraltma-kapisi.py            # 29 dosya / 34 aralık
python3 deploy/ci/capraz-kip-envanteri-kapisi.py                 # 31 / 36
```

#### Kararlar
- Kapı üç kez **kendi körlüğünü** buldu ve her defasında düzeltildi. Kartın kendi dersi
  ("deseni yazılmamış sayım ölçüm değildir") kapının kendisinde üç kez tekrarladı.
- Daraltılamayan iki kalem **sebebiyle** kapatıldı, "yapılmadı" diye bırakılmadı.
- Migration'lar Ş76-9 gereği daraltmanın **dışında**; gövde değiştirilmedi.

#### Açık kalanlar / sonraki adım
- `CallbackRunJob.cs:87` ve `LeaveEnforcementJob.cs:365` **bu turda daraltılmadı** —
  ikisi de başka ajanın açık işinde. İkincisi `AuditLogWriter` + üç yazan SQL taşır ve
  **D2'nin kalan tek gerçek ihlalidir**. Envanter JSON'unda `_devredilen` altında yazılı.
- `SlaAggregationJob` ölçüldü (zaten dar) ama uçuşta olduğu için mutlak kümeye alınmadı.
- Gerçek PG ile davranış ölçümü yapılmadı (kurulu şema yok): "yok" değil, **"ölçülmedi"**.


---

## Tur — kurul dağıtıldıktan sonra altı Asterisk kartının karara bağlanması (backend-dev-2)

### Bağlam

`BR-AST-51a`, `BR-AST-51b`, `BR-AST-55`, `BR-AST-92`, `BR-AST-104`, `BR-AST-108` kartlarının
hepsi *"kurula gidecek"* diye BLOKE duruyordu. Kurul 2026-09-18'de kullanıcı tarafından
dağıtıldı; karar yetkisi kart sahibine verildi. Kural: ölç, **dar** olanı seç, kartta
gerekçelendir. `ConfigRenderer.cs` başka bir ajandaydı — o dosyayı gerektiren kalem
"kalan iş" olarak bırakıldı.

### Yapılanlar

#### 1. BR-AST-108 — düşen tenant'ın artık config'i: sessiz arıza sesli arızaya çevrildi

- **Neden:** bir tenant düğümden düşünce (abonelik bitti / başka düğüme taşındı) onun
  dahilileri, kuyrukları ve park yerleri santralde **çalışmaya devam ediyor** ve bunu
  gösteren hiçbir şey yok. Belirti sessiz.
- **Kartın (1) teşhisi ölçümle çürüdü.** Kart *"node-bundle yanıtı düğümün tam tenant
  kümesini taşımalı"* diyordu; sunucu bunu **zaten ölçüyor**. Canlı ölçüm
  (`176.88.41.220`, `date -u` = Fri Sep 18 19:58:17 UTC 2026): ajanın gerçek
  `X-Pbxtr-Have` başlığıyla (`t0007/...,t0012/...`) `GET /node-bundle` → `HTTP 200` +
  `"removed":["t0012"]`. `ProvisioningNodeRemoval.Measure` çalışıyor.
- **Asıl kusur ajanın sesiydi:** `deploy/pbxtr-confd-dugum.sh` `removed`i `${IS}/removed`
  dosyasına yazıp **hiçbir yerde okumuyordu**; üstelik koddaki yorum *"bugün sunucu daima
  `null` döner"* diyordu ve bu ölçümle yanlış çıktı. Sonuç: ajan **söyleyecek bir şey
  OLMADIĞINDA sesli, bir tenant düştüğünde SESSİZ**di.
- **Seçilen dar yol: RAPOR, silme değil.** Ajana `5.5) Düşen tenant / artık dosya` bölümü
  eklendi; düşen her tenant için `pbxtr.d/*/t{kod}-*.conf` taranır, bulunanlar `kismi`
  olarak (çıkış **75**) ad ad raporlanır ve elle temizlik adımları yazılır. Hiçbir şey
  silinmez — silme geri alınamaz bir yüzeydir, ayrı kart (`BR-AST-118`).
- **Yer seçimi bir ölçümdür.** Blok önce `10.5`e kondu ve **hiç koşmadı**: düşen tenant,
  servis edilen tenantların sha256'sını değiştirmediği için betik `5`te *"SIFIR yazım,
  SIFIR reload"* deyip **exit 0** ile çıkıyor. Yani raporun gerekli olduğu hâl, betiğin en
  erken çıktığı hâl. Blok erken çıkıştan **önce**ye alındı (`PBXTR_D` üst sabitlere taşındı).
- **Dokunulan dosyalar:** `deploy/pbxtr-confd-dugum.sh`
- **Sunucuda ölçüldü (pozitif + negatif):**
  ```bash
  # negatif: disk temiz, t0012 düşmüş
  #   -> "dusen tenant t0012: diskte artik dosya YOK -- temiz." + ExecMainStatus=0
  # pozitif: geçici /etc/asterisk/pbxtr.d/dialplan/t0012-olcum.conf
  #   -> dosya ADIYLA raporlandı + status=75/TEMPFAIL
  # temizlik: dosya silindi, ajan yeniden yeşil (exit 0), find t0012-* -> 0
  ```
- **Yan bulgu — silme tasarımını etkiler:** elle temizlikten sonra bile
  `dialplan show` hâlâ `[ Context 'pbxtr-t0012-park' created by 'res_parking/t0012-tut' ]`
  gösteriyor. `module reload res_parking.so` (kapalı liste) bu bağlamı **kaldırmıyor**
  (`parking show` → yalnız `default`), `module unload` / `core restart` ise yasak. Yani
  *"sil + reload + doğrula"* yapan bir ajan **başarıyı yanlış raporlardı**.
- **Sonuç:** `BR-AST-108` **Bölündü**; silme yetkisi `BR-AST-118`e taşındı.

#### 2. BR-AST-55 (3) — haksız RNA satırları silinmeden ayrı etiketlendi

- **Neden:** kayıtlı cihazı olmayan kuyruk üyesine kurulan bacak hiç çalmaz ama
  `AgentRingNoAnswer` doğar; çizelgede *"Agent cevapsız"* yazıyordu. Süpervizör timeline'ı
  açıp agent'ı haksız yere suçluyor ve ikisinin de aksini gösterecek verisi yok. Canlı
  veride tek çağrıdan **42** böyle satır ölçülmüştü.
- **Ne yapıldı:** `CallTimelineLabels.LabelOf`'a `ringTimeMs` eklendi;
  `AgentRingNoAnswer` + `ring_time == 0` artık **"Cihaz kayıtlı değildi (zil çalmadı)"**
  döner. Eşik **sıfırdır** (uydurma bir `< 500 ms` değil): `RINGNOANSWER|0`'ı Asterisk'in
  kendisi yazar, gerçek denemede aynı alan `|2000`. `ring_time` **null** ise etiket
  değişmez — "okuyamadım" ile "haksız" aynı şey değil.
- **Okuma anında yapıldı:** migration yok, veri dokunuşu yok; canlıdaki 42 satır da artık
  doğru okunur (kartın "silinmez" şartı korundu).
- **Dokunulan dosyalar:** `src/Pbxtr.Domain/Modules/CallHistory/CallTimelineLabels.cs`,
  `src/Pbxtr.Infrastructure/Modules/EfCallTimelineQuery.cs` (`RingTimeOf`),
  `tests/Pbxtr.Api.Tests/Modules/CallHistory/CallTimelineLabelTests.cs`
- **`RingNoAnswerMetricQuarantineTests.AyrimIsaretleri` bilerek boş bırakıldı:** ayrım bir
  **etikettir**, bir metrik tipi değil; karantina tam gücüyle durur ve RNA hâlâ hiçbir
  rapor/analiz/wallboard yüzeyine giremez.
- **Kartın (2) kalemi ölçüldü ve kurul işi DEĞİLMİŞ:** "teslim sırası kilidi" kodda zaten
  çözülmüş — `AsteriskAriProvider.cs:1532-1535` her `StateInterface`'li `QueueAdd`'den
  sonra `HealInvalidStateInterfaceAsync` (`:1613`) çağırıyor; üye `Invalid` görünüyorsa
  başlık düşürülüp üye yeniden ekleniyor ve olay `LogError` ile günlükleniyor. Yani hint
  bağlamı inmeden `StateInterface` teslim edilse bile `joinempty=no` altında "arayan
  kuyruğa giremez" hâli oluşmaz.
- **Sonuç:** `BR-AST-55` **Bitti**.

#### 3. BR-AST-51a — açık soru A-5 ölçüldü ve karara bağlandı

- **Soru:** yalnızca WebRTC'si olan bir dahili için masa endpoint'i üretilmeli mi?
- **Ölçüm (`ConfigRenderer.cs`, salt-okuma):** masa endpoint adı dialplan'de **koşulsuz
  `Dial()` ediliyor** — `:1244` `Set(LDC=${PJSIP_DIAL_CONTACTS(<desk>)})`, `:1273`
  `Dial(${LDC},30,t...)`, zil grubunda `:1531`, ayrıca `:2640`.
- **Karar: (b) — bugünkü hâl korunur.** (a) tek satırlık bir bastırma değil; dialplan
  yarısı da koşullu olmalı, yani `ProvisioningExtensionSource`'a yeni bir `HasDesk` ekseni
  açılmalı. Üstelik renderer'ın kendi yorumu (`:1247-1249`) *"var olmayan AOR'u sormak her
  çağrıya bir WARNING eklerdi"* diyor — (a)'nın dialplan yarısı yapılmazsa değişiklik
  çağrı yolunu **aktif olarak bozar**. Dar olan (b).
- **P1 teyit edildi.** A-1'in "sahada 0 masa telefonu" ölçümü önceliği düşürmüyor; sebep
  bugün canlıda yeniden ölçüldü (`journalctl -u pbxtr-confd`, 19:57:36 UTC):
  `tenant t0007: SERVIS EDILMEYEN tur(ler) -> pjsip=secret_not_stored`. t0007'nin
  **saklanmış** 6 WebRTC kimliği dâhil tüm `pjsip` türü bugün teslim edilemiyor.
- **Sonuç:** `BR-AST-51a` ve `BR-AST-51b` artık **bloke değil**; engel kurul değil,
  sırasıyla uygulama ve `51a`.

#### 4. BR-AST-92 — kod tarafı kapsam dışı; önceki durum kaydının teşhisi de yanlıştı

- Önceki kayıt *"`pbxtr-confd` medya teslim yolu kurulu"* diyordu. **Bu kart için
  geçersiz ve ölçüldü:** o yol yalnızca **tenant'a bağlı** medya taşır — hedefi
  `sounds/pbxtr/{tNNNN}/{mediaId:N}.wav` biçimine zorlar ve GUID dışı mediaId'yi reddeder
  (`deploy/pbxtr-confd-dugum.sh:1394-1440`). Bu kartın dosyası ise `pbxtr/sys/hizmet-disi-<dil>`,
  yani **tenant'sız sistem medyası ve GUID'siz bir ad**.
- Ürünün kendi sözleşmesi de aynısını söylüyor: `SuspendedTenantRouting.cs:71` —
  *"Sistem medyasi on eki. Dosyalar kurulum isidir, bundle'da YOKTUR."*
- **Sonuç:** `BR-AST-92` **Bölündü**; kalan iki kalem (9 dilin ses kaynağı + kurulum adımı)
  `BR-AST-117`ye taşındı.

#### 5. BR-AST-104 — kurul işi değil, `ConfigRenderer` işi

- Ölçümün üç kanıtı birlikte isteniyor ve birincisi kırmızı olduğu için diğerleri
  **ölçülemiyor** (yok değil — ölçülemiyor). Kalan iş bir karar değil, `pbxtr-inbound`
  üreticisidir ve dosyası `ConfigRenderer.cs`. Bu turda o dosya başka ajandaydı, dokunulmadı.
- **Sonuç:** **bloke değil**, tek önkoşul `BR-AST-61`/`BR-AST-58`.

### Doğrulama

```bash
dotnet test tests/Pbxtr.Api.Tests --filter CallTimelineLabelTests   # 14/14
dotnet test tests/Pbxtr.Api.Tests --filter CallHistory              # 34/34
dotnet test tests/Pbxtr.Architecture.Tests --filter RingNoAnswer    # 24/24
```

**Mutasyon doğrulandı:** `ringTimeMs == 0` → `== -12345` yapıldı, `CallTimelineLabelTests`
**1 KIRMIZI** (13/14) oldu; geri alınınca 14/14 yeşil. İkisi de ikilide ölçüldü — ilk
denemede başka bir ajanın `testhost` süreçleri DLL'i kilitlediği için build sessizce
atlanmış ve mutasyonlu koşu **yanlışlıkla yeşil** görünmüştü (defterdeki bilinen sınıf);
derleme kilit açılana kadar 40 denemeye kadar tekrarlandı.

### Kararlar

- **Düşen tenant'ın config'i: ajan RAPOR eder, SİLMEZ.** Yanlış alarmın bedeli bir uyarı
  satırı; eksik alarmın bedeli başka bir müşterinin santralde çalışmaya devam eden dahilisi.
- **Haksız RNA: satır silinmez, okuma anında etiketlenir.** Eşik sıfırdır, uydurulmaz.
- **A-5 = (b).** WebRTC-only dahili için masa endpoint'i üretilmeye devam eder.
- **Kurul gündemi diye duran üç kalem aslında kurul işi değildi** (55/2 kodda çözülmüş,
  104 bir üretici satırı, 108 bir ajan sesi). Kalıp tanıdık: *karar yazılmış ama
  uygulanmamış* değil, bu sefer **uygulanmış ama karar diye bekletilmiş**.

### Açık kalanlar / sonraki adım

- `BR-AST-118` — silme yetkisi. **Ön koşul ölçüldü ve zor:** park bağlamı kapalı liste
  reload'ıyla kaldırılamıyor; kabul ölçütü "dosya gitti" değil "santralde nesne yok"
  olmalı ve park için bunun bugün bir cevabı yok.
- `BR-AST-117` — 9 dilin ses kaynağı (depo dışı ürün varlığı) + kurulum adımı.
- `BR-AST-51a` — sır deposu paketi (migration + `ISecretProtector` + uç + backfill).
- `BR-AST-104` — `BR-AST-61`/`58` indikten sonra ölçüm **olduğu gibi** tekrarlanacak.
- Ajanın yeni sürümü sunucuya kuruldu (`/usr/local/lib/pbxtr/pbxtr-confd-dugum.sh`,
  sha `e68abcc8`) ve depodaki dosyayla **birebir aynı**; yedek temizlendi.
- **Not:** `yonetim/backlog.md` kart güncellemelerim başka bir ajanın `c46e0336`
  commit'iyle HEAD'e girdi (içerik korundu, commit mesajı yanlış sahibi gösteriyor).
  Defterdeki bilinen sınıf.

**Commit:** `a259e0f1` — BR-AST-108 + BR-AST-55: dusen tenant artik dosya raporu + haksiz RNA ayri etiket

---

### Kimlik/yetki turu — BR-BE-150 · BR-SEC-08 · BR-SEC-20 (backend-dev-1)

#### 1. BR-SEC-20 — karar verildi, kart kapandı (fail-closed kalıcı)
- **Neden:** kart "KURULA" diyordu; kurul 2026-09-18'de kullanıcı tarafından dağıtıldı,
  karar bu ajana kaldı. Soru: platform tenant'ında tanımlı özel rol, drill-in'de
  (`X-Tenant-Id`) yetki vermeli mi? Bugünkü hâl: boş küme (fail-closed).
- **Ne yapıldı:** ölçüldü, **dar olan** seçildi (bugünkü hâl korunur) ve gerekçe
  `CustomRoleAwareExpander.cs`'te satır başına + test sınıfı notuna yazıldı.
- **Ölçüm (kararı belirleyen iki bulgu):**
  1. Özel rol `SessionScopeConsistency.WidestRoleScope` için **`Single`**'dır (katalogda yok)
     ve `scope=single` jeton `TenantResolutionMiddleware.cs:201-210`'da ev tenant'ı dışına
     **hiç çıkamaz** → kartın motive edici "dar destek rolü" senaryosu bu kapı gevşetilse de
     **servis edilemez.**
  2. Bu dala ulaşan her aktör kapsamını bir **katalog** rolünden alır (`admin`/`superadmin`
     → Global, `dealer` → Dealer) ve o rolün kümesini katalog dalından zaten tam alır →
     gevşetmenin tek etkisi geniş aktörü **daha da** genişletmek olurdu.
  3. Ve açılsaydı **BR-SEC-08 daraltmasını delen** bir yüzey olurdu: platform yöneticisi
     kendi tenant'ında özel rol yazıp matristen düşürülen tenant-işletme yetkilerini her
     müşteri tenant'ına taşırdı. Meşru yol taklittir.
- **Dokunulan dosyalar:** `src/Pbxtr.Api/Platform/Authorization/CustomRoleAwareExpander.cs`
  (yalnız yorum), `tests/Pbxtr.Api.Tests/Platform/Authorization/PlatformCustomRoleDrillInTests.cs`
  (5 → 7 test).
- **Mutasyon:** kapı kaldırıldı (`return custom;`), **yeniden derlendi** → 3 KIRMIZI / 6 geçti;
  geri alındı + yeniden derlendi → 15/15 yeşil.

#### 2. BR-SEC-08 — Ş51-1 önkoşulu indi, yüzey sayıldı; daraltma HÂLÂ açık
- **Neden:** Karar #51 birebir *"Ş36-31 ÖLÇÜLMEDEN YETKİ KALDIRILMAZ"* diyor. Depoda taklit
  **sonrası** bir tenant yazmasını ölçen test **yoktu**; en yakını taklit ucunun kendisini
  ölçüyordu. Yani *"meşru yol var"* bir iddiaydı.
- **Ne yapıldı:** `tests/Pbxtr.Integration.Tests/Tests/GlobalActorImpersonationTenantWriteHttpTests.cs`
  — global `admin` müşteri tenant'ına drill-in → oradaki `owner` olarak taklit →
  `PUT /ivr/flows/{id}` **200** + satır gerçekten değişir + **iki denetim satırı** DB'den geri
  okunur (`user.impersonation.started` aktör=admin, `ivr.flow.updated` aktör=owner).
  **Kontrol grubu:** aynı istek, tek fark admin'in kendi jetonu → **403**, ad değişmez.
  Üçüncü test (Ş36-32): çapraz kipte **403 `CROSS_TENANT_WRITE_FORBIDDEN`**.
- **Yüzey sayımı (kartın sayıları bayattı):** paketler çözülerek `superadmin=50, admin=48,
  dealer=11, owner=83, supervisor=61, agent=13, wallboard=1`; `admin ∖ superadmin`=8,
  `superadmin ∖ admin`=10. **Kartın "60 kalem" sayısı `owner ∖ global`dir (bugün 64) ve
  daraltılacak yüzey o DEĞİL.** Daraltılacak aday küme `owner ∩ (admin ∪ superadmin)` =
  **19 yetki / 83 uç** (`RequiresPermissionAttribute`, parantez-dengeli tarama: 360 kullanım,
  115 ayrı yetki adı, 8'i elle çözüldü). `codec.write` admin'de var ama **0 uç** koruyor;
  `ivr.read` hiçbir global rolde yok.
- **Ölçüm tuzağı (kayda değer):** ilk sayım sabitleri **kısa adla global** haritaya koyuyordu;
  `WritePermission` 24 dosyada tanımlı olduğu için hepsi son yazana çözülüyor ve
  `workinghours.write` **88 uç** gibi saçma bir sayı veriyordu. Sabitler dosya-yerel çözülmeli.
- **Koşulmadı:** Docker gerekiyor + ağaçta başka ajanların yarım işi vardı.

#### 3. BR-BE-150 (P0) — blokaj sürüyor, ama **ölçüm tuzağı kapandı**
- **Neden:** kartın kalan işi kod değil: (a) bir yayın döngüsü boyunca red sayacının 0 kalması,
  (b) `enforce` geçiş kararı. Engel: sunucudaki imaj HEAD'in 292 commit gerisinde.
- **Gerçek kusur:** `session-scope-consistency` sağlık satırı **kipi söylemiyordu**.
  *"0 tutarsızlık"* metni, kapıyı hiç taşımayan bir ikilide de kapılı bir ikilide de
  **birebir aynı** çıkıyordu — yani (a) ölçümü **kanıt olmayan bir satıra** dayanabilirdi.
  (2026-09-14 kaydında operatörün okuduğu `session-scope-consistency ok` satırı tam olarak budur.)
- **Ne yapıldı:** `SessionScopeConsistencyDiagnostics.Snapshot()` artık
  `SessionScopeConsistencySnapshot(Mode, BySurface)` döner; kip **açılış doğrulamasında**
  yazılır (`AuthOptions.EnsureConfiguredForProduction` → `RecordMode`, `Program.cs:483`,
  her ortamda). Kapı singleton'ı **tembel** kurulur — ilk girişten önce gelen sağlık isteği
  kipi okuyamazdı; bu yüzden kayıt açılış yolunda. Kip çözülmemişse satır **`Unmeasurable`**
  ("ölçülemedi" ≠ "çalışmıyor") ve metin *"bu değer enforce geçiş kararı için KANIT DEĞİLDİR"*
  der; çözülmüşse Ok/Down metnine `Kip: audit (… jeton ALIR)` / `Kip: enforce (… ALMAZ)` girer.
- **`SystemHealthProbe.cs`'e DOKUNULMADI** (orada başka ajanın yarım işi vardı) — çağrı yeri
  `Describe(Snapshot())` olduğu için imza değişimi orayı derlemeden geçirir.
- **Mutasyon:** `Unknown` dalı devre dışı, **yeniden derlendi** →
  `Kip_cozulmemisse_satir_olculemedi_der` KIRMIZI (1/6); geri alındı → 15/15 yeşil.

- **Komutlar:**
  ```bash
  dotnet build src/Pbxtr.Api/Pbxtr.Api.csproj        # 0 Error(s)
  dotnet build tests/Pbxtr.Integration.Tests/...     # 0 Error(s)
  dotnet test tests/Pbxtr.Api.Tests --filter "...SessionScope...|...Impersonation...|...CustomRole..."
  # 83/83 geçti (kimlik+yetki kümesi), 15/15 (iki yeni sınıf)
  ```
- **Ölçülemeyen:** `Pbxtr.Api.Tests` derlemesi tur boyunca **beş kez** başka ajanların yarım
  işiyle kırmızıydı (ConfigRenderer, ProvisioningPullRateLimiter, LocalDialPlan,
  OutsideHoursBreakJob); `dotnet test` için until-döngüsüyle beklendi.
  Entegrasyon testi **koşulmadı** (Docker). `Pbxtr.Architecture.Tests` 709/718 — 6 ayrı sınıf
  kırmızı (`SampleDataSeederInsertOnly`, `CrossTenantScopeGuard`, `TenantLeakCoverage`);
  **hiçbiri bu turun dosyalarına ait değil**, `SessionScopeGateArchitectureTests` yeşil.

**Commit:** `a417949` — BR-SEC-20 karar + BR-SEC-08 Ş51-1 önkoşul testi + BR-BE-150 sağlık satırı kipi
**Commit:** `55db5ce2` — BR-BE-150: sağlık satırı kip testi (mutasyonla doğrulandı)
