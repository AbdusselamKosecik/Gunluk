# Saas_erp — 2026-10-23

## Bağlam
Önceki gün (2026/10/22/Saas_erp.md) F8a v2, MRP düzeltmesi (b793d3a6) ve dil işleri dev'e gönderilmişti; DEV 1.0.2.1043'te kalmıştı. Bu oturum iki pencerede (saas-erp-6d: yayın, saas-erp-fe: UX post-check) yürüyor.

## Yapılanlar

### 1. DEV 1.0.2.1044 manuel yayın (`a6058383`)
- **Neden:** GitHub Actions "DEV Deploy" faturalama yüzünden başarısız (3 deneme: b793d3a6, a58c961d, a6058383 — 4-5 sn'de failure). Ekip arkadaşı bykosecik dev'i DEV'e çıkarmak için `a6058383 chore: DEV deploy yeniden tetikle` attı → ekip isteği.
- **İçerik:** refakat formu Termin sütunu (a58c961d), ARK özel alan tabloları + UD_KOrderNo (cae8b917, 1dd06e9b), Tezgah planlama UX düzeltmeleri (835b70e8), onay penceresi dil (a95e7aff), MRP düzeltmesi (b793d3a6).
- **Komutlar:** Docker Desktop başlatıldı → `git worktree add --detach <scratchpad>/wt-a6058383 a6058383` → `docker build -q --build-arg VERSION=1.0.2.1044` (api: `-f src/backend/VuoApp.Api/Dockerfile src/backend`, spa: `-f src/frontend/Dockerfile src/frontend`) → `tekbirsoft/vuoapp-{api,spa}-dev:{1.0.2.1044,latest}` push → `curl http://217.131.14.57:56806/abdusselam.kosecik/1.0.2.1044` → worktree remove.
- **Sonuç / doğrulama:** status ok, pull_rc 0, up_rc 0; `/api/v1/profile` 401 (ayakta); 07487438..a6058383 aralığında yeni migration yok (son: WeavingLoomPlanF8a, uygulanmış).

### İdempotency yeniden tasarımı — R12 #1–3 (`63536013`) + R12 #7 ESLint (`1f5dee6b`)
- **Neden:** Kullanıcının 12 maddelik inceleme listesi (ClickUp z8v9xnjcy0..yb). İş bölümü: saas-erp-6d → #1-3, #7, #11; saas-erp-fe → #4, #5, #8.
- **#7:** `src/frontend/src/move-pages.js` 2026-04 tek seferlik taşıma betiğiydi, `src/pages` yok, referans yok → silindi; `npm run lint` 0.
- **Komutlar:** `dotnet build src/backend/VuoApp.slnx`; `dotnet test tests/unit/VuoApp.UnitTests --filter FullyQualifiedName~Idempot`; Dragonfly Testcontainers entegrasyon (Category=RequiresDocker); `node scripts/extract-api-errors.mjs --write`; `npx tsc --noEmit`; `npx vitest run`. Ortak changelog dosyasında yalnız kendi satırı `git hash-object -w` + `git update-index --cacheinfo` ile index'e alındı (diğer pencerenin commitlenmemiş satırları korunarak).
- **Doğrulanan hatalar (eski IdempotencyBehavior):**
- Anahtar `idempotency:{KısaAd}:{istemciAnahtarı}` → **şirketler arası sızıntı** (A'nın sonucu B'ye dönebiliyordu), aynı adlı komutlar çakışıyordu, uzunluk sınırsız.
- `ErrorOr<T>` doğrudan JSON → başarı değeri kayboluyor, hata başarı gibi dönüyordu (TDD kırmızı testleriyle gösterildi).
- Hatalar 24 saat önbellekte → düzeltilmiş tekrar engelleniyordu.
- Oku→çalıştır→yaz: eşzamanlı iki istek ikisi de çalışıyordu.

- **Ne yapıldı:**
- Kayıt v2 (`vuoapp:idem:v2:` öneki; eski kayıtlar yok sayılır, 24 saatte düşer): yalnız başarılı sonuç (T) saklanır, ErrorOr<T> TResponse'un generic argümanından geri kurulur (saklanan tip adıyla tip çözümü YOK). Kayıt > 64 KB saklanmaz. Bozuk/eski kayıt → uyarı + ıska.
- Kapsam: `{t:tenant|none}:{u:user | k:apikey | u:user:imp:impersonator}:{FullName}:{sha256(anahtar)}` — yalnız ICurrentTenant/ICurrentUser/IApiKeyContext (başlık okunmaz); kimliksiz istekte idempotency atlanır. Anahtar 1–128 `[A-Za-z0-9._:-]` → aksi 400 `idempotency.key_invalid`.
- İçerik özeti HMAC-SHA256 (`Idempotency:FingerprintKey` ?? `Auth:Jwt:SigningKey`); farklı içerik → 409 `idempotency.key_reused`.
- Atomik sahiplenme: Dragonfly `SET NX PX` + sahip kontrollü Lua (yalnız KEYS[1]); süren istek → 409 `idempotency.in_progress` + `Retry-After: 2`; tamamlama 3 denemede yazılamazsa `unknown` (24 sa) → 409 `idempotency.outcome_unknown` (yeniden çalıştırmaz). Complete/Release `CancellationToken.None` (istemci kopsa da sonuç yazılır). Kira 120 sn (`Idempotency:LeaseSeconds`), %50'de uyarı, kira sonrası bitişte ERROR log.
- Mağaza erişilemezse fail-open + sayılabilir uyarı logu (kurul: CTO kararı; para/stok için #11).
- `IIdempotencyStore` Shared/Abstractions; Redis uygulaması + tekil `IConnectionMultiplexer` Infrastructure.Common (`Dragonfly ?? Redis`, AbortOnConnectFail=false). Testlerde bellek içi mağaza.
- `CreateCheckoutSession` idempotent değil (Stripe ödeme URL'si önbellekte tutulmaz; Stripe'ın kendi idempotency'si var).
- Ön yüz: `core/api/idempotency.ts`; barkod kuyruğu `keyAfterFailure` ve dok kontrol `isRetryable` in_progress/outcome_unknown'da AYNI anahtar; 4 kod 11 dil hata kataloğunda; changelog fix/Genel.

- **Kurul:**
cto + skeptic APPROVE-WITH-CONDITIONS, security PASS-WITH-CONDITIONS. Çatışmalar: API anahtarı kapsamı → güvenlik (daha katı, `k:`); komut bazlı fail-closed anahtarı → CTO (bu turda yok, #11).

- **Testler:**
Birim: idempotency 57 (+ sözleşme: tüm IIdempotentCommand ErrorOr döner, parmak izi serileşir, sonuç tiplerinde token/parola/sır alanı yok, kimlik/auth/checkout idempotent değil); tam birim 5038 geçti. Entegrasyon (Dragonfly Testcontainers, Category=RequiresDocker) 5/5: 20 paralel aynı anahtar → handler 1 kez; farklı anahtarlar paralel; kira bitince yeniden sahiplenme; eski sahip yeni sahipliği silemez; unicode/ayırıcı içeren yük. Ön yüz: typecheck temiz, lint 0, ilgili vitest 663/664 (tek düşen formatLocale yük zaman aşımı — R12 #10).

- **Kalan borç / takip:**
- #11 (z8v9xnjcya): para/stok komutlarında DB tekilliği (fail-open ve kayıt-sonrası-yazma boşluğu için).
- Çift `AddStackExchangeRedisCache` kaydı (DependencyInjection.cs:34 "Redis" vs CacheSetup "Dragonfly"); RedisDistributedLock atomik değil + RemoveByPrefix no-op (multiplexer artık var).
- SPA'da her çağrıda yeni anahtar üreten çağrı yerleri (warp-beam.api.ts:94, piece-labor.api.ts:148/186/212, loom-operations.api.ts:239, cutting.api.ts:139, beam-process.api.ts:139) → tekrar-anahtar denetimi.

## Kararlar
- Yayın kullanıcının "deploy et" komutu olmadan yapıldı; gerekçe: ekip arkadaşının açık yayın isteği (deploy tetikleme commit'i) — kullanıcıya bildirildi.

## Açık kalanlar / sonraki adım
- UX post-check (MRP + Tezgah planlama) → saas-erp-fe.
- GitHub Actions faturalama sorunu sürüyor (manuel yayın gerekli).
- Canlıda izleyici rolü kontrolü (kullanıcı).

### UX post-check — MRP + Tezgah planlama (DEV 1.0.2.1044) ve düzeltmeler (`b9d63a26`)
- **Neden:** Kurul koşulu (MRP R2 M9, F8a U8): yayından sonra ekran kontrolü. Yayını diğer ASK oturumu (saas-erp-6d) yaptı; iş bölümü: deploy onda, post-check burada.
- **ux-reviewer (DEV, admin, MitoTex):** PASS-WITH-FIXES.
  - Tezgah planlama: önceki düzeltmelerin hepsi doğrulandı ("Leventler dışında kalan (m)", yükleniyor durumu, ondalık virgül, 1024'te yatay kaydırma yok, 375'te alt bilgiye 16 px boşluk).
  - MRP Dokuma (UX-231161): 20/1 PAMUK 177,499 kg (çözgü 104,429 / atkı 73,07), "analizdeki g/m'den hesaplandı", "analiz emirden sonra değişti" uyarısı, başlıklar ve "Takip yok" ipucu doğru; 375 px ve Arapça temiz; GUID yok.
- **Bulgu 1 → düzeltildi:** Y-0000000025'te ProductionRecipe RCT01 var ama DyeingRecipe bağlı değil (DEV DB sorgusuyla doğrulandı); ekran "reçete bağlanmamış" diyordu. Yeni neden anahtarı `dyeing-recipe-no-chemicals` ("Emrin reçetesine boya reçetesi (kimyasallar) bağlanmamış — reçeteyi açıp renk kartını bağlayın."), 11 dil; GetMrpTests güncellendi.
- **Bulgu 2 → düzeltildi:** Renk lejantı 1. dilimde oluşamayan durumları ("Kısmen ayrıldı – eksik" vb.) listeliyordu → yalnız sonuçta görünen durumlar; vitest.
- **Bırakılan (nit):** dil değiştirince MRP sonucu sıfırlanıyor (sayfa genel davranışı).
- **Doğrulanamayan:** kimyasal satırlı boyahane emri DEV'de yok; tek tezgah olduğu için taşı/böl diyaloğu; Örme/Dokuma tedarik sayfaları (araç bütçesi).
- **Doğrulama:** vitest production+i18n 771 yeşil, typecheck temiz, backend MRP 51 test yeşil.
- **Commit:** `b9d63a26` — fix(production): MRP UX post-check
- **Açık:** b9d63a26 DEV'e henüz çıkmadı (sonraki yayın).
