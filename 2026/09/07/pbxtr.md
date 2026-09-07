# pbxtr — 2026-09-07

## Bağlam

Karar #34 uygulaması dün gece başladı, bugüne taştı. Kullanıcı gün ortasında **"kalan maddeleri
nereye yaptın? madde başlıklarını ClickUp'a güncellermisin"** dedi — o da bu günün ikinci konusu.

Turun başındaki tablo: 117 BR kartı, 25 bitti. Sonundaki: **132 kart, 49 bitti.**

## Yapılanlar

### 1. Backlog ClickUp'a taşındı — ve iki sayım hatası ölçüldü

- **Neden:** kullanıcı kalan işi görmek istedi. Kartlar `yonetim/backlog.md`'deydi; ClickUp'ta 400
  görev vardı ve **BR- öneki taşıyan tek bir kart yoktu**.
- **Ne yapıldı:** `yonetim/arac/` altına üç betik (`clickup-cikar.js`, `clickup-olustur.js`,
  `clickup-senkron.js`) ve `clickup-kart-eslemesi.json`. Senkron **önce okur, yalnızca farkı yazar**;
  `--kuru` ile ne değişeceğini yazmadan gösterir. Token `.clickup-token`'dan okunur ve hiçbir çıktıya
  düşmez.
- **Körü körüne senkron iki şeyi bozacaktı:**
  1. **Altı kartın durumu bayattı** — ajanlar bitirmiş, satırda hâlâ "Devam" yazıyordu.
  2. **Bir numara iki kez kullanılmıştı** (`BR-QA-16`), ikisi de aynı ölçümü tarif ediyordu. Kör
     senkron **ikinci satırı sessizce yutacaktı**. Numara ayrıldı, içerik korundu.
- **Ve aracın kendisinde bir hata buldum:** `"Yarısı bitti"` / `"Kısmen bitti"` içinde de "Bitti"
  geçtiği için naif bir `/Bitti/i` testi onları **kapalı** sayıyordu — defterdeki *"sayaç kısmi
  satırı kapalı sayar"* hatasının ta kendisi. İki kart yanlışlıkla `complete` görünüyordu.
- **Commit:** araç + eşleme + 117 kart

### 2. On kartın öncülü ölçümle YANLIŞ çıktı — hepsi benim yazdığım cümlelerdi

Turun asıl bulgusu bu. Dün altısını saymıştım; bugün dört tane daha eklendi:

| Yazdığım | Ölçülen |
|---|---|
| "Taban bir istemci başlığına bağlı" | Başlık hiçbir şey değiştirmiyor. Taban **her zaman** aktif tenant'tı; sebep RLS değil **EF query filter** |
| BR-BE-86'nın dört ucu | Kurul kararındaki dörtle **hiç örtüşmüyor**; ikisi **hiç var değil**, biri **zaten kapılı** |
| "BR-AST-36 mimari karar gerektiriyor" | Gerektirmiyor — olaylar **zaten** mevcut tüketiciden geçiyor |
| "Ek ADR-014 §2.11'e yazılsın" | Yanlış belge **ve** dolu bölüm — üstüne yazmak **mevcut bir kararı silerdi** |

Bir de mutasyon beklentim yanlış çıktı: *"`count` allowlist satırını kaldır → `waiting` testi
kırmızı"* olmuyor **ve olmamalı** — türetici olayı `Sanitize`'dan önce görüyor.

**Ortak sebep tek:** kod okumadan, ya da kendi yazdığım kararı ikinci kez okumadan yazmak.
**Ama onunun da altından gerçek kusur çıktı** ve çoğu benim yazdığımdan **daha kötüydü**. Yanlış
öncül boş alarm üretmiyor; **yanlış teşhisle bulunmuş gerçek hastalık** üretiyor — ve tehlike bulgunun
kaçması değil, **yanlış teşhisin yanlış düzeltmeyi şart koşması**: karta "sayımı `FOR UPDATE` et"
yazsam AB-BA deadlock'u üretecekti.

Hafızaya yazıldı: `kart-onculu-olculmeden-yazilmaz`.

### 3. Ölçüm aracının kendisi bozuktu — ve bunu ölçtük

- **`Test Run Aborted` veren bir koşu `Failed: 0` yazıyor.** Ölçülmüş vaka: 116/134 testten sonra
  abort, sonuç satırı yeşil. Bir başka ajanda aynısı: `Failed: 0, Passed: 805` yazdı, tekrarında
  **856/856** koştu — yani **51 test sessizce ölçülmemişti**.
