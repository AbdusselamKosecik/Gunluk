# paketleme — 2026-10-13

## Bağlam
Kullanıcı: "paketlemede tezgah işlemleri tamam mı? terazi işlemleri falan" + SerialPort Terminal ekran görüntüsü (hex).

## Yapılanlar

### 1. Terazi veri şablonu doğrulandı — `f4e942e`
- **Görüntüden çözülen akış:** `2B 30 30 30 33 2E 38 30 6B 67 0D 0A` = `+0003.80kg` CR LF; değerler 3.80, 3.85, 3.85, 3.75 … 0.00;
  kararlılık işareti yok (sürüm 1 biçimi).
- Mevcut `TartiOkuyucu.Ayristir(…, 1)` deseni (`^\s*([+-])\s*(\d+(?:\.\d+)?)\s*kg\s*$`) baştaki sıfırlı değeri okur; port
  `NewLine="\r"`, satır başındaki LF `Trim` ile atılır. Kod değişikliği gerekmedi.
- **Testler:** `GercekTeraziTestleri` 7 (gerçek satırlar, yarım satır "70kg" atlanır, dalgalanan akış kararsız, 5 eşit okuma → 3.85
  kararlı, boş terazi 0.00 kararlı sayılmaz) — geçti.
- **Doğrulanmadı:** baud (kod 9600 8N1 varsayar; görüntüde baud yok), gerçek port ile uçtan uca.

## Durum
- Tezgah/mamul/sevk tabloları canlıda hâlâ **yok** (`db/0002_tezgah.sql`, `sevkiyatmobil/db/0001_sevkiyatmobil.sql` çalıştırılmadı).

### 2. "Beş yaşındaki çocuk" okutma ekranı — `f356f13`
- **Neden:** kullanıcı "5 yaşındaki çocuğun anlayacağı gibi yapar mısın ekranları". Seçimler: düzen "Komut + dev sonuç";
  terazi kararlı olunca operatör **TAMAM**'a basar (otomatik kapatma yok).
- **Ne yapıldı:**
  - `Ekranlar/Veri/EkranRehberi.cs` (saf): durum → adım (① box ② ürün ③ adet ④ terazi ⑤ etiket) + tek komut anahtarı;
    hata → `Ipucu_{hata}` "ne yapmalı" anahtarı (21 hata).
  - VM: `Iyi/Kotu` sonuçları büyük alana da yazar; `KomutGuncelle`; `BuKolideSayi`, `KalanSayi`; `Tus` (sayı tuşları),
    `HizliAdet` (6/12/24/kalan), `YanlisOkuttum` (Sil aç/kapa, kenar kırmızı), `DetayGoster`, `YeniKapandi` (⑤).
  - XAML: üstte adım hapları + 34 pt komut + okut kutusu; ortada ✓/✗ 64 pt + 30 pt metin + ipucu; adet paneli (56 pt kutu,
    3×4 tuş takımı, hızlı tuşlar); tam alan terazi (72 pt ağırlık, sarı → yeşil, TAMAM — KAPAT, ETİKET BAS); tablo Detay'da;
    sağda tezgah şeridi; altta BU KOLİDE / SİPARİŞTE KALAN (44 pt) + YANLIŞ OKUTTUM / DETAY / KOLİ BİTTİ.
  - 42 yeni metin TR/EN/AR.
- **Testler:** `EkranRehberiTestleri` 11 + metin kapsama 29 (her komut/ipucu anahtarının çevirisi var); suite 123 geçti.
- **Doğrulanmadı:** ekran görsel olarak açılmadı (giriş şifresi gerekiyor); kullanıcı bakacak.
