# Saas_erp — 2026-10-29

## Bağlam
28 Ekim gece: kullanıcı yönerge analizi maddelerinin hepsini istedi ("önce değişiklikleri yapalım, sonra bu maddelere göre çalışalım, backlog çıkar, goal çalıştıralım") ve iş kararlarını verdi (sahip boyutu yok, HAM = varyant, sevk = tüketim, kullanılmış reçete kilitli + revizyon, lot ağacı, fason sipariş bağı, 3006 = bana gelen kumaş, H6 kontinü/gün sonu dağıtım).

## Yapılanlar

### 1. Backlog + ClickUp
- **Ne:** `docs/design/analysis/2026-10-28-yonerge-backlog.md` (kararlar tablosu + E0–E10 sırası + çalışma kuralları), commit `ee8a4953`.
- ClickUp: E1–E10 `to do` görevleri (z8v9xnjpea … z8v9xnjpek, tag yonerge); E0 = z8v9xnjmxx.
- Goal metni: scratchpad `goal-yonerge-backlog.txt` (kullanıcı /goal ile çalıştıracak).

### 2. E0 Tahsis Fişi tamamlandı
- **Ön yüz:** ajanın yarım bıraktığı iş tamamdı; tek eksik menü düzeni (`menu-layout.commercial.tsx` Stok > Hareketler'e `/inventory/allocation-documents`).
- **H10:** `AllocationConsumption.ConsumeAsync` aynı (tahsis, ref) için satırı birleştirir; `UX_StockAllocationConsumption_AllocationRef` unique index. TDD: önce kırmızı test.
- **Rebase:** wtcrm origin/dev'in 13 commit gerisindeydi (araya SerialCard migration'ları girmiş). Migration klasörü sıfırlandı, WIP commit → `git rebase origin/dev` (ReceiptLotSync using ve changelog çakışması çözüldü), migration `dotnet ef migrations add` ile yeni zaman damgasıyla (20261028205741) üretildi ve elle yazılmış backfill/RAISE SQL'i eski dosyadan aktarıldı; has-pending-model-changes: No changes.
- **DEV salt-okuma kontrol:** 93 tahsis, deposuz aktif 0, uyumsuz 0.
- **Doğrulama:** verify all: backend 6592 unit geçti; frontend ilk turda api-errors fixture bayattı → `node scripts/extract-api-errors.mjs --write` → rc=0.
- **Commit:** `921ae375` — feat(inventory,production): Tahsis Fişi …
- **Deploy:** DEV 1.0.2.1100 (wtdeploy pinli, deploy-dev2.sh). API 200; DEV'de migration uygulandı: 70 fiş, 18 açık.

### 3. E0 UX düzeltmeleri + E1a dilim A
- **Neden:** UX kurulu Tahsis Fişi listesinde çökme (Gridify `data.data.data`) ve telefon genişliğinde taşma buldu; E1a yönerge hataları (H1–H4, H10–H11).
- **Ne yapıldı:** liste API şekli düzeltildi (a3cd7ba6); tablo `w-0 min-w-full overflow-x-auto` sarmalı (Container flex-1 kabuğu büyütüyordu). E1a A: paketleme taramasında iptal satırları hariç, top kalite sınıfı kiracı kalite tanımlarından (`IFabricQualityGradeQuery`, yoksa A/B/C/PARCA), tamir emri reçeteyi kopyalar, `AllocateFromReceipt` idempotent.
- **Commit:** `a3cd7ba6`, `56ef7f53` — DEV 1101, 1102. Canlıda genişlik 701→497px doğrulandı.

### 4. E1a dilim B (3021 yönü + iplik kat)
- 3021 fiş tipi giriş (In) yapıldı (katalog + ön yüz profili); `YarnSpecInfo.Ply`, gr/m hesabı kat sayısıyla. Etiket "Numara (tek kat)" 11 dilde.
- **Commit:** `722570d9` — DEV 1103.

### 5. E11 ürün resmi (kullanıcı isteği)
- Stok kartı listesinde küçük resim + kart başlığında büyük resim; ana resim = son yüklenen ProductImage. `IFileService.GetPresignedUrlsAsync` toplu imza (tek tek imza ağ çağrısı yapıyordu), sayfa ≤200 sınırı, yükleme politikası + ek uç noktalarına yetki.
- **Commit:** `31c64243` — DEV 1104. UX PASS (nit), güvenlik PASS. TD-023 kaydedildi.

### 6. E2 stok bütünlüğü dilim 1+2
- Fiş oluşturma `ClientRequestKey` ile tekrar gönderime karşı korumalı; eksi stok firma varsayılanı (`Inventory.NegativeStockDefault`, mevcut kiracılar=1, yeni=2) + gerçek uyarı; onaylı fiş geri alınınca hareket silinmez, ters kayıt yazılır (`ReversalOfId`, CHECK işaret kısıtı NOT VALID→VALIDATE).
- **Migration:** `20261029005845_Sprint_StockReceiptClientKey`, `20261029013609_Sprint_StockMovementReversal`.
- **Commit:** `19c3bf8f` — DEV 1105; migration uygulandı, CHECK doğrulandı, ayar 18 kiracıya yazıldı.
- **Kurul:** S3 (transfer seri/tahsis taşır) BLOCK → tasarım dokümanı gerek; S4 (sevk=tüketim) kullanıcı cevabı bekliyor (ClickUp z8v9xnjpeb).

### 7. E7 dilim 1 — Konfeksiyon Uzlaşma (salt-okuma)
- **Neden:** sipariş→kesim→operasyon→paket→mamul→sevk zincirinde miktar kaçağını görmek; S2 kuralları bu veriyle tasarlanacak.
- **Ne yapıldı:** Shared'da 3 okuma portu (Orders: rota+varyant sipariş; Logistics: iptal olmayan koli paketleri; Inventory: 3052/3053 sevk + 3010 giriş `OrderReceiptItemId` ile). Production'da saf `ApparelReconciliationCalculator`; sağlam = sağlam + tamirden dönen; tamire giden hiçbirine sayılmaz (çift sayım yok). Liste önce sayfalar, sadece sayfayı toplar; "fark var" filtresi hafif başlık + tek Inventory çağrısı. İndeks zaten var → migration yok.
- **Ön yüz:** Üretim > Konfeksiyon > Üretim Takip > Uzlaşma listesi; sipariş detayında "Uzlaşma" sekmesi (varyant satırı, kırmızı hücre + ipucu).
- **Doğrulama:** verify all rc=0 (6736 backend, 2899 frontend).
- **Commit:** `fbd6266f` — DEV 1.0.2.1106 (health 200).
- **Kurul:** S2 BLOCK (rota sadece doğrusal → paralel operasyon), S3 koşullu (PROD'da BoxBarcode tekrar kontrolü kullanıcıya), S4 geçiş kuralı bekliyor. PO: tamirden dönen sağlam sayılır, tetik koli kapanışı, tolerans %5, karışık sevkte 2K yok.

## Açık kalanlar
- E7 S1 UX/güvenlik post-check (çalışıyor). E3 S1 (varyantlı tahsis) ve E6 S1+S2 (reçete/rota revizyon + doz) ajanlarda.
- H8 (3006 anlamı) kullanıcıda bk-ask. E2 S4 sorusu ClickUp'ta.
- Kalan: E1b, E3 S2/S3, E4, E5, E6 S3/S4, E7 S2–S4, E8, E9, E10.
- GitHub Billing hâlâ DEV Deploy'u engelliyor (elle deploy). `_wt-idem` worktree index'i bozuk (bizim değil).
