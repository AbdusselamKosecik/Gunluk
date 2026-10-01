# bantsayim — 2026-10-01

## Bağlam
Üretim bant terminali çalışıyor (okutma, 1./2. kalite box'ları, box başına 10 fişi). Hedef: box kapanınca
Zebra yazıcıya **10×10 cm paket etiketi** basmak. Kullanıcı seçimleri: ZPL, ağ yazıcısı (IP + 9100), bant box
etiketi, box kapanınca otomatik + tekrar yazdır.

## Yapılanlar

### 1. Kütüphane kararı — bağımlılıksız ZPL
- **Neden:** Resmi Zebra.Printer.SDK yalnızca MAUI hedefleri (android/ios/windows) için var, Linux yok.
  BinaryKits.Zpl.Label (MIT) net8 grubunda SixLabors.ImageSharp ≥3.1.12 çekiyor; Six Labors Split License'a göre
  ciro eşiği aşılırsa ücretli. Bu yüzden uygulamaya kütüphane eklenmedi.
- **Ne yapıldı:** ZPL'i kendimiz üretiyoruz. BinaryKits.Zpl.Viewer yalnızca scratchpad'te PNG önizleme için kullanıldı.

### 2. Ortak/Donanim (Ortak SURUM 3)
- **Dokunulan dosyalar:** `BantSayim/Ortak/Donanim/ZplEtiket.cs`, `BantSayim/Ortak/Donanim/ZplYazici.cs`, `BantSayim/Ortak/SURUM.txt`
- **ZplEtiket:** mm cinsinden konum. Zebra nokta/mm değeri 203 dpi için 8, 300 dpi için 12 (100 mm = 800 / 1200 nokta).
  - Başlık: `^XA^CI28^PW^LL^LH0,0`.
  - `Metin`: `^A0` + isteğe bağlı `^FB` (kaydırma/hizalama), `^FR` (ters yazı), `^FH_` (kaçırma: `^`→`_5E`, `~`→`_7E`, `_`→`_5F`).
  - `Barkod128`: `^BY{2|3}^BCN,h,N,N,N`. `Barkod128GenislikMm` ile ortalanır: (11·(n+2)+13)·modül.
  - `Kutu` / `Cizgi`: `^GB`.
- **ZplYazici:** TcpClient ile UTF-8 gönderim. Ayarlardaki IP/port kullanılır, zaman aşımı 5 sn.
  `Tanimli` = IP dolu mu.

### 3. Ayarlar'a DPI
- **Dokunulan dosyalar:** `Ortak/Veri/Ayarlar.cs` (`YaziciDpi` = 203), `Ortak/Giris/AyarlarViewModel.cs`,
  `Ortak/Giris/AyarlarView.axaml` (NumericUpDown 203–300, adım 97), `Ortak/Dil/OrtakMetinler.cs` (`YaziciDpi`).

### 4. Box etiketi düzeni ve verisi
- **Dokunulan dosya:** `BantSayim/Ekranlar/Veri/BoxEtiketi.cs`
- **Düzen (mm):**
  - Barkod: y=4, yükseklik 20, ortalı. Okunur kod: y=26.
  - Çizgi: y=33.
  - "İŞ EMRİ" ve iş emri no (8 mm): y=35.5 / 40.
  - Kalite rozeti: x=62, 33×13. 2. kalitede dolu kutu + `^FR`.
  - Model: 2 satır, 4 mm. Model adı kodla başlıyorsa kod tekrar yazılmaz.
  - Renkler: y=59. Çizgi: y=64.
  - Beden dağılımı: 3 satır, 4.5 mm. Çizgi: y=82.
  - Alt kısım: "ADET" + toplam (13 mm). Sağa yaslı: BANT n, kapanış zamanı, FİŞ no.
- **Sorgu:** `BilgiAsync(companyId, boxCode)`.
  - Kaynak tablolar: UZM_UretimBox + Meta_User + Erp_WorkOrder + Erp_InventoryReceipt + ilk BoxItem'ın Erp_Inventory kaydı.
  - Renkler: Variant1 için STRING_AGG.
  - Bedenler: Variant2, Variant2Order sırasıyla, SUM<>0.
- **BasAsync:** Bilgiyi okur, `Zpl(e, AyarDeposu.Gecerli.YaziciDpi)` üretir, `ZplYazici.GonderAsync` ile gönderir.

### 5. Ekran entegrasyonu
- **Dokunulan dosyalar:** `Ekranlar/OkutmaViewModel.cs`, `OkutmaView.axaml`, `YonetimViewModel.cs`,
  `YonetimView.axaml`, `UygulamaMetinleri.cs` (EtiketTekrar, EtiketBasildi, EtiketBasilamadi, YaziciTanimsiz)
- **Okutma ekranı:**
  - `KapatOnayla` başarılıysa ve iş emri değişince kapanan dolu box için (FisNo dolu) `EtiketBasAsync(otomatik)` çağrılır.
  - Hata alınırsa Gunluk.Yaz + "Etiket basılamadı" toast'ı gösterilir; box geri alınmaz.
  - IP boşsa otomatik basım sessizce atlanır, elle basımda hata gösterilir.
  - Üst barda "Etiketi yazdır: <son box>" düğmesi var.
- **Yönetim > Boxlar:** Seçili kapalı box için "Etiketi tekrar yazdır" düğmesi var.
- Not: BantKabulDetay'daki eski `EtiketYazdir` hâlâ yalnızca toast gösteren bir taslak; bu kapsamda dokunulmadı.

### 6. Test ve önizleme
- **Testler:**
  - `BantSayim.Tests/ZplTestleri.cs` (6 test): boyut, kaçırma, barkod mm→nokta, etiket içeriği, 2. kalite `^FR`/`^BY3`.
  - `EkranSorgulariTestleri.Box_etiketi_bilgisi`: canlıda son box, ZPL'i `%TEMP%\bantsayim-box-etiketi.zpl` dosyasına yazar.
- **Önizleme:** scratchpad `zplonizle` konsolu (BinaryKits.Zpl.Viewer, `ZplAnalyzer(new PrinterStorage())` +
  `ZplElementDrawer.Draw(elements, 100, 100, 8)`). PNG RGBA olduğu için beyaz zemine yapıştırıldı, zxingcpp ile okundu:
  Code128 `URT1-260930-001-0002`.
- **Komutlar:**
  ```bash
  MODFEX_DB_TEST=1 dotnet test BantSayim.Tests   # 53/53
  ```
- **Bağlantı:** Firma IP'si (192.168.0.2:1433) kapalıydı, VPN açıktı. `%LOCALAPPDATA%\Modfex\bantsayim\ayarlar.json`
  içinde Sunucu `100.119.104.122` yapıldı.
- **Commit:** `0bc52a1` — Zebra 10x10 box etiketi: ZPL uretici, TCP 9100, otomatik + tekrar yazdir (origin + github)

## Kararlar
- Uygulamada harici ZPL/Zebra kütüphanesi kullanılmıyor (lisans ve Linux nedeniyle).
- Etiket basılamazsa box kapanışı geri alınmaz; tekrar yazdır ile basılır.
- Nokta/mm değeri Zebra'nın standart değerleri: 8 / 12.

## Açık kalanlar / sonraki adım
- Gerçek Zebra'da test basımı yapılacak: Türkçe karakterler (`^A0` + `^CI28`) ve 10×10 hizalama kontrol edilecek. Font
  Türkçe harfleri basmazsa `^A@...E:TT0003M_.TTF` kullanılacak.
- Yazıcı IP'si Ayarlar'dan girilecek.
- Bant Kabul etiketi hâlâ taslak.
- Önceki turdan kalanlar: deneme kayıtlarının temizliği, TestModu sorusu, Hata Kodları "kartları yazdır" düğmesi,
  Ortak SURUM 3'ün diğer repolara taşınması, Ubuntu paketi.

## Ek — yazıcı test basımı denemesi
- **Ne yapıldı:** Kullanıcı yazıcı IP'si olarak 192.168.0.199 verdi. Bu IP `ayarlar.json` içine yazıldı (YaziciIp=192.168.0.199,
  port 9100, DPI 203). Firmaya dönüldüğü için Sunucu yeniden 192.168.0.2 yapıldı.
