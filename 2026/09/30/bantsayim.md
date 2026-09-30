# bantsayim — 2026-09-30

## Bağlam
Dünkü (29.09) üretim bant terminali işinin devamı: ekranlar yazılmıştı ama evdeki VPN (100.119.104.122) koptuğu
için DB testleri tamamlanamamıştı. Kullanıcı PL-001 şifresini verdi (`001`) ve firmaya geçildi.

## Yapılanlar

### 1. PL-001 şifresi doğrulandı
- `CONVERT(varchar(32), HASHBYTES('MD5', N'001'), 2) = Meta_User.Password` → yalnız PL-001 için doğru (diğer PL'ler farklı).

### 2. VPN'de testler neden düştü
- "pre-login handshake ... SSL Provider ... wait operation timed out": TCP kuruluyor, TLS el sıkışması 8 sn
  ConnectTimeout içinde bitmiyor. İlk hatadan sonra SqlClient havuzu "blocking period" ile sonraki açılışları
  1–3 ms'de düşürüyor (hepsi aynı hata). Kod sorunu değil, VPN yavaşlığı.
- `BantSayim.Tests/xunit.runner.json` → `parallelizeTestCollections: false` (DB testleri ortak statik durum
  paylaşıyor: Oturum, UygulamaBilgisi.KullaniciFiltresi) + csproj'da `CopyToOutputDirectory`.

### 3. Giriş testi
- `GirisTestleri.PL001_girisi_okutma_ekranina_yonlenir`: yanlış şifre ve listede olmayan (TRM-01) → GirisHatasi;
  PL-001/001 → Oturum.UserId 1134, rol Bant, `OkutmaViewModel.Olustur()` bant 1 şirket 2, `GosterildiAsync` hatasız.

### 4. Firmada tam test
- Yerel ayar `Sunucu` → `192.168.0.2` (yalnız bu makinedeki `%LOCALAPPDATA%\Modfex\bantsayim\ayarlar.json`).
- `MODFEX_DB_TEST=1 dotnet test BantSayim.Tests` → **41/41, 4 sn**. Canlı iz kontrolü: TST/URT box 0, fiş 10 yok,
  UZM_UretimBox/Okutma 0, applock 0, TestModu 0.
- **Commit:** `a95de06` — Testler: PL-001 giris/yonlendirme testi, DB testleri sirayla (GitLab + GitHub)
- Uygulama `dotnet run --project BantSayim.Desktop` ile kullanıcının ekranında açıldı (elle deneme için).

## Kararlar
- DB testleri sırayla çalışır.
- Evden çalışırken bağlantı yavaş; testler firmada (LAN) koşulmalı.

## Açık kalanlar / sonraki adım
- Kullanıcının arayüzü elle denemesi (PL-001). Canlıda gerçek okutma = gerçek box + 10 fişi (TestModu 0).
- Sentez kullanıcısı şifresi (yönetim ekranı elle denemesi için).
- Ortak SURUM 2'yi diğer repolara taşı; Ubuntu paketi; TestModu sorusu açık.

### 5. Açılışta açık box'tan devam
- **İstek:** "Açıldığında box var mı kontrol edelim, varsa ondan devam edelim."
- **Durum:** Zaten böyleydi — `OkutmaViewModel.GosterildiAsync` → `UretimDurumu.AcikBoxlarAsync` (UZM_UretimBox Durum=0)
  kartlara yükler; `UretimDeposu.OkutAsync` açık box'ı `UPDLOCK` ile alır, yeni box açmaz (iş emri farklıysa kapatır + yeni).
- **Eklenen:** ilk açılışta açık box varsa toast `AcikBoxDevam` ("Açık box'tan devam ediliyor: URT1-… (12)"), TR/EN/AR.
- Canlı kontrol: şu an açık box yok, okutma 0, fiş 10 yok.
- Build: açık uygulama DLL'i kilitlediği için Desktop derlenemedi; `BantSayim` + testler 41/41.
- **Commit:** `7f65a25` — Okutma: acilista acik box bildirimi

### 6. Hata kodu kartları (barkod)
- **Karar:** Önek **HK** kalıyor (kullanıcı: "HK01 tamam"). Barkod Code 128, içerik `HK`+FaultyCode.
- **Veri:** Erp_FaultyCard aktif 13 kayıt (01 LEKE … 13 PAKET). sqlcmd/PowerShell çıktısında Türkçe bozuk görünüyordu
  (PS 5.1 kodlaması) — veri nvarchar ve doğru; scratchpad `bagtest` (SqlClient) ile UTF-8 dosyaya `Kod|Ad` döküldü.
- **Betik:** `araclar/hata_kartlari_pdf.py` (reportlab; `pip install --user reportlab`; Arial TTF). A4, 2×4 kart 90×62 mm,
  kesikli kesim çerçevesi, pembe "MODFEX · HATA KODU", büyük kod, ad, barkod (barWidth 0.55 mm, 16 mm), okunur metin.
  ```bash
  python araclar/hata_kartlari_pdf.py kartlar.txt dagitim/hata-kartlari.pdf   # 13 kart, 2 sayfa
  ```
- **Doğrulama:** pymupdf ile 200 dpi PNG + `zxing-cpp` → 13 barkodun hepsi Code128 olarak HK01..HK13 okundu; görsel kontrol OK.
- PDF: `X:\Gitlab\modfex-apparel\bantsayim\dagitim\hata-kartlari.pdf` (dagitim/ gitignore'da).
- **Commit:** `6c38b11` — Hata kodu kartlari PDF betigi
- Açık: Yönetim > Hata Kodları'na "Kartları yazdır" düğmesi (seçenek 2) henüz yapılmadı.

### 7. İş emri önbelleği + kesim aşımı engeli + 2 gidişte okutma
- **İstek:** "Farklı bir order okutulunca o order'ın kesim miktarını ve barkodlarını hafızaya alalım, tekrar tekrar DB'ye gitmesin."
  Aşım sorusu → kullanıcı **(b) engelle** dedi.
- **Önce:** okutma başına ~11 DB gidişi (ayar 2, saat, barkod, kesim, açık box, box satırı 4, log) + ekran yenileme 4-5 sorgu.
- **`IsEmriOnbellegi.cs`:** `IsEmriOnbellegiYukleyici.YukleAsync` tek QueryMultiple (3 sonuç): iş emri başlığı/model; varyant başına
  kesim (`SUM(pv.Quantity)` ProcessId 167) + 1K/2K okutulan (log); barkodlar — son kesimi bu iş emrinde olan varyantlar ve
  şirkette barkodun **en küçük RecId** kaydı bu varyantsa (DB'deki VaryantBul `ORDER BY b.RecId` ile aynı sonuç için şart).
  `UretimOnbellegi` (bant başına, WO → önbellek), `Bul(barkod)`, `AsimOlur`, `Uygula(±1)`, 30 dk ömür.
  Tuzak: Dapper GridReader'da async multi-map yok → düz `BarkodSatiri` sınıfı.
- **`UretimDeposu`:** `AyarAsync` (5 dk bellek), `OkutAsync(..., VaryantKesim? cozulmus)`. Gidiş (1): `sp_getapplock
  UZM_Kesim_{WO}_{varyant}` + kesim/okutulan toplamı (tüm bantlar) + GETDATE + açık box UPDLOCK → `okutulan+1 > kesim` ise
  `KesimAsildi`. Gidiş (2): BoxItem upsert + BoxItemVariant upsert + log tek T-SQL batch. `UretimSonucu` + WorkOrderId, BoxAcildi.
  `VaryantKesim` public oldu.
- **`db/0002_uretim_kesim_index.sql`:** `UZM_UretimOkutma_IX4 (CompanyId, WorkOrderId, InventoryVariantId) INCLUDE (Kalite, Miktar)`;
  canlıya 2 kez uygulandı (idempotent).
- **Ekran:** `OkutmaViewModel` — önce bellek; bellek "dolu" diyorsa tazele + tekrar bak (başka bant silmiş olabilir); DB aşım
  deyip bellek demediyse tazele. Başarıda yerel güncelleme (box kartı `AcikBoxDurumu.Uygula(beden)`, son okutmalar, bugün
  sayaçları, kesim tablosu); box açılınca/kapanınca tam yenileme. Açılışta açık box'ların iş emirleri belleğe alınır.
  Yeni **Kesim** kartı: Beden · Renk · Kesim · 1K · 2K · Kalan (0'da kırmızı). `AcikBoxDurumu` → `BedenAdetleri` listesi.
- **Metinler:** KesimBaslik, Kesim, Kalan, KesimAsildi (TR/EN/AR).
- **Testler (`IsEmriOnbellegiTestleri.cs`):** birim (Bul, Uygula/AsimOlur, 30 dk); entegrasyon: önbellekteki 40 barkodun
  hepsi DB sorgusuyla aynı alanları veriyor; önbellekten okutma → box açılır, log'da WorkOrderProductionId doğru; başka bant
  (1143) kesim−2 okutmuş gibi log satırı → +1 tamam, bir sonraki `KesimAsildi`; sil → yer açılır. **46/46**, Desktop build temiz.
- **Heredoc tuzağı:** Bash heredoc'ta `'` + Türkçe/Arapça içerikli uzun Python betikleri "unexpected EOF" veriyor → betik Write ile
  scratchpad'e yazılıp çalıştırıldı.
- **Spec:** §6.2 eklendi.
- **Commit:** `46cc60d` — Okutma: is emri onbellegi, kesim asimi engeli, 2 gidiste okutma (GitLab + GitHub)
