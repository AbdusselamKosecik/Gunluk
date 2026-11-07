# pbxtr — 2026-11-07

## Bağlam
Sprint-50 (K1: Kamailio önde) sürüyor. Dün akşam t0012 hâlâ açılmamıştı: ETag düzeltmesi
(`7edf7365`) sunucuya kurulduktan sonra gövde indi, ama `queue reload` ertelendi, tur sapıp
yeniden donduruldu. Kök sebep bulunmuş, düzeltme yazılmış; öz-test koşusu oturum kapanınca
kesilmişti. Kullanıcı: *"devam edelim"*.

## Yapılanlar

### 1. Kesilen öz-testin artıkları temizlendi
- **Neden:** Depo kökünde dört boş dosya vardı (`moh`, `queue`, `res_parking.so`, `res_pjsip.so`), damgaları 2026-11-06 16:50. O dakika, öz-test koşarken betik düzenlendiği için sözdizimi hatasıyla düştüğü an. Bash betiği satır satır okur; yarım okunan satırlardaki yönlendirmeler bu dosyaları açmış.
- **Ne yapıldı:** içerik okundu (0 bayt), silindi.
- **Ders:** koşan bash betiği düzenlenmez; önce koşu biter.

### 2. confd: santrale yüklenmemiş kuyruk bekleyen-çağrı kapısını kalıcı kilitlemesin (BR-AST-164)
- **Neden (sunucuda ölçüldü, 2026-11-06 15:21Z):** t0012'nin kuyruk defterinde `t0012-musteri-hizmetleri` var, ama kuyruk santrale hiç yüklenmemiş. `queue show` onu göstermeyince kapı "bekleyen çağrı ÖLÇÜLEMEDİ" deyip `queue reload`'u erteledi. Ardından strateji doğrulaması `yuklu=OLCULEMEDI` ile sapıyor, tenant geri alınıp donduruluyordu. Her tick aynı döngü: 2026-10-24'ten beri süren kilidin asıl sebebi bu.
- **Ne yapıldı:** `deploy/pbxtr-confd-dugum.sh` `kuyruk_bosalmis_mi()`: `queue show` çıktısında başka bir kuyruğun `has N calls` satırı ya da birebir `No queues.` varsa ölçüm koşmuş sayılır. Tenant'ın kuyruğu listede yoksa santralde yoktur ve düşecek çağrı da yoktur; reload engellenmez, durum adıyla loglanır. Boş ya da ayrıştırılamaz çıktı fail-closed kalır (F23 yeşil).
- **Öz-test:** `deploy/pbxtr-confd-selftest.sh` F63 (başka tenant'ın kuyruğu görünür, defterdeki kuyruk görünmez → `queue reload all` koşar, "YÜKLÜ DEĞİL" yazılır) + M46 (eski davranış geri gelirse yakalanır). Tam koşu **336/336**.
- **Komutlar:**
  ```bash
  bash deploy/pbxtr-confd-selftest.sh      # 336 iddia gecti, EXIT=0
  git show HEAD:deploy/pbxtr-confd-dugum.sh | ssh root@176.88.41.220 'cat > /root/pbxtr-confd-dugum.sh.yeni && bash -n ...'
  # sunucuda: timer stop -> inactive/failed bekle -> install -m 0755 -> mv
  # /var/lib/pbxtr-confd/dondurulmus: t0012 satirlari silindi (yedek dondurulmus.yedek-br-ast-164-b)
  systemctl start pbxtr-confd.timer
  ```
- **Sonuç / doğrulama (2026-11-07 10:17Z):** tick'te `t0012: defterdeki kuyruklar santralde YUKLU DEGIL ... reload engellenmez`, `reload: queues`, `queues=1`, `=== SONUC: dugum paketi teslim edildi.` `queue show` → `t0012-musteri-hizmetleri ... 'rrmemory'`. `t0012-2011..2013` yüklü, `outbound_proxy sip:172.28.0.1:5060;lr` (t0007 ile aynı Kamailio kipi). Komşular: t0007'de 16 endpoint ve 2 kuyruk, t1001'de 13 endpoint. `dondurulmus` boş, servis failed değil. Sunucu confd sha'sı `d0c1c4f4…`, depodakiyle aynı.
- **Commit:** `a3327113` — confd: santrale yuklenmemis kuyruk bekleyen-cagri kapisini kalici kilitlemesin (BR-AST-164)

### 3. Backlog / sprint / ClickUp
- **Ne yapıldı:** `yonetim/backlog.md`: BR-AST-163, BR-AST-164, BR-BE-289, BR-BE-290 **Bitti**; BR-BE-291 **Kısmen** (kalan veri işi: `t0007-trunk-lab` panele girilir, `/etc/asterisk/pbxtr-lab.d/trunk-lab-pjsip.conf` kaldırılır); BR-QA-133 **Kısmen**; yeni **BR-SEC-36** (santral ACL `permit=172.28.0.1/32` host'taki her süreci güvenilir sayar; ölçülmedi). `yonetim/sprintler/sprint-50.md`: durum satırı + "geçişten doğan kartlar" tablosu. Yama betiği scratchpad'de Node ile (`k1b-kartlar.js`: satır `| KOD |` ile bulunur, durum son hücre, eski durum "Önceki kayıt:" ile korunur).
- **Komutlar:**
  ```bash
  cd yonetim/arac && node clickup-olustur.js   # yeni: 1 (BR-SEC-36)
  node clickup-senkron.js                      # yazilan: 6
  node clickup-senkron.js --kuru               # fark 0, izde olmayan 0
  ```
- **Commit:** `558c0286` — backlog: K1 bulgulari AST-163/164, BE-289/290 Bitti; BE-291 kismen; QA-133 kismi; yeni BR-SEC-36; sprint-50 durumu

### 4. Hedef: "backlog'dakileri kapat" — sunucu kartları (BR-BE-291, BR-OPS-23, BR-OPS-24, BR-SEC-36)
- **Neden:** Kullanıcı `/goal baclogdakileri kapat` verdi. `kalan-isler.js`: 962 BR kartının 56'sı açık; story satırlarıyla ~140 açık satır. Önce tek elle bitecek sunucu kartları; kod hataları (backend-dev-1), sprint-51 düğüm defteri (db-dev), BR-SEC-36 düzeltmesi (backend-dev-2) worktree ajanlarına; story satırlarının koda karşı ölçümü ayrı bir ajana.
- **BR-BE-291:** `t0007-trunk-lab` panele girilmedi, **emekliye ayrıldı**: ürün carrier trunk'ı panelden gelen `t0007-trunk-operator-lab` (Kamailio arkasında); lab trunk `lab-trunk-in` bağlamına düşen 2026-09-24 ölçüm artığı, tailnet yolu K1'den beri kapalı. Dosya `/root/pbxtr-yedek/`e taşındı.
  - **Bulgu:** host `pjsip.conf`'taki `#include "pbxtr-lab.d/*-pjsip.conf"` glob'u hiçbir dosyaya eşleşmeyince Asterisk **bütün pjsip.conf'u geçersiz** sayıyor (`Contents of config file 'pjsip.conf' are invalid`) ve eski nesneleri koruyor. `module reload` "successfully" der, endpoint kalır. Bir sonraki confd reload'u da sapardı. Satır kaldırıldı.
  - **Hata (benim):** lab dosyasını okurken `sed` maskem `password = x` (boşluklu) biçimini yakalamadı, lab trunk parolası transkripte düştü. Endpoint kaldırıldığı için parola artık hiçbir şeyi açmıyor. Ders: maske `^\s*(password|secret)\s*=` olmalı; daha iyisi o satırları hiç basmamak (`grep -v`).
- **BR-OPS-23:** host `pjsip.conf` = depo (yorumsuz); `deploy/asterisk-sunucu-sapma.sh` on iddia TAMAM. Santral imajı `22-9cc822363d88` kayıt defterinde yoktu → `ssh … docker save | docker load` + `docker push` (digest `f55b7e9b…`, sunucudaki imaj kimliğiyle aynı). `deploy/compose-sunucu-sapma.sh` BİREBİR + UYGULANMIŞ.
- **BR-OPS-24:** compose'ta santral RTP yayımı `${PBXTR_RTP_YAYIN_ADRES:-0.0.0.0}` (varsayılan Kamailio'suz kurulum için); sunucu `.env` `127.0.0.1` + `PBXTR_PhoneProvisioning__SipServer` = Kamailio genel IP'si. `up -d asterisk app`.
  - Ölçüm: santral medya adresi olarak konteyner IP'sini ilan ediyor (`external_media_address` boş). `nsenter -t <pid> -n tcpdump` ile host→`172.28.0.12:20050` 3/3 göründü (rtpengine yolu), genel IP:20050 0/3.
  - Carrier'dan gelen çağrı kuyrukta çaldı (cevap yok → RTP yok); giden çağrı call-permission `BLOCKED_UNKNOWN` (Local kanal, arayan dahili yok) — ikisi de medya ölçmedi, bu yüzden ad alanı ölçümüne inildi.
  - **Bulgu:** santral yeniden **oluşturulunca** `pbxtr-edge`/`edge-fastagi` `Exited (75)`'te kaldı — `network_mode: service:asterisk` eski konteyner kimliğine bağlı. Yayın yolu `edge_yeniden_katil` ile çözüyor; elle adımda `up -d --no-deps --force-recreate edge edge-fastagi` şart. `deploy/pbxtr-edge/konteyner-nginx.sh` yorumu düzeltildi.
- **BR-SEC-36 ölçüldü:** `/root/k1-gecis/bypass.py` host'tan koşuldu → sahte `X-Pbxtr-Trunk` ile INVITE santralde trunk olarak tanındı, `pbxtr-t0007-in`'e girdi, MixMonitor başladı (DID eşleşmediği için 503). Karar: IP ayrımı host süreçlerine karşı işe yaramaz → paylaşılan sır başlığı; backend-dev-2'de.
- **Komutlar:**
  ```bash
  ssh root@176.88.41.220 'mv /etc/asterisk/pbxtr-lab.d/trunk-lab-pjsip.conf /root/pbxtr-yedek/…; sed -i "/pbxtr-lab.d\/\*-pjsip.conf/d" /etc/asterisk/pjsip.conf; docker exec pbxtr-asterisk asterisk -rx "module reload res_pjsip.so"'
  bash deploy/asterisk-sunucu-sapma.sh; bash deploy/compose-sunucu-sapma.sh   # ikisi EXIT 0
  ssh root@… 'docker save tekbirsoft/pbxtr-asterisk:22-9cc822363d88 | gzip -1' | gunzip | docker load && docker push …
  ssh root@… 'cd /home/vuo/pbxtr-demo && docker compose -f docker-compose.yml -f docker-compose.vpn.yml --profile kamailio up -d asterisk app'
  ssh root@… '… up -d edge edge-fastagi'
  ```
- **Sır yedeği:** `sifreler` `pbxtr-demo/.env.sunucu` sunucudan tazelendi (`4430886`).
- **Commit:** `06e01db4` — sunucu kartlari: BR-BE-291 lab trunk emekli, BR-OPS-23 sapma sifir + santral imaji push, BR-OPS-24 RTP yayim adresi parametrik; BR-SEC-36 olculdu. ClickUp `--kuru` fark 0.

### 5. Story satırlarının ölçümü + ajan dalları + yayın b85a790a
- **Story ölçümü (salt-okuma ajanı):** 97 açık satır → 26 BAYAT-BİTMİŞ, 7 KAPSAM-KARARI, 23 KOD-İŞİ, 29 CANLI-ÖLÇÜM, 12 DIŞ-BAĞIMLILIK. Üç örnek elle doğrulandı (RecordingPlayer dalga formu, `MapRingGroupEndpoints`, `AnswerAsync`). 33 satır kapatıldı (`8be692b6`).
  - Yan etki: `DecisionCodeManifestTests` BL-DB-33'ü "planned" sanıyordu → `doc/mimari/decision-code-manifest.json` `telephony.ring-groups` `enforced` (sembol/route/test). Manifest SIKIŞIK biçimde kalmalı: JSON'u yeniden biçimleyince mutasyon testi metin değişimini uygulayamayıp kırmızı oldu (`da2f2a21`).
  - Yama aracı: `kart.js` kartı satır başındaki `\n| KOD |` ile bulur; aksi hâlde başka satırın bağımlılık sütunundaki atıf "mükerrer" sayılıyordu.
- **Birleştirilen dallar:** BR-SEC-36 (`320b10c7`), ops (BR-OPS-18 NG-01, BR-C2-1 kapi_89, ST-48 kuralları; `fa125194`), kod hataları (BR-OPS-22, BR-BE-256/262/283 CDR tek satır, BR-AST-132, BR-SEC-33; `ea05e2dd`), santral (BR-SEC-37, BR-AST-133, BR-AST-135; birleştirme), sprint-51 BR-DB-124/125 (`565efac2`, ADR çakışması iki bölüm korunarak), FE bağlama (G-17, BR-FE-148, P-03, P-04, BR-FE-141; `b85a790a`). Her birleştirmeden sonra `dotnet build pbxtr.sln` 0 hata; `dotnet ef migrations has-pending-model-changes --context PbxtrDbContext` → değişiklik yok; `tsc -b` 0.
- **Yayın sırası (BR-SEC-36):** sır `.env`'e sunucuda üretildi (`openssl rand -hex 32`, yalnız uzunluk 64 basıldı), `sifreler` yedeği (`a843fce`); confd zamanlayıcısı durduruldu; `bash deploy/yerel-yayin.sh --yayinla --testsiz --santral` (bu kip uygulamayı da `demo-b85a790ac935`'e aldı).
  - **KESİNTİ (benim hatam):** sunucu compose'u eskiydi ve sır değişkenini santrale geçirmiyordu → yeni giriş betiği `exit 78`, santral ~13:50–13:52:28Z kapalı (~2,5 dk). Yayın betiğinin SSH'ı da koptu (EXIT 255). Düzeltme: depo compose'u kopyalandı, `up -d --no-deps --force-recreate asterisk`, ardından edge yeniden katıldı. **Ders:** imaj yeni bir zorunlu env isterse compose ÖNCE sunucuya gider; santral dalı compose'u taşımaz.
  - Kamailio imajı sunucuda `git archive b85a790a deploy/kamailio | ssh … docker build -t pbxtr-kamailio:6.0.8-b85a790a`; `.env` `PBXTR_KAMAILIO_IMAGE` (yedek `.env.yedek-kam-b85a790a`); `up -d --no-deps kamailio` → healthy; JSONRPC `dispatcher.list`: set 1 + 100–103 `AP`.
  - confd yeniden başlatıldı → `SONUC: dugum paketi teslim edildi`, `pbxtr-t0007-kam-in` kapısı yüklü, `t0007-1042` bağlamı `pbxtr-t0007-kam-out`.
  - `deploy/telefon-db/kur.sh --konteyner pbxtr-postgres` (`PBXTR_TELDB_*` .env'den süreç ortamına, basılmadan) → `cdr`/`cel` kuruldu.
  - sysagent: `dotnet publish src/Pbxtr.SysAgent -c Release` → `install` (yedek `/root/pbxtr-yedek/pbxtr-sysagent.yedek-20261107`), katalog 83 komut.
- **Canlı ölçümler:** sahte trunk INVITE → `REDDEDILDI` + `Hangup(21)`, MixMonitor yok; carrier→DID kapıdan geçti, kuyruk 1042'yi çaldırdı; host'tan `From: t0007-1042` + `*8` → `kam-out` reddi (BR-SEC-37); NG-01 uygulama kullanıcısıyla (`setpriv --reuid=1654`) exit 0, 1 adet 502, IP `172.28.0.x` (root peer `uid_mismatch` ile reddedildi — doğru).
- **ST-48:** yeni sayaç penceresi 12:33Z; kilit en erken 2026-11-09 12:33Z.
- **Commit'ler:** `2ada07e5` (backlog 19 kart + yeni BR-BE-292), ClickUp yeni 2, yazılan 18, `--kuru` fark 0.

### 6. Kalıcı kırmızı kapılar, ikinci/üçüncü yayın, E-09 kapanışı
- **Migration uyumluluk kapısı** (`deploy/migration-compatibility-guard.py`) 2026-10-23'ten beri 7 migration yüzünden kırmızıydı; `--testsiz` yayında koşmadığı için görünmüyordu. Her `Up()` okundu (ekleyici ALTER, CHECK genişletme, `call_events` PK'ye `node`), sunucuda 7/7 uygulanmış → `deploy/migration-contract-onay.blobs` + `yonetim/kurul-kararlari.md` Karar#91 (`49b34c72`).
- **Çapraz kip envanteri** kırmızıydı (kod 40→43, migration 72→78). pbxtr-qa 7 kullanımı tek tek inceledi: hepsi keşif SELECT'i ya da migration geri doldurması, istekten gelen `tenant_id` çapraz kipte yazılmıyor. `TelefonCaprazKesif` daraltıldı (denetim satırı kip kapandıktan sonra, boş taramada yazılmaz — Ş34-25), `TelefonProjeksiyon` entegrasyon 7/7. `--dondur` + kapı docstring'ine "ÜÇÜNCÜ TUR" gerekçesi; dondurma günü dinamik (`fbeb7431`). Yeni kart BR-SEC-38 (`telephony_nodes_read USING (true)`).
- **Ağır DDL defteri** birleşmeden sonra bayattı → `python deploy/migration-agir-ddl.py --uret` (191 ad).
- **Birleştirmeler:** scripter (FE-140/BE-257/258/259), BE-258 arayüzü (editör işlemleri siliyordu — düzeltildi), BR-QA-132 entegrasyon kırmızıları (1329→1336/1339), K4 görüntü (i18n/prototip çakışmaları iki taraf korunarak; `ar.json` +16 anahtar farkı önceden vardı), E-09/K-06 performans, BR-AST-134.
  - **BR-AST-134 × BR-DB-126 sessiz hata:** iki dal `ProvisioningExtensionSource`'a birer `bool` ekledi; EF ifade ağacındaki konumsal `extension.DeskAutoAnswer` `VideoEnabled`'a düştü. Derleme 0 hata, 2386 birim test yeşil. Düzeltme: araya açık `false`; regresyon `ProvisioningExtensionFlagBindingTests` (gerçek PG, mutasyonla beklenen 1 / gelen 0). Hafızaya: `konumsal-bool-birlesmede-kayar`.
