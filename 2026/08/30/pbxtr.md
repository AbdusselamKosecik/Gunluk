# pbxtr — 2026-08-30

## Bağlam

Dün gece i18n taramasının ortasında kullanıcı iki yeni istek verdi ve öncelik
onlara geçti:

1. Telefon üst bara taşınsın; agent ve süpervizör her ekrandan erişsin,
   konuşurken başka ekrana geçmek çağrıyı düşürmesin.
2. Panelden bir çağrı gönderilebilsin; Asterisk'te bir kuyruk açılsın ve çağrı
   o kuyruğa bağlansın.

Gün bu ikisiyle geçti. i18n taraması **yarım kaldı** (aşağıda "Açık kalanlar").

## Yapılanlar

### 1. Yazılım telefonu uygulama kabuğuna taşındı

- **Neden:** `useSoftphone()` `AgentDeskScreen` içinde çağrılıyordu; yani SIP
  kaydı bir EKRANIN yaşam döngüsüne bağlıydı. Agent masadan çıkıp CDR'a ya da
  cari kartına geçtiği anda bileşen unmount oluyor, `unregister()` gidiyor ve
  **konuşulan çağrı düşüyordu.** Belirti "ekran değiştirince çağrı kesiliyor" idi.
- **Ne yapıldı:**
  - `SoftphoneProvider` (yeni): kanca kabukta **bir kez** çağrılır; uzak sesin
    bağlı olduğu `<audio>` de kabukta durur. İkinci bir `useSoftphone()` aynı
    AOR ile ikinci bir contact doğurur ve gelen çağrı iki kez çalardı.
  - `HeaderSoftphone` (yeni): üst bardaki yüzey — durum rozeti, dahili, Aç /
    Kapat ve tuş takımı. `loading`/`disabled` halinde **hiçbir şey çizilmez**
    (masa telefonu kullanan agent'a "telefonunuz bağlı değil" demek, bozuk
    olmayan bir şeyi arıza gibi göstermek olurdu).
  - Tuş takımı SIP.js `call()` **çağırmaz**; `POST /api/v1/agent/calls`
    üzerinden gider — kara liste / İYS / arama saati / deneme limiti zinciri
    sunucuda koşmaya devam eder (CLAUDE.md §5). `202` "santral aldı" demektir,
    "karşı taraf açtı" demez; o yüzden yerel bir "görüşme" fazı üretilmez.
  - `SoftphoneBadge` artık kancayı değil bağlamı okur; kabuk dışında `null`.
  - 7 yeni `softphone.*` anahtarı 9 dile eklendi.
- **Dokunulan dosyalar:** `src/Pbxtr.Web/src/app/shell/SoftphoneProvider.tsx`,
  `.../shell/HeaderSoftphone.tsx`, `.../shell/HeaderSoftphone.module.css`,
  `.../shell/AppShell.tsx`, `.../shell/AppHeader.tsx`,
  `.../screens/agent/SoftphoneBadge.tsx`, `.../i18n/messages/*.json`
- **Sonuç / doğrulama:** `npx tsc -b --noEmit` temiz, `npm run build` başarılı,
  staging'e yayınlandı.
- **Commit:** `15a6a13a` — feat(softphone): telefon ust bara tasindi

### 2. Örnek veri seed'i yazılım telefonu kimliğini EZİYORDU (gerçek kusur)

- **Neden:** Yayından sonra staging'de dokuz dahilinin dokuzunda da
  `webrtc_secret_cipher IS NULL` ölçüldü. Sebep: `SampleDataSeeder` içindeki
  `UpsertByIdAsync`, mevcut satıra `CurrentValues.SetValues(row)` uyguluyordu.
  `SetValues` **seçici değildir** — şablondaki tüm alanları yazar. Yazılım
  telefonu kimliğinin üç kolonu şablonda yoktur (çalışma zamanında
  `POST /users/extensions/{id}/webrtc` ile üretilir), dolayısıyla **her
  `seed-sample` koşusu, yani her yayın**, üretilmiş kimlikleri null'a eziyordu.
- **Belirti neydi:** "Yeni sürümde telefon yok." `GET /me/softphone` "tanımlı
  değil" dönüyor, rozet ve tuş takımı hiç çizilmiyordu. Bir telefon arızası
  gibi görünüyordu; oysa sebep örnek verinin sırrı silmesiydi.
- **Ne yapıldı:** `UpsertByIdAsync` isteğe bağlı bir `preserve` listesi alır;
  korunan alanların mevcut değeri `SetValues` sonrasında geri yazılır.
- **Dokunulan dosyalar:**
  `src/Pbxtr.Infrastructure/Persistence/Seeding/SampleDataSeeder.cs`
- **Doğrulama (mutasyon değil, gerçek koşu):** düzeltme yayınlandıktan sonra
  sunucuda seed tekrar koşturuldu; altı dahilinin kimliği **hayatta kaldı**
  (düzeltmeden önce hepsi `f` idi).

  ```bash
  ssh root@176.88.41.220 'cd /home/vuo/pbxtr-demo && docker compose run --rm migrate seed-sample'
  docker exec pbxtr-postgres psql -U postgres -d pbxtr -Atc \
    "select number, (webrtc_secret_cipher is not null) from extensions order by number;"
  ```
