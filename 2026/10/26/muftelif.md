# muftelif — 2026-10-26

## Bağlam
SentezSelvedge'de ölçümün POM listesi Sentez iş emri ekinden (`Erp_WorkOrderAttachment`)
anlık okunuyordu (spec §4.5, 0005). Müşteri bunun yerine eski Selvedge'deki gibi
**ölçü tablosunun model başına Excel ile yüklenmesini** istedi. Hedef: yükleme ekranı +
ölçüm açılırken kaynağın yüklenen tablo olması, mobil APK'yı yeniden çıkarmadan.

## Yapılanlar

### 1. Model ölçü tablosu (Excel yükleme) — şema 0007
- **Neden:** Kaynak Sentez eki değil, yüklenen Excel olacak; tablo bizde tutulmalı.
- **Ne yapıldı:** `UZM_Selvedge_MeasureSpecFile` (SentezInventoryId, FileName, ExcelStyleNo,
  Bedenler [dosya sırasıyla virgüllü], PomSayisi, IsDeleted; `SentezInventoryId WHERE IsDeleted=0`
  tekil filtreli indeks) + `UZM_Selvedge_MeasureSpec` (SpecFileId FK, SortOrder=Excel sıra no,
  PomCode, Description, Tolerance, SizeCode, SpecValue) + `UZM_Selvedge_Measure.MeasureSpecFileId`
  (FK). Anahtar `Erp_Inventory.RecId` (StyleQa ile aynı). Yeniden yükleme eskisini silmez,
  `IsDeleted=1` yapar; açılmış ölçümler satırları zaten kopyaladığı için etkilenmez.
- **Dokunulan dosyalar:** `SentezSelvedge/db/0007_olcu_tablosu.sql`, `api/Db/SemaBeklenen.cs`
  (2 tablo + MeasureSpecFileId kolonu, uygulama komutuna 0007).
- **Sonuç / doğrulama:** LocalDB'de `SvTest0007` (Turkish_CS_AS) açılıp Erp stub tabloları +
  0001..0007 uygulandı; 0007 ikinci kez koşunca da hatasız (idempotent). Test DB sonra silindi.

