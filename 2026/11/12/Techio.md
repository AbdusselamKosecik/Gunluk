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
