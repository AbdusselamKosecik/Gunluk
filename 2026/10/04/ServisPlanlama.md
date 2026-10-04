# ServisPlanlama — 2026-10-04

## Bağlam
Sıfırdan yeni proje (`X:\Gitlab\modfex-apparel\ServisPlanlama`). İstek: ZKBioTime'daki personel adreslerinden
(Arapça, Mısır — İskenderiye/Behira) koordinat bulup, **yol ağına göre en kısa süreli** servis rotaları
çıkaran ve haritada gösteren web sitesi. Filo: 2 × 28'lik + yeteri kadar 14'lük. Tamamen ücretsiz, limitsiz servisler.
Fabrika (varış): `30.81723351887507, 29.546573229779394` (Borg El Arab). Kapsam: tüm aktif personel (357).
Kurulum hedefi: modfexsrv 192.168.0.2, Windows servisi, port 8086 (Selvedge düzeni).

## Yapılanlar

### 1. Veri keşfi (BioTime)
- **Neden:** Adres alanlarının yapısını görmek.
- **Ne yapıldı:** `zkbiotime.dbo.personnel_employee`: `address` (serbest Arapça), `city` (çoğu zaman adresle çelişiyor,
  güvenilmez), `nickname` (Arapça ad), `mobile`. 357 aktif, 344'ünde adres var. Bağlantı: 100.119.104.122, `uzman` (sysadmin).
- **Komutlar:** `sqlcmd -S 100.119.104.122 -U uzman -d zkbiotime -C -f 65001 -Q "SELECT ... FROM personnel_employee WHERE status=0"`
- **Sonuç:** Adresler çok dağınık: yazım hataları (`الاسسسسكندرية`, `محلرم بك`, `ابو المكطامير`), Latin girişler
  (`Hanovil sahel`, `Awayed 45`), memleket adresleri (Sohag, Kena, Kafr el-Sheikh).

### 2. Ücretsiz servis seçimi ve testi
- **Neden:** "Limitsiz, ücretsiz" şartı.
- **Ne yapıldı / bulgular:**
  - Nominatim (OSM): ilçe/semtleri buluyor, Behira köylerinin çoğu OSM'de yok. Kural 1 istek/sn → sonuçlar DB'de önbellek.
  - Photon (komoot): bulanık, alakasız sonuç dönebiliyor (`النمرية` → Tanta) → ad + mesafe doğrulaması şart.
  - **GeoNames EG dökümü** (download.geonames.org/export/dump/EG.zip, CC BY): köyler var (قافلة, بلقطر, الوسطانية, كدوة) →
    bbox (lon 29.2–31.0, lat 30.4–31.45), P/A/L sınıfı, Arapça adlı 2971 kayıt `Veri/Sozluk/geonames-eg.tsv` olarak gömüldü. Çevrimdışı, kotasız.
  - OSRM genel sunucu: `table` istek başına **en çok 100 koordinat** ("TooBig") → 50×50 bloklarla matris.
  - Node `fetch` bu makinede IPv6/happy-eyeballs yüzünden zaman aşımı veriyor; testlerde
    `node --no-network-family-autoselection --dns-result-order=ipv4first` gerekti (.NET etkilenmiyor).

### 3. Uygulama (.NET 10 minimal API + Leaflet)
- **Dokunulan dosyalar:** `src/ServisPlanlama/` — `Program.cs`, `Ayarlar.cs`, `Veri/BioTimeDeposu.cs`, `Veri/Depo.cs`,
  `Konum/{AdresAyristirici,Bolgeler,Geocoder,YerSozlugu,KonumIsi}.cs`, `Rota/{Osrm,Cozucu,Planlayici}.cs`,
  `wwwroot/{index.html,app.js,app.css,lib/leaflet}`; `tests/` (24 test); `db/001_kurulum.sql`; `deploy/*`.
