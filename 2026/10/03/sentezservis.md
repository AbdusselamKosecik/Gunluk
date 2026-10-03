# sentezservis — 2026-10-03

## Bağlam
Evden VPN (Tailscale) ile çalışıldı. Sunucu `100.119.104.122` (MODFEXSRV, firmada 192.168.0.2).
Hedef: uygulamadaki ekran ve iş envanterini çıkarıp kullanılmayan modülleri kaldırmak.

## Yapılanlar

### 1. Envanter çıkarıldı
- **Neden:** Kullanıcı hangi ekran/servislerin silineceğine karar verecekti.
- **Ne yapıldı:** Liste koddan çıkarıldı (`web/src/components/Layout.tsx` MENU, `web/src/App.tsx` rotaları,
  `IJob` uygulamaları, `AddHostedService` kayıtları). Canlı uygulamaya evden ulaşılamadı:
  81 kapalı; 8080/8443'te başka bir panel var (UniFi benzeri, `api.err.LoginRequired`), SentezServis değil.
- **Not:** Sunucuya Windows yönetici erişimi yok; `uzman` hesabı SQL içindir, Windows'ta 1326 (yanlış kullanıcı/şifre) hatası verir.

### 2. Modüller kaldırıldı
- **Neden:** Kullanıcı kararı. Kaldırılan ekranlar: /raf /etiket-ciktisi /kurlar /eksi-stok /fatura
  /pazaryeri-siparisleri /forti /pazaryeri-hesaplari. Kaldırılan işler: eksi-stok-tarama, eksi-stok-mahsup,
  efatura-tetikle, pazaryeri-siparis-cek/hazirla/aktar, pazaryeri-cari-uret/aktar, forti-saglik.
- **Ne yapıldı:**
  - `src/SentezServis.Core/{Raf,EtiketCiktisi,Kur,Stok,Fatura,Pazaryerleri,Forti}` silindi.
  - `src/SentezServis.Host/Api/{Raf,EtiketCiktisi,Kur,EksiStok,Fatura,Forti,PazaryeriHesap,PazaryeriSiparis}Uclari.cs` silindi.
  - `Program.cs`: DI kayıtları, iş kayıtları, uç kayıtları ve pazaryeri tohum/doğrulama satırları çıkarıldı.
    `--paket-dogrula` artık FastReport'u `Varlik.EtiketRaporu` ile sınıyor (`deploy/tek-dosya-yayinla.ps1` hâlâ `etiketPdfBayt` bekliyor).
  - `Ayarlar.cs` / `BaglantiFabrikasi.cs`: Erp, Entegrasyon ve Mahsup bağlantıları kaldırıldı (artık kullanan yok).
    Forti, Pazaryeri, Crs ve EfaturaTetik ayar sınıfları da kaldırıldı. Sunucudaki appsettings'te bu anahtarlar kalsa da sorun çıkmaz, yok sayılır.
  - `SaklamaJob`: forti_*_olcumleri, eksi_stok_bulgulari, mahsup_calistirmalari ve efatura_tetikleri kuralları çıkarıldı.
  - `Core.csproj`: ClosedXML, Microsoft.Extensions.Http ve EtiketCiktisi frx kaynağı çıkarıldı.
  - Web: 9 sayfa, 8 API istemcisi, `utils/fatura`, Forti tipleri/mock'ları, Forti CSS'i, menü satırları ve kullanılmayan ikonlar silindi.
  - Testler: 19 modül test dosyası silindi; `SaklamaJobTestleri` güncellendi.
  - Dokümanlar: 8 modül dokümanı, örnek etiket xlsx/pdf klasörleri ve `raf adresi 08.08.2026.xlsx` silindi;
    `api-kontrat.md` ve `saklama-politikasi.md` güncellendi.
- **Komutlar:**
  ```bash
  dotnet build src/SentezServis.Host/SentezServis.Host.csproj
  dotnet test tests/SentezServis.Core.Tests/SentezServis.Core.Tests.csproj
  cd web && npm run build && npm test && npm run lint
  ```
- **Sonuç / doğrulama:** Host derlendi; .NET testleri 182/182 geçti; web build tamam, vitest 28/28 geçti, lint'te hata yok.
  Çözümün tamamını derlemede Ajan projesi `appsettings.json` bulunamadığı için hata veriyor (önceden de vardı, bu değişiklikle ilgili değil).
- **Commit:** `df37161` — Kullanilmayan moduller kaldirildi: raf, etiket ciktisi, kur, eksi stok, e-fatura, pazaryeri, FortiGate

## Kararlar
- Veritabanı tabloları (eksi_stok_*, mahsup_*, efatura_tetikleri, forti_*, pazaryeri/sipariş/cari tabloları) **silinmedi**; migrasyonlar geçmiş olarak duruyor.
- Kaldırılan işler açılışta `dbo.isler.kayitli = 0` olur (IsKayitDefteri.EsitleAsync); zamanlayıcı `kayitli = 1` şartıyla bunları çalıştırmaz.
- Toplayıcı (syslog) projesi duruyor. Ancak FortiGate VPN/web erişim kayıtlarını gösteren ekran ve uçlar kaldırıldığı için bu verinin artık arayüzde görüntülenecek yeri yok.

## Açık kalanlar / sonraki adım
- Sunucuya yayın yapılmadı (`deploy/uzaktan-yayimla.ps1`). Firmada veya Windows yönetici hesabıyla yapılacak.
- Toplayıcı kaldırılsın mı? Kullanıcıya sorulacak.
- Eski tablolar düşürülsün mü? Kullanıcıya sorulacak.

### 3. Modfex masaüstü uygulamaları tek sunucuya bağlandı
- **Neden:** Kullanıcı tüm Modfex sunucu bilgisinin `100.119.104.122` olduğunu, kullanıcının `uzman` olduğunu belirtti.
  bantdurumekrani, depo, paketleme ve sevkiyat eski geliştirme sunucusuna bakıyordu (`100.73.123.69` / `ModaSima2026` / `sa`).
- **Ne yapıldı:** `%LOCALAPPDATA%\Modfex\{bantdurumekrani,depo,paketleme,sevkiyat,kesimhane,bantsayim}\ayarlar.json`
  dosyalarında Sunucu, Veritabani (`SentezCore`), SqlKullanici (`uzman`) ve SqlSifreKorumali güncellendi.
  Şifre `dpapi:` + DPAPI(CurrentUser, entropi "Modfex.Ortak.Ayarlar") biçiminde yazıldı. Her dosyanın yanına `ayarlar.json.yedek-20261003` yedeği alındı.
- **Sonuç / doğrulama:** `uzman` ile SQL bağlantısı açıldı. Erişilebilen veritabanları: SentezCore, zkbiotime, zkbiotime1 (ModaSima2026 bu sunucuda yok).
  Her dosyadaki şifre geri çözülerek doğrulandı.
- **Not:** Bu yerel bir ayar değişikliği, repoya commit yok. Uygulamalar artık canlı SentezCore'a bağlanıyor.
