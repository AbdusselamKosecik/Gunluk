# webproject — 2026-11-19

## Bağlam
Kullanıcı (`/goal`): "Ön maliyette Operasyon parametrelerinde operasyonlar kısmında Su hariç operasyonları Erp_Process'te UD_MainType alanına göre getireceğiz; ne kadar varsa gelecek (distinct), adet bazlı fiyat girilecek; içerideki hesaplamalarda da aynı gruplama yapılacak."
Proje: `webproject/FredericOnMaliyet` (WPF, net9.0-windows, Syncfusion, DapperLite, SentezLive).

## Yapılanlar

### 1. Yıkama operasyonları UD_MainType'a göre
- **Neden:** Sabit kutular (Lazer, Zımpara, Sürme, Yıpratma, Eskitme, Kılçık) ve sabit proses kodu listesi (5001, 5010, 5013, 5021, 5030, 5049, 5104, 5057, 5060, 5924) yerine Sentez'deki ana tipler.
- **Bulgu (canlı):** `Erp_Process.UD_MainType` (UdtCode, 50) mevcut ama 4185 prosesin hepsinde boş → Sentez'de doldurulunca liste gelir.
- **Ne yapıldı:**
  - `Services/OperationTypeService.cs`: `UZM_ProcessMainTypePrice(MainType PK, Price, UpdatedAt)` (yoksa oluşturulur); `GetTypes()` = Erp_Process'teki distinct dolu ana tipler (SU hariç) + proses sayısı + fiyat; `Save()` (transaction, update/insert); `Group()` = rota operasyonlarını tipe göre grupla (Adet = operasyon sayısı, Toplam = Adet × Fiyat; fiyatsız tip 0 ile görünür).
  - Parametreler sekmesi: "Operasyon Maliyetleri" = Su Litre kutusu + ana tip tablosu (Ana Tip, Proses Sayısı, Adet Fiyatı). Kaydet: parametreler + tip fiyatları; eski 6 sütun UZM_Parameters'ta değişmeden kalır.
  - Ürün detayı > Yıkama Operasyonları: gruplanmış satırlar (Ana Tip, Operasyonlar, Adet, Adet Fiyatı, Toplam). Gereksiz `UD_Kimyasal5` join'i ve `Erp_Process.CompetencyPoints` yazımı kaldırıldı.
  - Toplu Excel (`YikamaOps`): aynı gruplama (rota operasyonu başına tip fiyatı), sorgu öncesi tablo garanti.
  - `FredericOnMaliyet.Tests` (xunit): 4 gruplama testi.
- **Dokunulan dosyalar:** `FredericOnMaliyet/{Inventory.xaml,Inventory.xaml.cs,MainWindow.xaml,MainWindow.xaml.cs}`, `Models/{ProcessItem,OperationTypePrice}.cs`, `Services/{ParameterService,OperationTypeService}.cs`, `FredericOnMaliyet.Tests/*`
- **Komutlar:**
  ```bash
  cd webproject/FredericOnMaliyet && dotnet build
  cd ../FredericOnMaliyet.Tests && dotnet test     # 4/4
  ```
- **Sonuç / doğrulama:** Derleme temiz, 4/4 test. Uygulama ve SQL canlıda çalıştırılmadı (VPN koptu; ayrıca uygulama SentezLive'a tablo oluşturur — kullanıcı açınca oluşacak).
- **Commit:** `3b784a0` — feat(on-maliyet): yikama operasyonlari Erp_Process.UD_MainType'a gore

### 2. Canlı doğrulama (salt okunur)
- GetTypes SELECT'i, ürün ekranı rota sorgusu ve toplu Excel YikamaOps alt sorgusu canlı Sentez'de hatasız çalıştı (fiyat tablosu yerine tablo değişkeni; Sentez'e yazılmadı). UD_MainType boş olduğu için sonuçlar boş/0.
- Sanal tip eşlemesiyle A214C-1554 rotası (5030, 5001, 5049, 5104, 5010, 5013): KILCIK 0,10 · LAZER 0,50 · PP SURME 2×0,30 · ZIMPARA 2×0,20 = 1,60; aynı veriyle `Group()` testi 1,60.
- **Commit:** `2668e59` — test(on-maliyet): canli rota (A214C-1554) gruplama karsilastirmasi (5/5 test)

## Kararlar
- Su ayrı (litre) kalır; "SU" adlı ana tip listeye/hesaba girmez.
- Davranış farkı: eskiden PP SÜRME ÖN/ARKA her biri Sürme/2, 5924 Kaplama Sprey "(ADT) × ProjectionQty × Sürme" idi; artık her rota operasyonu = 1 × tip adet fiyatı.
- Ürün ekranında fiyat değişikliği yalnız o hesaplamayı etkiler; kalıcı fiyat Parametreler'den.

## Açık kalanlar / sonraki adım
- Sentez'de proseslere UD_MainType girilmeli (şu an hepsi boş).
- Not: bağlantı dizesi (sa parolası) kodda sabit — önceden de böyleydi; ayara taşınmalı.

### 3. UD_MainType önerisi
- 171 yıkama rotası prosesinden 78 kuru işleme tip önerisi (LAZER 4, ZIMPARA 16, PP SURME 26, KILCIK 19, ESKITME 7, YIPRATMA 6); ıslak adımlar (kurutma, yumuşatma…) bilerek tipsiz — yıkama birim maliyeti/kimyasal/su ile zaten hesaplanıyor, tip verilirse çift sayılır.
- Dosyalar: `C:aaa\Sentez_UD_MainType_Oneri.csv`, `C:aaa\Sentez_Veri_Girisi_Oneri.sql` (ROLLBACK ile biter, çalıştırılmadı).
