# Techio — 2026-11-12

## Bağlam
Kullanıcı "paket çıkartır mısın" ve ardından "çalıştırılacak SQL'leri de verir misin" dedi.
Kaynak: `X:\Techio\backend` (.NET 10) + `X:\Techio\ui` (Vue 3). İkisi de git'te değil.

## Yapılanlar

### 1. Paket (API + gömülü UI)
- **Neden:** Sahaya kurulum.
- **Ne yapıldı:** UI production build → API self-contained single-file publish → publish çıktısındaki eski
  `wwwroot` (2025-08 UI) yeni `ui/dist` ile değiştirildi → `.pdb` ve `appsettings.Development.json` çıkarıldı → zip.
- **Komutlar:**
  ```bash
  cd X:/Techio/ui && npm run build
  cd X:/Techio/backend && dotnet publish Techtsio.Presentation/Techtsio.Presentation.csproj \
      -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -o <staging>/api
  rm -rf <staging>/api/wwwroot && cp -r X:/Techio/ui/dist <staging>/api/wwwroot
  tar.exe -a -c -f X:\Techio\Techio-paket-2026-11-12.zip -C <staging>\api *
  ```
  Not: PowerShell 5.1 `Compress-Archive` zip içine ters slash yazıyor (unzip uyarı veriyor) → `tar.exe -a` kullan.
- **Sonuç / doğrulama:** Zip açılıp `Techtsio.Presentation.exe console` ile çalıştırıldı: `GET /` 200
  (`<title>techtsio`), `GET /api/Shifts` 401 (auth var, API ayakta). Build: 0 hata, 68 uyarı (mevcut).
- **Çıktı:** `X:\Techio\Techio-paket-2026-11-12.zip` (61 MB, SHA256 `F2AD11F9…7007`), içinde `sql/`.
- **Dikkat:** paketteki `appsettings.json` TEST DB'yi gösteriyor (`192.168.1.69/TechtsioMerkezTest`).

### 2. Canlı için SQL
- **Neden:** Paketin canlıda (`192.168.10.58/TechtsioMerkez`) çalışması için DB'de eksik ne var?
- **Ne yapıldı (sadece okuma):** Test ve canlı şema dökümü (SP parametreleri, tablo kolonları, view, fonksiyon) +
  koddaki 89 `Exec [...]` çağrısı canlıyla eşleştirildi + çağrılan SP'lerin gövdeleri karşılaştırıldı.
- **Bulgular:**
  - Kodun çağırdığı 3 SP canlıda yok: `REPORT_F_OrderCuteInfo`, `REPORT_F_FabricStatusReport`, `REPORT_F_OrderProcessInfo`.
    Bağımlılıkları (SENTEZ linked server, `SentezLive.dbo.OrderSewingReport`, `UretimOranlari`) canlıda var.
  - Canlıda hiçbir SP'de `@LocationId` yok; kod da göndermiyor → eklemeye gerek yok.
  - Test ve canlı SP gövdeleri iki yönde sapmış (örn. `REPORT_F_Prim` canlıda daha yeni) → test gövdeleri kopyalanmadı.
  - Test'te `REPORT_F_EffYearMonthBreakdown`'da `@EmployeeId` → `@LocationId` ile değiştirilmiş (eklenmemiş); test'te bozuk olabilir.
  - `DATA_quality_control_screen` iki DB'de de yok (eski sorun).
- **Dosya:** `01_eksik_SPler.sql` (idempotent: `IF OBJECT_ID IS NULL EXEC('CREATE ... AS RETURN 0')` + `ALTER`),
  `OKU.md` kurulum notu. Kopyaları: `2026/11/12/Techio-sql/`.
- **Doğrulama:** canlıda `SET PARSEONLY ON` ile sözdizimi OK; canlıda hiçbir şey oluşturulmadı/değiştirilmedi.

## Kararlar
- Canlıya sadece eksik 3 SP; LocationId ve test gövdeleri bilerek dışarıda.

## Açık kalanlar / sonraki adım
- Kurulumda `appsettings.json` canlı bağlantıya çevrilmeli.
- `01_eksik_SPler.sql` canlıda kullanıcı tarafından çalıştırılacak.
- Techio kaynakları hâlâ git'te değil.

---

