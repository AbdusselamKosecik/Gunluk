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
