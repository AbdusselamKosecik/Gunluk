# timecraft — 2026-11-20

## Bağlam
Saha: "5000-6000 arası demiştik, varyantları gelmemiş." (Dünkü `079a3c5` işlem listesi Sentez 5000–5999.)

## Yapılanlar

### 1. Tablette işlem kodu listesi 60 ile kesiliyordu
- **Teşhis (salt okunur, SentezLive):** Erp_Process 5xxx: 197 dört haneli + 223 tireli varyant (5206-1 …) = 420,
  silinmiş 0 → sunucu sorgusu varyantların hepsini getiriyor. Dışarıda kalanlar yalnız 50/51/55/501/502 (üst grup)
  ve 5 haneli 50100, 50104 (adsız), 51116, 51117. Web `<select>` hepsini gösteriyor.
  Kök neden tablet `AutoCompleteField`: boş aramada `.take(60)` → yalnız 5000–505x görünüyor, 52xx/53xx varyantları hiç.
- **Ne yapıldı:** `ui/common/Components.kt` saf `filterOptions(value, options, label)` (sınır yok, arama etiket
  üzerinden), `AutoCompleteField(optionLabel=…)`. `ui/editor/EditorScreen.kt`: kod menüsü "5206-1 — ÖN SÜRME",
  açıklama menüsü "ÖN SÜRME (5206-1)" ve tekilleştirilmiş; açıklama da kod alanında aranabilir.
- **Test:** `android/app/src/test/.../ui/common/FilterOptionsTest.kt` (3). Tüm birim testler 26/26, debug APK derlendi.
- **Komut:** `JAVA_HOME=".../jdk-21.0.8" ./gradlew --no-daemon :app:testDebugUnitTest :app:assembleDebug`
- **Çıktı:** `X:\Gitlab\fredericTr\EtutVision-debug.apk` (yenilendi, 10:57). Sunucu tarafı değişmedi.
- **Commit:** `e668243`

## Açık kalanlar
- APK tablete kurulmalı; dünkü `TimeCraft-iis-20261119.zip` sunucuya kurulmadıysa liste hâlâ eski 16 kod olur.
- 5 haneli yıkama kodları (50100, 51116, 51117) listeye alınsın mı — cevap bekleniyor.
