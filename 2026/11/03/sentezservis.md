# sentezservis — 2026-11-03

## Bağlam
Dünkü müşteri sesi ilk dolumu gece 00:23te bitti. Kullanıcı: yorumlar alındı mı (hayır — resmi API yok); ardından Logo cari listesi + cari ekstresi istendi.

## Yapılanlar

### 1. Logo cari listesi ve cari ekstresi (/logo-cari)
- **Neden:** eski yılların (2009–2021) cari bilgisi ve ekstresi gerekiyor; Logo ayrı sunucuda. Kullanıcı: "önce db seçelim, sonra firma ona göre gelsin", "eski bilgiler lazım oluyor".
- **Keşif (salt okuma):** 192.168.1.3 ve .4'te Logo yok. Logo sunucusu **192.168.1.11** (SQL Server 2017), kullanıcı `logo1` (parola kullanıcıdan; gitignore'lu `appsettings.json`'da, repoda YOK) — kullanıcı **sysadmin**.
  - Logo veritabanları ve cari kartı olan firmalar: GO_ESKI (009, 010, 099), LOGO_18 (018), LOGO_19 (019), LOGO_20 / GODB2 (016, 017, 020 TEYZEOĞLU İŞHANI, 021, 050, 051, 099), GODB (021, 050, 051, 099), YEDEK (016, 017, 099). Her yerde yalnız dönem 01.
  - `L_CAPIFIRM` her veritabanında yok ve olduğunda o db'de tablosu olmayan firmaları da sayıyor → firma/dönem **tablo adlarından** (`LG_fff_CLCARD`, `LG_fff_dd_CLFLINE`) çıkarıldı; bazı firmalarda hareket var ama kart yok (LOGO_20/018) → listelenmez.
  - Kolonlar 2009 (GO_ESKI) ve 2021'de ortak (DEFINITION2 hariç).
  - CLFLINE modül 3 / kod 81 = **satış siparişi** (SOURCEFREF → ORFICHE); faturası kod 38 olarak ayrıca var → ekstrede varsayılan HARİÇ (Logo'nun kendi ekstresi gibi), "Siparişleri de göster" seçeneği.
  - İşlem kodu adları gerçek verinin borç/alacak yönüyle karşılaştırıldı; uyuşmayan banka 28/29 adlandırılmadı ("Modül 7 / kod 28").
- **Ne yapıldı:**
  - `Ayarlar.cs`: `BaglantiRolu.Logo`, `Baglantilar.Logo` (başka role düşmez). `BaglantiFabrikasi.LogoAcAsync(veritabani)` — `SqlConnectionStringBuilder` ile Initial Catalog yerine konur, `ApplicationIntent=ReadOnly`.
  - `Core/Logo/LogoDeposu.cs`: `VeritabanlariAsync`, `FirmalarAsync`, `CarilerAsync` (sayfa önce seçilir, borç/alacak OUTER APPLY ile yalnız sayfadaki cariler için), `EkstreAsync` (devir = başlangıçtan önceki toplam, bitiş günü dahil, yürüyen bakiye), keşif 10 dk önbellek; keşifte olmayan db/firma/dönem → `LogoBulunamadiException` (404). `LogoIslemTurleri`, `LogoMetin.Temizle` (eski kartlarda ünvan sonunda CR/LF var).
  - `Host/Api/LogoUclari.cs`: `/api/logo/veritabanlari`, `/{db}/firmalar`, `/{db}/{firma}/{donem}/cariler`, `/.../cariler/{ref}/ekstre` — GirisIster; SQL hatası → 503.
  - Web: `api/logo.ts`, `pages/LogoCariSayfasi.tsx` + `LogoCari.css` (db → firma → [dönem] → cari arama/liste → ekstre; seçimler URL'de; CSV (`;` + BOM) ve yazdır, print CSS menüyü gizler). Menü: "Logo cari ekstresi".
  - `docs/baglanti-cumleleri.md`: Logo rolü ve öneri (ayrı db_datareader kullanıcı).
- **Komutlar / doğrulama:**
  ```bash
  dotnet test tests/SentezServis.Core.Tests     # 749 geçti (LogoTestleri: keşif ayrıştırma, yürüyen bakiye, yazma ifadesi yok sınırı)
  cd web && npx tsc -b && npx vitest run        # 81 geçti (LogoCariSayfasi.test.tsx)
  # scratchpad/logodene: LogoDeposu canlı Logo'ya karşı (parola env LOGO_PW):
  #   keşif 8,3 sn; LOGO_19 101.995 cari, sayfa 4,5 sn; arama 6,4 sn; ekstre 0,5 sn;
  #   tüm zaman son bakiye == listedeki bakiye (-31.605.578,41); "LOGO_20; DROP TABLE" ve kartsız firma reddedildi.
  ```
  Tarayıcıda gerçek backend'le gözle bakılmadı (Host'u yerelde canlı DB'ye karşı açmak arka plan servislerini de çalıştırırdı).
- **Commit:** `b1dd834` — Logo cari ekstresi: eski Logo sunucusundan cari listesi ve ekstre (salt okunur)

## Kararlar
- Firma listesi tablolardan; ad L_CAPIFIRM'den (ilk görülen). Siparişler ekstrede hariç. Tutarlar TL (AMOUNT); döviz (TRNET/TRCURR) gösterilmiyor.
- Yetki: giriş yapan herkes (diğer ERP okuma ekranları gibi).

## Açık kalanlar
- Canlı sunucunun `appsettings.json`'ına `SentezServis:Baglantilar:Logo` eklenmeli (yoksa açılış doğrulaması "tanımlı değil" uyarır, ekran 503 döner); sunucudan 192.168.1.11:1433 erişimi doğrulanmalı.
- `logo1` sysadmin → canlı için salt okunur kullanıcı önerildi.
- Sunucuya yayın (müşteri sesi + Logo) hâlâ yapılmadı; `pazaryeri-siparis-cek` cron'u boş (dünden açık soru).
