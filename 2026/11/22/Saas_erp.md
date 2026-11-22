# Saas_erp — 2026-11-22

## Bağlam
`prodread` (üretim GET yetki taraması) wte33'te uygulanmıştı ama kapı koşusu oturum kapanırken kesilmiş, iş gönderilmemişti. Arada `dev` 11 commit ilerlemişti (Konfeksiyon üretim emri taşıma + emir zinciri, 11-16..11-20). Ayrıca kullanıcı worktree şişmesini sordu.

## Yapılanlar

### 1. Worktree temizliği (+~44 GB)
- **Neden:** `wt/` içinde 26 kopya (~15 GB), `Saas_erp/.claude/worktrees/` içinde 26 eski ajan kopyası (~31 GB) birikmişti. Kopya başına ~580 MB'ı bin/obj.
- **Ne yapıldı:**
  - `wt/`: işi `dev`'e geçmiş 21 kopya kaldırıldı (wte2,6,7,14,15,17–31, wtfix). Commit edilmemiş içerik yalnız regen ürünü `api-errors` JSON'larıydı.
  - Silmeden önce junction'lar `cmd //c rmdir` ile kaldırıldı; `wte13/src/frontend/node_modules` korundu (346 girdi).
  - Kalan kopyalarda (wte13, wtlocal, wtdeploy, wte32) bin/obj silindi.
  - `.claude/worktrees/agent-*` 26 kopya `git worktree remove --force` ile kaldırıldı; kullanıcı "sil" dedi. Dallar ve commit'ler depoda duruyor. Kaybolan yalnız `agent-audit.log` ve satır sonu farkı. Symlink/junction yoktu, kontrol edildi.
- **Arşiv (`wt/_archive/`):**
  - `wte26-receipt-standard-e7s3b2.patch`: `dev`'de OLMAYAN fiş standardı koli seçici istisna metni (E7 S3b-2);
  - e6s3b2 ve s8ux ilerleme notları.
- **Not:** `rm -rf` içeren birleşik komut izin sisteminde reddedildi; tek tek `git worktree remove` çalıştı.
- **Sonuç:** X: boş alan 73 GB → 117 GB.

### 2. dev'deki kırmızı kapılar — emir zinciri kayması
- **Neden:** prodread kapı koşusunda 3 unit ve 2 vitest kırmızısı çıktı. Hepsi `dev`'e giren 986101c60 / a930a2fc1'den geliyordu, prodread'den değil.
- **Ne yapıldı:**
  - `ProductionEndpointPermissionContractTests`: AddProductionOrderLink ve RemoveProductionOrderLink sabit tabloya `update` olarak eklendi; yazma ucu sayısı 113 → 115. DELETE fiilli Remove ucu adı geçen istisnaya alındı: bağ kaldırmak emri düzenlemektir. Uçların davranışı değişmedi.
  - `order_links_panel.tsx:35`: `ml-auto` → `ms-auto`.
  - `node scripts/extract-api-errors.mjs --write`; `order_link.duplicate/not_found/same_type/self` 11 dilde eklendi.
- **Commit:** `2dba98afb` — fix(production): emir zinciri kapilari kaymasi - kontrat tablosu, RTL sinifi, hata katalogu

### 3. prodread — ProductionController GET'lerine production:read
- **Kurul:** CTO ve Skeptic APPROVE-WITH-CONDITIONS (`wt/prodread-proposal.md`).
- **Ne yapıldı:**
  - 47 GET'e method-level `[RequirePermission("production","read")]` eklendi. 48 kapısız ucun biri manage probe'u (GetDyeingRecipeManagePermission), o allowlist'te.
  - ApiKeyScope'a dokunulmadı.
  - Rebase sonrası `dev` yeni ve kapılı bir GET (`orders/{id}/links`) eklemişti; sabit GET sayısı 72 → 73.
  - Changelog maddesi 2026-11-22'ye taşındı (`clday.py`).
- **Testler:**
  - unit 9439/9439;
  - tip kontrolü ve lint temiz, vitest 504 dosya / 3867 test;
  - entegrasyon `ProductionReadPermissionApiTests` 5/5 (viewer 200, kullanıcı deny 403, rol deny 403, ApiKey orders 200 / pre-costings 403, probe deny altında 200 + false).
  - Koleksiyon temizliğinde xUnit bir "Cleanup Failure" logladı; test sonuçlarını etkilemiyor.
- **Ön kontrol:** DEV'de production:read deny override sayısı 0/0 (standby, read-only). PROD ölçülmedi (kural).
- **Güvenlik koşulu 6:** kodla kapatıldı. Ek URL'si tenant kapsamlı (PreCostingAttachments.cs:22-23, :94), `MaxUrlExpiryMinutes = 60`.
- **Commit:** `8a210a61e` — fix(production,security): ProductionController GET'lerine production:read kapisi

