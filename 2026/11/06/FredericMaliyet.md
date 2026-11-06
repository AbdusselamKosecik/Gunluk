# FredericMaliyet — 2026-11-06

## Bağlam
Muhasebeci Eylül 2026 overhead raporunu gönderdi: `FredericMaliyet/Overheads Report-NEW-30092026.xlsx`
(repo'da untracked). Hedef: uygulamanın (700Ler ekranı → Excel export) Eylül 2026 için muhasebecinin
dosyasıyla aynı sonucu verip vermediğini kontrol etmek, farkları bulmak. Kod değişikliği yapılmadı.

## Yapılanlar

### 1. Excel dökümü
- **Neden:** Muhasebecinin rakamlarını kalem kalem almak.
- **Ne yapıldı:** openpyxl ile tüm sayfalar (data_only) döküldü. Dosyada formül yok, hepsi değer.
  Sayfalar: Overheads Cost, Overheads Cost-730#, Department Overheads, PO Department Overheads (+ "(2)"),
  PO Overheads (+ "(2)"), Total Expenses-26/24/23.
- **Komut:** `python -I dump2.py "<xlsx>"` (sys.stdout.reconfigure(encoding="utf-8") şart; -I modunda PYTHONIOENCODING işlemiyor).

### 2. Uygulama sorgularını Eylül 2026 için doğrudan çalıştırma
- **Neden:** WPF uygulamasını açmadan aynı hesabı yeniden üretmek.
- **Ne yapıldı:** `Query/Mizan.cs` ve `Query/Overheads.cs` içindeki `Sql = @"..."` stringleri regex ile çıkarılıp
  PowerShell SqlClient ile çalıştırıldı (StartDate=2026-09-01, EndDate=2026-09-30 23:59:59; pYear=2026, pMonth=9),
  CSV'ye yazıldı; 700Ler.xaml.cs içindeki 720/730 gruplama kuralları Python'da birebir tekrarlandı.
- **Kritik bulgu:** Uygulama `Database=SentezLive2025`'e sabit bağlı (700Ler.xaml.cs:50, :231; MainWindow.xaml.cs:52).
  `SentezLive2025`'te 2026 üretim verisi YOK (max StartProductionDate 2025-12-31). Doğru DB: `SentezLive`
  (Eylül sarf = 1.290.138,37 → Excel ile birebir). DatePicker varsayılanı da 2025-06.

### 3. Karşılaştırma sonucu
- **Muhasebe tarafı birebir tutuyor:** 720 (7 bölüm, toplam 45.224.730,91), 730 işçilik grupları, 730 tekil hesaplar,
  Diğer 730 (5.744.929,67), 730 toplam + sarf = 42.444.952,74, 760 = 3.808.920,48, 770 = 11.505.413,15, 780 = 84.206,10.
- **Üretim adetlerinde farklar:**
  - Yeni dikim yeri `UD_DikimYeri = "Fashion  - Basic"` (iki boşluklu). Uygulama bunu ayrı departman yapar
    ("SEWING-Fashion  - Basic"), 720 işçilik kovası yok → maliyet almaz. Muhasebeci Fashion + Fashion-Basic +
    Non Denim'i tek "SEWING-Fashion" satırında birleştirmiş (giriş 10.716+12.308+4.522 = 27.546 ✔).
    Non Denim cc=43'te 720 işçilik 0, ama üretim var (4.522/7.787).
  - CUTTING giriş +16: WO 96097, Ekim'de sonradan girilmiş kayıt (InsertedAt ≥ 2026-10-15).
  - FINISHING app 96.773/100.155 vs Excel 95.768/97.584; WASHING +2/+45; Fashion çıkış +227 (birleşik):
    85 iş emri (çoğu 1-3 adetlik, ağırlıkla 1-3 Eylül) Excel'de yok. Kayıtlar Eylül'de girilmiş, sonradan
    güncellenmemiş; ProductionType farkı değil. Sebep veride görünmüyor → muhasebeciye sorulacak.

### 4. "Kayıt kesim" — sonradan girilen üretim kayıtlarını hariç tutma
- **Neden:** Muhasebeci raporu ay kapanışındaki veriyle hazırlanıyor; sonradan (ör. Ekim'de) Eylül tarihli girilen
  kayıtlar uygulamada adetleri değiştiriyordu (Kesim +16, WO 96097).
- **Ne yapıldı:**
  - `700Ler.xaml`: "Kayıt kesim" Label + `CutoffPicker` DatePicker eklendi (kolonlar 7'ye çıktı, TabControl ColumnSpan=7).
  - `700Ler.xaml.cs`: `DatetimePicker_SelectedDateChanged` → kesim = seçilen ayın son günü (varsayılan).
    `GetInsertedBefore()` → `CutoffPicker.SelectedDate?.Date.AddDays(1)` (gün sonu dahil, boşsa null = filtre yok).
    OverHeads sorgusuna `pInsertedBefore` parametresi geçildi.
  - `Query/Overheads.cs`: WHERE'e `and (@pInsertedBefore is null or p.[InsertedAt] < @pInsertedBefore)`.
  - Mizan (GL) sorgusuna filtre konmadı — muhasebe rakamları zaten tutuyor.
- **Sonuç / doğrulama:** `dotnet build` 0 hata. SQL SentezLive'da Eylül 2026 için çalıştırıldı:
  kesim 2026-10-01 → CUTTING giriş 46.446 (Excel ile aynı); filtresiz 46.462. Diğer bölümler değişmedi
  (Finishing/Washing farkı sonradan giriş kaynaklı değil).
- **Commit:** `0e92321` — Overheads: sonradan girilen uretim kayitlarini haric tutan 'Kayit kesim' tarihi

### 5. Muhasebeciye sorular listesi çıkarıldı
- Fashion-Basic/Non Denim birleştirme kuralı, Finishing/Washing'den çıkarılan 85 iş emri, kesim tarihi kuralı,
  Non Denim işçilik masraf merkezi (43), "(2)" sayfalarının amacı.

## Kararlar
- Kod değiştirilmedi; önce kullanıcıdan Fashion-Basic/Non Denim birleştirme kuralı ve DB adı için onay alınacak.

## Açık kalanlar / sonraki adım
- (Hâlâ açık) Uygulama SentezLive2025'e bağlı; 2026 için kesim filtresi uygulamada ancak DB düzelince görülür.
- Bağlantı stringini `SentezLive`'a çevirmek (veya yıl seçimine göre parametrik yapmak).
- `SEWING-Fashion  - Basic` ve `SEWING-Non Denim`'i `SEWING-Fashion`'a eşlemek (Overheads.Sql CASE veya C# tarafında).
- Muhasebeciye: Finishing/Washing'de çıkarılan 85 iş emrinin kuralı ne?
- `PO Overheads (2)` sayfası başlıkları eski şablon (May / 2020) — muhasebecinin elle eklediği sayfa.
