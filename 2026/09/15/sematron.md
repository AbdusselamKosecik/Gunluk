# sematron — 2026-09-15

## Bağlam
`X:\Gitlab\Modasima\sematron` boş klasördü. Kullanıcı eski Sentez EDefter `MainWindow.cs` kodunu verdi
(içinde `SchematronExecuter.ExecuteSchematron("Edefter\sch\edefter_yevmiye.sch", file)` + `GetErrors`).
Hedef: bir e-Defter ay klasörünü (`06`) seçip içindeki XML'leri şematronla kontrol eden bağımsız WPF uygulaması.

## Yapılanlar

### 1. Şematron kaynaklarını ve motor seçeneğini araştırma
- **Neden:** Eski `SchematronExecuter` kaynağı ve GİB `.sch` dosyaları diskte yok (Y:\win-x64\EDefter\EDefter.exe tek dosya paketlenmiş, 228 MB).
- **Ne yapıldı:** Örnek e-defter sch/XML için `github.com/serayuzgur/lightsch` klonlandı (sadece test için, repoya konmadı).
  GİB e-defter sch'leri `queryBinding="xslt2"`: `matches`, `ends-with`, `xs:decimal`, `a/normalize-space(b)` kullanıyor
  → .NET `XslCompiledTransform` (XSLT 1.0) çalıştıramaz.
- **Karar:** Saxon-HE 12.10 (Java) IKVM ile .NET 10'a (`IKVM.Maven.Sdk 1.11.0` + `SaxonHE12s9apiExtensions 12.10.1` + `MavenReference net.sf.saxon:Saxon-HE 12.10`)
  ve SchXslt 1.10.1 (Maven Central `name.dmaus.schxslt:schxslt:1.10.1` jar içindeki `xslt/2.0/*`) ile `.sch → XSLT → SVRL`.
- **Komutlar:**
  ```bash
  curl -sL -o schxslt.jar https://repo1.maven.org/maven2/name/dmaus/schxslt/schxslt/1.10.1/schxslt-1.10.1.jar
  unzip schxslt.jar   # xslt/2.0/* → src/Sematron.Core/SchXslt/
  ```

### 2. Çözüm iskeleti
- **Komutlar:**
  ```bash
  dotnet new sln -n Sematron --format sln
  dotnet new classlib -n Sematron.Core -o src/Sematron.Core -f net10.0
  dotnet new wpf -n Sematron.App -o src/Sematron.App -f net10.0
  dotnet new console -n Sematron.Cli -o tools/Sematron.Cli -f net10.0
  ```
- İlk derleme Saxon'u Maven'dan çekip IKVM ile çeviriyor: ~4,5 dk, IKVM0100/0117 uyarıları normal.

### 3. Sematron.Core
- **Dokunulan dosyalar:** `LedgerKind.cs`, `LedgerFileDetector.cs` (ad deseni `-(Y|K|YB|KB|DR|DRB)-\d+\.xml`, `GIB-` önek; yoksa kök eleman + `gl-cor:entriesType` journal/ledger),
  `LedgerSource.cs` (xml + zip içi kayıt tarama), `SchematronCatalog.cs` (sch klasöründe `edefter_{yevmiye|kebir|berat}.sch`, yoksa anahtar kelime; `..\xsd\edefter.xsd`),
  `SchematronEngine.cs`, `XsdValidator.cs`, `LedgerChecker.cs` (tür→sch→XSD+şematron, rapor), `ValidationModels.cs`.
- **Önemli bulgular (yeniden yaparken tuzaklar):**
  1. `Xslt30Transformer.applyTemplates` global context item vermez → global `<let value="/edefter:defter/...">` için `XPDY0002 context item is absent`. Çözüm: `transformer.setGlobalContextItem(document)`.
  2. SchXslt 2.0 hattı yalnız `xslt2/xslt3` kabul eder → `queryBinding` boş/`xslt` ise bellekte `xslt2`'ye çevrilir.
  3. Örnek sch'de `normalize-space(ceiling(x))` gibi ifadeler XPath 2.0'da `XPTY0004` veriyor ve **tüm dönüşümü** durduruyor.
     İlk deneme: tüm XSLT'yi `version="1.0"` (geriye uyumluluk modu) ile tekrar çalıştırmak → **yanlış pozitif** üretti
     (tarih karşılaştırmaları sayıya dönüp NaN). Vazgeçildi.
     Son çözüm: üretilen XSLT'de `svrl:failed-assert/successful-report` içeren her `xsl:if` → `xsl:try` + `xsl:catch`
     (root `version="3.0"`), catch'te `sematron:evaluation-error` elemanı → "Kural değerlendirilemedi" uyarısı.
  4. `ErrorReporter` tipi `net.sf.saxon.lib.ErrorReporter` (s9api değil).
- **Sonuç / doğrulama:** `Sematron.Cli <06> <sch>`: geçerli yevmiye/kebir/berat örnekleri + zip içi berat **Geçti**,
  `negativeData.xml` **Hatalı** (ds:Signature zorunlu, 11611 borç/alacak eşitliği, 11619, 11623). 53 MB yevmiye: 33 sn.

### 4. Sematron.App (WPF)
- **Dokunulan dosyalar:** `App.xaml(.cs)`, `MainWindow.xaml(.cs)`, `ViewModels.cs`, `AppSettings.cs` (`%AppData%\Sematron\settings.json`).
- Klasör seç (OpenFolderDialog) → otomatik kontrol; sürükle-bırak; `Sematron.exe "<klasör>"`; F5/Esc/Ctrl+O.
  Sol: dosyalar (durum rozeti, tür, hata/uyarı, boyut, süre). Sağ: mesajlar (seviye, kaynak, mesaj, konum; satır detayında XPath + kural + teknik ayrıntı),
  "Tüm dosyalar", "Yoksayılanlar", arama; Ctrl+C kopyala; rapor .txt (`Konum:… Hata:…`) / .csv. Paralellik ≤4.
- "Bilinen istisnayı yoksay": eski koddaki `En az bir gl-cor:entryHeader elemanı bulunmalıdır` istisnası.
- **Hata/düzeltme:** `ProgressBar.Value` varsayılan TwoWay → private setter'da XAML istisnası; `Mode=OneWay` yapıldı.
- **Doğrulama:** Ekran kilitli olduğu için ekran görüntüsü alınamadı; geçici `RenderTargetBitmap` kancasıyla pencere PNG'ye çizildi, kontrol edildi, kanca silindi.
  `dotnet publish src/Sematron.App -c Release -r win-x64 --self-contained -o publish` (224 MB) çalıştı; `publish\EDefter\sch` otomatik bulundu.
- **Commit:** `a696c14` — e-Defter şematron kontrol uygulaması (WPF, .NET 10)
- **Remote:** `git@gitlab.com:modasima/sematron.git` (push-to-create ile oluştu)

## Kararlar
- GİB `.sch` dosyaları repoya konmadı (uygulama klasörü seçtirir / `EDefter\sch` arar). lightsch sch'leri lisanssız ve değiştirilmiş → sadece test.
- Tüm-stylesheet uyumluluk modu yerine assert bazında `xsl:try` izolasyonu.

## Açık kalanlar / sonraki adım
- Gerçek GİB e-Defter paketindeki güncel `sch` dosyaları ve gerçek bir `06` klasörüyle deneme yapılmadı.
- XSD kontrolü gerçek `edefter.xsd` (XBRL importları) ile test edilmedi.
- Defter raporu (`-DR-`) şematron adı GİB paketine göre doğrulanmalı.