### 2. API
- **Ne yapıldı:**
  - Yeni `api/Selvedge/Olcum/OlcuTablosuStore.cs` (Dapper, singleton): Getir, Yukle (tek
    transaction: eskiyi kapat → dosya ekle → satırlar → audit), Sil, SiparisTablolari
    (iş emrindeki modellerin geçerli tabloları, `EkOzet` biçiminde), SpecOku.
  - `OlcumController`: `GET/POST/DELETE /api/olcum/tablo/{inventoryId}` (POST multipart `file`,
    yalnız .xlsx/.xlsm — ClosedXML .xls okuyamaz; Excel okunamazsa hiçbir şey yazılmaz;
    "Style:" modelle başından tutmazsa `uyarilar`). `ekler/{isEmri}` artık yüklü tabloları döner.
  - `OlcumStore`: SentezReader yerine OlcuTablosuStore; açarken `MeasureSpecFileId` yazılır,
    `SentezWorkOrderAttachmentId` NULL kalır (eski ölçümlerde dolu).
  - `OlcumSpecExcel`: başlık satırı tespiti (1–10'da "P O M"+beden → o; yoksa 10'da beden → 10;
    yoksa 11–20'de "P O M"). İki bloklu sayfadaki ikinci başlık seçilmez. `SpecSonuc.StyleNo`.
- **Karar:** Mobil uç adları (`ekler`, `spec?ek=`, `attachmentRecId`) **değişmedi**, tablo kimliği
  taşıyor → mobil 2.0.0.3 APK değişmeden çalışır (dosya adı .xlsx/.xlsm ile bittiği için mobilin
  `isSpreadsheet` süzgecinden geçer). Mobilin "Sentez'de Excel eki yok" uyarı metni eski kaldı.

### 3. Web
- **Ne yapıldı:** `web/src/components/OlcuTablosuPaneli.tsx` (Excel yükle / POM×beden tablo /
  temizle), Siparişler penceresine "Olcu tablosu" sekmesi (`OrderPage.tsx`), `api/olcum.ts`
  (tablo, tabloYukle, tabloSil), `OlcumListePage.tsx` yeni ölçüm penceresi metinleri.
- **Komutlar:** `cd SentezSelvedge/web && npx tsc --noEmit -p . && npm run build` → temiz.

### 4. Testler
- **Ne yapıldı:** `tests/.../OlcuTablosuTests.cs` (SQL yalnız UZM_ tablolarına yazar, yeniden
  yükleme DELETE değil kapatma, uzantı kontrolü, Style eşleşmesi, başlık tespiti 9. satır,
  10 geçerliyken ikinci blok seçilmez, beden listesi). Sema sayıları 20→22, script 6→7,
  açma hata mesajı testi güncellendi.
- **Uçtan uca (geçici test, commitlenmedi):** LocalDB'de gerçek
  `Selvedge/90991 ... 2317-3011 DIRTY MARTINI.xlsx` ile: Style `2317-3011-1141-M11554` okundu,
  22/23 bedenleri, 36 satır; iki kez yükleme → tek geçerli tablo; aynı model iki kalemde → tek
  seçenek; kapatılmış tabloyla açma reddedildi; beden 23 ile ölçüm 18 satırla açıldı
  (`MeasureSpecFileId` dolu, attachment NULL); tablo silinince yeni seçenek yok, eski ölçüm duruyor.
- **Sonuç:** `dotnet test` → 514/514 geçti.
- **Commit:** `31e83b1` — feat(sentez-selvedge/olcum): model olcu tablosu Excel ile yuklenir (Sentez eki yerine)

### 5. IIS paketi (0007 dahil)
- **Neden:** Kullanıcı "paket çıkartır mısın" dedi.
- **Ne yapıldı:** Site yeniden derlendi; şema aracı yeniden publish edildi (`sema\db`'ye 0007 girdi);
  `IIS-KURULUM.txt` başına "2026-10-26 SURUMU — SEMA DEGISTI (0007)" bölümü eklendi (sıra: db-tool → 9001
  GRANT bloğu → paket → ilk tablo yüklemeleri), paket sürümü `31e83b1`. 9001'in GRANT'i UZM_Selvedge_
  tablolarını döngüyle dolaştığı için yeni tablolar da kapsanıyor, betik değişmedi.
- **Komutlar:**
  ```bash
  PK=SentezSelvedge-IIS-192.168.3.228-91
  .\SentezSelvedge\Deploy-IIS.ps1 -OutputDir "$PK\site"
  rm -rf $PK/sema && dotnet publish SentezSelvedge/db-tool -c Release -o $PK/sema
  mkdir -p $PK/sema/db $PK/sema/elle; cp SentezSelvedge/db/*.sql $PK/sema/db/; cp SentezSelvedge/db/elle/*.sql $PK/sema/elle/; cp SentezSelvedge/Deploy-IIS.ps1 $PK/
  Compress-Archive -Path "$PK\*" -DestinationPath "$PK.zip"
  ```
- **Sonuç:** `SentezSelvedge-IIS-192.168.3.228-91.zip` 161 girdi, 21,9 MB; bundle `index-Cl4QAEci.js`,
  wwwroot'ta eski bundle yok; Development/logs/files yok; appsettings'te bağlantı dizesi boş.
  Kurulum kullanıcıda (buradan sunucuya erişim yok).

### 6. SentezPlaning dikim: Fashion ve Non Denim ayrıca da görülsün
- **Neden (kullanıcı):** "Dikimde Fashion ve Non Denim'i birleştirmiştik. Onun haricinde ayrı ayrı DA
  görmek istiyorlar, mevcudu bozmadan."
- **Sorulan / karar:** Çalışan sayısı hat başına (Fashion & ND = 110) tanımlı, dikim yerine bölünemez.
  Kullanıcı seçti: alt görünüm **yalnız yük** (order, adet, +%pay, SMV, SAH, Op. %xx); çalışan/tahmini/
  fark/adet tavanı ve tam hafta özeti yalnız birleşikte. Excel'e de ayrı sayfa: **evet**.
- **Ne yapıldı:**
  - `api/Sentez/UretimPlan/HatAltGrup.cs` (yeni): `Indis(line, yer)` (boşluk/harf normalize),
    `Icinde(line, indis, order)` — önce UD_DikimYeri, boşsa AYNI SIRADAKİ kategori (hat eşleşmesiyle aynı kural).
  - `UretimPlanService`: `LineOrders(line, yer)`; `GetWeeks/GetWeeksToplam/GetSevk/GetOrders`'a isteğe bağlı
    `yer`. Alt görünümde `AltGorunum=true`, Calisan/Tahmini/Fark/AdetTavan=0, `Durum="yok"`; weeks-toplam → 204.
    Hatta olmayan yer → boş liste. `yer` verilmezse davranış birebir eski.
  - Controller: dört uca `[FromQuery] string? yer`.
  - `UretimPlanExport`: çok dikim yerli hatta birleşik sayfanın yanına `Kapasite Fashion`, `Kapasite Non Denim`
    (yalnız yük kolonları + TOPLAM + açıklama satırı). Sheet adı çakışmasın diye `BenzersizAd`.
  - Web `UretimPlanlamaPage.tsx`: hat düğmelerinin yanında `Birleşik / Fashion / Non Denim` seçici
    (yalnız `dikimYerleri.length > 1`), başlıklar "Fashion & ND › Non Denim", `CapacityTable yukOnly`
    kapasite kolonlarını gizler (tfoot colSpan'leri buna göre). `api/uretimPlan.ts` `yer` parametreleri.
  - README "Dikim hatları"na not.
- **Dokunulan dosyalar:** `SentezPlaning/api/Sentez/UretimPlan/{HatAltGrup,UretimPlanService,UretimPlanController,UretimPlanExport,UretimPlanModels}.cs`,
  `SentezPlaning/web/src/{api/uretimPlan.ts,pages/UretimPlanlamaPage.tsx}`, `SentezPlaning/tests/SentezPlaning.Tests/HatAltGrupTests.cs`, `SentezPlaning/README.md`.
- **Komutlar / doğrulama:**
  ```bash
  dotnet test SentezPlaning/tests/SentezPlaning.Tests     # 268/268 (yeni 5)
  cd SentezPlaning/web && npx tsc -b && npm run build      # temiz
  # yerel uçtan uca: data/sentez-planing.db yedeklendi; API Development 5299, JWT dev anahtarıyla imzalı
  ASPNETCORE_ENVIRONMENT=Development dotnet run --no-launch-profile --urls http://localhost:5299
  ```
  Yerel veride (Sentez'den fiili 28.445 satır): 10 dolu haftanın HER BİRİNDE Fashion + Non Denim =
  birleşik (order sayısı, plan adet, SAH). Order 295 = 193 + 102; sevk adedi 113.090 = 79.154 + 33.936.
  Alt weeks-toplam 204, geçersiz yer 0 satır. Export: 12 sayfa, `Kapasite Fashion` / `Kapasite Non Denim` doğru kolonlarla.
  Sonra API kapatıldı; açılışta oluşan WAL/SHM silindi (ana .db yedekle byte-aynıydı).
  Tarayıcıda görsel kontrol YAPILAMADI: chrome-devtools MCP profili başka oturumda kilitli.
- **Commit:** `3148029` — feat(sentez-planing/dikim): Fashion ve Non Denim birlesik hatta ayrica da gorulur

### 7. SentezPlaning paketi (3148029)
- **Neden:** Kullanıcı "paket çıkartır mısın" dedi.
- **Komutlar:**
  ```powershell
  cd SentezPlaning; powershell -ExecutionPolicy Bypass -File .\Deploy-IIS.ps1
  Compress-Archive publish\* X:\GitlabredericTr\SentezPlaning-paket-2026-10-26-3148029.zip
  ```
- **Sonuç:** 70 dosya, 7,9 MB; `.db`/log/Development/data yok. Bundle `index-DHkLEhDl.js` içinde
  alt görünüm metni, DLL'de `AltGorunum` → bayat değil. Şema değişikliği yok.
  Kurulum kullanıcıda: `.\Deploy-IIS.ps1 -SkipWebBuild -SetupIIS -SiteName SentezPlaning -Port 8090 -PhysicalPath 'C:\inetpub\SentezPlaning'` ya da zip.

### 8. SentezSelvedge canlı: 0007 + yetki (site düşmüştü)
- **Neden:** Kullanıcı paketi şema adımlarından ÖNCE kurdu → SemaDogrulayici "Sema eksik (3 sorun)" ile uygulama açılmadı.
- **Engeller:** `uzm_selvedge_app` DDL yetkisiz (CREATE TABLE/ALTER = 0, tasarım gereği). Windows kimliği (abdus,
  0001–0006'yı uygulayan) bu makineden "Cannot generate SSPI context". Kullanıcı `sa` verdi (şifre hiçbir yere yazılmadı,
  yalnız `SQLCMDPASSWORD` ortam değişkeni, komut sonrası silindi).
- **Ne yapıldı:**
  1. Hash = paketteki `sema/db/0007_olcu_tablosu.sql` (CRLF, BOM'suz; git checkout ile aynı) SHA256 = `A29443160EE9…`.
  2. `SET XACT_ABORT ON; BEGIN TRAN; <0007>; INSERT SchemaHistory(0007, hash, 'abdus'); COMMIT` — `sqlcmd -U sa -b` → trancount 0.
  3. 9001'in GRANT döngüsü (sa) → uygulama dışı yazma izni 0 satır.
  4. Doğrulama: tablolar + `MeasureSpecFileId` var; `uzm_selvedge_app` ile SpecFile/Spec INSERT + UPDATE → ROLLBACK, kalan 0.
     Not: sqlcmd'de `-I` (QUOTED_IDENTIFIER ON) şart — filtreli indeksli tabloya yazarken 1934 hatası.
- **Sonuç:** `http://192.168.3.228:91/` 200, bundle `index-Cl4QAEci.js` (= paket), `/api/olcum/tablo/1` 401 (API ayakta).

### 9. Excel okumaları ölçüm olarak yüklenir, mobilden yeni ölçüm kapalı
- **Neden:** Müşteri: "yalnız okunmuşlar girilsin, normal ölçüm gibi görülsün, mobilden yeni giriş engellensin".
  Örnek dosya `91798 LOW CURVE UTILITY A336-1885-1535 RANK.xlsx` (repo kökünde, izlenmiyor): satır 10 başlık,
  F=22, G=23 + H,I okuma, J=24 + K,L okuma … AL=34; okumalar "OK", "-1/2", "+1/8" (sapma). 22/33/34 okumasız.
  Eski ayrıştırıcı boş başlıkta durduğu için bu dosyada yalnız 22–23'ü okuyordu.
- **Ne yapıldı:**
  - `OlcumSpecExcel`: `BedenKolonu(Beden, Kolon, OkumaKolonlari)`. Başlığı boş kolon, veri satırlarında (başlık+1..+80)
    doluysa o bedenin okuma kolonu (en çok 10); okuma bir sonraki başlıkla sürer. Veri de boşsa ya da sonraki başlık
    TEKRAR eden bedense eskisi gibi biter (yanda ikinci blok testi korunur). `SapmaMetni`: OK=0, ±a/b, ±n a/b, ondalık.
    Sayı hücresi spec'e kendisinden yakınsa ölçülen değer sayılır. Okunamayan hücre → `OkumaUyarilari` (yükleme durmaz).
  - `OlcuTablosuStore.OkumaOlcumleri`: (beden, adet) başına bir ölçüm, bedenin tüm POM'ları; ölçülen = spec + sapma,
    durum `SapmaHesap.Durum` (×2 kuralı YOK). `YukleAsync(..., workOrderId)` aynı transaction'da: önceki
    `AttachmentType LIKE 'Excel okuma%'` ölçümlerini (aynı sipariş + model) IsDeleted=1, yenileri KAPALI
    (`EndTime` dolu, Status=Kapali, tip "Excel okuma - N. adet") yazar.
  - Controller: `POST /api/olcum/tablo/{inv}?isEmri=` (model siparişte yoksa 400), yanıtta `olcumSayisi`.
    `POST /api/olcum/ac` yalnız `X-Istemci: web` başlığıyla; yoksa 400 "Mobilden yeni olcum girisi kapatildi".
  - Web: `client.ts` her isteğe `X-Istemci: web`; `OlcuTablosuPaneli` `isEmri` prop'u (OrderPage `order.recId` geçer).
- **Dokunulan dosyalar:** `SentezSelvedge/api/Selvedge/Olcum/{OlcumSpecExcel,OlcuTablosuStore,OlcumController}.cs`,
  `SentezSelvedge/web/src/{api/client.ts,api/olcum.ts,components/OlcuTablosuPaneli.tsx,pages/OrderPage.tsx}`,
  `SentezSelvedge/tests/SentezSelvedge.Tests/OlcumOkumaTests.cs` (yeni).
- **Komutlar:**
  ```bash
  dotnet test SentezSelvedge/tests/SentezSelvedge.Tests      # 534/534
  cd SentezSelvedge/web && npx tsc -b && npm run build
  .\SentezSelvedge\Deploy-IIS.ps1 -OutputDir "$PK\site"     # bundle index-COevzwUv.js
  Compress-Archive SentezSelvedge-IIS-192.168.3.228-91\* SentezSelvedge-IIS-192.168.3.228-91.zip   # 22.9 MB
  ```
- **Sonuç / doğrulama:** Gerçek dosya (geçici test ile): 13 beden, 17 POM, 340 okuma, 0 uyarı → 20 ölçüm (23–32 × 2 adet),
  WAIST 23/1: spec 27.5, ölçülen 27.0, sapma −0.5, Uygun. Şema değişmedi; sunucuda yalnız paket kurulumu.
  IIS-KURULUM.txt'ye "2026-10-26 (2)" bölümü eklendi.
- **Commit:** `88c9f1e` — feat(sentez-selvedge/olcum): Excel okumalari olcum olarak yuklenir, mobilden yeni olcum kapali

### 10. Sipariş araması müşteri PO numarasında da arar
- **Neden:** Kullanıcı "91798 order'ı neden gelmez" dedi. 91798 Excel'deki "PO NO" = `Erp_WorkOrder.CustomerOrderNo`;
  `SentezSql.OrderAra` yalnız `WorkOrderNo` ve `InventoryCode`'da arıyordu. (DB'ye bağlanıp doğrulanmadı; kimlik bilgisi yok.)
- **Ne yapıldı:** `OrderAra` WHERE'ine `OR wo.CustomerOrderNo COLLATE Turkish_CI_AS LIKE @AramaKalip`; arama kutusu
  placeholder "Siparis no, PO no veya model kodu". Not: verbatim C# string içindeki SQL yorumunda çift tırnak derlemeyi bozdu, kaldırıldı.
- **Dokunulan dosyalar:** `SentezSelvedge/api/Sentez/SentezSql.cs`, `SentezSelvedge/web/src/pages/OrderPage.tsx`
- **Sonuç:** test 534/534; paket yeniden (bundle `index-Bnjda9Gf.js`, zip 22.9 MB, IIS-KURULUM.txt commit 525be39).
  Sipariş Sentez'de kapalı/iptal ya da tip 15 değilse yine listede çıkmaz (filtre bilerek).
- **Commit:** `525be39` — fix(sentez-selvedge/siparis): siparis aramasi musteri PO numarasinda da arar

### 11. SentezPlaning dikim: Fashion ve Non Denim ayrı hat düğmesi
- **Neden:** Kullanıcı (localhost:90/dikim) "Fashion & ND yanına Fashion ve ND getirmemişsin" dedi. 3148029'daki
  Birleşik/Fashion/Non Denim seçicisi yalnız Fashion & ND seçiliyken görünüyordu → bulunamadı.
- **Ne yapıldı:** `DikimTab` hat düğmeleri `flatMap`: her hat + `dikimYerleri.length > 1` ise her dikim yeri için
  ayrı düğme (`setLineId(l.id); setYerSecim(y)`); seçili = aynı hat VE aynı yer. Ayrı seçici kaldırıldı. API değişmedi.
- **Dokunulan dosyalar:** `SentezPlaning/web/src/pages/UretimPlanlamaPage.tsx`
- **Komutlar:**
  ```powershell
  cd SentezPlaning/web; npx tsc -b; npm run build
  cd ..; powershell -ExecutionPolicy Bypass -File .\Deploy-IIS.ps1
  Compress-Archive publish\* X:\GitlabredericTr\SentezPlaning-paket-2026-10-26-d7ee125.zip
  ```
- **Sonuç:** tsc/build temiz; bundle `index-Dcy5TFzh.js`, zip 8.3 MB, .db/log yok. Ekran tarayıcıda denenmedi (localhost:90 kullanıcının sunucusu).
- **Commit:** `d7ee125` — fix(sentez-planing/dikim): Fashion ve Non Denim ayri hat dugmesi olarak gorunur

## Kararlar
- Ölçü tablosunun kaynağı artık model başına yüklenen Excel (spec §4.5'e tarihli not düşüldü).
- Ölçüm girişi Excel okumalarından (web); mobilden yeni ölçüm açılmaz (sunucu reddeder, APK değişmedi). Web'de "Yeni ölçüm" kaldı.
- Excel dosyasının kendisi saklanmaz; yüklemede ayrıştırılıp satırlar yazılır.
- Çok modelli iş emrinde sipariş penceresi ilk kalemin modelini gösterir; ölçüm açarken her
  modelin tablosu ayrı seçenek olarak listelenir.

## Açık kalanlar / sonraki adım
- `sa` ve `uzm_selvedge_app` şifreleri sohbette açık yazıldı → değiştirilmesi önerildi (app şifresi değişirse sunucudaki ConnectionStrings__Sentez de).
- SentezPlaning: paket hazır (`SentezPlaning-paket-2026-10-26-d7ee125.zip`), sunucuya kurulmalı. Ekran tarayıcıda denenmedi.
- ~~0007 canlıya uygulanmadı~~ → 2026-10-26 uygulandı (bkz. 8).
  Uygulama: önceki gibi sqlcmd ile `BEGIN TRAN; 0007; INSERT SchemaHistory(0007, hash); COMMIT`
  ya da paketteki `sema\SentezSelvedge.Db.exe db`. Ardından yeni tablolar için
  `db/elle/9001_yetki.sql` yetki bloğu ELLE koşturulmalı (GRANT INSERT/UPDATE/DELETE).
- IIS paketi hazır (zip); sunucuya kurulmalı — ÖNCE 0007 + 9001 GRANT.
- Mevcut modellerin tablolarının ilk yüklemesi yapılmalı; yüklenmeyen modelde ölçüm açılamaz.
- İstenirse mobil uyarı metni ("Sentez'de Excel eki yok") güncellenip yeni APK.
- SentezSelvedge paketi (525be39) sunucuya kurulmalı; ardından Ctrl+F5. Önceki sürümle yüklenen tablolar (boş kolonlu Excel) yalnız 22–23 bedeni almış olabilir → yeniden yüklenmeli.
