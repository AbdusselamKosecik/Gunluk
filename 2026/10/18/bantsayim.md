# bantsayim — 2026-10-18

## Bağlam
Kullanıcı: "bant sonu na etiket basmada tarih fitresini 1 haftaya cikartirmisin".

## Yapılanlar

### 1. Yönetim → Raporlar: tarih filtresi varsayılan son 1 hafta
- **Neden:** Box etiketini tekrar basma ekranı (Yönetim → Raporlar, "Box etiketi yazdır") yalnız bugünü getiriyordu. Önceki günlerin box'ı için her seferinde tarih değiştirmek gerekiyordu.
- **Ne yapıldı:** `YonetimViewModel.Baslangic` varsayılanı `DateTime.Today` yerine `DateTime.Today.AddDays(-7)` oldu; Bitis bugün kaldı.
  Bant kabul listesi (`BantKabulListeViewModel`) zaten 7 gündü, ikisi aynı oldu.
  Aynı aralık bant özeti ve hata dağılımı raporlarına da uygulanıyor.
- **Dokunulan dosyalar:** `BantSayim/Ekranlar/YonetimViewModel.cs`, `BantSayim.Tests/YonetimFiltreTestleri.cs` (yeni)
- **Test (TDD):** `Tarih_filtresi_varsayilan_son_bir_hafta` önce kırmızıydı, sonra yeşil. Suite: 54 geçti, 20 DB testi atlandı.
- **Kapasite kontrolü:** Box sorgusu `TOP 500` (en yeni önce). Canlıda (192.168.0.2) son 14 günde günde 5–23 box var, yani haftada yaklaşık 70; sınırın çok altında.
  ```sql
  SELECT CAST(AcilisAt AS date), COUNT(*) FROM dbo.UZM_UretimBox WHERE AcilisAt >= DATEADD(day,-14,GETDATE()) GROUP BY CAST(AcilisAt AS date)
  ```
- **Commit:** `874ea70`. Push edildi.

## Açık kalanlar
- Değişiklik bant sonu bilgisayarındaki uygulama güncellenince görünecek.