- **Sonuç:** Yazıcıya ulaşılamadı.
  - Ping cevabı: "Destination host unreachable" (cevabı veren 192.168.0.72, yani bu PC). ARP kaydı yok.
  - 80, 9100, 6101 ve 515 portları kapalı.
  - IP'de kimse yok: yazıcı kapalı ya da IP'si farklı.
  - Bu PC 192.168.0.72'de, aynı /24 ağında.
- **Tekrar deneme:** scratchpad `zplonizle` içinde `dotnet run -- URT1-260930-001-0002 --bas`
  (`BoxEtiketi.BasAsync` kullanılır, gerçek box etiketi basılır).

## Ek — test basımı ve içerik matrisi
- **Test basımı:** Yazıcı açıldı (192.168.0.199:9100), 1. kalite etiketi iki kez basıldı (`URT1-260930-001-0002`).
  Her seferinde ilk SQL bağlantısı TLS el sıkışmada zaman aşımına düştü, ikinci denemede geçti. Etiket basımında
  otomatik tekrar deneme henüz yok.
- **Matris (kullanıcı isteği):** Beden dağılımı satırı ve renkler satırı kaldırıldı. Yerine renk × beden matrisi geldi:
  satırlar renk, sütunlar beden, son sütun TOP.
  - Başlık satırı dolu kutu (`^GB` kalınlık = yükseklik) üstüne `^FR` ile ters yazılıyor.
  - Alan y=59–82 mm. Satır yüksekliği min(6, alan/(renk+1)), yazı satır yüksekliğinin 0,62 katı (2,2–3,8 mm arası).
  - Renk sütunu 24 mm, beden sütunları eşit.
  - `BoxEtiketBilgisi.Hucreler` = (Renk, Beden, Adet). Sorgu Variant1/Variant2 ile gruplar, sıralama Variant2Order → Variant1Order.
