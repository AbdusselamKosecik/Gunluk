# paketleme — 2026-11-02

## Bağlam
Kullanıcı: ürün etiketinde ad ortalanmasın; uzun kayıtta baştaki kod görünmüyor. Sonra: yalnız değişen dosyalarla paket (internet kötü).

## Yapılanlar

### 1. Ürün etiketi kod/ad satırı sola dayalı, taşma yok
- **Neden:** Satıra sığdırma tek ortalama genişlikle (0,45 × yükseklik → 42 mm'de 33 karakter) yapılıyordu. Büyük harfli uzun adlar
  (ör. `6502 ROME SOFT PUSH UP REGULAR DANTELLI TEK SÜTYEN`, 50 kr) satırı aşıyor; Zebra tek satırlık ^FB'de taşanı aynı satıra
  bindiriyor, ortalı yazıda baştaki kod eziliyordu.
- **Ne yapıldı:** `UrunEtiketi.cs`: kod/ad satırı `'L'` (beden · renk ortalı kaldı). `Sigdir` artık karakter başına genişlik tahminiyle
  (`KarakterGenisligi`: dar i/l/./boşluk 0,27; f/t/r/-/1 0,35; M/W 0,78; m/w 0,68; büyük 0,58; rakam 0,52; küçük 0,48) ve %97 sınırla
  sondan kırpar; `AzamiKarakter` yerine `GenislikMm(s, h)`. Koli etiketi aynı `Sigdir`'i kullanıyor.
- **Dokunulan dosyalar:** `Paketleme/Ekranlar/Veri/UrunEtiketi.cs`, `Paketleme.Tests/UrunEtiketiTestleri.cs`
- **Sonuç / doğrulama:** `dotnet test Paketleme.Tests` → 167 geçti (57 DB testi atlandı); yeni test: büyük harfli uzun ad kodla başlar, L hizalı, ≤ 42 mm. Gerçek baskıda denenmedi.
- **Commit:** `03988b1` — Urun etiketi: kod/ad sola dayali; satira sigdirma karakter genisligine gore

### 2. Yama paketi (yalnız değişen dosyalar)
- **Komutlar:** `yayinla.ps1 -Hedef dagitim/paketleme-win-x64-yeni`, ardından eski yayın klasörüyle (`paketleme-win-x64`, 01.11) SHA256 karşılaştırma.
- **Sonuç:** Farklı: `Paketleme.dll`, `Paketleme.Desktop.dll`, `Paketleme.Desktop.exe` (+ pdb'ler, pakete konmadı) →
  `dagitim/paketleme-yama-2026-11-02.zip` (1,7 MB). Tam paket de `paketleme-win-x64-2026-11-02.zip`. Yeni yayın klasörü `paketleme-win-x64`
  oldu (bir sonraki yamanın karşılaştırma tabanı). Yama, 01.11 paketi kurulu makineye uygulanır.

## Açık kalanlar / sonraki adım
- Gerçek yazıcıda uzun büyük harfli adla deneme; gerekirse genişlik katsayıları ayarlanır.

### 3. Ürün adı değiştirilmeden basılır
- **Neden:** Kullanıcı: kod 6824, ad "6824 Venedik Balensiz Desteksiz Mikro Sütyen"; etikete "Venedik …" geliyordu (13.10.2026'daki
  "ad kodla başlıyorsa kod kırpılır" kuralı). Ad olduğu gibi gelmeli.
- **Ne yapıldı:** `UrunEtiketi.UrunAdi` (kırpma) kaldırıldı; `KodAdMetni`: ad Sentez'deki haliyle; "kod yazılsın" açıksa ve ad kodla
  başlamıyorsa başına kod eklenir (çift kod yok); ad boşsa kod. Koli MODEL satırı da aynı fonksiyonu kullanıyor.
- **Dokunulan dosyalar:** `Paketleme/Ekranlar/Veri/UrunEtiketi.cs`, `KoliEtiketi.cs`, `Paketleme.Tests/UrunEtiketiTestleri.cs`
- **Sonuç:** 165 test geçti. Yama: `dagitim/paketleme-yama-2026-11-02b.zip` (Paketleme.dll, Paketleme.Desktop.dll, .exe; 1,7 MB);
  tam paket `paketleme-win-x64-2026-11-02.zip` yeniden üretildi.
- **Commit:** `889fa12` — Etiket: urun adi degistirilmeden basilir
