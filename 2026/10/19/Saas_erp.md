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
