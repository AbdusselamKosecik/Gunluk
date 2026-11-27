# malkabul (SentezCore bakımı) — 2026-11-28

## Bağlam
GL hesapları 26.11'de silinmişti (bkz. 2026/11/26/malkabul.md §2). Yeni hesap planı `X:\Gitlab\modfex-apparel\MuhasebeKodlari.xlsx` dosyasında; kolonlar Kod / Turkce / Ingilizce / arabca. Kullanıcı İngilizce ve Arapça adların muhasebe terimleriyle, en fazla 25 karakter olarak doldurulmasını istedi.

## Yapılanlar

### 1. Hesap planı İngilizce/Arapça çevirisi
- **Ne yapıldı:**
  - 674 satırda 444 benzersiz Türkçe ad elle çevrildi.
  - İngilizce: IFRS terimleri (ACCUMULATED DEPREC(-), DEDUCTIBLE VAT vb.); ST/LT, PRV, EXP, ALLOC, VAR kısaltmaları kullanıldı.
  - Arapça: Mısır/Arap muhasebe terimleri (مجمع الإهلاك، مخصص، أوراق القبض vb.).
  - Firma, banka ve kişi adları Latin harfle bırakıldı; hesap numaraları korundu.
- **Kontrol:** Python betiği her değerin 25 karakteri aşmadığını doğruladı (en uzun 25/25). Arapçada aşan tek değer kısaltıldı.
- **Dosyalar:**
  - Çeviri tablosu: scratchpad `ceviri.py` (T listesi, benzersiz Türkçe adların sırasıyla).
  - Çıktı: `X:\Gitlab\modfex-apparel\MuhasebeKodlari-ceviri.xlsx`. Orijinal Excel'de açık olduğu için ayrı dosyaya yazıldı.
  - Orijinalin kopyası: `yedek\MuhasebeKodlari-orijinal-20261128.xlsx`.

## Açık kalanlar
- Kullanıcı çeviriyi gözden geçirip Sentez'e yükleyecek. Ardından KDV (Erp_TaxIA), cari ve banka hesap bağları yeniden kurulacak.
