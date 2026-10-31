# Saas_erp — 2026-10-31

## Bağlam
2026-10-30 oturumu gece yarısını geçti; hedef `/goal backlog u tamamlayalim` sürüyor. Önceki gün: `2026/10/30/Saas_erp.md`.

## Yapılanlar

### 1. Kurul turu (2026-10-30 akşam): E9 S3, E4 S4, E6 S3, E3 S2
- Dosya: scratchpad `board-round-1030b.md` (CTO/Skeptic/DBA/PO + DECISION).
- E9 S3 ve E4 S4 onaylı (koşullu). E6 S3 BLOCK: öneri hiç oluşturulmayan `ProductionOrderBatchStepExecution`'a dayanıyordu (gerçek kayıt `JobTransaction`);
  kimyasal 3062'ye `SourceRefId = ProductionOrderId` yazmak emrin asıl sarfını "AlreadyPosted" yapardı → S3a/S3b/S4 yeniden öneri. E3 S2 → S2a/S2b/S2c bölündü.

### 2. E8 S1a — beklenen tedarik bağı temeli
- `inventory.SupplyPeg` (13 CHECK, `UX_SupplyPeg_Key` NULLS NOT DISTINCT, CONCURRENTLY indeksler), `PurchaseOrderLinesChangedEvent` → otomatik uzlaştırma,
  Orders portu `IPurchaseLineSupplyQuery` (tek canlı satır tanımı `PurchaseLineLiveness`), kilit ③→③b→④ sıralı; 55P03 → 409 `inventory.supply_peg.busy`;
  geriye dönük uzlaştırma `maxHeaders` + imleç. Bayrak `inventory.supplyPeg.enabled` yalnız owner/admin (sunucuda uygulanır).
- Post-review: DBA + güvenlik koşullu onay → uygulandı. HTTP katmanında tenant'lar arası test yapılamadı (test host'u InMemory/sahte tenant).
- **Commit:** `c7858afa`. **DEV:** 1.0.2.1127 (2 migration, 6 indeks geçerli).
- **Olay:** `wtdeploy` çalışma klasöründe 5421 izlenen dosya silinmiş bulundu (nedeni bilinmiyor) → `git checkout -- .` ile geri yüklendi, yayın tekrarlandı.

### 3. E9 S3 — fason hizmet faturası
- 4018 + `OrderReceiptId` → 5203 (port: tip/cari/iptal), profil TEMEL/TICARI; `InvoiceLine.SourceReceiptItemId` (3006 satırı);
  Faturalanacak = 3006 − 3065 − fatura satırları (taslak dahil, tek gruplu sorgu); hizmet kartı zorunlu (kumaş kartı kopyalanmaz); fazla faturalama uyarı.
- Post-review: DBA (`RESET lock_timeout`) + güvenlik (sekme `finance:read` ile) — ben uyguladım.
- **Commit:** `86ae6f9e`. **DEV:** 1.0.2.1128.

### 4. E4 S4 — top stok durumu / kalite durumu ayrımı
- StockState okumada türetilir; veri migration'ı yalnız `scrapped` → lot Ret (olaysız Serbest lotlar); Down yalnız kendi olaylarını geri alır;
  eski `status` parametresi eşlenir; yazmada 400; top uçlarına `inventory` yetkisi (önceden viewer top açabiliyordu); aralık doğrulaması.
