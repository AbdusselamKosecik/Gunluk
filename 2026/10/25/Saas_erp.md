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
