# pbxtr — 2026-10-12

## Bağlam
Kullanıcı isteği (tek mesaj, beş iş + rapor): Güvenlik Duvarı/SSL/Ağ Arayüzleri ekranlarında
yazma işlemleri (kural ekle/sil, nginx reload, arayüz değişikliği, erişim yolundaki servisi
durdur/yeniden başlat) **her zaman 409** dönüyordu; düğmesi olmayan izinli komutlar (ban geri
koyma, SSL yenileme, paket indeksi tazeleme); tenant oluştururken **birden fazla yetkili**;
**Çırak / eş başkan** (platform global özel rol); **ticket yönleri** (admin→bayi, bayi→admin,
tenant→bayi, bayinin ticketını cevaplama). Sonra güncelleme + 4 Eylül'den bugüne rapor.
Kullanıcı: *"yapalim mesai zamani yok bizde"* → mesai içi yayın.

Dört iş paralel ajanlarla ayrı worktree'lerde yapıldı, ana dalda birleştirildi, yayın 22–26
arasında kapılar temizlendi; yayın 26 YEŞİL.

## Yapılanlar

### 1. Sistem ekranlarında yazma — ölü adam anahtarı (BR-SYS-137)
- **Neden:** ADR-014 §5 erişim yolunu kesebilecek her değişikliği "10 dk içinde onaylanmazsa geri
  al" şartına bağlamıştı; şart uygulanmadığı için uç bu komutları hep `409` ile reddediyordu.
- **Ne yapıldı:**
  - `pbxtr-sysagent` değişiklikten ÖNCE host'ta `systemd-run --on-active=600 --unit=pbxtr-sysagent-revert-<runId>`
    zamanlayıcısı kurar; kapalı geri alma tablosu (FW-07/08, NI-07/08, SV-05..08, SL-05),
    `--revert` kipi, yetim kurtarma, aynı anda tek açık işlem (`AGENT_DEADMAN_BUSY`).
  - API: `POST /api/v1/system/operations/{runId}/confirm|revert`, `GET open`. Onay **taze bağlantı**
    kanıtı ister (nginx `X-Pbxtr-Conn-Requests $connection_requests` = 1; onay location'ında
    `keepalive_timeout 0`) — eski keep-alive soketiyle gelen onay "erişim hâlâ var" kanıtı değildir.
  - FW-07 kendini kilitleme koruması (`FirewallSelfLockGuard`), sunucu taraflı etki önizlemesi,
    `DeadManRevertWatcher` (WS `system.operation.reverted` + denetim `auto_reverted`).
  - UI: #35 kural ekle/sil, #47 SL-04/05 (SSL yenileme), #40 NI-06/07/08, #46 durdur/yeniden
    başlat + SV-08, #36 TH-05 (ban geri koyma), #45 UP-05 (paket indeksi); ortak `DeadManBanner`, 9 dil.
- **Dokunulan dosyalar:** `src/Pbxtr.SysAgent/DeadManSwitch.cs`, `src/Pbxtr.Api/Modules/SystemAdmin/SystemOperationEndpoints.cs`,
  `ConfirmConnectionFreshness.cs`, `DeadManRevertWatcher.cs`, `src/Pbxtr.Infrastructure/Platform/SystemOps/SystemDeadManOperations.cs`,
  `deploy/nginx.conf`, `pbxtr-demo/nginx/pbxtr.conf`, `pbxtr-proxy-common.conf`, ADR-014 §5.6.
- **Sonuç:** Test sunucusunda ölçüldü: onay, ikinci işlem reddi, ajan yeniden başlatmasından sağ
  çıkan otomatik geri alma, elle geri alma. Deploy sonrası app uid 1654 = sysagent
  `--expected-peer-uid 1654`; nginx onay location'ı ve başlık canlı konfigde.
- **Commit:** `369aef8e`

### 2. Tenant yetkilileri — çoklu (BR-BE-225)
- **Ne yapıldı:** migration `20261012100000_TenantContacts`; `TenantContactEndpoints.cs`;
  oluşturma diyaloğunda `TenantContactsEditor.tsx` (hitap + görev, N kişi). `EfTenantProvisioning`
  ilk owner'ı açar: **giriş adı = tenant kodu, parola bir kez gösterilir.**
- **Commit:** `4bb2921d`

