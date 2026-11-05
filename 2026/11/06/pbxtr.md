# pbxtr — 2026-11-06

## Bağlam
Dünkü Kamailio + Asterisk havuzu planında (`deb40e87`) tenant tek bir Asterisk düğümüne
yapışıktı. Kullanıcı sordu: *"bir tenant birden fazla asteriskte dağılamaz mı"*. Seçenekler
anlatıldı, kullanıcı *"tamam bildiğin gibi yapalım"* dedi.

## Yapılanlar

### 1. Plan revizyonu: tenant düğümlere yayılır
- **Neden:** Yapışıklığın tek sebebi durum tutan nesnelerdi: `app_queue` (bekleyen arayan +
  üye durumu) ve `ConfBridge` (katılımcılar). Geri kalan trafik durumsuz.
- **Ne yapıldı:**
  - Yapışıklık tenant yerine **kuyruk ve konferans odası** düzeyine indi: `node_affinity`
    tablosu (nesne başına ev + yedek düğüm), `pbxtr_telefon.kuyruk_rota/oda_rota`.
  - Durumsuz trafik (dahili, dış hat, IVR, sesli mesaj, anons) Kamailio'nun **havuz set'i**
    üzerinden bütün aktif düğümlere yük tabanlı dağıtılır.
  - Kuyruk başka düğümdeyse: dialplan `REALTIME(kuyruk_rota,...)` ile ev düğümünü ortak
    DB'den okur, yerel değilse `Dial(PJSIP/q-<kuyruk>@kamailio)`. Yeni HTTP ucu yok, Sınıf B
    listesi genişlemiyor. İki bacak `X-Pbxtr-Call-Id` ile tek çağrı olarak birleşir.
  - Düğümler arası agent meşguliyeti: Kamailio `dialog` kapısı (kuyruk çağrısı + aktif dialog
    → 486) + pbxtr `QueuePause reason=pbxtr-baska-dugumde` senkronu (agent'ın kendi molasından
    ayrı alan). `res_pjsip_publish_asterisk` alternatif olarak ölçülecek.
  - `ITelephonyProvider` düğümü komuta göre seçer: originate → en az yüklü düğüm, kanal
    komutları → kanalın bulunduğu düğüm, `Queue*` → kuyruğun düğümü.
  - Failover ve boşaltma kuyruk/oda bazında: düşen düğüm havuzdan çıkar, kuyrukları yedeğe
    geçer. Tenant'ın diğer düğümlerdeki trafiği etkilenmez.
  - Tam dağıtık ACD (kuyruğu pbxtr'a taşımak) bilinçli olarak kapsam dışı, ayrı epik.
- **Dokunulan dosyalar:** `yonetim/kamailio-ve-asterisk-havuzu-plani.md` (§1 ilke 3, §2.2
  roller, §3.2 Kamailio tablosu, §4.1, yeni §4.2a/§4.2b, §4.3, §4.4, §5.1 sekme, §5.3 drain,
  §8 R8/R9, §9 S3/S5), `yonetim/sprintler/sprint-51.md`, `sprint-52.md`, `yonetim/backlog.md`,
  `yonetim/arac/clickup-kart-eslemesi.json`.
- **Kartlar:** yeni BR-AST-161, BR-BE-288; güncellenen BR-AST-154, BR-DB-124, BR-BE-285,
  BR-AST-158, BR-QA-134, BR-BE-287, BR-FE-149, BR-QA-135. Yama betiği scratchpad'de Python ile
  (satır başı `| KOD |` eşlemesi, eksik kartta assert).
- **Komutlar:**
  ```bash
  python -I yama.py yonetim/backlog.md
  cd yonetim/arac && node clickup-olustur.js   # yeni: 2
  node clickup-senkron.js                      # yazilan: 7
  node clickup-senkron.js --kuru               # fark 0, izde olmayan 0
  ```
- **Commit:** `c019d445` — Plan: tenant Asterisk dugumlerine yayilir; yapisik olan yalniz kuyruk ve konferans odasi

## Kararlar
- Tenant birden fazla Asterisk'e yayılır (kullanıcı kararı); kuyruk ve konferans odası tek düğümde.
- Kuyruk/oda ev düğümü yeni açılışta en az kuyruklu aktif düğüm, sonrası elle. Otomatik yeniden dengeleme yok.

## Açık kalanlar / sonraki adım
- Uygulama kullanıcı "başla" deyince; ilk iş sprint-50 / BR-DOC-25.
- Yeni riskler: R8 (düğümler arası aktarımda timeline/CDR birleşimi, İYS kapısının ikinci kez koşmaması), R9 (486 kapısı + pause senkronunun yarışı).
