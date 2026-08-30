# localserver (TechtsioService) — 2026-08-31

## Bağlam
2026-08-29 sabahına ait cihaz logu incelendi (F0940 / MAC d8:bf:c0:03:d6:a2,
personel 2828 NİMET KESER). Üç şikayet vardı:
1. SP'ye giden `@CurrentQuantity` 0 → 9 → 521 diye sıçramış.
2. Aynı kart peş peşe okutulunca tekrar işleniyor; sadece OK dönmesi lazım.
3. `## İLK ÇALIŞMA SIFIRLAMASI YAPILDI ##` her pakette tekrar ederek döngüye girmiş.

Kritik keşif: sahada koşan binary'nin kodu repoda **yok**. `Y:\defactor\TechtsioService`
JetBrains dotPeek ile `Y:\TechtsioService.exe` içinden decompile edilmiş çıktı ve
repodan **daha ileri** bir sürüm. Log'daki `SP calistirilamadi - kayit yazilamadi`
mesajı repoda hiç geçmiyor, sadece decompile çıktısında var
(`Bussiness/CurrentDeviceListManager.cs:963`). Yani disk uçmadan önceki
düzeltmelerin bir kısmı yalnızca decompile çıktısında duruyor.

## Yapılanlar

### 1. İLK ÇALIŞMA SIFIRLAMASI sonsuz döngüsü — kök neden
- **Neden:** Log'da 07:58:39, 07:58:49, 07:59:59, 08:00:00'da art arda sıfırlama.
- **Kök neden zinciri:**
  - `Uts23Service.RunBarcode` girişte `MainProcess.AddLockDevices(deviceId)` ile
    cihazın kilidini **kendisi** alıyor.
  - Aynı metodun ilk-çalışma dalında `SetQuantity(currentDevice, 0)` çağrılıyordu
    (ignore parametresi verilmeden, yani `ignore=false`).
  - `CurrentDeviceListManager.RunSp` içindeki
    `if (ignore || !MainProcess.Instance.HasLockDevices(device.DeviceId.ToString()))`
    koşulu → kilit bizde olduğu için **SP hiç çalışmıyor**.
  - `@ReturnVal` OUTPUT parametresi hiç dolmadığından `DBNull/null` kalıyor →
    `RunSp` `-20` dönüyor ve `SP calistirilamadi - kayit yazilamadi` logluyor.
  - `-20`/`-10` dalında `currentDevice.LastReciveDate = DateTime.Now.AddDays(-2)`
    yapılıp DB'ye yazılıyor (bilinçli bir "tekrar dene" mekanizması).
  - `WifiServer` her pakette `LastReciveDate < currentShift.StartTime` gördüğü için
    `sifirla()` çağırıyor → döngü. SP kalıcı olarak başarısız olduğu sürece kapanmıyor.
  - Log'da döngü 08:00:00.490'da kendiliğinden bitti çünkü o paket
    "DAHA ONCE OKUTULMUS" dalına düşüp geri tarihleme koduna hiç ulaşmadı.
- **Ne yapıldı:**
  - `SetQuantity(currentDevice, 0, ignore: true)` — aynı metottaki diğer tüm
    `SetQuantity` çağrıları zaten `true` geçiyordu, bu bir atlama idi.
  - `WifiServer.sifirla()` artık `LastReciveDate = DateTime.Now` işaretlemesini
    metodun **başında** yapıyor (eskiden en sondaydı). Sıfırlama ~500 ms sürdüğü ve
    40+ worker thread paket tükettiği için bu süre içinde gelen paketler tekrar
    `sifirla()` başlatıyordu. Kullanıcının önerisi buydu; ikinci savunma hattı.
- **Dokunulan dosyalar:** `Server/Providers/UTS23/Uts23Service.cs`, `Server/WifiServer.cs`

### 2. Sayaç sıçraması 0 → 9 → 521
- **Neden:** 08:01:36'da cihaz `0521;0001;0600;01;0054;` gönderdi; tek pakette
  iki SP çağrısı (`@CurrentQuantity 9`, sonra `521`) oluştu, `HesaplananHedef -10`.