- **Ve mevcut kapı bunu geçiriyordu:** gerçek iptal TRX'i `integration-trx-gate.py`'a verildi, kapı
  **"OK"** dedi. Yani bugün koşan entegrasyon kapısı **%42'si hiç koşmamış** bir koşuyu yeşil
  sayıyordu.
- **Kartın önerdiği çözümlerden biri ölçümle elendi:** `Passed+Failed+Skipped == Total` tutarlılığı
  bu arızayı **yakalamıyor** — sayaçlar yalnızca *kaydedilen* vakaları sayıyor, iç tutarlılık
  kusursuz kalıyor. Ayırt eden alanlar `ResultSummary outcome` ve `RunInfo` varlığı;
  `outcome="Warning"` **bilerek** dışarıda bırakıldı çünkü depodaki gerçek Integration TRX'i tam
  olarak onu taşıyor.
- **Bayi tezgahı yokmuş:** `ITenantDirectory` test harness'ında hiç kayıtlı değil. Mutasyon tezi
  kanıtladı: tezgâh kaydı kapatılınca **pozitif** test kırmızı, **negatif** test **yeşil kaldı** —
  yani bugüne kadar yazılmış *negatif-yalnız her bayi testi hiçbir şey ölçmüyordu*.

Hafızaya yazıldı: `testhost-cokmesi-olcum-kaybi`.

### 4. Kapılar kendi mutasyonlarıyla kör çıktı

Kaldırma manifesti turunda **iki kapı da** ilk yazımda mutasyonu görmedi:
- `case *"...Kinds"*` önek eşleşmesi `KindsKALDIRILDI`'yı da kabul ediyordu;
- aranan metin gömülü node betiğinin `//` yorumunda da geçiyordu ve `#` filtresi elemiyordu.

Mutasyon koşturulmasaydı ikisi de **yalan söyleyen kapı** olarak kalırdı. Aynı gün nginx tarafında
**hiç var olmamış bir kapıya yapılan atıf** düzeltilmişti; bu onun kardeşi.

### 5. Kapatılan başlıca kusurlar

- **Zil grubu düzenlemesi santrale hiç gitmiyordu** — üç yazma yolunun hiçbiri provisioning
  tetiklemiyordu. Sahada belirti *"kaydettim ama çalmıyor"* ve arada geçen süre **başka birinin
  yaptığı alakasız bir düzenlemeye** bağlıydı.
- **Bayat config santralde kalıyordu:** tenant'ın son zil grubu silinince tür **hiç üretilmiyor**,
  `confd` dosya silmediği için **silinmiş grup çalmaya devam ediyordu**. Ve arıza iki katmanlıydı —
  kartın önerdiği "confd silsin" çözümü tek başına kapatmazdı, çünkü sunucu da bayat içeriği servis
  etmeye devam ediyordu. Çözüm **silme değil mezar taşı**.
- **Gerçek santralde #12 boştu** ve **kuyruk alarm motoru hiç koşmuyordu** — `LiveQueueState`'i
  yazan tek dalı yalnızca simülasyon besliyordu.
- **`owner`, kendi tenant'ında barınan platform süper adminini** hem pasifleştirebiliyor hem rolünü
  alabiliyordu. İkisi de üretildi (200 döndü), ikisi de kapatıldı.
- **Saklama gecikmesi ölçümü verinin hacimce çoğunluğunu görmüyordu** (partition dalı kapsam dışı).
- **`DELETE /queues/{id}` korumasızdı** — kurulun *"8'in en ağırı"* dediği asimetri.

### 6. Ölçüm yönteminde iki ders

- **Saf `Barrier` yetmiyor.** Silme↔güncelleme yarışında kaybeden taraf **kimin önce satır kilidini
  kaptığına** göre değişiyor; silen önce kaparsa güncelleyen 404 alıyor — doğru davranış, ama
  ölçülmek istenen 409 dalı o koşuda **hiç koşmuyor ve mutasyon yeşil kalıyor**. Kilidin
  **tutulduğu doğrulandıktan sonra** ikinci aktör başlatılmalı.
- **Kilit karması nerede alınıyor, önemli.** `.NET GetHashCode()` süreç başına randomize; çok-node
  kurulumda advisory kilit **hiçbir şeyi serileştirmezdi** — tek node'lu testte kusursuz yeşil veren,
  üretimde vacuous bir kilit. `hashtextextended` ile PostgreSQL tarafına alındı.

