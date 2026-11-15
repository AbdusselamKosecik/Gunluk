# fortisyslog — 2026-11-15

## Bağlam
Proje (FortiGate UDP syslog → MSSQL collector, .NET 8 Worker Service) hazırdı. Hedef: build + publish
ve FortiGate'i 192.168.0.2'deki collector'a log gönderecek şekilde yapılandırma adımlarını çıkarmak.

## Yapılanlar

### 1. Build / test / publish
- **Neden:** Sunucuya (192.168.0.2) kurulacak paketi üretmek.
- **Komutlar:**
  ```bash
  dotnet build -c Release
  dotnet test -c Release --no-build          # 22/22 geçti
  powershell -File deploy/publish.ps1        # çıktı: publish/ (framework-dependent win-x64)
  ```
- **Sonuç:** 0 uyarı, 0 hata; `publish/` klasörü oluştu (appsettings.Production.json publish'e girmez).

### 2. README / test aracı IP düzeltmesi
- **Neden:** Dokümanda collector için placeholder `192.168.0.10` vardı; gerçek sunucu `192.168.0.2`
  (MSSQL de orada). FortiGate = `192.168.0.1`.
- **Dokunulan dosyalar:** `README.md`, `tools/Send-TestSyslog.ps1`
- **Commit:** `b558749` — docs: collector sunucu IP'si 192.168.0.2

### 3. FortiGate tarafı (kullanıcıya verilen tarif)
```
config log syslogd setting
    set status enable
    set server "192.168.0.2"
    set mode udp
    set port 514
    set facility local7
    set format default
end
config log syslogd filter
    set severity information
    set forward-traffic enable
    set local-traffic enable
    set anomaly enable
end
# policy'lerde: set logtraffic all
# doğrulama: diagnose log test / diagnose sniffer packet any 'udp and port 514' 4 10
```
Sunucuda: `.\deploy\kur.ps1 -Kaynak .\publish -FortiGateIp 192.168.0.1` (firewall UDP 514 yalnız 192.168.0.1).

## Açık kalanlar / sonraki adım
- publish klasörünü 192.168.0.2'ye kopyalayıp kur.ps1 çalıştırmak, appsettings.Production.json girmek.
- SQL şemasını (sql/00, sql/01) sunucuda çalıştırmak (yapılmadıysa).
- FortiGate CLI'yi uygulayıp `SELECT TOP 50 ... FROM dbo.FortiGateLogs` ile doğrulamak.

### 4. .NET 8 → .NET 10 geçişi
- **Neden:** Kullanıcı isteği; .NET 10 LTS (Kasım 2028'e kadar destek), .NET 8 Kasım 2026'da desteği bitiriyor.
- **Ne yapıldı:** İki csproj'da `TargetFramework` → `net10.0`. Paketler: Microsoft.Extensions.* 10.0.15,
  Microsoft.Data.SqlClient 6.1.8 (7.x major sürüm bilerek alınmadı — kırıcı değişiklik riski),
  Serilog.Extensions.Hosting 10.0.0, Serilog.Settings.Configuration 10.0.1, Sinks.Console 6.1.1, Sinks.File 7.0.0,
  Sinks.EventLog 4.0.0 (aynı). Test: Test.Sdk 18.12.0, xunit 2.9.3, runner 3.1.5 (xunit v2 korunuyor).
  README + publish.ps1'de ".NET 8 Runtime" → ".NET 10 Runtime".
- **Dokunulan dosyalar:** `src/FortiSyslog/FortiSyslog.csproj`, `tests/FortiSyslog.Tests/FortiSyslog.Tests.csproj`, `README.md`, `deploy/publish.ps1`
- **Komutlar:**
  ```bash
  rm -rf src/FortiSyslog/obj tests/FortiSyslog.Tests/obj
  dotnet build -c Release            # 0 uyarı / 0 hata (SDK 10.0.401)
  dotnet test -c Release --no-build  # 22/22
  powershell -File deploy/publish.ps1  # runtimeconfig: Microsoft.NETCore.App 10.0.0
  ```
- **Commit:** `62693c9` — build: .NET 8 -> .NET 10
- **Not:** Sunucuya (192.168.0.2) .NET 10 Runtime kurulmalı (veya `publish.ps1 -SelfContained`).
