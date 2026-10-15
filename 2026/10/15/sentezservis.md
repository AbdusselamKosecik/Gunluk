# sentezservis — 2026-10-15

## Bağlam
Kullanıcı Sentez'de iş emri numarasını değiştirdi (71531: Test-004-2 → 4315-2), ama listelerde eski numara kaldı.
`UZM_SiparisWorkOrder.WorkOrderNo` sütunu, iş emri oluşturulurken yazılan bir kopya.

## Yapılanlar

### 1. İş emri numarası Erp_WorkOrder'dan okunuyor
- **Ne yapıldı:** Üç okuma `ISNULL(w.WorkOrderNo, t.WorkOrderNo)` + `LEFT JOIN dbo.Erp_WorkOrder w ON w.RecId = t.WorkOrderId` ile değişti:
  - `SiparisDeposu.SiparislerAsync`: sipariş listesindeki WorkOrderNo sütunu.
  - `SiparisDeposu.OlusturAsync`: "zaten work order oldu" mesajındaki numaralar.
  - `PlanlamaDeposu.KalemlerAsync`: kalem bazında WorkOrderNo.
- **Test:** `tests/SentezServis.Core.Tests/IsEmriNoCanliTestleri.cs` (salt okuma).
  - Liste ve planlama numaraları Sentez'deki güncel numarayla karşılaştırılıyor.
  - Önce kırmızı: beklenen "4315-2, Test-004-1", gelen "Test-004-1, Test-004-2". Sonra yeşil.
- **Derleme düzeltmesi:**
  - Sorun: `System.Security.Cryptography.Pkcs` 10.0.0, MailKit/SqlClient üzerinden geliyor ve yeni açıkları var (GHSA-846f-f764-76mx, GHSA-2fmv-rv2c-59x7).
    Projede TreatWarningsAsErrors açık olduğu için NU1902/NU1903 derlemeyi kırıyordu.
  - Çözüm: `SentezServis.Core.csproj` içinde doğrudan `Version="10.0.13"` ile sabitlendi.
- **Komutlar:** canlı testler için `SENTEZCORE_TEST` ortam değişkeni gerekiyor.
  Scratchpad'deki `sentez-test.ps1`, paketleme ayarındaki DPAPI şifresinden bağlantıyı kurup `dotnet test` çalıştırıyor; şifreyi ekrana basmıyor.
- **Sonuç:** 287 testten 286'sı geçti.
- **Commit:** `e363870`

## Açık kalanlar
- `SiparisDeposuCanliTestleri.Onizleme_her_siparis_adedini_ya_taslakta_ya_eksikte_gosterir` kırmızı.
  - Bu değişiklikle ilgisi yok: önizleme yolu değişen SQL'i kullanmıyor.
  - Test canlıdaki son açık siparişe bağlı; bu siparişte birden fazla taslak var ve eksik yok.
- `SentezServis.Ajan` derlemesinde yerel `appsettings.json` eksik. Bu dosya gitignore'da, değişiklikle ilgisi yok.
- **Canlıdaki sentezservis'e yayın yapılmadı.** Web listelerinin yeni numarayı göstermesi için yeniden yayın gerekiyor.
