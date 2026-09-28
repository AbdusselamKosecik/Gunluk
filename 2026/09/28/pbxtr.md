# pbxtr — 2026-09-28

## Bağlam
Kullanıcı: *"Devam edelim"*. `yonetim/bekleyen-maddeler.md`'de kod işi kalmamıştı: yalnız
"es geç" denenler (BR-C2-1/2, BR-DB-74, BR-OPS-14) ve boş bırakılanlar (BR-10, BR-OPS-09)
duruyordu. Sıradaki doğal iş dün açılan **BR-DB-117** idi: BR-DB-67 öncesi açılmış bayi
personelini (demo.bayi → t0007) bayinin ev tenant'ına taşımak.

Yerel Docker kapalı. Ölçüm test sunucusundaki PostgreSQL'de yapıldı
(`root@176.88.41.220`, `pbxtr-postgres`), **her koşu `BEGIN … ROLLBACK`**, kalıcı hiçbir şey
yazılmadı.

## Yapılanlar

### 1. BR-DB-117 — `pbxtr_sys.relocate_dealer_staff_to_home`
- **Neden:** `users(id, home_tenant_id)` dört **ertelenemez** bileşik FK'nin hedefi
  (`user_roles`, `queue_members`, `agent_skills`, `extensions` — sunucuda `pg_constraint`'ten
  ölçüldü). `users_tenant_isolation` WITH CHECK (`home_tenant_id = app_current_tenant()`)
  **çapraz dal taşımıyor**. EF çapraz kipte yazamıyor, uygulama rolü de GUC'u kendisi
  çeviremiyor. Satır ancak tek işlemde ve GUC ev tenant'ına çevrilerek taşınabiliyor.
- **Ne yapıldı:**
  - 01'e SECURITY DEFINER, CALLER-CROSS bir fonksiyon (`move_tenants_to_dealer` kalıbı).
    Adımlar: rolleri sil → `set_config('app.tenant_id', ev)` → `users` UPDATE → rolleri ev
    tenant'ıyla geri yaz → GUC'u önceki değere döndür.
  - Taşınan küme: `scope = dealer` + `dealer_id` + ev tenant'ı o bayinin ev OLMAYAN tenant'ı.
  - Kilit: bayinin tüm tenant'larında sıralı danışma kilidi, tek tanımdan
    (`pbxtr_tenant_staff_lock_key`). Her yazımdan sonra row_count doğrulanıyor.
  - Hata kodları: PT005 ev tenant'ı yok, PT006 müşteri tenant'ına bağlı satır
    (DETAIL `{userId, count}`), çapraz kip dışında 42501.
  - Uygulama: `IDealerStaffRelocation` + `EfDealerStaffRelocation`. Taşınan kullanıcı başına
    `user.updated` denetim satırı, ev tenant'ına yazılıyor. `PostgresErrors.DealerStaffRelocationErrorOf`.
  - Uç `POST /api/v1/dealers/{id}/home-tenant/staff` (`dealer.write` + `user.write`):
    200 / 404 / 409 `INVALID_STATE` (`meta.reason`) / 503.
  - Migration `20260928090000_DealerStaffHomeRelocation`: yalnız bu fonksiyonu 01'den çalışma
    anında kesiyor + 02'yi tazeliyor. `Down` bilinçli olarak boş (emsal
    `20260923090000`: 02 fonksiyonu beklediği için düşürmek açılış bekçisini kırar).
  - 02: sys envanteri 34→35 (md5 `385c50d4…`, toplam `ee78f17d…`, ikisi de sunucuda okundu).
    Kısmi tekil indeks envanteri 8→9 (`ux_tenants_dealer_home`) + `.expected` dosyaları.
