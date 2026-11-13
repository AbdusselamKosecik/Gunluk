# Saas_erp — 2026-11-14

## Bağlam
E7 S3b-3a'nın UX post-check sonucu geldi: APPROVE-WITH-CONDITIONS. Bu turda koşul 3 kapatıldı.

## Yapılanlar

### 1. İrsaliye alt toplamında koli sayısı
- **Neden:**
  - Kurul UX koşulu 3 sayıyı istiyordu: karışık koli birden çok satırda olsa bile tek sayılmalı.
  - `distinctBoxCount()` yazılmış ve testlenmişti ama hiçbir ekran onu çağırmıyordu.
- **Ne yapıldı:**
  - Detay alt toplam paneline "Koli Sayısı" satırı eklendi (`data-testid=receipt-box-count`). Satır yalnız bağlı koli varsa görünüyor.
  - `summary.boxCount` 11 dilde (`b11.json`).
  - changelog 2026-11-14.
- **Dokunulan dosyalar:** `receipt_workspace.page.tsx`, `assets/i18n/*/b11.json`, `changelog.data.ts`
- **Komutlar:** wte32'de `npm run typecheck`, `npm run lint`, `npx vitest run --maxWorkers=2`, ardından `bash ship.sh wte32 e7box`.
- **Sonuç:** tip kontrolü ve lint temiz, vitest 497 dosya / 3837 test geçti. Yalnız ön yüz değiştiği için BE/PG koşulmadı.
- **Commit:** `cccd8c8aa` — fix(inventory): E7 S3b-3a irsaliye alt toplaminda distinct koli sayisi (kurul UX kosulu 3)

## Açık kalanlar
- **E7 Chrome yürüyüşü** veri bekliyor:
  - onaylı bir 5202 sipariş lazım (MİTO KONFEKSİYON);
  - her bedene ayrı satır, UE1'e bağlı;
  - sonra 390px ve dark modda tam akış yürünecek.
- **PO sorusu:** varyantsız bir sipariş satırı (bedenler alt satırda) 3052'ye varyantsız düşerse karışık kolilerin hepsi "Satır yok" görünür. Transferin bedenleri satıra açıp açmadığı doğrulanmalı.
- **UX küçükleri:**
  - satır seçicideki radyolar diyalog açıklamasının içinde duruyor (ekran okuyucu sorunu);
  - bağlanamayan kolinin mesajı genel kalıyor.
- **prodread:** CTO ve Skeptic kurulu bekliyor.
- **DEV:** hâlâ 1.0.2.1201. `0f298e542` ve `cccd8c8aa` DEV'de değil.
