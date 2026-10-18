# sentezservis — 2026-10-18

## Bağlam
Kullanıcı: "sentezservis de girisler gelmiyor sabah 8:30 da neden olabilir. cihazlarda birsey yapmak gerekirmi".
modfexsrv Tailscale'de çevrimdışı; SQL'e 192.168.0.2 üzerinden bağlanıldı. Sorguların hepsi salt okuma.
Scratchpad `sorgu2.ps1` ile `MODFEX_SUNUCU` / `MODFEX_DB` ortam değişkenleri kullanıldı.

## İnceleme (systematic debugging)
1. **ZKBioTime kayıtları zamanında geliyor mu?**
   - `zkbiotime.dbo.iclock_transaction`: bugün 08:10'a kadar 334 okutma, 326 kişi; önceki iş günlerinde ~330.
   - Yükleme gecikmesi yok. İki cihazın kayıt id'leri iç içe, yani ikisi de gerçek zamanlı yazıyor.
   - `iclock_terminal`: Yuz1 (SYZ8241400430, 192.168.0.30) ve Yuz2 (SYZ8241400429, .29) ikisi de aktif.
2. **İş çalışmış mı?**
   - `SentezServis.dbo.calistirmalar` (pdks-giris-cikis): 05:10:11 UTC'de (08:10 yerel) başarılı.
   - Özet: "357 personel (222 girissiz, 33 çikissiz)". 14.10'dan beri 210–222 girişsiz; 10–13.10 arasında 30–43.
3. **Raporun sorgusu bugün 08:10:11 itibarıyla elle çalıştırıldı:** 31 girişsiz çıktı. Çelişki var.
4. **Sunucudaki özet metni güncel kodla uyuşmuyor** ("dün … çıkışsız, dün … gelmedi" kısmı yok).
   Sunucuda 13.10 düzeltmesinden (`5b0f6ef`) önceki sürüm çalışıyor.