- **Ölçüm (sunucu PG, `pbxtr_app` rolü, ROLLBACK):**
  - Çapraz kip dışında → 42501.
  - demo.bayi t0007 → ev tenant'ı; `dealer` rolü ev tenant'ıyla yazıldı; GUC geri yazıldı.
  - İkinci çağrı 0 satır; `permission_version` arttı; t0007 personel sayımı 1→0.
  - Ertelenmiş tutarlılık tetikleyicisi geçti.
  - **Ardından `move_tenants_to_dealer` t0007'yi taşıdı** (kartın hedefi).
  - Personelli ev tenant'ını taşıma → PT003. Bağlı beceri satırı varken → PT006.
  - `MaintenanceRunner.GuardAsserts`'in **30 iddiasının 30'u geçti.**
- **Yerel doğrulama:** Architecture 794/794, Api Tenancy 311/311, Platform 1394/1394.
  Mutasyon: uçtan `user.write` kaldırıldı → 1 kırmızı; geri alındı, 15/15.
- **Kapılar:**
  - kapi_07 (migration uyumluluk): Karar#86 onay satırı. Ayrıca 01 **şablon çıpası**
    taşındı: guard'ın kendi `ANCHOR_DENIED`'iyle ölçüldü, eklenen tek öğe yeni
    `SECURITY DEFINER` başlığı.
  - kapi_71 (şablon tazeleme): 01+02 bu migration'a bağlandı; K6 commit sonrası yeşil.
- **Commit:** `908d121b` — BR-DB-117: bayi personelini ev tenant'ina tasima + BR-DB-67 duzeltmeleri

### 2. Dünkü BR-DB-67'de üç kusur bulundu ve kapandı
- **Gerçek hata:** `Tenant.CreateDealerHome` saklamayı 0 yazıyordu.
  `ck_tenants_recording_retention_days` 0'a yalnız bayisiz tenant'ta izin veriyor. Yani
  `POST /api/v1/dealers` ve `…/home-tenant` üretimde **23514 ile düşecekti**. Yerel testler
  sahte provisioning kullandığı, entegrasyon testi de Docker kapalı olduğu için görmedi;
  sunucu ölçümünde ilk INSERT'te yakalandı. Düzeltme: saklama 1 gün.
- `ux_tenants_dealer_home` 02 kısmi indeks envanterinde yoktu (UYARI).
- Dünkü 01 değişikliği şablon tazeleme defterine bağlanmamıştı (kapi_71 KIRMIZI).
- Kart notu önce "DUZELTME" ile başladığı için ClickUp kartı `backlog`'a döndü. Metin
  "Bitti" ile başlatıldı. **Commit:** `f2da7b00`.

### 3. ClickUp
`clickup-senkron.js` → BR-DB-117 complete, BR-DB-67 complete. `--kuru`: fark 0, izde olmayan 0.

## Kararlar
- Personel taşıma tek yazma kapısıyla, DB'de. Uygulama katmanında GUC çevirme **yok**.
- Müşteri tenant'ına bağlı satırı (dahili / kuyruk / beceri) olan personel **taşınmaz**;
  otomatik silme yok, açık 409.
- Migration tüm 01'i değil yalnız fonksiyonu uygular (call-permission FAIL-CLOSED penceresi yok).

## Açık kalanlar / sonraki adım
- **Integration.Tests hiç koşmadı:** `BrDb67_*` (5), `BrDb117_*` (3, biri sızıntı testi) ve
  `DealerHomeTenant` + `DealerStaffHomeRelocation` + `RingGroupExternalMember` + 09-25 migration'ları.
- Kısmi indeks bekçisi 8 **başka** kayıt dışı indeks için UYARI veriyor (`ux_silence_*`,
  `ux_wallboard_layouts_*`, `ux_callback_entries_*`, `ux_tickets_open_qa_objection`).
  Yayını kırmıyor, benim işim değil; kartsız.
- Kullanıcı testi (demo.bayi): migrate → `…/home-tenant` 201 → `…/home-tenant/staff` 200 →
  demo.bayi yeniden giriş → t0007'yi başka bayiye taşı 200.
