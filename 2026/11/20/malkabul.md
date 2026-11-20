# malkabul — 2026-11-20

## Yapılanlar

### 1. Masaüstü uygulaması açıldı
- Dünkü `5a4dee0` derlemesi (scratchpad `mk_win`) kullanıcı için başlatıldı.
- İlk açılışta saat 21:28'de "Şirketler okunamadı" hatası alındı: SQL 192.168.0.2'ye ağ bağlantısı anlık koptu (Win32 64, network name no longer available).
- `Test-NetConnection 192.168.0.2 -Port 1433` başarılı oldu; uygulama yeniden açıldı, hata tekrarlamadı.

### 2. Android emülatörü (Modfex'e özel)
- **Neden:** Kullanıcı uygulamayı emülatörde görmek istedi. Var olan `Terminal_API23` emülatöründe Modasima uygulamaları kurulu; kullanıcı "Modasima için olanı değil, Modfex için olanı" dedi.
- **Ne yapıldı:**
  - Yeni AVD `Modfex_Terminal` oluşturuldu: android-34 google_apis x86_64, 720×1280, density 320, donanım klavyesi, çerçevesiz.
    ```powershell
    $env:JAVA_HOME="C:\Program Files\Android\openjdk\jdk-21.0.8"
    avdmanager create avd -n Modfex_Terminal -k "system-images;android-34;google_apis;x86_64" -d pixel
    # config.ini: hw.lcd.width=720, hw.lcd.height=1280, hw.lcd.density=320, hw.keyboard=yes, showDeviceFrame=no
    emulator -avd Modfex_Terminal -no-snapshot-save -no-boot-anim
    ```
  - APK yalnız arm/arm64 derleniyordu: emülatörde INSTALL_FAILED_NO_MATCHING_ABIS.
    - Komut satırından `-p:RuntimeIdentifiers=android-x64` verilince ayar alt kütüphane projesine de geçti ve AVLN9999 hatası alındı.
    - Çözüm: `MalKabul.Android.csproj`'a koşullu `RuntimeIdentifiers` eklendi (`-p:Emulator=true` → android-x64).
    ```bash
    dotnet publish MalKabul.Android -c Release -p:Emulator=true -o <klasör>
    adb install -r <klasör>/com.modfex.malkabul-Signed.apk
    ```
