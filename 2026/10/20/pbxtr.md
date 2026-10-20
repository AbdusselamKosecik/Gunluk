# pbxtr — 2026-10-20

## Bağlam
Panel pbxtr.com apex'inde servis ediliyordu. Hedef: paneli app.pbxtr.com'a almak,
www.pbxtr.com'u tanıtım (landing) sayfasına ayırmak; landing için Claude Design prompt'u.

## Yapılanlar

### 1. Panel alan adı app.pbxtr.com
- **Neden:** www.pbxtr.com tanıtım sayfasına ayrılacak; panel ayrı alt alan adında.
- **Ölçüm:** Cloudflare origin sertifikası SAN = `*.pbxtr.com, pbxtr.com` (yeni sertifika
  gerekmez). `app.pbxtr.com` için DNS kaydı YOKTU — Cloudflare'de elle eklenmeli
  (CNAME app → pbxtr.com, proxied/turuncu bulut). Sunucuda CF API token'ı yok.
- **Ne yapıldı:**
  - `pbxtr-demo/nginx/pbxtr.conf` (sunucuya giden) + ikizi `deploy/demo/nginx-demo-cloudflare.conf`:
    ana blok `server_name app.pbxtr.com`, CSP `connect-src 'self' wss://app.pbxtr.com`;
    443'te `pbxtr.com www.pbxtr.com` → **302** `https://app.pbxtr.com$request_uri`
    (301 değil: tarayıcı önbelleğe alır, landing açılınca eski ziyaretçi panele düşerdi);
    80 → 301 `https://app.pbxtr.com`.
  - `deploy/staging-yayin.sh` `PANEL_HOST` varsayılanı `app.pbxtr.com` — yoksa sağlık
    ölçümü 302 görür ve yayını geri alırdı.
  - `deploy/nginx-dogrula.sh` ankraj + CSP tablosu, `webrtc-uctan-uca-olcum.sh`,
    `st48-kilit-uygula.sh`, `staging-yayin-migrate-selftest.sh`.
  - `pbxtr-demo/docker-compose.yml` ve sunucu `.env`: `PBXTR_PasswordResetMail__ResetUrlBase=https://app.pbxtr.com`
    (yedek `/root/pbxtr-demo.env.bak-20261020`).
  - JWT issuer **bilerek değişmedi** (opak kimlik; değişirse tüm oturumlar düşer).
- **Doğrulama:** yeni conf sunucudaki nginx konteynerinde `nginx -t` → OK.
  `deploy/nginx-dogrula.sh` başlık eşitliği TAMAM; "script taslak location" hatası
  değişiklikten ÖNCE de vardı (stash ile ölçüldü).
- **Sıra şartı:** DNS gelmeden yayın YAPILMAZ — yoksa pbxtr.com çözülmeyen adrese 302 eder.
- **Commit:** `c782ccb3` — Alan adi: panel app.pbxtr.com'a tasindi; pbxtr.com + www gecici 302 ile panele

### 2. www.pbxtr.com landing prompt'u
- **Ne:** `doc/pazarlama/www-landing-claude-design-prompt.md` — ürün tanımı, hedef kitle,
  panel token'ları (koyu/açık), tipografi, 12 bölümlük sayfa yapısı, multi-tenant vitrini,
  güvenlik/uyum, demo formu, erişilebilirlik/SEO, YAPMA listesi (uydurma logo/rakam/AI yok).
- **Commit:** `20ebfa31`

### 3. DNS + yayın 73
- Kullanıcı Cloudflare'de `app` kaydını ekledi (172.67.149.176 / 104.21.71.217).
- Yayın: `bash deploy/yerel-yayin.sh --yayinla --testsiz` → `YAYIN_EXIT=0`, imaj `demo-20ebfa31cc63`.
- **Ölçüm:** `https://app.pbxtr.com/` 200 · `https://pbxtr.com/login` 302 → `https://app.pbxtr.com/login`
  · `https://www.pbxtr.com/x` 302 → app · `http://app.pbxtr.com/` 301 → https · CSP
  `connect-src 'self' wss://app.pbxtr.com` · login API token döndü · `/sip-ws` upgrade 101 ·
  konteynerde `ResetUrlBase=https://app.pbxtr.com`.

