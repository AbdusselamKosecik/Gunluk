# Dia_entegrasyon — 2026-10-20

## Bağlam
Yeni proje. Hedef: DIA ERP ↔ SaaS (VuoApp) entegrasyonu; `Saas_entegrasyon` (Sentez ERP) ile aynı yapıda
bir Windows Service + yönetim uygulaması (servis kur/kaldır, tetikleme, ayarlar).
DIA → SaaS: malzeme kartları, depolar, mamuller, depo hareket fişleri. SaaS → DIA: üretim fişi, sarf fişi.
Bugünkü iş: repo açmak ve analiz (kod yok; geliştirme kurul onayından sonra).

## Yapılanlar

### 1. Repo açıldı
- **Neden:** Kullanıcı talebi; Saas_entegrasyon'un kardeşi olarak `vuo-app` org'unda.
- **Ne yapıldı:** `X:\GitHub\vuo-app\Dia_entegrasyon` oluşturuldu, README + `.gitignore` (Saas_entegrasyon'dan kopya).
- **Komutlar:**
  ```bash
  git init -b main
  gh repo create vuo-app/Dia_entegrasyon --private --source . --remote origin --push
  ```
- **Sonuç:** https://github.com/vuo-app/Dia_entegrasyon (private)
- **Commit:** `15d8e2c` — chore: proje iskeleti (README, .gitignore)

### 2. Referans proje analizi (Saas_entegrasyon)
- **Neden:** Aynı mimari izlenecek; nelerin taşınıp nelerin düzeltileceğini bilmek.
- **Bulgular:** .NET 10; Core/Sentez/Saas/Data(SQLite)/Worker/Admin(WinForms)/App(Avalonia). VuoApp `X-Api-Key`,
  `{succeeded,data}` zarfı, `/bulk` upsert, Polly (3dk/10dk). Job'lar: depo, cari, unitset, doviz, kdv, inventory,
  kimyasal, kumas, fis134, yikama, uretimfisi (VuoApp→Sentez, receiptType 3010, direction guard fail-closed).
- **Taşınmayacak hatalar:** servis kurulum aracı yok; GUI servisi tetikleyemiyor (kendi sürecinde çalıştırıyor);
  iki ayrı ayar kaynağı; düz metin sır + koda gömülü sa parolası; WAL açılmıyor; ölü `JobDefinition.Watermark`;
  koda gömülü RecId (`Depo13RecId=24`).

### 3. DIA WS v3 analizi
- **Kaynak:** https://doc.dia.com.tr/doku.php?id=gelistirici:wsapi:genel (girişsiz açık).
- **Ana bulgular:** `https://<sunucu>.ws.dia.com.tr/api/v3/<sis|scf|ure>/json`, POST JSON; login → session_id
  (1 saat boşta düşer, 419); her çağrı 0,0125 kontör. Keyset sayfalama (`_key >`), delta `_date`.
  Stok kartı `scf_stokkart_listele`, mamul = `stokkartturu` MML/YMML. Depo: `sis_yetkili_firma_donem_sube_depo`
  + `sis_depo_getir`. Fişler `scf_malzeme_fisi_*` (turu 2=Üretimden Giriş, 3=Sarf). Üretim fişi ayrıca
  `scf_uretim_fisi_ekle`. `_key` alanlarına `{"stokkartkodu":"X"}` gibi eşleşme nesnesi verilebiliyor.
  Bulk yok, idempotency yok → SyncMap + fisno ön kontrolü.
- **Dokunulan dosyalar:** `docs/dia-entegrasyon-analiz.md`, `docs/dia-ws-ornekler/*.json` (32 resmî örnek)
- **Commit:** `07afa90` — docs: DIA WS API ve entegrasyon analizi, ornek DIA istek/cevap JSON'lari

## Kararlar (öneri, kurul onayı bekliyor)
- Proje adlandırma `Dia.Integration.*`; Saas ve Data katmanları Saas_entegrasyon'dan taşınır.
- GUI tetikleme: SQLite `RunRequests` kuyruğu, tek yazıcı servis.
- Sırlar DPAPI ile, tek ayar kaynağı SQLite `Settings`.
- Servis kur/kaldır: `sc.exe` (UAC yükseltmeli), başlat/durdur `ServiceController`.
- Birim seti: DIA kart bazlı birimlerden sentetik set üretimi.

## Açık kalanlar / sonraki adım
- Analiz §6 açık soruları: üretim fişi Yol A/B, sarf fişinin SaaS kaynak tipi, aktarılacak fiş türleri,
  reçete kapsamı, GUI teknolojisi, DIA demo/API key, SaaS receipt-type/update ucu.
- `/kurul Dia_entegrasyon` → `/sprint-planla` → "başla".
