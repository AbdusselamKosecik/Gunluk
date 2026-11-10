# Saas_erp — 2026-11-10

## Bağlam
11-08 sabahı test hattı RAM yetersizliği yüzünden durmuştu: `msedgewebview2` 21 GB tutuyordu, boş bellek 3,7 GB'a düşmüştü. Kullanıcı "devam" deyince 39 GB boşla yeniden başlandı. Bu arada `origin/dev`'e başkaları da push etmişti:
- birleşik yetki matrisi,
- kesim planlama,
- stok fişi silme parametresi,
- onay geri almanın tek akışa toplanması (`ReceiptUnapproveFlow`).

## Yapılanlar

### 1. Ortam
- `%TEMP%/mem.ps1` Storage Sense tarafından silinmişti; `wt/mem.ps1` olarak yeniden yazıldı.
- Docker Desktop kapalıydı. Bu yüzden ilk PG koşusunda dilimdeki ve baseline'daki bütün testler kırıldı. Docker başlatıldı.
- `ship.sh` dosya listesine `session-logs|agent-audit` filtresi eklendi.
- `clday.py` düzeltildi:
  - **Sorun:** dilim kendi tarih bloğunu açınca araç dosyayı bozuyordu (11-08 E6 S3b-1 ve 11-10 E7 fix). Sebebi, yapısal satırları (`  {`, `    ],`) değerine göre silmesiydi.
  - **Çözüm:** artık yalnız `{ kind:` satırlarını taşıyor, boş kalan tarih bloklarını da siliyor.

### 2. E2 S4b-2 — `4911453f9`
- **Rebase çakışmaları** (`ApproveReceipt.cs`, `DeleteReceipt.cs`): upstream onay geri almayı `ReceiptUnapproveFlow`'a taşımıştı. Onaylı fiş silme de upstream'de yeni gelmişti.
  - E2 korumaları akışa taşındı: 3062 için kilit sırası, 3061 için `NetIssuedGuard`, 3062 için `ChemicalPostingReversal`.
  - Onaylı silme bu akıştan geçiyor. Taslak silme için ayrı bir blok eklendi. İki yeni test yazıldı.
- **Mimari testler:**
  - 3062 yazıcı tespiti gerçek yazmalara daraltıldı.
  - `ProductionInventoryService.cs:280` ve `YarnPackaging.cs:118` (kimyasal dışı sarf) allow-list'e eklendi.
  - Pin listesi `ChemicalPosting.cs`'e taşındı.
- **Gerçek açık (Q3):** Boyahane üretim fişinde operatörün seçtiği kimyasal, netleşme mekanizmasını atlayıp sarfa yazılabiliyordu. Artık `inventory.issue.boyahane_receipt_no_chemical` ile reddediliyor; 3 test eklendi.
  - Kalan risk: reçetesiz ya da erişimsiz emirde kontrol atlanıyor.
- **PG testleri:** 12 yeni test kırıktı, hepsi test kaynaklıydı.
  - UUIDv7'nin ilk hex'lerinden türetilen stok kodu çakışıyordu; son 12 hex'e çevrildi.
  - `Scalar` yardımcısı DBNull'u işlemiyordu.
  - Bir seed'de `ProductionIssueItems` eksikti.
- **Doğrulama:**
  - Unit: 9201 geçti.
  - Vitest: 3605 geçti.
  - PENDING_CHECK temiz.
  - ChemicalNetting PG testleri: 15/15.
  - Boş PG17'de migration zinciri uygulandı; CHECK'ler doğrulandı (convalidated = t).

### 3. E7 S3b-2 düzeltmesi — `5eb3d5ef1`
- **UX BLOCK (F1):** koli satırlarında `OrderReceiptId` NULL, sipariş bağı başlıkta. `GetShippableBoxes` yalnız satıra baktığı için gerçek kolileri bulamıyordu.
  - Sorgu: `line.OrderReceiptId == X || (line NULL && header == X)`. Bu OR iki indeksi de kullanabildiği için COALESCE seçilmedi.
  - `PackingBoxContentQuery` da aynı kuralla başlığa düşüyor.
- **Ek düzeltmeler:**
  - Koli hücresi yalnız konfeksiyon satırında açılıyor (C1).
  - "Koli Listesi'ne git" yeni sekmede açılıyor (C2).
  - Düğme metni "Vazgeç" oldu.
