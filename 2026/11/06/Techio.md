# Techio — 2026-11-06

## Bağlam
Soru: `X:\Gitlab\fredericTr\techtsio-core` (GitLab, branch `FiredEric`, HEAD `aed2d61`, temiz) ile
`X:\Techio\backend` (API, **git deposu değil**) arasında fark var mı? Sadece analiz, kod değişmedi.

## Yapılanlar

### 1. İki ağacın karşılaştırılması
- **Neden:** API kopyasının GitLab'daki core'dan ne kadar saptığını görmek.
- **Komutlar:**
  ```bash
  cd /x
  diff -rq -x .git -x .vs -x bin -x obj -x logs -x .sonarlint -x .sonarqube \
       Gitlab/fredericTr/techtsio-core Techio/backend
  diff -ru --strip-trailing-cr -w <aynı exclude'lar> Gitlab/fredericTr/techtsio-core Techio/backend > full.diff
  ```
- **Sonuç:** 23 dosya farklı, 2 dosya sadece API'de (`SP_LocationId_Changes.md`,
  `Properties/PublishProfiles/FolderProfile1.pubxml.user`), core'a özgü dosya yok.
  Farklar 3 grup:
  1. **.NET yükseltmesi** (tüm csproj): netcoreapp3.1 / net7.0 → `net10.0`; EF Core 3.1.4 → 10.0.8,
     AutoMapper 9/12 → 16.1.1, `System.Data.SqlClient` → `Microsoft.Data.SqlClient` 6.1.4,
     Swashbuckle 6.4 → 9.0.6, Serilog.AspNetCore 6 → 9, SonarLint ruleset ve LangVersion kaldırıldı.
     Buna bağlı kod uyarlamaları: `using Microsoft.Data.SqlClient` (QueryRepository, MachinesManager,
     ShiftsManager, SpecialController), `request.Timeout` int → TimeSpan, ClosedXML `.Value` → string,
     `Program.cs` `WebHost`+`RunAsService` → `Host.CreateDefaultBuilder`+`UseWindowsService` (UseSerilog/UseStartup korunmuş, doğrulandı).
  2. **LocationId parametresi** (IReportManager, ReportManager, ReportController ~40 rapor metodu):
     imzalara `Guid locationId` eklendi. ReportManager'da `ProductionLineId = ..., locationId,`
     yazımı anonim tipe ayrı `locationId` property'si (ham Guid) ekliyor; SQL string'inde
     `@LocationId` yok → filtre fiilen uygulanmıyor. SP'lere `@LocationId = NULL` eklendi
     (detay `backend/SP_LocationId_Changes.md`).
  3. **Ortam/küçük**: appsettings bağlantısı `192.168.10.58/TechtsioMerkez` → `192.168.1.69/TechtsioMerkezTest`;
     `YapilanIslerRaporu` modeline `WashName`, `StandartTime`; birkaç Excel return satırı yoruma alındı.

## Kararlar
- Kod değiştirilmedi; sadece rapor.

## Açık kalanlar / sonraki adım
- `X:\Techio\backend` git'te değil → kayıp riski. GitLab'da ayrı branch'e alınması önerildi.
- LocationId gerçekten filtrelenecekse SP body + C# parametre adı düzeltilmeli.

---

### 2. Bulk aktarım logu + log ekranı + ekranda versiyon — tasarım (uygulama YOK)
- **Neden:** Müşteri "kartları gönderdik, değişmemiş" diyor; gönderip göndermediğini ve bizim ne
  yaptığımızı kanıtlayacak kayıt yok (`BulkInstallController.Post` sadece Serilog dosyasına JSON basıyor).
- **Ne yapıldı:** Keşif + tasarım dokümanı. Kullanıcı "sen yaz sonra yaparız" dedi.
- **Dokunulan dosyalar:** `X:\Techio\docs\superpowers\specs\2026-11-06-bulk-aktarim-log-design.md`
  (kopyası bu repoda: `2026/11/06/Techio-specs/`).
- **Özet karar:** 2 tablo (`BulkTransferLogs` başlık + ham JSON, `BulkTransferLogItems` varlık/alan bazlı
  Eklendi/Güncellendi/Silindi/Değişmedi), log hatası aktarımı bozmaz, başlık en başta yazılır;
  `[Authorize]` okuma API'si; UI'da "Aktarım Logları" ekranı (filtre: tarih, sipariş no, kart kodu, durum);
  Footer'da `UI v.. · API v..` + `GET api/Version`.
- **Keşif notları:** kart döngüsünde aynı kodlu diğer kartlar soft-delete ediliyor (silme olayı);
  model rotaları her gönderimde `ExecuteDeleteAsync` ile silinip yeniden ekleniyor; `Post` transaction'sız.

## Açık kalanlar (tasarım)
- Kodun yaşayacağı yer: Techio kopyaları git'te değil → önce GitLab'da yeni branch.
- "Ekrana versiyon yok" = uygulama sürüm numarası diye yorumlandı, teyit bekliyor.
