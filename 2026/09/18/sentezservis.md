# sentezservis — 2026-09-18

## Bağlam

Bildirim altyapısı (kuyruk, dağıtıcı, gönderici, ayarlar) Ağustos'ta yazılmıştı ama
e-posta hiç canlıya alınmamıştı: `Eposta:Etkin=false`, sunucu `smtp.modasima.local`
gibi hayali bir değerdi. Hedef: `noreply@modasima.com.tr` hesabıyla gerçek gönderimi
çalıştırmak. Mail şablonları (TR/EN/AR) kullanıcı tarafından hazırlanıyor; bu turda
yalnızca gönderim ayarlandı.

Ayrıca projeyi TR/EN/AR çoklu dile çevirme işi konuşuldu ama **başlanmadı** (bkz.
"Açık kalanlar").

## Yapılanlar

### 1. SMTP sunucusunun teşhisi — iki tuzak vardı

- **Neden:** Verilen bilgi yalnızca kullanıcı adı + şifreydi; sunucu adı/portu yoktu.
- **Ne yapıldı:**
  - MX kaydı Natro'yu gösterdi (`mx-in01.natrohost.com`), `mail.modasima.com.tr` buna
    CNAME. 587 ve 465 açık, 25 ve 2525 kapalı.
  - **Tuzak 1 — sertifika.** `mail.modasima.com.tr:587` sertifikası `*.natrohost.com`
    ve **12.07.2026'da dolmuş** (o gün 17-18.09.2026). .NET `RemoteCertificateNameMismatch`
    + `RemoteCertificateChainErrors` ile reddetti. Kullanıcının önerdiği
    `mail.kurumsaleposta.com` de aynı altyapı, aynı süresi geçmiş sertifika.
    **Ama 465 portu farklı bir sertifika sunuyor:** `*.kurumsaleposta.com`,
    28.04.2026 – 12.11.2026 geçerli. `openssl -verify_return_error` ile tam
    doğrulamayla bağlandı.
  - **Tuzak 2 — şifre.** `AUTH LOGIN/PLAIN` ısrarla `454 4.7.0 Authentication rejected:
    Try later` döndü (535 değil, yani "yanlış şifre" demiyordu; yanıltıcı). Şifre
    sohbette `...=R8:` diye yazılmıştı ve **sondaki iki nokta şifrenin parçasıymış**.
    Onunla `235 2.7.0 Ok`. Şifre 15 değil 16 karakter.
- **Komutlar:**
  ```bash
  nslookup -type=MX modasima.com.tr 8.8.8.8
  openssl s_client -starttls smtp -connect mail.kurumsaleposta.com:587 \
      -servername mail.kurumsaleposta.com | openssl x509 -noout -subject -dates
  openssl s_client -connect mail.kurumsaleposta.com:465 \
      -servername mail.kurumsaleposta.com | openssl x509 -noout -subject -dates
  # kimlik dogrulama sinavi (sifre ortam degiskeninden verilmeli)
  AUTH=$(printf '\0KULLANICI\0SIFRE' | base64 -w0)
  printf 'EHLO modasima.com.tr\r\nAUTH PLAIN %s\r\nQUIT\r\n' "$AUTH" \
    | openssl s_client -quiet -connect mail.kurumsaleposta.com:465 -verify_return_error
  ```
- **Sonuç / doğrulama:** Çalışan yol: **`mail.kurumsaleposta.com:465`, implicit SSL,
  tam sertifika doğrulaması, 16 karakterlik şifre.**

### 2. EpostaGonderici BCL'den MailKit'e geçirildi

- **Neden:** `System.Net.Mail.SmtpClient`'ın `EnableSsl`'i **yalnızca STARTTLS**
  demektir; implicit SSL (465) desteği yok. Geçerli sertifika ise sadece 465'te.
  "Sertifika doğrulamasını atla + 587 kullan" seçeneği **reddedildi**: BCL'de örnek
  bazlı sertifika geri çağrısı yok, tek yol süreç genelinde statik olan
  `ServicePointManager.ServerCertificateValidationCallback` — bu, aynı süreçteki
  Trendyol/Hepsiburada/CRS/TCMB HTTPS çağrılarının TLS doğrulamasını da kapatırdı.
  Bir mail ayarı için tüm entegrasyonların güvenliğini feda etmek olmaz.
