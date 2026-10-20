# Saas_erp — 2026-10-20

## Bağlam
19 Ekim'deki CI hızlandırma (33 dk → ~6 dk) bitmişti. Kullanıcı yeni istek verdi: Santral ve PMS menülerden ve
modüllerden kalksın (yapılmayacak), self-signup kalksın, yönetici yeni firma açsın; firma yönetimi Pbxtr'deki gibi
olsun (firma listesi, kullanıcıları görme, kullanıcıya bürünme, yeni kullanıcı, mevcut kullanıcıyı atama, admin yapma).
Önce landing ekranı için bir Claude Design promptu istendi.

## Yapılanlar

### 1. Landing için Claude Design promptu
- **Neden:** Kullanıcı landing tasarımını Claude Design'da yaptıracak.
- **Ne yapıldı:** Tek sayfa landing promptu. Turuncu #D35400 + Inter; "Kayıt ol" yok, "Demo talep et" + "Giriş yap";
  hero, güven şeridi, 6 üretim alt modülü, modül ızgarası (Santral/PMS yok), nasıl çalışır (hesabı biz açarız),
  yetenekler, sayılar, SSS, kapanış CTA, KVKK onaylı demo formu, footer.
- **Dokunulan dosyalar:** `docs/design/landing-claude-design-prompt.md`
- **Commit:** `6a80103a` — docs: landing sayfasi icin Claude Design promptu

### 2. Keşif
- Pbxtr (`X:\GitHub\Pbxtr\pbxtr`) tenant yönetimi: tenant listesi + oluşturma sihirbazı (sahip için tek seferlik
  şifre), kullanıcı listesi/detay, rol seçici, "Bu kullanıcı olarak çalış" (30 dk JWT, refresh yok, kapatılamaz banner,
  "Kendi hesabıma dön", denetim kaydı), self-signup yok.
- VuoApp'te zaten var olan: admin tenant listesi (askıya al/aktif et/modüller/"Giriş Yap" = süper admin kendi kimliğiyle),
  tenant düzenleme (ad, paket, üyeler, mevcut kullanıcı ekle, rol değiştir, çıkar, şifre, e-posta onayı, üye modül yetkisi).
  Eksik olan: gerçek bürünme, admin'in yeni kimlik açması, admin'in tenant açması. Self-signup yolları: auth/signup,
  onboarding/complete, POST /tenants (herkese açıktı).

### 3. Kurul
- cto, skeptic, dba, product-owner → APPROVE-WITH-CONDITIONS; security-reviewer → PASS-WITH-NOTES. BLOCK yok.
- Önemli şartlar: bürünme token'ı tek tenant'a sabit (imp_tid) ve is_super_admin=false; bürünmede kimlik/yönetim
  mutasyonları 403; frontend 401'de admin refresh'ine düşmesin, tek token erişimcisi; geçici şifre Dragonfly idempotency
  önbelleğine/loglara girmesin; signup kontrolü controller'da (handler testleri bozulmasın); boş DB'de migration 0 satır
  günceller → seeder da modülleri pasif eklemeli; AlwaysCreateNew'da "kazanan tenant'ı döndür" ve DefaultTenantId ezme yok.
- Karar: sunucu şifre üretmez, **yönetici şifreyi formda girer** (rastgele oluştur/kopyala butonu). Böylece şifre yanıtta
  dönmez, önbelleğe/loga düşmez. "İlk girişte şifre değiştirmeye zorla" şema gerektirdiği için ertelendi.

### 4. Santral (ast) + PMS gizleme
- **Ne yapıldı:** `saas."Module".IsActive=false` (pms, ast). Module.IsActive enabled-modules hesabında
  (IntersectWith), admin modül listesinde, modül mağazasında, fiyat seed'inde zaten süzülüyor. Ek olarak menüde
  `isNav:false`, API anahtarı scope listesinden çıkarıldı. Kod/tablolar silinmedi.
- **Dokunulan dosyalar:** `VuoApp.Migrator/Migrations/20261019211725_DeactivatePmsAndAstModules.cs` (Down=true),
  `VuoApp.Modules.Saas/Seed/SaasDataSeeder.cs` (IsActive=false), `routes.tsx`, `api_keys.page.tsx`.
