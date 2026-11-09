# pbxtr — 2026-11-09

## Bağlam
Önceki oturum (2026-11-08) "backlog'u kapat" hedefiyle sürüyordu; oturum, BR-AST-158 (failover) birleştirmesinin doğrulama komutunun ortasında kesildi. Yayın hâlâ kullanıcı onayı bekliyor (yerel bellek yüzünden sistem durdurmuştu); sunucu `demo-f4c85d7a75a5`.

## Yapılanlar

### 1. Kesilen birleştirmenin doğrulanması
- **Neden:** son komut sonucu kaydedilmeden kesildi; birleştirme commit'i (1b8f4bc6) origin'de vardı ama doğrulama görülmedi.
- **Ne yapıldı:** build + Api (SystemAdmin/ConfigRenderer/Telefon) + kapılar yeniden koşuldu.
- **Sonuç:** build 0 hata; Api 1034/1034; env-esleme TAMAM; parite temiz. **İki çapraz-kip kapısı KIRMIZI**: `TelephonyFailoverMonitor.cs:304` yeni çapraz aralık (envanter 44 → 45). Kod okundu: aralık yalnız OKUR (düğüm listesi, referans sayısı, atamalar) + `CrossTenantReadAudit`; kip taşımadan önce aynı transaction'da kapanır; taşıma `EfTelephonyCluster.RelocateTenantAsync` içinde `BeginTenantScope` ile tenant başına. → `capraz-kip-envanteri-kapisi.py` docstring'ine "BESINCI TUR" gerekçesi + iki kapı `--dondur`. Architecture TAM 1027/1027.
- **Commit:** `04f7620d`.

