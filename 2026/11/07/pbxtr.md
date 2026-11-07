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

## Ek tur — K-05 PITR canlıda, yedek kapsamı, realtime birleşmesi (16:30–17:15Z)

### 1. K-05 — PostgreSQL WAL arşivi + haftalık taban yedek
- **Neden:** Ayrı konteyner tatbikatı tam yedekten geri yüklemeyi kanıtladı (281 sn, migration 263=263, policy 145, RLS tablo 121, rol 7). Ama sunucuda `archive_mode=off` idi: RPO 24 saatti ve "dün 14:05'e dön" yapılamıyordu.
- **Ne yapıldı:**
  - `pbxtr-demo/docker-compose.yml` postgres servisi: `archive_mode=on`, `archive_command=/usr/local/bin/pbxtr-wal-arsivle %p %f`, `archive_timeout=300`, ayrı `walarchive` hacmi.
  - Giriş noktası `install -d -o postgres ... /walarchive/wal && exec docker-entrypoint.sh "$$@"`. Gerekçe: adlı hacim, imajda olmayan bir yola bağlanınca root:root oluşur ve postgres arşive yazamaz.
  - `pbxtr-demo/postgres/pbxtr-wal-arsivle.sh`: zstd sıkıştırır, var olan dosyanın üstüne yazmaz (içerik aynıysa 0, farklıysa 1 döner), atomik rename yapar.
  - `deploy/pbxtr-taban-yedek.sh` + `.service`/`.timer` (Cumartesi 03:30):
    - `pg_basebackup -Ft -z -X none` ile `/walarchive/base/<damga>` dizinine yedek alır.
    - Yedeğin `.backup` dosyası arşive düşene kadar bekler (en çok 120 sn); düşmezse temizlik yapmaz ve exit 1 verir.
    - En yeni 2 taban yedeği tutar; `pg_archivecleanup -x .zst` ile eski WAL'ı kırpar.
  - `deploy/pbxtr-yedek-kur.sh` ESLEME tablosuna ve timer döngüsüne eklendi.
- **Komutlar:**
  ```bash
  # once compose (bellek: zorunlu-env-once-compose); sunucu compose HEAD ile birebir oldugu once olculdu
  scp pbxtr-demo/docker-compose.yml root@176.88.41.220:/home/vuo/pbxtr-demo/
  scp pbxtr-demo/postgres/pbxtr-wal-arsivle.sh root@...:/home/vuo/pbxtr-demo/postgres/
  docker compose up -d --no-deps postgres          # 16:41:19 -> healthy 16:41:28 (~9 sn)
  psql -c "select archived_count, failed_count from pg_stat_archiver"   # 1|0, sonra 5|0
  systemctl start pbxtr-taban-yedek.service; systemctl enable --now pbxtr-taban-yedek.timer
  ```
- **PITR kanıtı:** canlı arşivden alındı, atılır `pitr-dene` konteyneri ve hacmi temizlendi.
  - `postgres` DB'ye `pitr_isaret` tablosu açıldı. Önce `once` satırı yazıldı, sonra T alındı, ardından `sonra` satırı yazıldı.
  - Taban yedek açıldı; `recovery_target_time=T` ve `restore_command='zstd -dq /walarchive/wal/%f.zst -o %p'` verildi.
  - Sonuç: geri dönen yalnız `once` oldu (`recovery stopping before commit`), migration 263. İşaret tablosu canlıdan silindi.
- **Ders:** işaretsiz ilk deneme `recovery ended before configured recovery target was reached` ile düştü. Hedef an, arşivdeki son işlemden SONRAYA düşmüştü. PITR ölçümünde hedefin iki yanına işaret commit'i konmalıdır.
- **Commit:** `8346db39` — K-05: PostgreSQL WAL arsivi + haftalik taban yedek (PITR) canlida

### 2. Açıkta kalan dökümler
- `/var/backups/pbxtr/pre-6fe97e63-20260918-062224.dump` ve `pbxtr-20260822-154728.dump` silindi. İkisi de şifresiz ve 0644'tü (dizin 0700 olduğu için dışarıdan okunmuyordu). Bugün şifreli gece yedekleri var.
- `pjsip-elle-*`, `br-ast-128-*` ve `asterisk-spool-*`: `chmod -R go-rwx`.

