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

### 9. Envanterin kendisi yanlış sayılıyormuş — günün en önemli bulgusu

- **Neden çıktı:** kullanıcı *"biten/kalanları göreyim"* dedi, ClickUp'ı güncellerken aracı ölçtüm.
- **Ne bulundu:** `yonetim/arac/clickup-cikar.js` `cells.length < 6` diyerek satır eliyordu. Backlog'un
  **büyük çoğunluğu 5 kolonlu**, yalnızca en son bölümler 6 kolonlu — üstelik 6 kolonlu başlığın
  altında bile **65 satır** son hücreyi hiç taşımıyor, bir de **4 kolonlu** tablo var. 253 `| BR-`
  satırından **111'i düşüyordu.**
- **Sonucu:** kullanıcıya bildirdiğim her bilanço eksikti — *"134 kart, 50 bitti, 78 kalan"* derken
  gerçek **250+ kart**tı. Ve eleme `continue` ile **sessizdi**, yani eksik sayım **doğru sayım gibi**
  görünüyordu. Sayı uydurma değildi; gerçek satırlardan geliyordu, sadece **eksikti** — tam da bu
  yüzden inandırıcıydı.
- **Düzeltme:** kolonlar artık ne sabit indeksle ne başlık sayısıyla, **içerik şekliyle** çözülüyor
  (`Öncelik` = `P0…P3` kalıbına uyan son hücre). Ve kapı kondu: `| BR-` ile başlayıp çözülemeyen
  **tek bir satır** kalırsa betik **hata verip duruyor**.
- **Kapı ilk koşusunda üç mükerrer kimlik yakaladı** (`BR-SYS-45`, `BR-BE-47`, `BR-BE-53`) — üçü de
  eski satırın yerini yenisinin aldığı durumdu ve **kör senkron ikincisini sessizce yutardı**
  (`BR-QA-16` ile aynı sınıf). Eski satırlar **silinmedi**, *"Yerini satır N aldı"* ile işaretlendi.
- **Aynı araçta iki kusur daha:**
  1. `clickup-senkron.js` **bayat** `rows.json` okuyup *"fark olan kart: 0"* diyordu — o an sekiz
     yeni kart vardı. Artık çıkarıcıyı **kendisi** koşturuyor. *(Ve aynı kusur `clickup-olustur.js`'te
     de duruyordu; ilkini düzeltirken ikincisine bakmadım — ikinci turda o da düzeltildi.)*
  2. Uzak okuma **tam 800'de** duruyordu, yani `8×100` sayfa sınırının **kendisinde**. Gerçekte
     **1063** görev vardı; sınırın ötesindeki 263'ü *"uzakta yok"* görünürdü. Sınır 40 sayfaya
     çıkarıldı ve **vurulursa artık hata veriyor**.
- **Sonuç:** ClickUp'a eksik **116 kart** açıldı, durumlar senkronlandı, kuru koşu sıfır fark veriyor.
- **Hafızaya yazıldı:** `envanter-sayaci-kendi-filtresini-olcmez`.
- **Kart:** BR-QA-27 (Bitti).

### 10. Kurul: üç karar (Karar #35) — ve kurulun kendisi üç arıza ölçtü

**(1) Yayın yolu nginx'i taşısın mı → ŞARTLI ONAY, 10/10 lehte.** Ama oturumda ölçüldü ki:
- `staging-yayin.sh`'in sağlık kontrolü **yalan söylüyor**: `curl --fail http://127.0.0.1/` →
  80→443 yönlendirmesi **301** döner ve `--fail` 301'i hata saymaz. **443 bloğu tamamen kırıkken
  yeşil geçer.** Geri alma kararını verecek ölçüm bugün **yok**.
- `rollback()` yalnızca imajı geri alıyor, **conf'a dokunmuyor** → taşıma şartsız eklenseydi bozuk
  conf **aynı bozuk conf ile** recreate edilir ve **panel kapalı kalırdı**.
- `nginx -t` **boş konteynerde** koşuyor: sözdizimini ölçer, gerçek mount/sertifika/upstream'i ölçmez.

**(2) `scope: global` roller veri modelinde kısıtlansın mı → ERTELENDİ.** Şeytan ölçtü ve karar
yönünü değiştirdi: `St44AcceptanceSeeder` **açıkça** `scope='global'` hesapları müşteri tenant'ına
yazmak **zorunda**. Kısıt bugün yazılsaydı migration canlıda patlar, seeder bir daha koşamaz ve
**BR-SEC-04'ün kanıt fikstürleri** kurulamaz hâle gelirdi — *bir güvenlik kapısının kanıtını silmiş
olurduk.* İkinci ölçüm daha sinsi: uygulama kapsamı **rol kataloğundan** türetiyor, `users.scope`
ayrı bir alan; o kolona konacak CHECK **gerçek saldırı yolunu (`user_roles`) hiç görmez**.

**(3) `HealthState`'e sarı eklensin mi → ENUM GENİŞLETME REDDEDİLDİ (altı üye karşı).** Belirleyici
ölçüm linux uzmanından: sertifika dalı `days > 0 ? Ok : Down` — **10 gün kala yeşil, 1 gün kala
yeşil**, dolduğu an kırmızı; operatöre **sıfır uyarı süresi**. Ve palette yer olmadığı için
`DiskWarnPercent` koddan silinmiş, yani **gerçek bir operasyon kavramı ürünün dışına atılmış**.
Sarı `HealthState`'e değil **ayrı bir `severity` alanına** bağlandı.

### 11. Kendi kartımın öncülü yine yanlış çıktı — bu kez koda da yazmıştım

*"`job_runs` `pbxtr_app`'e kapalı"* demiştim. `db-lider` kurul oyunda ölçtü, ben doğruladım:
`20260812171500` gerçekten `REVOKE ALL` yapıyor **ama sonraki bir migration yetkiyi geri veriyor**
(`20260814141500_JobRunsHealthRead`) ve `SystemHealthProbe` o tabloyu **bugün zaten okuyor**.

**Beni yanıltan şey kayda değer:** koddaki *"canlı ölçüldü: permission denied"* notu **GRANT'ten
önceki** hâli anlatıyordu. Not **tarihseldi**, bugünkü yetki değil — yani depodaki yorum, kendi
düzeltmesinden önce **donmuş bir fotoğraftı**.

Kurul üyesinin önerisinde de bir hata çıktı: `outcome` kümesi `('leader','skipped','failed')`,
**`'success'` diye bir değer yok**; ve `'skipped'` (*"lider olamadım"*) sayılırsa çok-node kurulumda
her node her tick'te satır yazdığı için sinyal **her zaman taze görünür** — yani **vacuous** olur.

### 12. Kapatılan başlıca kusurlar (bu bölüm)

- **`deploy/test-kos.sh`: 200 satır, dört kapı, SIFIR çağıran.** İçinde iki ölçülmüş kusur vardı ve
  ikisi daha çıktı. En kritiği: filtreli çağrıda `beklenen 366 / toplam 16 → KALDI` — betik bugünkü
  hâliyle `delivery-mutation-gate`'i sarmalasa **her yayını kırmızı yapardı**. Ve `--configuration`
  yokluğu üç yüzlüydü: aynı anda `Debug = 366`, `Release = 364` ve `--no-build` koşusu `bin\Debug`'a
  gidiyordu — kapı **yayınlanan Release ikilisini hiç ölçmüyordu**. Üçüncü kusur çağrılabilir
  olmasının önündeki engeldi: log `tests/` altına yazıyordu ve o yol gitignore'da değil, yani betik
  yayın yolundan çağrıldığı an **kendi izine takılıp bir sonraki yayını bloke ederdi**.
  Kör noktası da ölçülüp betiğe yazıldı: bir test **kaynaktan** silinirse kapı yeşil kalıyor.
