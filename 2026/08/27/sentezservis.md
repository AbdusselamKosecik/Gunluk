# sentezservis — 2026-08-27

## Bağlam

Gün "memorydeki yapılanlara bakıp kodda ne eksik" sorusuyla başladı. İki şey ortaya çıktı:

1. Bu proje için **hiç memory kaydı ve hiç günlük yok** — `~/.claude/.../memory/` boş,
   `Gunluk/2026/08/` altında `sentezservis.md` yoktu. Bu dosya ilkidir.
2. Sunucuda çalışan sürümde olup depoda **hiç bulunmayan** bir modül var: CRS e-fatura
   karşılaştırması. Kaynağı yalnızca derlenmiş DLL'deydi.

Günün asıl işi bu modülü kurtarmak oldu.

## Yapılanlar

### 1. Plan ↔ kod boşluk analizi

- **Neden:** `yonetim/backlog.md` ve `sprint-01.md` durum tabloları gerçeği yansıtmıyor
  (backlog "Sprintte", alt görevler "Bekliyor" derken kodda hepsi bitmiş). Neyin gerçekten
  eksik olduğu ancak koda bakılarak anlaşılıyor.
- **Ne yapıldı:** Backlog maddeleri tek tek kaynakta arandı.
- **Sonuç — Sprint-2'den kodda hiç olmayanlar:**

| # | Ne | Durum |
|---|---|---|
| S2-01 | Telegram | `BildirimKanali.Telegram` sabiti ve `bildirim_tekrar_engeli` dedup altyapısı **var**; `BildirimDagiticiServisi.GonderAsync` switch'inde yalnız `Eposta` kolu var. Telegram kaydı kuyruğa düşerse `NotSupportedException` → sonsuz retry. Tek sınıf eksik. |
| S2-02 | "Hiç çalışmadı" alarmı | Yok. `ZamanlayiciServisi.cs:79`'da sadece "bu S2-02'nin işidir" yorumu. |
| S2-03 | "Uzun sürüyor" uyarısı | **Yarım ve yanıltıcı.** `calistirmalar.uzun_suruyor` kolonu şemada var; `Sorgular.cs`, `Modeller.cs`, API ve arayüz **okuyor**, hiçbir yer **yazmıyor**. Ekranda hep `false`. |
| S2-04 | Arama + tarih aralığı | `GET /api/calistirmalar` yalnız `Is`, `sayfa`, `boyut` alıyor. İndeksler (`IX_calistirmalar_durum`) hazır, sorgu yazılmamış. |
| S2-05 | 360px mobil | `theme.css`'te tek `@media` (480px, satır 841). |
| S2-06 | `/healthz` + `/readyz` | Yok. `SaglikUclari.cs` bambaşka şey (donanım ölçümü, üstelik `GirisIster()` korumalı). Kontratta tanımlı, kodda yok. Sertifika süre bildirimi de yok. |
| S2-07 | Log temizliği | **En kritik.** `saklama_politikasi`'nda 18 satır var ama `calistirma_loglari`, `calistirmalar`, `calistirma_adimlari` **hiçbirinde yok** — en yüksek hacimli tablo hiç temizlenmiyor, sınırsız büyüyor. %80 tavan bildirimi de yok. |

- **Sprint-1'den kalanlar:** çökme sonrası devam yok (`sahip` hiç yazılmıyor, `kalp_atisi`
  yazılıyor ama hiç okunmuyor; açılışta `CalistirmaDeposu.cs:129` `calisiyor`/`sirada`
  kayıtları toptan `durduruldu` yapıyor — checkpoint duruyor ama kendiliğinden devam
  ettirilmiyor); iki katmanlı timeout tek katman (`IsCalistirici.cs:202`); `denetim_kayitlari`
  DB düzeyinde append-only değil (trigger/DENY/temporal yok).
- **Backlog ile çelişki:** S2-07 "temizlik audit'e dokunmaz" der; `SaklamaJob`
  `denetim_kayitlari`'nı 1825 günde siliyor (`008_saklama_uygulamasi.sql:62`). İkisi de
  savunulabilir, biri yanlış — kurulun karara bağlaması gerekir.
- **Öneri sırası:** S2-07 → S2-01 → S2-03 → S2-06 → S2-04 → S2-02 → S2-05.

### 2. Sunucudaki derlenmiş sürüm ile depo karşılaştırması

