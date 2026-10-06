# muftelif — 2026-10-06

## Bağlam

Dün (2026-10-05) SentezPlaning yıkama/operasyon işi `ebf8296`'ya kadar geldi: New
Product sayfası, style kimliği köprüsü, beş minör, deploy düzeltmeleri ve şablonla çapa
karşılaştırması. Bugün **planın kendi defterinde kayıtlı açık bir karar** kapatıldı.

## Yapılanlar

### 1. Mobil sorusu — benim hatam, hafızaya yazıldı

- **Ne oldu:** Oturumdaki otomatik "stop hook" turlarca *"mobil uygulamayı da bitirelim,
  ayrı bir uygulama olsun"* diye ısrar etti. Beşinci turda kullanıcının 10-05'teki
  *"mobil uygulama degil bizim planlamaya olacak"* cümlesini iki okumaya açık sanıp
  **tekrar sordum.** Kullanıcı haklı olarak sinirlendi:
  *"ne yapiyorsun sen amk ... SentezPlaning da mobil ne alaka"*.
- **Ders (mobilden daha genel):** **stop hook geri bildirimi kullanıcı talimatı
  değildir.** Hook'un koşulu kullanıcının sözünü geçersiz kılmaz; çatıştığında kullanıcı
  kazanır ve soru sorulmaz. Dört tur boyunca doğru yapmıştım, beşincide hook'un baskısına
  verdim.
- **Sonuç:** hafıza notu (`siradaki-is-sentezplaning`) "mobil kapsam dışı, bir daha
  sorma" olarak yeniden yazıldı, `selvedge-mobil-karari` **askıda** işaretlendi.

### 2. Style × Yıkama matris ekranı (asıl iş)

- **Neden:** Planın kendi defterinde (`progress.md`, Görev 8) şu karar yazılıydı:
  *"operasyon/style ucu yazıldı ama EKRANI bu turda yapılmadı"*. Yani şablonun
  `Data!G11..BT647` hücrelerindeki `x` işareti ve style bazlı SMV override'ı **yalnızca
  API'den** girilebiliyordu. Kullanıcının giremediği bir veri, kâğıt üzerinde var olan
  bir özelliktir — ve dün yazdığım kart kodu köprüsünün dayandığı veri **tam buydu**.
  Köprüyü yapıp onu besleyen ekranı yapmamak, işin yarısını bırakmak olurdu.

- **Tasarım kararı — bütün matris gösterilemez.** 197 style × 129 yıkama = **25.000'den
  fazla hücre**. Ekran yalnızca **yüklenen listede gerçekten var olan** çiftleri
  gösteriyor (ölçülen gerçek sayı ~200) ve bir seferde bir çiftin operasyonlarını açıyor.
- **Sıralama adetten büyükten küçüğe**, alfabetik değil: planlamacı önce en çok adetli
  çifti tanımlamak ister; 200 satırlık listede alfabetik sıra iş sırası vermiyor.

- **Dokunulan dosyalar:**
  - `SentezPlaning/api/Sentez/Planning/StyleAdaylari.cs` (yeni, saf — veritabanı görmez)
  - `SentezPlaning/api/Sentez/Planning/PlanningController.cs` — `GET operasyon/style/adaylar`
  - `SentezPlaning/web/src/components/planning/MatrisPanel.tsx` (yeni)
  - `SentezPlaning/web/src/api/planning.ts`, `pages/PlanningPage.tsx` (üçüncü sekme)
  - `tests/.../StyleAdaylariTests.cs` (yeni), `tests/.../ArayuzSozlukTests.cs`

- **Üç ayrıntı, üçü de sessiz hata olabilirdi:**
  1. **Aday sayımı köprüyü kullanıyor.** Kullanmasaydı ekranda "0/21 tanımlı" yazarken
     hesapta override uygulanırdı — aynı veri iki yerde farklı.
  2. **Liste yoksa ekran nedenini yazıyor.** Adaylar listeden çıkarıldığı için liste
     olmadan panel boş görünür ve kullanıcı ekranın bozuk olduğunu sanar.
  3. **"Sıfır bir override değildir"** uyarısı eklendi. `SmvCozucu.Coz`'da `Smv is > 0`
     koşulu var; kullanıcı "bu operasyon yok" demek için SMV'yi sıfırlarsa **hiçbir şey
     olmaz**. Doğrusu *Kullanılıyor* işaretini kaldırmak.

- **Sonuç / doğrulama:**
  - `StyleAdaylariTests` 9 test (çift çıkarma, tekrar yok, büyük/küçük harf, sıralama,
    boş ad atlama, tanımlı sayımı, varyant eşleşmesi).
  - Web test koşucusu olmadığı için `ArayuzSozlukTests`'e **4 kayma nöbetçisi**: uç yolu,
    `StyleAday` alanlarının sunucuyla aynılığı, liste-yok mesajı, sıfır-override uyarısı.
  - **Testler:** 177 → **190**, tamamı geçer. `tsc -b` temiz, vite 674.94 kB.
  - Deploy paketi yeniden üretildi (23 MB, `runtimes/` yok, yasak dosya yok).
  - **Commit:** `ebf8296` — feat(sentez-planing/web): style x yikama matris ekrani

