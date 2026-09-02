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

## Açık kalanlar / sonraki adım

- **Bu değişiklikler pbxtr.com'a YAYINLANMADI** — yalnızca depoda ve yerel yığında.
  Sunucudaki **ajan ikilisi** güncellendi (o canlı).
- Mutasyon turunda **çıktı bir kez boş geldi**: dev backend DLL'i kilitliyordu ve
  `grep "error CS"` deseni `MSB3027`'yi tutmuyordu — yani üç mutasyon da "sessizce"
  geçmiş görünüyordu. Backend durdurulup tekrarlandı. *(Bilinen tuzak; deseni
  `error` olarak genişlettim.)*
- Geliştirme köprüsü hâlâ **açık**: `systemctl stop pbxtr-sysagent-kopru`.
- Hâlâ ölçülemeyen: **yedekleme durumu**, **host diski** (yerelde, ajandan
  okunmuyor), **fail2ban kural listesi**.