5. **`punch_state` dağılımı (saat 10:00'dan önce):** bugün Yuz1'in 199 okutmasının hepsi '1' (Çıkış), Yuz2'nin 135 okutması '0' (Giriş).
   Önceki günlerde ikisi de '0'.
   - Eski sürüm girişi yalnız '0' işaretinden okuyor: 357 − 135 = 222. Tam açıklama bu.
   - `iclock_terminaluploadlog`: Yuz1'de 08:06'da User/BioPhoto 5527 kaydı yapılmış (kullanıcı kaydı sırasında durum değişmiş olabilir).

## Sonuç / öneri (kod değişikliği yok)
- **Cihaz:** Yuz1'in durum tuşu Çıkış'ta kalmış. Hemen Giriş seçilmeli; kalıcı çözüm olarak durum Otomatik yapılıp saat tablosu tanımlanmalı
  (00:00–12:00 Giriş, 12:00–23:59 Çıkış). Aynı ayar iki cihazda da olmalı.
- **Yayın:** Güncel sürüm (yön işaretine güvenmiyor, işaret yoksa ilk okutmayı giriş sayıyor) yayınlanmalı.
  Kullanıcı onayı bekleniyor; canlı servis yeniden başlar.

## Açık kalanlar
- sentezservis'in güncel sürümünün modfexsrv'ye yayını (onay bekliyor).

### Yayın paketi (kullanıcı: "paket cikartirmisin")
- `deploy/yayinla.ps1` çalıştırıldı: arayüz derlendi, `dotnet publish` yapıldı, kurulum betikleri kopyalandı, ayar dosyası temizlendi.
  Doğrulama `SentezServis.exe --paket-dogrula` ile yapıldı: arayuzVar true, etiketPdfBayt 27447.
- Pakette `appsettings.json` yok; sunucudaki ayar korunuyor.
- **Çıktı:** `yayin-pdks-2026-10-18.zip` (73,1 MB, gitignore'da). Kaynak commit `e363870`
  (PDKS düzeltmesi 5b0f6ef + iş emri no + Pkcs 10.0.13 dahil).
- Not: 13.10 paketi (`yayin-pdks-2026-10-13.zip`) düzeltmeden bir dakika sonra üretilmişti ama sunucuya kurulmamış görünüyor
  (sunucudaki özet metni eski biçimde).
- **Kurulum:** sunucuda `servis-kur.cmd` yönetici olarak çalıştırılır. Servis `SentezServis`, varsayılan hedef
  `C:\Program Files\SentezServis`, port 81. Betik servisi durdurup dosyaları kopyalıyor ve servisi yeniden başlatıyor.

### PDKS mail özeti satır satır, Türkçe karşılıklı (kullanıcı: "basliktaki bilgileri yan yana degil, satir satir yazdiralim, yanlarina parantez icinde turklerini yazalim")
- **Neden:** Mailin üstündeki özet tek satırda, "·" ile ayrılmış ve yalnız İngilizceydi; okunması zordu.
- **Ne yapıldı:** `BildirimServisi.PdksOzetHtml` artık her bilgiyi ayrı bir `<div>` satırına yazıyor ve yanına parantez içinde Türkçesini ekliyor:
  - `N total (toplam)`
  - `N checked in today (bugün gelenler)`
  - `N not checked in today (bugün gelmeyenler)` (kırmızı)
  - `N no check-out on DD.MM.YYYY (DD.MM.YYYY çıkış yapmayanlar)`
  - `N absent on DD.MM.YYYY (DD.MM.YYYY gelmeyenler)` (kırmızı)
- **Dokunulan dosyalar:** `src/SentezServis.Core/Bildirim/BildirimServisi.cs`, `tests/SentezServis.Core.Tests/PdksGunlukTestleri.cs`
- **Test (TDD):** `Ozet_toplam_giren_girmeyen_cikissiz_dun_gelmeyen` testine Türkçe etiketler, 5 ayrı `<div><b` satırı ve " ·" bulunmaması eklendi.
  Test önce kırmızıydı, kod değiştikten sonra yeşil. Tüm suite: 276 geçti, 11 atlandı, 0 hata.
- **Commit:** `c9b3e84`. Push edildi.
- **Paket yeniden üretildi:**
  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File deploy\yayinla.ps1
  Compress-Archive -Path yayin\* -DestinationPath yayin-pdks-2026-10-18.zip
  ```
  Aynı adla (73,1 MB) üretildi, eski 18.10 zip'inin yerini aldı. Kaynak `c9b3e84`, arayuzTarihi 2026-10-18 09:11. Pakette appsettings.json yok.

---

## Modasima sentezservis (`X:\Gitlab\Modasima\sentezservis`, gitlab.com/modasima/sentezservis)

> Not: Yukarıdaki bölümler modfex-apparel deposundaki sentezservis içindi. Bu bölüm Modasima deposudur.

### 1. PDKS filtresi: emp_code 24 yerine "aktif ve iş tipi Geçici olmayan"
- **Kullanıcı:** "Serviste pdks cekerken filtreyi es gec sadece aktifleri ve is tipi Geçici olmayanlari (ornek 24 abdusselam kosecik) getirir misin"
- **İnceleme (salt okuma, 192.168.1.4/zkbiotime):**
  - `personnel_employee` kolonları: `status`, `emp_type`. `personnel_employment.employment_type = 2` → 24 numaralı kayıt.
  - 24 Abdusselam Kosecik: `status 0`, `emp_type 2` → Geçici = 2.
  - Dağılım: aktif (status 0) 11 kişi; 10'unda `emp_type` NULL, 1'inde 2.
- **Ne yapıldı:** `PdksDeposu` üç sorgu bacağında `p.emp_code <> @haricEmpCode` → `ISNULL(p.emp_type, 0) <> @geciciEmpType`;
  `HaricEmpCode = "24"` sabiti kaldırıldı, yerine `GeciciEmpType = 2`.
  **ISNULL şart:** düz `emp_type <> 2` NULL'ları da düşürür, rapor neredeyse boşalırdı.
- **Dokunulan dosyalar:** `src/SentezServis.Core/Pdks/PdksDeposu.cs`, `tests/SentezServis.Core.Tests/PdksSinirTestleri.cs`, `docs/pdks-raporu.md`
- **Test (TDD):** `Kullanicinin_filtreleri_korunur`, `Personel_filtreleri_UNIONun_IKI_bacaginda_da_vardir` güncellendi; yeni
  `Gecici_personel_is_tipinden_dislanir_sabit_kod_filtresi_yoktur` (emp_code geçmez, düz `p.emp_type <> ` geçmez). Önce 3 kırmızı, sonra
  tüm suite 683/683 yeşil.
- **Canlı doğrulama:** yeni filtre ile 10 kişi raporda, yalnız 24 dışarıda.
- **Commit:** `ad28b42` — PDKS: emp_code 24 filtresi kalkti; aktif ve is tipi Gecici (emp_type=2) olmayanlar raporlanir. Push edildi.
- **Yayın:** henüz paket çıkarılmadı / sunucuya (192.168.1.5 MDSMHYPERV, port 81) kurulmadı.

### 2. İkinci PDKS kaynağı: http://192.168.1.3:8095 (açık)
- **Kullanıcı:** aynı raporu bu ikinci BioTime'dan da, aynı saatlerde, ayrı alıcılara göndermek istiyor (alıcıları kendisi girecek).
- **Bulgular:**
  - 8095 bir ZKBioTime web arayüzü (Apache + Django, `/login/`).
  - 192.168.1.3'ün SQL Server'ında (ADAOSRV, tek instance MSSQLSERVER:1433) **zkbiotime veritabanı yok**; o BioTime'dan
    gelen oturum da yok. 5432/7496 kapalı, `\192.168.1.3\c$` erişilemez.
  - Muhtemelen BioTime'ın kendi gömülü PostgreSQL'i, yalnız localhost'ta dinliyor.
- **Sonraki adım:** veritabanı erişimi (PostgreSQL'i ağa açmak + kimlik) ya da BioTime REST API kullanıcısı gerekiyor; kullanıcıya soruldu.

#### 2a. İkinci BioTime'ın veritabanı bulundu (kullanıcı: "192.168.1.3 sql var")
- 1.3 SQL Server (ADAMOSRV, MSSQLSERVER) sa ile sysadmin; 11 veritabanının hiçbirinde `iclock_transaction` yok
  (`sp_MSforeachdb` + `OBJECT_ID` taraması).
- Kayıt defteri (`xp_regenumkeys ...\Services`, salt okuma): `bio-apache0`, `bio-pgsql`, `bio-redis`, `bio-server` servisleri var.
  `bio-pgsql` ImagePath: `C:\ZKBioTime\pgsql\bin\pg_ctl.exe ... -D C:\ZKBioTime\pgsql\data`.
- `C:\ZKBioTime\attsite.ini` (`OPENROWSET(BULK ..., SINGLE_BLOB)` ile okundu): `ENGINE=postgresql`, `NAME=biotime`,
  `USER=postgres`, `PORT=7496`, `HOST=127.0.0.1`, parola BioTime tarafından şifreli (`DB_PWD=1`). Web portu 8095.
- Sonuç: veri BioTime'ın gömülü PostgreSQL'inde, yalnız localhost'ta; ağdan 7496 kapalı. Sunucuda değişiklik yapılmadı.
- Karar bekleniyor: (1) PostgreSQL'i yalnız 192.168.1.5'e açmak + salt okunur rol (önerilen; tablolar 1.4 ile aynı, sorgu Postgres
  diyalektine çevrilir, Npgsql eklenir) veya (2) BioTime REST API kullanıcısı (emp_type / puantaj çıkışı API'de olmayabilir).

#### 2b. İkinci PDKS raporu BioTime API ile yazıldı (kullanıcı: "admin modasima1234 kullanici adi sifre")
- **Neden:** veritabanı localhost-only PostgreSQL; sunucuya dokunmadan tek yol BioTime REST API.
- **API ölçümü (canlı, salt okuma):**
  - `POST /api-token-auth/` → `{"token": ...}`, başlık `Authorization: Token <...>`. (`/jwt-api-token-auth/` de çalışıyor.)
  - `GET /personnel/api/employees/?page_size=N` → `{count,next,data}`; 11 aktif; işten ayrılanlar ayrı (`/personnel/api/resigns/`, 10 kayıt).
    Alanlar: `id`, `emp_code`, `first_name`, `last_name`, `department.dept_name`, `emp_type` (hepsi null).
  - `GET /iclock/api/transactions/?start_time=..&end_time=..` → `emp` (personel id), `punch_time` "yyyy-MM-dd HH:mm:ss", `punch_state` hep "0".
  - `/att/api/timeCardReport/`, `firstLastReport/` boş (puantaj hesaplanmıyor). Tek cihaz VGU6244600097 "Genel".
  - Aynı dakikada çift okutma var; cumartesi 13:05–13:12 çıkışlar var.
- **Ne yapıldı:**
  - `Pdks/BioTimeIstemcisi.cs`: token + sayfalı GET (`next` takip), `PersonelSayfasi`/`HareketSayfasi` JSON okuyucuları; `PdksApiAyarlari`
    (`Adres`, `KullaniciAdi`, `Parola`, `Ad`, `ZamanAsimi`). Token gövdesi `JsonObject` ile (anonim tip + JsonContent, yansıma kapalı
    derlemede patladı: "Reflection-based serialization has been disabled").
  - `Pdks/PdksApiHesabi.cs`: Geçici (emp_type 2) dışla; önceki tarih = son 31 günde bugünden önceki son okutma günü; Çıkış = o günün
    12:00 sonrası son okutması; Giriş = bugünün MAX okutması; ada göre grup, tr-TR sıralama.
  - `Pdks/PdksApiRaporuJob.cs`: anahtar `pdks-raporu-2`, cron `30 8 * * 1-5`, `JobParameter.Alicilar()`.
  - `PdksRaporuJob.RaporlaAsync` ortak akış (oku → mail → özet); iki iş de kullanıyor.
  - `PdksRaporu.Kaynak` → konu/başlık "Personel giriş/çıkış (192.168.1.3)".
  - `Ayarlar.PdksApi`, `Program.cs` kaydı; yerel (gitignore'daki) `appsettings.json`'a `PdksApi` bölümü eklendi.
    `yayinla.ps1` `"Parola"` değerini örnek dosyada boşaltıyor.
- **Dokunulan dosyalar:** yukarıdakiler + `Bildirim/BildirimServisi.cs`, `Bildirim/MahsupRaporu.cs`, `docs/pdks-raporu.md`,
  `tests/SentezServis.Core.Tests/PdksApiTestleri.cs` (12 test).
- **Test:** önce derleme kırmızı, sonra 695/695 yeşil.
- **Canlı deneme:** scratchpad `canli/canli.cs` (`dotnet run`, `#:project` Core) → 16.10 08:30: önceki 15.10, 11 satır, doğru;
  19.10 08:30: önceki 17.10 (cumartesi), çıkışlar 13:05–16:15.
- **Commit:** `26767e6` — PDKS: ikinci kaynak 192.168.1.3:8095 BioTime API raporu (pdks-raporu-2). Push edildi.

## Açık kalanlar (Modasima)
- Yayın paketi çıkarılıp 192.168.1.5'e kurulmalı.
- **Sunucudaki `appsettings.json`'a `SentezServis:PdksApi` bölümü elle eklenmeli** (paket taşımıyor); yoksa iş açık hatayla durur.
- Arayüzde `pdks-raporu-2` zamanlamasına alıcılar girilecek (kullanıcı). Boşsa genel `Eposta:Alicilar`'a gider.
