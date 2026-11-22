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

## Kararlar
- prodread güvenlik açığı düzeltmesi DEĞİL; derinlemesine savunma ve gerileme koruması (Skeptic koşulu 1).
- Asıl açık olan viewer'ın maliyet görmesi ayrı PO ticket'ı: `z8v9xnkr6b` (production_cost:read).

## Açık kalanlar
- production_cost:read: PO kararı bekliyor (`z8v9xnkr6b`).
- Ayrı ticket adayları: garment okumalarında method-level RequireModule boşluğu (CTO koşulu 7c).
- E7 S3b-3a Chrome yürüyüşü: MİTO için onaylı 5202 sipariş verisi gerekiyor. Varyantsız sipariş satırı riski PO'da.
- DEV hâlâ 1.0.2.1201; 0f298e542, cccd8c8aa, 2dba98afb, 8a210a61e ve upstream Konfeksiyon işi DEV'de yok. Kullanıcı isterse deploy.