- **Ne yapıldı:** `MailKit` 4.18.0 eklendi, `EpostaGonderici` MailKit ile yeniden
  yazıldı. **Dış arayüz aynen korundu** (`GonderAsync(hedef, konu, govde, ct)`), bu
  yüzden çağıran `BildirimDagiticiServisi` hiç değişmedi. `Ssl=true` →
  `SecureSocketOptions.Auto`: 465'te implicit SSL, diğer portlarda STARTTLS seçilir,
  böylece **yeni bir ayar anahtarı gerekmedi**. Sertifika doğrulaması açık bırakıldı.
  Gerekçe hem csproj paket notuna hem sınıfın XML yorumuna yazıldı.
- **Dokunulan dosyalar:** `src/SentezServis.Core/Bildirim/EpostaGonderici.cs`,
  `src/SentezServis.Core/SentezServis.Core.csproj`,
  `src/SentezServis.Host/appsettings.json` (sürümlenmiyor).
- **Sonuç / doğrulama:** `dotnet build` → 0 uyarı 0 hata (Core'da
  `TreatWarningsAsErrors` açık; `Parola` nullable olduğu için CS8604 yakalandı,
  `?? ""` ile kapatıldı). `dotnet test` → **458/458 geçti.**
- **Commit:** `f7622b5` — Mail gonderimi: MailKit'e gecis, 465 implicit SSL

### 3. Canlı gönderim doğrulaması

- **Neden:** Yapılandırma yazmak "çalışıyor" demek değil.
- **Ne yapıldı:** Scratchpad'de tek kullanımlık konsol: **gerçek `appsettings.json` →
  `Ayarlar` bağlama → `EpostaGonderici`**, yani taklit değil uygulamanın kendi yolu.
  Gövde olarak `docs/simple/01-info.html` şablonunun TR bloğu kullanıldı.
- **Dikkat edilecek nokta:** Şablon dosyaları **üç tam HTML belgesi** taşıyor
  (`lang="tr"`, `lang="en"`, `lang="ar" dir="rtl"`). İlk denemede `<!DOCTYPE`'a göre
  bölmeye çalıştım — **yanlış**, çünkü dosyanın açıklama yorumları da "`<!DOCTYPE html>`"
  metnini içeriyor; 6 eşleşme çıktı ve bt@'ye 181 karakterlik anlamsız bir mail gitti.
  Doğru çapa: `<html lang="xx"> ... </html>` (regex, Singleline), başına DOCTYPE eklenir.
- **Sonuç / doğrulama:** İkinci gönderim doğru: TR bloğu, 10.896 karakter.
  **Kullanıcı mailin ulaştığını teyit etti** ("2. gönderdiğin tamam").
  `Alicilar=bt@modasima.com.tr`, `Etkin=true`.

### 4. Mail şablonları sürüme alındı

- **Neden:** `docs/simple/` altındaki 5 şablon takip dışıydı; HDD kuralı gereği
  diskte kalan iş kaybolmuş iştir.
- **Ne yapıldı:** 01-info, 02-warning, 03-danger, 04-critical, 05-report commit'lendi.
  Sır içermedikleri teyit edildi. Her biri TR/EN/AR üç dili birlikte taşıyor,
  firma rengi üst barda (`#17365D` ModaSima, `#2F4858` Modfex).

### 5. Çoklu dil (TR/EN/AR) tasarımı — spec yazıldı, uygulanmadı

- **Neden:** Talep dört alt sistemi kapsıyordu (arayüz, arka uç metinleri, mail,
  rapor/PDF); tek turda yapılacak iş değil, önce parçalanması gerekiyordu.
- **Ne yapıldı:** Ölçüm alındı ve kararlar konuşuldu. Ölçüm: `web/src` 95 dosya /
  ~23.000 satır, 86 dosyada ~1.150 Türkçe metin, i18n kütüphanesi yok,
  `index.html`'de `lang="en"` (yanlış). **Çoğullu/enterpolasyonlu Türkçe cümle: 0**
  (iki ayrı desenle arandı) — bu, kütüphane kararını belirledi.
