# pbxtr — 2026-09-01

## Bağlam

Gün, `/goal` maddeleri açıkken başladı. Dün (31 Ağustos) rol atama kapısı açılmış,
VPN üzerinden yerel geliştirme kurulmuştu. Bugünkü hedefler `/goal`'un 3., 4. ve
7. maddeleri: **platform gelen kutusunun kullanılabilir hâle gelmesi** (sayfalama,
arama, tam sayfa detay, ekler) ve **tenant yönetiminden geçişin kaldırılıp
kullanıcıya bürünmeye çevrilmesi**.

Yerel yığın `deploy/yerel-baslat.sh` ile ayakta: UI ve backend localde, PostgreSQL /
Redis / MinIO / Asterisk sunucuda (Tailscale `100.106.82.119`). Doğrulamalar gerçek
veriyle, tarayıcı üzerinden yapıldı.

## Yapılanlar

### 1. Süper adminden üç tenant-yapılandırma ekranı kaldırıldı

- **Neden:** Kullanıcı: *"http://localhost:5173/queues i super adminden kaldir,
  http://localhost:5173/trunks, http://localhost:5173/working-hours bunu birde"*.
  Bunlar tenant'ın kendi yapılandırmasıdır; platform sahibinin ekranı değildir.
- **Ne yapıldı:** `bundle.telephony.admin` demeti 15 koddan 9'a indirildi; ayrılan
  6 kod (`queue.read/write`, `trunk.read/write`, `workinghours.read/write`) yeni
  `bundle.telephony.tenant.config` demetine taşındı ve **yalnızca `admin`** rolüne
  verildi.
- **Dokunulan dosyalar:** `src/Pbxtr.Api/Platform/Authorization/permissions.seed.json`,
  `src/Pbxtr.Web/src/app/screens/system-roles.generated.ts`
- **Sonuç / doğrulama:** Süper adminde sol menüden üç ekran düştü; admin'de duruyor.
- **Commit:** `88d6a046`

### 2. Platform gelen kutusu (#62) — ızgara, arama, sayfalama, tam sayfa detay

- **Neden:** `/goal` madde 3: *"cok tickette sikinti cikar, ticketleri sayfalama
  yapmamiz lazim, arama yapmamiz lazim yani grid olmasi lazim. basinca yeni ekranda
  tum deyayini gormemiz lazim. resimleri de gormemiz lazim tekrar tiklamadan."*
  Ekran 340px'lik bir sütuna sıkışmıştı.
- **Ne yapıldı:** `limit` parametresi kaldırıldı (bir tavan, "gerisi yok" ile
  "gerisi gösterilmiyor" arasındaki farkı gizliyordu), yerine `page`/`pageSize`
  geldi ve sunucu `total` döndürüyor. Arama eklendi. Liste ve detay tam sayfaya
  çıkarıldı.
  **Arama maskelemeyle çakışır:** numara görme yetkisi olmayan kullanıcının rakam
  içeren araması **sunucuda** 400 ile reddedilir; ekran kuralı tekrarlamaz.
- **Dokunulan dosyalar:** `src/Pbxtr.Web/src/app/screens/support/PlatformTicketScreen.tsx`,
  `.../PlatformTicketScreen.module.css`, `src/Pbxtr.Api/Modules/Support/PlatformTicketEndpoints.cs`
- **Commit:** `b640077d`, `740984ee`

### 3. Kapalı talep yeniden açılabiliyor + durum elle yazılabiliyor

- **Neden:** Kullanıcı: *"yeniden acip cevap durum yazmam lazim"*. Öncesinde tek
  çare talebe mesaj yazmaktı — yani **durum düzeltmek için yazışma kirletiliyordu**.
- **Ne yapıldı:** `POST /platform/tickets/{id}/status` eklendi. Bilinmeyen durumda
  400 (izinli küme gövdede), değişiklik yoksa 409 `Unchanged`, başarıda
  `previousStatus`. `ClosedAt` durumla birlikte hareket eder.
  **Kapatma ucu kaldırılmadı:** kapatmak en sık işlemdir, tek tıkta kalmalı.
- **Dokunulan dosyalar:** `src/Pbxtr.Api/Modules/Support/PlatformTicketEndpoints.cs`,
  `src/Pbxtr.Infrastructure/Modules/EfPlatformTicketDesk.cs`, `.../EfTicketDesk.cs`