### 3. BR-SYS-153 — gece yedeği Asterisk CDR veritabanını almıyordu
- **Neden (ölçüldü):** `pbxtr-asteriskcdrdb` konteyneri ayrı bir PostgreSQL. Ne hacim listesinde ne pg_dump'ta vardı, yani CDR'ın mutabakat kaynağı yedeksizdi.
- **Ne yapıldı:**
  - `deploy/pbxtr-yedek.sh` içine `ek_pg_dokumleri()` eklendi. `PBXTR_YEDEK_EK_PG=konteyner/db,...` listesindeki her veritabanı için `docker exec pg_dump -Fc` alır ve aynı gpg ile şifreler.
  - Döküm aynı koşuda `pg_restore --list` ile geri okunur. TABLE DATA sayısı 0 ise koşu BAŞARISIZ yazılır.
  - Drop-in'e `PBXTR_YEDEK_EK_PG=pbxtr-asteriskcdrdb/asteriskcdrdb` eklendi.
- **Sonuç:** 17:07Z koşusu `Result=success` ve `ek dokum ... 2 tablo verisi, 110511 bayt` yazdı.
- **Bilinçli dışarıda:** `pbxtr_telefon`. Türetilmiş bir veritabanı; projeksiyondan yeniden kurulur.
- **`wf_veri_ops11`:** BR-OPS-11 `lock_timeout` ölçümünden kalmış sentetik veritabanı. İçinde `call_attempts` 200000 satır ve boş migration geçmişi vardı, bağlantı 0'dı. `drop database` ile silindi.
- **Ders:** oneshot systemd servisi çalışırken `activating` durumundadır. Bu yüzden `until ! systemctl is-active` döngüsü hemen çıkar; doğru koşul `ActiveState=activating` iken beklemektir.
- **Commit:** `f1043820`

### 4. BR-AST-156/157 birleştirildi (ajan dalı `8ade60c4`)
- Realtime: `ps_endpoints/ps_aors/ps_endpoint_id_ips` ve `queues` artık `pbxtr_telefon`'dan okunuyor. Satırlar renderer çıktısının ayrıştırılmasıyla üretiliyor.
  - Kip ayarı `Telephony:Realtime:Mode` = off/shadow/on.
  - R1 ölçümünden dolayı önbellek süresi 0.
  - R2 ölçümünden dolayı `tcp_user_timeout=1500` ve `PGCONNECT_TIMEOUT=2`.
- **Çakışma:** ADR-023'te iki dal da §9 numarasını almıştı. Realtime'ın 45 atfı, K4'ün 10 atfı vardı; bu yüzden realtime §9'da kaldı, K4 §10 oldu. K4 atıfları yedi dosyada güncellendi.
- **Doğrulama:** solution build 0 hata. Pending model değişikliği yok. Architecture 892/892, Api (Provisioning|Telefon|Platform) 2036/2038 (2 atlandı). `dotnet format` 0, `tsc -b` 0.
- **Commit:** `bf5e3978` (merge), yayın: `deploy/yerel-yayin.sh --yayinla --testsiz --santral`.

### Yeni kartlar
- **BR-SYS-152:** yedekler sunucu dışına kopyalanmıyor.
- **BR-SEC-39:** ARI ile `contact` yazılabiliyor (astdb).
- **BR-AST-165:** teslim onayı (tenant × düğüm) başına tutulmalı; havuz paketinin önkoşulu.
- **BR-OPS-25:** `confd-boyut-olc.sh` exit 69 veriyor.
- K-05, ST-08 ve BR-SYS-153 **Bitti**; AST-156/157 **Devam**.

## Ek tur — backend-dev-1 worktree (agent-a980506b47610e081): M-04 / O-05 / BL-LIC-02 / BL-LIC-03 / S24-3