- **Kararlar:** kütüphane yok, ~120 satırlık kendi `t()`'miz (TypeScript ile anahtarlar
  tip güvenli olur, i18next'te bu yok); anahtarlar Türkçe slug; dil seçimi
  `localStorage`'da; **mailler tek mesajda üç dili alt alta taşıyacak** (sunucu alıcının
  dilini bilemez, bu karar o boşluğu kapatıyor); arka uç hataları `ApiError.kod`
  üzerinden çevrilir — C# elden geçirilmesi gerekmiyor.
- **İyi haber:** yön bağımlı CSS yalnızca 9 yer (`theme.css` 1.582 satır içinde),
  inline'da 49 yer. RTL küçük ve mekanik iş. Gezinmenin 28 metni `Layout.tsx:23`
  `MENU` sabitinde tek yerde.
- **Dokunulan dosyalar:** `docs/superpowers/specs/2026-09-18-coklu-dil-design.md`
- **Commit:** `cef7f35` — Coklu dil (TR/EN/AR) tasarim belgesi

### 6. Karşıt kod eşleştirme (`UZM_ExternalXRef`) tasarımı

- **Neden:** Gelen e-fatura XML'indeki ürün kodu `Erp_Inventory`/`Erp_Service`
  kaydına bağlanmak zorunda. Sentez bunu `Meta_ExternalXRef`'ten çözüyor
  (`TypeCode` 100/101, `ExtKeyValue4`=XML kodu, `KeyValue3`=cari, yoksa
  `ExtKeyValue2` ile LIKE kalıbı). İstenen: **önce bizim tablomuza bakılsın**,
  bulunamazsa Sentez'in mevcut mantığı uygulansın.
- **Ne yapıldı:** Tasarım belgesi yazıldı. Şema `UZM_ExternalXRef`
  (CompanyId, TypeCode, AccountCode, ExternalCode, ExternalName, TargetCode, InUse,
  audit), iki indeks + kod tekilliği kısıtı. Örnek parametreli sorgular belgeye kondu.
- **Önemli tespitler:**
  - Bizim kod tabanında `Meta_ExternalXRef` **hiç geçmiyordu**; e-fatura aktarımını
    biz yapmıyoruz, `192.168.1.4:3132/EFautra` adresindeki dış uygulamayı sadece
    tetikliyoruz. Eklentiyi kullanıcı yazacak.
  - `MigrasyonCalistirici` yalnızca bizim veritabanımıza bağlanıyor → ERP'deki tablo
    göç sistemiyle kurulamaz; DDL elle uygulanacak bir betik olarak repoda duracak.
    Servise canlı ERP'de DDL yetkisi vermek bir tablo için alınacak risk değil.
  - **Şart B-10 çelişkisi:** ERP bağlantısı salt okunur, bugüne kadar iki yazma
    istisnası var (raf adresi, `Meta_ForexRate`). Bu üçüncüsü olur ve kurul kararı
    yazılmadan uygulanmayacak. Hafifletici: `UZM_ExternalXRef` ERP'de duran ama
    tamamen bize ait **yeni** bir tablo; yanlış yazmada bozulacak ERP verisi yok.
  - Muhafız testlerinin var olduğunu **kontrol ederek** doğruladım (önce yok sandım):
    `EksiStokTestleri.cs:24`, `TcmbKurTestleri.cs:105`, `CariYaziciSinirTestleri`,
    `SiparisDeposuSinirTestleri` — modül modül kaynak taraması. Yeni depo da
    kendi sınır testini getirecek.
  - Mevcut eklenti kodu SQL'i string birleştirmeyle kuruyor, tek koruması
    `Replace("'", "-")`. XML dış veridir; belgede parametreli sorgu şart koşuldu.
- **Dokunulan dosyalar:**
  `docs/superpowers/specs/2026-09-18-karsit-kod-eslestirme-design.md`
- **Commit:** `7687acb` — Karsit kod eslestirme (UZM_ExternalXRef) tasarim belgesi

### 7. CANLI ARIZA bulundu: mahsup 10 gündür çalışmıyormuş

- **Nasıl bulundu:** Kullanıcı "şu iki sorguyu her gece 23:30'da çalıştır" dedi. 1. sorgu
  projede zaten uygulanmıştı (`EksiStokMahsupJob`). Doğrulamak için kendi defterimize
  bakıldı: `mahsup_calistirmalari` tablosunda **sadece 2 tur** vardı, ikisi de 4 Eylül'de
  "probe". Sonra `calistirmalar` sorgulandı: 08–17 Eylül arası **her gece** `basarisiz`,
  mesaj hep aynı: `Mahsup veritabanı yapılandırılmamış (SentezServis:MahsupBaglantiCumlesi)`.
