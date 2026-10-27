# Dia_entegrasyon — 2026-10-27

## Bağlam
25.10'da DIA demodan kartlar, varyantlar ve fişler okunmuştu (`docs/dia-demo-cevaplar/`). Kullanıcı bir VuoApp API
anahtarı verdi ve "kartları ve fişleri içeri aktar" dedi. Kurul süreci dışında, doğrudan talimatla yapıldı.

## Yapılanlar

### 1. Anahtarın ortamı bulundu
- Salt okuma GET denemeleri: `app-dev.vuo.app` 200 döndü (tenant boş), `app.vuo.app` 401 `ApiKey.Invalid`.
- Anahtar yalnızca dev ortamında geçerli. Anahtar repoya ve günlüğe yazılmadı.

### 2. VuoApp API sözleşmesi çıkarıldı (Saas_erp kaynak kodu, Explore ajanı)
- Uçlar: items, items/bulk (≤500, kodla upsert), receipts, warehouses, units, unit-sets, types, kinds, currencies.
- **Varyant uçları API anahtarına kapalı** (`[ApiKeyScope]` yok).
- Fiş kaleminde varyant dizisi yok; kalem başına tek kombinasyon, en fazla 3 slot.
- Transfer onaylanırsa tek tarafı stoka işleniyor.
- Inventory komutlarında idempotency yok.
- Ayrıntılar: analiz §2.1.3.

### 3. Aktarım
- **Betik:** `tools/dia_to_saas.py` (modlar: dry | one | items | receipts)
  ```bash
  VUO_KEY=... python -I tools/dia_to_saas.py docs/dia-demo-cevaplar dry
  VUO_KEY=... python -I tools/dia_to_saas.py docs/dia-demo-cevaplar one       # depolar + ilk kart
  VUO_KEY=... python -I tools/dia_to_saas.py docs/dia-demo-cevaplar items     # 78 kart bulk
  VUO_KEY=... python -I tools/dia_to_saas.py docs/dia-demo-cevaplar receipts  # 14 fiş
  ```
- **Eşleme:** birimler mevcut SaaS birim ve setlerine eşlendi (PK→PKT, TN→TON). Tür eşlemesi TCR/HMD/MML/YMML/KK; fiş türü eşlemesi analiz §2.1.3'te.
- **Sorun:** `LND.BRD.360` kartının DIA açıklaması boş olduğu için bulk aktarımda "Name empty" hatası verdi. Ad olarak kart kodu kullanıldı, tekrar çalıştırıldı (upsert).
- **Sonuç (GET ile doğrulandı):** 2 depo (AI00, AI01), 78 kart (75 Ticari, 2 Hammadde, 1 Mamul), 14 fiş (kalem sayıları DIA ile aynı).
  Hepsi onaysız; stoka işlenmedi. 3 maliyet fişi atlandı. 11 varyantlı kart varyantsız aktarıldı.
- **Commit:** `b0e51b6` — feat(tools): DIA demo -> VuoApp app-dev deneme aktarim betigi; SaaS kisitlari analize eklendi

## Kararlar
- Fiş numarası `DIA-<fisno>`, KDV 0, para birimi TL.
- Devir fişinin SaaS karşılığı yok; 3015 (özel giriş) kullanıldı.
- Fişler onaylanmadı. Transfer tek taraflı işleneceği için onay kararı kullanıcıya bırakıldı.

## Açık kalanlar / sonraki adım
- Fişler onaylanacak mı (transfer hariç)?
- Varyantlar için VuoApp'ta varyant uçlarına ApiKeyScope eklenmesi gerekiyor (Saas_erp işi).
- Transferin iki taraflı işlenmesi için VuoApp tarafında düzeltme gerekiyor.

---

## Ek: KDV eksikliği ve SaaS API yetki listesi
- **Kullanıcı:** "KDV'ler gelmemiş."
- **Bulgu:** Kartın KDV'si VuoApp'ta `inventory/vats` kaydına GUID ile bağlanıyor. Bu uç API anahtarına kapalı (`[ApiKeyScope]` yok). `finance/vats` açık ama boş ve kart onu kullanmıyor.
- **Saas_erp `InventoryController.cs` için eklenmesi istenen yetkiler:** `[ApiKeyScope]` şu uçlara:
  - GET `vats`
  - GET/POST `variant-groups`
  - GET/POST `variant-cards`
  - GET/POST `variants`
  - GET `lookups/variants`
- Kullanıcı yetkiyi "diğer tarafa" yaptıracak. Saas_erp'te başkasının commit'lenmemiş değişikliği olduğu için o repoya dokunulmadı.

