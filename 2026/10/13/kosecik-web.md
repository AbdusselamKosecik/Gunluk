# kosecik-web — 2026-10-13

## Bağlam
kosecik.com, kosecik.com.tr, kosecik.tr, abdusselam.com, abdusselam.com.tr, abdusselam.tr için tek bir site yapılacak; alan adları DNS ile yönlendirilecek. Kullanıcı tasarım örneği ve detayları ekleyecek, önce repo istendi.

## Yapılanlar

### 1. Repo oluşturuldu
- **Neden:** Yeni site için temiz bir başlangıç. Mevcut `kosecik.com` reposu (Mart 2025, eski .NET çözümü) kullanıcı kararıyla olduğu gibi bırakıldı.
- **Ne yapıldı:** Private `AbdusselamKosecik/kosecik-web` reposu açıldı; README (alan adı tablosu + açık kararlar), `tasarim/` ve `docs/detaylar.md` iskeleti eklendi.
- **Dokunulan dosyalar:** `README.md`, `docs/detaylar.md`, `tasarim/README.md`
- **Komutlar:**
  ```bash
  git init -b main
  git add README.md docs/detaylar.md tasarim/README.md
  git commit -m "İlk iskelet: README, tasarim/ ve docs/ klasörleri"
  gh repo create AbdusselamKosecik/kosecik-web --private --source=. --remote=origin --push
  ```
- **Sonuç / doğrulama:** Push başarılı, `main` dalı origin'i takip ediyor.
- **Commit:** `ace1048` — İlk iskelet: README, tasarim/ ve docs/ klasörleri

## Kararlar
- Yeni repo adı `kosecik-web`, private.
- Eski `kosecik.com` reposuna dokunulmadı.

## Açık kalanlar / sonraki adım
- Kullanıcı tasarım örneklerini `tasarim/`, detayları `docs/` içine ekleyecek.
- Ana alan adı, teknoloji, barındırma ve DNS sağlayıcı kararları verilecek.

---

## Tur 2 — Site, teklif sihirbazı, PHP mail, WhatsApp

