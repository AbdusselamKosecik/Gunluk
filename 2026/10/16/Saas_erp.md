# Saas_erp — 2026-10-16

## Bağlam
Kullanıcı, son değişikliklerin çekilmesini, bekleyen iş varsa gönderilmesini ve API ile UI'ın yerelde çalıştırılmasını istedi.

## Yapılanlar

### 1. Güncelleme
- **Ne yapıldı:** `dev` 7330b24a → b1b2e7a5 fast-forward oldu. Gelenler: ön maliyette model kodu/adı, sipariş ve fişlerde varyant matrisi, kısmi paketleme, barkodlu harekette düzeltme paneli ve çoklu emir modu, fiş onayı ayarı, lab test silme.
- **Bekleyen yerel iş:** Yoktu (çalışma ağacı temiz, push edilmemiş commit yok). Gönderilecek bir şey çıkmadı.

### 2. Yerelde çalıştırma
- **Komutlar:**
  ```bash
  # src/frontend/.env.development.local (git-ignored) → VITE_PUBLIC_API_URL=http://localhost:5240
  dotnet run --project src/backend/VuoApp.Api        # :5240
  cd src/frontend && npm install && npm run dev      # :3131
  ```
- **Sonuç:** API açıldı: "Bekleyen migration yok, 104 migration uygulanmış, 471 tablo yerinde". Yeni migration'lar paylaşımlı DB'ye başka makinede zaten uygulanmış. UI'da Vite hazır. Tailscale `services` erişilebilir durumdaydı.

## Açık kalanlar
- Build uyarısı: MailKit 4.15.1 orta seviye güvenlik açığı (NU1902). Güncellenmeli.
