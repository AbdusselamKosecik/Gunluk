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
