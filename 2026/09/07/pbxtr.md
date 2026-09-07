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
