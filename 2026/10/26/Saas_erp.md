# Saas_erp — 2026-10-26

## Bağlam
Kullanıcı tek mesajda 15 maddelik bir program verdi ve "bana sormadan yapıp sisteme gönder" dedi.
- **Fiş ekranı (beş madde):** yazılabilir lookup, indirim/masraf açıklaması, vergilerin listeden seçilmesi, tipe göre alan düzeni, tam ekran.
- **Arayüz ve navigasyon:** bayraklar, favoriler, ana sayfa ağacı, yönetici paneli.
- **Standart numara:** tüm fiş tipleri ve belgeler.
- **Raporlama:** BI paneli hatası, stok raporu modalı, rapor tasarımcısı.
- **Bildirimler:** bildirim tercihleri ve fiş bildirimleri.
- **Talep:** talep listesinin çevirisi.
- **Oluşturma ekranları:** talep, teklif, sipariş ve fatura oluşturma ekranları fiş ekranı gibi olacak.
- **Üretim:** planlamada kaynak yükleme, Sentez Textile menüsüne göre Örme/Dokuma sayfaları.

Takip dosyaları (scratchpad):
- `program-20261026.md`: istek, keşif özeti ve ilerleme.
- `plan-20261026.md`: paketler P1–P8 ve kurul kararları.
- `agent-brief-common.md`: ajanlara ortak kurallar.

## Yapılanlar

### 1. Keşif ve kurul
- **Neden:** iş çok büyük; kurul onayı zorunlu.
- **Ne yapıldı:**
  - 4 Explore ajanı çalıştı: fiş ekranı; kabuk, favoriler ve bildirim tercihleri; raporlar, BI, talep ve oluşturma ekranları; Sentez menü karşılaştırması.
  - Plan P1–P8 olarak yazıldı.
  - Kurul (PO, CTO, DBA, Şüpheci, Güvenlik) hepsine APPROVE-WITH-CONDITIONS verdi.
  - Şüpheci P3'ü, Güvenlik de P4'ü bloklamıştı. İkisi de koşullar uygulanarak kalktı:
    - P3: sayaç mevcut en yüksek numaradan tohumlanır; tüm numara yolları aynı commit'te yeni üreticiye geçer.
    - P4: `SendToRoleAsync` kullanılmaz; alıcılar kullanıcı başına izinle çözülür; `inventory:approve` izni eklendi.
- **Ana kararlar:**
  - Migration'lar paralel worktree'lerde üretilmez; her birleştirmeden sonra dev'de sırayla üretilir.
  - Fiş alan düzeni TenantSettings'te değil, `inventory.ReceiptTypeLayout` tablosunda tutulur.
  - Rapor/pivot için yeni modül `VuoApp.Modules.Reporting` açılır. Veri, Shared `IAnalyticsSource` beyaz listesi üzerinden okunur; ham SQL yok.
  - Numara üretiminde yeni Scope kolonu yok; mevcut ScopeKey kullanılır.

### 2. Paralel uygulama (worktree ajanları) ve birleştirme
- **Yöntem:** her paket ayrı worktree'de, TDD ile yazıldı ve `verify.sh all` rc=0 ile bitirildi. Coordinator `wtd`'de `origin/dev` üzerine cherry-pick etti.
  - changelog çakışmaları `scratchpad/resolve-both.cjs` ile çözüldü (iki taraf tutulur, satır tabanlı, CRLF uyumlu).
  - Migration `src/backend/VuoApp.Migrator` içinde `dotnet ef migrations add <Ad> --context MigratorDbContext` ve `node tools/strip-migration-designers.mjs` ile üretildi.
  - `verify.sh all` çalıştırıldı, commit amend edildi ve `git push origin HEAD:dev` yapıldı.