- **Retention sağlık satırı, iş HİÇ KOŞMAMIŞSA sonsuza kadar yeşildi.** Eşiklenen tek sayı
  `starved_age_days` ve o NULL iken `breached` kümesi **tanım gereği boş**; `pending` 40,
  `oldest_age_days` 4000 gün olsa bile satır yeşil. Yeni dal kırmızı değil **gri** üretiyor, çünkü
  meşru yeni kurulum **birebir aynı görüntüyü** veriyor.
- **Sertifika 10 gün kala yeşildi** → artık 21 gün sarı, 6 gün kırmızı. Ama **üçüncü bir eşik ayarı
  açılmadı**: `CertificateWarnDays`/`DangerDays` zaten vardı ve #47'de zaten okunuyordu. *Aynı
  gerçeği iki ayardan okumak bir gün iki farklı cevap üretirdi.*
- **`StateText`'teki `_ =>` catch-all'ı** gelecekteki her enum eklemesini sessizce yanlış
  raporlıyordu; iki uçta da kapatıldı ve mutasyonla doğrulandı — yeni bir enum değeri artık
  **derleme hatası**.
- **Santralde olmayan kuyruk listeden TAMAMEN düşüyordu.** Süpervizör *"sakin kuyruk"* değil **hiç
  kuyruk** görmüyordu — ve **eksik satır, `0` yazan satırdan çok daha az fark edilir.**
- **`PUT /users/{id}` kapılandı** ve `fetchUser`'ın **ölü kod** olduğu doğrulandı.
- **`PUT /tenant/mask-level`: kayıp güncelleme DEĞİL, DEADLOCK.** `audit_log.tenant_id` FK'si
  yüzünden uç tenant satırını **zaten kilitliyordu, ama yanlış sırada**; ölçümde aktör A **500**
  aldı. Çözüm kapı değil **sıralama**.

### 13. `pbxtr-confd`: ikinci elle-teslim yüzeyi

BR-SYS-73'ün öncülü (*"staging sunucusu gerekiyor"*) yanlıştı — **erişim vardı** ve `pbxtr-confd`
kurulu, 30 günde **968 koşu, başarısız koşu yok**. Gerçek sebep:

- Sunucudaki betik **225 satır**, depodaki **560**. Farklı sha256, ve `staging-yayin.sh` içinde
  `confd` kelimesi **hiç geçmiyor** — betiği bir insan **elle** koymuş.
- **`kapi_30` bunu görmüyor:** yedi iddiasının tamamı **depo dosyalarına** grep atıyor. 5. iddia
  *"confd betiği ile C# kümesi birebir aynı"* derken **sunucuda çalışmayan iki kopyayı**
  karşılaştırıyor; fiilen koşan betikte `ROLLBACK_ACIK_TURLER` **yok**, yani kapı yeşilken santralde
  uygulanan tür kısıtı **sıfır**.
- **Kurulsa ne olurdu, ölçüldü:** eksilme kapısı tür adını **dosya adından** türetiyor; sunucudaki
  altı `t0007-wrtc-<dahili>.conf` dosyasını **altı ayrı tür** sanıyor → **exit 75, her 5 dakikada
  bir, kalıcı**.
- Ajan **ölçtü, uygulamadı** — canlı teslim düğümüne yazmak gerekiyordu ve ölçüm ilk koşudan
  itibaren kalıcı kırmızı öngörüyordu. Doğru karar.

### 14. Bir CSP kartı gerçek tarayıcıda çürüdü

*"`style-src-attr` yok, o talimat uygulandığı gün logo kırılır"* demiştim. Üretim CSP'si **zorlayıcı**
olarak servis edildi, Chromium ile ölçüldü: direktif **yokken** logo 20px ve **stil ihlali yok**;
eklendiğinde **hiçbir fark yok**. Sebep: ReactDOM inline stilleri `style` **özniteliği olarak
yazmaz**, CSSOM üzerinden yazar ve **CSP CSSOM'u yönetmez**.

Ters yönde bir bulgu: iki nginx dosyası bu direktifi *"BİLEREK var (Logo.tsx inline)"* gerekçesiyle
taşıyor — **o gerekçe ölçülerek yanlış**, yani bugün canlıda **gereksiz bir gevşeme** duruyor.

**Ve asıl arıza kartta yazmıyordu:** CSP zorlayıcıya çevrildiğinde bloklanan **tek şey**
`index.html`'deki **tema önyükleme script'i**. `script-src`'in CSSOM gibi bir kaçış yolu **yok** —
yani talimatın bedeli logo değil, **gündüz temasındaki koyu yanıp sönme**. BR-SYS-79 açıldı.

## Kararlar (bu bölüm)

- **Bir sayaç kendi filtresini ölçmez.** Attığı satırı saymadığı için attığını da bilmez. Kaynaktaki
  aday satır sayısı ile araçtan çıkan satır sayısı **daima karşılaştırılır**; eşit değilse **hata
  verilir**, `continue` edilmez.
- **Ajanın "bu kartın öncülü yanlış" demesi başarıdır.** Bugün **on dört** kez oldu ve her seferinde
  kararın yönü değişti. Bugünkü en değerli üçü: `job_runs` yetkisi (benim koda yazdığım cümle),
  `St44AcceptanceSeeder` (kısıtı erteletti), CSP (gerçek tarayıcı ölçümü).
- **Ölçüm, verilen şartı da reddedebilir.** Sağlık ajanı kuruldan gelen ton şartını uygulamadı ve
  haklıydı: şart kararın kendi Ş35-22/Ş35-23'üyle çelişiyordu ve uygulansaydı **sıfır sarı satır**
  üretecekti — yani kart hiçbir şey kapatmayacaktı.
- **Aynı hatayı iki dosyada birden yapabiliyorum.** Bayat `rows.json` kusurunu `senkron`'da
  düzeltirken `olustur`'a bakmadım; ikinci turda o da çıktı.

## Bilanço (bu bölüm sonunda)

**258 kart — 101 bitti, 6 devam, 152 kalan.** (Sabahki *"134 kart / 78 kalan"* rakamı, §9'daki
sayım hatası yüzünden **yanlıştı**.)

### 15. Sprint-43-b veri katmanı — ve "yapısal bekçi çalışma-anı hatasını görmez"

- **`sms_resolve_tenant` HİÇ ÇALIŞMIYORDU.** Gövdesinde `min(uuid)` vardı ve **PostgreSQL'de
  `min(uuid)` yok**. Yapısal bir bekçi bunu göremezdi: fonksiyon **vardı**, imzası **doğruydu**,
  yalnızca **çağrıldığında** patlıyordu — yani her DLR **sessizce başarısız** olurdu. Smoke testi
  yakaladı.
- **`sms_provider_accounts` salt-okunurluğu HER DAĞITIMDA sessizce siliniyordu.** REVOKE migration
  gövdesindeydi, ama `00-roles.sql` her dağıtımda yeniden koşuyor ve şemadaki **bütün tablolara**
  toplu yazma yetkisi veriyor. Append-only'de daha önce ölçülen hatanın **birebir aynısı**.
  Çözüm kaynağına kondu ve küme **ad listesinden değil trigger'ın varlığından** türetiliyor —
  çünkü bu depoda ad listesi **iki kez** bayatlamıştı.
- **Şablon tazelemesi olmadan staging kırmızı olacaktı** ve bu **taklit edilerek** ölçüldü.
- **`.cs` dosyalarında CRLF, `prosrc` md5'lerini değiştiriyor.** Yerelde CRLF ile ölçüp donduran biri
  CI/deploy'da kırmızı alır.

**Ve çapraz kesen bir ölçüm (BR-DB-40):** RLS yükleminin **UUID regex'i satır başına koşuyor.**
Kontrol grubuyla izole edildi — aynı sorgu, aynı satırlar, **aynı plan**, tek fark GUC:
`app.tenant_id` **set** iken **77,7 ms**, **set değil** iken **3,6 ms** (~8,6 µs/satır). p95 < 5 ms
eşiği ≈ **600 satır**, ve bu **SMS'e özgü değil — RLS'li her tablo** bunu ödüyor. *"Fonksiyonu
inline et"* denendi ve **daha kötü** çıktı (105 ms).

