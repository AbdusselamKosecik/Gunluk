# sentezservis — 2026-10-27

## Bağlam
Kullanıcı `2026 1-6 İND. ORAN SATIŞ (003).xls` (GİB KDV iadesi "İndirimli Oranda Satışlara İlişkin Satış
Faturası Listesi", 2.156 fatura satırı, Downloads'ta) dosyasını sentezservis'e yükleyip boş duran
"Satılan Mal ve/veya Hizmetin Cinsi" ve "... Miktarı" sütunlarını doldurmak istedi. Cinsi = malzeme kartı
kategorileri tekrarsız, `+` ile (ARASIN + MAYO + BAYAN); Miktarı = toplam adet.

## Yapılanlar

### 1. Şema tespiti (canlı ERP'ye erişim yoktu)
- **Neden:** 192.168.1.3 ping veriyor ama 1433 kapalı (VPN üzerinden, Test-NetConnection False).
- **Ne yapıldı:** Sentez DLL'lerinde UTF-16 dize taraması (`X:\GitHub\Sentez-Core\Dlls\InvoiceRprModule.dll`).
  Sentez'in kendi "İndirimli Oranda Satışlar" raporu (#DiscountRateSalesTmp) bulundu:
  - Listedeki numara = `Erp_Invoice.DocumentNo` (boşluk varsa öncesi seri, atılır).
  - Kalemler: `Erp_InventoryReceipt.InvoiceId = inv.RecId` → `Erp_InventoryReceiptItem` (`Quantity`, `VatRate`,
    `InventoryId`, `ServiceCardId`). **`Erp_InvoiceItem` diye tablo yok.**
  - Sentez raporu cins olarak `Erp_InventoryGroup.GroupName` kullanıyor; biz kullanıcı isteğiyle
    `Erp_Category.CategoryName` (Inventory.CategoryId), boşsa grup, hizmette `Erp_Service.ServiceName`.
- **Komut (DLL dize çıkarma):** python ile dosyayı `utf-16-le` decode edip regex.

### 2. Backend
- **Dokunulan:** `src/SentezServis.Core/Fatura/IndirimliOranListesi.cs` (NPOI ile aç, başlıkları metinden bul,
  satırları oku, Ozetle, yaz, kaydet), `IndirimliOranDeposu.cs` (salt okunur ERP sorgusu, 1000'lik öbek),
  `src/SentezServis.Host/Api/IndirimliOranUclari.cs` (`POST /api/indirimli-oran/doldur`, multipart dosya+sirketId,
  JSON yanıt: özet + satır durumları + base64 dosya), `Program.cs` (DI + uç kaydı).
- **Kurallar:** yalnızca satırdaki KDV oranındaki kalemler (karma faturada %20 kalem %10 satırına girmez);
  tekrar kontrolünde büyük/küçük harf, boşluk ve I/ı/İ/i farkı yok sayılır (tr-TR'de ARASIN≠arasin olduğu
  için gerçek dosya denemesinde yakalandı, düzeltildi); iptal faturalar hariç.

### 3. Paketler
- NPOI 2.8.1 "OSMF EULA" onayı istiyor → **2.7.6 (Apache-2.0)**. O da ImageSharp 2.1.x getiriyor (yamasız
  yüksek açıklar) → kullanıcı kararı: `Directory.Build.props`'ta 5 GHSA `NuGetAuditSuppress`, gerekçeli.
  ImageSharp 2.1.13'e, System.Security.Cryptography.Xml 10.0.13'e sabitlendi.
- Toplayici'de Pkcs 9.0.11 denetim hatası Host derlemesini durduruyordu (önceden var) → 10.0.13'e sabitlendi.

### 4. Web
- `web/src/api/indirimliOran.ts`, `pages/IndirimliOranSayfasi.tsx` (+test), rota `/indirimli-oran`,
  menü Operasyon → "İndirimli oran listesi". Şirket seç → dosya seç → doldurulan dosya otomatik iner,
  eksik satırlar tabloda.

### 5. Belge
- `docs/indirimli-oran-listesi.md`.

- **Sonuç / doğrulama:** `dotnet test` 713/713, `vitest` 75/75, `npm run build` temiz, Host build OK.
  Gerçek dosya sahte kalemlerle dolduruldu (scratch konsol projesi): xlrd ile karşılaştırma — H/I dışında
  0 hücre/biçim farkı, iki sayfa duruyor, birleşik hücreler ve sütun genişlikleri aynı.
- **Commit:** `809183b` — Indirimli oran listesi: KDV iadesi listesinin Cinsi/Miktari sutunlarini ERP kalemlerinden doldur

## Kararlar
- Çıktı aynı dosya biçimi (.xls → .xls); yeni sayfa eklenmez (GİB yüklemesini bozmasın).
- Yanıt JSON + base64 dosya: tek istekle hem eksik listesi hem dosya; sunucu dosya saklamaz.
- Şirket seçimi zorunlu (diğer fatura ekranları gibi).

## Açık kalanlar / sonraki adım
- **Canlı ERP'de denenmedi.** İlk kullanımda "Fatura bulunamadı" sayısına bak: yüksekse liste numarası
  DocumentNo'da değil demektir (ReceiptNo yedeği var).
- Paket sunucuya kurulmadı (bkz. 6).

## Ek — 6. Paket
- **Neden:** Kullanıcı paket istedi.
- **Ne yapıldı:** `git status`: src/web'de commit edilmemiş değişiklik yok (yalnız docs altında ilgisiz dosyalar),
  çalışma klasörü = HEAD `809183b`. Paket çalışma klasöründen çıkarıldı.
- **Komutlar:**
  ```bash
  powershell -NoProfile -ExecutionPolicy Bypass -File deploy/yayinla.ps1
  powershell -NoProfile -Command "Compress-Archive -Path yayin\* -DestinationPath SentezServis-2026-10-27-indirimli-oran.zip -Force"
  ```
- **Sonuç / doğrulama:** `SentezServis-2026-10-27-indirimli-oran.zip` (80 MB), arayüz tarihi 2026-10-27 12:12.
  appsettings.json çıkarıldı, örnek bırakıldı (30 değer boşaltıldı). 20.10 paketiyle karşılaştırma: dosya listesi
  aynı (tek dosya exe, NPOI içinde; exe 201→211 MB), app.js rota sayısı 32→33, eksilen yok, yeni yalnız `/indirimli-oran`.
- **Kurulum:** sunucuda `servis-kur.cmd "D:\UzmanAdres\SentezServis" 81`; sonra `/api/surum` → arayuzTarihi 2026-10-27 12:12.
  Yeni ayar anahtarı yok (mevcut ERP bağlantısını kullanır), sunucu appsettings'ine dokunmak gerekmez.
- Zip depoya commit edilmedi (önceki zip'ler gibi izlenmiyor).
