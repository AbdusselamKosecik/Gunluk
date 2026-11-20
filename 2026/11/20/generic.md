# generic — 2026-11-20

## Bağlam
Techtsio (Frederic) üretim takip: 192.168.1.69'da (MERKEZANALIZ) A026-1483 modelinde 1125-8 operasyonu
görünüyor, 172.16.1.2'de (DIKIMANALIZSRV) görünmüyor — replikasyon hatası mı?

## Yapılanlar

### 1. Replikasyon / veri karşılaştırması (sadece okuma, değişiklik yok)
- **Bağlantı:** her iki sunucu `sa`, DB `TechtsioMerkez` (SQL 2019 15.0.2000.5).
- **Replikasyon yapısı:** .69 publisher, yayın `Merkezz` (transactional, 41 article), aboneler 172.16.1.2,
  10.10.10.200, SURMEVERIMLILIK (push). Log reader + distribution agent'lar sağlıklı
  ("No replicated transactions are available"). MSrepl_errors: 2026-11-19 14:28 172.16.1.2'ye bağlanamama (geçici).
- **Replike tablolar:** Models, Operations, ModelRoutes, Orders, OrderItems, Cards ... **Transections ve
  CurrentDeviceList replikasyonda değil** (her sahanın kendi verisi).
- **Karşılaştırma:**
  - `ModelRoutes` iki sunucuda birebir aynı (257658 satır, CHECKSUM_AGG eşit; A026-1483 için 74 rota, checksum eşit).
  - A026-1483 rotasında **1125-8 yok, 1125-9 (UZANTILI) var** (Sort 78). 1125-8 = "UZANTISIZ" — ayrı operasyon.
  - Sipariş `060c5878-37bd-42ee-a3a3-9ea471230a9c` = **Order 96062** (2026-10-27, model A026-1483), iki sunucuda aynı.
  - 172.16.1.2 `CurrentDeviceList`: cihaz IP 172.16.1.79 bugün 08:02'den beri 96062/A026-1483 için **1125-8**
    üzerinde, CurrentQuantity 567. Aynı model için Transections'ta 1125-8 kaydı 0 (1125-9 var: 5).
  - .69 Transections son tarih 2026-11-19 (Dikim verisi günlük taşınıyor; modelin ilk üretimi 2026-11-20).
- **Sonuç:** Replikasyon hatası yok. Cihaz rotada olmayan operasyona (1125-8) atanmış; doğru operasyon büyük
  ihtimalle 1125-9, ya da 1125-8 rotaya eklenmeli.

### 2. Kök neden: uygulama TEST veritabanına bağlı
- Kullanıcı ısrar etti ("A026-1483'te 1125-8 var") → .69'daki tüm Techtsio DB'lerinde 1125-8 Id'si tarandı.
- **TechtsioMerkezTest**'te A026-1483 (farklı Id `14202F97-...`) rotasında 1125-8 var; model Test'te bugün
  10:56'da oluşturulmuş, 12:48'de güncellenmiş. Test replikasyonda değil → 172.16.1.2'ye hiç gitmez.
- Test ile canlı rota farkı: Test'te **1102-2** (Sort 2, 8.49) ve **1125-8** (Sort 78, 21.114);
  canlıda yerlerinde **1102-1** (6.852) ve **1125-9** (23.184).
- .69 üzerindeki uygulama oturumları (host MERKEZANALIZ, sa, SqlClient) **TechtsioMerkezTest**'e bağlı;
  sadece ANALIZSERVER oturumu canlı DB'de.
- **Çözüm (kullanıcı kararı bekliyor):** uygulamanın bağlantı dizesini TechtsioMerkez'e çevirmek ve
  2 rota değişikliğini canlıda yapmak (uygulamadan veya SQL ile).

## Açık kalanlar / sonraki adım
- Kullanıcı karar verecek: 172.16.1.79 cihazını 1125-9'a almak mı, 1125-8'i A026-1483 rotasına (.69'da) eklemek mi.
