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

## Açık kalanlar / sonraki adım

- **`switchTenant` mekanizmasının artık hiçbir çağıranı yok.** Kod
  `SessionProvider`'da duruyor; bekçi onu yakalamaz (zaten izinli). Silmek ayrı bir
  iştir ve `stopImpersonation` ile aynı kimlik yenileme yolunu paylaştığı için
  dikkat ister. **Açık borç olarak yazıldı.**
- **`b0e41b70`'ten beri pbxtr.com'a yayın yapılmadı.** `88d6a046`, `b640077d`,
  `740984ee`, `9b0b078b`, `019bcc8c`, `512d5867` yalnızca depoda. Yayın için
  kullanıcının "çık" demesi bekleniyor.
- Bayi hâlâ kullanıcı yönetemiyor: `role.write` var, `user.read`/`user.write` yok.
- Bayi gelen kutusu (#56.1) kapalı talebe cevap yazmayı hâlâ engelliyor; platform
  kutusuna eklenen durum ucunun karşılığı orada yok.
- `doc/prototip-urun-farklari.md`'de #62 ve #63 kaydı yok, #56.1 kaydı bayat.
- `/goal`'un 1, 2, 6, 8, 9. maddeleri açık (Asterisk yönetimi, bayi yönetimi,
  güvenlik duvarı API'leri, hazır Asterisk komutları, süper admin kullanıcı CRUD).
- Gerçek Asterisk'e karşı hâlâ doğrulanmadı (CLAUDE.md §3.0).
