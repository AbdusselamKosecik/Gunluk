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

## Kararlar
- Ölçü tablosunun kaynağı artık model başına yüklenen Excel (spec §4.5'e tarihli not düşüldü).
- Excel dosyasının kendisi saklanmaz; yüklemede ayrıştırılıp satırlar yazılır.
- Çok modelli iş emrinde sipariş penceresi ilk kalemin modelini gösterir; ölçüm açarken her
  modelin tablosu ayrı seçenek olarak listelenir.

## Açık kalanlar / sonraki adım
- **0007 canlıya (SentezLive, 192.168.1.22) uygulanmadı** — bu oturumda SQL kimlik bilgisi yoktu.
  Uygulama: önceki gibi sqlcmd ile `BEGIN TRAN; 0007; INSERT SchemaHistory(0007, hash); COMMIT`
  ya da paketteki `sema\SentezSelvedge.Db.exe db`. Ardından yeni tablolar için
  `db/elle/9001_yetki.sql` yetki bloğu ELLE koşturulmalı (GRANT INSERT/UPDATE/DELETE).
- IIS paketi hazır (zip); sunucuya kurulmalı — ÖNCE 0007 + 9001 GRANT.
- Mevcut modellerin tablolarının ilk yüklemesi yapılmalı; yüklenmeyen modelde ölçüm açılamaz.
- İstenirse mobil uyarı metni ("Sentez'de Excel eki yok") güncellenip yeni APK.