- **Santral imajı aslında eski çalışıyordu:** 13:50 yayınında yeni imaj exit 78 verince yayın betiği `.env`'i eski imaja geri almış; elle yeniden oluşturma da eskiyi açmış (BR-SEC-37 ölçümü yine doğruydu: yeni giriş betiği düşmeden önce host bind mount'a dosyaları yazmıştı). Doğru santral yayını gölgeleme kapısında durdu: host `pjsip.conf` IMAJ sınıfı dosyayı gölgeliyordu (içerik aynı) → host kopyası `/root/pbxtr-yedek/`e, imaj tohumladı; santral `b3f1bef3`, sapma bekçisi on iddia TAMAM, sır kapısı yeniden doğrulandı.
- **Yayınlar:** `demo-b3f1bef3b2e3` (compose önce kopyalandı: Panel dizesi `Max Auto Prepare=64;Minimum Pool Size=8`), santral `22-b3f1bef3b2e3`, `demo-48ff4e78ae1a` (BR-AST-134 migration).
- **E-09:** ölçüm aracına `E09_RPS` açık döngü kipi eklendi (gecikme planlanan andan; koordineli ihmal yok, `6f84f38e`). Sunucuda 20 işçi: 50/100/200 rps'te call-permission p99 12,9/14,7/39,3 ms, route-decision 11,6/11,2/8,9 ms; 300 rps'te tavan (311 ms). Kapalı döngü c=20 p99 93,8 ms = CPU doygunluğunda kuyruk. E-09 Bitti (`40bcdcb4`).
- **Backlog:** `a0ad351f` (11 kart yayında Bitti + BR-SYS-151), ClickUp yeni 3, `--kuru` fark 0. Açık satır ~140 → 71.
- **Komutlar:**
  ```bash
  python deploy/migration-compatibility-guard.py; python deploy/ci/capraz-kip-envanteri-kapisi.py --dondur
  python deploy/migration-agir-ddl.py --uret && python deploy/migration-agir-ddl.py --kapi
  scp pbxtr-demo/docker-compose.yml root@…:/root/ && ssh … install … && compose config -q
  bash deploy/yerel-yayin.sh --yayinla --testsiz [--santral]
  ssh … 'mv /etc/asterisk/pjsip.conf /root/pbxtr-yedek/…'   # IMAJ golgesi
  E09_RPS=200 bash /root/e09-sunucu.sh sonra 3000 20
  ```

