# sentezservis — 2026-11-05

## Bağlam
Dünkü (04.11) Pazaryeri raporları işinin devamı (`7e769d4`). Kullanıcı: Excel'den yüklenen ürün
yorumları Müşteri sesi'nde de iadelerin yanında, arama ekranında ayrıntılı görünsün.

## Yapılanlar

### 1. Göç 024 — panel yorumları v_musteri_sesi'ye
- **Neden:** Müşteri sesi'nin `musteri_sesi_yorumlar` tablosunu dolduran sağlayıcı yok; tek
  yorum kaynağı artık panel Excel'i (`pazaryeri_rapor_urun_degerlendirme`).
- **Ne yapıldı:** `024_musteri_sesi_panel_yorumlari.sql` → `CREATE OR ALTER VIEW dbo.v_musteri_sesi`,
  dört dal (yorum, PANEL yorumu, iptal, iade) + yeni `model_kodu` sütunu (diğer dallarda NULL).
  Panel dalı: `tur='yorum'`, `kayit_id = -d.id` (yorum tablosu kimlikleriyle çakışmasın),
  `zaman = DATEADD(HOUR,-3,d.tarih)` (TR → UTC), `sirket_kodu` yükleme günlüğünden JOIN,
  `durum = N'Panel raporu'`, barkod/müşteri/sipariş NULL.
- **Karar:** Excel barkod taşımadığı için barkoda göre kurulan "En çok şikâyet alan ürünler"
  listesine GİRMEZ; sayılar, yıldız dağılımı, ortalama, günlük seri ve aramaya girer.
- **Risk notu:** İleride bir API sağlayıcı `musteri_sesi_yorumlar`'ı doldurursa aynı yorum iki
  kez sayılır → o gün panel dalı o şirket/pazaryeri için kapatılmalı (göç başında yazıyor).

### 2. Depo / API / ekran
- `MusteriSesiDeposu.cs`: `MusteriSesiFiltresi.ModelKodu` (`v.model_kodu = @model`), `Ara`
  model kodunda da arar, satıra `ModelKodu`.
- `MusteriSesiUclari.cs`: `/kayitlar?model=` parametresi, yanıtta `modelKodu`.
- `MusteriSesiAramaSayfasi.tsx`: "Model kodu" süzgeci; satırda "Model 6800" bağlantısı → o
  modelin tüm yorumları. `MusteriSesiPanosu.tsx`: açıklama metinleri (yorum kaynağı + liste sınırı).

### 3. Doğrulama
- **Komutlar:**
  ```bash
  dotnet test tests/SentezServis.Core.Tests     # 765 geçti (+2: model süzgeci, göç içeriği)
  cd web && npx tsc -b && npx vitest run        # 90 geçti (+1: panel yorumu model bağlantısı)
  ```
- Yerel Host (LocalDB `PrDeneme`, zamanlayıcı kapalı, port 81) yeniden başlatıldı; `sema_surumleri`
  023+024. `/api/musteri-sesi/ozet?sirket=04` → yorum 25.011, ortalama 4,27, dağılım Excel'le
  aynı (2092/986/1957/2990/16986). `/kayitlar?model=6800` (04.11) → 16 kayıt, 19:02 TR = 16:02Z.
- **Commit:** `d373aff` — Musteri sesi: satici panelinden yuklenen urun yorumlari da yorum olarak gorunur

## Kararlar
- Gece sorulan "iptal/iadeler": dokunulmadı; Excel'lerde yok, Müşteri sesi'nde API'den geliyor.
- "Yenilenen kayıtları sil": yerel DB'de tekrar yok (her rapor 1 yükleme); yeniden yüklemede
  eskiler zaten fiziksel siliniyor. Kullanıcıdan ne kastedildiği soruldu, bir şey silinmedi.
- Barkod ekleme önerisi (ürün tablosunda beden-barkod, değerlendirmelerde model→barkod eşleme,
  Müşteri sesi bağlantısı) kullanıcıya soruldu, cevap bekleniyor.

## Açık kalanlar / sonraki adım
- Canlıya paket: göç 023 + 024 açılışta otomatik; yeni appsettings anahtarı yok.
- Yerel Host hâlâ açık (http://localhost:81, `yonetici`); iş bitince durdurulup `PrDeneme` silinecek.
