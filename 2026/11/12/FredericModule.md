# FredericModule — 2026-11-12

## Bağlam
UPC Barkod Aktarımı ekranı (11.11) kullanıcı tarafından gerçek "UPC yeni.xlsx" ile deneniyor.

## Yapılanlar

### Kart bulunamadı hatası — tür filtresi ve firma kimliği
- **Neden:** Kullanıcı: "UPC yeni.xlsx icin model karti bulunamadi diyor... sadece diger inventoryde model olmasi sart degil".
  `FindModelSql` `InventoryType=6 AND InventorySubType=1` şartı koyuyordu; ayrıca firma `bo.CompanyId ?? 0` idi (Get öncesi boş → 0).
- **Ne yapıldı:** `Bussines/UpcTransfer/UpcTransferService.cs`: arama `where CompanyId=@CompanyId and InventoryCode=@Code` (tek sonuç şartı duruyor);
  firma `SysMng.Instance.getSession(SysMng.Instance.ActivatedSID).ActiveCompany.RecId` (BulkTransfer ile aynı, `using Sentez.Common.Commands`),
  yedek `bo.CompanyId`. Bulunamazsa mesaj: kod + firma + kod başka firmada varsa firma id'leri (`OtherCompanySql`).
- **Doğrulama:** scratch kopyada `dotnet build` 0 hata. Canlıda tekrar deneme kullanıcıda.
- **Commit:** `58da41f` — UPC aktarim: kart aramasinda tur/alt tur sarti kaldirildi, firma oturumdan

## Açık kalanlar
- Varyant eşleşmesi (renk=Variant1 ItemCode, beden=Variant2 ItemCode) gerçek kartta doğrulanmadı; "Varyant yok" çıkarsa UpcCodeMapper gerekir.
