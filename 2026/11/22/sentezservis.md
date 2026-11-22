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

## Kararlar
- Esas = en son eklenen düz sayısal numara (MAX değil), çünkü elle girilmiş 8501 sırayı 8502'ye atlatırdı.
- Alt numaralı (`4284-5`) ve harfli (`Test-005`, `NZR-2277`, `TEST01`) numaralar sıraya girmez.

## Açık kalanlar / sonraki adım
- Sentez ekranından elle büyük bir düz sayı (ör. 9000) girilirse sıra oradan devam eder — Sentez'in kendi davranışıyla aynı.
- Önceki 2 kırık test ayrıca incelenmeli.
- Sunucudaki SentezServis yeniden yayımlanmalı (deploy bu turda yapılmadı).
