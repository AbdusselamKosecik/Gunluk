# sentezservis — 2026-10-11

## Bağlam
Kullanıcı: "servise müşteri siparişi bazlı hafta hafta planlama ekranı getirmemiz lazım;
`X:\Gitlab\mitotr\muftelif\MitoSentezDashbord` için ModfexSentezDashbord yap, aynı şekilde, sentezservis içine."
Mito'da iş emri (`Erp_WorkOrder.UD_MitoTermin`) haftalara sürükleniyordu, ayrıca bir ana dashboard vardı
(açık order KPI, `Erp_WorkOrderProduction` aşama hareketleri, 14 gün teslim).

Kullanıcıya sorulan ve verilen kararlar:
- Birim: **sipariş kalemi** (`Erp_OrderReceiptItem`), sipariş fişi değil.
- Plan nereye: **kendi tablomuz**; "dikim, paketleme, kesim için de planlamalar koyalım" → her kalem üç aşamada ayrı haftaya.
- Kapsam: **planlama + dashboard**.

Keşif (salt okunur, `scratchpad/sorgu.ps1`):
- `Erp_OrderReceipt.UD_Termin` var ama boş (kullanılmadı, kendi tablo kararı). Açık satış siparişi şu an 1 (test).
- Tutar: `Erp_OrderReceiptItem.NetItemTotal` (TL). Mamul: `Erp_Inventory.InventoryCode/InventoryName`.
- `Erp_WorkOrderProduction` dolu süreçler: 167 Kesim (InOut 0, 1039 satır, son 07.10.2026), 56 Print, 74 Sewing, 85 Finish.
  `Erp_Process`'te aynı adla birden çok kayıt var (Kesim 54/122/158/167, Dikim 74/131/162…, Paketleme 138/165…).

## Yapılanlar

### 1. Core: planlama mantığı ve depo
- **Neden:** Mito `PlanningService.BuildWeeks`/`Filter`/`WeekMath` mantığının kalem + aşama karşılığı.
- **Ne yapıldı:**
  - `PlanlamaModelleri.cs`: `PlanAsamasi {Kesim=1,Dikim=2,Paketleme=3}` (JSON'da ad), `PlanKalemi` (Dapper için set'li sınıf),
    `KovaToplami`, `HaftaKutusu`, `HaftaKutulari`, `PlanEsikleri` (varsayılan 20.000/40.000 kalan adet), `HaftaHesabi` (ISO),
    `PlanKutulari.Olustur` (pencere bugün−4 hafta → en geç plan; öncesi "geciken"; plansız "atanmamış") ve `Suz`.
  - `PanoHesabi.cs`: `PanoAsamasi.Varsayilan` (Kesim 167/54/122/158, Print 56, Dikim 74/131/162/86/87/132/133, Finish 85,
    Paketleme 138/165/78/137), bugün/dün/hafta giriş(InOut=1)/çıkış, "bu hafta plan" (o aşamada bu haftaya planlı kalan), 14 gün teslim.
  - `PlanlamaExcel.cs`: ClosedXML, 15 sütun (üç aşamanın haftası dahil) + toplam formülleri.
  - `PlanlamaDeposu.cs`: açık kalem SQL'i (ReceiptType 2, CompanyId, silinmemiş/iptal/kapalı değil, Quantity > ReceivedQuantity;
    plan alt sorguları tablo yoksa NULL; WO bağı `UZM_SiparisWorkOrder.OrderReceiptItemId` varsa), `TasiAsync`
    (transaction + UPDLOCK/HOLDLOCK; null → DELETE, yoksa INSERT, varsa UPDATE), eşikler, hareketler.
- **Dokunulan dosyalar:** `src/SentezServis.Core/Planlama/*`, `db/sentezcore/siparis-plan.sql`
- **DB betiği:** `UZM_SiparisPlan (RecId, CompanyId, OrderReceiptItemId, Asama 1-3 CHECK, PlanTarihi date, Degistiren, DegismeZamani,
  UNIQUE(OrderReceiptItemId, Asama), IX(Asama, PlanTarihi))`, `UZM_SiparisPlanAyar (Asama PK, Dikkat, Tehlike, CHECK)`. Idempotent.