- **Adres çözümü:** Normalize (elif/ة/ى birleştir, tekrar harfleri teke indir, boşluksuz) → `Bolgeler` sözlüğü (≈45 semt/ilçe,
  takma yazımlarla, seviye 3>2>1, en belirgin seçilir) → adres `-`/`مركز`/`بجوار`… ile parçalanır, numara/önek atılır,
  `ش` → `شارع` olarak korunur → aday sırası GeoNames → Nominatim → Photon. Kabul şartı: sonuç adı adayı içerir, bölge yarıçapında,
  sonuç yalnız ilçe adı değil (`YalnizBolgeAdi`), köy adayı sokak sonucuyla eşleşmez (`SokakMi`). Yoksa bölge merkezi.
- **Rota:** 300 m içindeki evler tek durak; 14'ü aşan durak `Chunk(14)` (tam + kalan); OSRM süre matrisi;
  `Cozucu`: açık uçlu karışık filo VRP — Clarke-Wright iki strateji (karışık / önce küçük + büyükleri en kazançlı birleştirmelere dağıt),
  ardından durak taşıma + 2-opt; amaç = toplam süre + araç başı sabit maliyet (arayüzde kaydırıcı, varsayılan 20 dk); azami yolculuk 120 dk.
- **Veri:** önce SQLite yazıldı; kullanıcı isteğiyle **MSSQL `ServisPlanlama`** DB'ye geçildi (Konum, AramaOnbellegi[SHA-256 anahtar], Plan).
  Eski SQLite verisi `node:sqlite` ile okunup SQL'e çevrilerek aktarıldı (357 konum, 490 önbellek).
- **Komutlar:**
  ```bash
  sqlcmd -S 100.119.104.122 -U uzman -C -f 65001 -i db/001_kurulum.sql
  dotnet test ServisPlanlama.slnx
  ASPNETCORE_ENVIRONMENT=Development dotnet run --project src/ServisPlanlama --urls http://localhost:8086
  curl -X POST "localhost:8086/api/konum/bul?yeniden=true"
  curl -X POST localhost:8086/api/plan -H "Content-Type: application/json" -d '{"buyukAdet":2,"buyukKapasite":28,"kucukKapasite":14,"azamiSureDk":120}'
  ```
- **Sonuç / doğrulama:** 24/24 test geçti. Konum: 57 köy/sokak (`yer`), 279 bölge merkezi, 21 yok (14 boş adres, 7 il dışı memleket adresi).
  Plan (~35 sn): 29 araç (2×28 + 27×14), 336 kişi, ort. yolculuk 61 dk; 28'liklerden biri 28/28 dolu.
  Alt sınır 22 araç; fark uzak tekil personelden (Damanhur/Reşit/İtay, 115-130 dk). Tarayıcıda (chrome-devtools) harita, rotalar, servis kartları kontrol edildi;
  elle konum PUT/DELETE uçtan uca denendi.
- **Commit:** `a59e135` — ServisPlanlama: BioTime adreslerinden servis rotaları (OSM/OSRM) → https://gitlab.com/modfex-apparel/servisplanlama (push-to-create ile oluştu)

## Kararlar
- Mesafe **kuş uçuşu değil**, OSRM yol süresi (kullanıcı şartı). Kuş uçuşu yalnız geocoder sonucunu doğrulamada.
- OSRM erişilemezse kuş uçuşuna sessizce düşülmez, hata verilir.
- Sonuçlar MSSQL `ServisPlanlama` DB'de; zkbiotime'a yazılmaz.
- Ebu'l-Metamir köyleri (الياسنية, النمرية) hiçbir ücretsiz kaynakta yok → elle işaretleme.
- `.gitignore`'da `veri/` Windows'ta `Veri/` kaynak klasörünü de dışladı → `/veri/` yapıldı.

## Açık kalanlar / sonraki adım
- modfexsrv'ye kurulum (`deploy/yayinla.ps1` → `servis-kur.ps1`, `appsettings.Production.json` iki bağlantı cümlesi).
- 279 "bölge merkezi" personelin önemlilerini (özellikle Ebu'l-Metamir 30 kişi, Ebu Hummus 15) haritadan elle düzeltmek.
- İstenirse: servisler arası elle personel taşıma, plan Excel çıktısı, kendi OSRM/Nominatim Docker'ı.
- Yerelde kalan `veri/servisplanlama.db` (SQLite, artık kullanılmıyor) silinebilir.
