# Techio paket 2026-11-12 — kurulum notu

## Paket
- `Techio-paket-2026-11-12.zip` — API (.NET 10, self-contained win-x64, tek exe) + UI (wwwroot içinde, 2026-11-12 build).
- Windows servisi olarak çalışınca **port 81**, `console` argümanıyla çalışınca **port 44307** dinler.

## ⚠️ Kurmadan önce
1. **`appsettings.json` TEST veritabanını gösteriyor** (`192.168.1.69 / TechtsioMerkezTest`).
   Canlıya kurulacaksa `DefaultConnection` canlı veritabanına çevrilmeli
   (eski canlı ayarı: `Server=192.168.10.58;Database=TechtsioMerkez;...`).
2. Mevcut kurulumun klasörünü ve `appsettings.json`'unu yedekle.
3. Bu paket .NET 7'den .NET 10'a geçiş içerir. Self-contained olduğu için sunucuya .NET kurmak gerekmez.

## SQL (canlıda, paketten ÖNCE)
| Sıra | Dosya | Ne yapar | Zorunlu mu |
|---|---|---|---|
| 1 | `01_eksik_SPler.sql` | Canlıda olmayan 3 SP'yi oluşturur: `REPORT_F_OrderCuteInfo`, `REPORT_F_FabricStatusReport`, `REPORT_F_OrderProcessInfo` | Evet; yoksa bu 3 rapor 500 döner |

- Script tekrar çalıştırılabilir (SP varsa üzerine yazar).
- Canlıda `SET PARSEONLY` ile sözdizimi kontrol edildi; bağımlılıklar (SENTEZ linked server,
  `SentezLive.dbo.OrderSewingReport`, `SentezLive.dbo.UretimOranlari`) canlıda mevcut.

## Bilerek YAPILMAYANLAR
- **`@LocationId` parametresi canlı SP'lere eklenmedi.** Paketteki kod SP'lere `@LocationId` göndermiyor,
  bu yüzden gerek yok. (Test DB'de 39 SP'ye eklenmişti.)
- **Test DB'deki SP gövdeleri canlıya kopyalanmadı.** Test ile canlı iki yönde de sapmış durumda
  (örn. `REPORT_F_Prim` canlıda daha yeni: KayipZaman10/11 var; `DATA_BantTop5` test'te farklı yazılmış).
  Kopyalamak canlıdaki düzeltmeleri silerdi.
- Test DB'de `REPORT_F_EffYearMonthBreakdown`'da `@EmployeeId` yerine `@LocationId` yazılmış; kod hâlâ
  `@EmployeeId` gönderiyor → bu rapor **test**te bozuk olabilir, canlıda sorun yok.

## Bilinen eski sorun (bu paketle ilgisi yok)
- `DATA_quality_control_screen` SP'si ne test'te ne canlıda var; kod çağırıyor (`ProductionLinesManager.cs:411`).
