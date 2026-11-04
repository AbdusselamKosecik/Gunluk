# mobileverimlilik — 2026-11-04

## Bağlam
Sahadan yine "sabah sıfırlanma yapmıyor" şikâyeti geldi. 2026-09-10'daki düzeltme (`963a684`,
SQL'e gün filtresi + dünden kalan açık satırları kapatma) yerindeydi. Hedef: kalan sebebi
bulmak ve yeni release APK çıkarmak. Başlangıç: temiz `main`, son commit `782ae97`.

## Yapılanlar

### 1. Kök neden: gece yarısı çıkış timer'ı cihaz uykudayken ilerlemiyor
- **Neden:** Uygulama gece boyunca üretim ekranında açık kalıyor. Gün değişimi tek bir yerde
  ele alınıyordu: `production_screen.dart` `_scheduleMidnightLogout()` →
  `Timer(gece yarısına kadarki süre, _logout)`.
- **Bulgu:** Dart `Timer`'ları monotonik saate bağlı. Android cihaz uykuya geçince
  (ekran kapalı / doze) bu saat duruyor. Öğleden sonra kurulan 9 saatlik timer, gece uyunan
  saatler kadar geç tetikleniyor. Sonuç: sabah ekran dünkü oturum, operasyon ve sicille
  açık kalıyor; `load()` çalışmadığı için ekran tazelenmiyor.
- **Ek bulgu:** `ProductionController._updateLastRecord` (10 sn'lik tick) state'e
  `toplamMesaiDakika` ve `ortalamaStandartDakika` değerlerini yazmıyordu (`copyWith` eski
  değeri koruyor). Bu yüzden adet sıfırlansa bile mesai dünkü değerde kalıyordu.
- **Ne yapıldı:**
  - `_ProductionScreenState` artık `WidgetsBindingObserver` kullanıyor. `initState`'te
    `_sessionDay` (oturumun açıldığı gün 00:00) kaydediliyor. `Timer.periodic(30 sn)` ve
    `didChangeAppLifecycleState(resumed)` → `_checkDayChange()`: bugün > `_sessionDay` ise
    tek seferlik `_logout` çalışıyor (`_dayChangeHandled` bayrağıyla korunuyor). Periyodik timer da
    uykuda duruyor ama cihaz uyanınca hemen tetikleniyor; karşılaştırma duvar saatiyle
    (`DateTime.now()`) yapıldığı için kaçırma olmuyor.
  - `_updateLastRecord` içindeki `copyWith`'e `toplamMesaiDakika` ve `ortalamaStandartDakika` eklendi.
- **Dokunulan dosyalar:** `lib/features/production/screen/production_screen.dart`,
  `lib/features/production/provider/production_provider.dart`
- **Komutlar:**
  ```powershell
  & C:\flutter\bin\flutter.bat analyze lib/features/production
  & C:\flutter\bin\flutter.bat test test/gunluk_sifirlama_test.dart
  $env:JAVA_HOME = "C:\Program Files\Android\openjdk\jdk-21.0.8"
  $env:Path = "$env:JAVA_HOME\bin;$env:Path"
  & C:\flutter\bin\flutter.bat build apk --release
  ```
- **Sonuç / doğrulama:** analyze → yeni error/warning yok (tek warning `production_service.dart:230`
  unused_local_variable, bu değişiklikten önce de vardı). `gunluk_sifirlama_test.dart` 3/3 geçti.
  `√ Built build\app\outputs\flutter-apk\app-release.apk (56.2MB)`.
  Gece yarısı geçişi cihazda test **edilmedi**; sahada bir gece sonra doğrulanmalı.
- **Commit:** `330da0d` — Sabah sifirlanmayan ekrani duzelt: gun degisimini duvar saatiyle kontrol et

## Kararlar
- Gün değişiminde mevcut `_logout` yolu kullanıldı: açık satırları kapatıp gönderiyor ve login'e
  dönüyor. Login sonrası `load()` her şeyi tazeliyor. Ekranı yerinde sıfırlamak yerine bu yol
  seçildi; davranış eskisiyle aynı, sadece doğru zamanda tetikleniyor.
- Uzun süreli tek `Timer` yerine "kısa periyot + duvar saati karşılaştırması" kalıbı kullanılacak.

## Açık kalanlar / sonraki adım
- Sahada bir gece sonra doğrulama.
- Gece yarısını geçen vardiya varsa, 00:00'da logout işçiyi vardiya ortasında çıkarır. Böyle bir vardiya var mı, sorulmalı.
- 09-10 günlüğündeki açıklar hâlâ duruyor: gönderilemeyen satırlar için tekrar deneme kuyruğu,
  `_sendRowToServer` içindeki sessiz `catch`, `widget_test.dart` şablon testi.