### 16. Ölçüm bir kartı değil, verilen ŞARTI da reddedebilir

Sağlık ajanı kuruldan gelen ton şartını (*"sarı yalnızca `unmeasurable && warning`"*) **uygulamadı**
ve haklıydı: şart, kararın kendi Ş35-22'siyle çelişiyordu (sarının yüklemi *"ölçüldü, **çalışıyor**,
ama eşiği aştı"* — bu `Ok` hâlidir) ve Ş35-23'ün *"`Unmeasurable` sarıya katlanmaz"* şartını ihlal
ediyordu. Uygulansaydı bu turda **sıfır sarı satır** olurdu — kart hiçbir şey kapatmazdı.

Aynı ajan üçüncü bir eşik ayarı da **açmadı**: `CertificateWarnDays`/`DangerDays` zaten vardı ve
#47'de zaten okunuyordu. *Aynı gerçeği iki ayardan okumak bir gün iki farklı cevap üretirdi.*

### 17. Kapatılan başlıca kusurlar (bu bölüm)

- **Sertifika 10 gün kala yeşildi** (`days > 0 ? Ok : Down`) — operatöre **sıfır uyarı süresi**.
- **`StateText` catch-all'ı** her yeni enum değerini sessizce yanlış raporluyordu; iki uçta da
  kapatıldı ve `BackupStatusEndpoints`'teki *"bilerek"* iddiası **ölçülerek çürüdü**.
- **Santralde olmayan kuyruk "0 bekleyen · 0/4 agent" ile SAKİN görünüyordu** — üstte tehlike
  rozeti, altta huzurlu sıfırlar. Rozetin kendi metni **dokuz dilde** *"ölçümlerin boş olması sakin
  demek değildir"* diyordu; ölçümler **boş değildi**. Yazılmış ama uygulanmamış bir karar.
- **`PUT /users/{id}` kapılandı**; `fetchUser` **ölü koddu**, yani istemcinin damgayı okuyacak yolu
  hiç yoktu.
- **`PUT /tenant/mask-level`: kayıp güncelleme DEĞİL, DEADLOCK.** FK yüzünden uç tenant satırını
  **zaten kilitliyordu, ama yanlış sırada**; ölçümde aktör A **500** aldı.
- **`X-Pbxtr-Have` başlığı tabanı seçer, kapsamı seçmez** — yabancı bir `have` ile gövdede o
  tenant'ın dizesi **hiç geçmiyor**; ölçüldü.
- **Düğüm hız sınırı düğüm başına değilmiş:** tenant A limite girdikten sonra **tenant B aynı düğüm
  adıyla geçiyor**; fiilî hak `N × 30 / 5 dk`.
- **`gitleaks` düşük entropili sağlayıcı sırrını kaçırıyor** — iki fikstür, tek fark değer.
- **confd tür adı dosya adından türetiliyordu**; kurulsa **her 5 dakikada bir kalıcı exit 75**.
- **#57 düğüm alanı sunucuda zaten zorunluydu; istemci "opsiyonel" diye SÖZ VERİYORDU.**

### 18. `pbxtr-confd` ve compose: aynı yapısal kusurun üç yüzeyi

- confd betiği sunucuda **225 satır**, depoda **560** — ve onu oraya koyan bir **kurulum yolu yok**.
- `kapi_30`'un yedi iddiasının **tamamı depo dosyalarına** grep atıyordu; *"confd betiği ile C#
  kümesi birebir aynı"* derken **sunucuda çalışmayan iki kopyayı** karşılaştırıyordu.
- **`docker-compose.yml` için sapma kapısı yok** ve sunucudaki kopya **30 Ağustos'tan kalma**.
  Sonucu ölçüldü: posta ön koşul drop-in'i **yarım indi** — ölçüm üretiliyor ama uygulama onu
  **göremiyor**; belirti **DNS düzeltildiği gün** çıkacak ve operatör **yanlış yere** bakacak.

**Ve taşımanın kendisi sessiz bir arıza üretiyor:** `scp` hedefi **aynı inode üzerinde kırpar**;
timer koşarken bash betiği **ilerledikçe okuduğu** için çalışan koşuya **yeni dosyanın eski
ofsetindeki baytları** okutur — root olarak, çalışan bir santrale karşı, **sessiz ve
tekrarlanamaz**.

## Kararlar (bu bölüm)

- **Yapısal bekçi, çalışma-anı hatasını görmez.** Yazılan her şey **çağrılarak** ölçülmeli;
  `min(uuid)` vakası bunun ders kitabı örneği.
- **Bir düzeltme kaynağına konmazsa her dağıtımda geri alınır.** Salt-okunurluk vakası, append-only
  vakasının tekrarıydı — ve çözüm **ad listesi değil**, çünkü bu depoda ad listesi iki kez bayatladı.
- **"Ölçemedim" ile "sıfır" farklı şeylerdir** ve bu ayrım bugün **üç ayrı yerde** arıza çıkardı.
  `?? 0` artık bekçili.
- **Kartın öncülünü ölçmeden kabul etme** — bugün **on altı** kez yanlış çıktı.

## Bilanço (gün sonu)

**270 kart — 120 bitti, 15 devam, 136 kalan.** (Sabahki *"134 kart / 78 kalan"* rakamı §9'daki sayım
hatası yüzünden yanlıştı.)

---

# EK — Kurul turu (Karar #36) ve bir araç kusuru

## Bağlam

Gün boyunca beş kart karar bekleyerek birikmişti. Kullanıcı karar darboğazı olmak istemediği için
bunlar kurula gitti (kayıtlı ders: *"kararı kullanıcıya değil kurula sor"*). On üye paralel koştu;
her birine iki disiplin **birebir aynı cümleyle** verildi: *"kartın öncülünü ölçmeden kabul etme"*
(bugün on altı kez yanlış çıkmıştı) ve *"`Test Run Aborted` gördüğün her koşuyu TEKRARLA"*.

## 19. Kurul turunun asıl çıktısı: **altı üye brifingdeki bir cümleyi ölçerek çürüttü**

Bu turun değeri alınan kararlarda değil, **kararların dayandığı öncüllerin yıkılmasında**. Kurula
beş kart gitti, **dördünün metni değişti** ve biri tamamen düştü.

### 19.1 BR-DB-40 bir düzeltme kartı değilmiş — bir **ölçüm** kartıymış

Üç bağımsız çürütme geldi ve üçü de kartın rakamına dokunuyor:

- **Şeytan (İtiraz 1.2 — tek başına kartı düşürebilir):** `01-rls-template.sql:113-121`, GUC boşsa
  fonksiyon **regex'e hiç ulaşmadan** `RETURN NULL` yapıyor. Yani *"GUC set değil"* koşusu regex'i
  değil **erken dönen dalı** ölçmüş. Üstelik yüklem `tenant_id = app_current_tenant()` ve plan
  `Index Only Scan` — `NULL` anahtarla o tarama **0 satır** üretir. **İki koşu aynı işi yapmıyorsa
  `8,6 µs/satır` bölmesinin paydası uydurmadır.**
- **Şeytan (1.3):** kart *"inline varyant denendi, DAHA KÖTÜ çıktı (105 ms)"* diyor. Regex satır
  başına koşuyorsa inline varyantta da aynı regex koşar → süre **eşit** olmalıydı, **%35
  artmamalıydı.** Artması, baskın maliyetin regex değil **çağrı yolu** olduğunu söyler.