- **Commit:** `f8d9ad4c` — fix(seed): ornek veri yazilim telefonu kimligini ezmiyor

### 3. Altı dahiliye kimlik teslimi + kuyruk üyeliği

- **Neden:** Kuyruk (`t0007-satis`) zaten vardı ve çağrı alıyordu, ama üyeleri
  laboratuvarın Local kanallarıydı — yani çağrı **tarayıcıda çalmıyordu.**
  Ayrıca yalnızca 1042'nin PJSIP nesnesi vardı (elle yazılmıştı).
- **Ne yapıldı:** `deploy/demo-softphone-provision.sh` yazıldı. Panelden her
  dahili için kimlik üretir, **dosya başına bir dahili** yazar,
  `module reload res_pjsip.so` ile yükler, nesnenin gerçekten oluştuğunu
  **kapı olarak** doğrular, sonra 1042/1043'ü kuyruğa üye ekler. Sır hiçbir
  adımda stdout'a, loga veya hata satırına yazılmaz.
- **Ölçülen üç şey (betiğe gerekçe olarak işlendi):**
  1. **Mükerrer nesne tüm yüklemeyi düşürür.** Eski elle yazılmış
     `t0007-softphone.conf` de `t0007-wrtc-1042` nesnesini tanımlıyordu;
     Asterisk `pjsip.conf` dosyasının TAMAMINI reddetti ve yeni yazılan altı
     dahilinin hiçbiri yüklenmedi. `module reload` yine de
     **"reloaded successfully"** dedi — hata yalnızca konteyner logundaydı.
     CLAUDE.md §3.1'deki "tek dosyadaki hata tüm PJSIP yüklemesini etkiler"
     riskinin gerçekleşmiş hâli.
  2. **Uygulama portu dışarıya açık değil.** Host'tan `127.0.0.1:8080` denemek
     `http=000` verir ("uygulama ölü" gibi görünür, oysa yol yanlıştır);
     istekler nginx konteynerinden `pbxtr-app:5080` adresine atılır.
  3. **Laboratuvar statik üyeleri panelin önüne geçer.** `queues.conf`
     içindeki iki `member =>` satırı statiktir — `queue remove member` ve
     `queue pause member` ikisi de reddedilir ("Not there" / "Unable to
     pause") — ve o Local kanallar çağrıyı otomatik açar. `leastrecent`
     stratejisi hiç çağrı almamış lab üyesini her zaman önce seçer; onlar
     durdukça panelde telefon **hiç çalmaz** ve sebep hiçbir yerde görünmez.
     Satırlar silinmedi, yorumlandı (yedek:
     `/etc/asterisk/queues.conf.panel-oncesi`).
- **Doğrulama:** altı endpoint `pjsip show endpoints` çıktısında yüklü;
  kuyrukta yalnızca `Softphone-1042` ve `Softphone-1043` var; test originate'i
  kuyruğa girdi ve bekledi
  (`Callers: 1. Local/s@pbxtr-t0007-caller-00000002;2 (wait: 0:03)`).
  Tarayıcı kaydolduğunda o çağrı panelde çalar.
- **Commit:** feat(demo): tum dahililere WebRTC kimligi + kuyruk uyeligi teslimi

## Kararlar

- Panelden arama **her zaman sunucudan** başlar (`POST /agent/calls`). Tuş
  takımının SIP.js `call()` çağırması, kara liste/İYS/saat/limit zincirini
  atlamak demekti; bu bir hız tercihi değil, güvenlik sınırıdır.
- Telefon `loading`/`disabled` iken hiçbir şey çizilmez; "pasif düğme"
  bırakılmaz — basıldığında hiçbir şey yapmayan düğme kullanıcıya arıza gibi
  görünür.
- Kuyruk üyeliği config'e değil **çalışma zamanına** yazılır: `t0007-satis`
  lab `queues.conf` dosyasında tanımlıdır, ikinci bir tanım dosyası aynı
  kuyruğu iki yerden tarif eder ve hangisinin kazandığı yükleme sırasına
  kalırdı.

## Açık kalanlar / sonraki adım

- **GÜVENLİK — kullanıcıya bildirildi:** dünkü oturumda `pbxtr-app`
  konteynerinin ortam değişkenleri `env` ile dökülüp maskelenmeye çalışıldı.
  Maske **büyük/küçük harfe duyarlıydı** ve `AmiSecret=` / `AriPassword=`
  ile eşleşmedi; staging AMI secret'ı ve ARI parolası oturum dökümüne basıldı.
  Depoya girmedi. **Döndürülmesi kullanıcının kararına bırakıldı.**
- **i18n taraması yarım.** Biten gruplar: agent, live, console, shared, authz,
  dashboard, wallboard, network, qa, security (+ kalıntı turu). Kalan: system
  (13 dosya), tenant (8), settings (6), ivr (7), telephony (5), analytics (4),
  campaigns (4), users (6), automation (2), resultcodes (3), me (2), reports,
  media, workinghours (3), data (3), storage (3), queues (3), survey (2),
  compliance, trunks (3, kısmen), cdr, license, support (3), speech, dialer.
  Ayrıca `src/ui` tasarım sistemi katmanı ve ~26 yerdeki sabit `tr-TR`
  tarih/sayı biçimlendirmesi (merkezî bir değişiklik, metin turundan sonra).
- **`pbxtr-confd` hâlâ yok.** PJSIP teslimi elle yapılıyor
  (`deploy/demo-softphone-provision.sh`); üretimde bu confd'nin işidir.
- Bu tur **kapı/test koşturulmadan** yayınlandı (kullanıcı talimatı).

---

## Ek tur — i18n: ayarlar, bayi, tenant, auth (aynı gün, sonraki oturum)

### Bağlam

Hedefin 1. maddesi (`Tüm sayfaları dilden geçir`) sürüyor. Tur başında
`tara2.mjs src` ölçümü: **199 dosya, 49'u şüpheli.** Bu turda 12 dosya kapandı.

### Yapılanlar

#### 1. #49 Ayarlar ekranı (SettingsScreen 1756 satır + settingsApi + localeCatalog)
- **Neden:** kalan en büyük dosya; dokuz panel, sekmeler, kota/tenant sütunu ve
  `HostPanel` tamamen Türkçe sabitti.
- **Ne yapıldı:** 102 katalog anahtarı (`set.*`), tüm paneller `t()` / `<T>`
  üzerinden. Modül sabitleri `NUMBER_REQUIRED` / `DAILY_LIMIT_MALFORMED`
  katalog anahtarlarına taşındı (modül seviyesinde hook çağrılamaz).
- **İki yapısal düzeltme:**
  - **Ülke adları artık aktif dilde.** `localeCatalog.ts` sabit
    `Intl.DisplayNames(['tr'])` kullanıyordu: Almanca seçen kullanıcı ekranın
    geri kalanını Almanca, ülke listesini **Türkçe** görüyordu. Sıralama da
    sabit `'tr'` ile yapılıyordu — Bulgarca listede kiril harfleri Türkçe
    alfabeye göre sıralanıyordu. `countryLabel(locale, code)` /
    `countryOptions(locale, current)` imzaya `locale` aldı.
  - **Yüzde işareti katalogdan** (`ph.percent`): işaretin yeri dile bağlıdır
    (tr `%50`, en `50%`); SLA eşiği `%{deger}` diye sabit yazılıydı.
- **Commit:** `a0d14e92`

#### 2. #57 Konuşma analizi
Önceki turdan yarım kalan dosya tamamlandı. `linkedid` / `recording_assets`
teknik kimliktir, çevrilmez. **Commit:** `cd98f1a1`

#### 3. #56 Bayi paneli + bayi aç/düzenle
- 60 anahtar (`dlr.*`). `PERIOD_LABELS` → `PERIOD_KEY`,
  `QUOTA_KIND_LABEL` → `QUOTA_KIND_KEY`.
- `Quota` ve `DaysLeft` bileşen olduğu için kendi `useT`'sini alır;
  `periodLabel` / `quotaHint` / `belowUsageMessage` bileşen değildir, `t`'yi
  **ilk parametre** olarak alır (proje kuralı).
- **Commit:** `e584a9e1`

#### 4. #53 Tenant yönetimi (5 dosya)
- 161 anahtar (`tnt.*`). TenantScreen (874), TenantCreateDialog (504),
  TenantEditDialog (362), TenantDocumentsScreen (323), TenantWizardFields.
- **`WizardField.label` → `labelKey: MessageKey`.** Alan listesi **modül
  seviyesinde** duruyor; orada `useT()` çağrılamaz. Aynı liste üç ekranda
  kullanıldığı için (sihirbaz, tenant düzenleme, ayarlar/firma paneli) tek
  değişiklik üçünü birden düzeltti; `TenantProfilePane` çağrı yeri de
  güncellendi.
- Sihirbazın lisans periyodu tablosu bayi ekranının `dlr.period*`
  anahtarlarını **paylaşır** — aynı listeyi ikinci kez çevirmek, iki ekranın
  bir gün aynı koda iki farklı ad vermesi demekti.
- Sunucudan gelen `kindTitle` **çevrilmez** (kaynak sunucudur).
- **Commit:** `e83e117d`

#### 5. Giriş / şifremi unuttum + DİL SEÇİCİ GİRİŞ EKRANINA
- **Neden (gerçek kusur):** dil seçici yalnızca kabuktaki üst bardaydı, yani
  **ancak giriş yaptıktan sonra** erişilebiliyordu. Tarayıcısı Türkçe olan ama
  panelini Almanca isteyen kullanıcı, dilini değiştirmek için önce
  anlamadığı bir dilde giriş yapmak zorundaydı; şifresini unutmuş biri için
  akışın tamamı erişilemez bir dilde kalıyordu.
- `AuthLayout`'a `<LanguagePicker>` eklendi (kendi CSS sınıflarıyla; picker'ın
  tüm className prop'ları opsiyonel). Tercih `localStorage`'a yazıldığı için
  seçilen dil girişten sonra da geçerli.
- **Commit:** `9899d191`

#### 6. İki düşen test onarıldı — turun bulgusu
`src/app/primaryUserActionHttp.test.tsx` ve
`src/app/screens/deliveryManifest.test.tsx` ekranları çıplak
`render` ile çiziyordu. Ekranlar dile geçtikçe (DiagnosticsScreen dahil)
sağlayıcısız `useT()` çağrısı **"I18nProvider dışında çağrıldı"** diye
atıyordu. İkisi de **kök seviyesinde** durduğu için dizin bazlı koşularda
görünmüyordu — tur boyunca `vitest run <dizin>` çalıştırıldığı için haftalarca
sessiz kalabilirdi. Ortak `renderScreen` yardımcısına geçirildi.

### Komutlar

```bash
cd src/Pbxtr.Web
node <scratch>/ekle.mjs <scratch>/veri-*.mjs   # 9 dilin hepsi dolu değilse ATAR
node <scratch>/ed-*.mjs                        # idempotent metin düzenleme
npx tsc -b --noEmit
npx vitest run <dizin>
node <scratch>/tara2.mjs <dizin>
```

### Sonuç / doğrulama

- `tsc -b --noEmit` temiz.
- **Tam koşu: 142 dosya / 1267 test yeşil** (dizin bazlı değil, tamamı).
- `tara2` her kapatılan grupta `şüpheli: 0`.

### Kararlar

- **Modül seviyesindeki her etiket tablosu anahtar tutar, metin tutmaz.**
  Sebep teknik: hook modül seviyesinde çağrılamaz. Sonuç mimari: metin, onu
  çizen bileşende çözülür ve tek kaynak katalogdur.
- **Bileşen olmayan yardımcı `t`'yi ilk parametre alır.** İkinci bir kural
  (ör. "yardımcı kendi katalogunu okusun") aktif dili yardımcıya taşımanın
  ikinci bir yolunu açardı.
- **Sunucudan gelen Türkçe (`*Tr`, `kindTitle`, `reason`) istemcide
  çevrilmez.** Kaynak sunucudur; istemcide çevirmek iki doğruluk kaynağı
  yaratırdı.
- **Tanınmayan sunucu kodu HAM basılır** (`periodLabel`, `kindLabel`): eksik
  çeviri kendini söyler, `—` ile gizlenmez.

### Açık kalanlar / sonraki adım

- **i18n: 37 dosya kaldı.** ivr (7), `src/ui` (7), dashboards (4), live (3),
  console (2), security (2), analytics (2), ve tek tek: qa, authz, compliance,
  network, resultcodes, storage, survey, trunks, realtime/StaleDataBadge,
  agent/CallTab, AppRoutes.
- **`src/ui` ayrı bir iştir:** katman kuralı gereği (`mirrorSingleSource.test.ts`)
  `src/ui`, `src/app`'e bağımlı olamaz — `useT` oraya ithal edilemez. Kendi
  metin sözleşmesi gerekiyor (`src/ui` içinde Türkçe varsayılanlı bir `UiText`
  sağlayıcı, katalogdan `src/app` tarafından doldurulur).
- **Rusça (`ru`) 10. dil olarak sıraya alındı** — sayfalar bitince. Şimdi
  eklemek her yeni sayfayı iki dilde birden yazdırırdı.
- **`I18nProvider`'ın `profileLocale` / `onLocaleChange` prop'ları BAĞLANMADI.**
  `App.tsx` sağlayıcıyı prop'suz kuruyor ve sunucu tarafında kullanıcı diline
  ait bir alan **yok** (`me` içinde `locale` bulunamadı). Yani "başka bir
  makineden girince dilini yeniden seçme" yolu yazılmış ama ucu yok; kapanması
  bir sunucu alanı ister.
- Sabit `tr-TR` tarih/sayı biçimlendirmesi (~26 yer) hâlâ duruyor; metin turu
  bitince merkezî tek değişiklik.

---

## Ek tur 2 — ivr, kalıntı, `src/ui` + **ölçüm düzeltmesi**

### Yapılanlar

#### 7. #26 IVR akış tasarımı (7 dosya) — commit `685b220c`
113 anahtar. Üç etiket tablosu anahtara döndü (`IVR_NODE_TYPE_LABEL`,
`IVR_FLOW_STATUS_LABEL`, `publishViolationText`'in switch'i). `IvrT` tipi
`ivrApi`den dışa açıldı; bileşen olmayan dört yardımcı `t`'yi ilk parametre
alır. Lisans periyodu tablosu bayi ekranının `dlr.period*` anahtarlarını
**paylaşır**. SurveyScreen aynı tabloyu kullanıyordu; tek kaynak korundu.

**Bir test biçimlendirmeyi yakaladı:** karakter sayısı `t()`'den geçince
Türkçede binlik ayıracıyla `1.201` yazılıyor. Bu **doğrudur** (miktar, PID gibi
kimlik değil); beklenti katalogdan üretilecek şekilde düzeltildi.

#### 8. Kalıntı üç metin — commit `d7322d3e`
- `AppRoutes` açılış ekranı ("Oturum hazırlanıyor…").
- `StaleDataBadge` — 16 çağrı yeri `subject`'i **zaten** katalogdan geçiriyordu;
  cümlenin gövdesi Türkçe sabitti. Yetki listesini birleştiren `" veya "` de
  anahtar oldu: bağlaç dile bağlıdır.
- `ApiKeysScreen` — dört kural etiketinden üçü katalogdan geliyordu,
  `rotasyon` atlanmıştı.

#### 9. `src/ui` — kendi metin sözleşmesiyle — commit `4eb436a1`
`src/ui` katman kuralı gereği `src/app`'e bağımlı olamaz, yani `useT()`
çağıramaz. Kural delinip `useT` ithal edilseydi bedel görünmez olurdu: `useT`
`I18nProvider` dışında **atar** — kütüphaneyi sağlayıcısız çizen bir yer
(vitrin, birim testi, ileride bir hata sınır bileşeni) o gün ekranı komple
düşürürdü.

Çözüm: kütüphane **kendi** sözleşmesini taşır (`ui/text/UiTextProvider`),
sağlayıcısız Türkçe varsayılanla doğru çalışır; uygulama katmanı
`app/i18n/AppUiText` köprüsüyle katalogdan doldurur. Bağımlılık oku tek yönlü
kalır.

`TreeView`'ın üç prop varsayılanı (`recentLabel`, `emptyText`,
`truncatedHint`) da sözleşmeye taşındı: imzada Türkçe sabitlerdi ve prop
geçmeyen çağrı yeri (CallTab) — `truncatedHint` agent ekranında derinlik sınırı
yüzünden **gerçekten çizilir** — ekranın geri kalanı çevrilmişken Türkçe
gösterirdi.