- **Sebep:** Canlı sunucudaki `appsettings.json`'da `MahsupBaglantiCumlesi` **yok**. Paket
  bu dosyayı taşımıyor, yükseltmede sunucudakine dokunmuyor → yeni ayar anahtarı
  kendiliğinden gelmiyor.
- **Neden 10 gün görünmedi:** İş başarısız olunca `BildirimServisi` mail atar; **e-posta
  bugüne kadar kapalıydı** (madde 2). İki arıza üst üste binmiş.
- **Kullanıcının yapması gereken (KOD ÇÖZEMEZ):** canlı `appsettings.json`'a
  `MahsupBaglantiCumlesi` eklenmeli. Aynı dosyaya bugünkü `Eposta` bloğu da yazılmalı.

### 8. İkinci, henüz patlamamış arıza: `@SpecialCodeStart`

- **Ne:** `UZM_MahsubBarcode` **15.09.2026'da değiştirilmiş** (`sys.objects.modify_date`) ve
  7. parametresi `@SpecialCodeStart nvarchar(max)` **varsayılansız**. Kod yalnızca 6
  parametre geçiyordu → SQL Server çağrıyı reddeder.
- **Niye fark edilmedi:** 4 Eylül'deki probe turu değişiklikten önceydi ve geçmişti. Yani
  sadece bağlantı cümlesi eklenseydi, bu sefer her satır parametre hatası verecekti.
  İkisi birlikte düzeltildi.
- **Not:** `sys.parameters.has_default_value` T-SQL yordamlarında **her zaman 0** döner
  (yalnızca CLR için anlamlı); varsayılan `OBJECT_DEFINITION` okunarak anlaşıldı.

### 9. Mahsup: HR turu, 23:30, gece raporu maili

- **Neden:** 2. sorgu HR stoklarını hedefliyordu (`LIKE 'HR%'`, `KonsinyeHR`); koddaki filtre
  `NOT LIKE 'HR%'` olarak **sabitti**, yani ikinci sorgu desteklenmiyordu.
- **Ne yapıldı:**
  - `MahsupKapsami` enum'u (Normal → `Konsinye`, Hr → `KonsinyeHR`). Filtre ve yordam
    parametresi buradan gelir. Filtre SQL'e gömülür ama **enum'dan türediği için** dışarıdan
    veri içeremez; `LIKE` kalıbını parametreleştirmek sorgu planını bozardı.
  - İş aynı gece iki kapsamı peş peşe koşar. **Tavan paylaşılır** — kapsam başına ayrı tavan,
    "en fazla 1000" diyen yöneticiye sessizce 2000 fiş yazardı.
  - Yeniden tarama **turun kendi kapsamıyla** yapılır; HR turundan sonra normal stokları
    taramak düzelmemiş satırları düzelmiş gösterirdi.
  - `mahsup_satirlari`'na `kapsam` kolonu (göç 016).
  - Cron 00:00 → 23:30. **`IsKayitDefteri` mevcut zamanlama satırına dokunmuyor**, o yüzden
    koddaki `DefaultCron` canlıyı değiştirmez; göç 016 satırı günceller ve **yalnızca eski
    varsayılanı** (`0 0 * * *`) hedefler, yöneticinin seçtiğini ezmez.
  - Gece raporu maili: kapsam kırılımı + **barkodsuz satırların tam listesi**. Boş gece de
    gider — mailin gelmemesi "sorun yok" değil "iş hiç çalışmadı" demektir.
- **Kullanıcının betiğine karşı korunan davranışlar** (betiği aynen koşmak önerildi, itiraz
  edildi, kullanıcı vazgeçti): satır bazı transaction (yordam iki fiş üretiyor, içinde işlem
  yönetimi yok → ikincisi patlarsa eksi bakiye **başka şirkette açılır**), yeniden tarama
  (`@RC` daima 0 çünkü yordam hiç `RETURN` kullanmıyor → betiğin "Basarili: 312" çıktısı
  stok hâlâ eksiyken de 312 yazar), barkodsuzların silinmemesi, barkodun `MIN + COUNT` ile
  alınması.