### 4. www.pbxtr.com tanıtım sayfası (Claude Design → statik site, 9 dil)
- **Neden:** kullanıcı `doc/pbxtr Tanıtım Sayfası – Landing.html` (Claude Design paketi) www için ayarlansın, pbxtr'ın 9 dili olsun istedi.
- **Ne yapıldı:** `deploy/www-uret.py` paketi açar (manifest base64/gzip → dc-runtime, React UMD, hero.webp), `pbxtr-demo/www/` üretir. React/fontlar/bayraklar YEREL (Google Fonts dahil dış istek yok). TR/EN anahtarı → 9 dilli seçici (bayrak = ürünün `Flag.tsx` şekilleri, dilin kendi adı); `?lang=` > localStorage `pbxtr.www.lang` > tarayıcı dili. Arapça `dir=rtl`, hero görseli LTR sabit. Menü 1100px altında hamburgere döner (ka/hy/fr'de taşma ölçüldü, 0'a indi).
- **Çeviri:** tr/en tasarımdan; fr/de/bg/az/ar/ka/hy paralel ajanlarla, yapı en.js'e karşı node ile doğrulandı.
- **nginx:** `pbxtr.com/` → 301 www; apex diğer yollar → 302 app (eski yer imleri); www statik (`.rev/<rev>/www`), dosya yoksa 302 app. CSP `'unsafe-eval'` yalnız www bloğunda (dc-runtime `new Function`).
- **Yayın:** `yerel-yayin.sh` www'yi scp eder; CRLF `sed`'i www/'yi HARİÇ tutar (woff2/webp bozulurdu — canlı md5 = yerel md5 ölçüldü). `staging-yayin.sh` www'yi revizyona kopyalar, izinleri 0755/0644.
- **Ölçülen tuzaklar:** (1) Docker Desktop kapalıydı → yayın 74 imaj adımında düştü, başlatılıp tekrarlandı. (2) yayın www'yi ÇALIŞMA AĞACINDAN alır, commit'ten değil — yarım dosya canlıya çıktı. (3) Cloudflare statiği 4 sa tutar (max-age=14400) → eski legal-config ve 404'ler servis edildi; çözüm `?v=<sha256[:10]>` önbellek kırıcı. (4) Cloudflare Web Analytics beacon'ı zone'da açık; CSP engelliyor.
- **Commit:** `246f2906`, `ba6a9866`

### 5. Yasal metinler modal (Gizlilik / KVKK Aydınlatma / Çerez), 9 dil
- Alt bilgideki 3 bağlantı + demo formundaki KVKK bağlantısı modal açar; sekmeler, Escape/arka plan/kapat, odak geri döner, kaydırma kilidi. Derin bağlantı `#gizlilik`, `#kvkk`, `#cerez`.
- Metin `i18n/legal-<dil>.js`; şirket bilgisi tek yerde `i18n/legal-config.js` (kullanıcıdan: Abdusselam Kösecik, Gençosman Mah. Doğancılar Sok. No: 20 Güngören/İstanbul, info@uzmanadres.com). Saklama 2 yıl.
- Hata bulundu/düzeltildi: dc-runtime `componentDidUpdate`'e önceki state geçirmiyor → kaydırma kilidi kalıyordu; durum elle izleniyor.
- **Doğrulama (canlı, yayın 76):** 9 dil × 3 metin açılıyor, unvan dolu, yer tutucu yok, 4xx kaynak yok.
- **Commit:** `1554b68f`

### 6. Demo formu e-postası (Brevo)
- **Neden:** form tasarımdan beri hiçbir yere göndermiyordu; kullanıcı Brevo API anahtarı ve 4 alıcı verdi (info@uzmanadres.com, info@kosecik.com, a.kosecik@uzmanadres.com, abdusselam.kosecik@gmail.com), gönderici info@kosecik.com (Brevo'da doğrulu).
- **Ne yapıldı:** `POST /api/v1/public/demo-request` (`src/Pbxtr.Api/Modules/PublicSite/`), anonim, tenant/DB yok, kapalı anonim listeye gerekçeli. Brevo HTTP API (`/v3/smtp/email`), bal küpü, alan bazlı 400, 503 `DEMO_MAIL_NOT_CONFIGURED`, 502 `DEMO_MAIL_FAILED`, IP başına 5/10 dk + nginx 6/dk. Telefon `PhoneInput` (MaskedPhoneContractTests); form +ülke kodu ipucu + özel hata (9 dil). www nginx `/api/demo-request` → app proxy. Permissions-Policy `microphone=(self)` (PermissionsPolicyTests).
- **Sır:** anahtar sunucu `.env` (`PBXTR_Mail__Brevo__ApiKey`) + sifreler deposu `GitHub/Pbxtr/pbxtr/.brevo-api-key`. Brevo'da IP kısıtı var — kullanıcı 176.88.41.220'yi yetkilendirdi.
- **Tuzak (ölçüldü):** `yerel-yayin.sh` docker-compose.yml'i SUNUCUYA GÖNDERMEZ → yeni env değişkenleri konteynere ulaşmadı (anahtar_YOK). Sunucu compose'u depodakiyle farkı yalnız bu iş olduğu ölçülüp kopyalandı (yedek `/root/docker-compose.yml.bak-20261020`), `docker compose up -d app`.
- **Doğrulama:** canlıdan `www.pbxtr.com/api/demo-request` → 202; Brevo olayları: 4 alıcıya `delivered`. Testler: Architecture 857/857, PublicSite 42/42.
- **Commit:** `497b6c2a`

## Açık kalanlar / sonraki adım
- Yayın betiği compose'u taşımıyor: compose'a env eklenen her işte sunucu compose'u elle güncellenmeli (kalıcı çözüm: yayına compose taşıma).
- Brevo anahtarı sohbette açık paylaşıldı — kullanıcıya yenilemesi önerildi.
- Cloudflare Web Analytics zone'da açık (CSP engelliyor) — kullanıcı panelden kapatabilir.
- i18n dosyası elle düzenlenirse `python -I deploy/www-uret.py` yeniden koşulmalı (?v= özetleri).