- **Commit:** `1456a0c2`. **DEV:** 1.0.2.1128 (DEV'de hurda top yok → no-op).

### 5. E3 S2a — Ham (boyasız) sistem varyantı
- **Neden:** Karar: ham kumaş ayrı kart değil, aynı ürünün HAM varyantıdır (E3).
- **Ne yapıldı:**
  - `Variant`/`VariantGroup` tablolarına `SystemKey` alanı eklendi.
  - Migration her tenant için seed yapar:
    - Tek Renk/Color grubu varsa onu benimser; yoksa Renk grubunu, "Standart" kartını ve HAM'ı oluşturur.
    - Birden fazla aday grup varsa hiçbir şey oluşturmaz, NOTICE yazar ve Ayarlar'da seçim ipucu gösterilir.
  - Yeni tenant: `OnTenantCreated_SeedHamVariant` olay işleyicisi.
  - HAM silinemez, yeniden adlandırılamaz ve pasiflenemez:
    - Handler kontrolü, DB tetikleyicisi (`WHEN OLD.SystemKey IS NOT NULL`) ve kart koruması.
    - `ExceptionHandlingMiddleware`, 23514 `system_protected` hatasını 409'a çevirir.
  - Varyantlı kumaş kartında HAM zorunludur; kural yalnız varyantlar değişince çalışır, eski kartlar bloklanmaz.
- **Migration'lar:** `20261030233125_Sprint_E3S2a_HamSystemKey` ve `..._HamSystemKeyIndexes` (CONCURRENTLY, unique partial).
- **Doğrulama:**
  - BE 7540, FE 3073 test yeşil; `HamSystemKeyMigrationTests` gerçek PG'de 14/14.
  - DBA post-review şartları ve Security PASS (2 Low) uygulandı.
- **Commit:** `61ce375a`. **DEV:** 1.0.2.1129 — 18 tenantta HAM oluştu.

### 6. E12 — QA Excel'inin "Riskler ve Eksikler" sayfası backlog'a
- **Neden:** Kullanıcı isteği: `docs/qa/VuoApp_Test_Senaryolari.xlsx` dosyasındaki riskler ve eksikler backlog'a eklenip bitirilsin.
- **Ne yapıldı:**
  - 37 satır koda karşı doğrulandı: 10 madde kesin, 2 madde kısmi.
  - Kök nedenler:
    - Teklif/sipariş/fatura `ForexCalculator`'ı kullanıyor; dip indirim KDV matrahından düşmüyor, tevkifat ödenecekten düşmüyor.
    - Teklif→sipariş düğmesi yanlış URL'ye gidiyor (404).
    - Sipariş satırında teslim/fatura miktarı kalıcı tutulmuyor.
  - Backlog'a E12 eklendi (S1–S12).
- **Kullanıcı kararları:**
  - Teslim takibi otomatik olacak; sipariş %100 teslimde kapanır.
  - Fatura irsaliyeden ve siparişten kesilebilecek; kısmi fatura olacak, mükerrer fatura engellenecek.
  - İrsaliyede risk kontrolü siparişteki ayara göre yapılacak.
  - Eksiklerin hepsi yapılacak.
- **Commit:** `9d90826e`.
- **Sonraki:** S1 (KDV/tevkifat) + S2 (teklif→sipariş) + S8 (yer tutucu sayfalar) kurulda (cto/skeptic/po).

### 7. E6 S3a — kimyasal sarf idempotent + Kimyasal sarf düğmesi
- **Neden:** Kimyasal sarf yeniden gönderilince (çift tıklama veya yavaş ağ) stoktan iki kez düşüyordu; ayrıca diyalog hiçbir yerden açılmıyordu.
- **Ne yapıldı:**
  - `ConsumeChemicalsCommand.RequestId` eklendi. Bu id ile kind-3 `ProductionConsumptionPosting` satırı yazılıyor (`chem:`+RequestId); 3062 fişinin `SourceRefId` alanı null kalıyor.
  - Advisory lock alınıyor (lock_timeout 10s, 55P03 → 409 `request_in_progress`). 23505 yarışı yaşanırsa kazanan kayıt dönüyor.
  - Aynı RequestId farklı bir emir için gelirse reddediliyor.
  - CHECK kısıtı 1..4'e genişletildi: önce NOT VALID eklendi, ayrı bir migration'da VALIDATE edildi.
  - `RollOutputReceiptGuard` kind 3'ü muaf tutuyor; kind 2 ve 4 kilitli kalıyor.
  - Boyahane emir detayına `production:update` yetkisiyle görünen bir düğme eklendi. Miktar değişince yeni RequestId üretiliyor.
- **Doğrulama:** BE 7495 ve FE 3070 test yeşil; PG testleri 15/15. DBA ve Security post-review şartları uygulandı.
- **Commit:** `cac1d7c6`. **DEV:** 1.0.2.1130 (CHECK VALID).

### 8. Kullanıcı kararları (öğle)
- E12 S8: yer tutucu sayfalar gizlenmeyecek, geliştirilecek. Plan: S8a hazır ekranları bağla, S8b eksik backend'i yaz, S8c Konfeksiyon sayfalarını yap.
- Seri panelinde tarih formatı tarayıcı dilinden alınacak.
- Bozuk `_wt-idem` worktree'si kaldırıldı (`git worktree remove --force`; HEAD e49f2533 zaten dev'deydi).
- E12 S1/S2 kurulu: Skeptic BLOCK, CTO ve PO şartlı onay verdi. Gerekçe: e-Fatura UBL matrahı satır net tutarından hesaplanıyor; `IsVatBaseStale` dip indirimli faturayı reddederdi; tevkifat GL'ye yanlış gidiyor. v2 önerisi hazırlanıyor.

