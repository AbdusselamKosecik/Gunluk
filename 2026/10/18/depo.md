# depo — 2026-10-18

## Bağlam
Tailscale'de modfexsrv (100.119.104.122) 3 gündür çevrimdışı. Kullanıcı: "0.2 den dener misin" → 192.168.0.2:1433 açık.
Kullanıcı bağlantı bilgilerini sohbette verdi. Şifre hiçbir dosyaya yazılmadı; paketleme ayarındaki DPAPI şifresi kullanıldı.
Scratchpad betikleri (`sorgu.ps1`, `sentez-test.ps1`) `MODFEX_SUNUCU` ortam değişkeniyle sunucuyu değiştirebiliyor.

## Yapılanlar

### 1. Seri/tahsis tasarımı — Faz 0 canlı bulguları (salt okuma)
- **Seri:** `Erp_InventorySerialCard` 50 satır, 2021 test kaydı (8 haneli `00000001`–`00000050`). `…SerialTransaction` 0 satır; sistem boş.
- **Seri stok toplamı:** `Erp_InventorySerialTransactionInsert` tetikleyicisi, ItemType 1/2/3/5/10/12/13 için
  `EditInventorySerialCardTotal` çağırıyor. Toplamı Sentez tutuyor, biz yazmayacağız.
- **Tahsis:** 2348 satır, hepsinde `RequirementId` + `WorkOrderItemId` dolu, `SerialCardId` hiç dolu değil.
  Dağılım: 1320 satınalma siparişinden, 910 tip 1 giriş fişinden, 38 tip 16'dan, 78 tip 129 sarftan.
- **İhtiyaç:** `Erp_Requirement` 97.099 satır; `WorkOrderItemId` dolu, `OrderReceiptItemId` boş.
- **Satınalma siparişi:** tip 1, 44 adet. Giriş fişleri az kullanılıyor (tip 1: 19 adet).
- **Sorgu yöntemi:** tetikleyici gövdesi `OBJECT_DEFINITION` ile okundu (scratchpad `tetik.ps1`).
- **Belge:** `docs/superpowers/specs/2026-10-17-seri-kabul-tahsis-design.md` §8.1
- **Commit:** bu commit (Faz 0 bulguları).

## Açık kalanlar
- Kullanıcının §9 soruları; en kritiği 1. soru (giriş fişini kim yazıyor).
- Kesimhane DB testleri ve `db/0002` betiği. Testler uygulama ayarındaki sunucuyu (100.119…) okuyor; ofis adresiyle çalıştırmak için
  ya ayar değişmeli ya da sunucu Tailscale'e dönmeli.
