# muftelif — 2026-10-30

## Bağlam
27.10'daki SentezPlaning paketleri (2257a0b Özet bantları, dc3bf85 yıkama 50'li operasyonlar) müşteriye verilmişti. Asiye H. iki geri bildirim gönderdi:
- Dikim Özet'te Fashion / Non Denim bantları görünmüyor.
- Yıkama planında "Kaynak yok" görünen operasyonlar etütte var. Bu konuda Selin bir kod listesi verdi; 5100-1..4 tutturma kodları WSH- ATTACH FRONT'a girecek.

## Yapılanlar

### 1. Özet bantları — kod kontrolü
- **Neden:** Asiye H. Özet'e Fashion / Non Denim bantlarının eklenmesini tekrar istedi.
- **Ne yapıldı:** Değişiklik yapılmadı. Özellik `2257a0b`'de mevcut.
  - `SeriTanimlari` her hattı, ardından `DikimYerleri.Count > 1` olan hatlarda her bandı ekliyor.
  - Muhtemel neden: sunucuda eski paket (4a71920 / 5acf0e4) kurulu. Kurulması gereken paket `SentezPlaning-paket-2026-10-27-dc3bf85.zip`.
- **Sonuç:** Kullanıcıya kurulum ve kontrol adımları verildi: Ctrl+F5; hatta iki dikim yeri tanımlı olmalı; bant çalışanı Parametreler'den girilmeli.

### 2. 5100-x tutturma kodları → WSH- ATTACH FRONT
- **Neden:** Asiye H.: "5100-1, 5100-2, 5100-3, 5100-4 bu operasyonlar wsh- ön tutturma hesabına girecek". Ayrıca "Kaynak yok denen operasyonlar etudlerde".
- **Ne yapıldı:**
  - `YikamaOzetEsleme.Esle` ada göre eşliyor. `TUTTURMA` deseni dc3bf85'ten beri dört kodun hepsini (ÖN / GÖMLEK PARÇA ÖN / GÖMLEK ÖN / KOL TUTTURMA) ATTACH FRONT'a götürüyor.
  - Ad eşlemesi bölümden önce yapıldığı için etütte bölümü boş olan işlem de yüke giriyor.
  - Selin'in listesindeki eksik üç ad teste eklendi.
- **"Kaynak yok"un anlamı:**
  - Satıra hiç yük düşmemiş demek (`SmvCozucu.KaynakYok`: katalog SMV yok, rota/etüt dakikası 0 ya da satıra eşlenen order yok).
  - dc3bf85 öncesi paketlerde bu işlemler "eşlenmeyen" satırına gidiyordu; ATTACH FRONT / BUTTON SEWING satırları "Kaynak yok" görünüyordu.
- **Dokunulan dosyalar:** `SentezPlaning/tests/SentezPlaning.Tests/YikamaSablonGuncellemeTests.cs`
- **Komutlar:**
  ```bash
  dotnet test SentezPlaning/tests/SentezPlaning.Tests --filter "FullyQualifiedName~YikamaSablonGuncelleme"
  ```
- **Sonuç / doğrulama:**
  - 25/25 test geçti.
  - Canlı DB kontrolü yapılamadı: sorgu.ps1 sunucuya bağlanamadı ("Server is not found or not accessible").
- **Commit:** `15e7535` — test(sentez-planing/yikama): 5100-2/3/4 tutturma kodlari ATTACH FRONT'a eslenir

### 3. 5402-1 DÜĞME DİKME → WSH- ATTACH BUTTON
- **Neden:** Asiye H.: "5402-1 yeni bir operasyon, onu da WSH- ATTACH BUTTON olarak ekleyelim (wsh-attach front satırının altına gelebilir)".
- **Ne yapıldı:**
  - `YikamaOzetEsleme.Satirlar`: 210 "WSH-BUTTON SEWING" satırı kaldırıldı; yerine 195 "WSH- ATTACH BUTTON" eklendi (Islak Önce, ATTACH FRONT'tan hemen sonra). `DUGME DIKME` deseni yeni satıra gidiyor.
  - `OperasyonRepository.KodDegistir(eski, yeni, etiket, sira)`: tek transaction içinde operasyon, operasyon_param ve operasyon_style kodlarını taşır. Yeni kod zaten varsa hiçbir şey yapmaz.
  - `OperasyonStore.SablonGoc3` (meta `operasyon.sablon-2026-10-30`): dc3bf85 kurulumlarında katalogdaki "WSH-BUTTON SEWING" kodunu yeni koda taşır. SMV ve parametreler korunur. Eski kod yoksa ve yeni de yoksa tohum satırını ekler.
  - Kapasite grubu yok (şablonda karşılığı yok), SMV etütten.
- **Dokunulan dosyalar:** `SentezPlaning/api/Sentez/Planning/YikamaOzetEsleme.cs`, `.../OperasyonStore.cs`, `SentezPlaning/api/Storage/OperasyonRepository.cs`, `SentezPlaning/tests/SentezPlaning.Tests/OperasyonStoreTests.cs`, `.../YikamaSablonGuncellemeTests.cs`
- **Komutlar:**
  ```powershell
  dotnet test SentezPlaning/tests/SentezPlaning.Tests
  powershell -ExecutionPolicy Bypass -File .\Deploy-IIS.ps1
  Compress-Archive -Path .\publish\* -DestinationPath X:\Gitlab\fredericTr\SentezPlaning-paket-2026-10-30-a48c810.zip -Force
  ```
- **Sonuç / doğrulama:**
  - 301/301 test geçti. Yeni testler: göç SMV, sıra ve parametreyi taşıyor; satır ATTACH FRONT'un hemen altında.
  - Paket: `SentezPlaning-paket-2026-10-30-a48c810.zip` (8,3 MB).
  - Görsel test yapılmadı.
- **Commit:** `a48c810` — feat(sentez-planing/yikama): DUGME DIKME satiri WSH- ATTACH BUTTON, ATTACH FRONT'un altinda

## Kararlar
- Ad değişikliği için katalog satırı silinip yeniden eklenmedi; kod taşındı, böylece kullanıcının girdiği SMV ve haftalık parametreler kaybolmuyor.
- ATTACH BUTTON hiçbir kapasite grubuna bağlanmadı (istek yalnız satır ve yer).
- Eşleme kodu değiştirilmedi; mevcut desen istenen dört kodu zaten kapsıyor.

## Açık kalanlar / sonraki adım
- Müşteride dc3bf85 paketi kurulu mu, teyit edilecek. Kuruluysa ve hâlâ "Kaynak yok" görünüyorsa:
  - Etütte 5100-x satırlarının `StandartTime1` değeri 0 olabilir.
  - Kodlar WASHING (50) altında olmayabilir.
  - DB erişimi gelince `q4.sql` ile bakılacak.