- **Dokunulan dosyalar:** `BantSayim/Ekranlar/Veri/BoxEtiketi.cs`, `BantSayim.Tests/ZplTestleri.cs`. Testler 53/53.
- **Commit:** `ad4d1d8` — Box etiketi: icerik renk x beden matrisi
- **2. kalite test basımı:** Gönderilemedi. Yazıcı yeniden ağdan düştü (ping: host unreachable).

## Ek — kalite rozeti
- **Kullanıcı isteği:** 1. kalitede etikete kalite yazılmayacak. 2. kalitede rozet siyah zemin üstüne beyaz yazı olacak (değişmedi).
- **Ne yapıldı:** `BoxEtiketi.Zpl` içinde rozet yalnızca `Kalite == 2` olduğunda basılıyor (dolu `^GB` + `^FR` ile "2. KALİTE").
  Test: 1. kalite etiketinde "KALİTE" geçmemeli. Matris başlığı da `^FR` kullandığı için `^FR` üzerinden kontrol yapılmadı.
- **Sonuç:** 53/53 test geçti. 2. kalite test etiketi yazıcıya basıldı (192.168.0.199).

## Ek — etiket İngilizce
- **Kullanıcı isteği:** Etiket tamamen İngilizce olacak.
- **Eşleme:** İŞ EMRİ → WORK ORDER, 2. KALİTE → 2ND QUALITY, RENK → COLOR, TOP → TOTAL, ADET → QTY,
  BANT n → LINE n, FİŞ → RECEIPT.
- **Değişmeyenler:** Renk ve model adları Sentez verisinden geldiği için olduğu gibi kalıyor (ör. LACİVERT).
- **Rozet:** "2ND QUALITY" yazısı rozete sığmıyordu; yazı yüksekliği 6 mm'den 5 mm'ye indirildi.
- **Dokunulan dosyalar:** `BantSayim/Ekranlar/Veri/BoxEtiketi.cs`, `BantSayim.Tests/ZplTestleri.cs`. Testler 53/53.
- **Test basımı:** 1. ve 2. kalite etiketleri basıldı (scratchpad `zplonizle -- <box> --bas12`). Yazıcıya ilk iki denemede
  bağlanılamadı (TCP connect zaman aşımı), üçüncü denemede gitti. Basılan 2. kalite etiketi rozet yazısı küçültülmeden önceki sürümdür.
