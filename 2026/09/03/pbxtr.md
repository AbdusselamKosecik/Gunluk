# pbxtr — 2026-09-03

## Bağlam

Dün gece geliştirme köprüsü kuruldu ve PC'den sunucudaki host ajanına bağlanıldı.
Bugünün işi: *"calisirabilrmiisn ui da bir inceleyelim"* — yığını açıp sistem
ekranlarını **gerçek host verisiyle** gezmek.

**Turun ana bulgusu:** üç kusurun üçü de host ajanı bağlandıktan sonra **ortaya
çıktı.** Veri hep boşken bu kod yolları hiç koşmuyordu; veri gelmeye başlayınca
"hep boş" varsayan kod **yanlış cevaplar** üretmeye başladı. Yani bunlar yeni
yazılmış hatalar değil, **görünür hâle gelmiş** hatalar.

## Yapılanlar

### 1. #46 Servis Yönetimi — çalışan servisler "durdu" görünüyordu (en ağırı)

- **Belirti:** `pbxtr.service`, `nginx.service`, `postgresql.service` → **"durdu"**.
  Oysa panelin kendisi o anda ayaktaydı.
- **Kök sebep:** Birimin var olup olmadığı `Id` alanının varlığına bakılarak
  ayrılıyordu ve kodun yazılı gerekçesi *"birim yoksa Id gelmez"* diyordu.
  **Geliyor:**

  ```
  pbxtr.service    Id=pbxtr.service   LoadState=not-found  ActiveState=inactive
  docker.service   Id=docker.service  LoadState=loaded     ActiveState=active
  ```

  pbxtr Docker ile koşuyor; `pbxtr.service` diye bir **host birimi hiç yok**.
  systemd yok olan birim için de `inactive` döner — tek ayırıcı `LoadState`.
- **Neden tehlikeli:** Operatörü **olmayan bir servisi yeniden başlatmaya** gönderir.
  Yanlış cevap, doğru cevap gibi görünüyordu.
- **Ne yapıldı:**
  - `SV-01` argv'sine `-p LoadState` eklendi. **Katalog ajanın ikilisinde gömülü**
    (`EmbeddedResource` link), bu yüzden ajan yeniden derlendi ve staging'e kuruldu
    (`/usr/local/lib/pbxtr/pbxtr-sysagent.onceki` yedeği bırakıldı).
  - `not-found` artık `null` **değil, ölçülmüş bir cevap**: ekranda **"birim yok"**.
    `null` "sorulmadı" demektir ve burada **soruldu** — ikisini tek etikete indirmek
    az önce düzeltilen hatanın başka yüzü olurdu.
  - Ton **`muted`**: Docker kurulumunda birim yokluğu **beklenen** hâldir; kırmızı
    çizmek her kurulumda kurt masalı anlatmak olurdu. Gerçek `inactive` **aynen
    kırmızı** kalır.
  - **Eski ajan dalı:** `LoadState` gelmiyorsa ve durum `inactive` ise ayrım
    **yapılamaz** → "sorulmadı". "Durdu" yazmak, ayırt edilemeyeni ölçülmüş gibi
    göstermek olurdu.
- **Dokunulan dosyalar:** `system-commands.json`, `ExpectedServiceCatalogReader.cs`,
  `servicesApi.ts`, 9 dil dosyası
- **Komutlar:**
  ```bash
  dotnet publish src/Pbxtr.SysAgent -c Release -r linux-x64
  scp .../publish/pbxtr-sysagent root@176.88.41.220:/tmp/pbxtr-sysagent.yeni
  # sunucuda: yedek al, install, systemctl restart pbxtr-sysagent
  ```
- **Doğrulama (canlı):** pbxtr/nginx/postgresql/redis **"birim yok"**,
  docker/fail2ban/ufw/chrony/unattended-upgrades **"çalışıyor"**,
  `asterisk.service` **"sorulmadı"** (ayrı sunucu, bilinçli).

### 2. #46 başlığı verinin tersini iddia ediyordu

- Panel kalın harflerle **"SERVİSLERİN ÇALIŞIR DURUMU SORULMADI"** yazıyor, hemen
  ardından sunucunun kendi cümlesi *"… SV-01 ile okundu"* geliyor, kartta da
  **"ölçüldü"** yazıyordu. Aynı panelde üç ifade, ikisi doğru biri yanlış.
