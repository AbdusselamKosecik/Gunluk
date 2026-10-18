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

### 3. Asıl istenen yer: bant ekranındaki "tekrar yazdır" box listesi 2 gün → 1 hafta
- **Neden:** Kurulumdan sonra kullanıcı "simdi degismemiz gozukuyor" dedi. 1. maddede değiştirilen yer Yönetim → Raporlar ekranıydı.
  Bant sonundaki kişinin kullandığı liste ise bant (okutma) ekranındaki "🖨 Son 2 gün" düğmesi. Bu listenin sınırı
  `OkutmaViewModel.TekrarYazdirGun = 2` sabitinden geliyor (11.10'da `4e0c9ee` ile eklenmişti). Yanlış ekranı değiştirmiştim.
- **Ne yapıldı:**
  - `TekrarYazdirGun = 7` (`UretimKurallari.SonGunler`: bugün dahil son 7 gün).
  - `UygulamaMetinleri`: SonBoxlar / SonBoxlarBaslik / SonBoxlarBos metinleri "1 hafta" oldu (TR/EN/AR).
  - `OkutmaView.axaml` yorumu güncellendi.
  - Yönetim ekranındaki 1. madde değişikliği de kaldı (zararsız).
- **Dokunulan dosyalar:** `BantSayim/Ekranlar/OkutmaViewModel.cs`, `BantSayim/Ekranlar/OkutmaView.axaml`, `BantSayim/Ekranlar/UygulamaMetinleri.cs`, `BantSayim.Tests/YonetimFiltreTestleri.cs`
- **Test (TDD):** yeni `TekrarYazdirListesiTestleri` (4 test: 7 gün sınırı, 12.10–18.10 aralığı, üç metin "1 hafta" diyor). Önce 4'ü de kırmızıydı, sonra yeşil. Suite: 58 geçti, 20 atlandı.
- **Commit:** `529c77d`. Push edildi.
- **Kiosk'a kurulum:** 2. maddedeki adımlar (pscp → sudo install → pkill). Yedek dosya `BantSayim.Desktop.2026-10-11` yerinde duruyor.
  sha256 yerelde ve kiosk'ta aynı: bddc1b34… Yeni süreç 7760, 15 sn sonra çalışıyordu.
- **Ders:** "Bant sonunda etiket basma" = bant ekranındaki tekrar yazdır listesi. Yönetim raporu değil.

### 4. Etiket tekrar yazdır ayrı sekme (kullanıcı: "bunu ayri bir tab olarak yapabilirmisin")
- **Ne yapıldı:**
  - Bant ekranının üstüne iki sekme eklendi: **Okutma** ve **🖨 Etiket tekrar yazdır — son 1 hafta** (Yönetim ekranındaki `Button.sekme` stili).
  - Eski "Son 1 hafta" düğmesi ve listenin "Kapat"ı kaldırıldı. Listede "Yenile" düğmesi var; sekme her açılışta liste yeniden yükleniyor. Listedeki 360 px yükseklik sınırı kaldırıldı, sayfa kayıyor.
  - Okutma kutusu iki sekmede de üstte duruyor. `Okut` ilk iş `Sekme = 0` yapıyor: liste açıkken okutulan barkod kaybolmuyor, ekran okutmaya dönüyor.
  - Okutma sekmesinin içeriği (hata, sil modu, kalite kartları, kesim, son okutmalar) `IsVisible=OkutmaSecili` StackPanel'inde.
- **Dokunulan dosyalar:** `BantSayim/Ekranlar/OkutmaViewModel.cs` (Sekme, OkutmaSecili, BoxlarSecili, SekmeSec, BoxListesiYenile; BoxListesiAcik kalktı), `OkutmaView.axaml`, `UygulamaMetinleri.cs` (OkutmaSekme, SonBoxlar), `BantSayim.Tests/YonetimFiltreTestleri.cs`
- **Test:** `Bant_ekrani_iki_sekme_okutma_ve_etiket_listesi` önce derlenmedi (kırmızı), sonra yeşil. Suite: 59 geçti, 20 atlandı. Derleme hatasız (yalnız eski Pkcs 9.0.11 NU190x uyarıları).
- **Commit:** `bb7518e`. Push edildi. Kiosk'a 2. maddedeki adımlarla kuruldu: sha256 7d693ef5…, yeni süreç 7920.
- Görsel kontrol yapılmadı: ekran görüntüsü testi yok, kiosk ekranı görülemiyor. Kullanıcıdan bakması istendi.

### 5. Yeni istek (tasarım aşamasında): iş emri seçimi + box başlığına work order item
- Kullanıcı: "birde bunun ustune hangi workorder de calistigini secelim, paketin usune workorder item ekleyelim".
- **Bugünkü durum:** İş emri otomatik seçiliyor: `UretimDeposu.SonKesimAsync`, varyantın en son kesim (ProcessId = KesimProcessId) üretim kaydının iş emri.
  Box satırları (`Erp_BoxItem.UD_WorkOrderItemId`, `Erp_BoxItemVariant.UD_WorkOrderItemVariantId`) dolu. Box başlığına (`Erp_Box`) yalnız WorkOrderId yazılıyor.
- **Canlı bulgu (192.168.0.2):**
  - `Erp_Box.WorkOrderReceiptItemId` kolonu `FK_Erp_Box_Erp_WorkOrderItem` ile Erp_WorkOrderItem'a bağlı; 13.914 box'ın hiçbirinde dolu değil.
  - Bantta çalışılan iş emirlerinde 3–4 kalem var (4315-2: 3, 4316-2: 4).
- Kullanıcıya seçim düzeyi ve uymayan barkod davranışı soruldu.
