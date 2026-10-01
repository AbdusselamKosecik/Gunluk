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
