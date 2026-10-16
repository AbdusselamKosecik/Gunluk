# pbxtr — 2026-10-16

## Bağlam
2026-10-15'teki Yapılacaklar turunun (bkz. `2026/10/15/pbxtr.md`) yayın kapıları kırmızıydı
(yayın 37). Hedef: yayın 38+ ile işi canlıya almak, canlıda doğrulamak; ardından kullanıcının
iki düzeltmesi: (1) super admin menüsüne tenant işletme ekranları dökülmüştü, (2) kullanıcı
rol × ekran tablosu verdi, menüler ona göre ayarlanacak.

## Yapılanlar

### 1. Yayın 38–45: kapı kırmızıları ve ağ sorunları
- **Neden:** yayın betiği (`deploy/yerel-yayin.sh --yayinla`) her kırmızıda durur.
- **Ne yapıldı / commit'ler:**
  - `7f672429` st44 insan raporu `schema_revision`.
  - `224c1afa` kapı_13 üretilmiş `change-history.json`'ı tarama dışı bırakır.
  - `1923e128` npm audit ağ hatasında 3 deneme.
- **Ağ geçici çözümü (Docker Hub push bu makineden zaman aşımı, Docker Desktop 3128 proxy):**
  ```bash
  docker save IMG | gzip -1 | ssh root@176.88.41.220 'gunzip | docker load'   # ~16 dk
  # sunucuda: docker tag … :demo && docker push (iki etiket)
  # sonra yalnız 7. adım: scratchpad/yayin7.sh (yerel-yayin.sh başlığı + adım 7)
  ```
- **Sonuç:** yayın 45 canlı `2026.10.15+1923e1282323`; migration `20261015065424_TenantContactUserLink`.
- **Canlı doğrulama:** system/changes 200 (2085 commit), system/mail 200, threats (fail2ban +
  GeoIP + 48 saat), capture 6 arayüz, firewall/rules düzenlenebilir, packages/updates 200;
  SSH bileti superadmin 200 / admin 403 / parolasız 400; WS üzerinden PTY açıldı, temiz kapandı,
  bilet tekrar 403, `.cast` kaydı + `system.shell.opened/closed/denied` denetim satırları.
  Smoke: `PBXTR_SAMPLE_PASSWORD=… bash smoke.sh --base-url http://172.28.0.11:5080`
  (app konteyner IP'si; 127.0.0.1 değil).

### 2. #09 Çağrılarım hatası (5 istendi 1 geldi, numara boş)
- **Neden:** canlıda çağrı `1790295069.13` 5 bacak, aynı `started_at`; limit BACAK sayıyordu,
  temsilci bacak deterministik değildi, bazı bacaklar dahili (1043) taşıyordu.
- **Ne yapıldı:** `src/Pbxtr.Infrastructure/Modules/EfAgentWorkspace.cs` GetMyCallsAsync — önce
  son N linkedid seçilir, sonra bacaklar okunur; `ThenBy(UniqueId)`; numara E.164'e çevrilebilen
  ilk bacaktan.
- **Test:** `CdrMultiRowCallTests.Cagrilarim_limiti_cagri_sayar_ve_numarayi_cevrilebilen_bacaktan_alir`
  (düzeltmesiz kırmızı, düzeltmeyle yeşil).
- **Commit:** `21b8643a`.

### 3. Super admin menüsü geri daraltıldı (kullanıcı düzeltmesi)
- **Neden:** kullanıcı: *"tum menuler geliyor Super admine … agent ekranlarini ne yaptin"*.
  `6b31edba` "tüm yetki" kararını katalogdaki HER yetki diye uygulamıştı (135 yetki).
- **Ne yapıldı:** `permissions.seed.json` superadmin paketleri `28beec65` hâline + `system.shell`
  (52+1). `super_admin_immutable` (UserAdminRules) aynen. Üretilenler: `npm run screens:gen`,
  `PBXTR_WRITE_DOCS=1 dotnet test --filter Matris_belgesini_URET`, st44 matrisi
  (`python deploy/st44/s30-canonical-fixtures.py --root . --matrix … --seed …`).
- **Sonuç:** yayın 47 canlı `demo-cf9a72c4a2e7` (01:13Z), push `1923e128..cf9a72c4`.
- **Commit:** `cf9a72c4`.

### 4. Rol × ekran menü matrisi kullanıcı tablosuna göre (BR-FE-135)
- **Neden:** kullanıcı 7 rol × 70 ekranlık tablo verdi: *"menuleri buna gore ayarlarmisin"*.
- **Ölçüm:** tablo `scratchpad/matris-kullanici.txt`, fark betiği `diff.py` (4 boşluk = 1 hücre)
  → 27 ekranda fark. Üç şüpheli satır soruldu: #01 owner'da kalır, #58 admin'de kalır,
  #66 SSH yalnız superadmin.
- **Ne yapıldı (yayın 47 sürerken git worktree `../pbxtr-menu` içinde):**
  - Seed: agent'tan `bundle.console` → `call.handle`+`call.park` (konsol menüsü gider, masa
    kalır), `timeline.read` +, `voicemail.read` −; owner/supervisor `agent.self.read`;
    supervisor `role.read`, `network.quality.read`; bayi `user.read`, `role.read`, `ticket.read`;
    `system.changes.read` owner/sup/bayi + platformScopeOnly'den çıktı; bayi/owner'dan
    `bundle.apikey`; global rollerden `bundle.telephony.admin`; admin'e #35/#36/#46/#47/#68;
    global rollere `settings.read`, `ticket.read`, `media.*`, `settings.retention.write`.
  - Ekran kendi yetkisine bağlandı (menü dışı davranış bozulmasın): #17 `wallboard.display`
    (+`wallboard.view`), #39 `media.library.read` (+`media.read`; IVR medya okumayı korur),
    #65 `settings.retention.write`; #16 `inMenu:false`.
  - #62 Platform Destek Kutusu bayiye AÇILMADI: tüm platform talepleri, `ticket.inbox.platform`
    platformScopeOnly; bayi kendi kutusunu #56'dan açar. Alt yüzeyi (56.1) menüye almak
    ADR-006 §5.3'e aykırıydı (ScreenRegistryTests).
  - Kilit testleri yeni karara çekildi (Global rol sınırı 71→68, bayi altın listesi, ticket
    kapısı, sistem ekranları admin'e, wallboard açılış, FE smoke'ta ortak `/agent/state` ucu).
