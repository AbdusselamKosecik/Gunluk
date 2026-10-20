# Saas_erp — 2026-10-21

## Bağlam
Landing (www.vuo.app, dev sunucusu) bitmişti; demo e-postası Brevo IP allow-list yüzünden bekliyor (217.131.14.57 Brevo → Security → Authorised IPs'e eklenmeli). Hedef: kullanıcının istediği Dokuma Kumaş Üretim Sistemi'ni legacy Sentez analizinden yola çıkıp fazlar halinde (F1–F7) VuoApp'e uyarlamak. Tasarım: `docs/design/dokuma-kumas-uretim-sistemi.md`, legacy analiz: `docs/design/dokuma-sentez-analiz.md` (commit 4d914453).

## Yapılanlar

### 1. Dokuma F1 — Tanımlar (iplik numara sistemi, tahar, çözgü/kumaş analiz formları, hesaplayıcı)
- **Neden:** Tüm üretim fazları (çözgü planı, indigo, tezgah, kontrol) analiz formundaki tel/sıklık/iplik verisine dayanır; önce tanımlar.
- **Ne yapıldı:**
  - Inventory: `YarnProperty`'ye numara sistemi (Ne/Nm/Denye/Tex/dtex), filament, kat, büküm; stok kartında "İplik" sekmesi (GET/PUT `api/v1/inventory/inventories/{id}/yarn`, PUT'ta `[RequirePermission("inventory","edit")]`). Okuma portu `VuoApp.Shared/Abstractions/IYarnSpecQueryService` (modüller arası bağımlılık yok).
  - Production: `WeaveDraft` (tahar), `WeavingAnalysis` + `WeavingAnalysisLine` + numara serisi (ÇA-/KA- kodları), `WeavingCalculator` (saf statik; Ne→Nm 1,6934; hesap metresi = miktar×(1+çekme%)+çözgü fazlası; m/saat = RPM×60×verim/(atkı/cm×100); 4 puan/100 m²).
  - API `WeavingController`: weave-drafts CRUD, analyses CRUD + calculate (mode: all/reedWidth/weftShrinkage/totalEnds). Gridify hatalı alan → 400 (`GridifyMapper/Filtering/Ordering/QueryException` yakalanır), sayfa ≤ 500, satır ≤ 200.
  - UI: Üretim > Dokuma > Tahar listesi / Çözgü analizleri / Kumaş analizleri (canlı hesap debounce, "Çözgü analizinden getir" çözgü satırlarını REPLACE eder, sonuç paneli, satır ızgarası).
  - Migration `20261020220636_WeavingDefinitionsF1` (+ `node tools/strip-migration-designers.mjs` ile eski 5 designer inceltildi). Paylaşımlı dev DB'ye API açılışında uygulandı.
