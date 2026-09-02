# pbxtr — 2026-09-02

## Bağlam

1 Eylül'de #61 (bayi kullanıcılarının görülmesi ve bürünme), ekran kaldırmaları ve
platform gelen kutusu işleri bitmişti; hepsi **yalnızca depodaydı.** Kullanıcı:
*"pbxtr ye yayinlarmisin"*. Bu günün işi bir özellik değil, **yayının kendisi** —
ve yayın yolu üç kez kırmızı verdi. Üçünün ikisi gerçek kusurdu.

## Yapılanlar

### 1. Yayın koşusu 1 — 2/7'de durdu: `using` sırası

- **Neden:** `deploy/yerel-yayin.sh` adım 2'de `dotnet format --verify-no-changes` koşar.
  `ApiEndpointAuthorizationTests.cs` içinde `using Pbxtr.Domain.Platform.Audit;`
  dosyanın 2. satırındaydı, `Pbxtr.*` grubunun içinde değil.
- **Ne yapıldı:** `using` `Pbxtr.*` grubuna alındı.
- **Dokunulan dosyalar:** `tests/Pbxtr.Architecture.Tests/ApiEndpointAuthorizationTests.cs`
- **Commit:** `0dbc26ad` — style(fmt): using sirasi duzeltildi

### 2. Yayın koşusu 2 — 2/7'de durdu: **partition penceresi** (GERÇEK KUSUR)

- **Belirti:** 19 entegrasyon testi **fikstür kurulumunda** düştü:
  `23514: no partition of relation "call_events" found for row`.
- **Kök sebep:** `ensure_future_partitions` yalnızca **içinde bulunulan aydan ileriye**
  partition açıyordu. Örnek veri seed'i 6 gün geriye CDR/olay yazar. 31 Ağustos'ta
  bu hep aynı ayı gösteriyordu; **2 Eylül'de 27–31 Ağustos'a düştü ve partition yoktu.**
  Yani hata **takvime bağlıydı** — dün yeşil, bugün kırmızı.
- **Bu bir test sorunu değil, ÜRÜN sorunudur.** CEL mutabakatı ve CDR geri doldurması
  (CLAUDE.md §3.4) **tanımı gereği geçmişe yazar.** Ayın 1'inde koşan bir mutabakat
  önceki ayın deliklerini kapatmaya çalışırken aynı hatayı alırdı — ve o an kaybedilen
  şey test değil, **çağrı geçmişi** olurdu.
- **Ne yapıldı:** Pencere bir ay geriye açıldı
  (`v_start := date_trunc('month', now()) - interval '1 month'`), döngü
  `0 .. p_months + 1` yapıldı — yani **ileri ufuk kısalmadı.**
- **Üç md5 kilidi bilinçli açıldı:** `02-guards.sql` fonksiyon md5'i, `sys-functions.expected`
  satırı ve toplu hash. SECURITY DEFINER gövdesi üç yerden birden pinlidir; biri
  güncellenmeseydi DB kapıları düşerdi.
- **İki test beklentisi güncellendi:**
  - `InitialSchemaMigrationTests`: çocuk partition 4 → **5** (geçen ay + bu ay + 3 ileri).
  - `CallEventsTimelineIndexTests`: **iddia gevşetilmedi, veri kümesi genişletildi.**
    Yeni boş partition'ı planlayıcı — doğru olarak — `Seq Scan` ile okuyordu; sıfır
    satırda indeks okumak daha pahalıdır. "Boş partition'da Seq Scan serbesttir" demek
    kapıyı kurcalardı: o istisna gerçekten indekssiz kalmış bir partition'ı da örterdi.
    Gürültü verisi `generate_series(-1, 3)` yapıldı (1M → 1,25M satır).
- **Dokunulan dosyalar:** `deploy/db/01-rls-template.sql`, `deploy/db/02-guards.sql`,
  `deploy/db/sys-functions.expected`,
  `tests/Pbxtr.Integration.Tests/Tests/InitialSchemaMigrationTests.cs`,
  `tests/Pbxtr.Integration.Tests/Tests/CallEventsTimelineIndexTests.cs`
