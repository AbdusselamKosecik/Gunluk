# pbxtr — 2026-11-08

## Bağlam
"backlog'dakileri kapat" hedefi sürüyor. 7 Kasım gecesinden kalan iki ajan dalı (confd/teslim onayı ve güvenlik) birleştirilip yayına alındı. Kullanıcı Kamailio için bir yönetim GUI'si istedi.

## Yapılanlar

### 1. confd + teslim onayı (BR-AST-166, BR-AST-165, BR-OPS-25) — birleştirme `eaf5235b`
- **AST-166:** kısmi teslimde ETag artık kaydedilmiyor. Oz-test F67 ve M51 eklendi, 368/368 geçti.
- **AST-165:** yeni `provisioning_node_delivery (tenant, dugum)` damgası. Throttle anahtarı (anahtar, düğüm) oldu.
- **OPS-25:** `confd-boyut-olc.sh` artık uçtan uca koşuyor. Verdiği gerçek bulgu: N=50'de ~301 sn, yani `TimeoutStartSec=180` aşılıyor ve tavan ~26 tenant. Bu bulgu BR-AST-167'ye kartlandı.
- **Benim kaçırdığım:** BE-293'ün `CdrAbandonBackfill.cs`'i çapraz kip envanter kapısını kırmızı yapmıştı. Kapıyı BE-293'ü birleştirmeden önce koşmuştum. Kullanımı inceledim: yalnız tenant keşif SELECT'i yapıyor, yazım her tenant'ın kendi kapsamında. Kapının belgesine "DÖRDÜNCÜ TUR" kaydını yazıp `--dondur` koştum (44 kullanım).
- **Ders:** her birleştirmeden SONRA kapıları yeniden koş; önceki birleştirmenin yeşili sonrakini kapsamaz.

### 2. Güvenlik (BR-SEC-38/39/40) — birleştirme `a3d4a349`, Karar#93
- **SEC-38:** `telephony_nodes_read` yalnız çapraz kip ve platform oturumunda okunuyor. Müşteri oturumu sırsız `telephony_node_directory` görünümünü okuyor.
- **SEC-39:** Kamailio kipinde contact yalnız config'ten okunuyor, ARI PUT 403 dönüyor.
- **SEC-40:** `alarm_rules` için bileşik FK eklendi ve adaptör 404 dönüyor.
- **Karar#93:** iki contract migration onaylandı. Kabul edilen pencere riski: eski uygulama müşteri bağlamında düğüm defterinden 0 satır okuyor, bu da dispatcher'ı silebilirdi. Yayın sonrası ölçüldü: dispatcher 5/5.
- **Yayın `246886fe`:** yayın betiği EXIT=1 verdi. Gölgeleme kapısı host `sorcery.conf`'un imajınkini ezdiğini yakaladı; SEC-39 canlıya geçmemişti.
  - Çözüm: host dosyası `/root/pbxtr-yedek/sorcery.conf.host-golge-20261108`'e taşındı ve `up -d --force-recreate asterisk` ile imaj dosyayı tohumladı.
  - Canlı sonuç: S8, S11 ve S12 TAMAM (S12: "ARI PUT contact 403"). 31 endpoint, t0007-1042 statik contact yerinde, 12 kuyruk üyesi.
- Aynı gölgeleme 24 saatte üçüncü kez görüldü (pjsip, asterisk, sorcery). **BR-OPS-26** açıldı.
- confd host betiği ayrıca kuruldu (sha `6313b9c2`, depoyla eşit); tick 304, başarılı.

### 3. Kamailio GUI isteği
- Kamailio'nun kendi web paneli yok. JSONRPC yalnız `127.0.0.1:5090`'da dinliyor.
- **Siremis reddedildi.** Kamailio tablolarına doğrudan yazıyor; projeksiyon bu değişiklikleri sessizce ezer. Ayrıca dışarıya ikinci bir yönetim yüzeyi açıyor.
- **Karar:** pbxtr içinde ekran #80 "SIP Proxy ve Santral Havuzu". Kapsam: BR-FE-149, BR-BE-286/287, BR-SEC-35.
- Backend ve API sözleşmesi için ajan başlatıldı. Ekran, sözleşme gelince yazılacak.
- Bu arada CLI ile erişim: `docker exec pbxtr-kamailio kamcmd dispatcher.list | ul.dump | uac.reg_dump`.