- **Commit:** `9b0b078b`

### 4. Ek yükleme + **indirmedeki 500 onarıldı** (gerçek kusur)

- **Neden:** Kullanıcı: *"resim ek yukleme yapsak olmaz mi"*, ardından
  *"indirmede 500 aliyoruz"*.
- **Ne yapıldı:** Yükleme ucu eklendi. İndirme 500'ünün sebebi
  `NoAmbientTransactionException`'dı: uç `[SelfManagedTransaction]` işaretliydi —
  yani `UnitOfWorkMiddleware` **transaction açmıyordu** — ama denetim satırını
  kendi içinde yazmaya çalışıyordu (ADR-004 §3.3). Denetim yazımı
  `desk.RecordAttachmentDownloadAsync(...)` içine, masanın kendi transaction'ına
  alındı.
  **Sınıfı kapatan bekçi eklendi:** `ApiEndpointAuthorizationTests` içinde
  `SelfManaged_uclar_denetimi_kendisi_yazmaz` — self-managed bir uç imzasında
  `IAuditLog` taşıyamaz.
- **Ölçüm tuzağı:** İlk yükleme testim ayrıştırmıyordu — talebin sahibi zaten
  platform tenant'ıydı, "sahibine yazdı" ile "çağırana yazdı" aynı görünüyordu.
  Test `1111…1111` tenant'ındaki bir talebe taşındı.
- **Commit:** `019bcc8c`

### 5. Tenant geçişi kaldırıldı — içeri girmenin tek yolu bürünme

- **Neden:** Kullanıcı: *"Bu tenata gec kalkacak sadece tenant icindeki
  kullanicilardan Bu kullanıcı olarak çalış dan yapilacak. kullanici ya burunup
  herseyi yapabilecek Kullanici uzerinden (sag ust -> cikis uzeri) yetkilenmeden
  cik gibi bir buton ile yetkiyi birakacagiz."*
- **Ne yapıldı:**
  - #53'teki satır düğmesi ve tüm geçiş akışı (`guardTenantSwitch`, `switchTo`,
    `switching`/`switchError`) silindi; ona ait **7 i18n anahtarı × 9 dil**
    kaldırıldı (kodda 0 çağıran ölçüldü).
  - `tnt.listSubtitle` artık olmayan bir düğmeyi tarif ediyordu; 9 dilde
    **yerine geçen yolu söyleyecek** şekilde yeniden yazıldı.
  - Kimlik menüsüne **"Kendi hesabıma dön"** eklendi — çıkışın **üstünde**,
    yalnızca bürünülmüşken çizilir. Şerit kaldırılmadı: o bir güvenlik uyarısıdır,
    menü satırı ise kullanıcının **aradığı** yerdedir.
- **Dokunulan dosyalar:** `src/Pbxtr.Web/src/app/screens/tenant/TenantScreen.tsx`,
  `.../TenantSwitch.test.tsx`, `src/Pbxtr.Web/src/app/shell/IdentityMenu.tsx`,
  `src/Pbxtr.Web/src/app/api/tokens.ts`, `.../screens/users/impersonationApi.ts`,
  `.../screens/users/UserDetailPanel.tsx`, 9 × `i18n/messages/*.json`,
  `tests/Pbxtr.Architecture.Tests/TenantSwitchSurfaceTests.cs`
- **Commit:** `512d5867`

### 6. **Çapraz-tenant bürünme çalışmıyordu** (gerçek kusur, ölçümle bulundu)

- **Neden:** 5. maddeyi tarayıcıda denerken çıktı.
- **Ölçüm (tarayıcı ağ kaydı):**

      POST /api/v1/impersonation -> 200      (jeton alındı)
      GET  /api/v1/me            -> 403
      GET  /api/v1/me/menu       -> 403

- **Sebep:** Jeton artık hedefin (`scope=single`) jetonuydu ama istemcinin **aktif
  tenant'ı hâlâ aktörünkiydi** ve her isteğe `X-Tenant-Id` olarak o yazılıyordu.
  Sunucu haklıydı: scope=single kullanıcı yalnızca kendi tenant'ına erişebilir.
