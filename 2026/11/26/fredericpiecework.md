# fredericpiecework — 2026-11-26

## Bağlam
İstek: QR okutulunca parçanın hangi operasyonlardan ve hangi paletlerle geçtiğini gösteren bir alt program.

## Yapılanlar

### 1. Seri / QR Takip ekranı
- **Neden:** Tek bir parçanın üretim geçmişini (operasyon + palet) görmek.
- **Ne yapıldı:** Yeni salt-okuma form `SeriTakip`. QR biçimi `barkod,seriNo[,isEmriId]` (Form1.ReadBarcode ile aynı).
  1. `Erp_InventoryBarcode` → barkoddan `InventoryVariantId` + ürün/renk/beden.
  2. `Erp_WorkOrderProduction` (ProductionType=2, SubType=0) içinde `','+UD_Number+','` LIKE `'%,seri,%'`,
     isEmriId varsa `WorkOrderId` filtresi, `Erp_WorkOrderProductionVariant`→`Erp_WorkOrderItemVariant` üzerinden
     aynı `InventoryVariantId` şartı (EXISTS). Sıra: StartProductionDate, InsertedAt, RecId.
  3. Palet = `p.Cutter`. Operasyon adları: 11 YIKAMA, 12 KESIM, 13 FINISH, 15/22 DIKIM, parametrelerdeki
     YikamaId/FinishTamirId → YIKAMA-TAMIR/FINISH-TAMIR. Kalite: InOutType 1 Saglam, 2 2K, 3 Numune, diğer 3K.
  4. Son satır yeşil (şu anki yer), durum satırında ardışık tekrarları atılmış "palet yolu".
  5. Form1 sağ tık menüsüne "Seri / QR Takip" eklendi.
- **Dokunulan dosyalar:** `SeriTakip.cs`, `SeriTakip.Designer.cs`, `Form1.cs`, `Form1.Designer.cs`
- **Komutlar:** `dotnet build` → başarılı, yeni dosyalarda uyarı yok.
- **Sonuç / doğrulama:** Derleme temiz. Gerçek ERP veritabanında çalışma zamanı testi yapılmadı.
- **Commit:** `8021687` — Seri / QR Takip ekrani: okutulan parcanin operasyon ve palet gecmisi

## Kararlar
- Virgülle çevrelenmiş LIKE: "12" aranırken "112"/"120" eşleşmesin diye.
- Saat bilgisi kaydın oluşturulma saati (`InsertedAt`); kayıtlar gün/kullanıcı bazında toplandığı için parçanın tam okutma saati değil.
- Silinen okutmalar UD_Number'dan çıkarıldığı için geçmişte görünmez (iz tutulmuyor).

## Açık kalanlar / sonraki adım
- Proses ID → ad eşlemesini (özellikle 12 ve 22) kullanıcı doğrulamalı.
- Kullanıcı adı yerine şimdilik InsertedBy ID gösteriliyor.
- Sahada gerçek QR ile test.

### 2. Seri / QR Takip ayrı projeye taşındı
- **Neden:** Kullanıcı ekranı ayrı bir program olarak istedi.
- **Ne yapıldı:** `SeriTakip.cs`/`.Designer.cs` silindi, `Form1.cs`/`Form1.Designer.cs` `git checkout HEAD~1 --` ile özellik öncesine döndürüldü (menü kaldırıldı). Kod `fredericTr/seritakip` reposuna taşındı (bkz. `seritakip.md`).
- **Sonuç / doğrulama:** `dotnet build` başarılı.
- **Commit:** `1169b64` — Seri / QR Takip ekranini ayri projeye tasi (fredericTr/seritakip)
