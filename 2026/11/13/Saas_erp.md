# Saas_erp — 2026-11-13

## Bağlam
Kullanıcı talimatı: "son değişiklikleri alıp dev'e publish eder misin, testleri çalıştırma ama".
Bu yüzden hazır olan dilimler testsiz push edildi. Yapılan kontroller: güncel dev üzerine rebase, derleme, tip kontrolü, NUL taraması.

## Yapılanlar

### 1. MRP yetki düzeltmesi — `0b497892a`
- **Ne:** `GET /api/v1/production/mrp` ucuna `[RequirePermission("production","read")]` eklendi.
- **Kurul kararı (2026-11-10):** emir tipi bazında sızıntı yok, çünkü `ProductionModuleAccessMiddleware` erişilmeyen tipe 404 dönüyor. Bu yüzden handler'a tip kontrolü eklenmedi.
- **Testler:** yazıldı, koşulmadı.
  - `ProductionReadPermissionContractTests`
  - `MrpAnalysisTypeAccessPostgresTests`
- **Ayrı iş:** yetki şartı eksik diğer okuma uçlarının listesi `wt/prod-read-sweep.md` dosyasında; ayrı bir iş olacak.

### 2. Örme/Boyahane Teorik ihtiyaç — `78ff82285`
- **Rebase çakışması:** upstream `6fcd66b8c`, kullanıcı isteğiyle Boyahane çıkış özeti panelini sayfadan kaldırmıştı.
  - Bu karara uyuldu: panel yalnız Örme'de, `showBanner={false}` ile kalıyor.
  - Boyahane'de sayfa uyarı bandı ve kapanış onayı, ayara bağlı olarak çalışmaya devam ediyor.
- **Değişiklik listesi:** madde metni panel kararına göre düzeltildi.
- **Doğrulama:** derleme 0 hata, tsc temiz.
  - Unit (9270) ve hedefli testler önceki koşuda geçmişti.
  - Bu rebase'den sonra test koşulmadı.

## Açık kalanlar
- **E7 S3b-3a (karışık koli, wte32):** yarım. Backend kuralları ve migration hazır; ön yüz, i18n ve testler eksik. Bu yüzden publish edilmedi.
- **E6 S4:** DEV pilot turu bekleniyor (`z8v9xnkd69`).
- **S3b-3b Engelle:** pilot sonrasına ertelendi.
