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

### 13. G6 uygulandı + G5 UX düzeltmeleri — 1.0.2.1036
- G6 (`2730187f`): `EffectiveCalcWidth` (hesap eni boşsa ham en; DTO yolu dahil), UseOrderWidth kutusu gizli (TD-019), çözgü analizinde ham/mamul en+gramaj, `WarpNotes/WeftNotes` yalnız kumaş analizinde (`CK_WeavingAnalysis_NotesKind`, migration `20261022023250_WeavingAnalysisNotesG6`), rapora En/Puan/100 m²/Ek sayısı + "Kontrol tarihi", levent ve dok etiketi (mevcut liste uçları `filter=id=` ile; gerçek sunucuda 200 doğrulandı). Kısayollar backlog.
- G5 UX (`496205dc`): ana sayfa 375 px (`max-sm:overflow-x-clip` — hidden yapışkan header'ı bozuyordu), etikette ölçülen gramaj (hedef: x), top seti olan muayenede "Yeniden aç" kapalı, rapor dok görünümünde muayene kg/gramajı (aynı SQL'de LEFT JOIN).
- UX post-check G6: PASS. Not: açık kalmış eski sekme eski bundle'ı çalıştırır (normal SPA davranışı).

### 14. Yetki: üretim create/update/delete varsayılanları eksikti — 1.0.2.1037
- **Bulgu (G7 güvenlik incelemesi):** `DefaultPermissionSeeder` üretim için yalnız read/manage/scan-correct içeriyordu; 25 update + 16 delete + 7 create ucu 10-21 dokuma commit'lerinden beri süper admin dışında 403. Tüm UX kontrolleri admin@vuo.app (süper admin) ile yapıldığı için görünmedi. Dev DB `public.default_role_permissions` ile doğrulandı.
- **Kurul:** CTO/şüpheci APPROVE-WITH-CONDITIONS, güvenlik PASS-WITH-FIXES. Şüpheci ek buldu: ProductionController'da ~100 yazma ucunun yalnız ~12'si yetki kontrolü yapıyor (TD-020, ayrı iş).
- **Ne yapıldı (`2baa8b01`):** production create/update → owner/admin/manager/user, delete → owner/admin/manager; şirket geneli ayarlar (top deposu, kesim/kalite ayarları) ve kalite sınıfı tanımları → manage; muayene hatası ve levent hatası silme → delete. API-key kataloğu değişmedi. 10 dk izin önbelleği kabul. Açılışta seeder eksik satırları ekledi (dev: create 4, update 4, delete 3 rol).
- **Açık:** süper admin olmayan hesapla tarayıcı doğrulaması yapılamadı (şifre yok); birim testleri kapsıyor.

### 15. G7 — kurul: (a1) Sipariş Bilgileri + (a2) Ekler onaylı, F8a (tezgahlar arası planlama) BLOCK
- Şüpheci F8a'yı blokladı: tahsis kuyruk kaydında tutuluyordu ama tezgaha takınca kuyruk kaydı siliniyor → tahsis dokuma başlarken kayboluyor; formül kesimleri iki kez düşüyor; levent boyu zaten fiziksel tahsis; eski Sentez'de dokumaya özel karşılığı yok. G7'den çıkarıldı (kullanıcı isterse override + yeniden tasarım). Çok tezgahta aynı emrin yükünün iki kez sayılması ayrı düzeltme (levent kalanıyla sınırlama, şemasız).

