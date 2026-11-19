# muftelif — 2026-11-20

## Bağlam
19.11 sonunda Yükleme Kontrol'de dağılım yalnız Excel/elle, Sentez'den koli toplamı (`69c0e3c`). Gece istek (kullanıcı + Frederic/Olcay WhatsApp):
"Yükleme tarihine göre gelsin (Excel'deki), ayrıca Excel'dekileri ayrı ekranda gösterelim." / "Müşteri listesinde dağıtımlardan sonra kaç tane yüklendiğini göstersin; adet olan yeri 2 satıra bölsün, altına koliye giren, üstte girmesi gereken."

## Yapılanlar

### 1. Hafta = Excel X-Factory Date
- **Neden:** Planlamanın haftası Excel'deki yükleme tarihi; Sentez tarihi farklı olabiliyor.
- **Ne yapıldı:**
  - `YkDagilimDogrulama`: "X-Factory Date" (ve X FACTORY DATE / YUKLEME TARIHI) sütunu okunur; `TarihOku` ISO, dd.MM.yyyy, d-MMM-yy, Excel seri no. Okunamazsa hata; başka haftaya düşüyorsa uyarı (kabul, o haftada görünür); tarih boş + Sentez tarihi başka hafta → hata. `DosyaOrderlari` → controller dosyadaki iş emirlerini de Sentez'den çeker.
  - `YkHaftaOrder.Haftada` (geçerli tarih haftada mı). `YkExcel.SayfaOku`: tarih hücresi ISO okunur.
  - SQL `HaftaOrderlari`: `OR wo.WorkOrderNo IN @ekstra` (Excel tarihi bu haftada olanlar). Önbellek anahtarına ekstra listesi eklendi.
  - Servis `GecerliSatirlarAsync`: kayıtlı Excel tarihi Sentez tarihinin önüne geçer (`YkKaynakSatir.Kopya()` — önbellek bozulmasın); haftası dışındakiler listeden çıkar. `YkOrder.YuklemeTarihiKaynak` (Excel/Sentez), `SentezYuklemeTarihi`.
- **Commit:** `690344d`

### 2. Excel Verisi sekmesi
- SQLite `yk_excel_dosya(islem_id, dosya, baslik_json)`, `yk_excel_satir(islem_id, order_no, satir_no, yukleme_tarihi, hucre_json)`. Aktarımda (tur=yukleme, Baslik dolu) aynı transaction'da yazılır. Geçerli satır = iş emrinin geri alınmamış son yüklemesi → geri alınca önceki dosyanın tarihi döner.
- Önizleme `Baslik` + satır `Hucreler/YuklemeTarihi` döner; istemci aktarımda geri yollar. `GET api/yukleme-kontrol/excel?yil&hafta`. Web: "Excel Verisi" sekmesi (dosya başına tablo, boş sütunlar gizli, arama).

### 3. Müşteri hücresi iki satır (girmesi gereken / koliye giren)
- SQL `KoliMusteri` (eski `Koli` kaldırıldı): sipariş bağlı kutular, sevk adresi `Direction1` (Adres Tarif 1) başına adet + kutu; toplamlar satır toplamı.
- `YkHesap.KoliEsle`: Adres Tarif 1 ↔ müşteri adı/kodu (boşluk/-/_ farksız), "LA" → LA; kalan `KoliEslesmeyen`.
- Web Müşteri Dağılımı: LA + her müşteri + Dağıtılan hücresi üst = dağılım, alt = koli (yeşil tam, amber eksik, kırmızı fazla); sonra Koliye Giren (toplam), Koli Sayısı, Müşterisi Eşleşmeyen. Detay paneli "plan / koli". Excel dışa aktarımına "Koliye Giren: <müşteri>" sütunları.

- **Doğrulama:** 365/365 test (yeni: tarih biçimleri, hafta dışı Excel tarihi, uyarı/hata, Excel satır saklama + geri alma, servis hafta listesi). Canlı Sentez (salt okunur) + geçici SQLite (`scratchpad/yk-v2.db`): 47. hafta 45 iş emri, 41'i kutulu (24.258 adet); örnek.xlsx önizleme 34 satır 0 hata, X-Factory okunuyor. 95280'in tarihi 27.11 yapılıp yüklenince 47'den çıktı, 48'de "Excel" kaynaklı ve dağılımıyla göründü; Excel sekmesi 33 satır/53 sütun.
- **Bulgu:** Adres Tarif 1 hâlâ boş → koliye giren şimdilik tamamı "Müşterisi Eşleşmeyen" (24.258). Sentez'de sevk adreslerine müşteri sütun adı girilince alt satırlar dolar.
- **Paket:** `X:\Gitlab\fredericTr\SentezPlaning-paket-2026-11-20-690344d.zip` (8,6 MB, appsettings.Development.json / data / logs yok; index-NvfSEIfR.js).
  ```bash
  cd SentezPlaning/web && npm run build
  cd ../api && dotnet publish -c Release -r win-x64 --self-contained false -o <out>
  ```

## Kararlar
- Excel tarihi başka haftadaysa reddedilmez, uyarıyla o haftaya taşınır.
- Elle düzeltme tarihi değiştirmez; yalnız dosya yüklemesi.
- Koliye giren müşteri eşlemesi Adres Tarif 1 ile (başka bağ yok); eşleşmeyen ayrı gösterilir, toplam yine doğru.

## Açık kalanlar / sonraki adım
- Paket 192.168.3.228:90'a kurulmalı (69c0e3c/ff2d74e paketlerinin yerine).
- Sentez'de sevk adreslerinin Adres Tarif 1'ine müşteri sütun adları (C:\aaaa\Sentez_AdresTarif1_Oneri_Siparis.csv önerisi). ITALY/ITALY FME/ITALY-FAS/EMANUEL-NOA ve CANADA 3PL/SSENSE aynı adres kaydını paylaşıyor → ayrı adres kaydı gerekir.
