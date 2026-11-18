# yaziciaktarici — 2026-11-18

## Bağlam
Mal kabul Zebra'sı (ZDesigner ZD888-203dpi ZPL) 192.168.0.184'e USB ile bağlı ve `\192.168.0.184\Barcode` olarak paylaşılıyor.
Yazıcının kendi ağ bağlantısı yok; .184'te yalnız SMB (445) açık.
Bizim PC domain dışında (WORKGROUP), paylaşıma domain kullanıcısı olmadan girilemiyor. El terminali (Android) Windows paylaşımına zaten basamaz.

## Yapılanlar

### 1. Paylaşıma erişim denemesi
- `net use \192.168.0.184\IPC$ /user:modfextr\administrator ...` çalıştı; paylaşımda `Barcode` yazıcısı görüldü.
- `copy /b dosya \192.168.0.184\Barcode` "Access is denied" verdi.
- winspool `OpenPrinter` 1326 (logon failure) verdi: yazdırma kuyruğu geçici oturumu kullanmıyor.
- `cmdkey /add:192.168.0.184 /user:modfextr\administrator /pass:...` ile kayıt sonrası RAW iş gitti (ilk bağlantı yaklaşık 2 dakika sürdü) ve etiket çıktı.
- **Not:** domain yönetici kimlik bilgisi bu PC'nin Kimlik Bilgisi Yöneticisi'nde kayıtlı duruyor. Silmek için: `cmdkey /delete:192.168.0.184`. Öneri: yalnız yazdırma yetkili bir domain kullanıcısı.

### 2. Yeni repo: Windows servisi (kullanıcının seçimi: "3'ü yapalım, repo açalım")
- **Repo:** `git@gitlab.com:modfex-apparel/yaziciaktarici.git` (push ile oluştu). Yerel klon: `X:\Gitlab\modfex-apparel\yaziciaktarici`.
- **Ne yapıyor:** .NET 10 Worker + `Microsoft.Extensions.Hosting.WindowsServices`, servis adı `ModfexYaziciAktarici`.
  - `Dinleyici`: TCP portunu dinler. Her bağlantı bir iş: bağlantı kapanınca ya da `BostaKalmaMs` (1500) boyunca veri gelmeyince biter. Aynı yazıcıya işler sırayla gider; `AzamiBayt` (4 MB) üstü reddedilir; boş bağlantı yok sayılır.
  - `SpoolerCikisi`: winspool `OpenPrinter` / `StartDocPrinter` (RAW) / `WritePrinter`.
  - `GuvenlikDuvari`: açılışta `netsh` ile "Modfex Yazici Aktarici" kuralı (TCP portlar, `remoteip=localsubnet`).
  - Günlük: Olay Görüntüleyicisi > Uygulama, kaynak `ModfexYaziciAktarici`.
  - Ayar: `appsettings.json` > `Aktarici:Hatlar` = `[{Port:9100, Yazici:"ZDesigner ZD888-203dpi ZPL"}]`.
- **Kullanıcı isteği:** "Windows'ta kullanıcı açık olmasa bile çalışsın." `kur.ps1` her kurulumda `sc config obj= LocalSystem start= delayed-auto depend= Spooler` uyguluyor; çökmede 10 sn sonra yeniden başlıyor.
- **Kurulum betiği:** `deploy/kur.ps1 -Kaynak publish [-Bilgisayar 192.168.0.184]`. Uzaktan kurulumda dosyalar `C$` üzerinden kopyalanıyor, servis `sc.exe \ip` ile kuruluyor; hedefteki appsettings korunuyor.
  - İlk sürümde iki hata vardı: PowerShell 5.1'de dizi splat'i uzak bilgisayar argümanını bozdu; ayrıca `sc` adı Set-Content kısaltmasıyla çakışıyor. Çözüm: `ScCalistir` fonksiyonu.
- **Komutlar:**
  ```powershell
  dotnet test            # 4/4
  dotnet publish YaziciAktarici -c Release -r win-x64 --self-contained -p:PublishSingleFile=true -o publish
  .\deploy\kur.ps1 -Kaynak .\publish -Bilgisayar 192.168.0.184
  ```
- **Sonuç / doğrulama:**
  - .184'te servis RUNNING: AUTO_START (DELAYED), LocalSystem, Spooler bağımlı.
  - 9100 dışarıdan açık. TCP ile gönderilen deneme etiketi çıktı (kullanıcı teyidi: "çıktı etiket").
  - Olay günlüğü uzaktan okunamadı (RPC kapalı).
- **Commitler:** `2bf4c27`, son düzeltme bu commit.

## Açık kalanlar
- PM66'da malkabul Ayarlar: yazıcı IP `192.168.0.184`, port `9100`.
- Yönetici kimlik bilgisinin bu PC'den silinmesi ve ayrı bir yazdırma kullanıcısı.
