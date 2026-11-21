# selvedge — 2026-11-22

## Bağlam
Kullanıcı yeni Satın Alma Inspection API'sini (commit 4c97ccc) sunucuya kendisi kurdu; tablete 1.0.5 kurulması istendi.

## Yapılanlar

### 1. Tablete Selvedge QC 1.0.5
- **Ne yapıldı:** `adb -s R83XB0S3C7Y install -r build/app/outputs/flutter-apk/app-release.apk` (SM-X110).
- **Sonuç:** 1.0.4 (5) → 1.0.5 (6); veri korunur (install -r, aynı imza). Uygulama başlatıldı, süreç çalışıyor.

### 2. Sunucu kurulum kontrolü (192.168.0.2:8085)
- **Kontroller:** kök 200; `SentezSelvedge` Running/Automatic; Selvedge.Api.dll içinde `purchase-inspection`,
  Application.dll içinde `PurchaseInspectionService` var; appsettings*.json değişmemiş (10/6 tarihli);
  log 23:43 temiz açılış, migration 0, hata yok; `/api/purchase-inspection/orders` tokensız 401 (uç nokta yetkili, var).
- **Komut:** WinRM `Invoke-Command -ComputerName 192.168.0.2` + `Invoke-WebRequest`.

## Açık kalanlar
- Gerçek kullanıcıyla tabletten sipariş listesinin geldiğini görmek (şifre bende yok).
