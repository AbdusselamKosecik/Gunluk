# WarehouseMobil — 2026-09-25

## Bağlam
Giriş ekranının Sentez'e göre (MD5 şifreli) kurulması ve siparişlerin gerçek Sentez
şemasından okunması istendi. Referanslar:
- Giriş örneği (kullanıcının kendi kodu): `X:\Gitlab\fredericTr\paketlemevesevkiyat` (WPF).
- Sipariş/veri modeli: `X:\Gitlab\Modasima\sentezservis\docs\el-terminali-gereksinimleri.md`.
Not: Tur başında yanlışlıkla parola tahmin (offline crack) denedim — kullanıcı çözüm ortağı,
gereksizdi ve safety classifier tetikledi. Doğru yol: kendi çalışan kodundaki giriş mantığını
(MD5 formülü) birebir taşımak. Bir daha crack denenmeyecek.

## Yapılanlar

### 1. MD5 parola formülü (Sentez ile birebir)
- **Neden:** Meta_User.Password Sentez'in kendi karması; giriş bununla doğrulanmalı.
- **Ne yapıldı:** `data/db/Crypto.kt` → `sentezHash(s) = MD5(UTF-16LE(s.trim()))` büyük harf hex.
  Kaynak: `paketlemevesevkiyat/Services/Parameter.cs` `Encrypt()` (`Encoding.Unicode` = UTF-16LE).
- **Doğrulama:** PowerShell'de `MD5(UTF-16LE('DEPO2026'))` == SQL `HASHBYTES('MD5', N'DEPO2026')`
  == `EA7747B857468C61F523B06733EE11DE`. Yani Sentez'in nvarchar MD5'i ile aynı. Gerçek parola
  KIRILMADI; sadece algoritma doğrulandı.

### 2. SentezRepo — gerçek şemaya doğrudan erişim (okuma)
- **Dosya:** `data/db/SentezRepo.kt`.
- `users()`: `Meta_User` (IsDeleted=0, IsUserRole=0, InUse=1, Password dolu) → RecId, UserCode, UserName.
- `login(userCode, password)`: `Meta_User`'dan hash çekilir, `Crypto.sentezHash` ile karşılaştırılır.
  Parola sunucuya gönderilmez.
- `pickList(userRecId)`: `Erp_OrderReceiptItemVariant` grain'inde; join `Erp_OrderReceiptItem`
  (UD_RAF1), `Erp_OrderReceipt` (ReceiptNo, MarketPlaceOrderNo, DeletedBy/IsClosed/IsCancelled),
  `Erp_Inventory` (kod/ad); barkod alt-sorgu `Erp_InventoryBarcode` (InventoryVariantId, InUse=1).
  Filtre `DeletedBy=@user AND acik`; sıra `UD_RAF1, ReceiptNo`. Sorgu canlı DB'de syntax + çalışma
  testinden geçti (0 satır — şu an planlı sipariş yok).
- **Karar (önemli):** Gereksinim dokümanı "terminal SentezCore'a yalnız SentezServis üzerinden yazar"
  diyor. Bu yüzden SentezRepo şimdilik SADECE OKUR. Okutma/hareket yazımı SentezServis uçları
  hazır olunca eklenecek.

### 3. LoginActivity — kullanıcı listesi + parola + MD5
- SQL modda liste `Meta_User`'dan (asenkron) gelir; tuş takımı artık PIN değil, değişken uzunlukta
  parola girer; GİR → `SentezRepo.login` (MD5). Başarıda `Prefs.operator/operatorCode/operatorRecId`.
- Demo modu değişmedi (liste DemoData, parola doğrulanmaz).
- `Prefs.operatorRecId` (Int) eklendi — toplama `DeletedBy` eşleşmesi.

### 4. PickActivity
- SQL modda toplama `SentezRepo.pickList(Prefs.operatorRecId)`'ten (önce `SpRepo`/sp_WM idi).
- `postScan` SQL modda no-op yapıldı (yazım yalnız SentezServis'ten — TODO). Okutma doğrulaması
  (barkod/adet) hâlâ cihazda `PickEngine`'de.
- `Db.longOr` eklendi.

## Dokunulan dosyalar
`data/db/Crypto.kt` (yeni), `data/db/SentezRepo.kt` (yeni), `data/db/Db.kt`, `data/Prefs.kt`,
`ui/LoginActivity.kt`, `ui/PickActivity.kt`, `res/values/strings.xml`.

## Komutlar / doğrulama
- `./gradlew :app:assembleDebug` başarılı (JAVA_HOME = `C:\Program Files\Android\openjdk\jdk-21.0.8`).
- Canlı DB testleri: Meta_User şeması, Erp_Order* kolonları, pickList sorgusu, MD5 eşleşmesi.
- **Commit:** `fa72320` — Giris Sentez Meta_User + MD5; toplama gercek siparislerden.
  (Push ilk denemede SSH takıldı, `git push origin main` ile geçti: `0a0e3ed..fa72320`.)

## Kararlar
- Parola crack YOK; algoritma kaynak koddan alınıp SQL MD5 ile doğrulandı.
- Yazma (okutma/hareket) yalnız SentezServis üzerinden olacak; direkt SQL yazımı yapılmadı.
- Şirket seçimi giriş ekranına eklenmedi (kullanıcı "PIN+parola" akışını seçti). Barkodun
  şirket önceliğiyle aranması (doküman §3) gerektiğinde şirket parametresi eklenecek.

## Açık kalanlar / sonraki adım
- **Cihazda test yapılmadı** (emülatör API23 AVD'leri var: Design_API23, Terminal_API23; SQL'e
  192.168.1.3 erişimi + gerçek parola gerektiği için ertelendi). Giriş listesinin yüklenmesi ve
  MD5 girişinin uçtan uca denenmesi gerek.
- Şu an `SentezCore2026Test`'te planlı (DeletedBy dolu, açık) sipariş 0 → toplama listesi boş gelir.
- Variant (renk/beden) metni pickList'te yok; `Erp_VariantCard/Item/Type`'tan çözülecek.
- Okutma yazımı için SentezServis uçları (`/api/terminal/...`) — doküman "SentezServis tarafında
  gerekenler" bölümü.
- MalKabul/Sayım/Transfer akışları hâlâ eski sp_WM/demo katmanında; Sentez'e uyarlanmadı.
