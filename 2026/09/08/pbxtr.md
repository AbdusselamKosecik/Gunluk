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
