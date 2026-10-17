# pbxtr — 2026-10-17

## Bağlam
Menü matrisi 2026-10-16'da canlıya çıktı (`demo-e6f7e224da02`, bkz. `2026/10/16/pbxtr.md`).
Kullanıcı üç şey istedi: Lark SMTP/DKIM açıklaması, ekran × rol listesinin Excel'i (kendisi
düzenleyecek), bayi kısıtı için iş kartı.

## Yapılanlar

### 1. Lark SMTP ve DKIM ölçümü
- **Neden:** posta 535 dönüyor; DKIM selector bilinmiyordu.
- **Ölçüm (sunucudan `dig`):** `vuotech.com` MX = Lark (mx1/2/3.larksuite.com), SPF
  `v=spf1 +include:spf.onlarksuite.com -all` var. **DKIM yok:** 12 yaygın selector
  (`default s1 s2 lark larksuite larkmail feishu mail dkim selector1 google k1`) boş.
  **DMARC yok.**
- **Kullanıcıya:** Lark Yönetim Konsolu'nda üçüncü parti istemci izni + masaüstü uygulamada
  uygulamaya özel parola (*Settings → Mail → Third-party email client logon*); parolayı #68
  Posta Ayarları'na kendisi girer. DKIM TXT kaydını Lark *Mail → Domain*'den alıp DNS'e ekler,
  selector'ı bildirir → `/etc/pbxtr/mail-onkosul.env` `PBXTR_MAIL_DKIM_SELECTOR`.
  DMARC önerisi: `_dmarc` TXT `v=DMARC1; p=none; rua=mailto:info@vuotech.com`.

### 2. Rol × ekran Excel'i
- **Ne yapıldı:** `doc/rol-ekran-matrisi.md` (üretilmiş, canlıyla birebir) + `screens.json`
  (grup, route, sıra) → `C:\Users\abdus\Downloads\pbxtr-rol-ekran-matrisi.xlsx`.
  66 satır, 7 rol sütunu (1/boş, liste doğrulaması, sarı = düzenlenebilir), `COUNTIF` toplam
  satırı, "Notlar" sayfası (bilinçli sapmalar).
- **Betik:** scratchpad `matris-excel.py <repo> <çıktı>` (depoda değil; yeniden üretmek için
  aynı mantık: md tablosu + screens.json grubu).
- **Doğrulama:** satır başı sayım 29/28/8/40/37/5/2 = canlı `/api/v1/me/menu`. `recalc.py`
  Windows'ta koşmadı (`socket.AF_UNIX` yok); formüller basit `COUNTIF`, Excel açılışta hesaplar.

### 3. BR-SEC-33 — bayi çağrı merkezi işletemez
- **Kullanıcı:** *"bayi tenantinda cagri merkezi tenantindakileri yapamasin olmadi kendine bir
  tenant acsin oradan yonetsin"*.
- **Ölçülen bugünkü hâl:** bayi `user.impersonate` taşır; `ImpersonationRules.Check`
  (`src/Pbxtr.Domain/Platform/Identity/ImpersonationRules.cs`) single kapsamlı hedefe izin
  verir → bayi altındaki tenant'ın owner/süpervizör/agent'ı olarak her şeyi yapabilir;
  `tenant.write` + #53 drill-in de var.
- **Kart:** yalnız ticari yönetim (tenant kartı, limit, kullanıcı/rol, destek) kalsın;
  çağrı merkezi yetkileri bayi oturumunda ve taklitte 403; bayi kendi çağrı merkezi için kendi
  tenant'ını açar ve oradaki owner hesabıyla yönetir; kilit testleri.
- **ClickUp:** yeni kart açıldı, `--kuru` fark 0.
- **Commit:** `9e81e1c8`.

### 4. Deneme kullanıcıları
- `POST /api/v1/users` (demo.sahip ile, sunucu parolayı üretir ve bir kez döner):
  `deneme.agent` (agent), `deneme.supervizor` (supervisor); ikisi de giriş yaptı
  (`/agent`, `/live/queues`). Parolalar kullanıcıya verildi, depoya/günlüğe yazılmadı.