## Kararlar
- E-09 ölçütü kapalı döngü azami hız değil, sabit hızda (açık döngü) p99: call-permission çağrı başına bir kez sorulur; 2 vCPU paylaşımlı sunucuda 200 rps'e kadar < 50 ms.
- Kalıcı kırmızı kapı kapı değildir: migration onayı ve çapraz kip envanteri ölçülüp donduruldu; gerekçe kapı dosyasında ve karar defterinde.
- Kamailio sır başlığı: IP ayrımı host süreçlerine karşı işe yaramaz (bridge adresine rootsuz süreç de bağlanır) → paylaşılan sır + dialplan kapı bağlamı; panelden originate (`Local/…@-out`) kapıdan geçmez, yalnız endpoint girişleri geçer.
- BR-AST-134 masa telefonu: Karar #46 nedeniyle NOTIFY yok → kuyruk üyesi INVITE'ına agent ayarına bağlı `answer-after=0`.
- Bekleyen-çağrı kapısında "kuyruk görünmüyor" iki ayrı durum: komut koştu ama kuyruk yok (yüklü değil → reload serbest) ve komut çıktı vermedi (ölçülemedi → ertele). Ayrım `queue show` çıktısında başka bir kuyruğun ya da `No queues.`'in varlığıyla yapılır.

