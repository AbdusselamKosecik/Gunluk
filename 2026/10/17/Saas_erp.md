# Saas_erp — 2026-10-17

## Bağlam
İki panelli menü denemesi `feat/iki-panelli-menu` dalında sürüyor. Kullanıcı standart modüllerin Sentez gibi süreç bazlı ayrılmasını istedi (Envanter, Satın Alma, Satış Dağıtım, Finans…) ve SAP ile diğer ERP'lerin bunu nasıl ayırdığını sordu. Üretim modüllerine dokunulmayacak.

## Yapılanlar

### 1. ERP karşılaştırması (sohbette)
- SAP: MM (satın alma + stok + fatura kontrolü), SD (satış + sevkiyat + faturalama), FI/CO. Logo Tiger: Satınalma, Satış ve Dağıtım, Malzeme Yönetimi, Finans, Muhasebe. Sentez: Satın Alma, Satış, Malzeme, Finans, Genel Muhasebe. Netsis ve Odoo da benzer.
- Ortak ilke: belge türüne göre değil, süreçe göre ayırmak (talep → teklif → sipariş → irsaliye → fatura aynı modülde).

### 2. Süreç bazlı standart menü düzeni
- **Neden:** Bizde satın alma süreci Siparişler, Envanter, Finans ve Talep modüllerine dağılmıştı.
- **Ne yapıldı:**
  - `two-panel/menu-layout.ts`: `applyMenuLayout(modules, layout)` fonksiyonu. Sayfaları adresleri üzerinden yeniden gruplar.
    - Yalnızca tüm sayfaları `/inventory|orders|demand|logistics|crm|finance/` altında olan modüller "standart" sayılıyor, üretim modülleri hariç tutuluyor.
    - Sadece menüde görünen sayfalar yerleşiyor; lisans ve yetki filtresi korunuyor.
    - Düzende yeri olmayan sayfa eski modülünde kalıyor. Boş gruplar ve modüller budanıyor.
  - `two-panel/standard-menu-layout.tsx`: yeni modüller Stok, Satın Alma, Satış ve Dağıtım (Lojistik dahil), Fason, Finans (Cari/Kasa/Banka/Çek/Ödeme/Fatura/Kur-Vade/Döviz/Dış Ticaret), Muhasebe (Genel Muhasebe/Raporlar/Maliyet/Sabit Kıymet) ve CRM. Fiş tipleri `?type=` kodlarıyla dağıtıldı (ör. 3001 Mal Alım → Satın Alma, 3052 Toptan Satış → Satış, 3057 Fason Verilen Çıkış → Fason). "Tüm Siparişler / Teklifler / Talepler / Faturalar" hem Satın Alma'da hem Satış'ta duruyor.
  - `routes.tsx` değişmedi; sayfa adresleri aynı. Klasik menü eski gruplamayı gösteriyor.
- **Testler:** `menu-layout.test.ts` 6 test (yeniden gruplama, budama, artakalan sayfa, üretim modülüne dokunulmaması). `standard-menu-layout.test.ts` gerçek `HomeMenu` ile 3 test (her standart sayfa yerleşmiş, düzendeki her adres menüde var, üretim modülleri aynı). `src/layouts` toplamı 41 test geçti, typecheck temiz.
- **Görsel doğrulama:** playwright ile kontrol edildi. Şerit sırası: Anasayfa, Stok, Satın Alma, Satış ve Dağıtım, Fason, Finans, Muhasebe, CRM, Üretim, Boyahane… Mal Alım İrsaliyesi açıkken Satın Alma seçili.
- **Commit:** dal `feat/iki-panelli-menu`, push edildi.

## Kararlar
- Gruplama `routes.tsx` yerine menü katmanında yapıldı. Sebebi: route adresleri ebeveyn yolundan türetiliyor; öğeleri taşımak adresleri ve linkleri bozardı.