**Kapı:** `appUiText.test.tsx` — (1) sağlayıcısız Türkçe varsayılan, (2)
sağlayıcıyla Almanca katalog değeri, (3) ikisinin **farklı** olması (aksi halde
2. şart vacuous olurdu), (4) köprünün `App` kökünde `I18nProvider` **içinde**
bağlı olduğu. İki mutasyonla doğrulandı (anahtarı kaldır; köprüyü ağaçtan
çıkar) — ikisi de kırmızı verdi.

### ÖLÇÜM DÜZELTMESİ — tarayıcı eksik sayıyordu

Turun sonunda **ikinci ve bağımsız bir tarama** yazıldı (`son-tara.mjs`:
yorum blokları ve katalog dışında kalan, Türkçeye özgü harf taşıyan her satır).

`tara2.mjs` **biçim tabanlıydı** — JSX metni ve belirli nitelikleri arıyordu.
Bu yüzden **hiç bakmadığı** bir sınıf vardı: `*Api.ts` / `*Errors.ts`
modüllerindeki **kullanıcıya görünen hata ve bilgi metinleri**.

- `tara2` → "32 dosya şüpheli, çoğu yanlış pozitif, iş bitti".
- `son-tara` → **46 dosyada 329 satır**; yanlış pozitifler (üretilmiş
  `screens.generated.ts` başlıkları, `locales.ts` içindeki dil adları,
  `UiTextProvider`'ın kasıtlı Türkçe varsayılanları, satır sonu yorumları)
  düşülünce **~240 gerçek satır.**

Yani "sayfalar bitti" doğru, **"ürün 9 dilde" değil**: sayfaların görünen
kabuğu çevrildi, **mesaj/hata katmanı çevrilmedi.**

En büyükleri: `console/parkErrors.ts` (49), `agent/callControlErrors.ts` (24),
`live/monitorErrors.ts` (23), `live/interventionErrors.ts` (22),
`api/problem.ts` (19), `users/usersApi.ts` (16), `ui/CallTimeline` (13),
`sim/RewindControl` (9), `agent/missedCall.ts` (9).

### Sonraki adım — üç tur olarak planlandı

- **A. `api/problem.ts` + ona bağlı 11 API modülü.** `problemMessage(error)`
  97 çağrı yerinde kullanılıyor; imzaya `t` eklenecek. Ölçüldü: çağrı
  yerlerinin yalnızca **11 dosyası** `t` taşımıyor ve o 11'in çoğu (usersApi,
  objectionApi, auditApi, recordingApi, resourceState, settingsApi) **zaten**
  kendi Türkçe metnini taşıdığı için nasılsa dokunulacak — kaskad kapanıyor.
