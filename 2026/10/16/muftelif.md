# muftelif (SentezPlaning) — 2026-10-16

## Bağlam

Planlamadan (Asiye AYDIN, MFG Giyim) 15 Ekim'de gelen e-posta: dikim planı Excel'i
yüklendiğinde görünen sipariş adetleri, **"Sentez'den çek"** butonuna basınca
değişiyor. Soru aynen: *"Adetler neden değişiyor?"*

Elimde: iki `.eml` (15 Ekim ve 28 Ağustos), 15 Ekim'in ekinde plan Excel'i
(`5 Cep Fashion Non Denim Gömlek Dikim Planı 15.10.2026.xlsx`) ve çekim
öncesi/sonrası iki ekran görüntüsü.

## Yapılanlar

### 1. Kök neden bulundu (sistematik hata ayıklama)

- **Neden:** Rapor edilen davranış bir hata gibi görünüyordu; sayıların yanlış mı
  yoksa anlamlarının mı farklı olduğunu ölçmeden düzeltmeye girişmek yanlış olurdu.

- **Ne yapıldı:**
  1. İki ekran görüntüsü karşılaştırıldı. Kritik gözlem: **order sayıları birebir
     aynı** (7/13/13/24/11 = 68). Sipariş eklenip çıkmıyor, sadece adetler oynuyor —
     hem de iki yönde (+121, +74, **−24**, +176, +54; toplam +401).
  2. Ek Excel okunup dikim çıkış haftasına göre toplandı → **"önce" ekranıyla birebir**
     (5.805 / 14.892 / 8.950 / 14.660 / 12.550, toplam 56.857).
  3. Kod izlendi: `PLAN ADET` = `PlanOrder.Adet`, ve bu alan iki farklı kaynaktan
     doluyor:
     - `UretimPlanImport.cs` → Excel'in `ADET` kolonu
     - `UretimPlanService.SentezdenCekAsync` → ERP'nin adedi, **bilerek ezerek**
       (*"ADETLER HER ÇEKİŞTE ERP'DEN EZİLİR (planlamanın kararı)"*)
  4. `SentezSqlFragments.Quantity` okundu: ERP adedi = üretim varyantı toplamı varsa
     **o**, yoksa `SUM(CEILING(sipariş × 1.04))`.
  5. VPN açılınca canlı ERP'de 68 orderın tamamı sorgulandı ve üç şey kanıtlandı.

- **Dokunulan dosyalar (okuma):** `SentezPlaning/api/Sentez/UretimPlan/UretimPlanService.cs`,
  `UretimPlanImport.cs`, `UretimPlanSql.cs`, `api/Sentez/Common/SentezSqlFragments.cs`

- **Sonuç / doğrulama:**

  | Hafta | Excel | ERP sipariş | ERP üretim (16/10) | ×1.04 | Ekran "sonra" (15/10) |
  |---|---|---|---|---|---|
  | 2026-42 | 5.805 | **5.805** | 5.926 | 6.075 | 5.926 |
  | 2026-43 | 14.892 | **14.892** | 15.002 | 15.551 | 14.966 |
  | 2026-44 | 8.950 | **8.950** | 8.946 | 9.381 | 8.926 |
  | 2026-45 | 14.660 | **14.660** | 14.866 | 15.370 | 14.836 |
  | 2026-46 | 12.550 | **12.550** | 12.662 | 13.107 | 12.604 |
  | TOPLAM | 56.857 | **56.857** | 57.402 | 59.484 | 57.258 |

  1. Excel'in `ADET` kolonu = ERP sipariş adedi, **her haftada birebir**.
  2. `×1.04` kolu **hiç çalışmıyor** — 68/68 orderda ERP üretim kaydı var.
  3. Üretim adedi **gün gün değişiyor**: kesimi biten 2026-42 tam tutuyor,
     açık haftalar 15/10 → 16/10 arasında 144 adet kaymış.

  **Yani sayılar yanlış değildi.** Ekran iki farklı iş büyüklüğünü (sipariş adedi ve
  üretim adedi) tek kolonda gösteriyor, buton basılınca sessizce diğerine geçiyordu.

### 2. Düzeltme (TDD)

- **Neden:** Planlamacının sabit referansı olmalı; ERP de tek doğru kaynak kalmalı.
  İkisini ayrı kolonlara ayırmak her iki şartı da koruyor.

