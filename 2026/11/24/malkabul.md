# malkabul — 2026-11-24

## Bağlam
Kullanıcı isteği: depo uygulamasına "seri değiştir" (seri okut → renk/miktar düzelt; serinin geçtiği fişlerdeki
InventoryReceiptItem ve varyant kayıtları da değişsin; gerekirse satır bölünsün/silinsin; kesim detayları korunsun) ve
serisiz ürünlerin sayım / üretime gönderim kontrolü.

## Yapılanlar

### 1. Keşif ve kararlar
- **Bulgular:** Kesim bilgileri seri kartında (Erp_InventorySerialCard: FabricWidth, FabricWeight, FabricShrinkageWidth/Height,
  FabricTurning, PartyNo, QualityControlId) → kart silinip açılmaz, yerinde güncellenir. Son 60 günde çoğu fiş kaleminde 1 seri, ama
  65 seriye kadar birleşik kalemler var. Sentez tetikleyicileri (ReceiptItem, ReceiptItemVariant, SerialTransaction; INSERT/UPDATE/DELETE)
  toplamları tutar: varyant satırının UPDATE'i eski satırı geri alıp yenisini uygular (renk değişimi + sipariş karşılama dahil);
  seri toplamı (EditInventorySerialCardTotalID) varyanttan bağımsız.
- **Kullanıcı kararları:** Yaklaşım A — miktar farkı yalnız üretim dışı fişlere (129/29 dokunulmaz), renk tüm fişlere; eski fişler
  yerinde düzeltilir; serisizde tahsis şartı kalkar.
- **Benim kararım (kodu okurken):** Mutlak değer yerine fark uygulanır — kısmen kullanılmış serinin sonraki transferi o an kalanı taşır.
- Spec: `docs/superpowers/specs/2026-11-24-seri-degistir-design.md`, plan: `docs/superpowers/plans/2026-11-24-seri-degistir.md`.
- **Commit:** `ec76d1b`

### 2. Seri değiştir veri katmanı
- **Dosya:** `MalKabul/Ekranlar/Veri/SeriDegistirDeposu.cs` (BilgiAsync, DegistirAsync), test `MalKabul.Tests/SeriDegistirTestleri.cs` (8 canlı, ROLLBACK).
- Kurallar: fark = yeni − kart; her 129/29 dışı hareket += fark (≤0 ya da seri kalanı < 0 → `SeriKalanEksiyeDuser`); kalem Quantity +
  tutar alanları oranla; tek serili kalemde varyant satırı doğrudan (renk + OrderReceiptItemVariantId yeni renkli sipariş satırına);
  paylaşımlı kalemde eski renk satırından düşülür (≤0 DELETE), yeni renk satırına eklenir / eski satır sys.columns ile kopyalanarak açılır.
  Tahsis: 129/29 satırlarının rengi güncellenir, ihtiyacı başka renk olan stok tahsisi IsDeleted=1.
- Kumaş topu kısmen verilemediği (TopBolunmez) için kısmi üretim testleri aksesuar serisiyle.
- **Commit:** `1c1b102`

### 3. Serisiz düzeltmeleri (arka plan incelemesi bulguları)
- `UretimDeposu.SerisizVerAsync`: tahsis şartı (MalzemeTahsisliDegil/TahsisFazla) kaldırıldı; ihtiyaç şart, sınır stok.
- `FisYazimi.YerParcalariAsync`: depodaki pozitif yer toplamlarından parça; serisiz verme ve `SayimKapat` her parçayı çıkış yeriyle ayrı kalem yazar.
- `UretimViewModel`: bağlantı kopunca `KayitBelirsiz`, seçim/miktar temizlenir (çift kayıt yok).
- Ertelenen (kullanıcıya bildirildi): tahsis ekranında serisiz tahsislerin sayılmaması, ana birim dışı ihtiyaçta otomatik tahsis sınırı.
- **Commit:** `fb83385`

### 4. Seri Değiştir ekranı
- `SeriDegistirViewModel` / `SeriDegistirView.axaml`, terminal menüsü ve masaüstü ana menüsü; metinler TR/EN/AR.
- Ekran görüntüsü testi `malkabul-18-seri-degistir.png` (EkranGoruntusuTestleri, MODFEX_TEST_CIKTI ile).
- **Commit:** `7f5ed6d`

## Doğrulama
```bash
dotnet run <scratchpad>/sqldene/sentestest.cs -- test MalKabul.Tests   # 291/291 (canlı DB, ROLLBACK)
dotnet build MalKabul.Desktop ; dotnet build MalKabul.Android          # ikisi de başarılı
```

### 5. Bağımsız kod incelemesi ve düzeltmeler
- **Bulgu 1 (önemli):** Fiyatlı fişte kalem tutarı ölçekleniyor ama başlık toplamı (SubTotal/GrandTotal) eski kalıyordu →
  dokunulan fiyatlı fişlerde `MalKabulFisDeposu.ToplamlariGuncelleAsync`. Test `Fiyatli_fiste_baslik_toplami_guncellenir` (1080≠1200 kırmızı → yeşil).
- **Bulgu 2 (önemli):** Seri aynı fişte birden çok parçada (sayım kapatma iki yer → iki 130 satırı) ise fark iki kez uygulanırdı →
  miktar değişimi `SeriParcali` hatasıyla engellenir (renk değişimi serbest). Test `Ayni_fiste_parcali_seri_degistirilemez`.
- **Bulgu 3 (küçük):** Renk satırı kopyası rowversion, Updated/Deleted ve birikim (Inflow/Outflow/Returned/QCRejected) alanlarını taşımaz.
- Tam set 293/293 (canlı, ROLLBACK).
- **Commit:** `7e2e11d`

## Açık kalanlar
- Dağıtım (Windows paketi + PM66 APK) yapılmadı — kullanıcı onayı bekleniyor.
