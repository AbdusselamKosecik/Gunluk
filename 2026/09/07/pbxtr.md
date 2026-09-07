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

---

# Üçüncü tur — 2026-09-07 akşam

## Yapılanlar

### 10. confd düğüm ajanı indi (BR-SYS-36/37/38/39/41)

- **Neden yeni dosya:** kart `pbxtr-confd-cek.sh`'i işaret ediyordu; sözleşme §4.1 iki ucu
  **anahtara göre** ayırır — `/bundle` tenant'ı anahtardan çözer ve yanıtta tenant kodu **yoktur**.
  Yani oradaki `t0007-` sabiti betiğin tembelliği değil, **o ucun kaçınılmaz sonucu.** Dönüştürmek
  Mod A'nın tek teslim yolunu silerdi.
- **Bedeli:** iki `DIR` haritası. **Panzehiri:** `kapi_29` artık ikisini hem `ConfigRenderer.Kinds`'e
  hem **birbirine** karşı kilitliyor (mutasyonla doğrulandı).
- **Kapı `kapi_38`:** 17 fikstür, 67 iddia, 9 mutasyon — hepsi kırmızı verdi.
- **Kapı yazılırken bulunan üç gerçek hata:**
  1. **Kapı sessizce vacuous'tu** — MSYS'te `chmod 0600` tutmadığı için ajan hiç çalışmadı (78) ve
     *"dosya yazılmadı"* iddialarının **21 tanesi yeşil döndü**. Artık ölçemediğinde **"ÖLÇÜLMEDİ"**
     yazıyor, yeşil saymıyor.
  2. `ESKI=$(sed … sha-defteri)` `set -euo pipefail` altında ilk koşuda **tüm ajanı düşürüyordu** —
     ajan **ilk koşusunda hiçbir zaman çalışmazdı**.
  3. Kapının kendi `grep`'i birim dosyasındaki **açıklayıcı yorumu** ihlal sandı. Böyle bir kapı
     doğru davranışı belgeleyeni cezalandırır ve *"gerekçeyi silelim"* ile kapanır.
- **`PrivateTmp` bir hata ortaya çıkardı:** `docker run -v` yolları **daemon'ın** görüşüne göre
  çözer; çalışma dizini `/tmp` altında kalsaydı ayrıştırıcı boş dizin görür, ajan `69` döner ve
  arıza *"sunucu hatası"* gibi görünürdü. Dizin `/var/lib/pbxtr-confd/is`'e alındı.
- **Commit:** `26f4a2f4`

### 11. BR-BE-39 — kartın yazmadığı ikinci delik

Kart tek dalı (Conflict dışı DB hatası) yazıyordu. Ölçüm ikinciyi gösterdi: `Conflict` dalındaki
yorum *"iz `IAuditSink` ile kalır"* diyordu ama **o dalda `TryEnqueue` çağrısı yoktu.** Her iki
dalda da müşteri aranıyor, telefonu çalıyor, denetim günlüğünde **o arama hiç olmamış** görünüyordu.
İz artık originate kabulünün hemen ardında ve transaction dışında. Yeni eylem kodu üretilmedi
(`CallOriginated` zaten var). **Commit:** `6ab653a7`

### 12. `backlog.md` satırında zincirleme kendi hatam

`BR-AST-41` açıklamasına düz bir `|` yazdım (`string[]|null`) → markdown tablosunda **kolon
ayırıcısı**. Sonra "kolon sayısını normalize ederken" **yanlış kolonu düşürdüm** ve **durum
kolonu gitti**; çıkarıcı son kolonu durum sandı (`durum = "sahibi asterisk-uzmani"`). Satır
baştan yazıldı, metinde düz `|` hiç kullanılmadı. **Ders:** iki düzeltmeyi üst üste bindirmeden
önce her birinin sonucunu ayrı ölç.

Aynı turda bir **yanlış alarm** da oldu: kuru koşuda öncelikler "P3/P3/P2/P2" görününce kart
düzenini bozuk sandım. Değildi — `clickup-olustur.js:47` `oncelikEsle` P1'i ClickUp'ın **2 (High)**
değerine eşliyor ve `:107` o **sayıyı** basıyor. Koddan doğrulanmadan "düzeltilseydi" çalışan bir
eşleme bozulacaktı.

## Kararlar

