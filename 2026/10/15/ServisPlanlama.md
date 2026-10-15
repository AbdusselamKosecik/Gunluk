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
