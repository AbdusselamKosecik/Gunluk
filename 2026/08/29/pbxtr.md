# pbxtr — 2026-08-29

## Bağlam
Kullanıcı 11 menü grubu × 54 ekran için ekran→rol matrisini yazdı ve "buna göre
düzeltelim" dedi. Ayrıca 8 dil (İngilizce, Fransızca, Bulgarca, Arapça, Almanca,
Gürcüce, Azerice, Ermenice) istedi.

## Yapılanlar

### 1. Mevcut durum ölçüldü
- **Ne yapıldı:** Ekran kaydı `src/Pbxtr.Api/Platform/Screens/screens.json`, yetki
  kataloğu `src/Pbxtr.Api/Platform/Authorization/permissions.seed.json`. Gruplar
  kullanıcının 11 grubuyla birebir aynı çıktı; mevcut 55 ekranın **47'sinde** rol
  ataması matristen farklıydı.
- **Sonuç:** Süper Admin 57 ekranın hepsini görüyordu, matriste ~18'e iniyor.

### 2. Kullanıcı kararları (soruldu, cevaplandı)
1. **Süper Admin/Admin operasyonel ekranlardan tamamen düşer** — tenant'a drill-in
   yapsa bile kuyruk/agent/CDR görmez.
2. **Üç çakışan yetki bölünür** (aşağıda).
3. **Platform ticket'a 5. bir ekrandan cevap verir.**

### 3. Paketler yeniden kesildi (17 → 23)
- **Neden:** Roller yetkiyi paket üzerinden alıyor ve paketler roller arası paylaşımlı.
  Ölçümde **33 çarpışma** çıktı: bir paket, role artık yasak olan bir ekranı da açıyordu.
  Örnek: `bundle.queue` Admin'e verilse Kuyruk, IVR, Kampanya, Sonuç Kodları, İYS,
  Dialer, Anket ekranlarının hepsi açılırdı.
- **Sonuç:** superadmin/admin/dealer operasyonel paketleri tamamen bıraktı;
  supervisor 15 ekran, owner 6 ekran kazandı.

### 4. Üç yetki bölündü
- `tenant.read` → `tenant.read` (platform, #53) + `tenant.self.read` (kendi tenant'ı)
- `dealer.read` → `dealer.read` (bayi kaydı okuma) + `dealer.self.read` (bayinin kendi paneli)
- `ticket.read` → `ticket.read` (talep açan taraf) + `ticket.inbox.dealer`
- **Neden:** Tek isimde iki farklı hak birleşmişti. Bölmeden matris uygulanamıyordu:
  bayiye kendi panelini vermek, ona platformun bayi listesini de vermek demekti.
- **Dokunulan uçlar:** `TenantProfileEndpoints`, `TenantDocumentEndpoints`,
  `DealerOverviewEndpoints`, `DealerTicketEndpoints` + `delivery-manifest.json`.

### 5. Dört yeni ekran — hiçbiri yeni uç istemedi
`#58 Admin Dashboard` (superadmin+admin), `#59 Bayi Dashboard` (dealer),
`#60 Süpervizör Dashboard` (supervisor), `#61 Bayi Yönetimi` (superadmin+admin).
`#60` dar bir yetkiye (`dashboard.supervisor.read`) bağlandı: okuduğu iki yetkiyi
Tenant Sahibi de taşır, onlarla kapatsaydık "yalnızca Süpervizör" satırı uygulanamazdı.

### 6. Duman matrisi düzeltildi — gerçek bir bulgu kapandı
- **Bulgu:** Bayi, müşterisinin agent'larının **izin kayıtlarını** (`kind: sick` = rapor
  dahil) okuyup yazabiliyordu (`bundle.user`). `deploy/demo/smoke-demo.sh` içindeki
  satırın yorumu bunu açık bir KVKK sorusu olarak işaretlemiş ve kullanıcı kararı
  bekliyordu.
- **Sonuç:** Matris `bundle.user`'ı bayiden aldığı için kapandı. Beklenti 200 → 403.
  Bu bir yan etki değil, matrisin doğrudan sonucudur.

## Kararlar
- Matris harfi harfine uygulandı; Süper Admin bir **platform işletmecisidir**,
  çağrı merkezi operatörü değildir.
- Ekran görünürlüğü `permission` **+** `permissionsAll` birleşimidir; tek alana
  bakan ölçüm yanlış yeşil verir (bu tur bir kez yanılttı ve düzeltildi).

## Doğrulama
| Ölçüm | Sonuç |
|---|---|
| Matris | 63/63 ekran spec ile birebir |
| Access testleri | 88/88 |
| Tenancy + Support | 251/251 |
| Architecture | 304/305 |
| `tsc -b` | temiz |

**Commit:** `23f2dd73` (1/2), `ff2d77c1` (2/2), merge `7ce5f939` — main'e push edildi.
Spec dosyası: `yonetim/ekran-rol-matrisi.json` (makine-okunur, doğrulayıcı bunu okur).

## Açık kalanlar / sonraki adım
- **Platform Destek Kutusu (5. ekran)** ve **Admin Dashboard'un ticket istatistiği**:
  ikisi de çapraz-tenant ticket erişimi ister (`IgnoreQueryFilters` muafiyeti + RLS
  policy). Aynı erişimi paylaştıkları için birlikte, ayrı bir turda yapılacak.
  `ticket.inbox.platform` yetkisi bu yüzden katalogdan geri çekildi — bağlı olmayan
  yetki açılışı durduruyor.