- **Neden bugüne kadar görünmedi:** Bürünme hep aktörün **kendi** tenant'ı içinde
  yapılıyordu, dolayısıyla aktif tenant zaten doğruydu. Çapraz-tenant bürünme
  mümkün olunca ortaya çıktı.
- **Ne yapıldı:** `startImpersonation(token, expiresIn, tenantId)` aktif tenant'ı da
  taşıyor; **eski tenant askıda tutuluyor** ve `endImpersonation()` onu geri koyuyor
  — yoksa aktör kendi hesabına dönüp **başka bir müşterinin tenant'ında** kalırdı.
- **Doğrulama (tarayıcı, gerçek veri):** Süper Admin → #53 → Ertan Grup →
  Kullanıcılar → Ayşe Kılıçarslan (`demo.supervizor`) → "Bu kullanıcı olarak çalış":
  `/me` **200**, `/me/menu` **200**, süpervizör menüsü ve `/live/queues` çizildi,
  şerit göründü. Menüdeki "Kendi hesabıma dön" → **Süper Admin / pbxtr Platform**,
  şerit yok.

### 7. Ek yükleme teslim manifesti yoluna alındı (kapı sahte yeşildi)

- **Neden:** `deliveryManifest.test.tsx` kırmızı verdi:
  `platform-inbox.attach production request consumer: expected false to be true`.
- **Ne bulundu:** Bağlantı tanımlıydı ve düğme `data-pbxtr-action` ile o ucu
  **sürdüğünü söylüyordu**, ama istek çıplak `apiFetch`'ten çıkıyordu — yani
  **method/path drift kapısı bu ucu ölçtüğünü sanıyordu.** Uç tarafında rota değişse
  istemci hiçbir şey söylemeden 404 almaya başlardı.
  Gerekçe olarak yazdığım "request yolu JSON gövdesi kurar" cümlesi **yanlıştı**:
  `apiFetch` `FormData`'yı zaten özel ele alıyor (JSON'a çevirmez, `Content-Type`
  yazmaz) ve `request` seçenekleri olduğu gibi iletiyor.
- **Ne yapıldı:** Yükleme bağlantının `request`ine alındı; `api/tickets.ts`'teki iki
  ölü kopya (`uploadPlatformTicketAttachment`, `setPlatformTicketStatus` — kapıyı
  atlayan ikinci yol) ve `api/index.ts` dışa aktarımları silindi.
- **Commit:** `512d5867`

## Komutlar

```bash
# yerel yigin (UI + backend local, altyapi sunucuda / Tailscale)
bash deploy/yerel-baslat.sh

# olcumler
cd src/Pbxtr.Web && npx tsc -b && npx vitest run
dotnet test tests/Pbxtr.Architecture.Tests/Pbxtr.Architecture.Tests.csproj
```

**Sonuç:** web **1306/1306**, `tsc -b` temiz, Architecture **333/333**.

## Kararlar

1. **Bir tenant'ın içine girmenin tek yolu, o tenant'ın bir kullanıcısına
   bürünmektir.** Geçiş bir güvenlik sınırıydı ve düğmesi bir listenin satırındaydı;
   bürünme ise kimin adına iş yapıldığını **denetim günlüğüne yazar**.
2. **Kaldırılan davranışın testi silinmedi, tersine çevrildi.** Silinen bir test,
   davranışın yarın sessizce geri gelmesine izin verir. `TenantSwitch.test.tsx`
   artık **yokluğu** ölçüyor; dördüncü iddiası vacuity kapısıdır (1-3, ekranın hiç
   çizilmediği bir dünyada da yeşil kalırdı).
3. **Şerit ile menü satırı birlikte durur.** İkisi de "yetkiyi bırak" der ve bu
   bilinçlidir: şerit görmezden gelinemez bir uyarıdır, menü satırı kullanıcının
   aradığı yerdedir. Bir güvenlik uyarısını "çıkış yolu başka yerde" diye kaldırmak
   yanlış olurdu.
4. **Bir uç için ikinci bir çağrı yolu bırakılmaz.** Manifest bağlantısı varken
   çıplak `apiFetch` kopyası durursa, kapı ölçtüğünü sanır ve ölçmez.

### 8. #26 IVR, #27 Dahili, #39 Medya platform rollerinden kaldırıldı

