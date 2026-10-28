# Saas_erp — 2026-10-28

## Bağlam
DIA B3 (varyant bazlı stok) 27'sinde DEV 1088 ile kapandı. Kullanıcı; İleri Üretim, İplik, Örme, Dokuma, Boyahane, Yıkama,
Çivit (İndigo) ve Konfeksiyon için uçtan uca, tüm olasılıklarıyla diagrams.net akış şeması istedi.

## Yapılanlar

### 1. Üretim akış şemaları (diagrams.net)
- **Neden:** Modüllerin gerçek davranışını (karar noktaları, hata/ret yolları, stok fiş kodları) tek yerde görmek; boşlukları görünür kılmak.
- **Ne yapıldı:**
  - Önce kodu okuyan araştırma ajanlarıyla her modülün gerçek akışı çıkarıldı. Yalnız kodun yaptığı çizildi; olmayanlar "sistemde YOK" notu oldu.
  - Python üreticisi yazıldı: `drawio_gen.py` (kulvar ızgarası, düğüm tipleri, ortogonal kenarlar, sıkıştırmasız mxfile) + `flows.py` (12 sayfa tanımı).
  - Sayfalar: Lejant, Genel zincir, Ortak üretim emri, İleri Üretim, İplik, Örme, Dokuma, Çözgü, İndigo/Haşıl, Boyahane, Yıkama, Konfeksiyon.
  - Doğrulama: XML geçerli (661 mxCell), düğüm çakışma kontrolü temiz, viewer.diagrams.net'te Dokuma sayfası görsel olarak kontrol edildi.
- **Dokunulan dosyalar:** `docs/design/flows/{README.md, uretim-akislari.drawio, flows.py, drawio_gen.py}`
- **Komutlar:**
  ```bash
  cd docs/design/flows && py -3 -B flows.py uretim-akislari.drawio
  ```
- **Önemli bulgular (şemalarda not olarak):**
  - Ortak yaşam döngüsü: 0 Taslak → 1 Planlı → 2 Serbest → 3 İşlemde → 4 Tamamlandı / 5 İptal; 4→3 yeniden açma. Otomatik tamamlama yalnız Boyahane'de.
  - AllocateFromReceipt yalnız rezerv yapar, fiziksel transfer yok.
  - Üretim fişi = 3062 Sarf + 3010 Üretim (ops. 3066 fason çıkış / 3014 transfer).
  - MRP yalnız Dokuma (iplik) ve Boyahane (kimyasal) için dolu.
  - Yıkama ayrı emir tipi değil; Boyahane rotasında operasyon/program. Konfeksiyon yıkaması YOK.
  - Fason faturalama YOK.
  - Konfeksiyonda mamul 3010 otomatik değil (elle).
  - Örme fişleri emre bağlı değil; FabricInspection yalnız Dokuma'da.
- **Commit:** `4b61f3fd` — docs(design): uretim akis semalari (diagrams.net)

