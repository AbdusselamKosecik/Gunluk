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

---

## Oturum (devam): Sunucuya PgBouncer kurulumu + Mongo incelemesi + migration

### 1. SSH erişimi
- Kullanıcı `~/.ssh/id_ed25519.pub`'ı `vuo@services` authorized_keys'e ekledi. Giriş: `ssh vuo@100.109.159.58` (vuo docker grubunda, sudo parola ister).

### 2. Disk dolumu — Mongo (Novu)
- Kullanıcı diski dolduranın `vuoapp-mongodb` (Novu'nun DB'si, `/home/vuo/docker/docker-compose.yml`) olduğunu buldu, container+volume'u silip yeniden kurdu → disk %100 → %33.
- Veri silindiği için kesin kanıt yok. Bulgular:
  - Novu koleksiyonlarında (`jobs`, `messages`, `notifications`, `executiondetails`) **hiç TTL index yok** → Novu kayıtları sonsuza kadar birikir.
  - Mongo container log'u limitsiz (`LogConfig {json-file map[]}`, `/etc/docker/daemon.json` yok); Novu servisleri sürekli bağlantı açıp kapatıyor, Mongo bağlantı başına 5 satır log yazıyor → ~1 GB/gün.
  - **Mongo 27017 internete açık** (`217.131.14.61:27017`, compose'da `"27017:27017"`), auth var ama taranmaya açık.
- Standby log'larında pgpool kaynaklı `too many clients already`, `remaining connection slots are reserved` ve `cannot execute UPDATE in a read-only transaction` (outbox UPDATE standby'a yönlenmiş) görüldü.

### 3. Sunucuda pgpool → PgBouncer
- **Neden:** Sunucudaki `/home/vuo/posgrasql` repo'dan farklıydı (2 standby, `ANY 1`, postgis, pgpool-autoattach, 7 projenin DB'si). Repo değil, sunucu esas alındı.
- **Komutlar:**
  ```bash
  cp -a /home/vuo/posgrasql /home/vuo/posgrasql.bak-20260924      # yedek
  # pgbouncer/{pgbouncer.ini,entrypoint.sh} scp; compose: pgpool+pgpool-autoattach → pgbouncer (9999:9999), x-logging 50m×3
  docker run ... pgb-probe (vuoapp_net) → vuouser SCRAM ile bağlandı (ön test)
  docker exec pgc-primary psql -U postgres -c "ALTER SYSTEM SET max_slot_wal_keep_size='10GB'" -c "select pg_reload_conf()"
  docker compose up -d --remove-orphans     # primary/standby'lar logging için yeniden oluştu
  ```
