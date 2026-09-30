# sentezservis — 2026-09-30

## Bağlam
29.09 paketi (`SentezServis-2026-09-29-siparis-planlama-misirli.zip`) kuruldu. Mısırlı tarafı, beden bazlı
PAKET dökümünde farklı renklerin aynı bedeninin toplanmasını beğenmedi. Kullanıcı ayrıca "Yeni rayiç"in
menüden kaldırılmasını istedi.

## Yapılanlar

### 1. Mısırlı etiketi: BEDEN ve PAKET renk renk
- **Kullanıcı:** "Ortadaki tire 2 farklı renk olduğunu ima ediyormuş. Önce ilk rengin kırılımlarını, sonra
  diğer rengin kırılımlarını koyman lazım. Bu şekilde toplamamızı beğenmediler."
- **Ne yapıldı:** `MisirliExcelOkuyucu.cs`
  - Koli taslağında `Bedenler`/`BedenPaketleri` yerine `Kirilimlar` (renk → bedenler + beden paketleri) var.
  - Renk anahtarı satırın barkoddan çözülen rengidir (RENK satırıyla aynı); barkodu yoksa COLOUR.
  - Aynı rengin devam satırları aynı kırılıma girer.
  - BEDEN = kırılımlar ` - ` ile, bedenler boşlukla. PAKET aynı düzende.
- **Örnek:** RENK `SİYAH TEN - SİYAH BEYAZ` → BEDEN `75B 85C - 85C` → PAKET `40 20 - 30`.
  Koli 503: `85C - 85C` / `30 - 30` (önceden `85C` / `60`).
- **Testler:**
  - Yeni: `Beden_ve_paket_once_ilk_rengin_sonra_ikinci_rengin_kirilimidir`.
  - Karışık koli testi `85C - 85C` / `30 - 30` beklentisine çevrildi.
  - RED ("85C" ≠ "85C - 85C") → GREEN. .NET 671/671, web 68/68.
- **Belge:** `docs/etiket-ciktisi.md`, BEDEN ve PAKET satırları.
- **Commit:** `e4966c8`

### 2. "Yeni rayiç" menüden kaldırıldı
- **Kullanıcı:** "Onu Excel'de ayarlayacağız, sadece menüden kaldır."
- **Ne yapıldı:** `web/src/components/Layout.tsx` içinden "Satın alma" grubu kaldırıldı; grupta yalnız bu
  öğe vardı. `/rayic` rotası, sayfası ve arka tarafı duruyor.
- **Commit:** `a8d323c`

### 3. Paket
- **Ön kontrol:** Commit edilmemiş kod yoktu; `main` = `origin/main` = `a8d323c`. Temiz worktree'den
  `deploy/yayinla.ps1` çalıştırıldı (`appsettings.json` worktree'ye kopyalandı).
- **Sonuç:** `SentezServis-2026-09-30-misirli-renk-kirilimi.zip`, 73,8 MB. Arayüz 2026-09-30 13:59.
- **29.09 paketiyle karşılaştırma:**
  - Dosya listesi aynı.
  - app.js: karsit-kodlar 6, siparis-planlama 9, Pierre 3, Mısırlı 1, kasa 13 korunmuş.
  - "Yeni rayiç" 2 → 1 ve `/rayic` 11 → 10: menü bağlantısı gitmiş, sayfa ve rota duruyor.
  - Örnek ayarda 6 × `<DOLDURUN>`; `appsettings.json` pakette yok.

## Açık kalanlar / sonraki adım
- Sipariş planlama ertelenen küçükler, canlıya geçiş adımları, Shopify indirim kodu, el terminali soruları.
