# muftelif — 2026-11-18

## Bağlam
İki istek (C:\aaaa altındaki paketler):
1. `MFG_Yukleme_Kontrol_Demo.html` (+ `MFG_Yazilimci_Gelistirme_Notu.md`) planlamaya (SentezPlaning) eklenecek.
2. Daha önce APK olarak yapılan order takip (`OrderTrakingApk`) için yeni web uygulaması
   (`MFG_Order_Takip_Yazilimci_Paketi (6)`: README, GEREKSINIMLER.md, index.html demo, ornek-veri.json).
Sentez (192.168.1.22) bu makineden erişilemedi → canlı veri doğrulaması yapılamadı; birim testleri + demo veri ile doğrulandı.

## Yapılanlar

### 1. SentezPlaning — Yükleme Kontrol Merkezi (`/yukleme-kontrol`)
- **Neden:** Haftalık yüklenecek iş emirlerinde sağlam/sevk/açık, bölüm ve tamir bakiyesi, müşteri dağılımı (LA) ve sorumlu-aksiyon takibi tek ekranda.
- **Ne yapıldı:**
  - `YkHesap` (saf): ISO hafta (Pzt–Paz, Europe/Istanbul), kalan gün, tamir bakiyeleri (FÇ−YG, YG−YÇ, YÇ−FG, FÇ−FG), sevk bekleyen sağlam, üretim açığı, hazırlık %, LA = sipariş − diğer dağılımlar, risk (Veri kontrolü/Gecikmiş/Kritik 0–3/Yakın takip 4–7/Planlı/Sevke hazır/Tamamlandı), aksiyon hedef gecikmesi, sıralama.
  - Sentez SQL (`YuklemeKontrolSql`): hafta iş emirleri + sipariş adedi (WorkOrderItemVariant), tüm-zaman hareketleri (15/22 dikim, 11 yıkama, 13 finish, 757/758 tamir), depo 5 ReceiptType 10 = sağlam (kümülatif, TEYİT EDİLECEK), 120 = sevk. Kalite alanları eşlenmedi → "Veri yok". 3 dk önbellek, hata 503.
  - SQLite `yk_*` tabloları (`YuklemeKontrolRepository`): 18 müşteri kodu (kalıcı kod), sürümlü dağılım, işlem geçmişi (önceki/yeni JSON), istekId ile idempotent atomik aktarım, sürüm çakışması, güvenli geri alma (sonraki açık işlem varsa durur), aksiyon + aksiyon geçmişi.
  - Dağılım dosyası doğrulama (`YkDagilimDogrulama`): F-önek normalize, tekrar, eksik sütun, negatif/kesirli/metin, başka hafta, sipariş aşımı; LA sütunu yok sayılır. ClosedXML şablon/tam dışa aktarım (filtreli / tüm hafta), CSV okuma.
  - Controller `/api/yukleme-kontrol` (hafta, yetkiler, aksiyon, dagilim, sablon, onizleme, aktar, islemler, geri-al, disa-aktar). Yetki: `YuklemeKontrol:Yetki:{Dagilim,Aksiyon,GeriAl}` kullanıcı kodu listesi (boş = herkes).
  - Web: `YuklemeKontrolPage.tsx` (kartlar→filtre, 7 sekme, sabit iş emri/model sütunları, detay & aksiyon paneli, dağılım düzenle, yükleme önizleme, geçmiş/geri al), menüde "TAKİP > Yükleme Kontrolü".
  - `DemoYkKaynak` (`YuklemeKontrol__DemoVeri=true`) — sadece geliştirme/sunum.
- **Dokunulan dosyalar:** `SentezPlaning/api/Sentez/YuklemeKontrol/*`, `api/Storage/YuklemeKontrolRepository.cs`, `api/Program.cs`, `tests/SentezPlaning.Tests/YuklemeKontrolTests.cs`, `web/src/api/yuklemeKontrol.ts`, `web/src/pages/YuklemeKontrolPage.tsx`, `web/src/router.tsx`, `web/src/layouts/MainLayout.tsx`, `web/src/i18n/{tr,en}.json`, `README.md`
- **Komutlar:**
  ```bash
  cd SentezPlaning/tests/SentezPlaning.Tests && dotnet test     # 333/333
  cd SentezPlaning/web && npm run build
  # demo: ASPNETCORE_ENVIRONMENT=Development YuklemeKontrol__DemoVeri=true Planing__SqlitePath=<gecici.db> dotnet run (api)
  ```
- **Sonuç / doğrulama:** 333 test yeşil (yeni 32: K01–K09, K12–K17, K20…). Demo veriyle tarayıcıda ekran, aksiyon kaydı, CSV önizleme→aktar (aynı istek 2x → tek işlem), hatalı dosya reddi, geri alma, şablon geri yükleme, Excel dışa aktarım denendi.
- **Commit:** `7d4abe8` — feat(sentez-planing/yukleme-kontrol): Yukleme Kontrol Merkezi