- **Neden:** Kullanıcı: *"/telephony/ivr, /telephony/extensions, /maintenance/media
  bunlari kaldirimisin admin ve super adminden ve bayiden"*.
- **Ölçüm önce:** **Bayide zaten yoktu.** `dealer` rolü bu kodların hiçbirini
  taşımıyordu; ekranlar yalnızca `superadmin` ve `admin`'de vardı ve ikisi de aynı
  demetten (`bundle.telephony.admin`) alıyordu.
- **Ne yapıldı:** Demet 9 → 1 koda indi. Çıkanlar: `ivr.read/write`,
  `extension.read/write`, `media.read/write`, `ringgroup.write`.
  - `ringgroup.write` **de gitti**: ayrı ekranı yok, #27'nin ikinci yarısıdır.
    Bırakılsaydı ekranı olmayan bir **yazma** yetkisi kalırdı.
  - `codec.write` **silinmedi**, `bundle.telephony.tenant.config`'e taşındı: codec
    ayrı bir nesne değil, trunk'ın gövde alanıdır ve trunk artık yalnızca o pakette.
    Yerinde kalsaydı süper adminde yüzeyi olmayan bir yazma yetkisi olurdu;
    silinseydi `admin` trunk düzenlerken codec alanını kaybederdi.
- **Doğrulama (canlı):** superadmin jetonuyla `GET /api/v1/me/menu` → üç rota da
  **YOK**, `/analytics/network` **VAR**, toplam **23 ekran** (matris belgesiyle birebir).
- **Commit:** `20b11667`

### 9. **Dünkü kendi hatam ortaya çıktı: kırmızı bir kapı** (gerçek kusur)

- **Nasıl bulundu:** Seed değiştiği için Api takımının **tamamı** koşturuldu ve
  `NetworkQualityPermissionPairingTests` kırmızı yandı.
- **Kapı ne diyordu:** #25 Ağ Kalitesi yanıtında trunk'ın **yapılandırılmış peer
  adresini** taşır; bu bilgi normalde `trunk.read` ile görülür. Dolayısıyla
  `network.quality.read` taşıyan her rol `trunk.read` de taşımalıydı. Kapı
  **25 Ağustos'tan** beri vardı (`d771da57`).
- **Kim kırdı:** Dün `88d6a046` ile trunk'ı süper adminden kaldırdığımda çiftleme
  koptu ve **fark etmedim** — o commit'te Api takımını tam koşturmamışım. Sonuç:
  trunk okuması elinden alınmış bir rol, trunk topolojisini #25 üzerinden görmeye
  devam ediyordu. **Hiçbir hata üretmeden.**
- **Neden çiftleme geri kurulmadı:** İki yolu vardı ve ikisi de bir kullanıcı
  kararını çiğnerdi — süper admine `trunk.read`'i geri vermek (#04 menüye dönerdi)
  ya da ondan `network.quality.read`'i almak (#25 istenmediği hâlde kalkardı).
- **Ne yapıldı:** Testin **kendi reçetesi** uygulandı (metninde yazılıydı:
  *"ayrışırlarsa peerHost alanı kendi kapısına bağlanır"*). `peerHost` artık
  `trunk.read` ister; yetkisi olmayana `null` gider. **403 değil alan düşürme:**
  ölçümler (jitter/kayıp/RTT/MOS) trunk okuması gerektirmez; ucu kapatmak yetkisi
  olan bilgiyi de götürürdü. Kapı **sunucudadır** (CLAUDE.md §5).
- **Dokunulan dosyalar:** `src/Pbxtr.Api/Modules/NetworkQuality/NetworkQualityEndpoints.cs`

### 10. İlk test takımım üçüncü mutasyonu **kaçırdı**

- **Ölçüm:** Eşleyiciyi (`From(snapshot, peerHostVisible)`) doğrudan çağıran testler
  iki mutasyonu yakaladı (alanı hep gönder / hep düşür) ama üçüncüsünü **yakalamadı**:
  `PeerHostPermission` sabitini `trunk.read` yerine `network.quality.read` yapmak
  hiçbir testi kırmıyordu — ve o mutasyonla kapı **fiilen kalkar**, çünkü ucun kapısı
  zaten o yetkidir.
- **Sebep:** Eşleyici testleri `bool`'u kendileri verir; kararı **kimin** verdiğini
  hiç koşturmazlar.
