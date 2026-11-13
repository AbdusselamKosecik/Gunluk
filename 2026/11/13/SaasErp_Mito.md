# SaasErp_Mito — 2026-11-13

## Bağlam
Saas_erp (vuo-app/Saas_erp) projesinin "Mito" için ayrı bir repository olarak kopyalanması ve
docker/deploy isimlerinin Vuo'dan bağımsız hale getirilmesi istendi.

## Yapılanlar

### 1. Repo kopyası (tüm geçmiş + branch'ler)
- **Neden:** Mito, Saas_erp kod tabanıyla ama ayrı repo/deploy hattıyla yürüyecek.
- **Ne yapıldı:** Saas_erp mirror klonlandı, yeni private repo açılıp mirror push edildi.
  6 branch aktarıldı: main, dev, prod, feat/iki-panelli-menu, wip/order-variant-matrix,
  claude/nice-dijkstra-m1xwqe. `refs/pull/*` reddi normaldir (GitHub gizli ref'leri kabul etmez).
  Default branch: main. Yerel klon: `X:\GitHub\vuo-app\SaasErp_Mito`.
- **Komutlar:**
  ```bash
  git clone --mirror https://github.com/vuo-app/Saas_erp.git mirror.git
  gh repo create vuo-app/SaasErp_Mito --private --description "SaasErp - Mito kopyasi"
  cd mirror.git && git push --mirror https://github.com/vuo-app/SaasErp_Mito.git
  gh repo edit vuo-app/SaasErp_Mito --default-branch main
  cd X:/GitHub/vuo-app && git clone https://github.com/vuo-app/SaasErp_Mito.git SaasErp_Mito
  ```
- **Sonuç:** Mirror push'u yeni repoda "DEV Deploy" workflow'unu tetikledi; secret'lar
  kopyalanmadığı için 4 sn'de fail oldu → Vuo sunucusuna deploy GİTMEDİ.

### 2. Docker/deploy isimlerini mito'ya çevirme
- **Neden:** Aynı sunucuda çalışırsa Vuo'nun canlı volume/ağ/container'larına çarpmasın,
  imajlar Vuo imajlarının üstüne yazılmasın, Mito build'i Vuo deploy webhook'unu tetiklemesin.
- **Ne yapıldı (sed ile):**
  - `tekbirsoft/vuoapp-{api,spa}[-dev]` → `tekbirsoft/mito-{api,spa}[-dev]`
  - `vuoapp-pg-cluster` → `mito-pg-cluster` (compose name + external volume adları `mito-pg-cluster_*`)
  - container `pgc-*` → `mito-pgc-*`; ağ `vuoapp_net` → `mito_net`; `vuoapp-infra` → `mito-infra`
  - `/home/vuo/docker/app` → `/home/mito/docker/app`; `vuoapp-deploy.{py,service}` → `mito-deploy.{py,service}` (git mv)
  - SPA imajı: `/etc/vuoapp/` → `/etc/mito/`, `vuoapp-entrypoint.sh` → `mito-entrypoint.sh`
  - Jenkins repo URL → `vuo-app/SaasErp_Mito.git`; Vuo deploy host'u (`217.131.14.57`, port 56806)
    → `MITO_DEPLOY_HOST` / `MITO_DEPLOY_PORT` placeholder (TODO)
  - `posgrasql/.env.example`: `APP_DB=mito`, `APP_USER=mitouser`
- **Dokunulan dosyalar:** `.github/workflows/dev-deploy.yml`, `Jenkinsfile`, `Jenkinsfile.dev`,
  `jenkins-pipeline.txt`, `docker-build.bat`, `tools/build-dev.cmd`, `infrastructure/deploy/*`,
  `posgrasql/{docker-compose.yml,docker-compose.network-tek.yml,.env.example,README.md,barman/entrypoint.sh}`,
  `src/frontend/{Dockerfile,docker-entrypoint.sh}`, `.claude/docs/technical-preferences.md`
- **Bilerek dokunulmayan:** .NET proje adları (`VuoApp.*` — kod, docker değil), `docs/runbooks`,
  `yonetim/`, `production/` (Vuo'nun tarihsel kayıtları), host portları (15433-15435, 9999).
- **Commit:** dev `2dfc4dd9`, main `5ea71a58` (cherry-pick; 2 çakışma main sürümü alınıp aynı sed ile çözüldü)
  — chore(docker): Mito kopyasi icin docker/deploy isimlendirmesi

## Kararlar
- Kopya, geçmişi koruyan mirror olarak yapıldı (sıfır commit'li dump değil).
- Deploy hedefi bilinmediği için Vuo host'u bırakılmadı, placeholder konuldu.

## Açık kalanlar / sonraki adım
- Yeni repoya Actions secret'ları: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`, `DEV_DEPLOY_URL` (Mito sunucusu).
- Jenkins/`build-dev.cmd` içindeki `MITO_DEPLOY_HOST` placeholder'larını doldur.
- Mito aynı sunucuda koşacaksa host port çakışması: 15433/15434/15435/9999 değiştirilmeli.
- `jenkins-pipeline.txt` içinde açık Docker Hub PAT var (`dckr_pat_...`) — Vuo repo geçmişinde de
  mevcut, Mito'ya da kopyalandı → token'ı Docker Hub'da iptal edip yenile.
- `posgrasql/primary/init-cluster.sh` ve compose env'de diğer projelerin (eldegistir, garajla, ...)
  DB parolaları duruyor; Mito'ya ayrı küme kurulacaksa sadeleştirilebilir.