- **Komutlar:**
  ```bash
  # design-time için sahte bağlantı (Migrator connection string ister, DB'ye bağlanmaz)
  ConnectionStrings__DefaultConnection='Host=localhost;Port=5432;Database=design;Username=x;Password=x' \
    dotnet ef migrations add DeactivatePmsAndAstModules --project src/backend/VuoApp.Migrator --context MigratorDbContext --no-build
  node tools/strip-migration-designers.mjs   # 110 Designer, 1 inceltildi
  ```
- Migration API açılışında paylaşımlı dev DB'ye uygulandı (log: "1 bekleyen migration uygulanıyor").

### 5. Self-signup kapatma
- `Auth:SelfSignupEnabled` (varsayılan false; appsettings.json + Development.example). auth/signup ve onboarding/complete
  controller'da 403 `Auth.SelfSignupDisabled` (kullanıcı oluşturulmadan). POST /api/v1/tenants handler'da yalnız süper
  admin. auth/register açık (davet kabul sayfası kullanıyor; tenantsız hesap hiçbir veriye erişemez).
- Frontend: login'den "Kayıt olun" kalktı; /auth/register ve /onboarding/signup → /auth/login; firmasız kullanıcı
  `/no-tenant` ("firmanıza bağlı değilsiniz"), firmasız süper admin → /admin.

### 6. Admin firma/kullanıcı + hesap pasifleştirme
- `POST /api/v1/admin/tenants` {companyName, ownerEmail, ownerDisplayName, ownerPassword?, planCode?} — mevcut e-posta →
  o kullanıcı owner; yeni → şifre zorunlu. TenantProvisioner `AlwaysCreateNew` ile her zaman yeni tenant. Plan yoksa "free".
- `POST /api/v1/admin/tenants/{id}/members/new` {email, displayName, password?, role} — pasif üyeliği yeniden aktifler.
- `PUT /api/v1/admin/users/{id}/active` — kendini/süper admini pasifleyemez; pasiflemede refresh token'lar revoke.
  GET admin/users/{id} artık `isActive` döner (IUserProvisioner.IsActiveAsync).
- Ekranlar: "Yeni Firma" ve "Yeni Kullanıcı" diyalogları (ortak şifre sonuç bileşeni), kullanıcı detayında
  Pasifleştir/Aktifleştir.

### 7. Kullanıcıya bürünme
- `POST /api/v1/admin/tenants/{t}/members/{u}/impersonate` → `IImpersonationTokenIssuer` (Domain arayüzü, Identity impl).
  Kurallar: süper admin, hedef ≠ kendisi, hedef aktif, hedef süper admin değil, hedefin o tenant'ta aktif üyeliği var;
  ret tek tip 403 `Admin.ImpersonationNotAllowed`, sebep audit'e. Token 30 dk, refresh yok, claim'ler: hedefin
  sub/email/name, is_super_admin=false, act_sub, act_name, imp_tid.
- `ImpersonationGuard` (TenantResolutionMiddleware): X-Tenant-Id ≠ imp_tid → 403; GET dışı istekler
  auth/profile/api-keys/tenants/admin/onboarding/roles/permissions/saas/stripe → 403. NotificationHub imp_tid'e sabit.
  ICurrentUser.ImpersonatorId (default member), Serilog LogContext ImpersonatorId, audit newValues'a impersonatorId.
- Frontend: `src/core/auth/session.ts` tek erişimci; bürünme verisi sessionStorage'da (sekmeye özel), admin localStorage
  token'larına dokunulmaz; axios + iki SignalR hub'ı buradan okur; 401'de refresh denenmez, bürünme biter. Bürünmede
  profil `POST /auth/provision` yerine `GET /auth/me`'den (ilk sürümde provision guard'a takılıp admini düşürüyordu —
  UX kontrolü yakaladı). Kapatılamaz turuncu banner + "Kendi hesabıma dön"; başlatmadan önce onay diyaloğu.
  Süper admin olmayan /admin* → "/" (ön yüz koruması yoktu).

