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

## Kararlar
- "Tüm miktarlar boxların sayısı olacak" → dağılım adedi siparişe bağlı kutulardaki adet (stok sütunları dahil); siparişsiz kutular (2. kalite) girmez.
- Elle/Excel kaydı Sentez'in önüne geçer (silinmez, geri alınabilir); adres tarifi eşleşmezse adet düşürülmez, uyarı verilir.

## Açık kalanlar / sonraki adım
- VPN gelince: `SentezDagilim` SQL'ini 47. haftada çalıştır; 95280 kutularını örnek.xlsx (ARITZIA-2829 1614, ARITZIA-415 37, ITALY 43, CANADA 3PL 22) ile karşılaştır; hangi adres alanının (ShipTo/Shipping/Address) dolu olduğunu teyit et.
- Sentez'de adreslerin Adres Tarif 1'ine müşteri sütun adları girilmeli (ARITZIA-2829, ITALY, UK …); boşken dağılım uyarı verir.
- Yeni paket + sunucu kurulumu.
