# pbxtr — 2026-08-31

## Bağlam

Kullanıcının 9 maddelik `/goal`'ü sürüyor (Super Admin ekranları). Önceki turlarda
#9, #5, #3, #2+#4a, #4b-1 teslim edilmişti. Bu güne kalanlar: **#8** (Asterisk hazır
komutları), **#6** (Güvenlik Duvarı'nda çalışmayan servis API'leri), **#1** (Asterisk
yönetimi tam olsun), **#7** (diğer ekranlarda da aynı), **#4b-2** (impersonation).

Beşi de bu gün kapatıldı.

---

## Yapılanlar

### 1. #8 — Asterisk Konsolu (yeni ekran #63)

- **Neden:** Panelde santralin canlı durumunu **ham hâliyle** gösteren hiçbir yüzey
  yoktu. Ürün ekranları yalnızca ürünün modellediği soruları cevaplıyor (kuyruk
  üyeliği, trunk sağlığı); bir arızada sorulan sorular modellenmemiş: "şu endpoint
  neden Unavail", "kaç registration ayakta", "hangi modül yüklü". Kullanıcı bunu
  FreePBX'teki hazır komutlara benzeterek istedi.
- **Ne yapıldı:** `IAsteriskConsole` portu + AMI `Command` eylemiyle çalışan uygulama.
  12 komutluk **kapalı liste**, hepsi salt-okunur (`show`/`list`).
  - Katalog **derlenen koddadır**, yapılandırma dosyası bile yok — dosya yazma yetkisi
    ele geçiren biri allowlist'i genişletememelidir.
  - **İstemci komut metni göndermez**, yalnızca bir kimlik. Serbest metin kabul eden
    bir uç, `telephony.console.read` yetkisini fiilen `asterisk -rx` yetkisine
    çevirirdi (CLAUDE.md §3.1).
  - **Parametre de serbest değil:** `queue show <queue>` kuyruk adını tenant'ın kendi
    kuyruklarından çözer ve istemcinin gönderdiği dizeyi **üretilen adlarla
    karşılaştırır** — dize hiçbir zaman komuta girmez. Asterisk'te kuyruk adları global
    ad alanındadır ve orada tenant sınırı yoktur; sınır bu yüzden sorgunun kendisinde
    kuruldu.
  - `reload` **dahil** hiçbir durum değiştiren komut yok: reload provisioning yolunun
    işidir ve orada debounce + doğrulama + rollback ile sarılıdır.
- **Maskeleme sızıntısı bulundu ve kapatıldı:** `core show channels` çıktısındaki
  `Location` sütunu `exten@context`'tir — çevrilen numara, yani bir müşteri numarası
  olabilir. Ham CLI çıktısı **maskelenemez** (biçim sürüme göre değişir). Çözüm
  maskeleme değil **yetkilendirme**: AST-01 ayrıca `phone.unmask` ister ve kapı
  katalogla aynı dosyadadır (uçta olsaydı, yeni komut ekleyen kişi ucu güncellemeyi
  unuttuğunda kapı sessizce açılırdı).
- **Dokunulan dosyalar:** `src/Pbxtr.Domain/Modules/Telephony/Runtime/IAsteriskConsole.cs`,
  `src/Pbxtr.Infrastructure/Telephony/Asterisk/{AsteriskCommandCatalog,AmiAsteriskConsole,AmiCommandChannel}.cs`,
  `src/Pbxtr.Api/Modules/Telephony/AsteriskConsoleEndpoints.cs`,
  `src/Pbxtr.Web/src/app/screens/system/AsteriskConsoleScreen.{tsx,module.css,test.tsx}`,
  `asteriskConsoleApi.ts`, `screens.json`, `delivery-manifest.json`,
  `telephony-path-inventory.json`, `permissions.seed.json`, 9 dil dosyası.
- **Sonuç / doğrulama:** Architecture 332/332, Api/Platform 274/274, konsol uçları 7/7,
  Web 1299/1299. Mutasyonlar: katalog satırına `; core restart` → 2 bekçi kırmızı;
  ucun yetkisi `system.command.run` → 7/7 kırmızı; ekranda parametre geçişi silindi →
  kırmızı.
- **Commit:** `263d37ca`

