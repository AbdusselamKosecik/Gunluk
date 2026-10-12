# sevkiyatmobil — 2026-10-12

## Bağlam
11.10'da yalnız tasarım vardı (koliyi 120 irsaliyesine okutma). 12.10'da paketleme akışı değişti: koli kapanınca 42'de kalır,
Mamul'e (41) geçişi el terminali yapar. Kullanıcı "/loop 15m maddeleri konuştuğumuz gibi bitir" dedi.

## Yapılanlar

### 1. Tasarım güncellemesi — `de22934`
- Spec §0: iki mod. **MAMUL GİRİŞ**: koli okut → fiş 17 (Out 42, In 41; başlık/kalem/varyantta ikisi dolu, Sentez'deki tek 17
  kaydı gibi), günlük tek başlık `SpecialCode='MGR'`, kalem koli başına, `UZM_PaketKoli.MamulFisId/MamulAt/MamulUserId`;
  aynı gün sevk edilmemişse geri al. **SEVKİYAT**: 120 aynen + `KoliMamuldeDegil` reddi. Etikette QR + Code 128 (lazer okur).

### 2. Uygulama (alt ajan, sonuç bende incelendi) — `9fa2711`, `2a36eee`, `e28646f`, `0dd1549`
- İskelet: Avalonia 12.1.2 / .NET 10, `Ortak/` paketlemeden, Android API 23 (arm/arm64, Mono), Desktop, Tests.
- `SevkKurallari` (saf): barkod normalleştirme (P1/P2 kırp, P4 ret), ret sırası, kalem birleştirme, mamul kabul.
- Fiş 17 ve 120 yazımı (paketleme FisSql/FisYazici kopyası + transfer yönü), `db/0001_sevkiyatmobil.sql`
  (UZM_SevkIrsaliye, UZM_SevkOkutma, `SevkFisTipi=120`; 0002 Mamul kolonları yoksa durur).
- Ekranlar: mod seçimi, mamul giriş (günlük sayaç, son sonuç, geri al), açık irsaliyeler, okutma (ilk okutma müşteri onayı), tamamla.
- Canlıda doğrulanan (salt okuma): 120 başlığında `DriverName/DriverIdNo/PlateNumber/ShipTo*` var; ağırlık/koli sayısı kolonu yok
  → yalnız ekranda gösterilir.
- **Komutlar / sonuç:**
  ```bash
  dotnet test                                        # 59 geçti
  MODFEX_DB_TEST=1 MODFEX_DB_TEST_SEMA=1 dotnet test # 71/71 (şema test transaction'ında kurulur, ROLLBACK; canlıda iz yok)
  dotnet build SevkiyatMobil.Android                 # geçti; Release APK
  ```
- APK: `X:\Gitlab\modfex-apparel\sevkiyatmobil\dagitim\sevkiyatmobil-2026-10-12.apk` (debug anahtarıyla imzalı, 71 MB; dagitim gitignore'da).

## Kararlar (alt ajanın, kullanıcı değiştirebilir)
- İkisi birden geçerliyse "başka sipariş" reddi "Mamul'de değil"den önce; mamulde "sevk edilmiş" "zaten mamulde"den önce.
- 17'de e-irsaliye kapalı (mevcut 17 gibi), 120'de açık.
- Koli irsaliyeden çıkarma / mamul geri alma fiş satırlarını siler (IsDeleted değil).

## Açık kalanlar
- SQL sırası (kullanıcı): paketleme `db/0002_tezgah.sql` → sevkiyatmobil `db/0001_sevkiyatmobil.sql`.
- APK terminale yüklenmeli; lazer okuyucu girişi, titreşim/bip, ekranlar cihazda denenmedi.
