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

### 3. İnceleme: 2. tamir turunda Yıkama-Tamir girişi yapılamıyor (QR `193693877575,5,122094`)
- **Neden:** Kullanıcı bildirimi: Finish-Tamir çıkışı yapılmış seri Yıkama-Tamir girişine alınamıyor.
- **Veri (WorkOrderItemId 78462, SentezLive):**
  - 1. tur: 757/2 palet `T-757-74-261100029` (23.11) → 758/1 → 758/2 `T-758-73-261100083` → 757/1 (24.11).
  - 2. tur: 757/2 palet `T-757-74-261100036` (25.11 09:30) 14 seri: 94,74,85,96 / 5,19,13,2 / 211,220 / 156 / 296 / 266 / 242,246 / 131,124 / 51,60.
  - 758/1 `…036` (25.11 10:52): sadece 60,220,2,124,96 girebilmiş = 1. tura hiç girmemiş seriler. 1. turda tamir görmüş serilerin hiçbiri girememiş.
- **Kod analizi:** f6fb34d (çoklu tamir) sonrası akış bu senaryoya izin veriyor: kaynak eşleşmede seçili palet tercih ediliyor, `CanReadTamirAgain` 5 için okutma=1 < kaynak=2. `LiteDbProcess.SaveAndRemoveSentez` seri reddetmiyor.
  f6fb34d öncesi kod: `variants.FirstOrDefault` → eski palet (`…029`) seçilir → "…029 Paletinin Kaydi, …036 Paleti ile giris yapamazsiniz!!" ya da "Daha once okutulmus!". Desen eski sürümle birebir uyumlu.
- **Sonuç:** Kod değişikliği yapılmadı. Muhtemel neden: Yıkama-Tamir PC'sinde (kullanıcı 73) f6fb34d öncesi sürüm çalışıyor. Doğrulama için ekrandaki hata mesajı istendi.

## Açık kalanlar (ek)
- Yıkama-Tamir PC'sindeki sürümü kontrol et; `fredericpiecework-paket-2026-11-17-f6fb34d.zip` kurulu mu?
- Kurulu ise ekrandaki hata mesajıyla tekrar incele.

### 4. Dağıtım paketi (1169b64)
- **Neden:** Yıkama-Tamir PC'sine çoklu tamir düzeltmesini (f6fb34d) içeren güncel sürümü kurmak.
- **Komutlar:**
  ```bash
  rm -rf bin/Release/net6.0-windows/publish/win-x64
  dotnet publish FredericPieceWork.csproj -p:PublishProfile=FolderProfile
  # PowerShell: Compress-Archive publish\win-x64\* -> X:/Gitlab/fredericTr/fredericpiecework-paket-2026-11-26-1169b64.zip
  ```
- **Sonuç / doğrulama:** 9 dosya, zip 32.9 MB. exe içinde "tamir turu icin yeni palet", "bu tamir adiminda zaten okutulmus", "paletinde zaten var" metinleri var; "Seri / QR Takip" yok (ayrı projeye taşındı).
  Not: UTF-16 metin araması bayt hizasına bağlı; tek hizada arayınca yanlış negatif verdi, iki hizada da aranmalı.
  İşlevsel olarak f6fb34d paketiyle aynı (bugünkü piecework değişikliklerinin net etkisi sıfır).
- **Kurulum:** Hedef PC'de .NET 6 Desktop Runtime; mevcut kurulumun `Frederic\` klasörü (parameter.json, computer*.json) korunmalı, sadece zip içeriği üzerine yazılmalı.