### Bağlam
Kullanıcı `tasarim/AK Technology Consulting — Website.html` (Claude Design bundle'ı) ve detaylı brief'i (kişisel marka + teknoloji danışmanlığı sitesi, TR/EN, tekstil odaklı) verdi. Ekstra istek: kaçmadan hızlıca ihtiyacı anlayan **teklif sihirbazı**, **PHP ile mail**, **WhatsApp butonu**.

### 1. Tasarım dosyasını açma
- **Neden:** Dosya, base64+gzip ile paketlenmiş iç içe bundle; doğrudan okunamıyor.
- **Ne yapıldı:** Python ile `__bundler/manifest` ve `__bundler/template` script bloklarını çözüp her sayfanın (`page.html`) içine indim. 6 board: Home EN/TR, Textile EN, Contact EN/TR, Brand & Design System. Fontlar: Manrope + IBM Plex Mono. Renkler: navy #0B1422, #142338, accent #367FCB (UI metinde #2A68AD), bg #F7F9FC.
- **Tarif:** manifest[uuid] = {mime, compressed, data(base64)} → gzip.decompress; template JSON string; iç sayfalar da aynı formatta tekrar paketli.

### 2. Mimari kararı
- **Karar:** Next.js 16 + TS + Tailwind 4, `output: "export"`, `trailingSlash: true` → `out/` düz HTML. Mail için `public/api/quote.php`. Böylece her cPanel/Apache PHP hostingde çalışır, Node sunucu gerekmez.
- Dil başına ayrı root layout: `src/app/tr/layout.tsx`, `src/app/en/layout.tsx` (html lang doğru). Slug'lar dile göre farklı → route haritası `src/lib/i18n.ts`. İçerik `L<T> = {tr, en}` tipiyle; eksik çeviri tip hatası verir.
- Paketler: next@16.4.0, react@19, tailwindcss@4.3.3, typescript@5.9 (TS 7 kuruldu, Next uyumu için 5.9'a sabitlendi).

### 3. Teklif sihirbazı — `src/components/QuoteWizard.tsx`, içerik `src/content/quote.ts`
- 4 adım: Konu (5 kart, tek tık ilerler) → İhtiyaç (çoklu çip + mevcut durum) → Zamanlama/büyüklük/bütçe (isteğe bağlı, "atla") → İletişim (ad, e-posta, telefon, dönüş tercihi e-posta/telefon/WhatsApp, onay).
- Taslak `localStorage` (`ak-quote-draft-v1`) — sayfa kapansa da kalır; başlangıç zamanı da taslakta (geri dönen kullanıcı bot tuzağına düşmesin diye).
- `?topic=textile&need=assessment` ön seçim; tekstil sayfasında sihirbaz gömülü ve ön seçili.
- Canlı özet paneli, adım değişince başlığa odak, başarıda talep no + WhatsApp linki (talep no ile hazır mesaj).

### 4. PHP mail — `public/api/quote.php`
- POST JSON; Origin kontrolü (6 alan adı), honeypot, <4 sn gönderim = sessiz düşür, IP başına saatlik limit (temp dosya), opsiyonel Turnstile, sunucu doğrulaması (422 + alan listesi).
- PHPMailer v7.1.1 vendored (`public/api/lib/PHPMailer`), SMTP; Reply-To = müşteri. Opsiyonel müşteriye onay maili.
- Her talep `../quote-submissions/YYYY-MM.jsonl` yedeğine yazılır; mail düşerse lead kaybolmaz (yedek varsa 200 döner).
- Config: `quote-config.php` public_html'in BİR ÜSTÜNE (deploy silmesin). Şablon `api/config.example.php`. `api/.htaccess` sadece quote.php'ye izin verir.
- Saat dilimi Europe/Istanbul (ref numarası tarihi için).

### 5. WhatsApp
- `src/components/WhatsAppButton.tsx`: her sayfada sabit yeşil buton (navy ikon, kontrast için). Numara `src/site.config.ts` → `whatsapp`.

### 6. Sayfalar ve SEO
- TR/EN: anasayfa, tekstil landing (örnek dashboard "ÖRNEK VERİ" etiketli), hizmetler + 5 hizmet sayfası (ortak `ServiceView` şablonu), hakkımda, projeler + detay (hepsi `draft:true`, noindex, sitemap dışı), blog + 1 gerçek yazı (Hazır MES mi özel yazılım mı), gizlilik (KVKK/GDPR), iletişim.
- İçerikler: services/about/privacy/cases/blog iki alt ajana yazdırıldı (uydurma bilgi yasak, köşeli parantezli yer tutucular).
- canonical + hreflang (tr/en/x-default), OG, sitemap.xml, robots.txt, JSON-LD (ProfessionalService, Person, Service, FAQPage, Article).
- `public/.htaccess`: tüm alan adları + www → `https://kosecik.com` 301, HTTPS, kök `/` Accept-Language ile /tr/ veya /en/ (IP değil), `/not-found.html` 404 (Next kendi 404.html'ini ezdiği için ad değişti).

### 7. Bulunan sorun: Next 16 export prefetch 404
- **Belirti:** Linklerde `/tr/iletisim/__next.tr.iletisim.__PAGE__.txt` 404. Export dosyayı `__next.tr/iletisim/__PAGE__.txt` (iç içe) yazıyor; `next start` eşliyor, Apache eşlemiyor.
- **Çözüm:** `scripts/flatten-rsc.mjs` build sonrası noktalı adlara kopyalar. `"build": "next build && node scripts/flatten-rsc.mjs"`.

### 8. Doğrulama
- **Komutlar:**
  ```bash
  npm run build && npm run check:links   # 40 sayfa: link, tek h1, title, description, canonical, hreflang, lang
  # Docker: php:8.3-apache (out/ mount, rewrite+headers açık) + axllent/mailpit:v1.27 aynı network'te
  # curl ile: 405, 422, 403 origin, 400 json, honeypot/fast sessiz 200, 5/saat sonra 429, config/lib 403,
  #           kök 302 tr/en, www.abdusselam.com.tr → 301 https://kosecik.com, 404 sayfası
  # Playwright-core + yerel Chrome ile sihirbaz uçtan uca: hata mesajları, reload sonrası taslak,
  #           gönderim → Mailpit'e 2 mail (sahibe + müşteriye), 375px'te 30 sayfada taşma yok, mobil menü Esc
  ```
- **Sonuç:** Tümü geçti. HTML mailde `<script>` kaçışlı. Test sırasında bot tuzağının (4 sn) taslakla dönen gerçek kullanıcıyı düşürebileceği fark edildi → startedAt taslağa eklendi.
- **Commit:** `85a00c7` — Site: Next.js static export, quote wizard with PHP mail, WhatsApp button

## Kararlar
- Statik export + PHP (Node hosting gerektirmesin).
- Canonical alan adı şimdilik kosecik.com (`.htaccess` iki satır + `NEXT_PUBLIC_SITE_URL` ile değişir).
- Vaka çalışmaları taslak/noindex; doğrulanmış bilgi gelmeden yayınlanmaz.
- Bütçe aralıkları (TR: 100 bin / 500 bin ₺; EN: €5k / €25k) ve "1 iş günü içinde dönüş" sözü benim varsayımım — kullanıcı onaylamalı.

## Açık kalanlar / sonraki adım
- `src/site.config.ts`: gerçek e-posta, telefon, WhatsApp numarası (şu an yer tutucu 905000000000).
- Hosting/SMTP bilgisi → `quote-config.php`.
- Ana alan adı kararı; DNS + SSL (6 alan adı + www).
- Portre ve fabrika fotoğrafı; kariyer özeti; proje vakaları; gizlilik metnindeki adres/saklama süresi.
- İsteğe bağlı: Turnstile anahtarları, analytics (eklenirse gizlilik metni güncellenmeli), deploy otomasyonu (GitHub Actions → FTP).

## Tur 3 — Gerçek iletişim bilgileri

### 1. WhatsApp / telefon / e-posta
- **Neden:** Kullanıcı gerçek bilgileri verdi: `info@kosecik.com`, `905428198069`.
- **Ne yapıldı:** `src/site.config.ts` → `phoneDisplay: "+90 542 819 80 69"`, `whatsapp: "905428198069"` (tel: linkleri de bu alandan üretiliyor), TODO işaretleri kaldırıldı. `public/api/config.example.php` → `to_email: 'info@kosecik.com'`. README'deki "iletişim bilgileri yer tutucu" maddesi silindi.
- **Dokunulan dosyalar:** `src/site.config.ts`, `public/api/config.example.php`, `README.md`
- **Komutlar:**
  ```bash
  npm run build && npm run check:links
  grep -o 'wa.me/[0-9]*' out/tr/index.html | sort -u        # wa.me/905428198069
  grep -o 'tel:+[0-9]*' out/tr/iletisim/index.html | sort -u # tel:+905428198069
  ```
- **Sonuç / doğrulama:** Build OK, 40 sayfa sorunsuz; WhatsApp ve tel linkleri doğru numarada.
- **Commit:** `d3415c3` — Contact: real WhatsApp/phone number (+90 542 819 80 69), info@kosecik.com as recipient

### Açık kalanlar
- Sunucudaki gerçek `quote-config.php` (gitignore'da) hostingde `to_email => info@kosecik.com` + SMTP bilgileriyle oluşturulacak.

## Tur 4 — Ana alan adı abdusselam.tr

### 1. Canonical host değişikliği
- **Neden:** Kullanıcı kararı: "abdusselam.tr yapalım siteyi". Diğer 5 alan adı + tüm www'ler buraya 301.
- **Ne yapıldı:**
  - `public/.htaccess`: iki `[CANONICAL]` satırı → `RewriteCond %{HTTP_HOST} !^abdusselam\.tr$ [NC]` ve `RewriteRule ^(.*)$ https://abdusselam.tr/$1 [R=301,L]` (HTTPS kuralında da aynı hedef).
  - `src/site.config.ts`: `url` varsayılanı `https://abdusselam.tr` (canonical, hreflang, OG, sitemap, robots buradan üretiliyor).
  - `public/api/config.example.php`: `from_name` → `abdusselam.tr Teklif Formu`. E-posta adresleri (`info@kosecik.com`, `noreply@kosecik.com`) kosecik.com'da kaldı — posta kutusu orada.
  - `README.md`: alan adı tablosu ve Search Console satırı.
- **Dokunulan dosyalar:** `public/.htaccess`, `src/site.config.ts`, `public/api/config.example.php`, `README.md`
- **Komutlar:**
  ```bash
  npm run build && npm run check:links
  docker run -d --rm --name akq-web -p 18080:80 -v "$(pwd -W)/out:/var/www/html" php:8.3-apache \
    sh -c "a2enmod rewrite headers && sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf && apache2-foreground"
  curl -s -o /dev/null -w '%{http_code} %{redirect_url}' -H "Host: kosecik.com" localhost:18080/tr/iletisim/
  ```
- **Sonuç / doğrulama:** canonical `https://abdusselam.tr/tr/`, sitemap/robots abdusselam.tr; kosecik.com, www.abdusselam.tr, kosecik.com.tr, abdusselam.com → 301 `https://abdusselam.tr/...`; abdusselam.tr (https) → 200.
- **Commit:** `5158395` — Canonical domain: abdusselam.tr (all other domains 301 here)

### Not
- Dikkat: Git Bash `sed` ile `\.` kaçışı yutuldu (`!^abdusselam.tr$` oldu); Edit ile düzeltildi. Regex'li satırları sed yerine editörle değiştir.
- Search Console mülkü `https://abdusselam.tr` olarak açılacak.
