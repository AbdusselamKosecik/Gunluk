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