- **B. Dört hata modülü** (park / çağrı kontrolü / dinleme / müdahale). Çağrı
  yerleri az (2-4) ve hepsi `t` taşıyan bileşen ya da kanca; kaskad küçük.
- **C. Kuyruk:** `CallTimeline`, `RewindControl`, `missedCall`,
  `RealtimeProvider` kopma sebepleri, `licenseRestriction`,
  `useUnsavedChangesGuard`, `SlaRing`/`SidebarNav`/`Lightbox` prop
  varsayılanları, `shared/` yardımcıları.

### Doğrulama

`tsc -b` temiz; **tam koşu 143 dosya / 1270 test yeşil** (dizin bazlı değil).

---

## Ek tur 3 — hata katmanı (A turu)

### 10. `api/problem.ts` + 18 hata yardımcısı — commit `d94d9814`

**Neden en önce burası:** `problemMessage` **her ekranda** görünen metni
üretir — kimlik doğrulama, kota, kilit, doğrulama, yetki ve genel ret
cümleleri. Tamamı Türkçe sabitti.

- `problemMessage(error)` → `problemMessage(t, error)`.
- **Ölçüm kaskadı kapattı:** 97 çağrı yeri / 53 dosya; bunlardan yalnızca
  **18'i** `t` taşımayan API modülüydü ve o modüllerin `*ErrorText`
  yardımcılarına da `t` **ilk parametre** olarak eklendi. Kaskad daha ileri
  gitmedi.
