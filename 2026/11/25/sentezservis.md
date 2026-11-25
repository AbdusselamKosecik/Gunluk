# sentezservis — 2026-11-25

## Bağlam
Kullanıcı (mf-s.uzmanadres.com/koli-listesi): "Birden fazla satırda aynı koli numarası varsa aynı koliye koyman lazım;
6 kırmızı 3 sarı var mesela." Önceden aynı KoliBarcode ikinci kez görülünce satır "X. satırda da var" hatasıyla reddediliyordu.

## Yapılanlar

### 1. Karma koli: aynı KoliBarcode'lu satırlar tek koli
- **Neden:** Bir kolide birden fazla renk (ve gerekirse model) olabiliyor; liste her renk için ayrı satır veriyor.
- **Kurallar (kararlar):**
  - Aynı barkodlu satırlar = tek `Erp_Box`. `Erp_Box.OrderReceiptId` ve `WorkOrderId` koli başına tek alan olduğu için
    satırların CustomerOrder ve WorkOrder'ı aynı olmalı; değilse kolinin tüm satırları hatalı ("Aynı koli (X) farklı siparişlerde…").
  - Model/renk farklı olabilir.
  - Kolinin bir satırı hatalıysa (biçim ya da Sentez doğrulaması) diğer satırları da hatalı sayılır
    ("Aynı kolinin N. satırı hatalı"). Neden: ekran yalnız geçerli satırları gönderiyor; yoksa koli yarım açılırdı.
- **Ne yapıldı:**
  - `KoliListeKurallari.Koliler(satirlar)` (barkoda göre gruplar, ilk görünüş sırası) ve `KoliGrubuHatasi(koli)`.
  - `KoliListeAyristirici.Tablodan`: tekrar barkod hatası kaldırıldı; döngü sonunda koli bazında süzme (biçim hatalı
    satırın barkodu `hataliBarkod` sözlüğünde, kardeşleri de hata alır). Hatalar satır no'ya göre sıralı döner.
  - `KoliListeDeposu.DogrulaAsync` sonunda `KoliBazindaBirlestir` (public static, ReferenceEqualityComparer ile).
  - `KoliAcAsync`: satır değil koli başına transaction; koliyi grupça yeniden doğrular, hatada hiçbir satırı yazmaz.
  - `KoliYazAsync(IReadOnlyList<DogrulanmisSatir>)`: başlık ilk satırdan; `Erp_BoxItem` (MamulId, SiparisKalemId,
    IsEmriKalemId) başına; aynı varyant birden fazla satırda gelirse `Erp_BoxItemVariant`'ta adet toplanır.
  - `AcilmisKolilerAsync`: Model ve Renk DISTINCT virgüllü; birden fazla renk varsa Bedenler `RENK/BEDEN:adet` (nvarchar(1000)).
  - Ekran (`web/src/pages/KoliListesiSayfasi.tsx`): başlık/onay/"Koli aç (N)" farklı barkod sayısını sayar;
    karma koli satırlarında "karma koli · N satır"; ipucu metni güncellendi.
- **Dokunulan dosyalar:** `src/SentezServis.Core/KoliListe/{KoliListeAyristirici,KoliListeDeposu,KoliListeKurallari}.cs`,
  `tests/SentezServis.Core.Tests/KoliListeTestleri.cs`, `web/src/pages/KoliListesiSayfasi.tsx`
- **Testler:** yeni — 6 kırmızı + 3 sarı tek koli; farklı sipariş/iş emri → tüm satırlar hatalı; biçim hatalı satır
  kolinin tamamını düşürür; Sentez doğrulamasında kardeş satır hatalı → hepsi hatalı. Eski "aynı barkod" vakası
  "renk boş" vakasıyla değiştirildi.
