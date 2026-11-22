# onaymerkezi — 2026-11-22

## Bağlam
Kullanıcı Kesimhane pastal onayının Telegram'dan gelmesini istedi (bkz. kesimhane günlüğü). Kesimhane masaüstü uygulaması olduğu için HTTP geri çağırma alamaz. Karar, Onay Merkezi tarafından aynı veritabanına yazılmalı.

## Yapılanlar

### 1. PastalSonucYazici (`9939c5e`)
- **Ne yapıldı:** `Servis/PastalSonucYazici.cs`, bir `IGeriCagirici` süsleyicisi.
  - Olay kapanınca önce `PastalSonucu.Coz` çalışır. Koşullar: tür kodu `pastal`, kaynakRef `PastalRevizyon:{id}`, durum Onaylandı ya da Reddedildi.
  - Sonra `UZM_PastalRevizyon` güncellenir: OnayDurum 1/2, OnayAt, OnayBy = NULL, OnayNotu "Telegram onay: Ahmet, Mehmet" ya da "Telegram ret: Ahmet — neden".
  - Not en fazla 100 karakter (UdtExpLong = nvarchar(100)).
  - Yalnız son ve bekleyen revizyon güncellenir (kesimhane `OnayVerAsync` ile aynı kural). Tablo yoksa hiçbir şey yapılmaz.
  - Zaman aşımı ve iptal revizyona dokunmaz.
  - Yazım hatası loglanır; ardından HTTP geri çağırma yine çalışır.
- **Dokunulan dosyalar:** `Program.cs` (IGeriCagirici = PastalSonucYazici(HttpGeriCagirici)).
- **Testler:** `PastalSonucYaziciTestleri`: çözümleme, retler, kısaltma, hata yutma; DB testi TransactionScope ile.
- **Sonuç:** 201/201 (3 canlı YZ testi atlandı).

## Açık kalanlar
- Sunucuya kurulum (kullanıcı onayıyla).
- Panel ayarları: `kesimhane` uygulaması ve `pastal` olay türü.

### 2. Karar Sentez kesim kaydına (`350d70c`)
- **Neden:** Pastal Sentez'den okunacak (kesimhane günlüğü). Bu yüzden UZM_PastalRevizyon yazımı kaldırıldı.
- **Ne yapıldı:**
  - `PastalSonucu.Coz` artık kaynakRef `SentezKesim:{RecId}` arıyor ve şu güncellemeyi yapıyor: `UPDATE Erp_WorkOrderProduction SET UD_CuttingApprove = 'Onay: Ahmet, Mehmet' | 'Ret: Ahmet - neden'`. Yalnız alan `'Bekliyor #{olay}'` iken yazılır.
  - Zaman aşımı ve iptal alanı NULL yapar, böylece kayıt yeniden gönderilebilir. Değer 50 karaktere kısaltılır.
- **Test:** DB testi TransactionScope içinde aynı anda tek bağlantıyla yazıldı (iki bağlantı açık kalınca dağıtık işleme yükselip hata veriyordu). 201/201.

### 3. Sunucuya kurulum (kullanıcı: "günceller misin")
- **Paket:** `dagitim/yayinla.ps1 -Hedef <scratch>\om-yayin`. `appsettings*.json` paketten çıkarıldı; sunucu ayarları ezilmesin (kural). Zip boyutu 56 MB.
- **Sunucu:** MODFEXSRV 192.168.0.2, WinRM, `Import-Clixml ~\srv02.cred`. Servis `SentezOnayMerkezi` (nssm), klasör `C:\Server\Sentez_Onaymerkezi`.
  - Yedek: `C:\Modfex\Sentez_Onaymerkezi.yedek-2026-11-22`.
  - Sıra: Stop-Service → `Expand-Archive -Force` (zip `C:\Modfex\paket\`) → Start-Service.
- **Doğrulama:**
  - `/api/surum`: 35e1d89 → `1.0.0+350d70c`, servis Running.
  - `/api/olay/0` anahtarsız → 401; panel → 302.
  - appsettings dosyalarının tarihleri değişmedi.
- **Not:** Aradaki 0460446 yzsorgu değişikliği ayrı kurulur (`yzsorgu/kur.ps1`); bu kurulumla gitmedi.
- **Kalan:** Panelde `pastal` olay türü kullanıcı tarafından tanımlanacak.

### 4. Yetkiler sayfası ve PDF (`70d49fe`, sunucuya kuruldu)
- **Kullanıcı:**
  - "PDF gönderelim. Bir de yetkileri ayarlayalım, onay kısmında."
  - Onaycı sorusuna cevabı: "Ben ai sor ve bunun gibi tüm işlemlerde kimin ne yapabileceğinin yetkisini vermem lazım."
  - Grup ve onay sayısı: Modfex Onay, 2 onay.
- **Canlı durum:** Kullanıcı panelden `pastal` türünü açmış (Modfex Onay grubu, 2 onay, görev PASTAL; Abdusselam ve Büşra).
  - TEST01 olay 34 reddedildi; olay 36 iki onayla onaylandı.
  - `UD_CuttingApprove` = "Onay: Büşra Kömürcügil, Abdusselam Kösecik". **Uçtan uca canlıda çalıştı.**
- **Yetkiler sayfası (`/yetkiler`):**
  - Kişi × aktif görev tablosu, onay kutularıyla.
  - Her görevin başlığında neye izin verdiği yazıyor (`YetkiOzeti.IzinVerdikleri`): YZ → /ai /sor, PDKS → /pdks /gelmeyenler /gec, ayrıca görevin bağlı olduğu olay türlerinin adları.
  - Kaydet, formdaki her görevin kişi listesini baştan yazar. Menüde Görevler'den önce duruyor.
- **PDF:**
  - `GorselTuru.Bul` artık `%PDF-` imzasını tanıyor.
  - `OlayServisi` PDF'i `BelgeGonderAsync` ile gönderiyor (dosya adı başlık.pdf); resimler yine `FotoGonderAsync` ile gidiyor.
  - YZ değerlendiricileri yalnız resim alıyor (`GorselTuru.Resim`).
  - Eski bir test PDF'in reddedilmesini bekliyordu; GIF'e çevrildi.
- **Testler:** `YetkiVePdfTestleri`; toplam 205/205.
- **Dağıtım:** Önceki kurulumla aynı yöntem. Yedek `C:\Modfex\Sentez_Onaymerkezi.yedek-2026-11-22b`; `/api/surum` = 70d49fe; appsettings tarihleri değişmedi.