- Tip artık tek yerde: **`TranslateFn`** (`i18n/I18nProvider`). Her dosyanın
  kendi `ReturnType<typeof useT>` takma adını yazması, imzaların bir gün
  ayrışması demekti (`IvrT` bu şekilde doğmuştu).

**İki yan düzeltme:**

1. **Hesap kilidi saati sabit `tr-TR` ile biçimleniyordu.** Almanca bir panelde
   cümlenin gerisi çevrilirken içindeki saat Türkçe biçimde basılıyordu. Etiket
   artık `I18nProvider`'ın `<html lang>` üzerine yazdığı BCP-47 değerinden
   okunur; sağlayıcı koşmamışsa tarayıcının kendi dili kullanılır — sabit bir
   dil **değil**.
2. `QUOTA_KIND_LABEL` → `QUOTA_KIND_KEY`; kapalı küme (`Record<QuotaKind, …>`)
   korundu, eksik üye tsc'yi durdurur.

**İki test gerçek bir şey yakaladı:**
- `WallboardDesignScreen` testi `t` yerine `((key) => key)` saplaması
  geçiyordu. Katalogtan konuşmaya başlayınca saplama ham anahtarı döndürdü ve
  test ortak metnin **üretildiğini** artık ölçmüyordu. Gerçek katalogla
  değiştirildi.