- **Kurul:** cto/skeptic/dba/product-owner APPROVE-WITH-CONDITIONS (koşullar tasarım §3.7'de). Security post-check: PUT yarn yetkisi, Gridify 500→400, sayfa/satır limitleri. UX: ilk tur BLOCK → düzeltmeler: iplik seçici tüm stok kartlarını listeler (firmalar ipliği "Hammadde" tipinde tutuyor), boş inventoryId yerine EMPTY_GUID ile hesap (400 hatası), çözgü formuna "Tarak eni hesabı için" alanları (Ham en, atkı fazlası, atkı büzülmesi), ipliksiz satırla kaydetme uyarısı, 375px taşma, formül notu yalnız kumaş formunda, Hammadde tipli kartlarda da İplik sekmesi. UX post-check PASS-WITH-FIXES → satır ızgarası sayı alanları dar (px-2 + min-w-24), getir örgü tipi/taharı boşsa kopyalar, "Hesap eni boş (İplik İhtiyacı sekmesi)" uyarısı.
- **Dokunulan dosyalar:** `src/backend/VuoApp.Domain/Enums/{YarnCountSystem,WeavingAnalysisKind,YarnSide}.cs`, `VuoApp.Modules.Inventory/{Entities/YarnProperty.cs,Features/Yarn/YarnSpec.cs,Services/YarnSpecQueryService.cs,Features/InventoryController.cs,InventoryModule.cs}`, `VuoApp.Modules.Production/{Entities/Weav*.cs,Features/Weaving/*.cs,Features/WeavingController.cs,ProductionDbContext.cs,ProductionModule.cs}`, `VuoApp.Shared/{Abstractions/IYarnSpecQueryService.cs,Constants/ErrorCodes.cs,Resources/ErrorMessages.cs}`, migrator, `src/frontend/src/features/production/{api/weaving.*,pages/weaving/**}`, `features/inventory/{api/yarn-spec.api.ts,pages/inventory/**}`, routes, i18n, changelog, testler.
- **Komutlar:**
  ```bash
  dotnet test tests/unit/VuoApp.UnitTests          # (yerel API açıksa DLL kilidi → önce API'yi durdur)
  cd src/frontend && npx tsc --noEmit && npx vitest run src/features/production/pages/weaving src/features/inventory
  ```
- **Sonuç / doğrulama:** 3978 unit test geçti / 3 skip / 0 fail; tsc 0 hata; 215 vitest geçti. UX tarayıcıda ÇA-0001 çözgü analizi kaydedildi, getir + m/saat 15,3 doğrulandı.
- **Commit:** `32b0598f` — feat(production,inventory,frontend): Dokuma F1 tanimlar (dev'e push)

### 2. Dokuma F2 — Çözgü planlama kurulu
- **Ne yapıldı:** Öneri (WarpBeam genişletme, plan önerisi, toplu levent) cto/skeptic/dba/product-owner'a sunuldu; hepsi APPROVE-WITH-CONDITIONS. Birleşik kararlar:
  1. Hesap metresi tek formül: `WeavingCalculator.CalcMetersFrom`; fire % yalnız kg'a.
  2. Teller leventlere EŞİT dağılır: n=ceil(toplam/leventTel), her levent floor/ceil (5880/500→12×490; 4239/500→9×471/472).
  3. Kapasite girilirse parti = ceil(hesapMetre/kapasite), her partinin `WarpRunNo`'su.
  4. Varsayılan levent teli `WeavingAnalysis.EndsPerBeam`; çözgü verisi kumaş analizinin `WarpAnalysisId`'sinden yoksa kendisinden.
  5. Emir analiz bağlarken hesap girdilerini kopyalar (snapshot); leventi varken analiz değiştirme ve bağlı analizi silme → 409.
  6. Emir Dokuma tipi + metre birimi + açık olmalı; analiz Kind=Fabric.
  7. Şema: WarpBeam + BeamKind (default 1, CHECK 1/2), WeavingAnalysisId (Restrict), WarpRunNo; ProductionOrder + WeavingAnalysisId + snapshot kolonları; partial index'ler; PlannedEnds/PlannedLength/ParentBeamId YOK (ParentBeamId F3).
  8. Levent no `{emirNo}-C{nn}` (en yüksek ek+1, transaction), 23505 → 409, idempotent, ≤200.
  9. Satır başına iplik; 10. silme yalnız prepared/UsedLength=0/bağlı değil; 11. endpoint'ler mevcut `warp-beams` altında + yetki; 12. Çözgü planlama ekranı + mevcut warp_beams sayfasına BeamKind kolonu.

### 3. Dokuma F2 — Çözgü planlama (uygulama)
- **Neden:** Çözgü sorumlusu emrin kumaş analizinden kaç çözgü leventi (≈500 tel) gerektiğini görüp leventleri toplu oluşturabilmeli.
- **Ne yapıldı (§2'deki kurul kararları birebir):**
  - Backend: `Features/Weaving/WeavingCalculator.WarpPlan.cs` (PlanWarp / PlanWarpFromMeters; eşit dağıtım, parti), `Features/Weaving/{WarpPlanning,WarpPlanSupport}.cs` (PUT `weaving/orders/{id}/analysis` → emre kopya; GET `weaving/warp-plans/{orderId}?capacityM=&endsPerBeam=`), `Features/WarpBeams/{CreateWarpBeamBatch,DeleteWarpBeam}.cs` (POST `warp-beams/batch` idempotent ≤200, numara `{emirNo}-C{nn}` en yüksek ek+1, 23505→409; DELETE yalnız hazırlandı/kullanılmamış/makineye bağlı değil), GetWarpBeams `beamKind` filtresi + Gridify hatası 400 + sayfa ≤500, analiz silmede 409 (kullanımda), `Entities/WarpBeamStatuses.cs`, `Domain/Enums/WarpBeamKind.cs`. Tüm warp-beam aksiyonlarına `[RequirePermission("production", …)]` (öncesinde yoktu).
  - Migration `20261020223449_WeavingWarpPlanningF2` — yerel API açılışında paylaşımlı dev DB'ye uygulandı.
  - Frontend: `features/production/pages/weaving/warp_planning/*` (emir seçici Dokuma tipine sabit, analiz bağla, öneri kartı + formül notu, kapasite/levent teli girdileri emir bazında saklanır ve mevcut leventlerden doldurulur, önizleme ızgarası, fazla planlamada onay, mevcut leventler + silme). Oluştur/bağla sonrası plan yenilenene kadar düğmeler kilitli (çift oluşturma önlemi). Çözgü Leventleri sayfasına Tür + Parti No kolonu ve tür filtresi. Tablo kapları `w-0 min-w-full overflow-x-auto` → 375 px'te sayfa genişliği referans sayfayla aynı (445).
- **Uygulama kararları:** ProductionOrder'da güvenilir birim yok → PlannedQuantity metre kabul edilir, yalnız >0 kontrolü (tasarım dokümanında not). Parti no kısa etiket (P01..). Kopya yalnız sayıları dondurur; iplik satırları bağlı analizden canlı okunur.
- **Doğrulama:** backend 4026 test geçti / 0 hata; frontend tsc temiz, production vitest 197 geçti. Security PASS-WITH-FIXES (sayı sınırları, Gridify 400, IsDeleted filtresi uygulandı). UX ilk tur PASS-WITH-FIXES (eski ekran 3–6 sn → çift oluşturma riski, çift 409 mesajı, girdi kaybı, birincil düğme, 375 px) → düzeltildi; ikinci turda 3 hızlı tıklamada tek istek, 19→20 levent doğrulandı; 375 px'i Chrome'da elle ölçtüm (445).
- **Test verisi (dev DB, MitoTex A.Ş.):** emir UX-231161 (1000 m), KA-0001 kumaş analizi, 20 çözgü leventi.
- **Commit:** `8d88f022` — feat(production,frontend): Dokuma F2 cozgu planlama (dev'e push)

### 4. Dokuma F3 — İndigo / Haşıl (çözgü leventlerinden dokuma leventi)
- **Neden:** Kullanıcı isteği "İndigo/Kimyasal: çözgü leventlerini birleştirip dokuma leventi (≈6000 tel)".
- **Kurul (cto/skeptic/dba/po — hepsi APPROVE-WITH-CONDITIONS):** Skeptic'in itirazı kabul edildi: gerçek haşıl hattında bir çözgü partisi birden çok dokuma leventine kesilir → `ParentBeamId` yerine bağlantı tablosu `BeamProcessInput(BeamProcessId, WarpBeamId, UsedLength)`; çözgü leventi kısmi kullanılır, kalan 0 olunca `consumed`. Kimyasal satırları yalnız kayıt (stoktan düşmez, `PostedAt` null, UI notu; stok düşümü sonraki fazda Outbox `BeamProcessCompleted`). Proses tipi İndigo=1/Haşıl=2/İndigo+Haşıl=3 ("Kimyasal" tip değil). Ip boyama (rope dyeing) kapsam dışı. Tam karar listesi tasarım §3.10.
- **Ne yapıldı:**
  - `WeavingCalculator.MergeBeams` (tel=toplam, uzunluk ≤ en küçük kalan, varsayılan MIN; hedef tel = emir kopyası WarpTotalEnds; uyuşmazlık `acceptEndsMismatch` olmadan 400, kabulde Expected/Actual/AcceptedBy kaydı).
  - Entity'ler: `BeamProcess` (BP- serisi `BeamProcessNumberSequence` row-locked UPSERT), `BeamProcessInput`, `BeamProcessChemical` (ad/birim kopyası, `IInventoryMrpQueryService.GetInventoryNamesAsync` ile doğrulama). WarpBeam: `consumed` durumu (`ManualTransitions` dışında), CHECK UsedLength ≤ TotalLength.
  - API (`WeavingController`): POST/GET/GET{id}/DELETE `weaving/beam-processes` (idempotent; emir satırı `FOR UPDATE`; xmin/23505 → 409; dokuma leventi no `{emirNo}-D{nn}`, geri al sonrası numara yeniden kullanılabilir — bilinçli). Geri al: kaydedilen metre birebir iade, soft delete (girdi satırları iz olarak kalır).
  - F2 uçları kilitlendi: prosesli / dokuma leventi `DELETE warp-beams` → 409; `consumed` elle atanamaz.
  - UI: `pages/weaving/beam_processes/*` (emir seç, hazır leventler çoklu seçim + canlı özet, uzunluk, proses tipi, makine [Dokuma'ya sabit], tarih, haşıl alma %, kimyasal satırları + "Bu satırlar stoktan düşmez", uyuşmazlık onay kutusu, proses listesi/detay, geri al). Çözgü planlamada "Tüketildi" rozeti.
  - Migration `20261020230917_WeavingBeamProcessF3` (API açılışında dev DB'ye uygulandı).
- **Doğrulama:** backend 4080 test geçti / 0 hata; frontend tsc temiz, production vitest 218 geçti. Security PASS (tek Low: sıra tablosu CreatedBy=tenantId — tüm number service'lerde ortak mevcut desen, ayrı iş). UX PASS-WITH-FIXES → uzunluk hatası iki kez/düğme açık, detayda güncel değerler (kolonlar "Bu proseste kullanılan / Güncel kalan / Güncel durum"), kayıt sonrası haşıl % korunur, "%12", alan hizaları, "En az 2 levent seçin" ipucu — düzeltildi. 375 px = 445.
- **Test verisi (dev DB, MitoTex, emir UX-231161):** BP-0001 (300 m, D01), BP-0003 (290 m, D02) → C01–C10 tüketildi. BP-0002 oluşturulup geri alındı.
- **Commit:** `e3c86224` — feat(production,frontend): Dokuma F3 indigo/hasil (dev'e push)

## Kararlar
- F2 kodlamasına F1 ayrı commit olarak push edildikten sonra başlanır (CTO koşulu) — yapıldı.
- Çözgü hataları F2'den F5'e taşındı.

## Açık kalanlar / sonraki adım
- F4 Tezgah: levent bağlama/sökme, başlat/durdur (duruş nedeni), atkı sayacı okuması, dok kesme (FabricRoll), kalan metre/süre, tahar değişim beklemesi — kurul.
- F3 borç: kimyasal sarfın stoktan düşümü (Outbox), sıra tabloları CreatedBy=tenantId (ortak desen), detayda makine kodu (DTO'da yok).
- F2 öncesinden kalan borç: CreateWarpBeam/UpdateWarpBeamStatus aynı-tenant kontrolü yapmadan MountedOnMachineId/ProductionOrderId/YarnInventoryId yazıyor (security Low).
- F2 nit: kalan levent için önerilen parti no P04 (mevcut P01/P02).
- Frontend tam suite'te F2 dışı 7 kırık test: en.json'da FreeStockReport/KoliListesi/ChemicalStockOut/SystemParameters anahtarları eksik (i18n parity), login.test.tsx (5), worklist-routes.contract (1).
- UX nit'leri (F1): zorunlu alan işareti, paylaşılan malzeme seçici diyaloğunda Türkçe karakter eksikleri (mevcut, F1 kaynaklı değil).
- Brevo: kullanıcı 217.131.14.57'yi yetkili IP'ye ekleyince test demo talebi tekrar gönderilecek.
- Dev imajlarını F1 ile yeniden build/deploy (opsiyonel).
