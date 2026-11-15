# sevkiyatmobil — 2026-11-15

## Bağlam
İş akışı dokümanındaki kurulum sırası (G4) madde 1: hibrit sürümle birlikte mamul girişte KLY kolisi reddi tek APK'da.

## Yapılanlar

### 1. Mamul girişte koli listesi (KLY) kolisi reddi
- **Neden:** SentezServis "Koli listesi"nden açılan koliler (`Erp_Box.SpecialCode = 'KLY'`) webden stoğa alınır (fiş 10, `UZM_PaketKoli.MamulFisId` dolar). sevkiyatmobil mamul girişte bunları tekrar alırsa çift stok; geri al da web'in fişini silerdi (sentezservis spec 2026-11-10 §8a).
- **Ne yapıldı (TDD):**
  - Test önce: `MamulKuralTestleri.Koli_listesinden_acilmis_koli_giris_ve_geri_alda_reddedilir` (KLY, "kly " → ret; "XYZ" → kabul). RED: `OzelKod`/`KoliListeKolisi` yok.
  - `KoliDurumu`'na `string? OzelKod = null` (son parametre).
  - `SevkKurallari.KoliListeOzelKodu = "KLY"`, `KoliListeKolisiMi()` (trim + büyük/küçük duyarsız); `MamulKontrol` null kontrolünden hemen sonra KLY → `SevkRet.KoliListeKolisi` (giriş ve geri al).
  - `SevkRet.KoliListeKolisi = 17`; metin TR/EN/AR: "Bu koli webden stoğa alınır (koli listesi): {0}".
  - `SevkDeposu.KoliAsync` SELECT'ine `bx.SpecialCode AS OzelKod`.
  - Sevk (120) ve hibrit kurallarına dokunulmadı: KLY kolisi webden stoğa alınınca normal sevk edilir.
- **Dokunulan dosyalar:** `SevkiyatMobil/Ekranlar/Veri/SevkKurallari.cs`, `SevkHatasi.cs`, `SevkDeposu.cs`, `SevkiyatMobil/Ekranlar/UygulamaMetinleri.cs`, `SevkiyatMobil.Tests/SevkKurallariTestleri.cs`
- **Komutlar:**
  ```bash
  dotnet test SevkiyatMobil.Tests            # 86 geçti, 24 atlandı (DB testleri, test DB yok)
  dotnet publish SevkiyatMobil.Android -c Release -f net10.0-android
  cp SevkiyatMobil.Android/bin/Release/net10.0-android/publish/com.modfex.sevkiyatmobil-Signed.apk dagitim/sevkiyatmobil-2026-11-15.apk
  ```
- **Sonuç:** APK `dagitim/sevkiyatmobil-2026-11-15.apk` (74,1 MB; hibrit + KLY reddi). adb yok / cihaz bağlı değil → kurulmadı.
- **Commit:** `833296d` — Mamul giris: koli listesinden acilmis (KLY) koli giris ve geri alda reddedilir

## Açık kalanlar / sonraki adım
- PM66'ya 11-15 APK'yı kur; hibrit okutma + KLY reddini canlıda dene.
- KoliAsync'in SpecialCode okumasını kapsayan DB testi yok (DB testleri bu makinede atlanıyor).