### 3. Fashion (10.10.10.200) — 04.11.2026 12:05-12:20 herkese 15 dk HARICI DURUM (HAZIR, ÇALIŞTIRILMADI)
- **Neden:** Kullanıcı talebi; o gün 12:10-12:15 arası hiç kayıt yok (üretim durmuş).
- **Keşif (salt okuma):** `LostTimes` Code=10 "HARICI DURUM" (Id 1EF61346-…, AffectProductivity=1).
  `REPORT_F_EfficiencyReport`: TotalWorkingHours = PDKS `EntryControl.WorkedTime` (yoksa 540),
  Net = Total − (KZ01+KZ10+KZ11+KZ02) − Repair. KZ10 = `FC_New_Transection_Group_View_PDKS` içinde
  `IsLostTime=1 AND IsIllegal=0 AND Code='10'` satırlarının takvim süresi (`GetWorkingTimeFromTwoDate`) → üretim
  satırlarıyla çakışma bu raporu bozmaz. 9 bantta pencere = 900 sn. Trigger'lar kapalı.
  Bu DB'de hiç elle kayıp zaman yok (136k satır hepsi CreatedType=2). Cihaz harici durumları `IsIllegal=1` → raporda sayılmıyor olabilir (ayrı konu).
- **Hedef kitle:** cihaz kaydı olan, DeviceType<>4, len(Code)>3, ilk kayıt <12:05 ve son kayıt >12:20 → 165 kişi (2 kişi dışarıda).
- **Script:** `01_harici_durum_ekle.sql` (tek transaction, sayı 150-180 dışıysa rollback, etiket `ChangedExp='TOPLU HARICI DURUM 2026-11-04 12:05-12:20'`,
  CreatedType=4, alanlar kişinin 12:05'teki kaydından), `02_geri_al.sql`. Kopya: `2026/11/12/Techio-fashion/`.
  Önce raporu: `X:\Techio\Fashion-harici-durum-2026-11-04\rapor_ONCE.txt`.
- **Durum:** Kullanıcı onayı bekleniyor; çalıştırılmadı.

### 4. Dikim (172.16.1.2) — QualityControlQuantityList çiftleme analizi (salt okuma)
- **Ham veri temiz:** `OrderItemVariantProduction` (QualityType>1, 01.10-11.11) silinmiş kayıt 0, çift gönderim 0.
  `FC_New_Transection_OnlyQuantity_View` 6 haftada 62 grupta cihaz/makine/bant farkıyla bölünme, toplam 22 adet fazla (önemsiz).
- **Ölçüm 01-11.11.2026, CalculatorQuantity toplamı:**
  ana SP 115.006 | R0 67.220 | R1 67.220 | R2 91.560 | R3 67.220 | R4 91.560 (doğru = 67.220, tamir adedi hepsinde 396).
- **Kök neden:** Calc (sipariş, tamirci, tamir op) seviyesinde; ana SP satırı (hata, kontrolcü, kontrol op, **OrderItemVariantId** — select'te yok ama GROUP BY'da)
  seviyesinde → aynı üretim her satıra tekrar yazılıyor (en çok 7 kez). R2/R4 hata kodu seviyesinde → aynı sipariş üretimi her hata türünde tekrar.
  R2 Oran ×100, diğerleri değil (tutarsız).
- **Durum:** Düzeltme önerisi kullanıcıya sunuldu, SP'lere dokunulmadı.

### 5. Dikim (172.16.1.2) — QC çiftleme DÜZELTİLDİ (ana SP, R2, R4)
- **Neden:** Kullanıcı "sistemi ve çıktıyı bozmadan çiftlemeleri düzelt" dedi.
- **Kural:** Kolon adı/sırası/tipi aynı (backend Dapper modeli ve UI grid'i değişmiyor). R0/R1/R3 zaten doğru, dokunulmadı.
- **Ne yapıldı:**
  - Ana SP: `p.OrderItemVariantId` GROUP BY'dan çıktı; CalculatorQuantity `Calc` CTE ile (sipariş, tamirci, tamir op) seviyesinde
    bir kez hesaplanıp `ROW_NUMBER()` ile kombinasyonun ilk satırına yazılıyor, diğerlerinde 0 (korele alt sorgu da kalktı).
  - R2: payda = (kişi, op) için tamir gördüğü siparişlerdeki üretim (R1 ile aynı); Calc ilk hata satırında; Oran gerçek payda ile, ×100 korundu.
    → R2 hata oranları toplamı = R1 oranı (doğrulandı, 0 fark).
  - R4: payda = dönem toplamı (her sipariş/kişi/op bir kez); Calc ilk satırda; Oran gerçek payda ile.
  - Eski tanımlar `<ad>_yedek_20261112` olarak DB'de duruyor; `02_geri_al.sql` eskiye döndürür.
- **Test:** önce `#` geçici prosedürlerle eski/yeni yan yana (01-11.11.2026):
  ana 322→316 satır (fark yalnız görünmez varyant bölünmesi; görünen satır kümesi birebir aynı), Calc 115.006→67.220;
  R2 91.560→67.220 (166 satır aynı); R4 91.560→67.220 (12 satır aynı); tamir 396 hepsinde.
- **Uygulama:** `01_duzelt.sql` (PARSEONLY OK → tek transaction, yedek + ALTER). Sonrası canlı doğrulama aynı sayılar.
- **Dosyalar:** `X:\Techio\Dikim-QC-ciftleme-2026-11-12\` (kopya `2026/11/12/Techio-dikim-qc/`).
- **Kalan:** `FC_New_Transection_OnlyQuantity_View` cihaz/makine farkıyla nadir bölünme (6 haftada 22 adet) — dokunulmadı.

### 6. Fashion 04.11.2026 12:05-12:20 HARICI DURUM — "araya girme" yöntemiyle UYGULANDI
- **Neden:** Kullanıcı: "X:\Test altındaki gibi araya girmemiz lazım, yanlış olmuş". (#3'teki üst üste ekleme yaklaşımı
  hiç çalıştırılmamıştı; DB temizdi. O scriptler `ESKI_yanlis_yaklasim/` altına alındı.)
- **Kaynak şablon:** `X:\Test\fashion_losttime_fix.sql` (30.06.2026 15:00-15:15), `fashion_01_yedek_al.sql`, `fashion_02_geri_yukle.sql`.
  Mantık: 12:05'i kapsayan kayıt EndDate=12:05 (EndQ aynı); aralık içi kayıtlar (+Items, +Reason) silinir; 12:20'yi kapsayan kayıt
  StartDate=12:20, StartQ=Qboundary (sayaç zinciri içerideki adedi sağa taşır); 12:05-12:20 HARICI (Code 10) eklenir;
  tek kaydı aralığı tamamen kapsayan (overlap) kişilerde kayıt ikiye bölünür (üretim sol parçada).
- **Ön analiz:** 168 kişi = 86 normal + 82 overlap; 77 iç kayıt (122 adet); zincir uyumu %99,5; uç durum yok.
- **Şablondan farklar:** (a) yeni HARICI satırlarda IsRepair/IsIllegal=0 (rapor KZ10 IsIllegal=0 arar);
  (b) `ChangedExp='HARICI DURUM 2026-11-04 12:05-12:20'`; (c) overlap kaydı kayıp zamansa sağ parça da kayıp zaman;
  (d) bütünlük kontrolü = günün TÜM kayıt adedi korunmalı (yalnız üretim değil: 2806 ESMA TARDU'da iç 1 adet IsIllegal kayıt,
  sağdaki kayıp zaman kaydına zincirle geçiyor → üretim toplamı -1 görünüyordu, rapor etkisi 0) + aralıkta başka kayıt yok + herkeste 1 HARICI.
- **Akış:** 03 TEST (rollback) ×3 → yedek tabloları `*_yedek_20261104` (kullanıcı 03:34'te SSMS'ten almış; mevcut veriyle birebir
  aynı olduğu doğrulandı, 16.536 satır, fark 0) → kullanıcının 03:37 SSMS denemesi eski kontrol yüzünden kendini ROLLBACK etti
  (değişiklik yok) → düzeltilmiş script @DoCommit=1 ile COMMIT (168 HARICI, gün toplamı 185.862 = 185.862).
- **Sonradan düzeltme (c):** rapor karşılaştırmasında 2 kişide net çalışma +32/+34 çıktı → overlap kaydı kayıp zaman olan 3 kişide
  (7362 MAKINE ARIZA, 2828 MAKINE ARIZA, 2530 SETUP) şablon sağ parçayı üretim açmıştı. 3 satır IsLostTime=1 + orijinal sebep ile düzeltildi
  (`ChangedExp='HARICI 2026-11-04 sag parca KZ'`). Not: sqlcmd'de UPDATE için `-I` (QUOTED_IDENTIFIER ON) şart (computed/indexed nesneler);
  ChangedExp en fazla 50 karakter.
- **Sonuç (REPORT_F_EfficiencyReport 04.11):** 167 kişi; 165'inde Harici +15; performansı artan 141, aynı 26, azalan 0; net artan 0.
  Harici almayan 2 kişi o saatte işte değil. Net düşüşün bazılarında 15'ten az olması doğru: aralıktaki Standart Dışı vb. kayıp zamanlar
  silinip yerine HARICI geldi (54 kişide Standart Dışı azaldı). `rapor_ONCE.txt` / `rapor_SONRA.txt` klasörde.
- **Geri alma:** `02_geri_yukle_20261104.sql` (@DoCommit=1) günü yedek anına döndürür.
- **Dosyalar:** `X:\Techio\Fashion-harici-durum-2026-11-04\` (kopya `2026/11/12/Techio-fashion/`).
