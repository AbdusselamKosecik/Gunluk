# depo — 2026-10-17

## Bağlam
Kullanıcı hammadde mal kabulünün serili yapılmasını istedi:
- El terminaliyle kabul, her ürüne yeni Sentez seri numarası, aksesuarlar dahil; etiket basılıp yapıştırılacak.
- Masaüstünde onay; onaysız seri kesime ya da konfeksiyona verilemez.
- Gelen malın amacı kaydedilecek (müşteri order'ı ya da stok); müşteri amaçlıysa Sentez tahsis sistemiyle o order'a tahsis.
- Çıkış serili olacak; seri yoksa otomatik seri, tahsis yoksa otomatik tahsis.
- İzlenebilirlik: hangi seri hangi order'a tahsis edildi, ne kadar kullanıldı, ne kadar gönderildi.

Kullanıcı bir plan istedi.

## Yapılanlar

### 1. Araştırma (canlı DB kapalıydı: 100.119.104.122:1433 erişilemedi)
- **depo bugün:** yalnız UZM_ tablolarına yazıyor. Sentez fişi, seri ve tahsis yok. Lot serbest metin. Android projesi şablon halinde.
- **Hazır parçalar:**
  - ZPL etiket: paketleme `ZplEtiket` / `ZplYazici`.
  - Sentez fiş yazıcı: paketleme ve sevkiyatmobil `FisSql` / `FisYazici` (applock, `OUTPUT INTO`).
  - Android 6 shim: sevkiyatmobil.
  - DbFact + ROLLBACK testleri.
- **Sentez seri ve tahsis şeması**, `mitotr/MitoSentezApi` EF modellerinden ve gerçek koddan çıkarıldı:
  - `Erp_InventorySerialCard`, `…SerialTransaction` (fiş satırına `ReceiptItemId` ile bağlanıyor), `…SerialCardTotal` (tetikleyici tutuyor olmalı).
  - `Erp_InventoryAllocation` (`RequirementId`, `WorkOrderItemId`, `InventoryReceiptItemId`, `SerialCardId`).
  - Doğrudan SQL ile seri yazan örnek: `X:\GitHub\vuo-app\...\ProductionReceiptWriter.cs:531-575`.
  - Tahsis SQL örneği: `X:\GitHub\Sentez-4\...\InventoryReceiptExtension.cs:466-505`.
  - Sarfta seri ve tahsisi birlikte yazan örnek: `Sentez-Core\...\InventoryReceiptSerialCardExtension.cs:201-336`.
  - `Erp_InventoryReceiptItem`'da SerialCardId kolonu yok.

### 2. Tasarım taslağı
- **Dosya:** `docs/superpowers/specs/2026-10-17-seri-kabul-tahsis-design.md`
- **Ana karar değişikliği:** 2026-10-06 tasarımı "Sentez fişi yazılmaz" diyordu. Seri ve tahsis Sentez'in kendi sistemiyle istendiği için
  artık Sentez'e satır yazılacak (kolon eklenmeyecek).
- **Akış:** kabul (terminal) → onay (masaüstü) + tahsis → serili çıkış (kilit, otomatik seri ve tahsis, 129 sarf) → iade → izlenebilirlik.
- **Yeni tablolar:** UZM_SeriKabul ve UZM_SeriKabulSatir. UZM_HammaddeHareket'e seri, fiş satırı, tahsis ve hedef kolonları eklenecek.
- **Kurallar:** SeriOnaysiz, SeriBaskaOrderda, SeriStokYetersiz, SeriBaskaMalzeme, KabulOrderGerekli, OnayliSilinemez.
- **Fazlar 0–5.** Faz 0, canlı DB doğrulaması: tetikleyiciler, SerialCode numaralama, Requirement doluluğu, satınalma fiş tipi,
  Sentez'de elle seri ve tahsis oluşturup karşılaştırma.
- **Kullanıcıya sorulacak 5 soru:**
  1. Giriş fişini kim yazıyor?
  2. Seri birimi ne?
  3. Onaysız mal karantina deposunda mı duracak?
  4. Etiket yazıcısı hangisi?
  5. Eski stok nasıl serilenecek?
- **Commit:** `acb93f5`

## Açık kalanlar
- Kullanıcının 9. bölümdeki soruları cevaplaması.
- DB erişimi gelince Faz 0.
