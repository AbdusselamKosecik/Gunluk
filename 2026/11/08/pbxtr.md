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