- **Ne yapıldı:**
  - Önce **kırmızı test**: `UretimPlanImportTests.Excel_adedi_SIPARIS_adedine_de_yazilir`
    (yanında kontrol testi `Adetsiz_satir_atlanir` ilk turda geçti — parser sağlam).
  - `UretimPlanImport`: `SiparisAdet = adet` eklendi (eskiden **hiç** doldurulmuyordu).
  - `CapacityRowDto.SiparisAdet` + `GetWeeks` toplamı. Bu düzeltmeden önce yüklenmiş
    planlarda alan boş olacağı için `SiparisAdet > 0 ? SiparisAdet : Adet` geri düşüşü
    kondu (`GetAsama`'daki mevcut kalıbın aynısı).
  - Ekranda **"Sipariş"** kolonu; `Plan Adet`'in yanında fark rozeti (`+121` gibi);
    iki kolona da ne oldukları anlatan başlık ipucu.
  - Excel çıktısında da `Sipariş` kolonu — kolonlar bir kaydı, `opIlk` 12 → 13,
    toplam satırındaki `PlanAdetPayli` hücresi 9 → 10.
  - Alt toplam satırlarının hizası düzeltildi (`colSpan` 7→8, 11+opN→12+opN) ve
    TOPLAM satırına sipariş hücresi eklendi.
  - `InternalsVisibleTo` eklendi (`UretimPlanImport` internal, testten çağrılıyor).

- **Dokunulan dosyalar:** `SentezPlaning/api/Sentez/UretimPlan/{UretimPlanImport,UretimPlanModels,UretimPlanService,UretimPlanExport}.cs`,
  `SentezPlaning/api/SentezPlaning.Api.csproj`,
  `SentezPlaning/web/src/api/uretimPlan.ts`,
  `SentezPlaning/web/src/pages/UretimPlanlamaPage.tsx`,
  `SentezPlaning/tests/SentezPlaning.Tests/UretimPlanImportTests.cs`

- **Komutlar:**
  ```bash
  dotnet test tests/SentezPlaning.Tests --filter "FullyQualifiedName~UretimPlanImportTests"
  dotnet test tests/SentezPlaning.Tests
  npx tsc -b            # web/
  .\Deploy-IIS.ps1
  ```

- **Sonuç / doğrulama:** Testler **226/226**, `tsc -b` temiz, API derlendi.

- **Commit:** `2689396` — fix(uretim-plan): siparis adedi ile ERP uretim adedi ayri kolonlarda

### 3. Paket

- **Ne yapıldı:** `.\Deploy-IIS.ps1` (web build + publish), sonra zip.
- **Sonuç:** `publish` 70 dosya / 22,7 MB; sır, `.db`, `.log`, `Development` dosyası yok.
  Zip: `X:\Gitlab\fredericTr\SentezPlaning-paket-2026-10-16.zip` (7,9 MB).
- **Bayatlık kontrolü:** paketteki minified JS içinde yeni başlık ipucu metinleri
  arandı ve bulundu — paket gerçekten bu commit'ten üretilmiş.
- **Kurulum (kullanıcıda):**
  ```powershell
  .\Deploy-IIS.ps1 -SkipWebBuild -SetupIIS -SiteName SentezPlaning -Port 8090 -PhysicalPath 'C:\inetpub\SentezPlaning'
  ```

### 4. Hesap esası sipariş adedine çevrildi (aynı gün, planlamanın isteğiyle)

- **Neden:** Planlama, 3. maddedeki çözümü gördükten sonra *"hesapları kesim adedine
  göre değil order adetine göre alın"* dedi. İki gerekçe de ölçümle destekli:
  ERP üretim adedi gün gün değişiyor (144 adet kayma ölçüldü) ve kesim adedinin
  üstüne bir de `+%Pay` eklemek çift sayım.

- **Ne yapıldı:**
  - Esas **tek yere** taşındı: `UretimPlanService.PlanlamaAdedi(PlanOrder)`.
    Aynı mantık `GetKesimWeeks`'te zaten vardı ve gerekçesi kodda yazılıydı;
    dikim tarafına uygulanmamıştı. Artık iki ekran birbirinden kayamaz.
  - Esasa bağlananlar: kapasite tablosu plan adedi, **SMV ağırlığı** (Ort. SMV ve
    SAH, Plan Adet'le tutarsız kalmasın diye), sevk görünümü, özet (toplam +
    haftalık ortalama plan), order satırlarında toplam SMV ve plan-fiili farkı.
  - **Değişmedi:** yıkama ve finish aşama planları kesim adedini kullanmaya devam
    ediyor — yıkamaya fiilen kesilmiş parça giriyor, gerekçesi kodda yazılı.
    Planlama isterse tek satırla çevrilir.
  - `CapacityRowDto.SiparisAdet` → `ErpAdet` olarak yeniden adlandırıldı; alan artık
    ters anlamı taşıyor, eski adı yanlış okunurdu.
  - Ekran/Excel: **"Plan Adet" = sipariş adedi** (hesap esası), yanındaki
    **"ERP Kesim"** kolonu bilgi amaçlı ve fark rozetini taşıyor.

- **Dokunulan dosyalar:** `UretimPlanService.cs`, `UretimPlanModels.cs`,
  `UretimPlanExport.cs`, `web/src/api/uretimPlan.ts`, `web/src/pages/UretimPlanlamaPage.tsx`,
  `tests/.../UretimPlanImportTests.cs`

- **Sonuç / doğrulama:** 229/229 test, `tsc -b` temiz. Esas **iki kez yön değiştirdiği**
  için üç nöbetçi test eklendi (`PlanAdetEsasiTests`). Servis altı bağımlılıkla
  kurulduğu ve fikstür olmadığı için bu testler kaynak metnini yokluyor — zayıf ama
  sessiz geri dönüşü görünür kılıyor. **Açık borç: `UretimPlanService` için fikstür.**

- **Commit:** `d022431` — feat(uretim-plan): hesap esasi SIPARIS adedi

### 5. Gelmeyen SMV'ler — canlı ERP'de kovalandı

- **Neden:** 28 Ağustos'taki e-postada *"Basic(classic) bantta 1 order SMV'si gelmiyor,
  oysa orderda SMV girili"* deniyordu. VPN ayaktayken bakmak mantıklıydı.

- **Ne yapıldı / Sonuç:** 15/10 planındaki **203 orderın tamamı** sorgulandı.
  - 5 CEP'in 68 orderının **hepsinde** dikim SMV'si var — Ağustos'taki şikâyet
    bu plan için geçerli değil.
  - **13 orderda SMV sıfır.** Hepsinde tek kalem var ve o kartta
    `Erp_InventoryWorkStudy`'de **hiç satır yok** (silinmiş/pasif bile değil).
  - "Başka kalemde olabilir" ihtimali elendi (13/13 tek kalem).
  - `Erp_Inventory`, `Erp_WorkOrder`, `Erp_WorkOrderItem` tablolarında SMV benzeri
    **hiçbir kolon yok** — ERP'de SMV'nin tek kaynağı etüt.
  - Temel koda göre kardeş kart araması: 13'ten **4'ünde** SMV'li kardeş kart var
    (`2318-1101`→`2318-1617` 21,41 · `9519-2125`→`9519-1359-DARK OLIVE` 60 ·
    `A9153C-1895`→`A9153C-1554` 19,5 · `A9268-1346`→`A9268-1810` 38,54).
    **Değerler çok saçılmış, otomatik ikame tahmin olur** — yıkama tarafındaki
    style varyantı dersinin aynısı.

- **Çıkarım:** Bu bir yazılım hatası değil, **ERP veri eksiği**. Yazılımın
  yapabileceği şey eksiği *eyleme dönüştürülebilir* hale getirmek: ekran şu an
  yalnızca `⚠3` gibi bir **sayı** gösteriyor, hangi order olduğunu söylemiyor.

### 6. Çalışma takvimi HAT BAZLI + tatil haftası raporda görünür

- **Neden:** İki ayrı istek aynı işe bakıyordu. (1) 16 Ekim: *"hat bazlı olsun,
  departman departman"* — bir bant tatil edilirken diğerleri çalışabilmeli.
  (2) 28 Ağustos: *"W37 dikimler tatil ediliyor... 37. haftaya veri gelmedi.
  Raporda ilgili haftayı listeye getirip siparişleri sıfır gösterelim."*

- **Ne yapıldı — hat bazlı takvim:**
  - `work_days` birincil anahtarı `(line_id, tarih)` oldu. `line_id = ''` →
    **tüm hatlar**; resmî tatiller oraya yazılır, hatlar miras alır.
  - SQLite `PRIMARY KEY`'i `ALTER` edemediği için tablo **yeniden kuruluyor**
    (`PlaningDb.WorkDaysHatGocu`). Mevcut günlerin hepsi `''` olur →
    **göçten sonra davranış aynen korunur.** Göç bayrak yerine **kolon varlığına**
    bakar, yani idempotent; yarıda kalan çalışma ikinci açılışta tamamlanır.
  - Çözüm kuralı saf sınıfa çıkarıldı: `HatTakvimi` — *hattın kendi günü tüm
    hatlar gününü ezer.*
  - Kapasite tablosu **hattın** takvimini kullanır; aşama planları (kesim/yıkama/
    finish) hat üstü olduğu için **tüm hatlar** takvimini kullanmaya devam eder.
  - `calisma-takvimi` uçlarının hepsi (oku/kaydet/export/import) `lineId` taşır.
  - Ekranda hat seçici; miras alınan gün `takvim-genel` kaynağıyla ayırt edilir.

- **Ne yapıldı — tatil haftası:**
  - Haftalar artık order'lardan değil, ilk–son arasını **dolduran** diziden geliyor
    (`HaftaDizisi.Arada`). Order'ı olmayan hafta listeden düşmüyor.
  - Order'ı olmayan hafta **"sarı" gösterilmiyor**: fark 0 çıkacağı için eski kural
    tatil haftasını kapasite sorunu gibi okuturdu.
  - Satırda `tatil` / `plan yok` rozeti.
  - Dizi yalnızca **ilk–son arasını** doldurur; pencereyi dışarı büyütmek
    `GetWeeksToplam`'daki "ilk ve son hafta kısmıdır, dışlanır" kuralını bozardı.
    Bozuk aşama tarihine karşı **120 hafta tavanı** kondu.

- **Yakalanan hata (okuyarak):** Kural serviste dururken `lineId` boşken global
  takvimin **her günü "miras" işaretleniyordu** — bu resmî tatil işlemeyi bozardı,
  çünkü tatil mantığı zaten işlenmiş günleri atlıyor. Saf sınıfa çıkarma kararının
  karşılığı burada geldi; artık regresyon testi var
  (`Genel_takvim_sorulurken_gunler_MIRAS_sayilmaz`).

- **Dokunulan dosyalar:** `api/Storage/{PlaningDb,UretimPlanRepository}.cs`,
  `api/Sentez/UretimPlan/{HatTakvimi,HaftaDizisi,UretimPlanService,UretimPlanModels,UretimPlanController}.cs`,
  `web/src/api/uretimPlan.ts`, `web/src/components/planning/CalismaTakvimi.tsx`,
  `web/src/pages/UretimPlanlamaPage.tsx`, üç test dosyası

- **Sonuç / doğrulama:** **244/244** test (13 yeni), `tsc -b` temiz. Paket
  yenilendi; hat seçici ve tatil rozeti metinleri minified JS içinde arandı, bulundu.

- **Commit:** `eb4059c` — feat(uretim-plan): calisma takvimi HAT BAZLI + tatil haftasi raporda gorunur

## Kararlar (ek)

- Hesap esası sipariş adedi; yıkama/finish aşamaları kesim adedinde kaldı (fiziksel
  gerekçe kodda yazılı). Planlama isterse değiştirilir.
- Eksik SMV'de kardeş kart değeri **otomatik kullanılmayacak** — ölçülen saçılma
  (19,5 ile 60 arası) buna izin vermiyor.

## Açık kalanlar (güncel)

- ~~Takvim isteği~~ — **yapıldı** (6. madde). Kullanıcı "hat bazlı olsun" dedi,
  aşama değil hat kırılımı seçildi.
- **Eksik SMV ekranı:** order numaralarını listeleme + elle SMV girişi
  (`OverrideSmv` ucu serviste VAR, ekranı yok).
- Yıkama planlama tarafı (14 Ekim e-postası) hâlâ açık.
- Kurulu sürümdeki Islak kapasitesi 40.500 — kurulu `sentez-planing.db` lazım.

## Kararlar (ilk tur)

- **`PLAN ADET` ERP üretim adedi olarak KALIR.** Kapasite hesabı gerçekte kesilecek
  adetle yapılmalı; sipariş adedine döndürmek planı gerçeklikten koparırdı. Fark artık
  `Sipariş` kolonuyla görünür.
- Eski planlarda `SiparisAdet` boş olacağı için kolonun boş görünmemesi adına `Adet`'e
  geri düşülür. Çekim ya da yeni yükleme sonrası gerçek değer gelir.
- Excel çıktısına da kolon eklendi: ekranla çıktının ayrışması, planlamanın raporu
  paylaşırken aynı soruyu tekrar sormasına yol açardı.

## Açık kalanlar / sonraki adım

- **28 Ağustos tarihli e-postada iki istek daha var, henüz yapılmadı:**
  1. Basic (Classic)'te **1 orderın SMV'si gelmiyor**, oysa orderda SMV girili.
  2. **Tatil haftası raporda hiç görünmüyor** (W37 dikimleri tatil, takvim sıfırlanınca
     hafta listeden düşüyor). İstek: hafta listede sıfırlarla görünsün ki tatil fark
     edilsin.
- **Yıkama planlama tarafı** (14 Ekim'deki ayrı e-posta) hâlâ açık: kapasite kısıt
  kolonu (`WEEKLY CAPACITY CONSTRAIN`), grup/TOPLAM satırları, `Max Loading` /
  `Operators Requirement` / `Machine Requirement` kolonları. Kapsam kullanıcıyla
  netleşmedi.
- Kurulu sürümdeki Islak bölüm kapasitesi **40.500 saat** görünüyor; muhtemelen
  operasyon parametresine saat yerine dakika girilmiş. Kesinleştirmek için kurulu
  sunucudaki `<site>\data\sentez-planing.db` lazım.
