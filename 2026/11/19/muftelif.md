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
- **Paket:** `X:\GitlabredericTr\SentezPlaning-paket-2026-11-19-b243f3d.zip` (8,6 MB, sır yok).

## Kararlar
- "Tüm miktarlar boxların sayısı olacak" → dağılım adedi siparişe bağlı kutulardaki adet (stok sütunları dahil); siparişsiz kutular (2. kalite) girmez.
- Elle/Excel kaydı Sentez'in önüne geçer (silinmez, geri alınabilir); adres tarifi eşleşmezse adet düşürülmez, uyarı verilir.

## Açık kalanlar / sonraki adım
- Sentez'de 1.111 adetlik adreslerde Adres Tarif 1'e irtibat kişisi yazılmış; müşteri sütun adıyla değiştirilmeli.
- Sentez'de adreslerin Adres Tarif 1'ine müşteri sütun adları girilmeli (ARITZIA-2829, ITALY, UK …); boşken dağılım uyarı verir.
- `SentezPlaning-paket-2026-11-19-b243f3d.zip` sunucuya kurulmalı (192.168.3.228:90).