- **Sonuç:** Uygulama emülatörde açıldı ve çalışıyor, çökme yok. Sunucu ayarlarını ilk açılışta kullanıcı girecek.
- **Commit:** Android emülatör derleme anahtarı (bu günün malkabul commit'i).

## Notlar
- Emülatörden ana makinedeki Zebra simülatörüne basmak için yazıcı IP'si `10.0.2.2`, port 9100. 10.0.2.2, emülatörün ana makineye ulaştığı adres.

## Açık kalanlar
- `5a4dee0` için kod gözden geçirmesi yarım kaldı.
- PM66'ya yeni APK yüklenmedi.

### 3. Emülatör bağlantısı (VPN)
- **Durum:** Emülatör, VPN üzerinden 192.168.0.2'ye erişiyor.
  - Ping gidiyor, ~470 ms. 1433 portu açık.
  - Ana makine bu adrese "Ethernet 2" (10.250.0.10) üzerinden çıkıyor.
- **Bağlanamama sebebi:** Veritabanı alanına "SenezCore" yazılmıştı ("t" eksik); kullanıcının girdiği şifre doğruydu.
  - Emülatör klavyesi US düzeninde (hw.keyboard, qwerty2). Türkçe ana makine klavyesiyle yazarken karakter kayabiliyor.
- **Ne yapıldı:**
  - Alanlar `adb shell input` ile dolduruldu.
  - Şifre masaüstü ayarından DPAPI ile çözülüp doğrudan emülatöre yazıldı, hiçbir yere basılmadı. DPAPI entropisi "Modfex.Ortak.Ayarlar", önek "dpapi:".
  - Yazıcı IP'si 10.0.2.2 yapıldı.
- **Sonuç:** Giriş ekranında şirket listesi geldi.

### 4. Ayarlar: sayım deposu açılır liste
- **Ne yapıldı:**
  - Kullanıcı: "depo seçimlerini combobox yapalım tüm uygulamalarda, depo varsa depo yeri de."
  - Tüm uygulamalar tarandı. Elle RecId girilen tek alan malkabul ayarlarındaki `SayimDepoId` (NumericUpDown) idi.
  - Bu alan `ParametreSatiri` ile depo + depo yeri ComboBox'ına çevrildi; "—" seçeneği = yok.
  - Bağlantı kaydedilmemişse liste görünmez ve kayıtlı değer korunur.
- **Test:** `AyarlarDepoTestleri` 3 test.
- **Commit:** `57f615b`.

### 5. Terminal: kaydırılabilir menü + Manuel mal kabul + son seri no
- **Kullanıcı istekleri:**
  - Menü küçük ekranda sığmıyor; sürüklenebilsin.
  - Mobilde okutarak almanın yanında manuel giriş olsun: tek tek renk, kg, lot girilerek.
  - Etiket basılsın; yazıcı uzakta olduğu için son seri no ekranda yazsın. Depocu numarayı topun üstüne yazacak, etiketler sonra yapıştırılacak.
- **Ne yapıldı:**
  - `TerminalMenuView`: ScrollViewer eklendi; yeni düğme "Manuel mal kabul (etiketsiz)".
  - `SeriOlusturAlViewModel` yeniden yazıldı:
    - sipariş verilmezse önce sipariş listesi (arama) gelir;
    - satır = sipariş satırı × renk; yenilemede aynı renk seçili kalır;
    - miktar başlığında birim yazar ("Top / paket miktarı (KG)");
    - `SonSeri` (aralık olabilir) + `SonSeriBilgi` (stok · renk · miktar · lot) büyük kartta gösterilir;
    - etiket basılamazsa kart kırmızı olur.
  - `EtiketBas` artık sipariş no'yu parametre olarak alıyor.
- **Testler:** 211/211 (DB dahil).
- **Commit:** `e4f4b42`.
- **Dağıtım:** Emülatöre kuruldu (`-p:Emulator=true`). PM66'ya henüz yüklenmedi.

### 6. Üretimden iade order'a bağlı + üretime verde harici seri
- **Kullanıcı istekleri:**
  - Üretimden iadede de order seçilsin; yalnız teslim ettiğimiz order'lar listelensin, yalnız teslim ettiğimiz seriler okutulsun.
  - Üretime verde harici verilebilsin (aynı kumaş, boştaki farklı seri). Onay istensin: "bu fazla verdiğiniz kumaş yönetime raporlanacaktır, lütfen neden verdiğinizi yazınız"; yazmadan ve tamam demeden verilmesin.
- **Veri katmanı (`UretimDeposu`):**
  - `UretimdekiOrderlarAsync`: WorkOrderType 15 order'lar içinden tahsis tablosunda 129 − 29 toplamı > 0 olanlar.
  - `IadeAlAsync(..., workOrderId)`: serinin son 129 tahsisinin order'ı seçili order değilse `SeriBuOrderaVerilmedi`.
  - `UretimeVerAsync(..., hariciNeden)`:
    - seri tahsissizse ve neden boşsa `HariciNedenGerekli`;
    - neden varsa fiş 129 kaleminin `Explanation` alanına "HARİCİ: neden" yazılır (200 karakter sınırı). Yönetim raporu bu alandan çekilir.
  - `SeriUretimDurumu`'na `TahsisWorkOrderId`, `UretimWorkOrderId`, `UretimOrderNo` eklendi.
- **Terminal (`UretimViewModel`):**
  - Order seçimi iki modda da zorunlu; iade modunda liste üretimdeki order'lardan gelir.
  - İadede okutulan seri başka order'a verilmişse ya da üretimde değilse hemen reddedilir.
  - Verirken başka order'a tahsisli seri hemen reddedilir. Tahsissiz seride kırmızı uyarı kutusu ve neden kutusu açılır; neden boşken Kaydet reddedilir.
- **Testler:**
  - `HariciIadeTestleri` 5 test (DB).
  - `UretimEkraniTestleri` güncellendi (+4 test).
  - Eski testlerde tahsissiz seri veren 12 çağrıya `hariciNeden: "test"` eklendi.
  - Toplam 220/220.
- **Commit:** `e4c19bd`. Emülatöre kuruldu; PM66'ya kurulmadı.
