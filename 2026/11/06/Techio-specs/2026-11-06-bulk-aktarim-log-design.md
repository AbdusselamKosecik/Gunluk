# Toplu Aktarım (Bulk) Logu + Log Ekranı + Ekranda Versiyon — Tasarım

**Tarih:** 2026-11-06
**Durum:** Taslak, onay bekliyor. Uygulama sonra yapılacak.
**Kapsam:** `X:\Techio\backend` (API, .NET 10) + `X:\Techio\ui` (Vue 3)

---

## 1. Neden

Müşteri "kartları gönderdik ama değişmemiş" diyor. Şu an bunu doğrulayacak veya çürütecek
bir kayıt yok. `BulkInstallController.Post` gelen JSON'u sadece Serilog dosya loguna basıyor;
dosyada aramak zor, eski dosyalar kalmayabilir ve "biz ne yaptık" kısmı hiç yazılmıyor.

İstenen: anlaşmazlık olduğunda ekrandan bakıp şunu söyleyebilmek:
- "O tarihte bu siparişi / bu kartı hiç göndermemişsiniz", **veya**
- "Gönderdiniz, saat şu, şu kartı ekledik / şu alanı şundan şuna çevirdik / şunu sildik", **veya**
- "Gönderdiniz ama işlem şu hatayla yarıda kaldı."

## 2. Hedefler

1. Her `POST api/BulkInstall` çağrısı için **bir gönderim kaydı**: ne zaman, hangi sipariş no,
   hangi model, kaç kart, sonuç (başarılı / hata + mesaj), işlem süresi, ham gelen JSON (değiştirilmeden).
2. O gönderimde yapılan **her değişiklik için bir detay satırı**: hangi varlık (Kart, Varyant,
   Sipariş, Operasyon, Model rotası, …), hangi kod, işlem tipi (Eklendi / Güncellendi / Silindi /
   Değişmedi), alan bazında eski → yeni değer.
3. Kartlar için **"Değişmedi"** de yazılır — "kart değişmemiş" iddiasına "gönderdiğiniz değerle
   zaten aynıydı" cevabı verebilmek için.
4. UI'da **Aktarım Logları** ekranı: liste + detay + ham JSON görüntüleme.
5. UI'da **versiyon bilgisi**: ekranda hangi UI ve API sürümünün çalıştığı görünür.

## 3. Hedef dışı

- Diğer endpoint'lerin (`InsertTransection`, `RunSql`, `Cards/BulkInsert`) loglanması.
- `Post` metodunun iş mantığını düzeltmek/değiştirmek. Log, mevcut davranışı **gözlemler**;
  ne eklediyse, sildiyse onu yazar.
- Log ekranından geri alma / yeniden gönderme.

## 4. Anti-hedefler (çalışsa bile başarısızlık sayılır)

- Log yazımı hata verdiği için **aktarımın kendisinin bozulması**. Log hatası yutulur,
  Serilog'a yazılır, aktarım devam eder.
- Aktarım hata verdiğinde **logun hiç kalmaması**. Gönderim kaydı en başta yazılır, sonuç sonda güncellenir.
- Ham JSON'un kırpılması/yeniden biçimlendirilmesi (kanıt değeri kaybolur).

## 5. Mevcut durum (keşif)

- `backend/Techtsio.Presentation/Controllers/BulkInstallController.cs` → `Post([FromBody] BulkOrders)`.
  Sırası: Operasyonlar → Model → Bedenler → Renkler → Model rotaları (**önce tümü siliniyor,
  `ExecuteDeleteAsync`**, sonra yeniden ekleniyor) → Cari → Sipariş → Sipariş kalemi →
  Varyantlar → Kartlar.
- Kart döngüsü (`Post` içinde, ~satır 387-418):
  - Kart bulunamazsa aynı koddaki **diğer tüm aktif kartlar soft-delete** ediliyor
    (`ExecuteUpdateAsync(IsDeleted = true)`) → bu bir **taşıma/silme** olayıdır, loglanmalı.
  - Bulunsa da bulunmasa da `Descriptions, LotCode, BundleNo, ModelId, OrderId, Quantity, TypeId=9`
    üzerine yazılıp `Update` çağrılıyor → eski değerler `Update`'ten **önce** okunmalı.
