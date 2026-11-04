# sentezservis — 2026-11-04

## Bağlam
Kullanıcı Trendyol satıcı panelinden üç Excel indirdi (şirket 04 = Erp_Company.RecId 7):
`seller-327733-favori-görüntüleme-raporu-…xlsx` (765 satır), `…-urun-degerlendirmeleri-…xlsx`
(25.011 satır, 01.01–04.11.2026), `…-satıcı-değerlendirmeleri-…xlsx` (68 satır). İstek: bunları
okuyup pazaryeri raporlarına eklemek, yüklerken şirket seçmek, analiz ekranına çevirmek.
Bu raporların satıcı API'sinde karşılığı yok → elle yükleme.

## Yapılanlar

### 1. Dosya yapısı incelendi
- **Neden:** Sütunlar, tipler, tekrarlar belirlenmeden tablo tasarlanamaz.
- **Bulgular:** Panel sayıları METİN yazıyor ("18901", "3.15"), ondalık nokta. Tarih
  `dd-MM-yyyy HH:mm` (Türkiye saati). Favori raporu ürün (renk varyantı) bazlı, 270 model / 765
  satır, tarih yok (dönem toplamı). Ürün değerlendirmelerinde kimlik yok ve 390 GERÇEK tekrar
  satır var (aynı dakika, aynı ürün, aynı puan). Satıcı değerlendirmesinde teslimat no maskeli
  ("1****9"). "Olumsuz Etkiler": Ürün/malzeme kalitesi, Kusurlu/hasarlı, Eksik, Yanlış/farklı ürün.
- **Komut:** `python -I -X utf8 -c "import openpyxl ..."` (cp1252 konsolda `-X utf8` şart).

### 2. Göç 023 — `023_pazaryeri_raporlari.sql`
- **Ne:** `pazaryeri_rapor_yuklemeleri` (günlük), `pazaryeri_rapor_favori`,
  `pazaryeri_rapor_urun_degerlendirme`, `pazaryeri_rapor_satici_degerlendirme`. Şirket
  `sirket_id` (RecId) + `sirket_kodu` olarak saklanır.
- **Karar — yeniden yükleme:** favori = şirket+pazaryerinin eski satırları silinir (anlık
  görüntü). Değerlendirmeler = dosyadaki en eski–en yeni tarih ARALIĞI silinip yazılır →
  aynı dosya iki kez yüklenince çift saymaz, kısa aralıklı dosya eskileri silmez, gerçek
  tekrarlar korunur (tekilleştirme YOK).

### 3. Okuyucu ve depo (Core/PazaryeriRaporlari)
- `PazaryeriRaporOkuyucu.cs`: NPOI; tür imza başlıktan ("Toplam Görüntülenme Sayısı" /
  "Teslimat Numarası" / "Ortalama Ürün Puanı"). Sütunlar ADA göre (Türkçe büyük harf,
  boşluk sadeleştirilmiş anahtar). Puan 1–5 dışı/tarihsiz satır atlanır ve sayılır.
- `PazaryeriRaporDeposu.cs`: tek transaction'da günlük INSERT → DELETE → `SqlBulkCopy`
  (25 bin satır ~1,1 sn). `AnalizAsync` tek `QueryMultiple`: son yüklemeler, favori
  toplam/kategori/ürün (+ aynı model kodunun puanı), ürün ve satıcı puan özeti (dağılım,
  aylık), modeller, son 300 olumsuz yorum, satıcı kayıtları; olumsuz etkiler C#'ta bölünüp sayılır.

### 4. API — `Host/Api/PazaryeriRaporUclari.cs`
- `POST /api/pazaryeri-raporlari/yukle` (multipart: çok dosya, `sirketId`, `pazaryeri`) —
  **MudahaleIster** (rol + CSRF). İlk hâli `GirisIster` idi; curl denemesinde CSRF'siz
  yüklemenin 200 aldığı görüldü → düzeltildi (projede durum değiştiren uç = MudahaleIster).
  Şirket `FaturaKarsilastirici.SirketlerAsync` (Erp_Company) ile doğrulanır. Dosyalar bağımsız:
  biri bozuksa diğerleri yüklenir.