Dal: `worktree-agent-a980506b47610e081` (push edildi; main'e birlestirme ve backlog satirlari ust ajanda).
Kararlar: `doc/mimari/ADR-024-backlog-kapanis-2026-11-07.md`.

### 1. M-04 + BL-LIC-02 + BL-LIC-03 — commit `d4e7d020`
- **M-04:** `campaigns.callback_interval_minutes` (NULL = tenant `auto_callback_interval_minutes`), cozum kampanya > tenant > varsayilan (`CallbackPolicy.ResolveInterval`); `callback_entries.campaign_id` kayitta kuyrugun kampanyasindan kopyalanir. Migration `20261107135159_CampaignCallbackInterval`. #30 kampanya formunda alan.
- **BL-LIC-02:** `locked` kademede muaf olmayan GET de 403 + denetim; kimlik/menu/ws/lisans/cari `[LicenseExempt]` kapali liste (11 rota). Kill switch + aktif cagri korumasi aynen.
- **BL-LIC-03:** kisitli kipte dialer preview (`DialerLicensePolicy`, `DialerCallDispatcher.ApplyLicenseModeAsync`), gecis basina denetim + canli alarm, #30 serit. Migration `20261107140549_DialerLicensePreview`.

### 2. S24-3 — commit `874bf65e`
- `departments` + `department_members` (RLS, bilesik FK; kullanici uyeligi `users(id, home_tenant_id)`), uclar `/api/v1/departments` (`department.read/write`, bundle.user), #02 bolumu, #23 departman kirilimi (borc notu kalkti), manifest `telephony.department` enforced. Migration `20261107142901_Departments`.
- Altin listeler: owner 103, supervizor 84, tenant isletme 87. Entegrasyon sizinti testi (RLS + FK + EF + bayi baglami) gercek PG'de yesil.

### 3. O-05 — commit `64b639c8`
- `tenant_storage_quotas` (satir yok = kota yok). `tenants` kolonu denendi: gercek PG `42501` (Karar #64 kolon bazli UPDATE yetkisi) -> ayri RLS'li tablo. Migration `20261107160318_TenantStorageQuotas`.
- `GET /api/v1/storage`, `PUT /api/v1/storage/quota` (tenant.license + global), yukleme kapisi 507 `STORAGE_QUOTA_EXCEEDED`, ses kaydi aktarimi atlanir (cagri etkilenmez), #34 kota cubugu.

### Test ozeti
- Api.Tests: Platform 1554/1557 (3 skip), Modules iki parca 1921 + 3414 yesil (tek parca kosu 15. dakikadan sonra yuk altinda 133 sahte kirmizi verdi — parcalayinca hepsi yesil).
- Architecture 880 (son kosu: 4 kirmizi duzeltildi, hedefli tekrar yesil). FE tsc -b temiz, vitest 2542/2542.
- Integration (Docker, tam zincir): 1329 gecti; kalan kirmizilar ONCEDEN VAR (audit_log/cdr bolum yok, BackgroundJobLocks, FinalDelivery kanonik revizyon, EnumMirror'da baskalarinin 6 CHECK'i).
- Mutasyonlar: departman HomeTenantId + tasima; O-05 kapi, atlama, IgnoreQueryFilters, purged filtresi — hepsi yakalandi.

### Acik kalanlar
- Kota yazma ekrani yok (uc hazir). Platform/bayi destek eki ve sesli mesaj kotaya takilmaz (bilinçli).
- `deploy/migration-compatibility-guard.py` main'de onceden kirmizi (onaysiz eski migration'lar); yeni dort migration bulgu uretmiyor.

## Ek tur — realtime canlıda `on`, birleştirmeler, kritik sızıntı (17:20–19:30Z)

### 1. BR-AST-156 — Asterisk realtime canlıya alındı (ADR-023 §9.6 kesme sırası)
- **Adımlar (sunucu 176.88.41.220):**
  1. `deploy/telefon-db/kur.sh --konteyner pbxtr-postgres`. 02c tabloları + yetkiler kuruldu. PBXTR_TELDB_* değişkenleri .env'den basılmadan yüklendi.
  2. Compose'a santral `PBXTR_REALTIME/PBXTR_DUGUM/PBXTR_TELDB_HOST/PBXTR_TELDB_ASTERISK_PASSWORD`, uygulama `PBXTR_Telephony__Realtime__Mode` eklendi. `.env`: `PBXTR_REALTIME=true`, `PBXTR_DUGUM=ast-01`, `PBXTR_REALTIME_MODE=off`. `up -d --no-deps asterisk`, ardından edge'ler yeniden katıldı. `realtime show pgsql status`: Connected. S8 YALNIZ SELECT.
  3. `PBXTR_REALTIME_MODE=shadow`, app yeniden yaratıldı. `docker exec pbxtr-app dotnet Pbxtr.Api.dll telefon-projeksiyon yeniden-kur` → **KeyNotFoundException**. Aynı komut `-e PBXTR_Telephony__Realtime__Mode=off` ile yeşil (8 tenant, 43 satır); hata realtime yolunda.
     - **Kök:** `TelefonKaynakOkuyucu` sorgusu `GroupBy(Kind).Select(g => g.OrderByDescending().First()).Select(new{..})`. EF Core bunu `'EmptyProjectionMember'` KeyNotFound hatasıyla çeviremiyor. Sorgu tür başına tek satırlık iki sorguya bölündü.
     - Yeni `TelefonKaynakOkuyucuRealtimeTests` gerçek PG'de koşuyor: eski sorguyla aynı istisnayla KIRMIZI, düzeltmeyle yeşil. Önceki realtime testleri kaynağı elle kurduğu için bu sorgu hiç koşmamıştı.
     - CLI artık yığın çerçevelerini de basıyor (istisna mesajını basmıyor).
     - Yayın `81af581d` sonrası shadow'da yeniden-kur 110 satır yazdı. Parite birebir: 31 tenant endpoint = 31 `ps_endpoints`, 3 kuyruk = 3 `queues`.
  4. Yeni confd kuruldu, `PBXTR_REALTIME_MODE=on`. İlk tur kanarya t0007 oldu: pjsip mezar taşı yazıldı, ama queues **"BEYANSIZ KUYRUK KAYBI -> general"** ile durdu.
     - **Kök:** mezar taşı tenant parçasının `[general] persistentmembers=no` satırını da düşürüyor. Bu davranışı değiştirmez, çünkü imajın ana `queues.conf`'u `persistentmembers = no` diyor ve tenant parçalarından önce okunuyor. Ama kayıp kapısı `general`'i kuyruk sanıyordu.
     - Düzeltme `pbxtr-confd-dugum.sh`'ta. Öz-test F66 canlı defter biçimini (`general` satırı dahil) kullanıyor, M50 mutasyonu eklendi; 356/356.
     - Öz-testin fikstür defteri `general` taşımadığı için kapı bu durumu hiç görmemişti.
  5. Ertelenen tür sonraki turlarda 304 aldı. Bu ayrı bir kusur, BR-AST-166 olarak kartlandı. `state.json` etag'i boşaltılınca tam teslim gerçekleşti; üç tenantın pjsip ve queues dosyaları mezar taşına döndü (0 bölüm), `queue reload` koştu.
- **Doğrulama:**
  - Endpoint 31 ve kuyruk 3, ikisi de realtime'dan geliyor.
  - Üyelik `QueueMembershipSyncJob` ile yaklaşık 1 dk'da geri geldi: 12 üye, kesmeden önceki sayı.
  - S1–S10 yeşil.
  - Gerçek telefonla test çağrısı yapılmadı; kayıtlı cihaz yok.
- **Commit'ler:** `240b898d` (okuyucu + compose + env şablonu), `bd93b6eb` (confd general + bayat bekçiler).

### 2. Birleştirilen ajan dalları
- `81af581d`: BR-BE-292 (kuyruk dışı çağrıda CDR agent) ve BR-QA-137. Kök neden ürün kusuruydu: `idle_in_transaction_session_timeout=15s` aşılıyordu. RawSqlAllowlist 7→8 kabul edildi.
- `efcbe5f9`: M-04, O-05, BL-LIC-02/03, S24-3 (ADR-024).
  - i18n JSON çakışmaları iki taraf da korunarak çözüldü, mükerrer anahtar yok.
  - `doc/ekran-yazma-yollari.md` `PBXTR_WRITE_DOCS=1` ile yeniden üretildi.
  - `migration-agir-ddl.py --uret` → 194 ad.
- **QA-138:** **KRİTİK SIZINTI.** `EfAnalyticsQuery.GetQueueSlaAsync` içindeki üç ham SQL'de tenant koşulu yoktu. RLS'nin bayi dalı aktif tenant'ı denetlemediği için bayi kullanıcısı, kendi altındaki tüm tenant'ların kuyruk ve CDR sayılarını görüyordu. Düzeltme yayında: `demo-bd93b6eb`. 40/65 adaptör iki-tenant testli.
- **Bekçi tazelemeleri:**
  - EnumMirror'a 3 CHECK eklendi (telephony_nodes.state, node_affinity.object_kind, conference_rooms.video_mode).
  - st44 kanonik raporu ve insan raporunun şema revizyonu güncellendi.
  - TenantLeakCoverage genel borç tavanı 51→50→53 (BE-285'in üç yeni yüzeyi gerekçeli kayıt).
- `df249e6d`: BR-BE-285 çok düğümlü sağlayıcı.
  - ADR §8.4, §9 realtime bölümünden önceye kondu.
  - **Karar #92:** `call_events.node DROP DEFAULT`. Migrate ile app arasındaki ~10 sn'lik pencere CEL mutabakatıyla kapanıyor; Down mevcut.
- BR-BE-293 (ADR-032, tek sayım tanımı + `cdr-terk-geri-doldur`) birleştirildi.
  - DROP DEFAULT sonrası QA-138 ve BE-293 test fikstürleri 23502 verdi; `node` damgası eklendi.
  - **Ders:** `Sla*` sınıfları `node` sütunu olmayan ayrı bir şema fikstüründe koşuyor. Aynı yamayı onlara uygulamak 29 kırmızı (42703) üretti ve geri alındı. Fikstürleri körlemesine yamamadan önce hangi şemaya yazdıklarını ölç.

### 3. Yayın öncesi dökümlere rotasyon
- `staging-yayin.sh`: en yeni 10 `pre-*.dump` tutulur. Sunucuda 75 döküm (2,2 GB) birikmişti; 10'a indirildi (541 MB). Commit `4cee1d66`.

### Yeni kartlar
- BR-SEC-40: alarm_rules.queue_id tenant denetimi yok.
- BR-AST-166: confd'de ertelenen tür 304'te kalıyor.
