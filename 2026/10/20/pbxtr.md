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

## Açık kalanlar / sonraki adım
- Landing hazır olunca: apex+www 302 kaldırılır, www için ayrı statik server bloğu.