### 2. OrderTakipWeb — APK'nın mobil web sürümü
- **Neden:** APK yerine telefon tarayıcısından order adet takibi; üretim ve tamir ayrı.
- **Ne yapıldı:** `muftelif/OrderTakipWeb` — .NET 10 minimal API + tek dosya `wwwroot/index.html` (paket demosunun tasarımı). APK SQL'i/yön kuralı birebir (Giriş InOut 1; Çıkış 2/0 veya 6+InOutType 1; 12/15/22/11/13, tamir 758/757), hareket kimliği RecId (tekrar sayılmaz, birleştirilmez), departman bazlı toplam, genel tamir özeti, 404/503/boş durumları, eski isteği iptal (AbortController). Sentez Meta_User MD5 girişi, ortak JWT. Demo modu (95560; 1 = hareketsiz, 2 = bağlantı hatası).
- **Dokunulan dosyalar:** `OrderTakipWeb/api/{Program.cs,Takip/*,Auth/SentezGiris.cs,wwwroot/index.html,appsettings.json}`, `OrderTakipWeb/tests/*`, `README.md`
- **Komutlar:**
  ```bash
  cd OrderTakipWeb && dotnet test OrderTakipWeb.slnx      # 19/19
  dotnet publish api -c Release -o publish/site
  ```
- **Sonuç / doğrulama:** 19 test (318/317/1, 24/19/5, ayrı departman, negatif bakiye…). 320/375/390/430 px iki sekmede yatay taşma yok; giriş zorunlu modda tokensız 401. IIS paketi: `X:\Gitlab\fredericTr\OrderTakipWeb-IIS-20261118.zip` (sır içermez).
- **Commit:** `a43c7fa` — feat(order-takip-web): APK order takibinin mobil web surumu


### 3. Excel çıktısı `örnek.xlsx` düzeninde + canlı Sentez kontrolü (VPN)
- **Neden:** Planlama, Yükleme Kontrolü çıktısını kendi haftalık dosyası (`C:aaa\örnek.xlsx`, sayfa "Week 47") biçiminde istedi. VPN ile Sentez'e erişim açıldı.
- **Ne yapıldı:**
  - `YkExcel.OrnekSayfa`: 53 sütun aynı sıra, 2. satır dikey başlıklar (turuncu accent2, tamir sarı, kalite turkuaz), satır 1'de "sentez (kalite kontrol raporu)", `forder` = `"F"&A`, `LA` = sipariş − SUM(müşteriler) formülü, mavi `Total` satırı, A3 dondurma, otomatik filtre, %85 zoom. Dışa aktarım: 1. sayfa bu düzen, 2. sayfa "Yükleme Kontrolü" (risk/sevk/aksiyon). Şablon da aynı düzende.
  - Doğrulayıcı başlığı ilk 5 satırda arar, `Total`/`Toplam` satırını atlar → kullanıcının `örnek.xlsx` dosyası olduğu gibi yükleniyor (34 satır, 0 hata).
  - Sentez'den yeni alanlar: kumaş kodu (Erp_InventoryReceiptItem 129, OutWarehouse 8, `F[0-9]%` tiresiz, en yüksek miktar), ilk kesim (`UD_FirstCutRPT`). Style = ilk iki parça; Wash = ad + "-PARÇA BOYA" (`UD_WashType`).
  - Yeni kural: sağlam > kesim → veri uyarısı; uyarılı iş emri Sevke hazır/Planlı/Yakın takip ise "Veri kontrolü".
  - OrderTakipWeb: Sentez her okutmayı ayrı kayıt tutuyor (95560 yıkama 110 kayıt) → gün+yön satırı (referans tabloyla aynı) + dokununca kayıtlar. Kesim (12, InOut 0) çıkarıldı.
- **Komutlar:** `powershell -ExecutionPolicy Bypass -File q.ps1 -sqlFile qN.sql` (scratchpad, salt okunur SELECT'ler); `dotnet test` (SentezPlaning 340, OrderTakipWeb 19).
- **Sonuç / doğrulama:** Hafta 47 canlı: 42 iş emri, ~2 sn. örnek.xlsx ile 34 ortak iş emrinde sipariş/kesim/kumaş/model adı/yükleme tarihi %100 aynı; başlıklar birebir. 95560 günlük yıkama satırları 291/27/1/2/82/233 (referans 232 → o günden beri +1 okutma).
- **Bulgu:** 95448'de depo 5'e 11.11'de 00028401 no'lu fişle 2602 adetlik ikinci giriş (sağlam 5070 görünüyor) — Sentez'de kontrol edilmeli.
- **Commit:** `8eb42e6` (SentezPlaning), `10aee48` (OrderTakipWeb). IIS paketi yenilendi: `X:\GitlabredericTr\OrderTakipWeb-IIS-20261118.zip`.

## Kararlar
- "Planlama" = SentezPlaning (SentezDashbord değil); hafta verisi önbellekten değil doğrudan Sentez sorgusuyla alınır.
- Sağlam = depo 5 girişi (kümülatif) varsayımı; kalite sınıfları uydurulmadı, "Veri yok".
- Order takip için ayrı uygulama (kullanıcı "yeni web uygulaması" dedi); auth Sentez kullanıcısı, order bazlı ek yetki APK'da yoktu.

## Açık kalanlar / sonraki adım
- XX işareti ve "-LA WASH" ekinin Sentez karşılığı yok; 95560 ilk kesim Sentez "RPT" vs örnek "1st cut" — planlamayla teyit.
- 95448 çift depo fişi (00028401) Sentez'de incelenmeli.
- Kalite sınıfları (2./3. kalite, numune) için kaynak hâlâ eşlenmedi.
- Şirket ağında: 95560 ve birkaç iş emrinde Sentez/kaynak rapor mutabakatı (sağlam, sevk, FÇ/FG yönü, kalite alanları).
- SentezPlaning yeni paket (Deploy-IIS) ve sunucuya kurulum; yetki listelerinin tanımlanması.
- OrderTakipWeb için IIS sitesi/port seçimi, `ConnectionStrings__Sentez` + `Jwt__Key` ortam değişkenleri; Android Chrome / iPhone Safari cihaz testi.
