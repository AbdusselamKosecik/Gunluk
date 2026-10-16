# Saas_erp — 2026-10-17

## Bağlam
İki panelli menü denemesi `feat/iki-panelli-menu` dalında sürüyor. Kullanıcı standart modüllerin Sentez gibi süreç bazlı ayrılmasını istedi (Envanter, Satın Alma, Satış Dağıtım, Finans…) ve SAP ile diğer ERP'lerin bunu nasıl ayırdığını sordu. Üretim modüllerine dokunulmayacak.

## Yapılanlar

### 1. ERP karşılaştırması (sohbette)
- SAP: MM (satın alma + stok + fatura kontrolü), SD (satış + sevkiyat + faturalama), FI/CO. Logo Tiger: Satınalma, Satış ve Dağıtım, Malzeme Yönetimi, Finans, Muhasebe. Sentez: Satın Alma, Satış, Malzeme, Finans, Genel Muhasebe. Netsis ve Odoo da benzer.
- Ortak ilke: belge türüne göre değil, süreçe göre ayırmak (talep → teklif → sipariş → irsaliye → fatura aynı modülde).

### 2. Süreç bazlı standart menü düzeni
- **Neden:** Bizde satın alma süreci Siparişler, Envanter, Finans ve Talep modüllerine dağılmıştı.
- **Ne yapıldı:**
  - `two-panel/menu-layout.ts`: `applyMenuLayout(modules, layout)` fonksiyonu. Sayfaları adresleri üzerinden yeniden gruplar.
    - Yalnızca tüm sayfaları `/inventory|orders|demand|logistics|crm|finance/` altında olan modüller "standart" sayılıyor, üretim modülleri hariç tutuluyor.
    - Sadece menüde görünen sayfalar yerleşiyor; lisans ve yetki filtresi korunuyor.
    - Düzende yeri olmayan sayfa eski modülünde kalıyor. Boş gruplar ve modüller budanıyor.
  - `two-panel/standard-menu-layout.tsx`: yeni modüller Stok, Satın Alma, Satış ve Dağıtım (Lojistik dahil), Fason, Finans (Cari/Kasa/Banka/Çek/Ödeme/Fatura/Kur-Vade/Döviz/Dış Ticaret), Muhasebe (Genel Muhasebe/Raporlar/Maliyet/Sabit Kıymet) ve CRM. Fiş tipleri `?type=` kodlarıyla dağıtıldı (ör. 3001 Mal Alım → Satın Alma, 3052 Toptan Satış → Satış, 3057 Fason Verilen Çıkış → Fason). "Tüm Siparişler / Teklifler / Talepler / Faturalar" hem Satın Alma'da hem Satış'ta duruyor.
  - `routes.tsx` değişmedi; sayfa adresleri aynı. Klasik menü eski gruplamayı gösteriyor.
- **Testler:** `menu-layout.test.ts` 6 test (yeniden gruplama, budama, artakalan sayfa, üretim modülüne dokunulmaması). `standard-menu-layout.test.ts` gerçek `HomeMenu` ile 3 test (her standart sayfa yerleşmiş, düzendeki her adres menüde var, üretim modülleri aynı). `src/layouts` toplamı 41 test geçti, typecheck temiz.
- **Görsel doğrulama:** playwright ile kontrol edildi. Şerit sırası: Anasayfa, Stok, Satın Alma, Satış ve Dağıtım, Fason, Finans, Muhasebe, CRM, Üretim, Boyahane… Mal Alım İrsaliyesi açıkken Satın Alma seçili.
- **Commit:** dal `feat/iki-panelli-menu`, push edildi.

## Kararlar
- Gruplama `routes.tsx` yerine menü katmanında yapıldı. Sebebi: route adresleri ebeveyn yolundan türetiliyor; öğeleri taşımak adresleri ve linkleri bozardı.

