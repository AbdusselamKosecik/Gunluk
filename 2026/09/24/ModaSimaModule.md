# ModaSimaModule — 2026-09-24

## Bağlam

Zamanlanmış iş **JOB-29970 "E-arşiv durum sorgulama"** başarısız oldu:

```
Deneme      1 / 1
Hata Kodu   ZAMAN-ASIMI
Hata Mesajı Çalıştırma 360 dakikalık zaman aşımını aştı.
```

Job önce `GET /EArsiv/GetList` çağırıyor, dönen listeyi `POST /EArsiv/Run`'a
gönderiyor. Soru: neden hiç cevap vermedi. "Yavaş" değil, **cevap yok** —
bu ayrım önemli, aşağıdaki teşhisin dayanağı bu.

Not: 19 Eylül'den bu yana `EArsivController.cs` üzerinde benim dışımda
değişiklik yapılmış (SysMng.DefaultLogger tabanlı loglama, create yolunun
type 2 = `CreateEInvoice` / type 3 = `CreateEInvoice`+`SendEInvoice` olarak
ayrılması, `GetList`'in `LoginToOtherCompany` yerine `LoginSysMng.getSession()`
kullanması). Analiz bu güncel hal üzerinden yapıldı.

## Yapılanlar

### 1. Kök neden analizi — servis headless sunucuda modal pencere açıyor

- **Neden:** Timeout'un sebebi tahmin edilmeden, IL seviyesinde kanıtlanmak
  istendi.
