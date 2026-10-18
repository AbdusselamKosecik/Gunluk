# bantsayim — 2026-10-18

## Bağlam
Kullanıcı: "bant sonu na etiket basmada tarih fitresini 1 haftaya cikartirmisin".

## Yapılanlar

### 1. Yönetim → Raporlar: tarih filtresi varsayılan son 1 hafta
- **Neden:** Box etiketini tekrar basma ekranı (Yönetim → Raporlar, "Box etiketi yazdır") yalnız bugünü getiriyordu. Önceki günlerin box'ı için her seferinde tarih değiştirmek gerekiyordu.
- **Ne yapıldı:** `YonetimViewModel.Baslangic` varsayılanı `DateTime.Today` yerine `DateTime.Today.AddDays(-7)` oldu; Bitis bugün kaldı.
  Bant kabul listesi (`BantKabulListeViewModel`) zaten 7 gündü, ikisi aynı oldu.
  Aynı aralık bant özeti ve hata dağılımı raporlarına da uygulanıyor.
- **Dokunulan dosyalar:** `BantSayim/Ekranlar/YonetimViewModel.cs`, `BantSayim.Tests/YonetimFiltreTestleri.cs` (yeni)
- **Test (TDD):** `Tarih_filtresi_varsayilan_son_bir_hafta` önce kırmızıydı, sonra yeşil. Suite: 54 geçti, 20 DB testi atlandı.
- **Kapasite kontrolü:** Box sorgusu `TOP 500` (en yeni önce). Canlıda (192.168.0.2) son 14 günde günde 5–23 box var, yani haftada yaklaşık 70; sınırın çok altında.
  ```sql
  SELECT CAST(AcilisAt AS date), COUNT(*) FROM dbo.UZM_UretimBox WHERE AcilisAt >= DATEADD(day,-14,GETDATE()) GROUP BY CAST(AcilisAt AS date)
  ```
- **Commit:** `874ea70`. Push edildi.

## Açık kalanlar
- Değişiklik bant sonu bilgisayarındaki uygulama güncellenince görünecek.

### 2. Bant sonu kiosk'u (192.168.0.83) güncellendi
- **Neden:** Kullanıcı "uygulamayi guncelle" dedi. Kiosk'ta 11.10 tarihli sürüm vardı; 1 haftalık tarih filtresi (`874ea70`) yoktu.
- **Makine:** Ubuntu 26.04.1, host `pltest`, sudo yetkili kullanıcı `pl-test` (şifre kullanıcıda; günlüğe yazılmaz).
  Kullanıcılar: root, pl-test (1000), kiosk (1001). Uygulama `/opt/modfex/bantsayim/BantSayim.Desktop`, döngü `/opt/modfex/kiosk/oturum.sh`.
- **Kiosk PIN kontrolü:** `/etc/modfex/kiosk-pin` kullanıcının söylediği PIN ile eşleşiyor (11.10 15:30'da kurulmuş). PIN değiştirilmedi, günlüğe yazılmadı.
- **Komutlar:**
  ```bash
  bash paketle-linux.sh                                  # dagitim/bantsayim-linux-x64/ (commit 874ea70)
  pscp -pw … dagitim/bantsayim-linux-x64/BantSayim.Desktop pl-test@192.168.0.83:/tmp/BantSayim.Desktop.yeni
  # sunucuda (sudo):
  cp -p /opt/modfex/bantsayim/BantSayim.Desktop /opt/modfex/bantsayim/BantSayim.Desktop.2026-10-11   # yedek
  install -o root -g root -m 755 /tmp/BantSayim.Desktop.yeni /opt/modfex/bantsayim/BantSayim.Desktop
  pkill -TERM -f '^/opt/modfex/bantsayim/BantSayim.Desktop'   # oturum.sh çökme sayıp yeniden açar
  ```
  Windows'tan şifreyle bağlanmak için PuTTY `plink`/`pscp` kullanıldı. plink argümanları tek komutta birleştiriyor; sudo şifresi stdin'den `read -r P` ile verildi.
- **Sonuç / doğrulama:** sha256 yerelde ve kiosk'ta aynı (a759fea4…). Eski süreç 6529 kapandı, yeni süreç 7357 açıldı ve 18 sn sonra hâlâ çalışıyordu.
  Günlükte (`~kiosk/.local/share/Modfex/bantsayim/log/2026-10-18.log`) 09:10:42'de "Etiket basılamadı: URT1-261018-002-0002" var:
  ZPL yazıcıya TCP bağlantısı kurulamamış. Bu güncellemeden önce, güncellemeyle ilgisiz.
- **Geri dönüş:** `sudo install -m 755 /opt/modfex/bantsayim/BantSayim.Desktop.2026-10-11 /opt/modfex/bantsayim/BantSayim.Desktop` + pkill.

## Açık kalanlar (ek)
- 09:10'daki etiket yazıcısı bağlantı hatası: yazıcı o an kapalı mıydı ya da IP mi değişti, bakılmalı.
- pl-test şifresi sohbette paylaşıldı: değiştirilmesi ve SSH anahtarıyla erişim önerildi.