- **Sonuç / doğrulama:** 468/468 test; örnek rapor maili gerçek şablonla bt@'ye gönderildi
  (42 KB, üç dil, yer tutucu kalmadı).
- **Commit:** `1998cb0`

### 10. Mail şablonu motoru

- **Neden:** Rapor maili `docs/simple/05-report.html` şablonuyla istendi, ama şablonun tablosu
  **sabit örnek satırlardı**; değişken uzunlukta liste basılamıyordu.
- **Ne yapıldı:** Şablon `src/SentezServis.Core/Bildirim/Sablonlar/mahsup-raporu.html` olarak
  servise taşındı (**gömülü kaynak**, çünkü paket `docs/`'u taşımaz; EXE yanındaki
  `sablonlar/` klasörü öncelikli — `.frx` düzeninin aynısı). Tablo üç dilde de
  `{{#satirlar}}…{{/satirlar}}` tekrar bloğuna çevrildi; kolonlar Şirket / Stok Kodu /
  Varyant / Miktar.
- **`MailSablonu`:** `{{alan}}` + tekrar bloğu; **üç dil tek HTML gövdesinde** birleşir —
  üç `<!DOCTYPE>` uç uca eklemek geçersiz HTML olurdu, bunun yerine ilk belge kabuk alınır,
  diğerlerinin `<body>` içerikleri `dir` taşıyan `<div>`'lere sarılarak eklenir (yoksa Arapça
  RTL kaybolurdu), `<style>`'lar başlığa taşınır. Tanımsız yer tutucular boşaltılır, değerler
  HTML'e kaçırılır.
- **Commit:** `1998cb0`

### 11. Bağlantı cümleleri rol bazlı + açılışta doğrulama

- **Neden:** Kullanıcı "bağlantı cümlesini servis bazlı parametrik yap, boşsa app'den alsın"
  dedi. İlk yarısı yapıldı, **ikinci yarısına itiraz edildi ve kullanıcı vazgeçti.**
- **İtirazın özü:** Boş bir rolün ana bağlantıya düşmesi arızayı çözmüyor, **görünür arızayı
  görünmez arızaya çeviriyordu**: mahsup ERP tablolarını kendi servis veritabanımızda arardı,
  entegrasyon yanlış veritabanına yazardı, ERP okumaları **sessizce boş** dönerdi. Ayrım
  ayrıca Şart B-10'un kanıtlanabilirliğini taşıyor.
- **Ne yapıldı:** `SentezServis:Baglantilar` bölümü (Servis/Erp/Entegrasyon/Mahsup). Eski düz
  anahtarlar **kaldırılmadı** — canlıdaki dosya onları kullanıyor; çözüm sırası önce yeni
  bölüm, yoksa aynı rolün eski alanı. Roller birbirine düşmez.
  `BaglantiFabrikasi.DogrulaAsync` açılışta **şemadan önce** her rolü dener (tanımlı mı +
  gerçekten açılıyor mu), Event Log'a yazar ve maille bildirir (aynı sorun için 6 saatte bir).
  Servisi durdurmaz.
- **Dokunulan dosyalar:** `Ayarlar.cs`, `Data/BaglantiFabrikasi.cs`,
  `Bildirim/BildirimServisi.cs`, `Host/Program.cs`, `docs/baglanti-cumleleri.md`, testler
- **Sonuç / doğrulama:** 476/476 test geçti.
- **Commit:** `80149a7`

### 12. Rapor mailinden satış rakamları çıkarıldı

- **Neden:** Kullanıcı örnek maili görünce "satış tutarlarını eklemene gerek yok, sadece
  bulunmayan barkodları eklesen yeterli" dedi. Şablon `05-report.html`'den türetildiği için
  **üç dilde de** sabit örnek satış KPI'ları duruyordu: "Toplam Sipariş 1.248",
  "Toplam Tutar 4.860.300 ₺", "İade Oranı %2,1". Tabloyu değiştirmiştim ama KPI kutularını
  görmemiştim.
