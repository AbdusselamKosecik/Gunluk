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

### 4. Paket — `SentezServis-2026-11-05-pazaryeri-raporlari.zip`
- **Neden:** Kullanıcı canlı için paket istedi (pazaryeri raporları + Müşteri sesi panel yorumları).
- **Ön kontrol:** `git status`'ta kod değişikliği yok (yalnız `docs/sql/depo_yeri_000_kurulum.sql`,
  pakete girmez), `main` = `origin/main` (`cffa154`).
- **Komutlar:**
  ```bash
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File deploy/yayinla.ps1   # PS 5.1 oturumundan
  # doğrudan çağırınca Vite'ın stderr satırı NativeCommandError olup betiği durduruyor → ayrı süreç
  powershell.exe -NoProfile -Command "Compress-Archive -Path 'yayin\*' -DestinationPath 'SentezServis-2026-11-05-pazaryeri-raporlari.zip' -Force"
  ```
- **Karşılaştırma (11-03 paketiyle, Python zipfile):** 18 dosya / 18 dosya, aynı liste; app.js
  yolları 35 → 36, kaybolan yok, yeni `/pazaryeri-raporlari`. appsettings çıkarıldı (31 sır boşaltıldı).
- **Kurulum doğrulaması:** `/api/surum` → `arayuzTarihi` = `2026-11-05 08:24`. Göç 023 + 024 açılışta.

## Kararlar
- Gece sorulan "iptal/iadeler": dokunulmadı; Excel'lerde yok, Müşteri sesi'nde API'den geliyor.
- "Yenilenen kayıtları sil": yerel DB'de tekrar yok (her rapor 1 yükleme); yeniden yüklemede
  eskiler zaten fiziksel siliniyor. Kullanıcıdan ne kastedildiği soruldu, bir şey silinmedi.
- Barkod ekleme önerisi (ürün tablosunda beden-barkod, değerlendirmelerde model→barkod eşleme,
  Müşteri sesi bağlantısı) kullanıcıya soruldu, cevap bekleniyor.

## Açık kalanlar / sonraki adım
- Canlıya paket: göç 023 + 024 açılışta otomatik; yeni appsettings anahtarı yok.
- Yerel Host hâlâ açık (http://localhost:81, `yonetici`); iş bitince durdurulup `PrDeneme` silinecek.

---

## Stok Devir Hızı · Superset dashboard'u (01:30–02:00)

### Bağlam
Kullanıcı `X:\Gitlab\Modasima\new` içindeki 01/02 SQL + 03 md'ye göre Superset dashboard'u ve ürün bazlı devir
hızı istedi; ardından "paket çıkar, çalışan sistemde deneyeceğim".

### 1. Şema ve veri kontrolü (salt okunur, 192.168.1.3 SentezCore2026)
- Nesneler DB'de 01:25–01:28'de kurulmuş; DB'deki prosedürde join'ler doğru (`InventoryReceiptItemId`,
  `InventoryReceiptId`), dosyada yanlıştı.
- **`ReceiptTypeMap` boş** → `SalesQuantity` toplamı 0, devir boş.
- Tip profili (cari 120/320, faturalı, giriş/çıkış deposu): SATIS = 120 toptan, 121 perakende, 128;
  SATIS_IADE = 3 toptan, 2 perakende. 123 / 128 çıkışlarının tamamı, 120'nin 13 haftalık 123 binin 103 bini
  hariç carilere (VIUMOD 120.01.246, VIUMA 120.01.004, PLS 320.01.001).
- Hariç hareketler stoktan da atıldığı için stok ~1,4 milyon şişkin (2,55 M → doğrusu 1,17 M).

### 2. SQL düzeltmeleri (`superset/stok-devir-hizi/sql/`)
- 01: join'ler, `ReceiptTypeMap` MERGE tohumu (yalnız eksikler), boş eşleme için THROW 50002, hariç cariler
  stokta / satış dışı, `ExcludedIncomingQuantity` / `ExcludedOutgoingQuantity`.
- 02: `ExcludedOut_13w`, `ExcludedIn_13w`.
- Kuru çalıştırma: prosedür gövdesi `#Map/#IWS/#ITW` geçici tablolara (python dönüştürücü, scratchpad `kuru.py`) →
  satış 400.942, iade 17.222, son stok 1.173.951, negatif varyant 1.205 (−56.790 adet), satış bazlı devir 0,12/yıl.
  Prod'a yazılmadı.

### 3. Dashboard (`olustur.py`, bantdurumekrani kalıbı)
- Fiziksel dataset `dbo.InventoryTurnoverWeekly`, 21 metrik (md §2 + sevk bazlı devir, kardeş şirket çıkışı,
  negatif stok, stoklu ürün), 4 sekme / 29 grafik, 7 native filtre (zaman filtresi anlık grafiklerden hariç).
- Ürün sekmesi: ürün tablosu + koşullu renk, en hızlı/yavaş 25, ölü stok (HAVING), tükenmek üzere, ürün trendi.
- **Doğrulama:** kuru çıktı (564.792 satır) Docker `mssql/server:2022`'ye BULK INSERT, `apache/superset:latest`
  + pymssql'e API import 200; tarayıcıda 4 sekme gezildi, 29 `/chart/data` isteğinin hepsi 200, hata yok.
  ("Tükenmek üzere" 0 satır döndü.) Konteynerler silindi.
- **Paket:** `superset-stok-devir-hizi-paket-2026-11-05.zip` (README, md, import ZIP, 01, 02).
- **Commit:** `05fc0be` (ilk hal), `b0736aa` — Superset: Stok Devir Hizi dashboard'u + SQL duzeltmeleri

### Kararlar
- Kardeş şirket sevkleri satış sayılmadı (kullanıcının tanımı), ama ayrı "sevk bazlı devir" metriği eklendi.
- DB'ye yazmadım; 01/02 + EXEC'leri kullanıcı çalıştıracak.

### Açık kalanlar
- ReceiptTypeMap SATIS/SATIS_IADE eşlemesini kullanıcı onaylamalı (özellikle 128).
- Superset bağlantı kullanıcısı (`superset_okur` varsayıldı), haftalık SQL Agent işi.
- `X:\Gitlab\Modasima\new` içindeki eski 01 dosyası düzeltilmedi; repo kopyası esas.

### 4. Kurulum sırası düzeltmesi (02:05)
- **Neden:** Kullanıcı 02'yi çalıştırınca `Invalid column name 'ExcludedOutgoingQuantity'` (view, tablo eski yapıdayken
  derlendi). README sırası yanlıştı (01, 02, sonra EXEC'ler).
- **Ne yapıldı:** README: 01 → `EXEC sp_RefreshInventoryWeeklyStock` → 02 → `EXEC sp_RefreshInventoryTurnoverWeekly`;
  02 başına `COL_LENGTH` kontrolü + THROW 50003 (anlaşılır mesaj). Paket yeniden üretildi.

### 5. superset_okur betiği (02:08)
- **Neden:** Kullanıcı salt okur şifresini sordu; 192.168.1.3'te böyle bir kullanıcı yoktu (ZIP'te yer tutucu).
- **Ne yapıldı:** `superset/stok-devir-hizi/superset_okur.sql`: CREATE LOGIN/USER + yalnız
  `dbo.InventoryTurnoverWeekly` SELECT. Şifre 20 karakter rastgele, yalnız kullanıcıya iletildi; repoda `<şifre>`.
  Betik DB'de çalıştırılmadı. Paket yeniden üretildi.
