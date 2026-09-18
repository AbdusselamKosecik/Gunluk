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

### 13. Rapora barkodlu hata listesi — yanlış kümeyi hedeflemişim

- **Nasıl anlaşıldı:** Kullanıcı "barkod numaralarını da eklersen güzel olur" dedi. Ama
  barkodsuz satırların tanım gereği barkodu yok. Canlıya bakıldı:

  | Şirket | Kapsam | Eksi satır | Barkodlu | Barkodsuz |
  |---|---|---|---|---|
  | 5 (03) | normal | 392 | 392 | **0** |
  | 5 (03) | hr | 9 | 9 | **0** |
  | 7 (04) | normal | 776 | 776 | **0** |
  | 7 (04) | hr | 13 | 13 | **0** |

  **Barkodsuz satır sıfır.** Yani hazırladığım liste her gece boş gidecekti.
- **Doğru yorum:** Kullanıcının ilk cümlesi ("bulunmayan inventoryler … bunları bulamadım
  bu şirkette diye") barkodu NULL olanları değil, **yordamın hedef şirkette bulamadığı**
  ürünleri kastediyordu. Onların barkodu bilinir (yordama biz veriyoruz).
- **Ne yapıldı:** Rapor iki tablo taşıyor:
  - *Hatalılar*: Barkod | Stok Kodu | Şirket | Miktar | Hata — yordamın hata verdikleri
    **ve** çağrı patlamadığı hâlde eksi bakiyesi devam edenler (sayaçta "başarılı" görünen
    en sinsi durum).
  - *Barkodsuzlar*: Stok Kodu | Varyant | Şirket | Miktar — barkod kolonu yok.
  - Şablonda kolon 1 `class="hide-sm"` taşıyor (telefonda gizlenir); barkod ve hata sebebi
    bilerek oraya konmadı.
  - `MailSablonu` artık birden fazla adlandırılmış liste destekliyor.
- **Ayrıca:** birikmiş 1.190 satır, `azami` varsayılanı 1.000'e takılacaktı → 5.000 yapıldı.
- **Commit:** `b760b48` (öncesinde `e4bfae2`: şablondan satış KPI'ları çıkarıldı)

### 14. Zamanlanmış turlar parametre taşımıyordu — genel boşluk kapatıldı

- **Nasıl çıktı:** Kullanıcı "servislere alıcı parametresi ekleyelim" dedi. `zamanlamalar`
  tablosunda **parametre kolonu yok** ve `ZamanlayiciServisi.TetikleAsync` turu
  `new Dictionary<string, string?>()` ile başlatıyordu. Yani bir işe parametre eklemek
  yalnızca **elle tetiklemede** işe yarıyordu; gece turu onu hiç görmüyordu.
- **Ne yapıldı (göç 017):** `zamanlamalar.parametreler` (JSON, `ISJSON` kısıtlı). Zamanlayıcı
  okuyup geçiriyor. Bozuk JSON'da varsayılanlara düşülür — bozuk bir alan yüzünden turu hiç
  çalıştırmamak daha kötüdür. **Parametreler kayıt anında** `ParametreDogrulayici` ile
  sınanır; aksi hâlde geçersiz bir değer her gece sessizce turu düşürür ve ancak ertesi
  sabah görünürdü.
- **Kazanım alıcılarla sınırlı değil:** artık her işin gece turu yöneticinin seçtiği
  değerlerle koşabilir.

### 15. İş bazlı mail alıcıları

- **Ne yapıldı:** `JobParameter.Alicilar()` tek yerde tanımlandı — `Multiline` tipi zaten
  *"noktalı virgülle ayrılmış alıcı listesi"* diye belgelenmişti. Boş bırakılması geçerlidir
  ve `Eposta:Alicilar` anlamına gelir. Desen, yanlış yazılmış adresi **kaydetme anında**
  yakalar.
- **Neden ayar dosyası değil:** parametre bizim veritabanımızda durur. `appsettings.json`'a
  yazılması gereken bir alan unutulduğunda modül sessizce ölü kalır — mahsup 10 gün böyle
  kaldı (madde 7).
- **Arayüz:** Zamanlama sayfasına "Parametreler" düğmesi + `ZamanlamaParametreModal`.
  Manuel çalıştırma modalıyla aynı formu kullanır ama **"buradaki değerler her gece
  kullanılır"** diye açıkça uyarır; ikisi karıştırılırsa yönetici tek seferlik sandığı bir
  değeri kalıcı yapardı. "Varsayılanlara dön" düğmesi parametreleri temizler.
- **Commit:** `60de775`, `c66da4a`

### 16. PDKS (personel giriş/çıkış) raporu — KOD HAZIR, DOĞRULANMADI

- **Ne yapıldı:** Yeni iş `pdks-raporu`, her sabah **10:00** (cron Europe/Istanbul'a göre
  yorumlanıyor, `CronHesaplayici`). ZKBioTime veritabanından dünkü çıkış + bugünkü girişi
  okuyup TR/EN/AR tek mailde raporluyor. Kullanıcının sorgusu birebir korundu; tek ekleme
  `ORDER BY dept_name, first_name` (rapor okunacak şey).
- **Yeni bağlantı rolü:** `Baglantilar:Pdks`. **Salt okunur** ve sınır testiyle korunuyor:
  PDKS bizim sistemimiz değil, bir kayıt cihazının veritabanı; oraya yazmak cihazın verisini
  bozar.
- **Şema görülemediği için alınan karar:** saatler SQL tarafında
  `CONVERT(varchar(5), …, 108)` ile metne çevriliyor. `clock_in`/`clock_out` kurulum başına
  `time` veya `datetime` olabiliyor ve ikisi .NET'te farklı tiplere eşleniyor; bu çeviri
  ikisinde de `HH:mm` veriyor.
- **BLOKE:** `192.168.1.4`'e bağlanılamadı — `Login failed for user 'sa'`. O sunucu ayrı bir
  kimlik istiyor. **Sorgu canlıda hiç koşturulmadı**; kullanıcı bağlantı bilgisini verince
  doğrulanacak.
- **Commit:** `60de775`

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
3. `SentezServis:Baglantilar:Pdks` — ZKBioTime (192.168.1.4/zkbiotime) için **ayrı kimlik**.
   Bu olmadan PDKS raporu hiç çalışmaz. (Bağlantı ve sorgu gün içinde canlıda
   doğrulandı; eksik olan yalnızca sunucudaki ayar satırı.)

---

## Ek tur — PDKS raporu: hafta içi kararı, yeni sorgu, 08:30

### 6. PDKS bağlantısı ve sorgu canlıda doğrulandı

- **Neden:** Sorgu şemayı görmeden yazılmıştı; `clock_in`/`clock_out` kolon tipi bile
  varsayımdı. Doğrulanmadan "bitti" demek, mahsupta 10 gün sessiz kalan hatanın aynısını
  üretmek olurdu.
- **Ne yapıldı:** Geçici bir konsol projesi (`scratchpad/spimza`) `SentezServis.Core`'a
  referans verilerek gerçek kod yolundan koşturuldu: `appsettings.json` → `Ayarlar` →
  `BaglantiFabrikasi` → `PdksDeposu` → `MailSablonu` → `EpostaGonderici`. Kuyruk atlandı.
- **Ölçüm sonuçları:**
  - `clock_in`/`clock_out` = `datetime2`, `att_date` = `date`. `CONVERT(..., 108)` tercihi
    doğru çıktı.
  - **Personelin çoğu cihazı kullanmıyor:** `att_payloadtimecard` her personel için her gün
    satır açıyor, ama yalnızca ~5'i kayıt üretiyor (17.09: 12 satır / 5 giriş; 15.09: 17/5;
    14.09: 15/1).
  - **Hafta sonu hiç kayıt yok** (12–13.09: 15 satır, 0 giriş).
- **Sonuç:** Kullanıcı "herkesi listele" dedi — rapor sayıyı sinyal değil envanter olarak
  sunuyor. Hafta sonu için cron `1-5` yapıldı; bedeli kayda geçirildi: hafta sonu için
  "mail gelmedi = iş çalışmadı" sinyali kaybediliyor, bilerek kabul edildi.

### 7. `att_payloadtimecard.clock_in` gün içinde BOŞ — sorgu iki kaynaklı oldu

- **Neden:** Doğrulama sırasında sunucu saati 08:31'di ve **bugünün 12 satırının 12'sinde de
  `clock_in` boştu**; dünkü `clock_out` değerleri ise doluydu. Kullanıcı aynı anda yeni bir
  sorgu gönderdi ve sebebi açıkladı: puantaj toplaması gün içinde koşmuyor, günün girişi ham
  cihaz hareketlerinde (`iclock_transaction.punch_time`) duruyor.
- **Bunun önemi:** Tek kaynaklı sorgu **her sabah "kimse gelmemiş" derdi** ve mail düzgün
  göründüğü için bu fark edilmezdi. Sessiz yanlış rapor, hiç rapor gelmemesinden kötüdür.
- **Ne yapıldı:** `PdksDeposu.GunlukAsync` bir CTE + `UNION ALL` ile yazıldı:
  - 1. bacak — çıkış: `att_payloadtimecard.clock_out`, `att_date` bugün veya dün.
  - 2. bacak — giriş: `iclock_transaction.punch_time > CONVERT(date, GETDATE())`.
  - Dışta `MAX(Cikis)` / `MAX(Giris)` + `CONVERT(varchar(5), ..., 108)`.
- **Dokunulan dosyalar:** `src/SentezServis.Core/Pdks/PdksDeposu.cs`,
  `src/SentezServis.Core/Pdks/PdksRaporuJob.cs`,
  `tests/SentezServis.Core.Tests/PdksSinirTestleri.cs`, `docs/pdks-raporu.md`
- **Sonuç / doğrulama:** Canlıda **11 satır**; gerçek girişler geldi — HÜSEYİN YILMAZ 07:49,
  YAĞMUR DEMİR 07:54, naciye akkaya 07:54, AYTEN ÇAKMAK 07:55, BUŞRA KÖMÜRCÜGİL 07:59,
  HASAN EGE AYDIN 08:01, SİBEL TAŞDELEN 08:02. Örnek rapor bt@ adresine gönderildi
  (69.773 karakter, TR/EN/AR).
- **Commit:** `04e03fe` — PDKS raporu 08:30'da, gunun girisi ham hareketten

### 8. Kullanıcının sorgusundaki iki bulgu

Sorgu birebir uygulanmadan önce veriye bakıldı; iki şey çıktı:

- **Filtre asimetrisi (DÜZELTİLDİ).** `p.status = 0` ve `p.emp_code <> '24'` filtreleri
  kullanıcının sorgusunda **yalnızca puantaj bacağındaydı**; hareket bacağında yoktu.
  18.09'da sızan kimse yoktu — ama sebebi filtre değil, o kişilerin o gün kayıt
  üretmemesiydi. Yani hata **veri bağımlıydı**: rapor dışı tutulan personel bir gün
  turnikeyi kullansa rapora geri girerdi. Filtreler iki bacağa da kondu ve
  `Personel_filtreleri_UNIONun_IKI_bacaginda_da_vardir` testi her birinin **iki kez**
  geçtiğini doğruluyor.
- **`MAX` vs `MIN` (DEĞİŞTİRİLMEDİ).** Giriş kavramsal olarak **ilk** hareket (`MIN`);
  sorguda `MAX` var. 18.09'da fark yoktu: hareket üreten 7 kişinin her birinde **tam bir**
  hareket vardı (`MIN == MAX`). Fark ancak gün içinde ikinci kez geçen biri için doğar ve
  rapor 08:30'da koştuğu için pencere çok dar. Değiştirmek bir karardır, kod düzeltmesi
  değil — bu yüzden kullanıcının yazdığı gibi bırakıldı, gerekçesi belgeye yazıldı.
  Gerekirse `MAX(Giris)` → `MIN(Giris)`, tek satır.

### 9. Saat 10:00 → 08:30

- **Neden:** Kullanıcı kararı. Ölçüm de destekliyor: girişler 07:49–08:02 arasında düşüyor,
  yani 08:30'da günün girişleri tamamlanmış oluyor.
- **Ne yapıldı:** `DefaultCron = "30 8 * * 1-5"`. Sınır testi
  `Rapor_hafta_ici_her_sabah_8_30da_kosar` bunu kilitliyor.
- **Dikkat:** Saat daha erkene çekilirse **işe geç kalmamış personel "girişi yok" görünür.**
  Bu, cron'u değiştirecek kişinin bilmesi gereken tek şey.
- **Canlı DB'ye etkisi yok:** `IsKayitDefteri` zamanlama satırı **varsa dokunmuyor**
  (`IF NOT EXISTS`), yani yöneticinin arayüzden verdiği cron korunuyor. `pdks-raporu` hiç
  yayına girmediği için canlıda satır yok; ilk açılışta 08:30 olarak açılacak.

### 10. Gruplama ada göre — bilinçli, bedeli var

Kullanıcının `GROUP BY dept_name, first_name, last_name` tercihi korundu. **Faydası:**
canlıda aynı kişinin iki personel kaydı var (`emp_code` farklı) ve satırlar birleştiği için
çıkışı ile girişi yan yana gelebiliyor. **Bedeli:** adı soyadı birebir aynı iki ayrı çalışan
da birleşir ve satır sayısı sessizce eksilir. Bugünkü kadroda çakışma yok; kadro büyürse
gruplamanın `emp_code`'a taşınması gerekir.

## Kararlar (ek tur)

- PDKS raporu **hafta içi 08:30**. Hafta sonu yok, bedeli kabul edildi.
- Giriş **ham hareket tablosundan**, çıkış **puantaj tablosundan** okunur. Bu bir optimizasyon
  değil zorunluluk; sebebi ölçülmüştür.
- Kullanıcının sorgusunun filtre **değerleri** değiştirilmez; ama bir filtrenin eksik bacağa
  taşınması düzeltmedir, karar değildir.
- `MAX(Giris)` kullanıcının yazdığı gibi kaldı; `MIN` bir karar olarak açık bırakıldı.

## Açık kalanlar (ek tur)

- Canlı `appsettings.json`'a `SentezServis:Baglantilar:Pdks` yazılmadan PDKS raporu hiç
  çalışmaz. Bağlantı ve sorgu doğrulandı; eksik olan yalnızca sunucudaki ayar satırı.
- PDKS raporunun `alicilar` parametresi boş; boş kalırsa `Eposta:Alicilar` (şu an sadece
  bt@) kullanılır. Kime gideceği karara bağlı.
- `MIN(Giris)` sorusu açık.

---

## Ek tur — paket ve canlı ayar dosyasının birleştirilmesi

### 11. Yayım paketi üretildi

- **Komut:** `deploy\yayinla.ps1`
- **Çıktı:** `SentezServis-2026-09-18-0923.zip` (73,7 MB, depo kökü, `.gitignore` kapsamında).
  18 dosya: tek dosya `SentezServis.exe` (201 MB, self-contained), `wwwroot\app.js` +
  `app.css` (09:23), kurulum `.cmd`'leri, `kur.ps1`, `web.config`, `.pdb`'ler.
- **Sonuç / doğrulama:** Betik `appsettings.json`'ı pakete almadı, **29 sır değerini**
  boşaltıp `appsettings.ornek.json` bıraktı ve kaçan sır kalmadığını doğruladı. Zip ayrıca
  elle de kontrol edildi: gerçek parola yok.
- **Not:** Paket `.pdb` taşıyor (~450 KB). Hata ayıklamada satır numarası verdiği için
  zararsız; bilinçli olup olmadığı kullanıcıya sorulacak.

### 12. Canlı `appsettings.json` birleştirildi

- **Neden:** Kullanıcı canlı sunucudaki dosyayı (pazaryeri sırları paketten dolayı boş) ve
  ayrı bir listede gerçek anahtarları verdi; ikisinin birleştirilmesi istendi.
- **Ne yapıldı:**
  1. Her pazaryerinin **hangi alanı okuduğu koddan doğrulandı**
     (`PazaryeriAyarlari.cs:255-390`), çünkü yanlış alana yazılan anahtar sessizce 401
     üretir: Trendyol `ApiAnahtari`/`ApiGizli` = API Key/Secret; Hepsiburada
     `SaticiKimligi` = Merchant ID + `Parola` (`Kullanici` **boş kalır**, Basic auth
     kullanıcı adı olarak Merchant ID gider); Pazarama `ApiAnahtari`/`ApiGizli` = Client
     ID/Secret; Boyner `ApiAnahtari` = kullanıcı adı, `ApiGizli` = parola; Shopify
     `SaticiKimligi` = mağaza adı, `Jeton` = `shpat_` token.
  2. Canlı dosya ile yereldeki doğrulanmış dosya **anahtar ve değer düzeyinde
     karşılaştırıldı** (yorumlar ayıklanıp JSON olarak düzleştirilerek).
  3. Son dosya yerel dosyadan üretildi (yorumlar ve Türkçe metinler bozulmasın diye),
     üzerine sunucuya özel üç değer yazıldı.
- **Karşılaştırmanın sonucu — boş sırların dışında SADECE 3 fark, üçünde de canlı doğru:**

  | Alan | Yerel | Canlı (doğru) |
  | --- | --- | --- |
  | `Crs.Sirketler[04].KullaniciAdi` | `ViumaDigital` | `ViumaDigital_WebServis` |
  | `Crs.Sirketler[04].Parola` | `v1234567` (yer tutucu) | gerçek parola |
  | `Kasa.ServisHesabiDosyasi` | `D:\UzmanAdres\...` | `C:\Program Files\SentezServis\...` |
  | `Toplayici.Spool.Klasor` | `D:\UzmanAdres\...\spool` | `C:\Program Files\...\spool` |

  **Yereli temel alıp körlemesine üretmek CRS 04 kimliğini bozacaktı.** Bu yüzden
  karşılaştırma yapılmadan dosya üretilmedi.
- **Anahtarların kendisi:** kullanıcının verdiği 18 değer, yerelde **canlı doğrulanmış**
  (03.09'da 10/10 hesapta `BaglantiDeneAsync` başarılı) değerlerle **birebir aynı** çıktı.
  Yani listede sürpriz yok.
- **Doğrulama:** Son dosya canlı dosyaya göre yalnızca **18 boş sır dolduruldu**; anahtar
  farkı sıfır, başka hiçbir değer değişmedi. JSON geçerli, 14.681 bayt, UTF-8.
- **Dosya deponun DIŞINDA** (`scratchpad\ayar\appsettings.json`) tutuldu; sırlar repoya
  girmez.

### 13. Üç bulgu

- **04/Pazarama çift kayıt riski — CİDDİ.** `Etkin: true` ve anahtarları 03'ünkiyle
  **birebir aynı** (aynı satıcı kimliği, aynı Client ID/Secret). 18.09 listesinde 04 için
  Pazarama **hiç yok**. Bu hâliyle gece sipariş çekme işi aynı siparişleri iki kez çeker ve
  aynı ticari belge iki firmaya düşer — geri alması zor bir muhasebe hatası. Dosyaya
  uyarı notu kondu, `"Etkin": false` önerildi; **karar kullanıcıda.**
  (02.09 tarihli hafıza notu "04/Pazarama bilerek kapalı" diyordu; ölçüm bunun artık
  doğru olmadığını gösterdi, not düzeltildi.)
- **Yerelde CRS 04 kimliği bayat** (`ViumaDigital` / `v1234567`). Canlıdaki doğru değerle
  güncellenmesi öneriliyor; aksi hâlde geliştirme makinesinde 04'ün CRS çağrıları başarısız.
- **Kullanıcının yapıştırdığı dosyada Türkçe karakterler bozuk** (`ModaÅŸima`, `â€”`):
  UTF-8 metnin CP1252 olarak okunmuş hâli. Üretilen dosya temiz UTF-8; sunucuda düzenlenirken
  **UTF-8 olarak kaydedilmesi** gerekiyor, yoksa arayüzde mağaza adları bozuk görünür.

### 14. Pakete alınmayanlar (kasıtlı)

- **N11:** entegrasyon iptal; 5 adet App Key/Secret çifti verildi ama sağlayıcı yazılmayacak.
- **PTT Kargo:** pazaryeri sözleşmesine (sipariş/fiyat/stok) uymuyor, kendi katmanını
  bekliyor. **Barkod aralığı TERS:** başlangıç `2791859800001` > bitiş `2791852299999`.
  Bu hâliyle aralık boş kümedir; PTT katmanı yazıldığında ilk düzeltilecek şey bu. Ayrıca
  üç şirket aynı PTT hesabını ve aynı aralığı paylaşıyor — çakışma riski.

## Kararlar (paket turu)

- Canlı ayar dosyası **karşılaştırma yapılmadan** üretilmez. Tek yönlü kopyalama, canlıda
  doğru olan bir değeri (CRS 04) sessizce bozabiliyor.
- Pazaryeri alan eşlemesi **koddan** doğrulanır, listedeki etiketten değil.

## Açık kalanlar (paket turu)

- **04/Pazarama açık mı kalacak?** Çift kayıt riski; kullanıcı kararı bekliyor.
- Yerel `appsettings.json`'daki CRS 04 kimliği canlıyla eşitlenecek mi?
- Pakette `.pdb` dosyaları kalsın mı?
- PTT barkod aralığının doğrusu ne? (başlangıç/bitiş ters)

---

## Ek tur — yönetici kendi arayüzünden kilitliymiş

### 15. Belirti

Kullanıcı `https://ms.uzmanadres.com/zamanlama` sayfasında dört şeyin **hiçbirinin
olmadığını** bildirdi: bağlantı cümlesi girme, mail alıcılarını girme, saati değiştirme,
manuel çalıştırma. Kullanıcı `yonetici` rolüyle giriş yapmış durumda.

İlk varsayımım "paket kuruldu mu" idi ve **yanlıştı**: `GET /api/surum` canlının
`04e03fe` / `2026-09-18 09:23` olduğunu, yani sabahki paketin kurulu olduğunu gösterdi.
Varsayımla devam edilseydi tur boşa giderdi.

### 16. Kök sebep — rol karşılaştırması tam eşitlikti

- **Bulgu:** Sayfalar `rol === 'mudahaleEden'` diye **tam eşitlik** arıyordu. Roller
  hiyerarşik: `izleyen` < `mudahaleEden` < `yonetici`. Sunucu bunu **doğru** uyguluyor —
  `Modeller.cs:132`: `MudahaleEdebilir => RolAdi is Rol.MudahaleEden or Rol.Yonetici`.
  Arayüz uygulamıyordu.
- **Sonuç:** En yetkili rol en az yetkiyi görüyordu. Zamanlama sayfasında cron kutusu,
  aç/kapat, "Şimdi çalıştır" ve "Parametreler"in **dördü birden** render edilmiyordu.
  API istekleri kabul ederken düğme hiç çizilmiyordu — sessiz hata, hiçbir şey patlamıyor.
- **Yayılım:** Aynı hata `IsListesiSayfasi`, `KaynaklarSayfasi` ve
  `CalistirmaDetaySayfasi`'nda da vardı (durdur / tekrar dene dahil). Bazı sayfalar
  doğru yapıyordu (`RafSayfasi`: `rol === 'mudahaleEden' || rol === 'yonetici'`,
  `VarlikDetaySayfasi`: `rol !== 'izleyen'`) — yani kural sayfa başına elle yazıldığı için
  bazı yerlerde tutmuş, bazılarında tutmamıştı.
- **Düzeltme:** Kural tek yere alındı — `useAuth().mudahaleEdebilir`, sunucudakiyle
  **birebir aynı ifade**. Beş sayfa buna bağlandı.
- **Dokunulan dosyalar:** `web/src/context/AuthContext.tsx`,
  `web/src/pages/{ZamanlamaSayfasi,IsListesiSayfasi,KaynaklarSayfasi,CalistirmaDetaySayfasi,RafSayfasi}.tsx`,
  `web/tests/yetki.test.ts`, `web/tsconfig.node.json`
- **Commit:** `83a5ec2`, `09e8945`

### 17. Koruma testi ve iki kendi hatam

`web/tests/yetki.test.ts` hiçbir kaynak dosyanın tam eşitlik aramadığını doğrular.

İki hata yaptım, ikisi de kayda değer:

1. **Testi `src` altına koydum.** `tsconfig.app.json` tüm `src`'i kapsar ve yalnızca
   `vite/client` tiplerini tanır; `node:fs` kullanan test `npm run build`'i üç tip
   hatasıyla kırdı. **Tip denetimi yakaladı** — testler geçerken derleme kırılıyordu, yani
   "testler geçti" tek başına yeterli sinyal değil. Test `web/tests/` altına taşındı ve
   node tiplerini `tsconfig.node.json`'dan alıyor.
2. **Testin yakaladığını yanlış ölçtüm.** Hatayı geri koymak için kullandığım python tek
   satırı şuydu:
   ```python
   io.open(p,'w',encoding='utf-8').write(io.open(p,encoding='utf-8').read().replace(...))
   ```
   Python **önce yazma tutamacını** değerlendirir ve dosyayı sıfırlar, sonra argümanı
   değerlendirip **boş** dosyayı okur. Yani dosya silindi, test boş dosyaya bakıp geçti ve
   ben "test yakalamıyor" sonucuna vardım. Bu yanlış sonuçla `import.meta.glob` sürümünü
   "sessizce bozuk" diye suçladım — dayanaksızdı, testin içindeki gerekçe düzeltildi.
   Doğrusu iki ayrı ifade:
   ```python
   s = io.open(p, encoding='utf-8').read()
   s = s.replace(...)
   io.open(p, 'w', encoding='utf-8').write(s)
   ```
   Düzeltilince test hatayı **dosya adıyla** bildirdi.

- **Sonuç / doğrulama:** 51 web testi + 489 .NET testi geçti, `npm run build` temiz.

### 18. Yeni paket

`SentezServis-2026-09-18-1018.zip` (73,7 MB). Arayüz tarihi **2026-09-18 10:18**;
kurulumdan sonra `GET /api/surum` bunu dönmeli.

## Kararlar (yetki turu)

- **Yetki kuralı arayüzde tek yerde durur** (`useAuth().mudahaleEdebilir`) ve sunucudaki
  ifadenin aynısıdır. Sayfa başına elle yazılan rol karşılaştırması yasak; sınır testi
  zorluyor.
- **Koruma testi yazıldığında yakaladığı ölçülür.** Geçen ama yakalamayan test, hiç test
  olmamasından kötüdür: güven verir.

## Açık kalanlar (yetki turu)

- **Paket canlıya kurulmadı.** Kurulmadan yönetici düğmeleri görmeye başlamaz.
- **Bağlantı cümlesini arayüzden girme özelliği YOK** ve yazılmadı. Bu bir tasarım
  kararıdır: bağlantı cümlesi `sa` parolası taşır; veritabanında saklanıp web arayüzünden
  düzenlenebilir olması yeni bir saldırı yüzeyi açar ve `appsettings.json`'ın
  `deploy/yayinla.ps1` ile korunan sır temizliğini devre dışı bırakır. Kullanıcıyla
  konuşulacak.
- Diğer üç istek (alıcılar, saat, manuel çalıştırma) zaten vardı; yalnızca rol hatası
  yüzünden görünmüyordu.