- **UX yeniden kontrol:** PASS-WITH-NITS.
  - MitoTex'in 10 kolisinin hepsi karışık (asorti), bu sürümde bağlanamıyor.
  - ClickUp backlog işi açıldı: `z8v9xnkd22` "E7 S3b-3: karışık koli bağlama + Engelle modu".

### 4. E6 S3b-2 — `a1e189fd8`
- **İçerik:**
  - Kontinü boyahane makinesinde kapanan iş hareketi için otomatik kimyasal sarf. Poster; iş kaydı oluşturma, güncelleme ve silmeye bağlı. Revizyon, supersede ve lease kullanıyor.
  - Geri alma ve tekrar deneme endpoint'leri.
  - Elle sarfta, otomatik sarf aktifse `acknowledgeAutoPost` zorunlu; yoksa 409 `chemical.auto_post_active`.
  - Kimyasal deposu sırası: makine deposu (kesin) > tenant ayarı `production.dyehouse.chemicalWarehouseId` (kesin) > en çok stoklu depo.
  - Kill-switch `production.dyehouse.chemicalAutoPost` varsayılan '0'.
- **Yöntem:**
  - wte28'e E2'nin commit edilmemiş hali tohumlanmıştı.
  - E2 push edilince E6'ya özgü fark iki geçici commit arasından çıkarıldı (`C1` = yalnız E2 tohumu, `C2` = E2 + E6).
  - Fark yeni `origin/dev`'e `git apply -3` ile uygulandı. JSON ve changelog çakışmalarında iki taraf korundu.
- **Migration:** `E6S3b2_ChemicalAutoPost`. Elle eklenenler:
  - `lock_timeout`,
  - kill-switch seed'i (`WHERE NOT EXISTS`),
  - Down öncesi kontrol (satır varsa iptal).
  - Boş PG17'de up, down ve tekrar up temiz çalıştı.
- **Gerçek hata:** farklı emirlerden eşzamanlı sarflarda bakiye xmin çakışması 500 veriyordu. Artık 409 `inventory.stock.balance_conflict` dönüyor.
- **Testler:**
  - Diğer kırıklar test kaynaklıydı: seed kodu, eksik `useOrderChemicalConsumptions` mock'u, izin sözleşme sayısı (113).
  - Unit: 9246 geçti.
  - Vitest: 3618 geçti.
  - PG: 304 testte yalnız bu dilimde kırılan yok (24 hata baseline ile aynı).

### 5. UX post-check ve düzeltme — `684cf3e7c`
- **Kontrol:** yerel yığın, E2 S4b-2 + E6 S3b-2. Sonuç PASS-WITH-NITS, düzeltilmesi şart bir maddeyle.
- **Şart madde:** Boyahane emrindeki çıkış özeti iplik metinlerini gösteriyordu. Kurul koşulu 14 karşılanmıyordu.
- **Düzeltmeler:**
  - Panel metni artık emir tipine göre seçiliyor (`issue_summary_copy.logic.ts` + vitest).
  - Onay bandı karanlık modda doğru renkleri kullanıyor.
  - 390px'te diyalog başlığı kapatma düğmesiyle çakışmıyor.
  - "batch" → "parti".
  - "sonraki sürümde" yardım metinleri güncellendi.
  - Otomatik sarf anahtarına erişilebilir ad verildi.
- **Gates:** ilk koşuda TC_FAIL çıktı, ama sebep kod değildi: npm "Illegal instruction" ile çöktü. Tekrar koşunca temiz geçti (vitest 3626).
- **Not:** Karşılanan kolonu, onay bandı ve iş satırı çipleri canlı görülemedi; MitoTex'te verisi yok. Kodda incelendi.

## Açık kalanlar
- E6 S4: kurul koşulu gereği S3b-2'nin DEV'de bir pilot turu bekleniyor (DEV deploy ve gerçek kullanım gerekir).
- ClickUp `z8v9xnkd22`:
  - karışık koli bağlama ve Engelle modu,
  - Örme ve Boyahane için teorik ihtiyaç,
  - E7 S3b-2'nin Chrome kontrolü için test verisi.