- **Komutlar / sonuç:**
  ```powershell
  $env:SENTEZCORE_TEST="<SentezCore bağlantısı>"; dotnet test tests/SentezServis.Core.Tests   # 367/368
  cd web; npx tsc -b --noEmit; npx vitest run                                                 # 66/66
  ```
  Tek başarısız `KoliListeDeposuCanliTestleri.Kullanicinin_ornegi_satir_satir_neden_hatali_oldugunu_soyler` —
  önceden de başarısız (22.11'de git stash ile teyit), 10.11 canlı verisine bağlı, benzersiz barkodlar kullanıyor.
  "Açılmış koliler" yeni SQL'i canlı salt okuma testinde (`Acilmis_koliler_sorgusu_calisir`) geçti.
  Koli yazma canlıda denenmedi (test veritabanı yok).
- **Commit:** `c87c02b` — Koli listesi: ayni KoliBarcode'lu satirlar tek koliye girer (karma koli, orn. 6 kirmizi + 3 sari)

### 2. 0.2 (MODFEXSRV) sunucusuna yayım
- **Neden:** Kullanıcı "çalıştırır mısın" dedi.
- **Bulgu:** Sunucuda zaten `f17913e` (23.11, döviz kurları işi) çalışıyordu — döviz işi önceden canlıdaydı; bu yayım
  yalnız koli listesi değişikliğini ekledi.
- **Ne yapıldı:** `deploy/yayinla.ps1` ayrı powershell sürecinde. Paket hazırlandı ama süreç kapanmadı: dotnet build
  sunucuları yönlendirilmiş stdout'u açık tuttu → `dotnet build-server shutdown` ile kapandı. Sonra 22.11'deki gibi
  elle (Get-Credential'sız): yedek `C:\Server\SentezServis\yedek-2026-11-25-f17913e\` (exe, appsettings.json, wwwroot),
  `sc stop` → 18 dosya → `sc start`. appsettings.json korundu (tarihi 10.11).
- **Doğrulama:** `http://192.168.0.2:81/api/surum` ve `https://mf-s.uzmanadres.com/api/surum` → `1.0.0+c87c02b`,
  arayüz 2026-11-25 15:32 (UTC). Paketteki app.js'te "karma koli" metni var.
- **Geri dönüş:** servisi durdur, yedek klasörden exe + wwwroot'u geri kopyala, başlat.

### 3. Analiz: EXP2600001–709 koli listesi neden geçmiyor (kod değişikliği yok)
- **Yöntem:** listedeki tüm (sipariş, iş emri, model, renk, beden) kombinasyonları scratch konsolda
  `KoliListeDeposu.DogrulaAsync` ile canlıya karşı salt okuma doğrulandı; Sentez'den model varyantları, sipariş
  içerikleri, iş emri içerikleri, UZM_KarmaKoli tanımları ve UZM_SiparisWorkOrder bağları okundu. Hiçbir kombinasyon geçmedi.
- **Bulgular:**
  1. Siparişler SET stok kartında (6816-2, 6813-2, 6800-2, 2073-7, 2076-7, 1230-3, 6825-2, 6826-2, 6201-1); listedeki
     Model bileşen kartı (6816 …), Renk ise SET rengi (SİYAH-EKRU = 1 SİYAH + 1 EKRU; SBT/KARIŞIK 7 parça).
     Koli listesi kodu modeli doğrudan arıyor → "renk modelde yok / siparişte yok". Paketleme set kolisinde kutuya
     SET varyantını (set adedi) yazar, bileşenleri yalnız tezgah stoğu için kullanır.
  2. Liste adetleri büyük ihtimalle parça (525/7=75, 100'lük 2'li set kolileri; 00000012 SİYAH-TEN 75B 3100 parça ≤ 1700 set×2).
     1230-3 SBT'de bazı adetler 5'e bölünmüyor (174, 36, 24).
  3. Türkçe harf: liste SIYAH/LACIVERT/KARISIK/SiYAH, Sentez SİYAH/LACİVERT/KARIŞIK; Normal() yalnız tr ToUpper yapıyor.
     2073'te hem SIYAH hem SİYAH varyantı var (katlamada tam eşleşme öncelikli olmalı).
  4. Liste SIYAH-BORDO, sipariş 00000015/16 seti BORDO-SİYAH (6813'te ikisi de var).
  5. İş emri: 00000016 → bağlı iş emirleri 4558/4559 (25.11 açıldı), listede 4836-2 (00000015'in, içinde 6816).
     00000018 → bağlı 4284-2, listede 4284-4 (yalnız uyarı).
- **Karar bekleyen:** kutuya set mi bileşen mi yazılacak; adet parça mı set mi; SIYAH-BORDO = BORDO-SİYAH kabul mü.

### 4. Set desteği denemesi ve 00000018 ↔ 4284-4 bağı — kullanıcı isteğiyle GERİ ALINDI
- **İstek:** "customer siparişleri ilgili üretim emirlerine bağla; SIYAH-TEN bir set, tek ürün".
- **Yapılan, sonra geri alınan:**
  - `UZM_SiparisWorkOrder`'a 00000018 (584973, kalem 961540) ↔ 4284-4 (61295) satırı eklendi (Olusturan 'koli-listesi');
    kullanıcı "dur bozma, geri al" dedi → aynı satır silindi. Şu an 00000018 yalnız 4284-2'ye bağlı (önceki hali).
  - Koli listesinde set desteği (commit edilmedi): sipariş varyantlarından eşleşme, set içeriği UZM_KarmaKoliIcerik,
    adet parça ÷ set parça, Türkçe harf sadeleştirme, iki parçalı renkte ters sıra. Canlı salt okuma denemesinde
    00000016 (iş emri 4836-2) ve 00000020 SİYAH-EKRU 90B (siparişte yok) dışında hepsi geçti.
    `git checkout` ile geri alındı; depo temiz, sunucu c87c02b'de (değişmedi).
  - Fikir için: set parça sayıları 1230-3 SBT 5, 2073-7 SBT 7, 2076-7 KARIŞIK 7 (tüm bedenlerde).
- **Not:** 00000016 ↔ 4836-2 bağlanmadı (4836-2 00000015'in, içinde 6816).

## Açık kalanlar / sonraki adım
- İlk karma koli canlıda açılınca Sentez'de içeriği (Erp_BoxItem/Variant) kontrol edilmeli.
- Paketleme uygulamasının QR etiket ekranı karma koliyi (birden fazla renk) doğru basıyor mu kontrol edilmeli (ayrı repo).
