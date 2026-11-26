# Saas_mobile — 2026-11-27

## Bağlam
Kullanıcı Saas_erp için mobil uygulama istedi. Hedef: RAM'i az kullanmak, React Native, temel menüler. Öncelik bildirim ve onay mekanizması. Repo, Saas_erp'nin üst dizininde ayrı olarak açılacak.

## Yapılanlar

### 1. Teknoloji seçimi
- **Neden:** telefon ve geliştirme makinesinin RAM'i az kullanması.
- **Karar:** Expo (SDK 58) + React Native 0.88 + Hermes, derleme EAS'ta (bulutta), emülatör yerine gerçek cihaz.
  - Telefondaki RAM farkını çatı değil uygulama kodu belirliyor: FlatList, sunucu sayfalama, kısa gcTime.
  - Geliştirme makinesindeki asıl tüketiciler emülatör (2-4 GB) ve Gradle; EAS ile ikisinden de kaçınılıyor.
  - TS tipleri, TanStack Query ve i18n web uygulamasıyla ortak.

### 2. Backend keşfi
- Auth: refresh gövdede taşınıyor (mobile uygun). Firma seçimi `X-Tenant-Id` ile, `GET tenants/my`. 2FA: `login/2fa`.
- Bildirim: liste, okunmamış sayısı, okundu işareti var. SignalR `/hubs/notifications`. **Push yok** (FCM/APNs/Expo yok).
- Onay: **ortak mekanizma yok**, her modülün kendi `.../approve` ucu var. Stok fişi için `receipt_pending_approval` bildirimi zaten var (OnInventoryReceiptEvents).
- Not: Saas_erp/src/mobile (Expo 52) eski bir deneme olarak duruyor; kullanıcı ayrı repo istedi.

### 3. Kurul (öneri: X:/GitHub/vuo-app/wt/mobile-push-approvals-proposal.md)
- **CTO:** APPROVE-WITH-CONDITIONS. Expo Push + Shared IPendingApprovalSource; faz 1: stok fişi + cari, banka, kasa fişi.
- **Skeptic:** BLOCK.
  - Finans fişlerinde "onaya gönderildi" durumu yok, kutu taslaklarla dolar.
  - Finans onayı deftere geri alınamaz kayıt atıyor.
  - Push için henüz kullanıcı yok.
  - Faz 1 = stok fişi, mevcut uçlarla, push yok.
- **PO:** önce finans, biyometrik doğrulama, yalnız onay, 4 sekme.
- **Security:** içeriksiz push yükü, token yeniden bağlama ve impersonation kuralları, deep link kısıtı. Finans onay uçlarında yetki tutarsız.
- **DBA:** DeviceToken BaseEntity (kiracısız); "bekleyen" sorgusu için kısmi index gerekli.
- **Uygulanan:** tüm üyelerin kesişimi (Skeptic'in daraltılmış faz 1'i), backend değişikliği yok.

### 4. Uygulama
- **Dokunulan:** `X:/GitHub/vuo-app/Saas_mobile` (yeni):
  - `src/app` (login, select-tenant, switch-tenant, (tabs)/index, approvals, notifications, account, receipt/[id]);
  - `src/api` (client: tek uçuşlu yenileme; endpoints; errors);
  - `src/auth` (auth-context, token-store, confirm-identity);
  - `src/notifications/route-for.ts`, `src/ui`, `src/hooks/use-badges.ts`;
  - `CLAUDE.md`, `README.md`, `docs/kurul-kararlari.md`.
- **Komutlar:**
  ```bash
  cd X:/GitHub/vuo-app && npx create-expo-app@latest Saas_mobile --template blank-typescript --no-install
  cd Saas_mobile && npm install
  npx expo install expo-router react-native-safe-area-context react-native-screens expo-linking expo-constants expo-secure-store expo-notifications expo-device expo-localization react-dom expo-local-authentication @expo/vector-icons expo-font
  npm install @tanstack/react-query axios i18next react-i18next && npm install -D vitest@3
  ```
  - Not: `react-dom`, expo-router'ın web tarafı için `expo install` ile sabitlenmeli. Yoksa `npm install` ERESOLVE veriyor (react-dom 19.3.1 ile react 19.3.0 çakışıyor).
- **Kararlar:**
  - access token yalnız bellekte; refresh token ve firma SecureStore'da (WHEN_UNLOCKED_THIS_DEVICE_ONLY);
  - ağ hatası oturumu silmez;
  - her onaydan önce telefon kilidi istenir; ekran kilidi yoksa onay verilmez;
  - onay gövdesi `{approve:true}` (uç bir aç/kapa anahtarı);
  - `X-Idempotency-Key` gönderilir; `inventory.receipt.already_approved` bilgi olarak gösterilir;
  - sayılar 60 sn'de bir ve odağa dönüşte yenilenir;
  - Expo şablonunun MIT LICENSE dosyası (650 Industries) kaldırıldı.
- **Doğrulama:**
  - tsc temiz;
  - vitest 13/13 (tek uçuş testi, kod bilerek bozulunca kırmızıya döndü);
  - expo-doctor 20/20;
  - `expo export --platform android` paketi üretti (2.9 MB hbc).
  - Gerçek cihazda ya da DEV'e karşı henüz denenmedi: development build gerekiyor.
- **Commit:** `063c268`. Remote: github.com/vuo-app/Saas_mobile (private), dal `main`.

## Kararlar
- Skeptic BLOCK'u yüzünden push ve finans onayı kullanıcı kararını bekliyor (docs/kurul-kararlari.md "Bekleyen").

## Açık kalanlar / sonraki adım
- Kullanıcı kararları:
  - (1) push faz 1'e alınsın mı;
  - (2) finansa "onaya gönder" adımı mı, yoksa risk kabulü mü.
- İlk development build (EAS) ve DEV hesabıyla gerçek cihaz testi. EAS projectId için Expo hesabı gerekli.
- Saas_erp tarafı: 22 Kasım'daki bozuk migration (`DO 22777`) dev'de düzeltilmiş. P0b dilim A (43 uç) hâlâ gönderilmedi; wte33'te ve dev'in gerisinde.
