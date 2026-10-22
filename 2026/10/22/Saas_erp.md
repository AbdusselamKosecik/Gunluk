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

### 5. Arapça ve Urduca (sağdan sola) — yayında
- **Kurul:** CTO + Şüpheci APPROVE-WITH-CONDITIONS. Kapsam notu: ar/ur için adı geçen müşteri yok; kullanıcı açıkça istedi ("landing'deki diller"), kalıcı bakım yükü kabul edildi.
- **Önce görüntüsü:** dev 261022.0059, 10 Türkçe ekran (`scratchpad/rtl-baseline`, index.md ile yeniden çekilebilir).
- **Sınıf dönüşümü** (`abbac09a`, ayrı commit): `scripts/rtl-codemod.mjs` yalnız className/cn/clsx/cva/twMerge dizgelerinde 2179 fiziksel yön sınıfı → mantıksal (ms/me/ps/pe/start/end/text-start/end/border-s/e/rounded-s/e…), 467 dosya; landing/test/yazdırma hariç. tailwind-merge çakışma grupları genişletildi (px→ps/pe ezmesi; yoksa LTR değişirdi) + 24 test.
- **Altyapı** (`00090d38`): koruma testi (yeni fiziksel sınıf / paddingLeft vb. npm test'te kırılır, allowlist), Radix DirectionProvider, calendar/sonner/vaul dir, satır içi stiller mantıksal, 205 navigasyon ikonu `rtl:rotate-180`, fiş grid sütun genişletme RTL'de ters delta, ar/ur `-u-nu-latn` (Latin rakam) + `parse-number.ts` gidiş-dönüş testi, `<bdi>` sayı/tarih hücreleri, yazdırma pencereleri/etiketler `dir=ltr`, Excel `rightToLeft` (değerler ham).
- **Sonra görüntüsü** (dev 261022.0136): 6 ekran 0 piksel; 01/03 kenar yumuşatma (≤1 seviye), 09 hover geçiş zamanı, 10 canlı "… önce" metni → **PASS**, sonra push.
- **Çeviri** (`34043be5`): ar 13.549 + 823 hata (koli=كرتون; صندوق kasa ile karışıyordu), ur 13.549 + 823.
- **RTL UX 1. tur → BLOCK:** stok listesinde kod/ad karışıyordu ("20/1 PAMUK" → "PAMUK 20/1"), kaydedilmemiş değişiklik onayı sabit Türkçe, takvim gün adları üst üste, barkod yer tutucu.
- **Düzeltmeler** (`759b50ae`): metin hücreleri `<bdi dir=auto>`, kod/tarih/sayı `dir=ltr` (ColumnBuilder kod benzeri sütunlara `meta.bidi`); onay + takvim etiketleri 11 dilde (`d03.json`); ar'da tek harf gün adları; barkod yer tutucu. **Ayrıca gerçek hata:** fiş grid'de boş satıra ilk tuş yeni satır id'si ile hücreyi yeniden kuruyordu, odak düşüyordu ("1234,5" → "1"; dilden bağımsız) → yeni satır boş satırın id'sini korur, user-event testi.
- **RTL 2. kontrol** (dev 1.0.2.1031, Chrome'da kendim): ar stok listesi kod/ad doğru, Arap-Hint rakamı yok; takvim tek harf + Arapça nav etiketleri; ur fiş ekranı başlık/sütun/alt bilgi Urduca, ham anahtar yok → seçicide açıldı (`02a280f6`, test önce kırmızı sonra yeşil).
- **DEV:** 1.0.2.1029 (önce/sonra karşılaştırması için, push öncesi), 1.0.2.1030 (ar/ur çeviri), 1.0.2.1031 (düzeltmeler + Türkçe karakter), **1.0.2.1032 (ar/ur açık)**.

### 6. Türkçe karakter düzeltmesi
- 1.205 metin (tr-TR.json + 19 tr parçası): Aciklama→Açıklama, Iptal→İptal, Guncelle→Güncelle, Disa/Ice aktar… Kelime haritası + büyük/küçük harf korunur; barkod komut kodları GIRIS/CIKIS bilerek aynı. 6 test güncellendi. en: Bon Type→Voucher Type, Kadro→Staff, RetailCustomer, GV Type (tahmin — doğrulanmalı), b12 yinelenen anahtar. Kaynak kodda ~100 ASCII Türkçe metin (diyalog başlıkları, durum etiketleri) listelendi, değiştirilmedi (bazıları sunucu değeriyle karşılaştırılıyor olabilir). — `2b0d9817`.

## Kararlar
- Düşük öncelikli UX bulguları bırakıldı: dil yüklenirken gösterge yok (1–4 sn), de'de stok listesi araç çubuğu 1440'ta 2 satır, 375'te taşma (önceden de var), landing dil menüsü uygulamadan ayrı (ar/ur orada görünür).

## Açık kalanlar / sonraki adım
- ar/ur yayında (beta). Kalan: 375 px / çekmece / bildirim / yazdırma önizlemesi RTL kontrolü yapılmadı; takvim gün etiketinde "Today" İngilizce; ar için _few/_many çoğul biçimleri (test şu an yalnız en anahtarlarına izin veriyor).
- Menüde iki adres aynı Projeler sayfasını açıyor (/finance/project ve /finance/projects) — birini kaldırma kararı kullanıcıda.
- Sunucu mesajları: 823 kod çevrildi; 252 istisna + doğrulama (FluentValidation, PropertyName kodlu) mesajları hâlâ sunucu dilinde → backend'de MapErrorCode/parametreli hata (ayrı kurul).
- Anadil kontrolü: cari/fiş/irsaliye karşılıkları, ÖTV/ÖİV kısaltmaları, parçalı cümleler.
- Dokuma eksik listesi: levent hataları, kumaş kontrol tartım/en, dok kontrol alanları, küçükler, büyükler (F8).