- **Ne yapıldı:** Ucu gerçekten koşturan ikinci bir dosya yazıldı
  (`NetworkQualityPeerHostEndpointTests`) — handler çalışır ve kararı
  `ITenantContext.Permissions`'tan okur. Üç mutasyon da artık yakalanıyor.
  Yetkilendirme middleware'i **her policy'yi geçiren** bir sağlayıcıyla kurulur:
  gerçek sağlayıcı, ucun kapısını alan kapısının **önüne** koyar ve ölçülmek istenen
  ayrım hiç görünmezdi.
- **Eski çiftleme dosyası silinmedi, tersine çevrildi:** artık alanın kapısını ölçüyor
  ve üçüncü iddiası *"kapı üretimde fiilen kapanıyor mu"* diye soruyor — kapanmasa
  kod yolu hiç koşmaz ve bozulduğunda kimse görmez.

### 11. Girişteki 500 — benim bıraktığım kapalı backend

- Kullanıcı: *"loginde hata veriyor 500"*. Sebep: Api testlerinin build'i için DLL
  kilidini açmak üzere `Pbxtr.Api`'yi durdurmuş, geri başlatmamıştım. Vite (5173)
  ayaktaydı, arkasında kimse yoktu ve proxy 500 dönüyordu.
- Backend `deploy/yerel-gelistirme.sh` ile geri başlatıldı (5080); giriş **200**.
- **Ders:** `dotnet test` çalışan bir dev backend varken Debug DLL'lerini kilitler ve
  build hiç yapılmaz. Durdurmak zorunludur ama **geri başlatmak da işin parçasıdır**.

### 12. #61 — bayinin kullanıcıları görülür ve bürünülebilir

- **Neden:** Kullanıcı: *"bayilerin de tenant gibi davranip kullanicilari gorup
  kullanicilarina burunmemiz lazim"*.
- **Akış:** #61 satırında **Kullanıcılar** → #02 açılır, şerit *"şu bayinin
  kullanıcıları"* der, **Bu kullanıcı olarak çalış** ile bayiye bürünülür.
- **Doğrulama (tarayıcı, gerçek veri):** Anadolu İletişim Bayii → Gökhan Serttaş
  (`demo.bayi`) → Bayi Dashboard, bayinin kendi menüsü (Bayi Paneli, Tenant
  Yönetimi, API Anahtarları); "Kendi hesabıma dön" → Süper Admin / pbxtr Platform.
- **Commit:** `b6fac60d`

### 13. Bürünme kuralı: *"hedef Single olmalı"* → *"kapsamlı hedef DAHA GENİŞ aktör ister"*

- **Engel:** Kural bayiyi **adıyla** yasaklıyordu: *"Kapsamlı hesap (platform
  yöneticisi ya da bayi) taklit edilemez."*
- **Ama yazılı gerekçesi bayiyi kapsamıyordu:** *"başka bir platform yöneticisi
  olarak çalışmak o kişinin adına denetim satırı üretir — ve superadmin'de
  `audit.purge` gibi geri alınamaz yetkiler vardır."* Süper adminin (global) bir
  bayiye (dealer) bürünmesi tam olarak **daralmadır** ve bayide `audit.purge` yok.
- **Ne yapıldı:** Kural silinmedi, yeniden yazıldı. Korunan kusur aynen duruyor:
  `global → global` ve `dealer → dealer` reddedilir.
