# depo — 2026-10-06

## Bağlam
Depo uygulamasında Hammadde Çıkış/Giriş ekranları vardı ama hareketler yalnız bellekteydi (demo lotlarla).
Kullanıcı istedi: order'a bağlı malzeme teslim/iade işlemlerinde FastReport ile imzalı tutanak çıktısı;
kesimhane pastal formu onaylanmadan depodan kumaş çıkmasın; kumaş teslimini kesimhane onaylasın.
Yönerge (/goal): **Sentez DB'sine müdahale yok**, gereken alanlar harici bire bir `UZM_` tablolarında,
dosyalar fiziksel (konum sonra belirlenecek), sırayla devam.
Bağlantı: evden `100.119.104.122` / SentezCore / `uzman` (şifre repoya yazılmadı).

## Yapılanlar

### 1. Spec ve plan
- **Neden:** Üç alt iş (depo kalıcılığı + tutanak, kesimhane pastal formu, kilitler) birbirine bağlı.
- **Ne yapıldı:** Tasarım ve plan yazıldı; kesimhane de bu spec'i kullanır.
- **Dosyalar:** `docs/superpowers/specs/2026-10-06-pastal-kesim-hammadde-design.md`, `docs/superpowers/plans/2026-10-06-pastal-kesim-hammadde.md`
- **Kararlar (spec §1):** Sentez fişi oluşturulmaz (önceki tasarımdaki UD_ kolonları + fiş iptal); order = `Erp_WorkOrderItem`
  (renk başına); kurallar uygulama kodunda tek transaction + UPDLOCK; kumaş Ver/Extra'yı kesimhane, aksesuar ve Geri'yi depo onaylar.
- **Commit:** `5cb698d`

### 2. DB şeması (UZM_)
- **Ne yapıldı:** `db/0001_hammadde.sql` — `UZM_HammaddeIs` (UNIQUE CompanyId+OrderReceiptId+WorkOrderItemId),
  `UZM_HammaddeHareket` (Tip 1 Ver/2 Extra/3 Geri, Kumas, Lot serbest metin, Onay, yumuşak silme; CHECK silinmiş+onaylı olamaz),
  `UZM_HammaddeTutanak` + `UZM_HammaddeTutanakSatir`; `UZM_Ayar.DosyaKlasoru` tohumu. Idempotent.
- **Komut:**
  ```bash
  sqlcmd -S 100.119.104.122 -U uzman -P '***' -d SentezCore -C -b -i db/0001_hammadde.sql   # iki kez: idempotent
  ```
- **Dikkat:** Sentez UDT'lerinde `sys.types.max_length` BYTE: `UdtCode`=25, `UdtExpShort`=50, `UdtName`=50, `UdtExpLong`=100 karakter.
  SHA-256 hex (64) ilk `UdtCode` idi → "String or binary data would be truncated"; `UdtExpLong` yapıldı, betik `ALTER` ile düzeltir.
- **Commit:** `7190597`, düzeltme `8b8f767`

### 3. HammaddeDeposu bellekten DB'ye
- **Dosyalar:** `Depo/Ekranlar/Veri/HammaddeDeposu.cs` (yeniden yazıldı), `HammaddeKurallari.cs` (saf kurallar),
  `PastalKontrol.cs` (kesimhane `UZM_Pastal*` tablolarını okur; tablo yoksa hiçbir pastal onaylı sayılmaz),
  `Depo/Ortak/Veri/UzmAyar.cs`, `Depo/Ortak/Veri/DosyaDeposu.cs` (kök: `UZM_Ayar.DosyaKlasoru` → yoksa `%LOCALAPPDATA%\Modfex\dosyalar`;
  `FileMode.CreateNew`, salt okunur, aynı içerik aynı dosya, farklı içerik `-1` sonekli; DB'de göreli yol + SHA-256).
- **Ekran:** demo lot listesi kalktı; Lot/Top No alanı; okutma = stok kodu veya `Erp_InventoryBarcode` (+ `*miktar`);
  kumaş satırında "✓ pastal: N m" / "⛔ onaylı pastal yok"; kumaş teslimi "kesimhane teslim onayı bekliyor".
- **Kural:** kumaş Ver/Extra → `PastalOnaysiz` (order'da bu kumaş için son revizyonu onaylı pastal yok).
- **Commit:** `7190597`

### 4. Teslim/İade tutanağı (FastReport)
- **Dosyalar:** `Depo/Ekranlar/Rapor/hammadde-tutanak.frx` (gömülü, A4; `raporlar/` altında dosya varsa o), `TutanakRaporu.cs`,
  `Veri/TutanakDeposu.cs`, `HammaddeDetayViewModel.Tutanak.cs`; paketler `FastReport.OpenSource` + `.Export.PdfSimple` 2026.2.3 (sentezservis ile aynı).
- **Akış:** hareketleri işaretle → "Seçilenlerin tutanağı" → `UZM_HammaddeTutanak` + satırlar → PDF `tutanak/<order>/T<no>-Teslim|Iade.pdf`
  → varsayılan görüntüleyicide açılır (yazdırma oradan). Teslim (Ver/Extra) ve iade (Geri) karışamaz. Tutanaklar listesinden tekrar açılır.
- **Not:** frx'te her metin kutusu tek kolon (karışık ifade Roslyn'i tetikler); başlıklar seçili dilde C#'ta hazırlanır. Android'de kapalı.
- **Doğrulama:** örnek PDF üretildi, görsel kontrol: başlık, Türkçe karakterler, imza kutuları doğru.
- **Commit:** `db00ecd`

### 5. Testler
- `Depo.Tests` (xunit): saf kurallar, dosya deposu, tutanak PDF; `MODFEX_DB_TEST=1` ile canlı DB testleri tek transaction + ROLLBACK
  (kombinasyon tekilliği, kumaş kilidi, onaylı silinemez, onaylı pastalla kumaş verilir, tutanak kaydı + SHA 64).
  Headless Skia ekran görüntüsü testi (`MODFEX_TEST_CIKTI`).
- **Sonuç:** 28/28 geçti. `Depo.Desktop` build + 8 sn açılış denemesi OK.
- **Commit:** `8b8f767`, `61d2a2c`, `7419b2a`

## Kararlar
- Sentez stok fişi yok; hareket yalnız UZM tablosunda.
- Lot Sentez'de yok → serbest metin (Lot/Top No).
- Test DB kalemi `63093` = 4315 **SİYAH** (EKRU = 63095, PUDRA = 63094).

## Açık kalanlar / sonraki adım
- **SentezCore'da satış siparişi (Erp_OrderReceipt ReceiptType=2) hiç yok** → depo "+ Yeni" ekranında sipariş seçilemiyor.
  Fabrika DB'sinde (192.168.0.2) durum kontrol edilmeli; yoksa İş'i sipariş olmadan (yalnız order) açma kararı gerekli.
- Betikler fabrika DB'sine uygulanmalı: bantsayim 0001 → depo 0001 → kesimhane 0001.
- `UZM_Ayar.DosyaKlasoru` için paylaşılan UNC klasör belirlenecek.
