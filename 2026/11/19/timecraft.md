# timecraft — 2026-11-19

## Bağlam
Etüt sahasından 4 geliştirme talebi geldi (operasyon listesi + Sentez eşleşmesi, kimyasal zorunluluğu,
görselde cm zorunluluğu, kronometre duraklatma). Kullanıcı ek not: "yıkama operasyonlarının hepsi gelmeli, 5000 ile 6000 arası".

## Yapılanlar

### 1. İşlem listesi = Sentez Erp_Process 5000–5999 (canlı)
- **Neden:** Liste UZM_ETUT_Operation'daki 16 sürme koduydu. Listede olmayanlar (ÖN TUTTURMA, YIPRATMA 2,
  FULL ESKİTME, kılçık çakmalar…) elle yazılıyor, `OperationCode` NULL kalıyor, Sentez'e SMV yazılamıyordu.
  Canlıda doğrulandı: NULL kodlu ~30 etüt var; hepsinin karşılığı Sentez'de 5xxx aralığında mevcut
  (ÖN TUTTURMA = 5100-1, YIPRATMA 2 = 5157, FULL ESKİTME = 5173).
- **Ne yapıldı:** `Etut/Services/EtutOperationCatalog.cs`:
  - Her istekte Sentez'den okur → Sentez'de yeni kart açılınca liste kendiliğinden güncel (senkron işi yok).
  - SQL: `ISNULL(IsDeleted,0)=0 AND LTRIM(ProcessCode) LIKE '5[0-9][0-9][0-9]%' AND (LEN=4 OR 5. karakter rakam değil)`.
    InUse'a göre **filtrelenmez** (5206-1 ÖN SÜRME bile InUse=0, etütlerde 38 kez kullanılmış).
  - `IsPlaceholder`: adı boş, `---` içeren grup başlıkları (5201-00 "_PANTALON GRUBU_"), "5200 SÜRME OPERASYONU SEÇ" atlanır.
  - `Merge`: Sentez adı esas; UZM_ETUT_Operation'dan SuggestedMachineId eklenir; Sentez'de olmayan yerel kod korunur;
    doğal sıra (5206-1, 5206-2, 5206-10). Sentez okunamazsa yerel tabloya düşer.
  - API `GET api/etut/operations` ve web `EtutController.OperationsAsync` bu servisi kullanır (DI: EtutSetup).
  - SMV'ye gönderimde **İşlem kodu zorunlu** oldu (sunucu `MissingForSubmit`, tablet `SubmitRules`).
- **Canlı veri:** 420 satır, ~9 başlık/boş → ~410 seçilebilir. 5 haneli yıkama kodları (50100 REÇİNE MAKİNEDE,
  51116 REAKTİF PARÇABOYA 2, 51117 SODA DURULAMA) aralık dışı kaldı — kullanıcıya soruldu.

### 2. Kimyasal yalnız sürmede zorunlu
- `EtutRules.RequiresChemical(desc)`: tr-TR büyük harfte "SÜRME" veya "SURME" geçiyorsa zorunlu.
  Tablet `SubmitRules.requiresChemical` aynı kural; web etiketi `*` işaretini JS ile açıklamaya göre değiştirir.
  Sprey/hipo/lazer/kılçık/tutturma/düğme/overlok → zorunlu değil.

### 3. Görselde cm isteğe bağlı
- Sunucu `ValidateAnnotations`: line/curve için iki nokta şart, cm null olabilir; girildiyse > 0.
- Tablet `MediaTabs.kt`: cm diyaloğu boş kabul eder (`parseOptionalCm`), etiket `measureLabel` → cm yoksa yalnız "3)".
  Web detay ekranı da cm'siz etiketi "n)" / "n) işaret" gösterir.

### 4. Kronometre Duraklat / Devam
- `domain/SwClock.kt` (saf): startedAt + accumMs + paused; elapsed = accum + (now − start).
- `EditorState.swStart` → `sw: SwClock`. VM: pause/resume/updateClock; Bitir toplam süreyi ekler.
- `SettingsStore`: SW_ACCUM, SW_PAUSED eklendi; SW_START duraklatmada silinir. Duraklatılmış ölçüm
  cihaz yeniden başlasa da geri yüklenir (yalnız birikmiş süre taşır); çalışan dilim reboot'ta yine iptal.
- Ölçüm sürerken (duraklatılmış dahil) manuel ekleme/düzeltme kapalı.

- **Dokunulan dosyalar:** `Etut/Services/EtutOperationCatalog.cs` (yeni), `Etut/Domain/EtutRules.cs`, `Etut/Services/EtutStudyService.cs`,
  `Etut/EtutSetup.cs`, `Etut/Api/EtutApiController.cs`, `Controllers/Etut/EtutController.cs`, `Views/Etut/Details.cshtml`,
  `android/.../domain/{SwClock,Workflow}.kt`, `android/.../data/SettingsStore.kt`, `android/.../ui/editor/{EditorScreen,EditorViewModel,MediaTabs}.kt`,
  testler: `tests/TimeCraft.Tests/{EtutOperationCatalogTests,EtutStudyServiceTests}.cs`, `android/.../test/.../{SwClockTest,DomainTest}.kt`
- **Komutlar:**
  ```bash
  dotnet test tests/TimeCraft.Tests                      # 59/59
  export JAVA_HOME="/c/Program Files/Android/openjdk/jdk-21.0.8"
  cd android && ./gradlew --no-daemon :app:testDebugUnitTest :app:assembleDebug
  # canlı salt okunur kontrol: sqlcmd -S 192.168.1.22 -d SentezLive ... (Erp_Process 5xxx, UZM_ETUT_Study kod dağılımı)
  ```
- **Sonuç / doğrulama:** sunucu 59/59, tablet birim testleri geçti, debug APK derlendi. Katalog SQL'i canlıda çalıştı (420 satır).
  Emülatörde uçtan uca denenmedi.
- **Commit:** `079a3c5` — Etut: islem listesi Sentez 5000-5999 canli, kimyasal yalniz surmede, cm istege bagli, kronometre duraklatma

## Kararlar
- Liste önbelleksiz canlı okunur (420 satır, ucuz) → "eşzamanlı güncelleme" ayrı senkron işi gerektirmez.
- InUse filtrelenmez; yalnız IsDeleted ve başlık satırları elenir.
- Aralık katı 5000–5999 (6000 hariç, 5 haneli kodlar hariç).

## Açık kalanlar / sonraki adım
- Kodu NULL kalmış eski etütlere geriye dönük kod atama (açıklama = Sentez adı tam eşleşenler) — onay bekliyor, DB'ye yazılmadı.
- 50100/51116/51117 gibi 5 haneli yıkama kodları listeye girsin mi — kullanıcıya soruldu.
- IIS paketi + APK sahaya kurulacak; emülatörde duraklat/cm'siz işaret uçtan uca denenmeli.