- **Doğrulama:** Api Platform 1432, Api Modules 5383 (3 kilit testi düzeltildi, yeniden yeşil),
  Architecture 857, Integration (rol/ekran/modül alt kümesi) 138, vitest 2371, `tsc -b` temiz,
  `dotnet format --verify-no-changes` temiz (worktree'de önce Integration build şart).
- **Commit:** `b21d4173`. Yayın 48 başlatıldı.

### 5. Yayın 48–50: menü matrisi canlıya
- **Yayın 48 kırmızı (tek kapı):** st44 öz-testi `test_permissionsAll_is_an_AND_condition`
  vakum oldu — "birincil yetkiyi taşıyıp permissionsAll'dan birini taşımayan rol" artık yoktu
  (agent konsolu kaybetti). Düzeltme `660fbde3`: test o durumu verinin kopyasında kendisi kurar;
  üreticinin AND kuralı bozulunca KIRMIZI olduğu doğrulandı.
- **Yayın 49 kırmızı (Integration 3/1303):** menü değişikliğinin yan etkisi.
  - `TenantProvisioningDeliveryHttpTests` (2): owner/bayi artık `apikey.manage` taşımıyor.
    Pin korumasının non-global yolu tenant özel rolüyle (`karar58.apikey`, owner'a ek rol)
    ölçülür; bayi 403 beklenir; rejected denetim satırı 2→1.
  - `SessionScopePlatformBoundaryHttpTests` (1): `system.changes.read` platformScopeOnly'den
    çıktığı için `system.` önek yasağından muaf.
  - Yerelde 17/17 yeşil. **Commit:** `e6f7e224`.
- **Yayın 50 yeşil:** `tekbirsoft/pbxtr:demo-e6f7e224da02` (04:48:33Z), push `cf9a72c4..e6f7e224`.
- **Canlı doğrulama:**
  - Sunucudaki `/home/vuo/pbxtr-demo/smoke.sh` bayattı (yayın onu güncellemiyor; 8 KALDI hepsi
    eski beklenti). Depo kopyası `tr -d '\r'` ile kopyalandı (yedek `smoke.sh.bak-20261016`).
  - Depoda kalan tek bayat satır: menü `demo.agent /live/timeline 0` → 1; ayrıca agent
    `/console 0`, `/voicemail 0` eklendi (iki kopya: `pbxtr-demo/smoke.sh`, `deploy/demo/smoke-demo.sh`).
  - Smoke: bir koşuda tek `000` (geçici bağlantı), ardından `Tum makine kontrolleri gecti`.
  - `/api/v1/me/menu` (betik `scratchpad/menu-olc.sh`): superadmin 29, admin 28, bayi 8,
    owner 40, supervizor 37, agent 5, wallboard 2 = üretilen `doc/rol-ekran-matrisi.md`.
- **Sürüm notu** `e6f7e224da02` eklendi, sayfa üretildi; canlı imaja beklemeden
  `docker cp` + `chmod 644` ile `/app/wwwroot/surum-notlari/index.html` güncellendi
  (pbxtr.com/surum-notlari/ yeni başlığı gösteriyor).
- **ClickUp:** BR-FE-135 Bitti (yeni kart), 10 kart complete; `--kuru` fark 0.
- **Commit'ler:** `b1fcaa2c` (backlog + sürüm notu + smoke), `a324300a` (ClickUp eşlemesi).

## Kararlar
- "Super admin tüm yetkili" = platform yönetimi; tenant işletmesi drill-in/taklit ile.
- Menü gizlemek için yetki silinmez; iş başka ekranda o yetkiyi istiyorsa ekran kendi
  yetkisine bağlanır.
- Platform kutusu bayiye açılmaz (veri sızıntısı); bayi kendi kutusunu kullanır.

## Açık kalanlar / sonraki adım
- Sunucu `smoke.sh` yayınla güncellenmiyor — elle kopyalanıyor; yayın betiğine eklenmeli.
- #62 Platform Destek Kutusu bayiye açılmadı (kullanıcıya bildirildi).
- KULLANICI: Lark uygulamaya özel SMTP parolası (şu an 535); DKIM selector; Yapilacaklar
  dosyasındaki parolayı silmek.
- BR-SYS-139: ilk gerçek retention silme koşusunun sayıları.
