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

### BR-SEC-41 — iki butunluk sorusu olculdu ve kapatildi
- **Neden:** QA-138 son turunda "olculmedi" diye acilan kart: izin takviminin userId'si ve RingGroup yedek hedefleri tenant'a ait mi?
- **Olcum (canli DB, salt okuma):** `pg_constraint` -> `agent_leaves`'te yalniz `tenant_id` FK'si var, **`user_id`'de FK YOK**; `ring_groups`'ta `(tenant_id, fallback_queue_id)` ve `(tenant_id, fallback_extension_id)` bilesik FK'leri var. SQL'i ssh'a heredoc ile degil dosyadan `psql -At < sec41.sql` ile verdim (`$$` kabukta PID'e donusmustu).
- **Ne yapildi:** `ILeaveCalendar.IsTenantUserAsync` (users global, HomeTenantId kosulu) + `POST /api/v1/leaves` once bunu sorar, degilse 404 (yok/baska tenant ayni cevap). RingGroup'a kod degisikligi yok — DB reddediyor.
- **Dokunulan dosyalar:** `src/Pbxtr.Domain/Modules/Leaves/ILeaveCalendar.cs`, `src/Pbxtr.Infrastructure/Modules/EfLeaveCalendar.cs`, `src/Pbxtr.Api/Modules/Leaves/LeaveEndpoints.cs`, `tests/Pbxtr.Api.Tests/Modules/Leaves/LeaveEndpointTests.cs`, `tests/Pbxtr.Integration.Tests/Tests/TenantSettingsAdaptersTenantLeakTests.cs`
- **Sonuc / dogrulama:** Api Leaves 25/25; Integration leave testleri 5/5; mutasyon (tenant kosulu silindi) -> "SIZINTI ... users.IsTenantUserAsync" KIRMIZI, geri -> yesil.
- **Commit:** `e60e3707`, backlog `4172c5d1`. ClickUp fark 0.
- **Not:** yerel bellek ~5 GB bos (msedgewebview2 ~20 GB); yayin 50fa1f81+e60e3707 hala bekliyor.

