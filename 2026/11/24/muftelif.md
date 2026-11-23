# muftelif — 2026-11-24

## Bağlam
23.11'de OrderTakipWeb "MFG Genel Takip" (Order Takip + Numune Bulma + Tamir/Kurtarma) bitti ve push edildi
(`14d1d96`). Kullanıcı IIS paketi ve SQL istedi ("paket cikartirmisin iis cve sql"). OrderTakipWeb'in
daha önce hiç sunucu paketi yoktu.

## Yapılanlar

### 1. OrderTakipWeb IIS paketi + kurtarma yetki SQL'i
- **Neden:** Uygulama sunucuya kurulacak; kurtarma tablosu (`dbo.UZM_ORDERTAKIP_KURTARMA`) uygulama
  kullanıcısıyla kurulamaz (DDL yetkisi yok), SSMS'te yetkili hesapla çalıştırılacak SQL gerekiyor.
- **Ne yapıldı:**
  - `OrderTakipWeb/Deploy-IIS.ps1` (SentezPlaning'deki betik örnek alındı, sadeleştirildi):
    - `-Paket`: `dotnet publish -c Release -r win-x64 --self-contained false` →
      `../OrderTakipWeb-IIS-192.168.3.228-92/` (site, sql, ornek/appsettings.json, IIS-KURULUM.txt, betik) + `.zip`.
    - Paketlerken kontrol: web.config/dll/wwwroot var; appsettings.Development.json yok;
      `DemoVeri=false`, `GirisGerekli=true`; appsettings'te bağlantı dizesi/Jwt.Key BOŞ.
    - `-SkipPublish -OutputDir .\site -SetupIIS -Port 92`: sunucuda paket klasöründen kurulum
      (robocopy /MIR, logs ve mevcut appsettings.json korunur; havuz No Managed Code; logs Modify;
      eksik ortam değişkeni kırmızı uyarı).
  - Port 92 seçildi: 89 SarfKullanim, 90 SentezPlaning, 91 SentezSelvedge.
  - `OrderTakipWeb/IIS-KURULUM.txt`: şablon ({{COMMIT}}, {{TARIH}}, {{SUNUCU}}, {{PORT}} pakete doldurulur);
    SQL → site → ortam değişkenleri (`ConnectionStrings__Sentez`, `Jwt__Key`) → kontrol (95360) → sorun giderme.
  - `db/0002_kurtarma_yetki.sql`: `@Kullanici` değişkeni; yer tutucu kalırsa / kullanıcı yoksa / tablo yoksa
    THROW; `GRANT SELECT, INSERT` (dinamik, QUOTENAME). 0001'deki yorumlu GRANT satırı kaldırıldı.
  - `System.Security.Cryptography.Pkcs` 10.0.15 eklendi: SqlClient 7.0.1 9.0.13 getiriyordu (NU1903 high);
    10.0.8 de hâlâ uyarılıydı.
  - `.gitignore`: `OrderTakipWeb-IIS-*/` ve `.zip` (diğer paketlerle aynı kural).
- **Dokunulan dosyalar:** `OrderTakipWeb/Deploy-IIS.ps1`, `OrderTakipWeb/IIS-KURULUM.txt`,
  `OrderTakipWeb/db/0001_kurtarma.sql`, `OrderTakipWeb/db/0002_kurtarma_yetki.sql`,
  `OrderTakipWeb/api/OrderTakipWeb.csproj`, `OrderTakipWeb/README.md`, `.gitignore`
- **Komutlar:**
  ```bash
  cd OrderTakipWeb
  dotnet add api/OrderTakipWeb.csproj package System.Security.Cryptography.Pkcs --version 10.0.15
  dotnet test OrderTakipWeb.slnx
  powershell -NoProfile -ExecutionPolicy Bypass -File ./Deploy-IIS.ps1 -Paket
  # SQL denemesi: LocalDB'de OtPaketTest DB, USE SentezLive -> USE OtPaketTest, CREATE USER ot_app WITHOUT LOGIN
  sqlcmd -S "(localdb)\MSSQLLocalDB" -b -i 0001.sql   # iki kez
  sqlcmd -S "(localdb)\MSSQLLocalDB" -b -i 0002.sql   # iki kez
  ```
- **Sonuç / doğrulama:**
  - Testler 47/47, NU190x uyarısı kalmadı.
  - SQL: 0002 tablo yokken 50003, yer tutucuyla 50001 verdi; 0001 ve 0002 ikişer kez hatasız; ot_app
    INSERT yapabildi, UPDATE "permission denied". Test DB silindi.
  - Paketteki `site/OrderTakipWeb.dll` demo ortam değişkeniyle açıldı: index 200, `/api/order/95360` doğru;
    sırsız canlı ayarla "ConnectionStrings:Sentez eksik" diye bilerek açılmadı.
  - İlk denemede hata: PowerShell değişkenleri büyük/küçük harf ayırmıyor; `$paket` değişkeni `[switch]$Paket`
    parametresiyle çakıştı ("Cannot convert System.String to SwitchParameter"). `$hedef` yapıldı.
  - Paket: `X:\Gitlab\fredericTr\muftelif\OrderTakipWeb-IIS-192.168.3.228-92.zip` (2.8 MB), commit 7ca032c ile.
- **Commit:** `7ca032c` — build(order-takip-web): IIS paketi (Deploy-IIS.ps1 -Paket), kurtarma yetki SQL'i 0002, Pkcs 10.0.15

## Kararlar
- Sırlar pakete girmez; havuz ortam değişkeni (SentezSelvedge ile aynı yöntem).
- Jwt__Key: SentezPlaning ile aynı verilirse oturum ortak (README'deki tasarım); ayrı da olabilir.
- Uygulama kullanıcısına yalnız SELECT + INSERT: kurtarma bir hareket defteri, silme/güncelleme yok.

## Açık kalanlar / sonraki adım
- Sunucuya kurulum yapılmadı (sunucuya erişim yok): SSMS'te 0001 + 0002, site, ortam değişkenleri kullanıcıda.
- Port 92'nin sunucuda boş olduğu doğrulanmadı.
- Numune tablosu adı hâlâ bekleniyor (canlıda Numune Bulma 503 + açık mesaj).
- 1. Kalite canlı 2545 / spec 2565 farkı teyit bekliyor.
