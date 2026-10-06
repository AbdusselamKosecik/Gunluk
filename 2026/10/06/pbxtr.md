# pbxtr — 2026-10-06

## Bağlam
Kullanıcı: *"eksik bir şey kaldı mı? servisi update edebilir misin"*. Sunucu `736f570d6557`
(app + santral) üzerindeydi; yerelde push edilmemiş iki entegrasyon-testi düzeltmesi vardı.
Hedef: HEAD'i yeşil bir tam yayınla sunucuya götürmek. Yol boyunca yayın hattında üç ayrı kusur
ve canlıda üç gündür sessizce düşen bir arka plan işi çıktı.

## Yapılanlar

### 1. Entegrasyon testlerinde iki saatli bomba (yayın 11–12)
- **Neden:** Yayın 11'de 18 kırmızı. Sabit tarihli testler takvimle çürüdü:
  (a) taze test DB'sinde `pbxtr_sys.ensure_future_partitions()` geçmişe yalnız **1 ay** bölüm
  açar; `2026-08-17`/`2026-08-23` sabit anları 1 Ekim'de pencereden çıktı → `23514 no partition`.
  (b) `LicensePersistenceTests` bitiş tarihi geçmişe düştü.
- **Ne yapıldı:** İlk deneme ortak fikstüre (`TelephonyFixture`) geçmiş bölüm açmaktı →
  yayın 12'de 3 YENİ kırmızı (`CallEventsTimelineIndexTests` ×2 bölüm sayısını ölçüyor,
  `CallDataRetentionLagPartitionTests`). Fikstür **geri alındı**; onun yerine sabit anlar
  göreli yapıldı: `GecenAy(DayOfWeek, saat)` = geçen ayın 15–21'i arasındaki ilk o gün.
  Lisans tarihleri 2099/2100'e taşındı.
- **Dokunulan dosyalar:** `tests/Pbxtr.Integration.Tests/Tests/SilenceSamplerJobTests.cs`,
  `CallResultIntakeTests.cs`, `LicensePersistenceTests.cs`, `Infrastructure/TelephonyFixture.cs` (geri alındı)
- **Sonuç:** beş sınıf 31/31; tam takım yayın 16'da Integration 1290 + 2 izinli atlama.
- **Commit:** `62834ccc`, `ba3aeb90`

### 2. Aynı ağacın ikinci yayını tazelik eşiğinde KALIYOR (yayın 13–15)
- **Neden:** Yayın 13 Architecture testhost'u `0xC0000005` ile çöktü (211/794, ortam).
  Yayın 14'te 794/794 geçti ama `test-kos.sh` **karar KALDI**: DLL zaman damgası
  `PBXTR_TESTKOS_MIN_EPOCH`'tan eski. Artımlı derleme kaynak değişmediği için güncel DLL'e
  dokunmuyor; eşik "bu koşuda üretildi" der → doğru ikili reddediliyor. Yayın 15'te aynısı
  Api.Tests'te (yalnız Architecture çıktısını silmiştim).
- **Ne yapıldı:** `deploy/yerel-yayin.sh` Release derlemesi `--no-incremental`.
- **Commit:** `bb88e153`

### 3. npm audit high/critical yayını durdurdu (yayın 16–17)
- **Neden:** Backend tamamen yeşil, ama `npm audit --audit-level=high` yeni bildirimler:
  tinypool (critical ×2, vitest 3 üzerinden), source-map-js (high), @vitest/mocker (moderate).
- **Ne yapıldı:** `vitest ^3.2.7 → ^5.0.3` (vite 6.4 destekli; host Node 24, imaj `node:22`),
  `overrides.source-map-js ^1.2.2`.
- **Komutlar:**
  ```bash
  cd src/Pbxtr.Web
  npm pkg set devDependencies.vitest="^5.0.3" overrides.source-map-js="^1.2.2"
  npm install && npm audit --audit-level=high && npm run typecheck && npx vitest run
  ```
