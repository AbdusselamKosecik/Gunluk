
### Provisioning / confd grubu (BR-AST-17, BR-AST-114, BR-AST-118, BR-BE-43-B)
- **Neden:** gece turu kartları; önce ölçüm, sonra küçük ve kesin kapanan kart.
- **BR-AST-17 (ölçüm, kod yok):** sunucu 176.88.41.220, 2026-09-24 23:55Z. `pjsip show endpoints` → `t0012-2011/2012/2013` endpoint+auth+aor (grep -c t0012 = 9); `queue show t0012-musteri-hizmetleri` 3 dinamik üye; son `PJSIP TESLIM KANITI YOK` uyarısı 22:59:26Z, 23:04:27Z `santralde eksik olan 3 kuyruk uyeligi eklendi`, sonrasında ~10 tick uyarısız; `NO_SUCH_QUEUE` 24 saatte 0; confd düğüm paketi `t0007/*` + `t0012/*` (pjsip dahil) revizyonlarını bildiriyor. Kartın dört kabul ayağı yeşil → bitti.
- **BR-AST-114 (b) hata düzeltmesi:** agent masasındaki failback şeridi `callSource 'callback'` metnini basıyordu ("arayan geri arama talebi bırakmıştı, bu çağrı onun dönüşü") — olanın TERSİ. Yeni anahtarlar `desk.queueReentry.failback` / `failbackWhy` (9 dil), test eski metnin görünmediğini de ölçer.
  - **Dokunulan dosyalar:** `src/Pbxtr.Web/src/app/screens/agent/AgentDeskScreen.tsx`, `AgentDeskScreen.test.tsx`, `src/Pbxtr.Web/src/app/i18n/messages/{tr,en,de,fr,az,bg,ar,hy,ka}.json`
  - **Doğrulama (sunucuda node:22 konteyneri):** vitest AgentDeskScreen (18) + i18n klasörü: 55/56, tek kırmızı `i18n.test.tsx` 20 sn timeout (load avg 124); `--testTimeout=180000` ile AgentDesk+i18n.test 44/44 yeşil; `tsc -b` 0. Mutasyon: HEAD tsx → failback testi KIRMIZI (1 failed); geri alındı (sha 87eb3f7c) → yeşil.
  - **Commit tekniği:** i18n dosyaları başka ajanda kirliydi; geçici `GIT_INDEX_FILE` + `commit-tree` + `update-ref` ile yalnız benim 2'şer satırım commitlendi, gerçek index bu yollar için yeni bloba çekildi.
  - **Commit:** `d3b94000` — BR-AST-114 (b): failback seridi olanin TERSINI soyluyordu -- kendi metni eklendi
- **BR-AST-114 (a):** kodda var (`ConfigRenderer` failback `Playback` tenant medyası, `ck_queues_callback_media_required` tuş doluyken anonsu zorunlu kılar; `vm-sorry` dalı bugün ulaşılamaz). Canlıda hiçbir kuyrukta `callback_digit` dolu değil → yol hiç render edilmiyor.
- **BR-AST-118:** dokunulmadı — `deploy/pbxtr-confd-dugum.sh` + selftest aynı anda başka ajanda (BR-SYS-60) kirli; silme yetkisi o dosyada yazılır.
- **BR-BE-43-B:** migration gerektirir (son görülen düğüm kolonu, Karar #66 M2 (a)); bu gece migration yasak → açık.

## Açık kalanlar / sonraki adım
- BR-AST-114 canlı: yayından sonra tuş dolu bir kuyrukta talep alınamayan çağrı → agent masasında "Geri arama talebi alınamadı" şeridi.
- BR-AST-118 ve BR-BE-43-B açık (gerekçe yukarıda).
# pbxtr — 2026-09-25

## 06:20–07:00Z — 14 gruplu iş akışı başlatıldı ve kullanıcı emriyle DURDURULDU
- Sunucu 2 CPU / 7 GB; derlemeler tek kilitte sıraya girdi (21 bekleyen), 30 dk'da ilerleme düşük. Kullanıcı: token maliyeti
  yüzünden her şeyi durdur, işler tek tek verilecek.
- Main'e giren: `8b623974` BR-AST-117 (8 dilde hizmet dışı anonsu), `79988a24` BR-BE-223 (CallId'siz olay aktif çağrıyı ezmez),
  `a000a40d` BR-AST-61 (pbxtr-edge santral ağ ad alanında kuruldu). Bunlar QA denetiminden GEÇMEDİ.
- Yarım iş (234 dosya, doğrulanmadı) `wip/is-akisi-20260925` dalına yedeklendi (geçici index + commit-tree; main'e dokunulmadı).
  Yerel ağaçta commit'siz olarak da duruyor. Sunucuda wf-* konteyner/dizin/kilit temizlendi.
- Ders: `pkill -f` desenini `[.]` ile kır (`pgrep -f "wf-derleme[.]kilit"`), yoksa ssh kabuğu kendini öldürür.
