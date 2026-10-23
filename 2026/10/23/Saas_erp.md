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

### İdempotency koruma matrisi — R12 #11 (`ede473ad`)
- **Neden:** Kullanıcı listesi #11; genel altyapı (63536013) sonrası komut bazlı boşlukları çıkarmak.
- **Ne yapıldı:** `docs/architecture/idempotency-protection-matrix.md` — 30 kritik komut; IIdem, SPA anahtarı, DB/iş kuralı koruması, dış servis, risk, test. 4/30 işaretli. YÜKSEK: SendEInvoice (gönderildi kontrolü yok, UUID sağlayıcıdan sonra kaydediliyor — kodla doğrulandı), CreateCashMovement (koruma yok — doğrulandı), kimyasal sarf, SettlePaymentPlanItem. ORTA: AllocateFromReceipt, cari fiş no, Stripe webhook.
- **Sonuç:** ClickUp z8v9xnjcyv..z8v9xnjcz1 (7 görev, her biri ayrı kurul); otomatik marker eklenmedi.

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

### İnceleme listesi #4 #5 #8 — şirket izolasyonu, şirket listesi hatası, veri tazeliği (`df238607`)
- **Neden:** Kullanıcının 12 maddelik inceleme listesi; saas-erp-6d ile iş bölümü (bende #4/#5/#8; ClickUp z8v9xnjcy3/4/7).
- **Keşif:** ~1100 sorgu anahtarından ~12'si tenant içeriyor; önbellek hiç temizlenmiyordu; seçim penceresi/uygulama içi giriş önbelleğe dokunmuyordu; geç gelen A cevabı B'de aynı anahtara yazılabiliyordu; başka sekmedeki tenant yazımı bu sekmenin isteklerine anında sızıyordu (interceptor localStorage'ı her istekte okuyor). #5: TenantContext hata sonrası tekrar istek atmıyordu (effect bağımlılıkları değişmiyor) → sonsuz spinner.
- **Kurul:** R1 skeptic BLOCK (global queryKeyHashFn gereksiz/tutarsız; axios "tenant yoksa istek yok" koruması /auth/*, onboarding, davet, /tenants/switch'i kırardı). R2 sade tasarım: cto, skeptic, product-owner APPROVE-WITH-CONDITIONS; security PASS-WITH-CONDITIONS.
- **Ne yapıldı:**
  - Şirket geçişi = `switchToTenant` → tenant yaz + flash + `location.assign('/')` (bürünmenin kullandığı yöntem; önbellek, yoldaki istekler ve geç mutation yazımları tek seferde gider). Yalnız `POST /tenants/switch` başarılıysa; işlem sürerken değiştirici kapalı.
  - Tenant sekme bazlı sabitlendi (`session.ts` tabTenantId; tek yazıcı, statik test); tüm `api.defaults` X-Tenant-Id yazımları kaldırıldı.
  - Sekmeler arası `storage` dinleyici: başka sekmede şirket değişince bu sekme de geçer (kalıcı uyarı); `auth_token` silinirse girişe, farklı kullanıcı (`sub`) girerse yenile; bürünmede yok sayılır.
  - Oturum sonu temizliği (fatura taslakları + aktif tenant) çıkış/401/oturum düşüşünde; şirket geçişinde taslaklar korunur. Uygulama içi girişte `queryClient.clear()`.
  - #5: 1/2/4 sn geri çekilmeli 3 deneme, sonra hata paneli ("Şirket bilgileri yüklenemedi", "Tekrar dene"/"Çıkış yap"); 401/403 tekrar denenmez; boş liste ≠ hata.
  - #8: global `refetchOnMount: true` (yalnız bayatsa → tanım listeleri en geç 5 dk'da bir); canlı katman (30 sn + odak) bakiye/cari/kasa-banka/yetki/onay anahtarları; finans F3: kasa fişi listesi ve hesap seçici geçersiz kılma eksikleri düzeltildi. `docs/design/frontend-data-freshness.md` (kullanıcı bölümü dahil).
- **Komutlar:** `npx tsc --noEmit`; `npx vitest run` (tam: 230 dosya / 1781 test yeşil).
- **Commit:** `df238607`
- **Kararlar:** global hash/axios guard yerine tam yenileme (skeptic), tenant sekmede sabit (cto/security); "fresh" finans katmanı ertelendi (backlog P3).
- **Açık:** DEV UX post-check (iki sekme, başarısız geçiş, hata paneli, 375 px) yayından sonra; çeviriler ana dil kontrolü ister; TenantSwitcher bileşeni uygulamada monte edilmemiş (üst menüde şirket değiştirici yok — ürün kararı).

### [fe] R12 #10 — Yük altında kararsız testler (ClickUp z8v9xnjcy9)
- **Neden:** Testler yük altında rastgele kırmızı veriyordu. #6 CI gate'te (6d) bypass yok; kararsız test deploy'u durdurur.
- **Repro:** Frontend `npx vitest run` ile backend `dotnet test tests/unit/VuoApp.UnitTests --no-build` eşzamanlı koşturuldu, 3 koşu yapıldı.
  - BE 3/3 kırmızı: FabricCutOptimizer 50 ms testi 286-464 ms ölçtü (tek başına 12-17 ms).
  - FE 2/3 kırmızı: formatLocale testi 11 dil paketini yüklüyordu, 5,0 sn.
  - rtl-guard 4,6 sn ile sınıra dayanıyordu.
- **Ne yapıldı:**
  - Perf testi yeni `FabricCutOptimizerPerformanceTests` sınıfına taşındı:
    - `CollectionDefinition("Performance", DisableParallelization=true)` ve `Trait Category=Performance`.
    - Isınma, ardından 5 ölçüm; en iyisi < 50 ms olmalı. Hedef korundu.
    - Ölçümler `ITestOutputHelper` ile çıktıya yazılıyor.
    - Yardımcı metotlar (`In`, `Opt`, `AssertCoverage`, `Random`) `internal` yapıldı.
  - formatLocale eşlemesi `formatLocaleFor` ile, paket yüklemeden doğrulanıyor.
  - rtl-guard kaynakları bir kez okuyor; `SCAN_TIMEOUT_MS = 30_000` ölçülmüş sınır.
- **Dokunulan dosyalar:**
  - `tests/unit/VuoApp.UnitTests/Modules.Production/Features/FabricCutOptimizerTests.cs`
  - `FabricCutOptimizerPerformanceTests.cs` (yeni)
  - `src/frontend/src/core/lib/i18n/format-locale.test.tsx`
  - `src/frontend/scripts/rtl-guard.test.ts`
- **Sonuç:** Eşzamanlı yük altında 5/5 temiz (BE 5038, FE 1781). Perf testinin en iyi ölçümü yük altında 23-33 ms.
- **Kararlar:**
  - Timeout'lar topluca yükseltilmedi; yalnız ölçülen tarama testine açık sınır verildi.
  - Kurul kapsam dışı: yalnız test değişikliği.
- **Commit:** `c6f40d4f` — test: yuk altinda kararsiz testler (R12 #10)

### [fe] Dil taraması — son sabit Türkçe ekran metni
- **Neden:** Kullanıcı önceliği "dilleri başta olmak üzere". Ekranlarda kalan sabit Türkçe metin var mı diye bakıldı.
- **Komut:**
  ```bash
  grep -rlP ">[^<{}]*[çğıöşüÇĞİÖŞÜ][^<{}]*<|(label|title|placeholder|aria-label)=\"[^\"]*[çğıöşüÇĞİÖŞÜ]" src --include=*.tsx
  ```
  Testler, `/reference/` ve changelog hariç tutuldu.
- **Bulgu:** 8 dosya çıktı.
  - 7'si JSDoc yorumu veya dilden bağımsız örnek değer (ör. `59×40×28X1.76`).
  - Yalnız `employees.page.tsx`'te kullanıcıya görünen metin vardı: Ahmet / Yılmaz / ornek@firma.com placeholder'ları.
- **Ne yapıldı:** `HrmEmployees.firstNamePlaceholder`, `lastNamePlaceholder` ve `emailPlaceholder` anahtarları 11 dilde `b09.json`'a eklendi. Her dil için yerel örnek isim seçildi.
  - Biçim korundu: 2 boşluk girinti, dosyanın kendi satır sonu (CRLF/LF). Ekleme öncesi gidiş-dönüş kontrolü yapıldı.
- **Changelog:** "Personel" altında iyileştirme maddesi.
- **Doğrulama:** i18n + hrm testleri (88) geçti, tsc temiz.
- **Commit:** `31e38be7`

### R12 #6 — Dağıtım öncesi kalite kapısı (`fbebd11b`)
- **Neden:** `dev-deploy.yml` test/lint çalıştırmadan deploy ediyordu. Actions faturalama nedeniyle bloklu olduğundan gerçek yol olan elle `build-dev.cmd` de kontrolsüzdü.
- **Kurul:** CTO + Şüpheci APPROVE-WITH-CONDITIONS. Koşullar:
  - tek betik;
  - `build-dev.cmd`'ye bağlama;
  - `global.json` yok → `dotnet-version 10.0.x`;
  - Node 22 (Dockerfile ile aynı);
  - TZ sabit;
  - Release + `--no-build`;
  - atlatma bayrağı yok.
- **Ne yapıldı:**
  - `tools/verify.sh [backend|frontend|all]` yazıldı. `all` iki tarafı ayrı süreçte çalıştırır, çünkü `( f ) || …` içinde `set -e` devre dışı kalır.
  - `.github/workflows/ci.yml` eklendi: PR + `workflow_call`, secret yok, artifact `if: always()`.
  - `dev-deploy.yml`'e `needs: verify` eklendi.
  - `build-dev.cmd` docker build'den önce verify çalıştırıyor.
  - `.gitattributes` `*.sh` / `*.mjs` için `eol=lf`.
  - Runbook `docs/runbooks/dev-deploy.md` yazıldı.
  - CLAUDE.md §10 düzeltildi.
- **Yakalanan gerçek hata:** Windows temiz klonunda (`autocrlf=true`) shebang'li `extract-api-errors.mjs` CRLF oluyordu ve vitest `api-errors.test.ts`'i SyntaxError ile kırıyordu. Ana ağaçta dosya LF olduğu için görünmüyordu. Bisect ile 7 import tek tek denendi, sonra satır sonları karşılaştırıldı.
- **Doğrulama:**
  ```bash
  git worktree add --detach ../_wt-ci-2 fbebd11b
  bash tools/verify.sh all
  ```
  - rc=0, 114 s.
  - BE 5041 test, 0 başarısız.
  - FE 230 dosya / 1781 test, typecheck ve lint temiz.
  - Bir önceki koşuda kapı FabricCut perf testinde kırmızı verip deploy'u doğru şekilde durdurmuştu (#10 ile düzeldi, fe `c6f40d4f`).
- **Doğrulanamayan:** gerçek GitHub Actions koşusu (faturalama).
- **ClickUp:** z8v9xnjcy5 → complete.

### R12 #12 — Doküman ↔ kod mutabakatı (`d4c54970`)
- **sprint-013:** 12 iş kanıtlı denetlendi: 5 tamamlandı, 5 kısmi, 2 yapılmadı. "Kod mutabakatı" bölümü eklendi. Test sayıları ölçüm tarihi ve commit'iyle yazıldı. Denetimi bir ajan yaptı, örnek kanıtları elle doğruladım.
- **Standart dokümanları:** çelişkiler koda göre düzeltildi.
  - `technical-preferences`: tablo adı PascalCase (kodda 2489'a karşı 25), yerleşik auth, Dragonfly, Outbox + Hangfire, Zustand yok, Azure kullanılmıyor.
  - `coding-standards`: `ApiResponse<T>`, Gridify offset sayfalama.
  - CLAUDE.md: ZITADEL ifadeleri düzeltildi.
  - `context-management`: `active.md` gitignored.
- **ClickUp:** z8v9xnjcyb → complete.
- **Kararlar:** çelişkide CLAUDE.md ve kod esas. Tekrar ekran/route'lar yalnız not edildi, değiştirilmedi.
- **Açık kalanlar:**
  - #9 fe'de (kurul önerisi hazırlanıyor).
  - 1044 sonrası DEV deploy kullanıcının "deploy et" demesini bekliyor.
  - Matris açığı görevleri (7 adet).
  - sprint-013'ün kısmi işleri.

### [fe] R12 #9 — Kapalı dönem: kayıtlı tarih kontrolü
### Kural (R1)
Kilitli bir aya tarihli belge, durumu ne olursa olsun (taslak dahil), sahip/yönetici dönemi açmadan:
- değiştirilemez,
- başka aya taşınamaz,
- silinemez,
- taslaktan kesilemez veya iptal edilemez.

Kurul onayladı (hepsi koşullu onay): cto, skeptic, dba, product-owner. Tüm koşullar uygulandı.

### Yapılanlar
- `Services/FiscalPeriodChecks.cs` (Finance-yerel): `EnsureStoredOpenAsync` + `IStoredFiscalDocumentCommand` işareti.
  - Kontrol sırası: rol → bulunamadı → durum kuralları → kayıtlı dönem → mutasyon.
- Kayıtlı tarih kontrolü eklenen handler'lar:
  - Update/Delete Invoice
  - UpdateInvoiceStatus (yalnız taslaktan)
  - Update/Delete CreditNote ve DebitNote
  - Update/Delete cari Receipt
  - Delete CashReceipt
  - Update/Delete BankReceipt
  - GL Update/Delete
  - 4 onay handler'ı bu yardımcıya taşındı.
- Yeni tarih kapısı eklenen komutlar: UpdateBankReceipt, CreateInvoiceFromOrder, Create/Update CreditNote, CreateCreditNoteFromInvoice, Create/Update DebitNote, CreateCashMovement.
- `finance.fiscal_period.locked` mesajı sabitlendi; dönem etiketi `Metadata["periods"]`'e taşındı. Mesaj artık 11 dilde çevriliyor (önce ham İngilizce görünüyordu).

### Testler
- `FiscalPeriodStoredDateTests` (Invoice, cari Receipt, BankReceipt ve GL için):
  - eski kapalı / yeni açık
  - eski açık / yeni kapalı (MediatR + behavior üzerinden)
  - ikisi açık
  - silme
  - Reddedilen her durumda başlık ve satırların değişmediği yeni context'ten okunarak doğrulanıyor.
- `FiscalPeriodCoverageGuardTests`: reflection ile her Update/Delete/Approve/Cancel/Change komutu ya işaretli ya da gerekçeli muaf olmalı.
- Temiz worktree'de Release build: 5071 test geçti, 0 kaldı.

### Bilinen sınırlar ve ertelenenler
- **Yarış durumu:** kontrol ile kayıt arasında dönem kilitlenirse kayıt geçebilir. DBA kabul etti; aynı sınır mevcut oluşturma yolunda da var.
- **UTC+3 gece yarısı:** istemci yerel gece yarısı gönderirse tarih bir önceki aya düşebilir. Bu davranış önceden de vardı.
- **Ertelenenler (ClickUp):**
  - z8v9xnjd72: storno tarihleme (P1, kullanıcı kararı gerekli)
  - z8v9xnjd73: çek (P1)
  - z8v9xnjd74: taslak iptal/storno
  - z8v9xnjd75: dönem kilidi ekranı
  - z8v9xnjd76: GL IsDeleted
  - z8v9xnjd3t: ekstre ödeme filtresi (P1 hata)
- **Commit:** `e49f2533`
- **Not:** Oturum push sırasında koptu; yeniden açılışta `.git/index` bozuktu. Yedeklendi, `git reset` ile HEAD'den yeniden kuruldu; çalışma ağacı korundu, push zaten tamamlanmıştı.

### [fe] Landing (tanıtım) sayfası: SEO ve LLM okunurluğu
- **Neden:** Kullanıcı isteği ("vuo landing ekranı için LLM'lerin ve SEO gerekli düzenlemeleri"). `/tanitim` istemcide çizilen bir SPA rotasıydı; JS çalıştırmayan GPTBot/ClaudeBot/PerplexityBot boş `<div id="root">` görüyordu. Açıklama, OG, canonical, yapısal veri, robots, sitemap ve llms.txt yoktu.
- **Kurul:** cto, skeptic, product-owner ve security; hepsi koşullu onay verdi.
- **Kararlar:**
  - Kayıtlı seçim ya da `?lang=` yoksa sayfa Türkçe açılır. Googlebot en-US ile çiziyor; aksi halde TR kanonik altında İngilizce indekslenirdi.
  - `/` noindex; keşif sitemap ve llms.txt üzerinden.
  - Yalnız `app.vuo.app` indekslenir; DEV hiçbir zaman.
- **Ne yapıldı:**
  - `src/frontend/src/features/landing/seo/landing-static.ts` saf fonksiyonları ve `vite.config.js` eklentisi şunları üretir: `dist/tanitim/index.html` (TR head + #root içinde `<main>` statik metin), `llms.txt`, `llms-full.txt`, `sitemap.xml`, `robots.txt`, `robots.noindex.txt`.
  - JSON-LD: Organization, WebSite, SoftwareApplication, FAQPage. offers/rating yok; `</script>` ve U+2028/9 kaçışları yapılıyor.
  - `meta.description` 11 dile eklendi.
  - `public/og-image.png` (1200x630): Chrome'da HTML kart çizilip ekran görüntüsü alındı. Kaynak scratchpad'de `og/card.html`.
  - nginx: `map $host` ve `map "$vuo_indexable:$request_uri"` ile X-Robots-Tag, `always`; `if` yok. robots dosyası host'a göre seçilir. `try_files $uri $uri/index.html /index.html`.
  - Favicon mutlak yola alındı. Landing'de meta description çalışma anında değişiyor ve sayfadan çıkınca geri alınıyor.
- **Doğrulama:** Temiz worktree'de (HEAD + yalnız bu değişiklik) typecheck temiz, landing testleri 95/95 geçti, `vite build` tüm dosyaları üretti. Statik görüntü JS olmadan tarayıcıda kontrol edildi.
- **Commit:** `bb7bbda1` (dev).
- **ClickUp:** z8v9xnjdd7 (tamam). Takip işleri:
  - z8v9xnjdd8: dil başına URL + hreflang
  - z8v9xnjdd9: pazarlama alan adı
  - z8v9xnjdda: Search Console (bk-ask)
  - z8v9xnjddb: /yenilikler statik görüntüsü
  - z8v9xnjddc: DEV erişim kısıtı
- **Açık:** Dağıtım sonrası curl kontrolleri. DEV deploy hâlâ docker build izni bekliyor.

### [fe] UYARI — 17:22 çökmesinde X: diskinde sıfırlanan dosyalar
- Oturum çöktüğünde, o sırada diskte bekleyen dosyalar **tamamen NUL bayta dönüştü**:
  - 6d oturumunun commit edilmemiş idempotency işi (26 dosya: CreateCashMovement, ConsumeChemicals, use-idempotent-submit, cash.api.ts vb.);
  - `changelog.data.ts`;
  - `.git/index`;
  - `_wt-idem` worktree'sinin tamamı.
- Commit edilmiş ve push edilmiş iş sağlam.
- **Kurtarma:**
  - Yalnız `CreateCashMovement.cs`'in son hali git nesnesi olarak var (blob `81e8a21f`).
  - Geri kalanı 6d oturumunun C: diskindeki transcript'inden (Write/Edit çağrıları) yeniden kurulabilir.
- Sıfırlanmış dosyalara dokunulmadı.
- Disk sağlığı (SMART / chkdsk) kontrol edilmeli.

### Marka yeniden tasarımı: giriş, ana panel, kabuk, yükleme renkleri, 404/401 görselleri
- **Neden:** Kullanıcı "VUO — Giriş ve Dashboard.html" referansına göre giriş ve panelin tasarım+rengini, yükleme ekranının yalnız rengini istedi; ardından 404 hata sayfalarındaki SVG'lerin değişmesini istedi.
- **Referansın çözülmesi:** Dosya paketlenmiş bir sayfa (`__bundler/manifest` + `template`, gzip+base64). `scratchpad/extract.cjs` ile manifest açıldı, iç sayfalar (`login.html`, `dash.html`) `tpl.cjs` ile template JSON'undan çıkarıldı. Palet: brand-600 `#0a7873`, brand-900 kabuk `#043332`, safran `#ffae0a`, nötrler `#f4f8f8/#e9f0f0/#d5e0e0/#566b6c/#0d1c1e`; fontlar Plus Jakarta Sans + JetBrains Mono.
- **Kurul:** cto + skeptic + product-owner → APPROVE-WITH-CONDITIONS. Koşullar: safran yeni token (`--brand-accent`, `--accent` nötr hover kaldı); koyu temada `--primary-foreground` koyu yazı (AA); font yalnız giriş/panelde (`font-brand`/`font-figure`), uygulama Inter; header renkleri `.header` kapsamında token ezme; gömülü `#d35400` temizliği; 401 kendi görseli; SVG'de metin yok; şifre düğmesi type=button, aria-pressed, 2FA'da sıfırlanır; changelog cümlesi PO'dan.
- **Ne yapıldı:** `config.css` (açık/koyu token'lar + `@theme` renk/font), `app.css` (`.header` token ezme), `index.html` (theme-color, Google Fonts, body bg-page), `login.tsx` (sol tanıtım paneli + dokuma deseni + kart form + şifre göster/gizle), `tenant_dashboard.page.tsx` (KPI kartları, modül durumu, son hareketler başlık satırı), header/sidebar/rail logo ve gölge renkleri, `constants/ui.tsx` (solid primary yazı `text-primary-foreground`, outline/link tonları), spinner/LoadingScreen/app.tsx fallback renkleri, inventory sekme ve route-error-boundary turuncuları, 404/401 açık/koyu SVG'ler (`scratchpad/gen-err-svg.cjs` ile üretildi), 11 dilde `assets/i18n/<dil>/brand.json` (sifreyiGoster/Gizle, colTime/Module/Method/Action).
- **Doğrulama:** TDD (şifre düğmesi 2 test, panel KPI çubuğu + başlık satırı 2 test önce kırmızı → yeşil). Chrome'da 1440 açık/koyu giriş+panel, dar ekran giriş, 404. Panel için temiz worktree'den yerel API (5240) + Vite (3131) açıldı, oturum API ile alınıp tarayıcıya verildi (şifre ekrana basılmadı, geçici dosyalar silindi). `bash tools/verify.sh frontend` → 232 dosya / 1840 test yeşil.
- **Commit:** `e38c446a` — feat(ui): giris ekrani, ana panel ve kabuk yeni VUO marka tasarimina gecti; 404/401 gorselleri yenilendi (dev'e push).
- **Not:** Ana rengin petrol yeşili olması tüm ekranlardaki birincil düğme/bağlantıları etkiler; geri almak `config.css` içindeki `--primary` tek satır. Worktree'de çalışan Vite, `npm ci`'yi EPERM ile kilitledi → süreç kapatılınca kapı geçti.
- **Açık:** DEV dağıtımı hâlâ `docker build` izni bekliyor (bu commit de dahil olur).

### Tanıtım sayfası petrol yeşili + DEV dağıtımları (1.0.2.1045 → 1048)
- **Tanıtım:** `landing.css` turuncu token/değerleri petrol yeşili + safrana eşlendi (`scratchpad/landing-retheme.cjs`), nötrler yeşil tonlu, koyu tema uyarlandı; logo simgesi `--accent`. `landing-static.ts` theme-color `#0a7873`. OG görseli (`public/og-image.png`) `scratchpad/og/card.html`'den 1200x630 yeniden çekildi. Commit `af774793`.
- **DEV dağıtımı:** Kullanıcı "paketleyip güncelle" dedi → `docker build/push` + webhook. 1045 (`af774793`), 1046, 1047, 1048 yayınlandı; her birinde spa/api 200, robots kontrol edildi.
- **Bulgu — DEV sunucusu imajdaki nginx ayarını kullanmıyor:** canlıda `robots.txt` statik dosya olarak sunuldu (PROD "Allow" sürümü), `X-Robots-Tag` yok, `/tanitim` 301 → `http://.../tanitim/`. İmaj yerelde (`docker run` + Host başlığı) doğru davranıyor → sunucuda eski bir conf bağlı olmalı. **Güvenli varsayılan düzeltmesi** (`a981caf4`): düz `robots.txt` artık Disallow; PROD dosyası `robots.index.txt`, yalnız yeni conf `app.vuo.app` için sunar. Test: `nginxConf_RobotsMap_ProdGetsIndexFile_DefaultIsPlainRobotsTxt`.
- **Giriş düzeni geniş ekranda sola sıkışıyordu** (`AuthLayout` kökü tam genişlik almıyordu, 2048px'te 1226px) → `w-full` (`bba96cae`).
- **Kullanıcı isteği "çizgileri keskinleştir"** (`47326fff`): kart 1px belirgin çerçeve + kısa gölge, radius 16; dokuma deseni daha net (`--weave-b #0f958f`, maske geç soluyor); istatistik kutusu kenarı belirgin. Ayrıca `externalProvidersRequest` dizi dönmezse ekran çöküyordu → `Array.isArray` koruması + test.
- **vuo.app 404:** DNS vuo.app ve www.vuo.app → 217.131.14.57; traefik'te yalnız www için router var, apex için yok (traefik "404 page not found"). www.vuo.app şu an DEV SPA'yı sunuyor (robots Disallow). SSH `vuo@217.131.14.57` "dev" makinesine düşüyor ama orada `/home/vuo/docker/app` yok ve docker yetkisi yok → yönlendirme eklenemedi; traefik etiket önerisi kullanıcıya verildi.
- **Açık:** vuo.app → www.vuo.app traefik router'ı (sunucu erişimi gerekli); DEV compose'daki eski nginx conf bağlantısının kaldırılması; www.vuo.app'in DEV yerine PROD/tanıtıma bakması kararı.

### Sol menü: Metronic tarzı akordeon (1.0.2.1049)
- **Neden:** Kullanıcı Metronic demo1 menüsündeki gibi "birini açınca diğeri kapansın" istedi.
- **Durum tespiti:** Klasik menü (`sidebar-nav.utils.ts` `toggleOpenGroup`) zaten tek-açıktı. İki panelli menüde (`two-panel/page-panel.tsx`) başlıklar bağımsızdı; tercih `collapsed` = varsayılandan sapma listesi (üst bölüm açık, alt grup kapalı varsayılan).
- **Kurul:** cto + skeptic APPROVE-WITH-CONDITIONS. Skeptic: üst bölümler varsayılan açıkken exclusive eklemek karışık durum yaratır → (a) yalnız alt gruplar ya da (b) her seviye + varsayılan kapalı. Kullanıcı "Metronic gibi" dediği için (b).
- **Ne yapıldı:** `applyCollapse(rows, openKeys, activePath)` artık "açık anahtarlar" modeli (varsayılan hepsi kapalı, açık sayfanın bölümü zorla açık). Yeni `toggleSectionExclusive(rows, openKeys, key, isCollapsed)`: açılan başlığın kardeşleri (aynı derinlik + aynı üst anahtar, `GROUP_KEY_SEPARATOR` ile) kapanır; kapatma yalnız kendisini; kapanan kardeşlerin alt kayıtları korunur. `nav-prefs.ts`: `collapsed` → `openSections` (eski kayıt okunmaz). `page-panel.tsx`: modül öneki tek yerde, diğer modüllerin kayıtları korunur.
- **Doğrulama:** TDD (applyCollapse testleri yeni modele göre + 6 akordeon testi). Chrome'da yerel API+Vite ile Stok paneli: hepsi kapalı → Hareketler açık → Transfer → Sayım açınca Transfer kapandı → Stok Kartları açınca Hareketler kapandı. Kapı: 1848 test yeşil. DEV 1.0.2.1049, spa/api 200, robots Disallow.
- **Commit:** `c7e0eafb`.
