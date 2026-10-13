# pbxtr — 2026-10-13

## Bağlam
Kullanıcı talebi (12 Ekim gecesi): *"Bir sayfaya public sayfaya versiyon versiyon guncellemeleri
eklermisin? yani degisiklik listesi"*. Sayfa ve üreticisi 12 Ekim'de yazılıp commit edilmişti
(`6f71fbd7`, `6330d196`); bugün yayın, canlı doğrulama ve çıkan arızanın düzeltmesi yapıldı.

## Yapılanlar

### 1. Herkese açık sürüm notları sayfası (özet — 12 Ekim'de yazıldı)
- **Kaynak:** `doc/dagitim/surum-gecmisi.json` — `{surumler:[{sha(12 hex), yayin(ISO Z), baslik, maddeler:[{tur, metin}]}]}`,
  eskiden yeniye; `tur` ∈ yeni / iyilestirme / duzeltme / degisiklik. Sürüm = sunucuya yayınlanan imaj
  (`docker images` listesinden `demo-<sha12>` aralıkları; 2026-08-26 → 2026-10-12, 42 sürüm, 268 madde).
- **Üretici:** `deploy/surum-notlari-uret.py` → `src/Pbxtr.Web/public/surum-notlari/index.html`
  (+ elle yazılmış `surum-notlari.css`). Betik yok (CSP `script-src 'self'`), harici CSS (`style-src 'self'`).
  `--kontrol` çıktı kaynakla aynı mı diye bakar (rc=1).
- **Sızıntı bekçisi (YASAK):** kart kodu `(BR|ST|RS|BL|S24)-`, karar no, IP, port (`(?<![0-9]):\d{2,5}`; saat geçer),
  sha, iç terimler (demo, lab, kurul, sudoers, AMI, ARI, "test sunucu"), ekran no `#\d{1,2}` → üretim durur.
- **SPA dışında:** ekran kayıt defterindeki yetkisiz ekranlar kapalı liste (login, forgot-password, me-profile,
  forbidden); genişletmemek için statik sayfa. Giriş ekranı sürüm damgası `<a href="/surum-notlari/">`
  (`LoginScreen.tsx`, router `<Link>` değil).

### 2. Yayın 30 → mesai kapısı, yayın 31 → yeşil
- **Neden:** yayın 30 `YAYIN_EXIT=67` — `mesai: ... 1340 -- MESAI ICI (08:00-20:00). Yayin REDDEDILDI.` Hiçbir şey değişmedi.
  Kullanıcının önceki kararı "apalim mesai zamani yok bizde" → bilerek devam.
- **Komut:**
  ```bash
  nohup bash -c "PBXTR_MESAI_ICI_YAYIN=1 bash deploy/yerel-yayin.sh --yayinla > LOG 2>&1; e=\$?; echo YAYIN_EXIT=\$e >> LOG; \
    if [ \$e -eq 0 ]; then git push >> LOG 2>&1; echo PUSH_RC=\$? >> LOG; fi" &
  ```
- **Sonuç:** `YAYIN_EXIT=0`, `PUSH_RC=0`, imaj `tekbirsoft/pbxtr:demo-6330d196363c` healthy.

### 3. Canlıda /surum-notlari/ SPA dönüyordu → nginx iç yeniden yazma
- **Ölçüm:** `/surum-notlari/` 200 ama 1544 bayt (SPA index); `/surum-notlari/index.html` 200, 75060 bayt (doğru);
  dosya imajda `/app/wwwroot/surum-notlari/` altında vardı.
- **Kök sebep:** `Program.cs` açık `UseRouting` çağırmaz → örtük routing hattın başında. `MapFallbackToFile`
  deseni `{*path:nonfile}` klasör yolunu SPA uç noktası olarak seçer; `UseDefaultFiles` uç noktası seçilmiş
  isteğe dokunmaz. Uzantılı yol desene uymaz, static files'tan gelir.
- **Düzeltme (uygulama hattını değiştirmeden):** `pbxtr-demo/nginx/pbxtr.conf`
  ```nginx
  location = /surum-notlari  { return 301 /surum-notlari/; }
  location = /surum-notlari/ { rewrite ^ /surum-notlari/index.html last; }
  ```
  `last` → `location /` (proxy + başlıklar aynen).
- **Sunucuya:** `/home/vuo/pbxtr-demo/nginx/current/conf.d/default.conf` (symlink `.rev/...`), önce md5 HEAD ile
  aynı olduğu doğrulandı; yedek → yaz → `docker exec pbxtr-nginx nginx -t` → `nginx -s reload` → yedek silindi.
  Sunucu md5 = repo (LF) md5 (`a6e0d461…`), nginx-drift kapısı için şart.
- **Doğrulama:** `/surum-notlari/` 200, 75060 bayt, 42 `<article>`, 0 `<script>`, `Cache-Control: no-store`;
  `/surum-notlari` 301; `/`, `/login` 1544 (SPA, etkilenmedi); giriş bundle'ında `surum-notlari` var.

### 4. Bu yayının kaydı kaynağa eklendi
- `surum-gecmisi.json` sonuna `6330d196363c` / `2026-10-13T12:12:36Z` / "Herkese açık sürüm notları";
  `python deploy/surum-notlari-uret.py && python deploy/surum-notlari-uret.py --kontrol` → YESIL.
  Bir sürüm kendi sha'sını taşıyamayacağı için sayfada **bir sonraki yayında** görünür.
- **Commit:** `04f14e4b` — Surum notlari: klasor yolu nginx'te dosyaya yeniden yaziliyor; 6330d196363c kaydi

## Kararlar
- Klasör yolu düzeltmesi uygulamada değil nginx'te: uygulamada çözmek için açık `UseRouting` + rewriter gerekiyordu,
  bu tüm ara katman sırasını değiştirir. Bedeli: nginx'siz koşan uygulama `/surum-notlari/`'de SPA verir.
- Her yayında `surum-gecmisi.json`'a bir önceki yayının kaydı eklenir, sonra `surum-notlari-uret.py`.

## Açık kalanlar / sonraki adım
- Sonraki yayında sayfa 43 sürüm gösterecek (6330d196363c kaydı).
- Kaynak elle güncelleniyor; yayın betiğine `--kontrol` kapısı bağlanmadı.