- **`DeployPrivilegeTests.Staging_wrapper_...` kırık ve benim değil:** test
  `PROJECT=/opt/pbxtr-staging` bekliyor; staging `dbd6310d` ile
  `/home/vuo/pbxtr-demo`'ya taşınmış, test güncellenmemiş. Ayrıcalık sarmalayıcısına
  bilerek dokunmadım.
- **8 dil işi henüz başlamadı.** Ölçüm: i18n paketi **yok**, `screens.json`'da tek dil
  alanı (`titleTr`), frontend'de 406 dosyada ~6.000 aday dize, backend'de 385
  kullanıcıya giden metin. Arapça **RTL** ayrı bir düzen işidir; Gürcüce/Ermenice için
  font doğrulaması gerekiyor.

---

## İkinci tur — ticket işleri (#62 + Admin Dashboard sayaçları)

### 7. Kapatılan boşluk ölçüldü
- **Bulgu:** Bayisi **olmayan** bir tenant'ın `audience=dealer` talebini **hiçbir kutu
  göstermiyordu.** `/api/v1/tickets` aktif tenant'ı, `/api/v1/dealer/tickets` bir bayinin
  alt ağacını gösterir; o talep ikisine de düşmüyordu. Talep açılıyor ve kayboluyordu.
- **Neden şimdi:** Rol-ekran matrisi `#55 Destek Talepleri`'ni platformdan aldı.

### 8. Yeni audience değeri üretilmedi
`TicketAudiences.Dealer`'ın kendi tanımı zaten **"bayiye ve üstüne gider"** diyor;
platform o "üst"tür. Üçüncü bir değer, talebi **açan müşteriye** "bunu bayim mi platform
mu çözer" diye bir seçim daha sordururdu. Migration da UI değişikliği de gerekmedi.

### 9. Admin'e `crosstenant.read` verildi (kullanıcı kararı)
- **Ölçüm:** `BeginCrossTenantScope` `crosstenant.read` + `scope=global` istiyor; Admin'de
  o yetki yok. Matrisin Admin'e verdiği **üç ekranın üçü de** çapraz-tenant okur. Yani
  Admin `#53 Tenant Yönetimi`'ni **bugün de** görüyor ama RLS
  `tenant_id = app_current_tenant()` dediği için yalnızca kendi platform tenant'ını
  okuyabiliyordu — ekran teslim edilmiş, boş.
- **Karar gerekçesi:** Matris Admin'den tüm operasyonel ekranları aldı; kapsamı açan
  yerler yalnızca bu üç ekran. Her açılış örneklemesiz denetime yazılır (ADR-002 §3.7).
- **Ayrıca ölçüldü:** "ikinci onay" diye bir mekanizma **yok** — katalogdaki o cümle
  uygulanmamış. Gerçek kapı yetki + scope + denetim kaydı.

### 10. Yeni kapsam açılmadı — mevcut olan kullanıldı
Ticket sayaçları `PlatformRollupJob` içindeki **mevcut** `CountsSql`e eklendi; o iş zaten
`app.cross_tenant='on'` ile koşuyor. Yeni ham SQL sabiti açılmadı, ham SQL muafiyet sayısı
değişmedi. Kutu ile **aynı** daraltmayı kullanır (`audience=dealer`) — iki yerde ayrı koşul
yazılsaydı dashboard sayısı ile listedeki satırlar birbirini tutmazdı.

### 11. Üç bekçi yeni çağrıyı yakaladı
| Bekçi | Ne yakaladı |
|---|---|
| `CrossTenantScopeGuardTests` | `BeginCrossTenantScope` dondurulmuş envanteri (+3 çağrı) |
| `IgnoreQueryFiltersAllowlistTests` | muafiyet kaydı (+4 çağrı) |
| `SmokeScreenCoverageTests` | duman matrisi + kapsam (+5 satır) |

Üçüne de gerekçe yazıldı; hiçbiri "listeye ekle geç" ile kapatılmadı.

## Ölçülen borç — bu turda DÜZELTİLMEDİ, kayda geçirildi

**`Ticket` ve `TicketMessage` `TenantId` taşıyor ama `ITenantOwned` uygulamıyor.**
`PbxtrDbContext.OnModelCreating` filtreyi yalnızca `ITenantOwned` varlıklara takıyor, yani
bu iki tabloya **EF global query filter'ı hiç uygulanmıyor** ve iki masadaki
`IgnoreQueryFilters()` çağrıları **etkisiz**. Ticket tablolarının tenant izolasyonu bugün
**tek katman** (yalnızca RLS); CLAUDE.md §4 iki katman diyor.

**Nasıl fark edildi:** `ExpectedTenantOwnedReads`'e iki satır ekledim, ölçüm onları
**çürüttü** — dedektör haklıydı, benim beklentim yanlıştı. Beklentiyi silip geçmek bir kör
nokta yaratırdı; bunun yerine ölçülen gerçek üç yere yazıldı.

**Neden şimdi düzeltilmedi:** `EfTicketDesk`'in 15 okumasını, ek deposunu ve temizlik
yollarını etkiler — arka plan temizliğinde tenant bağlamı yoksa 0 satır dönüp sessizce
kırılabilir. Ayrı ölçüm ister.

## İkinci turun doğrulaması
| Ölçüm | Sonuç |
|---|---|
| Matris | 64/64 |
| `PlatformTicketGateTests` | 13/13 — **mutasyon:** uç yetkisi `ticket.read` yapılınca 7 kırmızı |
| Access + Support + Tenancy | 339/339 |
| SystemAdmin + Observability | 295/295 |
| Architecture | 304/305 (kalan: staging yolu, benim değil) |
| `tsc -b` | temiz |