## Açık kalanlar
- K3 (#80 ekranı): backend ajanı çalışıyor.
- BR-OPS-26, BR-AST-167, BR-AST-157 (havuz paketi), BR-QA-138 (25 adaptör), BE-288.
- Dış bağımlılıklar: BR-SYS-152 (sunucu dışı yedek hedefi), BR-SYS-150 (DNS), sağlayıcı seçimleri, SMTP, QA-126 insan imzası.

### 4. BR-OPS-26 — IMAJ gölgesini yayın betiği kendisi onarır (birleştirme `582e5db0`)
- **Ne yapar:**
  - Gölgelenen dosyayı ESKİ imajın tohum dizinindeki (`/opt/pbxtr/asterisk-default`) kopyasıyla bayt bayt karşılaştırır. Eşitse dosya elle düzenlenmemiş demektir: tarihli yedek alınır, dosya kaldırılır, santral ikinci kez yaratılır, edge'ler yeniden katılır ve kapı yeniden koşar.
  - Host kopyası farklıysa betik durur.
- **Fail-closed haller:**
  - Eski imaj okunamazsa OLCEMEDIM der ve durur.
  - İkinci ölçümde aktif kanal varsa onarım yapmaz.
  - Onarımdan sonra sağlık bozuksa yedeği geri koyar.
- **Öz-test (kapi_53) 22/0.** Mesai kapısının dört senaryosu (S9-S12) ve M4 mutasyonu kaldırıldı. Kapı 2026-10-18'de betikten çıkarılmıştı; senaryolar o günden beri hep kırmızıydı ve kapi_53'ü fiilen kaldırıyordu. Commit `c10b48b6`.
- **Ders:** hep kırmızı kapı = kaldırılmış kapı. Bunu yeni senaryo eklenirken ajan fark etti.

### 5. BR-QA-138 son tur ve K-06 kapanışı (birleştirme `316990c9`)
- Kalan 25 adaptöre iki-tenant sızıntı testi eklendi (4 yeni sınıf, 22/22). Borç tavanı 25 → 0; artık 65/65 adaptör testli.
- Bayi/platform yüzeylerinde sızıntının tanımı ayrı: bayi B, bayi A'nın tenant'larını göremez. `TenantLeakProbe`'a ikinci bayi `DealerB` eklendi.
- Yeni sızıntı bulunmadı. Mutasyon 5/5 kırmızı. Leak filtresi 132/132, Architecture 895/895.
- **K-06 Bitti:** üç ölçü de sağlandı.
  - Sızıntı 0, 65/65 adaptör.
  - p99 < 50 ms (E-09).
  - SLA/terk tek tanımda (BE-293).
- Yeni kart **BR-SEC-41**: LeaveCalendar userId ve RingGroup yedek hedeflerinin tenant aidiyeti denetlenmiyor. Ölçülmedi.
- Commit `d1af35b1`.

### K3 #80 canli kapi olcumu + Kamailio istemci havuzlama duzeltmesi
- **Neden:** #80 SIP Proxy ekrani canlida; JSONRPC panel yolunun uc kapisi (kaynak IP, sir basligi, kapali metod listesi) olculmeden BR-BE-286 kapanamazdi.
- **Ne yapildi:**
  1. Uygulama konteynerinde curl yok -> `docker run --network container:pbxtr-app curlimages/curl:8.10.1` ile ayni ag ad alanindan olcum (kaynak IP 172.28.0.11 korunur). Sir `docker exec pbxtr-app printenv ...` ile degiskene alindi, basilmadi.
     Sonuc: dogru sir core.version / dispatcher.list **200**; core.kill / cfg.seti **403**; yanlis sir **403**. Genel IP:5090 refused, nginx'ten timeout.
  2. Panel API olcumu: superadmin girisi sunucuda (parola .env'den okunup python ile JSON'a, basilmadi), `GET /api/v1/system/telephony-cluster/overview` -> **X-Cross-Tenant: on** basligi sart (yoksa 400 VALIDATION_FAILED).
  3. **SAHA BULGUSU:** overview'da registeredUsers/activeDialogs/bannedIps `null`. Kamailio dogrudan sorulunca degerler geliyordu -> ayristirici degil. App logu: ilk cagri disindaki her JSONRPC `Unreachable connect`. Sebep: Kamailio xhttp baglanti basina tek yanit verip Connection: close soylemiyor; .NET havuzdaki soketi ikinci POST'ta yeniden kullaniyor, POST idempotent olmadigindan yeniden denemiyor. curl her seferinde yeni baglanti actigi icin gorunmedi.
  4. Duzeltme: `HttpKamailioRpcClient.CreateHandler()` (PooledConnectionLifetime=0) DI ve testte tek fabrika; her istekte `request.Headers.ConnectionClose = true`.
  5. Test `KamailioRpcClientConnectionTests`: baglanti basina tek yanit veren, ayni sokette ikinci istekte koparan sahte TCP sunucu + 4 ardisik cagri. Mutasyon (duzeltme geri) -> "CoreUptime: Unreachable connect" KIRMIZI (saha belirtisinin aynisi); geri -> yesil.
- **Dokunulan dosyalar:** `src/Pbxtr.Infrastructure/Telephony/Kamailio/KamailioRpcClient.cs`, `src/Pbxtr.Infrastructure/DependencyInjection/TelephonyClusterServiceCollectionExtensions.cs`, `tests/Pbxtr.Api.Tests/Modules/SystemAdmin/KamailioRpcClientConnectionTests.cs`, `yonetim/backlog.md`
- **Komutlar:**
  ```bash
  dotnet test tests/Pbxtr.Api.Tests --filter "FullyQualifiedName~KamailioRpcClientConnectionTests|FullyQualifiedName~TelephonyCluster"   # 15/15
  dotnet test tests/Pbxtr.Architecture.Tests --filter "FullyQualifiedName~Kamailio"   # 20/20
  bash deploy/yerel-yayin.sh --yayinla --testsiz   # demo-f4c85d7a75a5 healthy
  ```
- **Sonuc / dogrulama:** yayin sonrasi overview kamailio: state ok, registeredUsers 0, activeDialogs 0, bannedIps 0 (null degil); son 3 dk logda Unreachable 0. compose-sunucu-sapma TAMAM (BIREBIR + UYGULANMIS). Sunucu .env sifreler reposuna yedeklendi (sha256 iki tarafta 9e6a3017, sifreler 66d30ac).
- **Commit:** `f4c85d7a` — Kamailio JSONRPC istemcisi havuzlamasin; `a05b4798` — backlog BR-BE-286/287, BR-SEC-35, BR-FE-149 Bitti. ClickUp fark 0.

## Acik kalanlar (bu tur sonu)
- BR-QA-135 (K3 uctan uca bosaltma/tasima/409/yetkisiz rol olcumu), BR-SYS-148 (sysagent node start/stop).
- Arka plan ajanlari: BR-AST-167 (confd teslim olcegi), mock saglayicilar + Brevo parola sifirlama.
- BR-SYS-150: sip.pbxtr.com Cloudflare proxy kapatilinca Let's Encrypt + tls.reload.
- QA-126 fidelity insan imzasi (ajanlar bitince uret).

### Ajan birlestirmeleri: BR-AST-167 (confd olcegi) + mock saglayicilar / Brevo parola postasi
- **Neden:** havuz paketi (BR-AST-157) icin confd teslimi tenant sayisiyla dogrusal buyumemeli; kullanici karari IYS/TTS/odeme simdilik mock, parola postasi Brevo.
- **Ne yapildi:**
  1. `worktree-agent-adc046e0157ddfae9` (f930f7a8) main'e birlestirildi (d6c46bfd): tek tar akisi ile toplu yazim + olcumde 9 CLI cagrisi; N=50 docker 2273 -> 48. Yeni oz-test F68-F70, mutasyon M52-M54.
  2. `worktree-agent-aa112d43e157d9824` (5b05a909 + c02fd7f0) birlestirildi: ADR-033 (mock = yapilandirma secimi, bos = fail-closed, simulasyon seridi + saglik satiri), IYS mesaj kanali + marka kodu migration'i `20261108090000_TenantIysBrandCode`, MockTts (bip, 8 kHz), PaymentCard/MockPayment/IvrPaymentProcessor (PCI log testleri mutasyonla), Brevo/SMTP secici parola postasi.
  3. Birlestirme sonrasi duzeltmeler (50fa1f81): `doc/st44-final-delivery-*.json` databaseSchemaRevision -> TenantIysBrandCode; `capraz-kip-yazma-daraltma` main'de zaten kirmiziydi (4 yeni + 6 kayan aralik, HEPSI yazma=yok) -> `--dondur`.
- **Komutlar:**
  ```bash
  dotnet build Pbxtr.sln                         # 0 hata
  dotnet test tests/Pbxtr.Architecture.Tests     # 902/902
  dotnet test tests/Pbxtr.Integration.Tests --filter FinalDeliveryReportTests   # 25/26 (1 atlandi)
  bash deploy/pbxtr-confd-selftest.sh            # 394/394 (~40 dk Windows'ta)
  bash deploy/asterisk-kapali-liste-parite.sh    # PARITE TEMIZ
  python3 deploy/ci/capraz-kip-yazma-daraltma-kapisi.py --dondur
  ```
- **Sonuc:** main yesil. Sunucuya compose kopyalandi (yedek `/root/pbxtr-yedek/docker-compose.yml.pre-50fa1f81`; yalniz TTS/odeme saglayici env, varsayilan mock). **Yayin (`yerel-yayin.sh --yayinla --testsiz`) yerel bellek yetersizligi nedeniyle sistem tarafindan durduruldu** -- dotnet format asamasinda, sunucuya imaj gitmedi; uygulama `demo-f4c85d7a75a5` healthy kaldi.
- **Backlog:** BR-AST-167, F-04, O-06 Bitti (mock); M-05/M-09 Devam; yeni BR-AST-168, BR-AST-169. ClickUp fark 0.
- **Commit:** `d6c46bfd`, merge aa112d43 dali, `50fa1f81`, backlog commit'i.

## Acik kalanlar (guncel)
- Yayin 50fa1f81 (bellek bosalinca) -> ardindan Brevo gercek test postasi + TTS/odeme simulasyon seridi canli kontrolu.
- BR-QA-135, BR-SYS-148, BR-AST-157/168/169, BR-SEC-41, BR-SYS-150 (DNS proxy), QA-126 (insan imzasi), BL-SMS-01 ve BR-SYS-152 ertelendi.
