# onaymerkezi — 2026-10-19

## Bağlam
Kullanıcı onaymerkezi için Vanna AI'nın 192.168.0.2'ye (MODFEXSRV) kurulmasını ve MSSQL'e bağlanmasını istedi.
"Bu PC değil, 192.168.0.2'ye kuracağız" dedi: yerel PC'ye hiçbir şey kurulmadı.
Hedef: Telegram'da `/sor <Türkçe soru>` yazılınca Sentez verisinden yanıt gelmesi.
Kurallar:
- Veri sunucudan çıkmaz; yerel Gemma kullanılır.
- Veritabanına yazma imkânı olmamalı.

## Yapılanlar

### 1. Sunucuya Python 3.12 + Vanna
- **Neden:** Sunucudaki tek Python BioTime'ın kendi Python'u (`C:\ZKBioTime\Python311`), dokunulmadı.
- **Sorun:**
  - Sistem genelinde `PYTHONHOME=C:\ZKBioTime\Python311;...` tanımlı. Bu yüzden başka Python'lar "SRE module mismatch" hatasıyla açılmıyor.
  - Makine ayarı değiştirilmedi. Her bizim süreçte değişken boşaltılıyor: WinRM'de `Remove-Item env:PYTHONHOME`, serviste nssm `AppEnvironmentExtra PYTHONHOME=`.
- **Komutlar (WinRM, `Invoke-Command -ComputerName 192.168.0.2 -Credential (Import-Clixml ~\srv02.cred)`):**
  ```powershell
  Invoke-WebRequest https://www.python.org/ftp/python/3.12.10/python-3.12.10-amd64.exe -OutFile C:\Modfex\Vanna\python-3.12.10-amd64.exe
  Start-Process ... '/quiet','InstallAllUsers=1','TargetDir=C:\Modfex\Vanna\python','PrependPath=0','Include_launcher=0' -Wait
  Remove-Item env:PYTHONHOME
  C:\Modfex\Vanna\python\python.exe -m venv C:\Modfex\Vanna\venv
  C:\Modfex\Vanna\venv\Scripts\python.exe -m pip install "vanna[mssql,openai,chromadb,fastapi]==2.0.2" pyodbc uvicorn
  ```
- **Sonuç:** vanna 2.0.2, chromadb 1.5.9, openai 3.35.1, fastapi 0.146.0, pyodbc 5.3.0.

### 2. Salt-okunur SQL kullanıcısı `modfex_yz_okur`
- **Neden:** Modelin ürettiği SQL canlı SentezCore'da çalışıyor; yazma imkânı DB seviyesinde kapalı olmalı.
- **Ne yapıldı:**
  - Bağlantı `uzman` (sysadmin) ile kuruldu.
  - `CREATE LOGIN modfex_yz_okur` açıldı; şifre rastgele 31 karakter, ekrana ve repoya yazılmadı.
  - `CREATE USER` + `ALTER ROLE db_datareader ADD MEMBER`.
  - `DENY SELECT`: `dbo.UZM_Ayar`, `dbo.UZM_OnayAyar` (Telegram token), `dbo.Meta_User (Password, EMailPassword)`.
  - Şifre yalnızca sunucuda `C:\Modfex\Vanna\ayar.json` içinde duruyor: `odbc` (ODBC Driver 17, 127.0.0.1, ApplicationIntent=ReadOnly), `llm_adres` http://127.0.0.1:8180/v1, `llm_model` gemma-4-26b. Dosyayı `icacls` ile yalnız SYSTEM ve Administrators okuyabiliyor.
- **Doğrulama:**
  - SELECT çalışıyor.
  - UPDATE "permission denied".
  - `UZM_OnayAyar` ve `Meta_User.Password` denied.
  - `Meta_User.UserName` okunuyor.