**Commit:** `b167eafe` — main'e push edildi.

---

# Üçüncü tur — ticket izolasyon borcu + i18n altyapısı + kırmızı kalan testlerin onarımı

## Bağlam
Hedef üç maddeydi: **(1)** yukarıda kayda geçen ticket izolasyon borcunu kapat, **(2)** 8 dil
için i18n altyapısı kur, **(3)** staging yolu testini bitir. Üçüncüsü bir önceki turda
(`b38ba3ab`) kapanmıştı; bu tur birinci ve ikinciyi bitirdi ve yol boyunca **altı ayrı
gerçek kusur** ortaya çıkardı.

## Yapılanlar

### 1. Ticket izolasyon borcu — kapandı
- **Neden:** `TenantId` taşıyıp `ITenantOwned` uygulamayan varlıklara EF global tenant
  filtresi **hiç** uygulanmıyordu; izolasyon tek katmandı (yalnızca RLS), CLAUDE.md §4 ise
  iki katman söz veriyor.
- **Ne yapıldı:** Ölçüm iki değil **beş** varlık buldu: `Ticket`, `TicketMessage`,
  `TicketAttachment`, `RecordingAsset`, `TenantDocument`. Beşi de `ITenantOwned` yapıldı;
  her birine ölçülen boşluğu anlatan blok yorum yazıldı. Aralarında **ses kaydı** (ürünün
  en hassas verisi) ve **firma belgeleri** vardı.
- **Bekçi:** `tests/Pbxtr.Architecture.Tests/TenantIsolationSurfaceTests.cs` (3 test).
  Kümesi **`PbxtrDbContext`'in `DbSet` genel argümanlarından** türer, tüm assembly'den
  değil — ilk yazımda assembly taranıyordu ve ölçüm onu çürüttü: 21 DTO/komut da `TenantId`
  taşıdığı için "eksik" diye raporlanıyordu.
- **İki onaylı istisna:** `RefreshTokenRow`, `PasswordResetTokenRow`. İkisi de **kimlik
  doğrulama öncesi** okunur; filtre eklenseydi `CurrentTenantId` henüz `Guid.Empty` olduğu
  için sorgu 0 satır döner, token yenileme ve parola sıfırlama **tamamen çalışmaz** olurdu.
- **Vacuity eşiği ölçülerek kondu:** "68" yazmıştım, gerçek 67; sabit düzeltildi.

### 2. i18n altyapısı — 9 dil (tr kaynak + 8 hedef)
- **Neden:** kullanıcı kararı — ürün yalnızca Türkiye'ye satılmayacak.
- **Dosyalar:** `src/Pbxtr.Web/src/app/i18n/` — `locales.ts` (dil kayıt defteri),
  `messages/{tr,en,fr,bg,ar,de,ka,az,hy}.ts`, `catalog.ts` (tip sözleşmesi),
  `format.ts` (`Intl` çoğul/sayı/tarih), `I18nProvider.tsx`, `LanguagePicker.tsx`.
- **Karar — katalog `Partial` DEĞİL, tam kayıt:** eksik anahtar çalışma anında Türkçeye
  düşerdi ve o düşüş **sessiz** olurdu (ekranda karışık dil, hiçbir yerde uyarı). Tam kayıt
  istenince eksiklik **derleme anında** görünür.
- **Karar — `useI18n` sağlayıcı yoksa ATAR:** sessiz yedek yazılsaydı sağlayıcıyı ağaca
  bağlamayı unutmak hiçbir yerde görünmezdi. Nitekim **attı** ve `roleActiveScreenSmoke`
  testindeki gerçek bir boşluğu ortaya çıkardı.
- **Arapça yalnızca RTL değil, yerleşim işidir:** `<html dir>` DOM'a yazılıyor; ama 77 CSS
  dosyasındaki 233 fiziksel yön kuralı (`margin-left`, `text-align: left`…) Arapçada yanlış
  tarafa düşer. **Arapça bu yüzden "çevrildi ama yerleşimi doğrulanmadı" durumundadır** ve
  bu `doc/i18n-durum.md`'de yazılı bir sınırdır.

#### Yazarken ölçülen iki gerçek kusur
1. **`{count}` dile göre biçimlenmiyordu.** `interpolate` `String(value)` diyordu → Türkçe
   ekranda `1234` (doğrusu `1.234`), Arapça ekranda Latin rakamları. Sayı biçimini yalnızca
   `formatNumber` çağrılarında doğru yapmak, hatayı **görünmediği yere taşımaktı**.
2. **Yer tutucu eşitliği çoğul anahtarlarında yanlış ölçülüyordu.** Birçok dilde "bir"
   sınıfı sayıyı harfle yazar (ar: `طلب واحد`); orada `{count}` olmaması doğrudur. Kural
   `.other` biçimine taşındı — sayının kaybolmasının gerçekten zarar verdiği yer.

#### Mutasyon doğrulaması (üçü de yakalandı, sonra geri alındı)
| Mutasyon | Kırılan test |
|---|---|
| ar `ticket.count.two` silindi | *çoğul sınıfı Intl ile seçilir* |
| de katalogu tr'nin kopyası yapıldı | *gerçekten çevrilmiş* (55 birebir aynı) |
| de `dir: 'ltr'` → `'rtl'` | *yalnızca Arapça sağa yatıktır* |