- **Markdown tablo hücresinde düz `|` yazılmaz.** Kaçışlı `\|` de tercih edilmez: bu dosyayı okuyan
  araçların hepsi onu aynı okumuyor (263 satırın 110'unun kolon sayısı zaten farklı). "veya" yazılır.
- **Bir aracın çıktısı beklenmedikse önce aracın kodunu oku.** Bugün iki kez, tahminle "düzeltmeye"
  kalksaydım çalışan bir şeyi bozacaktım.

## Açık kalanlar / sonraki adım

- **BR-SYS-86 (yeni):** `pbxtr-confd-dugum.sh` sunucuda yok ve BR-SYS-80 döngüsü duruyor. Sıra
  bağlayıcı: (1) `RemovedBasis` taşıyan imaj, (2) **sonra** betikler, (3) elle ilk koşu. Ters sıra
  düğümü **kalıcı kırmızı** yapar. Yayın kullanıcı onayı ister.
- **BR-BE-109 (yeni):** `GET /provisioning/media/{id}/content` anahtarın kendi tenant'ına kapsanıyor
  → düğümdeki diğer tenantların medyası 404 → **medyası olan her ikinci tenant kalıcı olarak
  atlanıyor.** Sunucu tarafı düzeltme gerekiyor.
- **BR-AST-41/42 (yeni):** düğüm paketi sözleşmesi iki noktada koddan geride (`Removed`/
  `RemovedBasis` tenant başına; `X-Pbxtr-Have` başlığı tabloda yok).
- **Kurulda dört madde:** A10 (`phone.unmask` gereksinimi — `admin` kilitlenir), A11 (serbest metin
  maskeleme tasarımı), A12 (`NODE_NOT_PINNED`), A13 (`withheld` biçim birleşmesi).
- **smtp2go:** DNS kayıtları `pbxtr.com` bölgesinde hâlâ yok; selector sayısı ve gerçek API anahtarı
  bekleniyor.
- **Testler hâlâ koşulmadı** — kullanıcının açık talimatı.

## Bilanço

**285 kart — 177 bitti, 10 yarım, 93 açık, 5 kapandı/red.**
(Sabah 276/122 ile başlandı. Gün boyunca **+55 bitti, +9 yeni kart**.)

---

# Dördüncü tur — 2026-09-07 akşam geç

## Yapılanlar

### 13. confd düğüm ajanında İKİ GERÇEK ÜRETİM KUSURU

İkisi de ancak ajan **aynı gövdeyle iki kez** koşturulunca çıktı. 17 fikstürün hiçbiri ajanı
aynı kök altında iki kez koşturmuyordu; "önceki durum" hep fikstürün **elle yazdığı** defterdi
— yani **ajan kendi yazdığını hiç okumadı.**

- **D1 — "sha256 değişmediyse reload yok" kuralı fiilen SIFIR kez çalışıyordu.** Defteri yazan
  satır dört sütun yazıyor; okuyan `sed` geri referansı **satırın kalanının tamamını** alıyordu,
  yani karşılaştırma hiçbir zaman doğru olamıyordu. Ölçüm: değişmeyen gövdede ikinci koşu
  *"değişen tür sayısı: 12"*. **Üretimdeki karşılığı: her beş dakikada tam yazım +
  `module reload res_pjsip.so` + `queue reload all` + `dialplan reload` — canlı çağrıların
  üstünde, sonsuza kadar.**
- **D2 — ilk başarılı teslimden sonra ajan, kuyruk türü her değiştiğinde SESSİZCE ölüyordu.**
  `EKSIK=$(grep -vxF -f YENI ESKI ...)` — `grep` hiçbir satır seçmezse **1** döner ve bu,
  kapının ölçmek istediği **normal** haldir ("kuyruk kaybı yok"). `set -euo pipefail` altında
  atama başarısız sayılıyor ve ajan orada ölüyordu: `exit 1`, gerekçe yazmadan, diske hiçbir
  şey yazmadan. Kuyruk defteri kuran iki fikstür de **gerçek bir eksilme** üretiyordu, yani
  *"önceki defter VAR + eksilme YOK"* dalı **hiç koşmamıştı**.
- **Panzehir:** F18 (aynı gövde ikinci kez → sıfır yazım/reload) ve F19 (önceki defter var +
  eksilme yok → ajan ölmez). Fikstür 17→19, iddia 67→74. İkisi de mutasyonla doğrulandı.
- **Ders:** bir bekçi, ölçtüğü şeyin **ikinci koşusunu** içermiyorsa "durum" mantığını hiç
  ölçmemiştir. Fikstürün elle yazdığı önceki durum, ürünün ürettiği önceki durum değildir.

### 14. BR-SYS-40 — `TimeoutStartSec` N=50'de YETMİYOR

Gövde sunucudan ölçüldü (t0007 = 9 881 B). N=2/10/50 → gzip 1,9 / 7,2 / **33 KB** — sözleşmenin
8 MB eşiğinin **1/250**'si. **Gövde sorun değil; sınır çağrı sayısında.** Tek `docker exec`
hedef sunucuda **115 ms** ölçüldü → N=50 için tur ~**300 sn**, `TimeoutStartSec=240` **yetmez**
ve kesilen tur **yarım teslimdir**. Tavan ~**38 tenant**; değer büyütülemez (300 sn timer
aralığından küçük kalmalı). Servis dosyasındaki *"N=50 ölçülmedi"* borç bloğu **ölçülmüş
tabloyla** değiştirildi. Yeni kart BR-SYS-87 (çağrı toplulaştırma).

### 15. BR-SYS-70 — yayında `--force-recreate nginx` kalktı

Kartın dört öncülü de doğru çıktı. **Ek ölçüm (kartta yoktu):** recreate'in tek makul gerekçesi
*"app'in IP'si değişir"*di — compose'da `app` **sabit adresli** (`172.28.0.11`, depo ve sunucu
birebir aynı). Yani recreate **hiçbir şey kazandırmadan** tüm SIP/izleme WebSocket'lerini
düşürüyordu. Yerine gerçek konteynerde `nginx -t` → geçerse `nginx -s reload`.

**Sahte sağlık kanıtı kaldırıldı:** `curl --fail http://127.0.0.1/` — `--fail` **3xx'i hata
saymaz**, yani 443 bloğu tamamen kırıkken de yeşil geçerdi. Yerine iki gerçek ölçüm.

**Ş35-4'ün WebSocket 101 şartı bilerek yazılmadı:** ölçüldü, `/ws/` upgrade isteğine bugün
**200** dönüyor; şartı olduğu gibi yazmak **her yayını geri alan** bir kapı kurardı.

### 16. BR-SYS-71 — `sysagent` bileşeni `All` listesinde yoktu

Kart tek yönü soruyordu (*listede olup yayılmayan*); o yön yeşildi. **Ölçüm öbür yönü kırık
buldu:** sınıf 16 sabit tanımlıyor, `All` 15 taşıyordu — `SystemAgent` listede yoktu, oysa probe
onu gerçek bir bileşen olarak yayıyor ve sabitin kendi açıklaması *"ön sistem ekranı bu bileşene
bakar"* diyor. Mevcut `HealthComponentLabelPairingTests` bunu göremezdi: o test sabit ↔ **etiket**
çiftini ölçüyor, sabit ↔ **liste** çiftini kimse ölçmüyordu. İki yönlü bekçi kuruldu, iki mutasyon
kırmızı doğrulandı.

### 17. BR-QA-05 — beş ön ölçüm; biri yeni bir risk açtı

**#43 Paket İzleme ham `.pcap` dosyasını istemciye indiriyor** (`CaptureEndpoints.cs:223-224`).
Bir SIP yakalaması tam numaraları taşır ve **bir pcap anlamlı biçimde maskelenemez** — bu, açık
karar A11'in *"çıktıyı maskele"* seçeneğini #43 için **geçersiz** kılıyor. Geriye yetki (A10) ya
da kapsam daraltma kalıyor. Yeni kart BR-SEC-09.

(b) öncülü yanlıştı: `call.hold`/`call.transfer` kodları **hiçbir şeyi kapamıyor**, ikisi de tek
uca çökertilmiş ve kapıları `call.handle`. (e) **vacuous**: canlı DB'de 45.393 denetim satırı var
ama `qa.*` ve `recording.*` **sıfır** — "dinlemeden puanlama" oranı hesaplanamaz.

### 18. Posta/rapor turu — yedi kart

`MailWarningDto` daraltıldı (aynı yanıtta iki konvansiyon vardı). Ölçüm bir boşluk da gösterdi:
**hiçbir test `message` alanına bakmıyordu**, o yüzden daraltma hiçbir testi kırmadı.
İlk taslak yarışının gerçek PostgreSQL kanıtı yazıldı — `Barrier` **bilerek** kullanılmadı,
çünkü A önce commit ederse B `UPDATE` dalına düşer ve test **yeşil ama ölçülmemiş** olur.
BR-BE-51 **bloke**: `provisioningGapSec`'i üretecek kalıcı kayıt yok (provisioning durumu Redis'te
30 dk TTL) → yeni kart BR-DB-44.

