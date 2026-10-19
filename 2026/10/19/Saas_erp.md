# Saas_erp — 2026-10-19

## Bağlam
18 Ekim gece: kullanıcı yereli açtırıp birlikte çalışmak istedi. API ve UI yerelde açıldı (`dotnet run --project src/backend/VuoApp.Api`, `npm run dev`, dal `feat/iki-panelli-menu`), sonra stok fişi ekranı için 12 maddelik bir liste verdi.

Kurul (cto, skeptic, dba, product-owner) dördü de APPROVE-WITH-CONDITIONS verdi; öneri dosyası scratchpad'de `fis-oneri.md`.

Skeptic'in uyarısı üzerine iş dört gruba bölündü:
- **A:** yalnız ekran maddeleri (1, 2, 3, 4, 7, 8; 5'in güvenli kısmı).
- **B:** stok kaydını değiştiren düzeltmeler (satır ItemType, transfer fişinin çift yön kaydı).
- **C:** dip indirim/masraf saklama ve migration.
- **D:** TCMB kurunun otomatik gelmesi.

**Madde 11 (`/saas/modules/enabled` 500):** kod hatası değil. Ortak sunucu 100.109.159.58'e ping/SSH/DB/Redis erişimi yoktu; tüm sorgular 21 sn timeout verdi. Daha sonra sunucu kendiliğinden geri geldi.

## Yapılanlar (dev)

### 1. Liste Yeni butonu — `868077d7`
- WorkList'teki Yeni butonu artık solid success (yeşil) ve önünde Plus ikonu var; PageTitle'a `icon` prop'u eklendi.
- İşlevsiz tip rozeti (`badge` prop'u) WorkList'ten ve 5 liste sayfasından silindi: fiş, sipariş, teklif, talep, fatura.
- Test: `work-list.contract.test.tsx`. Not: `src/test/setup.tsx` `@/common/components` modülünü global mock'luyor; bu yüzden test dosyası kendi PageTitle spy'ını mock'luyor.

### 2. Skeleton ve kayıtlı kur — `c6992d95`
- `components/receipt-workspace-skeleton.tsx`:
  - `isReceiptWorkspaceReady`: kayıtlı fişte `hydrated` + `system_parameters` yüklenene kadar skeleton gösterilir.
  - Hydration effect'i `setHydrated(true)` çağırır; satırsız fişte de çağrılır.
  - `receiptLoadFailed` olursa skeleton gösterilmez.
- `use-receipt-forex.ts`:
  - Yeni `shouldAutoFetchForex`: kayıtlı fişte `currencyId|tarih` kayıtlı anahtarla aynı kaldıkça kur yeniden çekilmez. Eskiden açılışta günün kuru kayıtlı kurun üzerine yazıyordu.
  - Hook'a `enabled` ve `savedKey` parametreleri eklendi.

### 3. Başlık düzeni ve Fiş Tipini Değiştir — `0f6d2066`
- Başlık satırları: Belge (Fiş No / Belge No / Fiş Tarihi / Termin) | Cari / Adres / Yetkili | Depo + Döviz + Kur | Açıklama + Seçenekler.
- Transferde Çıkış Depo, Genel sekmesinden başlığa taşındı (Çıkış → Giriş).
- `components/receipt-type-change.tsx`:
  - `ReceiptTypeTitle`: tip adı + yön rozeti + değiştirme dialog'u.
  - `canChangeReceiptType` ve `receiptTypeChangeOptions`: yeni fişte tüm tipler; kayıtlı fişte yalnız aynı yöndekiler; transfer hiç değişmez.
- Backend:
  - `ReceiptTypeChangeGuard`, UpdateReceipt içinde çalışır: onaylı/kilitli/kapalı/iptal fişte Conflict; yön farklıysa veya transferse Validation. Hata kodu `inventory.receipt.type_change_not_allowed`.
  - Fiş no tekilliği artık yeni tipe göre kontrol ediliyor.
  - 6 unit test eklendi.

### 4. Alt satır kolonları ve 2. miktar — `5b37cb9b`
- Yeni `receipt-dynamic-columns.ts` / `applyRowDrivenColumns`, `gridColumns` memo'su üzerinden grid'e verilir.
- Alt satırlarda (50/51/52/100/101) yalnız lineNo, description, vatRate, amount görünür. `amount` kolonunun başlığı "Tutar"; yalnız alt satır varken görünür.
- İkincil miktar ve birim: kart ikincil birimliyse, kumaşsa veya satırda kayıtlı değer varsa gösterilir.
- Kumaş En/Gramaj: kart kumaşsa (inventoryDetails.fabric) veya satırda değer varsa gösterilir.
- Bu kolonları gerektiren satır yoksa kolon `hidden`; gerektirenler arasında hücre bazında `cellHiddenFor` kullanılır.

### 5. Satır tipleri — `038715f4`
- `buildInventoryReceiptRowTypes({ headerRows: false })`: workspace'te Fason ile Dip İndirim/Masraf seçenekleri artık yok.
- Bu satırlar zaten hiç kaydedilmiyordu (payload'da itemType sabit 1 gidiyordu).

## Doğrulama
- Playwright (scratchpad `pw/fis*.cjs`), yerel ortam + ortak DB:
  - Liste butonu yeşil.
  - Transfer başlığı ve tip değiştirme dialog'u ekran görüntüsüyle kontrol edildi.
  - Grid'de boş kumaş/2. miktar kolonları gizli.
- Testler:
  - Frontend inventory + receipt-detail: 216 geçti; typecheck temiz.
  - Backend "Receipt" filtreli testler: 604 geçti.

## Kararlar
- Gruplar ayrı ayrı commit edildi. B/C/D grupları stok kaydını etkilediği için kullanıcı kararı bekliyor:
  1. Madde 5'in yorumu.
  2. Sabit kıymet satırı stok kaydı yazsın mı?
  3. Onaylı eski fişler eski kuralla mı kalsın?
  4. Alt satırda Oran (%) olsun mu?
  5. Kur alış mı satış mı?
- TCMB "çek" butonu D grubuna kadar ekranda kalıyor.

## Açık kalanlar
- B: transfer fişinde çift yön kaydı (mapper + posting builder'a Transfer case), satır ItemType'ın kayda gerçek değerle gitmesi ve sunucuda sınıf kontrolü.
- C: dip indirim/masraf sekmesi + `InventoryReceiptDiscount` alanları (Kind/Description/CalcType/VatRate/SortOrder) + migration.
- D: Hangfire ile hafta içi 15:45'te TCMB kuru; buton kaldırılacak; kurun tarihi gösterilecek.
- Faz 2: teklif, sipariş, talep ve fatura ekranları.
- UX ve güvenlik post-check'leri çalışıyor.

### 6. UX post-check düzeltmeleri — `fdd39787`
- **Neden:** ux-reviewer post-check sonucu PASS-WITH-NOTES; notlardaki eksikler kapatıldı. (Güvenlik post-check'i tip değiştirme guard'ı için PASS verdi.)
- **Ne yapıldı:**
  - Döviz Cinsi SelectTrigger `size="sm"` ile h-8 yapıldı.
  - Başlık alanlarına `id`/`htmlFor` bağları eklendi.
  - Tip değiştirme dialog'unda liste Giriş/Çıkış/Transfer/Düzeltme gruplarına ayrıldı ve mevcut tip gösteriliyor.
  - Başlık text-xl font-semibold yapıldı; butona ikon eklendi.
- **Kapsam dışı bırakılanlar:**
  - Grid'deki Birim/Depo hücrelerinin 36px yüksekliği eskiden beri var; ortak grid işi.
  - Dialog'daki "Close" etiketi ortak bileşenden geliyor.
  - Onaylı fişte "Güncelle" butonunun aktif kalması eski davranış.

### 7. Dip İndirim ve Masraflar sekmesi — `8e56761a`
- **Neden:** Kullanıcı "ekranda indirimler sekmesi yok" dedi; C grubu öne alındı.
- **Ne yapıldı:**
  - **Migration** `20261018213313_InventoryReceiptDiscount_HeaderCharges`:
    - Yalnız ekleme: Description varchar(500), CalcType int default 0, VatRate numeric(18,6) default 0, SortOrder int default 0.
    - `IX_InventoryReceiptDiscount_TenantId_ReceiptId` index'i.
    - Down adımı var.
    - Yerel API açılışta bunu ortak dev DB'ye uyguladı ("1 bekleyen migration uygulanıyor").
  - **`ReceiptHeaderChargeSync`:**
    - Dip satırları (ReceiptItemId=null; ItemType 100 = indirim, 101 = masraf) Create/Update'te silinip yeniden yazılır.
    - İki liste de null gelirse satırlara dokunulmaz.
    - `LoadAsync`, GetReceiptById'de `HeaderCharges` olarak döner.
  - **FE:**
    - `receipt-header-charges.ts`: `toHeaderChargePayload` (oran → CalcType 0, tutar → 1) ve `fromHeaderChargeResults`.
    - `components/receipt-header-charges-tab.tsx`: Tür, Açıklama, Oran, Tutar, KDV (yalnız masrafta), sil; altta sunucunun hesapladığı toplamlar.
    - Sekme state'i fiş yüklenince doluyor.
    - Payload, preview-totals isteğine ve "kaydedilmemiş değişiklik" kontrolüne bağlandı.
- **Test:**
  - Backend: 5 yeni test (sıralı saklama, iki kez kayıtta çoğalmama, boş liste siler, null liste korur, GetById döner). Receipt filtreli 609 test geçti.
  - FE: 6 yeni test; inventory testleri 198 geçti.
  - Playwright: kayıtlı fişte sekmeden %10 indirim ve 250 TL + %20 KDV masraf eklendi. Preview isteği doğru payload'ı gönderdi; dönen toplamlar: masraf 250, genel toplam 300. Kaydetme ekrandan denenmedi; ortak DB'ye test verisi yazılmadı.
- **Açık kalan:** CloneReceipt dip satırları kopyalamıyor.

### 8. Menü "bozuldu"
- **Neden:** Fiş işlerini yaparken yerel çalışma kopyası `dev`'e geçirilmişti. İki panelli menü yalnız `feat/iki-panelli-menu` dalında olduğu için kullanıcı eski menüyü gördü.
- **Ne yapıldı:** `dev` menü dalına merge edildi (`037b29b4`) ve yerel kopya menü dalına alındı. Vite dev server çalışma ağacından servis ettiği için başka bir şey gerekmedi.
- **Kural:** Bu oturumda yereli kullanıcıyla birlikte kullanırken menü dalında kal. dev'e iş cherry-pick ile gider, sonra dev menü dalına merge edilir.

### 9. Satır indirim/masraf/ÖTV paneli — `fc9b784c` (menü), `026a52ab` (dev)
- **Kullanıcının isteği:** "Satır indirimini ayrı eklemek lazım, gridden bağımsız ama satırın altında. Satır indirimini hesaplamıyor; dip indirimle ikisi de hesaplanmalı."
- **Hata:** `buildPreviewItems`/`pickPair`, alt satır toplamını yalnız discountAmount elle düzenlenmişse ekliyordu. Kayıt `own + subSum` gönderiyordu; use-receipt-totals ise sunucu sonucunu aynı alana geri yazıyordu, bu da çift sayım riski demekti. Ayrıntılar da hiç saklanmıyordu.
- **Kurul:** cto + skeptic APPROVE-WITH-CONDITIONS. Öneri metni scratchpad'de `satir-indirim-oneri.md`.
- **Backend:**
  - `ReceiptTotalCalculator`'a `ReceiptItemCalculationInput.Charges` (`LineChargeInput`: Kind 50/51/52, Rate, Amount, CalcType) eklendi.
  - Charges null değilse hesap yalnız bu satırlardan yapılır: indirim sırayla kalan tutara, masraf satır tutarına, ÖTV indirimli tutara uygulanır.
  - Tek hesap yeri burası; preview-totals ve kayıt aynı kodu kullanır.
  - `LineChargeCommand`, CreateReceiptItemCommand ve PreviewReceiptItemInput'a eklendi.
  - `ReceiptLineChargeSync`: InventoryReceiptDiscount'a ReceiptItemId ile yazar. Hiçbir kalemde Charges yoksa satırlara dokunulmaz; varsa fişin tüm satır kayıtları silinip yeniden yazılır, böylece silinen kalemlerin kayıtları da temizlenir. Dip satırlarına dokunmaz.
  - GetReceiptById `items[].charges` döner. Migration gerekmedi: tablo ve kolonlar 7. maddede eklenmişti.
- **Frontend:**
  - Grid'e opsiyonel `renderRowFooter` eklendi (detail satırın altında tam genişlik `<tr>`, sticky-left); test yazıldı.
  - Fiş ekranında `subRows:false` ile grid içi İndirim/Masraf/Vergi alt satırları kalktı.
  - İndirim/masraf/ÖTV oran ve tutar kolonları salt okunur oldu (yalnız sonucu gösteriyor).
  - `LineChargesPanel`, aktif satırın veya indirimi olan satırın altında açılıyor.
  - `receipt-line-charges.ts`: payload üretimi ve yüklenen veriden panel satırı kurma. Eski kalemlerde kayıtlı TUTARLARDAN tek satır kuruluyor, orandan değil; skeptic şartı.
  - Satır indirimleri "kaydedilmemiş değişiklik" kontrolüne dahil edildi.
- **Test:**
  - Backend: hesap için 6 test (sıralı indirim, masraf/ÖTV matrahı, boş liste eski alanları yok sayar, null eski davranışı korur, satır + dip birlikte), sync için 4 test. Receipt filtreli 619 test geçti.
  - FE: inventory + receipt-detail 228 test geçti; typecheck temiz.
  - Playwright (kayıt yapılmadan): 750 × 100 = 75.000; satır %10 = 7.500; dip %10 = 6.750; toplam indirim 14.250; genel toplam 60.750.
- **Not:** Eski fişlerde çift sayım nedeniyle şişmiş DiscountAmount varsa o değer olduğu gibi taşınır, düzeltilmez.

### 10. İki panelli menü dev'e birleştirildi
- **Neden:** Kullanıcı "menü geçmemiş dev'e" dedi; menü yalnız `feat/iki-panelli-menu` dalındaydı, DEV ortamında görünmüyordu.
- **Ne yapıldı:** `git checkout dev && git pull --ff-only && git merge feat/iki-panelli-menu` → `934479c6`; typecheck temiz. `src/common` testlerinde 2 kırık (`data-table-search.test.tsx`) — origin/dev'de de kırık, birleştirmeyle ilgisiz. Yenilikler'e "iki panelli menü" maddesi `b94c9970`. Menü dalı dev'e ff ile eşitlendi, ikisi push edildi.
- **Açık:** `data-table-search.test.tsx` 2 test önceden kırık, ayrıca bakılmalı.

### 11. CI derlemesi 33 dk → hızlı; tüm warning/notice temizliği
- **Neden:** Kullanıcı DEV Deploy logunu yapıştırdı (run #103, 33m44s): "tüm warning ve infoları düzelt, 33 dk derleme olmaz".
- **Kök neden (ölçüldü):** logda `VuoApp.Migrator` derlemesi 130.5s → 1689.2s (~26 dk). `src/backend/VuoApp.Migrator/Migrations` = 159 MB; 109 migration'ın her `.Designer.cs`'i ~1.5 MB tam model kopyası (`BuildTargetModel`). Bu yüzden Dockerfile'a OOM önlemleri (`-m:1`, `UseSharedCompilation=false`) eklenmişti → daha da yavaş.
- **Kurul:** cto + skeptic APPROVE-WITH-CONDITIONS (Up/Down/idempotent script önce/sonra aynı; son 3 Designer + snapshot dokunulmaz; ayrı commit'ler; script idempotent + dokümante). security-reviewer (KnownIPNetworks + paketler) PASS-WITH-NOTES.
- **Ne yapıldı:**
  1. `tools/strip-migration-designers.mjs` (yeni): son 3 hariç Designer'larda ilk `modelBuilder.Entity(` ile `#pragma warning restore` arası silinir; öznitelikler + ProductVersion/identity annotation kalır. 159 MB → 8.5 MB. Kural `src/backend/VuoApp.Migrator/CLAUDE.md`'ye yazıldı (her yeni migration sonrası çalıştır; arka arkaya en fazla 2 `migrations remove`).
     ```bash
     cd src/backend/VuoApp.Migrator; export ConnectionStrings__DefaultConnection="Host=localhost;Database=design_only;Username=x;Password=x"
     dotnet ef migrations script --idempotent ... ; dotnet ef migrations script 0 <son> ; dotnet ef migrations script <son> 0   # önce/sonra cmp → AYNI
     node tools/strip-migration-designers.mjs ; dotnet ef migrations has-pending-model-changes ...   # No changes
     ```
     Yerel Migrator derlemesi 6 sn; tüm solution Release --no-incremental 13 sn.
  2. NuGet açıkları: MailKit 4.18.1, OpenTelemetry 1.20, Swashbuckle 10.3.0, Testcontainers 4.16.0; pin Pkcs 10.0.13 (Infrastructure*), MessagePack 2.5.307 (Api). `dotnet list package --vulnerable` temiz.
  3. C# uyarıları 0: OrderReceipt IncludeProperties nameof; GetDemandDashboard `(avgRating ?? 0)` (gerçek null patlaması); CreateScanMovement ToDictionary null anahtar → Guid.Empty (gerçek patlama riski); Program.cs KnownIPNetworks; EmailService eksik SMTP ayarında açık hata; AmiEventPumpTests EnumeratorCancellation.
  4. Ön yüz: barrel döngüsü (page-title/dialog/confirm-dialog-reverse/data-table → doğrudan ui modülleri) → "reexported ... circular chunk" uyarıları bitti; data-table-search 2 kırık test düzeldi. exceljs dinamik import, kullanılmayan moment-timezone kaldırıldı (convertToTRTime Intl + test), vendor manualChunks, signalr PURE onwarn, chunkSizeWarningLimit 1000 (yalnız tembel exceljs). Ana paket 2.0 MB → 380 kB. shadcn/add/drawer/root (kullanılmayan) kaldırıldı, npm audit fix, `overrides.exceljs.uuid ^11.1.1` → 33 açık → 0.
  5. CI: actions/checkout v7, setup-buildx v4, login v4, build-push v7 (Node 24); API Dockerfile'a Identity + Migrator csproj COPY; SPA Dockerfile NPM_CONFIG_UPDATE_NOTIFIER/FUND=false.
- **Doğrulama:** unit 3814 geçti; FE typecheck temiz, vite build 0 uyarı; production preview (port 3131, config.js apiUrl=localhost:5240) giriş + fiş listesi + fiş ekranı konsol hatasız.
- **Commit:** `96f326df` (designer), `73d692a6` (frontend), `dcf60f7e` (ci), `48a6cb91` (backend).
- **Açık:** Dockerfile OOM önlemleri (-m:1 vb.) CI süresi ölçüldükten sonra ayrı commit'te kaldırılacak (CTO koşulu). exceljs'in eski bağımlılıkları (glob7/inflight/rimraf2/fstream/lodash.isequal) npm deprecation uyarısı vermeye devam eder (3. parti). Önceden kırık FE testleri: i18n parity (22 tr-only anahtar), login (jsdom SVG), orders worklist contract.
