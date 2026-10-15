# aaaa (bordro/PDKS programı veri klasörü) — 2026-10-15

## Bağlam
`X:\Yazilim\aaaa` eski tip (DOS/Pascal tarzı) bir bordro programının veri klasörü:
- `2026\*.MAS` / `.NDX`
- `CFF\PYRXX.USR` vb.

Kullanıcı, PDKS'den çıkarılıp önerilen 01–21 departman listesinin programa girilmesini istedi.
Liste üretim akışı sırasında: 01 Administration … 06–13 Line 1–8 … 21 Training. Git projesi değil; commit yok.

## Yapılanlar

### 1. DEPXX.MAS biçimi çözüldü
- **Dosya:** 990 sabit slot × 4331 bayt (toplam 4 287 690 bayt). Departman kodu = slot sırası + 1 (slot 0 = 01).
- **Kayıt düzeni:**
  - Bayt 0: durum (`A` = kullanımda, `D` = boş).
  - Bayt 1–2: `00 14` (ad alanı uzunluğu 20).
  - Bayt 3–22: ad, ASCII, boşlukla doldurulur, **en çok 20 karakter**. Program uzun adı kırpıyor.
  - Bayt 23'ten itibaren: 12 blok × 31 bayt `01` (aylık gün takvimi), bloklar 359 bayt arayla; geri kalanı sıfır.
- **Yöntem:**
  1. Değişiklik öncesi klasör yedeklendi.
  2. Kullanıcı programda 01 ve 02'yi elle girdi.
  3. Yedekle bayt bayt karşılaştırıldı: yalnız `DEPXX.MAS` slot 0–1 ve `CFF\PYRXX.USR` değişmişti.

### 2. 21 departman yazıldı
- **Ön koşullar:** Program kapalıydı (süreç listesiyle bakıldı). Yazmadan önce ikinci yedek alındı.
- **Yöntem:** Slot 0'ın tam kaydı şablon alındı, ad alanı değiştirilerek slot 1–20'ye yazıldı.
  Hedef slotların boş (`D`) olduğu doğrulandı. 22. slottan sonrası boş kaldı.
- **20 karakter sınırı yüzünden kısaltılanlar:**
  - 02 Production Management → `Production Mgmt` (programın kırptığı "Production Managemen" düzeltildi)
  - 04 Raw Material Warehouse → `Raw Mat. Warehouse`
  - 15 Ironing & Spot Cleaning → `Ironing & Spot Clean`
  - 17 Finished Goods & Shipping → `FG Wh. & Shipping`
- **Sonuç:** Dosya geri okundu; 01–21 `A` ve doğru adlarla, 22 ve sonrası `D`.

## Açık kalanlar
- Kullanıcı programı açıp 21 departmanın göründüğünü doğrulamalı.
- Programın ayrı bir indeks veya sayaç tutup tutmadığı bilinmiyor; `.NDX` dosyaları değişmedi.
- Yedekler scratchpad'de: `aaaa-yedek-*` (kalıcı değil).
