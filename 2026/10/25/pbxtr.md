# pbxtr — 2026-10-25

## Bağlam
Santral epiği (Sprint-46..49) sürüyor. Sprint-46 kapalı; gün Sprint-47 QA-128 ölçümünün ortasında başladı (oturum kopmuştu).

## Yapılanlar

### 1. Sprint-47 QA-128 tamamlandı ve kapanış
- **Neden:** Faz B1 (yakalama, yönlendirme, sesli mesaj, özellik kodları) gerçek santralde ölçülmeden kapanmaz.
- **Ne yapıldı:** Kopan QA ajanı SendMessage ile devam ettirildi. Ajan bir hata buldu: ön nginx 8443 mTLS kuralı `feature-code` ucunu taşımıyordu → telefondan `*72` vb. hep `FC_UNAVAILABLE`/beeperr. Düzeltme `4fe67e7f` (8443 kuralına uç eklendi, panel portunda 404, `nginx-dogrula.sh` bekçisi artık `MapPost(Route, …)` sabitini de okuyor; 3 mutasyon kırmızı).
- **Yayın:** ilk deneme `npipe dockerDesktopLinuxEngine` hatasıyla düştü — Docker Desktop kapalıydı. Yol `C:\Users\abdus\AppData\Local\Programs\DockerDesktop\Docker Desktop.exe` (Program Files'ta DEĞİL). Açıldıktan sonra `deploy/yerel-yayin.sh --yayinla --testsiz` → `demo-4fe67e7fd51d`; `nginx/current/conf.d/pbxtr-telefon-8443.inc` içinde `feature-code` doğrulandı.
- **Sonuç:** QA-128 10/10. Yayınlanmış config ile yeniden: `*72` kural + `PBXTR_FWD_*` global, WebSocket `extension.settings.changed` (sahip oturumu, `/api/v1/ws`) aynı milisaniyede, `*90` dış hedef → call-permission `BLOCKED_IYS`, internal sınıf `FC_EXTERNAL_NOT_ALLOWED`, `*78/*79` DND. Temizlik: tablolar 0, override kaldırıldı, t0007 config md5'leri baseline ile aynı (6 dosya). Silinemeyen: boş değerli `PBXTR_FWD_T0007_1042`/`ZZQA_MODE` globalleri (Asterisk 22'de restart'sız silinmiyor; boş değer "yok" sayılıyor).
- **Bulgu → kart:** `BR-AST-148` (P3, Açık): `*79` bir config çekimine kadar (~15 sn) etkisiz; statik katman `Goto(busy)`.
- **Backlog/ClickUp:** 9 kart Bitti; `--kuru` fark 0 / izde olmayan 0. **Commit:** `495c119b`.

### 2. Sprint-48 başlatıldı
- backend-dev-2: outbound_routes, giden rota, acil numaralar (P0; sahte `19999` ile ölçülecek, gerçek 112 aranmaz), iç kayıt, rehber + hızlı arama, BLF.

## Kararlar
- `*79` penceresi kabul edildi (iki katman modeli + S76-12a negatif testi); çözüm DND değişiminde anında rerender — P3.
- Agent rolünün telefondan `*72` yapabilmesi kabul: özellik kodu dahiliye bağlıdır, role değil.

## Açık kalanlar / sonraki adım
- Sprint-48 → FE-144/145 → yayın → QA-129; ardından Sprint-49.