- **Neden:** Sunucuya yayım tek yönlü (`deploy/uzaktan-yayimla.ps1`, geliştirme makinesi →
  sunucu); sunucuda kaynak yok, yalnız `yayin\` çıktısı. "Sunucuda olup depoda olmayan ne var"
  sorusu ancak decompile ile cevaplanır. Kullanıcı DLL'leri `Y:\defactor\` altına çıkardı.
- **Ne yapıldı:** Dosya listesi karşılaştırması yanıltıcı (decompiler her tipi ayrı dosyaya
  böler, depoda `*Modelleri.cs` içinde toplu duruyorlar). Bu yüzden **tip adı** düzeyinde
  karşılaştırıldı:

  ```bash
  tipler() { grep -rhoE '\b(public|internal)\s+(sealed\s+|static\s+|abstract\s+|partial\s+|readonly\s+)*(class|record|struct|enum|interface)\s+[A-Za-z_][A-Za-z0-9_]*' "$1" --include=*.cs \
    | grep -oE '[A-Za-z_][A-Za-z0-9_]*$' | sort -u; }
  comm -23 <(tipler Y:/defactor/SentezServis.Core) <(tipler src/SentezServis.Core)
  ```

- **Sonuç:**
  - **Toplayıcı: birebir aynı.**
  - **Host:** yalnız `FaturaUclari` eksik.
  - **Core:** yalnız Fatura modülü (13 tip) eksik.
  - `VarlikIceAktarici` yanlış pozitif çıktı — sebebi 3. maddedeki NUL baytı.
- **Build damgası:** `AssemblyInformationalVersion = 1.0.0+70d2bd3…` → sunucudaki sürüm
  **ilk commit'ten** derlenmiş. Sonraki commit `3159ada` zaten `src/`'ye dokunmamış
  (sadece `.gitignore`, zip'ler, `deploy/`, `docs/`, `Tema/`). Yani iki taraf aynı temelde;
  Fatura modülü **hiç commit edilmemiş**, `git log --all -- "*Fatura*"` boş.

### 3. Fatura modülünün kurtarılması

- **Neden:** ~1170 satırlık çalışan modülün tek kopyası sunucudaki DLL'di. Global kural
  ("HDD uçtu, tekrar uçabilir") tam olarak bu senaryo — decompile edilmeseydi kurtarılamazdı.
- **Ne yapıldı:** JetBrains çıktısı proje diline çevrildi. Temizlenenler: `op_Equality`,
  `(StringComparison) 5`, `(NumberStyles) 511`, `(SaveOptions) 1` gibi sayısal enum sabitleri,
  derleyici üretimi alan referansları (`<fabrika>P`, `k__BackingField`), açık `base..ctor()`
  çağrıları, elle açılmış try/finally dispose iskeletleri. Yerine: Türkçe XML belgeleme,
  primary constructor, `await using`, raw string SQL, `switch` ifadeleri.
- **Modülün işi:** CRS Soft entegrasyon servisinden (`connect.crssoft.com`) e-fatura çekip
  Sentez ERP'deki fatura başlıklarıyla kıyaslar. Amaç: **"CRS'te var, Sentez'e girilmemiş"**
  faturayı bulmak.
- **Dokunulan dosyalar:**
  - `src/SentezServis.Core/Fatura/FaturaModelleri.cs` (yeni, 228)
  - `src/SentezServis.Core/Fatura/CrsIstemcisi.cs` (yeni, 326)
  - `src/SentezServis.Core/Fatura/FaturaKarsilastirici.cs` (yeni, 261)
  - `src/SentezServis.Host/Api/FaturaUclari.cs` (yeni, 203)
  - `src/SentezServis.Core/Ayarlar.cs` — `Crs` özelliği
  - `src/SentezServis.Host/Program.cs` — `using`, DI (`CrsIstemcisi`, `FaturaKarsilastirici`),
    `FaturaUclariniEkle()`
  - `docs/api-kontrat.md` — modül bölümü (+105)
- **Uçlar:** `GET /api/fatura/sirketler` · `GET /api/fatura/karsilastir` (giriş yeterli) ·
  `GET /api/fatura/crs-dene` (**yönetici** — yanıtta CRS kullanıcı adı görünüyor).
- **Komutlar:**
  ```bash
  dotnet build src/SentezServis.Host/SentezServis.Host.csproj   # 0 uyarı, 0 hata
  dotnet test tests/SentezServis.Core.Tests/...                  # 213 geçti
  ```
- **Commit:** `3223486` — Fatura modulu decompile'dan kurtarildi + VarlikIceAktarici NUL bayti

### 4. `VarlikIceAktarici.cs` — ham NUL baytı

- **Neden:** Dosyada bir adet **ham 0x00 baytı** vardı (satır 219,
  `$"{girdi.Uretici}<NUL>{seri}"` — bileşik anahtar ayırıcısı, kaçış dizisi yerine baytın
  kendisi gömülmüş). Bu yüzden git/grep dosyayı **ikili** sayıyordu: `git diff`'te
  görünmüyor, `grep` atlıyor, kod incelemesine girmiyor. Tip karşılaştırmasında yanlış
  pozitif üretmesi de bu yüzdendi.
- **Ne yapıldı:** Bayt, iki karakterlik `\0` kaçışına çevrildi. Çalışma zamanında aynı bayt.
- **Dikkat — iki başarısız deneme:**
  - `perl -0777 -pi -e 's/\x00/\\0/g'` hiçbir şey değiştirmedi (Windows'ta metin kipi).
  - `tr '\000' '\001'` + `sed 's/\x01/\\0/g'` **ayırıcıyı tamamen sildi** — sed'de `\0`
    replacement içinde "tüm eşleşme" demektir. Fark edilip `git checkout --` ile geri alındı.
  - Çalışan yol PowerShell bayt düzeyi oldu:
    ```powershell
    $b = [IO.File]::ReadAllBytes($f)
    # 0x00 -> 0x5C 0x30
    [IO.File]::WriteAllBytes($f, $out.ToArray())
    ```
- **Sonuç:** `git diff --stat` → `1 file changed, 1 insertion(+), 1 deletion(-)`. Artık metin.

## Kararlar

- **Fatura kurtarma backlog'un önüne alındı.** S2-07/S2-01 vb. kaybolmuş değil, ne zaman
  istenirse yazılır; Fatura ise tek diske bağlıydı. Kaybolabilir iş, yapılacak işten önce gelir.
- **Sıralama karşılaştırıcısı yeniden yazıldı, kopyalanmadı.** Derlemede lambda olarak
  kaybolmuştu (`<>9__9_2`). Sınıfta duran `Oncelik()` yardımcısından çıkarıldı:
  `sentezdeYok > tutarFarkli > mukerrer > eslesti`, sonra tarih, sonra fatura no. **Sonuçların
  doğruluğunu etkilemez, yalnızca gösterim sırasını**; sunucudaki eski sırayla birebir aynı
  olmayabilir. Commit mesajında da açıkça yazılı.
- **Sırlar depoya girmedi.** `Y:\defactor\appsettings.json` gerçek kimlikler taşıyor (SQL `sa`
  parolası, üç CRS hesabı, FortiGate API anahtarı, Google servis hesabı). `Crs` bölümü yalnızca
  yerel `src/SentezServis.Host/appsettings.json`'a yazıldı — bu dosya `.gitignore`'da.
  `git log --all -S'DuzceYeni123'` ve `-S'crssoft'` boş: parolalar geçmişe de hiç sızmamış.
  Commit öncesi `git diff --cached | grep -iE "<parolalar>"` ile ayrıca doğrulandı.
- **`CrsAyarlari` `SentezServis.Core.Fatura` isim alanında bırakıldı** (özgün hâli). Diğer
  ayar sınıfları `Ayarlar.cs` içinde ama `FortiCihaz` da `Forti` isim alanında — aynı desen.

## Açık kalanlar / sonraki adım

- **Fatura modülünün arayüzü yok.** Sunucudaki `wwwroot`'ta da `/api/fatura` çağrısı
  bulunamadı; uçlar şu an yalnız API üzerinden kullanılabiliyor. `web/src` tarafında bir
  Fatura sayfası hiç yazılmamış olabilir — ya da o da kayıp. Doğrulanmalı.
- **Kurtarılan modül gerçek veriyle çalıştırılmadı.** Derleniyor ve testler geçiyor ama
  `crs-dene` ile üç şirketin kimliği sınanmalı, sonra bilinen bir tarih aralığında
  `karsilastir` sonucu sunucudaki eski sürümün sonucuyla kıyaslanmalı.
- **Sunucudaki sürüm hâlâ eski build.** Kurtarma yayımlanmadı; `deploy/yayinla.ps1` +
  `uzaktan-yayimla.ps1` ile güncellenmesi gerekiyor.
- **Backlog sırası bekliyor:** S2-07 → S2-01 → S2-03 → S2-06 → S2-04 → S2-02 → S2-05.
- **Durum tabloları gerçeği yansıtmıyor** — `backlog.md` ve `sprint-01.md` güncellenmeli.
- **Kurula gidecek madde:** `SaklamaJob`'un denetim kayıtlarını silmesi ile S2-07'nin
  "temizlik audit'e dokunmaz" kuralı çelişiyor.