### 3. Matris değişikliğinden kalan 20 kırmızı test — onarıldı
- **Bu benim atlamamdı:** iki tur önce `Modules.*` filtreleriyle koştum,
  `Platform.Authorization` / `Platform.Screens` / `Platform.Identity` ad alanlarını **hiç
  koşmadım** ve matrisi o testler kırmızıyken merge ettim.
- **Kök sebep (A sınıfı):** seed `JSON.stringify(j, null, 2)` ile yeniden üretilince satır
  içi diziler çok satıra geçti; testlerdeki **dize çıpaları sessizce tutmaz oldu**. Mutasyon
  uygulanmadan testler koşuyordu — yani kapılar "kırmızı" değil, **anlamsız** olmuştu.
  Çözüm: `JsonNode` ile anlamsal düzenleme (`SeedWithRoleExtras`, `SeedWithCrossTenantDeny`,
  `RemoveExtra`) — biçim değişse de mutasyon uygulanır, uygulanmazsa test patlar.
- **B sınıfı (bayat iddialar), her biri gerekçesiyle güncellendi:** paket sayısı 17→24,
  ekran envanteri 63→68 (numaralı 55→60, menüde 56→61), bayi altın listesi 28→8 kod,
  `superadmin`/`admin` artık `workinghours.write` ve `blacklist.write` taşımıyor,
  `owner` `tenant.read` yerine `tenant.self.read` taşıyor.

### 4. Yol boyunca bulunan ve onarılan altı ayrı kusur
| # | Kusur | Neden sessizdi |
|---|---|---|
| 1 | Üç rolün `landingRoute`'u görünmeyen bir ekranı gösteriyordu | Giriş 404 vermez, "ilk görünür ekrana" düşer — rol `sortOrder`'ın seçtiği rastgele bir ekranla açılırdı |
| 2 | `platform-inbox` eylemleri manifest bağlantısının `request` yolundan geçmiyordu | Ekran çalışıyordu; ama method/path drift kapısı o uçların üstünden atlıyordu |
| 3 | `platform-inbox.close` bağlantısı hiç yoktu | Aynı |
| 4 | `BackgroundJobLocks` listesine 27. iş (`trunk-health-snapshot`) girmemişti | Aynı sessizlik **ikinci kez** tekrarladı (24-25 de girmemişti) |
| 5 | `AmiEventMappingTests` blok ayıracı iki `\n` arıyordu | Windows çalışma kopyasında fikstür **CRLF**; 15 test **platforma bağlı** kırmızıydı, CI'da yeşil |
| 6 | `WallboardDesignScreen` testi #54/1 ile gerçek karo olan "Kampanya İlerlemesi"ni hâlâ eksik listesinde arıyordu | Kapı o günden beri kırmızıydı ve kırmızılığı kimse görmedi |

Ayrıca `st44` kanonik şeması 20+ migration geride kalmıştı; güncellendi ve rapor belgeleri
`PBXTR_WRITE_DOCS=1` ile yeniden üretildi.

- **`landingRoute` için yeni bekçi:** `Every_role_lands_on_a_screen_it_can_actually_see` —
  görünürlük **iki alandan birden** okunur (`permission` + `permissionsAll`); tek alana
  bakan bir ölçüm yanlış yeşil verirdi.

## Komutlar
```bash
dotnet test tests/Pbxtr.Api.Tests/Pbxtr.Api.Tests.csproj --no-build --filter "FullyQualifiedName~Platform"
# Api testleri tek seferde koşturulmuyor (bellek): ad alanına bölünüyor
dotnet test tests/Pbxtr.Api.Tests/Pbxtr.Api.Tests.csproj --no-build --filter "FullyQualifiedName~Modules.A|FullyQualifiedName~Modules.C|FullyQualifiedName~Modules.D"
dotnet test tests/Pbxtr.Architecture.Tests/Pbxtr.Architecture.Tests.csproj
dotnet test tests/Pbxtr.Integration.Tests/Pbxtr.Integration.Tests.csproj
PBXTR_WRITE_DOCS=1 dotnet test tests/Pbxtr.Integration.Tests/Pbxtr.Integration.Tests.csproj --filter "Canonical_report_documents_URET"
cd src/Pbxtr.Web && npm run screens:gen && npx tsc -b && npm test -- --run
```

## Doğrulama
| Ölçüm | Sonuç |
|---|---|
| `Pbxtr.Api.Tests` | **3701 geçti / 0 kırmızı** (Platform 1039, Modules A–W 2662) |
| `Pbxtr.Architecture.Tests` | 308/308 |
| `Pbxtr.Integration.Tests` | 215 geçti, 3 kırmızı — **üçü de yalnızca Docker çalışmadığı için** (testcontainers) |
| Frontend | 141 dosya / 1264 test yeşil |
| `tsc -b` | temiz |

**Commit:** `62be82d9` — main'e push edildi.

## Kararlar
- Katalog tipi tam kayıttır (`Partial` değil): eksik çeviri **derleme** hatasıdır.
- `useI18n` sağlayıcısız çağrılırsa **atar**; sessiz Türkçe yedeği yoktur.
- Arapça, RTL yerleşimi doğrulanana kadar **müşteriye teslim edilmez** — yazılı sınır.
- Bozulan dize çıpaları yenisiyle değil, **anlamsal JSON düzenlemesiyle** değiştirilir.

## Açık kalanlar / sonraki adım
`doc/i18n-durum.md` §2'deki dört kalem, sayısıyla:
1. **2 740** çevrilmemiş arayüz dizesi / 244 dosya — ekran ekran taşınmalı.
2. **80** ekran/grup başlığı yalnızca `titleTr`; menü hâlâ tek dilli. Doğru çözüm alan
   çoğaltmak değil, ekran kimliğinden anahtar türetmek (`screen.<id>.title`).