- `Post` transaction içinde değil, try/catch yok; hata olursa yarıda kalır ve 500 döner.
- Controller'da `[Authorize]` yok; çağıran sistem Aktarım servisi (`backend/Aktarim`).
- Veritabanı değişiklikleri EF migration ile değil SQL script ile yapılıyor
  (son migration 2022; `UpdateDatabaseQueries.sql`, `SP_LocationId_Changes.md`).
- DAL deseni: `ICardsDal : IEntityRepository<Cards>`, `CardsDal : EntityRepository<TechtsioContext, Cards>`;
  entity'ler `Techtsio.Database/Domain`, context `Techtsio.Database/TechtsioContext.cs`.
- UI: Vue 3 + Syncfusion Grid + bootstrap-vue-next, route'lar `ui/src/router/index.ts`,
  menü `ui/src/containers/navs/Sidebar.vue`, alt bilgi `ui/src/containers/navs/Footer.vue`,
  `package.json` version `0.1.0`. Ekranda şu an versiyon yok.

## 6. Veri modeli

### 6.1 `BulkTransferLogs` — gönderim başlığı (her POST = 1 satır)

| Kolon | Tip | Not |
|---|---|---|
| `Id` | `uniqueidentifier` PK | |
| `ReceivedAt` | `datetime2` | İstek geldiği an (sunucu saati) |
| `FinishedAt` | `datetime2 NULL` | |
| `DurationMs` | `int NULL` | |
| `OrderNo` | `nvarchar(100)` | `postData.No` — **indeksli** |
| `OrderCode` | `nvarchar(100) NULL` | `postData.Code` |
| `ModelCode` | `nvarchar(100) NULL` | ilk OrderItem modeli |
| `CurrentAccountCode` | `nvarchar(100) NULL` | |
| `VariantCount` / `CardCount` | `int` | gelen veriden sayılır |
| `AddedCount` / `UpdatedCount` / `DeletedCount` / `UnchangedCount` | `int` | detaylardan özet |
| `Status` | `tinyint` | 0=İşleniyor, 1=Başarılı, 2=Hata |
| `ErrorMessage` | `nvarchar(max) NULL` | exception mesajı + inner |
| `RemoteIp` | `nvarchar(64) NULL` | `HttpContext.Connection.RemoteIpAddress` |
| `RawPayload` | `nvarchar(max)` | gelen JSON, **olduğu gibi** |

İndeks: `(OrderNo, ReceivedAt DESC)`, `(ReceivedAt DESC)`.

### 6.2 `BulkTransferLogItems` — değişiklik detayı

| Kolon | Tip | Not |
|---|---|---|
| `Id` | `uniqueidentifier` PK | |
| `LogId` | `uniqueidentifier` FK → `BulkTransferLogs` | indeksli |
| `Seq` | `int` | sıralama |
| `EntityType` | `nvarchar(50)` | `Card`, `OrderItemVariant`, `Order`, `OrderItem`, `Operation`, `OperationGroup`, `MachineType`, `Model`, `ModelRoute`, `ModelSize`, `ModelColor`, `SizeCard`, `ColorCard`, `CurrentAccount` |
| `EntityCode` | `nvarchar(200)` | kart kodu, operasyon kodu, "Renk/Beden" vb. — **indeksli** |
| `EntityId` | `uniqueidentifier NULL` | |
| `Action` | `tinyint` | 1=Eklendi, 2=Güncellendi, 3=Silindi, 4=Değişmedi |
| `Changes` | `nvarchar(max) NULL` | JSON: `[{"field":"Quantity","old":"10","new":"12"}]` |
| `Note` | `nvarchar(500) NULL` | örn. "Başka varyanttaki aynı kodlu kart silindi" |
| `ParentCode` | `nvarchar(200) NULL` | kartlar için varyant (Renk/Beden) |

