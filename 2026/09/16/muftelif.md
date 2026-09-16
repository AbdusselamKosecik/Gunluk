# muftelif (Selvedge) — 2026-09-16

## Bağlam
Müşteri `Selvedge/doc/Hata1` klasörüne dosya bıraktı (PO066.PDF, PO012.pdf, 2332 BRYNN model PDF'i,
2 adet A7380 ARIS model PDF'i). Konu 2: PO 91760 (PO066 içinde, 2332 / WNWHT BRYNN) başka bir modelin
kartına bağlanıyor. Branch: `feat/sentez-planing-ayrimi`. Kod değişikliği yapılmadı — sadece teşhis.

## Yapılanlar

### 1. Parser çıktısı — Hata1 + Downloads\fw dosyaları
- **Ne yapıldı:** `tests/Selvedge.PdfImport.Tests` içine geçici `ZzHata1Dump` testi yazılıp
  `PoPdfParser` / `StylePdfParser` çıktıları basıldı, sonra dosya silindi.
- **Komut:** `dotnet test tests/Selvedge.PdfImport.Tests --filter ZzHata1Dump --logger "console;verbosity=detailed"`
- **Sonuç:** PO066 → 91754 `2321 / WNWHT`, 91759 `9293B / WNWHT`, 91760 `2332 / WNWHT` (+EXT), miktarlar
  PDF ile aynı. 2332 model PDF → StyleNo `2332`, WashCode `WNWHT` → model kodu `2332/WNWHT`.
  Parser tarafında yanlış eşleşme YOK.

### 2. Eşleştirme kodu incelemesi
- `CustomerOrderService.ImportSingleOrderAsync` → `ResolveStyleAsync`: tam eşleşme → `{base}/{wash}` →
  sadece base. Hepsi `==` karşılaştırma, çapraz model eşleşmesi mümkün değil.
- **Bulunan zayıf nokta:** `if (entity.StyleId is null) entity.StyleId = style.RecId;` — sipariş (OrderNo)
  daha önce yanlış modelle oluşmuşsa (elle web formu, PdfImports confirm akışı, eski import),
  PO'yu yeniden içeri almak bedenleri/tarihleri günceller ama MODELİ DÜZELTMEZ.
- Mobil "TP" popup (`style_pdf_popup.dart`) ve web listesi modeli doğrudan `order.StyleId`'den okuyor.

## Açık kalanlar / sonraki adım
- Canlı DB'de kontrol: `select o.RecId,o.OrderNo,o.StyleId,s.StyleNo,o.CreatedAt,o.UpdatedAt,o.SourcePdfId
  from sv_CustomerOrder o left join sv_Style s on s.RecId=o.StyleId where o.OrderNo='91760'`
  ve `select RecId,StyleNo,StyleName,IsDeleted from sv_Style where StyleNo like '2332%'`.
- Kullanıcı onaylarsa: PO import'ta StyleId'yi PDF'teki modele göre her zaman güncelle (+ test).

### 3. Kullanıcı teyidi + düzeltme: 91760 canlıda `2320-1904/CRM`'e bağlıymış
- **Neden:** Kullanıcı bildirdi: 91760 → `2320-1904/CRM`; olması gereken `2332/WNWHT`.
- **Teşhis (simülasyon):** Scratchpad'de `sim` konsol projesi (Selvedge.Infrastructure referansı +
  `Microsoft.EntityFrameworkCore.InMemory` 10.0.8). `SelvedgeDbContextAdapter` + sahte `IAttachmentService` ile
  gerçek `CustomerOrderService.ImportFromPdfAsync` PO066 üzerinde koşuldu.
  - Boş DB (4 model var): 91760 → `2332/WNWHT` (doğru). `2332/WNWHT` yoksa 91760 atlanıyor.
  - 91760 önceden `2320-1904/CRM` ile varken: ESKİ kod `2320-1904/CRM`'de bıraktı → hata birebir tekrarlandı.
- **Kök neden:** `ImportSingleOrderAsync` içinde `if (entity.StyleId is null) entity.StyleId = style.RecId;` —
  mevcut siparişte model hiç güncellenmiyordu. Sipariş ilk nasıl yanlış modelle oluştu bilinmiyor
  (web formundan elle giriş/düzenleme en olası yol; kod tarafında başka yazan yer yok).
- **Ne yapıldı:** `CustomerOrderService.cs` — marka/sezon atamasının yanına: `styleChanged` hesapla,
  `entity.StyleId = primaryStyle.RecId` her zaman; model değiştiyse BrandId/SeasonId de yeni modelden.
  Döngüdeki `if (entity.StyleId is null)` satırı kaldırıldı.
- **Doğrulama:** Aynı simülasyonda yeni kod 91760'ı `2332/WNWHT`'e taşıdı. `dotnet build src/Selvedge.Api -c Release`
  OK, `dotnet test tests/Selvedge.PdfImport.Tests` 33/33.
- **Commit:** `529d8f2` — fix(selvedge/po-import): PO yeniden import edilince siparis modeli PDF'teki modele guncellenir

## Açık kalanlar (güncel)
- Docker API imajı henüz build edilmedi (yeni sürüm bat'ı yok). Deploy sonrası müşteri PO066'yı tekrar yüklemeli
  → 91760 kendiliğinden `2332/WNWHT`'e geçer. Acil ise canlıda web formundan modeli elle değiştirmek de yeter.
- 91760'a bağlı QC raporlarında `sv_QaReport.StyleId` eski modelde kalmış olabilir (EnrichAuditCounts `??=`) — kontrol et.
