# malkabul — 2026-11-23

## Bağlam
Kullanıcı tablette (PM66, adb seri `1ed69882`) sayımda miktar girerken uygulamanın hata verip kapandığını bildirdi. Canlı logcat ile yakalandı.

## Yapılanlar

### 1. PM66 çökmesi: Sayım → Yeni Seri aramasında SQL zaman aşımı (`9dc330b`)
- **Neden:** Uygulama kapanıyordu. Logcat'te `FATAL EXCEPTION: main` ve `SqlException: Execution Timeout Expired` vardı. Yığın `SayimViewModel.AramaYapAsync` → `SayimDeposu.MalzemeAraAsync` yolunu gösteriyordu.
- **Kök neden:** `YeniSeri` komutu `AramaYapAsync()`'i `GuvenliAsync` olmadan döndürüyordu. Bu yüzden AsyncRelayCommand'daki istisna UI thread'e çıktı ve süreç öldü. Metin değişince yapılan arama korumalıydı, buton yolu korumasızdı. Uygulamada genel bir yakalayıcı da yoktu.
- **Sorgu süresi:** Aynı sorgu PC'den canlıda ölçüldü: boş arama 54 ms, 'K' 40 ms, 'KUM' 1,07 sn (4202 stok). Tablet anında 30 sn'yi aşması ağ (Wi-Fi) ya da anlık kilitle ilgili görünüyor. Tekrarlanamadı.
- **Ne yapıldı:**
  - `SayimViewModel.YeniSeri` → `return GuvenliAsync(AramaYapAsync);`
  - `App.OnFrameworkInitializationCompleted` içine `Dispatcher.UIThread.UnhandledException` eklendi. Hatayı `Gunluk.Yaz` ile günlüğe yazar, `e.Handled = true` yapar ve `KabukViewModel.Ornek.Hata` ile gösterir (SqlException için "BaglantiYok").
- **Dokunulan dosyalar:** `MalKabul/Ekranlar/SayimViewModel.cs`, `MalKabul/App.axaml.cs`
- **Komutlar:**
  ```bash
  adb -s 1ed69882 logcat -c && adb -s 1ed69882 logcat -v time > logcat.txt   # yakalama
  dotnet build MalKabul.Desktop ; dotnet test MalKabul.Tests --filter Sayim   # 16 geçti
  dotnet publish MalKabul.Android -c Release -o <dir>
  adb -s 1ed69882 install -r dagitim/malkabul-2026-11-23.apk                # Success, 09:47:38 cihaz saati
  ```
- **Sonuç:** Yeni APK PM66'ya kuruldu (21.11 sürümünün üzerine). Artık zaman aşımı olursa uygulama kapanmaz, hata ekranda bildirim olarak görünür.
- **Commit:** `9dc330b` — Sayim: Yeni Seri aramasi korumali; UI thread'de yakalanmamis hata uygulamayi kapatmaz

## Kararlar
- Komut bazında korumanın yanında uygulama genelinde bir güvenlik ağı da eklendi. Gerekçe: tek bir korumasız komut tüm uygulamayı kapatıyordu.

## Açık kalanlar / sonraki adım
- Tablette 30 sn'lik zaman aşımının kaynağı (Wi-Fi mi, kilit mi) belirsiz. Tekrarlarsa `sys.dm_exec_requests` ile engelleme kontrol edilmeli.
- Diğer terminallere (39916cf0) de 23.11 APK'sı kurulmalı.