- **Karar:** `max_connections` 100'de bırakıldı — hot standby'da standby değeri primary'den küçük olamaz; 300 yapmak standby'ları açılmaz yapardı (önceki commit'teki 300 geri alındı). Havuz: 15+5, max_db 40, max_user 60.
- **Doğrulama:** dışarıdan :9999 okuma+yazma OK; 150 paralel istemci 0 hata; standby1/standby2 `streaming|quorum`; API yerelde PgBouncer üzerinden 9 sn'de Ready (şema 95 migration/471 tablo, seed OK), `pg_locks` advisory = 0 (sızıntı yok).
- **Commit:** `76ebf6a0` — chore(db): sync pg cluster config with live server, deploy PgBouncer (sunucu dosyaları repo'ya çekildi, drift kapandı).

### 4. Migration (vuo_dev)
- Bekleyen tek migration: `20260912140914_Sprint014_ProcessSequenceCheckAndEmployeeMachineDefaults` (önceden çakışan). 466a9a33 ile idempotent hale gelmişti.
- Ön kontrol: hedef index'ler yok, `RouteItem (TenantId, RouteId, SequenceNo)` mükerrer yok, kolonlar `IF NOT EXISTS`.
- `ConnectionStrings__DefaultConnection=<Migrations: :15433 direkt> dotnet run -- migrate` → uygulandı; status: 95 applied, pending none.

### Açık kalanlar
- Mongo: 27017'yi sadece Tailscale IP'sine bağla (`100.109.159.58:27017:27017`), mongo'ya logging limiti ekle, Novu için retention/TTL.
- Docker daemon genelinde log limiti (`/etc/docker/daemon.json`, sudo gerekir) — diğer compose'lar hâlâ limitsiz.
- Sunucuda eski `pgpool/` klasörü duruyor (kullanılmıyor), yedek: `/home/vuo/posgrasql.bak-20260924`.
- Novu verisi silindi → Novu'yu kullanan projelerin org/API key'leri yeniden oluşturulmalı.
- Prod `vuo` DB'sine migration uygulanmadı (prod API açılışta kendisi uygular).

---

## Oturum (devam): Sunucudaki açık işlerin kapatılması (sudo ile)

### 1. Docker genelinde log limiti
- **Neden:** `/etc/docker/daemon.json` yoktu → tüm container log'ları sınırsız.
- **Ne yapıldı:** `/etc/docker/daemon.json` = `{"log-driver":"json-file","log-opts":{"max-size":"50m","max-file":"3"}}` (`sudo install -m 644`), `sudo systemctl restart docker` (tüm container'lar kısa süre yeniden başladı, hepsi geri geldi).
- `/home/vuo/docker/docker-compose.yml`'e de `x-logging` anchor'ı + 15 servise `logging: *default-logging` (yedek: `docker-compose.yml.bak-20260924`, `.bak-20260924-2`).

### 2. Mongo — kök neden bulundu ve kapatıldı
- **Kök neden:** Novu'nun Mongo havuzu `maxIdleTimeMS` varsayılanı 10 sn → api/worker/ws her biri ~100 bağlantı/dk açıp kapatıyor; Mongo her bağlantıda 5 satır log yazıyor. Yeniden kurulumdan 30 dk sonra log 36 MB idi (~1,7 GB/gün), limitsiz json log'a gidiyordu. Buna TTL'siz Novu koleksiyonları eklenince disk doldu.
- **Düzeltmeler:**
  - `novu-api`, `novu-worker`, `novu-ws`: `MONGO_MAX_IDLE_TIME_IN_MS: "600000"` → auth/dk 300 → 0 (sadece healthcheck kaldı).
  - mongodb: `command: ["--quiet"]` (bağlantı accepted/ended/metadata log'ları kesildi).
  - mongodb port: `"27017:27017"` → `"127.0.0.1:27017:27017"` (internetten açıktı; Tailscale IP'ye bağlamak reboot'ta tailscale docker'dan geç kalkarsa Mongo'yu başlatmazdı). Compass: `ssh -L 27017:127.0.0.1:27017 vuo@100.109.159.58`.
  - Novu TTL (`collMod` ile mevcut `createdAt_1` index'i TTL'e çevrildi): executiondetails 30g, jobs 30g, notifications 90g, messages 90g. Novu restart sonrası sağlıklı, index çakışma hatası yok.
- **Doğrulama:** 217.131.14.61:27017 kapalı; tüm novu servisleri healthy; standby1/2 quorum; LogConfig tüm container'larda `max-size:50m max-file:3`.

### Kararlar
- Sudo parolası hiçbir dosyaya yazılmadı.
- Diğer internete açık portlara dokunulmadı (başka projeler/sunucular kullanıyor olabilir).

### Açık kalanlar (güvenlik — kullanıcı kararı)
- İnternete açık: 80 443 **3180 (Traefik dashboard, auth YOK)** 6379 (Dragonfly, parolalı) 9090/9091 (MinIO) 8083/5341 (Seq) 16686/4317/4318 (Jaeger) 9200 (ES, auth var) 4222/8222 (NATS) 18087/18088 **9001 (Portainer agent)** **9999/15433/15434/15435 (Postgres)**. Tailscale/127.0.0.1'e çekilmeli; önce dışarıdan kim bağlanıyor belirlenmeli.
- `/home/vuo/docker` hiçbir git repo'sunda değil — sunucudaki infra compose versiyonlanmıyor.
- Novu verisi silindi → Novu kullanan projelerin org/API key'leri yeniden.