## Ek: Servis yazıldı (Sprint 01)
- **Neden:** Kullanıcı "bunları bizim servisle yapsan olmaz mıydı" dedi, ardından "hadi başla" dedi. Kurul atlandı (doğrudan talimat, CLAUDE.md md.4).
- **Plan:** `yonetim/sprintler/sprint-01.md`
- **Ne yapıldı:**
  - Solution `Dia.Integration.slnx`, .NET 10.
  - **Core, Data, Saas:** Saas_entegrasyon'dan isim değiştirilerek taşındı. Data'ya eklenenler:
    - `Settings` (DPAPI LocalMachine + entropy),
    - `SourceLookups` (DIA birim key → kod),
    - `RunRequests` kuyruğu,
    - WAL (`PRAGMA journal_mode=WAL`),
    - `Default Timeout=30`.
  - **Dia:** `DiaWsClient`
    - login (`disconnect_same_user=false`),
    - 419'da tek seferlik yeniden login,
    - 406'da `DiaCreditException` (demo için `dia.demoKontorYoksay`),
    - keyset sayfalama,
    - logout,
    - ayarların en fazla dakikada bir okunması.
  - **Okuyucular:**
    - Depo: `sis_yetkili_firma_donem_sube_depo`.
    - Stok kartı: `_date` delta, `birim_listesi`.
    - Malzeme fişi: başlık listesi + getir (KDV ve varyant getir'de; birim uzun adla geldiği için key → kod lookup kullanılıyor).
  - **Job'lar:**
    - `depo`
    - `stokkart` (bulk, delta, birim/set/tür çözümü, birim lookup yazımı)
    - `malzemefisi` (depolar = X/Y/Z giriş filtresi, ya hep ya hiç, 409 → tarih ve kalem sayısıyla doğrulanmış eşleme, kalıcı/geçici hata ayrımı)
  - **CLI (`DiaIntegration.exe`):** `settings`, `set-setting`, `jobs`, `job-enable`, `job-disable`, `job-param`, `run-once`, `request`, `unresolved`.
  - **Testler:** 37 xUnit testi. Fixture olarak DIA demo cevapları, store'lar için gerçek SQLite in-memory.
- **Canlı doğrulama (geçici veritabanı, demo DIA → app-dev):**
  ```bash
  export ConnectionStrings__Integration="Data Source=<scratch>/test-run.db"
  DiaIntegration set-setting dia.sunucuKodu diademo   # ... ws/ws, firma 1, dönem 1, demoKontorYoksay true
  DiaIntegration set-setting saas.baseUrl https://app-dev.vuo.app/
  DiaIntegration set-setting saas.apiKey <anahtar>    # şifreli
  DiaIntegration run-once depo stokkart malzemefisi
  ```
  - depo: 2, stokkart: 77 (demoda 78'den 77'ye inmiş), malzemefisi: 14 fiş 409 sonrası eşlendi, 3 maliyet fişi atlandı.
  - İkinci tur delta: 0 değişiklik. Kuyruk isteği "Bitti". Kilit testi: ikinci süreç atlandı. Logout yapıldı.
  - İlk denemede app-dev geçici 502 döndü; Polly 3 kez denedi, sonraki çalıştırma geçti.
- **Bulunan ve düzeltilen hatalar:**
  - CLI başka klasörden çalıştırılınca `appsettings.json` bulunmuyordu → `ContentRootPath = AppContext.BaseDirectory`.
  - Konsol Türkçe karakterleri bozuyordu → UTF-8 çıktı.
- **Kod incelemesi (feature-dev:code-reviewer):** 9 bulgu çıktı, hepsi düzeltildi (sprint-01.md "Sonuç" bölümünde).
- **Commit'ler:**
  - `2aeea98` — feat: DIA -> SaaS entegrasyon servisi (sprint 01)
  - `ecc2938` — fix: kod inceleme bulguları

## Kararlar (servis)
- Fiş kalemleri `_listele_ayrintili` yerine `getir` ile okunuyor. Getir KDV ve varyantı veriyor, ayrintili vermiyor. Fiş başına 1 çağrı.
- Yazılmış fiş DIA'da değişirse güncellenmiyor; politika kurulda belirlenecek.
- Job'lar varsayılan pasif başlıyor; `job-enable` ile açılıyor.
- Fiş başlığı `>=`, kart `>` ile okunuyor. Kartta `>=` her turda bulk yeniden yazım demek; fişte SyncMap tekrarı ucuza atlıyor.

## Açık kalanlar (güncel)
- Saas_erp API yetkisi gelince varyant ve KDV aktarımı.
- Sprint 02: yönetim uygulaması, SaaS → DIA üretim ve sarf fişleri.
- Fişler hâlâ onaysız (transfer tek taraflı işleniyor, VuoApp hatası).