- **Ne yapıldı:** `EInvoiceAndEArchiveStatusControlService` kaynak kodda yok,
  `Dlls/InvoiceModule.dll` içinde. ildasm ile disassemble edilip incelendi.

  **Bulgu zinciri:**

  1. `Run?type=1` → `OnEArchiveInvoiceStatusCommand` → her satır için
     `EInvoiceAndEArchiveStatusControlService.Execute(...)`.
  2. Bu servis **7 ayrı yerde** `SysMng.ActWndMng.ShowMsg(...)` çağırıyor.
     İlki, `EInvoiceProviderFactory.GetInstance(...)` null dönünce:
     *"Web servis bağlantısı yapılamadı. Log kayıtlarını kontrol ediniz."*
     (IL'de UTF-16 bytearray olarak gömülü, decode edildi.)
  3. `DesktopWndMng.ShowMsg` (`LiveCore.Desktop.dll`) — tüm overload'lar aynı
     korumayı tekrarlıyor:
     ```csharp
     bool fromService = sysMng != null
                     && sysMng.getSession() != null
                     && sysMng.getSession().FromService;
     if (fromService) return 0;              // pencereyi atla
     else return ShowMsg(...);               // RootWindow uzerinde WPF modal
     ```
  4. `FromService` bayrağını yalnızca `SysMng.Login(..., bool fromService, ...)`
     set ediyor. `LoginToOtherCompany` set **etmiyor**; bizim kodumuz da
     etmiyor (`Instance_AfterLogin` sadece `Demo = false` yapıyor).
  5. Web API `Task.Run(() => StartWebApi())` ile arka plan thread'inde koşuyor
     (`ModaSimaModule.cs:76`). Koruma `SysMng.getSession()`'a — ambient
     oturuma — bakıyor, bizim `LoginToOtherCompany`'den aldığımız
     `LiveSession`'a değil.

- **Sonuç:** Koruma devreye girmiyor → ekranı olmayan LiveServer'da modal
  pencere açılıyor → kimse OK'e basmıyor → istek thread'i sonsuza kadar bloke
  → HTTP cevabı hiç yazılmıyor → zamanlayıcı 360 dk bekleyip timeout veriyor.
  Semptomla birebir uyuşuyor. Üstelik döngünün ilk satırında, ağ trafiği
  başlamadan oluyor.

- **Komutlar:**
  ```bash
  # Servisin IL'i
  ildasm.exe X:\GitHub\Sentez-Core\Dlls\InvoiceModule.dll /out=InvoiceModule.il /text=false
  grep -n "EInvoiceAndEArchiveStatusControlService" InvoiceModule.il   # class @ 391609
  sed -n '391609,394237p' InvoiceModule.il > svc.il
  grep -n "ActWndMng\|ShowMsg" svc.il                                  # 7 cagri

  # Pencere yoneticisi
  ildasm.exe X:\GitHub\Sentez-Core\Dlls\LiveCore.Desktop.dll /out=LiveCore.Desktop.il /text=false
  grep -n "implements.*IWndMng" LiveCore.Desktop.il                    # DesktopWndMng @ 340233
  # -> tum ShowMsg overload'lari get_FromService kontrolu yapiyor
  ```

### 2. İkincil bulgular (asıl neden değil ama gerçek)

- **İstek bazlı log yoktu.** `WriteApiLog` sadece açılışta yazıyordu; elimdeki
  en yeni dosya `modasima_2026-08-29.log` ve o da dev çıktısı. Nerede
  takıldığını gösteren hiçbir iz yok.
- **`GetList`'te satır sınırı yok**, `startDate` varsayılanı sabit `20260701`
  olduğu için pencere her gün genişliyor. Pencere sorunu hiç olmasa bile N
  satır × entegratör gidiş-dönüşü seri şekilde saatler sürebilir.
- **Her satır için tam yıl tarih aralığı** geçiliyor (`01.01`–`31.12`); satır
  başına maliyet sabit ve yüksek.
- Satır başına timeout, `CancellationToken`, paralellik yok.
- `LoginToOtherCompany` içinde global `Monitor.Enter/Exit` var; bir istek
  kilitli bölgede asılırsa sonraki istekler de birikir.

### 3. İzleme eklendi (düzeltme değil)

- **Karar:** Kullanıcı önce sadece log istedi — kodu değiştirmeden bir tur daha
  çalıştırıp asılma noktasını kanıtlamak için. Davranış bilerek değiştirilmedi:
  timeout, satır sınırı, `FromService` ataması **eklenmedi**.
- **Ne yapıldı:**
  - `ModaSimaModule.WriteApiLog` `internal static` yapıldı, thread id ve
    `lock` eklendi; controller'lar da aynı dosyaya yazabiliyor.
  - `LogEArchive` artık **iki hedefe** yazıyor: `SysMng.DefaultLogger` (try/catch
    ile sarılı) + dosya. Gerekçe: DefaultLogger'ın kendisi bu thread'de
    çalışmıyor olabilir, o zaman tek iz kaynağı kaybolurdu.
  - Durum sorgulama ve oluşturma döngülerinde her kayıt için
    **"başladı" / "döndü" çifti + süre**. Eşleşmeyen bir "başladı" satırı
    asılmanın tam yerini gösterir — teşhisin can alıcı noktası bu.
  - Servis çağrısındaki istisna loglanıp **yeniden fırlatılıyor** (yutulmuyor),
    böylece davranış aynı kalıyor.
  - `LoginToOtherCompany` süresi ölçülüyor.
  - `GetList`'te sorgu metni, oturum null mı, satır sayısı ve süre loglanıyor.
  - **`DescribeWndGuard()`**: `getSession() != null && FromService` kosulunun o
    anki değerini her tur başında yazıyor. Hipotezi doğrudan doğrulayan
    diagnostik bu — log `AmbientSession=NULL` veya `FromService=False` derse
    `ShowMsg` yolu canlı demektir ve teşhis kanıtlanmış olur.

- **Dokunulan dosyalar:** `Controllers/EArsivController.cs`, `ModaSimaModule.cs`

- **Sonuç / doğrulama:** Build EXIT=0. Uç noktalar canlı çalıştırılmadı —
  bir sonraki job turunun logu beklenecek.

- **Commit:** `a08b265` — EArsiv: asilma noktasini tespit icin izleme eklendi

## Kararlar

- Teşhis tahminle değil IL disassembly ile kanıtlandı; "muhtemelen yavaştır"
  açıklaması reddedildi çünkü semptom "yavaş" değil "hiç cevap yok".
- Düzeltme tek turda yapılmadı: önce iz, sonra kanıt, sonra düzeltme.
- Log iki hedefe yazılıyor ki loglama mekanizmasının kendisi arızalanırsa
  teşhis kör kalmasın.
- İstisna loglanıp yeniden fırlatılıyor — iz eklemek davranışı değiştirmemeli.

## Açık kalanlar / sonraki adım

- **Bir sonraki job turunun logunu oku:** sunucudaki modül DLL klasöründe
  `modasima_<tarih>.log`. Aranacak iki şey:
  1. `DescribeWndGuard` çıktısı — `FromService=False` ya da
     `AmbientSession=NULL` ise teşhis kesinleşir.
  2. "Servis cagrisi basladi" satırının ardından aynı RecId için
     "Servis dondu" satırının **olmaması** — asılma noktası orasıdır.
- Teşhis doğrulanırsa asıl düzeltme: servis çağrılmadan önce oturumu headless
  işaretlemek (`FromService = true`) ve `SysMng.getSession()`'ın o oturumu
  görmesini sağlamak.
- Ardından: satır başına timeout, `GetList`'e `maxRows` sınırı, `startDate`'in
  sabit `20260701` yerine kayan pencere olması.
- `EInvoiceProviderFactory.GetInstance(...)` neden null dönüyor, ayrıca
  bakılmalı — pencere sorunu çözülse bile durum sorgulama çalışmaz.
  Entegratör parametreleri (`IntegratorUserName`, `EDMSecretKey`,
  `EInvoiceIntegrator`) ilgili şirket için dolu mu kontrol edilecek.