### 2. Sızan üç sırrın döndürülmesi (güvenlik olayı)
- **Neden:** BR-AST-158 ajanı sunucu ölçümünde `kamailio-yerel.cfg` `#!substdef` adlarını `grep -o` ile alırken değerleri de bastı: Kamailio DB parolası, RPC sırrı, santral sır başlığı transkripte düştü (ajan kendisi bildirdi).
- **Ne yapıldı:** her sırrın tüketicileri compose'ta bulundu (RPC: kamailio + app; santral: kamailio + asterisk; DB: kamailio + `pbxtr_tel_kamailio` rolü), biçim kapıları entrypoint'ten okundu (hex 32-128 / [A-Za-z0-9._~-] 16-128), `show log_statement` = none doğrulandı. Tek betik (`sir-dondur.sh`, sunucuda koşup silindi): `.env` yedeği (`/root/pbxtr-yedek/env.pre-rotate-20261109T084806Z`, 600), `openssl rand -hex 32/32/24`, `.env` python ile yerinde (her anahtar tam 1 satır assert), `ALTER ROLE pbxtr_tel_kamailio PASSWORD :'p'` psql `\getenv` ile (değer argv'ye girmez), `docker compose up -d --force-recreate --no-deps kamailio asterisk edge edge-fastagi app`.
- **Sonuç / doğrulama:** üç servis healthy; app yeni RPC sırrını taşıyor; `dispatcher.list` yeni sır 200 / ESKİ sır **403**; Kamailio son 1 dk DB auth/bağlantı hatası 0 (2 "password" satırı TLS `private_key_password` bilgi satırıydı — maskeli okundu); asterisk sır hatası 0. `.env` sifreler'e: sha256 iki tarafta `08c3343c`, sifreler commit `542c023`.
- **Kalıcı ders:** memory `env-okurken-degeri-kes` altıncı vaka + tekrar kullanılabilir rotasyon tarifi.

### 3. Backlog
- BR-AST-161 Bitti (REALTIME_FIELD; planın REALTIME biçimi yanlıştı), BR-AST-158 Bitti (varsayılan `gozlem`), BR-BE-288 Kısmen (Kamailio 486 dilimi; pbxtr QueuePause senkronu kaldı), yeni BR-QA-140 (failover yürütücüsü sızıntı testi). ClickUp fark 0. Commit `1b223884`.

## Kararlar
- Failover compose varsayılanı `gozlem` (ilk yayında yanlış pozitif izlenir, sonra `etkin`).
- Failover çapraz okuma aralığı kabul (yazma yok, taşıma tenant kapsamında).

## Açık kalanlar / sonraki adım
- Yayın (main sunucunun 50fa1f81 → 1b223884 önünde) kullanıcı "yayını tekrar başlat" bekliyor; ardından Brevo testi, sysagent kurulumu, ast-02, Mode=on, spool `delete`, BR-QA-134/135/139.
- sip.pbxtr.com DNS-only (BR-SYS-150), QA-126 insan imzası.
- BR-BE-288 pbxtr dilimi, BR-QA-140.

### 4. X: diski doldu (0 bayt) — birleşmiş worktree temizliği
- **Neden:** BR-BE-288 ajanı `ENOSPC` ile hiç yazamadı; `df` X: 301G/301G.
- **Ne yapıldı:** `.claude/worktrees` 18 GB, 42 worktree. Her biri ölçüldü (`git status` temiz + dalı `git branch --merged main`): 41'i temiz ve birleşmiş → `git worktree remove --force` + `prune` (dallar duruyor). Koşan QA-140 ajanının worktree'sine dokunulmadı. Sonuç: 18 GB boş.
- **Diskin geri kalanı kullanıcının verisi** (Gitlab 74,5G, untitled 70G, Test 37G, Oyun 13G, GitHub ölçüm zaman aşımı) — dokunulmadı. X:'te vhdx yok. Ders: her birleştirmeden sonra worktree kaldırılır.

### 5. BR-BE-288 pbxtr dilimi (backend-dev-2 ajanı) + BR-AST-170 kartı
- **Ne yapıldı (d8ec173e, merge 828241d8):** CrossNodeBusyCoordinator + `xnode-busy` ikinci alanı + kullanıcı başı Redis kilidi + QueueMembershipSyncJob mutabakatı; diğer düğümün geri yolladığı duraklatma olayı agent molası sanılıp `on_call`'ı eziyordu — üç yerde filtrelendi; ACW koruması.
- **Birleştirme sonrası koordinatör:** format kapısı `CrossNodeBusyTests.cs:340` tek satır sonu (ajanın "her dosya CRLF yüzünden kırmızı" iddiası yanlıştı — yalnız bu dosya); yazma daraltma bir satır kayması → `--dondur`. Commit `9677b3d8`.
- **Doğrulama:** build 0 hata; Api 96/96; Integration gerçek Redis 2/2; çapraz-kip iki kapı OK; format 0.
- **Yeni kart BR-AST-170:** agent molası (PAUSEALL) yalnız varsayılan düğüme gidiyor. `EfUserQueueMembershipReader` sızıntı testi BR-QA-140 ajanına eklendi.

### 6. BR-AST-170 — agent molası tüm düğümlere (backend-dev-2 ajanı)
- **Öncül ölçüldü (kod):** `AgentEndpoints.cs:1793` QueueId null → `QueueNodeAsync("")` → yalnız varsayılan düğüm. Ek bulgu: BR-BE-288'in "mola xnode duraklatmasını ezer" garantisini de bozuyordu. Canlıda tek düğüm (ast-01, node_affinity 4 satır), yeniden üretilemez.
- **Ne yapıldı (87525491, ff):** PAUSEALL üyenin kuyruklarının ev düğümlerine paralel (`EfMemberQueueResolver`), `QueuePauseFanOut` sonuç birleştirme (başlatmada kısmi = başarılı + mutabakat onarır; bitirmede kısmi = PARTIAL_NODES red).
- **Doğrulama (main):** build 0; Api 164/164; Integration 22/22; çapraz-kip iki kapı OK; format 0. Worktree kaldırıldı.
- **Backlog:** BR-AST-170 Bitti, yeni BR-AST-171 (geçici üyelik + kısmi başarı denetimi). ClickUp fark 0.