Tablolar yeni bir SQL script ile oluşturulur: `backend/Sql/2026-11-06_BulkTransferLog.sql`
(ad builder'ın; mevcut desen SQL script).

## 7. Backend

### 7.1 Akış

1. `Post` girişinde: `BulkTransferLogs` satırı `Status=0` ile **hemen** kaydedilir
   (RawPayload = `Request.Body`'den okunan ham metin; okunamazsa `JsonConvert.SerializeObject(postData)`).
2. İş mantığı mevcut haliyle çalışır; her karar noktasında bir `BulkTransferLogItems` kaydı
   bellekteki listeye eklenir.
3. Sonunda (başarılı veya `catch` içinde) detaylar toplu eklenir, sayaçlar + `Status` + `FinishedAt`
   güncellenir. Hata olduysa exception **yeniden fırlatılır** (çağıran mevcut 500'ü görmeye devam eder).
4. Log yazma kodu kendi try/catch'inde; hata olursa Serilog'a yazılır, aktarım etkilenmez.

> Ham gövdeyi okuyabilmek için `[FromBody]` model binding'den önce `Request.EnableBuffering()`
> gerekir (küçük bir middleware ya da sadece bu route için filtre). Builder'ın kararı.

### 7.2 Ne loglanır (öncelik sırasıyla)

| Varlık | Eklendi | Güncellendi | Silindi | Değişmedi |
|---|---|---|---|---|
| **Kart** | ✔ | ✔ alan bazında (`Descriptions, LotCode, BundleNo, Quantity, ModelId, OrderId, TypeId`) | ✔ aynı kodlu diğer kartların soft-delete'i (her biri ayrı satır, eski OrderVariant bilgisiyle) | ✔ |
| **Sipariş kalemi varyantı** | ✔ | — (kod şu an güncellemiyor) | — | ✔ |
| **Sipariş / Sipariş kalemi / Cari** | ✔ | — | — | ✔ |
| **Model rotası** | ✔ (yeniden eklenen) | — | ✔ (silinen eski rotalar: operasyon kodu, sort, standart süre) | — |
| **Operasyon** | ✔ | ✔ (`AverageStandardTime, IsInOut, Name, OperationGroupId`) | — | — |
| Op. grubu, makine tipi, model, beden, renk, model-beden, model-renk | ✔ | — | — | — |

"Değişmedi" sadece kart, varyant, sipariş için yazılır (gürültüyü azaltmak için); diğerlerinde yazılmaz.

Model rotası "silinip yeniden eklendi" ise ekranda bu ikisi ayrı satır görünür; builder isterse
aynı operasyon kodu için sil+ekle çiftini **"Güncellendi"** olarak birleştirebilir (değişen alanlarla).
Bu birleştirme tercih edilir ama zorunlu değil.

### 7.3 Kod yapısı

- Yeni sınıf `BulkTransferLogger` (Business katmanı, scoped): `Start(...)`, `Added(...)`,
  `Updated(entityType, code, id, changes)`, `Deleted(...)`, `Unchanged(...)`, `CompleteAsync()`,
  `FailAsync(ex)`. Değişiklik karşılaştırması için küçük yardımcı:
  `Diff(string field, object old, object @new)` → farklıysa listeye ekler.
- Controller sadece bu sınıfı çağırır; iş mantığına dokunulmaz, sadece eski değerler `Update`
  öncesi okunur.
- Entity + Dal: `BulkTransferLogs`, `BulkTransferLogItems` → mevcut `IEntityRepository` deseni.

### 7.4 Okuma API'si — `BulkTransferLogController` (`[Authorize]`)

- `GET api/BulkTransferLog?startDate&endDate&orderNo&cardCode&status&page&pageSize`
  → başlık listesi (RawPayload **hariç**). `cardCode` verilirse o kartın geçtiği gönderimler
  (`BulkTransferLogItems.EntityCode` + `RawPayload LIKE` yedeği).
- `GET api/BulkTransferLog/{id}` → başlık + detay satırları.
- `GET api/BulkTransferLog/{id}/raw` → ham JSON (indir/görüntüle).
- `GET api/Version` → `{ apiVersion, buildDate }` (assembly InformationalVersion).

## 8. UI

### 8.1 Aktarım Logları ekranı

- Yer: menüde **Veri Giriş Ekranları** veya **Raporlar** altında "Aktarım Logları"
  (route `/app/data-input-screens/transfer-logs`). Yer builder'ın; sipariş ekranının yanında olması önerilir.
- **Filtreler:** tarih aralığı (varsayılan son 7 gün), Sipariş No, Kart Kodu, Durum (Tümü / Başarılı / Hata).
- **Liste (Syncfusion Grid, mevcut ekranlarla aynı stil):**
  Tarih-Saat · Sipariş No · Model · Cari · Kart sayısı · +Eklenen · ~Güncellenen · −Silinen · =Değişmeyen · Durum (yeşil/kırmızı rozet) · Süre.
- **Detay (satıra tıklayınca modal veya alt panel):**
  - Üstte özet + hata mesajı (varsa).
  - Sekme 1 **Kartlar**: Kart kodu · Varyant (Renk/Beden) · İşlem · Değişen alanlar (`Adet: 10 → 12`) · Not.
  - Sekme 2 **Diğer**: varlık tipi, kod, işlem, değişiklikler.
  - Sekme 3 **Gelen veri**: ham JSON, okunur biçimde gösterilir + "İndir" düğmesi (indirilen dosya **ham** hali).
  - İşlem renkleri: Eklendi yeşil, Güncellendi turuncu, Silindi kırmızı, Değişmedi gri.
- **Kart arama senaryosu:** Kart Kodu ile filtrelenince liste o kartın geçtiği tüm gönderimleri
  gösterir — "bu kart hiç gelmemiş" cevabı burada boş listeyle verilir.
- Sipariş ekranından (`Order.vue`) "Aktarım geçmişi" kısayolu: bonus, zorunlu değil.

### 8.2 Ekranda versiyon

- `Footer.vue`'da: `UI v<package.json version> · API v<api version>` (ör. `UI v0.2.0 · API v1.4.0`).
- UI versiyonu build sırasında `package.json`'dan gömülür (`process.env.VUE_APP_VERSION`,
  `vue.config.js` içinde tanımlanır) + build tarihi.
- API versiyonu `GET api/Version`'dan, uygulama açılışında bir kez çekilir; erişilemezse "API ?" yazılır.
- Bu iş için `package.json` version'ı `0.1.0`'dan anlamlı bir sürüme çekilir ve her yayında artırılır;
  API csproj'a `<Version>` eklenir.

## 9. Kenar durumlar

- Aynı sipariş birden çok kez gönderilirse: her gönderim ayrı başlık satırıdır (tekrar gönderim
  ekranda zaman sırasıyla görünür — "üç kez gönderdiniz, ikincide değişti" diyebilmek için).
- `OrderItems` boş / `CurrentAccount` null gelirse mevcut kod NRE fırlatır → log `Status=2` + mesaj ile kalır.
- Çok büyük payload: `nvarchar(max)` yeterli; liste sorgusu RawPayload'u çekmez.
- Saklama süresi: şimdilik sınırsız. İleride "X aydan eski kayıtları sil" job'ı eklenebilir.

## 10. Kabul kriterleri

1. Test DB'ye (`TechtsioMerkezTest`) Aktarım'dan bir sipariş gönderilince ekranda yeni satır görünür,
   kart sayısı ve ekle/güncelle/sil sayıları DB'deki gerçek değişiklikle tutar.
2. Aynı siparişi kart adedi değiştirilmiş halde tekrar gönderince, detayda o kart "Güncellendi,
   Adet: eski → yeni" görünür; değişmeyen kartlar "Değişmedi".
3. Kart kodu aranınca hiç gönderilmemiş kart için liste boş gelir.
4. Bozuk veri gönderilince aktarım eskisi gibi 500 döner **ve** log satırı `Hata` + mesajla görünür.
5. Log tablosu silinmiş/erişilemez olsa bile aktarım çalışmaya devam eder.
6. Footer'da UI ve API versiyonu görünür.

## 11. Açık noktalar (karar senin)

1. **Kod nerede yaşayacak?** `X:\Techio\backend` ve `X:\Techio\ui` git deposu değil; GitLab'daki
   `techtsio-core` / `techtsio-ui` eski sürüm (.NET 7/3.1). Uygulamaya başlamadan önce Techio
   kopyalarının GitLab'da yeni bir branch'e (örn. `net10`) alınması öneriliyor.
2. "Ekrana bir versiyon yok" ifadesini **uygulamanın sürüm numarası ekranda görünmüyor** diye
   yorumladım (§8.2). Kastedilen "her gönderimin versiyonu/sürüm geçmişi" ise o zaten §6'daki
   gönderim başlıkları ile karşılanıyor — teyit et.
3. Müşteri "kart değişmedi" derken kart kodu mu yoksa adet/lot mu kastediyor — tasarım ikisini de
   kapsıyor, ama ekranda öne çıkacak kolon buna göre seçilebilir.

## 12. Builder'a bırakılanlar

Script/dosya adları, menüdeki tam yer, rota sil+ekle birleştirmesi, ham gövde okuma yöntemi,
Grid kolon genişlikleri, sayfalama boyutu.
