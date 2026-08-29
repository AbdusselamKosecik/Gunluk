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