- **DB Lideri (rakip ve daha güçlü teşhis):** `01-rls-template.sql:315` →
  `USING (tenant_id = app_current_tenant() OR app_is_cross_tenant())`. **Bu `OR` bir indeks koşulu
  olamaz.** `tenant_id = f()` tek başına olsaydı planlayıcı onu index scankey'e koyar ve **tarama
  başına bir kez** değerlendirirdi; `STABLE` bunun için yeterlidir. `OR` ile yüklemin tamamı
  **Filter**'a düşüyor. Rakam da oturuyor: 77 buffer ≈ 9.000 satır × 8,6 µs ≈ 77 ms.

**Ve bir metodoloji hatası:** *"inline denendi, daha kötü çıktı"* bir karşı kanıt **değil**, çünkü
kartın kendi cümlesi *"regex yine satır başına koşuyor"* diyor — denenen varyant **regex'i taşımış**.
Ölçüm, *inline etmenin* değil *regex'i taşımanın* sonucu. Bu ikisi karıştırıldığı için **doğru çözüm
(regexsiz, tek ifadeli, inline edilebilir `LANGUAGE sql`) elenmiş durumdaydı.**

**Güvenlik sorusu kapandı:** regex bir kapı değil, **derin savunma**. CTO ölçtü — `EXCEPTION WHEN
invalid_text_representation` bloğunun yerine konmuş, çünkü o blok alt-transaction açıp
`PARALLEL SAFE` ile çelişiyormuş; görevi cast hatasını bastırmak.

**Ama "SET LOCAL anına al" önerisi reddedildi — ve sebebi ayrı bir ölçüm:** Backend Lideri
`TenantSessionWriter` dışında `app.tenant_id` yazan **en az 11 çağrı yeri** saydı
(`LeaveEnforcementJob`, `ObjectRowRetentionJob`, üç `Recording*Job`, `QueuePushReconciliationJob`,
`PersistentTelephonyProvider`, ve `St44AcceptanceSeeder:77,88,96` — **sonuncusu parametre değil,
string interpolasyonu**). Yani **doğrulama taşınamaz, yalnızca çoğaltılabilir.**

> **Ders:** *"Kontrol grubu kurdum"* demek yetmez — **kontrol grubunun aynı işi yaptığı ayrıca
> ölçülmeli.** Burada iki koşunun `rows=` değeri hiç yazılmamıştı; yazılsaydı hata ilk dakikada
> görülürdü.

### 19.2 BR-SEC-07 tamamen düştü: iki iddiasının ikisi de yanlıştı

- *"Bu kısıt hiçbir yerde yazılı değil"* → **yazılı.**
  `doc/analiz/rol-yetki-ekran-analizi-2026-09-06.md:314-317`, betik çıktısıyla üretilmiş, tarihli.
  **On iki gün önce ölçülüp belgelenmiş.**
