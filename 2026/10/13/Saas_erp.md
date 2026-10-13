# Saas_erp — 2026-10-13

## Bağlam
`dev` dalı remote'tan 50 commit gerideydi. Önce güncellendi, sonra kullanıcı herkese açık, sürüm sürüm bir değişiklik listesi sayfası istedi. Bu listeye ekipteki herkesin (ve ajanlarının) otomatik madde eklemesi için CLAUDE.md'ye kural olarak yazılması da istendi.

## Yapılanlar

### 1. Son değişiklikleri alma
- **Neden:** Başka makinelerden gelen 50 commit vardı (6 migration, fiş termin tarihi, mamul en, otomatik onay vb.).
- **Komutlar:**
  ```bash
  git fetch --all --prune && git pull --ff-only   # dev: 76ebf6a0 → b0910e43
  ```
- **Sonuç:** Fast-forward oldu, çakışma çıkmadı.

### 2. Herkese açık `/yenilikler` sayfası
- **Neden:** Kullanıcılar sürüm sürüm neyin değiştiğini görebilsin. Sayfa giriş gerektirmiyor.
- **Ne yapıldı:**
  - `features/changelog/changelog.types.ts`: `ChangelogRelease { date, items[] }`, `ChangelogItem { kind: new|improvement|fix, area, text }`.
  - `changelog.utils.ts`: `toReleaseVersion("2026-10-13") → "261013"` (logodaki `BUILD_VERSION` = `yyMMdd.HHmm` ile aynı tarih kısmı) ve `sortReleases` (en yeni üstte).
  - `changelog.data.ts`: tek kaynak. İlk dolum 2026-09-01'den bu yana feat/fix/perf commit konularından script ile yapıldı. Kapsamlar (scope) modül adına çevrildi: production→Üretim, inventory→Stok vb. migrations/db/ci atıldı.
  - `pages/changelog.page.tsx`: tarih başlığı + Yeni/İyileştirme/Düzeltme rozetleri. Badge ve Icons, barrel yerine doğrudan dosyalarından import edildi; böylece public sayfa sidebar ve route ağacını çekmiyor, test setup'ındaki barrel mock'una da takılmıyor.
  - `app.tsx`: lazy `ChangelogPage`, `path="yenilikler"` PrivateRoute dışında, RouteErrorBoundary ile sarıldı.
  - `login.tsx`: sürüm numarası span'ı `/yenilikler`'e giden Link'e çevrildi.
- **Dokunulan dosyalar:** `src/frontend/src/features/changelog/**`, `src/frontend/src/app.tsx`, `src/frontend/src/features/identity/pages/login/login.tsx`
- **Sonuç / doğrulama:** Changelog testleri 5/5 geçti. Typecheck temiz. Chrome'da girişsiz açıldı, konsolda hata yok.
- **Commit:** `4a611da1` — feat(frontend): herkese acik /yenilikler surum degisiklik listesi sayfasi; `7330b24a` — sayfanın kendi maddesi

### 3. CLAUDE.md kuralı (ekip geneli)
- **Neden:** Diğer arkadaşların ajanları da her feat/fix'te otomatik madde eklesin.
- **Ne yapıldı:** `CLAUDE.md` §9'a eklenen ZORUNLU kural şunları söylüyor:
  - Kullanıcıya görünen her feat/fix/perf commit'i aynı commit'te `changelog.data.ts`'e madde ekler.
  - Gün = sürüm. O günün kaydı varsa `items`'a eklenir, yoksa en üste yeni kayıt açılır.
  - Metin son kullanıcı diliyle, Türkçe karakterli yazılır. Teknik işler eklenmez.
- **Commit:** `4a611da1`

## Kararlar
- Sürüm = gün (yyMMdd). CI'daki `1.0.2.<run_number>` git geçmişinde görünmediği için kullanılmadı. Logodaki BUILD_VERSION ile tutarlı.
- Build sırasında git log'dan otomatik üretim seçilmedi: Docker context'i `src/frontend` olduğu için `.git` yok ve checkout sığ. Bu yüzden commit'lenen, elle bakımı yapılan bir TS veri dosyası kullanıldı; typecheck yapıyı doğruluyor.

## Açık kalanlar / sonraki adım
- İlk dolumdaki maddeler commit konusundan geldiği için Türkçe karaktersiz ve bazıları teknik terim içeriyor (StockLedger, EF, PUT). Public sayfa için elden geçirilmeli.
- `login.test.tsx`'teki 5 test bu değişiklikten önce de kırıktı (svgr / mock sorunu). Ayrıca düzeltilmeli.
- ESLint config'i `src/features/**` dosyalarını kapsamıyor ("no matching configuration").
