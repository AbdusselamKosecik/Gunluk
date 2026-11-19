# muftelif — 2026-11-19

## Bağlam
Kullanıcı (`/goal`): "planlamada örnek excelli yüklediğimizde hata alıyor; adreslerde adres tarif 1'e girilen değerleri getireceğiz, sipariş miktarlarından; stock olanlarda siparişe bağlı boxlardan; tüm miktarlar boxların sayısı olacak." (Ön maliyet kısmı → `webproject.md`.)
Sunucuda (192.168.3.228:90) 18.11 paketi (`10aee48`) kurulu.

## Yapılanlar

### 1. Örnek Excel yükleme hatası — yeniden üretme
- **Neden:** Kullanıcı örnek.xlsx yüklemede hata bildirdi.
- **Ne yapıldı:** Hem yerelde (canlı Sentez) hem sunucuda API ve tarayıcı (chrome-devtools, ayrı profil, geliştirme JWT'si) ile 47. hafta önizleme: **34 satır, 0 hata**. Yerelde aktarım da başarılı (işlem 1). Sunucuda aktarım denenmedi (canlı veri yazar); sunucuda hiç işlem yok. 48. haftada yüklenince tüm satırlar "İş emri seçili haftada yok" ile reddediliyor.
- **Sonuç:** Hata, güncel paketle yeniden üretilemedi. Olası nedenler: dosya farklı hafta seçiliyken yüklendi ya da hata eski paketteydi (eski sürüm başlığı 1. satırda bekliyordu). Bu iş için kod değişmedi.

### 2. Müşteri dağılımı Sentez kutularından
- **Neden:** Dağılım Excel'le elle girilmek yerine Sentez'den gelsin.
- **Bulgular (canlı, VPN kopmadan önce):**
  - "Adres Tarif 1" = `Erp_Address.Direction1`; şu an neredeyse boş (3 adreste dolu, biri "UK").
  - İş emri ↔ sipariş satırı doğrudan bağı yok (`Erp_OrderReceiptItem.WorkOrderId`, `Erp_WorkOrder.OrderItemId` boş).
  - Bağ kutularda: `Erp_Box.WorkOrderId` + `Erp_Box.OrderReceiptId`. 95280'in kutuları 5 siparişe (120.02.001/003, adres 001/002/007/008/029) bağlı; siparişsiz kutular 2K-Giyilebilir.
- **Ne yapıldı:**
  - `YuklemeKontrolSql.SentezDagilim`: siparişe bağlı kutular → sipariş adresi (ShipTo → Shipping → Address) → `Direction1`; adet = `Erp_BoxTotal.Quantity`, kutu sayısı.
  - `YkHesap.SentezDagilimEsle`: Direction1 ↔ müşteri adı/kodu (BaslikNormalize, `-`/`_`/boşluk farkı yok). Boş/eşleşmeyen adres → `DagilimUyarilari` (risk durumunu değiştirmez).
  - Servis: elle/Excel kaydı (en az bir adet) varsa o, yoksa Sentez. Geri alınınca Sentez'e döner. `YkOrder.DagilimKaynak/SentezDagilim/SentezKutu/DagilimUyarilari`.
  - Web: Müşteri Dağılımı sekmesinde "Kaynak" sütunu, detayda etiket + Sentez kutuları + uyarılar.
- **Dokunulan dosyalar:** `SentezPlaning/api/Sentez/YuklemeKontrol/{YkHesap,YuklemeKontrolModels,YuklemeKontrolService,YuklemeKontrolSql}.cs`, `tests/SentezPlaning.Tests/YuklemeKontrolTests.cs`, `web/src/api/yuklemeKontrol.ts`, `web/src/pages/YuklemeKontrolPage.tsx`
- **Komutlar:**
  ```bash
  cd SentezPlaning/tests/SentezPlaning.Tests && dotnet test   # 342/342
  cd SentezPlaning/web && npm run build
  ```
- **Sonuç / doğrulama:** 342 test yeşil (3 yeni: 95280 örneği 1614/37/43/22 → LA 284, stok sütunları, boş/eşleşmeyen adres). **SQL canlıda çalıştırılmadı** — VPN koptu.
- **Commit:** `4703b33` — feat(sentez-planing/yukleme-kontrol): musteri dagilimi Sentez kutularindan

### 3. Gerçek planlama dosyalarının yüklenmesi (Excel hatası için sertleştirme)
- **Neden:** Örnek dosya hatasız okunduğu hâlde kullanıcı hata alıyor; okuyucuda gerçek dosyalarda hata üretecek noktalar vardı.
- **Ne yapıldı:**
  - `YkExcel.Oku`: iş emri başlığı (cut / İş Emri / FOrder) olan ilk görünür sayfa okunur; eskiden hep 1. sayfa okunuyordu.
  - `.xlsm` kabul; `.xls` için "xlsx olarak kaydedin" mesajı.
  - `AdetOku`: formül kayan nokta artığı (1614.0000000001) tam sayı kabul; metin "1.614" / "1,614" / "1 614" → 1614; gerçek kesir (1.5, 1614.4) hâlâ red.
  - Web: dosya seçici `.xlsm`, yardım metni.
  - Çevrim dışı kontrol: sunucudan indirilen şablon + dışa aktarım (41 satır) ve örnek.xlsx (34 satır) 0 hata.
- **Dokunulan dosyalar:** `api/Sentez/YuklemeKontrol/{YkExcel,YkDagilimDogrulama}.cs`, `tests/.../YuklemeKontrolTests.cs`, `web/src/pages/YuklemeKontrolPage.tsx`
- **Sonuç / doğrulama:** 357/357 test.
- **Commit:** `a8809eb` — fix(sentez-planing/yukleme-kontrol): gercek planlama dosyalarinin yuklenmesi

### 4. Canlı doğrulama (VPN geri geldi) + düzeltme
- **Bulgu:** `Erp_BoxTotal.Quantity` canlıda boş → adet `Erp_BoxItem.Quantity` (IsDeleted=0). `ShipToAddressId` boş; siparişe özel adres `ShippingAddressId` (AddressId carinin ana adresi).
- **95280 sevk adresleri:** 008 ARITZIA 2829 Rohr Rd → 1614, 002 SNATT (İtalya) → 43, 029 Entreposage M2 (Montreal) → 22, 007 ARITZIA LP 415 Boyne → 35 (örnekte 37), 001 Citizens of Humanity (LA) → 273. Örnek.xlsx ile aynı.
- **Ne yapıldı:** SQL BoxItem + Shipping önce; Direction1 "LA" uyarı vermez (LA hesaplanır).
- **Canlı sonuç (47. hafta):** 40 iş emri, 1173 kutu, 23.384 adet; 22.273 adet adres tarifi boş adreslere, 1.111 adet "CONTACT NAME: JORGE CHAVEZ…" yazılmış adreslere (eşleşmedi uyarısı). Uçtan uca API: 41 iş emri kaynak Sentez; örnek.xlsx önizleme 34/0 → aktar → 95280 Elle (LA 284), 95349 Sentez; geri al → 95280 Sentez. Dışa aktarım + şablon 200.
- **Commit:** `b243f3d` — fix(sentez-planing/yukleme-kontrol): kutu dagilimi canli Sentez'e gore
- **Paket:** `X:\Gitlab\fredericTr\SentezPlaning-paket-2026-11-19-b243f3d.zip` (8,6 MB, sır yok).

### 5. Sentez veri girişi önerisi (kanıta dayalı) + sunucu
- **Neden:** Kod canlıda doğru, ama Adres Tarif 1 / UD_MainType boş olduğu için ekranda veri yok.
- **Ne yapıldı:** 42–47. hafta kutuları (sipariş + sevk adresi bazında) örnek.xlsx dağılımlarıyla iş emri iş emri karşılaştırıldı → her sipariş tam bir müşteri sütununa düştü (14 sipariş). Stok: MFG Giyim (Avrupa Serbest Bölge, adres 037, sipariş 00001096) = LA STOCK; Entreposage M2 sipariş 00001070 = CANADA (SSENSE) STOCK.
- **Bulgu:** ITALY / ITALY FME / ITALY-FAS / EMANUEL-NOA aynı SNATT adres kaydını (23482), CANADA 3PL ile CANADA (SSENSE) STOCK aynı Entreposage kaydını (23444) kullanıyor → adres düzeyinde ayrışmaz; bu siparişlere ayrı sevk adresi kaydı gerekir.
- **Simülasyon (sipariş eşlemesiyle, 47. hafta):** 58 hücrenin 44'ü birebir, 10'u ±%3 (paketlenen − plan), kalan: 95355 henüz kutusuz, 95525 örnekte boş.
- **Dosyalar (C:\aaaa):** `Sentez_AdresTarif1_Oneri_Siparis.csv`, `Sentez_UD_MainType_Oneri.csv` (171 rota prosesinden 78 kuru işleme tip önerisi), `Sentez_Veri_Girisi_Oneri.sql` (BEGIN TRAN … ROLLBACK; REVOLVE adresindeki irtibat bilgisi Adres Tarif 2'ye taşınır). SET NOEXEC ile derlendi, ÇALIŞTIRILMADI.
- **Sunucu:** SMB kapalı, WinRM açık ama kimlik yok; canlı siteye kendim kurmadım. Paket: `X:\Gitlab\fredericTr\SentezPlaning-paket-2026-11-19-b243f3d.zip`, kurulum IIS-KURULUM.txt adımlarıyla (data/logs/appsettings.json'a dokunmadan).

## Kararlar
- "Tüm miktarlar boxların sayısı olacak" → dağılım adedi siparişe bağlı kutulardaki adet (stok sütunları dahil); siparişsiz kutular (2. kalite) girmez.
- Elle/Excel kaydı Sentez'in önüne geçer (silinmez, geri alınabilir); adres tarifi eşleşmezse adet düşürülmez, uyarı verilir.

## Açık kalanlar / sonraki adım
- Sentez'de 1.111 adetlik adreslerde Adres Tarif 1'e irtibat kişisi yazılmış; müşteri sütun adıyla değiştirilmeli.
- Sentez'de adreslerin Adres Tarif 1'ine müşteri sütun adları girilmeli (ARITZIA-2829, ITALY, UK …); boşken dağılım uyarı verir.
- `SentezPlaning-paket-2026-11-19-b243f3d.zip` sunucuya kurulmalı (192.168.3.228:90).

### 6. Genel Bakış'tan LA ve Tamirde Bekleyen kaldırıldı + OrderTakipWeb tamir 2x
- **İstek:** "Planlamada Genel listeden LA ile Tamirde bekleyen miktarı alanlarını kaldırıyoruz; OrderTakipWeb'de tamir miktarları 2x yapıyor."
- **SentezPlaning:** `web/src/pages/YuklemeKontrolPage.tsx` Genel Bakış sekmesi kolonlarından `LA` ve `Tamirde Bekleyen` çıkarıldı, sekme açıklaması güncellendi (diğer sekmeler, kartlar, Excel aynı). Commit `5b590a7`.
- **OrderTakipWeb bulgusu (canlı, salt okunur, 95694):** Sentez satırları tekrarlı değil. Bir tamir turu 4 kayıt bırakır: 757/2 Finish Tamir çıkış (tamire yollar) → 758/1 Yıkama Tamir giriş → 758/2 Yıkama Tamir çıkış → 757/1 Finish Tamir giriş (dönüş). "Genel tamir durumu" iki departmanı topluyordu → 369/383 (gerçek 191/189).
- **Düzeltme:** `OrderTakip.TamirOzeti`: özet = Yıkama Tamir toplamı; yalnız Finish Tamir varsa yönü çevrilir. `wwwroot/index.html` istemci yedek toplaması kaldırıldı. 2 yeni test, 21/21. Commit `ff2d74e`.
- **Paketler:** `X:\Gitlab\fredericTr\SentezPlaning-paket-2026-11-19-ff2d74e.zip`, `OrderTakipWeb-paket-2026-11-19-ff2d74e.zip` (`dotnet publish -c Release -r win-x64 --self-contained false`, appsettings.Development.json / data / logs hariç). Sunucuya kurulmadı.
