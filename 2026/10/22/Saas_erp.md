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

### 7. G3 — Çözgü/dokuma leventi hataları
- **Neden:** Sentez "Çözgü Parti Çalışma Formu"ndaki levent hata gridi VuoApp'te yoktu; tasarım dokümanı §3.9 #13 bunu F5'e taşımış, F5 kapsamı düşürmüştü (dokuma eksik listesi G3).
- **Kurul:** CTO, şüpheci, DBA, ürün sahibi → APPROVE-WITH-CONDITIONS; güvenlik → PASS. Ana şartlar: 6/7 tipleri kumaş muayenesinde sunucu tarafında da engellenir; hata kartı tipi 0..7 doğrulaması; WarpBeam'e navigation koleksiyonu yok (EF istemci cascade tuzağı, levent soft-delete); emre göre GET leventin silinme filtresiyle tek sorgu; kumaş kontrolünde salt okunur "Levent hataları (n)".
- **Ön kontrol:** dev DB `SELECT FaultyType, count(*) FROM inventory."FaultyCard"` → yalnız 1 (3 satır); 6/7 boş.
- **Ne yapıldı:** `production.WarpBeamFault` (kart kodu/adı/tipi kopyalanır, adet 1..9999 CHECK, not 500, hard delete), migration `20261022004929_WeavingBeamFaultsG3` (üretildi, uygulanmadı; has-pending temiz). Endpoint: GET `warp-beams/faults?productionOrderId|warpBeamId`, POST `warp-beams/{id}/faults`, PUT/DELETE `warp-beams/faults/{faultId}`. `VuoApp.Shared.Constants.FaultyTypes` (6 Çözgü, 7 İndigo/Haşıl). Frontend: `BeamFaultsDialog` (Kod–Ad, Adet, Açıklama, alt toplam "n hata, Σ adet"), Çözgü planlama "Hatalar" sütunu, İndigo/Haşıl levent satırında buton, kumaş kontrolünde salt okunur grup görünümü; muayene butonları + barkod araması 6/7'yi dışlar. 11 dil (`assets/i18n/<dil>/g3.json`) + 5 yeni hata kodu çevirisi; changelog; tasarım dokümanı §3.23.
- **Ek düzeltme:** G3'ten önce de kırık olan 6 test: vitest'e `svgr()` eklendi (`?react` svg'ler bileşen değildi), login testi gerçek Türkçe çeviriyle, teklif listesi kontratından kaldırılmış rozet beklentisi silindi.
- **Doğrulama:** frontend tam test 1397/1397 (düzeltmeden sonra kırık yok), typecheck temiz; backend ilgili 408 birim testi yeşil (ajan: tüm birim 4540 geçti).
- **Commit:** `a8de9ed9` — feat(production): G3 levent hataları; `68e6cae2` — test(frontend): eskimiş login ve worklist testleri. DEV: 1.0.2.1033.
- **Açık:** UX post-check (Chrome, 375 px) dağıtım sonrası; fault silme `production:update` ile (güvenlik: bilinçli tercih, belgelendi); İndigo/Haşıl girdisi başka emre aitse rozet 0 gösterebilir (diyalog doğru veriyi gösterir).

### 8. G3 UX post-check (Chrome, app-dev 1.0.2.1033) → PASS-WITH-FIXES, düzeltildi
- Bulgular: yeni hata kartı oluşturunca pencere eski listeyi gösteriyordu (form doğrudan api.post kullanıyor, cache geçersizlenmiyordu); dokuma silme onayı biçimsiz (düğmeler bitişik, Sil kırmızı değil); en "1 faults"; 375 px'te hata adı 6 satır; boş durum linki düz metin; tip adları küçük harf.
- Düzeltme: `useInvalidateFaultyCards` + pencere açılışta yeniden çeker; `weaving_confirm_dialog` outline/destructive (4 silme çağrısı kırmızı); `_one/_other` çoğul (ar için ek biçimler en'de olmadığı için düz anahtar geri dönüşü); tablo yatay kaydırma, `pe-8`; link stili; "Çözgü Hatası"; odak kart seçimine döner. — `35c6e432`.
- Test verisi: DEV'de "UX-CZ1 UX Çözgü kopuk tel" (Çözgü tipi) kartı bırakıldı.

### 9. G4 — Dok kesiminde top başına tartım/en + kesim ekranından yeni hata
- **Neden:** Sentez Dok→Top'ta her top ayrı tartılıyor, giriş eni zorunlu. VuoApp'te kumaş→top zaten kapanışta kg/en alıyordu; dok→top'ta kg metreye oranlanıp dok eni yazılıyordu. Yeni hata yolu (reopen) vardı ama kesim ekranından erişilemiyordu.
- **Kurul:** CTO/şüpheci/DBA/ürün sahibi APPROVE-WITH-CONDITIONS. Çatışmalar: WeightSource eklendi (CTO+PO+DBA); geriye dönük doldurma YOK (Posted toplar TR_WovenRoll_PostedImmutable ile kilitli, UPDATE migration'ı düşürür — PO isteği CTO/DBA ile reddedildi); karışık tartım = hep-ya-hiç (şüpheci; PO "kg opsiyonel" set düzeyinde korunur); en zorunlu, ön dolu.
- **Kritik risk (şüpheci):** `FabricCutOptimizer.Build` kesimleri sıralayıp top numaralarını yeniden veriyor → değer yanlış topa gidebilirdi. Çözüm: kg/en `CreateRollCutRequest → CutPlanItem → CutSegment` alanlarıyla taşınır; doğrulama istek numaralarıyla, renumber öncesi.
- **Ne yapıldı:** `WovenRoll.WeightSource smallint` (1 oransal, 2 tartılan, null eski) + `CK_WovenRoll_WeightSource`; migration `20261022012346_WeavingRollWeighG4` (üretildi, uygulanmadı). Raporlar: tartılan = `WeightSource==2 || (null && kg!=null)`. Frontend: kesim diyaloğunda tartım tablosu (birim anahtarlı, Σ kg vs dok kg, %5 üstü uyarı, 44 px, virgül), oransal kg "≈"; kesim ekranında "Yeni hata ekle" → reopen → muayene (returnTo + önceki bitiş/en/kg dolu, bitiş değişirse fark) → kesime dönüş. 11 dil (`g4.json`), changelog, doküman §3.24.
- **Sapmalar:** ölçüm kontrolleri FluentValidation kuralı değil, handler'dan çağrılan statik metot (ValidationBehavior kodu `validation.invalid_format`'a çeviriyordu); reopen sunucuda `production.delete` istiyor (D9'da update yazıyordu, değiştirilmedi); muayene ekranında ters çevirme kavramı yok → sabit uyarı.
- **Doğrulama:** frontend 1441/1441, typecheck temiz; backend birim 4566 geçti/0 kaldı; yeni Postgres entegrasyon testi `WovenRollWeightSourceCheckTests` 7/7 (ajan çalıştırdı).
- **Commit:** `df5a0f59` — feat(production): G4. DEV: 1.0.2.1034.
- **Açık:** G4 UX post-check (Chrome) dağıtım sonrası; etiket DTO'sunda weightSource yok.

### 10. G4 UX post-check (Chrome, 1.0.2.1034) → PASS-WITH-FIXES, düzeltildi
- Bulgular: 375 px'te sayfa 445 px (header arama kutusu + ikonlar, içerik sarmalayıcısında min-w-0 yok) → diyaloglar sağdan kesik; yeniden açılışta önceki kg "9.6" (nokta); canlı metre son hata metresinden başlıyordu → sahte "−18 m / %−60" uyarısı; tartım tablosunda en için görünür * yok; hata sonrası odak; tezgah kesimi sonrası Dok Kontrol listesi yenilenmiyordu (G4 öncesi de vardı).
- Şüphe: yeniden açılan muayeneye eklenen 2. hata DB'de yok (yalnız 1 kayıt; POST hiç gelmemiş). Testle yeniden üretilemedi — sayfa mantığı sağlam (2 yeni test POST'u doğruluyor); muhtemel neden 375 px taşmasında tıklamanın hedefi kaçırması. Taşma düzeltildi; tarayıcıda tekrar denenmeli.
- Düzeltme: header `min-w-0`, dar ekranda arama + Mesaj/Ayar ikonları gizli; `fmtInput` yerel ondalık; canlı metre önceki bitişten; `*`; ilk hatalı alana odak; `cut`/`cancel-last` → `INSPECTABLE_CUTS_KEY` invalidate. Frontend 1507/1507. — `baec409b`.
- Test verisi (DEV, UX-231161): dok UX-231161-K003, muayenesi, Posted top seti INV-2026-3010-000016 (T008 9,9 kg/158,5 cm, T009 0,3 kg).

### 11. G5 — Dok kontrol: brüt/dara → net kg, ölçülen gramaj, etikette müşteri/kontrolör
- **Bulgu (öneri):** G5'in çoğu zaten var ya da sipariş kopyası: kesim metresi = fire segmenti/WasteM, çoklu en = yalnız gösterim gridi, müşteri/lot = sipariş verisi. Eski Sentez'de Create ekranında dara kutusu bağlı değil (hiç kaydedilmiyor), net yalnız örmede stoğa etki ediyor.
- **Kurul:** CTO/şüpheci/ürün sahibi APPROVE-WITH-CONDITIONS. Çatışmalar: dara yardımcısı kaldı (ürün kararı → PO; şüpheci "gereksiz" demişti); hedef gramaj YALNIZ analiz GreigeGsm (şüpheci: teorik formül doğrulanmamış, sipariş FabricGramaj'da birim karışıklığı); oransal kg'dan gramaj yok; müşteri adı `useGetCurrentAccountById` (şüpheci: liste kancası yalnız ilk 20 kaydı getiriyor → çoğu siparişte boş kalırdı); kontrolör = oturumdaki kullanıcıysa adı, değilse boş (üye listesi admin uç noktası).
- **Ne yapıldı:** ayar `production.weaving.defaultTareKg` (0..100, mevcut quality-settings uç noktası, `defaultTareIsDefault`); Brüt/Dara modu (kayıt yok, yalnız net gider; ayar >0 ise açık); kg alanları "Net kg"; `WeavingCalculator.MeasuredGsm` C#+TS aynı altın testler (50/100/160 → 312,5); ±%5 uyarı (engellemez); muayene/etikette müşteri, kontrolör, hedef gramaj; rapor ve top seti detayında gramaj. Migration yok. — `d273b8cd`.
- **Doğrulama:** backend birim 4594 geçti; frontend 1497/1497.
- DEV: 1.0.2.1035 (G5 + G4 düzeltmeleri), health 200.

### 12. G6 — Küçük kalemler (kurul onayı, uygulamada)
- Kurul (CTO/şüpheci/DBA/PO, APPROVE-WITH-CONDITIONS). Kararlar: UseOrderWidth → hesap eni boşsa ham en (tek yardımcı, DTO yolu dahil), kutu gizli, kolon kalır; çözgü sekmesinde ham/mamul en+gramaj, aktarım yalnız boşları doldurur (eski F11 üzerine yazıyordu — bilinçli fark); notlar: çözgü analizinde Description = "Çözgü açıklaması", WarpNotes/WeftNotes yalnız kumaş analizinde (CHECK `CK_WeavingAnalysis_NotesKind`, migration `WeavingAnalysisNotesG6`); gizli iplik alanları düşürüldü (teknik borç); rapora En/Puan/100 m²/Ek sayısı; levent/dok etiketi mevcut verilerle (kumaş/iplik adı yok — PO istemişti, backlog; son söz kullanıcıda); kısayollar G6 dışı (PO, backlog; CTO'nun AltGr kuralları not edildi).

## Kararlar
- Düşük öncelikli UX bulguları bırakıldı: dil yüklenirken gösterge yok (1–4 sn), de'de stok listesi araç çubuğu 1440'ta 2 satır, 375'te taşma (önceden de var), landing dil menüsü uygulamadan ayrı (ar/ur orada görünür).

## Açık kalanlar / sonraki adım
- ar/ur yayında (beta). Kalan: 375 px / çekmece / bildirim / yazdırma önizlemesi RTL kontrolü yapılmadı; takvim gün etiketinde "Today" İngilizce; ar için _few/_many çoğul biçimleri (test şu an yalnız en anahtarlarına izin veriyor).
- Menüde iki adres aynı Projeler sayfasını açıyor (/finance/project ve /finance/projects) — birini kaldırma kararı kullanıcıda.
- Sunucu mesajları: 823 kod çevrildi; 252 istisna + doğrulama (FluentValidation, PropertyName kodlu) mesajları hâlâ sunucu dilinde → backend'de MapErrorCode/parametreli hata (ayrı kurul).
- Anadil kontrolü: cari/fiş/irsaliye karşılıkları, ÖTV/ÖİV kısaltmaları, parçalı cümleler.
- Dokuma eksik listesi: ~~levent hataları~~ (G3 tamam, madde 7), ~~kumaş kontrol tartım/en~~ (G4 tamam, madde 9), ~~dok kontrol alanları~~ (G5 tamam, madde 11), küçükler (G6 uygulamada), büyükler (F8).
