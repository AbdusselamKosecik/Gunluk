# sentezservis — 2026-10-19

## Bağlam
Sabah giriş/çıkış maili (PDKS, `pdks-giris-cikis` işi) ve ekindeki devam Excel'i için kullanıcının istekleri:
- ZKBioTime'da elle müdahale edilen kayıt listede ve Excel'de görünsün.
- Girişi olmayan gün ile çıkışı olmayan gün ayrı ayrı gösterilsin. Önceden ikisi de aynı sarı "OK" idi.
- Önerisi: hücre çapraz bölünsün. Yeşil/kırmızı = giriş var, çıkış yok. Yeşil/sarı = giriş var, çıkış elle.

## Yapılanlar

### 1. Elle kaydın ZKBioTime'daki izi
- **Bulgu:**
  - `iclock_transaction.source`: cihaz okutması = 1. Elle eklenen (onaylı manuel kayıt) = 2 ve aynı tabloya düşüyor.
  - Elle kayıtların asıl listesi `att_manuallog` tablosunda (`workflow_workflowinstance` üzerinden personel ve onay durumu).
  - `source = 2` kayıtları: 114 adet, 01.12.2024–06.10.2025 arası. Son 60 günde hiç yok.
  - `base_adminlog` son 60 günde 706 Modify kaydı içeriyor, hepsi `personnel.employee`. Okutma kaydı değiştirilmemiş.
- **Karar:** cihaz dışı kayıt (`source <> 1`) "elle" sayılır. Giriş ve çıkış için ayrı ayrı işaretlenir.
- **Komut (salt okunur):** scratch `sorgu.ps1`, `USE zkbiotime; ...`. Sunucu `MODFEX_SUNUCU=tcp:100.119.104.122,1433`.

### 2. Kod
- `src/SentezServis.Core/Pdks/PdksDeposu.cs`:
  - `GunlukAsync` dönüşüne `CikisElle` (önceki iş günü) ve `GirisElle` (bugün) eklendi.
  - `DevamAsync` dönüşüne `GirisElle` ve `CikisElle` eklendi. Değer: `CAST(MAX(CASE WHEN punch_state='0'/'1' AND source<>1 ...) AS bit)`.
  - Kayıtlara yeni alanlar sona eklendi. Dapper kurucuyu sırayla eşlediği için SELECT sırası kurucuyla aynı tutuldu.
- `PdksDevamAnalizi.cs`:
  - Yeni `enum PdksOkutma { Var, Yok, Elle }`.
  - `PdksHucre` yeni alanlar: `Giris`, `Cikis`, `GirisZamani`, `CikisZamani` ve `Capraz` (gelinmiş ama giriş/çıkış Var değil).
  - `PdksDevamSatiri` yeni sayaçlar: `GirisYok`, `CikisYok`, `Elle`.
  - Elle girilen saatle de süre (+3h/-3h) hesaplanır.
- `PdksDevamExcel.cs`:
  - **Çapraz hücre:** ClosedXML gradient dolgu yazamıyor. Bu yüzden:
    1. Hücreler giriş/çıkış birleşimine özgü bir işaret rengiyle boyanır (`#FE{giriş:X2}{çıkış:X2}`).
    2. Kayıttan sonra `CaprazDolgulariYaz`, OpenXML SDK ile stil tablosundaki bu dolguları bulur.
    3. Bulunan her dolgu `gradientFill degree=45` ile değiştirilir. Duraklar: 0/0.49 giriş rengi, 0.51/1 çıkış rengi.
    4. Hücreye beyaz ince çapraz çizgi (DiagonalUp) eklenir.
  - Renkler: yeşil `C6E0B4` var, kırmızı `F4B183` yok, sarı `FFD966` elle.
  - Attendance sayfasına "No in", "No out", "Manual" sütunları eklendi (NON'dan sonra).
  - Açıklama satırına çapraz örnekler eklendi.
  - **Yeni sayfa "Missing punches":** kişi-gün bazında Date, Department, Name, Local name, In, Out. Değerler: saat, "missing" ya da "HH:mm (manual)". En yeni gün en üstte, autofilter açık.
- `Bildirim/BildirimServisi.cs`:
  - Elle girilen saat hücresi `td.s.elle` (sarı) ve `<span class="m">manual</span>` ile işaretlenir.
  - Özete 6. satır eklendi: "N manual entries (elle girilenler)".
- **Testler:**
  - `PdksDevamTestleri`: giriş/çıkış var/yok/elle teorisi; elle çıkışta süre; NON/boş gün bölünmez.
  - `Excel_giris_cikis_yok_ve_elle_ayri_gosterilir`: sayaçlar, "Missing punches" satırları, 3 gradientFill, işaret rengi kalmadı, `OpenXmlValidator` hatasız.
  - `PdksGunlukTestleri`: mailde elle işaretli hücre; özet 6 satır.
- **Komutlar:**
  ```bash
  dotnet test tests/SentezServis.Core.Tests     # 285 geçti, 11 atlandı (DB)
  ```
- **Canlı sorgu denemesi:** devam sorgusu `zkbiotime` üzerinde çalıştı. 597 numaralı personelin 2025 kayıtlarında GirisElle=True geldi.
- **Commit:** `2ca0022` — PDKS: elle girilen giris/cikis, girisi ve cikisi olmayan gunler ayri ayri

### 3. Paket
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File deploy\yayinla.ps1
Compress-Archive -Path yayin\* -DestinationPath yayin-pdks-2026-10-19.zip -Force
```
- **Çıktı:** `yayin-pdks-2026-10-19.zip` (73 MB), arayuzTarihi 2026-10-19 16:28. İçinde appsettings.json yok.
- **Kurulum durumu:** sunucuya henüz kurulmadı.

## Kararlar
- "Elle" = `source <> 1`. Mobil uygulama ya da web'den okutma gelirse o da elle sayılır (şu an veride yok).
- Çapraz yalnız sorunlu günde kullanılır. Normal günler eski renklerinde kalır (OK yeşil, +3h mavi, -3h turuncu).
- Gradient ortasında %2 geçiş var. Aynı konumda iki durak kullanmadım, bazı okuyucular reddedebilir.

## Açık kalanlar / sonraki adım
- Paketin sunucuya kurulması.
- Bu PC'de Excel yok, çapraz hücre burada görsel olarak açılıp kontrol edilemedi. İlk mailin ekinde kontrol edilmeli.
- Son 45 günde elle kayıt yok. Sarı, biri ZKBioTime'dan elle kayıt girince görünecek.
