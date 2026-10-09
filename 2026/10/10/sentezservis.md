# sentezservis — 2026-10-10

## Bağlam
Kullanıcı: "Serviste https://mf-s.uzmanadres.com/karma-koli de kullanımda olmayan varyantları getirmez misin, listede de detayda."

## Yapılanlar

### 1. Karma koli: kullanım dışı varyantlar gizlendi — `f5a0ce3`
- **Neden:** `Erp_InventoryVariant.InUse` (UdtBool) vardı ama sorgular yalnız `IsDeleted`'a bakıyordu.
  Canlı veride (şirket 2) set varyantlarının 8.166'sı InUse=0, 2.725'i InUse=1; bileşenlerde 71.968 / 49.415.
  Tanımlı karma kolilerin hepsi InUse=1 varyantlarda; içerikte InUse=0 varyant yok (salt okuma ile kontrol).
- **Ne yapıldı:** `KarmaKoliDeposu`'na `AktifVaryantKosulu = "ISNULL(iv.IsDeleted,0)=0 AND ISNULL(iv.InUse,1)=1"`;
  kullanıldığı yerler: `SetMamulleriAsync` (liste, varyant sayısı), `MamulVaryantlariAsync` (detay, öneri, toplu
  uygula, bileşen varyantları), `MamulAraAsync` (yalnız kullanımda varyantı olan mamul), `VaryantlarAsync(sadeceAktif)`
  (kaydetme doğrulaması). Kayıtlı içeriği göstermek için kullanılan filtresiz `VaryantlarAsync` değişmedi.
- **Dokunulan dosyalar:** `src/SentezServis.Core/KarmaKoli/KarmaKoliDeposu.cs`,
  `tests/SentezServis.Core.Tests/KarmaKoliDeposuCanliTestleri.cs` (yeni, `SENTEZCORE_TEST` ile salt okuma).
- **Doğrulama:** Canlı testler önce 4/4 kırmızı (InUse=0 varyant dönüyordu), düzeltmeden sonra 4/4 yeşil;
  tüm suite 245 geçti, 4 atlandı. Bağlantı, kesimhane ayarlar.json'daki DPAPI şifresiyle (scratchpad `canlitest.ps1`).
- **Yayın:** `deploy/yayinla.ps1 -AyarlariKoru` → `yayin/`, arayüz tarihi 2026-10-10 00:35.

## Açık kalanlar
- Sunucuya (MODFEXSRV) kurulum: `deploy/uzaktan-yayimla.ps1` ya da paket — kullanıcı onayı bekleniyor.