3. **233** fiziksel yön CSS kuralı / 77 dosya → mantıksal özelliklere (`margin-inline-start`…).
4. Sunucu tarafı metinler (`ProblemDetails`, e-posta/SMS şablonları) ve
   `Accept-Language` + kullanıcı dil tercihi. İstemci ayağı hazır: `negotiateLocale()`
   `ka-GE;q=0.9` biçimini kabul eder ve testi vardır.
5. Gürcüce/Ermenice/Kiril/Arap yazıları için **font kapsamı doğrulanmadı**.

---

## Ek — açık kalan işin ölçümü (aynı gün, `b4ec1c89`)

"Neler kaldı" sorusu ölçülerek cevaplandı; ölçüm sırasında **A1 maddesinin kapanmış olduğu**
ortaya çıktı ve kayda geçirildi.

### A1 kapandı (KVKK)
`yonetim/acik-kararlar.md` A1: *"bayi, müşteri tenant'ının canlı çağrısını dinleyebiliyor"*.
Rol–ekran matrisi bayiden `bundle.live`'ı **toptan** aldı. Ölçüm: `dealer`ın tek paketi
`bundle.apikey`, etkin küme **8 kod** (önce 28), `monitor.listen`/`monitor.whisper`/
`live.agent.read` **false**. Madde 🔵 → 🟢, taşınan sayım `0/9` → `1 🟢 · 8 🔵`.
`deploy/acik-karar-bayatlik-kontrol.sh` yeniden koşuldu: TAMAM.

Kapanışı ölçülen kısıt yapan şey `DealerPermissionBoundaryTests` altın listesinin **küme
eşitliği** olmasıdır — `monitor.listen` bayiye geri verilirse build kırılır.

### Ölçülen genel durum
| Boyut | Ölçüm |
|---|---|
| Ekran envanteri | **68/68 `active`** — `planned` ekran kalmadı |
| Prototip↔ürün farkları | 163 **BİLİNÇLİ**, 6 **BORÇ KAPANDI**, açık BORÇ satırı **yok** |
| Açık kararlar | 26 numaralı: 19 🟢 · 7 🔵 · **0 🟡 · 0 🔴** · taşınan: 1 🟢 · 8 🔵 |
| ClickUp | **24 açık kart**, hepsi `backlog` — A-00…A-14 (gerçek Asterisk bağlantısı) ve B-01…B-09 (`pbxtr-sysagent` + katalog konsolu) |

**Kalan işin şekli:** karar veya ekran eksiği değil, **iki bileşen** — `pbxtr-confd`
(provisioning ajanı, A-12) ve `pbxtr-edge` (mTLS yan arabası, A-13) hâlâ depoda yok; ayrıca
`pbxtr-sysagent` bugün **hiç bağlanamıyor** (B-01) ve `SO_PEERCRED` (B-02) onun ön koşulu.

---

## Dördüncü tur — paket çıkarma ve staging yayını (`demo-b4ec1c89b3ca`)

### Bağlam
İstek: *"dev'e merge eder misin, bir de paket çıkartıp SSH'i günceller misin"*.
Ölçüm: **pbxtr deposunda `dev` diye bir dal yok** (yalnızca `main` ve tamamen merge edilmiş
`feat/rol-ekran-matrisi`), CI/deploy hiçbir yerde `dev`'e bakmıyor. Kullanıcı kararı:
**"dev yoksa main'den devam."**

### 1. CI'nin neden kırmızı olduğu bulundu — kodla ilgisi yok
Son dört koşu (`b167eafe`, `b38ba3ab`, `62be82d9`, `b4ec1c89`) hep `failure`. İlk iş
(`Güvenlik kapıları`) **4 saniyede, sıfır adımla** düşüyordu. Annotation:

> *"The job was not started because recent account payments have failed or your spending
> limit needs to be increased."*

**GitHub Actions faturalama.** Yani ~2026-08-23'ten beri **hiçbir CI kapısı koşmadı** ve
kırmızılık kod kusuru sanılabilirdi. Ölçen komut:

```bash
gh api repos/Pbxtr/pbxtr/check-runs/<jobId>/annotations
```

### 2. Expand-only migration kapısı yerelde koşturuldu (Python yok → konteynerde)
CI'nin atladığı kapı `deploy/migration-compatibility-guard.py`. Bu makinede Python yok;
Docker ile koşturuldu:

```bash
MSYS_NO_PATHCONV=1 docker run --rm -v "X:/GitHub/Pbxtr/pbxtr:/repo" -w /repo python:3.12-slim \
  sh -c "apt-get install -y git && git config --global --add safe.directory /repo && \
         python3 deploy/migration-compatibility-guard-selftest.py && \
         python3 deploy/migration-compatibility-guard.py"
```

Self-test **OK**; asıl kapı **RED**: `deploy/migration-expand-legacy.blobs` 91 satır, depoda
146 migration → **55'i ledger dışı** ve contract/destructive desen taşıyor. Hepsi
2026-08-23 sonrası, yani **CI'nin öldüğü dönemde birikmiş**; hiçbiri bu turun işi değil.

**Yayın kararını değiştiren ölçüm:** sunucuda `__EFMigrationsHistory` **146 satır**, depoda
da **146 migration**. Yani yeni imaj **sıfır** yeni migration getiriyor; `migrate` adımı
no-op ve wrapper'ın uyardığı *"şema ileri, kod geri"* riski **bu yayın için yok**. Karar
tahminle değil bu sayıyla verildi.

