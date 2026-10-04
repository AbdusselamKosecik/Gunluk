# fortisyslog — 2026-10-04

## Bağlam
Sıfırdan yeni proje. Hedef: FortiGate 30G (FortiOS 7.2.11) cihazının UDP syslog ile gönderdiği
logları dinleyen, key=value formatını parse eden ve MSSQL'e toplu yazan .NET 8 Worker Service
(Windows Service). Kullanıcı ayrıca projenin GitLab'da açılmasını ve 192.168.0.2'deki SQL Server'da
veritabanı oluşturulmasını istedi.

- Repo: https://gitlab.com/modfex-apparel/fortisyslog (push-to-create ile özel repo)
- Yerel: `X:\Gitlab\modfex-apparel\fortisyslog`
- DB: `192.168.0.2` (SQL Server 2022 Developer) → `FortiGateLogs` veritabanı, `dbo.FortiGateLogs` tablosu

## Yapılanlar

### 1. Proje iskeleti
- **Neden:** Spec'teki klasör yapısı (Models/Services/Parsers/Data/Workers/Configuration) + test projesi.
- **Ne yapıldı:** `FortiSyslog.sln`, `src/FortiSyslog` (Microsoft.NET.Sdk.Worker, net8.0, win-x64),
  `tests/FortiSyslog.Tests` (xUnit). Paketler: Microsoft.Data.SqlClient 5.2.2, Hosting(.WindowsServices) 8.0.1,
  Options.DataAnnotations 8.0.0, Serilog.Extensions.Hosting 8.0.0, Serilog.Settings.Configuration 8.0.4,
  Serilog.Sinks.Console/File 6.0.0, Serilog.Sinks.EventLog 4.0.0.
- **Komutlar:**
  ```bash
  mkdir -p src/FortiSyslog/{Models,Services,Parsers,Data,Workers,Configuration} tests/FortiSyslog.Tests sql deploy tools
  git init -b main
  ```

### 2. Parser (`Parsers/FortiGateLogParser.cs`)
- **Neden:** FortiGate key=value; tırnaklı değerler boşluk, `=` ve `\"` içerebilir; log tipine göre alanlar değişir.
- **Ne yapıldı:** El yazımı tokenizer (regex yok). `<PRI>`, RFC5424 ve BSD başlıklarını atlar (ilk `anahtar=`
  token'ını bulur, `[...]` structured-data'yı atlar). Kapanmayan tırnak → satır sonuna kadar. Exception
  fırlatmaz; hata `ParseError` kolonuna, `RawLog` her zaman dolu. `user` yoksa `unauthuser` kullanılır.
  Ek alanlar: devname, devid, tz, vd, srcintfrole/dstintfrole, devtype, osname, group.

### 3. Boru hattı
- **SyslogListener:** Raw `Socket` + `ReceiveFromAsync`, 8 MB soket tamponu, Windows'ta `SIO_UDP_CONNRESET`
  kapatma (ICMP sonrası ConnectionReset hatası), `AllowedSourceIps` filtresi, `MaxMessageLength` kesme.
- **LogBuffer:** `Channel.CreateBounded` (FullMode=Wait + `TryWrite` → dolunca false döner, düşen sayılır).
  `ReadBatchAsync`: ilk kayıttan sonra BatchSize'a veya FlushInterval'a kadar toplar; iptalde eldekini döndürür.
- **SqlBulkWriter:** tek transaction içinde SqlBulkCopy; kolon şeması `Data/FortiGateLogTable.cs` tek
  noktada (DataTable + mapping + VARCHAR truncate). Veri hatası (SQL hata no listesi) → satır satır →
  yine olmazsa parameterized raw-only INSERT → yine olmazsa dead-letter dosyası.
- **DatabaseWriterWorker:** bağlantı hatasında aynı batch'i 2→60 sn üstel geri çekilmeyle sonsuz dener.
  Kapanışta `ShutdownFlushTimeoutSeconds` içinde boşaltır, yazamadığını `deadletter/unsent-YYYYMMDD.log`'a döker.
- **Mükerrer koruma:** her datagram'a `SequentialGuid` (SQL sıralı, son 6 byte zaman) `LogKey`;
  `UX_FortiGateLogs_LogKey` index'i `IGNORE_DUP_KEY = ON` → retry'da aynı satır ikinci kez yazılmaz.
- **RetentionService/Worker:** her gün 03:00'te `DELETE TOP (@BatchSize) ... WHERE ReceivedAt < @Cutoff` döngüsü.
- **Durdurma sırası:** Host servisleri kayıt sırasının tersine durdurur → `SyslogListenerWorker` en son
  kaydedildi, ilk o durur, kuyruğu `Complete` eder, sonra yazıcı boşaltır.