- **Sonuç:** Integration **596/596**.
- **Commit:** `e688099f` — fix(db): partition penceresi bir ay geriye acildi

### 3. Yayın koşusu 3 — 4/7'de durdu: `npm ci` dosya kilidi

- **Belirti:** `npm error code EPERM / syscall unlink /
  node_modules\@esbuild\win32-x64\esbuild.exe`, `YAYIN_CIKIS=127`.
- **Sebep:** Yayın öncesi **yalnızca `Pbxtr.Api` durdurulmuştu.** Vite dev sunucusu
  (PID 43260), onu başlatan `npm run dev` (52140) ve **esbuild servis süreci** (40108)
  ayaktaydı; `npm ci` `node_modules`'ü silmeden yeniden kuramıyordu.
- **Ne yapıldı:** Üç süreç durduruldu. Kalıcı bir kod değişikliği yok — bu bir
  **çalışma düzeni** hatasıydı.
- **Ders:** Yayın öncesi durdurulacak şey "backend" değil, **`node_modules` ve `bin/obj`
  üzerinde tutamağı olan her şey**: `Pbxtr.Api`, Vite, esbuild.

### 4. Yayın koşusu 4 — 7/7 tamam

- **İmaj:** `tekbirsoft/pbxtr:demo-e688099f04e1`
  (`sha256:c77ef255422fe24dd3e18084ca6da0771903350cd122712d350472bd6688948a`)
- **Yedek:** `/home/vuo/pbxtr-demo/backups/pre-e688099f04e1.dump` (3.199.856 bayt)
- **Önceki imaj:** `tekbirsoft/pbxtr:demo-b0e41b709fae`
- **Migrate:** bekçi assert'leri **26/26**, şema + bootstrap + `seed-sample` tamam.
- **Komut:**
  ```bash
  bash deploy/yerel-yayin.sh --yayinla
  ```

### 5. Canlı doğrulama (pbxtr.com, gerçek istek)

| Ölçüm | Sonuç |
|---|---|
| `/healthz` | **200** |
| `POST /api/v1/auth/login` (superadmin) | **200**, `landingRoute=/admin-dashboard` |
| Menüde `/telephony/ivr`, `/telephony/extensions`, `/maintenance/media` | **üçü de yok** |
| `GET /api/v1/dealers` | 200, 1 bayi (Anadolu İletişim Bayii) |
| `GET /api/v1/users?dealerId=…` + `X-Cross-Tenant: on` | 200, roller **`["dealer"]`** (boş değil) |
| Aynı istek **başlıksız** | **0 satır** |

Son iki satır birlikte önemli: çapraz-tenant başlığı **gerçekten iş yapıyor**, süs değil —
ve 1 Eylül'de düzeltilen "çapraz okumada roller boş geliyor" kusuru canlıda da kapalı.

## Kararlar

- **Partition penceresi geriye açıldı, ileri ufuk korundu.** Bir ay: her ek ay bir
  `ACCESS EXCLUSIVE` kilit demektir. Daha eski bir geri doldurma **zaten bilinçli bir
  iştir** ve partition'ı açıkça açılmalıdır.
- **Perf testinde iddia değil veri kümesi değişti.** Kapıyı gevşetmek, ölçmek istediğin
  şeyi ölçmeyi bırakmaktır.
- Yayın betiği `python3` yokluğunu Docker içinde python koşarak **kendisi çözüyor**;
  elle shard bölmeye gerek kalmadı.

### 6. #58 Admin Dashboard — "sunucu durumu görünmüyor" (gerçek kusur)

- **Kullanıcı:** *"admin-dashboard daki sunucu durumu gosterilmiyor sorunu
  giderelim, birde kartlar arasi biraz bosluk verelim olmuyor boyle"*.
- **Ölçüm:** Uç zaten sağlamdı — `GET /api/v1/system/health` **200** ve 12 bileşen
  dönüyordu. Panel de çiziliyordu. Sorun **sunum**du.