### 4. DEV deploy denemesi: 1.0.2.1202 (tamamlanmadı)
- **Ne yapıldı:**
  - `wt/wtdeploy` `origin/dev` 8a210a61e'ye alındı. `bash tools/verify.sh all` rc=0.
  - api-dev ve spa-dev için 1.0.2.1202 ve latest imajları build edildi, 4 etiket push edildi.
- **Engel:**
  - Webhook `:56806` "connection refused" veriyor.
  - .57'de `vuoapp-deploy.service` 2026-11-15 açılışında "Dependency failed" (`Requires=docker.service`) ile düşmüş, `inactive (dead)`.
  - Başlatmak sudo istiyor; vuo kullanıcısının şifresiz sudo'su yok. Kullanıcıdan şu istendi: `ssh -t vuo@217.131.14.57 "sudo systemctl start vuoapp-deploy"`.
  - Kalıcı çözüm önerisi: servis dosyasına `Restart=on-failure` ve `RestartSec=10`.
- **Not:** port 80 URL'si (build-dev.cmd) 301 ile https'e yönleniyor; webhook bu yoldan da çalışmıyor.

### 5. production:cost-read — maliyet verisi ayrı okuma yetkisi
- **Kurul:** PO, CTO, Skeptic ve Security, hepsi APPROVE-WITH-CONDITIONS. Birleşik karar `wt/costread-proposal.md`'de.
- **Ne yapıldı:**
  - Katalogda ve seed'de (owner/admin/manager) `production:cost-read`. Migration yok.
  - API anahtarı kataloğuna cost-read eklendi.
  - 10 GET'te read → cost-read; ApiKeyScope yalnız açık 3 uçta cost-read.
  - Handler içindeki ikinci read kontrolü (GetCostCalculations/ById) cost-read oldu.
  - FE: CostReadGuard (12 rota), menü gizleme, Tedarik ve sipariş ön doldurmasında yetkisizken GET yok ve fiyat null.
  - Model standart maliyeti gizlendi. API anahtarı seçicisi, i18n 11 dil, changelog.
- **Yan düzeltme:** "auth" rate-limit sınırı yapılandırılabilir oldu (`RateLimiting:AuthPermitLimit`, varsayılan 10); test host'u 1000 veriyor.
  - Neden: Api test koleksiyonu tek kovayı paylaşıyor. İki yetki sınıfı birlikte koşunca girişler kuyrukta 1 dk 40 sn zaman aşımına düşüyordu (5 dk sürüyordu); şimdi 11/11, 5 sn.
- **Ajan notu:** iki ajan da 20 adım sınırına defalarca takıldı. Arka uç ajanı CRLF/LF karışık tek satırda döngüye girdi; iş devralındı, satır sonu normalize edildi.
- **Testler:** unit 9455/9455, vitest 3873/3873, tip kontrolü ve lint temiz, integration 11/11.
- **Commit:** `d908a5f9a` — feat(production,security): production:cost-read - maliyet verisi ayri okuma yetkisi
- **ClickUp:** z8v9xnkr6b → complete. Takip ticket'ı: z8v9xnm9ye (kesim fiyatı, UnitPrice, piece-labor, fason tutarı, standardCost backend, boş fiyatın 0 kaydı).

### 6. cost-read takip maddeleri (z8v9xnm9ye) — v2 dilimi
- **Kurul:** PO, Skeptic, CTO; hepsi APPROVE-WITH-CONDITIONS (`wt/moneyfollow-proposal.md`).
- **Kararlar:**
  - kesim fiyatı, Konfeksiyon UnitPrice, piece-labor: KABUL;
  - fason raporu Tutar ve model standardCost backend maskesi: SONRA, yeni ticket z8v9xnma0a.
  - Skeptic uyarısı: standardCost maskesi, UpdateInventory.cs:807 koşulsuz yazdığı için saklı değeri null ile ezer.
- **Ne yapıldı (yalnız FE):**
  - `applyOrderRowChange` bilinmeyen fiyatı null tutuyor; kayıtta yine 0 gidiyor.
  - `countUnpricedLines` ve kayıt BAŞARILI olduktan sonra çoğul toast (11 dil). Fason siparişte bildirim yok.
  - tedarik_bulk ve demand-transfer ön doldurması 0 yerine null.
- **Hata ve düzeltme:** ar `_zero/_one/_two` metinlerinde `{{count}}` yoktu; i18n testi "en placeholder'ları korunmalı" kuralıyla kırdı. Eklendi.
- **Testler:** TDD (7 test önce kırmızı: 5 fail / 2 pass), sonra vitest 3881/3881, tip kontrolü ve lint temiz.
- **Commit:** `198f3c825` — fix(orders,production): fiyati bilinmeyen siparis satiri bos kalir, kayit sonrasi fiyatsiz satir bildirilir

### 7. UX post-check (yerel, 198f3c825 + d908a5f9a)
- **Ortam:** `bash local-up.sh origin/dev`; ux-reviewer hiçbir kaydı kaydetmedi (paylaşılan DEV DB).
- **Sonuç:** PASS-WITH-NITS, BLOCK yok.
  - Tedarik → sipariş: fiyat boş geliyor, adet düzenlenince de boş kalıyor.
  - CostReadGuard, TenantAdminGuard ile aynı.
  - "Maliyet görüntüle" API anahtarı seçicisinde ve Yetki matrisinde ("Diğer işlemler") görünüyor.
  - 390px ve dark mod sorunsuz.
