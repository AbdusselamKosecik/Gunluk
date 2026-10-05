# aaa — 2026-10-05

## Bağlam
`X:\Yazilim\aaa` içinde Mısır fabrikasının Eylül 2026 maaş dosyaları var (git reposu değil):
`September Salaries 2026.xlsx` (386 çalışan) ve `September Disable 2026.xlsx` (13 engelli çalışan).
Hedef: iki listeyi hata/tutarsızlık açısından denetlemek. (Repo herkese açık olduğu için burada
isim / kimlik no / kod yazılmadı, sadece yöntem ve özet bulgular var.)

## Yapılanlar

### 1. Dosya yapısını çıkarma
- **Neden:** Hangi sütunun neyi tuttuğunu ve formül olup olmadığını görmek.
- **Ne yapıldı:** openpyxl ile sayfa/sütun dökümü. Ana sayfa A3:BH4 başlıklar (EN+AR), veri 5–390,
  toplamlar 391–393. Gizli sayfa `s&T` (126 kod + 2025-08 tarihleri) ve boş `Sheet1` var.
- **Bulgu:** Ana sayfada **hiç formül yok** — her şey değer olarak yapıştırılmış.
- **Not:** Windows'ta `PYTHONIOENCODING=utf-8` gerekli (Arapça başlıklar cp1252'de patlıyor);
  pandas `python -m pip install pandas` ile kuruldu. Pandas'ta `df.T` transpoz demek → sütun
  erişimi `df['T']` ile yapılmalı.

### 2. Hesap kurallarını geri çıkarma ve satır satır doğrulama
- **Çıkarılan kurallar (hepsi 386 satırda tutuyor):**
  - Gün ücreti = Temel/30, saat = gün/7; Toplam gün U = O+P+Q+R+S+T; V = U×gün.
  - Fazla mesai: ×1.35 / ×1.70 / ×2 saat ücreti üzerinden; AC = toplamı.
  - Sigorta: çalışan %11, işveren %18.75 (AE matrahı üzerinden); AZ = AF.
  - Brüt AV = V+AC+AD+AJ+AK+AM+AN+AO+AP+**AF** (yukarı yuvarlanmış).
  - Kesinti BE = AX+AY+AZ+BA+BC+BD; **BD = AK = 1400 herkes için** (ulaşım ekleniyor ve geri kesiliyor).
  - Net BF = AV−BE, en yakın 5'e yuvarlanmış. Banka+Nakit = 3.232.950 tutuyor.
- **Sonuç:** Aritmetik hata yok; sorunlar politika/uyum/veri kalitesi tarafında.

### 3. Uyum ve veri kalitesi kontrolleri
- TC benzeri Mısır milli kimlik no (14 hane, yüzyıl+doğum tarihi+il kodu) çözümlendi → yaş, işe
  girişte yaş hesaplandı.
- Sigorta durumu ↔ matrah ↔ banka/nakit çapraz tablosu.
- Devam primi (AN/AO) için kural çıkarıldı (devamsızlık günü → 1200/800/400/0) ve istisnalar listelendi.
- Eylül'de işe girenlerin gün sayısı, işe giriş tarihinden beklenen günle karşılaştırıldı.
- Engelli listesi isimleri ana listeyle (normalize Arapça) eşleştirildi → **hiç eşleşme yok**.

## Özet bulgular (detay kullanıcıya sohbette verildi)
- Sigortasız 110 kişi; 47'si 3 aydan uzun süredir çalışıyor (en eskisi 2018). Sigortalı görünen 2
  kişinin matrahı 0. Bir kişide matrah temel ücretin %45'i (22.000 → 10.000).
- İşe girişte 18 yaş altı 21 kişi; şu an 18 altı 4 kişi, biri gece/bayat dahil fazla mesai yapıyor.
- Ulaşım 1400 herkese ekleniyor + aynen kesiliyor → brüt şişiyor; temel ücreti 7.000 altı 152 kişi.
- Devam priminde tutarsız uygulama (aynı devamsızlıkta farklı prim).
- Bir idari personelde 185 saat fazla mesai (temel ücretten fazla ödeme).
- Engelli listesi: 13 kişi (5% kotası için ~20 gerekli), ana bordroda yoklar, kimlik/sigorta yok,
  2700 sabit, sigorta kesintisi yok, "Collar" sütununa 0.05 yazılmış.
- Veri kalitesi: bölüm adları tutarsız (`Line 5`/`line5`, `White`/`white`, `Samble`), 4 boş bölüm,
  float gürültüsü (4.9999…), gizli `s&T` sayfası açıklamasız.

## Kararlar
- Dosyalara dokunulmadı; sadece okuma/analiz. Analiz scriptleri session scratchpad'inde.

## Açık kalanlar / sonraki adım
- Kullanıcı isterse: bulguları satır numaralı bir "Kontrol" Excel'i olarak üretmek.
- 2026 Mısır özel sektör asgari ücretinin güncel tutarı teyit edilmeli (7.000 EGP Mart 2025 kararı esas alındı).
- `aaa` klasörü git reposu değil → proje tarafında push yapılmadı.

### 4. İngilizce denetim raporu (md) — kişi bazlı tablolarla
- **Neden:** Kullanıcı raporu İngilizce ve her maddenin altında ilgili kişilerin (ad-soyad, sicil, değerler) listesiyle istedi.
- **Ne yapıldı:** Scratchpad'de `report.py` (yükleyici `load.py`) ile 9 bulgu bölümü + özet tablosu üretildi;
  her bölümde Satır / Kod / İsim (EN+AR) / ilgili sütun değerleri tablosu var.
- **Çıktı:** `X:\Yazilim\aaa\Payroll Audit September 2026.md` (~650 satır). Kişisel veri içerdiği için
  **bu herkese açık repoya kopyalanmadı.**
- **Düzeltme:** 1d (matrah tutarsızlığı) ilk sürümde normal %77 oranlıları da listeliyordu → filtre
  "tavan altı ve temelin <%70'i veya temelden büyük" yapıldı; 7a sadece sigorta kesilenleri gösteriyor.

### 5. Raporu HTML'e çevirme
- **Ne yapıldı:** `python -m pip install markdown` → scratchpad `tohtml.py`: md → HTML (tables eklentisi),
  sabit üst menü (bölüm linkleri), yatay kaydırmalı tablolar, Arapça isimler ayrı satırda RTL, koyu tema
  ve yazdırma (her bölüm yeni sayfa) CSS'i. Tek dosya, dış bağımlılık yok.
- **Çıktı:** `X:\Yazilim\aaa\Payroll Audit September 2026.html` (~130 KB, 19 tablo). Kişisel veri → yayınlanmadı.
- **Tuzak:** markdown kütüphanesi ham `<br>`'yi aynen bırakıyor (`<br />` değil) → regex `<br ?/?>`.