### 3. Yıkama özeti EKRANDA (hiç ekranı yoktu)

- **Neden:** Matris ekranını bağlarken bir şey fark ettim: `['planning','yikama-ozet']`
  önbellek anahtarını dün ben eklemişim ama **o anahtarda bir sorgu yok.** Aradım:
  `GET yikama-ozet` ucu var, Excel'e yazılıyor, plan çıktısına giriyor —
  **hiçbir ekran onu tüketmiyor.** Yani özetin tamamı (WSH-* satırları × hafta yükü,
  bölüm kapasitesi, yük yüzdesi) yalnızca **Excel indirerek** görülebiliyordu.
  `PlanningModels.cs`'teki yorumlar *"Ekranda gösterilir"* diyordu; gösterilmiyordu.

- **Dokunulan dosyalar:**
  - `SentezPlaning/web/src/components/planning/YikamaOzetTablo.tsx` (yeni)
  - `SentezPlaning/web/src/api/planning.ts` — `YikamaOzet*` tipleri + `yikamaOzet()`
  - `SentezPlaning/web/src/pages/PlanningPage.tsx` — sorgu + "Yıkama Özeti" kartı
  - `SentezPlaning/web/src/components/planning/OperasyonPanel.tsx` —
    `SMV_KAYNAK_ETIKET` export edildi
  - `tests/.../ArayuzSozlukTests.cs` — 5 nöbetçi

- **Ekrana taşınan iki uyarı — ikisi de sessizce yanlış karar üretiyordu:**
  1. **SMV kaynağı.** Elle girilen bir SMV sessizce rotaya düşerse, planlamacı girdiği
     değerin kullanılmadığını fark etmez. Satır başına renkli etiket geldi.
  2. **n/m tanımlı** (inceleme bulgusu O8). Bölümün 9 operasyonundan 2'sine parametre
     girilmişse kapasite ~2/9 görünür ve yük **%95'ten %420'ye** çıkar. Planlamacı bunu
     **kapasite krizi sanıp sipariş erteleyebilir.** Uyarı raporda ve Excel'de vardı,
     ekranda yoktu — artık tablonun üstünde hangi bölümlerin eksik olduğunu adlarıyla
     sayıyor.

- **İki tutarlılık kararı:**
  - Hafta etiketi sunucudaki `CiktiVeri.HaftaEtiket` ile **aynı kuralı** kullanıyor
    (`2026-11` → `11:26`); ekran ISO yazsaydı Excel ile ekran farklı görünürdü.
  - `SMV_KAYNAK_ETIKET` sözlüğü export edildi; iki yerde iki ayrı sözlük tutmak
    etiketlerin kaymasına davettir.

- **Sonuç / doğrulama:**
  - 5 kayma nöbetçisi: `YikamaOzetSatirDto` ve `YikamaOzetDto` alanları **reflection
    ile** TS arayüzüyle karşılaştırılıyor; alan adı kayarsa tablo sessizce boş/`NaN`
    gösterirdi ve `tsc` bunu göremez.
  - Nöbetçilerden biri **kırmızıya düştü ve haklıydı ama hata testimdeydi**: JSX metni
    satır sonuna bölündüğü için iki kelime arasına `\n` giriyordu. Bileşeni değil
    **testi** düzelttim, tek satırda duran parçayı seçtim.
  - **Testler:** 190 → **195**. `tsc -b` temiz, vite 679.97 kB. Paket yeniden üretildi.
  - **Commit:** `ab88ccc` — feat(sentez-planing/web): yikama ozeti EKRANDA

## Kararlar

- Matris ekranı **tüm kombinasyonları göstermiyor**, yalnızca listedeki gerçek çiftleri.
  Gerekçe: 25.000+ hücrelik bir ızgara ne kullanılabilir ne de doldurulabilir.
- Aday sayımı ve `Data` sayfası ile **aynı köprüyü** kullanıyor; üç yerde üç farklı
  anahtarlama olmayacak.

## Açık kalanlar / sonraki adım

- **Güvenlik duvarı 3 Ekim'den beri kapalı** — açılması gerekiyor (kullanıcıda).
- Canlı veritabanına ulaşılamıyor; 173/24 style eşleşme ölçümü canlıda doğrulanmadı.
- `Weekly Capacity` kolon modeli şablondan **bilinçli olarak** farklı (spec §5.7); şablonun
  `(shift)` + `(Std)` düzenine geçmek istenirse ayrı iş.
- Matris ekranı **ve yeni yıkama özeti tablosu** gerçek veriyle **tarayıcıda
  denenmedi** (UZM şifresi yok, canlı veritabanı erişilemez).