**Bekçiler üç gerçek kusur buldu:**
1. Teslim manifesti şeması: `sourceKind: postgres` (doğrusu `postgresql`),
   `rlsMode: enforced` (doğrusu `standard_tenant`), tablo listesi sıralı değil. Üçü de
   açılışta istisna verdi — yani yanlış manifest üretime çıkamazdı.
2. `operationalClass: high_risk` yazmıştım; doğru sınıf `asterisk_external` ve o sınıf
   telefon yolu envanterinde bir satır **zorunlu** kılıyor (TPI009).
3. Duman kapsamı: yeni active+inMenu ekran, rol-teslim kapısının görmediği bir ekran
   olurdu. 5 rollü matris satırı eklendi.

### 2. #6 — Güvenlik Duvarı: iki gerçek ayrıştırma kusuru

- **Neden:** Kullanıcı "çalışmayan servis apilerini bağla" dedi.
- **Ne yapıldı — ÖNCE ÖLÇÜM:** İşi "ajan kurulmamış, uçları bağlayayım" diye
  planlamıştım. **Canlı sunucuda ölçtüm ve varsayım çürüdü:** `pbxtr-sysagent`
  29 Ağustos'tan beri `active`, compose'a bağlı, ve menüdeki her sistem ekranı gerçek
  veri döndürüyor. Kod yazmadan önce ölçmesem, çalışan bir şeyi "bağlıyorum" diye
  yeniden yazacaktım.
