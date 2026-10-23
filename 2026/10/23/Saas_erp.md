# Saas_erp — 2026-10-23

## Bağlam
Önceki gün (2026/10/22/Saas_erp.md) F8a v2, MRP düzeltmesi (b793d3a6) ve dil işleri dev'e gönderilmişti; DEV 1.0.2.1043'te kalmıştı. Bu oturum iki pencerede (saas-erp-6d: yayın, saas-erp-fe: UX post-check) yürüyor.

## Yapılanlar

### 1. DEV 1.0.2.1044 manuel yayın (`a6058383`)
- **Neden:** GitHub Actions "DEV Deploy" faturalama yüzünden başarısız (3 deneme: b793d3a6, a58c961d, a6058383 — 4-5 sn'de failure). Ekip arkadaşı bykosecik dev'i DEV'e çıkarmak için `a6058383 chore: DEV deploy yeniden tetikle` attı → ekip isteği.
- **İçerik:** refakat formu Termin sütunu (a58c961d), ARK özel alan tabloları + UD_KOrderNo (cae8b917, 1dd06e9b), Tezgah planlama UX düzeltmeleri (835b70e8), onay penceresi dil (a95e7aff), MRP düzeltmesi (b793d3a6).
- **Komutlar:** Docker Desktop başlatıldı → `git worktree add --detach <scratchpad>/wt-a6058383 a6058383` → `docker build -q --build-arg VERSION=1.0.2.1044` (api: `-f src/backend/VuoApp.Api/Dockerfile src/backend`, spa: `-f src/frontend/Dockerfile src/frontend`) → `tekbirsoft/vuoapp-{api,spa}-dev:{1.0.2.1044,latest}` push → `curl http://217.131.14.57:56806/abdusselam.kosecik/1.0.2.1044` → worktree remove.
- **Sonuç / doğrulama:** status ok, pull_rc 0, up_rc 0; `/api/v1/profile` 401 (ayakta); 07487438..a6058383 aralığında yeni migration yok (son: WeavingLoomPlanF8a, uygulanmış).

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
