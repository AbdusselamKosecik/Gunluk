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