### 9. E3 S2a UX düzeltmesi
- **Neden:** UX post-check BLOCK verdi. Korunan kayıt silinmek istendiğinde doğru toast'un üstüne ham anahtarlı İngilizce bir modal daha açılıyordu.
- **Ne yapıldı:**
  - Ortak `delete-item-modal.tsx` (tüm GenericTable listeleri) artık tek bir hata gösteriyor.
  - Varyant tipi listesine "Sistem" rozeti eklendi; sistem grubunda Sil düğmesi gizli.
  - Seri geçmişinde tarihler tarayıcı diline göre gösteriliyor (kullanıcı kararı).
- **Commit:** `3993c88d`. **DEV:** 1131.

### 10. E2 S4b-1 — dokuma iplik çıkış özeti + boyahane maliyet düzeltmesi
- **Ne yapıldı:**
  - Emir detayına İhtiyaç/Çıkılan/İade/Net/Fark paneli ve rejim rozeti eklendi; "Çıkış yap" düğmesi geldi.
  - Teorik > 0 ve Çıkılan = 0 iken uyarı ve kapatma onayı gösteriliyor.
  - Özet endpoint'i eklendi (yalnız dokuma; modül erişimi kontrol ediliyor).
  - Emre çıkış rejiminde maliyet, canlı RefType 4/5 tüketimi ile fazla çıkışın kart fiyatından hesaplanıyor.
  - Bloklamayan uyarılar eklendi.
  - Bağlı lot satırında RefType 4 kaydı onay anında yazılıyor; eski taslaklar çift tüketmiyor.
  - Fix: tip-1 tahsis maliyeti kalem id ile eşleniyor (boyahane kumaş maliyeti eksik çıkıyordu).
- **Doğrulama:**
  - Testler: BE 7568, FE 3096 yeşil; PG testleri 3/3.
  - Security PASS; Low bulgu uygulandı (dokuma dışı emirde boş dönüyor).
- **Commit:** `36a3e968`. **DEV:** 1132.
- **Not:** `production/reports/actual-cost` endpoint'inde izin kontrolü yok (önceden beri). Ayrı ele alınacak.