- **Ne yapıldı:** Üç kutu mahsup sayaçlarına çevrildi: **bulunan / düzelen / barkodsuz**.
  (`{{duzelen}}`, çağrının hata vermediği sayı değil, yeniden taramada eksi bakiyesi
  gerçekten kalmayan satır sayısıdır.) Ayrıca `{{ad_soyad}}` boş kalınca "Sayın ," gibi
  kırık bir satır bırakıyordu; hitap üç dilde de sistem raporuna uygun bir cümleyle
  değiştirildi. Dosya başındaki açıklama yorumu bu şablona uyarlandı.
- **Not:** KPI kutuları tek `<td>` içinde iki `<div>` (üstte etiket, altta değer); `<td>`
  aramak yetmiyor.
- **Sonuç / doğrulama:** 476/476 test; örnek mail bt@'ye tekrar gönderildi, üç dilde de
  tutar/para izi kalmadı.
- **Commit:** `e4bfae2`

## Kararlar

- **465 kullanılır, 587 kullanılmaz.** Gerekçe sertifika; 587'nin sertifikası
  yenilenirse bile geri dönmeye gerek yok.
- **MailKit bağımlılığı kabul edildi.** Eski kodun "ek NuGet bağımlılığı gerektirmez"
  notu bilinçliydi ve bozuldu; gerekçe yukarıda, kalıcı olarak csproj'a yazıldı.
  Kurul kararlarında bunu yasaklayan madde yok (E-2'deki "dış bağımlılık kurul
  kararıdır" ifadesi izleme ajanları bağlamında).
- **TLS doğrulaması hiçbir koşulda kapatılmayacak.** Süreç genelinde statik olduğu
  için maliyeti mailin çok ötesinde.
- Şifre `appsettings.json` içinde durur; dosya `.gitignore`'da (satır 26) ve
  `deploy/yayinla.ps1:93` `"Parola"` alanını paketten temizleyip kaçan sır kalırsa
  paketi üretmeyi reddediyor — SMTP şifresi bu korumanın içine kendiliğinden girdi.

## Açık kalanlar / sonraki adım

- **Çoklu dil — tasarım onaylandı, UYGULAMA PLANI YAZILMADI.** Ölçüm: `web/src` altında
  95 dosya / ~23.000 satır, **86 dosyada ~1.150 Türkçe metin**, i18n kütüphanesi yok,
  `index.html`'de `lang="en"` yazıyor (yanlış). Arapça için RTL gerekir. Ayrıca
  arka uçtan gelen metinler (iş adları, hata mesajları) ve mail şablonları da kapsam
  sorusu. Bu iş "architectural" sınıfında: soru–yaklaşım–tasarım–spec–plan akışı
  işletilmeli, tek turda yapılmamalı. Mail şablonlarının hâlihazırda TR/EN/AR
  taşıması iyi bir girdi.
- `Eposta:Alicilar` şimdilik yalnızca `bt@modasima.com.tr`. Operasyon adresleri
  eklenecek mi, karar verilmedi.
- Canlı sunucudaki `appsettings.json` **elle güncellenmeli**; paket bu dosyayı
  taşımıyor ve yükseltmede sunucudaki dosyaya dokunulmuyor. Yeni `Eposta` bloğu
  oraya da yazılmadan canlıda mail çalışmaz.
- 587'nin süresi geçmiş sertifikası Natro'ya bildirilebilir (bizim için acil değil,
  465 çalışıyor).
- **Karşıt kod işi:** belgedeki üç açık soru cevaplanmalı (ad kalıbı birden fazla
  satır tutarsa öncelik nasıl belirlenecek; `AccountCode` boş bırakılıp "cari fark
  etmez" denebilmeli mi; eşleşmeyen XML kodları için kayıt/uyarı üretilsin mi).
  Sonra Karar #07 yazılacak, sonra uygulama planı.

## 18 Eylül sonu — CANLIDA YAPILMASI GEREKENLER

Bunlar kodla çözülemez; sunucudaki `appsettings.json` elle düzenlenmelidir:

1. `SentezServis:Eposta` bloğu (bugün yapılandırıldı ve doğrulandı, canlıda yok).
2. `SentezServis:MahsupBaglantiCumlesi` (10 gündür eksik; mahsubun çalışmama sebebi).

İkisi yazılıp servis yeniden başlatıldığında, açılış doğrulaması kalan eksikleri kendisi
haber verecek.