- **İlk yazdığım hâl fazla katıydı** ve **istenmemiş bir daraltma** getiriyordu:
  şart her hedefe uygulanınca `Single → Single` de kapanıyordu (tenant yöneticisinin
  kendi agent'ıyla çalışması — **eskiden serbestti**). Bunu `UserAdminEndpointTests`
  kırmızısı gösterdi; şart yalnızca **kapsamlı** hedefe uygulanacak şekilde düzeltildi.
- **Genişlik sıralaması enum'un sayısal değerine yaslanmaz:** `TenantScopeKind` bugün
  tesadüfen genişlik sırasında; enum yeniden sıralanırsa kural **sessizce tersine
  dönerdi**. Sıralama açıkça yazıldı ve teste pinlendi.
- **Tanınmayan kapsam her iki tarafta reddedilir.** İlk hâlim sayısal bir "en geniş"
  (`int.MaxValue`) dönüyordu: hedef tarafında doğru çalışır ama **aktör tarafında
  arka kapı açardı** — tanınmayan kapsamlı bir aktör herkesten geniş sayılıp her şeyi
  taklit edebilirdi. `null` iki yönü birden kapatır.
- **Dokunulan dosyalar:** `src/Pbxtr.Domain/Platform/Identity/ImpersonationRules.cs`,
  `src/Pbxtr.Api/Platform/Identity/ImpersonationEndpoints.cs`,
  `src/Pbxtr.Api/Modules/Access/UserAdminEndpoints.cs`

### 14. Çapraz-tenant okumanın **ilk çağıranı** yazıldı

- **Neden:** Bir bayinin kullanıcıları **tek tenant'ta durmaz**. RLS:
  `home_tenant_id = app_current_tenant() OR app_is_cross_tenant()`.
- **Bulgu:** Sunucudaki `X-Cross-Tenant` mekanizması vardı ama **hiç çağıranı yoktu**
  (kod var, koşan yok). RLS'i gevşetmek yerine onun ilk çağıranı yazıldı; her çapraz
  istek **örneklemesiz** denetlenir.
- **Ölçüldü:** başlık olmadan liste **0 satır**, bürünme **403** — yani başlık
  gerçekten iş yapıyor, süs değil.
- **`?dealerId=` kendi kapısına bağlandı** (`dealer.read`, #61 ekranıyla aynı).
  Kapısız bırakılsaydı `user.read` taşıyan her rol `dealerId`'yi değiştirip dönen
  sayıya bakarak bir bayi kimliğini **tarayabilirdi**. Boş GUID **400**'dür,
  sessizce "filtre yok"a düşmez.
- **İstemci yüzeyi bekçiye bağlandı:** `crossTenant` için ayrı bir izinli-dosya
  listesi eklendi ve `targetTenantId` listesinden **dar** olması ayrıca ölçülüyor —
  daraltmayı **kaldıran** seçenek, taşıyandan daha geniş bir yüzeye yayılamaz.

### 15. **Çapraz okumada roller boş geliyordu** (gerçek kusur)

- **Ölçüm (canlı):** kendi tenant'ında `["dealer"]`, çapraz okumada `[]`.
- **Sebep:** `users` global bir tablodur ve EF query filter **taşımaz** (daraltması
  `ScopedUsers()` + RLS); ama `user_roles` ve `extensions` `ITenantOwned`'dır ve
  global filtre onları aktif tenant'a daraltır. Ana sorgu çapraz okurken yan
  sorgular okumuyordu.
- **Neden tehlikeli:** Ekran "bu kullanıcının rolü yok" der. **"Rol yok" ile "rol
  okunamadı" aynı görüntüyü verir** ve yetki denetimi için açılan bir ekran, tam da
  ölçmek istediğin şeyi boş gösterir.
- **Ne yapıldı:** Yan sorgular ana sorguyla hizalandı. **Muafiyet koşulludur**
  (`IsCrossTenantRead`): koşulsuz olsaydı sıradan tenant okumalarında da uygulama
  katmanı daraltması kalkar ve CLAUDE.md §4'ün iki katmanlı izolasyonu tek katmana
  inerdi. `IgnoreQueryFilters` allowlist'ine gerekçesiyle yazıldı (bekçi ayrıca
  gerekçenin **kaynakta** da yazılı olmasını istiyor).

### 16. **Rota durumu beyaz listesi** (gerçek kusur, tarayıcıda yakalandı)

- **Belirti:** Drill-in çalışmıyordu — ekran platform tenant'ının kullanıcılarını
  gösteriyordu. `history.state` tarayıcıda **doğru görünüyordu**.
- **Sebep:** `NavigationState` bir arayüzdür ama `currentState()` ondan **beyaz liste**
  ile okur. `dealerId` arayüze eklendi, `navigate` yazdı, ama beyaz listeye
  eklenmediği için ekran onu **hiç görmedi**.
- **Neden sinsi:** Hata yok, kırmızı yok. Yalnızca **yanlış ama makul görünen** bir
  liste. TypeScript de yardım etmez: fazladan bir alanı okumamak tip hatası değildir.
- **İkinci kusur aynı değişiklikte:** `statesEqual` `dealerId`'yi karşılaştırmıyordu,
  dolayısıyla aynı rotada bir bayiden diğerine geçmek "state eşit" sayılıp **hiç
  yönlendirme yapmıyordu**. `tenantId` için bu tuzağa bir kez düşülmüş ve kodda notu
  bırakılmıştı; ikinci kez düşüldü.
- **Ne yapıldı:** İkisi de kapatıldı ve boşluğu ölçen `history.test.ts` yazıldı.
  Testler alan alan değil **tur (round-trip)** ölçer: yazılan her alan geri
  okunabilmeli. İki mutasyon da yakalanıyor.

### 17. Bayi görünümünde yazma kapalı (bilinçli)

- `users_tenant_isolation`'ın `WITH CHECK` dalı `home_tenant_id = app_current_tenant()`
  der; başka bir tenant'ın kullanıcısına yazmak **zaten** reddedilir. Alanları açık
  bırakmak, çalışmayacağı kesin olan bir formu teklif etmek olurdu.
- **Bürünme açık kalır** — istenen odur. Düzenleme, o kullanıcı olarak çalışırken ya da
  doğru tenant'ın kendi listesinden yapılır.

**Ölçüldü:** Api **3847/3847** (4 shard), Architecture **337/337**, web **1314/1314**,
`tsc -b` temiz. Yeni kapıların hepsi mutasyonla **iki yönde** doğrulandı.
## Açık kalanlar / sonraki adım

- **`switchTenant` mekanizmasının artık hiçbir çağıranı yok.** Kod
  `SessionProvider`'da duruyor; bekçi onu yakalamaz (zaten izinli). Silmek ayrı bir
  iştir ve `stopImpersonation` ile aynı kimlik yenileme yolunu paylaştığı için
  dikkat ister. **Açık borç olarak yazıldı.**
- **`b0e41b70`'ten beri pbxtr.com'a yayın yapılmadı.** `88d6a046`, `b640077d`,
  `740984ee`, `9b0b078b`, `019bcc8c`, `512d5867`, `20b11667`, `b6fac60d` yalnızca depoda.
  Yayın için kullanıcının "çık" demesi bekleniyor.
- Bayi hâlâ kullanıcı yönetemiyor: `role.write` var, `user.read`/`user.write` yok.
- Bayi gelen kutusu (#56.1) kapalı talebe cevap yazmayı hâlâ engelliyor; platform
  kutusuna eklenen durum ucunun karşılığı orada yok.
- `doc/prototip-urun-farklari.md`'de #62 ve #63 kaydı yok, #56.1 kaydı bayat.
- `/goal`'un 1, 2, 6, 8, 9. maddeleri açık (Asterisk yönetimi, bayi yönetimi,
  güvenlik duvarı API'leri, hazır Asterisk komutları, süper admin kullanıcı CRUD).
- Gerçek Asterisk'e karşı hâlâ doğrulanmadı (CLAUDE.md §3.0).
- **Seed değişen her commit'te Api takımının TAMAMI koşmalıdır.** `88d6a046` bunu
  atladı ve bir güvenlik kapısını sessizce kırmızıya çevirdi; bir gün sonra bulundu.
- `bundle.telephony.admin` tek kod taşıyor ve adı içeriğini anlatmıyor. Kodu
  değiştirmek rol tanımlarını ve üretilmiş dosyaları etkiler — **açık borç.**
- Bu makinede **python3 yok**; `deploy/yerel-yayin.sh` bunu konteynerle çözüyor ama
  betiğin dışında elle shard koşturulacaksa `deploy/ci/api-test-shards.py` çalışmaz
  (ölçüldü: bayat bir `api.runsettings` sessizce kullanılır ve "shard 0 geçti" yalan
  olur).
- **Bir arayüze alan eklemek yetmez.** `currentState()` beyaz listesi ve `statesEqual`
  elle tutulan iki süzgeçtir; yeni bir `NavigationState` alanı ikisine de yazılmalıdır.
  Artık `history.test.ts` bunu zorluyor.
- Bayi görünümünde **düzenleme yok** (RLS zaten reddederdi). Gerçekten gerekirse ayrı
  bir karar: ya çapraz yazma açılır ya da ekran doğru tenant'a yönlendirir.