## Kendi hatalarım (bu turda dört tane)

1. **BR-SEC-06'yı yanlış ölçtüm ve yanlış yazdım.** *"`AddMemberAsync` operasyonel olup olmadığına
   hiç bakmıyor"* dedim; kapı **zaten vardı** (`EfQueueAdministration.cs:442-452`). Dosyayı satır
   440'ta okumayı bırakmıştım. Kart ve commit ile düzeltildi.
2. **Sağlık bileşeni ölçümünü üç kez yanlış yaptım.** `node -e` heredoc'u `\b`'yi **gerçek
   backspace karakterine** çevirdi ve regex hiçbir şeye eşleşmedi → *"15/15 bileşen hiç geçmiyor"*
   gibi **imkânsız** bir sonuç. Sonucun imkânsızlığı kurtardı.
3. **`kapi_27`'yi yanlış koşturdum:** fonksiyon `WF="$0"` kullanıyor; onu `/tmp/k27.sh` olarak
   koşturunca **yanlış dosyayı** taradı ve altı bekçiyi "çağrılmıyor" sandım. Doğrusu 14/14.
4. **Canlı DB'ye `scope <> 'tenant'` sorgusu attım** — o değer hiç yok (`global`/`dealer`/`single`),
   yani sayım anlamsızdı.

## Ajanın bir kazası — kayıt için

Bir ajan ölçüm sırasında bir komuta **`git checkout -- .`** dahil etti ve o andaki tüm
commit'lenmemiş değişiklikleri geri aldı. **Kayıp olmadı** (paralel işlerin hepsi zaten
commit'liydi, HEAD `origin/main` ile eş, benim `sysagent` düzeltmem ve yeni test dosyam yerinde)
— **ama bu şanstı.** `git add -A` yanlış şeyi *ekler* ve geri alınabilir; `git checkout -- .`
yanlış şeyi **siler** ve reflog'da izi **yoktur**. Bundan sonra ajan brifinglerine
`git checkout -- .` / `git restore .` / `git clean -fd` / `git reset --hard` yasağı da açıkça
yazılacak — "commit etme" cümlesi *yazma* işlemlerini yasaklıyor gibi okunuyor ve geri alma
komutları o kümeye girmiyor.

## Kararlar

- **Bir bekçi, ölçtüğü şeyin ikinci koşusunu içermiyorsa "durum" mantığını hiç ölçmemiştir.**
  Fikstürün elle yazdığı önceki durum, ürünün ürettiği önceki durum değildir.
- **`grep`'in 1 dönmesi `set -e` altında bir arıza değil, çoğu zaman NORMAL haldir.** `|| true`
  ile susturmak üçüncü hali (gerçek hata) ikinciye katar ve kapıyı fail-open yapar; üç hal ayrı
  okunur.
- **Bir aracın çıktısı beklenmedikse önce aracın kodunu oku.** Bugün üç kez, tahminle
  "düzeltmeye" kalksaydım çalışan bir şeyi bozacaktım.

## Açık kalanlar / sonraki adım

- **smtp2go** hâlâ sende: DNS kayıtları `pbxtr.com` bölgesinde yok, selector sayısı ve gerçek API
  anahtarı bekleniyor.
- **BR-SYS-86** yayın onayı sende. Gerekçesi düzeltildi: ters sıranın bedeli "kalıcı kırmızı düğüm"
  değil, **"kuyruk kaldırma işlemleri teslim edilmez"**.
