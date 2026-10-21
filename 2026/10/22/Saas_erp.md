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

### 2. Tarih/sayı biçimlerini aktif dile bağlama (başlangıç — sonucu madde 3)
- ~200 dosyada sabit 'tr-TR'. Ajan: `formatLocale()` + `useFormatLocale()` yardımcısı, gösterim amaçlı kullanımları değiştirme; API'ye giden/parse edilen/karşılaştırılan/resmi Türkçe belge çıktıları hariç; date picker'a date-fns dil eşlemesi.

### 3. Tarih/sayı biçimleri aktif dile göre
- `core/lib/i18n/format-locale.ts`: `formatLocale()` / `useFormatLocale()` (tr→tr-TR, en→en-GB, de-DE, fr-FR, it-IT, bg-BG, az-Latn-AZ, ka-GE, hy-AM, ar, ur), 6 test (Türkçe çıktı birebir: `1.234.567,89`, `05.10.2026`).
- Codemod: 201 dosyada gösterim amaçlı `'tr-TR'` → `formatLocale()`; import anında kurulan 10 biçimleyici fonksiyona çevrildi. `date-fns-locale.ts` + `date-comp.tsx` (ur yok → enGB; en artık enGB).
- Dokunulmayan: `toLocaleLower/UpperCase('tr-TR')` (veri eşleştirme, ~32), kiracı dil ayarı değeri.
- Dev'e merge (başka geliştiricinin "gerçekleşen maliyet" commit'leri; hata mesajı ajanı aynı ağaçta çalıştığı için stash yerine merge). Yeni "Gerçekleşen Maliyet" ekranı 9 dile (`d02.json`) — `0dc2d546`.

### 4. Sunucu hata mesajları seçili dilde (9 dil)
- **Kurul:** CTO APPROVE-WITH-CONDITIONS; Şüpheci önce **BLOCK** (katalog `ErrorMessages.cs` aslında İngilizce; 36 kod çok mesajlı; 91 `$""` mesaj; doğrulama hataları PropertyName kodlu; mevcut el haritası ASCII Türkçe ve dil vermeden hep tr). Şartlar uygulandı → yeniden inceleme APPROVE-WITH-CONDITIONS; ek bulgu: `ModuleEntitlementGateMiddleware` `Subscription.ModuleNotInPlan` genel mesajı yerine üretim emrine özgü metin gösterilecekti → "ayrıştırılmayan kullanım yeri" istisnası.
- **Yapı:** `scripts/extract-api-errors.mjs` (ErrorCodes.cs + ErrorMessages.cs + satır içi Error.X/WithErrorCode), `assets/api-errors/<dil>.json` düz anahtar (i18next derin birleşme dışı), `core/lib/i18n/api-errors.ts` (aktif dil → en → sunucu → kod; `kod:Alan` son eki), `api-errors.{inscope,excluded}.json` fikstür. 823 kapsamda, 252 istisna (145 ayrıştırılmayan yer, 63 değer gömülü, 37 çok mesajlı, 3 dinamik, 3 kaynaksız, 1 yer tutucu) → sunucu mesajı.
- **Test:** kapsamdaki her kod tüm dillerde, istisna yok, yetim yok, HTML yok, kaynak metin değişince kırılır (yalnız YEREL; CI'da test adımı yok), `ModuleNotInPlan` istisna. Eski el haritası silindi; `apiErrorMessage` + axios toast aktif dil; giriş ekranı `auth.invalid_credentials` için UI anahtarı.
- **Backend:** `ErrorMessages.cs` 7 gölgelenen çift satır silindi (çalışma anında kazanan metin korundu → sunucu çıktısı değişmedi).
- **Çeviri:** de/fr/it, bg/az, ka/hy ajanları. fr "locataire" (kiracı) → "société" düzeltildi. Sözlük: bg/az/ka/hy levent/çözgü/atkı/top/dok düzeltmeleri (`0d445ba5`).
- **Not:** hook, cwd `assets/api-errors` iken oraya `production/session-logs/` yazdı → klasör testi kırıldı → silindi. cwd'yi proje köküne almak gerekir.
- **Commit:** `f10e9634` (+ dev merge). **DEV:** 1.0.2.1028 pull_rc 0 / up_rc 0. Ağ bir süre github.com'u çözemedi; push sonra geçti.

## Kararlar
- Düşük öncelikli UX bulguları bırakıldı: dil yüklenirken gösterge yok (1–4 sn), de'de stok listesi araç çubuğu 1440'ta 2 satır, 375'te taşma (önceden de var), landing dil menüsü uygulamadan ayrı (ar/ur orada görünür).

## Açık kalanlar / sonraki adım
- ar/ur: RTL geçişi (~795 fiziksel yön sınıfı → mantıksal) + çeviri; ayrı kurul + UX.
- Sunucu mesajları: 823 kod çevrildi; 252 istisna + doğrulama (FluentValidation, PropertyName kodlu) mesajları hâlâ sunucu dilinde → backend'de MapErrorCode/parametreli hata (ayrı kurul).
- Anadil kontrolü: cari/fiş/irsaliye karşılıkları, ÖTV/ÖİV kısaltmaları, parçalı cümleler.
- Dokuma eksik listesi: levent hataları, kumaş kontrol tartım/en, dok kontrol alanları, küçükler, büyükler (F8).
