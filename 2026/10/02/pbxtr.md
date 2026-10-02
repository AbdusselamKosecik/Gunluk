# pbxtr — 2026-10-02

## Bağlam
Kullanıcı: *"kalan birşey varmı"* → *"kapalıları ayarlayıp durumunu clickupda da günceller misin"*.

## Yapılanlar

### 1. Pano ölçümü — senkronun görmediği 822 görev
- **Neden:** `clickup-senkron.js --kuru` "fark 0" diyordu ama "uzakta okunan görev: 1640" —
  eşleme defterinde 818 kart var. Fark ölçülmemişti.
- **Ne yapıldı:** salt-okuma betiği (`scratchpad/pano-olc.js`): listeyi sayfalayıp eşleme
  defteriyle karşılaştırır, durum ve kod sınıfına göre gruplar.
- **Sonuç:** eşli 818 (814 complete + 4 es-geç). Eşsiz 822: 790 complete, **32 açık**:
  - 8 **mükerrer BR** (aynı kodun eşli ikizi complete; backlog'da Bitti):
    BR-AST-115, BR-BE-205, BR-AST-114, BR-FE-117, BR-QA-32, BR-DB-44, BR-SEC-09, BR-BE-110.
  - 24 **kaynağı olmayan A-00…A-14 / B-01…B-09** (2026-08-26'da panoya doğrudan girilmiş;
    depoda plan dosyası yok, backlog'daki EPIC A/B satırlarıyla **adları farklı**).

### 2. 8 mükerrer kapatıldı
- `scratchpad/mukerrer-kapat.js`: her biri için (a) ikizin kendisi olmadığını, (b) backlog'da
  `complete` eşlendiğini, (c) görev adının kodla başladığını, (d) ikizin panoda complete
  olduğunu doğrular; `--kuru` önce, sonra `PUT status=complete` + **geri okuma**.
- **Sonuç:** yazılan 8; yeniden ölçüm: eşsiz açık 32 → **24**; senkron `--kuru` fark 0.

### 3. Yan bulgu — "kalan iş" sayımı eksikti
- Önceki turlarda "açık kart 4" dedim; bu yalnız **BR-*** kartlarıydı. `backlog.md`'deki
  EPIC story satırlarında (`A-01`, `E-09`, `K-01` …) **61 açık satır** var
  (in progress 40, backlog 20, to do 1; ayrıca 16 satır öncelik kolonu olmadan ayrıştırılamadı).
  Senkron bunları panoya hiç taşımaz (CLAUDE.md §14 "Panonun görmedikleri").

### 4. Kullanıcı kararı: story satırları panoya, 24 kaynaksız görev kapansın
- **Karar (kullanıcı):** "Evet, panoya taşı" + "Hepsini kapat".
- **Ölçüm önce:** 281 story kimliğinin **273'ünün panoda eşlemesiz görevi vardı** (eski süreç);
  açık olanlar bile `complete`. Kör oluşturma 273 mükerrer üretirdi.
- **Kod (`ba281efd`):**
  - `yonetim/arac/backlog-satir.js` — BR ve story yollarının ortak ayrıştırıcısı; `rows.json`
    **bayt bayt aynı** kaldı (cmp).
  - `clickup-cikar.js` → ayrıca `story-rows.json` (mutabakat 284 satır = 281 kart + 3 aynı
    durumlu mükerrer: BL-SMS-01, ST-40, S24-11; farklı durumlu mükerrer HATA). Story başlığı
    hücrenin tamamı (ilk kalın ifade "CI/CD" gibi anlamsız başlık üretiyordu).
  - `clickup-olustur.js` → önce **sahiplen**: üretilmiş `KOD — ` biçimi, sonra Türkçe-katlamalı
    başlık benzerliği; belirsiz aday HATA (ilk kuru koşu 6 belirsizde durdu), örtüşmeyen tek
    aday **kod çakışması** (BL-DB-33, BL-OPS-07, S24-3 → yeni görev).
  - `clickup-senkron.js` iki dosyayı okur; `.gitignore` `story-rows.json`; CLAUDE.md §14.
- **Canlı:** eşleme yedeği `scratchpad/esleme-yedek-20261002.json` → olustur: 270 sahiplenildi,
  11 açıldı (defter 1099) → 24 A/B görevine gerekçe yorumu + `complete` + geri okuma
  (`scratchpad/kaynaksiz-kapat.js`) → senkron: **220 yazıldı (70 durum: 40 in progress,
  29 backlog, 1 to do; 150 ad)** → `--kuru` fark 0.
- **Son pano:** 1651 görev; eşli 1099 (açık 80 = 4 BR + 76 story); eşlemesiz 552, **hepsi complete**.
- **Kapılar:** ilk koşu Docker Desktop düştüğü için yarıda kesildi (`dockerDesktopLinuxEngine`
  pipe yok) — **ve komut zinciri push'u koşulsuz yaptı** (`git push` kapı sonucuna bağlı
  değildi). Docker başlatıldı, yeniden koşu: 87 konteyner + 6 host YEŞİL. Ders: push
  `EXIT=0` koşuluna bağlanmalı.

### 5. 76 açık story işi (özet)
DM 11 (sunum anları) · ST 8 · RS 7 (rol teslim turları) · R 6 (sistem ekranları) · I 5
(ETL/mutabakat/kayıt/rapor) · M 5 (dialer/terk/tahsilat) · O 5 · G 4 · P 4 (firewall/SSL
yazma) · K/L/N 3'er · E/J 2'şer · F, H, BL-SMS, BL-ES, BL-DB-33, S24-3 1'er + BL-LIC 2.
Çoğu "kod/test tamam, canlı kabul açık"; bir kısmında ürün işlevi yok (tahsilat, MTR,
firewall/SSL yazma, gerçek TTS).

## Kararlar
- 24 kaynaksız A/B görevi **toptan kapatılmadı**: bir kısmının işi backlog'da başka kodla hâlâ
  açık (B-02 SO_PEERCRED → K-01 "Devam"; A-11 → G-16 "Kısmen"; A-14 üretim Asterisk'i yok).
  Açık işi kapalı göstermek, kapalıyı açık göstermekten kötüdür.

## Açık kalanlar / sonraki adım
- 76 açık story işinden hangisinden başlanacağı (kullanıcıda).
- Not: ilk sayımım 61 dedi; 4 kolonlu tablo satırları dahil edilince 76.
