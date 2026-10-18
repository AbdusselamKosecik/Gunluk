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

### 6. Sipariş + iş emri seçimi, box başlığına work order item
- **Kullanıcı kararları:**
  - Seçim: önce sipariş, sonra seçili siparişe bağlı iş emri. Kalem seçilmez ("zaten tek satır iş emirleri").
  - Seçili iş emrinde olmayan barkod: hata ver, okutma.
  - Box'ta renkler karışık olabilir; başlığa tek work order item yazılır, varyantlar satırlarda (WorkOrderItemVariant).
- **Canlı bulgular:**
  - 4315-2'de aslında 3 Erp_WorkOrderItem satırı var (EKRU/PUDRA/SİYAH, her biri 12 varyant, ortak varyant yok).
    Kural ("ilk okutulan ürünün kalemi") iki durumda da doğru çalışır.
  - 75 bant box'ının 11'inde iki kalem karışık.
  - Sipariş↔iş emri bağı yalnız `UZM_SiparisWorkOrder`'da: 2 sipariş, 4 iş emri. Sentez'in kendi `OrderItemId` bağı son 29 kalemin hiçbirinde dolu değil.
    Bu yüzden 4316-2 / Test-002 gibi bağlanmamış iş emirleri seçilemez.
  - Bugün bant 4315-2'de çalışıyor (sipariş 00000002'ye bağlı); açık box yok.
- **Ne yapıldı:**
  - `BantSayim/Ekranlar/Veri/IsEmriSecimi.cs` (yeni) — `IsEmriSecimDeposu`:
    - `SiparislerAsync`: UZM_SiparisWorkOrder'da iş emri olan, silinmemiş/iptal edilmemiş siparişler.
    - `IsEmirleriAsync`: iş emri numarası Sentez'den, `ISNULL(w.WorkOrderNo, sw.WorkOrderNo)`.
    - `BulAsync`: açık box'ın iş emri; siparişe bağlı değilse yalnız iş emri bilgisi döner.
  - `UretimDeposu.OkutAsync(..., isEmriId)`:
    - Kesim yalnız seçili iş emrinde aranır (`SonKesimAsync` + `@isEmriId` filtresi). Bellekten gelen çözüm başka iş emrindeyse kullanılmaz.
    - Bulunamazsa: varyant iş emrinde yoksa `IsEmrindeYok`, varsa ama kesilmemişse `KesimYok`.
  - `BoxAcAsync`: `Erp_Box.WorkOrderReceiptItemId` (FK Erp_WorkOrderItem) = box'a okutulan ilk ürünün kalemi.
  - `OkutmaViewModel`:
    - "YENİ ORDER" onayı yerine "İŞ EMRİ SEÇ" paneli: sipariş ve iş emri ComboBox'ları; tek iş emri varsa otomatik seçilir.
    - İş emri değişince açık box'lar `YeniOrderAsync` ile kapanır ve etiketleri basılır; yeni iş emrinin kesim tablosu hemen yüklenir.
    - Seçim yoksa okutma `IsEmriSecin` hatası verir (silme serbest).
    - Açılışta açık box varsa onun iş emri seçili gelir; yoksa panel kendiliğinden açılır.
    - Üstte büyük yazıyla "Sipariş X · İş emri Y · model".
  - Metinler: SecimBaslik, SecimYok, IsEmriSecin, IsEmrindeYok, IsEmriSecildi… `BaskaOrder` metni artık "İŞ EMRİ SEÇ"e yönlendiriyor.
- **Testler:**
  - DB'siz: `IsEmriSecimiTestleri` (okutma engeli, üst bilgi metni).
  - DB (ROLLBACK): `Secili_is_emri_disindaki_urun_reddedilir_box_acilmaz`, `Box_basligina_ilk_urunun_work_order_itemi_yazilir`, `Siparise_bagli_is_emirleri_listelenir`.
  - Önce derlenmedi (kırmızı), sonra yeşil.
  - `TestOrtami.AyarYukle()`: `MODFEX_SUNUCU` ile sunucu yalnız bellekte değişir (ayar dosyası 100.119… gösteriyor).
  - Canlıda bantlar okuttuğu için testlerin örnek barkodu kesimi dolmuş varyanta düşüyordu (`KesimAsildi`). Seçiciler kesimden en az 5 kalan / hiç okutulmamış varyanta sınırlandı.
  - Sonuç: `MODFEX_DB_TEST=1 MODFEX_SUNUCU=192.168.0.2 dotnet test BantSayim.Tests` → 84/84 geçti.
