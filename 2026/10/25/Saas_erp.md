# Saas_erp — 2026-10-25

## Bağlam
Bir gün önce yeni sol menü DEV'e çıktı (1.0.2.1050). Kullanıcı, Dokuma modülünün menüsünde kaybolduğunu söyledi. Örnek bir emir açılıp uçtan uca yönetilmesini istedi; örnek olarak kumaş teknik analiz formu, tezgah açma ve planlamayı verdi. Çalışma, temiz worktree `scratchpad/wtd` üzerinde yapıldı (origin/dev, detached).

## Yapılanlar

### 1. Dokuma akışının haritası ve örnek emir (yerelde, paylaşımlı vuo_dev üzerinde)
- **Neden:** Kullanıcı hangi sayfanın hangi sırayla kullanılacağını göremiyor.
- **Nasıl:** Yerel API (:5240) ve Vite (:3131) çalıştırıldı. `appsettings.Development.json` ve `.env.development.local` geçici olarak kopyalandı, iş bitince silindi. Giriş `scratchpad/tok.cjs` ile yapıldı (şifre yazdırılmaz; token dosyası hemen silinir). Firma: MitoTex A.Ş. Chrome DevTools ile tıklandı.
- **Oluşturulan örnek veri (app-dev'de de görünür, aynı DB):**
  - Tezgah: **TZG-01** "Picanol Armaflex 1 (Örnek)". Dokuma > Tanımlar > Makineler; 600 RPM, 24 saat.
  - Stok tipi **IPLIK** "İplik" (sistem tipi Hammadde). Firmada yoktu; İplik Kartları listesi tip adında "iplik" arıyor.
  - İplik kartı **IPL-NE30-PMK**: Ne 30/1, %100 pamuk, Ağırlık birim seti.
  - Kumaş kartı **DK-POPLIN-160**: Dokuma Kumaş, en 160, bez, çekme %8/%6, kalite A, **seri takibi açık** (top oluşturmak için şart).
  - Kumaş analizi **KA-0003**:
    - tarak no 120, 2 tel/diş, kenar 48, ham en 160, atkı 20/cm;
    - sonuç: tarak eni 173,84, toplam tel 4.220, 94,7 g/m², 5.000 m için 826 kg iplik, 367 m/gün.
  - Emir **Y-0000000031**: 5.000 m DK-POPLIN-160, müşteri MİTO KONFEKSİYON, termin 20.11.2026.
  - Çözgü planlama:
    - KA-0003 bağlandı;
    - 9 çözgü leventi (C01–C09, 469/468 tel, 5.450 m);
    - Haşıl ile dokuma leventi **Y-0000000031-D01** (4.220 tel).
  - Tezgah planlama: TZG-01 kuyruğu, 5.000 m, tahmini bitiş 07.11.
  - Tezgah panosu: levent bağlandı, başlatıldı. Dok **Y-0000000031-K001** (100 m, levent tüketimi 108 m) kesildi.
  - Dok kontrol: 35. m 1 puan, 72. m 4 puan; 5 puan, 3,13 puan/100 m², 95 g/m², 15,2 kg.
  - Kumaş kontrol (dok → top): **Y-0000000031-T001** 1A 100 m, depo 06, fiş INV-2026-3010-000017.
  - Emir "Açık" kaldı; tezgah çalışıyor, kalan 4.900 m.
- **Doğru sıra (tarif):**
  1. iplik kartı (iplik sekmesinde numara);
  2. kumaş kartı (kumaş sekmesi + seri takibi);
  3. tezgah (Makineler);
  4. kumaş analizi;
  5. üretim emri (Planlanan Miktar);
  6. çözgü planlama (analizi bağla → leventler);
  7. İndigo/Haşıl (dokuma leventi);
  8. tezgah planlama;
  9. tezgah panosu (bağla, başlat, dok kes);
  10. dok kontrol;
  11. kumaş kontrol dok → top;
  12. toplar.

### 2. Hata: Dokuma emirleri 0 m kaydediliyordu (başkasının commit'i)
- **Neden:** Abdurrahman'ın `419fa88e` commit'i "Reçete Miktarı"nı (emrin PlannedQuantity alanı) Boyahane dışında gizlemişti. Çözgü planlama "Emir miktarı sıfırdan büyük olmalı" diye reddediyordu. Tezgah ve makine kuyruğu da bu değeri kullanıyor.
- **Kurul:**
  - İlk öneri (kalem toplamını göndermek) için CTO koşullu onay verdi, Şüpheci BLOCK dedi: birim karışabilir, eski emirler sessizce değişir, kural yalnız frontend'de kalır.
  - Şüphecinin önerdiği yol uygulandı ve onaylandı.
- **Ne yapıldı:**
  - Boyahane dışında düzenlenebilir "Planlanan Miktar" alanı geri geldi (`ProductionOrderDetailForm.fields.plannedQty`, 11 dil `b19.json`).
  - Kapasite ve hesaplama yöntemi yalnız Boyahane'de kalıyor.
  - Test: `__tests__/production_order_detail_planned_qty.test.tsx` (3 vaka, önce kırmızı sonra yeşil).
  - Changelog: 2026-10-25 fix maddesi.
- **Commit:** `f756e50c` fix(production): boyahane disi emirlerde Planlanan Miktar alani geri geldi

### 3. Kalite kapısı onarımı (yetki grupları commit'lerinden)
- **Neden:** Yeni hata kodları `PermissionGroup.*` için tr/en çeviri yoktu. `Tenant.InsufficientPermission` artık iki mesajlı olduğundan hariç listesine geçti, ama çeviri dosyalarında duruyordu.
- **Komut:** `node scripts/extract-api-errors.mjs --write`; ardından 11 `assets/api-errors/*.json` güncellendi.
- **Commit:** `c91615b2` fix(i18n): yetki gruplari hata kodlari katalogu guncellendi
- **Doğrulama:** `bash tools/verify.sh frontend` rc=0, 1.880 test.

### 4. Dokuma menüsü iş sırasına dizildi (kullanıcı onayı: "tamam menüyü iş sırasına göre düzenle, paket çık")
- **Neden:** Kullanıcı Dokuma menüsünde kayboluyordu; gruplar uçtan uca akışın sırasını izlemiyordu.
- **Kurul:** CTO ve Şüpheci koşullu onay verdi. Koşullar uygulandı:
  - yol kümesi birebir testle korunuyor (32 yol, tekrar yok, pano en üstte);
  - 11 dilde etiket eklendi;
  - "ortak iskelet" yorumuna Dokuma istisnası yazıldı;
  - verify yeşil;
  - Chrome'da masaüstü ve 390 px kontrol edildi.
- **Yeni sıra:** Tezgah Panosu (üstte) → Kartlar & Analiz → Emir & Planlama (emirler, planlama, çözgü planlama, tedarik) → Çözgü Hazırlık → Tezgah (tezgah planlama, doklar) → Kontrol & Muayene → Hareketler (genel hareket/barkod/paketleme) → Raporlar → Tanımlar.
- **Dosyalar:**
  - `layouts/components/sidebar/two-panel/menu-layout.production.ts`
  - `__tests__/menu-layout.production.test.ts` (4 test; önce kırmızı)
  - 11 × `assets/i18n/<dil>/b25.json` (`LayoutStandardMenu.ordersPlanning`, `.loom`)
  - changelog `improvement` maddesi
- **Commit:** `aebafbb5` feat(production): Dokuma menusu is sirasina dizildi

### 5. Kalite kapısı (backend): makine kuyruğu silme ucu yetkisi
- **Neden:** `verify.sh all` kırmızıydı. Sebep: `ProductionEndpointPermissionContractTests.EveryDeleteEndpoint_RequiresDeleteOrManage`. Abdurrahman'ın `d169f183` commit'indeki `MachineOpsController.Remove` (DELETE) `production:update` istiyordu.
- **Ne yapıldı:** `production:delete` yapıldı. Dokumadaki eşi `LoomOperationsController.RemoveQueueItem` de böyle. Tek satır; mevcut test kırmızıdan yeşile döndü.
- **Sonuç:** backend 5.133 test geçti, `[verify] BAŞARILI (backend)`. Frontend 1.884 test geçti.
- **Commit:** `2864cdfa` fix(auth): makine kuyrugundan cikarma production:delete ister

### 6. DEV paketi 1.0.2.1051
- **Adımlar:**
  - api ve spa `docker build` (`--build-arg VERSION=1.0.2.1051`), etiketler `:1.0.2.1051` ve `:latest`, push;
  - `curl http://217.131.14.57:56806/abdusselam.kosecik/1.0.2.1051` → status ok, up_rc 0.
- **Doğrulama:**
  - API `/api/v1/auth/external/providers` ilk denemede 502 verdi, 15 sn sonra 200;
  - SPA 200, ana pakette `ordersPlanning` anahtarı var.
- İçerik: Planlanan Miktar düzeltmesi, Dokuma menü sırası, yetki düzeltmesi, Abdurrahman'ın 10-24 commit'leri (yetki grupları, makine planlama).

### 7. Modül atlaması, gizli ön koşul uyarıları, analiz formu (kullanıcı: "tamam onlari da duzelt, paket cik")
- **Kurul:**
  - CTO, Şüpheci ve Güvenlik koşullu onay verdi; koşullar uygulandı.
  - UX için Chrome'da elle kontrol edildi: 1494, 1280 ve 390 px; menü ve onay penceresi denendi.
- **Sol menü** (`two-panel.utils.ts` `findActiveModuleKey`, `two-panel-sidebar.tsx`, `nav-prefs.ts`):
  - Yalnız menü sayfasının tam kendisi (yol eşit, sorgu eşleşir) modül değiştirir.
  - Detay, yeni kayıt ya da menüde olmayan sayfada kullanıcı geldiği modülde kalır.
  - Son modül `sessionStorage` `vuo.navLastModule` anahtarında tutulur. Menüde artık yoksa (yetki/lisans) yok sayılır.
  - Doğrulama: Dokuma'dan "Yeni Makine" (`/production/machines/new`) ve üretim emri formu açıldı; menü Dokuma'da kaldı, yenilemeden sonra da.
- **Tezgah planlama:**
  - `UnplannedOrdersResult.MissingAnalysisCount`: liste ile aynı "açık dokuma emri" koşulunda, analizsiz emir sayısı.
  - Panelde uyarı ve Çözgü Planlama bağlantısı.
- **Levent bağla:** dokuma leventi yoksa bağlantı verilir; kuyruğun ilk emri varsa `/production/weaving/beam-processes/{orderId}`, yoksa liste sayfası.
- **Top oluşturma:**
  - Yeni port metodu `IInventoryMrpQueryService.GetLotTrackedInventoryIdsAsync`: `HasSerialTracking`, IN-list, AsNoTracking, tenant filtresi.
  - `WovenRollTargetResolver.DescribeAsync` seri takibi kapalıysa `RollItemNotLotTracked` hatası ekler.
  - Yeni `fabric_cut/roll_target_errors.tsx` hataları düğmeden önce gösterir ve kumaş kartına bağlantı verir.
  - Kayıttaki asıl kontrol aynen duruyor.
- **Analiz formu:**
  - **Taşma:** `weaving_lines_grid.tsx` tablo kabı `relative w-0 min-w-full overflow-x-auto` oldu (ihtiyaç tablolarıyla aynı kalıp). Başlık ızgarası `[&>*]:min-w-0` aldı (mobilde 63 px taşma).
  - **Neden:** `overflow-x-auto` kabın en küçük içerik genişliği, flex düzende üst katmana yansıyordu.
  - **Kaydedilmemiş değişiklik:** `useUnsavedChanges(inputKey)` bağlandı; başarılı kaydetme ve silmede `markSaved`.
  - Sayfanın 4 test dosyası, `useBlocker` veri yönlendiricisi istediği için `createMemoryRouter`'a geçti.
- **Testler:**
  - backend: port 3, tezgah planlama 2, top hedefi 2;
  - frontend: menü 6, nav-prefs 2, tezgah planlama 2, levent bağlama 2, top hedef hataları 3, kaydedilmemiş değişiklik 3.
- **Doğrulama:** `verify.sh all` yeşil (backend 5.140, frontend 1.902).
- **Commit:** `1498fbcd`

### 8. DEV paketi 1.0.2.1052
- api ve spa build/push; tetik status ok.
- API 200; ana pakette `vuo.navLastModule` ve `ordersPlanning` var.

### Test notu
- chrome-devtools'ta `evaluate_script` içinden yapılan router geçişi, bekleyen `window.confirm`'i bir sonraki araç çağrısına erteliyor ("hayalet" onay penceresi).
- Kaydedilmemiş değişiklik testinde `click` aracı ve `handle_dialog` kullanılmalı.

### 9. Kalan bulgular, paket A (kullanıcı: "tamamlayalim")
- **Kurul:** CTO ve Şüpheci koşullu onay verdi; koşullar uygulandı.
- **Emir durumu:**
  - `LoomRunCommands.cs` `StartLoomHandler.MarkOrderInProgressAsync`: tezgahtaki emir Status < 3 ise 3 (İşlemde) olur; `StartDate ??=` ve `ProductionOrderStatusChangedEvent` yazılır, aynı transaction'da.
  - İkinci başlatmada olay tekrar yazılmaz (test var).
  - Emsal: `CreateScanMovement`.
- **Analiz formu:**
  - `applyFabricWidth`: kumaş seçilince ham en boşsa kart eni (`/api/v1/inventory/items/{id}` → `fabric.width`, yeni `fabric-width.api.ts`) yazılır.
  - Kumaş seçicisi `typeNameCi=*dokuma` süzgecini kullanır.
  - `linesReadyForCalc`: tel ya da tekrarı 0 olan satırla hesap isteği gitmez; backend Ends/Repeat mesajları Türkçe.
- **Kumaş kartı:**
  - `InventoryFabricLimits` sabitleri: entity yapılandırması ve `SaveInventoryFabricValidator` aynı kaynaktan; `SetValidator(...).When(Fabric != null)`.
  - Kalite girişi `maxLength=5`.
- **Emir alt başlığı:** `subtitleByType.{1,2,3,4,6}` ve `subtitleGeneric` (11 dil); Boyahane eski metni korur. Eski boyahane crash testi `findByText`'e çevrildi.
- **Yapılmadı:**
  - Tarih biçimi: 61 yerel `<input type=date>`, tarayıcı diline göre çiziliyor. Ayrı karar.
  - İplik sarfı (F6c): ayrı paket.
- **Doğrulama:**
  - `verify.sh all` yeşil (backend 5.154, frontend 1.916).
  - Canlı kontrol: emir alt başlığı "Dokuma kumaş üretim emri"; kumaş seçicisinde süzgeç; DK-POPLIN-160 seçilince ham en 160.
- **Commit:** `ca644613`. DEV 1.0.2.1053 yayında, API 200.
- **F6c planı:** Plan ajanı özeti scratchpad'de `f6c-plan.md`. Kurula gidiyor.

### 10. F6c — Dokuma iplik sarfı (kullanıcı: "tamamlayalim", paket B)
- **Neden:** Top oluşturma iplik stoğunu düşmüyordu ("yakında"). F7 raporu yalnız teorik kg gösteriyordu.
- **Kurul:**
  - 1. turda skeptic BLOCK verdi: çözgü leventi tetiği F7 kararıyla (sarılan ≠ tüketilen) çelişiyordu. Tetik yalnız dok kesimi olacak şekilde değiştirildi.
  - 2. tur: cto ve skeptic APPROVE-WITH-CONDITIONS; dba, product-owner APPROVE-WITH-CONDITIONS; security PASS-WITH-CONDITIONS.
  - Uygulama sonrası güvenlik kontrolü: PASS. Üç düşük notun biri düzeltildi: liste ucundaki tarih hatası artık güvenli koda sarılıyor.
- **Tasarım:**
  - Dok kesilince emrin kumaş analizinden teorik kg hesaplanır. Çözgü = WarpConsumedM × g/m / 1000, atkı = LengthM × g/m / 1000; rapor ile aynı `WeavingYarnKg.Kg`.
  - Inventory portu kilitli 3062 fişi yazar. Idempotency `inventory.ProductionConsumptionPosting` ile sağlanır (UX TenantId+SourceKind+SourceRefId).
  - Depo seçimi: ayar `production.weaving.yarnWarehouseId`, yoksa en çok stoklu depo. Stok yetmezse `insufficient_stock`; satır depolara bölünmez.
  - Durumlar: Bekleyen / İşlendi / Geri alındı. "Geri alma bekliyor" = İşlendi ∧ dok iptal.
  - Poster sagası: kira alınır, Bekleyen satırlar yeniden hesaplanır, sonuç xmin ile koşullu yazılır. Port çağrısı sürerken dok iptal edilirse anında ters kayıt yapılır.
  - Kesim ve iptal tetikleri komutu asla bozmaz; başarısızlıkta yalnız uyarı çıkar.
- **Dokunulan dosyalar:**
  - Inventory: `Services/ProductionInventoryService.YarnConsumption.cs`, `Entities/ProductionConsumptionPosting.cs`, `RollOutputReceiptGuard.cs`.
  - Production: `Entities/WeavingYarnConsumption.cs`, `Features/WeavingYarn/*` (Support, Poster, Hooks, Queries, Batch), `YarnConsumptionController.cs`, `LoomCutCommands.cs`, `LoomCancelLastCommand.cs`, `YarnConsumptionReport.cs` (rapor bandı).
  - Shared: `IProductionInventoryService.YarnConsumption.cs`, ErrorCodes, ErrorMessages, TenantSettingKeys.
  - Diğer: `DefaultPermissionSeeder` (`production_yarn_consumption` read/create/manage), migration `WeavingYarnConsumptionF6c`.
  - Frontend: `api/weaving-yarn.api.ts`, `pages/weaving/yarn_consumption/*`, menüde Hareketler › İplik Sarfı, Tezgah Panosu ve Kumaş Kontrol uyarı şeridi, 11 dilde `f6c.json`, `b21c.json` yarnNote, `api-errors` (yeni kilit kodu).
  - Belge ve liste: tasarım dokümanı §3.29, changelog.
- **Testler:**
  - YarnConsumptionPortTests: 14 test.
  - WeavingYarnConsumptionTests: 17 test. Kesim, iptal, yarış, g/m düzelt → fiş kg = rapor kg, analiz sonrası donma, iki tenant, toplu tarama, 200 sınırı.
  - yarn_consumption.test.tsx: 8 test.
  - Mevcut sayfa testlerinde şerit taklit edildi (fabric_cut, loom_board).
- **Hata/düzeltme:**
  - i18n ad alanı `WeavingYarnConsumption` raporla çakıştı; yeni ad `WeavingYarnPosting` oldu.
  - Backfill onay düğmesinde yer tutucu yanlıştı (`n` yerine `cuts`).
  - Migration'da gereksiz FK indeksleri çıktı; indeksler FK sütunuyla başlatıldı. `migrations remove` DB'ye bağlanmaya çalıştığı için migration dosyaları elle silinip snapshot git'ten geri alındı.
- **Komutlar:**
  ```bash
  dotnet ef migrations add WeavingYarnConsumptionF6c --project . --context MigratorDbContext   # ConnectionStrings__DefaultConnection sahte değerle
  node tools/strip-migration-designers.mjs
  node scripts/extract-api-errors.mjs --write
  bash tools/verify.sh all    # rc=0
  ```
- **Canlı kontrol (yerel, paylaşımlı vuo_dev):**
  - Migration açılışta uygulandı.
  - Sayfa, menü, sekmeler ve depo ayarı çalışıyor.
  - "Geçmişi tara" önizlemesi: 4 dok, 4'ü hesaplanabilir, 40,376 kg. Kayıt AÇILMADI; örnek tenant stoğunu değiştirmemek için karar kullanıcıya bırakıldı.
  - 390 px'te taşma yok.
- **Commit:** `f2a7e5a4` — feat(production,inventory): dokuma iplik sarfi (F6c).
- **DEV:** 1.0.2.1054 deploy edildi. Sağlık ucu 200; yeni uç girişsiz isteğe 401 dönüyor, yani uç kayıtlı.

### 11. Tarih biçimi global: bilgisayarın bölge ayarı (kullanıcı: "tarih bicimi glabol olmak lazim. bilgisayarin tarih formati neyse o")
- **Neden:** Ekrandaki tarihler uygulama dilini izliyordu (`formatLocale()`, tr → 25.10.2026), tarih giriş kutuları ise tarayıcının yerel ayarını (İngilizce Chrome'da 10/25/2026). Genel ayarlardaki "Tarih biçimi" seçimi kaydediliyordu ama hiçbir yerde kullanılmıyordu.
- **Ne yapıldı:**
  - Yeni `src/frontend/src/core/lib/i18n/date-locale.ts`. `dateLocale()` = `Intl.DateTimeFormat().resolvedOptions().locale`, giriş kutularıyla aynı kaynak. `formatDateOnly('yyyy-MM-dd')` saat dilimi kaymadan gün biçimler.
  - Python kod dönüştürme betiği: sayısal tarih/saat çağrıları `formatLocale()` → `dateLocale()` (102 çağrı, 86 dosya). Ay/gün adı yazan uzun biçimler (36) kelimeler uygulama dilinde kalsın diye bırakıldı. Sayı/para biçimi değişmedi.
  - Sabit `dd.MM.yyyy` kullanan yerler `formatDateOnly`'ye geçti: tablo tarih süzgeci, dokuma rapor gün anahtarı (`fmtDay`), termin (`formatDeadline`).
  - Genel ayarlardaki ölü "Tarih biçimi" kartı kaldırıldı; DB'deki kayıtlı değere dokunulmadı.
  - Test kurulumunda sistem yerel ayarı `tr-TR`'ye sabitlendi; mevcut test beklentileri değişmedi.
  - Changelog maddesi eklendi.
- **Doğrulama:** `verify.sh frontend` rc=0, 1928 test.
- **Not:** Web uygulaması Windows bölge ayarını doğrudan okuyamaz; tarayıcının diline/bölgesine bakar. Chrome'da bu, Chrome'un dil ayarıdır. Test tarayıcısı en-US → 10/25/2026.
- **Commit:** `9f070416` — feat(frontend): tarih bicimi bilgisayarin bolge ayarini izler.
- **DEV:** 1.0.2.1055 (sağlık 200).

### 12. Ekip içi mesajlaşma + canlı bildirim sistemi (kullanıcı: "bildirimlerin sistemini, mesajlaşmanın sistemini yazman lazım… whatsapp gibi arkada çalışacak… dosya gönderebilmem… geçmiş kayıtlar" + "yeni grup oluşturma falan olsun" + "fişlerin, malzeme kartlarının, seri topların, carilerin, cari fişlerinin linkini verebileceğiz")
- **Neden:** Kullanıcı DB'leri sıfırlayıp kullandıkları 3. parti uygulamayı (Novu) kaldıracak; öncesinde sistem içi mesajlaşma/bildirim çalışır olmalı. Keşif: Messaging/Notifications modülleri vardı ama uçtan uca çalışmıyordu (hub'da tenant yok, iki NotificationHub — biri korumasız `SendToTenant`, dosya servisi implementasyonsuz, ön yüz sahte rozetler, "ben" ilk katılımcı sanılıyor).
- **Kurul:** CTO, Skeptic, DBA, PO, Security → hepsi APPROVE/PASS-WITH-CONDITIONS. Koşullar + API kontratı `scratchpad/chat-plan.md`'de; özet: hub tenant'ı `?tenantId=` (yalnız /hubs, middleware doğrular, HttpContext.Items), kişisel push grupları `t:{tenant}:user:{id}`, hub'da mesaj gönderme yok (REST+MediatR+idempotency), presence Dragonfly sorted set (90 sn), MessageAttachment + NotificationReceipt tabloları, keyset sayfalama, Conversation.DirectKey, atomik UnreadCount. Aşama 2'ye kalan: sohbet içi arama, ✓✓, SendToRoleAsync rol süzgeci, Web Push.
- **Ne yapıldı (paralel iki ajan: backend + frontend, ortak kontrat):**
  - Backend: `TenantResolutionMiddleware` /hubs query tenant; `HubTenant`/`RealtimeGroups` (Shared); ChatHub yeniden (Ping/Typing/StopTyping/MarkRead, presence); Api NotificationHub silindi, modül hub'ı `/hubs/notifications`; contacts (Shared port `ITenantMemberDirectory`, Tenant modülü implement eder); grup komutları (rename/add/remove/promote/leave/mute, son admin devri, sistem mesajları); multipart gönderim (≤10 dosya, AttachmentUploadPolicy + txt/csv/zip, tenant önekli anahtar, hata olursa yüklenenler silinir), `attachments/{id}/url` (15 dk presigned, attachment disposition); NotificationReceipt ile kişi başı okundu; kullanıcı başı dakikada 60 mesaj sınırı. Migration `20261025102528_MessagingNotificationsV2`.
  - Frontend: `RealtimeProvider` (AppLayout'ta, iki hub, artan beklemeli yeniden bağlanma, tenant değişince yeniden aç), toast + tarayıcı bildirimi + sekme başlığında "(n)", iki panelli Mesajlar sayfası (Sohbetler/Ekip, mobilde tek panel), yeni grup diyaloğu, grup bilgi paneli, "⋯" mesaj menüsü (yanıt/tepki/düzenle/sil), dosya ataç/sürükle/yapıştır, header'da gerçek zil + mesaj rozeti. 11 dil `chat.json` parça dosyaları; 12 yeni API hata kodu 11 dilde.
  - Kayıt paylaşma: header paylaş düğmesi → sohbet seç → `🔗 başlık\nURL` mesajı; mesajda tıklanabilir kart, uygulama içi linkify (javascript:/data: link olmaz). `useShareTitle` ile başlık: malzeme kartı, stok fişi, cari kart, kumaş topu. Cari kart ve kumaş topu `?edit=<id>` ile doğrudan açılır.
  - Güvenlik post-check (PASS-WITH-FIXES) düzeltmeleri: teklif dosyası yüklemesine (Orders, artık IFileStorageService adapter'ı ile canlı) tür/imza kontrolü + boyut sınırı; `/hubs/chat` modül kapısından geçer (ModuleEntitlementGateMiddleware).
  - UX post-check (PASS-WITH-FIXES) düzeltmeleri: üye çıkar/yönetici yap onaylı, "⋯" menü (dokunmatik), paylaşımda "Gönderilecek:" satırı, yeni grupta zorunlu yıldız + ipucu, ortak Input/SearchInput, mobilde yazma alanı ekrana sığar. Saat biçimi değişmedi (kullanıcı kararı: bilgisayarın bölge ayarı).
  - DEV'de hub'lar 405 verdi: DEV sunucusu imajdaki nginx.conf yerine ESKİ elle bağlanmış bir ayar kullanıyor (yalnız `/api` API'ye gidiyor). Çözüm: `HubPathAliasMiddleware` (`/api/hubs/*` → `/hubs/*`, UseRouting'den önce; `app.UseRouting()` artık açık), ön yüz `/api/hubs/...` kullanır, hub yanıtlarında `X-Accel-Buffering: no`; imajdaki nginx.conf'a WebSocket'li `/api/hubs/` bloğu.
  - Novu: kodda hiç bağımlılık yok; tek iz `posgrasql/docker-compose.network-tek.yml` yorumu, nötr örnekle değiştirildi.
- **Dokunulan dosyalar:** 187 + 6 dosya; başlıcaları `src/backend/VuoApp.Modules.Messaging/**`, `VuoApp.Modules.Notifications/**`, `VuoApp.Api/Middleware/{TenantResolutionMiddleware,ModuleEntitlementGateMiddleware,HubPathAliasMiddleware}.cs`, `VuoApp.Api/Program.cs`, `VuoApp.Shared/Realtime/*`, `VuoApp.Infrastructure.Common/{Caching/RedisPresenceStore,FileStorage/TenantFileStorageService}.cs`, `src/frontend/src/features/messaging/**`, `features/notifications/**`, `layouts/components/header/header.tsx`, `src/frontend/nginx.conf`, testler `tests/unit/VuoApp.UnitTests/{Api,Modules.Messaging,Modules.Notifications,Modules.Orders/Rfqs}/*`.
- **Komutlar:**
  ```bash
  cd src/backend/VuoApp.Migrator && ConnectionStrings__DefaultConnection="Host=localhost;Database=x;Username=x;Password=x" dotnet ef migrations add MessagingNotificationsV2 --project . --context MigratorDbContext
  node tools/strip-migration-designers.mjs
  bash tools/verify.sh all           # rc=0 (her commit öncesi)
  V=1.0.2.1057; docker build -f src/backend/VuoApp.Api/Dockerfile --build-arg VERSION=$V -t tekbirsoft/vuoapp-api-dev:$V -t tekbirsoft/vuoapp-api-dev:latest src/backend
  docker build -f src/frontend/Dockerfile --build-arg VERSION=$V -t tekbirsoft/vuoapp-spa-dev:$V -t tekbirsoft/vuoapp-spa-dev:latest src/frontend
  docker push ... (4 etiket); curl http://217.131.14.57:56806/abdusselam.kosecik/$V
  ```
- **Sonuç / doğrulama:**
  - Yerel canlı (Chrome, gerçek backend, paylaşımlı vuo_dev — migration açılışta uygulandı): ekip listesi, birebir mesaj, grup kurma, sistem mesajları, ad değiştirme ikinci sekmeye canlı yansıdı, paylaş → kart → tıklayınca cari kart açıldı, mobil 390 px.
  - DEV uçtan uca (Node + @microsoft/signalr, jeton yazdırılmadan): iki hub bağlandı (Server-Sent Events — eski nginx WebSocket'i iletmiyor), REST ile gönderilen mesaj canlı `MessageReceived` olarak geldi.
  - **Dosya yükleme DEV'de ÇALIŞMIYOR — altyapı:** mevcut eski `/api/v1/files/upload` da 500. MinioFileService her tenant için `{BucketName}-{tenantId}` kovası açmaya çalışıyor; anahtarın kova oluşturma yetkisi yok / uç nokta uyuşmuyor. Yerelde: `cdn.vuo.app` → .57 traefik 404; servis sunucusundaki MinIO (`100.109.159.58:9090`, `vuoapp-minio`) AccessDenied; o MinIO'da hiç `vuoapp*` kovası yok.
- **Commit:** `913506a0` — feat(messaging,notifications): ekip içi mesajlaşma ve canlı bildirim sistemi (aşama 1) + kayıt linki paylaşma; `9b278981` — fix(messaging): hub'lar /api/hubs altından da erişilir.
- **DEV:** 1.0.2.1057 (sağlık 200).
- **HATA (düzeltildi):** 1056 imajları önce yanlışlıkla `-dev` eki OLMAYAN `tekbirsoft/vuoapp-api` / `vuoapp-spa` depolarına (`latest` dahil) gönderildi. Prod'a deploy tetiklenmedi. `latest` depo tarafında önceki `0.2.1020`'ye geri bağlandı (`docker buildx imagetools create`), yanlış `1.0.2.1056` etiketleri Hub API ile silindi, sonra doğru `-dev` depolarına gönderildi.

## Bulgular (düzeltilmedi, kullanıcıya raporlandı)
- **Modül atlamaları:**
  - Dokuma'da "Yeni Makine" Üretim Yönetimi'ne, "Yeni" iplik/kumaş kartı Stok'a atlıyor.
  - Üretim emri formunda menü tamamen boşalıyor ("Soldan bir modül seçin").
- **Dokuma Tezgahları sayfası:** salt liste. Tezgah özellikleri (tarak eni, maks tel) hiçbir formdan girilemiyor.
- **Kumaş analiz formu:**
  - Sayfa yana taşıyor (1494 px'te 1770 px; rapor tablosu hücreleri). Tıklamalar menüye denk geliyor, form uyarısız kayboluyor (kaydedilmemiş değişiklik uyarısı yok).
  - Ham en "İplik İhtiyacı" sekmesinde saklı; kumaş kartındaki en forma gelmiyor.
  - Ham İngilizce doğrulama mesajı: "[Input.Lines[0].Ends] 'Ends' must be greater than '0'."
  - Malzeme ve iplik seçicileri tüm stok kartlarını gösteriyor (kumaş/iplik süzmesi yok).
- **Kumaş kartı Kalite alanı:** en fazla 5 karakter; ekranda sınır yok. Uzun değerde ham veritabanı hatası kullanıcıya düşüyor (`value too long for type character varying(5)`).
- **Yeni Dokuma emri:**
  - alt başlık "Kumaş terbiye (boya/apre) üretim emri" yazıyor;
  - tarihler mm/dd/yyyy;
  - kalemde ham en/gramaj kumaş kartından gelmiyor.
- **Gizli ön koşullar:**
  - kumaş analizinin bağlanması (Çözgü Planlama'da);
  - Haşıl/İndigo adımı (tezgah yalnız dokuma leventi kabul ediyor);
  - kumaş kartında seri takibi.
- **Top oluşturma:** iplik stoğunu düşmüyor ("yakında").
- **Emir durumu:** dokuma akışında hiçbir adım emrin durumunu değiştirmiyor.
- **İki sekme:** iki sekmede aynı anda çalışınca refresh token yeniden kullanım tespiti oturumu kapattı (test notu).

## Kararlar
- İlk turda DEV'e paket çıkılmadı. Kullanıcı menü sırasını onaylayınca 1.0.2.1051 çıkıldı.
- Makine kuyruğu silme yetkisi "update"ten "delete"e çekildi. Yalnız güncelleme yetkisi olan kullanıcı artık kuyruktan emir çıkaramaz; dokumadaki tezgah kuyruğuyla aynı davranış.

## Açık kalanlar / sonraki adım
- **DEV dosya yükleme (altyapı, kullanıcıda):** DEV API ortamındaki MinIO uç noktası/anahtarı çalışan bir MinIO'ya bakmalı ve anahtar kova oluşturabilmeli (veya tenant kovaları önceden açılmalı). Düzelince sohbet ekleri + stok/dokuma ekleri birlikte çalışır.
- **DEV nginx:** sunucudaki elle bağlanmış eski nginx ayarı imajdakiyle değiştirilmeli (WebSocket, X-Robots-Tag). Şimdilik /api/hubs + SSE ile çalışıyor.
- Mesajlaşma aşama 2: sohbet içi arama, ✓✓ okundu, SendToRoleAsync rol süzgeci, Web Push (VAPID).
- GitHub Billing (Actions DEV Deploy) hâlâ bozuk.
- **0 m emirler:** `419fa88e` sonrası 0 m kaydedilmiş Boyahane dışı emirler varsa elle düzeltilmeli (CTO koşulu). Abdurrahman'a haber verilmeli.
- **Backend kuralı (CTO önerisi, teknik borç):** Boyahane dışı emirde PlannedQuantity 0 ise kaydı engellemek veya uyarmak.
- Kalan bulgular:
  - analiz formunda ham en kumaş kartından gelmiyor;
  - malzeme ve iplik seçiciler süzülmüyor;
  - ham İngilizce doğrulama mesajı;
  - Kalite alanı 5 karakter hatası;
  - dokuma emri alt başlığı ve tarih biçimi;
  - emir durumu değişmiyor;
  - iplik stoğu düşmüyor.
- Abdurrahman'a `2864cdfa` yetki düzeltmesini bildir.