## Kararlar
- Şemalar elle çizilmedi, kodla üretildi; akış değişince `flows.py` güncellenip yeniden üretilir.
- Ajanlar çeliştiğinde (AllocateFromReceipt'in Ham→WIP taşıdığı iddiası) koda bakıldı: `TransferAsync`'in çağıranı yok, yani yalnız rezerv.

## Açık kalanlar / sonraki adım
- DIA backlog: C4 (envanter idempotency) ve C6 (gerçek toplu upsert) — ikisi de kurul gerektirir.
- B3 takipleri: varyant bazlı üretim çıktısı/tahsis; DEV test kayıtları; düşük önemli güvenlik bulguları (ClickUp z8v9xnjkn9).

---

## Ek (öğleden sonra)

### 2. Tahsis Fişi + tüketim defteri + seri takipli tahsis bütünlüğü (DEVAM EDİYOR, commit yok)
- **Neden:** Kullanıcı: "Tüm tahsisleri tahsis fişi olarak tahsisle, kullanılan miktarı kontrol et; lotlu ürünü serili (kısmi) veya serisiz bütünlüğü bozmadan tahsis et."
- **Kurul:** CTO/Skeptic/DBA/PO/Security → hepsi APPROVE-WITH-CONDITIONS. Kullanıcı kararları: fiş YALNIZ OTOMATİK; seri takipli malzemede başka emre tahsisli stoğa dokunan çıkış/sarf (3061/3062 dahil) ENGEL.
- **Spec:** scratchpad `tahsis-fisi-spec.md`; ClickUp `z8v9xnjmxx` (ip-ask).
- **Backend (worktree wtcrm, commit yok):** `StockAllocationDocument` (TF-000001, açık/kapalı, (kaynak, depo) başına tek açık fiş), `StockAllocationConsumption` defteri + `UsedQuantity`, rezerv = Q−U tek yardımcı, `pg_advisory_xact_lock(tenant:item:wh)` kilidi, seri takipli hard-block, ledger guard 3061/3062, lot–depo uyuşmazlık açığı kapandı, migration `20261028070041_Sprint_StockAllocationDocument`.
- **Migration denemesi:** DEV şema + ilgili tabloların veri kopyası lokal postgres:18 container'da: ilk deneme 7 eski deposuz (Guid.Empty) satır yüzünden RAISE → düzeltme: 3'ü irsaliye başlığından türetildi, 4 kapalı eski kayıt WarehouseId NULL fişe. Sonra Up/Down/Up temiz (92 satır, 70 fiş, sayaçlar 13/55, 24 backfill tüketim = 38812).
- **Doğrulama:** `tools/verify.sh backend` rc=0 (6558 unit), StockAllocationConcurrencyTests 3/3 gerçek PG (Testcontainers; Docker Desktop elle başlatıldı).
- **Post-check:** Security PASS; Skeptic PASS-WITH-FIXES → 5 düzeltme uygulandı (unapprove'da yalnız unconsume edilen miktar kadar azaltma, giriş geri almada seri guard, lot FOR UPDATE her relational durumda, eski veri fallback'inde backfill satırı silme, Used>0 iken depo değişimi red).
- **Bulgu (ayrı borç):** Inventory entegrasyon testlerinden 10'u temiz dev'de de kırık (ITenantSettingsQueryService DI eksik).
- **Açık:** ön yüz (Tahsis Fişleri liste/detay, Seri seç/Serisiz, emirden fişe link, changelog) yarım kaldı; UX kontrolü, commit/push/DEV deploy bekliyor.

### 3. Tekstil ERP gereksinim belgesi (docs/chatcpt) yönerge–kod analizi
- **Neden:** Kullanıcı `docs/chatcpt` içindeki md'lerin (ana belge + 7 bölüm) yönergeleriyle ilgili analiz istedi.
- **Ne yapıldı:** 5 bölüm (temel+ortak, iplik, kumaş, yaş işlem, konfeksiyon) paralel ajanlarla yönerge yönerge kodla karşılaştırıldı (VAR/KISMİ/YOK/ÇELİŞKİ, grep kanıtlı); 07 (yazılım modeli, P0 kural kataloğu, UAT, yol haritası) elle okundu. En kritik iddia (3021 yönü) elle doğrulandı.
- **Dosya:** `docs/design/analysis/2026-10-28-tekstil-erp-yonerge-analizi.md`
- **Önemli bulgular:** H1 3021 "Üretimden İade" Out tanımlı ama menü/raporlar iade (giriş) sayıyor (DEV'de 0 fiş, düzeltme ucuz); H2 Ply g/m hesabına girmiyor (katlı iplikte yarı sarf riski); kimyasal sarfı idempotent değil ve emre bağlı değil; boya reçete sürümü emre dondurulmuyor; onaylı fiş geri almada hareketler fiziksel siliniyor; bakiyede sahip/kalite/lot boyutu yok.
- **Commit:** `29570385` — docs(design): tekstil ERP gereksinim belgesi yonerge-kod karsilastirmasi

## Açık kalanlar
- Tahsis Fişi ön yüz + UX + commit/deploy.
- Analizdeki H1–H7 hızlı düzeltmeler (her biri kurul önerisi).

### 4. Gereksinim belgesi 1.2 eki: §19 zincirleme tahsis, §20 iç üretim/fason/ham-mamul
- **Neden:** Kullanıcı `docs/chatcpt` altında güncelleme yaptı (yeni `08_zincirleme_tahsis.md`, `09_ic_uretim_fason_kumas_asamasi.md`; 01/06/07'de yalnız atıflar) ve tekrar kontrol + yorum istedi.
- **Ne yapıldı:** İki yeni bölüm elle okundu; iki Explore ajanı kodu taradı. Ana klasör (X:) origin/dev'in 103 commit gerisinde çıktı; ajanlar güncel `wtcrm` ağacında yeniden doğruladı (ilk turda varyant bakiyesi yanlış "yok" görünmüştü).
- **Sonuç:** Raporun sonuna bölüm 8 eklendi. Ana yorum: tahsis bugün yalnız fiziksel stokta; beklenen tedarik (PR/PO/planlanan çıktı) bağı, mal kabulünde/üretim çıktısında otomatik tahsis ve kalite bekletme yok. Fason sevki (3057) düz çıkış, fasoncudaki miktar yalnız raporda. Ham/mamul ayrı kart + depo. Yeni bulgular: H8 3006 anlamı raporlar arasında tutarsız (doğrulanmalı), H9 varyantlı bakiye vs varyantsız tahsis, H10 tüketim defterinde tekillik yok, H11 AllocateFromReceipt çift gönderimde çift satır.
- **HTML:** artifact https://claude.ai/artifact/XCRHhQDJuxpBeAK1Qf522T (v2) + indirilebilir tek dosya (scratchpad `tekstil-erp-yonerge-analizi.html`).
- **Commit:** `fbc3d146` — docs(design): yonerge analizi eki (§19, §20, H8-H11)

### Açık kalanlar (güncel)
- Tahsis Fişi ön yüz + UX + commit/deploy; H10 bu işe eklenebilir.
- H1–H11 her biri kurul önerisi.
- Ana çalışma klasörü X: origin/dev'in 103 commit gerisinde (kullanıcının değişiklikleri var, dokunulmadı).