- `RedialStrip` testi ASCII'ye düşmüş bir yazımı arıyordu ("ulasilamadi");
  katalogtaki doğru yazımla ("ulaşılamadı") eşleşmedi. Beklenti artık
  katalogtan üretiliyor.

### 11. #02 kullanıcı red gerekçeleri — commit `6e29dbc9`

`RULE_TEXT` → `RULE_KEY` (17 gerekçe). Bunlar sunucunun `meta.rule` kapalı
kümesinin ekran karşılığıdır ve 403'leri birbirinden ayırır. Tanınmayan gerekçe
yine genel metne düşer.

### Ölçüm

`son-tara`: **329 → 310 satır.** `problem.ts` temizlendi ve asıl kazanç
görünmeyen kısımda: 18 API modülü artık `t` taşıyor, yani kendi metinleri
**ikinci bir imza değişikliği olmadan** çevrilebilir.

### Kalan (ölçülmüş, yanlış pozitifler düşülmüş)

- **Dört hata modülü — 118 satır:** `console/parkErrors.ts` (49),
  `agent/callControlErrors.ts` (24), `live/monitorErrors.ts` (23),
  `live/interventionErrors.ts` (22). Uzun, çok cümleli metinler; her biri
  "ne oldu + ne yapmalı" yazım kuralına uyuyor ve dokuz dile bu kuralla
  çevrilmeli.
