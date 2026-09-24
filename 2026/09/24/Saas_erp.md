# Saas_erp — 2026-09-24

## Bağlam
Yerelde commit'lenmemiş halde duran "Stok Kartı bağımsız 2. birim seti" işi vardı (20 dosya). Kullanıcı isteği: commit + push.

## Yapılanlar

### 1. İkincil birim seti özelliği commit'lendi
- **Neden:** Diskte duran iş kayıp risklidir; push edilmeyen iş bitmiş sayılmaz.
- **Ne yapıldı:** Backend (entity + SecondaryUnitSetWriter + Create/Update/GetById), frontend (2. Birim tab, inventory.detail, generic-table-request), migration `20260919205051_InventorySecondaryUnitSet`, testler ve tasarım dokümanı tek commit'te toplandı.
- **Dokunulan dosyalar:** `src/backend/VuoApp.Modules.Inventory/*`, `src/backend/VuoApp.Migrator/Migrations/20260919205051_*`, `MigratorDbContextModelSnapshot.cs`, `src/frontend/src/features/inventory/*`, `src/frontend/src/core/services/generic-table-request*`, `tests/unit/VuoApp.UnitTests/Modules.Inventory/*`, `docs/architecture/inventory-secondary-unit-set.md`
- **Komutlar:**
  ```bash
  git add <yollar> && git commit -F - && git push
  ```
- **Sonuç / doğrulama:** `e7380557..481ad9b0 dev -> dev` push edildi. Bu turda build/test çalıştırılmadı.
- **Commit:** `481ad9b0` — feat(inventory): independent secondary unit set on inventory cards

## Kararlar
- Değişiklikler atılmadı, commit'lendi (kullanıcı onayı ile).

## Açık kalanlar / sonraki adım
- Ortak dev DB'de eski `20260912140914_Sprint014_...` migration'ı hâlâ çakışıyor; yerel API `--skip-migrate` ile çalışıyor. Kurul/dba kararı bekliyor.
- Jenkins deploy URL'si 301 ile https'e yönleniyor, sertifika IP için geçersiz → deploy tetiklenmiyor.
- Jenkins log'unda sızan Docker Hub ve GitHub PAT'leri hâlâ iptal edilmeli.

---

## Oturum: DB 500 hatası → disk dolu teşhisi + pgpool → PgBouncer

### Bağlam
Dev ortamı (pgpool `100.109.159.58:9999`) 500 veriyordu. Kullanıcı pgpool'un bağlantı limitinden şüphelendi, limitsiz bir havuz istedi.

### 1. Teşhis — sunucu diski %100 dolu
- **Neden:** Kök neden bulunmadan havuz değiştirmek sorunu çözmezdi.
- **Ne yapıldı:** SSH anahtarım sunucuda yok. Tailscale üzerinden dockerize psql (`docker run postgres:18-alpine psql ...`) ile:
  - pgpool `:9999` → 6/6 `FATAL: unable to get session context`
  - primary `:15433` → `No space left on device`; `CREATE TEMP TABLE` bile `could not create file ... No space left`
  - standby1/standby2 slotları pasif, `:15434` kapalı; `synchronous_standby_names = ANY 1 (standby1, standby2)`
  - Tüm DB'ler toplam ~300 MB → diski DB verisi doldurmuyor.
  - Bir süre sonra primary disk dolu yüzünden çöküp recovery döngüsüne girdi ("not yet accepting connections").
  - Aynı host'ta MinIO (:9090), Seq (:5341), Jaeger (:16686), OTel (:4317), Dragonfly de çalışıyor.
- **Kullanıcı `df` çıktısı:** `/dev/mapper/ubuntu--vg-ubuntu--lv` 100 GB, %100, 0 byte boş.
- **Not:** Canlı sunucudaki cluster repo'daki compose'dan farklı (postgres alpine, 2 standby, ANY 1) — drift var.
- **Sonuç:** Diski neyin doldurduğu SSH olmadan görülemedi; kullanıcıya `du`/`docker system df` komutları verildi.

