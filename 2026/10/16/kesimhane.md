# kesimhane — 2026-10-16

## Bağlam
Kullanıcının iki isteği vardı:
1. GEMX yükleme. PDF ile GEMX uyumsuzsa hata verilecek. Onaylanmamış pastal silinip yeniden yüklenebilecek, onaylı pastal yalnız indirilebilecek.
   - Kararlar: silme = "iptal işaretle"; uyum ölçütleri = marker/dosya adı + en/boy/verim + beden/adet.
   - Elde örnek GEMX dosyası yok, kullanıcıdan istendi. Bu kısım GEMX gelince yapılacak.
2. Kesim girişi. Kullanıcının sözleri: "pdf de katman sayisina gore kumas da turune gore adet kontrolu … siparis adeti, pastala gore adet,
   kesilen adet (Kendi Girecegi) … atilan kumas hesaplanip … kestigin miktar girilsin … iade edilecek kumas ekranda … miktari degistirebilsin."
   Tasarım özetlenip kullanıcıya sunuldu: "onayliyorum".

## Yapılanlar

### 1. Kesim girişi: beden adetleri, kumaş, iade
- **Hesaplar (`Kesimhane/Ekranlar/Veri/KesimHesabi.cs`, saf kod):**
  - Pastala göre adet = kat başı adet × kesilen kat.
  - Kumaş, kesilen kata göre:
    - hesaplanan = (pastal boyu + pastal payı) × kat
    - net = boy × kat × verim
    - atılan = hesaplanan − net (metre ve yüzde)
  - Kalan = teslim alınan (Ver + Extra − Geri) − önceki kesimlerde kullanılan − bu kesimde kullanılan.
  - İade önerisi: son katlar kesiliyorsa kalanın tamamı, ara kesimde 0.
  - Doğrulama:
    - Kesilen adet 0 ile pastala göre adet arasında olmalı.
    - Kullanılan kumaş > 0 ve kalanı aşmamalı.
    - İade 0 ile kalan arasında olmalı.
  - Kumaş türü kontrolü: aynı Sentez varyantının kesilen adedi kumaşlar arasında farklıysa uyarı verilir; tam ürün = en az olan.
    Henüz kesilmemiş kumaş uyarı üretmez.
- **Veri katmanı (`PastalDeposu.KesimGirAsync(pastalId, KesimGirdisi)`), tek transaction:**
  - Pastal UPDLOCK ile kilitlenir.
  - Kilitler kontrol edilir (`KesimKontrol`).
  - Bedenler son revizyonla karşılaştırılır (her beden tam bir kez, kat başı adet aynı); uymazsa hata `KesimBedenUyumsuz`.
  - `KesimHesabi.Dogrula` çalışır.
  - İade > 0 ise `UZM_HammaddeHareket` tablosuna Tip 3 (Geri), Kumas 1, Onay 0 kaydı açılır.
    Kaynak, bu kumaşın son onaylı Ver/Extra hareketinin HammaddeIs kaydı ve birimidir.
  - Ardından `UZM_KesimGiris` (HesaplananMetre, KullanilanMetre, IadeHareketId) ve `UZM_KesimGirisBeden` satırları yazılır.
  - Kimlikler `SCOPE_IDENTITY()` ile alınıyor: tetikleyicili tabloda `OUTPUT` kullanılamıyor.
  - `KesimDurumu.OncekiKullanilan` = aynı order ve aynı kumaştaki kesimlerin KullanilanMetre toplamı.
  - `Pastal.BedenKesilen` ve `KullanilanMetre` alanları eklendi; `VaryantKesimleri()` kumaşlar arası karşılaştırma için.
- **Ekran (`KesimGirisView` / `KesimGirisViewModel`):**
  - Order detayındaki eski satır içi kat kutusu kaldırıldı; "✂ Kesim gir" düğmesi bu ekranı açıyor.
  - Kat, kesilen adet, kullanılan kumaş ve iade alanları elle değiştirilene kadar hesaplanan değeri izliyor; elle girilen değer kat değişince ezilmiyor.
  - Sağ panelde hesaplanan, net, atılan, kullanılan, teslim alınan, önceki kullanılan, kalan ve iade gösteriliyor.
  - Üstte kumaş türleri arasındaki fark uyarısı var.
- **Şema (`db/0002_kesim_kumas.sql`, idempotent):**
  - `UZM_KesimGiris`'e HesaplananMetre, KullanilanMetre, IadeHareketId eklendi.
  - `UZM_KesimGirisBeden` tablosu: CK `KesilenAdet` 0 ile `PastalAdet` arasında; silinmez ve değişmez tetikleyicileri.
  - `UZM_PastalRevizyon`'a GemxDosyaAdi, GemxDosyaYolu, GemxSha256 eklendi; değişmezlik tetikleyicisi bu kolonları da kapsıyor.
  - `CK_UZM_PastalRevizyon_OnayDurum` (0, 1, 2, 3) oldu; 3 = iptal.
- **Testler:**
  - `KesimHesabiTestleri` (7): önce kırmızı (tipler yok), sonra yeşil.
  - `KesimGirisViewModelTestleri` (4, DB'siz): varsayılanlar, ara kesimde iade 0, elle girilen değerin korunması, kumaş farkı uyarısı.
  - `PastalTestleri`: eski testler yeni imzaya uyarlandı; yeni DB testi `Kesim_beden_adetleri_kumas_ve_iade` eklendi.
    DB testleri 0002 betiğini kendi transaction'ında kurup ROLLBACK ediyor (paketleme `TezgahTestVerisi.SemaAsync` kalıbı).
  - `EkranGoruntusuTestleri.Kesim_ekrani_render_edilir`: `MODFEX_TEST_CIKTI` verilirse örnek veriyle PNG üretiyor; görüntü kontrol edildi.
- **Komutlar:**
  ```bash
  dotnet test Kesimhane.Tests                                   # 28 geçti, 5 DB testi atlandı
  MODFEX_TEST_CIKTI=<klasor> dotnet test Kesimhane.Tests        # kesimhane-4-kesim.png
  ```
- **Sonuç:** Derleme 0 uyarı. **DB testleri çalıştırılamadı**: SQL'e ulaşılamıyordu (100.119.104.122:1433 TCP kapalı).
- **Commit:** `47fe574`

## Kararlar
- İade, depo spec'indeki gibi onaysız "Geri" hareketi olarak açılıyor ve depo onaylıyor. Onay beklese de net teslimden düşüyor
  (KesimDurumu sorgusu Tip 3'ü onaydan bağımsız sayıyor).
- Eski (beden satırı olmayan) kesim kaydı canlıda yok (UZM_KesimGiris 0 satır); geriye uyum kodu yazılmadı.

## Açık kalanlar / sonraki adım
- **`db/0002_kesim_kumas.sql` canlıda çalıştırılmadı.** Kullanıcı onayı ve DB erişimi gerekiyor.
  Betik çalışmadan kesimhane order detayı açılmaz (yeni sorgular yeni tabloya bakıyor).
- DB bağlanınca `MODFEX_DB_TEST=1 dotnet test Kesimhane.Tests` çalıştırılacak.
- GEMX: kullanıcıdan örnek GEMX bekleniyor. Sonra yükleme, uyum kontrolü, iptal ve onaylıda yalnız indirme yapılacak.
- Depo uygulamasında kesimhaneden gelen "Geri" hareketinin görünümü kontrol edilecek. Depo, Tip 3'ü kendi onay akışında zaten listeliyor olmalı.