### 2. Host: `/api/planlama`
- `durum`, `haftalar?asama=`, `kalemler?asama=&yil=&hafta=&geciken=`, `excel?…&tum=true` (giriş);
  `POST tasi {kalemId, asama, yil, hafta}` ve `PUT esikler` (müdahale); `pano` (giriş). SqlException → 503 mesajlı.
  Taşıma denetimi: `plan-tasindi` "Kesim: 2026-H41 → 2026-H42".
- **Dokunulan:** `src/SentezServis.Host/Api/PlanlamaUclari.cs`, `Program.cs` (DI + map).

### 3. Web
- `api/planlama.ts`, `utils/planlama.ts` (+test: kutu rengi, sorgu, ISO hafta etiketi, termin uyarısı),
  `pages/PlanlamaSayfasi.tsx` (aşama sekmeleri, kutular, sürükle-bırak, çoklu seçim, eşik düzenleme, Excel),
  `pages/PanoSayfasi.tsx` (KPI, aşama tablosu + gerçekleşme %, yaklaşan teslimler, 60 sn yenileme),
  route `/planlama` `/pano`, menü "Haftalık planlama" (takvim) ve "Üretim panosu" (grafik), `theme.css` planlama/pano sınıfları.

### 4. Testler ve doğrulama
- **Komutlar:**
  ```bash
  dotnet test tests/SentezServis.Core.Tests            # 268 geçti, 9 atlandı (canlı)
  powershell -File scratchpad/canlitest.ps1 "FullyQualifiedName~PlanlamaDeposuCanli"   # 3/3 canlı okuma
  cd web && npx tsc -b && npx oxlint && npx vitest run  # tsc 0, yeni dosyalarda lint yok, 54/54
  ```
- Yeni testler: `PlanlamaTestleri` (hafta, pencere, aşama bağımsızlığı, süzme, Excel, pano), `PlanlamaDeposuCanliTestleri`
  (salt okunur), yazma koruması `KarmaKoliTestleri`: PlanlamaDeposu yalnız `UZM_SiparisPlan*`'a yazar, SentezCore açan dosyalar listesine eklendi.
- Yazma SQL'i ve DDL canlı DB'de `BEGIN TRAN … ROLLBACK` içinde denendi (kalem 948166: insert→update→delete,
  eşik upsert); sonrasında `OBJECT_ID('dbo.UZM_SiparisPlan')` NULL → kalıcı hiçbir şey yazılmadı.
- Tarayıcıda canlı tıklama denemesi YAPILMADI (yerelde servis DB'si yok); sunucuda kurulumdan sonra bakılacak.
- **Commit:** `c2ba51c` — Haftalik planlama + uretim panosu (MitoSentezDashbord'un Modfex karsiligi)

### 5. Paket
- `powershell -File deploy/yayinla.ps1 -AyarlariKoru` → `yayin/` (arayüz 2026-10-11 05:12); `yayin/db/` içine
  `siparis-plan.sql` + `siparis-work-order.sql` kopyalandı; `yayin-planlama-2026-10-11.zip` (77 MB).

## Kararlar
- Plan tarihi = hafta Pazartesi'si (gün önemsiz); Mito'daki "haftaiçi gününü koru" kuralı alınmadı.
- Kutu rengi kalan adede göre (Mito sipariş adedine bakıyordu): planlanacak iş kalan iştir.
- Pano aşama → süreç eşlemesi kodda sabit (`PanoAsamasi.Varsayilan`); gerekirse ayara taşınır.
- Sevk edilmiş (kalan ≤ 0) ve kapalı kalemler listede yok.

## Açık kalanlar / sonraki adım
- Sunucuda `db\siparis-plan.sql` çalıştırılmalı (ve hâlâ çalışmadıysa `siparis-work-order.sql` v2), sonra paket kurulup
  `/api/surum` arayuzTarihi 2026-10-11 05:12 kontrolü; `/planlama` ve `/pano` sayfaları denenmeli.
- Pano süreç eşlemesi kullanıcıyla teyit (özellikle Dikim/Paketleme hangi Erp_Process kayıtlarına yazılıyor).
- `src/SentezServis.Host/wwwroot/.gitkeep` silinmiş görünüyor (yayın derlemesi wwwroot'u temizliyor); bu tura ait değil, dokunulmadı.