### 2. pgpool → PgBouncer
- **Neden:** pgpool `num_init_children=32` → en fazla 32 eşzamanlı istemci; `unable to get session context` bilinen pgpool hatası.
- **Ne yapıldı:**
  - `posgrasql/pgbouncer/pgbouncer.ini`: `* = host=pg-primary`, `pool_mode=transaction`, `max_client_conn=5000`, `default_pool_size=20`, `reserve_pool_size=10`, `max_db_connections=60`, `max_user_connections=200`, `max_prepared_statements=200`, `query_wait_timeout=30`, auth: `scram-sha-256` + `auth_query` (pg_shadow) + `auth_user=postgres`.
  - `posgrasql/pgbouncer/entrypoint.sh`: `/tmp/userlist.txt` içine sadece postgres parolasını env'den yazar.
  - `docker-compose.yml`: pgpool servisi silindi, `pgbouncer` (`edoburu/pgbouncer:v1.24.1-p1`, host `9999:6432` — app string'leri değişmesin diye) eklendi; `x-logging` 50m×3 tüm servislerde; primary `max_connections=300`, `max_slot_wal_keep_size=10GB`. `pgpool/failover.sh` silindi, failover artık elle (README).
  - **Kod:** Migration + seed OTURUM seviyesinde advisory lock kullanıyor → transaction pooling'de lock/unlock farklı sunucu bağlantısına düşer, kilit sızar, sonraki açılış kilitlenir. Çözüm: `VuoApp.Migrator/MigrationConnection.cs` → `ConnectionStrings:Migrations` (primary :15433 direkt), yoksa `DefaultConnection`. `MigrationRunner.AddMigratorDbContext`, `ModuleDbContextRegistration` bunu kullanır; `SeedingExtensions.SeedPlatformDataAsync` kilidi ayrı `NpgsqlConnection` üzerinde tutar.
  - Connection string'lere `No Reset On Close=true` (örnek + yerel dev config).
- **Dokunulan dosyalar:** `posgrasql/docker-compose.yml`, `posgrasql/README.md`, `posgrasql/pgbouncer/*`, `posgrasql/pgpool/failover.sh` (silindi), `CLAUDE.md`, `src/backend/VuoApp.Migrator/{MigrationConnection,MigrationRunner,ModuleDbContextRegistration}.cs`, `src/backend/VuoApp.Api/Extensions/SeedingExtensions.cs`, `appsettings.Development.json.example`, `tests/unit/VuoApp.UnitTests/Api/MigrationConnectionTests.cs`
- **Doğrulama:**
  - TDD: 4 test önce kırmızı (derleme), sonra yeşil.
  - `docker compose config -q` OK.
  - Yerel docker ağında postgres:18-alpine + pgbouncer: vuouser (userlist'te yok) doğru parola ile bağlandı, yanlış parola `SASL authentication failed`; **300 paralel istemci, 0 hata, Postgres'te sadece 30 bağlantı**.
  - Unit test: 3485 geçti, 2 kırık (Pms AllotmentPickup, QualityPermissionContract) — değişiklik öncesinde de kırık, ilgisiz.
- **Commit:** `3c5c0149` — feat(db): replace pgpool with PgBouncer transaction pooling

### Kararlar
- Kurul atlandı — kullanıcı açıkça "kurulu unut birşey sorma" dedi.
- Okuma/yazma ayrımı bırakıldı (300 MB veri için gereksiz); gerekirse Npgsql multi-host.
- Host portu 9999 korundu → app connection string'leri aynı kalır.

### Açık kalanlar / sonraki adım
- **Sunucu diski:** neyin doldurduğu bulunup temizlenmeli (docker log'ları / MinIO / Seq / Jaeger / Barman / imajlar şüpheli).
- Disk açılınca primary recovery'den çıkmalı, standby'lar bağlanmalı (`pg_stat_replication`); yoksa sync replikasyon commit'leri asar.
- Sunucuda: `git pull` + `docker compose up -d pgbouncer` + `docker compose rm -sf pgpool`; canlı config repo ile drift'li — dikkat.
- Ekip `appsettings.Development.json`'a `Migrations` bağlantısını eklemeli.
- Sunucuya SSH için `~/.ssh/id_ed25519.pub` authorized_keys'e eklenmeli.
