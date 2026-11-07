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

## Kararlar
- Bekleyen-çağrı kapısında "kuyruk görünmüyor" iki ayrı durum: komut koştu ama kuyruk yok (yüklü değil → reload serbest) ve komut çıktı vermedi (ölçülemedi → ertele). Ayrım `queue show` çıktısında başka bir kuyruğun ya da `No queues.`'in varlığıyla yapılır.

## Açık kalanlar / sonraki adım
- BR-QA-133 canlı izolasyon senaryoları: kullanıcı kararı (kendisi koşar / Defense Access / kısmi bırakılır).
- BR-SEC-36: önce host'tan sahte INVITE ile ölçülmeli.
- BR-SYS-150 (SIP TLS sertifikası `sip.pbxtr.com`), BR-OPS-23 (host `pjsip.conf` gölgesi, santral imajı push edilmedi, compose elle kopyalanıyor), BR-OPS-24 (provisioning SipServer, RTP 0.0.0.0).
- BR-BE-291 veri işi.
- Sprint-50 kapanınca sprint-51 için kullanıcının "başla" demesi beklenir.
