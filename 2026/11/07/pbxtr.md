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

## Kararlar
- Bekleyen-çağrı kapısında "kuyruk görünmüyor" iki ayrı durum: komut koştu ama kuyruk yok (yüklü değil → reload serbest) ve komut çıktı vermedi (ölçülemedi → ertele). Ayrım `queue show` çıktısında başka bir kuyruğun ya da `No queues.`'in varlığıyla yapılır.

## Açık kalanlar / sonraki adım
- BR-SYS-150: `sip.pbxtr.com` DNS'te yok; Cloudflare kimliği ne bu makinede ne sunucuda — DNS kaydını kullanıcı açmalı.
- BR-QA-133 canlı izolasyon senaryoları: kullanıcı kararı (kendisi koşar / Defense Access / kısmi bırakılır).
- BR-SEC-36: önce host'tan sahte INVITE ile ölçülmeli.
- BR-SYS-150 (SIP TLS sertifikası `sip.pbxtr.com`), BR-OPS-23 (host `pjsip.conf` gölgesi, santral imajı push edilmedi, compose elle kopyalanıyor), BR-OPS-24 (provisioning SipServer, RTP 0.0.0.0).
- BR-BE-291 veri işi.
- Sprint-50 kapanınca sprint-51 için kullanıcının "başla" demesi beklenir.