- **Küçük API/yardımcı kuyruğu — ~62 satır:** objectionApi (7),
  complianceApi (7), resourceState (6), apiKeysApi (6), auditApi (5),
  recordingApi (5), slaWindow (5), RealtimeProvider (5), useCallControl (3),
  cdrApi (2), breakAllowance (2), licenseRestriction (2), settingsApi (2),
  contact/updatesApi/systemCommandApi/extensionsApi/useUnsavedChangesGuard (1'er).
- **Bileşen kuyruğu — ~34 satır:** `ui/CallTimeline` (13),
  `sim/RewindControl` (9), `agent/missedCall.ts` (9), `AuditScreen` (2),
  `WorkingHoursScreen` (1).
- **Yanlış pozitifler (dokunulmayacak):** `screens.generated.ts` (üretilmiş
  `titleTr` başlıkları + geliştiriciye atılan `Error` metinleri),
  `i18n/locales.ts` (dillerin kendi adları), `UiTextProvider` (kasıtlı Türkçe
  varsayılanlar), `agent/CallTab.tsx` (sunucuya giden etiket **değerleri**).

---

## Ek tur 4 — hata katmanı A/B/C tamamlandı

### 12. Küçük API/yardımcı kuyruğu — commit `c979043f`

12 modül (itiraz aç/kapat, İYS senkron cümlesi, üç ayrı kutu metni, API
anahtarı ölçüm metinleri, denetim temizliği, kayıt dinleme, CDR kayıt ucu, SLA
pencere/gün görünümü, çağrı kontrolü emir kayıtları, ayar kaydetme, cari
eşleşmesi, dahili yönlendirme). 45 anahtar × 9 dil.

**GERÇEK KUSUR — `resourceState.ts`.** Ekrana özel yedek cümle **yalnızca
Türkçede** görünüyordu. Dal, `problemMessage`'in genel cümlesini **sabit Türkçe
metinle** karşılaştırıyordu:

```ts
return message === 'İşlem tamamlanamadı. Lütfen tekrar deneyin.' ? fallback : message;
```

`problem.ts` katalogtan konuşmaya başlayınca (tur 3) bu eşitlik Almanca/Arapça
panelde **hiç tutmuyor**; "Cari havuzu okunamadı." gibi ekrana özel cümle
sessizce düşüyordu. Yani bir tur önce yapılan doğru iş, bir sonraki dosyada
sessiz bir kusur üretmişti. Karşılaştırma artık `t('prb.generic')`.

İkinci bulgu: `slaDailyView` ölçülemedi hâlinde `SLA_NOT_MEASURED_LABEL`
(src/ui'daki sabit Türkçe prop varsayılanı) okuyordu.

### 13. Dört hata modülü — commit `8b2cbd86`

park (#16, 49 satır), çağrı kontrolü (24), dinleme (#28, 23), müdahale (22).
54 anahtar × 9 dil.

- **Yazım kuralı çeviriye taşındı:** "TEKRAR DENEMEYİN" uyarıları
  (`TELEPHONY_INDETERMINATE`, `LIVE_EVENT_REJECTED`, `SPY_TENANT_MISMATCH`)
  her dilde aynı kesinlikte durdu. Bu bir biçim tercihi değil — o cümlelerin
  tek işi **ikinci kez uygulanacak bir müdahaleyi önlemek**.
- **Slot adı taşıyan üç ret iki ayrı anahtarla** çevrildi, tek anahtar + boş
  yer tutucu değil: "tut3 DOLU" ile "Seçtiğiniz slot dolu" aynı cümlenin iki
  hâli değildir.
- Kapalı küme tipleri korundu; C# bekçisinin (`LiveFailureMessageSurfaces`)
  regex okuyucusu kör kalmadı (anahtarlar düz harf dizisi, tip ifadesinde `=` yok).

> **Not:** o C# bekçisini çağıran hiçbir `[Fact]` yok — dosyanın kendi
> başlığında yazılı (FE-67, 2026-08-17). Yani kapı **koşmuyor**. Bu turda
> kapsam dışı bırakıldı, açık kalem olarak duruyor.

### 14. Son kuyruk + `src/ui` prop varsayılanları — commit `fd79e15c`

53 anahtar × 9 dil. Uygulama tarafı: kaydedilmemiş değişiklik uyarısı,
WebSocket iptal sebepleri, kaçan çağrı şeridi, mola hakkı a11y cümlesi, komut
çıktısı kırpma satırı, damgalanmamış sürüm, çalışma saatleri, lisans kısıtı,
sunum kumandası.

`src/ui` tarafında prop varsayılanlarındaki Türkçe dizeler **metin
sözleşmesine** taşındı (`UiTextProvider`) ve `AppUiText` köprüsünden katalogtan
doluyor. Katman kuralı delinmedi: `src/ui` hâlâ `src/app`'i tanımıyor ve
sağlayıcısız Türkçe varsayılanla tek başına çalışıyor.

**İki yeni kapı** — ikisi de mutasyonla doğrulandı:

1. **Sözleşmenin her alanı köprüde doldurulmalı.** `Partial<UiText>` eksik
   alanı **susarak** geçirir; sonuç o metnin bütün dillerde Türkçe görünmesidir
   ve bunu hiçbir davranış testi görmez. Alan listesi sözleşme kaynağından
   okunup köprüde aranıyor. (`sidebarLabel` silindi → kırmızı.)
2. **Çizelge adım başlıkları katalogdan gelmeli.** 16 üyeli tek nesnede bir
   üyenin unutulması yalnızca **o satırı** Türkçe bırakırdı. (`hangup`
   sabitlendi → kırmızı.)

### Ölçüm

`son-tara`: **310 → 244 → 126 → 93 satır.** Kalan 93 satırın **tamamı
bilinçli**: üretilmiş `screens.generated.ts` (46), dillerin kendi adları (2),
`UiTextProvider`'ın kasıtlı Türkçe varsayılanları (~30), sunucuya giden etiket
**değerleri** (2) ve geliştiriciye atılan `Error` metinleri (7) + Türkçe kod
yorumları. **Ekranlarda çevrilmemiş kullanıcı metni kalmadı.**

Her turda: `npx tsc -b --noEmit` temiz, tam koşu **1272 test / 143 dosya yeşil**.

## Sonraki adım

- **Rusça (`ru`) 10. dil** — kullanıcı istedi, metinler bittiği için artık
  sırası geldi.
- **~25 sabit `tr-TR` tarih/sayı biçimleme yeri** — `problem.ts` ve
  `localeCatalog.ts`'te ikisi düzeltildi; geri kalanı tek turda merkezî olarak.
- **`LiveFailureMessageSurfaces` bekçisini koşturan bir `[Fact]` yok** —
  koşmayan kapı, kapı değildir.

---

## Ek tur 5 — hedefin 2/3/4 maddeleri: doğrulama + bulunan boşluk

Stop kancası "yalnızca 1. madde yapıldı" dedi. Kanca önceki oturumları
göremiyor; iddia etmek yerine **depoda ölçtüm.**

### Madde 3 — kuyruk/dahili aramalarında İYS ve kontroller

**Uygulanmış.** `src/Pbxtr.Api/Modules/Telephony/CallPermissionEndpoints.cs:245`
— "SANTRAL İÇİ HEDEF MUAFİYETİ (kullanıcı kararı, **2026-08-30**)". Zincir
`UnresolvableNumber` ile döndüğünde ve hedef bir dahili ise karar `Allow`'a
çevriliyor. Muafiyet **ikinci kapıda da** (dialplan yolu) var; olmasaydı agent
panelden 1043'ü arayabilir ama SIP telefonundan aynı dahiliyi çevirdiğinde
fail-closed reddedilirdi — ve bu fark hiçbir ekranda görünmezdi.

**Sıra da karar:** zincir ÖNCE koşar, muafiyet SONRA ve yalnızca çözülemeyen
numarada sorulur; böylece sıcak yola (dialplan her aramada burayı çağırır) ek
sorgu eklenmiyor.

### Madde 2 — Asterisk entegrasyonu

**Yazılmış** (CLAUDE.md §3.0 gereği kablonun ucu hariç):
`Infrastructure/Telephony/Asterisk/` altında `AmiConnection`,
`AmiCommandChannel`, `AmiEventMapper`, `AmiAriEventConsumer`, `AriClient`,
`AriStasisApp`, `AsteriskAriProvider`, `AriLinkStatus`, `AmiTenantCodeMap`.
Sınıf B uçlarının hepsi `Program.cs`'te kayıtlı (894-897) + provisioning (922).
`deploy/asterisk-lab`, `pbxtr-confd-cek.sh`, `telefon-kanali-kontrol.sh` yerinde.

### Madde 4 — teknik test → **GERÇEK BOŞLUK BULUNDU**

`GET /api/v1/me/tech-check` yazılmıştı, `Program.cs:807`'de kayıtlıydı, istemci
(`TechTestPanel.tsx`) onu çağırıyordu — **ama hiçbir sunucu testi koşmuyordu.**
Bu tam olarak "kod var, koşan yok" deseni.

Altı test yazıldı (`tests/.../Telephony/TechCheckEndpointTests.cs`, commit
`8a836529`):

- kimliksiz istek 401,
- bağlantı açıkken üç bileşen de ölçülür, **sıra** korunur,
- **KOPUK (`false` → down) ile ÖLÇÜLEMEDİ (`null` → unknown) ayrı hâllerdir**,
- Redis erişilemezken uç 500 vermez; bileşen `down` olur, diğerleri ölçülmeye
  devam eder,
- uç sağlayıcıya **hiç dokunmaz** (bağlantı durumu istek başına tek kez okunur).

Üçüncü madde bu ucun varlık sebebi: ikisi tek renge düşseydi Asterisk'e fiilen
bağlanmayan bir kurulum her açılışta **sahte bir kırmızı** üretirdi.

**Mutasyonla doğrulandı** (ikisi de ikili yeniden derlenerek — `dotnet build`
ayrı çalıştırıldı, test koşusunun build'i sessizce atlaması ihtimaline karşı):

| Mutasyon | Sonuç |
|---|---|
| `null => Unknown` yerine `Down` | `Kopuk_ile_olculemedi_ayri_hallerdir` **KIRMIZI** |
| istisna yutulmayıp yukarı bırakılınca | `Onbellek_erisilemezken_panel_ayakta_kalir` **KIRMIZI** |

Geri alındıktan sonra kaynak byte-aynı (`git diff` boş) ve 6/6 yeşil.

### Karar

"Yazıldı" ile "çalışıyor" farkını yalnızca koşan bir kapı kapatır. 2. ve 3.
maddeler ölçüldü ve yerinde; 4. maddede uç yerindeydi ama **ölçümü yoktu** —
eksik olan buydu ve kapatıldı.
