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
