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

## Kararlar

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
