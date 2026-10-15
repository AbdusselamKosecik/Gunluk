# ServisPlanlama — 2026-10-15

## Bağlam
Kullanıcı `ServisPlanlama/DENDATA Employee Information Transfer Template.xlsx` dosyasını klasöre koydu ve
ev adreslerinin oradan güncellenmesini istedi. Ek uyarısı: **"PDKS yi guncelleme"**. ZKBioTime yalnız okundu.

## Yapılanlar

### 1. Excel'den oturma adresi aktarımı (canlı veri, kullanıcı isteğiyle)
- **Neden:** BioTime adresleri eksik veya hatalı. ServisPlanlama, `PersonelServis.OturmaAdresi` doluysa
  BioTime adresi yerine onu kullanıyor (`PersonelKaynagi`).
- **Excel yapısı:**
  - Sayfa: "Employeee Enrollment". 1. satır Arapça, 2. satır İngilizce başlık; veri 3. satırdan başlıyor.
  - Sütunlar:
    - A `code` = BioTime `personnel_employee.emp_code` (sicil no).
    - D: ad.
    - F/G/H: Home Address 1/2/3 (sokak-köy / ilçe / il).
    - I: Service Route.
  - Sondaki 41 satır kodsuz boş şablon satırı; atlandı.
- **Eşleme:**
  - Excel `code` → BioTime `emp_code` → `id` (= `PersonelServis.PersonelId`).
  - Eşleşen 359 kişinin 355'i aktif, 4'ü pasif. Eşleşmeyen yok.
- **Adres:** `"Adres1, Adres2, Adres3"` (boş parçalar atılır, en çok 500 karakter). Örnek: `El Zeraa El-Bahry, Amreya First, Alexandria`.
- **Yazım:** tek transaction (`XACT_ABORT`).
  - Var olan kayıtta yalnız `OturmaAdresi` güncellenir (değiştiyse; BIN2 karşılaştırma).
  - Yoksa INSERT. Servis ve durak atamalarına dokunulmaz. `Guncelleyen = 'excel-dendata'`.
- **Elle düzeltilmiş konumlar korundu:**
  - `KonumIsi`, `Konum.AdresAnahtari` (`"{Adres}|{Sehir}"`) değişince konumu yeniden arıyor; elle konulmuş konumlar da buna dahil.
  - Bu yüzden `Hassasiyet = 'elle'` olan 3 kaydın anahtarı aynı transaction'da yeni adrese çekildi:
    `STUFF(AdresAnahtari, 1, CHARINDEX('|')-1, yeniAdres)`.
- **Takılan nokta:**
  - İlk deneme "collation conflict Turkish_CS_AS vs Arabic_100_CI_AI" hatasıyla tamamen geri alındı.
  - Bağlantı SentezCore üzerinden açıldığı için tablo değişkeni Türkçe collation alıyordu.
  - Çözüm: `@v.Adres COLLATE Arabic_100_CI_AI`.