- Sebep: `srv.stateNotAskedLead` **koşulsuz** basılıyordu. #35 Güvenlik Duvarı ve
  #44 Paket Yönetimi bu ayrımı zaten yapıyordu; **#46 tek istisnaydı.**
- `srv.stateMeasuredLead` eklendi (9 dil) ve seçim `stateMeasured`'a bağlandı.

### 3. DataTable — uzun belirteç komşu sütunun üstüne taşıyordu

- **Belirti (#40 Ağ Arayüzleri):** IP/PREFİX sütunu MAC sütununun üstüne biniyor,
  ikisi üst üste okunuyordu.
- **Sebep:** `.cellWrap` `white-space: normal` + `overflow: visible`.
  `normal` yalnızca **boşlukta** kırar; `fe80::407f:2cff:fe5b:b772/64` içinde
  kırılacak yer yok → metin hücrenin dışına boyanıyor.
- **Ölçüldü (tarayıcı, gerçek host verisi):** 180px hücrede metin **218px**, MAC
  sütununa **38px** taşıyor. `overflow-wrap: anywhere` ile **179px**, taşma yok.
- **`break-all` değil:** o normal Türkçe metni de rastgele yerden bölerdi.
  `anywhere` yalnızca satır **başka türlü taşacaksa** kırar.
- Paylaşılan bileşen olduğu için **sarma kullanan her tabloyu** düzeltir.

### 4. Kusur olmayan, ölçülüp geçilenler

- **#40'ta sağdaki TX/HATA sütunlarının kesilmesi kusur değil:** sarmalayıcıda
  `overflow-x: auto` var (1166px görünür / 1628px içerik) — tablo kendi içinde
  kayıyor.
- **#35 Güvenlik Duvarı** host'tan **9 gerçek ufw kuralı** okuyor; dört katmandan
  üçü ölçülü.

## Kararlar

- **"Ölçülmedi" ile "yok" ile "durdu" üç ayrı cevaptır** ve üçü ayrı etiketle
  yazılır. İkisini birleştirmek her seferinde aynı hatayı üretiyor.
- **Birim yokluğu kırmızı değildir.** Karar okuyanındır; ekran gerçeği yazar.
- **Eski ajanla belirsizlik "sorulmadı"ya düşer**, "durdu"ya değil.

## Ölçüm

Api SystemAdmin+SystemOps **325/325** (4 yeni test), üç mutasyonla doğrulandı
(not-found ayrımını kaldır / eski-ajan belirsizliğini geçir / not-found'u null
döndür) — üçü de kırmızı. web **1315/1315**, Architecture **338/338**,
`dotnet format` temiz.

**Commit:** `2334f101`

### 5. Admin Dashboard'da çalışmayan satırlar — 12 bileşenin 10'u yeşil

- **Kullanıcı:** *"calismayan yerleri calistirabilirmisn. Host ayni sekilde linux
  sunucu bu bilgisayar degil."*
- **Başlangıç:** 5 bileşen ölçülemiyordu — `tls-certificate`, `storage`, `host-disk`,
  `host-resources`, `asterisk` (+ `provisioning-pull` **down**).

#### 5.1 Host diski artık **ajandan** okunuyor (`DK-01`)

- **Bulgu:** Disk yalnızca `DriveInfo` ile okunuyordu — yani **uygulamanın gördüğü**
  dosya sistemi. Windows'ta host'un diski oradan görülmez ve satır susuyordu.
  **`DK-01` katalogda 2026-08-29'dan beri duruyordu ama hiçbir yer çağırmıyordu**
  (yine *kod var, koşan yok*).
- **Sıra bilinçli:** yapılandırılmış yol (üretimdeki `/host-fs` bind mount) **kazanır**;
  ajan yalnızca yol yazılmamışsa devreye girer. Ajan önce denenseydi çalışan bir üretim
  yolu sessizce değişirdi, üstelik ajan düştüğünde okuma da düşerdi — oysa mount ayakta.
- **İlk satır değil `/` seçilir.** `df` çıktısında onlarca satır var (udev, tmpfs,
  overlay); ilkini almak, hangi diski gösterdiği **çekirdek sıralamasına bağlı** bir
  sayı üretirdi — her açılışta değişebilen ve hiçbir testin yakalayamayacağı bir yanlış.
- `IHostDiskProbe` asenkron oldu; rollup işinde okuma **döngüden önce ve bir kez**.
- **Ölçüldü:** PC'den %21 dolu / 77.4 GB — sunucunun kendi değeriyle aynı.

#### 5.2 Ek deposu gerçekten yoklanıyor

- **Satır sabitti** ve daima *"yoklama ucu yok"* diyordu — yani hiçbir şey ölçmüyordu.
  **Sabit bir satır arıza anında da aynı cümleyi basar:** depo tamamen düşse ekran
  hiçbir şey söylemezdi.
- `IAttachmentStoreProbe` eklendi; MinIO ve yerel disk uygulamalarının ikisi de yoklanır.
- **Nesne YAZILMAZ** (sağlık ekranı her açılışta kovaya çöp üretirdi ve yetim tarayıcı
  onları silmeye çalışırdı) ve **LİSTELENMEZ** — `IObjectStoreInventory` kendi belgesinde
  *"hiçbir istek yolunun kova listeleme yetkisi olmamalıdır"* der ve `GET /system/health`
  bir istek yoludur.
- **Yoklama aynı örneği paylaşır**; ayrı kaydedilseydi ikinci bir S3 istemcisi doğar ve
  sağlık ekranı **başka bir yapılandırmayı** ölçebilirdi — "yeşil ama çalışmıyor" tam
  böyle üretilir.
- **Ölçüldü:** 8 ms, `pbxtr-attachments` erişilebilir.

#### 5.3 Panel TLS sertifikası yerelde de ölçülüyor

- Üretimde zaten çalışıyordu (5453 gün); yerelde `Tls:CertificatePath` boştu.
- Dosya sunucudan `.yerel/panel-tls.pem` içine çekiliyor (jetonla aynı desen).
- **Yalnızca `BEGIN CERTIFICATE` taşır**; özel anahtar ayrı dosyada (`0600`) ve betik
  `PRIVATE KEY` görürse kopyayı **siler** — sessizce PC'ye özel anahtar indirmek,
  kolaylığın en pahalı biçimi olurdu.
- **Kataloğa `FR-*` eklenmedi:** katalog yolları **sistem** yollarıdır;
  `/home/vuo/pbxtr-demo/...` bir dağıtım ayrıntısıdır ve oraya gömülseydi katalog tek
  bir kurulumun klasör düzenine bağlanırdı.

#### 5.4 Kalan ikisi bilinçli

- `asterisk` — CLAUDE.md §3.0: fiilen bağlanılmıyor.
- `provisioning-pull` — **down**, ama bu bir **ölçüm**: config Asterisk'e gitmiyor.

#### Ölçüm

11 yeni test. Mutasyonla doğrulandı: ilk satırı seç / yapılandırılmış yolu atla /
çıkış kodunu yoksay / yanlış katalog kimliği / arızayı ok say / arızayı ölçülemedi say
— hepsi kırmızı.

**Bir mutasyon önce hayatta kaldı** (çıkış kodu dalı): fikstürde boş `stdout` vardı,
dolayısıyla çıktı zaten ayrıştırılamıyordu ve test **başka bir yoldan** yeşil kalıyordu —
dal hiç koşmuyordu. Geçerli bir `df` satırıyla yeniden yazıldı; artık kontrolü kaldırmak
bir **ölçüm** üretiyor ve test kırılıyor.

Api **403/403**, Architecture **338/338**, `dotnet format` temiz.

**Commit:** `c106318e`
### 6. CLAUDE.md §3.0 kaldırıldı — **Asterisk'e bağlanıyoruz**

- **Kullanıcı kararı:** *"Asterisk (CLAUDE.md §3.0 — bağlanmıyoruz) u kaldir abim.
  Sunucuda ami ari den baglanacagiz, daha da baglanacaksak host ajani ustunden
  dockerden calistiracagiz."*

#### Ölçüm önce: **zaten bağlıydık**

Kuralı değiştirmeden önce ölçtüm ve sonuç şaşırtıcıydı:

```
dev.log: "ARI Stasis uygulamasi 'pbxtr' acildi."
AMI     : Asterisk Call Manager/11.0.0   (banner geldi)
ARI     : HTTP 401 (kimliksiz — beklenen)
```

**Yani kod bağlanıyor, ekran "bağlanmıyoruz" diyordu.** Sağlayıcı zaten `asterisk`
modundaydı; sabit olan yalnızca sağlık satırıydı. Kural kaldırılmasaydı bile o cümle
yanlıştı — *karar yazılmış ama uygulanmamış*ın tersi: **uygulanmış ama karar
güncellenmemiş.**

#### Kural yeniden yazıldı

- Eski hâl **silinmedi**, `GEÇERSİZDİR` diye işaretlendi ve "artık ne değişti" tablosu
  ona göre yazıldı — sonraki okuyucu neyin değiştiğini metne bakarak görebilsin.
- **Değişmeyenler açıkça sayıldı:** Asterisk pbxtr PostgreSQL'ine asla bağlanmaz;
  Sınıf B uçları kapalı liste; kuyruk üyeliği AMI ile push edilir; nesne adları tenant
  önekli; reload komutları kapalı liste. Bir kuralı kaldırırken **komşularının da
  kalktığı** varsayımı en pahalı okuma hatasıdır.
- Daha derin ihtiyaçta yol **host ajanıdır** ve komut **kapalı katalogdan** seçilir —
  serbest kabuk yok.

#### Sağlık satırı üç hâl üretiyor

- `ITelephonyLinkStatus`'a bağlandı: **açık / kopuk / ölçülecek bağlantı yok**.
- **`null` kırmızı değildir.** Simülasyonda hiç kurulmamış bir bağlantıyı "santral
  kapalı" diye göstermek, var olmayan bir arıza uydurmak olurdu.
- **Okuma santrale gitmez:** süreç içi bayrak. Sağlık ekranı dakikada bir açılabilir;
  her açılışta Asterisk'e istek atmak, ölçmek istediğimiz şeye yük bindirirdi.

#### Kuralın bayatlattığı metinler

Kaldırılan kural 6 yerde daha atıf alıyordu ve hepsi artık yanlıştı. Düzeltilenler:
`SystemHealthProbe`, `ISystemHealthProbe`, `IAgentExtensionDirectory`,
`ThreatMonitorReader`, `ServicesScreen` ve **#46'nın Asterisk satırı (9 dil)**.

O satır *"Asterisk ayrı bir sunucudadır ve pbxtr ona bağlanmamaktadır"* diyordu —
**iki iddia da yanlıştı**: Asterisk bu sunucuda bir **konteynerdir** (`pbxtr-asterisk`,
2 gündür ayakta) ve host systemd birimi yoktur (ölçüldü: `LoadState=not-found`).
Yeni metin ne olduğunu söylüyor: konteyner, host birimi yok, durumu AMI/ARI ile #37'de
ölçülür.

#### Ölçüm

**12 bileşenin 11'i yeşil** — `Asterisk → ÇALIŞIYOR`. Kalan tek satır
`Config Teslimi (confd)` (down; gerçek ölçüm, config Asterisk'e gitmiyor).

5 yeni test; iki mutasyonla doğrulandı (kopuğu `ok` say / `null`'ı kopuk say) — ikisi
de kırmızı. Api **1034/1034**, Architecture **338/338**, web **1315/1315**,
`dotnet format` temiz.

> Bir tur `web 3 failed` verdi ve **tekrarında yeşil geldi**: o koşu paralel
> `dotnet test` yüküyle çakışmıştı. Kararsızlık olarak not edildi, düzeltme yapılmadı.

- **Commit:** `57b39ca6`
## Açık kalanlar / sonraki adım

- **Bu değişiklikler pbxtr.com'a YAYINLANMADI** — yalnızca depoda ve yerel yığında.
  Sunucudaki **ajan ikilisi** güncellendi (o canlı).
- Mutasyon turunda **çıktı bir kez boş geldi**: dev backend DLL'i kilitliyordu ve
  `grep "error CS"` deseni `MSB3027`'yi tutmuyordu — yani üç mutasyon da "sessizce"
  geçmiş görünüyordu. Backend durdurulup tekrarlandı. *(Bilinen tuzak; deseni
  `error` olarak genişlettim.)*
- Geliştirme köprüsü hâlâ **açık**: `systemctl stop pbxtr-sysagent-kopru`.
- Hâlâ ölçülemeyen: **yedekleme durumu** ve **fail2ban kural listesi**.
  *(Host diski çözüldü — bkz. §5.1.)*
- **Sabit bir sağlık satırı, ölçüm değildir.** "Yoklama ucu yok" cümlesi arıza anında
  da aynı kalır; yani o bileşen çöktüğünde ekran sessiz kalır. Sabit satır = gizli
  kör nokta.
- **Mutasyonun hayatta kalması fikstürü sorgulatır.** Bu turda tam olarak bu oldu:
  kod doğruydu, testin verisi dalı hiç koşturmuyordu.
- Bu değişiklikler **pbxtr.com'a yayınlanmadı**. Sunucuda üretimde `storage` hâlâ
  eski "yoklama ucu yok" cümlesini basıyor.
- **Bir kuralı kaldırmadan önce ölçün: belki zaten uygulanmıyordur.** Burada tam tersi
  çıktı — kural kâğıtta duruyordu, kod çoktan bağlanıyordu.
- **Kaldırılan kuralın atıfları da bayatlar.** 6 yerde daha geçiyordu; kuralı silip
  atıfları bırakmak, ekranı yanlış konuşmaya devam ettirirdi.
- Hâlâ eski kurala atıf yapan **dokümanlar**: `doc/mimari/ADR-014` §8.2 ve
  `doc/prototip-urun-farklari.md` (birkaç satır). Kod ve ekran temiz, doküman değil.
- `Config Teslimi (confd)` **down** kalmaya devam ediyor: `pbxtr-confd` düğümleri
  bundle çekmiyor. Artık bağlantı açıldığına göre bu iş yapılabilir hâle geldi.

---

### 8. #63 Asterisk Konsolu — 12 komutun 12'si çalışmıyordu (sessizce)

- **Neden:** Ekranlardan devam ederken #63 açıldı; "Kuyruk listesi" → "Çalıştır"
  çıktısı **`Permission denied`**. Ekran bunu **arıza olarak göstermiyordu**: uç
  `200` ve `connected: true` dönüyor, reddi yalnızca çıktı metni taşıyordu.

- **Ölçüm (önce):**
  ```
  POST /api/v1/telephony/console/run {"commandId":"AST-05"}
    -> 200 {"connected":true,"output":"Permission denied"}

  /etc/asterisk/pbxtr.d/credentials/ami.conf
    write = call,agent,originate          # `command` YOK
  ```
  AMI'nin `Command` eylemi `command` yazma yetkisi ister.

- **Karar:** **AMI'ye `command` verilmedi.** Vermek, AMI'ye erişen herkese keyfi bir
  Asterisk CLI'si açardı — CLAUDE.md §3.1'in `asterisk -rx` tuzağı başlığı altında
  açıkça yasakladığı şey. *Yol değiştirildi, kapı genişletilmedi.* Kullanıcı bu yolu
  zaten önceden yetkilendirmişti: *"daha da bağlanacaksak host ajanı üstünden
  Docker'dan çalıştıracağız."*

- **Ne yapıldı:** Katalog, yetki, tenant kuyruk çözümü ve denetim **aynen kaldı**;
  yalnızca **taşıma katmanı** değişti.
  - `system-commands.json` → `AST-CLI`, screenCode 63,
    argv `/usr/bin/docker exec pbxtr-asterisk /usr/sbin/asterisk -rx <cli>`.
  - `cli` **kapalı bir `enum`**; değerleri `AsteriskCommandCatalog`'un ta kendisi.
  - `AsteriskCliRunner` — ajan varsa ajan, yoksa AMI (fallback silinmedi).
  - `AsteriskQueueBlock` — AST-06'nın blok ayırıcısı.

- **Dokunulan dosyalar:** `src/Pbxtr.Infrastructure/Platform/SystemOps/system-commands.json`,
  `src/Pbxtr.Infrastructure/Telephony/Asterisk/{AsteriskCliRunner,AsteriskQueueBlock,
  AsteriskCommandCatalog,AmiAsteriskConsole}.cs`,
  `src/Pbxtr.Infrastructure/Telephony/TelephonyServiceCollectionExtensions.cs`,
  `tests/Pbxtr.Architecture.Tests/{AsteriskConsoleTransportTests,AsteriskCommandCatalogTests}.cs`,
  `tests/Pbxtr.Api.Tests/Modules/Telephony/AsteriskQueueBlockTests.cs`,
  `tests/Pbxtr.Api.Tests/Modules/SystemAdmin/SystemOpsReaderTests.cs`,
  `CLAUDE.md` §3.1, `doc/mimari/ADR-014` §2.10.2.

- **Komutlar:**
  ```bash
  dotnet publish src/Pbxtr.SysAgent/Pbxtr.SysAgent.csproj -c Release -r linux-x64 \
    --self-contained true -p:PublishSingleFile=true -o <cikti>
  scp <cikti>/pbxtr-sysagent root@176.88.41.220:/usr/local/lib/pbxtr/pbxtr-sysagent.yeni
  ssh root@176.88.41.220 'cd /usr/local/lib/pbxtr && cp -a pbxtr-sysagent pbxtr-sysagent.onceki \
    && chmod 755 pbxtr-sysagent.yeni && mv pbxtr-sysagent.yeni pbxtr-sysagent \
    && systemctl restart pbxtr-sysagent'
  ```

- **Sonuç / doğrulama:** Uçtan uca (yerel panel → Tailscale → ajan → konteyner)
  **12 komutun 12'si gerçek çıktı** dönüyor: `core show version` → *Asterisk 22.10.1*,
  `queue show` → 3 tenant kuyruğu, `core show channels`, `dialplan show`, `core show calls`.
  AST-06 iki meşru kuyrukta doğru bloğu, kapsam dışı adda **404** döndü.
  Testler: Architecture 342/342, Api.Tests Telephony 686/686, SystemAdmin 307/307,
  `dotnet format` temiz.

- **Commit:** `043cad5e` — fix(telephony): #63 konsol komutlari GERCEKTEN kosuyor

#### 8.1 Ölçülen teknik ayrıntılar (bir daha aramamak için)

- **Bölünmüş argv ÇALIŞMIYOR.** `asterisk -rx queue show` (tırnaksız, iki argv öğesi)
  yalnızca ilk belirteci komut sayar: `No such command 'queue'` — ve **çıkış kodu 0**
  döner, yani hatayı yutar. `-rx` tek dizeli argüman ister.
- **Boşluklu `enum` değeri güvenlidir.** Ajan parametreyi `argv`'ye **tek öğe** olarak
  ekler (`ProcessStartInfo.ArgumentList`), kabuk yoktur, yeniden ayrıştırma yapılmaz.
  Bu, kapalı listeyi bozmadan `"queue show"` gibi çok kelimeli bir komut geçirmenin
  tek yoludur.
- **AST-06'nın kuyruk adı `enum`'a giremez** (tenant'a özgü, derleme zamanında bilinmez)
  ve `enumFromProbe` boşluk kabul etmez. Bu yüzden komut `queue show`dur ve blok
  **çıktıdan ayrılır**.
- **Katalog sayısı 3 yerde çivili:** `SystemOpsReaderTests` (iki kez), ADR-014 §2.10
  tablosu, `$comment`. 53 → 54, okuma 36 → 37.

### 9. Kararlar

- **Yetkiyi genişletmek yerine yolu değiştir.** `command` yetkisi bir okuma kolaylığı
  için verilecek en pahalı tavizdi: geri alınması zor, etkisi AMI'nin tamamı.
- **Ajan sözleşmesine "serbest metin" parametre tipi eklenmedi.** AST-06 için cazipti;
  eklemek kapalı listeyi fiilen kaldırırdı. Bir satır ayrıştırma daha ucuz.
- **AMI fallback silinmedi.** `command` verilmiş bir kurulumda çalışır ve ajanı olmayan
  bir kurulumun tek yoludur; ama ajan bağlıyken AMI'ye **düşülmez** — ölçülmüş şekilde
  `Permission denied` dönen bir yolu ikinci kez koşturup o metni santralin cevabı gibi
  göstermek olurdu.

### 10. Açık kalanlar

- **Ölçüm hatası kaydı:** katalog ucunun anahtarı `items`, `commands` değil. İlk
  ölçümde "0 komut görünüyor" sonucuna vardım; yanlıştı — 12 komut dönüyordu.
  *Önce yanıtın ham hâline bak, sonra ayrıştır.*
- `$comment`'teki **"BU DALGADA HİÇBİRİ ÇALIŞTIRILMAZ / sysagent bu sunucuda yok"**
  satırları bayattı (ajan kurulu ve etkin) — düzeltildi. *Bayat beyan, yanlış beyandır.*
- Geliştirme köprüsü hâlâ **açık** (yerel geliştirme buna bağlı):
  `systemctl stop pbxtr-sysagent-kopru`.
- Bu değişiklikler **pbxtr.com'a yayınlanmadı**; sunucuda yalnızca **ajan ikilisi**
  güncellendi (yedek: `/usr/local/lib/pbxtr/pbxtr-sysagent.onceki`).
- Hâlâ ölçülemeyen: yedekleme durumu, fail2ban kural listesi. `Config Teslimi (confd)`
  hâlâ **down**.