- **Ne yanlıştı:** #58 aynı veriyi #37'den **ayrı**, kendi yazdığı bir `<ul>` ile
  çiziyordu:
  - durum ham İngilizce (`ok` / `down` / `unmeasurable`),
  - bileşen adı ham anahtar (`phone-masking`),
  - **`detail` alanı hiç yoktu.**
  Yani ekranda *"Config Teslimi: down"* yazıyor ama **neden** down olduğu —
  "4 aktif anahtardan 2 tanesi HİÇ bundle teslim almadı…" cümlesi, arızayı arayan
  kişiyi doğru yere gönderen tek şey — görünmüyordu.
- **Ne yapıldı:** Satırlar `HealthComponentList` bileşenine çıkarıldı; #37 ve #58
  artık **aynı görünümü** kullanıyor (LED + çevrilmiş ad + çevrilmiş durum +
  gecikme + gerekçe). #58'e ayrı bir görünüm yazmak, aynı veriyi iki ekranda iki
  ayrı dilde anlatmak olurdu.
- **Dokunulan dosyalar:** `src/Pbxtr.Web/src/app/screens/system/HealthComponentList.tsx`
  (+ `.module.css`), `PlatformHealthScreen.tsx` (+ `.module.css`), `platformApi.ts`,
  `dashboards/AdminDashboardScreen.tsx` (+ `AdminDashboard.module.css`)

### 7. Eksik etiket: `phone-masking` — ve **sınıfını kapatan kapı**

- **Bulgu:** `HealthComponentKeys.PhoneMasking` sunucuya eklenmiş, istemcideki
  `HEALTH_COMPONENT_KEY` haritası **elle** tutulduğu için geride kalmıştı.
- **Neden sessizdi:** `componentLabel` bilinmeyen anahtarda **anahtarın kendisini**
  döndürür. Bu fail-soft doğrudur (yeni bileşen ekranda **kaybolmaktansa** çirkin
  görünmeli) ama sessizdir — ekrana bakan biri olmadan görülmez.
- **Kapı:** `tests/Pbxtr.Architecture.Tests/HealthComponentLabelPairingTests.cs`
  sunucunun sabitleri ile istemcinin haritasını **birebir** eşleştirir ve etiketin
  **dokuz dilde** var olmasını ister. Yön tek taraflı değil: fazladan bir etiket de
  kırar (kaldırılmış bileşeni hâlâ varmış gibi gösteren ölü çeviri).
- **Vacuity kapısı var:** desen bayatlarsa `0 == 0` ile yeşil kalmasın diye
  `serverKeys.Count >= 10` ayrıca ölçülüyor.
- **Mutasyonla doğrulandı (üçü de kırmızı):** (1) anahtarı sil, (2) olmayan bir
  bileşene etiket ekle, (3) `fr.json`'dan çeviriyi sil.

### 8. Kart ızgarası

- #58, satır içi `display:flex; gap:12` kullanan **tek** ekrandı; kartlar içeriğine
  göre büzüşüyordu (`BAYİ` dar, `DAHİLİ` geniş) ve göz hizalanacak bir kenar
  bulamıyordu.
- Ev deseni ızgaraya alındı: `repeat(auto-fit, minmax(190px, 1fr))`, `gap: var(--sp-4)`
  — ölçü **#37 ile aynı**, iki platform ekranı aynı ritmi tutsun diye.
- **Uzun lisans gerekçesi kart notundan panel notuna taşındı:** 60 kelimelik cümle
  kart içindeyken **ızgara satırının tamamını** yükseltiyor, yanındaki "TENANT 3"
  kartı boş bir dikdörtgene dönüyordu. Kota ve destek panelleri aynı aileden notları
  (`quotaNoteKey`, `ticketNoteKey`) zaten panel altına yazıyordu; platform paneli
  **tek istisnaydı**.

**Ölçüldü:** web **1314/1314**, Architecture **338/338**, `tsc -b` temiz, #58 ve #37
tarayıcıda gerçek veriyle doğrulandı.

