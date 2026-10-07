# ClaudeDeck — 2026-10-07

## Bağlam
Repo tarayıcı + sekmeli/bölünmüş Claude Code terminalleri hazırdı (`1c2893b`). Sekmeler zaten çift
tıkla yeniden adlandırılabiliyordu. Hedef: her panele (oturuma) kendi başlığını ve "bu oturumda ne
yapıyoruz" notunu verebilmek.

## Yapılanlar

### 1. Panel başlığı + oturum notu
- **Neden:** Aynı repo birden fazla panelde farklı işlerle açık olabiliyor; panel başlığı sadece klasör
  adını gösterdiği için hangi oturumda ne yapıldığı anlaşılmıyordu.
- **Ne yapıldı:**
  - Pane modeli `{ repo }` → `{ repo, title, note }`. `save()` ve `init()` bu alanları state JSON'una
    yazıp okuyor (backend değişmedi; `settings.state` içinde duruyor).
  - `paneTitle(p)` = `p.title || baseName(p.repo)`. Sekme otomatik adı (`tabTitle`) artık bunu kullanıyor;
    sekme tooltip'i her panel için `başlık — not` + yol gösteriyor.
  - Panel başlığında `.path` yerine `.note` span'i. Ada çift tık → başlık, nota çift tık → not
    (placeholder: "Bu oturumda ne yapıyoruz?"). Not boşken soluk italik "not ekle…" görünür. Yol, adın
    tooltip'inde.
  - Ortak `inlineEdit(span, initial, onDone, placeholder)` yardımcısı: Enter/blur kaydet, Esc vazgeç;
    sekme yeniden adlandırma da buna taşındı.
  - `updatePaneHead(tab, i, restore)`: düzenleme sürerken input'u ezmiyor (nokta/düğmeler yine güncellenir).
  - Başlık klasör adıyla aynı girilirse ya da boş bırakılırsa varsayılana döner. Panel boşaltılınca
    (`clearPane`) başlık/not sıfırlanır.
- **Dokunulan dosyalar:** `src/ClaudeDeck/wwwroot/app.js`, `src/ClaudeDeck/wwwroot/app.css`, `README.md`
- **Komutlar:**
  ```bash
  node --check src/ClaudeDeck/wwwroot/app.js
  dotnet build -c Debug src/ClaudeDeck   # 0 hata
  ```
- **Sonuç / doğrulama:** Sözdizimi kontrolü ve derleme temiz. Uygulama içinde elle tıklayarak test edilmedi.
- **Commit:** `988a931` — Panel başlığı ve oturum notu: çift tıkla düzenlenir, kaydedilir

### 2. Repo olmayan klasörleri listeye ekleme
- **Neden:** Liste yalnızca taramada `.git` bulunan klasörlerden oluşuyordu; git olmayan klasörlerde de
  Claude oturumu açabilmek istendi.
- **Ne yapıldı:**
  - `Database.cs`: `repos` tablosuna `manual INTEGER NOT NULL DEFAULT 0` kolonu. Açılışta
    `pragma_table_info('repos')` ile var mı diye bakılıp yoksa `ALTER TABLE` ile ekleniyor (otomatik göç).
    `RepoInfo` artık `Manual` alanını da taşıyor. Yeni `AddFolder(path)` (upsert, `manual=1`,
    `last_opened=şimdi`) ve `RemoveRepo(path)`. `SaveScan` içindeki silme `AND manual=0` ile elle
    eklenenlere dokunmuyor.
  - `MainWindow.xaml.cs`: `addFolder` mesajı → `Microsoft.Win32.OpenFolderDialog` (çoklu seçim, başlangıç
    klasörü = tarama kökü). Seçilenler eklenip `repos` gönderiliyor, ardından `foldersAdded`.
    `removeRepo` mesajı → satırı siliyor.
  - Arayüz: alt kısımda "Tara"nın yanında "＋ Klasör" düğmesi. Eklenen klasör hemen açılıyor (`openRepo`).
    Listede 📁 ile işaretli, sağ tık → onayla listeden kaldır (klasörün kendisine dokunulmuyor).
    "Tüm repolar" başlığı "Tüm klasörler" oldu.
- **Dokunulan dosyalar:** `src/ClaudeDeck/Database.cs`, `src/ClaudeDeck/MainWindow.xaml.cs`,
  `src/ClaudeDeck/wwwroot/app.js`, `src/ClaudeDeck/wwwroot/app.css`, `src/ClaudeDeck/wwwroot/index.html`, `README.md`
- **Komutlar:**
  ```bash
  node --check src/ClaudeDeck/wwwroot/app.js
  dotnet build -c Debug src/ClaudeDeck   # 0 uyarı, 0 hata
  ```
- **Sonuç / doğrulama:** Derleme temiz. Uygulama çalıştırılmadı (ikinci bir örnek kayıtlı tüm panellerde
  `claude` oturumlarını yeniden başlatırdı). Göç ve klasör seçici elle denenmeli.
- **Commit:** `beee735` — Repo olmayan klasörleri de listeye ekleme; `034df2f` — README: elle klasör ekleme

## Kararlar
- Not/başlık **panel (oturum) bazında**, repo bazında değil: aynı repo iki panelde farklı işler yapabilir.
- Ayrı veritabanı kolonu yerine mevcut state JSON'u genişletildi (geri uyumlu: eski kayıtlarda alanlar boş).
- Elle eklenen klasörler aynı `repos` tablosunda, `manual` bayrağıyla tutuluyor; ayrı tablo yok. Arama,
  son açılanlar ve sürükle-bırak aynen çalışıyor.

## Açık kalanlar / sonraki adım
- Uygulamayı çalıştırıp çift tık akışını, "＋ Klasör" ekleme/kaldırmayı ve DB göçünü elle denemek.
- İstenirse kenar çubuğunda repo bazında kalıcı takma ad.
