# Saas_erp — 2026-10-16

## Bağlam
Kullanıcı, son değişikliklerin çekilmesini, bekleyen iş varsa gönderilmesini ve API ile UI'ın yerelde çalıştırılmasını istedi.

## Yapılanlar

### 1. Güncelleme
- **Ne yapıldı:** `dev` 7330b24a → b1b2e7a5 fast-forward oldu. Gelenler: ön maliyette model kodu/adı, sipariş ve fişlerde varyant matrisi, kısmi paketleme, barkodlu harekette düzeltme paneli ve çoklu emir modu, fiş onayı ayarı, lab test silme.
- **Bekleyen yerel iş:** Yoktu (çalışma ağacı temiz, push edilmemiş commit yok). Gönderilecek bir şey çıkmadı.

### 2. Yerelde çalıştırma
- **Komutlar:**
  ```bash
  # src/frontend/.env.development.local (git-ignored) → VITE_PUBLIC_API_URL=http://localhost:5240
  dotnet run --project src/backend/VuoApp.Api        # :5240
  cd src/frontend && npm install && npm run dev      # :3131
  ```
- **Sonuç:** API açıldı: "Bekleyen migration yok, 104 migration uygulanmış, 471 tablo yerinde". Yeni migration'lar paylaşımlı DB'ye başka makinede zaten uygulanmış. UI'da Vite hazır. Tailscale `services` erişilebilir durumdaydı.

## Açık kalanlar
- Build uyarısı: MailKit 4.15.1 orta seviye güvenlik açığı (NU1902). Güncellenmeli.

### 3. Menü yapısı analizi
- **Neden:** Müşteri menüde aradığını bulamıyor.
- **Ne yapıldı:** `routes.tsx` TypeScript AST ile tarandı (scratchpad `menu.cjs`). Görünür menüde 28 ana başlık ve 348 sayfa var. Tekrarlar: Rotalar/Operasyonlar 6×, Cari Hesaplar 7×. Finans 45 sayfalık düz bir liste. Çevrilmemiş anahtarlar: Pms.title, ExportFiles.menu, AdminUsers.menu, AdminBilling.menu.
- **Karar (kullanıcı):** Yapı ve iç içelik kalacak, sadece görünüm değişecek.

### 4. İki panelli menü denemesi (dal: `feat/iki-panelli-menu`)
- **Ne yapıldı:**
  - `layouts/components/sidebar/two-panel/` altında yeni menü: solda modül ikonları ve adları (84px), yanında seçili modülün sayfaları (248px). Alt gruplar açılır-kapanır yerine başlık oldu (seviye 0: büyük harfli başlık, seviye 1+: küçük başlık ve girinti).
  - Panelde tüm menüde arama var: Türkçe karakter duyarsız ("kumas" → "Kumaş"), Ctrl+K ile açılır, Enter ilk sonuca gider.
  - Menü kapalıyken bir modüle tıklanınca panel üstte açılır; sayfa değişince ya da fare çıkınca kapanır.
  - Seçim, `vuo.menuStyle` anahtarıyla localStorage'da tutuluyor (`useSyncExternalStore`). Klasik menüye "Yeni menüye geç" düğmesi eklendi.
  - `index.tsx` hangi menünün gösterileceğine karar veriyor; menü verisi (`use-navigation`) aynı.
- **Testler:** `two-panel.utils.test.ts` 9 test (normalizeForSearch, findActiveModuleTitle, flattenModule, searchNav). Layout testleri 17/17 geçti, typecheck temiz.
- **Görsel doğrulama:** Chrome MCP kopuktu. Scratchpad'e `playwright-core@1.56.1` kuruldu, sistem Chrome'u ile girişsiz değil, admin + MitoTex tenant'ı ile ekran görüntüsü alındı. Kontrol edilenler: Anasayfa, Boyahane, Finans, arama, kapalı menüde açılan panel, klasik menüye gidip dönme. React'in tekrarlanan anahtar uyarısı (Finans'taki iki "Projeler") anahtara sıra numarası eklenerek giderildi.
- **Commit:** `c0ef8af3` (dal `feat/iki-panelli-menu`). `dev`'e bilerek alınmadı: dev'e push otomatik DEV yayını yapıyor.

## Açık kalanlar (eklendi)
- Kullanıcı denemeyi onaylarsa: kurul (CTO + Şüpheci + UX) çalıştırılacak, `dev`'e merge edilecek ve changelog maddesi eklenecek.
- Üst bardaki "Ara: sipariş, stok, müşteri… ⌘K" kutusu işlevsiz (state'e yazıyor ama hiçbir şey yapmıyor).