### 8. UX kontrolü bulguları ve düzeltmeler
- Admin ekranlarında Türkçe karakterler (Kullanıcılar, Üyeler, Şifre Değiştir…), AdminUsers.menu/AdminBilling.menu
  i18n anahtarları, dialog "Close" → "Kapat", 375px taşma (overflow-x-auto, flex-wrap), "Açılıyor…" bekleme durumları,
  pasifleştirmede rozet anında güncellenir, kullanıcı aramasında 300 ms debounce.
- Admin kullanıcı araması 500: Gridify filtresi record constructor projeksiyonu üzerinde SQL'e çevrilemiyordu →
  filtre/sıralama/sayfa UserProfile üzerinde, projeksiyon en sonda (`GetAllUsers.cs`, test `GetAllUsersTests`).

- **Doğrulama:** backend build 0 hata/0 uyarı, unit 3880 geçti (3 skip). Frontend typecheck 0 hata, vitest 828 geçti,
  7 kırmızı hepsi önceden var (i18n parity, login jsdom SVG, orders worklist). Tarayıcıda (headless Chrome):
  login'de kayıt linki yok, Santral/PMS yok, firma açma, yeni kullanıcı, admin yapma, bürünme başlat + banner + Yönetim
  menüsü gizli + admin token korunuyor + "Kendi hesabıma dön", pasifleştir/aktifleştir, 375px'te genişlik 375.
  Güvenlik son kontrolü PASS-WITH-NOTES (iki Low not uygulandı: hub imp_tid, saas/stripe bloğu).
- **Commit:** `12e673be` — feat(admin): yonetici firma/kullanici acar, kullaniciya burunme; kayit kapandi, Santral/PMS gizlendi

## Kararlar
- Kod silinmez, modül pasiflenir (geri dönüş: migration Down / config true).
- Şifreyi yönetici girer; sunucu üretmez/döndürmez.
- auth/register açık kalır (davet akışı).
- Bürünme oturumu sessionStorage'da; sayfa yenilense de sekmede sürer, sekme kapanınca biter.

## Açık kalanlar / sonraki adım
- **GitHub Actions çalışmıyor:** 6a80103a ve 12e673be koşuları "recent account payments have failed or your spending
  limit needs to be increased" ile başlamadı → DEV'e deploy olmadı. Kullanıcı GitHub Billing'i düzeltince son commit
  için workflow yeniden tetiklenmeli (`gh run rerun 39331116063`).
