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

### 4. Personel giriş-çıkış (PDKS) sorgusu Modfex için uyarlandı
- **Neden:** Kullanıcı, Modasima sentezservis'teki PDKS sorgusunun (`Modasima/sentezservis/src/SentezServis.Core/Pdks/PdksDeposu.cs`) Modfex'e uyarlanmasını istedi.
- **Bulgular (zkbiotime, 100.119.104.122):**
  - `zkbiotime` canlı; `zkbiotime1` 19.11.2025'te kalmış eski kopya.
  - Cihazlar Yuz1 ve Yuz2. `punch_state` alanı 0 = giriş (06–07), 1 = çıkış (16).
  - Puantaj (`att_payloadtimecard`) clock_in/clock_out o gün ve ertesi gün boş kalıyor; 2 Ekim ve 3 Ekim'de 0 satır dolu.
  - Hafta tatili cuma; cumartesi az hareket var.
  - Modasima'daki `emp_code <> '24'` istisnası burada yok (öyle bir personel yok), kaldırıldı.
  - Administration personelinin çoğu çıkış okutmuyor.
- **Değişiklikler:** Sorgu yalnızca ham hareketleri okuyor. Giriş = bugünkü İLK state=0 hareketi (eskisi MAX'tı, öğleden sonra yanlış sonuç verirdi).
  Çıkış = önceki iş gününün SON state=1 hareketi. Gruplama ada göre değil, personel id'sine göre.
- **Sonuç / doğrulama:** @Gun = 2026-10-01 ile denendi: 337 satır, 0,7 sn; çıkışların hepsi 16'da, girişler 06–07'de.
  Bugün (cumartesi, hareket yok) önceki gün olarak 10-01 seçildi, 295 satır döndü.
- **Sorgu:**
  ```sql
  -- Modfex PDKS — önceki iş gününün ÇIKIŞI + bugünün GİRİŞİ
  -- Veritabanı: zkbiotime (100.119.104.122). zkbiotime1 2025 sonunda kalmış eski kopyadır.
  -- Cihazlar (Yuz1, Yuz2) yönü kaydeder: punch_state 0 = giriş, 1 = çıkış.
  -- Puantaj (att_payloadtimecard) gün içinde boş kaldığı için kullanılmaz; ham hareket okunur.
  DECLARE @Gun date = CONVERT(date, GETDATE());
  
  -- Önceki iş günü: bugünden önce hareket olan son gün (cuma tatili / cumartesi otomatik atlanır).
  DECLARE @Onceki date = (
      SELECT MAX(CONVERT(date, punch_time))
        FROM dbo.iclock_transaction
       WHERE punch_time < @Gun);
  
  WITH cikis AS (
      SELECT emp_id, MAX(punch_time) AS Cikis
        FROM dbo.iclock_transaction
       WHERE punch_state = 1
         AND punch_time >= @Onceki AND punch_time < DATEADD(day, 1, @Onceki)
       GROUP BY emp_id
  ), giris AS (
      SELECT emp_id, MIN(punch_time) AS Giris
        FROM dbo.iclock_transaction
       WHERE punch_state = 0
         AND punch_time >= @Gun AND punch_time < DATEADD(day, 1, @Gun)
       GROUP BY emp_id
  )
  SELECT d.dept_name  AS Departman,
         p.emp_code   AS SicilNo,
         p.first_name AS Ad,
         p.last_name  AS Soyad,
         @Onceki      AS OncekiGun,
         CONVERT(varchar(5), c.Cikis, 108) AS Cikis,
         CONVERT(varchar(5), g.Giris, 108) AS Giris
    FROM dbo.personnel_employee p
    LEFT JOIN dbo.personnel_department d ON d.id = p.department_id
    LEFT JOIN cikis c ON c.emp_id = p.id
    LEFT JOIN giris g ON g.emp_id = p.id
   WHERE p.status = 0
     AND (c.Cikis IS NOT NULL OR g.Giris IS NOT NULL)
   ORDER BY d.dept_name, p.first_name, p.last_name;
  ```

### 5. PDKS raporları: 08:10 giriş/çıkış maili + 45 günlük devam Excel'i
- **Neden:** Kullanıcı istedi. Giriş/çıkış sorgusu her gün 08:10'da çalışıp mail atılacak.
  Her gün son 45 günün kişi × gün Excel'i gönderilecek: solda departman, ad soyad, yerel ad; hücrelerde OK / NON (kırmızı) / +3h / -3h.
  Modfex mailleri ModaSima'dan ayırt edilebilmeli. Her rapor ayrı alıcıya gidecek ve alıcılar arayüzden girilecek.
- **Ne yapıldı:**
  - ModaSima'dan zamanlama parametreleri taşındı (`git format-patch` + `git apply`): 60de775 (yalnızca zamanlayıcı, IsUclari, Sorgular, JobParameter, göç 017→016),
    2cd81a9, c66da4a, a5173a0, d7e000b (web ZamanlamaParametreModal, DinamikForm). Hepsi çakışmasız uygulandı.
  - Mail kuyruğuna dosya eki eklendi: göç `017_bildirim_ekleri.sql`, `BildirimSatiri`'na EkAdi/EkIcerik, `EpostaGonderici` Attachment ekliyor, `GonderenAdi` ayarı.
  - `Ayarlar`'a `PdksBaglantiCumlesi`, `FirmaAdi` ("Modfex"; konu satırı `[Modfex] ...`) ve `SaatDilimi` eklendi.
    Saat dilimi boşsa sunucunun yerel saati kullanılıyor; eskiden Europe/Istanbul'a sabitti, Mısır ekim sonunda Türkiye'den 1 saat geri düşüyor.
  - `src/SentezServis.Core/Pdks/`: PdksDeposu (salt okunur, punch_state '0'/'1' metin olarak), PdksDevamAnalizi, PdksDevamExcel (ClosedXML geri eklendi),
    PdksGirisCikisJob (`10 8 * * 0-4,6`), PdksDevamJob (`15 8 * * 0-4,6`, gün sayısı parametresi 45), PdksAlicilari (boşsa mail gitmez, genel listeye düşmez).
- **Analiz (canlı zkbiotime):** İş günleri pazar–perşembe (~335 kişi); cuma ~13, cumartesi ~58 kişi.
  Giriş+çıkışı olan iş günlerinin ortalaması 562 dk, %85'i 540–569 dk aralığında. BioTime'daki "normal work time" 565 dk → standart 565 dk alındı.
  İş günü veriden çıkarılıyor: aktif personelin ≥%50'si okuttuysa iş günü (30.08 tatili de böyle ayrıldı).
  Fark ≥60 dk olunca tam saate aşağı yuvarlanıyor. İş günü olmayan günde çalışılan sürenin tamamı fazla mesai sayılıyor.
  İşe giriş tarihinden (hire_date) önceki günler boş kalıyor.
- **Sonuç / doğrulama:** Canlı veriyle scratch konsoldan çalıştırıldı: 361 personel, 10.656 kişi-gün, 2 sn, Excel 90 KB.
  Hücre dağılımı: OK 8665, NON 760, +h 449, -h 141, tek okutma 1050. Hiç gelmeyen 2 kişi.
  .NET testleri 202/202 (yeni `PdksDevamTestleri`, içinde salt okunur kaynak taraması da var), web testleri 40/40.
- **Commit:** `9fd3457` — PDKS raporlari: 08:10 giris/cikis maili ve 45 gunluk devam Excel'i, is bazli alicilar

## Açık kalanlar (güncel)
- Sunucuya yayın yapılmadı. Yayın sonrası sunucudaki `appsettings.json`'a `PdksBaglantiCumlesi` eklenmeli (`docs/pdks-raporlari.md`),
  ardından Zamanlama ekranından iki işin alıcıları girilmeli.
- Sunucudaki `Eposta:Gonderen` adresi hâlâ modasima.local olabilir; kontrol edilmeli.
- Security personeli vardiyalı çalıştığı için yüksek NON görünüyor; kural gerekirse ayrıca ele alınacak.
- Zamanlama parametre ekranı canlı arayüzde gözle denenmedi (birim testleri geçiyor).

### 6. Günlük giriş/çıkış maili bt@modasima.com.tr'ye test olarak gönderildi; mail düzeltmeleri
- **Neden:** Kullanıcı günlük maili görmek istedi (Excel'li olanı değil). Excel mailinde gövde tablosu olmayacak, Excel yalnızca ek olarak gidecek.
- **Ne yapıldı:**
  - Bu makinede Outlook COM çalışmadı (80080005). SMTP bilgileri ModaSima'nın yerel `appsettings.json` dosyasından okundu:
    mail.kurumsaleposta.com:465, noreply@modasima.com.tr. Parola ekrana yazdırılmadı.
  - Modfex'teki `EpostaGonderici` BCL `SmtpClient` kullanıyordu; bu sınıf 465 portunu (implicit SSL) desteklemiyor.
    ModaSima f7622b5 örnek alınarak MailKit'e (4.18.0) geçildi; dosya eki ve GonderenAdi korundu.
  - Test için scratch konsol yazıldı: canlı zkbiotime → `BildirimServisi.PdksGirisCikisAsync` → LocalDB'de geçici `bildirim_kutusu` (PdksMailDeneme) → `EpostaGonderici`.
    Gönderen "Modfex SentezServis <noreply@modasima.com.tr>", konu "[Modfex] Personnel in/out — 03.10.2026", 295 satır.
  - Gövde 182 bin karakterdi; hücre stilleri tek `<style>` bloğuna alındı, 63 bin karaktere indi (Gmail 102 KB'tan sonrasını kırpıyor).
    Gönderilen test maili hafifletmeden önceki sürümdü.
  - `pdks-devam` maili sadeleşti: gövdede tek satır var, rapor yalnızca Excel ekinde.
- **Sonuç / doğrulama:** Mail gönderildi (SMTP hata vermedi). Testler 202/202.
- **Commit:** `e567e65` — Mail: MailKit'e gecis (465 implicit SSL), devam maili yalnizca Excel eki, gunluk tablo hafifletildi
- **Ek (devam maili testi):** Aynı scratch konsolla `pdks-devam` maili de gerçek kodla üretildi ve bt@modasima.com.tr'ye gönderildi.
  Konu "[Modfex] Attendance last 45 days — 02.10.2026"; gövde tek satır; ek `Modfex-attendance-2026-10-02.xlsx` (90 KB, 361 personel, 19.08–02.10).