## Açık kalanlar / sonraki adım
- Kullanıcı onaylarsa kurul (CTO, Şüpheci, UX, Product Owner) çalıştırılacak, `dev`'e merge edilecek ve changelog maddesi eklenecek.
- Yeni modül başlıkları sabit Türkçe; i18n anahtarı yok (İngilizce arayüzde de Türkçe görünür).

---

## Ek: Teklif listesi 500 hatası (dev)

### Teklif / RFQ / Teklif Talebi listelerinde filtre-sıralama hatası
- **Neden:** Satış Teklifleri menüsü (`/orders/quotations?type=5101`) açılınca API 500 veriyordu: `InvalidOperationException ... new QuotationListResult(..).ReceiptType == 5101 could not be translated`. Handler önce `Select(new Result(..))` yapıp sonra `GridifyAsync` çağırıyordu; Gridify filtresi projeksiyona uygulanınca EF Core SQL'e çeviremiyor.
- **Ne yapıldı:** `GetQuotations`, `GetRfqs`, `GetQuotationRequests` handler'ları projede zaten kullanılan desene (`GetCurrentAccounts`/`GetInvoices`) çevrildi: `GridifyMapper<Entity>(autoGenerateMappings: true)` ile `ApplyFiltering` + `ApplyOrdering` entity üzerinde → `CountAsync` → `Skip/Take` → en sonda `Select` → `new Paging<T>(total, items)`. Varsayılan sıralama `CreatedAt desc` korundu.
- **Test (TDD):** InMemory sağlayıcı bu hatayı yakalamıyor (client-side çalışıyor). Bu yüzden `InventoryGroupSortingTests` desenindeki gibi gerçek Npgsql çeviricisi bağlantısız (interceptor ile) çalıştırıldı → önce 4 test kırmızı (kullanıcının hatasının aynısı), düzeltme sonrası yeşil. Dikkat: `QuotationRequests` sayfa sorgusu `Items.Count` alt sorgusunda `count(*)` içerdiği için sahte sayım yalnız `SELECT count(*)` ile başlayan komuta verildi.
- **Dokunulan dosyalar:** `src/backend/VuoApp.Modules.Orders/Features/{Quotations/GetQuotations.cs, Rfqs/GetRfqs.cs, QuotationRequests/GetQuotationRequests.cs}`, `tests/unit/VuoApp.UnitTests/Modules.Orders/OrdersListTranslationTests.cs`, `tests/unit/VuoApp.UnitTests/Modules.Orders/Quotations/GetQuotationsTests.cs`, `src/frontend/src/features/changelog/changelog.data.ts` (fix maddesi).
- **Komutlar:**
  ```bash
  dotnet test tests/unit/VuoApp.UnitTests --filter "FullyQualifiedName~Modules.Orders"   # 151/151
  dotnet build src/backend/VuoApp.slnx -c Debug                                           # 0 hata
  ```
  Not: çalışan API `bin` dosyalarını kilitlediği için test öncesi durdurulup sonra yeniden başlatıldı.
- **Sonuç / doğrulama:** Canlı (vuo_dev, MitoTex) `GET /api/v1/orders/quotations?filter=receiptType=5101`, RFQ ve teklif talebi listeleri filtre+sıralama ile 200 döndü (MitoTex'te kayıt yok, sayım 0).
- **Commit:** `d7e0ec96` — fix(orders): teklif, RFQ ve teklif talebi listelerinde filtre/siralama 500 hatasi (dev'e push → DEV deploy).

### Kararlar
- Kullanıcının doğrudan bugfix talimatı → kurul muafiyeti (CLAUDE.md üst kural 4). Aynı hata sınıfındaki iki kardeş liste (RFQ, Teklif Talebi) de aynı commit'te düzeltildi.

### Açık kalanlar
- Diğer modüllerde de `Select → GridifyAsync` sırası olan liste handler'ları olabilir; taranıp aynı desene çekilmesi önerilir.
