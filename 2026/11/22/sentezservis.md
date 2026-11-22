# sentezservis — 2026-11-22

## Bağlam
Siparişten order (Erp_WorkOrder) oluştururken numaralar `Test-001`, `Test-005-1/-2` biçimindeydi.
İstek: baştaki TEST kalksın, Sentez'de sırada ne varsa öyle gitsin; -1/-2 alt numaralar esas alınmasın.

## Yapılanlar

### 1. Work order numarası Sentez sırasından devam eder
- **Neden:** Gerçek Sentez iş emirleri düz sayı (son: 4548–4550). Test- öneki geliştirme dönemi kalıntısıydı.
- **Bulgu (SentezCore, salt okuma):** Sayaç/numara tablosu yok. Düz sayısal en büyük numara 8501 (elle
  girilmiş, sıra dışı); 4823, 4837-x gibi aykırılar da var. Sentez'in kendi akışı "en son eklenen + 1"
  (4547 → 4548). Bu yüzden MAX değil, RecId'e göre en son eklenen düz sayı esas alındı.
- **Ne yapıldı:**
  - `WorkOrderNumarasi.Onek` kaldırıldı; `DuzSayi(no)` (yalnız rakam) eklendi.
  - `Sonrakiler(mevcut, adet)`: mevcut RecId azalan sırada; ilk düz sayı + 1'den başlar, birden fazla
    work order ardışık tam numara alır (4551, 4552 …), mevcutta olan numara atlanır. Hiç yoksa 1.
  - `SiparisDeposu.MevcutNumaralarAsync` sorgusu:
    `WHERE CompanyId=@SirketId AND WorkOrderNo<>N'' AND WorkOrderNo NOT LIKE N'%[^0-9]%' ORDER BY RecId DESC`
    (kayıtta UPDLOCK/HOLDLOCK korunuyor).
- **Dokunulan dosyalar:** `src/SentezServis.Core/Siparis/WorkOrderToplayici.cs`,
  `src/SentezServis.Core/Siparis/SiparisDeposu.cs`, `src/SentezServis.Host/Api/SiparisUclari.cs` (yorum),
  `tests/SentezServis.Core.Tests/SiparisWorkOrderTestleri.cs`, `tests/SentezServis.Core.Tests/SiparisDeposuCanliTestleri.cs`
- **Komutlar:**
  ```bash
  dotnet test tests/SentezServis.Core.Tests --filter "FullyQualifiedName~SiparisWorkOrder"
  SENTEZCORE_TEST="<bağlantı>" dotnet test tests/SentezServis.Core.Tests
  ```
- **Sonuç / doğrulama:** 357 testin 355'i geçti. Canlı önizleme testleri geçti. Başarısız 2 test
  (`KarmaKoliTestleri.SentezCore_yazmasi_yalnizca_UZM_KarmaKoli_tablolarina`,
  `KoliListeDeposuCanliTestleri.Kullanicinin_ornegi_...`) değişiklikten önce de başarısızdı (git stash ile teyit).
- **Commit:** `78184d6` — Siparis -> order: work order numarasinda Test- oneki kalkti, Sentez sirasindan devam eder

### 2. 0.2 (MODFEXSRV) sunucusu HEAD'e güncellendi
- **Neden:** Kullanıcı istedi ("0.2'ye günceller misin"). Sunucuda `75a0800` (10.11 koli listesi) çalışıyordu;
  güncelleme 55cbc76 barkod tanımları, 4fe02dd ArkaPlanKapali, 2623d79 üretim raporları ve 78184d6 numara
  değişikliğini birlikte götürdü. Yeni SQL betiği yok; `ArkaPlanKapali` varsayılanı false (sunucu ayarında yok → arka plan çalışır).
- **Ne yapıldı:** `deploy/yayinla.ps1` ayrı `powershell.exe` sürecinde (Vite stderr uyarısı yüzünden) → `yayin/` (18 dosya).
  `uzaktan-yayimla.ps1` Get-Credential istediği için aynı adımlar elle yapıldı (geliştirme makinesinin oturumu
  `\192.168.0.2\C$` ve `sc.exe \192.168.0.2`'ye zaten yetkili):
  1. Servis klasörü `sc qc` ile: `C:\Server\SentezServis` (D:\UzmanAdres değil).
  2. Yedek: `C:\Server\SentezServis\yedek-2026-11-22-75a0800\` (exe, appsettings.json, wwwroot).
  3. `sc stop` → 18 dosya kopyala → `sc start`. Pakette appsettings.json yok; sunucudaki korundu (tarihi 10.11, değişmedi).
- **Komutlar:**
  ```powershell
  Start-Process powershell.exe -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','deploy\yayinla.ps1' -Wait
  sc.exe \192.168.0.2 stop SentezServis ; <yayin\* -> \192.168.0.2\C$\Server\SentezServis> ; sc.exe \192.168.0.2 start SentezServis
  Invoke-WebRequest http://192.168.0.2:81/api/surum
  ```
- **Sonuç / doğrulama:** `/api/surum` → `derleme 1.0.0+78184d6`, arayuzTarihi 2026-11-22 17:50 (UTC); `/` 200.
- **Geri dönüş:** servisi durdur, yedek klasöründeki exe + wwwroot'u geri kopyala, başlat.

## Kararlar
- Esas = en son eklenen düz sayısal numara (MAX değil), çünkü elle girilmiş 8501 sırayı 8502'ye atlatırdı.
- Alt numaralı (`4284-5`) ve harfli (`Test-005`, `NZR-2277`, `TEST01`) numaralar sıraya girmez.

## Açık kalanlar / sonraki adım
- Sentez ekranından elle büyük bir düz sayı (ör. 9000) girilirse sıra oradan devam eder — Sentez'in kendi davranışıyla aynı.
- Önceki 2 kırık test ayrıca incelenmeli.
- `uzaktan-yayimla.ps1`ye mevcut oturumla (Get-Credential istemeden) çalışan bir seçenek eklenebilir.
