# sevkiyatmobil — 2026-11-22

## Bağlam
Kullanıcı: "üretimden depoya box olarak kabulde, Box olarak depo yerinin değişmesini yapmamız lazım".

Durum:
- Box kabulü sevkiyat mobilin "Mamul giriş" ekranında yapılıyor: fiş 17, SpecialCode MGR, 42 Üretim → 41 Mamul.
- Fiş SQL'inde depo yeri kolonları sabit `null` yazılıyordu.
- Canlıda 41'de 304 yer tanımlı, ama 15.231 Erp_Box'ın hiçbirinde `WarehouseLocationId` yok.
- `UZM_Ayar` içinde `MamulYerId` yok. Malkabul Depo parametreleri ekranında "Tartılan koli (mamul)" alanı zaten var.

## Kararlar (AskUserQuestion)
- **Kabulde yer:** "Parametrede depo / depo yeri seçmemiz lazım, direkt oraya almamız lazım; sonrasında depo yeri değiştirle değiştirmemiz lazım."
- **Yer değiştirme nerede:** sevkiyat mobil (yeni mod).

## Yapılanlar

### 1. Koli depo yeri (`8b1898e`)
- **Ayar:** `SevkAyarlari.MamulYerId` (UZM_Ayar `MamulYerId`; 0 ya da boşsa null).
- **Fiş yazımı:**
  - `FisSql.KalemEkle` ve `VaryantEkle` içinde `InWarehouseLocationId` / `OutWarehouseLocationId` artık parametreli. Kolon-değer eşlemesi Python ile pozisyonel olarak doğrulandı (230/230 ve 50/50).
  - `FisYazici.KalemleriYazAsync(..., girisYer, cikisYer)`: birleştirme anahtarına yer de girdi. Aynı gün ileri-geri taşıma ayrı kalem olur.
- **Mamul giriş:**
  - Kalem ve varyanta giriş yeri `MamulYerId` yazılır; `Erp_Box.WarehouseLocationId` = yer.
  - Geri al: kolinin MYR kalemi varsa `KoliYeriDegisti` reddi. Yoksa geri alınır ve kolinin yeri boşaltılır.
- **Yer değiştir:** `SevkDeposu.YerDegistirAsync(k, hedefYer, barkod)`, yeni dosya `SevkDeposu.Yer.cs`.
  - Fiş 17, giriş = çıkış = MamulDepoId, SpecialCode MYR (test modunda TST-MYR), günlük tek başlık.
  - Kalemler koli içeriğinden: giriş yeri = hedef, çıkış yeri = kolinin yeri (yersiz eski kolide boş).
  - Kurallar: `YerDegistirKontrol`. Retler: koli yok, KLY, açık, sevk edilmiş, mamulde değil, `KoliZatenBuYerde`; hedef mamul deposunda değilse `YerMamulDeposundaDegil`.
- **Sevk (120):** koli bulunduğu yerden çıkar (`cikisYer: koli.YerId`). `KoliDurumu.YerId` = `Erp_Box.WarehouseLocationId`.
- **Log:** `UZM_SevkOkutma.Islem` alanında CHECK (1,2,3,4) var; DDL yapılmadığı için yer değişimi log'a yazılmaz. İzi MYR fişidir.
- **Ekran:**
  - `KoliYerViewModel` / `KoliYerView`: raf etiketi (kod ya da barkod) okutulunca hedef seçilir, sonraki koliler o rafa gider.
  - Ana menüye "KOLİ YER DEĞİŞTİR" düğmesi eklendi.
  - TR/EN/AR metinleri eklendi.
- **Sentez yer toplamı:**
  - `EditInventoryTotal` → `EditInventoryTotalD` → `EditWarehouseLocationTotal`; kalem ve varyant tetikleyicileri çağırıyor.
  - Toplam hem kalem düzeyinde (varyant boş) hem varyant düzeyinde tutuluyor.
  - Geçici bir teşhis testiyle doğrulandı: taşımada A rafı 5→0, B rafı 0→5; varyantlarda 3 ve 2.
  - Testteki ilk kırmızı, iki düzeyin birlikte toplanmasından geliyordu.
- **Testler:**
  - `KoliYeriTestleri` (7 DB testi, rollback): girişte yer, taşıma, yer toplamı, yersiz koli, retler, geri al, sevkte çıkış yeri, yer listesi.
  - `KoliYerEkraniTestleri`: raf okutmadan koli taşınmaz.
  - Ekran görüntüsü testine yeni ekran eklendi; headless render kontrol edildi.
  - Sonuç 118/118.
- **Komut:** `MODFEX_DB_TEST=1 dotnet test SevkiyatMobil.Tests`

## Açık kalanlar
- Malkabul → Depo parametreleri → "Tartılan koli (mamul)" için 41'de bir yer seçilmeli (`MamulYerId`). Seçilmezse koliler yersiz girer; yer değiştir ile yer verilebilir.
- Sevkiyat mobil APK'sı yeniden derlenip terminallere kurulmalı (paket üretilmedi).
- Mevcut 15.231 yersiz koli: sayım ya da yer değiştir ile yerlerine okutulmalı.