### BR-SYS-148 — sysagent ile Asterisk dugumu baslat/durdur (ajan isi, birlestirildi)
- **Neden:** #80 yasam dongusu (BR-BE-287) yeni dugumu (ast-02...) ayaga kaldiramiyordu; BR-QA-135'in on kosulu.
- **Ne yapildi (linux-uzmani ajani, 6396ee5f, main'e fast-forward):** `src/Pbxtr.SysAgent/AsteriskNodeLifecycle.cs` (sabit docker run sablonu, ad kalibi ast-02..99 + root defteri `/etc/pbxtr/asterisk-nodes.json`, sirlar --env-file 0600, imaj = ast-01'in icerik kimligi, yalniz etiketli konteyner, durdurmada aktif kanal kapisi), katalog AN-01/AN-02 (yalniz #80, paletten 409), uc `POST /system/telephony-cluster/nodes/{name}/runtime`. Belgeler: sysagent README kurulum adimlari, ADR-014 §2.10.5, ADR-023 §8.6/D.
- **Kararlar:** imaj sabit etiket degil ast-01'in icerik kimligi (etiket her yayinda degisiyor); uc iki yetki ister (telephony.cluster.manage + system.command.run).
- **Dogrulama (main'de):** build 0 hata; Architecture ilgili 114/114; Api TelephonyCluster/SystemOps/CommandCatalog 103/103; kapali liste paritesi temiz. Ajan: 54/54 yeni test, 8 mutasyon kirmizi (biri gercek acik: .NET `$` sondaki \n'i kabul ediyordu).
- **Backlog:** BR-SYS-148 Bitti (kurulum bekliyor), yeni BR-FE-151 (#80 dugmesi). Commit `dc152aef`. ClickUp fark 0.
- **Sunucu:** KURULMADI. Yayin (50fa1f81..dc152aef) + ajan ikilisi kurulumu yerel bellek bosalinca birlikte.

### BR-FE-151 — #80 Baslat/Durdur dugmesi (frontend-junior ajani, birlestirildi)
- **Ne yapildi:** `telephonyClusterApi.ts` runClusterNode; `telephonyClusterView.ts` nodeRuntimeActions (sunucu kuraliyla ayni) + runtimeProblemMessage (409 default_node/runtime_state_not_allowed/cikis 75, 503 agent_unavailable); `TelephonyClusterNodes.tsx` dugmeler + TransitionDialog -> ConfirmNodeDialog genellemesi; denetim etiketi + 9 dil i18n.
- **Dogrulama (main'de):** `npx tsc -b` temiz; `npx vitest run TelephonyClusterScreen auditActionParity` 27/27. Ajan: mutasyon (isDefault kontrolu) kirmizi.
- **Commit:** `2a0e66b2` (merge ff), backlog ayri commit. ClickUp fark 0. Sunucuya yayin bekliyor.

### BR-SYS-147 — Asterisk dugum paketi (linux-uzmani ajani, birlestirildi)
- **Neden:** dialplan'siz bir dugum saglik kapisini (ARI + systemname) gecip `aktif`'e alinabiliyordu; ast-02'nin confd ve edge'i yoktu. BR-QA-135 ve BR-AST-157'nin on kosulu.
- **Ne yapildi (e56e53b5):** AN-03 `asterisk-node-health` (yalniz show: pjsip endpoint sayisi, pbxtr-tNNNN baglam sayisi, edge 8790) -> aktif gecisinde 409 health_gate_failed / health_unmeasured; AN-01/AN-02 edge + edge-fastagi yan arabalarini da yonetir; `deploy/pbxtr-confd/pbxtr-confd@.service/.timer` dugum basina confd. Koordinator: `confd-privilege-kapisi.py` hicbir kapidan cagrilmiyordu -> `yerel-kapilar.sh` kapi_70'e eklendi (yalniz ana birimi okur; sablonu ConfdNodeTemplateUnitTests olcer).
- **Dogrulama (main, merge 63c95d7d):** build 0 hata; Architecture ilgili 171/171; Api TelephonyCluster/SystemOps/CommandCatalog 113/113; parite temiz; confd-privilege OK; vitest TelephonyClusterScreen 20/20. Ajan: Architecture 1002/1002, 8 mutasyon kirmizi.
- **Backlog:** BR-SYS-147 Bitti (kurulum bekliyor), yeni BR-SYS-154 (kayit tasiyici), BR-SYS-155 (FastAGI yoklamasi + esik). Commit `5753d5d0`. ClickUp fark 0.
- **Sunucu kurulum sirasi:** `deploy/pbxtr-sysagent/README.md` "Kurulum sirasi" — yayin + ajan ikilisi + defter/env + edge kimlik dizini + confd@ birimi; ilk gercek kosu BR-QA-135.

### BR-SYS-155 + BR-AST-168 — FastAGI saglik yoklamasi + confd semantik dogrulama toplu (linux-uzmani ajani)
- **Ne yapildi (2e1dc0da, main'e ff):** AN-03'e 4573 yoklamasi (cikis koduyla okunur, belirsiz = olculemedi), dialplan esigi parametrik (alt sinir 1). confd semantik dogrulama: tek `ast endpoint-details` (stdin ad listesi, kapali kalip) + tek `queue show` + tek awk; observe sarmalayicisinda tek docker exec + xargs sabit sablon, kabuk yok. helper-selftest ve ayrac-selftest `yerel-kapilar.sh` kapi_70'e baglandi.
- **Olcum (ajan, confd-boyut-olc):** N=50 docker 448 -> 50, uretim T 151 -> 62 sn, tavan ~61 -> ~253 tenant/dugum; gercek santralde 310 ad 5,3 sn, cikti eski yolla bayt bayt ayni.
- **Dogrulama (main):** kapi_70'in 5 adimi rc=0 (parite, parite oz-test 9/9, privilege, helper, ayrac 14/14); build 0 hata; Architecture ilgili 175/175; Api TelephonyCluster 41/41. Windows tam confd selftest arka planda.
- **Backlog:** BR-SYS-155, BR-AST-168 Bitti (yayin bekliyor). ClickUp fark 0.

### BR-AST-169 — IVR tahsilat santral tarafi (backend-dev-2 ajani) + Karar#94
- **Neden:** M-05/M-09'un eksik yarisi: IVR'da tahsilat dugumu, kayit susturma, hanelerin isleyiciye tasinmasi.
- **Kritik olcum (ajan, sunucuda salt-okur):** AMI kullanicisinin okuma izni `dialplan` sinifini tasiyor -> ADR'deki `Read()` her degeri `VarSet` olayiyla AMI'ye DUZ METIN yayardi. Tasarim degisti: haneler Stasis oturumunda ARI tus olaylarindan toplanir. (Ders: "belge santral degildir" -- ADR'nin adimi olculunce PCI ihlali cikti.)
- **Ne yapildi (e9ff8e45, merge c4edab39):** IVR tipi `payment` + migration `20261108120000_IvrPaymentNode`; ConfigRenderer: sonuc bosalt -> StopMixMonitor -> TryExec(Stasis(pbxtr,pbxtr-pay)) -> MixMonitor(ab) -> yalniz approved onay dalina (fail-closed); `AriIvrPaymentSessions` + AriStasisApp devri; editor + 9 dil.
- **Koordinator karari:** migration-compatibility-guard CHECK DROP/ADD'de kirmiziydi; yeni yuklemler ust kume, emsal Karar#59/#91 -> **Karar#94** `yonetim/kurul-kararlari.md` + `deploy/migration-contract-onay.blobs` (blob 3617bcc3). Commit `3edb1a5f`.
- **Dogrulama (main):** guard OK (ONAYLI Karar#94), agir-ddl paritesi 198, capraz-kip iki kapi OK, st44 revizyonu IvrPaymentNode; build 0 hata; Architecture 1020/1020; Api Ivr/Payment/Stasis 259/259; Integration EnumMirror/FinalDelivery/IvrTenantLeak 132/133; tsc -b temiz; vitest 58/58. Ajan: 9 mutasyon kirmizi.
- **Backlog:** BR-AST-169, M-05, M-09 Bitti (yayin bekliyor); yeni BR-QA-139 (canli tahsilat cagrisi + app_data + CHECK red testi). ClickUp fark 0.

### BR-AST-157 — confd havuz paketi (linux-uzmani ajani) + iki dogrulama notu
- **Ne yapildi (bd75e0bb, main'e ff):** `ProvisioningNodePool` (saf sinif): Mode=on + kayitli dugum -> kumedeki tum tenant'larin dialplan + sesi; node-bundle/media/rapor ayni kume; saglik esigi = teslim kumesi boyutu. Kurul #77 pin kapisi: kayitli dugumun sakinleri = tum kume (yeni bos ast-02'ye tenant sahibinin pinleyip tum dialplan'i cekme acigi kapandi; entegrasyon mutasyonu 201 ile kanitladi).
- **Dogrulama (main):** build 0 hata; Api Provisioning/TelephonyCluster/ApiKey 371/371; capraz-kip iki kapi OK. Ajan: Integration (sunucuda gercek PG) 28/28, confd selftest 409/409, 8 mutasyon.
- **Olcum notu 1 — Architecture 1018 goruldu:** main oncesi 1020'ydi. `--list-tests` iki commit'te ayni; d9fb2827 gecici worktree'de derlenip ikisi TRX ile kosuldu -> ikisi de **1020/1020**, vaka adlari birebir ayni. 1018 eksik kalmis bir kosuydu (olcum kaybi), gerileme degil. Komut: `git worktree add <tmp> d9fb2827` + `dotnet test ... --logger trx` + `grep -o testName= | sort | diff`.
- **Olcum notu 2 — BR-AST-168 Windows:** tam confd selftest Windows'ta 408/408 (Linux 409; fark Linux'a ozgu izin kapisi, onceki 394/395 ile ayni desen).
- **Backlog:** BR-AST-157 Bitti (yayin + Mode=on gecisi bekliyor), yeni BR-BE-294 (teslim damgasi okuyuculari dugum basina tabloya). ClickUp fark 0.

### BR-SYS-154 — kayit spool bosaltma (backend-dev-2 ajani)
- **Olcum kart onculunu duzeltti:** ast-01'de MinIO'ya tasima zaten calisiyordu (RecordingTransferJob; sesi olan 9/9 dosya kovada + recording_assets). Eksik: spool'dan silme. (Ders: kart onculu olculmeden yazilmaz.)
- **Ne yapildi (ac087da0, main'e ff):** RecordingSpoolPurgeJob (kilit 47, ARI GET/DELETE recordings/stored), bes fail-closed kapi (tenant, source_ref, tenant onekli depo + ozet, spool SHA-256, >=360 dk), varsayilan kip `report` (silmez); ast-02 kayitlari kendi dugumunun ARI'sinden aktarilir.
- **Dogrulama (main):** build 0 hata; Api Recording 235/235; Architecture RawSql/BackgroundJob/Audit/TenantLeak 44/44; capraz-kip iki kapi OK; tsc -b; vitest auditActionParity+AuditScreen 19/19 (ajanin worktree'sinde node_modules yoktu, ben kostum). Ajan: 8 mutasyon kirmizi.
- **Devreye alma:** yayin -> report kipinde bir dongu (beklenen silinebilir 9) -> `PBXTR_RecordingStorage__SpoolPurgeMode=delete`.
- **Backlog:** BR-SYS-154 Bitti, yeni BR-SYS-156 (kayip kayitlar: CDR billsec>0 ama dosya/satir yok + bos 44 B WAV karari). ClickUp fark 0.

### BR-SYS-156 — "kayip kayitlar" olculdu: hata yok (backend-dev-2 ajani)
- **Bulgu:** CDR billsec>0 + dosyali 28 cagrinin 8'i aktarilmis; 20'si 10-24 ve 10-25 test temizliklerinde BILEREK silinmis (bu Gunluk'teki 2026/10/24 ve 2026/10/25 kayitlari birebir dogruluyor). CDR satirlari salt-okur Asterisk DB'de kaldi. (Ders: gunluk "yeniden yapilabilir tarif" oldugu icin kanit oldu.)
- **Ne yapildi (c96226bf):** kod duzeltmesi yok; `doc/mimari/br-sys-156-kayip-kayitlar-ve-bos-wav-olcumu.md`. Bos 44 B WAV icin RecordingSpoolPurgeJob'a fail-closed dal (CDR'da billsec>0 yok + >=24 sa + kanonik bos baslik), varsayilan kip report.
- **Dogrulama (main):** build 0 hata; Api Recording 248/248; Architecture ilgili 44/44; Integration SpoolLedger 2/2; capraz-kip iki kapi OK. Ajan: 7 mutasyon kirmizi.
- **Backlog:** BR-SYS-156 Bitti; yeni BR-SYS-157 (gercek kayip bugun iz birakmaz -> alarm). ClickUp fark 0.