- **Kurulda dört madde:** A10 (`phone.unmask` — `admin` kilitlenir), A11 (serbest metin maskeleme;
  #43 için **geçersiz**, bkz. ölçüm eki), A12 (`NODE_NOT_PINNED`), A13 (`withheld` biçimi).
- **Testler hâlâ koşulmadı** — kullanıcının açık talimatı.

## Bilanço

**290 kart — 183 bitti, 8 kapandı/red, 11 yarım, 88 açık.**
(Sabah 276/122 ile başlandı. Gün boyunca **+61 bitti, +14 yeni kart**.)

---

# Beşinci tur — 2026-09-07 gece

## Bağlam

Gün boyunca biriken dört açık karar (A10–A13) PBXTR kuruluna götürüldü. Kurulu ben topladım,
karar metnini ben yazdım. **Turun asıl sonucu kararlar değil, kurulun brifingimi çürütmesi oldu.**

## Yapılanlar

### 19. Kurul Karar #37 — on üye, dört karar

Sonuçlar: **A10 ŞARTLI ONAY** (7 ŞARTLI · 3 HAYIR — mekanizma değiştirildi) ·
**A11 ŞARTLI ONAY** (8 ŞARTLI · 2 HAYIR + DB lideri izolasyon vetosu — regex reddedildi) ·
**A12 ONAY** (5 EVET · 5 ŞARTLI, karşı oy yok) · **A13 ŞARTLI ONAY**
(1 EVET · 7 ŞARTLI · 2 HAYIR — birleştirme reddedildi).

- **Dosya:** `yonetim/kurul-kararlari.md` (+375 satır), `yonetim/acik-kararlar.md` (A10–A13 kapandı)
- **Commit:** `830baed8` — push edildi
- **Sonuç:** karar bekleyen madde **SIFIR** (`grep -c "^## 🟡" → 0`)

### 20. Kurul, kendisine sunulan brifingin BEŞ öncülünü çürüttü

Bunlar benim yazdığım cümlelerdi ve dördü kararın **yönünü** değiştirdi.

1. **"Kısıt konursa admin'in iki sistem ekranı kilitlenir" — YANLIŞ.** Beş üye (CTO, backend-lider,
   db-lider, frontend-uzmanı, Şeytan) **bağımsız olarak** aynı yeri ölçtü:
   `PermissionCatalog.cs:565-583`/`:604-613` sistem rollerinin etkin kümesini **açılışta** doğrular
   ve ihlalde `InvalidOperationException` atar. `admin` `phone.unmask` taşımadığı için seed'e
   `requires` konsaydı sonuç *"ekran kilitlenir"* değil, **uygulama hiç açılmaz** olurdu.
   Ayrıca `requires` bir **çalışma anı kapısı değildir** — `PermissionAuthorizationHandler` yalnız
   `IsSatisfiedBy` çağırıyor; `MissingPrerequisites`'in tek çağıranı `CustomRolePolicy.cs:126`.
   **Yani önerdiğim kısıt, koruma değil, dağıtım kuralıydı ve tek etkisi ürünü açılmaz yapmaktı.**
2. **"#63 bu kısıttan etkilenir" — YANLIŞ.** #63'ün ekran yetkisi `telephony.console.read`
   (`screens.generated.ts:88`), `system.command.run` değil. Etkilenen ikili #41 ve #43.
3. **"#63'te hiçbir maskeleme yok" — YANLIŞ.** `AsteriskCommandCatalog.cs:63` `UnmaskPermission`
   tanımlı, `AST-01 core show channels` **zaten** `phone.unmask` istiyor, katalog yetkiye göre
   **filtreli** dönüyor ve `AmiAsteriskConsole.cs:92` ikinci kapıyı çalışma anında koyuyor.
   Dosyanın kendi yorumu A11'de önerdiğim cümlenin aynısını **altı ay önce** yazmış:
   *"çözüm maskeleme DEĞİL, yetkilendirmedir."*
4. **"Katalogda 8 komut var" — YANLIŞ.** AST-01…AST-12 (11 farklı CLI dizesi).
5. **"`/bundle` sözlük gelirse `.join()` ile patlar" — YANLIŞ, ve gerçek daha kötü.**
   Asterisk uzmanı ve Linux uzmanı **bağımsız olarak** aynı zinciri ölçtü: `withheld` sözlük
   gelirse `withheld.length` **`undefined`**, `undefined > 0` **false**, `.join()` **hiç
   çağrılmaz**. İstisna yok, çıkış kodu yok → *"SERVIS EDILMEYEN TURLER"* bandı **kaybolur**,
   `/tmp/pbxtr-withheld-turler` **boş** yazılır, `:551`'deki eksilme kapısının muafiyet listesi
   çöker ve kesilen tür `BEYANSIZ EKSILME → exit 75` ile **yanlış sebeple** kırmızıya döner.
   **Kırılan şey bir ayrıştırıcı değil, toll-fraud kapısının kendi raporudur.**

### 21. Karar konusu OLMAYAN altı gerçek arıza — hepsi ölçümde çıktı

Üyeler karar için ölçüm yaparken kartı olmayan altı kusur buldu. Beşi yeni kart, biri güncelleme:

- **BR-SEC-10 (Şeytan)** — `ProvisioningContentGate` **yalnızca düğüm ucunda** koşuyor.
  `FindUndeliverableKinds`'in tek üretim çağrısı `ProvisioningNodeBundleEndpoints.cs:514`;
  `ProvisioningEndpoints.cs:430` yalnız sır kapısını çağırıyor. Yani **Mod A ile çeken her
  kurulum `#exec` / `#include` direktif kapısından hiç geçmiyor** — o kapının kendi yorumu
  *"#exec KOMUT CALISTIRIR"* diyor. `ProvisioningTenantPrefixGuardTests` o yol için **vacuous**.
- **BR-SEC-11 (süpervizör)** — `.pcap` indirmesi `auditSink.TryEnqueue` ile yazılıyor ve **dönüş
  değeri okunmuyor**; `ChannelAuditSink.cs:31-33` bu kuyruğun ayrıcalıklı eylemlerde
  kullanılmasını **birebir yasaklıyor**. Kodun kendi yorumu *"HER indirme yazilir"* diyor ama
  mekanizma bunu garanti etmiyor. **Kaydın düşme olasılığı en yüksek an, denetimde ona en çok
  ihtiyaç duyulan andır.**
- **BR-SYS-88 (db-lider)** — `CaptureRules.Lifetime = 30 dk` ama `Purge()` **fırsatçı**: yalnız
  `:87`/`:94`/`:162`'den (List/Open/Run) çağrılıyor, zamanlayıcı yok. Kimse ekrana girmezse
  kişisel veri + SIP digest materyali taşıyan pcap **diskte süresiz** kalır. "30 dk'da imha"
  bugün **ölçülmemiş bir iddia**.
- **BR-AST-43 (asterisk-uzmanı)** — `rtp-headers` snaplen 96. Hesap: 14+20+8+12 = 54 → **42 bayt
  payload**. G.711'de %26 parça (iddia tutar) ama **G.729 = 20 B, G.723.1 = 24 B, Opus@8k ≈ 20 B**
  → **payload'ın TAMAMI**. Yani G.729 müzakere edilebilen bir düğümde bu şablon **tam bir çağrı
  kayıt cihazıdır** ve #21'in yetki+denetim zincirini atlar. Üstelik `CaptureEndpoints.cs:90`
  `CarriesAudio: false` **sabit yazılmış** — ekran ölçülmemiş bir güvence veriyor, ve
  `CaptureTemplateTests.Rtp_sablonu_SES_TASIMAZ` **yanlış bir iddiayı koruyor**.
- **BR-QA-34 (linux-uzmanı)** — #43'ün gizlilik güvenliğini taşıyan şey **kod değil ağ kipi**:
  app düz bridge'de, `network_mode: host` yok, `NET_ADMIN` yok, tcpdump `-p`. `sip` şablonu bugün
  **fiilen hiçbir paket yakalamıyor**. Bir gün compose'a `network_mode: host` eklenirse **aynı kod**
  tüm SIP trafiğini müşteri numaralarıyla yakalar ve **tek bir test bile kırılmaz** — koda
  dokunulmadığı için review de yakalamaz.
- **BR-QA-33 (CTO + linux-uzmanı, ben ölçtüm)** — "iki şıktan biri" hâlinden **ölçülmüş** hâle
  çevrildi. Üç gerçek: `AmiAsteriskConsole.cs:91-92` kapıyı **`AsteriskCommandCatalog`'tan**
  kuruyor (yalnız AST-01'de `phone.unmask`); `SystemCommandRunner.cs:93` **aynı ifadeyi**
  **`system-commands.json`'dan** kuruyor (enum'un tamamı için `phone.unmask`); taşımanın kendisi
  (`UnixSocketSystemAgent.cs`) **hiçbir yetki kontrolü taşımıyor** — `Permission` kelimesi dosyada
  **0 kez** geçiyor. **Sonuç sessiz başarısızlık değil, yüzeye göre farklı cevap:** `phone.unmask`
  taşımayan operatör `pjsip show contacts`'ı **#63'ten çalıştırır, #41'den çalıştıramaz.**

## Kararlar

- **Bir kurul brifingi de bir iddia yığınıdır ve ölçülmeden yazılırsa kurulu yanlış soruya
  oylatır.** Bu turda kurul dört kararın ikisinde **benim önerdiğim mekanizmayı reddetti** ve
  gerekçesi her seferinde ölçümdü. Brifing metnini kurula sunmadan önce her teşhis cümlesinin
  ölçülmesi gerekiyor — kartlar için geçerli olan kural karar metinleri için de geçerli.
- **Aynı yeri beş ajanın bağımsız ölçmesi, bir ajanın ölçmesinden farklı bir şey üretiyor.**
  A10'un öncülünü beş üye ayrı ayrı çürüttü; tek bir ajana sorsaydım bir "hayır" oyu olarak
  görünürdü, beşi birden gelince **öncülün kendisi** düştü.
- **"Patlar" ile "sessizce yutar" arasındaki fark, kararın yönünü değiştirebilir.**
  `{}.length === undefined` yüzünden `/bundle` birleştirmesi bir çökme değil, bir **kapının
  sessizce susması** üretiyordu. Gürültülü çökme tercih edilirdi — bu, `grep` exit-1 dersinin
  (bu sabah) JavaScript'teki tam karşılığı.
- **Bağlayıcı genel kural (Ş37-30):** *provisioning yanıtında var olan bir alanın **TİPİ** hiçbir
  zaman değiştirilmez; yeni bilgi **yeni alanla** gelir.* Sahadaki confd sürümleri ölçülemediği
  sürece tek güvenli evrim biçimi budur.

## Açık kalanlar / sonraki adım

- **Karar #37'nin 38 şartı** (`Ş37-1…Ş37-38`) uygulanmadı — kurul kararı planlamaya **kendiliğinden
  geçmez** (skill kuralı). Kullanıcı "başla" demeden kod yazılmayacak.
- **smtp2go** hâlâ kullanıcıda: DNS kayıtları `pbxtr.com` bölgesinde yok, selector sayısı ve
  gerçek API anahtarı bekleniyor.
- **BR-SYS-86** yayın onayı kullanıcıda.
- **Testler hâlâ koşulmadı** — kullanıcının açık talimatı ("testleri sona sakla").

## Bilanço

**299 kart** (+9: BR-QA-33, BR-SEC-10, BR-SEC-11, BR-SYS-88, BR-AST-43, BR-QA-34 bu turda).
**Karar bekleyen açık madde: 0.**

---

# Altıncı tur — 2026-09-07 gece geç

## Bağlam

Kurul turu bitti, karar bekleyen madde sıfıra indi. Kullanıcı tarafındaki üç engel (smtp2go,
BR-SYS-86 onayı, Karar #37'nin uygulanması için "başla") duruyor; onlardan **bağımsız** açık
kartlara dönüldü. Beş kart paralel ajanla açıldı.

## Yapılanlar

### 22. BR-QA-31 — `ProblemCodes` ↔ belge iki yönlü parite bekçisi

- **Neden:** `api-kontrat-v1.md` §1.5.1 bir ara **45** kod sayarken kod **96** taşıyordu; fark **51**
  ve hiçbir kapı uyarmadı. Belge elle eşitlendi ama **aynı şekilde tekrar ayrışır**.
- **Ne yapıldı:** `tests/Pbxtr.Architecture.Tests/ProblemCodeCatalogDocParityTests.cs` — üç test.
  Kod tarafı **yansımayla** türetiliyor (metin taraması değil), böylece çok satırlı/boşluklu tanım
  biçimi değişse de kaçırmaz. Vacuity tabanı **90** (96 değil): iki tarafta birden yapılan **meşru
  silme** bekçiyi kilitlememeli, kilitlenmesi gereken şey ayrıştırıcının çökmesidir — biçim
  bozulmasında çıkan tipik sayılar (0/5/8/13) 90'ın çok altında kalır.
- **Ölçüm:** belge 96, kod 96, fark **0**. Yani bekçi bir kusuru değil **bayatlamayı** önlüyor.
- **İki yön de ölçülüyor.** Tek yön ölçen bekçi bugün bulunan kusurun tersini kaçırırdı — bu hatayı
  bu depoda bugün bir kez yaptık (BR-SYS-71).

### 23. BR-QA-32 — MAIL uyarı şeridi hiç ölçülmüyordu

- **Öncül üçünde de doğru çıktı.** `MailSettingsPane.test.tsx` `warnings` alanına hiç bakmıyordu;
  `MailWarningDto.Message` daraltmasının **hiçbir testi kırmamasının** sebebi buydu.
- **Bilinmeyen kod davranışı DEĞİŞTİRİLMEDİ.** Ölçüldü ve **bilinçli, yazılı gerekçeli** çıktı:
  ekranın kendi yorumu *"sözlük KAPALI KÜME DEĞİLDİR; bilinmeyeni atmak uyarının kendisini yok
  ederdi — sunucu 'bu ayarla mail GİTMEZ' derken ekran boş bir şerit çizerdi"* diyor.
- Yedi test (221→369 satır). Boş-liste ve alan-yok dalları **bilerek ayrı test**: tek test içinde
  ikinci fikstür hiç fetch edilmezdi (aynı root'a ikinci render **remount değildir**) ve dal
  **hiç koşmadan** ölçülmüş sayılırdı.
- 9 dil ölçümü **temiz** (36/36).

### 24. BR-BE-110 — hedef=aktör kapısı, ölçülmüş DAR kısıtla

- **Öncül doğru:** `LiveEndpoints.cs`'in 913 satırının tamamı okundu; `userId` ile
  `tenantContext.UserId` hiçbir yerde karşılaştırılmıyordu, dosyada `403` hiç geçmiyordu ve
  diğer katmanlarda da yoktu.
- **Kaba kısıt konulmadı ve daraltma ölçüldü:** `add_to_queue` → **403**, çünkü agent'ın kendi ucu
  bu eylemi kapalı kümesinin dışında **bilerek** bırakıyor (*"kuyruk üyeliği kadro kararıdır"*) ve
  buradan kendini hedeflemek tam olarak o kuralı atlamak. `pause`/`end_break` → **serbest**, çünkü
  ürün **başka bir yüzeyde açıkça** izin veriyor; kaba kısıt meşru bir akışı sessizce kilitlerdi.
- **Kapının YERİ de bir karar:** kadro sorgusundan ve gövde doğrulamalarından **önce**. Sonraya
  bırakılsaydı boş `queueId` ile gelen bir kendini-hedefleme 400 alır ve **denetime hiç yazılmazdı**.
- **Özel rol ayağı ölçüldü, P düşmedi:** `live.agent.act` katalogda `sensitive` değil,
  `nonDelegable` değil, ön koşulsuz → bir owner `CustomRolePolicy`'nin **beş kapısının hiçbirine
  takılmadan** bu yetkiyi bir agent'a atayabilir.

### 25. BR-AST-41 / BR-AST-42 — iki sözleşme sapması: doğru, ama gerekçeleri çürük

Her iki kartın **iddiası doğru**, **"sessiz bedel" gerekçesi yanlış** çıktı:

- **41:** *"istemci bunu okumasaydı"* senaryosu **yaşanmıyor** — `dugum.sh:762-768` üç alanı da
  diske yazıyor ve `:974-983` kuyruk kaybı kapısının **muafiyetini** oradan okuyor. Bugünkü bedel
  **sıfır**; **P düştü**. Sapma tek belgeye özeldi (`asterisk-provisioning.md` şemayı zaten yazıyordu).
- **42:** *"göndermeyen istemci"* **yok** — iki betik de gönderiyor; `selftest.sh:855`'teki
  "GONDERILMEZ" bir **negatif test senaryosu**, gerçek istemci değil. **Gerçek risk başka yerde:**
  değer **yerel defterden** türüyor ve **defter yoksa başlık boş gidiyor** — ilk tur, temiz kurulum
  ve `/var/lib` kaybı hâllerinde sonuç gönderilmemiş hâlle **birebir aynı**. Ayrıca `removedBasis`
  üç değil **dört** değerli; önceki revizyon hiç yoksa `first_revision` olur, yani kartın
  *"alt sınıra düşer"* cümlesi **ilk üretimde geçerli değil**.
- Belge koda uyduruldu (kod değişmedi): §2.1.1 ve §2.6 yeni; §2.2/2.3/2.4/3/4.2/4.3/4.4/5.3/6.1
  güncellendi. §6.1'e güvenlik notu: **`X-Pbxtr-Have` bir tenant SEÇİCİ hâline getirilmemelidir** —
  o an bir kimlik iddiasına dönüşür.

### 26. BR-BE-109 — medya ucu, düğümdeki DİĞER tenantların medyasını 404 döndürüyordu

- **Öncül doğru ve sorun hipotetik değil.** Uç `BeginTenantScope(outcome.TenantId)` ile **anahtarın
  kendi** tenant'ına kapsanıyordu; bir düğüme birden çok tenant pinlenebildiği için
  (`ux_api_keys_tenant_node`) anahtarın tenant'ı düğümün tenant kümesinin **öz alt kümesiydi**.
- **İstemci bu ucu fiilen çağırıyor** (`dugum.sh:1110-1127`, tüm tenantlar için aynı anahtarla) ve
  betik arızayı **zaten adıyla yazmıştı**: *"Bu bir ağ hatası değil, SÖZLEŞME BOŞLUĞUDUR."*
  Etki *"bir anons eksik"* değildi: §4.3/2d gereği **o tenant'ın revizyonu hiç aktif edilmiyordu**.
- **İkinci yol icat edilmedi:** `/provisioning/report`'un zaten kullandığı desen birebir kopyalandı
  → pinli anahtarda küme `ListTenantsForNodeAsync`, yani `/node-bundle` ile **aynı tek kaynak**.
  Pinsiz (Mod A) dalda **tek satır bile değişmedi**.
- **Neden izolasyon genişlemedi:** küme aynı anahtarın aynı turda `/node-bundle` ile **zaten aldığı**
  küme; küme **istekten değil sunucudan** geliyor; yalnız `IsNodePinned` dalında ve `revoked_at`
  dolu anahtar keşifte görünmüyor; okuma hâlâ tenant başına RLS + query filter altında.
- **Keşif patlarsa daraltır** (`members = []`) + `LogCritical` — 500 dönmek Mod A'yı da durdururdu;
  **daraltma da kapamadır**.
- Üç negatif test, **üçü de önce ÖNCÜLÜ ölçüyor** (yoksa 404 *"dosya zaten yok"* demek olur ve test
  vacuous kalırdı); tenant başına **farklı baytlar** kullanıldı.
- **Ben de iki şey düzelttim:** sözleşme §4.3/2d + §4.4 (404'ün anlamı **daraldı**), ve
  `dugum.sh`'teki *"BILINEN SUNUCU SINIRI"* uyarı bloğu — **benim değişikliğim onu yanlış bilgi
  hâline getirdi** ve yanlış kalan bir uyarı sonraki operatörü gerçek sebepten uzağa gönderirdi.

## Kararlar

- **Bir kartın iddiası doğru olabilir, gerekçesi yanlış olabilir — ve bu ikisi ayrı ayrı ölçülür.**
  Bu turda iki kart (BR-AST-41/42) tam olarak bu şekilde kapandı: sapma gerçekti, "bedeli" hayaliydi.
  Gerekçeyi ölçmeden kapatsaydık P seviyesi yanlış kalırdı.
- **Kaba kısıt, meşru akışı sessizce öldürür.** BR-BE-110'da doğru cevap "aktör kendini hiçbir
  eylemle hedefleyemez" değil, tek eyleme bağlı bir kısıttı — ve bunun gerekçesi ürünün **başka bir
  yüzeyinde yazılı** duruyordu.
- **Bir kapının YERİ, varlığı kadar önemlidir.** Gövde doğrulamasından sonra konan bir yetki kapısı,
  reddi denetime **hiç yazdırmayabilir**.
- **Bir şeyi düzelttiğinde, onun hakkındaki yazıları da bayatlatırsın.** BR-BE-109 düzeltmesi bir
  betik uyarısını yanlış hâle getirdi; aynı sınıftan ikinci bir bayat blok da bulundu (BR-AST-44).

## Kendi hatalarım

1. **`node -e` içine backtick'li Türkçe metin koydum** — bash yuttu ve betik sözdizimi hatası verdi.
   Defterde yazılı bir ders (`heredoc-icinde-backtick-yutulur`); bu turda **bir kez daha** yaşandı.
   Çözüm aynı: betiği Write ile dosyaya yaz.
2. **Kart metnine düz `|` koydum** (`401|403`) ve markdown hücresini böldüm — BR-AST-41'de yaptığım
   hatanın aynısı. Kolon sayımıyla yakalandı ve düzeltildi.
3. **`git status --short --cached`** diye olmayan bir bayrak kullandım; `&&` zinciri koptu ve commit
   sessizce hiç koşmadı. `git log` ile fark edildi.

## Yanlış alarmlar (değişiklik YAPILMADI)

- **backlog'da 159 satırda hücre içi düz `|` var.** Çıkarıcı bunların **158'ini doğru okuyor** —
  indeksle değil uçlardan ayrıştırıyor. Sapma sandığım `BR-BE-59 "P1/P2"` de yanlış alarm:
  `oncelikEsle` `/P1/` ile eşliyor, panoya **P1** gidiyor. Çalışan bir ayrıştırıcıyı "düzeltmek"
  onu bozacaktı. *(Bu, bugün üçüncü kez: aracın çıktısı beklenmedikse önce aracın kodunu oku.)*
- **backlog 299 satır ama 296 benzersiz kod** — üç kod iki kez geçiyor (`BR-SYS-45`, `BR-BE-47`,
  `BR-BE-53`), hepsi **kasıtlı mezar taşı** (*"Yerini satır N aldı"*). Çıkarıcı **sonuncuyu** tutuyor,
  yani üçünde de **doğru satır** panoya gidiyor.
- **ClickUp senkronu dört kartta fark üretmedi** (`BR-QA-31`, `BR-AST-41/42`, `BR-BE-109`) — pano o
  dörtte **defterden öndeydi**, backlog bugün yetişti.

## Açık kalanlar / sonraki adım

- **Karar #37'nin 38 şartı uygulanmadı** — kurul kararı planlamaya kendiliğinden geçmez (skill
  kuralı). `/sprint-planla pbxtr` + "başla" gerekiyor.
- **smtp2go** kullanıcıda: DNS kayıtları `pbxtr.com` bölgesinde yok, selector ve gerçek API anahtarı
  bekleniyor.
- **BR-SYS-86** yayın onayı kullanıcıda.
- **Testler hâlâ koşulmadı** — kullanıcının açık talimatı.

## Bilanço

**300 kart — 192 bitti, 8 karar alındı (planlanmayı bekliyor), 1 kapandı/red, 11 yarım, 88 açık.**
(Bu turda +9 bitti, +6 yeni kart. ClickUp senkronu **fark 0** ile yakınsadı.)

---

# Yedinci ve sekizinci tur — 2026-09-07 gece yarısı sonrası

## Bağlam

Kurul kapandı, karar bekleyen madde sıfır. Kullanıcı tarafındaki üç engel (smtp2go, BR-SYS-86,
Karar #37'nin uygulanması için "başla") duruyor. Onlardan bağımsız açık kartlarla iki tur daha.

## En önemli bulgu: SONDA YAPACAĞIMIZ BÜYÜK TEST KOŞUSU YALAN SÖYLEYEBİLİR

BR-QA-24 turunda çıktı; **iddialarının hepsini kendim doğruladım.**

- **Api shard'ları ve Integration.Tests tazelik kapısına bağlı değil.** `test-kos.sh` DLL tazeliğini
  `PBXTR_TESTKOS_MIN_EPOCH` ile ölçüyor ve değişken `yerel-yayin.sh:256`'da **zaten export edilmiş** —
  ama kapıya bağlı olan yalnız **iki** koşu var (`:301`, `:316`). Shard döngüsü (`:430`) ve
  Integration (`:351`) **ham `dotnet test --no-build`** ile gidiyor.
- **Kimlik kapısı bunu kurtarmıyor.** `yerel-yayin.sh:418-424` yorumu kimlik kapısının
  `test-kos.sh`'tan *"DAHA GÜÇLÜ"* olduğunu söylüyor; **iddia yanlış**: beklenen kimlik listesi de
  `--no-build` ile **aynı DLL'den** üretiliyor. Derleme sessizce atlanırsa (MSB3027 / "locked by")
  liste de koşu da **aynı eski ikiliyi** tarif eder, kimlikler **birebir tutar**, dört shard da
  **yeşil yanar**. Mutasyon, silinmiş test, ters çevrilmiş assert — hiçbiri görünmez.
- **Bugünkü hâl zaten bozuk:** `shard-0.trx` 4 Eylül, `shard-1/2/3.trx` **2 Eylül** — dördü **aynı
  koşudan bile değil**. O tarihten beri **132 test .cs dosyası** değişti.
- **En sert sayı:** kaynakta **3223** test var, son ölçülen listede **2629** metod → **594 test hiç
  ölçülmemiş.**
- **Ortam hazır değil:** `python3` **yok**, Docker daemon **kapalı**. `yerel-yayin.sh` `:306`'daki ilk
  `python3` çağrısında ölür. Integration'ın 673 testinin **480'i** `RequiresDockerFact`: Docker yoksa
  elle koşu **sessizce atlar, exit 0 döner**.

**Bayatlamayan bir taban bulundu ve gerçek veriyle doğrulandı:** kaynak dosyalardaki `[Fact]/[Theory]`
öznitelik sayısı, `--list-tests` **metod** sayısına **birebir eşit** (`1d60d234`: 2629 == 2629). Yani
beklenen sayı depoda tutulan bir listeden değil, **her koşuda kaynaktan** türetilebilir — elle liste
tutulmadığı için **bayatlayamaz**. Kural fail-closed yönde `liste_metod >= kaynak_öznitelik`.

Ajan **kod yazmadı ve bu doğru karardı**: python3 yok, Docker kapalı, dotnet yasak → yazacağı hiçbir
kapıyı **koşturamazdı**. *"Koşmayan kapı bulgu değildir."*

Kartlar: **BR-QA-36 (P1)**, **BR-QA-37**, **BR-QA-38**, **BR-SYS-89 (P1)**.

## Diğer kapanan kartlar

### BR-BE-108 — SMS: `ProviderUnavailable` DÖRT hali topluyordu

Öncül doğru ama eksik. Kartın görmediği: `00` **(KABUL)** döndü ama `bulkid` **yok** dalı da aynı
kovadaydı — yani mesajın **neredeyse kesin gittiği** dal *"hiç olmadı"* diye kaydediliyordu; devre-açık
(süreçten hiç çıkmadı) aynı kovaya **ters yönden** düşüyordu. Üç dal ayrıldı, **Ş1-2 genişletilmedi**
(*"reddedilen"* ≠ zaman aşımı). İki sınıflandırma kararı ölçülmüş gerekçeli: devre-açık (a)'ya kondu
(yoksa her breaker açılışı yığın sahte satır üretirdi), `HttpRequestException` (b)'ye kondu çünkü .NET
"connection refused" ile soket sıfırlamasını ayırt edemiyor ve **bedeller asimetrik** — fazladan satır
bir soru sordurur, **eksik satır o soruyu sonsuza kadar engeller**.

`IAuditSink` **seçilmedi**, üç ölçümle: kota/faturalama `segments` toplamından okunuyor ve denetim
satırı o toplama **görünmez**; `audit_log` **append-only** oysa belirsizliğin **kapatılabilir** olması
gerek; `ChannelAuditSink` sınırlı bellek içi kanal — *"gitmiş olabilir"* tam da sürecin öldüğü anda
lazım. `sent` durumunu yeniden kullanmak reddedildi: **aynı eksik ölçümden doğan zıt iddia**.
Migration yeri seçilmedi, **zorlandı** (terminal bekçi sonuncu olmalı); yalnız şema dosyasını
düzenlemek kurulu DB'leri eski `CHECK` ile bırakır ve **mesaj gittikten sonra** patlardı.

### BR-BE-42 — itme etkisi SİSTEM tenant'ına yazılıyordu

Kartın *"`BeginTenantScope` açmıyor"* iddiası yanlıştı — ikisi de açıyor, **başka bir bacak için**.
Gözden kaçan **sağlayıcı bacağıydı**. `MembershipRow` `tenant_id`'yi **hiç taşımıyordu**: itme
aşamasında *"bu satır kimin"* sorusunun cevabı **kodda yoktu**. İki işe **ayrı karar**:
`LeaveEnforcementJob` düzeltildi; `TrunkHealthSnapshotJob`'a **dokunulmadı** çünkü sonda **tek turdur**,
atfedilecek tenant başına çağrı **yoktur** ve satırın parmak izi `count:N` — satır **hiçbir tenant'ın
verisini taşımıyor**. *Sonda platformun, sonuç tenant'ın.* Test **üç tenant**la yazıldı; iki yetmiyor,
sistem tenant'ı üçüncü olmazsa "yanlış yer" ile "doğru yer" ayrışamaz.

### BR-SYS-43 — mezar taşının "silme" yarısı ölçümle geçersiz

Silme **bilerek yok**: lab'da ölçülmüş (boş dosya + reload bağlamı **düşürüyor**, dosyaya dokunmadan
reload **düşürmüyor**) ve `rm` fiili atomik yazım/rollback desenlerine oturmuyor. Üç gerçek boşluk
bulundu: **yokluk doğrulaması yoktu** (`removed-kinds` **yazılıyor ama hiç okunmuyordu** — ölü meta
dosyası; üstelik `cek.sh` onu yalnız **muafiyet** olarak okuduğu için **beyanla birlikte doğrulama da
düşüyordu**); **bekleyen çağrı yanlış eksendeydi** (düğüm geneli kanal eşiği ölçülüyordu, kuyruk başına
**hiç** — 5 kanallı sessiz bir santralde eşik aşılmaz ve kuyruk **yine boşaltılırdı**); **yabancı dosya
koruması vacuous doğruydu** (hiçbir şey silinmediği için, ama **üzerine yazmak silmek kadar yıkıcı**).
Katalog **genişletilmedi**. Selftest 74→**104 iddia**, 24 fikstür / 13 mutasyon; **ben de koşturdum**,
13/13 yakalandı.

### BR-DB-16 — bu iki turun TEK tutan öncülü

Canlıda tam 63 karakter **3 ad**, 63'ü aşan **0**; `42704` riski bugün gerçekten yok. Kartın
**söylemediği** kırılganlık: `tenant_ledger_entries` adı zaten **geri kırpılmış**; aynı 62 karakterlik
öneki paylaşan ikinci bir FK doğarsa EF `~1` üretir, ad **sessizce değişir** ve **42704 o gün doğar**.
Bekçi genişletmesi bugün **3 ihlal** üretir → zinciri kilitler, yani **regresyon**; kart sırayı doğru
yazmış. Taslak yazıldı, `Migrations/` altına **konmadı** (rename tek başına **bugün var olmayan**
hatayı üretirdi + terminal migration testini kırardı).

## Kendi hatalarım (bu iki turda üç tane, ikisi aynı sınıf)

1. **Kart durumunu YANLIŞ SÜTUNA yazdım — ve yanlış-sıfırı kendi hikâyemle örttüm.** Tablo altı
   sütunlu (`… | Durum | Şart`); ben durumu `p[p.length-2]` ile adresledim, yani **Şart** hücresine.
   Dokuz satırda Ş-referansı **ezildi** ve durum "Bekliyor" kaldı → **dokuz bitmiş kart panoda açık
   duruyordu**. ClickUp senkronu *"fark: 0"* dedi, ben bunu *"pano defterden önde"* diye yorumladım ve
   **kullanıcıya da öyle söyledim**. Uzaktan tek tek okuyunca ortaya çıktı. Onarıldı (Şart değerleri
   oturum öncesi commit'ten geri alındı) ve **`kapi_41`** ile kilitlendi — üç ölçüm: pozitif yeşil,
   hatamın aynısı kırmızı, vacuity kırmızı.
2. **Kart metnine düz `|` yazdım, üç kez.** `401|403`, `(pjsip|queues|…)` — markdown hücresini bölüyor.
   Üçüncüsünde satır 10 kolona çıktı. Kolon sayımıyla yakalandı.
3. **`node -e` içine backtick'li Türkçe metin koydum, yine.** Bash yuttu. Defterde yazılı ders; çözüm
   aynı: betiği Write ile dosyaya yaz.

## Kararlar

- **Bir kapıyı yanlış yerden koşturmak, kapının yanlış olduğunu göstermez.** `kapi_41`'i scratchpad'den
  koşturunca yanlış kökü taradı — betik kökü `$0`'dan türetiyor. Defterdeki `kapi_27` dersinin aynısı;
  runner **depo içinde** koşturulmalı.
- **Bir şeyi düzeltince onun hakkındaki yazılar bayatlar.** Bu iki turda üç kez: `dugum.sh`'in
  "BILINEN SUNUCU SINIRI" bloğu, `CrossTenantScopeSurfaces.cs`'in gerekçesi, `kapi_38`'in etiketi.
  Ajanlar dokunma yasağı yüzünden ikisini bırakıp **raporladı** — doğru davranış.
- **Ajanın "kod yazmadım" demesi bazen doğru cevaptır.** BR-QA-24'te ortam (python3/Docker) olmadığı
  için yazılacak kapı koşturulamazdı; yazsaydı kapatmaya çalıştığı hata sınıfının kendisini üretirdi.

## Açık kalanlar / sonraki adım

- **BR-SYS-89 kullanıcı adımı olabilir:** büyük koşu için **python3 mu kurulacak, Docker daemon mı
  ayağa kaldırılacak?** İkisinden biri olmadan koşu hiç başlamaz.
- **BR-QA-36 (P1)** kapanmadan yapılacak büyük koşunun sonucu **güvenilir değildir**.
- smtp2go, BR-SYS-86 ve Karar #37'nin uygulanması kullanıcıda.
- **Testler hâlâ koşulmadı** (confd selftest hariç — o `dotnet` gerektirmiyor).

## Bilanço

**308 kart — 206 bitti, 8 karar alındı, 1 kapandı/red, 11 yarım, 82 açık.**
(Bu iki turda **+14 bitti, +12 yeni kart**. ClickUp senkronu fark 0 ile yakınsadı.)