- **Ama ölçüm iki gerçek kusur gösterdi:**
  1. `ufw status numbered` çıktısındaki `Anywhere` hedefi **port sanılıyordu**. O,
     "tüm portlar" demektir. Panel kurulumun **en geniş** kuralını
     (`192.168.31.0/24`'ten her port açık) sıradan bir port satırı gibi çiziyordu.
     Yalnızca `null`'a çevirmek yetmezdi: özet `portSpec` null olanları **eliyordu**,
     yani düzeltmenin tek başına sonucu en geniş kuralın özetten tamamen kaybolması
     olurdu — yanlış bir satırı **eksik** bir satırla değiştirmek.
  2. Adres ailesi eki (`(v6)`) port alanına sızıyordu; özet aynı portu iki kez
     sayıyordu (`"443"` ve `"443 (v6)"`).
- **Fikstür neden gerçek çıktı:** Mevcut fikstür üçü de düzgün bir `ufw` çıktısıydı ve
  iki kusuru da göremiyordu. Yeni test sınıfının fikstürü pbxtr.com'dan alınan çıktının
  **birebir** kendisidir; sadeleştirmek kusuru doğuran biçimi testin dışında bırakmak
  olurdu.
- **fail2ban katmanına dokunulmadı:** `measured: false` kalması bir eksik değil, yazılı
  bir karardır (#35/5) — ban sayısının tek kaynağı #36'nın okuyucusudur.
- **Komutlar:**
  ```bash
  ssh root@176.88.41.220 'ufw status numbered'
  curl -s https://pbxtr.com/api/v1/system/firewall/rules -H "Authorization: Bearer $TOK"
  ```
- **Sonuç:** Architecture 332/332, Firewall 32/32, Web system+i18n 161/161.
  Mutasyonlar: `PortSpec: allPorts ? null : portPart` → `portPart` (1 test kırmızı);
  `(v6)` soyma adımı silindi (2 test kırmızı).
- **Commit:** `f8a519af`

### 3. #1 — Super Admin santral yapılandırmasını yönetebiliyor

- **Neden / ölçüm:** Canlı sunucuda superadmin jetonuyla `GET /api/v1/queues` ve
  `/api/v1/trunks` **403** dönüyordu. Rol-ekran matrisinde superadmin ve admin
  sütunları **yedi ekranda** boştu (#03, #04, #07, #25, #26, #27, #39). Yani "Asterisk
  yönetimi" ekranları vardı ama platform yöneticisi hiçbirini görmüyordu. Eksik olan
  ekran değil, **erişimdi**.
- **Ne yapıldı:** Yeni paket `bundle.telephony.admin` — santral **nesneleri**: queue,
  ivr, extension, ringgroup, trunk, codec, çalışma saatleri, medya, ağ kalitesi
  (15 yetki). superadmin + admin'e verildi.
- **Neden mevcut `bundle.queue` verilmedi:** o paket kampanya, dialer, anket, sonuç
  kodu, kara liste ve İYS de taşır. Bunlar santral yapılandırması değil **operasyon**
  kararlarıdır ve sahibi tenant tarafıdır; vermek, "Asterisk yönetimi" isteğini bahane
  edip platform yöneticisini kiracının kampanya ve izin yönetimine sokmak olurdu.
- **2026-08-29 matrisi geri alınmadı:** diff tam olarak yedi satırda superadmin+admin
  sütunlarına ✓ koydu, başka hiçbir hücre değişmedi.
- **İçerik kilidi:** sayı kilidi (25→26) yeni bir paketi yakalar ama **içeriğini**
  ölçmez; birinin ileride `blacklist.write` eklemesi hiçbir testi kırmazdı. Bu yüzden
  `Telephony_admin_bundle_stays_within_pbx_configuration` 15 yetkiyi birebir sayıyor.
  Duman matrisi de **sınırı** ölçüyor (`/telephony/blacklist` ve `/contacts` → 403).
- **Commit:** `0d009532`

### 4. #4b-2 — Seçilen kullanıcının yetkileriyle çalışma (impersonation)

- **Neden:** "kullanıcı listesinden seçtiğimiz kullanıcı ve rolü ile yetkilenip o
  şekilde işlem yapabilmemiz lazım ki hata varsa o şekilde daha kolay görebilmemiz
  lazım." İstenen şey **yetki yükseltme değil, yetki daraltma**: "bende çalışıyor,
  agentta çalışmıyor" farkını görmenin tek doğru yolu gerçekten o kullanıcının yetki
  kümesiyle istek atmaktır.
- **Dört kapı** (`ImpersonationRules`), dördü de ayrı bir arızayı kapatır:
  1. `user.impersonate` — hiçbir pakette değil, `globalScopeOnly`, yalnızca
     `superadmin.extraPermissions`.
  2. **Kendini taklit edemezsin** — denetimde "X, X olarak çalıştı" ile "X çalıştı"
     ayırt edilemez hale gelirdi ve taklit kaydının tüm anlamı bu ayrımdır.
  3. **Devre dışı hesap** taklit edilemez — edilebilseydi "hesabı kapattım" cümlesi
     yanlış olurdu.
  4. **Kapsamlı hesap** taklit edilemez — superadmin'de `audit.purge` gibi geri
     alınamaz yetkiler var; taklit bir hesabı **devralma** aracı değildir.
- **İstemciye tek bir 403 gider**, sebep ayırt edilmeden: ayırmak, taklit edilemeyen
  hesapların kim olduğunu (platform yöneticilerini) dışarıdan taranabilir kılardı.
  Sebep **denetim günlüğündedir**; reddedilen denemeler de yazılır.
- **Bulunan ve kapatılan sessiz kusur:** yenileme jetonu **aktöre** aittir. Taklit
  sırasında erişim jetonunun süresi dolunca istemci `/auth/refresh` çağırır ve sunucu
  aktörün jetonunu döner — yani **taklit sessizce biter**. Kullanıcı hedefin ekranına
  bakmaya devam ederken istekler kendi geniş yetkisiyle gitmeye başlar; üstelik şerit
  bile açık kalır (şerit `/me`'den gelir). Aracın ölçmek için var olduğu şey (dar
  yetki) tam da ölçüm sırasında kaybolurdu.
  → `doRefresh` taklit sırasında **ağa hiç çıkmaz**; taklidi açıkça bitirir ve aktörün
  **askıdaki** jetonunu geri koyar. `onImpersonationEnded` ayrı bir sinyaldir
  (`onSessionLost` değil — aktörün oturumu hiç düşmedi).
- **Tek üretim yolu:** taklit jetonu `AccessClaims()` üzerinden, gerçek oturumla aynı
  claim üretiminden geçer. Ayrı bir liste yazsaydık biri diğerinden sapınca taklit
  gerçek oturumdan farklı davranırdı — yani araç yanlış bir şeyi ölçerdi.
- **Ömür 30 dk ve yenilenemez.** Yenilenebilir olsaydı taklit süresiz olurdu; bitiş bir
  düğmeye değil **saate** bağlıdır.
- **Bekçiler gerçek kusur buldu:** `AmbientClockGuardTests` kırmızı yandı — ömrü
  `expiresAt - Date.now()` ile türetiyordum (CLAUDE.md §11). Sunucu artık `expiresIn`
  dönüyor, istemci saat okumuyor.
- **Duman matrisinin POST körlüğü kapatıldı:** `status()` yalnızca GET atıyor; POST-only
  bir ucu oradan ölçmek **yanlış yeşil** üretirdi (rota GET'e eşleşmediği için ASP.NET
  yetkiye hiç bakmadan 405 döner). Ayrı bir `YAZMA_MATRISI` eklendi (400 = kapıdan
  geçtim, 403 = kapı kapalı).
- **Sonuç:** Architecture 332/332, Api/Platform 217/217, Web 1306/1306.
  Mutasyonlar: kapsam kapısı ters çevrildi (3 test kırmızı); `suspended ??=` →
  `suspended =` (kırmızı); yenilemedeki taklit kapısı silindi (kırmızı, ve ikinci test
  o kapının **her** yenilemeyi kesmediğini de ölçüyor).
- **Commit:** `d677c439`

### 5. #7 — ölçüldü, düzeltilecek bir şey çıkmadı

- **Ne yapıldı:** Menüde görünen 62 ekranın primary GET uçları canlıda tarandı.
  Superadmin'in yetkisi olan hiçbirinde boş/ölçülmemiş yanıt yok. `switchTenant`
  çağıran tek yer `TenantScreen.tsx:200` (Karar #11/G'nin izin verdiği tek yüzey) —
  yani #5'in "diğer ekranlara yayılması" gereken bir düzeltme değil, **yapısal olarak
  zaten kapalı** bir sınır.
- **Yanlış çıkan bir şüphe kayda geçti:** #37'nin yanlış uca bağlı olduğunu sandım;
  manifest dört ucu birden bağlıyor, tarayıcım ilkini yazıyordu.
- **Dokunulan dosya:** `doc/olcum-2026-08-31-ekran-uclari.md` (yeni)
- **Commit:** `2f7de975`

---

## Kararlar

1. **Asterisk konsolu terminal değildir ve olmayacaktır.** Kullanıcı listeden seçer,
   çalışacak CLI dizesini sunucu çözer. Katalog derlenen koddadır.
2. **Ham CLI çıktısı maskelenmez, yetkilendirilir.** Biçim Asterisk sürümüne göre
   değişir; "maskelediğimizi sandığımız" bir ayrıştırıcı ilk sürüm farkında sessizce
   numara sızdırırdı.
3. **`bundle.telephony.admin` santral nesnelerinde durur.** Operasyon (kampanya,
   dialer, İYS), müşteri verisi ve hukuki zincir yetkileri **dışarıdadır** ve içerik
   kilidiyle donduruldu.
4. **Taklit yalnızca daraltır.** Hedef tek-tenant hesap olmak zorunda; kapsamlı hesap
   taklidi devralma olurdu.
5. **Taklit jetonu yenilenmez.** Bitiş düğmeye değil saate bağlıdır.
6. **#7 için kod yazılmadı ve bu bir sonuçtur, atlama değil** — ölçüm belgeye yazıldı
   ve neyi kanıtlamadığı da yazıldı (tek kullanıcı, tek sunucu).

---

## Açık kalanlar / sonraki adım

- **Bu turun hiçbiri canlıya DAĞITILMADI.** pbxtr.com hâlâ önceki sürümü koşuyor;
  taramada `#63 asterisk-console` uçları 404 dönüyor. Dağıtım kullanıcının kararına
  bırakıldı.
- **Gerçek Asterisk'e karşı doğrulanmadı** (CLAUDE.md §3.0). `#8`'in telefon yolu
  envanteri üç `unverifiedClaims` maddesini açıkça sayıyor: AMI `Command` eyleminin her
  komutta `Output:` döndürdüğü, sürümün komut adlarını tanıdığı, ve bağlantısız durumun
  gerçek bir kopmada da `Connected = false` ürettiği.
- Önceki turlardan devam edenler: `pbxtr-inbound`/`pbxtr-outbound` statik context'leri
  dialplan'de referanslı ama üretilmiyor; `dealer.self.read` `crossTenantDeny`'de yok;
  `doc/st44-final-delivery-canonical.json` bayat; entegrasyon paketi konteyner koşusu
  istiyor; Rusça (`ru`) yerel yok; ~25 sabit `tr-TR` biçimlendirme yeri.
