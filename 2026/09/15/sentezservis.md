# sentezservis — 2026-09-15

## Bağlam
EtiketCiktisi ekranında Defakto akışı vardı (commit edilmemişti). Hedef: Mısırlı koli etiketi.
Girdi: `docs/Misirli/modasima-barcod tanımala 2.xlsx` (barkod listesi) + `PACKING LIST EXPORT 12.2026 (1).xlsx`.
Referans düzen: `revize mısırlı.pdf` (KOLİ NO / MÜŞTERİ / MODEL / RENK / BEDEN / PAKET / PAKET İÇİ / TOPLAM ADET / EAN 1..n).

## Yapılanlar

### 1. Veri analizi (Python/openpyxl ile prototip)
- **Neden:** Kolonlar ve eşleşme kuralları belirsizdi.
- **Bulgular:**
  - Barkod listesi: MARKA, EAN, NEBİM KOD, MODEL COD, BEDEN, RENK (522 satır, 2'si MODEL COD boş → 520).
  - PACKING LIST sayfa `SHIPMENT `, başlık satır 3. Beden sütunları PACKING TYPE ile QTY. ASSORTMENT SIZES arasında (36..46, 70B..100D).
  - PACKING TYPE = Client: satır 201–372, CTNS SEQ 497–646 → 150 koli, 33.313 adet.
  - CTNS SEQ boş Client satırı = üstündeki kolinin devamı (karışık koli). Doğrulama: Σassortment × Lots = PCs PER CTN; 150 kolinin hepsinde tuttu.
  - Eşleşme: STYLE NAME ↔ MODEL COD (1008 → `1008-2`), COLOUR ↔ RENK (Türkçe/sıra farkı, `SBT`=Siyah/Beyaz/Ten, `Bordo/Siyah`=SIYAH-BORDO), beden (`75B/36` iki parça).
  - Veri boşlukları: `GULKRUSU` (listede "Gül Kurusu"), 1008 SIYAH-BEYAZ ve 1230 SBT için set barkodu yok.

### 2. Mısırlı okuyucu + PDF
- **Ne yapıldı:** `MisirliExcelOkuyucu` (ClosedXML) ve `MisirliKoliEtiketRaporu` (FastReport, 100×100 mm, GroupHeader `KoliSira` StartNewPage, EAN'lar DataBand satırı; en az 3, en fazla 7 EAN).
- **Kurallar:** KOLİ NO = CTNS SEQ (aralık adedi NO OF CTNS ile eşit olmalı); MODEL = NEBİM KOD; PAKET = Σ assortment; PAKET İÇİ = Lots; TOPLAM = PCs PER CTN.
  Tek harf yazım farkı (Levenshtein ≤1, tek aday) ve set barkodu yoksa tekli renk barkodları → uyarı. Eşleşmeyen beden → hata, PDF yok.
- **Uçlar:** `POST /api/etiket-ciktisi/misirli/onizle|pdf` (multipart `barkod`, `paketListesi`).
- **Arayüz:** EtiketCiktisi → Mısırlı: iki dosya seçimi, özet, uyarılar, koli tablosu, etiket önizleme, tek PDF.
- **Dokunulan dosyalar:** `src/SentezServis.Core/EtiketCiktisi/MisirliExcelOkuyucu.cs`, `MisirliKoliEtiketRaporu.cs`, `Raporlar/misirli-koli-etiket.frx`,
  `src/SentezServis.Host/Api/EtiketCiktisiUclari.cs`, `web/src/api/etiketCiktisi.ts`, `web/src/pages/EtiketCiktisiSayfasi.{tsx,css,test.tsx}`,
  `tests/SentezServis.Core.Tests/MisirliEtiketTestleri.cs`, `docs/etiket-ciktisi.md`.
- **Komutlar:**
  ```bash
  dotnet test tests/SentezServis.Core.Tests      # 458 geçti
  cd web && npx vitest run && npm run build       # 48 geçti
  ```
- **Sonuç / doğrulama:** Gerçek dosyalarla scratch konsol: 150 koli, 33.313 adet, 150 sayfalık PDF (~20 MB, PDFSimple raster). Sayfa görselleri referansla kontrol edildi.
  Uygulama yerelde başlatılamadı: 192.168.1.3 SQL Server'a bağlantı zaman aşımı (migrasyon adımında).
- **Commit:** `6ce1367` — EtiketCiktisi: Defakto ve Misirli koli etiketleri (10x10 PDF) (önceden commit edilmemiş Defakto işi de bu commit'te).

## Kararlar
- KOLİ NO olarak 1..N yerine packing list CTNS SEQ numarası kullanıldı (koli ile liste izlenebilir).
- Müşteri verisi Excel/PDF'ler repoya konmadı.

## Açık kalanlar / sonraki adım
- Uygulamayı SQL erişimi olan ortamda çalıştırıp ekrandan uçtan uca dene.
- Barkod listesine 1008 SIYAH-BEYAZ ve 1230 SBT set barkodları eklenecek mi, yoksa tekli barkod doğru mu — kullanıcıya soruldu.
