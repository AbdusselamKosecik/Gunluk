# sentezservis — 2026-09-23

## Bağlam
`docs/BitmisUrunSatinAlma` altındaki iki Excel ("Kopya E-Ticaret proje dosyasi(1).xlsx" ve
"GÜNCELLEME.xlsx") analiz edilip YENİ RAYİÇ sayfası uygulamaya ekran olarak taşınacaktı.
İstek: Dolar kuru, Proje kodu, Firma teklifi, Net/Brüt ağırlık elle; İçerik ve Ürün grubu listeden;
"+" ile sol taraftaki karşılaştırma listesine eklensin; düzenleme + geçmiş için DB; rayiçler
GÜNCELLEME.xlsx'ten, gram bazlı ortalama (30 gr = 20 ile 40'ın ortası). Menüye eklensin.

## Yapılanlar

### 1. Excel analizi
- **Neden:** Formülleri birebir taşımak için.
- **Ne yapıldı:** openpyxl ile formüller + önbellekteki sonuçlar okundu.
  - YENİ RAYİÇ: Malzeme gizli kodu = CONCATENATE(İçerik, Brüt, Grup); Rayiç = DÜŞEYARA('ESKİ RYÇ')
    (gram gram tablo, SÜTYEN 160 gr'a kadar uzatılmış); Vergi sonrası = Teklif + Rayiç×(0,065+0,39+0,01);
    Toplam USD = ×(1+0,12+0,07+0,05+0,10); Ürün maliyeti = Kur×USD; Tav.SF = CEILING(×4;10)−0,1;
    kargo 67, iade %10, komisyon = KDV'li×0,1/1,2, hizmet 5,49, stopaj = KDV'siz×0,02;
    Karlılık = KDV'siz/Toplam−1.
  - GÜNCELLEME.xlsx: YENİ FİYATLAR ve ESKİ FİYAT, 20 gr kırılımlı (20..120), DOĞAL/SENTETİK × SÜTYEN/ATLET/SLİP.
  - Kontrol: YENİ RAYİÇ'teki elle yazılmış rayiçler (115 gr → 4,08; 94 gr → 3,83) doğrusal
    enterpolasyon + 2 hane yuvarlama ile birebir çıkıyor.
  - Sheet1'deki ardiye/antrepo hesabı bu işle ilgisiz, alınmadı.

### 2. Backend
- **Ne yapıldı:** Migrasyon 018 (`rayic_tablolari`, `rayic_tablo_satirlari`, `rayic_hesaplari`,
  `rayic_hesap_gecmisi`; yeni tablo aktif, eski pasif tohumlandı). `RayicHesaplayici` (saf hesap,
  enterpolasyon; tablo dışı → uç eğimle uzatma + işaret), `RayicDeposu` (her yazma aynı transaction'da
  geçmişe tam JSON anlık görüntü), `RayicUclari` (`/api/rayic/...`, GirisIster, denetim `rayic.*`).
- **Dokunulan dosyalar:** `src/SentezServis.Core/Data/Migrations/018_rayic_hesaplari.sql`,
  `src/SentezServis.Core/Rayic/*`, `src/SentezServis.Host/Api/RayicUclari.cs`, `Program.cs`,
  `tests/SentezServis.Core.Tests/RayicHesaplayiciTestleri.cs`, `docs/rayic-hesabi.md`

### 3. Web ekranı
- **Ne yapıldı:** `RayicSayfasi.tsx/.css`, `api/rayic.ts`, rota `/rayic`, menüde yeni "Satın alma →
  Yeni rayiç" bölümü. Solda Excel yönünde karşılaştırma tablosu (proje = sütun, sabit etiket sütunu,
  karlılık renkli), sağda form + canlı önizleme (sunucudaki /hesapla), "Oranlar ve giderler" açılır
  bölümü, düzenle/geçmiş/sil düğmeleri, geçmişte değişen hücre vurgusu, "Bu sürüme dön",
  "Son değişiklikler"den geri getirme, rayiç tablosu penceresi.

### 4. Doğrulama
- **Komutlar:**
  ```bash
  dotnet test tests/SentezServis.Core.Tests            # 569/569
  cd web && npx tsc -b && npx oxlint ...                # temiz
  sqlcmd -S "(localdb)\MSSQLLocalDB" -I -i 018_...sql   # iki kez: idempotent
  ```
- Host yerelde LocalDB (RayicUi) ile, ERP/entegrasyon/mail/kasa/toplayıcı kapalı olarak açıldı;
  vite dev sunucusu geçici proxy config ile. Tarayıcıda 6230/6234 girildi → Excel ile aynı
  (%39,6 / %39,4); düzenleme, geçmiş, sil, geri getir denendi. Geçici DB'ler ve dosyalar silindi.
- Not: `sqlcmd` varsayılan QUOTED_IDENTIFIER OFF → filtreli index hatası verir; `-I` gerekir.
  Uygulamanın migrasyon çalıştırıcısı (SqlClient) etkilenmez.
- **Commit:** `03d224f` — Yeni rayic ekrani: bitmis urun satin alma karsilastirmasi

