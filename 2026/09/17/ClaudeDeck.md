# ClaudeDeck — 2026-09-17

## Bağlam
Sıfırdan yeni proje. İstek: `X:\` altındaki git repolarını "Tara" deyince SQLite'a kaydeden, sekmeli ve
sekme içinde 1/2/1+2/2x2/3x2 gibi bölünmüş PowerShell panelleri olan, her panelde
`claude --dangerously-skip-permissions` otomatik çalışan, kapanınca her şeyi kapatan, açılınca kaldığı yerden
(pencere konumu, sekmeler, paneller) devam eden bir masaüstü uygulaması. Teknoloji seçimi bana bırakıldı.

Repo: <https://github.com/AbdusselamKosecik/ClaudeDeck> (private) — yerel: `X:\Yazilim\ClaudeDeck`

## Yapılanlar

### 1. Teknoloji kararı
- **Neden:** Claude Code bir TUI; gerçek terminal emülasyonu şart. WinForms/WPF'e conhost pencereleri
  `SetParent` ile gömmek Windows 11'de (Windows Terminal varsayılan konsol) kırılgan.
- **Ne yapıldı:** WPF (.NET 10) kabuk + tek WebView2; terminal çizimi xterm.js 6; süreçler ConPTY
  (`CreatePseudoConsole`) ile C# tarafında; kalıcılık `Microsoft.Data.Sqlite`.
- **Ortam:** .NET SDK 9 + 10, Node 24, WebView2 Runtime 153, pwsh yok → Windows PowerShell 5.1.

### 2. Proje iskeleti
- **Dokunulan dosyalar:** `src/ClaudeDeck/ClaudeDeck.csproj` (net10.0-windows, UseWPF, WebView2 1.0.4191.47,
  Microsoft.Data.Sqlite 10.0.12, `wwwroot\**` çıktıya kopyalanır), `app.manifest` (PerMonitorV2), `App.xaml(.cs)`
  (`CLAUDECODE` env değişkenini siler — Claude Code içinden başlatılırsa iç içe oturum korumasına takılmasın).
- **xterm dosyaları** (offline, repoda):
  ```bash
  npm pack @xterm/xterm @xterm/addon-fit @xterm/addon-webgl   # 6.0.0 / 0.11.0 / 0.19.0
  # lib/xterm.js, css/xterm.css, lib/addon-fit.js, lib/addon-webgl.js → src/ClaudeDeck/wwwroot/lib/
  ```
  UMD global'leri: `Terminal`, `FitAddon.FitAddon`, `WebglAddon.WebglAddon`.

### 3. ConPTY oturumu — `PseudoConsoleSession.cs`
- 2 × `CreatePipe` → `CreatePseudoConsole` → `STARTUPINFOEX` + `PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE (0x20016)` →
  `CreateProcessW(EXTENDED_STARTUPINFO_PRESENT | CREATE_UNICODE_ENVIRONMENT | CREATE_SUSPENDED)`.
- Süreç askıdayken kendi **Job Object**'ine (`JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE`) atanır, sonra `ResumeThread`.
  Böylece powershell → claude → node ağacının tamamı job içinde; panel kapatınca `TerminateJobObject`,
  uygulama kapanınca/çökünce handle kapanır ve hepsi ölür.
- Okuma thread'i UTF-8 `Decoder` ile (bölünmüş çok baytlı karakterler bozulmasın), bekleme thread'i
  `WaitForSingleObject` → `Exited`. `ClosePseudoConsole` UI'ı kilitlemesin diye ThreadPool'da.
- Komut satırı: `"powershell.exe" -NoLogo -NoExit -Command "<komut>"`; geri yüklemede
  `<komut> --continue; if ($LASTEXITCODE -ne 0) { <komut> }` (konuşma yoksa normal başlar).

### 4. SQLite — `Database.cs`
- `%LOCALAPPDATA%\ClaudeDeck\claudedeck.db`, WAL.
- `repos(path PK NOCASE, name, last_opened, scanned_at)`, `settings(key, value)`.
- `settings` anahtarları: `state` (sekmeler/paneller/aktif sekme/kenar genişliği JSON), `window` (konum, boyut,
  maximized), `scanRoot` (vars. `X:\`), `command` (vars. `claude --dangerously-skip-permissions`), `resume`.
- `SaveScan`: upsert + kökün altında olup bu taramada görülmeyenleri sil. `TouchRepo`: `last_opened` günceller.

### 5. Tarayıcı — `RepoScanner.cs`
- Yığın tabanlı gezinme; `.git` klasör **veya dosya** (worktree/submodule) varsa repo, içine inmez.
- Atlananlar: `node_modules, .pnpm-store, bin, obj, $RECYCLE.BIN, System Volume Information, .fseventsd,
  .Trashes, .TemporaryItems, .Spotlight-V100, .vs, .idea, __MACOSX, .history, .venv, venv, __pycache__, .next, .nuxt`;
  reparse point ve System öznitelikli klasörler atlanır.
- **Sonuç:** `X:\` → 193 repo, 1350 ms (geçici konsol projesiyle ölçüldü).

### 6. Ana pencere — `MainWindow.xaml(.cs)`
- WebView2 `claudedeck.local` sanal host → `wwwroot`. Tarayıcı kısayolları kapalı (Ctrl+F vb. terminale gitsin),
  ClipboardRead izni otomatik verilir, koyu başlık çubuğu (DWM attr 20).
- JS ↔ C# mesajları: `ready/init`, `saveState`, `saveSettings`, `scan/cancelScan/scanProgress/scanDone`,
  `open/input/resize/close/output/exit`, `openFolder`, `repos`.
- Çıktı 12 ms'lik `DispatcherTimer` ile oturum başına toplanıp gönderilir (tek kilitli `Dictionary`).
- Pencere sınırları kapanışta kaydedilir; açılışta ekran dışındaysa ortalanır.

### 7. Arayüz — `wwwroot/index.html, app.css, app.js`
- Kenar çubuğu: arama, **Son açılanlar** (10), **Tüm repolar**, Tara/Durdur + ilerleme, ⚙ ayarlar; genişlik sürüklenebilir.
- Sekme çubuğu: ekle (düzen seçimli menü), kapat (orta tık da), çift tık yeniden adlandır, sürükle-sırala;
  sağda aktif sekmenin düzen seçicisi.
- Düzenler CSS grid-template-areas: `1, 2v, 2h, 1+2, 1+3, 2x2, 3x1, 3x2`.
- Sayfalar `visibility:hidden` ile gizlenir (display:none değil) → gizli sekmedeki terminaller de doğru
  boyutla başlar/fit olur.
- Panel: başlık (durum noktası, repo, ⟳ yeniden başlat, 📁 klasör, ✕ boşalt); boş panelde arama listesi;
  repo sürükle-bırak. Süreç bitince Enter ile yeniden başlar.
- Kısayollar: Ctrl+Shift+T, Ctrl+Tab, Alt+1..9, Ctrl+Shift+K, Ctrl+C (seçimde)/Ctrl+V.

### 8. Doğrulama
- **Komutlar:**
  ```bash
  dotnet build src/ClaudeDeck        # 0 hata
  ```
- DB'ye test `state` (1+2 düzen, 2 repo) ve test komutu (`Write-Host ClaudeDeck-OK; git status -sb`) yazıp
  uygulamayı başlattım: 2 ConPTY `powershell.exe` başladı, ekran görüntüsünde düzen/renkler doğru,
  `--continue` hatası sonrası yedek komut çalıştı.
- `CloseMainWindow` sonrası tüm alt powershell süreçleri öldü, `window` ayarı kaydedildi.
- Test `state`/`command` ayarları sonra silindi.
- **Commit:** `1c2893b` — ClaudeDeck: repo tarayıcı + sekmeli/bölünmüş Claude Code terminalleri

## Kararlar
- WPF + WebView2 + xterm.js + ConPTY (gömülü conhost yerine) — Claude TUI'si için doğru emülasyon.
- Durum tek JSON (`settings.state`) olarak; repolar ayrı tablo.
- "Kapanınca kapanacak" = panel/sekme/uygulama kapanınca süreç ağacı öldürülür. claude'dan çıkınca PowerShell açık kalır (`-NoExit`).
- Açılışta `--continue` varsayılan açık (ayarlardan kapatılabilir).

## Açık kalanlar / sonraki adım
- Paneller arası sürüklenebilir ayırıcı (şimdilik eşit grid).
- Gerçek `claude` ile uzun kullanımda performans/rendering gözlemi (webgl 6 panelde).
- İsteğe bağlı: tek dosya `dotnet publish` + masaüstü kısayolu.