- `GET /analiz?sirketId&pazaryeri&baslangic&bitis`, `GET /yuklemeler` — GirisIster.

### 5. Ekran — `/pazaryeri-raporlari` (menü: Operasyon › Pazaryeri raporları)
- `web/src/pages/PazaryeriRaporlariSayfasi.tsx` (+ `.css`, MusteriSesi.css'in ms-* sınıfları).
- Şirket seçimi (varsayılan 04, tarayıcıda hatırlanır), pazaryeri, değerlendirme tarih aralığı,
  sürükle-bırak çoklu yükleme (yalnız müdahale eden/yöneticiye görünür).
- Sekmeler: Genel bakış (KPI, satış hunisi, kategori cirosu, 4 fırsat listesi), Ürün performansı
  (sıralanır tablo, kategori süzgeci, görsel), Ürün değerlendirmeleri (dağılım, aylık seri,
  modeller → yorum süzgeci, olumsuz yorum araması), Satıcı değerlendirmeleri (etkiler, kayıtlar).
- Fırsat kuralları `web/src/utils/pazaryeriRapor.ts` → `ESIK` sabiti: mağaza ortalamasına göreli
  (çok görülüp az satan, sepette kalan, satan ama puanı < 4 (≥20 değ.), favoride bekleyen).

### 6. Doğrulama
- **Komutlar:**
  ```bash
  PAZARYERI_RAPOR_KLASORU="X:/Gitlab/Modasima/sentezservis" dotnet test tests/SentezServis.Core.Tests --filter "FullyQualifiedName~PazaryeriRapor"
  dotnet test tests/SentezServis.Core.Tests        # 763 geçti
  cd web && npx tsc -b && npx vitest run && npm run build   # 89 geçti
  ```
- LocalDB `PrDeneme`: scratchpad konsolu ile göç + iki kez yükleme (2. yükleme silinen = önceki
  satır, çift yok) + analiz 0,5 sn. Sonra Host LocalDB'ye bağlandı (`SentezServis__Baglantilar__Servis/Erp`,
  `SentezServis__ZamanlayiciEtkin=false`, sahte `Erp_Company` 01/04), curl ile giriş → CSRF'siz 403,
  üç dosya + README tek istekte: 3 başarılı, README "Excel olarak açılamadı". DB sonra silindi.
- Curl'de Türkçe karakterli dosya adları Git Bash'te okunamadı (sessiz boş yanıt) → ASCII kopyalarla denendi.
- Tarayıcı (chrome-devtools MCP) başka oturumda kilitliydi; ekran görsel olarak DENETLENMEDİ.
- **Commit:** `7e769d4` — Pazaryeri raporlari: satici paneli Excel yukleme ve analiz ekrani

## Kararlar
- Ayrı tablolar; `musteri_sesi_yorumlar`'a YAZILMADI (o tablo barkod + yorum_no ister, Excel
  model kodu veriyor, kimlik yok).
- Excel dosyaları müşteri verisi → depoya eklenmedi (kök dizinde izlenmeyen dosya olarak duruyor).
- Zamanlar dosyadaki gibi Türkiye saati saklanır (diğer pazaryeri tabloları UTC'dir — bilerek farklı).

## Açık kalanlar / sonraki adım
- Canlıya paket + göç 023 (açılışta otomatik). Yeni appsettings anahtarı YOK.
- Canlıda 04 için üç dosya ekrandan yüklenmeli; ekran tarayıcıda gözle kontrol edilmeli.
- İstenirse: Müşteri sesi panosuna Excel yorumlarını da katmak, fırsat eşiklerini iş birimiyle ayarlamak.
