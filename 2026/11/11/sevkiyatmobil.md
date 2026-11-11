# sevkiyatmobil (Modfex, `X:\Gitlab\modfex-apparel\sevkiyatmobil`) — 2026-11-11

## Bağlam
10.11 incelemesi: okutma yavaşlığı SQL değil, Wi-Fi gecikmesi (medyan 79 ms, p90 342 ms, en çok 2,7 sn) × okutma başına ~25 sıralı
SQL gidiş-dönüşü. Kullanıcı: "dün sevkiyatı geciktirdik"; "depo için sevkiyat el terminalini hibrit çalıştırmamız lazım. İlk okumada tüm
order barkodlarını detaylarını local db'ye alıp local db'den güncelleyip okuyup aralıklarla internet olduğunda sisteme atmamız lazım."
Aynı sipariş tek terminalden okutulur; "gönderdikten sonra değişiklikleri alsın", "aynı box varsa aktarımda es geçecek".

## Yapılanlar

### 1. Tasarım + plan
- `docs/superpowers/specs/2026-11-11-hibrit-okutma-design.md` (commit `67b740a`), okuyucu kontrolü 4 soru → 3'ü benim kararım,
  1'i kullanıcı cevabı. Plan `docs/superpowers/plans/2026-11-11-hibrit-okutma.md` (`d7aa525`), satır içi uygulama (main).

### 2. Kod (TDD)
- **Task 1 `2889777`:** `Ekranlar/Veri/Yerel/` — `YerelModeller` (GoruntuKoli, GoruntuIrsaliye[SaatFarki], KuyrukSatiri, durumlar),
  `YerelKurallar` (Karar = bugünkü SevkKontrol, Uygula, YenidenUygula, Sinifla, CevrimiciSor, KodSozlugu), `YerelDepo` (SQLite,
  `LocalApplicationData/Modfex/sevkiyatmobil/yerel.db`, Dapper'sız, tarih tick/ondalık metin, WAL, SemaphoreSlim). Paket
  `Microsoft.Data.Sqlite 10.0.12` (Directory.Packages.props).
- **Task 2 `97994fe`:** `SevkDeposu.OkutAsync`/`LogYazAsync` → `okutmaAt` parametresi (kalem ReceiptDate + UZM_SevkOkutma.OkutmaAt;
  kalem InsertedAt Sentez kayıt saati kalır). `SevkDeposu.Aktarim.cs` `AktarAsync(KuyrukSatiri)` — kural reddi savepoint'e geri alınır,
  sınıflanır; `SevkSorgulari.Goruntu.cs` `GoruntuAsync` (tek gidiş-dönüş: GETDATE + başlık + koliler) ve `KoliAsync` (tek koli).
- **Task 3 `2f77264`:** `Gonderici` (tek örnek; tur: sıradaki → aktar → sonuç; hata → satır bekler, tur durur; işlenen irsaliyeleri
  tazeler; döngü 30 sn boş bekleme / 2-5-10-30 sn hata beklemesi; BaglantiHatasi sınıflaması). `YerelDepo.GoruntuTazeleAsync`
  tek kilitte bekleyenleri yeniden uygular.
- **Task 4 `9388709`:** `OkutmaViewModel` yerelden (ilk koli + onay çevrimiçi kalır; sonrası yerel karar → kuyruk → Durt; görüntüde
  yoksa / KoliMamuldeDegil / KoliBaskaIrsaliyede → 3 sn çevrimiçi soru), gönderim durumu satırı, ret bandı + Tamam, Tamamla engeli;
  irsaliye listesinde "N gönderilmedi"; gönderici `ModSecimViewModel` kurucusunda başlar; tamamlanınca yerel temizlik.
- **Son inceleme (opus alt ajan) + düzeltmeler `5680ad1`:** eski indirme yeni görüntüyü ezmesin (işaret = son işlenen kuyruk Id);
  `KoliBaskaIrsaliyede` artık uyarı (yalnız `KoliZatenOkundu` es geçilir); Tamamla ekranında son kontrol; `SQLitePCL.Batteries_V2.Init()`;
  aynı barkodlu kolilerde en büyük BoxId (sunucu gibi).
- **Komutlar:**
  ```bash
  dotnet test SevkiyatMobil.Tests                       # 85 geçti, 24 atlandı (DbFact)
  MODFEX_DB_TEST=1 dotnet test SevkiyatMobil.Tests      # 99/99 (Task 2'de; canlı SentezCore, transaction + ROLLBACK)
  dotnet publish SevkiyatMobil.Android -c Release -f net10.0-android
  cp SevkiyatMobil.Android/bin/Release/net10.0-android/publish/com.modfex.sevkiyatmobil-Signed.apk dagitim/sevkiyatmobil-2026-11-11.apk
  ```
- **APK:** `dagitim/sevkiyatmobil-2026-11-11.apk` (73,8 MB; libe_sqlite3 arm64 + armeabi-v7a içinde). Cihaz bağlı değildi → kurulmadı.

## Kararlar
- Sentez'e yazma bugünkü çekirdekle satır satır (fiş birebir aynı); okutma saati gönderim saati değil.
- Beklenmeyen hata kuyruğu durdurur, atlamaz. Diğer retlerde operatör "Tamam" yeterli.
- "Aynı box" = bu irsaliyede zaten var → es geç; başka irsaliyede → uyarı (inceleme sonrası).

## Açık kalanlar / sonraki adım
- PM66'ya kurulum + gerçek sevkiyatta deneme (SQLite yükleniyor mu, okutma hızı, gönderim, Tamamla).
- Ertelenen küçükler (ledger): dürtme kaybı (30 sn), bağlantı yokken 3 sn soru, ilk indirme için Yenile düğmesi, masaüstünden tamamlanan
  irsaliyenin kuyruk temizliği, ret log'u çift yazımı, büyük siparişte liste yeniden kurulumu.
- Okutma ekranı mantığı birim testsiz (cihazda denenecek).