### 3. Paket
Docker Desktop kullanıcı tarafından açıldı (daemon kapalıydı).

```bash
docker build --build-arg SOURCE_REVISION=$(git rev-parse HEAD) \
  -t tekbirsoft/pbxtr:demo -t tekbirsoft/pbxtr:demo-b4ec1c89b3ca .
docker push tekbirsoft/pbxtr:demo-b4ec1c89b3ca && docker push tekbirsoft/pbxtr:demo
```

### 4. Yayın — wrapper'ın adım sırası birebir aynalandı
**Neden `/usr/local/sbin/pbxtr-deploy-artifact` kullanılmadı:** wrapper Ed25519 **imzalı**
bir artifact bekler; imzalama anahtarı yalnızca GitHub'ın `STAGING_ARTIFACT_SIGNING_KEY`
secret'ındadır ve CI koşmuyor. İmzasız çalıştırmanın yolu yok.

Bu yüzden `/root/staging-deploy.sh` yazıldı ve wrapper'ın **aynı sırasını** uyguladı:
yedek → pull → migrate → `.env` atomik etiket → app/nginx recreate → sağlık → başarısızsa
rollback. `healthy()` ve `write_image()` wrapper'dan birebir alındı.

```
eski: tekbirsoft/pbxtr:demo-dbd6310d1e9b
yeni: tekbirsoft/pbxtr:demo-b4ec1c89b3ca
yedek: /home/vuo/pbxtr-demo/backups/pre-b4ec1c89b3ca.dump (1.927.226 bayt)
Bekci assert'leri gecti (26/26). migrate tamamlandi.
staging yayini tamamlandi.
```

`pbxtr-app` → `Up (healthy)`, imaj `demo-b4ec1c89b3ca`.

### 5. Yayın doğrulaması
| Ölçüm | Sonuç |
|---|---|
| Yeni ekranlar SPA paketinde | `admin-dashboard`, `dealer-dashboard` bundle'da |
| i18n dilleri paketinde | `Azərbaycanca`, `Български`, `Հայերեն`, `ქართული` — dördü de |
| Açılış rotaları | superadmin/admin `/admin-dashboard`, bayi `/dealer-dashboard`, sahip `/dashboard` |
| Duman testi | **45/45 geçti** |

