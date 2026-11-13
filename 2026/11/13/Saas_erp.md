# Saas_erp — 2026-11-13

## Bağlam
Kullanıcı talimatı: "son değişiklikleri alıp dev'e publish eder misin, testleri çalıştırma ama".
Bu yüzden hazır olan dilimler testsiz push edildi. Yapılan kontroller: güncel dev üzerine rebase, derleme, tip kontrolü, NUL taraması.

## Yapılanlar

### 1. MRP yetki düzeltmesi — `0b497892a`
- **Ne:** `GET /api/v1/production/mrp` ucuna `[RequirePermission("production","read")]` eklendi.
- **Kurul kararı (2026-11-10):** emir tipi bazında sızıntı yok, çünkü `ProductionModuleAccessMiddleware` erişilmeyen tipe 404 dönüyor. Bu yüzden handler'a tip kontrolü eklenmedi.
- **Testler:** yazıldı, koşulmadı.
  - `ProductionReadPermissionContractTests`
  - `MrpAnalysisTypeAccessPostgresTests`
- **Ayrı iş:** yetki şartı eksik diğer okuma uçlarının listesi `wt/prod-read-sweep.md` dosyasında; ayrı bir iş olacak.

### 2. Örme/Boyahane Teorik ihtiyaç — `78ff82285`
- **Rebase çakışması:** upstream `6fcd66b8c`, kullanıcı isteğiyle Boyahane çıkış özeti panelini sayfadan kaldırmıştı.
  - Bu karara uyuldu: panel yalnız Örme'de, `showBanner={false}` ile kalıyor.
  - Boyahane'de sayfa uyarı bandı ve kapanış onayı, ayara bağlı olarak çalışmaya devam ediyor.
- **Değişiklik listesi:** madde metni panel kararına göre düzeltildi.
- **Doğrulama:** derleme 0 hata, tsc temiz.
  - Unit (9270) ve hedefli testler önceki koşuda geçmişti.
  - Bu rebase'den sonra test koşulmadı.

### 3. DEV deploy — 1.0.2.1201
- **Neden:** kullanıcı "DEV'e de deploy et" dedi. GH Actions DEV Deploy hâlâ faturalama yüzünden 4 saniyede düşüyor.
- **Kaynak:** temiz worktree `wt/wtdeploy`, `origin/dev` `78ff82285`.
- **Komutlar:**
  ```bash
  docker build --build-arg VERSION=1.0.2.1201 -f src/backend/VuoApp.Api/Dockerfile -t tekbirsoft/vuoapp-api-dev:{1.0.2.1201,latest} src/backend
  docker build --build-arg VERSION=1.0.2.1201 -f src/frontend/Dockerfile -t tekbirsoft/vuoapp-spa-dev:{1.0.2.1201,latest} src/frontend
  docker push ...   # 4 etiket
  curl http://217.131.14.57:56806/abdusselam.kosecik/1.0.2.1201
  ```
- **Sonuç:**
  - webhook `status ok`, `pull_rc 0`, `up_rc 0`;
  - `/api/v1/auth/external/providers` 200 döndü;
  - SPA bundle hash'i değişti (`Crfo5ib2` → `DdRoIm92`).
- **Not:**
  - `verify.sh` kalite kapısı kullanıcının "testleri çalıştırma" talimatıyla atlandı.
  - Sürüm numarası Docker Hub'dan okunamadı. Notlardaki son sürüm 1133 civarıydı; çakışmayı önlemek için 1201 seçildi.
  - Deploy ile E2 S4b-2 / E6 S3b-2 / E6 S3b-1 migration'ları DEV DB'ye açılışta uygulandı.

### 4. Yetki taraması bulgusu
- ProductionController'da 72 GET'in 48'inde `[RequirePermission]` yok. Bunların 24'ünde hiçbir kapı yok; aralarında ön maliyet ve imzalı ek URL'si var.
- Öneri ve güvenlik kararı (APPROVE-WITH-CONDITIONS): `wt/prodread-proposal.md`.

## Açık kalanlar
- **E7 S3b-3a (karışık koli, wte32):** yarım. Backend kuralları ve migration hazır; ön yüz, i18n ve testler eksik. Bu yüzden publish edilmedi.
- **E6 S4:** DEV pilot turu bekleniyor (`z8v9xnkd69`).
- **S3b-3b Engelle:** pilot sonrasına ertelendi.

### 5. E7 S3b-3a — karışık (asorti) koli birden çok irsaliye satırına bağlanır (23:40)
- **Neden:** gerçek MitoTex kolileri tek kolide 8 beden taşıyor. Eskiden bir koli yalnız tek 3052 satırına bağlanabiliyordu, bu yüzden karışık koliler seçilemiyordu.
- **Kurul:** kurul kararı `wt/e7s3b3-proposal.md`'de. S3b-3a onaylandı, S3b-3b (Engelle modu) ertelendi.
- **Ne yapıldı:**
  - migration `E7S3b3a_MixedBoxClaim`. Down adımı, satır varsa RAISE ile durur.
  - `ReceiptBoxRules`/`ReceiptBoxClaim` kuralları ve `box_incomplete` hata kodu.
  - `GetShippableBoxes` artık her koli için `lines` döndürüyor ve `ContentInvalid` alanını taşıyor.
  - Ön yüz:
    - `receipt-box-mixed.ts`: `planMixedBoxBind` ve kaldırma zinciri;
    - dağıtım önizleme, kaldırma onayı ve satır seçici diyalogları;
    - `use-receipt-box-binding` hook'u;
    - i18n x11 ve changelog.
- **Kapılar:**
  - BE unit 69 ve PG 26 hedefli test geçti.
  - Tip kontrolü, lint ve vitest 3837 temiz, `PENDING_CHECK` temiz.
  - PG karşılaştırmasında `ONLY_IN_SLICE` boş.
  - DEV standby'da DBA ön kontrolü: ihlal 0, satır 0.
- **Commit:** `0f298e542` — feat(inventory,logistics): E7 S3b-3a karisik (asorti) koli 3052 irsaliyesine birden cok satira baglanir
- **UX post-check:**
  - **Karar:** APPROVE-WITH-CONDITIONS, BLOCK yok. Notlar `wt/uxlocal16-notes.md`'de.
  - **Shippable API:** UE1 için 10 karışık koli dönüyor, her biri 8 satırlı.
  - **Eksik veri:** satış siparişi 00000001 taslakta (Status 0), bu yüzden açık sipariş listesi boş geliyor. Chrome'da uçtan uca yürüyüş bu veri yüzünden yapılamadı.
  - **Kod incelemesi:** koşul 3'teki alt toplam koli sayısı eksikti. Bu eksik 11-14 günlüğünde düzeltildi.