### 16. G7 dilim 1 — Sipariş Bilgileri sekmesi — 1.0.2.1038
- `ceb6e650`: `IOrderLineQueryService` (Shared port, Orders uygulaması; yalnız satış siparişi tipleri 1/5202/5206), uç `GET production/weaving/analyses/{id}/orders?status=` (production:read + handler'da order:read → 403; çözgü → 400). Fiyat/tutar yok; metre toplamları tüm filtreli kümeden; 500 satır + truncated. Eski Sentez "Kapalı" toplam hatası düzeltildi. Index `IX_OrderReceiptItem_TenantId_InventoryId` (migration `20261022030557_OrderItemInventoryIndexG7`). Güvenlik post-check PASS.
- Sınırlama: sipariş miktarı birim dönüşümsüz metre kabul edildi; Orders sevk miktarı yazmadığı için "Sevk" 0.

### 17. Çok tezgahta aynı emrin kalan/bitiş çift sayımı düzeltildi — 1.0.2.1039
- **Neden:** G7 F8a'yı bloklarken şüphecinin bulduğu gerçek hata: aynı emir birden çok tezgaha takılabiliyor (takma yalnız leventi kontrol ediyor) ve `LoomViewBuilder` her tezgaha emrin TÜM kalanını yazıyordu → N tezgahta yük/bitiş ~N kat, arkadaki kuyruklar kayıyordu.
- **Kurul:** CTO/şüpheci/ürün sahibi APPROVE-WITH-CONDITIONS. Kritik düzeltmeler: kuyruk kuralında aynı tezgahın kendi leventi de düşülür (aynı emir A'da takılı + A kuyruğunda olabiliyor); "takılı" kaynağı `LoomState.CurrentBeamId` (elle Mounted yapılan levent sayılmaz); levent kartının bitişi kumaş metresiyle.
- **Ne yapıldı (`db65cf28`):** takılı: kalan = min(emir kalanı, levent kalanı/(1+çekme)); kuyruk: max(0, emir kalanı − tüm takılı dokuma leventlerindeki kumaş); tek `ShrinkFactor` yardımcısı; DTO'ya ek `orderRemainingM`; kartta "Kalan (bu tezgah, tahmini)" + "Sipariş kalanı", "Diğer tezgahlarda karşılanıyor", "Levent bitti"; pano/kuyruk/tezgah durum raporu (ekran + Excel) aynı etiket; 11 dil (`loomfix.json`). Şema yok.
- **Doğrulama:** backend birim 4771 geçti; frontend 1569/1569 (altın senaryolar 1000 m emir, A/B levent 600/400, A 100 m kesince A 500, B 400, kuyruk C 0).
- **İki oturum çakışması:** Yeniden başlatma sonrası aynı konuşma iki pencerede (saas-erp-c2 ve saas-erp-fd) devam etti; iki ajan aynı dosyalara yazdı. Oturumlar arası mesajla iş bölümü: bu oturum çift sayım düzeltmesi, diğeri G7 Ekler (`e6fc32ae`). Tek dağıtım: 1.0.2.1039 (Docker Desktop yeniden başlatma sonrası kapalıydı, açılıp tekrar denendi).
- **Açık:** UX post-check (pano/kuyruk/rapor) sürüyor; G7 Ekler post-check'leri diğer oturumda.

### 18. G7 dilim 2 — Ekler (dokuma analizi + dokuma emri) — 1.0.2.1039
- **Neden:** Sentez analiz formunda ve dokuma emrinde "Ekler" sekmesi (numune fotoğrafı, teknik çizim, talimat). VuoApp'te yoktu.
- **Kurul:** CTO/PO/DBA APPROVE-WITH-CONDITIONS, güvenlik PASS-WITH-CONDITIONS (ön), skeptic (a2) onay. Kota servisi hiç uygulanmamış → 25 MB + sahip başına 50 dosya (TD-021).
- **Ne yapıldı (`e6fc32ae`):** `production.WeavingAttachment` (hard delete, tek sahip CHECK; migration `20261022033250_WeavingAttachmentsG7`); ortak yükleme politikası `VuoApp.Shared/Files/AttachmentUploadPolicy` (uzantı + magic bytes, sunucu ContentType, svg/html/xml/js red, dosya adı temizleme); yazma `production:manage`, okuma `production:read`; yanıtta ObjectKey yok; 15 dk imzalı URL (görsel inline, diğerleri attachment); silme önce depolama (yok = başarı); silinmiş sahibin ekleri erişilemez; `EntityAttachmentsTab` analiz + kayıtlı Dokuma emri (emirde analiz ekleri salt okunur); 9 hata kodu 11 dil. `MinioFileService.DeleteAsync` artık yalnız "nesne/bucket yok"u başarı sayar.
- **Güvenlik post-check:** PASS; Low-3 (kilit SQL'inde TenantId) uygulandı `f5f0ba33`. Low-1 (imzalı URL'de bucket/anahtar görünür, aynı tenant) kabul; Low-2 (açıklamada & → &amp; görünümü, genel SanitizationBehavior) ayrı iş.
- **Koordinasyon:** aynı depoda ikinci oturum (saas-erp-c2) çift sayım düzeltmesini aldı (madde 17); dosya sahipliği bölündü, ortak dosyalarda (changelog, tasarım dokümanı) yalnız kendi satırlarımız stage edildi (`git update-index --cacheinfo`), tek dağıtım 1039 c2 tarafından.
- **Not:** `api-errors.test.ts` git worktree içinde SyntaxError ile düşüyor (ortam; önceki commit'te de aynı), ana ağaçta 35/35 geçiyor.

### 18. Dil artıkları + tezgah panosu UX notları — 1.0.2.1040
- `461233b2`: ar için 37 çoğul anahtara _zero/_two/_few/_many (i18n testi CLDR eklerine en `_one/_other` tabanına göre izin verir); takvim gün etiketleri ("Today, …", "…, selected") 11 dilde; tezgah kartı/detayında dokunma+klavye ile açılan bilgi düğmesi (44 px, kart `article` + uzanan başlık linki), levent satırı "kalan (çözgü)", açıklamaya çekme dönüşümü; tezgah durum raporuna (ekran+Excel) "Sipariş kalanı". Frontend 1579/1579.
- Çift sayım UX post-check: PASS-WITH-NITS (DEV'de tek tezgah → çok tezgah, "Levent bitti", kuyruk satırı canlıda görülemedi; birim testlerle kapsandı). Notlar bu maddede kapatıldı.

### 19. TD-020 — ProductionController'daki 88 kontrolsüz yazma ucu (izleyici dahil herkese açıktı)
- **Kurul:** CTO/şüpheci/ürün sahibi APPROVE-WITH-CONDITIONS, güvenlik PASS-WITH-CONDITIONS. Şüpheci: audit log yalnız API-key yazımlarını tutuyor → "son 30 günde izleyici yazdı mı" kontrolü yerine üyelik tablosu sorgusu. Dev: izleyici/tanımsız rol yok (owner 13, admin 2, user 2). **Canlıda aynı kontrol kullanıcıda (T6) — canlıya dokunulmadı.**
- **PO kararları:** ön maliyet, BOM reçeteleri, laboratuvar deneme onayı → manage; emir durumu → update (kullanıcı iptal edebilir, kısıtlama backlog); fason sevk/iade → create.
- **Ne yapıldı (`cb6c2dcf`):** yöntem adına göre manage 29, delete 16, create 21, update 21, read 1 (salt okuma POST); `ProductionEndpointPermissionContractTests` (Production derlemesindeki her yazma ucu yöntem düzeyinde [RequirePermission], eylem `DefaultPermissionSeeder`'dan, 100 uçluk sabit tablo, boş istisna listesi); barkod ekranında 403 ayrı mesaj ("okutma kaydedilmedi"); genel "yetkiniz yok" metni 11 dil (`CommonLabels.forbidden`); TD-020 kapandı + TD-020a..f; kiracı yöneticilerine sürüm notu.
- **Doğrulama:** backend birim 4913 geçti; güvenlik post-check PASS (149 yazma ucunun tamamı kontrollü). Frontend'de 4 kırmızı test diğer oturumun yarım RTL etiket işinde.
- **İki oturum:** diğer oturum (saas-erp-fd) RTL bulgularını düzeltiyor (axios-instance genel toast dalı, etiket sayfaları, 404, header, rtlfix.json); dosyalar ayrıştırıldı. 1.0.2.1041 ikisini birlikte çıkaracak.

### 20. RTL/i18n ekran kontrolü bulguları düzeltildi — 1.0.2.1041 (`7c7c2aca`)
- **Neden:** ar/ur post-check (UX, Chrome) bulguları: ipuçlarında "soldan" gibi yön ifadeleri, Arapça etiket sayfasında tarih/değerlerin karışması, 404 sabit Türkçe, axios genel hata toast'unda İngilizce sunucu metni, 375 px'te tablo alt satırı/arama taşması, mobil çekmece Esc ile kapanmıyor, klasik menü RTL'de ters kayıyor, şirket/kullanıcı adlarında noktalama ters.
- **Ne yapıldı:** ar `b10/b14/b20/b25/c06` + ur `b04/b10/b14/b20/b25/c06` ipuçları yönsüz ("listeden"); etiket sayfalarında (`inspection_label`, `beam_label`, `cut_label`, `label_print_shell`) `dir=ltr` yalnız etiket kartında + değerler `<bdi>`; `404.tsx` i18n (`assets/i18n/<dil>/rtlfix.json`, 11 dil); `axios-instance.ts` yedek toast `ApiFallback.generic`; `data-table.tsx` duyarlı alt satır/arama; `admin_user_detail.page.tsx`; `sidebar.tsx` Esc + RTL kayma; header/user-menu/TenantSwitcher/TenantPickerModal `<bdi>`; testler + changelog satırı.
- **Komutlar:** `cd src/frontend && npm run test` → 209 dosya / 1601 test yeşil; `git push origin HEAD:dev`.
- **Dağıtım:** diğer oturum 1.0.2.1041'i `7c7c2aca` üzerinde (TD-020 `cb6c2dcf` dahil) çıkarıyor.
- **Açık:** 375 px düzeltmeleri kod analiziyle yapıldı, canlıda yeniden ölçülecek (stok listesi, kullanıcı detayı, boyahane raporu, Arapça etiket, 404, çekmece Esc). `401.tsx` de sabit Türkçe — dokunulmadı.

## Kararlar
- Düşük öncelikli UX bulguları bırakıldı: dil yüklenirken gösterge yok (1–4 sn), de'de stok listesi araç çubuğu 1440'ta 2 satır, 375'te taşma (önceden de var), landing dil menüsü uygulamadan ayrı (ar/ur orada görünür).

## Açık kalanlar / sonraki adım
- ar/ur yayında (beta). Kalan: 375 px / çekmece / bildirim / yazdırma önizlemesi RTL kontrolü yapılmadı; takvim gün etiketinde "Today" İngilizce; ar için _few/_many çoğul biçimleri (test şu an yalnız en anahtarlarına izin veriyor).
- Menüde iki adres aynı Projeler sayfasını açıyor (/finance/project ve /finance/projects) — birini kaldırma kararı kullanıcıda.
- Sunucu mesajları: 823 kod çevrildi; 252 istisna + doğrulama (FluentValidation, PropertyName kodlu) mesajları hâlâ sunucu dilinde → backend'de MapErrorCode/parametreli hata (ayrı kurul).
- Anadil kontrolü: cari/fiş/irsaliye karşılıkları, ÖTV/ÖİV kısaltmaları, parçalı cümleler.
- Dokuma eksik listesi: ~~levent hataları~~ (G3 tamam, madde 7), ~~kumaş kontrol tartım/en~~ (G4 tamam, madde 9), ~~dok kontrol alanları~~ (G5 tamam, madde 11), ~~küçükler~~ (G6 tamam), büyükler G7: Sipariş Bilgileri tamam, Ekler uygulamada, F8a BLOCK (madde 14-16)
