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

### 2. Sprint-50 başladı (`/basla pbxtr sprint-50`) — kuyruk Asterisk'te kalır
- **Neden:** Kullanıcı: *"devam edelim ama Queue yapısı gene Asterisk'te kalsın"*. pbxtr'a ACD taşımak kapalı karar.
- **Ne yapıldı (sırayla, her biri ayrı commit):**
  - **BR-DOC-25** — `CLAUDE.md`/`AGENTS.md` §3.3/1'e "DEĞİŞİYOR" notu: Asterisk + Kamailio yalnız türetilmiş `pbxtr_telefon` DB'sine bağlanır; ana DB yasağı aynen durur (RLS/GUC gerekçesi). `doc/mimari/ADR-023-ortak-telefon-db-ve-kamailio.md`: K1 sözleşmesi (Kamailio host network, test portu 5070/5071, WS `172.28.0.1:8090`, JSONRPC `127.0.0.1:5090`, rtpengine ng `127.0.0.1:2223` medya 30000-30999, postgres sabit `172.28.0.15`, SIP alanı `sip.pbxtr.com`).
  - **BR-DB-123** — `deploy/telefon-db/` (00 roller, 01 Kamailio 6.0.8 şeması 73c93991'den, 02 pbxtr tabloları, 03 yetkiler; `kur.sh`, `selftest.sh` 73/0). `okur` rolü ha1/ha1b/auth_password okuyamaz; ana DB'ye CONNECT yasağı ölçüldü (55000).
  - **BR-SYS-146** — `deploy/kamailio/` (debian:12-slim digest + kamailio 6.0.8+bpo12, entrypoint 9 substdef, eksikte exit 78), `deploy/rtpengine/`; compose `kamailio` profili host network + cap_drop ALL/read_only/no-new-privileges/non-root; konteyner ayrıcalık kapısı host network'ü yalnız servis bazlı 4 telafi kontrolüyle kabul eder (21/21).
  - **BR-BE-284** — Outbox projeksiyonu: `telefon_outbox`, tenant-kirli işaret, yeniden hesap + fark, advisory lock 46, CLI `telefon-projeksiyon yeniden-kur`, sapma metriği + sağlık satırı. Migration `20261106090626_TelefonOutbox`.
  - **BR-AST-154/155** — `kamailio.cfg` (K1 yönlendirme; K2 `WITH_K2` arkasında). `Telephony:Kamailio:Enabled` açıkken endpoint'ler authsız, `outbound_proxy`, `deny 0.0.0.0/0 permit 172.28.0.1/32`, `identify match_header=X-Pbxtr-Trunk`; trunk kaydı Kamailio `uac_reg`'e geçti.
  - **BR-AST-162** — santral `[global] endpoint_identifier_order=header,username`; tek değişken `PBXTR_KAMAILIO_ONDE` hem santrale hem uygulamaya gider (`lab-entrypoint.sh` atomik yazar, geçersiz değerde exit 78).
- **Commit'ler:** `e0c6097c`, `e564faa1`, `b246c9fd`, `eee41aaf`, `5a5b1d22`, `93d8c769`+`674a5a8b` (backlog; ilki satırları taşımıyordu), `bf3e1c2a`, `9cc82236`.

### 3. K1 geçişi pilot sunucuda (176.88.41.220) — geri dönüşsüz tamamlandı
- **Ne yapıldı:** yayın (`bash deploy/yerel-yayin.sh --yayinla --testsiz`, imaj `demo-9cc822363d88`; ilk deneme Docker Desktop kapalı olduğu için düştü), nginx `/sip-ws` → Kamailio, nftables üretim portları, carrier-lab trunk `172.28.0.1`.
- **Duman testleri a–e geçti:** UDP/WSS REGISTER 200, iç çağrı + RTP, carrier→DID (`X-Pbxtr-Trunk`), dış trunk 200 + RTP, bypass INVITE ACL'de reddedildi. Kesintiler: postgres 7,7 sn, app 16 sn, santral 28 sn, kanal 0. `yeniden-kur` iki kez aynı özet (8 tenant, 39 satır, sapma 0).
- **Geçişte elle yapılanlar (her biri karta dönüştü):** host `/etc/asterisk/pjsip.conf` imajdakini gölgeliyor, `[global]` elle eklendi (BR-OPS-23); render damgaları elle silindi (BR-BE-290); Kamailio boş tablolarla açıldı, reload'lar elle (BR-BE-289); WSS kontağı 600 sn kalıyor (BR-AST-163); t0012 confd'de tıkalı (BR-AST-164); `t0007-trunk-lab` projeksiyonda yok (BR-BE-291); provisioning SipServer eski IP + RTP 0.0.0.0 (BR-OPS-24).
- **Commit:** `02d47355` (runbook §11 ilk geçiş kaydı), `ace8a2f7` + `7da3b2c3` (kartlar + ClickUp).

### 4. confd pjsip semantik doğrulayıcı boş alanı yutuyordu
- **Neden (ölçüldü):** doğrulayıcı alanları SEKME ayraçla okuyordu. Sekme bash'te IFS boşluğudur: ardışık sekmeler tek ayraç sayılır, boş `allow` alanı yutulur, `transport-udp` allow'a kayar. Her dahili sahte "SEMANTİK SAPMA" üretti ve t0007/t0012/t1001 pjsip'i GERİ ALINDI. 316 iddialı öz-test bu vakayı içermiyordu.
- **Ne yapıldı:** ayraç `\037` (US). Yeni `deploy/pbxtr-confd-dugum-ayrac-selftest.sh` fonksiyonu gerçek dosyadan çıkarıp koşar (P1/P2 yeşil, N1 kırmızı, M1 sekme mutasyonu yakalanır) → 4/4. Tam öz-test 316/316.
- **Commit:** `62158b38`.

### 5. BR-QA-133 (K1 ölçümü) — kısmi
- Tur 1: 1g, 2, temizlik GEÇTİ; 1a–1f, 3 kısmen, 4, 5 ölçülmedi. Bulgular: **YÜKSEK** kayıtlı (uacreg) trunk kaynak IP doğrulanmadan tanınıyordu; **ORTA-1** projeksiyon gecikmesi (oluştur 94 sn, sil 227 sn; tick 5 dk); **ORTA-2** santral ACL `172.28.0.1` = host'taki her süreç (ölçülmedi → BR-SEC-36).
- İkinci tur QA ajanı Anthropic güvenlik filtresi tarafından durduruldu. Canlı izolasyon senaryoları kullanıcı kararını bekliyor; ajanın işini ben yapmadım.

### 6. Geçiş bulgularının kodu (backend-dev-2, worktree) → birleştirme + dağıtım
- **Ne yapıldı:** AST-163 `usrloc handle_lost_tcp`+`close_expired_tcp` (TCP kapanınca kontak ≤5 sn düşer); BE-289 Kamailio `route[TABLO_TAZELE]` 10 sn'de dispatcher/address/uacreg md5'ini izler, yalnız değişende reload eder (+ `sql_query` hata dalı `$rc` ile — DID_COZ/TRUNKA/K2_AKTAR DB hatasında 404 yerine 503); BE-290 Kamailio ayarı render parmak izinde; BE-291 kökeni: trunk panelde yok, santrale elle yazılmış; AST-164 confd `[general]` alt sınırı + geri alınamayan tür için defter işareti; YÜKSEK bulgu → kayıtlı trunk yalnız kaynak IP ile tanınır, yabancı kaynak 403 (A/B ölçüldü); ORTA-1 → outbox commit sonrası sinyal + `TelefonProjeksiyonHizliDongu`.
- **Doğrulama (birleştirmeden sonra main'de):** 4 proje 0 hata; Api.Tests Telefon+Provisioning+ConfigRenderer 361/361; Architecture 858/858; `dotnet format --verify-no-changes` 0.
- **Dağıtım:** yayın `demo-e4b49f662e01` (EXIT 0); Kamailio imajı sunucuda `git archive e4b49f66 deploy/kamailio | ssh ... docker build -t pbxtr-kamailio:6.0.8-e4b49f66`, `.env` `PBXTR_KAMAILIO_IMAGE` değişti (yedek `.env.yedek-kam-e4b49f66`), `compose --profile kamailio up -d kamailio` → healthy, `tz_ds/tz_adr/tz_reg` dolu, ERROR 0.
- **Commit:** `29518e53`, birleştirme `e4b49f66`.

### 7. t0012'yi açmaya çalışırken iki confd kilidi daha bulundu
- **(a) ETag:** runbook'taki tek seferlik adım defter satırını `reload-bekliyor:` ile işaretledi ama `state.json` eski ETag'i taşıyordu → sunucu 304, işaretli tura hiç gelinmedi. Düzeltme: defterde işaretli satır varken `If-None-Match` gönderilmez. Öz-test F62 (pozitif kontrol + "istek gerçekten atıldı" kontrolü) + M45.
  - Ders: ilk F62 yazımında yardımcı fonksiyon daha sonra tanımlanıyordu (`command not found`) ve öz-test yine "331 geçti" dedi. İkinci yazımda argv defteri `>>` ile birikiyordu, iddia hep kırmızıydı ve M45 "yakalandı" diyordu ama taban zaten kırmızıydı. Üçüncü yazım 333/333.
  - **Commit:** `7edf7365`. Sunucuya kuruldu (sha `af094cb3…`).
- **(b) Bekleyen çağrı kapısı:** t0012'nin kuyruk defterinde kuyruk var, santrale hiç yüklenmemiş. `queue show` onu göstermeyince kapı "ölçülemedi" deyip `queue reload`'u her tick erteledi → strateji doğrulaması sapar → tur dondurulur. 13 günlük kilidin asıl sebebi bu. Düzeltme: `queue show` başka kuyrukları ya da `No queues.` basıyorsa ölçüm koşmuştur, bu tenant'ın kuyruğu yoksa düşecek çağrı yoktur; boş çıktı fail-closed kalır (F23). Öz-test F63 + M46 — koşu oturum kapanınca kesildi, 2026-11-07'de yeniden koşuluyor.
- **Not:** düzenleme sırasında koşan öz-test sözdizimi hatasıyla düştü ve depo köküne 4 boş dosya bıraktı (`moh`, `queue`, `res_parking.so`, `res_pjsip.so`); 07'de silindi. Koşan bash betiği düzenlenmez — önce koşu biter.

## Kararlar
- Tenant birden fazla Asterisk'e yayılır (kullanıcı kararı); kuyruk ve konferans odası tek düğümde.
- Kuyruk/oda ev düğümü yeni açılışta en az kuyruklu aktif düğüm, sonrası elle. Otomatik yeniden dengeleme yok.

## Açık kalanlar / sonraki adım
- t0012: F63/M46 öz-testi geçince confd kur, `dondurulmus` t0012 satırlarını temizle, `queue show` + `pjsip show endpoint t0012-*` ile doğrula.
- BR-QA-133 canlı izolasyon senaryoları: kullanıcı kararı (kendi koşar / Defense Access / kısmi bırak).
- BR-SEC-36 (santral ACL host süreçleri), BR-SYS-150 (SIP TLS sertifikası), BR-OPS-23/24 (sunucu sapması, provisioning SipServer + RTP yayını), BR-BE-291 veri işi (trunk panele).