## Açık kalanlar / sonraki adım
- BR-SYS-150: `sip.pbxtr.com` DNS'te yok; Cloudflare kimliği ne bu makinede ne sunucuda — DNS kaydını kullanıcı açmalı.
- BR-QA-133 canlı izolasyon senaryoları: kullanıcı kararı (kendisi koşar / Defense Access / kısmi bırakılır).
- BR-SEC-36: önce host'tan sahte INVITE ile ölçülmeli.
- BR-SYS-150 (SIP TLS sertifikası `sip.pbxtr.com`), BR-OPS-23 (host `pjsip.conf` gölgesi, santral imajı push edilmedi, compose elle kopyalanıyor), BR-OPS-24 (provisioning SipServer, RTP 0.0.0.0).
- BR-BE-291 veri işi.
- Sprint-50 kapanınca sprint-51 için kullanıcının "başla" demesi beklenir.

---

## Ek tur — backend-dev-1 worktree: BR-FE-140 / BR-BE-257 / BR-BE-258 / BR-BE-259

Dal: `worktree-agent-ac32c2707996329cd` (push edildi; ana dala birleştirme backend-lider'de).

### 1. BR-FE-140 + 257/259 onay satırları
- **Neden:** üç 2026-10-18 migration'ı (QaFormAnswerOptions, ScripterQueueCampaignAndContactExtra, ScriptStandalone) compatibility kapısında onaysızdı.
- **Ne yapıldı:** `deploy/migration-contract-onay.blobs` sonuna Karar#90 bloğu (`git hash-object` sha + yol). Sunucuda üçü `__EFMigrationsHistory`'de, `qa_evaluation_scores` 12 satır, `score>100` 0.
- **Commit:** `edd4efb4`.

### 2. BR-BE-259 — kampanya süzgeci
- **Ne yapıldı:** `script_responses.campaign_id` (nullable + kısmi indeks, migration `20261107100000_ScriptResponseCampaign`, yalnız EF AddColumn/CreateIndex). Rapor süzgeci: `CampaignId == c` VEYA (null ve kişinin kampanyası c).
- **Doğrulama:** mutasyon (süzgeç geri) → beklenen 3, gerçek 2 KIRMIZI. Sunucu entegrasyon (DooD) 24/24.
- **Commit:** `4035ec5c`.

### 3. BR-BE-257 — XLSX içe aktarma + dışa aktarmada serbest alanlar
- **Ne yapıldı:** `ContactImportXlsx.cs` (BCL ZipArchive + XmlReader, DTD yasak, entry başına okunan bayt sayarak 32 MB tavan, dosya 2 MB, 5000 satır, 64 kolon). Uç `Csv` ya da `Xlsx` (base64) alır. Export ek anahtarların birleşimini kolon olarak yazar (Redact'tan geçer). FE `ContactTransfer.tsx` .xlsx kabul eder; 9 dilde not.
- **Doğrulama:** 5 yeni test; zip-bomb mutasyonu (`MaxEntryBytes=long.MaxValue`) KIRMIZI. vitest 19/19, `tsc -b` 0.
- **Commit:** `b098d695`.

### 4. BR-BE-258 — Scripter faz 2 (fonksiyon/veri/REST/e-posta/alt-script/cevap raporu)
- **Ne yapıldı:** Domain'de `ScriptOperation` + doğrulayıcı + `ScriptSubscriptExpander`; Infra'da `ScripterRestSender` (OutboundHostGuard ön kontrol + ConnectCallback ile çözülen IP kontrolü = DNS rebinding savunması, 5 sn timeout, 64 KB yanıt, yalnız JSON, yalnız https/443), `ScriptOperationRunner`, `EfScripterRestConnectionStore` (sır ISecretProtector ile şifreli, `tenant_settings.scripter_rest_connections` jsonb, migration `20261107110000_ScripterRestConnections`). Uçlar: `GET/PUT /api/v1/scripts/rest-connections` (campaign.write + lisans; kaydetmede SSRF reddi IAuditSink ile denetime), `GET /api/v1/scripts/{id}/report/answers`. ADR: `doc/mimari/ADR-031-scripter-faz2-dugumleri.md`.
- **Kapı düzeltmesi:** `deploy/migration-agir-ddl.py` generic `AddColumn<T>`'yi görmüyordu → regex genişletildi, öz-test 12/12, defter 171→187 ad.
- **Doğrulama:** SSRF mutasyonu (ön kontrol kapalı) → 7 REST testi KIRMIZI, geri alınca 53/53. Sunucu entegrasyon (tam migration zinciri + RLS, iki tenant sızıntı testi dahil) 26/26 EXIT=0. Yeni DDL sunucu PG'de ROLLBACK'li ölçüm: üç DDL toplam 45 ms.
- **Takip düzeltmesi:** red testi yalnız IAuditLog'u değiştiriyordu, red satırı IAuditSink'e gidiyor → test yük altında boş koleksiyon gördü. Sink de yakalayıcıya bağlandı.
- **Commit:** `7f599cb2`, `659f2fec`.

### Test özeti
- Api.Tests (namespace parçalı): 1173 + 2366 (4 kırmızı → düzeltildi, Scripter 292/292) + 2421 (2 skip) + Platform/Health 1502.
- Architecture 857/858 — tek kırmızı `DecisionCodeManifestTests` (backlog.md'de "Bitti (2026-11-07 olc…" satırı, `8be692b6`; bu turun dışı, backlog'a dokunma yasağı).
- `dotnet format --verify-no-changes` rc=0. kapi_86 rc=0.
- Compatibility kapısı genel KIRMIZI: bu turun dışındaki 5 migration onaysız (TenantModulesAndExtensionLimits, PbxForwardingPickupFeatureCodes, PbxOutboundRoutesEmergencyPhonebook, PbxFieldFeatures, TelefonOutbox).

### Açık kalanlar
- BR-BE-258 FE (tasarımcı/koşucu, operations/computed/pressedActions, rapor ekranı) → BR-FE-141 ajanı.
- Gerçek SMTP/DNS/TLS ile REST/e-posta düğümü uçtan uca ölçülmedi; e-posta commit sonrası gider ama commit sonrası başarısızlıkta geri alınamaz; REST çağrısı istek transaction'ı içinde koşar.
- İşlemler kapanışta (closure) koşmaz; yalnız adım ilerlemesinde.
- `dat.csvFile` etiketi hâlâ "CSV dosyası" diyor.
