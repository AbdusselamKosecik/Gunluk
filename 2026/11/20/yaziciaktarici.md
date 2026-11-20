# yaziciaktarici — 2026-11-20

## Bağlam
Kullanıcı istedi: "bana bir zebra printer simülasyonu yazar mısın, 9100 portuna gönderdiğimde ekranda resim olarak gözüksün."
Amaç: etiketleri (mal kabul seri ve raf etiketleri) yazıcı ve kâğıt harcamadan, terminalden gerçek gönderimle denemek.

## Yapılanlar

### 1. ZebraSimulator (WinForms, net10.0-windows)
- **Neden:** Gerçek yazıcı (ZD888) 192.168.0.184'te ve paylaşımlı. Etiket tasarımını denemek her seferinde kâğıt harcıyor ve yazıcının başında olmayı gerektiriyordu.
- **Ne yapıldı:**
  - `ZplSunucu`: TcpListener. Her bağlantı bir iştir; istemci kapatınca ya da 1,5 sn veri gelmeyince biter, 4 MB sınırı var. Kural Yazıcı Aktarıcı'daki `Dinleyici` ile aynı.
  - `ZplAyristirici`: akıştaki her `^XA…^XZ` bloğu bir etiket; aradaki komutlar ve yarım blok atılır.
  - `ZplCizici`: BinaryKits.Zpl.Viewer 1.3.1 ile PNG'ye çizer; çevrimdışıdır, içerik dışarı gitmez. Labelary API'si bu yüzden seçilmedi: etiketlerde sipariş ve tedarikçi bilgisi var.
  - `AnaForm`:
    - üstte port, Başlat/Durdur, etiket mm × mm, dpi (203/300/600), PNG kaydet, Temizle ve "Dinliyor: IP:port";
    - solda gelen etiketler (saat, gönderen IP);
    - sağda resim (Zoom) ve ham ZPL.
  - Argüman `--port N`. Açılışta otomatik dinlemeye başlar.
- **Dokunulan dosyalar:**
  - `ZebraSimulator/ZebraSimulator.csproj`, `ZebraSimulator/ZplCekirdek.cs`, `ZebraSimulator/Program.cs`
  - `ZebraSimulator.Tests/*`, `YaziciAktarici.slnx`, `README.md`
- **Komutlar:**
  ```bash
  dotnet test ZebraSimulator.Tests
  dotnet publish ZebraSimulator -c Release -r win-x64 --self-contained -p:PublishSingleFile=true -o publish/ZebraSimulator
  ```
  `IncludeNativeLibrariesForSelfExtract=true` eklendi; yoksa libSkiaSharp.dll ve libHarfBuzzSharp.dll exe'nin yanında kalıyor.
- **Sonuç / doğrulama:**
  - TDD: 5 test önce kırmızı (derlenmedi), sonra yeşil. Testler: bölme, PNG ölçüsü 99 mm @ 8 dpmm = 792 px, TCP kapatılan iş, açık kalan bağlantıda boşta kalma.
  - Mal kabulün gerçek `SeriEtiketi.Zpl` ve `RafEtiketi.Zpl` çıktıları PNG'ye çizildi ve kontrol edildi: QR, Türkçe harfler ve çizgiler doğru.
  - Fark: kütüphanenin yazı tipi "-" işaretini " – " gibi gösteriyor.
  - Uzun raf kodu (WH01-Z04-R08-L09-P05) simülatörde iki satıra kırılıyor. Gerçek yazıcıda denenmeli.
  - YaziciAktarici.Tests 4/4.
- **Hata / ders:**
  - Pencereyi PowerShell `CopyFromScreen` ile yakalamaya çalıştım; DPI ölçeği yüzünden arkadaki başka pencere yakalandı.
  - Dosya hemen silindi. Ekran yakalama yöntemi bir daha kullanılmayacak; doğrulama doğrudan PNG çizimiyle yapılıyor.
- **Commit:** `c2b5715`.

## Açık kalanlar
- İlk açılışta Windows Güvenlik Duvarı izni gerekiyor (özel ağ).
- Terminalde yazıcı IP'si olarak simülatörün çalıştığı PC'nin IP'si girilip uçtan uca denenecek.
- malkabul: dünkü depo parametreleri değişikliğinin (`5a4dee0`) kod gözden geçirmesi oturum kapanınca yarım kaldı. APK ve masaüstü paketi derlendi ama terminale yüklenmedi.