- Dahili 1048 açılamadı: `PROVISIONING_BLOCKED extensions.count out-of-range`
  (`ConfigRenderGuard.AssertAgentQuota`, tenant agent limiti 6). Bunun yerine dahili **1047**
  "1047" adlı test hesabından `deneme.agent`'a taşındı (`PUT /api/v1/extensions/{id}` + `If-Match` ETag).

### 5. Operatör lab — ikinci Asterisk + masaüstü arayıcı
- **Neden:** kullanıcı: *"sunucuya baska bir asterisk yukler misin … masa ustunden cagri
  gonderdigimizde muzik dinletelim … webden alabiliyor muyuz … trunk degerlerini girelim"*.
- **pbxtr-carrier:** `deploy/carrier-lab/carrier-kur.sh` (sunucuda root, `bash -s`). Aynı imaj
  `tekbirsoft/pbxtr-asterisk:22-736f570d6557`, `--entrypoint /usr/sbin/asterisk`, kendi config'i
  `/home/vuo/carrier/etc`; `pbxtr_ic` ağında `172.28.0.13`; SIP `100.106.82.119:5070/udp`,
  RTP `21000-21049` (yalnız Tailscale). Parola `/home/vuo/carrier/.env` `MASAUSTU_PAROLA`.
  Dialplan: `600` yerel test; diğerleri `PJSIP/${EXTEN}@to-pbxtr`; arayan `X-Arayan` başlığından.
- **pbxtr'a girilen değerler (API, demo.sahip):** trunk `operator-lab` host `172.28.0.13`
  (UDP, register yok, `ulaw,alaw`, `secretRef` zorunlu); DID `02122223344` → kuyruk 8001
  (`isActive` zorunlu). confd ~15 sn'de `t0007-trunk-operator-lab` + identify `172.28.0.13/32` kurdu.
- **Masaüstü arayıcı:** `deploy/carrier-lab/masaustu-arayici/` (.NET 10 WinForms, SIPSorcery
  10.0.17, NAudio 3.2.0; `SIPSorceryMedia.Windows` bu çerçeveyle uyumsuz → gelen ses NAudio ile).
  Kendi `Directory.Build.props`'u depo kökündekini keser. Yayın:
  `dotnet publish -c Release -r win-x64 --self-contained false -p:PublishSingleFile=true`
  → `C:\Users\abdus\Downloads\pbxtr-masaustu-arayici\MasaustuArayici.exe`.
- **Ölçüm (başsız test kabuğu, aynı `Telefon.cs`):** kayıt OK; `600` cevaplandı; DID çağrısı
  carrier → trunk → `route-decision=queue,t0007-musteri-hizmetleri` → `Queue(...)`, arayan
  `05551234567` ulaştı; kuyrukta üye yok → Ring. Hata bulundu ve düzeltildi: çalan çağrıda
  "Kapat" CANCEL göndermiyordu, çağrı kuyrukta kalıyordu → `SIPUserAgent.Cancel()`; tekrar ölçüldü,
  kuyruk boş.
- **Bulgular (kart):** `BR-AST-132` gelen DID→kuyruk çağrısı `[pbxtr-dialer]`'da
  `__PBXTR_DIR=out` ile eziliyor (`ConfigRenderer.cs:1132`); `BR-AST-133` trunk auth'ta
  `username` yok.
- **Commit:** `157e7332`.

## Kararlar
- Bayi altındaki tenantları işletmez; işletme kendi tenant'ında owner hesabıyla (kullanıcı).

## Açık kalanlar / sonraki adım
- BR-SEC-33 uygulaması.
- Kullanıcı testi: deneme.agent web'den girip 1047 WebRTC kaydıyla kuyruktan çağrıyı açacak
  ve müziği duyacak — **henüz ölçülmedi**.
- BR-AST-132 (yön), BR-AST-133 (trunk kullanıcı adı).
- Kullanıcının Excel'de yapacağı düzeltmeler → seed/screens'e işlenecek.
- KULLANICI: Lark uygulama parolası, DKIM kaydı + selector, DMARC; Yapilacaklar dosyasındaki
  parolayı silmek.
