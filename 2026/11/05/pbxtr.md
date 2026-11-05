# pbxtr — 2026-11-05

## Bağlam
Kullanıcı talebi: Asterisk'lerin önüne Kamailio koymak, görüntülü aramayı açmak, admin tarafına
Kamailio yönetim paneli ve "Asterisk'leri istediğimiz kadar açıp kapatma" planı. Ek talep:
"konfigler zannımca ortak DB'den okunması lazım". Hedef yalnızca **plan** (uygulama "başla" ile).

## Yapılanlar

### 1. Mevcut durum ölçümü
- **Neden:** Plan bugünkü hâlin üstüne kurulmalı.
- **Ne yapıldı:** Tek Asterisk (`AsteriskOptions.cs:59-74` tek AMI/ARI), tenant→düğüm bağı API
  anahtarının `node` alanında (`IProvisioningNodeDirectory`, BR-BE-278), config pull (confd),
  WebRTC var (`ConfigRenderer.cs:486-562`), görüntü yok (`ConfigRenderer.cs:118`
  "no video"), depoda Kamailio 0 geçiş.
- **Komutlar:** `git grep -i kamailio`, `grep -n webrtc ConfigRenderer.cs`, kart numarası
  boşluk taraması (`git grep -l BR-XXX-NNN` → hepsi 0).

### 2. Ortak DB kararı (kullanıcıya soruldu)
- **Neden:** CLAUDE.md §3.3/1 "Asterisk asla pbxtr PostgreSQL'ine bağlanmaz, realtime yasak"
  diyordu; talep bununla çakışabiliyordu.
- **Seçenekler:** (a) Kamailio ayrı DB, Asterisk pull kalır · (b) Asterisk'ler de ortak DB'den ·
  (c) pbxtr DB'de salt-okur view. **Kullanıcı (b)'yi seçti.**
- **Uygulama biçimi (benim seçimim, planda gerekçeli):** aynı PG kümesinde ayrı veritabanı
  `pbxtr_telefon`; pbxtr outbox projeksiyonuyla yazar; ana DB (RLS) telefon sistemine kapalı
  kalır, çünkü Asterisk/Kamailio `app.tenant_id` GUC'unu set edemez.

### 3. Plan + sprintler + backlog + ClickUp
- **Dokunulan dosyalar:** `yonetim/kamailio-ve-asterisk-havuzu-plani.md` (yeni),
  `yonetim/sprintler/sprint-50.md` … `sprint-53.md` (yeni), `yonetim/backlog.md` (EPIC KAMAILIO,
  27 kart), `yonetim/arac/clickup-kart-eslemesi.json`.
- **Fazlar:** K1 (sprint-50) ortak DB + Kamailio/rtpengine önde, tek Asterisk arkada ·
  K2 (sprint-51) realtime + düğüm kayıt defteri + çok düğümlü sağlayıcı + failover ·
  K3 (sprint-52) yönetim paneli #80 + düğüm aç/boşalt/kapat (sysagent sabit argv) ·
  K4 (sprint-53) görüntülü arama (K1'den sonra paralel olabilir).
- **Kartlar:** BR-DOC-25, BR-DB-123..126, BR-BE-284..287, BR-SYS-146..149, BR-AST-154..160,
  BR-SEC-35, BR-FE-149..150, BR-QA-133..136.
- **Komutlar:**
  ```bash
  cd yonetim/arac
  node clickup-senkron.js --kuru   # 27 KAYIP
  node clickup-olustur.js          # yeni: 27
  node clickup-senkron.js          # yazilan: 0
  node clickup-senkron.js --kuru   # fark 0, izde olmayan 0
  ```
- **Commit:** `deb40e87` — Plan: Kamailio onde + Asterisk havuzu + ortak telefon DB + goruntulu arama + yonetim paneli

## Kararlar
- Tenant düğüme yapışık (afinite): `app_queue` durumu düğüme yereldir, kuyruk iki düğümde paylaşılamaz.
- Kayıt Kamailio'da; Asterisk durumsuz, telefon parolasını görmez (yalnız Kamailio IP'sinden kabul).
- Telefon→telefon kısayolu yok: her çağrı Asterisk'ten geçer (izolasyon).
- Dialplan ve ses dosyaları confd'de kalır; PJSIP endpoint + kuyruk realtime'a geçer. Kapalı reload listesi değişmez.
- Düşen düğümdeki canlı çağrı kaybı BİLİNÇLİ; görüntü kaydı yok, dinleme yalnız ses.
- "Aç/kapa" = kayıtlı host'larda konteyner; bulut VM açma kapsam dışı.
- Görüntü varsayılan kapalı (tenant ayarı).

## Açık kalanlar / sonraki adım
- Kullanıcı "başla" diyene kadar uygulama yok. Başlangıç sprint-50; ilk iş BR-DOC-25 (CLAUDE.md §3.3/1 güncellemesi).
- Ölçülecek riskler: R1 `ps_registrations` realtime, R2 sorcery önbellek süresi, R3 trunk sırrı düz.