- **Adımlar** (betikler scratchpad'deydi; yeniden yazmak için tarif):
  1. BioTime'dan `id|emp_code|status` listesi çekildi (salt okuma).
  2. Python + openpyxl ile Excel okunup eşlendi; önizleme sayıları üretildi; `@v` VALUES'lu SQL dosyası yazıldı.
  3. SQL dosyası, dosyadan okuyan yazma betiğiyle çalıştırıldı. Komut satırı 32K sınırı yüzünden dosyadan okutuldu.
- **Sonuç / doğrulama:**
  - Güncellenen 330, eklenen 29, korunan elle konum 3.
  - `PersonelServis` içinde adresi dolu 359 kayıt var; hepsi `excel-dendata`.
  - Servis atamaları yerinde (örn. 21 → servis 23).
- **Commit:** yok. Projede kod değişmedi; değişen yalnız canlı veri.

## Kararlar
- PDKS (zkbiotime) hiç yazılmadı.
- PDKS'de pasif olan 4 kişinin adresi de yazıldı. Zararsız: pano yalnız aktifleri gösteriyor.
- "Service Route" sütunu kullanılmadı; yalnız adres istendi.

## Açık kalanlar / sonraki adım
- Uygulama, değişen adreslerin konumunu arka planda yeniden arayacak (Nominatim 1 istek/sn, ~10-20 dk).
- Adresler İngilizce (Latin harf). Ayrıştırıcı (`AdresAyristirici`) Arapça ağırlıklı; Nominatim İngilizce adları genelde buluyor.
  Konum sonuçları "bolge" ağırlıklı kalırsa sözlüğe Latin takma adlar eklenmeli.
- Excel dosyası maaş ve kimlik bilgisi içeriyor ve repo klasöründe izlenmeyen dosya olarak duruyor. Commit edilmemeli.

---

## Devam (aynı gün)

### 2. Uygulama kullanıcılarının parolası sıfırlandı (kullanıcı isteğiyle)
- **Neden:** Kullanıcı `admin` / `user` parolalarını bilmiyordu. Özetten parola geri çıkarılamaz.
- **Ne yapıldı:**
  - `Kullanici.ParolaOzeti` iki kullanıcı için kullanıcının verdiği parolayla yeniden yazıldı. Parola günlüğe yazılmaz.
  - Biçim `Kimlik/Parola.cs` ile aynı: `pbkdf2$100000$<tuz b64>$<özet b64>`, PBKDF2-SHA256, 16 bayt tuz, 32 bayt özet.
  - Özet PowerShell 5.1'de üretildi: `New-Object Security.Cryptography.Rfc2898DeriveBytes(p, tuz, 100000, SHA256)`.
    .NET Framework'te statik `Pbkdf2` yok.
- **Doğrulama:** `POST http://192.168.0.2:8086/api/oturum/giris` iki kullanıcı için de 200 döndü.

### 3. "Tüm atamaları temizle" + "Tüm adreslerin konumunu yeniden bul" butonları
- **Ne yapıldı:**
  - `ServisDeposu.AtamalariTemizleAsync`: `PersonelServis.ServisId` ve `DurakId` NULL yapılır.
    Servisler, duraklar ve oturma adresleri kalır.
  - Uç: `POST /api/atamalar/temizle` (yönetici) → `{ temizlenen }`.
  - Servisler panosu araç çubuğunda onaylı "Tüm atamaları temizle" butonu.
  - Ayarlar › Konumlar'da onaylı "Tüm adreslerin konumunu yeniden bul" butonu.
    Mevcut `POST /api/konum/bul?yeniden=true` ucunu çağırır; elle konulan konumlar korunur.
  - TR/EN/AR metinleri `dil.js` içine eklendi.
- **Dokunulan dosyalar:**
  - `src/ServisPlanlama/Veri/ServisDeposu.cs`
  - `Api/PlanlamaUclari.cs`
  - `wwwroot/index.html`
  - `wwwroot/js/pano.js`
  - `wwwroot/js/ayarlar.js`
  - `wwwroot/dil.js`
- **Komutlar:** `dotnet test ServisPlanlama.slnx` → 34/34.
- **Canlı veri (kullanıcı isteğiyle):**
  - Yerel uygulama ofis SQL'ine (192.168.0.2) bağlanarak açıldı. Bağlantı cümlesindeki sunucu yalnız ortam değişkeninde değiştirildi:
    `ServisPlanlama__BaglantiCumlesi`, `ServisPlanlama__BioTimeBaglantiCumlesi`.
  - Yeni uçla tüm atamalar temizlendi: 275 kaldırıldı.
  - Sonrasında servisli 0, duraklı 0, adresli 359.
- **Konum:** Sunucudaki (eski sürüm) servis üzerinden `konum/bul?yeniden=true` başlatıldı; 353 kişi işleniyor.
- **Commit:** `39ca432` — Tüm atamaları temizle ve tüm konumları yeniden bul butonları

### Ortam notları
- `modfexsrv` Tailscale'de çevrimdışıydı (100.119.104.122 erişilemiyor). Kullanıcı ofis ağındaydı (192.168.0.80); 192.168.0.2 doğrudan erişilebiliyordu.
- `dotnet run` apphost exe'si bu makinede SQL'e bağlanamayabiliyor; `dotnet <dll>` ile çalıştırmak gerekiyor.
- Kestrel ayarı `--urls` parametresini eziyor; uygulama her zaman 8086'da dinliyor.

## Açık kalanlar
- Yeni butonlar sunucuya henüz yayınlanmadı. Gereken adımlar: `deploy/yayinla.ps1`, ardından sunucuda zip açılıp `servis-kur.ps1` (yönetici).

### 4. Kişi bazında "Konumu yeniden ara"
- **Neden:** Kullanıcı, toplu tarama bittikten sonra istediği kişiyi tek başına yeniden taratmak istedi.
- **Ne yapıldı:**
  - `POST /api/personel/{id}/konum/ara`: `Geocoder.CozAsync(p.Adres, p.Sehir)` sonucu `Konum`'a yazılır.
    Elle konulmuş konumda istemci onay sorar, onaylanırsa konum değişir.
  - İstemci: `pano.js` içinde `konumYenidenAra(id)`. Butonlar:
    - Personel tablosunda satır başına 🔄
    - Kişi penceresinde `#kisiKonumAra`
    - Harita balonunda `data-is="ara"`
  - TR/EN/AR metinleri: `kd.konumAra`, `kd.elleOnay`, `kd.araniyor`, `kd.bulundu`.
- **Doğrulama:**
  - `dotnet test` 34/34; `node --check` ile JS dosyaları temiz.
  - Yerelde (ofis SQL'i) uç denendi; yanıt döndü.
  - Denenen adres `12 Al-Nour Al-Muhammady St., Janoty, Raml Second, Alexandria` sonucu: "yok".
- **Commit:** `9ee53d0` — Kişi bazında konumu yeniden ara

### Gözlem: İngilizce adreslerde konum kalitesi düşük
- Sunucudaki toplu taramanın ilk 102 sonucu: yer 27, bölge 55, yok 20.
- `AdresAyristirici` ve `Bolgeler` takma adları Arapça ağırlıklı. Excel adresleri Latin harfli
  ("Amreya First", "Raml Second", "Borg El Arab", "Montaza Section").
- Öneri: `Bolgeler.Takmalar` içine Latin yazımlar eklemek, `Parcala` / `Temizle` için İngilizce ekler
  ("St.", "First/Second", "Section", "Village") tanıtmak.

### 5. DENDATA Excel: Original Department + Job (PDKS'ye göre)
- **İstek:** "Employee's Working Data" sayfasında E (Original Department) ve F (Job) sütunları doldurulacak.
  Departman yeni 01–21 koduna göre (bordro programı `X:\Yazilim\aaaa` DEPXX.MAS ile aynı ad ve kod), iş PDKS'deki görevden.
- **Kaynaklar (salt okuma):**
  - PDKS `personnel_employee`: `emp_code`, `department_id → dept_code`, `position_id → position_name`.
    Operatörlerin `last_name` alanında makine türleri yazıyor ("Singer-Over-Zigzag", "Joker A", "orle"...).
  - Excel satır r = Enrollment satır r; sicil = Enrollment!A.
- **Departman eşlemesi** (PDKS → yeni kod):
  - 1 / Administration → 01
  - Production → 02, Sample → 03, Warehouse → 04, Cutting → 05
  - Bant 1–7 → 06–12, Line 8 → 13
  - Quality control / Qc / Final Qc → 14
  - Ironing → 15, Packing → 16, Export Warehouse → 17, Maintenance → 18, Security → 19, Service → 20, Training → 21
  - Biçim: `05 - Cutting` (şablon örneği "6 - Embroidery").
- **Operatör iş kuralı** (Jobs List'teki makine işleri):
  - Makine aileleri:
    - S (düz dikiş): singer, zigzag, bartack/partack, 2needle
    - O: over
    - R: orle
    - F (flat): recme
  - Eşleme:
    - Tek aile: S → 028, O → 032, R → 031, F → 128
    - İkili: SO → 088, SR → 089, OR → 090, SF → 129, RF → 130, OF → 131
    - 3+ aile ya da "Joker" → 029 Machine Joker
    - Makine bilgisi yok → 030 Machine Operator
  - Şablondaki tek örnek ("orle -ziazag" → 089) bu kuralla birebir tutuyor.
- **Diğer görevler:**
  - Helper → 022, Packing → 039, Qc → 043, Triming Machine → 123 Thread Operator, Final Qc → 065
  - Accessories (depo) → 139 Store Keeper, Cutting Chief → 077, QC cap → 157 Team Leader
  - vb.; tam tablo betikte (`GOREV`).
- **Yazım:**
  - openpyxl kaydederken x14 dataValidation'ı (F sütunu Jobs List açılır listesi) siliyor.
    Bu yüzden xlsx zip içinde yalnız `xl/worksheets/sheet2.xml` E/F hücreleri `inlineStr` olarak değiştirildi.
  - İlk denemede self-closing hücre regex'i sonraki hücreyi yuttu; assert yakaladı, dosyaya yazılmadı.
    Düzeltilmiş desen: `<c r="E4"(?:[^>]*?/>|[^>/]*>.*?</c>)`.
- **Sonuç:**
  - E 359/359, F 358/359 dolu. Boş kalan sicil 5343: PDKS'de görev ve soyad boş.
  - Tüm işler Jobs List'te var; açılır liste korundu.
  - Satır 3'teki şablon örneği ("6 - Embroidery") PDKS'ye göre "08 - Line 3" oldu.
- **Yedek:** Excel'in yazım öncesi kopyası scratchpad'de `DENDATA-yedek-*.xlsx`.
- Excel git'e eklenmedi (kişisel veri).