- **Program.cs:** `Directory.SetCurrentDirectory(AppContext.BaseDirectory)` (servis System32'de başlar),
  options `ValidateDataAnnotations().ValidateOnStart()`, `ShutdownTimeout = flush + 15 sn`.

### 4. Veritabanı (192.168.0.2)
- **Ne yapıldı:** `sql/00_create_database.sql` (RECOVERY SIMPLE), `sql/01_create_table.sql` (idempotent;
  49 kolon; indexler: ReceivedAt, SrcIp+ReceivedAt INCLUDE, DstIp, HostName/PolicyId/Application filtered,
  unique LogKey IGNORE_DUP_KEY).
- **Komutlar:**
  ```powershell
  sqlcmd -S tcp:192.168.0.2,1433 -U uzman -P <sifre> -C -b -i sql\00_create_database.sql
  sqlcmd -S tcp:192.168.0.2,1433 -U uzman -P <sifre> -C -b -d FortiGateLogs -i sql\01_create_table.sql
  ```
- **Sonuç:** DB + tablo + 8 index oluştu. Testten sonra tablo TRUNCATE edildi (boş).

### 5. Deploy / araçlar
- `deploy/publish.ps1` (Release win-x64, `appsettings.Production.json`'u çıktıdan siler),
  `deploy/install-service.ps1` (kopyala, Event Log kaynağı, `sc.exe create ... start= delayed-auto`,
  `sc.exe failure` restart 10/30/60 sn, firewall UDP 514 yalnız FortiGate IP'ye, başlat),
  `deploy/uninstall-service.ps1`, `tools/Send-TestSyslog.ps1` (UDP gönderici, -Count ile yük testi).
- README: FortiGate 7.2 CLI (`config log syslogd setting/filter`), sc.exe/New-Service örnekleri, sorgular.

### 6. Doğrulama
- `dotnet test` → 22/22 geçti (parser 17; yazıcı: retry'da kayıp/mükerrer yok, kısmi batch flush,
  SQL kapalıyken kapanışta 35/35 dead-letter, veri hatasında 19 bulk + 1 raw-only, kuyruk sınırı 1000/500 düşen).
- `dotnet build` 0 uyarı, `deploy/publish.ps1` çalıştı.
- Uçtan uca (gerçek DB, port 5514): 20.002 mesaj (~7.000 msg/sn) → 20.002 satır, tekil LogKey, bozuk mesaj
  `ParseError` + `RawLog` ile yazıldı.
- **Commit:** `c262d80` — FortiSyslog: FortiGate UDP syslog -> MSSQL collector (.NET 8 Worker Service)

### 7. Kurulum betikleri SentezServis `kur.ps1` stiline çevrildi
- **Neden:** Kullanıcı SentezServis'in `kur.ps1`'ini örnek verip "bunun gibi" istedi.
- **Ne yapıldı:** `deploy/install-service.ps1` → `deploy/kur.ps1`, `uninstall-service.ps1` → `deploy/kaldir.ps1`.
  Türkçe parametreler (`-Kaynak` zorunlu, `-Hedef 'C:\Program Files\FortiSyslog'`, `-Port 514`, `-FortiGateIp`,
  `-Hesap`, `-Parola`), `Yaz()` önekli çıktı, yönetici + exe varlık kontrolü, idempotent
  durdur → kopyala → oluştur/güncelle → recovery → firewall → başlat → `WaitForStatus('Running')`.
  `appsettings.Production.json` sunucuda korunur; ilk kurulumda örnekten oluşturulur.
- **Teknik karar:** Servis yolu `New-Service` (oluşturma) ve registry `ImagePath` (güncelleme) ile yazılıyor;
  hesap `Win32_Service.Change` (CIM) ile. Sebep: Windows PowerShell 5.1, `"C:\Program Files\..."` gibi boşluklu
  ve tırnaklı argümanları sc.exe'ye bozuk geçirebiliyor. `sc.exe` yalnızca tırnaksız işlerde
  (`start= delayed-auto`, `failure`, `failureflag`) kullanılıyor.
- **Not:** SentezServis `kur.ps1`'indeki `"binPath=`"...`""` (eşittir ile değer bitişik) kullanımı sc.exe'de
  çalışmayabilir; sc.exe `binPath=` ile değerin ayrı argüman olmasını ister. Orada kontrol edilmeli.
- **Encoding:** Tüm `.ps1` dosyaları UTF-8 **BOM'lu** kaydedildi; BOM'suz dosyada PS 5.1 Türkçe karakterleri
  bozuyordu (`yÃ¶netici`). Doğrulama: parser 0 hata, yönetici olmayan oturumda düzgün Türkçe hata mesajı.
- **Commit:** `301a00b` — deploy: kur.ps1 / kaldir.ps1 (SentezServis kur.ps1 stilinde)

## Kararlar
- `ReceivedAt` UTC tutulur; cihaz yerel saati FortiGateDate/Time/TimeZone kolonlarında.
- Gerçek bağlantı bilgisi `src/FortiSyslog/appsettings.Production.json`'da, **.gitignore'da** (repoya girmez).
  Servis Production ortamında çalıştığı için bu dosya otomatik yüklenir.
- Bağlantı `Server=tcp:192.168.0.2,1433` ile TCP'ye zorlandı: Wi-Fi'de TCP zaman aşımında SqlClient Named
  Pipes'a düşüp yanıltıcı "1326 kullanıcı adı/parola yanlış" hatası verdi (gerçek sebep ağ kesintisiydi).
- Kuyruk dolunca **yeni** log düşürülür (eskiler korunur), sayılır, 5 dk'da bir Warning.
- Servis hesabı varsayılan LocalSystem; SQL Authentication (uzman) kullanılıyor.

## Açık kalanlar / sonraki adım
- Windows servis kurulumu canlı denenmedi (geliştirme makinesinde yönetici yetkisi yoktu); hedef
  Windows Server'da `deploy\kur.ps1` ile kurulup `sc stop` ile kapanış boşaltması gözlenmeli.
- `uzman` yerine yalnızca SELECT/INSERT/DELETE yetkili ayrı SQL kullanıcısı açılmalı (README'de script var).
- FortiGate'te `config log syslogd setting` yapılmalı; `AllowedSourceIps`'e FortiGate IP'si yazılmalı.
- Dead-letter dosyalarını otomatik geri içe aktarma yok (elle).