### 7. `users` izolasyonu — kolay görünen çözüm ÖLÇÜLDÜ ve reddedildi

- **Arıza üretildi:** çapraz kipteki bir aktör, A tenant'ının kullanıcı satırını kilitledi ve
  A'nın **kendi** yazma isteği **2004 ms bekledi**. Sızıntı değil **bloklama** — ve hiçbir denetim
  satırı üretmiyor.
- **`UserRecord : ITenantOwned` yapmak akla ilk gelen çözümdü; uygulandı, derlendi, koşuldu ve
  reddedildi.** EF `TenantId ... unmapped` ile **`BootstrapSeeder`'ın ilk sorgusunda** patladı.
  Mapli hâle getirmek `users`'a `tenant_id` kolonu ister ve o kolon CLAUDE.md §4 ile **yasak**.
  Üstelik giriş yolu (`FindByLoginAsync`) tenant **bilinmeden** koşuyor — global filtre orada
  0 satır üretir ve **kimse giriş yapamaz**. Yani kolay çözüm, ürünü açılışta kilitlerdi.
- Seçilen yol: kapının koşulu **kendisi** taşıması. Çapraz kipte **0 satır kilitlendi, kurban hiç
  beklemedi**; mutasyon ısırdı.

### 8. `PUT /tenant/settings` — damga tek kolon değilmiş

- Damga `GREATEST(tenants.updated_at, tenant_settings.updated_at)`. Yalnızca birincisini almak
  kapıyı **maskeleme seviyesi için vacuous** yapardı; ölçüldü: yalnızca maskeyi değiştiren bir
  yazımda `tenants.updated_at` **değişmiyor**.
- Kurulun bu ucu kümenin en ağırı saymasının gerekçesi karta girdi: **kayıp güncellemenin veri
  İMHA ETTİĞİ tek yer** — A saklama süresini 365'e çeker, B bayat gövdesiyle 90'a alır, iş
  **275 günlük ses kaydını siler** ve geri dönüşü yoktur.
- **İki ölçüm hatası ajan tarafından yakalandı ve ikisi de defterde kayıtlı tuzaklar:**
  1. Yarış testinin ilk hâli her istekte giriş yapıyordu; parola doğrulaması pencereden uzun
     sürdüğü için ikinci aktör kapıya birincinin **commit'inden sonra** varıyordu ve mutasyon
     **ısırmıyordu** — yani test kapıyı değil kendi kurulumunu ölçüyordu.
  2. Başka bir ajanın `testhost`'u DLL'i kilitlemişti; build **"0 Error(s)"** dedi ama kopya
     başarısız oldu ve mutasyonlu koşum **eski ikiliye** gitti.

## Kararlar (bu tur)

- **Ajanın "bu kartın öncülü yanlış" demesi başarıdır.** Bu turda on kez oldu ve her seferinde
  kararın yönü değişti. Göreve daima *"kartın öncülünü ölçmeden kabul etme"* yazılıyor.
- **Ölçülmemiş kod "kapı" diye sunulmaz.** Süper admin turunda `FOR UPDATE`'in mutasyonda yeşil
  kaldığı **ajan tarafından bildirildi** ve savunma amaçlı bırakıldığı koda yazıldı.
- **Yarım teslim "bitti" sayılmaz** ve ölçülmeyen yarı **kart olur**: bu turda kapanan 12 kart,
  15 yeni **ölçülmüş** kart doğurdu. Kalan sayısının düşmemesi bir başarısızlık değil, envanterin
  ilk kez gerçeğe yaklaşması.

## Açık kalanlar / sonraki adım

- `PUT /users/{id}` kapısı (BR-BE-86'nın kalan yarısı) — `VersionedResource.User` dalı hazır.
- BR-FE-63: retention **hiç çalışmamışsa** sağlık satırı sonsuza kadar yeşil kalıyor.
- BR-SYS-74: `deploy/test-kos.sh`'ın **sıfır çağıranı** var ve içinde iki kusur duruyor.
- BR-SYS-72: `CSP style-src-attr` üretim şablonunda yok — Report-Only zorlayıcıya çevrildiği gün
  logo kırılır.
- Kurula gidecek ikisi: BR-SYS-70 (yayın yolu nginx'i taşımıyor), BR-SEC-05 (`scope: global` roller
  yalnızca platform tenant'ında barınabilsin mi).
- `pbxtr-confd` provisioning ajanı ve Netgsm SMS epikleri hâlâ büyük ölçüde açık.