### 3. YZ Sorgu servisi (`onaymerkezi/yzsorgu/`)
- **Kararlar:**
  - **Vanna 2.0 ajan yapısı kullanılmadı.** Modelin araç çağırabilmesini (tool calling) gerektiriyor; llama-server `--jinja` olmadan çalışıyor. Legacy API (`vanna.legacy`: ChromaDB_VectorStore + OpenAI_Chat) kullanıldı.
  - **Vanna'nın MSSQL çalıştırıcısı kullanılmadı.** `engine.begin()` her şeyi commit ediyor. Yerine kendi `calistir()`: pyodbc, autocommit kapalı, `READ UNCOMMITTED` + `LOCK_TIMEOUT 5000`, 30 sn, en çok 200 satır, `finally rollback`.
  - **Hız:** İlk denemede soru başı 90–120 sn sürüyordu. llama günlüğüne göre istem işleme ~35 token/sn; Vanna her soruda farklı DDL ve belge seçtiği için 2.300–3.500 token baştan işleniyordu.
    - Çözüm: şema özeti, belgeler ve kurallar her soruda aynı sabit sistem isteminde (~13 KB, ~4.300 token). llama.cpp bu öneki önbellekte tutuyor.
    - Vanna'dan yalnızca benzer soru-SQL örnekleri geliyor (`n_results_sql=4`). `get_related_ddl` ve `get_related_documentation` boş döner.
    - Servis açılırken `isit()` öneki önbelleğe yüklüyor.
    - **Sonuç:** soru başı 30–45 sn.
  - **Güvenlik filtresi** (`guvenlik_hatasi`): yorumlar silinir; tek ifade olmalı ve `get_type()=="SELECT"` (CTE dahil) olmalı. Yasak kelime taraması metin sabitleri çıkarıldıktan sonra yapılır; çünkü "2'li Set" ürün adı `SET` olarak reddediliyordu.
  - **Düzeltme turu:** SQL hata verirse hata mesajı modele verilip bir kez yeniden üretiliyor.
  - **`/dogru`:** onaylanan soru-SQL çiftini öğreniyor; `C:\Modfex\Vanna\ogrenilen.sql`'e de yazılıyor, yeniden eğitimde kaybolmuyor.
- **Eğitim verisi (`yzsorgu/egitim/`):**
  - `ddl-uret.ps1` seçilmiş 31 tablonun dolu kolonlarından `ddl.sql` üretir. Kayıt kolonları atılır; RecId, CompanyId, IsDeleted, IsCancelled, IsClosed ve InUse her zaman tutulur. `Meta_User` için yalnız RecId, UserCode, UserName ve IsDeleted elle eklendi.
  - `Erp_Employee` kişisel veri olduğu için bilerek dışarıda bırakıldı.
  - `belgeler.md`: tablo anlamları, bağlar ve durum kodları. Kodlar gerçek veri ve uygulama kodundan doğrulandı:
    - UretimOkutma: Islem 1/2, silme Miktar=-1.
    - UretimBox/PaketKoli Durum: 0 açık, 1 kapalı.
    - SevkOkutma Islem: 1 ekle, 2 çıkar, 3 mamul giriş, 4 geri al.
    - TezgahHareket: Miktar işaretli, bekleyen = SUM(Miktar).
    - Fiş tipleri: 10 üretimden giriş, 130 paketleme, 17 mamul giriş, 120 sevk. Diğerleri "belirsiz" diye yazıldı.
    - Bantlar PL-001…; LostTimes.Duration dakika.
  - `ornekler.sql`: 20 soru-SQL; hepsi DB'de çalıştırılıp doğrulandı.
