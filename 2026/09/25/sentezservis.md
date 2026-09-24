# sentezservis — 2026-09-25

## Bağlam
Kullanıcı depo yeri '000' kurulum betiğini (`docs/sql/depo_yeri_000_kurulum.sql`, `98d22b4`)
SentezCore2026Test'te kalıcı çalıştırdı. Sipariş planlama ekranı tasarımına devam edildi; kullanıcı ek
olarak el terminalinin ne yapması gerektiğini bir md olarak istedi.

## Yapılanlar

### 1. Planlamada depo yeri → UD_RAF1 kuralı
- **Kullanıcı:** Planlama sırasında depo yeri sipariş üzerinde `UD_RAF1`'e yazılacak. Arama şirketten
  bağımsız: barkod önce sipariş şirketinde, yoksa 01'de aranır.
- **İnceleme (test, salt okuma):**
  - `UD_RAF1` başlıkta değil, satırda: `Erp_OrderReceiptItem.UD_RAF1` nvarchar(100).
  - Şirketler: 01=2, 02=3, 03=5, 04=7. 16.714 barkod birden çok şirkette var.
  - '000' yer RecId'leri: 22 (Co2), 23 (Co3), 24 (Co5), 25 (Co7). LocationTotal dolu.
- **Kararlar (AskUserQuestion):**
  - Birden çok yer varsa en çok stoklu yer yazılır.
  - Stoklu yer yoksa da yer yazılır: Quantity DESC, LocationCode sırasıyla ilk satır.
  - Yer satırı hiç yoksa alan boş kalır.
- **Prototip:** scratchpad `yer_bul.sql`.
  - Sonuç: Co2 360 varyant, Co5 333, Co7 2.180; hepsi kendi şirketinde bulundu.
  - 37 varyantın yeri yok.
- **Diğer kararlar:**
  - Otomatik planlama kalem grubuna (1/2/3+) göre, sırayla eşit dağıtır; önce önizleme, onayla yazar.
  - Planı kaldırma ve başka kullanıcıya aktarma serbest; kapanmış siparişe dokunulmaz.
  - UD_RAF1 yalnız planlamada yazılır.
- Tasarım kullanıcıya sunuldu; onay bekliyor. Varsayımlar: (a) e-ticaret siparişi = ECMOrderNo dolu,
  (b) DeletedBy'ı başka bir süreç kullanmıyor.

### 2. El terminali gereksinimleri
- **Neden:** Planlama bir kullanıcıya atama yapıyor; bunun sahadaki karşılığı el terminali.
- **Ne yapıldı:** `docs/el-terminali-gereksinimleri.md`
  - İçerik: toplama, yerleştirme/yer transferi, yer sorgu, sayım, devretme, kurallar, önerilen API
    uçları, açık sorular (8 madde).
- **Kritik tespit:** Yer stoğunu Sentez tetikleyicileri hareketin In/OutWarehouseLocationId'sinden
  güncelliyor. Takip açık depoda yer alanı boş kalan her hareket yer stoğunu sessizce kaydırır. Bu yüzden
  terminal gerçek alınan yeri kaydetmeli ve sevk hareketine yazmalı.
- **Commit:** `c2637cd` — El terminali gereksinimleri taslagi

### 3. El terminali kararları
- **Kullanıcı:** Mobil uygulama olacak. Sipariş satır kimliği harekete yazılınca sipariş kendiliğinden
  IsClosed olur. Eksikli sipariş kapatılmaz.
- **Kontrol:** Kapatan bir tetikleyici yok. Bağlantı `Erp_InventoryReceiptItem.OrderReceiptItemId`;
  kapatma Sentez uygulaması veya süreci tarafından yapılıyor.
- **Varsayım (b) doğrulandı (salt okuma):**
  - Test ve canlıda `Erp_OrderReceipt.DeletedBy` hiç dolu değil.
  - IsDeleted=1 sipariş de yok; Sentez fiziksel siliyor.
  - Sonuç: planlama için alan boş.
- **Commit:** `570cdca` (ilk push GitLab 502 verdi, tekrar denemede gitti).

### 4. Sipariş planlama spec'i
- **Kullanıcı:** "b kullanmıyor, Sentez IsDeleted değilse bakmıyor o alana, altyapısını ben yazdım, yap".
- **Ek ölçüm (salt okuma, test + canlı):**
  - Açık siparişlerde `IsETrade=1` ile `ECMOrderNo` dolu olması birebir örtüşüyor (1.800/1.800 ve 1.394/1.394).
  - Pazaryeri adı başlığın `SpecialCode` alanında.
- **Ne yapıldı:** `docs/superpowers/specs/2026-09-25-siparis-planlama-design.md`
  - İçerik: kararlar K1–K10, veri kuralları, yarış koruması (`beklenenOnceki`), otomatik dağıtım
    algoritması, API, kod yerleşimi, ekran, hatalar, test planı.
  - Günlük tablosu SentezServices'te, migration 021.
- **Öz denetim:** Örnek dağıtım tablosundaki çelişki düzeltildi (tam bölünen grup C'de biter, sonraki A'dan
  başlar).
- **Commit:** `0d5b17f` (push iki kez düştü: publickey ve sideband; üçüncüde gitti).
- **Hafıza:** `siparis-planlama-deletedby.md`.

## Açık kalanlar / sonraki adım
- Spec kullanıcı incelemesinde; onay gelince writing-plans.
- El terminali açık soruları (cihaz, "toplandı" sonrası süreç, sayım fişi tipi, eksik ürün politikası).
- Shopify indirim kodu düzeltmesi hâlâ kullanıcı kararı bekliyor.