- İlk girişte şifre değiştirmeye zorlama (User'a alan + migration) — ürün sahibi önerdi, ertelendi.
- Paylaşımlı dev DB'de test verisi: "UX Test Firma 2010", ux-test-2010@vuo.app, ux-user-2010@vuo.app.
- Önceden var olan: `VuoApp.Api/Hubs/NotificationHub.SendToTenant` herhangi bir girişli kullanıcının herhangi bir tenant
  grubuna mesaj göndermesine izin veriyor (yetki kontrolü yok) — ayrı iş olarak ele alınmalı.
- Tailscale üzerinden dev sunucuya ping ~1.1 sn idi (yerelde sayfalar 20-30 sn yükleniyordu) — ağ kaynaklı.

---

## Akşam turu — Tanıtım (landing) sayfası

### 9. Claude Design çıktısından tanıtım sayfası (/tanitim), 10 dil
- **Neden:** Kullanıcı Claude Design'da hazırladığı landing'in (`docs/VuoApp Landing – Landing.html`, ayrıca
  `~/Downloads`) uygulamaya yazılmasını istedi; ardından dil seçici (tr, en, fr, bg, ar, de, ka, az, hy) + Urduca
  (Pakistan) eklenmesini ve KVKK veri sorumlusu bilgilerini verdi.
- **Tasarım dosyasını açma:** Çıktı bir "bundler" HTML: `<script type="__bundler/template">` JSON-string, manifest'te
  gzip+base64 JS/font. Node ile `JSON.parse(template)` → HTML, font-face'ler atıldı; CSS bir betikle `.vuo-landing`
  altına alındı, animation/transition bildirimleri `@media (prefers-reduced-motion:no-preference)` bloğuna taşındı,
  keyframe adlarına `vl-` öneki (global çakışma yok), `.dark` → `.is-dark` (Tailwind dark varyantıyla çakışmasın).
  Betik: scratchpad `landing/css.cjs` (tek seferlik; çıktı repo'da `landing.css`).
- **Ne yapıldı:**
  - `src/frontend/src/features/landing/`: `pages/landing.page.tsx` (dil/tema durumu, localStorage try/catch,
    `<html lang/dir>` ve başlık sayfadan çıkınca geri alınır), `components/*` (header, hero [fare ile ışık/paralaks],
    kart ızgarası, örnek ekranlı yetenek satırları, SSS, demo bölümü+formu, KVKK/Gizlilik modalı [odak tuzağı, Esc,
    scroll kilidi], footer, dil seçici + SVG bayraklar), `landing.data.ts` (dilden bağımsız ikon/rakam/iletişim,
    `DATA_CONTROLLER`), `landing.utils.ts` (`buildDemoMailto`, 1800 karakter sınırı, not kısaltılır).
  - `i18n/`: `landing-text.types.ts` sözleşme, `tr.ts` kaynak, 9 çeviri (3 paralel ajan; ar/ur RTL). Yasal metinlerde
    `{controller} {address} {kvkkEmail} {email} {phone}` belirteçleri render'da doldurulur.
  - Yönlendirme: `app.tsx` public lazy `/tanitim`; `private-route.tsx` girişsiz + `pathname === "/"` → `/tanitim`,
    diğer korumalı yollar yine `/auth/login`. Giriş sayfasına "VuoApp'i tanıyın, demo talep edin" bağlantısı.
  - Demo formu sunucuya yazmaz: `mailto:info@vuo.app` hazır ileti; teşekkür metni "e-posta uygulamanız açıldı" der.
    Üretim alanı değerleri hangi dil seçilirse seçilsin Türkçe gönderilir (ekip okusun).
  - KVKK veri sorumlusu (kullanıcı verdi): Abdusselam Kösecik, Gençosman Mah. Doğancılar Sok. No: 20, Güngören /
    İstanbul; KVKK başvuru e-postası info@uzmanadres.com.
- **Kurul:** cto APPROVE-WITH-CONDITIONS (lazy chunk, CDN yok, kapsamlı CSS istisnası + başlık yorumu, KVKK onay kutusu,
  mailto encode/uzunluk, PrivateRoute testi zorunlu, takip işleri ClickUp'a); skeptic APPROVE-WITH-CONDITIONS
  (ham `[..]` yer tutucu gösterilmez, harici CDN yok, yönlendirme yalnız `!isAuthenticated` dalında). UX son kontrolü
  PASS-WITH-NOTES → uygulandı: modal odak tuzağı + body scroll kilidi, dil seçicide listbox rolleri yerine
  `aria-current`, `<html lang/dir>`. Uygulanmadı: hero eğrisinin alt yazının arkasından geçmesi (tasarımın kendisi).
- **Doğrulama:** vitest landing+route+changelog 42/42; tam takım 864 geçti, 7 kırmızı önceden var (aynı liste);
  `tsc --noEmit` temiz. Headless Chrome: `/` → `/tanitim`, 1440/375'te yatay kaydırma yok, Urduca RTL, koyu tema.
  Not: ESLint yapılandırması `src/features/landing`'i kapsamıyor (eslint "ignored" diyor) — lint koşulamadı.
- **Commit:** `7868bd89` — feat(landing): herkese acik tanitim sayfasi (/tanitim), 10 dil + RTL, demo talep formu
  (origin/dev'e rebase; changelog çakışması iki taraf korunarak çözüldü; dev + feat/iki-panelli-menu push).
- **Repo'ya alınmayan:** `docs/VuoApp Landing – Landing.html` (378 KB tasarım çıktısı; CTO şartı — brief
  `docs/design/landing-claude-design-prompt.md` yeterli). Kopyası `~/Downloads`'ta.

### Açık kalanlar (landing)
- Demo talepleri için sunucu uç noktası (ClickUp backlog açıldı).
- SEO ön render + KVKK metninin hukuk onayı + çevirilerin anadil kontrolü (ClickUp backlog).
- Güven şeridi/rakamlar ("Türkiye'de barındırılan veri", "Günlük yedek", "100+ fiş türü") kullanıcının tasarımından
  alındı — doğruluğu kullanıcı teyit etmeli.
- DEV/PROD yayını hâlâ bekliyor (SSH anahtarı / DEV deploy URL'si; önceki bölüm).

### 10. Demo talepleri Brevo ile ekibe e-posta
- **Neden:** Kullanıcı Brevo API anahtarı verdi; demo talepleri info@uzmanadres.com, info@kosecik.com,
  a.kosecik@uzmanadres.com, abdusselam.kosecik@gmail.com adreslerine gitsin. (Anahtar sohbete yapıştırıldı →
  döndürülmesi önerildi; repoya/günlüğe YAZILMADI.)
- **Keşif:** Mevcut e-posta SMTP (MailKit, `Smtp:*`). Verilen anahtar `xkeysib-` = Brevo HTTP API anahtarı (SMTP şifresi
  değil) → `POST https://api.brevo.com/v3/smtp/email`. Brevo hesabında **IP izin listesi açık**: yerel IP 401 aldı.
- **Kurul:** cto + skeptic APPROVE-WITH-CONDITIONS, security PASS-WITH-FIXES → ortak karar: Brevo YALNIZ demo talepleri
  için (`IDemoRequestMailer`); auth/davet mailleri SMTP'de kalır (IP listesi yüzünden hepsi kırılmasın). Tüm girdiler
  HTML-encode (pipeline encode etmiyor), konu CR/LF'siz, replyTo JSON alanı, loglarda kişisel veri/Brevo gövdesi yok.
  Güvenlik son kontrolü PASS-WITH-NOTES.
- **Ne yapıldı:**
  - `VuoApp.Domain/Interfaces/IDemoRequestMailer.cs`, `Infrastructure.Common/Email/BrevoDemoRequestMailer.cs`
    (typed HttpClient "Brevo", 15 sn), `EmailSetup.cs` kayıt.
  - `Modules.Saas/Features/DemoRequests/SubmitDemoRequest.cs` (command+validator+handler; alan/çalışan beyaz liste,
    KVKK onayı zorunlu, bal küpü `website` doluysa sessizce 200) + `DemoRequestController.cs`
    (`POST api/v1/public/demo-requests`, `[AllowAnonymous]`, `[TenantFree]` metotta — sınıfta derlenmiyor; 202/400/503).
  - `RateLimitingExtensions.cs`: "demo-request" IP başına 3 / 15 dk.
  - Config: `Brevo:{ApiKey,SenderEmail=noreply@uzmanadres.com,SenderName}`, `DemoRequests:Recipients` (appsettings.json,
    .example); anahtar yalnız gitignore'daki `appsettings.Development.json`'da. Sunucuda `Brevo__ApiKey` env.
  - Ön yüz: `landing.api.ts` (fetch, credentials omit), `demo-form.tsx` önce API, başarısızsa mailto; yeni metinler
    (sending/sentTitle/sentText) ve Gizlilik "Gönderim" maddesi 10 dilde.
- **Hata/ders:** `WebUtility.HtmlEncode` Türkçe harfleri `&#214;` yapıyor → `HtmlEncoder.Create(UnicodeRanges.All)`.
  Git Bash curl Türkçe karakteri bozuk gönderiyor → JSON'da `\u00d6` kaçışı.
- **Doğrulama:** unit 3912 geçti (yeni 16); integration Docker yok (ortam). Vitest landing 39/39, tsc temiz. Yerel API ile
  elle: X-Tenant-Id'siz erişim OK, doğrulama 400, Brevo 401 (IP listesi) → 503 (ön yüz mailto'ya düşer), 4. istekte 429.
- **Commit:** `dd1cb2cd` — feat(landing): demo talepleri Brevo ile ekibe e-postalanir; gonderilemezse mailto

### Açık kalanlar (Brevo)
- Brevo → Security → Authorised IPs: DEV/PROD sunucu çıkış IP'leri eklenmeli (veya IP kısıtı kapatılmalı); yoksa
  canlıda da 401 → ziyaretçi mailto yoluna düşer.
- `noreply@uzmanadres.com` Brevo'da doğrulanmış gönderici/alan adı olmalı (SPF/DKIM).
- Sunucu env: `Brevo__ApiKey` (DEV + PROD). Anahtar döndürülmeli.
- Program.cs ForwardedHeaders yalnız `Proxy:TrustForwardedHeaders=true` iken; proxy arkasında gerçek IP için ayar kontrol.