## Açık kalanlar / sonraki adım
- Kullanıcı onaylarsa kurul (CTO, Şüpheci, UX, Product Owner) çalıştırılacak, `dev`'e merge edilecek ve changelog maddesi eklenecek.
- Yeni modül başlıkları sabit Türkçe; i18n anahtarı yok (İngilizce arayüzde de Türkçe görünür).

---

## Ek: Teklif listesi 500 hatası (dev)

### Teklif / RFQ / Teklif Talebi listelerinde filtre-sıralama hatası
- **Neden:** Satış Teklifleri menüsü (`/orders/quotations?type=5101`) açılınca API 500 veriyordu: `InvalidOperationException ... new QuotationListResult(..).ReceiptType == 5101 could not be translated`. Handler önce `Select(new Result(..))` yapıp sonra `GridifyAsync` çağırıyordu; Gridify filtresi projeksiyona uygulanınca EF Core SQL'e çeviremiyor.
- **Ne yapıldı:** `GetQuotations`, `GetRfqs`, `GetQuotationRequests` handler'ları projede zaten kullanılan desene (`GetCurrentAccounts`/`GetInvoices`) çevrildi: `GridifyMapper<Entity>(autoGenerateMappings: true)` ile `ApplyFiltering` + `ApplyOrdering` entity üzerinde → `CountAsync` → `Skip/Take` → en sonda `Select` → `new Paging<T>(total, items)`. Varsayılan sıralama `CreatedAt desc` korundu.
- **Test (TDD):** InMemory sağlayıcı bu hatayı yakalamıyor (client-side çalışıyor). Bu yüzden `InventoryGroupSortingTests` desenindeki gibi gerçek Npgsql çeviricisi bağlantısız (interceptor ile) çalıştırıldı → önce 4 test kırmızı (kullanıcının hatasının aynısı), düzeltme sonrası yeşil. Dikkat: `QuotationRequests` sayfa sorgusu `Items.Count` alt sorgusunda `count(*)` içerdiği için sahte sayım yalnız `SELECT count(*)` ile başlayan komuta verildi.
- **Dokunulan dosyalar:** `src/backend/VuoApp.Modules.Orders/Features/{Quotations/GetQuotations.cs, Rfqs/GetRfqs.cs, QuotationRequests/GetQuotationRequests.cs}`, `tests/unit/VuoApp.UnitTests/Modules.Orders/OrdersListTranslationTests.cs`, `tests/unit/VuoApp.UnitTests/Modules.Orders/Quotations/GetQuotationsTests.cs`, `src/frontend/src/features/changelog/changelog.data.ts` (fix maddesi).
- **Komutlar:**
  ```bash
  dotnet test tests/unit/VuoApp.UnitTests --filter "FullyQualifiedName~Modules.Orders"   # 151/151
  dotnet build src/backend/VuoApp.slnx -c Debug                                           # 0 hata
  ```
  Not: çalışan API `bin` dosyalarını kilitlediği için test öncesi durdurulup sonra yeniden başlatıldı.
