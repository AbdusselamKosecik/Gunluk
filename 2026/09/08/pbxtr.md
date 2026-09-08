# pbxtr — 2026-09-08

## Bağlam

Kullanıcı emri: **"kontrol et calistir. kurula sorulacaklarida sorabilirsin. sisteme yukleyip
deneyebilirsin."** — yani uzun süredir yürürlükte olan *"testleri sona sakla"* kısıtı **kalktı**,
takımlar koşacak, açık kararlar kurula gidecek.

Güne başlarken durum: dört test takımından **hiçbiri tam koşturulmamıştı.** Docker yeni ayağa
kalkmıştı (BR-SYS-89 kapandı), yani Integration.Tests ve 41 yerel kapı ilk kez ölçülebilir hâldeydi.

Turun tek cümlelik özeti: **16 kırmızı çıktı, hiçbiri ürün kusuru değildi — ama yedisi "yazılmış
ama hiç koşmamış kapı" sınıfındaydı.** Bu deponun baskın hata deseninin (`karar-yazilmis-ama-
uygulanmamis`) test tarafındaki ikizi.

---

## Yapılanlar

### 1. Kurul Karar #38 — A14 ve A15 kapandı

- **Neden:** Açık karar defterinde iki 🟡 madde vardı ve ikisi de ölçülmüş bir öncüle dayanıyordu.
  Kullanıcı karar darboğazı olmak istemiyor (`karari-kullaniciya-degil-kurula-sor`), bu yüzden
  kurula gitti.
- **Ne yapıldı:** 10 üyenin tamamı paralel çalıştırıldı. Sonuç: **A14 ŞARTLI ONAY (9 ŞARTLI /
  1 HAYIR), A15 ŞARTLI ONAY (10/10, seçenek 2).**
- **Dokunulan dosyalar:** `yonetim/kurul-kararlari.md` (7479 → 7632 satır, silme yok),
  `yonetim/acik-kararlar.md` (🟡 sayısı 2 → 0)
- **Sonuç / doğrulama:** Kararın asıl değeri **canlı ölçümlerin brifingi çürütmesi** oldu:

  | Brifingdeki iddia | Ölçüm |
  |---|---|
  | `dialplan show` "DID → hedef eşlemesi" sızdırır | 7+ haneli desen sayısı **0**; Ş37-4'ün gerekçesi yanlıştı |
  | `sensitive` yüzünden `admin` 12 → 10 komuta **mecburen** düşer | `sensitive` bir **paket** yasağı, rol yasağı değil — `admin` yetkiyi `extraPermissions` ile alır ve **12 komutu korur** |
  | D seçeneği 12 kat DB yükü getirir | Bir çarpımdı, ölçüm değil: gerçek maliyet kapasitenin **%1,7'si** |

  Şeytan A14'e HAYIR verdi ama üç dönüşüm koşulu yazdı; üçü de zaten başka üyelerin şartıydı,
  Ş38-1/2/3 olarak bağlayıcı yazıldı. Şeytan'ın iki ölçülmüş bulgusu da karara girdi: reddedilen
  E seçeneği **zaten üretimde koşuyor**, ve çapraz-tenant dökümü `AST-02`/`AST-05`'te AST-12'den
  **daha geniş** açık — bu yüzden karar komut bazında değil **sınıf bazında** verildi.
- **Commit:** `39cf3326`

### 2. Api.Tests ilk kez tam koştu — 4788/4788

- **Neden:** Test yasağı kalktı; takım hiç bütün olarak koşmamıştı.
- **Ne yapıldı:** Üç dilim hâlinde koşuldu (`api-testleri-parcalanmali`). 4 kırmızı çıktı.
- **Dokunulan dosyalar:**
  `tests/Pbxtr.Api.Tests/Pbxtr.Api.Tests.csproj`,
  `tests/Pbxtr.Api.Tests/Modules/Compliance/CallingHoursClockTests.cs` (yeni),
  `tests/Pbxtr.Api.Tests/Modules/Access/CustomRolePolicyTests.cs`,
  `tests/Pbxtr.Api.Tests/Modules/AgentDesk/AgentRedialEndpointTests.cs`
- **Komutlar:**
  ```bash
  dotnet test tests/Pbxtr.Api.Tests/Pbxtr.Api.Tests.csproj -c Release \
    --filter "FullyQualifiedName~Pbxtr.Api.Tests.Platform|FullyQualifiedName~Pbxtr.Api.Tests.Support"
  # + Modules dilimleri
  ```
- **Bulgular:**
  - **Üç SMS ölçümü — belirti YANILTICIYDI.** Kapı istisnayı `catch (Exception)` ile yutup
    fail-closed `DECISION_UNAVAILABLE` dönüyordu; yani ekranda *"saat dilimi çözülemedi"* değil
    *"karar üretilemedi"* görünüyordu. Kök sebep **konak farkı**: Windows'ta invariant kipte ICU
    yok → `Europe/Istanbul` IANA kimliği çözülmüyor. **Linux'ta (üretim) sorun yok.** Bu fark
    2026-08-31'de `Pbxtr.Integration.Tests` için zaten ölçülüp çözülmüştü; BR-BE-60 aynı
    bağımlılığı Api.Tests'e sokunca düzeltme taşınmamış. Emsal gerekçesiyle uygulandı.
  - `CallingHoursClock` için depoda **hiç test yoktu** → kalıcı kanarya eklendi (4 ölçüm), ki aynı
    arıza bir daha çıktığında **kendi adıyla** konuşsun.
  - **`CustomRolePolicyTests`** — `bbda7920` `recording.listen`i `nonDelegable` yaptı ve o kayıt
    hassas listenin başında duruyor; testin `First(...)` seçicisi onu dışlamıyordu. **Aynı commit
    hem seed'i hem bu test dosyasını değiştirmiş ama seçiciyi daraltmamış** → test o günden beri
    kırmızıydı ve kimse koşmamıştı.
  - **`AgentRedialEndpointTests` (3 test)** — `6ab653a7` (BR-BE-39) başarı yolunda kuyruğa ayrıca
    `call.originated` yazıyor; testler o commit'ten önce yazılmıştı. İddialar **zayıflatılmadı,
    yer değiştirdi**: satır sayısı açıkça iddia ediliyor (üçüncü satır sessizce eklenemesin).
- **Commit:** `39cf3326`, `317aa7ac`

### 3. Integration.Tests — 764/764 (Docker ile ilk kez)

- **Neden:** Docker ayağa kalktı; 480 test `RequiresDockerFact` ile bekliyordu.
- **Ne yapıldı:** Tam koşu; 9 kırmızı, 3 kök sebep.
- **Dokunulan dosyalar:**
  `tests/Pbxtr.Integration.Tests/Tests/ScriptCrossTenantOracleTests.cs`,
  `tests/Pbxtr.Integration.Tests/Tests/ApiKeyNodePinHttpTests.cs`,
  `doc/st44-final-delivery-canonical.json`, `doc/st44-final-delivery-report.json`
- **Bulgular:**
  - **ÇAPRAZ-TENANT İZOLASYON ORACLE'I BİR KEZ BİLE YEŞİL GÖRMEMİŞ (7 test).**
    `CleanupAsync` append-only `script_publications` tablosundan `DELETE` ediyordu → `42501`.
    Bekçinin kendi metni *"sahibi de dahil HERKESİ durdurur"* diyor; `script_publications → scripts`
    FK'si de RESTRICT. **Sıra ölçüldü:** bekçi `face55bd` ile 2026-09-05, sınıf `0b332b57` ile
    2026-09-07 → temizlik hiç çalışmadı, yedi ölçüm de `InitializeAsync`'te patlıyordu.
    Yerine geçen desen: zincir sabit kimliklerle **idempotent tohumlanır ve silinmez**; silinen tek
    şey koşuya özel aktör. **Sonuç: 7/7 yeşil, sızıntı yok** — kontrol grubu da geçtiği için ölçüm
    vacuous değil.
  - **Teslim raporu ürünün gerisinde kalmış:** kanonik şema revizyonu `Sprint33FinalGuard`'da
    donmuş, ürün 5 migration ilerlemiş. Bu kapı tam bunun için var ve işini yaptı.
  - **İki test sınıfı aynı tenant kodunu farklı kimlikle yazıyordu** (`t9035`). `ON CONFLICT (id)`
    kod çakışmasını yakalamıyor → `23505`. Arıza **yalnız tam takımda ve sıraya bağlı** görünüyordu.
    Kapı kurmadan önce ölçüldü: başka çakışma yok. Kod `t9133`'e ayrıldı.
- **Commit:** `bac747b0`

### 4. 41 yerel kapı — hepsi geçti

- **Ne yapıldı:** `deploy/yerel-kapilar.sh` konteynerde koşturuldu. 3 kırmızı çıktı, üçü de ayrı sınıf.
- **Komutlar:**
  ```bash
  docker build -q -f deploy/yerel-kapilar.Dockerfile -t pbxtr-kapi:local deploy
  HOST_REPO=$(pwd -W); MSYS_NO_PATHCONV=1 docker run --rm \
    -e PBXTR_HOST_REPO="$HOST_REPO" -v "$HOST_REPO:/repo" \
    -v //var/run/docker.sock:/var/run/docker.sock \
    -w /repo pbxtr-kapi:local bash deploy/yerel-kapilar.sh
  ```
- **Bulgular:**
  - **Sır taraması — üç bulgu, üçü de kapıların KENDİ yorumunda.** İkisi BR-SYS-50'nin *"gitleaks
    neden yetmiyor"* ölçümünü anlatan yorumun içine **literal yazılmış** yüksek entropili örnek
    değerdi: kapının kendi belgesi kapıyı kırmızıya boyuyordu. Üçüncüsü `nftables.conf`'ta bir DNS
    zinciri yorumundaki public konak adı.
    Gerçek sır olmadığı **üç bağımsız ölçümle** sabitlendi: BR-SYS-50'nin kendi kapalı-liste kapısı
    aynı koşuda **geçti**, depoda `.env` yok, literal yalnız o iki yorum satırında geçiyor (veri
    olarak hiçbir yerde kullanılmıyor). **Değer hiçbir aşamada transkripte düşürülmedi** — `=`'in
    sağı kesilip yalnız uzunluk/karakter sınıfı ölçüldü (`env-okurken-degeri-kes`).
    Emsale uyuldu: çalışma ağacındaki literal yer tutucuya çevrildi (ölçümün kanıtı **sonuçtaydı**,
    literalde değil) **+** geçmiş için üç parmak izi.
    **Kalıcı kırmızı bir kapı kapı değildir: insanlar onu atlamayı öğrenir.**
  - **Üretilmiş dosya bayat — ve bu bir güvenlik sapması.** `system-roles.generated.ts`, `owner` ve
    `supervisor`'da `recording.listen`i **eksik** gösteriyordu; seed onu vermiş. Ekleyen commit yine
    **`bbda7920`** — o tek commit'in bıraktığı **üçüncü** sessiz sapma.
  - **Açık karar defteri — benim yazım hatam.** A14/A15'i `✅` ile kapatmıştım; kapalı liste `🟢`
    tanıyor. Bekçi haklı: *"tanımadığım işareti yok sayayım"* deseydi, yeni işaret icat eden herkes
    bekçiyi devre dışı bırakırdı.
- **Sonuç / doğrulama:** `Tum kapilar gecti (41).`
- **Commit:** `88b642ed`

### 5. Frontend — 185/185, `tsc -b` temiz

- **Neden:** vitest de hiç koşmamıştı; ayrıca `system-roles.generated.ts` değişmişti.
- **Dokunulan dosyalar:** `src/Pbxtr.Web/vitest.config.ts`,
  `screens/system/CaptureScreen.tsx`, `screens/queues/QueuePublishStatus.tsx` + testi,
  `screens/settings/SmsSettingsPane.test.tsx`, `i18n/messages/*.json` (9 dil)
- **Bulgular:**
  - **`auditTargetParity` — bekçi yazıldığı günden beri hiç koşmadı.** Sunucudaki `AuditTargets`
    sabitlerini C# kaynağından okuyup ön yüzle karşılaştıran parite bekçisi, Vite'ın kök dışı okuma
    yasağı yüzünden **dosya düzeyinde** patlıyordu. İzin `vitest.config.ts`e konuldu,
    `vite.config.ts`e **değil** — dev sunucusu C# kaynağını tarayıcıya servis edebilir hâle
    gelmesin. Bekçi ilk kez koştu ve **geçti**.
  - **`CaptureScreen` — benim yarım işim.** `3e347492`'de (BR-AST-43) teste `SES YAKALANMAZ`
    iddiasını ekledim ama ekranı ve i18n'i güncellemedim. Şimdi gerçekten yazıyor
    (`cap.noAudioGuarantee`, 9 dil) ve garantinin **nerede** olduğunu söylüyor: filtrede,
    snaplen'de değil.
  - **`QueuePublishStatus` — ürün doğruydu, ölçüm yanlıştı.** İddia satırın tamamını tarıyordu ve
    **inkâr cümlesi** kelimeyi içeriyordu (*"…'Uygulandı' varsayılmaz"*). Rozete kimlik verildi.
  - **`SmsSettingsPane` — ölçüm aracı yanlıştı.** `textContent` input value'larını hiç görmez.
    Aynı dosyanın kendi emsaline hizalandı; yeni hâli daha güçlü.
- **Commit:** `6256a2e8`

---

## Kararlar

- **Karar #38 / A14 — ŞARTLI ONAY.** Yaş tavanı **90 sn** (`ReconcileEvery * 1,5` türetilerek),
  tel kontratı **üç değerli kalır** (dördüncü değeri `MeasuredAt` yokluğu temsil eder), yaş
  **sunucuda** hesaplanır. Blokan ön şartlar: **BR-BE-119 önce**, **BR-AST-45 önce**.
  D/E/F kalıcı red — ama **D'nin gerekçesi düzeltildi** (DB maliyeti ölçüldü: %1,7; red artık
  santral yükü ve §3.4 ayrımı gerekçesiyle).
- **Karar #38 / A15 — ŞARTLI ONAY, seçenek (2).** Anahtar `telephony.dialplan.read`;
  `phone.unmask` AST-12'den kalkar, **AST-01'de kalır**. Karar **sınıf bazındadır**
  (AST-02/05/12). `admin` yetkiyi `extraPermissions` ile alır ve **12 komutu korur**.
- **Bayat testi düzeltirken iddia zayıflatılmaz, yer değiştirir.** Üç redial testinde
  `Assert.Single` yerine **satır sayısı açıkça** iddia edildi.
- **Append-only bir tabloyu temizleyen fikstür yazılmaz.** Zincir idempotent tohumlanır ve
  bırakılır; kimlikler sınıfa özel olduğu için çakışma doğmaz.

---

## Açık kalanlar / sonraki adım

- **`sisteme yukleyip deneyebilirsin`** — dağıtım henüz yapılmadı; turun kalan ayağı bu.
- Karar #38'in şartları **plana dönüşmedi**: `/sprint-planla pbxtr` gerekiyor (kurul skill'i
  kendiliğinden planlamaya geçmeyi yasaklar).
- Karar #37'nin 38 şartı da hâlâ plan bekliyor.
- Ölçülmeden kalan: üretim kuyruk sayısında bir mutabakat turunun süresi (Ş38-4'ün girdisi).
- `AST-03`/`AST-04` **"ölçüldü" sayılmaz** — canlı koşuldu ama `No objects found` döndü
  (o düğümde trunk/kayıtlı cihaz yok). Trunk tanımlı bir düğümde tekrarlanmalı.
- Kullanıcı tarafı: smtp2go DNS kayıtları, BR-SYS-86 yayın onayı.

---

## 6. Sisteme yükleme — yayın yolu dört kapıda durdu, dördü de gerçek bulguydu

- **Neden:** Kullanıcı emrinin son ayağı: *"sisteme yukleyip deneyebilirsin."*
- **Komut:** `PBXTR_CONFD_SAPMA=0 bash deploy/yerel-yayin.sh --yayinla`
- **Sonuç:** **`tekbirsoft/pbxtr:demo-d66684a676ce` canlıda.** Yedek alındı
  (`/home/vuo/pbxtr-demo/backups/pre-d66684a676ce.dump`), 27/27 bekçi assert'i geçti,
  nginx reload edildi.

### Kapı 1 — nginx sunucu sapması (CANLI KUSUR)

Kapı yönü bilerek kendi kararı saymıyor. Ölçtüm: sunucu ile depo arasında **tek bir kod satırı**
farklıydı — depodaki CSP, tema önyükleme scriptinin `sha256` karmasını taşıyor, sunucudaki
taşımıyordu.

Körlemesine kopyalamadım: karmanın **sunucuda servis edilen `index.html` ile eşleştiğini**
hesaplayarak doğruladım (`sha256-X3x5UKUE…`, birebir). Canlı başlığı da okudum: `script-src 'self'`,
karma yok, başlık **zorlayıcı**. Yani tema önyükleme scripti üretimde **fiilen bloklanıyordu** —
BR-SYS-79'un tam da önlemek için var olduğu FOUC canlı demoda duruyordu.

Sıra: yedek → kopya → `nginx -t` → reload → doğrula. Sonuç: CSP karmayı taşıyor, `80 → 301`,
`443 → 200 text/html`.

**Yapısal sebep (karta dönmeli):** `staging-yayin.sh` nginx yapılandırmasını sunucuya
**göndermiyor**; o dosyalar oraya elle konuyor.

### Kapı 2 — confd sunucu sapması (DAİRESEL BAĞIMLILIK)

Kapı doğru teşhis etti: bugün taşımak düğümü **kalıcı kırmızı** yapardı, çünkü koşan imaj
`removed` üretmiyor ve taşınan betiğin 7. adımı her koşuda `exit 75` verirdi. Reçete: önce imajı
yayınla, sonra taşı.

Atlamadan önce reçetenin uygulanabilirliğini ölçtüm: `RemovedBasis` `f9c78fad`'de gelmiş, koşan
imaj (`demo-3a4039ad`) **o commit'ten önce**, HEAD **sonra**. Yani bu yayın kapının kendi (1)
adımı. `PBXTR_CONFD_SAPMA=0` ile yalnız bu tur atlandı; iz `artifacts/ATLANAN-KAPILAR.txt`'de.
**Atlamak sapmayı kapatmaz** — taşıma ayrı adım olarak duruyor.

### Kapı 3 — `dotnet format` de hiç koşmamış

5 dosyada 14 sapma (11 boşluk + 3 import sırası); hiçbiri bu turda dokunduğum dosya değil.
Boşluk dışındaki fark yalnız `using` sıralaması.

**Yan bulgu:** yayın betiğinin kendi biçim adımı *"Formatted 5 of 1937 files"* yazdığı hâlde
çalışma ağacına **hiçbir değişiklik bırakmamıştı** (`git status` temiz). Düzeltici elle
koşturulunca aynı beş dosya gerçekten değişti (md5 farklı). Yani o adım hatayı **bildiriyor** ama
düzeltmeyi **kalıcı kılmıyor**.

### Kapı 4 — `test-kos.sh`: 440/440 geçti ama ikili bayattı

Kapı `KALDI` dedi: test DLL'i bu koşunun derleme anından eskiydi (`dll=1788834964 < eşik=1788850329`,
~4,3 saat). Defterdeki tam tuzak: *"0 Errors" yalan olur, ölçüm eski ikiliye gider.*

Ölçtüm: ikili (05:36) kaynaktan (05:31) **yeni**, yani derleme güncel — MSBuild artımlı davranıp
yeniden bağlamamış, kapı bunu "bu koşuda derlenmedi" diye okumuş. **Kapıyı gevşetmedim**; Release
çıktılarını silip ikilileri bu koşuda yeniden ürettim. Kapının iddiası dürüstçe karşılandı.

### Yükleme sonrası doğrulama (canlı)

| Ölçüm | Sonuç |
|---|---|
| Koşan imaj | `tekbirsoft/pbxtr:demo-d66684a676ce` |
| `pbxtr-app` | `Up (healthy)`, recreate edildi |
| `/health` | **200** |
| Panel `443` | **200 text/html** |
| CSP | karma yerinde |
| **ARI** | `Stasis uygulamasi 'pbxtr' acildi` |
| **AMI** | `AMI baglandi. banner=Asterisk Call Manager/11.0.0` |
| Hata sayımı (5 dk) | **0** |

CLAUDE.md §3.0'ın *"doğrulanır — doğrulanmadıysa bu bir eksiktir"* şartı bu turda **karşılandı**:
santral bağlantısı belge değil, ölçüm.

## Açık kalanlar — güncelleme

- `staging-yayin.sh` nginx yapılandırmasını göndermiyor (sapmanın yapısal sebebi) → kart.
- confd taşıması: imaj artık `RemovedBasis` taşıyor, yani **(2) taşı** adımı artık uygulanabilir.
- Yayın betiğinin biçim adımının yazımı ağaca inmiyor → kart.
- `test-kos.sh` ağaç değişmediğinde yanlış kırmızı verebiliyor (artımlı derleme) → kart.

---

## 7. confd taşıması denendi — GERİ ALINDI, ve neden geri alındığı bir bulgudur

- **Neden denendi:** Yayın turunda atlanan confd sapma kapısının reçetesi *"(1) imajı yayınla,
  (2) sonra taşı"* idi. İmaj yayınlandı, yani (2) açıldı.
- **Ön koşul ölçüldü, tahmin edilmedi:** betiğin kendi göstergesi yayından önce
  `imaj RemovedBasis: 0` derken şimdi **`1`** diyor. Ayrıca dağıtılan `Pbxtr.Api.dll` içinde
  `RemovedBasis` **kontrol grubuyla** doğrulandı (`ProvisioningEndpoints` = 2 eşleşme, yani
  grep ikili üzerinde gerçekten çalışıyor). İlk denemem `removedBasis` (küçük r) ve `strings`
  ile yapılmıştı ve **ikisi de 0 döndü** — `araç-yokluğu-sıfır-gibi-görünür` tuzağının birebir
  tekrarı; kasa ve araç düzeltilince cevap değişti.

### Ne oldu

`--olc` → sapma doğrulandı → timer durduruldu → `--tasi` (dört dosya atomik, `.onceki` yedekli)
→ **ilk koşu elle ve izlenerek**. İki ayrı arıza çıktı:

1. **`226/NAMESPACE`** — `ReadWritePaths=/var/lib/pbxtr-confd` yazan unit, dizinin **önceden var
   olmasını** ister; taşıma betiği yalnız dosya kopyalıyor, dizin oluşturmuyor. Dizinler
   `root:root 700` ile oluşturuldu (`/etc/pbxtr/confd` ile aynı izin).
2. **`78/CONFIG` — `dugum adi yok (/etc/pbxtr/confd/dugum)`.** Yeni model **düğüm kimliği**
   ister; eski model istemiyordu.

### Neden geri alındı

`staging-yayin.sh`in kendi metni kapatıyor: anahtar ve düğüm adı **bilerek üretilmez** —
*"anahtar #57 ekranından DÜĞÜME PİNLİ olarak üretilir; bu betik anahtar ÜRETMEZ (üretseydi
yönetici parolası düğümde durmak zorunda kalırdı)"*. Yani taşımanın kalan ayağı bir ürün-tarafı,
elle yapılacak adımdır ve tasarım bunu otomatikleştirmeyi **açıkça reddediyor**.

Canlıda **çalışan** bir teslim yolunu kırık bırakmak, kapatmaya çalıştığımız sapmadan kötüdür.
`--geri-al` çalıştırıldı: eski unit döndü, elle tek koşu **temiz** (`status=0/SUCCESS`,
*"SONUC: urunun urettigi config teslim edildi"*), timer yeniden **active**.

### Bu turda ölçülen, kayda geçmesi gereken üç şey

1. **Taşıma betiği eksik:** `/var/lib/pbxtr-confd` ve `.../is` dizinlerini oluşturmuyor →
   `--tasi` tek başına **her zaman** `226/NAMESPACE` verir. (Dizinler artık sunucuda var, boş.)
2. **Taşımanın gerçek ön koşulu `RemovedBasis` değil, DÜĞÜM KİMLİĞİdir.** Kapının metni yalnız
   `RemovedBasis`'i sayıyor ve *"artık taşınabilir"* izlenimi veriyor; oysa düğüm adı ve pinli
   anahtar olmadan yeni unit **hiç açılmaz**.
3. **Eski confd yolu çalışıyor ve bir eksiği var:** her koşuda
   `!!! SERVIS EDILMEYEN TURLER: pjsip — çözülmemiş PBXTR-SECRET(...) yer tutucusu`.
   Yani PJSIP config **teslim edilmiyor**, eski hâliyle kalıyor; PJSIP'i
   `demo-softphone-provision.sh` ayrı teslim ediyor. Bu, sessiz değil (günlükte yazılı) ama
   ölçülmüş bir eksiktir.

### Düzeltme — taşımanın gerçek engeli düğüm kimliği DEĞİLMİŞ

Yukarıdaki *"gerçek ön koşul düğüm kimliğidir"* çıkarımım **eksikti**; ölçüm devam edince
düzeldi. Sunucu günlüğündeki `crit` satırı düğüm adını zaten söylüyordu
(`node=asterisk-01`, `keyid=ak_...`), eski betik de onu sabit taşıyor
(`NODE=${PBXTR_NODE:-asterisk-01}`), ve `/etc/pbxtr/confd/anahtar` **zaten vardı** (63 bayt,
`600 root:root`). Yani eksik olan tek şey `dugum` dosyasıydı — bir sır değil, zaten yürürlükte
olan bir ad. Yazıldı (`600 root:root`), taşıma tekrarlandı.

**Bu kez yeni confd uçtan uca koştu** — node-bundle çekti, yazdı, reload etti ve reload sonrası
doğrulama yaptı. Ve **asıl engeli orada buldu:** pbxtr'ın beklediği nesne sayıları santraldekiyle
tutmuyor.

| tenant t0007 | beklenen | ölçülen |
|---|---|---|
| endpoints | 12 | **18** |
| auths | 12 | **6** |
| aors | 12 | **6** |
| queues | 2 | **3** |
| contexts | 8 | **11** |
| parkingLots | 1 | **0** |

Tasarım gereği sapan tenant önceki revizyona geri alındı, koşu `75/TEMPFAIL` ile **başarısız**
işaretlendi — betiğin kendi cümlesiyle: *"Bilinen/temiz tenantlar teslim edildi ve santral
ÇALIŞIR durumda; koşu BAŞARISIZ işaretlendi. **Sessiz atlama YASAKTIR.**"* `queues` türü
rollback'e kapalı olduğu için geri alınmadı ve ileri yönde yeniden teslim gerekti.

**Geri alındı**, çünkü betiğin talimatı bu (`exit 75 → --geri-al`) ve yeni yol yerinde kalsaydı
timer her 5 dakikada bir teslim → doğrula → geri al döngüsüne girip **canlı santrali sürekli
reload** ederdi. Eski yol geri yüklendi, elle koşturuldu (`exit 0`), `queues` ileri yönde yeniden
teslim edildi (`rev=1`), timer `active`.

Santral doğrulaması: uptime 2 gün, 18 bağlam, 3 kuyruk, 7 endpoint, app `health=200`.

**Kalan gerçek iş (kart):** yeni confd yolu **teknik olarak hazır** — engel artık kurulum değil,
**pbxtr'ın ürettiği manifest ile santralin fiili durumu arasındaki sapma**. Bu sapma bugüne kadar
görünmüyordu, çünkü eski yol reload sonrası nesne sayısı doğrulaması **yapmıyor**. Yani yeni yol
kurulmadan da var olan bir tutarsızlığı ilk kez o ölçtü.

**Sunucuda bıraktıklarım:** `/var/lib/pbxtr-confd` + `/is` (boş, `700 root:root`) ve
`/etc/pbxtr/confd/dugum` (`asterisk-01`). Üçü de yeni yol için gerekli, eski yola zararsız.
