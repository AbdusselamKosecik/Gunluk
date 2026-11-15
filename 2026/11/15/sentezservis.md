# sentezservis — 2026-11-15

## Bağlam
Kullanıcı mal alım testi için `T-00000001` siparişini açtı (T-KMS-001, T-AKS-001 serili; T-IPL-001 serisiz). Varyantlara
barkod tanımlamak gerekiyor; Sentez'in kendi ekranı varyant barkodunda hata veriyor.

## Yapılanlar

### 1. Barkod tanımları ekranı
- **Neden:** "Satır varyantının barkodunu girebileceğimiz bir ekran, Sentez hata veriyor"; "barkod tanımlarının yapılması lazım".
- **Canlı bulgular (salt okunur):** `Erp_InventoryBarcode` tetikleyicisiz, CompanyId yok, Barcode'da tekil indeks yok
  (108 boş, 6'lı tekrarlar var). 45.910 barkodun 43.770'i varyant düzeyinde. Sentez'in kendi girişi (T-KMS-001, 19:57):
  BarcodeType 0, Quantity 1, InUse 1, varyant boş.
- **Ne yapıldı (alt ajan, sonra gözden geçirildi):** `/barkod-tanimlari` sayfası (Operasyon menüsü): stok ara → kart + renk/beden
  varyant barkodları; okuyucuyla Enter ekler, sonraki varyanta geçer; onayla yumuşak sil. Tekillik kodda (harf duyarsız,
  tüm tablo, silinmemiş), kontrol + ekleme `sp_getapplock N'UZM_Barkod'` altında tek transaction. Yazma
  `SentezServis:BarkodYazmaAcik` (varsayılan kapalı) + `KoliListeSentezKullaniciId`; denetim `barkod-eklendi/silindi`.
- **Dokunulan dosyalar:** `src/SentezServis.Core/BarkodTanim/*`, `src/SentezServis.Host/Api/BarkodTanimUclari.cs`, `Ayarlar.cs`,
  `Program.cs`, `tests/SentezServis.Core.Tests/BarkodTanimTestleri.cs`, `KarmaKoliTestleri.cs` (yazma koruma testi genişletildi),
  `web/src/api/barkodTanim.ts`, `web/src/pages/BarkodTanimlariSayfasi.tsx`, `web/src/utils/barkodTanim.ts(+test)`, `App.tsx`,
  `Layout.tsx`, `api/index.ts`, `docs/superpowers/specs/2026-11-15-barkod-tanimlari-design.md`
- **Doğrulama:** `dotnet test tests/SentezServis.Core.Tests` 339 geçti / 18 atlandı; web build + lint (0 hata) + vitest 66 geçti.
  Ekleme/çakışma/silme canlıda henüz denenmedi. `dotnet build SentezServis.slnx` Ajan projesinde eksik `appsettings.json`
  yüzünden hata veriyor (önceden var olan sorun).
- **Commit:** `55cbc76` — Barkod tanimlari: stok karti / varyant barkodu Erp_InventoryBarcode'a

### 2. Yama paketi
- **Komutlar:** `deploy\yayinla.ps1` (Windows PowerShell'de çıktı `*>` ile yönlendirilirse vite uyarısı hata sayılıp durur —
  yönlendirmeden çalıştır). Yama = `SentezServis.exe` + `wwwroot` + `KURULUM.txt`.
- **Sonuç:** `SentezServis-yama-2026-11-15-barkod.zip` (76,6 MB, repo kökü, git'e girmez). 10.11 koli listesi değişikliklerini de içerir.

## Açık kalanlar
- Sunucuya kurulum + appsettings `BarkodYazmaAcik`, `KoliListeSentezKullaniciId` (kullanıcıyla).
- İlk barkodlar: T-KMS-001, T-AKS-001, T-IPL-001 varyantları.

## Ek (00:05, 16.11) — yerelde çalıştırma
- **Neden:** Kullanıcı barkod ekranını hemen kullanmak istedi ("sentez servisi direk çalıştır, 0.2'de mssql"). Docker denemesi gereksizdi, kaldırıldı.
- **Ne yapıldı:** `src/SentezServis.Host/appsettings.json` (gitignore'da): BaglantiCumlesi = 192.168.0.2 / SentezServis,
  SentezCoreBaglantiCumlesi = 192.168.0.2 / SentezCore (uzman), `ArkaPlanKapali: true`, `BarkodYazmaAcik: true`,
  `KoliListeSentezKullaniciId: 1`, TabanAdres http://localhost:8563.
- **Kod:** yeni ayar `SentezServis:ArkaPlanKapali` → ZamanlayiciServisi, BildirimDagiticiServisi ve açılıştaki
  HayaletleriKapatAsync çalışmaz (canlı DB'ye bağlı ikinci kopya iş/e-posta tekrarlamasın, canlıdaki süren çalıştırmalar kapanmasın).
  Canlı sema_surumleri 018'de; bekleyen göç yok.
- **Komut:** `cd src/SentezServis.Host && dotnet run --launch-profile SentezServis.Host --urls http://localhost:8563`
- **Sonuç:** `/api/surum` → derleme 55cbc76, `/barkod-tanimlari` 200. Giriş canlı SentezServis kullanıcılarıyla.
- **Commit:** `4fe02dd`