- **Sonuç:** audit 0, typecheck 0, **261 dosya / 2255 test** (vitest 3 koşusuyla birebir aynı sayı).
- **Yan kırık (yayın 17):** vitest 5'te `basic` reporter yok → kapı adımı `Failed to load custom
  Reporter from basic`. `HOST_KAPILARI` listesi + fiili çağrı birlikte `--reporter=dot`
  (`kapi_81` ikisini karşılaştırır).
- **Commit:** `68c17149`, `740ae3be`

### 4. Yayın 18 YEŞİL — servis güncellendi
- Sunucu `tekbirsoft/pbxtr:demo-740ae3bee62a`, healthy; anons kapısı **KOŞTU**
  (`YESIL : pbxtr/sys/hizmet-disi-en.gsm VAR`). Santral değişmedi (bugünkü işler ona dokunmuyor).

### 5. BR-BE-224 — sesli mesaj taşıma işi 3 gündür her tikte düşüyordu
- **Neden (ölçüm):** deploy sonrası log kontrolünde `recording-transfer` işi `25P02`. PG günlüğü:
  72 saatte **863** kez `column c.linked_id does not exist` + `25P02`. Kolon `linkedid`.
  Hiçbir sesli mesaj taşınmıyordu. Testler sorguyu sahte okuyucuyla görüyor, gerçek şemaya
  hiç koşmamış.
- **Ne yapıldı:** `LEFT JOIN LATERAL (SELECT caller_e164 FROM cdr WHERE c.linkedid = vm.call_id
  ORDER BY started_at, uniqueid LIMIT 1)`. Düz JOIN yetmezdi: `cdr` çağrı başına birden çok
  satır (sunucuda 1594 satır / 1103 çağrı) → aday çoğalırdı. Metin bekçisi eklendi.
- **Dokunulan dosyalar:** `src/Pbxtr.Infrastructure/Modules/Recordings/RecordingTransferJob.Voicemail.cs`,
  `tests/Pbxtr.Api.Tests/Modules/Recordings/VoicemailIntakeWriterTests.cs`, `yonetim/backlog.md`,
  `deploy/ci/capraz-kip-yazma-daraltma.json`
- **Doğrulama:**
  - Sorgu sunucuda `BEGIN … ROLLBACK` içinde rc=0, 2 aday.
  - Recordings 163/163, ilgili mimari bekçiler 50/50.
  - Yayın 19 `capraz-kip-yazma-daraltma` kapısında KALDI: eklenen yorum satırları çapraz aralığı
    368 → 377 kaydırdı, `yazma=yok` aynı. `--dondur` ile yeniden donduruldu (yalnız satır no).
  - Yayın 20 YEŞİL → `1cb1b51867e4`. Deploy sonrası PG'de `linked_id`/`25P02` **0**.
  - İki aday 72 sa `LookbackHours` dışındaydı. Geçici override ile ölçüldü:
    ```bash
    # /tmp/vm-lookback.override.yml: services.app.environment.RecordingStorage__LookbackHours: "720"
    docker compose -f docker-compose.yml -f /tmp/vm-lookback.override.yml up -d --no-deps app
    # ... sonuç okunduktan sonra:
    docker compose up -d --no-deps app && rm /tmp/vm-lookback.override.yml
    ```
    → `Sesli mesaj: 1 yeni mesaj acildi` (`1790320122.93`). Diğeri (`1790190119.131`, öneksiz
    hedef `1042`, eski dialplan) **tasarım gereği** açılmadı (fail-closed, Ş71-S7).
    Override geri alındı, app aynı imajla healthy.
- **Commit:** `36551577`, `1cb1b518`, `74121cdb`; ClickUp eşleme `dbda29c0` (BR-BE-224 kartı açıldı).

## Kararlar
- Yayın yalnız `YAYIN_EXIT=0` iken push eder (koşullu push); bugün 10 yayın denemesinin
  hiçbiri kırmızıyken push etmedi.
- Ortak test fikstürüne geçmiş bölüm açmak **reddedildi** — bölüm sayısını ölçen testleri bozar;
  tarih bombası test tarafında göreli anla çözülür.
- `capraz-kip-yazma-daraltma.json` yeniden dondurması yalnız satır kayması olduğu diff'le
  doğrulandıktan sonra yapıldı.

## Açık kalanlar / sonraki adım
- Pano: 4 BR (BR-C2-1, BR-C2-2, BR-DB-74, BR-OPS-14 — kullanıcı "şimdilik es geç") + 76 story.
- Sesli mesaj aday sorgusu hâlâ yalnız metin bekçisiyle korunuyor; gerçek şemaya karşı
  koşan bir entegrasyon testi yok (bu bug sınıfını o yakalar).
- Lab trunk parolası değiştirilmeli; ölçüm çağrılarının 7 CDR satırı bilerek bırakıldı.
- Santral imajı `736f570d6557`'de; bugünkü değişiklikler santrali etkilemiyor.
