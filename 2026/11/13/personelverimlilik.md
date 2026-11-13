# personelverimlilik — 2026-11-13

## Bağlam
İstek: sicil girilince (örn. 7411) takvime göre olması gereken verimliliği mola aralıklarına bölerek
(sabah→1. çay, 1. çay→yemek, yemek→2. çay, 2. çay→mesai bitişi) Excel'e çıkaran küçük program.
Kullanıcı: "69'dan bakmayacaksın, Fashion ve Dikim'e bakman lazım."

## Yapılanlar

### 1. Veri kaynağı ve formülün tespiti
- **Neden:** Sistemdeki verimlilikle aynı sonucu vermesi için Techtsio'nun kendi formülünü kullanmak.
- **Ne yapıldı:** Bağlantılar `muftelif/SentezDashbord/api/appsettings.json` içinde: Dikim=172.16.1.2, Fashion=10.10.10.200 (TechtsioMerkez).
  Dikim'deki nesneler okundu: `REPORT_GunlukVerimlilik` → `FC_New_Transection_Group_View` → `New_Transection_View` → `GetWorkingTimeFromTwoDate`, `GetEfficiency`.
  - mesai = hareket ∩ takvim dönemleri (Calendars: ShiftId, ProductLineId, WorkTimeType=gün 0=Pazar), Hour<8 → 0
  - Hedef = mesai / Operations.AverageStandardTime (0→1); tamir ve AffectProductivity=1 kayıp zaman hariç
  - ReelTotalQuantity = tamir/kaçak/kayıp dışı adet, kart+operasyon+cihaz grubunda kart adedi ile sınırlı; IsInOutOperation → kart adedi
  - Verim = Reel / Hedef × 100
  - Hat: günün (herhangi) ilk hareketinin hattı
- **Sonuç:** MONTAJ takvimi 08:00-10:15, 10:30-12:40, 13:10-15:30, 15:45-18:00, FM 18:20-20:20.

### 2. Program (.NET 10 konsol, ClosedXML)
- **Ne yapıldı:** `Depo` (Employee, Transections+LostTimes+Operations+Cards, Calendars), `Hesaplayici` (dönemlere bölme;
  moladan geçen hareketin adedi süre oranında, tamamen molada biten önceki döneme), `ExcelYazici` (Özet + Hareketler sayfaları), `Program`
  (interaktif sor veya `exe sicil [bas] [bit]`, her iki sunucuya bakar, Excel'i `Raporlar\`'a yazıp açar).
  Çalışılmamış fazla mesai dönemi gizlenir. Dönem adları mola sayısına göre (Cumartesi 3 dönem: çay, yemek).
- **Dokunulan dosyalar:** `src/PersonelVerimlilik/{Program,Depo,Hesaplayici,ExcelYazici,Modeller}.cs`, `appsettings.json`,
  `appsettings.Local.example.json`, `tests/PersonelVerimlilik.Tests/HesaplayiciTests.cs`, `README.md`, `.gitignore`
- **Komutlar:**
  ```bash
  dotnet new sln -n PersonelVerimlilik --format slnx; dotnet new console/xunit ...
  dotnet add package ClosedXML 0.104.2, Dapper 2.1.66, Microsoft.Data.SqlClient 6.1.4, Microsoft.Extensions.Configuration.Json 10.0.0
  dotnet test   # 7/7
  dotnet publish src/PersonelVerimlilik -c Release -r win-x64 --self-contained -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -o ../PersonelVerimlilik-program
  ```
- **Sonuç / doğrulama:** 7411, 12.11.2026: dönemler %92,3 / %87,9 / %54,9 / %54,2, gün %69,3 (852/1229);
  `REPORT_GunlukVerimlilik` toplamı 852/1228 → aynı. 11.11: gün %60,5. Fashion'da 7411 var ama hareketi yok.
  İlk denemede komut satırı modunda bitiş tarihini stdin'den bekleyip asılı kaldı → argüman verildiyse sorma düzeltildi.
- **Commit:** `f18407d` — PersonelVerimlilik: sicile gore takvim donemlerinde verimlilik (Dikim/Fashion) Excel raporu

## Kararlar
- 69 kullanılmaz; Dikim + Fashion (kullanıcı kararı).
- Hedef paydası sistemdeki gibi "takvim içinde hareketi olan süre"; personelin hiç okutma yapmadığı süre hedefe girmez.
  Excel'de ayrıca dönemin takvim dakikası ve çalışılan dakika gösterilir.
