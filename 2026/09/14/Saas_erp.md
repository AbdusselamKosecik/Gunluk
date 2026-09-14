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