- **Notlar (önceden var olan):** backlog ticket'ı açıldı (sipariş sekmeleri 390px'te taşıyor, boş satırda fiyat 0, aria-label, İngilizce modül adları, Toplu Tedarik GUID).
- **Not:** uygulama dark modu sistem ayarından değil, `dark` sınıfıyla açıyor; test için elle eklendi.
- **ClickUp:** z8v9xnm9ye → complete. Yerel ortam kapatıldı.

### 8. UX küçük notları (z8v9xnma0v)
- **Ne yapıldı:**
  - PermissionMatrix modül adları koda göre çevriliyor (tr/en, 29 kod; DB adı fallback). DB'de adlar karışık dildeydi.
  - Toplu Tedarik Model kolonu GUID yerine kod · ad gösteriyor (inventoryByIdQuery).
  - document-workspace-shell TabsList yatay kayıyor (production_order_detail emsali).
  - receipt-detail-control giriş hücrelerine aria-label=column.caption.
- **Testler:** tip kontrolü ve lint temiz, vitest 3881/3881.
- **Commit:** `5b15dada4`
- **Bilerek yapılmayan:** boş yeni satırda fiyat 0 (tüm sipariş tipleri, PO/UX kararı).
- **Ek (`fe07bb5cb`):** docs/design/yetki-maliyet-goruntule.md (6 bölüm) eklendi; barkod placeholder'ı sans + ellipsis, tam metin title ile görünüyor. vitest 3881/3881.

### 9. İş etüdü maliyet maskesi + yeni satırda boş fiyat (z8v9xnma0a B, z8v9xnma0v md.2)
- **Kurul:** PO, Skeptic, CTO, Security; hepsi APPROVE-WITH-CONDITIONS (`wt/later-proposal.md`).
  - A (fiş/satır fiyatı): PO SONRA dedi, Skeptic KABUL. Ürün kararı PO'da olduğu için `inventory:price-read` ayrı özellik ticket'ı açıldı (z8v9xnma33).
- **Ne yapıldı:**
  - **B:** `GetDetailAsync(…, bool canReadCost)` zorunlu parametre. 4 alan (Labor, Machine, Overhead, StandardCost) GET, Update ve Create yanıtında maskeleniyor.
    - CTO bulgusu: PUT/POST yanıtı da tam detay döndürüyordu.
    - UpdateInventory yetkiyi baştan bir kez kontrol ediyor; cost-read yoksa gelen değer yok sayılıyor. Fail-closed.
    - FE: "Standart Maliyet" kartı gizli.
  - **C:** `emptyOrderLineRow` ve `initialOrderLineRows` payload'a taşındı, fiyat null başlıyor. emptyOrderLine ve OrderLineForm tipi değişmedi.
- **Testler:**
  - InventoryWorkStudyCostMaskTests (10), PermissionService API anahtarı teorisi (4), work-study-cost (3), order-line-new-row (6, önce kırmızı);
  - unit 9469/9469, vitest 3890/3890, tip kontrolü ve lint temiz.
  - Tip kontrolü bir kez test dosyasındaki eksik `item` prop'u yüzünden kırıldı, düzeltildi.
- **Bulgu:** CreateInventory WorkStudy'yi hiç kaydetmiyor. Ayrı hata ticket'ı z8v9xnma34; bugünkü davranış testte kilitli.
- **Commit:** `d7c71984c` — feat(inventory,orders,security): is etudu maliyet alanlari cost-read ile maskelenir; yeni siparis satiri bos fiyatla baslar
- **ClickUp:** z8v9xnma0a ve z8v9xnma0v → complete. Yeni: z8v9xnma33 (price-read özelliği), z8v9xnma34 (Create WorkStudy hatası).

## Kararlar
- prodread güvenlik açığı düzeltmesi DEĞİL; derinlemesine savunma ve gerileme koruması (Skeptic koşulu 1).
- Asıl açık olan viewer'ın maliyet görmesi ayrı PO ticket'ı: `z8v9xnkr6b` (production_cost:read).

## Açık kalanlar
- production:cost-read tamamlandı (d908a5f9a). Takip ticket'ı z8v9xnm9ye.
- Ayrı ticket adayları: garment okumalarında method-level RequireModule boşluğu (CTO koşulu 7c).
- E7 S3b-3a Chrome yürüyüşü: MİTO için onaylı 5202 sipariş verisi gerekiyor. Varyantsız sipariş satırı riski PO'da.
- DEV hâlâ 1.0.2.1201. Deploy servisi .57'de kapalı, kullanıcının sudo ile başlatması gerekiyor. 1202 imajları d908a5f9a'yı İÇERMİYOR; servis açılınca 1203 build edilip deploy edilecek.
