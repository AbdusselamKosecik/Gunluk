# muftelif — 2026-11-23

## Bağlam
`OrderTakipWeb/MFG-Yazilimci-Teslim/` klasörüne yeni talimat geldi (YAZILIMCI-NOTLARI.txt + MFG-Demo.html):
order takip ekranı "MFG Genel Takip"e dönüşüyor — Order Takip (kalite kartları), Numune Bulma, Tamir/Kurtarma; 6 kabul testi.
Ayrıca 19.11'den kalmış commit edilmemiş tamir özeti düzeltmesi vardı.

## Yapılanlar

### 1. Bekleyen tamir özeti düzeltmesi commit edildi
- **Neden:** 19.11 22:57'de yazılmış, testleri yeşil ama commit edilmemiş (`OrderTakip.TamirOzeti`: giren = max(Finish Tamir çıkış, Yıkama Tamir giriş), dönen = Finish Tamir giriş).
- **Dokunulan dosyalar:** `OrderTakipWeb/api/Takip/OrderTakip.cs`, `OrderTakipWeb/tests/OrderTakipTests.cs`
- **Sonuç:** 26/26 test. **Commit:** `a835d9f`

### 2. MFG Genel Takip (üç bölüm)
- **Kullanıcı kararları:** Kurtarma → SentezLive `UZM_ORDERTAKIP_KURTARMA` (SSMS'te kullanıcı çalıştırır). 1. Kalite = mamul depo (ReceiptType 10, depo 5); 2. Kalite = yalnız kurtarma girişleri. Numune tablosunu kullanıcı söyleyecek.
- **Bulgular (canlı, salt okunur, SentezPlaning dev bağlantısı):** SentezLive'da adında/kolonunda numune/sample geçen tablo YOK (687 tablo). 95360: kesim 2566, 1. kalite 2545 (spec demo 2565), Yıkama 2566/2565/1, tamir 76/76/0, müşteri `Erp_CurrentAccount` = COH TURKEY…; spec'teki "AQUADUCT" aslında yıkama adı. 95361 = A9268-1810 RINSE.
- **Ne yapıldı:**
  - `OrderBaslik` + Customer/Kesim/BirinciKalite/IkinciKalite; başlık SQL'ine alt sorgular. `Kalite` kaydı: Kalan = Kesim − 1.K − kaynak 2.K (kurtarma Kalan'ı değiştirmez — MFG-Demo.html ile aynı; ilk denemede −10 çıktı, düzeltildi).
  - `IOrderKaynak` → `BaslikAsync` + `HareketlerAsync`; demo 95360 (gün toplamları 3/134/49 kayda bölündü), 95361.
  - `api/Kurtarma/`: `KurtarmaHesap` (doğrulama, toplam, havuz), `BellekKurtarmaDeposu` (demo), `SqlKurtarmaDeposu` (Serializable + UPDLOCK/HOLDLOCK; çıkış ≤ bakiye). Boş model/yıkama: önceki kayıt → Sentez iş emri → yükleme numunesi.
  - `api/Numune/`: arama modları any/style/order/code/barcode, `DemoNumuneKaynak` (A9255-1141: 6 orijinal + 20 yükleme, uzun açıklamalar), canlıda `BagliOlmayanNumuneKaynak` → 503 açık mesaj.
  - `Program.cs`: `/api` grubu (giriş zorunlu): order, numune, kurtarma/order/{no}, kurtarma/havuz, POST kurtarma (400/404/409).
  - `wwwroot/index.html` MFG-Demo görünümüyle yeniden yazıldı; giriş, istek iptali, günlük satır + açılır kayıt korundu; kurtarma sonrası Order Takip'e dönünce 2. kalite tazelenir.
  - `db/0001_kurtarma.sql` (idempotent; GRANT satırı yorumda).
- **Dokunulan dosyalar:** `OrderTakipWeb/{README.md, api/Program.cs, api/Takip/*, api/Kurtarma/*, api/Numune/*, api/wwwroot/index.html, db/0001_kurtarma.sql, tests/GenelTakipKabulTests.cs, tests/SqlKurtarmaDeposuTests.cs, MFG-Yazilimci-Teslim/*}`
- **Komutlar:**
  ```bash
  cd OrderTakipWeb && dotnet test OrderTakipWeb.slnx                                     # 47/47
  ORDERTAKIP_TEST_SQL='Server=(localdb)\MSSQLLocalDB;Database=OrderTakipKurtarmaTest;Integrated Security=true;TrustServerCertificate=true' dotnet test OrderTakipWeb.slnx
  cd api && OrderTakip__DemoVeri=true OrderTakip__GirisGerekli=false ASPNETCORE_URLS=http://localhost:5187 dotnet run --no-launch-profile
  ```
- **Sonuç / doğrulama:** 47/47 (kabul 1-6 xUnit; SQL depo LocalDB'de, eşzamanlı iki 7'lik çıkıştan biri geçti; migration iki kez çalıştı). Demo 390 px Chrome: kabul 1-6 arayüzde geçti, yeniden yüklemede 2.K 11 kaldı, yatay taşma yok. Canlı salt okunur: 95360 kartlar 2566/2545/0/21 + "kurtarma kayıtları okunamadı" uyarısı (tablo yok), numune 503.
- **Commit:** `14d1d96` — feat(order-takip-web): MFG Genel Takip - kalite kartlari, Numune Bulma, Tamir/Kurtarma havuzu

## Kararlar
- Kalan formülü teslim demosunu izler (kurtarma yalnız 2. kalite kartını büyütür).
- Kurtarmada order no yalnız rakam (spec pattern); order Sentez'de yoksa kayıt reddedilir (404).
- Numune "Son Aramalar" cihazda (localStorage), kurtarma sunucuda.

## Açık kalanlar / sonraki adım
- **Numune kaynağı:** kullanıcı Sentez tablo/ekran adını verecek → `SentezNumuneKaynak`.
- **`db/0001_kurtarma.sql`** SSMS'te yetkili hesapla + uygulama kullanıcısına SELECT, INSERT.
- 1. Kalite canlıda 2545, spec 2565 — kaynak teyidi (mamul depo girişi doğru mu?).
- IIS paketi / sunucu kurulumu yapılmadı.