- **Bulgular:**
  - **9 / 521 ikilisi normal.** `CurrentDeviceListManager.SetQuantity`
    `GetEmployeeStatusFunction`'a bakıp seri kartın kalan kapasitesini (`freeSeri`)
    aşan kısmı `main` + `sub` diye ikiye bölüyor ve SP'yi iki kez çağırıyor.
    `main = EndQuantity + freeSeri = 9`, `sub = 521`. Tasarım gereği.
  - **521 hayali.** Cihaz sıfırlama paketini kaçırdığında eski sayacını taşımaya
    devam ediyor; sunucu ise 0'da kalıyor.
  - Eski koruma koşulu tam bu senaryoda kapalı kalıyordu:
    `if (quantity != null && quantity.Counter > 10 && quantity.Counter > currentQuantity)`
    → sıfırlama sonrası sunucu 0 olduğu için `Counter > 10` tutmuyor, düzeltme
    hiç çalışmıyor, cihazın 521'i olduğu gibi SP'ye yazılıyor.
- **Ne yapıldı:** koşul çift yönlü fark/eşik kontrolüne çevrildi:
  `fark = quantity.Counter - currentQuantity`, `Math.Abs(fark) >= 30` ise sunucu
  değeri (+1) cihaza basılıyor ve detaylı loglanıyor; `>= 5` farklar "eşik altı"
  olarak sadece loglanıyor. (Bu mantığın bir versiyonu decompile çıktısında da
  vardı — `Uts23Service.cs:925` — ama oradaki `Counter > 10` guard'ı hâlâ hatalıydı.)
- **Dokunulan dosyalar:** `Server/Providers/UTS23/Uts23Service.cs`

### 3. Mükerrer kart okutma
- **Neden:** Log'da 08:00:00.019 / .490 / 08:00:01.009 → aynı barkod 1 saniyede
  3 kez işlendi. Cihaz ACK'i geç aldığı için UDP paketini retransmit ediyor.
- **Ne yapıldı:**
  - `CurrentDevices`'a `LastBarcode` / `LastBarcodeDate` eklendi.
  - `RunBarcode` içinde aynı cihaz + aynı barkod 5 sn içinde tekrar gelirse
    işleme alınmıyor, ekran korunarak `SendOk(..., sendDisplayOnly: true)` dönülüyor.
  - Ek hata: `RunBarcode`'un `finally` bloğu kilidi **koşulsuz** bırakıyordu. Erken
    dönen "Devam eden kayit oldugu icin isleme alinmadi" yolu, devam eden başka bir
    işlemin kilidini açıyordu — yani mükerrer koruması kendini bozuyordu.
    `lockTaken` bayrağı eklendi; kilidi sadece alan bırakıyor.
- **Dokunulan dosyalar:** `Server/Model/CurrentDevices.cs`,
  `Server/Providers/UTS23/Uts23Service.cs`

### 4. Yanlış alarm — barkod/kod uyuşmazlığı
`FDFBF8FD` okutulup `barcodeResult` içinde `"Code":"DA4838B6"` dönmesi hata değil.
`GetDatas.SeriCache` sorgusu `Select top 1 isnull(ParentId,Id) from Cards ...` ile
alt kartı parent karta çözüyor.

## Komutlar
```bash
dotnet build TechtsioService/TechtsioService.csproj   # 0 Error, 68 Warning (hepsi mevcut)
git add TechtsioService/TechtsioService/Server/Providers/UTS23/Uts23Service.cs \
        TechtsioService/TechtsioService/Server/WifiServer.cs \
        TechtsioService/TechtsioService/Server/Model/CurrentDevices.cs
git commit -m "Sayac sicramasi, mukerrer kart okutma ve ILK CALISMA dongusu duzeltmeleri"
git push origin FiredEric
```

- **Sonuç / doğrulama:** Build 0 hata. Saha doğrulaması yapılmadı — düzeltmeler
  cihazla test edilmedi.
- **Commit:** `4cd4e5f` — Sayac sicramasi, mukerrer kart okutma ve ILK CALISMA dongusu duzeltmeleri

## Kararlar
- Kilit çakışması `RunSp`'de değil çağrı yerinde çözüldü (`ignore: true`).
  `RunSp`'nin kilit kontrolünü tamamen kaldırmak, kilidin başka amaçlı kullanımlarını
  bozma riski taşıyordu.
- Decompile çıktısındaki `-20` geri-tarihleme dalı repoya **taşınmadı**; asıl döngü
  sebebi oydu. Repo zaten sadece `-10`'da geri tarihliyor.
- Mükerrer penceresi 5 sn, sayaç farkı eşiği 30 — ikisi de `Uts23Service` içinde
  `const` olarak duruyor, sahada ayarlanabilir.

## Açık kalanlar / sonraki adım
- **En önemlisi:** `Y:\defactor\TechtsioService` (decompile) repodan ileride.
  Repoda olmayan dosyalar/mantık var: `Server/DeviceConnections.cs`, `Server/Entity.cs`,
  `Server/Model/CurrentDevicesData.cs`, `Server/Model/IdDetailCache.cs`,
  `Server/Providers/IDeviceProcess.cs`, `Setting/Device.cs`, `Setting/LockDevice.cs`,
  `Bussiness/SenderModel.cs`. Ayrıca `RunCounter` içindeki `-20 → SUNUCU HATASI /
  KAYIT YAZILAMADI` ekran mesajı ve InOut loglaması repoda yok. Dosya dosya farkın
  çıkarılıp repoya geri taşınması gerekiyor.
- `SetTransectionFromDevice` SP'sinin aynı parametrelerle 100 ms arayla farklı
  `SeriIslenenAdet` döndürmesi (13/13 → 0/0 → 13/13) incelenmedi.
- Düzeltmeler sahada cihazla doğrulanmalı.

---

# İkinci tur — repo ↔ decompile farkının çıkarılması

## 5. DÜZELTME: "repoda eksik dosyalar" iddiası yanlıştı
İlk turda eksik diye listelenen `DeviceConnections.cs`, `Entity.cs`,
`CurrentDevicesData.cs`, `IdDetailCache.cs`, `IDeviceProcess.cs`, `Device.cs`,
`LockDevice.cs`, `SenderModel.cs` **eksik değil.** dotPeek her tipi ayrı dosyaya
yazıyor; bu tiplerin hepsi repoda başka dosyaların içinde tanımlı
(ör. `Entity` → `WifiServer.cs:719`). Aynı şekilde `checksum` repoda local
function; `SendDisplay` / `GetPureData` / `SendOk(IPEndPoint...)` ise `Extension`
sınıfında. CRC kontrolü, `YS:` PIC hata kodları ve `IsInFlight` ingress dedup'ı da
repoda zaten var.

Karşılaştırma yöntemi: her dosya için metot imzası listeleri ve 18+ karakterlik
string literal kümeleri `comm` ile diff'lendi. Decompiler artefaktları
(`str2`, `num5`, `op_Equality`, `(object)` cast'leri) filtrelendi.

**Gerçekten eksik olup taşınan davranışlar:**
1. `RunSp` DBNull/null ReturnValue durumunda `-10` yerine `-20` dönüyor.
2. `RunCounter` için `-20` dalı (SUNUCU HATASI / KAYIT YAZILAMADI).
3. `RunCounter` InOut dalında cihaza yanıt dönülmesi.
4. `CurrentDeviceListManager.SetIpAddress` + IP değişikliğinin işlenmesi.
5. `SendOk` ve `RunCounter` default dalında alan bazlı gönderim.

**Repoya bilerek TAŞINMAYAN:** Y'deki `case -20: case -10:` geri-tarihleme dalı.
Sonsuz `İLK ÇALIŞMA` döngüsünün kaynağı oydu.

## 6. `-20` ayrı kod + sistemdeki değerin cihaza basılması
- **Neden:** `RunSp`, SP hiç çalışmadığında `-10` dönüyordu. `-10` SP'nin kendi
  döndürdüğü "ILLEGAL OKUTMA" kodu; iki durum ayırt edilemiyor, cihaza yanlış
  mesaj basılıyordu. Ayrıca kayıt yazılamadığında cihaza sadece hata basmak
  yetmiyor — cihaz kendi (yanlış) sayacıyla devam ediyor.
- **Ne yapıldı:**
  - `RunSp` artık `-20` dönüyor (`CurrentDeviceListManager.cs`).
  - `RunCounter` `-20` dalı: cihazın sayacı reddediliyor, sistemdeki son geçerli
    değer (`device.CurrentQuantity`) hedefle birlikte cihaza geri basılıyor,
    ekranda SUNUCU HATASI / KAYIT YAZILAMADI.
  - `RunBarcode` ilk çalışma `-20` dalı: aynı şekilde sunucu sayacı basılıyor,
    **LastReciveDate geriye atılmıyor.**
- **Ek koruma:** `GetEmployeeCurrentQuantity` hata durumunda `Counter = -1`
  dönüyor. Sayaç düzeltme bloğundan `Counter > 10` guard'ı kaldırıldığı için bu
  değer sızabiliyordu; `Counter >= 0` kontrolü eklendi. Aksi halde geçici bir SQL
  hatasında cihaz sayacı sıfırlanacaktı.
- **Commit:** `92e6552`

## 7. Alan bazlı gönderim (hedef / standart zaman / makas sayısı)
- **Neden:** Kullanıcı isteği — "hangisi farklıysa farklılıkları göndereceğiz".
  Decompile çıktısında vardı, repoda yoktu.
- **Ne yapıldı:** `SendOk` ve `RunCounter` default dalı tek bir "değişti" bayrağı
  kullanıp üç alanı birlikte basıyordu. Artık her alan tek tek karşılaştırılıp
  sadece farklı olan gönderiliyor; diğerleri pakette `????` olarak gidiyor ve
  cihaz o alanlara dokunmuyor.
- `RunCounter`'da hedef karşılaştırması cihazın bildirdiği hedefi de dikkate
  alıyor: `|cihazTarget - ortP| > 5 || |eskiHesaplananHedef - yeni| > 5`.
- **Yan düzeltme:** `SendOk`'un "Değişiklik Olmadığından Veri Gönderilmedi" logu
  `t!.Target` kullanıyordu → istek çözülemediğinde NullReferenceException.
  `t?.Target` yapıldı. `RunCounter`'daki `device.Order.Code` için de null guard.
- **Commit:** `29ec598`

## 8. IsInFlight neden mükerrer okutmayı engellemedi
`WorkerLoopAsync`'in `finally` bloğu `_inFlight.TryRemove(packet.Data)` yapıyor.
Yani kayıt sadece **işlenirken** tutuluyor (adı üstünde "in flight"); işlem bitince
(~100-400 ms) aynı paketin retransmit'i yeni paket sayılıyor. Log'daki
08:00:00.019 / .490 / 08:00:01.009 tam bu yüzden üç kez işlendi. Ingress dedup'ı
eş zamanlılık için; tekrar okutma için `RunBarcode` seviyesindeki 5 sn'lik
`LastBarcode` kontrolü eklendi (madde 3).

## Açık kalanlar (güncel)
- Repo ↔ decompile farkı çıkarıldı; bilinen tek fark bilinçli (madde 5 sonu).
- `SetTransectionFromDevice` SP'sinin aynı parametrelerle 100 ms arayla farklı
  `SeriIslenenAdet` döndürmesi (13/13 → 0/0 → 13/13) hâlâ incelenmedi.
- Hiçbir düzeltme sahada cihazla doğrulanmadı; sadece `dotnet build` (0 hata).
