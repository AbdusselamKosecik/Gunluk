# Saas_erp — 2026-09-14

## Bağlam
`dev` dalı origin'den çekildi (a294b152: proses sıra kontrolü, Kod Üretici, Parça İşçilik, Pre-Costing, finans/e-fatura merge).
Jenkins `Vuo-Dev` job'u (1.0.2.14) API imajı build'inde başarısız: `csc exited with code 137` (VuoApp.Migrator), build adımı ~5 sa 41 dk sürdü, agent defalarca "offline" oldu.

## Yapılanlar

### 1. Son değişiklikleri çekme
- **Komutlar:**
  ```bash
  git pull --ff-only
  ```
- **Sonuç:** fast-forward, çakışma yok.

### 2. Jenkins OOM teşhisi
- **Neden:** exit 137 = SIGKILL → kernel OOM killer. Agent kopmaları swap'ta donan JVM'in ping'e cevap verememesi.
- **Kök neden bulgusu:** `src/backend/VuoApp.Migrator/Migrations` altında 90 adet `*.Designer.cs`, her biri ~1,4 MB; toplam ~135 MB C# kaynağı tek csc sürecinde derleniyor. `VuoApp.Api.csproj` Migrator'a ProjectReference veriyor, bu yüzden API imajı her seferinde bunu derliyor.
- **Tespit komutları:**
  ```bash
  ls VuoApp.Migrator/Migrations/*.Designer.cs | wc -l     # 90
  cat VuoApp.Migrator/Migrations/*.cs | wc -c              # ~135 MB
  ```

### 3. Dockerfile bellek ayarları
- **Neden:** Build'i hızlıca geçirmek (geçici önlem).
- **Ne yapıldı:** publish adımından önce `ENV DOTNET_gcServer=0 MSBUILDDISABLENODEREUSE=1 DOTNET_CLI_TELEMETRY_OPTOUT=1`; publish'e `-m:1 /p:UseSharedCompilation=false /p:BuildInParallel=false` eklendi.
- **Dokunulan dosyalar:** `src/backend/VuoApp.Api/Dockerfile`
- **Sonuç / doğrulama:** Yerelde docker build çalıştırılmadı; Jenkins'te yeniden denenmeli.
- **Commit:** `2f8db7c1` — fix(ci): reduce API image build memory to avoid csc OOM kill

### 4. Debian agent'a 8 GB swap (kullanıcı sunucuda uygulayacak)
- **Komutlar:**
  ```bash
  sudo fallocate -l 8G /swapfile   # olmazsa: dd if=/dev/zero of=/swapfile bs=1M count=8192
  sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
  echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-swap.conf && sudo sysctl --system
  free -h && swapon --show
  ```

## Kararlar
- Paralellik/GC ayarları geçici; tek csc sürecinin belleğini kökten düşürmez.
- Kalıcı çözüm: migration squash (tek baseline) + `__EFMigrationsHistory` güncellemesi → şema işi, `dba` + kurul onayı gerekli.

## Açık kalanlar / sonraki adım
- **GÜVENLİK:** Jenkins log'unda Docker Hub PAT ve GitHub PAT düz metin göründü → iki token iptal edilip yenilenmeli; Jenkinsfile'da `withCredentials` ile maskelenmeli.
- Jenkins build'i yeniden tetikle, `dmesg -T | grep -i oom` ile doğrula.
- Migration squash önerisini kurula götür; API→Migrator referansını gözden geçir.

---

### 5. DEV pipeline dosyası + token'ların credentials'a taşınması
- **Neden:** Jenkins job'unda Docker Hub ve GitHub PAT düz metin (log'a düşüyordu); repo'daki eski `Jenkinsfile` de Docker PAT içeriyordu.
- **Ne yapıldı:**
  - `Jenkinsfile.dev` (yeni, Linux agent `docker`): GitSCM shallow checkout (`github-vuoapp` credential), build'den önce `withCredentials` ile docker login (`dockerhub-tekbirsoft`), 90 dk timeout, `buildDiscarder`, post'ta `docker logout` + prune. Build/push/deploy adımları kullanıcının verdiği pipeline ile aynı.
  - `Jenkinsfile` (eski Windows/main): hardcoded Docker PAT kaldırıldı → `withCredentials`.
- **Dokunulan dosyalar:** `Jenkinsfile`, `Jenkinsfile.dev`
- **Commit:** `26795345` — ci: add DEV Linux pipeline and move registry/git tokens to Jenkins credentials
- **Jenkins tarafı (elle):** Credentials'a `github-vuoapp` ve `dockerhub-tekbirsoft` (Username with password) eklenmeli; job → "Pipeline script from SCM", branch `dev`, Script Path `Jenkinsfile.dev`.
- **Not:** Eski PAT git geçmişinde (`Jenkinsfile`) duruyor → token iptali şart.

### 6. Yerel DEV paketi 1.0.2.16 + build-dev.cmd
- **Neden:** Jenkins agent OOM ile düşüyor; paket yerelden (32 CPU / 31 GB Docker Desktop) çıkarıldı.
- **Ne yapıldı:** `tools/build-dev.cmd <build-no> [nodeploy]` eklendi (git pull → API build → SPA build → 4 push → deploy curl). `.gitattributes`'a `*.cmd text eol=crlf`.
- **Commit:** `8e0c0b80` — chore(tools): add build-dev.cmd
- **Sonuç:**
  - `tekbirsoft/vuoapp-api-dev:1.0.2.16` / `:latest` → `sha256:422798b5...` push edildi
  - `tekbirsoft/vuoapp-spa-dev:1.0.2.16` / `:latest` → `sha256:b933b946...` push edildi
  - Deploy: `http://217.131.14.57/abdusselam.kosecik/1.0.2.16` → **301** → `https://217.131.14.57/...`; HTTPS sertifikası IP için doğrulanamıyor → deploy **tetiklenmedi**.
- **Bulgu:** Jenkins'teki `curl --fail` 3xx'i hata saymaz → pipeline deploy yapmadan "başarılı" görünebilir.

## Açık kalanlar (ek)
- Deploy URL'si: https + geçerli sertifikalı alan adı mı kullanılmalı, yoksa `-k` ile mi çağrılmalı → kullanıcı kararı.