### 3. Çırak / eş başkan — platform global özel rol (BR-BE-240/241/242/243)
- **Ne yapıldı:** migration `20261012200000_PlatformGlobalCustomRoles` (Karar #88); rol kaydı
  hatası düzeltildi; platform tenant'ında tenant sahibi ve altı rol gizli.
- **Yakalanan regresyon (yayın 24, 9 entegrasyon kırmızısı):** `SessionScopeConsistencyGate` özel rol
  dizinine tenant çözümünden ÖNCE soruyor; bağlamsız okuma `TenantContextMissingException` atıyor ve
  dizin **boş snapshot'ı 30 sn önbellekliyordu** → o süre boyunca hiçbir özel rol hiçbir şey
  vermiyordu. Düzeltme `CustomRoleRowSource.cs`: bağlam yoksa platform tenant'ında sistem kapsamı açar.
  Bisect scratchpad worktree'sinde yapıldı.
- **Commit:** `819cc7af`, `529c24d9`, `f0ebc68d`

### 4. Ticket yönleri (BR-BE-250)
- **Ne yapıldı:** migration `20261012300000_TicketDealerPlatformDirections`; yeni yetki
  `ticket.desk.open`; admin↔bayi iki yön, tenant→bayi, bayinin kutusunda cevaplama paritesi.
  Ek: bayi rolüne `ticket.attachment.download` (resim önizleme için), altın liste + testler.
- **Commit:** `38783ad4`, `9029f311`, `9ea44911` (entegrasyon platform tohumu `t0000`)

### 5. Yayın kapıları (yayın 22–26)
- 22: nginx sürüklenme kapısı → sunucuda `.yedek-<ts>` alınıp `pbxtr-demo/nginx/*` canlıya kopyalandı, `nginx -t`, reload.
- 23 (7 kırmızı): Karar #89 migration onayı (`deploy/migration-contract-onay.blobs`), gitleaks
  (`.gitleaksignore` + fikstür değeri `ornek-ilk-parola`), ST-44 rol matrisi yeniden üretildi,
  `roles-1440x900.png` bilinenBayat (BR-QA-126, son tarih 2026-11-12), çapraz kip envanter/daraltma
  `--dondur` (yeni açıcı salt-okunur doğrulandıktan sonra), kapsayıcı yetki kapısı `.claude/worktrees`'i
  tarıyordu → worktree'ler kaldırıldı.
- 24: yukarıdaki özel rol regresyonu + süperadmin taban testi.
- 25: Docker Desktop kapılar ortasında çöktü → yeniden başlatıldı.
- 26: **YEŞİL**, koşullu push (`YAYIN_EXIT=0`).
- **Mesai içi yayın:** `PBXTR_MESAI_ICI_YAYIN=1` + `PBXTR_OLCULMUS_PENCERE` — değerler sunucuda
  **gerçekten ölçüldü** (PlatformGlobalCustomRoles 25 ms ≈ fiili 18 ms; TicketDealerPlatformDirections 30 ms), uydurulmadı.
- **Commit:** `957426d5`, `2af20f43`, `b16c80ab`

### 6. Deploy sonrası doğrulama
- İmaj `tekbirsoft/pbxtr:demo-f0ebc68d164f` healthy; üç migration uygulandı; anons kapısı YEŞİL.
- App loglarında `fail:`/`crit:` yok; "Host metrik örneği alınamadı" **0** (sysagent yolu açık).
- Duman testi: sunucudaki `smoke.sh` **bayattı** (admin `/queues` `/trunks` için 200 bekliyordu;
  Karar #51 / BR-SEC-08 2026-09-25'ten beri 403 doğru). Depo sürümü (md5 `6582bbb4…`) yedekli kopyalandı.
  Güncel betik: 29 geçti, 2 kaldı — ikisi de `demo.agent`'ın çağrı listesi: tek bacak 25 Eylül'den
  numarasız lab çağrısı (`phone:null`), yani maskeyi ölçecek kayıt yok. **Veri durumu, bugünkü yayından değil**
  (sorguda zaman penceresi yok, `EfAgentWorkspace.GetMyCallsAsync`).
  ```bash
  P=$(grep -E "^PBXTR_SAMPLE_PASSWORD=" .env | cut -d= -f2-)   # değer yazdırılmaz
  PBXTR_SAMPLE_PASSWORD="$P" bash smoke.sh --base-url https://pbxtr.com
  ```

### 7. ClickUp
- `clickup-olustur.js` → 8 yeni kart; `clickup-senkron.js --kuru` → fark 0, izde olmayan 0.
- Açık iş: BR 6 (4 "es geç" + BR-BE-243 kısmen + BR-QA-126) + story 76 = **82**.
- **Commit:** `e6822b39`

## Kararlar
- Mesai yasağı ölçülmüş kilit penceresiyle aşıldı; ölçülmemiş değer verilmedi.
- Sunucudaki smoke beklentisi geri çevrilmedi, betik depo sürümüne çekildi (kaynak depo).
- Migration uyumluluk kapısı **tüm birleştirmelerden sonra** koşulur (ilk kontrol ticket dalından önce koşmuştu).

## Açık kalanlar / sonraki adım
- BR-BE-243: canlıda gerçek bir Çırak hesabıyla uçtan uca deneme.
- BR-QA-126: `deploy/fidelity/fidelity-kos.sh uret` ile roller ekranı taban görüntüsü (2026-11-12'ye kadar).
- Kullanıcı kararı bekleyen: eş başkan drill-in için BR-SEC-20 dar istisnası; bayi ek indirme yetkisinin onayı.
- Ajanların bildirdiği: SL-05 compose nginx konteyneri yerine systemd nginx'i hedefliyor; üretilen owner
  için zorunlu parola değişimi yok; yetkili düzenlemesi owner kullanıcısını güncellemiyor; TH-05 listesi sayfa oturumu başına.
- `demo.agent` için numaralı örnek çağrı yok → smoke'un iki KVKK kontrolü ölçemiyor.
- Lab trunk parolası değiştirilmeli (önceki günlerden).
