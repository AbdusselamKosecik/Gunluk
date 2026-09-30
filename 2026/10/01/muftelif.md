# muftelif — 2026-10-01

## Bağlam
SarfKullanim'dan SentezPlaning'e geçildi. Kullanıcının iki isteği:
(1) yıkamaya parametre, (2) dikim planında model kodu + Excel/adet/SMV düzeltmeleri.

## Yapılanlar

### 1. Keşif (2 paralel Explore ajanı)
- **Haftalık kapasite modülü:** İstenen parametrelerin çoğu ZATEN var (PP R/S, Islak I/Iss = sprey
  öncesi/sonrası, Zımpara ZB/ZR, Kılçık K/KF, Yıpratma). Tek eksik Lazer'in çalışma saati:
  Lazer `l_min_per_person × makine × vardiya × 6` ile hesaplanıyordu, `l_working_time` kolonu ölü.
  Haftada 6 iş günü her yerde sabit kodlu (backend + frontend'de formül iki yerde).
- **Dikim planı:** `orders.model_kodu` var ama DTO/ekran/Excel'e hiç çıkmıyor. Excel `GetOrders(null,null,null)`
  ile TÜM order tablosunu döküyor (ekran ise hat/dikim yeri/kategori + dikim çıkış tarihine göre filtreli)
  → "planda olmayan modeller" bundan. Adetler sentez-çekte bilerek korunuyor, fark sadece uyarı.
  SMV: etüt sorgusundan `InUse=1` filtresi bir ara kaldırılmış → muadil operasyonlar toplanıyor
  (6510-1259 için 21,0904/19,9007 = 1,0598 tam bu profile uyuyor).

### 2. Kullanıcı kararları
- Excel: ekrandaki filtrenin aynısı. Adetler: ikisi de (sipariş + kesim paylı) Sentez'den ezilsin, uyarı yok.
- Yıkama parametreleri: haftalık kapasite ekranı (Lazer çalışma saatine geçsin).
- SMV: muadilleri (InUse=0) etüt toplamından çıkar.

### 3. Uygulama (2 paralel ajan + kendi doğrulamam)
- **Lazer:** `Machine(LActiveMacCount, LWorkingTime, LShiftCount)`; `LMinPerPerson` legacy olarak kaldı.
  Tek seferlik backfill `PlaningDb.BackfillLazerWorkingTime` (meta bayrağı `weekly_capacity.l_working_time.backfill`),
  `l_working_time = ROUND(l_min_per_person/60)`. Ekranda "Makine başı dk" → "Çalışma (saat)".
- **Model kodu:** `PlanOrderDto.ModelKodu = ModelOf(o)`; plan tablosunda "Model" kolonu; Excel'de STYLE'dan
  sonra "MODEL" (sonraki kolonlar ve 3 SUM formülü bir kaydı).
- **Excel:** `ExportExcel(lineId, week, lokasyon)` + controller query param'ları; hat verilirse yalnız o hattın
  kapasite sayfaları. Web export çağrısı ekrandaki filtreleri gönderiyor.
- **Adet:** sentez-çekte `o.SiparisAdet`/`o.Adet` her zaman ERP'den; `AdediFarkli` sayacı ve toast kaldırıldı.
- **SMV:** `EtutSmv`'ye `ISNULL(ws.InUse,1)=1` ve `ISNULL(i.IsDeleted,0)=0`.
- Ajanın bıraktığı gereksiz BOM (`UretimPlanService.cs`) temizlendi.

### 4. Doğrulama (kendim, canlı çalıştırarak)
```bash
dotnet build            # 0 hata
# API 5299 + web 5280 ayağa kaldırıldı, dev JWT ile:
GET /api/sentez/uretim-plan/orders      # 862 kayıt, modelKodu hepsinde dolu
GET .../export                          # 11 sayfa
GET .../export?line=fashion-nd          # 5 sayfa, 261 model dışarıda kaldı
# xlsx içi: başlıklar MARKA|ORDER|STYLE|MODEL|FIT|... → MODEL kolonu yerinde
GET /api/sentez/planning/capacity/2026-27   # lMinWeek 17280 (480dk→8 saat dönüşümü sonrası aynı)
```
- Backfill doğrulandı: `l_min_per_person 480 → l_working_time 8`, kapasite değişmedi.
- **Doğrulanamayan:** SQL sunucusu 192.168.1.22'ye bu oturumda erişilemedi → SMV değişikliği (muadil filtresi)
  ERP'ye karşı denenemedi; A9255-1601 repodaki eski dev DB'de yok. Tarayıcı MCP'si de bağlanamadı,
  görsel kontrol yapılamadı (web build + lint geçiyor, lint hataları değişiklik öncesiyle birebir aynı).
- **Commit:** `8794ba7`

## Açık kalanlar
- Erişim açılınca: `sentez-cek` + SMV recalc çalıştırıp 6510-1259'u kontrol et. Modelin yerel SMV kaydı
  `excel`/`elle` kaynaklıysa değer donmuştur; etüt düzeltmesi görünmez, kayıt silinmeli
  (`DELETE /api/sentez/uretim-plan/smv/{style}`); plan tablosundaki rozetten (E/X/M) anlaşılır.
- Adetlerin ERP'den ezilmesi tek yönlü: elle düzeltilmiş adetler ilk çekişte kaybolur, planlamacılara söylenmeli.
- Excel kolon sırası değişti (D'den sonrası bir kaydı); dışarıdaki makro/sheet varsa etkilenir.
- Filtreli Excel'de hâlâ "KATEGORISIZ" sayfası olabiliyor: hatta düşen ama kategorisi boş order'lar.