### 11. E12 kurulu tur 2 + kullanıcı kararları
- **Kararlar:**
  - D1: GL'de tevkifat işlenecek (alışta 360 alacak, satışta 391 − W).
  - D2: Tevkifatlı e-Fatura şimdi tam yapılacak (satır tevkifat kodu + `WithholdingTaxTotal`; TEVKIFAT tipi yalnız UBL'de türetilecek).
  - D3: Konfeksiyon planlama sürükle-bırak + kapasite ile yapılacak.
  - D4: SEPA pain.001.001.03 yapılacak.
- **Kurul:**
  - Şartlı GO: S1a, S1b (DebitNote dahil), S1c, S2, S8a, S8b CRUD, S8c stok kontrol + Numune.
  - Ayrı tasarım + kurul bekleyenler: SEPA (şema eksikleri, cari etkisi) ve Konfeksiyon Order Planlama.
- **Kural değişikliği:** Satır KDV'si v_i = Round2(B_i·r); grup kalanı yok (e-Fatura `IsVatBaseStale` uyumu için).
- **Uygulamada:** S8a (wte7), S1a (wte9), E8 S1b-1 (wte8).

### 12. E8 S1b-1 — beklenen tedarik bağı: üretim emri
- **Neden:** Konfeksiyon kumaşının yaklaşık %30'u devam eden üretimden karşılanıyor (karar E8).
- **Ne yapıldı:**
  - Konfeksiyon Tedarik ekranından bir ihtiyaç, açık bir üretim emrine elle bağlanabiliyor ya da bağ kaldırılabiliyor. Yetki: owner/admin ve `inventory.supplyPeg.enabled` bayrağı (varsayılan kapalı).
  - Bağlanacak emir seçilirken aday emirler durumları ve kalan miktarlarıyla listeleniyor.
  - Üretilen miktar bağlara (NeedDate, Id) sırasıyla dağıtılıyor.
  - Emir tamamlanınca bağ duruyor; emir iptal edilir ya da silinirse bağ iptal oluyor ve iptal nedeni görünüyor.
  - `ProductionOrderSupplyChangedEvent` → `OnProductionOrderSupplyChanged_ReconcilePegs`.
  - ③b kilit anahtarı artık gerçek `NeedSourceType` ile kuruluyor.
  - Null varyant ve null tarih için Postgres testi eklendi.
- **Doğrulama:** Backend 7614 ve frontend 3109 test yeşil; SupplyPeg Postgres testleri 52/52. DBA şartlı onay verdi, Security PASS.
- **Commit:** `202f2551`. **DEV:** 1133.
- **S1b-2'ye devredilenler:**
  - Aday sorgusu için kısmi indeks (CONCURRENTLY).
  - Bağ yeniden açılırken Σ ≤ Planned kontrolü.
  - Manuel kind-2 bağ ve diğer bağ şekilleri. S1b-2 wte8'de başladı.

### 13. E12 S8a — İzin tipleri, Bordro dönemleri, Kalite spesifikasyonları [16:46]
- **Ne yapıldı:**
  - HRM'de `leave-types` ve `payroll-periods` için CRUD eklendi. Dönem kapatma tek yönlü; kapanan dönem salt okunur.
  - Uçlarda `RequirePermission("hrm", read/create/edit/delete/approve)` var. Varsayılan yetki satırları her açılışta seed ediliyor.
  - Kalite spesifikasyonu listesi ve soft delete eklendi. Migration'lar: `20261031094017_..QualitySpecSoftDelete` ve `20261031130331_..QualitySpecIndex` (CONCURRENTLY).
  - İzin tipi formundaki PUT'un veri sıfırlama hatası düzeltildi.
  - Yer tutucu sayfalar menüden gizlendi; kontrat testi eklendi.
  - Eşzamanlı aynı kod girişi (23505) artık 409 döndürüyor.
  - Teknik borç kaydı: TD-024.
- **Doğrulama:**
  - Testler: BE 7643, FE 3125 geçti.
  - DBA şartlı onay verdi.
  - Security, izinler olmadığı için BLOCK verdi; izinler eklendi.
- **Commit:** `7c354b21`. DEV'e deploy edilmedi (yeni akış, aşağıda).

### 14. Yerel kontrol ortamı (kullanıcı isteği) [16:35–16:54]
- **Neden:** Kullanıcı "kontrolleri localden yap, her seferinde docker oluşturma" dedi.
- **Ne yapıldı:**
  - `scratchpad/wtlocal` worktree'si açıldı. `appsettings.Development.json` ve `.env.development.local` ana ağaçtan kopyalandı; bu dosyalar git'e girmiyor. CORS'a `vuo.local:3131` eklendi.
  - `local-up.sh [ref]` yazıldı:
    - Yalnız origin/dev'deki commit'leri çalıştırıyor; açılışta migration'lar ortak DEV DB'ye uygulandığı için başka ref'leri reddediyor.
    - API'yi `:5240`'ta `dotnet run` ile, web'i `:3131`'de Vite ile başlatıyor (`__VITE_ADDITIONAL_SERVER_ALLOWED_HOSTS=vuo.local`).
    - `/health/live` ve web 200 dönene kadar bekliyor.
  - `local-down.sh` portları kapatıyor.
  - hosts dosyasına `127.0.0.1 vuo.local` eklemek admin yetkisi istiyor; kullanıcının eklemesi gerekiyor.
- **Sonuç:** 16:54'te READY. S8a'nın 2 migration'ı DEV DB'ye uygulandı.
- **Kararlar:**
  - Her dilimde docker build/deploy yapılmayacak; DEV deploy toplu yapılacak.
  - Durum mesajlarına `[HH:MM]` zaman damgası eklenecek.

### 15. E8 S1b-2 [17:44] — tedarik bağı genişletildi
- **Ne yapıldı:**
  - Üretim emri artık tip 1, 2 ve 3 ihtiyaçlara bağlanabiliyor; satınalma satırı da üretim ihtiyaçlarına bağlanabiliyor.
  - Orders güncellemesinde, manuel bağı olan satırın RequirementOrderId'si değiştirilirse 409 dönüyor.
  - Yeni indeks: `IX_ProductionOrder_OpenOutput` (CONCURRENTLY; CREATE sırasında lock_timeout=0).
  - Runbook: `e8-supply-peg-flag-off.md`.
- **Kontrol:** DBA şartlı onay verdi, Security PASS. Şartlar uygulandı.
- **Commit:** `e880d219`.

### 16. E12 S8a UX düzeltmeleri + Çıkış yap [17:51 / 20:28 / 21:22]
- **Ne yapıldı:**
  - `aa014bcc`:
    - Spesifikasyon silme işlemine onay adımı ve arama eklendi.
    - İzin tipi etiketleri ve devir kolonları düzeltildi.
    - Bordro diyaloglarına açıklama metni eklendi.
    - `use-production-order-prefill` hook'u eklendi.
  - `0c8c3183`: Yerel E2E testinde ön doldurmanın çalışmadığı görüldü. İki kök neden vardı:
    - setRows updater'ı saf değildi; StrictMode'da ikinci çalıştırmada emir kayboluyordu.
    - Boş giriş satırı emir bilgisini almıyordu.
    - Hook testleri artık StrictMode altında çalışıyor.
  - `e0fb1ff1`: Yerel E2E testinde ikinci bir hata bulundu. Satırda "Üretim emri temizle" yalnızca görünen numarayı siliyordu, `productionOrderId` kalıyordu ve satır kayıtta yine emre bağlı gidiyordu. Kolona `clearFields: ['productionOrderId']` eklendi.
- **Doğrulama:** Yerel UX kontrolü [20:52]: İzin tipleri, Spesifikasyonlar ve mobil/koyu görünüm notlarla geçti. UXTEST kayıtları silindi.

### 17. Arda ile iş bölümü [18:40] (kullanıcı kararı)
- **Durum:** Arda aynı QA Excel'in 1.x Satınalma bölümünü yapıyor:
  - da6bbb62: A1 dip indirim KDV matrahı, A2 tevkifat ödenecek.
  - 6f984d02: teklif→sipariş.
  - 21c326ef: satınalma kısmen teslim + sipariş adresi.
- **Karar:** Satınalma Arda'da; geri kalan bizde.
- **Sonuç:**
  - Bizim E12 S1a iptal edildi; aynı kuralın ikinci bir uygulaması olmasın. Değişiklikler stash `e12s1a-superseded-by-da6bbb62` ve scratchpad'deki patch/tar dosyalarında.
  - Arda'ya öneriler: ortak golden HC dosyası, HC-12, C7 diyaloğu.

### 18. E12 S8c [21:43] — Konfeksiyon Stok Kontrolleri + Numune listesi
- **Ne yapıldı:**
  - Sipariş bazında kumaş ve aksesuar için ihtiyaç / eldeki / tahsisli / siparişte / eksik görünümü. Kaynaksız kolonlarda "—" gösteriliyor.
  - Uç noktası: `GET inventory/mrp/stock-control`.
  - Orders modülüne `IApparelOrderModelQuery` portu eklendi.
  - Numune listesi menüde görünüyor.
- **Kontrol:** Security PASS.
- **Commit:** `7925e87f`.
- **Uygulamada:** E12 S1c (wte9), S8b (wte7), S2 (wte8).

## Kararlar
- E6 S3/S4 ve E3 S2b/S2c yeni öneri gerektiriyor; E2 S4b, E8 S1b, E6 S3b+S4 önerileri Plan ajanlarında.

## Açık kalanlar / sonraki adım
- UX kontrolü E9 S3 + E4 S4 (DEV 1128) ve E3 S2a (1129). E6 S3a (wte8) post-review düzeltmeleri, E2 S4b-1 (wte9) uygulanıyor.
- E12 S1/S2/S8 kurulu → uygulama; ardından S3→S7, S9–S12.
- Öneri → kurul: E2 S4b (+Örme/Boyahane), E8 S1b, E6 S3a/S3b/S4.
- Sonra: E3 S2b/S2c, E5 S2a-2 (~11-01) ve S2b-S5, E8 S2b-S4b, E7 S2 (paralel operasyon tasarımı), E2 S3 (transfer tasarım dokümanı), E10, H12.
