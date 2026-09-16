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