- **Sonuç / doğrulama:** Canlı (vuo_dev, MitoTex) `GET /api/v1/orders/quotations?filter=receiptType=5101`, RFQ ve teklif talebi listeleri filtre+sıralama ile 200 döndü (MitoTex'te kayıt yok, sayım 0).
- **Commit:** `d7e0ec96` — fix(orders): teklif, RFQ ve teklif talebi listelerinde filtre/siralama 500 hatasi (dev'e push → DEV deploy).

### Kararlar
- Kullanıcının doğrudan bugfix talimatı → kurul muafiyeti (CLAUDE.md üst kural 4). Aynı hata sınıfındaki iki kardeş liste (RFQ, Teklif Talebi) de aynı commit'te düzeltildi.

### Açık kalanlar
- Diğer modüllerde de `Select → GridifyAsync` sırası olan liste handler'ları olabilir; taranıp aynı desene çekilmesi önerilir.

---

## Ek 2: Stok menüsü ve malzeme kartı kuralları (müşteri listesi)

### Bağlam
Kullanıcı Stok modülü için 9 maddelik bir liste verdi: menü düzeni (1-6) + malzeme kartı sınıflandırma kuralları (7-9).

### 1. Menü (dal `feat/iki-panelli-menu`, commit `1f10e408`, sonra `ac6644ad`)
- **Neden:** Hareketler altındaki alt gruplar uzun; referans listeleri (UBL/UNECE/GS1, Kimyasal Maddeler, Varyant Kartları, Birimler) menüde gereksiz; bazı tanımlar yanlış modülde.
- **Ne yapıldı:**
  - `two-panel.utils.ts`: başlık satırlarına `key` (modül içi yol, ayraç " › ") eklendi; `applyCollapse` ağaç bilinçli: üst bölümler varsayılan AÇIK, alt gruplar varsayılan KAPALI, `collapsed` listesi = varsayılandan sapan anahtarlar; açık sayfanın grubu ve ataları her zaman açık.
  - `panel-rows.tsx`: alt grup başlıkları da buton (chevron + sayfa sayısı).
  - `routes.tsx`: units, variant-cards, unece-unit-codes, ubl-code-lists, chemical-substances, gs1-prefixes → `isNav: false` (route duruyor; iki menüde de gizli).
  - i18n: InventoryManufacturers "Envanter Üreticileri" → "Üreticiler" (en: "Manufacturers").
  - `menu-layout.ts`: `MenuPlacement {anchorPath, paths}` — standart sayfayı standart olmayan bir modüle, `anchorPath` sayfasının listesine ekler (başlık dile bağlı olduğu için yol ile hedeflenir; hedef yoksa sayfa yerinde kalır).
  - `standard-menu-layout.tsx`: Hata Kartları + Kalite Tipleri → Üretim › Tanımlar (anchor /production/machines); Stok Türleri + Stok Cinsleri → Ayarlar (anchor /settings/general); Masraf Tipleri → Finans › Ödemeler; Stok Kartları altına sınıf listeleri.
- **Test:** `src/layouts` 47 test; Playwright ekran görüntüsü (Stok/Üretim/Ayarlar/Finans).

### 2. Kurul (malzeme kartı kuralları)
- cto: APPROVE-WITH-CONDITIONS (verisi olan sekme gizlenmesin; Demirbaş→ayrı tip önerisi; ORME/DOKUMA seed; sabitler tek dosyada).
- skeptic: Faz A APPROVE-WITH-CONDITIONS, **Faz B (InventoryOperationTime tablosu) BLOCK** — rota (RouteItem: OperationId + RunTime) zaten kartla bağlı; ikinci kopya kayar. Alternatif: İş Etüdü'nde rotanın operasyonlarını salt-okunur göster.
- dba: APPROVE-WITH-CONDITIONS (deterministik Standart tür seçimi; Faz B olursa hard replace-all TenantEntity).
- product-owner: APPROVE-WITH-CONDITIONS (sınıf değişince uymayan tip temizlenir; Hizmet/Demirbaş/Ticari Mal'da firma tipleri listelenmez; sınıf listeleri; ?class ile Yeni).
- **Kullanıcı kararı:** Demirbaş → yalnız Ticari Mal (müşteri isteği; CTO itirazı kod yorumuna not edildi).

### 3. Faz A uygulaması (dev, commit `293ef8fc`)
- **Backend:** `InventoryClass.CommercialGoods = 6`; `SystemInventoryType.Service = 12`; seeder'a ORMEKUMAS/DOKUMAKUMAS/HIZMET; `CreateInventory` KindId boşsa aktif Standart tür (firma kaydı önce, sistem sonra); `GetInventoryTypes`/`GetInventoryKinds` filtre/sıralama entity üzerinde (Select→Gridify 500 hatası).
- **Frontend:** `inventory-system-classifications.ts` (INVENTORY_CLASS, SYSTEM_TYPE, SYSTEM_KIND, sınıf→tip eşlemesi, `typeFilterForClass`), `inventory-card-rules.ts` (`isTabVisible`, `tabsWithData`), `inventory.detail.tsx` (sınıf seçenekleri, sınıf değişince tip temizleme, filtreli tip lookup wrapper — §3.10 deseni, koşullu sekmeler, ?class + Standart tür varsayılanı), `inventory-kind.api.ts`, tip listesi pageSize 1000, `inventory-class-list.page.tsx` + routes (products, semi-finished, commercial-goods, fixed-assets, services), tip/cins formunda kod boş.
- **Bulunan eski hata:** `/inventory/inventories/new` route'unda `id` parametresi yok → `isNew` hep false idi; `?type=boya` ön-seçimi hiç çalışmıyordu. `isNew = !id || id === 'new'`.
- **Bulunan döngü:** yüklenirken her render'da yeni `[]` → efekt formu her seferinde yeniden yazıyordu; değişiklik yoksa `prev` döndürülerek düzeltildi.
- **Test:** `SqlTranslationCapture` ortak yardımcı (Npgsql çevirisini bağlantısız sınar; Orders testleri buna taşındı). Backend tüm birim testleri 3740 geçti; frontend envanter/app/layout 160 test.
- **Doğrulama (Playwright):** ?class=4 → sınıf Hizmet, tür Standart, tip lookup'ta yalnız HIZMET, sekmelerde yalnız Hizmet; Mamul/Demirbaş/Ticari Mal sekmeleri doğru; mevcut Dokuma Kumaş kartında Kumaş sekmesi, varyantlı kartta Varyant sekmesi görünüyor.
- **Not:** Yerel API açılışta yeni sistem tiplerini paylaşılan vuo_dev'e seed etti (idempotent, ekleme).

### 4. Sistem kayıt koruması + İş Etüdü rota süreleri (dev, commit `dc56f8a4`)
- **Neden:** Sistem stok tipleri ve cinsleri (`TenantId = Guid.Empty`) tüm firmalarda ortak, ama herhangi bir firma bunları Update/Delete ile değiştirip silebiliyordu. Kullanıcının isteği: "devam et, sistem tiplerinin korunmasını da düzelt". Bu aynı zamanda İş Etüdü için skeptic'in önerdiği yola devam onayı.
- **Kurul:**
  - cto ve skeptic: APPROVE-WITH-CONDITIONS.
  - security-reviewer: **BLOCK**, üç bulguyla (üçü de giderildi):
    1. Stok tipi, stok cinsi ve birim seti yazma uçlarında hiç `[RequirePermission]` yoktu. PermissionGateMiddleware attribute yoksa isteği geçiriyor, yani izleyici rolü bile yazabiliyordu.
    2. UpdateUnitSet, CreateUnitSetItem ve DeleteUnitSetItem'da sistem guard'ı yoktu.
    3. Delete sonucunda Forbidden hatası 500 olarak dönüyordu.
- **Backend:**
  - Guard: Update/Delete Type ve Kind, UpdateUnitSet, Create/DeleteUnitSetItem'da `TenantId == SystemTenantId && !IsSuperAdmin` ise Forbidden döner.
    - Hata kodları: tip/cins için `inventory.type.system_read_only` ve `inventory.kind.system_read_only`; birim seti için mevcut UnitSet kodu.
    - CreateUnitSetItem önce setin var olduğunu kontrol eder, yoksa NotFound döner.
  - Sonuçlara `IsSystem` alanı eklendi; Select içinde hesaplandığı için SQL'e çevriliyor.
  - `[RequirePermission("inventory", ...)]` eklenen uçlar (MasterDataController ve InventoryController):
    - Stok tipi ve cinsi: create, edit, delete.
    - Birim seti: create, edit, delete, save, clone.
    - Birim seti satırı: ekleme `create`, silme `edit`.
  - **ApiKeyScope bilerek eklenmedi.** Sistem fail-closed çalışıyor: attribute yoksa API anahtarı zaten erişemiyor. Eklemek entegrasyon anahtarlarına yeni bir kapı açardı.
  - İki controller'ın HandleDeleteResult'ında Forbidden artık 403 döner.
- **Rollout testi:** `RequirePermissionContractTests.InventoryMasterDataMutations_RemainOutsideThisRollout` tip/cins uçlarını "kapsam dışı" diye sabitliyordu. Bu uçlar listeden çıkarıldı ve yeni `InventorySharedMasterDataPermissionContractTests` eklendi.
- **Frontend:**
  - Yeni `features/inventory/utils/system-record.tsx`: `canModifyRecord`, `useCanModifyRecord` (süper admin bilgisini `useMe().isSuperAdmin`'den alır) ve `SystemRecordNotice`.
  - Tip/cins düzenleme formu sistem kaydında kilitli açılır (fieldset disabled + uyarı); listede Sil düğmesi `canDelete` ile gizlenir.
  - `error-messages.ts`'e tr/en mesajları eklendi.
- **İş Etüdü:**
  - Yeni `work-study-routes.tsx` ve `work-study-routes.utils.ts`. Kart, `GET /production/routes?filter=inventoryId=<id>&pageSize=100` ile karta bağlı rotaları çeker (sessiz istek, yeniden deneme yok).
  - Firmada üretim modülü yoksa sorgu **hiç atılmaz**. Sebep: axios `Subscription.ModuleNotInPlan` hatasında kullanıcıyı ana sayfaya atıyor ve bu kontrol silent'tan önce çalışıyor.
  - Aktif rota önce, ardından en yeni sürüm gösterilir; makine adı `effectiveMachineName`'den gelir.
  - Hazırlık, çalışma ve bekleme süreleri ayrı ayrı toplanır, birbirine eklenmez; çalışma süresi birim başına.
  - `route_detail.page.tsx`: yeni rota `?inventoryId&inventoryName` ile ürün hazır seçili açılır. Modül seçimi zaten zorunlu (§3.10).
  - `InventoryItem.RouteId`'ye dokunulmadı.
- **Test:**
  - Backend birim testlerinin hepsi geçti (3770). Yeni testler: SystemTypeKindProtectionTests 10, UnitSetSystemProtectionTests 7, permission contract 13.
  - Frontend inventory ve production testleri geçti (270); typecheck temiz.
- **Doğrulama (Playwright):**
  - Tip listesi `isSystem` alanını döndürüyor.
  - Dev DB'de karta bağlı rota olmadığı için rota yanıtı `page.route` ile taklit edildi; paylaşılan DB'ye test verisi yazılmadı.
    - Kart, tabloyu ve toplamları (25 / 6,15 / 2) doğru gösterdi; pasif rotada "Pasif" rozeti var.
    - "Rota oluştur" ürünü dolu açıyor.
  - Firma kullanıcısının gözünden kilitli form görülmedi; elde yalnız süper admin hesabı var.
  - ux-reviewer çalıştırılamadı (chrome-devtools MCP bağlanmadı).
- **Not:** Günlüğe ilk yazımda kabuk, metindeki ters tırnakları komut sandı; bölüm bozuk girdi ve düzeltildi.

## Açık kalanlar
- Güvenlik (kalan): MasterDataController/InventoryController'daki diğer stok tanım yazma uçlarında (marka, özellik, özel kod vb.) da [RequirePermission] yok — ayrı tur.
- Süper admin bir sistem tipini silerse tüm firmalarda kaybolur; kullanımda mı kontrolü yok (CTO teknik borç).
- UX post-check (ux-reviewer) chrome-devtools MCP bağlanınca yapılmalı.
- Firma kendi "Hizmet"/"Örme Kumaş" tipini açtıysa listede iki benzer kayıt görünebilir.
- ~138 liste handler'ında Select→GridifyAsync sırası (filtrede 500 riski) — taranıp düzeltilmeli (kurul).
- Menü dalı `dev`'e alınmadı (kurul + kullanıcı onayı bekleniyor).
