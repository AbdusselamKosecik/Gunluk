# Saas_erp — 2026-10-22

## Bağlam
21 Ekim gecesi /loop (10 dk) ile "dilleri başta olmak üzere elindeki maddeleri bitir" sürüyor. 7 yeni dil (de, fr, it, bg, az, ka, hy) 1.0.2.1026 ile dev'deydi; kurulun şart koştuğu UX post-check bekleniyordu. Önceki gün: `2026/10/21/Saas_erp.md` madde 16–18.

## Yapılanlar

### 1. Dil UX post-check (ux-reviewer, Chrome, app-dev) → PASS-WITH-FIXES
- **Bulgular:** (1) tembel dil seçiliyken sayfa yenilenince İngilizce açılıyor; (2) fiş ekranı satır sütun başlıkları dil değişince eski dilde kalıyor (Türkçe sayfada Almanca başlık); (3) modül şeridi (83 px) etiketleri kırpılıyor (de 5, tr 2 etiket); (7) her dilde Türkçe kalan alt bilgi, stok arama kutusu, pano tarihi; (8) giriş ekranında "TR · EN"; (9) dil düğmesinin erişilebilir adı yalnız dil kodu. Seçici, beta etiketleri, ar/ur gizli, ka/hy yazı tipleri, ham anahtar yok — tamam.
- **Kök neden (1):** `i18nReady` ve seçiciler `i18n.resolvedLanguage` okuyordu; tembel dilin paketi henüz yokken bu 'en' döner → paket hiç yüklenmez. `i18n.language` kullanıldı. Test: kayıtlı 'de' ile `vi.resetModules()` + import → `i18nReady` sonrası dil 'de' ve paket yüklü (düzeltmesiz kırmızı, düzeltmeyle yeşil).
- **(2):** `receipt_workspace.page.tsx` `baseColumns` useMemo bağımlılığına `tSafe` (react-i18next `t` dil değişince yenilenir; `buildInventoryReceiptColumns` başlıkları okunduğu anda çevirir).
- **(3):** `module-rail.tsx` etiketlerine `hyphens-auto` + `[overflow-wrap:anywhere]`, düğmeye `title`.
- **(7–9):** `footer.tsx` → `SharedFooter.copyright` ({{year}}), `inventory.list.tsx` arama → `InventoryList.searchPlaceholder`, pano tarihi `toLocaleDateString(i18n.language)`, giriş istatistiği `SELECTABLE_LOCALE_OPTIONS.length`, header dil düğmesi `aria-label` `LayoutHeader.languageButton`. Yeni anahtarlar 9 dilde `assets/i18n/<dil>/d01.json`.
- **Commitler:** `a6906c73` (yenileme), `493b5d88` (diğer bulgular).
- **DEV yayını:** 1.0.2.1027 (temiz worktree, 3 denemeli derleme) pull_rc 0 / up_rc 0. Chrome'da doğrulandı: localStorage 'de' + yenileme → html lang=de, başlık "Lagerumbuchungsbeleg", sütunlar "Kartencode, Name, Beschreibung…", alt bilgi "Alle Rechte vorbehalten"; seçiciden Türkçe → "Depo Transfer Fişi", sütunlar "Kart Kodu, Adı, Açıklama…".

### 2. Tarih/sayı biçimlerini aktif dile bağlama (devam ediyor)
- ~200 dosyada sabit 'tr-TR'. Ajan: `formatLocale()` + `useFormatLocale()` yardımcısı, gösterim amaçlı kullanımları değiştirme; API'ye giden/parse edilen/karşılaştırılan/resmi Türkçe belge çıktıları hariç; date picker'a date-fns dil eşlemesi.

## Kararlar
- Düşük öncelikli UX bulguları bırakıldı: dil yüklenirken gösterge yok (1–4 sn), de'de stok listesi araç çubuğu 1440'ta 2 satır, 375'te taşma (önceden de var), landing dil menüsü uygulamadan ayrı (ar/ur orada görünür).

## Açık kalanlar / sonraki adım
- ar/ur: RTL geçişi (~795 fiziksel yön sınıfı → mantıksal) + çeviri; ayrı kurul + UX.
- Backend hata/doğrulama mesajları Türkçe.
- Anadil kontrolü: cari/fiş/irsaliye karşılıkları, ÖTV/ÖİV kısaltmaları, parçalı cümleler.
- Dokuma eksik listesi: levent hataları, kumaş kontrol tartım/en, dok kontrol alanları, küçükler, büyükler (F8).
