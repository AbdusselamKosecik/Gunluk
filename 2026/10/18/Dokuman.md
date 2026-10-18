# Dokuman — 2026-10-18

## Bağlam
Kullanıcı, Sentez'deki ürün tanıtımından sevkiyata kadar bütün akışın "5 yaşındaki çocuğa anlatır
gibi" anlatıldığı bir HTML doküman istedi. Doküman yeni bir repoda duracaktı: `Dokuman`.

## Yapılanlar

### 1. Repo açıldı
- **Neden:** Dokümanlar için ayrı bir repo istendi.
- **Ne yapıldı:** `X:\Gitlab\modfex-apparel\Dokuman`, `git init -b main` ile açıldı. Remote
  `git@gitlab.com:modfex-apparel/dokuman.git` olarak eklendi. GitLab'da proje önceden açılmadı;
  ilk push projeyi oluşturdu (glab kurulu değil). Push sandbox dışından yapıldı (SSH).
- **Komutlar:**
  ```bash
  git init -b main
  git remote add origin git@gitlab.com:modfex-apparel/dokuman.git
  git push -u origin main
  ```

### 2. index.html — "Bir ürünün yolculuğu"
- **Neden:** Kullanıcı rehberi istendi.
- **Kaynak:** Bilgiler dört Explore ajanıyla kaynak koddan toplandı (`sentezservis`, `bantsayim`,
  `paketleme`, `sevkiyatmobil`). Tahmin yazılmadı. Etiket yerleşimi koddaki ZPL mm değerlerinden alındı.
- **Biçim:**
  - Tek dosya; dış bağımlılık yalnız Google Fonts (Nunito, JetBrains Mono).
  - Açık/koyu tema, tema düğmesi, yazdırma stili, mobil uyum.
- **Bölümler:**
  - Kahramanlar (Sentez, web, bant terminali, paketleme, el terminali).
  - Sentez'de mamul ve set kartları; set kodu `-rakam` ile biter, InventoryType 6.
  - Web'de karma koli eşleme: Önerileri getir, Tüm bedenlere uygula, ✎ ve ! işaretleri.
  - Sentez'de sipariş.
  - Siparişten üretim emri: Önizle → Order yap. Erp_WorkOrder tipi 15; WO, Item ve ItemVariant
    satırları ile UZM_SiparisWorkOrder yazılır.
  - Bağlantıyı kopar.
  - Bant sonu:
    - İş emri seçimi: önce sipariş, sonra üretim emri.
    - Okutma, HK ile 2. kalite, sil modu, kesim renkleri.
    - Box kapatma ve fiş 10; tekrar yazdır (1 hafta).
    - Yönetim ekranı ve kiosk.
  - Bant etiketleri: box 100×100, hata kodu 45×20 (2'li).
  - Paketleme:
    - Tezgaha dökme, koli, set dönüşümü, terazi (brüt − dara 1,1 = net).
    - Koli kodu PK{k}-{sipariş}-{no}.
  - Paketleme etiketleri: koli 100×100 (QR), ürün 45×20.
  - Sentez fişleri tablosu:
    - Fiş 10 (URT-PL-xxx) ve set dönüşümü 10+130 (PKT).
    - Fiş 17 (MGR, 42→41) ve fiş 120 (SVK).
    - BoxItem.InventoryReceiptItemId yalnız 120'de dolar.
  - El terminali:
    - Mamul giriş; geri alma yalnız aynı gün; silinen 17 fişinin kolisi tekrar okutulabilir.
    - Sevkiyat: onay, sayaç, Tamamla ile şoför ve plaka.
  - Sorun giderme tablosu ve sözlük.
- **Barkod ve QR:** JS ile çizilen temsili desenler; okutulamaz, dokümanda da böyle yazıyor.
- **Doğrulama:**
  - Chrome DevTools ile açıldı; konsolda hata yok.
  - Barkod (322 çubuk) ve QR (625 hücre) çizildi.
  - Bant etiketleri ekran görüntüsüyle kontrol edildi.
  - Headless Edge ile tam sayfa görüntüsü alındı.
- **Dokunulan dosyalar:** `index.html`, `README.md`
- **Commit:** `098e9f7` — Bir ürünün yolculuğu: Sentez'den sevkiyata kullanıcı rehberi (HTML)

## Kararlar
- Örnek veri olarak gerçek akıştaki değerler kullanıldı: sipariş 00000002, WO 4315-2, model
  4731001/2, set 4731001/2-2 SIYAH-EKRU.
- Koli etiketindeki müşteri adresi uydurma/örnek. Gerçek adres dokümana konmadı.
- Masaüstü "Sevkiyat" uygulamasının deneme aşamasında olduğu belirtildi. Gerçek sevkiyat el
  terminalinde yapılıyor.
- Şifre veya PIN dokümana yazılmadı.

## Açık kalanlar / sonraki adım
- Uygulamalar değiştikçe doküman güncellenmeli. Örnek: fiş 17'de set için WO satırı eşlemesi
  çözülürse "emir satırı boş kalabilir" notu kalkmalı.
- İstenirse gerçek ekran görüntüleri eklenebilir veya GitLab Pages ile yayınlanabilir.
