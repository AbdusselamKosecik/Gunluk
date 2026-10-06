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
- Matris ekranı gerçek veriyle **tarayıcıda denenmedi** (UZM şifresi yok).