- Şifreler sadece `appsettings.Local.json` (gitignore). Exe paketi `X:\Gitlab\fredericTr\PersonelVerimlilik-program\` (repo dışı, şifreli ayar içerir).

## Açık kalanlar / sonraki adım
- Kullanıcı "olması gereken" ile tam takvim süresini (okutma olmasa da) payda istiyorsa ikinci bir verim sütunu eklenebilir.
- Paketteki `System.Security.Cryptography.Pkcs` 9.0.11 NU1903 uyarısı (ClosedXML/SqlClient bağımlılığı).

### 3. Tek exe, şifreler exe içinde
- **Neden:** Kullanıcı: "tek exe yapalım, şifreler uygulamanın içinde olsun."
- **Ne yapıldı:** csproj'da `appsettings.json` ve (varsa, gitignore'daki) `appsettings.Local.json` `EmbeddedResource` (LogicalName aynı) yapıldı;
  `Program.cs` ayarı `GetManifestResourceStream` + `AddJsonStream` ile okuyor, exe yanında `appsettings.Local.json` varsa onu üstüne yazıyor.
  Release için csproj'a win-x64, SelfContained, PublishSingleFile, IncludeNativeLibrariesForSelfExtract, EnableCompressionInSingleFile, DebugType=none eklendi.
- **Dokunulan dosyalar:** `src/PersonelVerimlilik/PersonelVerimlilik.csproj`, `src/PersonelVerimlilik/Program.cs`, `README.md`
- **Komutlar:**
  ```bash
  dotnet publish src/PersonelVerimlilik -c Release -o ../PersonelVerimlilik-program
  ```
- **Sonuç / doğrulama:** Klasörde sadece `PersonelVerimlilik.exe` (44 MB, sıkıştırmayla 95 → 44 MB). Yanında ayar dosyası olmadan 7411 / 12.11.2026 aynı sonuç (%69,3).
  `git grep 204571` → repoda şifre yok. Program kullanıcının ekranında açıldı.
- **Commit:** `5169b20` — Tek exe: ayarlar (sifreler dahil) derlemede exe'ye gomulur

## Not
- Exe şifreyi düz metin olarak taşır (gömülü kaynak, exe'den çıkarılabilir). Sadece iç ağda paylaşılmalı.

### 4. Windows Form + detay
- **Neden:** Kullanıcı: "şunu Windows Form yapalım, detayda ekleyelim."
- **Ne yapıldı:**
  - `Hesaplayici` her okutmanın döneme düşen payını `DetaySatiri` (dönem, dönemdeki süre, hedef, sayılan adet) olarak üretir; moladan geçen okutma 2 satır.
  - Veri çekme `Raporlayici`'ya taşındı (gömülü ayar yükleme + Dikim/Fashion döngüsü).
  - `AnaForm` (kodla, designer yok): üstte Sicil + Başlangıç/Bitiş DateTimePicker + Hesapla (AcceptButton) + Excel'e aktar + personel adı;
    SplitContainer: Dönemler grid'i (gün toplamı kalın/mavi, verim rengi ≥85 yeşil, ≥65 turuncu, altı kırmızı) ve seçilen dönemin Detay grid'i; StatusStrip.
  - Excel'deki "Hareketler" sayfası "Detay" oldu (dönem, dönemdeki süre, hedef, sayılan adet, durum).
  - csproj: WinExe, net10.0-windows, UseWindowsForms; test projesi de net10.0-windows. Konsol modu kaldırıldı.
- **Dokunulan dosyalar:** `src/PersonelVerimlilik/{AnaForm,Raporlayici,Program,Hesaplayici,Modeller,ExcelYazici}.cs`, csproj'lar, `tests/.../DetayTests.cs`, `README.md`
- **Komutlar:**
  ```bash
  dotnet test     # 9/9
  dotnet publish src/PersonelVerimlilik -c Release -o ../PersonelVerimlilik-program   # tek exe 55 MB
  ```
- **Sonuç / doğrulama:** UI Automation ile form açıldı, 7411 girildi, Hesapla tıklandı: 13.11.2026 dönemler %90,1 / %92,1 / %59,3 / -, gün %83,8 (791/944);
  detay "10 okutma, hedef 365, sayılan 329" = özet satırıyla aynı. Detayda decimal'ler `35,0000000000` görünüyordu → "0.##" biçimi.
  Kullanıcının Excel'de açık tuttuğu `Raporlar\Verimlilik_7411_2026-11-13_143818.xlsx` silinmedi.
- **Commit:** `bdfe96c` — Windows Form: sicil/tarih girisi, donem ozeti, secilen donemin okutma detayi, Excel'e aktar