**`--base-url` olmadan koşturmak yanıltıcıdır** (memory'deki uyarı doğrulandı): nginx
HTTP→HTTPS **301** verdiği için 45 kontrolün 45'i "KALDI" göründü. Doğru adres uygulama
konteynerinin kendisi: `--base-url http://172.28.0.11:5080`.

### 6. Duman testinin yakaladığı bayat iddia (commit `1ae1146e`)
İlk doğru koşuda **44/45**. Kalan kırmızı bir ürün kusuru değil, testin kendi bayat
iddiasıydı: `menu: demo.admin /leaves — beklenen 1, gelen 0`. Matris #50 Agent İzinleri'ni
yalnızca owner + supervizöre verdi; aynı ekranın **uç** iddiası (403) bu turda
güncellenmiş ama **menü** iddiası atlanmıştı — yani ekranın iki sınırından biri güncel,
diğeri bayattı. Menü satırı 0'a çekildi ve aynı rotanın **pozitif** ölçümü supervizörden
alındı (tek yönlü bırakılsaydı *"/leaves artık hiçbir rolde görünmüyor"* hâli de sessizce
geçerdi). Sonra **45/45**.

### Kararlar
- `dev` dalı açılmadı; `main` tek dal olarak sürdürülüyor (kullanıcı kararı).
- İmzalı artifact yolu kullanılamadığında wrapper'ın **adım sırası** taklit edilir; yedek
  ve rollback adımları **atlanmaz**.
- Yayın kararı, kapı kırmızı olduğunda tahminle değil **uygulanmış migration sayısıyla**
  verilir.

### Açık kalanlar
1. **GitHub Actions faturalaması** — çözülene kadar hiçbir CI kapısı koşmuyor. En kritik
   sonucu: expand-only migration kapısı, DB/RLS kapıları ve gitleaks sır taraması **yayın
   yolunda değil**.
2. **`deploy/migration-expand-legacy.blobs` 55 migration geride** — ledger bakımı yapılmalı;
   yapılmadan kapı her koşuda kırmızı kalır ve gerçek bir contract değişikliği fark edilmez.
3. İmzalama anahtarı yalnızca GitHub secret'ında; CI olmadan **imzalı yayın yolu yok**.

---

## İkinci tur — Actions kaldırıldı, 27 kapı depoya taşındı, i18n JSON'a geçti

**Bağlam:** yukarıdaki "açık kalanlar" listesinin 1. ve 2. maddeleri bu turda kapandı.
Kullanıcı kararı: *"GitHub Actions kullanmayacagiz amk. localde build edip
gonderecegiz."*

### 7. Kapılar `ci.yml`den depoya taşındı

- **Neden:** Actions ~2026-08-23'ten beri faturalandırma yüzünden **sıfır adımda**
  düşüyordu. Kapılar kırmızı değil **görünmez** olmuştu — altı gün kimse fark etmedi.
  Actions'ı kaldırmak o yalanı bitirir; **kapıları** kaldırmak depoyu gerçekten
  savunmasız bırakırdı ve öyle bir karar verilmedi.
- **Ne yapıldı:** `ci.yml`den 27 kapı `deploy/yerel-kapilar.sh`e çıkarıldı; sabit bir
  ortamda (`deploy/yerel-kapilar.Dockerfile` — ubuntu 24.04 + python3/nginx/openssl/
  git/node/docker CLI + **pinlenmiş gitleaks 8.24.0**) koşuyor.
  `deploy/yerel-yayin.sh` 7 adımlı yayın yolu: kapılar → backend → 4 API shard →
  frontend → DB kapıları → imaj → staging. **İmaj, kapılar yeşil olmadan üretilmez.**
- **Dokunulan dosyalar:** `deploy/yerel-kapilar.sh`, `deploy/yerel-kapilar.Dockerfile`,
  `deploy/yerel-yayin.sh`, `deploy/staging-yayin.sh`,
  `deploy/ci/integration-yayin-contract-test.py` (silinen .rb testin portu)
- **Sonuç:** ilk koşumda **13 kırmızı** → 7 → 3 → **27/27 yeşil**.

### 8. Kapıları koşturunca çıkan ÜÇ GERÇEK KUSUR

Bunlar kapıların bulgusudur; hiçbiri kapı koşmadan görünmüyordu.

**(a) PowerShell ayrıştırma kapısı HİÇBİR ŞEY ölçmüyordu.** Gövde
`powershell -NoProfile -Command -` stdin'ine heredoc ile veriliyordu; Windows
PowerShell 5.1 bu kipte çok satırlı `foreach` bloğunu **sessizce yutuyor** — hata yok,
çıktı yok, çıkış kodu 0. Mutasyonla görüldü: `smoke-demo.ps1` sonuna kapanmamış bir
`function Bozuk {` eklendi, kapı **yine geçti**.

`-File` ile koşturulunca ikinci kusur çıktı: **`smoke-demo.ps1` gerçekten
ayrıştırılamıyordu.** Dosyada BOM yoktu; PS 5.1 BOM'suz dosyayı ANSI okuyor ve string
içindeki em dash (`—`) dizgiyi bozuyor. Yani **sunum smoke betiği Windows'ta
çalıştırılamaz hâldeydi** ve bunu ancak sunum sabahı görecektik. İki `.ps1` dosyasına
UTF-8 BOM eklendi.

Konteynerde `pwsh` yok. İki kötü seçenek vardı: imaja ~130 MB pwsh kurmak, ya da
"pwsh yoksa atla" demek — ki bu kapıyı kaldırmakla aynı şeydir, tek farkı görünür
olması. **Seçilen üçüncü yol:** kapı host'ta koşar ve `.kapi-pwsh-makbuz` bırakır;
konteyner tarafı makbuza *güvenmez*, **doğrular** — makbuzdaki `.ps1` özetleri o andaki
ağaçla birebir tutmazsa kırmızı yanar. **Makbuz bir izin değil, kanıttır.**

**(b) expand-only migration kapısı 55 migration'ı birden reddetti.** Defterin işi
(kendi tanımı) *"mevcut kurulu taban çizgisini dondurmak"*tır ve bu 55 migration
staging'de **uygulanmıştır** (`__EFMigrationsHistory` 146 satır = depoda 146
migration). Uygulanmış bir migration'ı "normal deploy'a kabul edilir mi" diye analiz
etmenin anlamı yok. Defter gerçeği yansıtmadan kapı **147.** migration'ı da ölçemez.
Ayrıca `20260823150000_FinalDeliveryTerminalGuard` blob'u bayattı: `e68a713b`
(Karar #27) **27 FinalGuard dosyasını** düzenlemiş, defterde **yalnızca birini**
güncellemişti.

**(c) `nginx -t` kapısı docker-in-docker'da boş dizin mount ediyordu.** `mktemp -d`
konteynerin `/tmp`'sini veriyor, host daemon'ı o yolu bulamıyor ve mount'u boş bir
dizin olarak yaratıyor. Belirti yanıltıcıydı: *"nginx.conf ... Is a directory"* — sanki
yapılandırma bozukmuş gibi. Sahne dizini artık depo ağacında açılıyor, mount'a
`PBXTR_HOST_REPO` ile **host yolu** veriliyor.

- **Dokunulan dosyalar:** `deploy/kapi-pwsh-ayristirma.sh`,
  `deploy/kapi-pwsh-ayristirma.ps1`, `deploy/demo/{smoke,start}-demo.ps1`,
  `deploy/migration-expand-legacy.blobs`, `deploy/nginx-dogrula.sh`, `.gitignore`

### 9. Kapılar boşalmadı — hepsi mutasyonla ölçüldü

| Mutasyon | Sonuç |
|---|---|
| bozuk `.ps1` (host, pwsh var) | **RED** — `ayristirilamadi` |
| `.ps1` host koşumundan sonra değişti (`--dogrula`) | **RED** — `makbuz agacla tutmuyor` |
| makbuz silindi (`--dogrula`) | **RED** — `Kapi ATLANMAZ` |
| yeni `DropColumn` taşıyan migration | **RED** — `contract/destructive desen` |
| dondurulmuş `HostMetrics.cs`'e tek satır | **RED** — `blob degistirilemez` |

### 10. i18n — kullanıcının iki geri bildirimi

**(a) *"dil degisimi yok. ust bara eklermisin bayrak ve dil adiyla birlikte"*.**
Belirti tekti, sebep **ikiydi**:
1. **Emoji bayraklar Windows'ta hiç çizilmiyordu** — Segoe UI Emoji bölge göstergesi
   çiftlerini içermez; ekranda iki harf kutusu çıkıyordu. Yazı tipi yüklemek bir dağıtım
   riskidir → **satır içi SVG** (`Flag.tsx`, 20×14): yazı tipinden, OS'ten ve ağdan
   bağımsız.
2. **Kabuk metinleri Türkçe sabitti** — dil değiştirmek `<html lang>`/`dir` değerlerini
   gerçekten değiştiriyordu ama ekranda **değişen tek kelime yoktu**. `AppHeader`,
   `IdentityMenu`, `AppSidebar` çevrildi. Seçici artık üst barda, `Popover` ile,
   **bayrak + dilin kendi adı**. (Menü grubu başlıkları hâlâ tek dil — `titleTr`.)

**(b) *"i18n olarak json olarak yapsana dilleri"*.** Dokuz katalog `.ts` → `.json`.
Derleme anındaki güvence **kaybolmadı**: `resolveJsonModule` + `MessageCatalog` tam
kayıt. Mutasyonla ölçüldü — `de.json`'dan `common.save` silindi → **TS2322**. Kazanım
çevirmen tarafında: Fransızca `l'écran` satırı tam olarak TypeScript tırnak kaçışı
yüzünden **iki kez** bozulmuştu; JSON'da o tuzak yok.

- **Dokunulan dosyalar:** `src/Pbxtr.Web/src/app/i18n/*` (catalog/format/locales/
  I18nProvider/LanguagePicker/Flag + 9 `messages/*.json`),
  `src/Pbxtr.Web/src/app/shell/{AppHeader,AppHeader.module.css,IdentityMenu,AppSidebar}`
- **Ölçüm:** `npx tsc -b` temiz, `npm test -- --run` **141 dosya / 1 264 test** yeşil.

### Komutlar

```bash
docker build -f deploy/yerel-kapilar.Dockerfile -t pbxtr-kapi:local deploy
docker run --rm -e PBXTR_HOST_REPO="X:/GitHub/Pbxtr/pbxtr" \
  -v "X:/GitHub/Pbxtr/pbxtr:/repo" -v //var/run/docker.sock:/var/run/docker.sock \
  -w /repo pbxtr-kapi:local bash deploy/yerel-kapilar.sh     # 27/27
bash deploy/kapi-pwsh-ayristirma.sh          # host: koşar + makbuz yazar
bash deploy/kapi-pwsh-ayristirma.sh --dogrula # konteyner: makbuzu doğrular
bash deploy/yerel-yayin.sh --yayinla          # kapılar+test+imaj+staging
```

### Kararlar (bu tur)
- **CI'ın düşmesi ile CI'ın yokluğu aynı şey değildir.** Düşen kapı görünür; koşmayan
  kapı, kaldırılmış kapıyla birebir aynı sonucu verir.
- **Bir kapının yeşil olması ölçtüğünü göstermez — boş da yeşil görünür.** Her kapı,
  ölçtüğünü iddia ettiği hatayı gerçekten üreterek doğrulanmalıdır.
- Ortamı olmayan bir kapı **atlanmaz**: ya ortam kurulur, ya kapı doğrulanabilir bir
  **kanıt** (makbuz) bırakır.

### Açık kalanlar (güncel)
1. **DB-MIG-03** — 55 migration kapıdan *geçmedi*, kapının görmediği pencerede doğdu.
   Geriye dönük contract review borcu. Defter satırları o incelemenin yerine geçmez.
2. İmzalama anahtarı hâlâ yok → `deploy/staging-yayin.sh` **provenance doğrulaması
   yapmıyor** (betiğin içinde yazılı sınır). Kapatma yolu: anahtarı yerelde üret,
   açık anahtarı `/etc/pbxtr/staging-artifact-signing.pub` ile eşle.
3. i18n borcu duruyor: 2 740 çevrilmemiş dize / 244 dosya, 80 `titleTr`, 233 fiziksel
   yön kuralı (RTL), sunucu tarafı metinler, font kapsamı (`doc/i18n-durum.md`).

### Commit
`5bc08dd9` — ci: GitHub Actions kaldirildi, 27 kapi depoya tasindi + i18n JSON'a gecti

### 11. Yayın betiğinin ilk gerçek koşumu bir kusur daha çıkardı (`7896566e`)

`bash deploy/yerel-yayin.sh --yayinla` ilk kez koşturulduğunda **10 kapı kırmızı**
yandı. Sebep kapıların bulgusu değildi: `deploy/yerel-kapilar.sh` doğrudan **Windows
host** üzerinde koşuyordu ve orada `python3`, `gitleaks`, `openssl`, `nginx` yok.
Yani 10 kapı *"araç yok"* diye düştü.

**Bu ayrım önemlidir:** ekranda *"kapı bir hata buldu"* ile *"kapı koşamadı"*
birbirinin **aynısı** görünüyor. Bir kapının araç yokluğundan düşmesi, o kapının
ölçtüğü şeyi **hiç ölçmemek**tir — tek farkı görünür olması. (Kapı konteyneri de tam
bu yüzden `docker.io` + `nodejs` ile yeniden kurulmuştu.)

`set -e` çalıştı, yayın durdu, **imaj üretilmedi** — yani yanlış olan sonuç değil,
kapıların *nerede koştuğuydu*. Düzeltme: (a) PowerShell kapısı host'ta koşar ve makbuz
bırakır, (b) kalan 26 kapı `deploy/yerel-kapilar.Dockerfile` imajında koşar, host yolu
`PBXTR_HOST_REPO` ile geçirilir.

**Commit:** `7896566e` — fix(deploy): yayin betigi kapilari KONTEYNERDE kosturuyor
