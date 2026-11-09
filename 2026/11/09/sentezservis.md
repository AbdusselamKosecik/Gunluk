# sentezservis — 2026-11-09

## Bağlam
Dün yazılan `TrendyolFaturaKontrol.exe`'de bölünmüş siparişler (birden çok etkin paket) "elle bakılmalı" diye atlanıyordu. Kullanıcı şunu bildirdi: "her siparişin faturası CRS'de farklı". Yani bölünmüş siparişte her paket için Sentez'de ayrı bir fatura (ayrı ETTN) kesiliyor.

## Yapılanlar

### 1. Veri keşfi (yalnız SELECT)
- **Neden:** Faturanın hangi pakete ait olduğunu bulmak.
- **Yöntem:** Scratchpad'deki `q.ps1` betiği. Bağlantı cümlesini servisin appsettings dosyasındaki salt okur `ErpBaglantiCumlesi` ayarından çalışma anında okuyor, ekrana yazmıyor. SqlClient + DataTable ile çalışıyor.
- **Bulgular:**
  - Aynı `MarketPlaceOrderNo` ile birden çok 121 fişi var ve her birinin ETTN'si farklı. Bölünme şirketler arasında da oluyor; örneğin sipariş 11789921627'nin bir paketi şirket 03'ten, öbürü 04'ten faturalanmış.
  - Fişi pakete bağlayan alan `Erp_InventoryReceipt.UD_CargoBarcode`. Bu, Trendyol paketinin `cargoTrackingNumber` alanına eşit (`UD_KargoTakipNumarası` da aynı değeri tutuyor).
  - Ekim'den bu yana yaklaşık 15.900 paket var. Bunların 83'ünde aynı pakete birden çok fatura kesilmiş. Barkodsuz fiş yok.

### 2. Kod
- `TrendyolPaketi` kaydına `KargoTakipNo` eklendi; `cargoTrackingNumber` alanı sayı da metin de olsa okunuyor.
- `PaketKarari.Ver(paketler, kargoBarkodu, ayniPaketFisSayisi)` kuralları:
  - Aynı pakette birden çok fatura varsa: Atla. Trendyol paket başına tek dosya kabul ediyor.
  - Barkodun paketi bulunduysa: paket iptalse Atla, faturalıysa ZatenVar, faturasızsa o pakete Yükle.
  - Barkod hiçbir pakete uymuyorsa: tek paket olsa bile Atla.
  - Barkod boşsa: eski kural uygulanıyor (tek etkin paket varsa yükle, yoksa atla).
- `FaturaAdayDeposu` aday sorgusu:
  - İlk denenen bağlı alt sorgu (`COUNT ... WHERE MarketPlaceOrderNo = ...`) index olmadığı için **120 sn zaman aşımına** düştü.
  - Sorgu CTE ile yeniden yazıldı. `COUNT(*) OVER (PARTITION BY sipariş, barkod)` sayımı `ReceiptDate >= başlangıç - 15 gün` penceresiyle sınırlandı. Sorgu artık saniyeler içinde dönüyor.
- 6 yeni test eklendi; toplam 777 test geçti.
- README güncellendi.
- **Dokunulan dosyalar:**
  - `src/SentezServis.Core/Fatura/TrendyolPaketKarari.cs`
  - `src/SentezServis.Core/Pazaryerleri/Saglayicilar/TrendyolSaglayici.cs`
  - `src/SentezServis.TrendyolFatura/FaturaAdayDeposu.cs`
  - `src/SentezServis.TrendyolFatura/TrendyolFaturaKontrolcusu.cs`
  - `src/SentezServis.TrendyolFatura/README.md`
  - `tests/SentezServis.Core.Tests/TrendyolPaketKarariTestleri.cs`

### 3. Canlı kuru deneme
- **Ayar:** `BaslangicTarihi = 2026-11-06`, `TurBasinaAzami = 1500`. Komut: `--kuru --bir-kez`. Deneme bitince test ayarları geri alındı.
- **Sonuç:** 1500 fiş işlendi (852 sn); 01'den 4, 03'ten 37, geri kalanı 04'ten.
  - 1465 fişte barkod Trendyol paketine uydu ve paket faturalıydı ("zaten var").
  - 21 fişin paketi Trendyol'da `Cancelled` olduğu için atlandı.
  - 14 fiş (7 paket) "aynı pakete 2 fatura" olduğu için atlandı.
  - Barkod uyuşmazlığı **0**, hata 0.
- Bölünmüş sipariş 11789921627'de şirket 04'ün fişi kendi paketine (4310582421) eşlendi.

### 4. Paket
- `TrendyolFaturaKontrol-2026-11-09.zip` repo kökünde (exe, README, örnek ayar dosyası, sql). Commit edilmedi.
- **Komut:** `dotnet publish src/SentezServis.TrendyolFatura -c Release -o yayin-trendyol-fatura`; ardından README, ayar örneği ve sql/ kopyalanıp Compress-Archive ile sıkıştırıldı.
- **Commit:** `c043caf` — Trendyol fatura: bolunmus sipariste fis pakete kargo barkoduyla eslenir

## Kararlar
- Fiş pakete sipariş numarasıyla değil, kargo barkoduyla bağlanıyor. Barkod uymazsa yanlış pakete yüklemek yerine atlanıyor.
- Aynı pakete iki fatura kesildiyse fiş atlanıyor; hangisinin yükleneceğine elle karar verilecek.

## Açık kalanlar / sonraki adım
- Kullanıcı SSMS'te `UZM_E_ReceiptCheckOK.sql` dosyasını çalıştıracak ve yazma yetkili `appsettings.json` hazırlayacak.
- İptal edilen paketlerin fişleri ve aynı pakete iki fatura kesilmiş fişler hiç işaretlenmiyor; 30 dakikada bir yeniden loglanıyorlar. İstenirse iptal paket "işaretle" ya da "ayrı kolon" olarak ele alınabilir.
- Trendyol `orders` ucundan `v2/orders` ucuna geçiş.