- **Commit:** `9bdeebb3`
### 9. Host ajanı denetimi — **belge bayattı, ajan çalışıyor**

- **Soru:** *"Hostaki sunucu ajanini kontrol edermisin neden veri alamiyoruz."*
- **Ölçüm (sunucu, `root@176.88.41.220`):**
  - `pbxtr-sysagent.service` **active (running)**, 29 Ağustos'tan beri (3 gün).
  - Soket `srw-rw---- root:pbxtr /run/pbxtr-sysagent/sock`, jeton `/etc/pbxtr/app/sysagent.token`.
  - Konteynerde ortam değişkenleri, soket ve jeton **hepsi bağlı**.
  - Canlı sağlık: `sysagent = ok` — *"Host ajani cevap veriyor (soket + jeton dogrulandi)"*.
- **`deploy/pbxtr-sysagent/README.md` hâlâ "GERÇEK SUNUCUDA HENÜZ KOŞTURULMADI" diyor.**
  Belge bayat; ajan kurulmuş ve çalışıyor.
- **İlk okumam yanlıştı.** `NetworkInterfaceReader`/`ThreatMonitorReader` gibi
  dosyalarda "host ajanı henüz yazılmadı" sabitlerini görüp "hiç sormuyorlar" dedim.
  O metinler **ölçülemeyen dalın yedek cümleleri**. Canlı ölçüm tersini gösterdi:
  ağ arayüzleri, tehditler, servisler, paketler, disk, CPU/bellek — hepsi
  `measured: true`. Kaynağa bakıp karar vermek yerine **ucu çağırmak** doğru olanı
  gösterdi.
- **Gerçekten eksik olan:** `system/backup` → `unmeasurable`, ve güvenlik duvarının
  dört katmanından biri (`fail2ban` kural listesi) okunmuyor — tablo FW-03 ile
  ölçülüyor ama kurallar nft ruleset ayrıştırması istiyor.

### 10. "PC'de mi Docker'da mı" — uç nokta artık ortamdan çözülüyor

- **Neden:** Kullanıcı: *"benim pc de calistigimi anlayip ona gore uc noktayi
  ayarlasin, docker de calistigini anlayip ona gore ayarlasin"*.
- **Asıl kusur bir metindi:** tek bir *"yapılandırılmamış"* cümlesi **üç ayrı gerçeği**
  aynı gösteriyordu:
  1. bu makinede ajan **olamaz** (Windows),
  2. ajan kurulu ama **ayar eksik**,
  3. ayar var ama **soket ortada yok**.
  Üçünün müdahalesi apayrı — birincisinde yapacak bir şey yok, ikincisinde ayar
  yazılır, üçüncüsünde servise bakılır. Aynı metni basmak, geliştiriciye **yanlış iş**
  yaptırıyordu: olmayan bir ajanı kurmaya çalışmak.
- **Ne yapıldı:** `SystemAgentPathResolver` — Linux host / konteyner / Linux-dışı ayrımı.
  - **Açık ayar her ortamda kazanır.** Geliştirici bir tüneli ya da özel yolu bilerek
    gösterebilir; algılamanın onu ezmesi *"ayarı yazdım ama uygulama dinlemiyor"*
    sınıfında bir hata olurdu.
  - **Yarım ayar tamamlanmaz.** Eksik yanı algılamayla doldurmak, operatörün yazdığı
    yarım ayarı "çalışıyor" göstermek olurdu.
  - **Yol TAHMİN EDİLMEZ:** standart yol yalnızca **diskte varsa** benimsenir.
    Tahmin, ajanı hiç kurulmamış bir sunucuda *"bağlanamadım"* (**arıza**) üretirdi;
    doğru cevap *"kurulu değil"*dir (**kurulum hali**) ve ikisi ayrı ekiplere gider.
  - **Linux dışı makine bir eksiklik değil, imkânsızlıktır** ve cümle bunu söyler:
    ajan root koşan bir Linux sürecidir, `AF_UNIX` + `SOCK_SEQPACKET` ile konuşur,
    Windows `SOCK_SEQPACKET` desteklemez. **Bu yüzden yerelden sunucunun ajanına
    tünelle bağlanmak da mümkün değil:** SSH `-L` bir *stream* soket verir, dinleyici
    SEQPACKET'tir ve `connect()` `EPROTOTYPE` ile düşer.
  - Konteynerde eksik yol **bind mount'a**, host'ta **README'ye** gönderir.