- **Kurulum:** `yzsorgu/kur.ps1` (geliştirme PC'sinden):
  1. Servisi durdurur.
  2. Dosyaları `C:\Modfex\Vanna\uygulama`'ya kopyalar.
  3. `egit.py` çalıştırır.
  4. nssm ile `ModfexYzSorgu` servisini kurar ve başlatır: `uvicorn yzsorgu:app --host 127.0.0.1 --port 8190`, otomatik başlangıç, log `C:\Modfex\Vanna\log\`.
  5. `/saglik` yanıtını bekler.
- **Deneme sonuçları:**
  - "Bugün 1. bant kaç adet üretti?" → doğru SQL.
  - "Hangi tedarikçiden kaç açık satın alma siparişi" → FOSHAN 6, CITY TEXTIL 4…
  - "Son 30 günde en çok üretilen 5 model" → 4731001/2 8.475…
  - "…tüm kayıtları sil" → "Veri silme işlemi yapamam".
  - Güvenlik filtresi şu girişleri reddetti: DROP / INTO / EXEC / UPDATE / OPENROWSET / WAITFOR / çoklu ifade.

### 4. onaymerkezi `/sor` komutu
- **Dokunulan dosyalar:**
  - `OnayMerkezi/Yz/YzSorgu.cs`: `SorguSonucu.Coz` (sayılar tr-TR, ISO tarih → gg.aa.yyyy), `ISorguServisi`, `HttpSorguServisi` (adres `UZM_OnayAyar.YzSorguAdres`, varsayılan http://127.0.0.1:8190, istemci zaman aşımı 8 dk).
  - `OnayMerkezi/Komut/SorguMetni.cs`: cevap biçimi.
    - Tek değer → `<b>Kolon</b>: değer`.
    - En çok 15 satır ve 48 karakter genişlik → `<pre>` tablo.
    - Daha büyüğü → Excel (sayılar sayı hücresi, başında sıfır olan kodlar metin) ve "📎 N satır" mesajı.
    - SQL her cevapta `<blockquote expandable>` içinde.
  - `KomutServisi.cs`: `/sor`, YZ görevi yetkisi, bekleme mesajı düzenlenir.
  - TelegramMetinleri (TR/EN/AR), PanelMetinleri ipucu, Program.cs (DI + HttpClient), AyarKodu.
  - Testler: `OnayMerkezi.Tests/SorguKomutuTestleri.cs` (8 test).
- **Sonuç:** `dotnet test OnayMerkezi.Tests` → 170 geçti, 7 atlandı (canlı testler).
- **Dağıtım:**
  - Paket: `dagitim/yayinla.ps1`, zip.
  - Sunucuda: servis durduruldu, `C:\Server\Sentez_Onaymerkezi` → `C:\Modfex\Sentez_Onaymerkezi.yedek-2026-10-19` yedeklendi, zip üzerine açıldı, servis başlatıldı.
  - `/api/surum`: 3bd44ac → 0afc7a0.
- **Commit:** `0afc7a0` — /sor: Sentez verisinden Türkçe soruya yanıt (Vanna + yerel Gemma, salt okunur SQL)

## Kararlar
- Yetki `/ai` ile aynı: YZ görevi.
- Yanlış ya da eksik cevaplar `ornekler.sql`'e doğru SQL'iyle eklenip `kur.ps1` yeniden çalıştırılarak düzeltilir.
- Telegram'dan 👍 ile öğrenme (`/dogru`) servis tarafında hazır, bot tarafına bağlanmadı.

## Açık kalanlar / sonraki adım
- Kullanıcının Telegram'dan `/sor` denemesi; yanlış cevap veren soruları örneklere eklemek.
- "kaç metre" gibi birim içeren sorularda model tüm birimleri topluyordu; birim bazında gruplayan örnek eklendi, gözlenecek.
- İstenirse: bot mesajına "✅ doğru" düğmesi → `/dogru`; llama-server `-t 6` artırılırsa hız artar, ama sunucu SQL Server ile paylaşılıyor, kullanıcıya sorulmalı.

---

## Öğleden sonra: kullanıcının ilk denemeleri

### 5. /sor reçete ve stok sorularına cevap veremiyordu
- **Belirti (Telegram, tekbirsoft, 13:08–13:16):**
  - "6224'ün kumaşlarından ne kadar var" sorusuna seri kartında 6224 kodlu stok aradı, "Sonuç yok" döndü.
  - "6224 reçetesindeki kumaşlar" sorusunda "reçete ilişkisi tanımlı değil" dedi.
  - "erp_receiptitem OnverId" sorusunu da anlamadı. Kullanıcının kastettiği `Erp_RecipeItem.OwnerInventoryId`.
- **Sebep:** Eğitimde reçete ve stok tabloları yoktu; "X'in kumaşları = X'in reçetesi" kuralı yazılmamıştı.
- **Yapılan:**
  - `ddl-uret.ps1` listesine `Erp_RecipeItem`, `Erp_InventoryTotal`, `Erp_InventoryUnitItemSize` eklendi.
  - `Erp_InventoryTotal`'daki tutar, fiyat ve konsinye kolonları sabit istemden atıldı.
  - `belgeler.md`'ye iki bölüm eklendi:
    - **Reçete:** `OwnerInventoryId` = mamul; `RecipeType` 1 kumaş, 2 aksesuar; birim çevirisi `UnitDivisor/UnitFactor`. Kaynak: depo `ReceteSorgulari.cs`.
    - **Stok:** `TotalDate IS NULL` güncel bakiye. Kartın toplamı `InventoryVariantId IS NULL`, varyant kırılımı `IS NOT NULL`; ikisi birlikte toplanırsa çift sayılır. Doğrulama: 1582'nin varyant toplamı 5.471,67 = kart satırı.
  - **Birim düzeltmesi:**
    - `Erp_Inventory.UnitId` birim SETİdir (1 adet, 2 ağırlık, 3 uzunluk). Ana birim `Erp_InventoryUnitItemSize.IsMainUnit = 1`'den gelir. Önceki yol danteller için "Deste", kumaşlar için "Çift" veriyordu.
    - Sipariş ve fiş satırlarının `UnitId`'si doğrudan `Meta_UnitSetItem`'dır (Mt/Kg), Mal Kabul doğru.
  - Aynı kodla birden çok stok kartı var (6224'ün 3 kartı: 1289, 14808, 15691).
  - 6 yeni örnek (toplam 26), hepsi DB'de çalıştırıldı.
  - **Gerçek cevap:** 6224'ün reçetesindeki 4 kumaşın (KMS-0082, KMS-0129, KMS-0035, KMS-0034) stoğu 0.

### 6. YZ Sorgu llama yuvalarını kilitliyordu
- **Belirti:** Yeniden kurulumdan sonraki denemelerde ilk soru 600 sn'de dönmedi. 25 dk boyunca tek soru tamamlanmadı; servis.log'da `openai.APITimeoutError`.
- **Sebep:**
  - OpenAI istemcisi 180 sn zaman aşımı + varsayılan 2 yeniden deneme.
  - `/ai` gibi başka istekler bir yuvayı kullanınca o yuvadaki önbellek siliniyor. ~5.6k token önek, ikinci yuva da meşgulken ~20–25 token/sn → 220+ sn.
  - Zaman aşımında yeniden deneme aynı istemi tekrar gönderiyor, iki yuva sürekli dolu kalıyor.
- **Düzeltme:**
  - `OpenAI(timeout=600, max_retries=0)`.
  - `/sor` soruları `threading.Lock` ile sırayla işleniyor.
  - `n_results_sql` 4 → 3.
- **Not:** llama-server (build 11541) `--cache-ram 8192` varsayılan açık; llama ayarına dokunulmadı.

### 7. /ai'ye gönderilen Excel hiç okunmuyordu
- **Sebep:** `GuncellemeCevirici` yalnız `m.Text` okuyordu. Dosyalı mesajda açıklama `Caption`'da geldiği için bot "/ai"yi hiç görmüyordu; dosya indirme de yoktu.
- **Yapılan:**
  - `GelenMesaj`: `Metin = Text ?? Caption`; yeni alanlar `Dosya`, `YanitlananDosya` (`GelenDosya`: Id, Ad, Boyut).
  - `ITelegramIstemci.DosyaIndirAsync`: `Bot.GetInfoAndDownloadFile`.
  - `Komut/TabloMetni.cs`:
    - xlsx/xlsm (ClosedXML) ve csv okur. CSV'de `;` ya da sekme ayıracında ondalık virgül, `,` ayıracında nokta kabul edilir; tırnaklı alanlar desteklenir.
    - Çıktı: sayfa başına satır/kolon sayısı ve kolon istatistikleri (sayı: adet/toplam/en az/en çok; tarih aralığı; metin: farklı değer sayısı). İstatistikler tüm satırlardan hesaplanır.
    - Satır dökümü 12.000 karakter bütçeyle, en çok 5 sayfa.
  - `/ai`:
    - Dosyanın açıklamasında ya da dosyaya yanıt olarak çalışır.
    - Soru yoksa varsayılan "Bu dosyayı analiz et…" sorusu kullanılır.
    - .xls/.pdf için uyarı; 10 MB üstü ve okunamayan dosya için mesaj.
  - Testler: `TabloMetniTestleri` (5), çevirici (2), komut (4) → `dotnet test` 186 geçti, 7 atlandı.
- **Commit:** `35e1d89` — /ai Excel/CSV analizi; /sor reçete-stok eğitimi ve llama kilitlenmesi düzeltmesi
- **Dağıtım:** zip → `C:\Server\Sentez_Onaymerkezi`, `/api/surum` = 35e1d89. yzsorgu `kur.ps1` ile güncellendi (26 örnek).

### 8. Reçete sorularında takma ad karışıklığı
- **Belirti:** Doğru tablolar kullanıldı ama:
  - Model `i`/`m` takma adlarını karıştırdı ve kumaş yerine mamulün adını gösterdi.
  - "6202 stokta olmayan aksesuarlar" sorusu 0 satır döndü (eski birim yolu ve eksik stok kuralı).
- **Düzeltme:**
  - Reçete örnekleri `model`/`kumas`/`aksesuar`/`birim` takma adlarıyla yeniden yazıldı.
  - "Stokta olmayan aksesuarlar" örneği eklendi (toplam 27).
  - Sabit isteme kural eklendi: aynı anlamdaki örneğin SQL'i aynen kullanılır, yalnız kodlar değiştirilir; aynı tablo iki kez bağlanırsa anlamlı takma ad verilir.
- **Deneme sonuçları (sırayla, 140–167 sn):**
  - "6224 un kumaşlarından ne kadar var" → KMS-0034/0035 Kg 0, KMS-0082 Mt 0 ✔.
  - "6224 reçetesindeki kumaşlar" → 4 kumaş, sarf ve birim ✔.
  - Örneklerde birebir olmayan "6202'nin kumaşları ve stokları" → KMS-0214 95.165 Mt, KMS-0140 0, KMS-0298 0 ✔.
- **Kalan küçük sorun:** Reçetede aynı kumaş iki satırsa, sonuçta da iki kez görünüyor.
- **Commit:** `0460446`
- **Hız:** Soru başı ~2,5 dk; çoğu üretimde geçiyor (~4–8 token/sn). Daha hızlısı için llama `-t 6` artırılabilir ya da GPU kullanılabilir; bu sunucu ayarı, kullanıcıya soruldu.