## Kararlar
- Rayiç 2 haneye yuvarlanır (Excel'deki elle yazılmış değerler böyle).
- 20 altı / 120 üstü gramda uçtaki eğimle uzatılır ve `*` ile işaretlenir.
- Rayiç kayıt anında dondurulur; tablo değişirse "güncel: X" uyarısı, düzenleyince güncellenir.
- Satış fiyatları (KDV'li/KDV'siz) isteğe bağlı ek alan: karlılık için şart (Excel'de proje başına ayrı).
- Oranlar proje başına JSON olarak saklanır, varsayılanlar Excel'deki değerler.
- Ortak dosyalardaki (Program.cs, App.tsx, Layout.tsx) başka oturumun commit'lenmemiş karşıt-kod
  satırları commit'e alınmadı (HEAD blob + yalnızca rayiç değişiklikleri `git update-index` ile staged).

## Açık kalanlar / sonraki adım
- Canlıya yayın: yeni paket + servis yeniden başlatılınca migrasyon 018 kendiliğinden uygulanır.
  Yeni appsettings anahtarı yok.
- Rayiç tablosunu ekrandan güncelleme (yeni sürüm yükleme) yok.
- Dolar kuru elle; TCMB/ERP'den otomatik doldurma istenirse eklenebilir.
- `EtiketCiktisiSayfasi.test.tsx`'te 5 test kırmızı — başka oturumun commit'lenmemiş etiket
  değişikliklerinden; bu işle ilgisiz.

### 5. Paket
- **Ne yapıldı:** `deploy/yayinla.ps1` (ayrı powershell sürecinde; PS içinden `2>&1` ile vite
  uyarısı hata sayılıyor) → `yayin\` → `SentezServis-2026-09-23-rayic.zip` (73,8 MB, depo kökü, commit'lenmez).
- **Karar:** Paket ÇALIŞMA KOPYASINDAN alındı, temiz HEAD'den değil. Sebep: bir önceki paket
  (`SentezServis-2026-09-23-aktarim.zip`, 09:10) commit'lenmemiş karşıt kod / etiket işlerini zaten
  içeriyor (app.js'te `karsit-kodlar` var) → canlıda bunlar çalışıyor; HEAD'den paket bunları geri alırdı.
  09:10'dan beri değişen dosyalar yalnızca rayiç ile ilgili (find -newer ile doğrulandı).
- **Doğrulama:** app.js'te `/rayic` ve karşıt kod rotası var; appsettings.json çıkarıldı (29 sır boşaltıldı).
  Arayüz tarihi: 2026-09-23 11:42 — kurulumdan sonra `/api/surum` bu değeri dönmeli.

### 6. Kâr oranı / KDV'siz / KDV'li bağlı fiyat
- **İstek:** KDV'siz satış = toplam maliyet (KDV'siz) + %40 (parametrik); KDV'li = KDV'siz + %10 KDV
  (parametrik). Kâr, KDV'siz veya KDV'li değiştirilince diğerleri güncellensin.
- **Ne yapıldı:** `RayicParametreleri.HedefKarOrani` (0,40) ve `KdvOrani` (0,10). `FiyatlariTamamla`:
  öncelik girilen KDV'siz → girilen KDV'li/(1+KDV) → kâr hedefi. Kâr hedefi döngüsel (komisyon KDV'li,
  stopaj KDV'siz fiyattan) → `S = (1+m)·sabit / (1 − (1+m)·a)`, `a = (1+KDV)·komisyon/1,2 + stopaj`;
  karlılık tam m çıkıyor. `RayicSonucu`'na çözülmüş `SatisFiyatiKdvsiz/Kdvli` eklendi.
  Ekran: üçlü alan grubu, son değiştirilen "kaynak" (elle rozeti), sunucuya yalnızca kaynak gider,
  diğer ikisi önizlemeden 2 haneyle geri yazılır; önizleme isteği girdi JSON anahtarına bağlandı (döngü yok,
  boştayken 0 istek ölçüldü). Karşılaştırmaya "KDV oranı" ve "Fiyatın kaynağı" satırları eklendi.
- **Doğrulama:** 573/573 test (yeni: kâr %40/%25/%0 tam oturuyor, KDV'siz 600 → KDV'li 660 & toplam 449,93,
  KDV'li 660 → KDV'siz 600). Tarayıcıda LocalDB ile: 6230 %40 → toplam 453,89, KDV'siz 635,45, KDV'li 698,99.
- **Karar:** Komisyondaki `/1,2` Excel'deki gibi kaldı (komisyonun kendi KDV'si), satış KDV'sinden bağımsız.
  Kaynağı kâr olan kayıtta fiyat saklanmaz → maliyet değişince fiyat %40'ı korur.
- **Commit:** `4626c5c` — Rayic: kar orani, KDV'siz ve KDV'li satis fiyati birbirine bagli
- **Paket:** `SentezServis-2026-09-23-rayic-kar.zip` (çalışma kopyasından; önceki paketten sonra başka
  değişiklik yok). Arayüz tarihi 2026-09-23 12:10.

### 7. Detay Excel satırlarıyla birebir
- **İstek:** Detay, Excel YENİ RAYİÇ'teki 32 satır listesi gibi, ayrıntılı çıksın.
- **Ne yapıldı:** Tek `SATIRLAR` listesi (Excel sırası ve adları: Dolar Kuru … dolar fiyat … Tav. SF …
  güncel kura göre Satış Fiyatı (KDV'li), Satış Fiyatı (KDV'siz), Brüt Karlılık) hem karşılaştırma
  tablosunda hem sağdaki canlı önizlemede ("Detay (Excel sırası)") kullanılıyor. İki "Toplam Maliyet
  (KDV'siz)" birim rozetiyle (USD/TL) ayrışıyor. Ekranın eklediği Kâr hedefi / KDV oranı / Fiyatın
  kaynağı altta ayrı blok. Tabloda "Proje Kodu" sütun başlığında olduğu için satır olarak tekrarlanmıyor.
- **Doğrulama:** tsc + oxlint temiz; LocalDB + tarayıcı: önizlemede 32 + 3 satır, tabloda 6230/6234
  (453,89 / 401,98 toplam, %40 karlılık).
- **Commit:** `3b526b7` — Rayic detayi Excel YENI RAYIC satirlariyla birebir
- **Paket:** `SentezServis-2026-09-23-rayic-detay.zip` (çalışma kopyasından; başka değişiklik yok).