- *"`ivr.write` bir vakadır"* → **değil.** `owner ∖ (admin ∪ superadmin)` = **60 kalem**, ve
  **`ivr.read` bile hiçbir global rolde yok** (admin IVR'ı okuyamıyor).
- **Ve üçüncü, hiç sorulmamış bulgu:** `permissions.seed.json:915-923` — **admin**
  `queue.write`/`workinghours.write` taşıyor, **superadmin taşımıyor** → **`superadmin ⊄ admin`.**
  Bu, *"platform yöneticisi çağrı akışını değiştirmemeli"* gerekçesini de çürütüyor (çalışma saati
  de çağrı akışıdır). **Ortada bir ilke değil, birikmiş bir kesit var.**

> **Ders:** *"belgelenmemiş"* iddiası da bir öncüldür ve **grep'lenerek ölçülür.** Kart, kısıtı
> "keşfettiğini" sanıyordu; kısıt zaten yazılıydı ve kart onu **ikinci kez** keşfetmişti.

### 19.3 BR-BE-81: "kapatılamaz" gerekçesinin ikisi de yanlıştı — ama kartta yazmayan gerçek bir açık çıktı

- *"Platform anahtar alanı yeni bir istisna açar"* → **açmaz, bugün zaten var:**
  `RedisPlatformCounters.cs:41-77` `pbxtr:sys:*` yazıyor ve gerekçesi **yapısal çakışmazlıkla**
  yazılı: *"`sys` geçerli bir GUID değildir."*
- Testteki *"mimari karar gerektirir"* → **gerektirmiyor:** `EfApiKeyDirectory.cs:130-156`
  `PlatformCacheState()` ile **`ITenantCache` içinde** platform ad alanı kuruyor; desen **üç yerde**
  kullanılmış.
- **Buna karşılık db-lider kartta hiç yazmayan bir izolasyon açığı ölçtü:** `ApiKey.cs:51` —
  **`Node` serbest metin ve nullable**; tenant B, `Node = "asterisk-01"` yazarak **tenant A'nın
  düğüm kovasını tüketebilir.** Yani "düğüm başına sayaç" bugünkü veri modeliyle bir **çapraz-tenant
  DoS yüzeyi.**
- **Ve sınırın yönü tersine çevrildi** (Asterisk + Linux): 429 alan confd **geri çekilir** → config
  **bayat kalır** → yeni dahili devreye girmez. Bu bir **santral doğruluk sorunu ve sessiz**; yani
  burada **gevşeklik doğru taraf.**

**Benim bir rakamım da bayat çıktı:** *"30 günde 968 koşu"* demiştim; 5 dakikalık timer 30 günde
~8.460 eder. Ölçülen **282/gün** ve 968, kurulumdan sonraki ~3,5 günün sayısıymış.

### 19.4 Kimsenin sormadığı en ciddi bulgu: **yan etkili GET** (BR-BE-107, P1)

`ProvisioningNodeBundleEndpoints.cs:99` **`MapGet`**, ve `TryAcquireAsync` **`SET NX EX` ile numaralı
slot rezerve ediyor** — bu bir **nonce ilkeli**. CLAUDE.md §3.2 Ş6 tam olarak bunu yasaklıyor. Ama
bekçi `AsteriskClassBIdempotencyTests` **yalnızca Sınıf B** uçlarını sayıyor; bu uç **Sınıf A**
olduğu için kapsam dışı → **kural var, bu yüzeyde koşan bekçi yok.** nginx `proxy_next_upstream` bu
GET'i sessizce tekrar gönderirse **düğüm kendi kotasını yakar** ve görünür bir iz kalmaz.

> **Ders:** bir kuralın **kapsamı**, kuralın kendisi kadar ölçülmeli. *"Bekçi var"* demek
> *"bu yüzeyde koşuyor"* demek değil — bu, `kapinin-kosmamasi-bulgu-degildir` dersinin yeni bir yüzü:
> bekçi koşuyor, **yeşil**, ama **yanlış kümeyi** sayıyor.

### 19.5 BR-FE-66: karar iki son kullanıcının aynı cümleyi bağımsız söylemesiyle çözüldü

- **Agent:** *"`—` gördüğümde **'kimse beklemiyor'** diye düşünürüm. Kesinlikle bunu düşünürüm."*
- **Süpervizör:** *"İlk gün 'bozuk mu' derim. İkinci gün bakmayı bırakırım. Üçüncü gün ekipteki
  herkes o karonun sürekli `—` olduğunu öğrenir ve **karo ölür**."*

**Ama ikisi de *"sessizce ölçülmüşlerin maksimumu"*nu da reddetti** — süpervizör somut koydu:
*"4 dk görünce müdahale etmem; ölçülemeyen kuyrukta 12 dk bekleyen varsa kabul edilemez. Sessizlik
beni yavaşlatır; **yanlış sayı beni yanlış yöne götürür** — ikincisi daha kötü."*

**Ve Şeytan kartı hafif bulup ağırlaştırdı:** `presentOnPbx = false` olan kuyruk tanım gereği ne olay
üretir ne `QueueSummary`'de görünür → karo **kalıcı olarak** `—`. TTL/mutabakat aritmetiği bu kümeye
**hiç değmiyor**; senaryo teorik değil, **provisioning sapması olan her tenant'ta sürekli hâl.**

**Çözüm iki üyenin önerisinin birleşimi** — *"santralde yok"* ile *"ölçemedim"* **farklı olgular**:
`presentOnPbx = false` toplama **hiç girmez** (kalıcı `—`'yi kaynağında kaldırır), kalan gerçek
delikler için **`≥` + sayı** → rakam **alt sınır olduğunu kendisi söyler** ve BL-QA-42 korunur.

**Ve kapsam dışı gerçek bir eksik:** `DashboardScreen.tsx:439/445/449` `NO_VALUE`'yu **çıplak**
yazıyor (`title` yok, `VisuallyHidden` yok); oysa #17'de `NoLiveFigure` var ve Ş35-27 gereği metriğin
adını taşıyor. Süpervizörün *"gri okunmaz"* itirazının tire karşılığı: **çıplak tire, renk kadar
sessizdir.**

## 20. Araç kusuru: **kurul sonucu bir karardır, açık iş değildir**

ClickUp senkronunda görüldü: **BR-SEC-07 kurulda RED aldı** (iş yapılmayacak) ama eşleme onu
`backlog`'a düşürdü — yani kapanmış bir kart panoda **sonsuza kadar açık** görünecekti. Aynı şekilde
karar almış dört kart da `backlog`'da kalıyordu ve *"henüz bakılmamış"* ile *"karar verildi,
planlanmayı bekliyor"* **aynı hücrede** birleşiyordu.

İki kural eklendi (`Kurul: RED → complete`, `Kurul: (ŞARTLI )?ONAY → to do`) ve **yama iki dosyaya
birden kondu** — geçen turda aynı sınıf bir yama yalnızca birine konmuştu ve araç *"yeni: 0"* derken
üç kart eksikti.

**Vacuity kontrolü:** kuralın dokunduğu satır sayısı = `Kurul:` taşıyan kart sayısı = **5**; başka
hiçbir kartı yakalamıyor. Kuru koşuyla doğrulandı, sonra gerçek koşu yapıldı.

## Kararlar (bu bölüm)

- **Kontrol grubunun aynı işi yaptığı ayrıca ölçülür.** İki koşunun `rows=` değeri yazılmazsa
  "aynı plan" iddiası bir varsayımdır ve bölmenin paydası uydurma olabilir.
- **"Belgelenmemiş" de bir öncüldür ve grep'lenir.** Bir kart, zaten yazılı olan bir kısıtı ikinci
  kez keşfedebilir.
- **Bir kuralın kapsamı, kuralın kendisi kadar ölçülür.** Bekçi yeşil olabilir ve yine de **yanlış
  kümeyi** sayıyor olabilir (Sınıf B sayan bekçi, Sınıf A ucunu görmez).
- **Kurul çıktısı panoda "açık iş" değildir.** RED kapanmıştır, ONAY planlanmayı bekler; ikisini de
  backlog'a düşüren bir araç, alınmış kararı görünmez kılar.

## Sonraki adım

- **BR-SYS-82 hâlâ kullanıcı onayı bekliyor.** Linux Uzmanı kesintiyi ölçtü: 502 penceresi
  **~10–20 s**, betiğin "tamam" demesi ~35–45 s (aradaki fark ilan gecikmesi). Aktif çağrılar
  **düşmez**. Önerilen pencere **03:00–05:00 yerel**, confd timer'ı **önce durdurulur**.
- **BR-SYS-83 (yeni):** `confd-sunucu-sapma.sh` imaj ön koşulunu `strings` ile ölçüyor ama
  konteynerde `strings` **yok** → dal **her zaman** `OLCULEMEDI` veriyor. Düzeltme **yazılmadı**,
  çünkü bu turda sunucuya erişilemedi (`Connection timed out`) ve **ölçümsüz yazılmaz.** Ayrıca
  naif düzeltme ikinci bir kusur doğurur: `grep -c` sayım **0 iken çıkış kodu 1** verir, yani
  bugünkü `|| echo OLCULEMEDI` kalıbı aynen taşınırsa **meşru bir sıfır da "ölçülemedi" olur.**
- SMS sağlayıcı katmanı (BR-BE-54/55/56/57) hâlâ koşuyor.

**Commit'ler:** `97fbfff9` (Karar #36 + backlog senkronu), `3b7b15f2` (ClickUp eşleme düzeltmesi).

## Bilanço (kurul turu sonrası)

**276 kart — 122 bitti, 11 devam, 1 karar bekleyen, 142 kalan.**
(Beş yeni kart Karar #36'dan doğdu: BR-BE-107, BR-SEC-08, BR-OPS-01, BR-DB-42, BR-SYS-83.)

---

# İkinci tur (2026-09-07, akşam) — "hızlıca maddeleri bitir, testleri sona sakla"

## Bağlam

Kullanıcı hedefi değiştirdi: *"Hizlica maddeleri bitir testleri sona sakla. once maddeler bitsin."*
Bu turda **hiçbir test koşulmadı** (talimat). Doğrulama: derleme, `tsc -b`, kapı betikleri ve
mutasyon. Ajanlar test **dosyası** yazdı ama koşturmadı.

## 21. Disk bozulması — 3118 hatanın tek satırı bile kod değildi

- **Belirti:** `dotnet build` → **3118 hata**, hepsi `CS0246` ("Domain namespace'i yok").
- **Gerçek sebep:** `src/Pbxtr.Domain/Modules/Messaging/SmsClosedSets.cs` diskte **2147 baytlık
  NUL bloğuna** dönüşmüştü (boyut doğru, içerik tamamen `0x00`); Domain'in
  `obj/.../ref/Pbxtr.Domain.dll`'i de `MZ` yerine `0000` ile başlıyordu.
- **Üç tuzak birden:**
  1. Domain'i tek başına derlemek **"0 Error(s)"** dedi — MSBuild artımlı olarak **atladı**.
     Yalan ancak `obj/`+`bin/` silinince ortaya çıktı (202 gerçek hata).
  2. Bozuk ref dll'i silmek **yetmedi**: MSBuild `refint/`ten geri kopyaladı, dosya **aynı boyut
     ve aynı zaman damgasıyla** geri geldi. `obj/Debug`'ın tamamı silinmeliydi.
  3. Ağacı taramak için yazdığım `grep -qP '\x00'` döngüsü **"temiz" dedi** — grep desende NUL
     eşleyemiyor. Bayt okuyan bir node betiğiyle tekrar ölçtüm: bozuk dosya **1**.
- **Sebep tahmini:** eşzamanlı ajan yükü. Bu yüzden turun geri kalanında `dotnet` yetkisi **tek
  ajana** verildi.
- **Sonuç:** dosya `git checkout` ile geri alındı, enum ile birebir örtüştü, **kayıp yok**.
- **Deftere yazıldı:** `nul-blogu-derleme-selini-uretir`.

## 22. BR-SYS-83 — kartın öncülü TERS yönde yanlıştı

- Kart: *"`strings` yok, o dal **her zaman** `OLCULEMEDI` veriyor."*
- **Ölçüldü: dal her zaman `0` veriyordu.** `grep -c` sayım sıfırken stdout'a `"0"` yazar **ve**
  çıkış kodu 1 verir; `|| echo OLCULEMEDI` ikinci satıra düşer ve
  `IMAJ_SAYI=$(bolum IMAJ | head -1)` **birinciyi** alır. `:383`'teki dal **ölü koddu.**
- **Kontrol grubu:** işaretçiyi **gerçekten taşıyan** bir fikstür bile eski kalıpta `0` döndü,
  yeni kalıpta `1`. Eski kodun bugün doğru cevabı vermesi **tesadüf**.
- **Düzeltme:** üç durum ayrı token (`DOSYA_YOK` / `ARAC_YOK` / `<sayı>`), `strings` yoksa
  `grep -ac` ile ikiliye doğrudan bakılır, sayısal olmayan her işaret tek bir "ölçülemedi"
  dalına düşer. Commit `c18be95d`.

## 23. Kart durumu denetimi — hipotezim çürüdü, yerine başka bir sapma çıktı

55 "Bekliyor" kartının teşhis cümlesi tek tek ölçüldü.

- **Hipotez** ("iş bitmiş, satır bayat kalmış") **büyük ölçüde çürüdü: 55'te 2.**
- **Yerine çıkan:** **yedi kartın teşhis cümlesi yanlış.** İkisi ters yönde
  (*"hiçbir yerde kullanılmıyor"* / *"hiç koşmadı"* derken şey vardı ve koşuyordu; biri kartın
  yazıldığı **aynı gün** eklenmişti). Biri kartın önerdiği kapı numarasını (`kapi_28`) **dolu**
  buldu — kurulsaydı mevcut SMTP kapısını ezecekti. BR-DB-34 ise **kötüleşmişti**: "ikinci kez"
  değil **üçüncü kez**.
- Aynı ders bu turda üç kez daha tekrarlandı (BR-FE-33 uygulanabilir değildi, BR-FE-57'de kod
  haklı yorum bayattı, BR-FE-67'nin Asterisk bağı gereksizdi). **Oran deftere işlendi.**

## 24. Bitirilen kartlar

| Kart | Ne yapıldı | Commit |
|---|---|---|
| BR-BE-54/55/56/57 | Netgsm sağlayıcı katmanı, kapalı küme, devre kesici, fail-closed açılış | `46a3b7f8` |
| BR-SYS-83 | Ölçülmemiş önkoşul "sayım = 0" diye raporlanıyordu | `c18be95d` |
| BR-SYS-52/53 | Kart bayatmış; 53 mutasyonla doğrulandı | `8766cb09` |
| BR-DOC-06 + Ş36-26 | `pjsip reload` → `module reload res_pjsip.so` (13 dosya, 14 yer) | `5f916a67` |
| BR-DOC-03/04/13 | Üçünün de öncülü küçük çıktı (bkz. §25) | `3dcdffc6` |
| BR-SYS-57 | Posta ön koşul tazelik payı kapısı (`kapi_34`), 4 mutasyon | `6422ce68` |
| BR-FE-42…47 | SMS ön yüzü + Arapça çoğul boşluğu | `910a1aed` |
| BR-BE-58/60/64 | SMS satır yazımı, arama saati, kampanya turu | `af5825ca` |
| BR-SYS-79 + 6 P3 | CSP hash kapısı (`kapi_35`) + Web kartları | `a006e9a9` |

## 25. Belge kartları — üçünün de işi kartta yazandan büyüktü

- **BR-DOC-04:** kart yalnız `PAYLOAD_TOO_LARGE` eksik diyordu. Ölçüldü: `ProblemCodes` **96 kod**,
  belge **45** sayıyordu → **51 eksik**. Ters yön temiz (hayalet kod **0**). 51'i de anlamlarıyla
  eklendi, aynı betikle yeniden ölçüldü: **96 = 96**.
- **BR-DOC-13:** sayı **10 değil 18**. Belge kendi içinde de çelişiyordu (başlık "10 uç", tablo 11
  satır). Daha önemlisi: *"hepsi provisioning tetikler"* ilkesi **artık yanlış** — 18'in dördü
  tetiklemiyor; ortak nitelik "kaybedilen güncellemenin geri alınamaz olması" olarak yeniden
  yazıldı.
- **BR-DOC-03:** F6 → **BİLİNÇLİ**, R7 → **BORÇ**. Kurul Karar #30/2 ile **10/10** oyla
  `recording.listen`'ın owner+supervisor'a açılmasına karar vermiş; `permissions.seed.json:888`
  hâlâ yalnız `superadmin` taşıyor. **Karar yazılmış, uygulanmamış.**

## 26. Araç kusuru — ClickUp "Çoğu bitti"yi KAPALI sayıyordu

- BR-BE-64'ün durumu *"Çoğu bitti (otomatik tur BR-DB-43)"* idi ve mapper `complete` dedi.
- Kısmi satır kuralı bir **kelime listesiydi** (`Yarısı|Kısmen`) ve "Çoğu" listede yoktu.
- Kural **yapısal** yapıldı: *"bitti" içerip "Bitti" ile başlamayan her durum kısmidir.*
- **İlk denemem eski kapsamı kaybetti:** `KISMEN KAPANDI` içinde "bitti" geçmiyor. Ölçüldü,
  geri eklendi. **Yeni bir kapı, değiştirdiği kapının kapsamını kaybetmemelidir.**
- Yama **iki dosyaya** birden uygulandı; eşleşme bekçisi (`!=1 → throw`) ikinci dosyadaki farklı
  deseni yakaladı.

## 27. Ajanların bulduğu gerçek kusurlar (kartlarda yazmıyordu)

- **`SmsBody.Render(body, null)` şablonu olduğu gibi döndürüyordu** → `{tutar}` içeren bir şablon
  toplu gönderimde müşteriye **ham süslü parantezle** giderdi.
- **`problemMessage`, `BLOCKED_IYS_UNVERIFIED`'i `prb.generic`'e düşürüyordu** → Ş1-1 kapısı
  çalışır ama agent "Bir hata oluştu" görüp **aynı ticari şablonu tekrar denerdi**.
- **Demo CSP'si Report-Only değil ZORLAYICI** → tema önyükleme scripti demoda **bugün fiilen
  bloklanıyordu**. Kart bunu gelecek zamanla yazmıştı.
- **Arapça çoğul boşluğu** (benim ölçümüm): yeni `sms.segments` yalnız `one`/`other` taşıyordu;
  `Intl.PluralRules('ar')` **2** için `two`, **3–10** için `few` seçer — parça sayısının tipik
  aralığı eksikti. Emsal `ticket.count` altı kategori taşıyor. Dördü eklendi.

## Kararlar

- **Eşzamanlı ajan koştururken `dotnet` tek ajana verilir.** Bugünkü NUL bozulmasının en olası
  sebebi budur ve bedeli bir kaynak dosyasıydı.
- **Ölçemediğim kapıyı yazmam.** BR-SYS-81 (compose sapma kapısı) yazılmadı: kartın kendisi
  "önce sapma kapatılmalı" diyor ve sunucu yine `Connection timed out`.
- **Kısmi durum, tam sayılmaz** — ve bu kuralı **liste** değil **yapı** zorlar.

## Açık kalanlar / sonraki adım

- **BR-SYS-82 hâlâ kullanıcı onayı bekliyor** (kısa kesinti; 502 penceresi ~10–20 s, aktif
  çağrılar düşmez, önerilen pencere 03:00–05:00 yerel).
- **YAYIN ÖNKOŞULU DEĞİŞTİ:** `Sms:Provider` yazılıysa **`Sms:HashPepper` zorunlu** (mock dâhil),
  yoksa uygulama **hiç açılmaz**. Sunucuda `PBXTR_Sms__HashPepper` yazılmadan dağıtım kalkmaz;
  değer `sifreler` aynasına düşmeli.
- **Yeni kartlar:** BR-DB-43 (çağrı sonrası SMS'in veri bağı yok, özellik inert),
  BR-BE-108 (zaman aşımında SMS izi kalmıyor — denetim satırı gönderimle aynı transaction'da),
  BR-QA-31 (§1.5.1 ↔ `ProblemCodes` parite bekçisi yok), BR-SYS-84 (`style-src` zorlayıcı
  yapıldığı gün 17 inline stil özniteliği bloklanır).
- **Testler hâlâ koşulmadı** — kullanıcının açık talimatı. Sona saklandı.

## Bilanço

**280 kart — 148 bitti, 9 yarım, 104 bekliyor, 19 diğer.**
(Sabah: 276 kart / 122 bitti. Bu turda **+26 bitti, +4 yeni kart**.)

---

# İkinci tur — 2026-09-07 öğleden sonra

## Bağlam

Sabah turu 12:20'de kapandı; sunucuya Tailscale ile erişim açıldı ve bekleyen sunucu işleri
uygulanabilir hâle geldi. Kullanıcı smtp2go'yu kendisi yapılandırmaya başladı. Testler hâlâ
koşulmuyor (kullanıcının açık talimatı).

## Sabahki günlükte YANLIŞ yazdığım bir cümlenin düzeltmesi

Sabah "Açık kalanlar" bölümüne şunu yazmıştım:

> Sunucuda `PBXTR_Sms__HashPepper` yazılmadan dağıtım kalkmaz.

**Bu yanlıştı ve ölçümle çürüdü.** `AddPbxtrSms` `Sms:Provider` boş olduğunda **erken dönüyor**;
biber kapısı o dalda hiç koşmuyor. Sunucudaki compose'da `PBXTR_Sms__*` anahtarlarının **hiçbiri
yoktu**, yani dağıtım zaten kalkıyordu — SMS sadece kapalıydı. Bir kapının *varlığı* ile o kapının
*koştuğu dal* farklı şeyler; ben ikisini birleştirmiştim.

Ayrıca ölçüldü: `pbxtr-demo/docker-compose.yml` `app` servisi için **`env_file` KULLANMIYOR** —
değişkenleri tek tek sayıp `.env`'den `${...}` ile enterpole ediyor. Bu yüzden `.env`'e
`PBXTR_Sms__...` yazmak **etkisizdir**; anahtarın compose'da da sayılması gerekir.

## Yapılanlar

### 1. Sunucu: mail ön koşulu ve compose sapması (BR-SYS-81/82/83)

- **Neden:** ön koşul dosyası uygulamaya ulaşmıyordu ve depo ile sunucudaki compose ayrışmıştı.
- **Ne yapıldı:** iki ayrı 24 saniyelik kesintiyle uygulandı (kullanıcı onayı alınarak). Yazmadan
  önce sunucudaki `.env`'de 12 zorunlu değişkenin varlığı doğrulandı, aday compose
  `docker compose config` ile geçerlendi.
- **Sonuç:** uygulama artık ölçümü **görüyor** ve `precondition_missing` yerine doğru şekilde
  **SPF başarısız** diyor. Depo ↔ sunucu compose sha'sı **aynı**.
- **Yeni kapı:** `deploy/compose-sunucu-sapma.sh` (`yerel-yayin.sh` 1/7-c) — iki iddia: (1) sha
  eşitliği, (2) `app.environment` içindeki her `PBXTR_*` anahtarının **çalışan konteynerde**
  bulunması. Çıkış kodları 0/1/2(vacuity)/3(ölçülemedi); dört mutasyon doğrulandı.
- **Commit:** `9c552306`

### 2. `strings` yokluğu bir ölçümü sessizce sıfır gösterdi

- **Neden:** derlemenin gerçekten yeni kodu taşıdığını doğrulamak istedim.
- **Ne oldu:** `strings ... | grep -c X` üç ölçüm için de **0** yazdı. "Yeni tipler ikilide yok"
  demekti. Gerçek sebep: **bu makinede `strings` YOK** ve boş girdi alan `grep -c` 0 basıyor.
- **Doğru ölçüm:** node ile ham bayt araması, hem UTF-8 hem **UTF-16LE** (.NET dizeleri böyle
  saklanır). Sonuç: üç yeni tip de ikilide **var**, `schedule-owner` **var**, `tenant-owner` ve
  `tr-TR` **gitmiş**.
- **Ders:** aracın yokluğu, ölçümün "0" sonucu gibi görünür. Bu depoda aynı sınıf bugün ikinci kez
  yaşandı (sabah `confd-sunucu-sapma.sh` üç durumlu hâle getirilmişti).

### 3. BR-QA-13 — gönderici alan adı literali bekçisi

- **Neden:** rapor postası adresi ayardan gelmeli; kodda alan adı literali olmamalı.
- **Önce ölçüldü:** `src/` altında `pbxtr.com` geçen **14 satırın hiçbiri çalışan kod değil**
  (7 XML doc/yorum, 7 `.test.tsx` fikstürü). Yani düzeltme değil, **regresyon bekçisi**.
- **Ne yapıldı:** `tests/Pbxtr.Architecture.Tests/SenderDomainLiteralGuardTests.cs` — üç kural
  (sunucu `pbxtr.com`, istemci `pbxtr.com`, gömülü `no-reply@`/`postmaster@`/`bounce@`), yorum
  satırı ve `.test.*` hariç, vacuity kapılı (1272 C# / 381 TS; eşikler 500 / 200).
- **Doğrulama:** üç mutasyon ayrı ayrı kırmızı, mutasyon geri alındı, ağaç temiz.
- **Neden önemli:** beyaz-etiket gönderici alanı (BR-SYS-44) bayinin kendi alan adıyla
  göndermesini gerektiriyor. Koda kaçacak tek literal, bayinin postasını **bizim** alan adımızdan
  yollar; SPF/DKIM hizalaması bizim kayıtlarımıza düşer. Belirti yanıltıcıdır: mesaj gider, teslim
  edilir, yalnızca `From` yanlıştır.
- **Commit:** `b3b79c7d`

### 4. BR-QA-14 — ekran dokuz dilde yanlış şey söylüyordu (gerçek kusur)

- **Kartın öncülü:** "`replyToPolicy` gönderim yoluyla eşleşmiyor **olabilir**".
- **Ölçüm:** gerçekten eşleşmiyordu. Sabit `tenant-owner`, ekran metni *"yanıt adresi tenant
  sahibidir"*; adres ise `ReportDeliveryDispatcher.cs:425` içinde `schedule.OwnerUserId`'den
  okunuyor ve o alan `EfReportScheduleService.cs:128` içinde `_tenantContext.UserId` ile —
  **zamanlamayı KURAN kişi** ile — doldurulur.
- **Etkisi:** süpervizörün kurduğu bir zamanlamada yanıtlar süpervizöre gider; ekran yöneticiye
  "tenant sahibine gider" diyordu.
- **Karar:** kod tasarıma uygun (`ReportSchedule.OwnerUserId` zaten böyle tanımlı), yanlış olan
  **etiketti**. Sabit `schedule-owner` oldu, dokuz dilin metni ve iki bayat yorum düzeltildi.
- **Bekçi:** `ReplyToPolicyParityTests.cs` — 6 test, iddia zincirini bağlıyor (`ReplyToAddress`
  tek atama, adres `schedule.OwnerUserId` + `HomeTenantId == tenantId` üzerinden, sistem
  postasında Reply-To yok, istemci haritası ↔ sunucu kodu birebir, dokuz dilde metin + eski
  anahtarın yokluğu).

### 5. BR-BE-34 — kart P3 kozmetik diyordu, ölçüm ÇÖKME gösterdi

- **Kartın öncülü:** "`AnalyticsExportCsv.cs:255` tr-TR kültüründe ondalık ayırıcı virgül üretir".
- **Ölçüm:** `Directory.Build.props:11` ile `InvariantGlobalization=true` **tüm projelerde** açık.
  O kipte `tr-TR` kültürü **yoktur** ve `new CultureInfo("tr-TR")` **`CultureNotFoundException`
  fırlatır**. Yani satır yanlış ayırıcı üretmiyordu — yüzde içeren **her analitik dışa
  aktarımında patlıyordu** (9 çağrı yeri).
- **Aynı hata daha önce görülmüş:** `CallReportCsv.FormatPercent` BR-BE-15 ile ölçülüp
  düzeltilmiş, bu dosya o turda atlanmış.
- **Düzeltme:** `ToString("0.00", InvariantCulture).Replace('.', ',')` — aynı çıktı ("75,50"),
  kültürden bağımsız.
- **Bekçi:** `InvariantGlobalizationGuardTests.cs` — yasak **artı** yasağın **öncülünü** ayrıca
  ölçen ikinci test (props ayarı hâlâ `true` mu). Bekçinin kendi varsayımını ölçmesi, ayar
  değiştiğinde kuralın sessizce anlamsızlaşmasını engelliyor.
- **Sonuç:** `src/` içinde kalan `new CultureInfo(` sayısı **0**. Kart P3 → **P1**.

### 6. Ön yüz turu (BR-FE-23, BR-QA-17, BR-QA-25, BR-QA-09)

- **BR-FE-23:** zil/modal yalnızca #09 ve #15'in render ağacındaydı; agent #19/#23'e geçince ağaç
  sökülüyor, `AudioContext` kapanıyordu — kusur "zil kısık" değil **"zil YOK"**. `IncomingCallAlert`
  kabuğa taşındı; **yeni fetch/abonelik/interval yok** (polling yasağı korundu), mevcut
  `AgentStatusProvider`'dan besleniyor. Yutulan `setSinkId` reddi yüzeye çıkarıldı.
- **BR-QA-17:** `vi.mock` imza daralması depo genelinde **76 adet** ölçüldü. En riskli ikisi
  düzeltildi; kalanlar satır ve sayısıyla donduruldu, çark yalnız aşağı döner. Düzeltilenlerden
  biri gerçek risk taşıyordu: `updateTenantSettings` ikizi ekranın **`etag`'ini `signal` adıyla**
  kaydediyordu.
- **BR-QA-25 / BR-QA-09:** `If-Match` davranışı fetch seviyesinde üç hâlli ölçüldü; denetim hedef
  türü paritesi 43/43, iki yönlü, anti-vacuity kaynak okunamazsa **atar**.

### 7. Provisioning turu (BR-BE-72/74/47/75/49/73)

- **BR-BE-72:** öncül **yanlış** — 304 dalı denetim satırı yazmıyor, iş Karar #33 ile zaten
  kapanmış, backlog satırı bayattı.
- **BR-BE-75:** dört belge `POST /provisioning/report`'u çağırıyordu, **uç yoktu**. Yazıldı; gövde
  kapalı küme, serbest metin denetim günlüğüne giremez, denetim kuyruğuna yazılamazsa **503**.
- **BR-BE-47:** kartın önerdiği `ITenantCache` yolu **seçilmedi** — sunucunun "teslim ettim" kaydı
  düğümün diskinde ne olduğunu söylemez ve silme geri alınamaz; ayrıca GET'e `SetAsync` eklemek
  Sınıf A idempotency kapalı listesini kırardı. Doğru kaynak düğümün kendisi: `X-Pbxtr-Have`.
- **BR-BE-73:** kod değişikliği **yapılmadı**, gerekçesi ölçülü — alarm yüzeyi olmadan fail-open
  yapmak, bugün gürültülü olan bir arızayı **sessiz** hâle getirirdi.
- **Commit:** `f5ed10db`, kartlar `ec65b607`

### 8. `backlog.md` bir kez 4742 → 9334 satıra şişti (kendi hatam)

- **Sebep:** JS `String.replace`'in `$` + backtick özel deseni. BR-BE-75 kart metnindeki regex
  örneği (`{0,39}$`) hemen ardından gelen backtick ile birleşince **"eşleşmeden önceki tüm metin"**
  olarak yorumlandı ve dosyanın tamamı enjekte edildi.
- **Fark ediş:** doğrulama çıktısında aynı kart kodunun **iki satır** görünmesi.
- **Düzeltme:** `git checkout --` ile geri alındı, replacement fonksiyona çevrildi
  (`replace(hedef, () => yeni)`), sonuç 4742 satırda doğrulandı.
- **Not:** bu hata bu depoda daha önce de not edilmişti; bu kez farklı bir yerden geldi
  (kart metnindeki regex örneği).

### 9. smtp2go — kullanıcının adımı, ölçüm bende

- **Ölçülen:** `spf.smtp2go.com` düz `ip4:` listesi → **ek DNS lookup yok**, SPF 10-lookup bütçesi
  sorun değil. Sunucudaki `/etc/pbxtr/mail-onkosul.env`'de `PBXTR_MAIL_DOMAIN`,
  `PBXTR_MAIL_RELAY_HOST`, `PBXTR_MAIL_SPF_INCLUDE` **dolu**; `PBXTR_MAIL_DKIM_SELECTOR` ve
  `PBXTR_MAIL_RETURN_PATH_HOST` **boş**. Sarmalayıcı (satır 72-73) ikisini de env'den okuyor —
  yani eşlenik ayar **bağlı**, yalnızca değer yok.
- **Ölçülen (olumsuz):** kullanıcı "DNS'leri ekledim" dedikten sonra yetkili sunucuya
  (`pam.ns.cloudflare.com`) doğrudan soruldu: apex TXT, `_dmarc` TXT ve MX **üçü de boş**.
  Cloudflare'de kayıt anında yetkilidir → yayılma gecikmesi değil. Kayıtlar başka bir bölgeye
  girilmiş ya da kaydedilmemiş.
- **Ölçülen (olumsuz):** paylaşılan API anahtarı smtp2go tarafından **reddedildi**
  (`An API User matching the passed 'api_key' was not found`).
- **Bekleyen:** selector sayısı (`s<N>`), doğru bölgeye girilmiş DNS kayıtları, gerçek API
  anahtarı (bana yazılmadan sunucuya konacak).

## Kararlar

- **Kart öncülü ölçülmeden kod yazılmaz.** Bu turda kapanan 13 karttan **beşinde** öncül
  yanlıştı ya da kartın önerdiği çözüm yanlıştı. İkisinde altından **daha ağır** bir kusur çıktı
  (BR-BE-34 çökme, BR-QA-14 dokuz dilde yanlış iddia).
- **Bir bekçi kendi öncülünü de ölçmeli.** `InvariantGlobalizationGuardTests` ikinci bir testle
  `Directory.Build.props` ayarını doğruluyor; ayar değişirse kural sessizce anlamsızlaşmıyor,
  **kırmızı** yanıyor.
- **Aracın yokluğu ölçüm sonucu gibi görünür.** `strings` yok → `grep -c` 0 → "yeni kod ikilide
  yok" yanlış sonucu. Ölçüm aracının varlığı ayrıca doğrulanmalı.
- **Paralel ajan varken `git add -A` kesinlikle yok; yollar tek tek sayılır.** Bu turda confd
  ajanının iki dosyası bilerek commit dışında bırakıldı.

## Açık kalanlar / sonraki adım

- **smtp2go:** DNS kayıtları `pbxtr.com` bölgesinde **yok**; kullanıcı bölgeyi teyit edecek ve
  `s<N>` selector sayısını verecek. Sonra `PBXTR_MAIL_DKIM_SELECTOR` / `PBXTR_MAIL_RETURN_PATH_HOST`
  sunucuya yazılıp `pbxtr-mail-onkosul.service` elle koşturulacak; beklenen `ok=true`.
- **BR-SYS-80:** çalışan imaj `RemovedBasis` taşımıyor (ölçüldü: 0). Sıra değişmedi — önce onu
  taşıyan imaj yayınlanmalı, **sonra** confd betiği aktarılmalı. Yayın kullanıcı onayı ister.
- **BR-SEC-08** kurulda: ilke taslağı + 7 yetkilik etki listesi teslim edildi, koda dokunulmadı.
- **Netgsm** gerçek sağlayıcı doğrulaması hesap açılmadan yapılamıyor; sunucuda SMS kapalı.
- **Testler hâlâ koşulmadı** — kullanıcının açık talimatı, tur sonuna saklandı. Yazılmış ama
  koşulmamış test dosyası sayısı 60'ın üzerinde.
- **Koşan ajanlar:** confd düğüm istemcisi (BR-SYS-36/37/38/39) ve provisioning BE ölçüm turu
  (BR-BE-43/46/48/50/52).

## Bilanço

**281 kart — 167 bitti.** (Sabah: 280 kart / 148 bitti. Bu turda **+19 bitti, +1 kart**.)
