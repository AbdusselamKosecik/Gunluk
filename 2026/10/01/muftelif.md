# muftelif — 2026-10-01

## Bağlam
SarfKullanim'dan SentezPlaning'e geçildi. Kullanıcının iki isteği:
(1) yıkamaya parametre, (2) dikim planında model kodu + Excel/adet/SMV düzeltmeleri.

## Yapılanlar

### 1. Keşif (2 paralel Explore ajanı)
- **Haftalık kapasite modülü:** İstenen parametrelerin çoğu ZATEN var (PP R/S, Islak I/Iss = sprey
  öncesi/sonrası, Zımpara ZB/ZR, Kılçık K/KF, Yıpratma). Tek eksik Lazer'in çalışma saati:
  Lazer `l_min_per_person × makine × vardiya × 6` ile hesaplanıyordu, `l_working_time` kolonu ölü.
  Haftada 6 iş günü her yerde sabit kodlu (backend + frontend'de formül iki yerde).
- **Dikim planı:** `orders.model_kodu` var ama DTO/ekran/Excel'e hiç çıkmıyor. Excel `GetOrders(null,null,null)`
  ile TÜM order tablosunu döküyor (ekran ise hat/dikim yeri/kategori + dikim çıkış tarihine göre filtreli)
  → "planda olmayan modeller" bundan. Adetler sentez-çekte bilerek korunuyor, fark sadece uyarı.
  SMV: etüt sorgusundan `InUse=1` filtresi bir ara kaldırılmış → muadil operasyonlar toplanıyor
  (6510-1259 için 21,0904/19,9007 = 1,0598 tam bu profile uyuyor).

### 2. Kullanıcı kararları
- Excel: ekrandaki filtrenin aynısı. Adetler: ikisi de (sipariş + kesim paylı) Sentez'den ezilsin, uyarı yok.
- Yıkama parametreleri: haftalık kapasite ekranı (Lazer çalışma saatine geçsin).
- SMV: muadilleri (InUse=0) etüt toplamından çıkar.

### 3. Uygulama (2 paralel ajan + kendi doğrulamam)
- **Lazer:** `Machine(LActiveMacCount, LWorkingTime, LShiftCount)`; `LMinPerPerson` legacy olarak kaldı.
  Tek seferlik backfill `PlaningDb.BackfillLazerWorkingTime` (meta bayrağı `weekly_capacity.l_working_time.backfill`),
  `l_working_time = ROUND(l_min_per_person/60)`. Ekranda "Makine başı dk" → "Çalışma (saat)".
- **Model kodu:** `PlanOrderDto.ModelKodu = ModelOf(o)`; plan tablosunda "Model" kolonu; Excel'de STYLE'dan
  sonra "MODEL" (sonraki kolonlar ve 3 SUM formülü bir kaydı).
- **Excel:** `ExportExcel(lineId, week, lokasyon)` + controller query param'ları; hat verilirse yalnız o hattın
  kapasite sayfaları. Web export çağrısı ekrandaki filtreleri gönderiyor.
- **Adet:** sentez-çekte `o.SiparisAdet`/`o.Adet` her zaman ERP'den; `AdediFarkli` sayacı ve toast kaldırıldı.
- **SMV:** `EtutSmv`'ye `ISNULL(ws.InUse,1)=1` ve `ISNULL(i.IsDeleted,0)=0`.
- Ajanın bıraktığı gereksiz BOM (`UretimPlanService.cs`) temizlendi.

### 4. Doğrulama (kendim, canlı çalıştırarak)
```bash
dotnet build            # 0 hata
# API 5299 + web 5280 ayağa kaldırıldı, dev JWT ile:
GET /api/sentez/uretim-plan/orders      # 862 kayıt, modelKodu hepsinde dolu
GET .../export                          # 11 sayfa
GET .../export?line=fashion-nd          # 5 sayfa, 261 model dışarıda kaldı
# xlsx içi: başlıklar MARKA|ORDER|STYLE|MODEL|FIT|... → MODEL kolonu yerinde
GET /api/sentez/planning/capacity/2026-27   # lMinWeek 17280 (480dk→8 saat dönüşümü sonrası aynı)
```
- Backfill doğrulandı: `l_min_per_person 480 → l_working_time 8`, kapasite değişmedi.
- **Doğrulanamayan:** SQL sunucusu 192.168.1.22'ye bu oturumda erişilemedi → SMV değişikliği (muadil filtresi)
  ERP'ye karşı denenemedi; A9255-1601 repodaki eski dev DB'de yok. Tarayıcı MCP'si de bağlanamadı,
  görsel kontrol yapılamadı (web build + lint geçiyor, lint hataları değişiklik öncesiyle birebir aynı).
- **Commit:** `8794ba7`

## Açık kalanlar
- Erişim açılınca: `sentez-cek` + SMV recalc çalıştırıp 6510-1259'u kontrol et. Modelin yerel SMV kaydı
  `excel`/`elle` kaynaklıysa değer donmuştur; etüt düzeltmesi görünmez, kayıt silinmeli
  (`DELETE /api/sentez/uretim-plan/smv/{style}`); plan tablosundaki rozetten (E/X/M) anlaşılır.
- Adetlerin ERP'den ezilmesi tek yönlü: elle düzeltilmiş adetler ilk çekişte kaybolur, planlamacılara söylenmeli.
- Excel kolon sırası değişti (D'den sonrası bir kaydı); dışarıdaki makro/sheet varsa etkilenir.
- Filtreli Excel'de hâlâ "KATEGORISIZ" sayfası olabiliyor: hatta düşen ama kategorisi boş order'lar.

### Canlı (eski) sürüm ile karşılaştırma — doğrulama
- **Neden:** HDD silinmişti; `http://192.168.3.228:90` üzerinde koşan eski kod geri kalmış olabilir.
  Kullanıcı Excel çıktılarının ve dikim sonuçlarının yeni kodla karşılaştırılmasını istedi.
- **Ne yapıldı:** Canlı API'ye login olunup `/api/sentez/uretim-plan/{orders,lines,export}`
  çekildi; xlsx zip'i açılıp sayfa adları, başlık satırı ve shared-string indeksleri okundu.
  ERP'den (salt okunur) iki kartın etüt toplamları alındı.
- **Bulgular:**
  - Canlı export **10 sayfa**, filtre yok, **MODEL kolonu yok**. Yeni kod ekran filtresini
    (hat/hafta/dikim yeri) uyguluyor ve STYLE'dan sonra MODEL basıyor.
  - `A9255-1601` canlı export'ta "5 CEP" sayfası satır 156 ve 181'de; iki siparişinin de
    (94438, 94731) dikim çıkış tarihi ve haftası boş → plan ekranında yok. Filtre düzeltmesi
    bunu dışarıda bırakıyor.
  - 501 siparişin 373'ünde dikim çıkış tarihi yok, 83'ü aktif hat kategorileri dışında
    (29 GÖMLEK - hat kapalı, 54 kategorisiz). Eski export hepsini basıyordu.
  - **SMV farkı kart farkıymış:** planda `6510-1259-1691` var (order 94761, smv 21,0904);
    ERP'de bu kartın UD_SMVF = 21,0904 → doğru. Kullanıcının baktığı `6510-1259` kartının
    UD_SMVF'i 19,9007 ve bu kart planda hiç yok. Fashion & ND hattının smvKaynak = udf.
  - **Önceki hipotez yanlıştı:** "muadil (InUse=0) operasyonlar toplama giriyor" bu vakayı
    açıklamıyor; iki kartta da InUse=0 satır yok. InUse filtresi yine doğru ama sebep bu değil.
- **Sonuç:** Kodda ek değişiklik gerekmedi; `8794ba7` içindeki düzeltmeler yeterli.
  Canlıya deploy edilmesi gereken fark: modelKodu alanı, export filtresi + MODEL kolonu,
  yıkama/lazer parametreleri, InUse filtresi, adetleri Sentez'den her zaman güncelleme.

### Yıkama planlaması — süre kaynağı zinciri, ıslak ayrımı, hafta ataması, Excel
- **Neden:** Kullanıcı: *"sürelerini Sentez'de rotadan çekeceksin (örnek `X:\Gitlab\fredericTr\firedericproduct`),
  rota olmayanları direkt etütten alacaksın. burada yıkamanın tamamını planlayacağız."*
- **Referans okuma:** `firedericproduct/ViewModels/OrderViewModel.cs:218` — yıkama rotası
  `Erp_Inventory.UD_UretimRota1` → `Erp_Route` → `Erp_RouteItem` → `Erp_Process`.
- **Veri keşfi (salt okunur sqlcmd):**
  - Açık 481 order: 419 rotalı, **62 rotasız** (48 kart). Rotasızlar eski kodda altı grupta da 0 dk.
  - Rotasız kartların kendi etüdünde yıkama işlemi (`5xxx` kodlu) **yok** — 48 kartın 1'inde var.
    Etütlerinde yalnız `1xxx` dikim işlemleri. Ana model kartı (ör. `A355-2029`) sistemde hiç yok.
  - Aynı `UD_WashName`'e sahip **rotalı** kart 48'in 38'i için mevcut; aynı yıkamadaki kartlar
    pratikte aynı süreyi veriyor (12 örnekte 11'i tek değer).
  - `Erp_RouteItem.ProcessTime` yıkama bölümlerinde neredeyse boş (Zımpara 20'ye karşı 6.325);
    dolu olan kolon `Erp_Process.StandartTime` → kolon seçimi doğruymuş.
  - `UD_SpreyDurumu` = `Sprey Öncesi` (37.126) / `Sprey Sonrası` (23.991) → ıslak ayrılabilir.
  - **Tuzak:** DB collation `Turkish_CS_AS`. Test SQL'imi sqlcmd ANSI okuduğu için `Zımpara`
    literalleri bozuldu, "kodda yazım yanlış" sandım. Hex çözümü koddaki yazımın doğru olduğunu
    gösterdi. Türkçe harf gereken sorgularda `NCHAR(305)` gibi ASCII-güvenli kurulum kullan.
- **Karar (kullanıcı seçti):** süre kaynağı = **rota → etüt → aynı yıkama**; hiçbiri yoksa "yok".
  Kart BÜTÜN olarak tek kaynaktan okunur (yarısı rotadan yarısı etütten gelmez).
- **Ne yapıldı:**
  - `PlanningSql.cs` yeniden yazıldı: `Orders` (başlık+miktar), `BolumSureleri` (uzun format,
    rota+etüt), `YikamaSureleri` (yıkama adı bazlı mod). İşlem→bölüm eşlemesi rotalardan öğrenilir
    (etüt satırlarında `UD_IslemBolumu` yok).
  - `PlanningService.cs`: zincir çözümleme, ıslak sprey kırılımı, 2 dk snapshot önbelleği.
  - `planning_week_atama` tablosu + repository + store; order elle haftaya taşınabiliyor.
  - `PlanningExport.cs`: Haftalık Yük / Kapasite / Order Detay / Süresi Yok sayfaları.
  - Web: süre kaynağı rozeti, SP Önce–SP Sonra kolonları, "N süresiz" uyarısı, hafta seçici,
    Excel'e aktar butonu.
- **Düzeltme (önemli):** eski ıslak sorgusu `p.RecId IN (SELECT ri.ProcessId ...)` yazdığı için
  bir rotada TEKRAR EDEN işlemi tek sayıyordu (41.861 rota satırı / 36.001 tekil rota-işlem çifti;
  bir rotada aynı durulama 6 kez). Artık her satır sayılıyor. PP/Lazer/Kılçık/Yıpratma birebir aynı
  kaldı, Zımpara'da order başına yuvarlamadan 1 dk fark.
- **Doğrulama (yerel, gerçek veri):**
  ```bash
  dotnet build api/SentezPlaning.Api.sln          # 0 uyarı 0 hata (önce API'yi durdur: exe kilitlenir)
  curl .../planning/weeks                          # 15 hafta, süresiz 62 -> 11
  curl .../planning/export                         # 4 sayfa, 482 order satırı
  curl -X PUT .../orders/92408/week -d '{"week":"2026-40"}'
  ```
  - 92408 taşındı: 2026-36 islakOnce 38.704 → 37.885 (−819), 2026-40 32.922 → 33.741 (+819).
    Atama kaldırıldı, `planning_week_atama` 0 satır — test verisi bırakılmadı. Bilinmeyen order → 404.
  - 2026-27 kıyası: birleşik ıslak %80,8 iken SP önce **%156,5**, SP sonra %32,0 — eski birleşik
    gösterim aşımı gizliyormuş.
  - Önbellek: 15,3 sn → 1,6 sn (ilk) / 1,1 sn (sonraki).
  - Web build geçti; lint 10 hata + 1 uyarı — **değişiklikten önce de aynıydı** (`8794ba7^`
    ağacında aynı komut aynı sayıyı verdi).
- **Commit:** `1602129` — feat(sentez-planing/yikama): sure kaynagi zinciri, islak sprey ayrimi,
  hafta atamasi, Excel

## Açık kalanlar / sonraki adım
- 11 order'ın yıkama süresi hâlâ yok (rota+etüt+aynı yıkama hiçbirinde): ör. `A300-1285` (DETOX),
  `A3083-1896` (CROC). Bunlara rota tanımlanması veya etüt girilmesi gerekiyor — ekranda ve
  Excel'de "Süresi Yok" olarak listeleniyor.
- 2026-36 ve sonrası haftalarda kapasite girişi yok (yerelde yalnız 2026-27 dolu), bu yüzden
  yük % hesaplanmıyor.
- SentezPlaning canlıya (192.168.3.228:90) deploy edilmedi. Deploy'da `api/data/sentez-planing.db`
  EZİLMEMELİ — dikim çıkış tarihleri, hat ayarları ve hafta atamaları orada.
