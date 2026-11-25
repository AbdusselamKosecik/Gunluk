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

## Açık kalanlar / sonraki adım
- İlk karma koli canlıda açılınca Sentez'de içeriği (Erp_BoxItem/Variant) kontrol edilmeli.
- Paketleme uygulamasının QR etiket ekranı karma koliyi (birden fazla renk) doğru basıyor mu kontrol edilmeli (ayrı repo).