- **Çözümleme ajan olmasa da kaydedilir** — yalnızca ajan varken kaydedilseydi, tam da
  cümleye ihtiyaç duyulan hâlde kayıt olmaz ve yoklama eski genel metne düşerdi.
- **Ölçüldü:** 14 yeni test; **dört mutasyon** (yolu tahmin et / Linux-dışı dalı
  etkisizleştir / yarım ayarı tamamla / açık ayarı yoksay) — dördü de kırmızı.
  İlk üç mutasyon denemem **derlenmedi** (uyarı=hata, `CS0162`); derlenen
  eşdeğerleriyle tekrarlandı — derlenmeyen bir mutasyon doğrulama sayılmaz.
- **Sunucuda davranış değişmedi:** compose iki yolu da açıkça yazıyor, kaynak
  `Configuration` kalıyor.
- **Commit:** `d6994541`
## Açık kalanlar / sonraki adım

- **Yerel geliştirme yığını yayın için durduruldu** (Pbxtr.Api 5080, Vite 5173) —
  çalışmaya devam edilecekse yeniden başlatılmalı.
- Takvime bağlı kırmızı **bir kez daha olabilir**: ayın ilk günlerinde koşan başka bir
  fikstür geçmişe yazıyorsa aynı sınıfa girer. Pencere artık bir ay tolerans veriyor,
  **sonsuz değil.**
- `/goal` içinden hâlâ açık: **1** (Asterisk yönetimi), **2** (bayi yönetimi — kısmen
  ilerledi), **6** (güvenlik duvarı servis API'leri), **8** (hazır Asterisk komutları),
  **9** (süper admin kullanıcı CRUD).
- Bilinen borçlar (1 Eylül'den devam): `switchTenant` mekanizmasının çağıranı yok;
  `bundle.telephony.admin` tek kod taşıyor ve adı artık içeriğini anlatmıyor; bayi
  görünümünde düzenleme yok; `doc/prototip-urun-farklari.md` #62/#63'ü içermiyor.
- **Gerçek Asterisk'e karşı hiçbir şey doğrulanmadı** (CLAUDE.md §3.0).
- **Bir "gösterilmiyor" şikâyeti veri sorunu olmak zorunda değil.** Uç 200 dönüyordu,
  panel çiziliyordu; kayıp olan şey **gerekçe sütunuydu**. Önce uca bakmak doğruydu,
  ama orada durmak yanlış olurdu.
- **Elle tutulan iki liste er geç ayrışır.** Sunucu sabitleri ↔ istemci etiket
  haritası artık bir kapıyla bağlı; aynı desen (fail-soft + elle harita) başka
  yerlerde de olabilir.
- Prettier/ESLint bu depoda **kapı değil** (baseline'da 508 dosya uyarıyor, ESLint v9
  yapılandırması yok). Biçim kapısı `dotnet format` tarafındadır, frontend'de yoktur.
- **Kaynaktaki cümle, koşan davranış değildir.** "Host ajanı henüz yazılmadı" yazan
  sabitler ölçülemeyen dalın yedeğiydi; ucu çağırmadan verilen karar yanlıştı.
- `deploy/pbxtr-sysagent/README.md` **güncellenmeli**: "gerçek sunucuda henüz
  koşturulmadı" artık doğru değil.
- Açık kalan gerçek eksikler: **yedekleme durumu** (`unmeasurable`) ve güvenlik
  duvarında **fail2ban kural listesi** (tablo ölçülüyor, kurallar okunmuyor).
