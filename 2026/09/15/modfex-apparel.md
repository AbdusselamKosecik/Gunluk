# modfex-apparel — 2026-09-15

## Bağlam
5 Avalonia iskeleti (bantsayim, bantdurumekrani, depo, paketleme, sevkiyat) "Ilk iskelet" durumunda.
Hedef: referans WPF uygulaması (`X:\Gitlab\fredericTr\paketlemevesevkiyat\PaketlemeVeSevkiyat`) ve
`İç Giyim Üretim Planlama Uygulaması` tasarımları baz alınarak tüm uygulamaların tasarımını çıkarmak (brainstorming).

## Yapılanlar

### 1. İnceleme (salt okuma)
- **Neden:** Tasarım kararları referans uygulama, tasarım dosyaları ve Sentez DB gerçeğine dayanmalı.
- **Ne yapıldı:** 3 paralel inceleme:
  - Referans WPF: Meta_User MD5(UTF-16LE, trim, büyük hex) login; Erp_Box/BoxItem/BoxItemVariant; SP'ler
    `UZM_Sevkiyat_BarcodeProcess(2)`, `UZM_Sevkiyat_BoxRead`, `UZM_Sevkiyat_Sayim_BoxRead` (gövdeleri repoda yok);
    1. kalite = siparişe bağlı koli, "Tekleme" (…TEK01) = 2K-Giyilebilir/2K-Giyilemez/3K; siyah+beyaz ikili mantığı YOK;
    sevk irsaliyesi ReceiptType 120; tartı seri port (`+ 45.32kg`, `= 1.12F`); Output.prn raw etiket (repoda yok).
  - Tasarım: Suite sekme 3 Hammadde, 4 Bant Kabul, 5 Paketleme, 6 Sevkiyat (açık tema, #b4457a, IBM Plex);
    TV Panosu 4 döner ekran (koyu tema, bant kartları % renkli). Login ve dil seçici tasarımda yok.
  - DB ModaSima2026 (100.73.123.69, sadece SELECT): `Sentez/147963` hash doğrulandı (4EC62C40979EF55034807B9E2E1B044B);
    referansın UD_ kolonları ve UZM_Sevkiyat_* SP'leri YOK; sipariş–iş emri bağlantısı boş; Erp_RecipeItem 30.440 satır;
    sentezservis Sentez login kullanmıyor (kendi kullanicilar tablosu, Argon2id).
- **Komutlar:**
  ```bash
  sqlcmd -S 100.73.123.69 -U sa -P "***" -d ModaSima2026 -C -W -Q "SELECT ... FROM sys.tables ..."
  ```

### 2. Tasarım kararları ve spec
- **Ne yapıldı:** Soru-cevapla kararlar alındı, 8 bölüm tek tek onaylandı, spec yazıldı.
- **Dokunulan dosyalar:** `bantsayim/docs/superpowers/specs/2026-09-15-modfex-uretim-uygulamalari-design.md`
- **Commit:** bantsayim `862d0c4` — Modfex uretim uygulamalari tasarim dokumani (spec)

## Kararlar
- Doğrudan SQL (API yok); iş kuralları `UZM_` stored procedure'lerde (yaklaşım A).
- Veri: Sentez tabloları + UD_ kolonları + UZM_ tabloları (UZM_Ayar, UZM_Bant, UZM_BantKabul, UZM_Paketleme, UZM_HammaddeIs, UZM_KoliAcma, UZM_SetEslesme, UZM_Mesaj, UZM_DbSurum).
- Sipariş = Erp_OrderReceipt, Order = Erp_WorkOrder. Aynı kombinasyon için ikinci kayıt yok (UNIQUE index).
- Bantlar UZM_Bant. Bant kolisi kapanınca üretimden giriş fişi (Bant ara depo).
- Paketleme: Box Aç = bant kolisi okut (siyah ve beyaz order kolileri); siyah/beyaz barkod okutunca aynı bedende açık siyah+beyazdan 1 set;
  set ayrı stok kartı, bileşenler Sentez reçetesinden; kalite anahtarı 1K/2K-G/2K-GZ/3K, 2K/3K da set olarak ayrı kutuya.
- Hammadde: iş emrine bağlı Sentez fişi, onay UD_ alanlarında.
- Ortak kod her repoya kopya (`Ortak/`, SURUM.txt). TR/EN/AR her ekranda, AR RTL.
- Donanım: Android el terminali (klavye gibi okuyucu), seri port tartı (Desktop), ağ etiket yazıcısı TCP 9100.
- TV "Giren" = banta atanmış order adedi. bantdurumekrani girişsiz, salt-okuma view'ler.
- Geliştirme DB: ModfexTest (ModaSima2026 kopyası). Canlıya DDL yok.
- Elle adet ekleme yok (sadece barkod).

## Açık kalanlar / sonraki adım
- Kullanıcı spec'i gözden geçirecek; onaydan sonra writing-plans ile 1. adım (ModfexTest + temel şema) planı.
- ModfexTest kopyasını kim açacak (kullanıcı mı, ben mi) netleşmedi.
- Doğrulanacaklar: ReceiptType numaraları, reçete/set bileşen yapısı, lot tablosu, şoför TC alanı.

---

## Tur 2 — Tüm uygulamaların ekranları (ekran aşaması)

### Bağlam
Kullanıcı: "şimdilik tüm projelerin ekranlarını tamamlayalım". Karar: giriş ve seçim listeleri gerçek DB'den
**salt-okuma**, koli/kutu/hareket/irsaliye kayıtları **bellekte** (DB'ye yazma yok). SP/fiş/tartı/yazıcı sonraki aşama.

### 3. Ortak kod (`Ortak/`, namespace `Modfex.Ortak`, SURUM 1) — bantsayim'de yazıldı, 4 repoya birebir kopyalandı
- **Neden:** 5 uygulamada aynı giriş/dil/tema/kabuk; karar "her repoya kopya".
- **Ne yapıldı:**
  - `Veri/`: `AyarDeposu` (%LOCALAPPDATA%\Modfex\<kod>\ayarlar.json, SQL şifresi Windows'ta DPAPI, Android'de şimdilik b64),
    `Veritabani` (SqlClient, Encrypt+TrustServerCertificate), `SentezGiris` (Meta_User, MD5(UTF-16LE(trim)) hex; IsUserRole=1 ve NULL şifre reddedilir),
    `Oturum`, `Gunluk` (log/yyyy-MM-dd.log), `UretimSorgulari` (sipariş arama, siparişe bağlı order — bağlantı yoksa açık order'lar + uyarı, beden satırları, barkod çözme).
  - `Dil/`: `Ceviri` (TR/EN/AR sözlük, `Surum` sayacı), `{o:T Anahtar}` markup extension (ReflectionBinding → `Surum` + converter), `OrtakMetinler`.
  - `Kabuk/`: tek pencere; üst bar (logo, başlık, TR|EN|ع, kullanıcı@şirket, ⚙, çıkış), gezinme yığını, toast; AR'de `FlowDirection=RightToLeft`.
  - `Giris/`: Ayarlar ve Giriş ekranları. `Tema/Tema.axaml`: Suite paleti (#b4457a), kart/tablo/rozet/hap/buton sınıfları, Tv* koyu renkler.
  - `Kontroller/`: `OkutKutusu` (Enter, 300 ms çift okuma filtresi, odak geri), `DuyarliPanel` (ağırlıklı yan yana / dar ekranda alt alta), `SiparisOrderSecici(+View)`.
  - Fontlar: IBM Plex Sans/Mono + IBM Plex Sans Arabic (Assets/Fonts, gömülü).
- **Öğrenilenler (Avalonia 12):** `{Binding [key]}` indexer bildirimi ("Item[]") çeviri yenilemiyordu → `Surum` property'si;
  Dapper'da record ctor tip uyuşmazlığı patlıyor (RecId int) → `{get;init;}` class; `Watermark` obsolete → `PlaceholderText`;
  `CalendarDatePicker.SelectedDate` `DateTime?`; ProgressBar MinWidth 200; null ComboBox öğesi çizilmiyor.
- **Doğrulama aracı (repoda değil):** scratchpad'de Avalonia.Headless + Skia konsol projesi; gerçek App'i pencere açmadan çalıştırıp VM komutlarıyla akışı sürer, PNG kaydeder. Her uygulama TR/AR/EN + dar ekran + hata toast'ı ile kontrol edildi.

### 4. bantsayim — `5ab3494`
- Liste (arama, bant, tarih aralığı) → Yeni (bant butonları + sipariş/order) → Detay (Suite sekme 4: beden tablosu, okut, sil modu, Koli Oluştur, oluşturulan koliler + etiket tekrar yazdır).
- Kurallar bellekte: barkod order'da olmalı, order miktarı aşılamaz, sil modu, boş koli kapanmaz, kombinasyon tekrarı açılır. Koli kodu `B{n}-{WO}-{NNN}`, barkod `P1`+kod. Barkodsuz varyant için `V{InventoryVariantId}`.

### 5. paketleme — `8f9f442` (paralel ajan)
- Liste → Yeni (sipariş + order + isteğe bağlı **set eşi order**) → Detay 3 sütun: Box Aç (okutulabilir/açılan bant kolileri), açık miktarlar
  (set: siyah/beyaz açık, eşleşen, kalan, **Fark**; tek ürün), kalite sekmeleri 1K/2K-G/2K-GZ/3K, kalite başına açık depo kutusu, brüt/net ile kapatma.
- Demo: her order için gerçek bedenlerden bant kolileri üretilir (paketleme ayrı süreç). Set bileşeni ileride Sentez reçetesinden gelecek.

### 6. sevkiyat — `f8f060a` (paralel ajan)
- Fiş listesi → Yeni (sipariş + depo Mamul/2K/3K + tarih) → Sevkiyat ekranı (Suite sekme 6: KPI, ilerleme, tamamlandı bandı, şoför/TC/plaka, sil modu).
- P1/P2 kırpma, P4 palet açma, referanstaki -1..-4 hata anlamları; fiş no `SVK-yyMMdd-NNN`. Demo koliler siparişin gerçek satırlarından.

### 7. depo (Hammadde) — `98ea193` (paralel ajan)
- Liste → Yeni → Detay (Suite sekme 3: işlem tipi, miktar, teslim veren/alan, `LOT*25` okutma, hammadde tablosu Ver/Extra/Geri Al, hareketler + onay/sil).
- **Önemli DB bulgusu (spec §3.7):** gerçek reçete `Erp_RecipeItem.OwnerInventoryId` ile modele bağlı (1.121 ürün; açık 737 order modelinin 706'sında var).
  `RecipeType` 1=kumaş (KMS-), 2=aksesuar (AKS-). Birim: `UnitId` → `Erp_InventoryUnitItemSize` (UnitFactor/UnitDivisor) → `Meta_UnitSetItem.UnitCode`; ana birime = miktar × Divisor / Factor.
  `InventoryVariantIds` doluysa satır sadece o varyantlara (ör. beden) uygulanır. `Erp_Recipe`, `Erp_WorkOrderItemRecipe` boş, `WorkOrder.RecipeId` NULL.
  Sorgu: `depo/Depo/Ekranlar/Veri/ReceteSorgulari.cs`. 4460 BEYAZ → 19 gerçek kalem.
- **Lot verisi yok:** Lot/Batch tablosu yok, PartyNo her yerde boş, `HasPartyNo`=0 → lotlar ekran aşamasında demo.

### 8. bantdurumekrani (TV) — `0f09978` (paralel ajan)
- Girişsiz, koyu tema, 1920×1080 tasarım + Viewbox; 4 döner ekran (Bant Giriş/Çıkış 5×2 kart, Paketleme Durumu, Sipariş Durumları, Order Akış), saat, noktalar, dil.
- Klavye: F11 tam ekran, Esc, ←/→, 1–4, Space döngü durdur, L dil. `ITvVeriKaynagi`: gerçek order/sipariş adları + deterministik demo ilerleme; DB yoksa demo + "bağlantı yok" rozeti.

### Doğrulama
```bash
for r in bantsayim paketleme sevkiyat depo bantdurumekrani; do dotnet build <App>.Desktop -v q; done   # hepsi 0 hata, 0 uyarı
diff -rq bantsayim/BantSayim/Ortak <repo>/<App>/Ortak                                              # hepsi aynı
git rev-list --count origin/main..main                                                              # hepsi 0 (push edildi)
```
Android derlenmedi (makinede android workload yok).

## Kararlar (tur 2)
- Ekran aşamasında DB'ye yazma yok; bellek depoları `Ekranlar/Veri/*Deposu.cs`, kurallar ileride `UZM_*` SP'lerine taşınacak olanlarla aynı.
- Set eşi şimdilik yeni paketleme ekranında elle seçiliyor; spec'e göre Sentez reçetesinden bulunacak.
- Reçete kaynağı `Erp_RecipeItem.OwnerInventoryId` (spec §3.7 güncellenmeli).

## Açık kalanlar / sonraki adım
- Kullanıcı ekranları gözden geçirecek (gerçek Windows'ta `dotnet run --project <App>.Desktop`).
- 420 px'de ortak üst bar sağdan taşıyor (Ortak düzeltmesi → 5 repoya senkron).
- ModfexTest DB kopyası + temel şema (spec yapım sırası 1). Android workload kurulumu.
- Spec'e Ek A: reçete/birim/lot bulguları.
