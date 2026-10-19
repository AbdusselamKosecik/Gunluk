# muftelif (SentezSelvedge) — 2026-10-19

## Bağlam
Hedef: SentezSelvedge, modfex-apparel/selvedge gibi tamamen Sentez'den çalışacak.
İstek: "Sentez'den çalışmayan ne var" analizi. Kod değişikliği yapılmadı.

## Yapılanlar

### 1. Sentez'den çalışmayan noktaların analizi
- **Neden:** Modfex selvedge'de QA/anket dışındaki her şey SentezCore view'leri (`0028_sentez_canli.sql`); SentezSelvedge'de neyin hâlâ yerel olduğunu çıkarmak.
- **Ne yapıldı:** `SentezSelvedge/db/000*.sql`, `api/Sentez/SentezSql.cs`, `api/Selvedge/*`, spec `docs/superpowers/specs/2026-10-03-sentezselvedge-design.md` ile modfex `db/migrations/0028/0029` karşılaştırıldı.
- **Bulgular:**
  1. `UZM_Selvedge_Firm` yerel CRUD tablo (Sentez carisinin kopyası değil, `SentezCurrentAccountId` opsiyonel). Anket cevabı ve KK raporu `FirmId` ile buna bağlı; KK'da ayrıca `SentezCurrentAccountId` var → çift kaynak. Modfex: `sv_Firm`/`sv_Supplier` = tüm cariler view.
  2. `UZM_Selvedge_Brand` yerel, API/seed yok → KK `BrandId` hep NULL. Modfex: marka = siparişi olan cari.
  3. `UZM_Selvedge_Defect` tablo var ama API/seed/ekran yok; KK hata satırı serbest metin. (Modfex'te de yerel — Sentez işi değil ama ölü.)
  4. Sezon hiç okunmuyor (`Erp_Season`, `Erp_Inventory.SeasonCode`/`UD_WashName` spec'te var, SQL'de yok).
  5. Order sorgusunda `WorkOrderType = 15` filtresi yok (modfex'te var) → üretim iş emirleri de listeye düşebilir. CompanyId filtresi de yok.
  6. Modfex'teki yerel ek alanların karşılığı yok: `sv_OrderQc` (Status/FinalQc/Supplier/Notes), `sv_StyleQa`.
- **Sonuç:** Kullanıcıya rapor edildi, karar bekleniyor.

## Açık kalanlar / sonraki adım
- Firma → Sentez cari mi, yerel mi kalacak (saha "Sentez'de olmayan firma" gerekçesi) kararı.
- Marka kaynağı, WorkOrderType filtresi, sezon okuma.

### 2. Firma, marka, sezon Sentez'den; sipariş tipi 15; OrderQc/StyleQa (uygulama)
- **Neden:** Kullanıcı kararı: "cari=firma Sentez CurrentAccount'tan, markalar Sentez'den (Erp_Mark), sezon Erp_Season, sipariş tipi 15, 6. maddeyi UZM olarak ekle".
- **Canlı Sentez'de ölçülenler (salt okuma):**
  - `Erp_WorkOrder` tipleri: 15 = 17.896 (sipariş), 30 = 32.994 (üretim) → liste filtresizken 30'lar da geliyordu. Tek şirket (CompanyId=1).
  - Marka: `Erp_Inventory.MarkId → Erp_Mark` (2026 sipariş kalemleri: CITIZENS OF HUMANITY 2130, AGOLDE 1588, boş 65). `Erp_Mark`'ta makine markaları da var (SINGER, PEGASUS) → marka listesi tip-15 sipariş modelleriyle sınırlandı. `Erp_Model` boş (Inventory.ModelId hiç dolu değil) → kullanılmadı.
  - Sezon: `Erp_Inventory.SeasonId → Erp_Season` (%98 dolu).
  - Yerel veri: Firm 1 satır (AKIN TEKSTIL, cari bağı YOK), Brand 0, 1 cevap firma bağlı, 1 Firm eki.
- **Ne yapıldı:**
  - `db/0006_sentez_kaynak.sql`: SurveyResponse.FirmId → SentezCurrentAccountId; QaReport.FirmId kalktı, BrandId → SentezMarkId; Firm ekleri cari RecId'ye, karşılıksız olan `FirmEski`; yeni `UZM_Selvedge_OrderQc` (PK SentezWorkOrderId) ve `UZM_Selvedge_StyleQa` (PK SentezInventoryId). Firm/Brand tabloları DROP edilmedi (ScriptTarayici DROP TABLE yasaklıyor).
  - API: `api/Selvedge/Firma/*` silindi, `firma.yaz` izni kalktı; `SentezSql.OrderAra` tip 15 + marka/sezon kolon ve filtre, `MarkaListe`/`SezonListe`/`CariById`; `/api/sentez/marka|sezon|cari/{id}`; KK ve anket Sentez carisi/markası; `api/Selvedge/OrderQa/*` (`/api/order-qa/order/{id}`, `/model/{id}`, iyimser kilitli upsert, sipariş Sentez'de yoksa 404).
  - Web: Firma sayfası salt okunur cari listesi; anket doldurmada cari araması; KK raporunda firma/marka siparişten; Siparişler sayfasında marka/sezon filtresi + Sipariş KK ve Model QA paneli.
  - Testler: `SentezKaynakTests`, `OrderQaTests` (+24).
- **Komutlar:**
  ```bash
  dotnet test SentezSelvedge/tests/SentezSelvedge.Tests   # 467/467
  cd SentezSelvedge/web && npm run build                  # temiz
  sqlcmd ... -i test0006.sql   # BEGIN TRAN; 0006; upsert 3 senaryo; ROLLBACK
  ```
- **Sonuç / doğrulama:** 0006 canlıda transaction içinde koştu: kolonlar doğru, Firm eki `FirmEski` oldu, upsert ilk kayıt=1 / yanlış sürüm=0 / doğru sürüm=1, FinalQcAt yazıldı; ROLLBACK sonrası trancount=0, tablo yok.
- **Commit:** `34d9347` — feat(sentez-selvedge): firma, marka, sezon Sentez'den; siparis tipi 15; OrderQc/StyleQa

### 3. Canlıya şema: 0006 + eski tabloların silinmesi + yetki
- **Neden:** Kullanıcı: "silinecek tabloları silsene", "yetkiyi de sen çalıştırır mısın".
- **Engeller:** `UZM_Selvedge_Firm/Brand`'e 3 FK bağlıydı (0006 bunları kaldırıyor) → sıra 0006 → silme → yetki. ScriptTarayici otomatik betikte DROP'a izin vermiyor → silme `db/elle/` altında elle betik. `dotnet run db-tool` SQL'e TCP zaman aşımı aldı (sqlcmd aynı sunucuya bağlanıyor; makinede .NET'e özgü ağ engeli, çözülmedi) → db-tool'un işi sqlcmd ile birebir yapıldı.
- **Ne yapıldı:**
  1. 0006 working copy CRLF'e çevrildi (checkout ile aynı içerik); SHA256 = `39C25516…7C6C` (db-tool yöntemi: BOM'suz metin, UTF-8; 0001/0005 kayıtlı hash'leriyle aynı yöntem doğrulandı).
  2. `BEGIN TRAN; 0006; INSERT SchemaHistory(0006, hash); COMMIT` — sqlcmd `-b`, XACT_ABORT.
  3. `db/elle/9002_eski_firma_marka_sil.sql` yazıldı ve koşturuldu (0006 yoksa / FK varsa durur) → Firm ve Brand yok.
  4. `9001_yetki.sql` geçici kopyada parola yer tutucusu rastgele parolayla değiştirilip master'da koşturuldu, kopya silindi. `uzm_selvedge_app` login'i HİÇ YOKTU — ilk kez oluşturuldu.
- **Doğrulama:** uzm_selvedge_app ile: Erp_Mark okuma OK, UZM_Selvedge_OrderQc INSERT OK (rollback), Erp_Mark UPDATE "izin reddedildi". 9001 doğrulama sorgusu boş.
- **Commit:** `cccb77b` — chore(sentez-selvedge): kullanim disi Firm/Brand tablolarini silen elle script (9002)

## Kararlar
- Sipariş listesi tip 15; tek sipariş okuma tipe göre süzmez (eski raporlar açılsın).
- Firm/Brand tabloları silinmez, kullanım dışı.
- Sipariş KK durumları: Acik/Kontrolde/Tamamlandi/Beklemede; final karar KK kararlarıyla aynı.

## Açık kalanlar / sonraki adım
- Şema canlıda (0006 + 9002 + 9001). ESKİ uygulama sürümü artık çalışmaz (FirmId/BrandId/Firm/Brand arıyor) → yeni paket 192.168.3.228:91'e kurulmalı (buradan sunucuya erişilemedi).
- Sunucuda `ConnectionStrings__Sentez` → uzm_selvedge_app + yeni parola (parola depoya YAZILMADI; kullanıcıya iletildi).
- Eski test verisi: AKIN TEKSTIL firmasına bağlı 1 anket cevabının firma bağı düşecek.
