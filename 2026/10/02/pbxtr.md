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

## Kararlar
- 24 kaynaksız A/B görevi **toptan kapatılmadı**: bir kısmının işi backlog'da başka kodla hâlâ
  açık (B-02 SO_PEERCRED → K-01 "Devam"; A-11 → G-16 "Kısmen"; A-14 üretim Asterisk'i yok).
  Açık işi kapalı göstermek, kapalıyı açık göstermekten kötüdür.

## Açık kalanlar / sonraki adım
- Kullanıcı kararı: (1) 61 açık story satırı panoya taşınsın mı, (2) 24 kaynaksız A/B görevi
  nasıl ele alınsın.