- **Commitler:**
  - `be3017b7` fix(demand): talep listesi kolon başlıkları 11 dilde, bilinmeyen durumda liste bozulmaz (`dmd.json`, `demand-status.ts`).
  - `87e78275` P2: bayraklar, sunucuda favoriler (kategori/başlık gruplu, sıralanabilir), ana sayfa ağacı. Migration `20261025230242_UserPreferences`.
  - `f2bb6e20` P4: fiş bildirimleri (oluşturuldu / onay bekliyor / onaylandı / silindi) ve tam katalog tercihler. Migration yok. `inventory:approve` izni eklendi. Bildirim şablonu seeder'ı artık gerçekten çalışıyor. receipt-created webhook artık tetikleniyor.
  - `47e60618` P3: tüm fiş ve belge numaraları tek üreticiden (Kod Üretici + atomik sayaç, en yüksek mevcut numaradan tembel tohumlama, 3 kez yeniden deneme). Sipariş ekranındaki `00000001` hatası düzeltildi.
  - `3ea48866` P7a: planlamada kaynak yükleme ısı haritası, Örme/Dokuma menülerine Sentez karşılıkları, fişe `ProductionModuleType`. Migration `20261025231846_ReceiptProductionModuleType`.
  - `71cb7bfe` P1:
    - yazılabilir lookup ve kaldırılabilir ön filtre çipi;
    - satır vergisi listeden seçilir (ÖTV/ÖİV), kart ek vergileri otomatik eklenir;
    - KDV combo vergi listesinden beslenir;
    - fiş tipine göre alan düzeni;
    - tam ekran.
    - Migration `20261025232332_ReceiptTaxListAndTypeLayout`.
  - `ac9fb890` P5: BI pivot backend, rapor tasarımcısı, stok raporu modalda. Migration `20261025232640_ReportingModule` (yeni şema `reporting`).
- **Komutlar:**
  ```bash
  git fetch "X:/GitHub/vuo-app/Saas_erp" <worktree-branch> && git cherry-pick FETCH_HEAD
  node ../resolve-both.cjs src/frontend/src/features/changelog/changelog.data.ts
  cd src/backend/VuoApp.Migrator && ConnectionStrings__DefaultConnection="Host=localhost;Database=x;Username=x;Password=x" dotnet ef migrations add <Ad> --project . --context MigratorDbContext
  node tools/strip-migration-designers.mjs && bash tools/verify.sh all
  bash scratchpad/deploy-dev.sh 1.0.2.<n>
  ```
- **Sonuç:**
  - Her birleştirmede `verify.sh all` rc=0. Son durum: backend 5631 test geçti, frontend 2157 test geçti.
  - DEV 1.0.2.1059 (K+P2+P4) ve 1.0.2.1060 (+P1, P3, P5, P7a) yayında, sağlık 200.
  - DEV duman testi (`scratchpad/smoke-1060.cjs`): tercihler, bildirim kataloğu, numara önizlemesi, alan düzeni, makine yükü, analitik kaynaklar, 4 kaynakta pivot ve rapor tanımları 200 döndü. DEV DB boş (sıfırlanmış).

### 3. Kalan paketler, güvenlik ve 1061
- **Commitler:**
  - `77845a07` P8: yönetici paneli `/admin-panel`, admin-summary uç noktası, duyurular sayfası, PrivateRoute düzeltmesi.
  - `327c4b1c` P7b: Fason Takip, Kümülatif, Parti Tarihçesi (Örme + Dokuma). Migration `20261025235107_InventoryReceiptTypeDateIndex`. Elle düzenlendi: `CREATE INDEX CONCURRENTLY IF NOT EXISTS ... WHERE "IsDeleted" = false`, `suppressTransaction: true`.
  - `1f300637` P6: talep, teklif, sipariş ve fatura oluşturma ekranları ortak `DocumentWorkspaceShell` üzerinde. Talep toplamları sunucuda hesaplanıyor. `IInventoryReferenceValidator` eklendi.
  - `674f44fd` güvenlik post-check: fason raporları `production:read` yanında `inventory:read` de istiyor (`SubcontractReportSupport.EnsureReceiptReadAsync`, `SubcontractReportsAccessTests`).