- **Commit:** `e5cc165`. Push edildi. Linux paketi `dagitim/bantsayim-linux-x64/` hazır; **kiosk'a henüz kurulmadı** (operatör akışını değiştirdiği için kullanıcıya soruldu).

### 7. İş emri doğrudan Erp_WorkOrder'dan, satır barkodun renginden
- **Kullanıcı:** "Erp_WorkOrder seçsin, okuttuğu barkoddaki renge göre satır seçelim, en mantıklı o."
  6. maddedeki "sipariş → siparişe bağlı iş emri" kararının yerini aldı. Sebep: 4316-2 gibi siparişe bağlanmamış iş emirleri seçilemiyordu.
- **Canlı:** Kesimi yapılmış, kapanmamış ve iptal edilmemiş 252 iş emri var. `Erp_WorkOrder.InventoryId` boş; model satırların stok kodundan alınıyor.
- **Ne yapıldı:**
  - `IsEmriSecimDeposu.IsEmirleriAsync(companyId, kesimProcessId, arama)`:
    - Kaynak: kesim üretim kayıtlarından iş emirleri (`MAX(InsertedAt)` = son kesim).
    - Filtre: `IsDeleted/IsClosed/IsCancelled = 0`; `TOP 40`, en son kesilen önde; `WorkOrderNo LIKE %arama%`.
    - Sipariş no yalnız bilgi olarak, `UZM_SiparisWorkOrder` varsa eklenir. Tablo yoksa SQL'e hiç konmuyor (ad çözülemezse sorgu derlenmez).
  - `BulAsync`: Erp_WorkOrder'dan.
  - Panel: arama kutusu + büyük satırlı liste ("4315-2 · 4731001/2 · kesim 13.10"). Sipariş seçimi kaldırıldı.
  - Satır (renk) seçilmiyor: okutmada varyant → iş emrindeki satır (6. madde), box başlığı = ilk ürünün satırı.
- **Testler:** `Kesimli_acik_is_emirleri_listelenir_ve_numarayla_aranir` (DB), `Listede_son_kesim_tarihi_gorunur`, siparişsiz üst bilgi. Önce kırmızı, sonra yeşil.
  `MODFEX_DB_TEST=1 MODFEX_SUNUCU=192.168.0.2 dotnet test BantSayim.Tests` → 85/85.
- **Commit:** `5766207`. Push edildi. Paket hazır; **kiosk'a kurulmadı**, kullanıcı onayı bekleniyor.

### 8. Önce açık sipariş, sonra üretim emri (kullanıcı: "once acik siparis secelim sonra uretim emri secelim")
- 7. maddedeki "doğrudan Erp_WorkOrder" listesinin üstüne sipariş adımı geri geldi.
- **Canlı:** Şirket 2'de yalnız 2 satış siparişi var (ReceiptType 2): 00000001 (TEST-10), 00000002 (4731001/2-2); ikisi de açık.
  Sipariş stok kartı iş emrininkinden farklı (4731001/2-2 ↔ 4731001/2), yani model eşleştirmesi bağ olamaz. Bağ yalnız `UZM_SiparisWorkOrder`.
- **Ne yapıldı:**
  - `SiparislerAsync`: ReceiptType 2, `IsClosed/IsCancelled/IsDeleted = 0`, en yeni önce, müşteri adıyla.
  - `IsEmirleriAsync(companyId, kesimProcessId, orderReceiptId)`: UZM_SiparisWorkOrder'dan, iş emri açık; son kesim tarihi (yoksa boş), WorkOrderNo sırasıyla.
  - `BulAsync`: OrderReceiptId'yi de döner; panel yeniden açılınca sipariş seçili gelir.
  - Panel: sipariş ComboBox'ı, altında üretim emri listesi. Tek sipariş / tek iş emri varsa otomatik seçilir. Arama kutusu kaldırıldı.
- **Test:** `Acik_siparisler_ve_siparise_bagli_acik_is_emirleri_listelenir` (DB), `Siparis_musteriyle_gorunur`, kesimsiz görünüm. Önce kırmızı, sonra yeşil. 86/86.
- **Commit:** `ffd979e`. Push edildi. Kiosk'a kurulmadı.
- **Yerel deneme:**
  - Bu PC'de `%LOCALAPPDATA%\Modfex\bantsayim\ayarlar.json` Sunucu = 192.168.0.2 yapıldı (yedek: `ayarlar.json.yedek-2026-10-18`).
  - `dotnet BantSayim.Desktop.dll` ile açıldı. Canlıda TestModu = 0: doğru barkod okutmak gerçek box açar.
- **Sonuç:** Siparişe bağlanmamış iş emirleri (4314-2, 4222-2, 4316-2…) bu akışla seçilemez. Kullanıcıya bildirildi.