- **Sonuç:** DEV 1.0.2.1061 yayında, sağlık 200, duman testi OK.

### 4. UX post-check ve 1062
- **Neden:** ekran değişen her iş uygulama sonrası UX kontrolünden geçer.
- **Ortam:** yerel ortam açılmadı. Paylaşımlı dev primary'si (`100.109.159.58:15433`) zaman aşımı veriyordu, PgBouncer `:9999` açıktı. Migration'sız açılan yerel API'de yeni tablolar olmayacaktı. Bu yüzden kontrol, migration'ları uygulanmış DEV 1061 (app-dev.vuo.app) üzerinde ux-reviewer ile yapıldı.
- **Sonuç:** PASS-WITH-FINDINGS, engelleyici yok. Sekiz ekran grubunun hepsi çalışıyor. Konsolda hata, ağda 4xx/5xx yok. İngilizce kontrolü temiz.
- **Düzeltilenler (`6125384d`):**
  - stok kartı seçim penceresinde silme düğmesi yok (`inventory_item.page.tsx`, `canDelete={isModal ? () => false : undefined}`);
  - fason raporlarında cari filtresi düz `<select>` (pageSize=1000) yerine lookup (`customer_filter_field.tsx`);
  - stok raporu sayıları dile göre biçimleniyor (`ColumnBuilder.addNumberColumn`); "Free (Kullanılabilir)" artık "Kullanılabilir";
  - boş listede sayfa bilgisi "0 - 0" ve "1 / 1" (`pagination-range.ts`);
  - `/finance/invoice/create` açıkken menüde Finans seçili (`two-panel.utils.ts`, istisna yalnız rapor/analitik modülünden gelişte);
  - fatura ekranında "Vazgeç" yerine "İptal";
  - Kaynak Yükleme tablosu tam genişlikte.
- **Komutlar:** `bash tools/verify.sh all` (rc=0, frontend 2230 test), ardından `git push origin HEAD:dev` ve `bash scratchpad/deploy-dev.sh 1.0.2.1062`. İlk denemede Docker Desktop kapalıydı; açılınca deploy geçti.
- **Sonuç:** DEV 1.0.2.1062 yayında, sağlık 200, duman testi OK.

## Kararlar
- PlannedDuration "saat" kabul edildi (planlayıcı 7 gün için 7×24 gönderiyor).
- Bilinmeyen vergi kodu satırda reddedilir (`line_tax_unsupported`); sessizce kaybolmaz.
- Fatura numaralarında boşluk olabilir; e-Fatura için boşluksuz sıra gerekirse ayrı tasarım yapılacak.

## Açık kalanlar / sonraki adım
- Fiş çalışma alanı açılırken tüm stok kartlarını (`pageSize=100000`) çekiyor. Bu önceden de vardı; ekranın sunucu taraflı aramaya taşınması ayrı iş.
- Oluşturma ekranlarında fiş çalışma alanıyla tam eşlik yok: "Alanları düzenle" yok, sekme seti farklı, faturada satır lookup'ı tek kolon. Ekler için backend yok.
- P7b: İplik Kullanım Kontrol ve Müşteri/Ham Depo raporları ertelendi. Kalan/Fire formülleri Sentez'den aynen alındı; İade'yi tutarsız sayıyor. Yeni menü grubu `production-module-sub-items.ts` içinde yok.
- KDV satırda hâlâ yüzde kutusu (ÖTV/ÖİV listeden). Zorunlu alan işareti yok. a11y eksikleri (tema düğmesi etiketi, DialogContent açıklaması).
- Override ile `inventory:edit` almış kullanıcılar `inventory:approve` almıyor; outbox tekrarında çift bildirim olabilir.
