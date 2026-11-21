# Dokuman — 2026-11-21

## Bağlam
Kullanıcı: "İK hariç, inspection dahil depo için kullanma kılavuzu … bir repository oluşturalım, dokümanları kılavuzları oraya yazalım." Grupta zaten kullanıcı dokümanları deposu `modfex-apparel/dokuman` (yerel `X:\Gitlab\modfex-apparel\Dokuman`) vardı ve DEVAM.md'de "Kılavuzlar G1–G6" bekliyordu; yeni depo açmak yerine buraya `kilavuz/` eklendi.

## Yapılanlar
### 1. Depo kullanma kılavuzları
- **Ne yapıldı:** `kilavuz/README.md` (dizin) + `kilavuz/depo/`:
  - `00-genel-akis.md` — hammaddenin yolu, uygulamalar, depolar (canlı: karantina WI01=175, hammadde WH01=177, eski 43 / 1), fiş tipleri. (kendim)
  - `01-mal-kabul-masaustu.md` (~600 satır), `02-mal-kabul-terminal.md` (~465), `04-sevkiyat-mobil.md` (~400) — üç paralel ajan kaynak koddan + UygulamaMetinleri'nden yazdı.
  - `03-satin-alma-inspection.md` — tablet Satın Alma Inspection + masaüstü sipariş bazlı karantina onayı + PDF. (kendim)
  - `img/` — malkabul EkranGoruntusuTestleri çıktıları (örnek veri); eski `malkabul-6b-irsaliye.png` çıkarıldı (irsaliye adımı yok).
  - Kök README'ye kılavuz bağlantısı.
- **Doğrulama:** tüm resim/sayfa bağlantıları dosyalara çözülüyor; depo parametreleri canlı UZM_Ayar'dan okundu.
- **Commit:** `716ad58`.

### 2. Kılavuz HTML + ekran görüntüleri (gece)
- **Neden:** Kullanıcı "html olarak çıkartalım, ekran görüntülerini çekip düzenler misin" dedi.
- **Ne yapıldı:**
  - Yeni görüntüler `kilavuz/depo/img/`: malkabul giriş / ayarlar / üretimden iade / karantina kaldı / sayımı kapat (örnek
    satırlarla), sevkiyat mobil işlem seçimi / mamul / irsaliyeler / sevk / tamamla, tablet 1-4 (menü, siparişler, anket, sonuç).
    Kullanılmayan `*-dar.png` iki dosya silindi.
  - Görseller ilgili md başlıklarının altına eklendi (scratchpad `resimekle.py`); 00'daki dosya adı bağlantıları okunur metne çevrildi.
  - `kilavuz/html-olustur.py`: markdown-it-py (CommonMark + tablo) ile 5 kılavuzu tek sayfaya çevirir; sol menü (h2), PNG'ler
    base64 gömülü, alttaki boş alan Pillow ile kırpılır (en alttaki 14 px kenar korunur), md→md bağlantıları sayfa içi
    çapaya, yazdırmada her kılavuz yeni sayfa. Görüntüler çözülünce sayfa uzadığı için `load`'da #çapaya yeniden kaydırılır.
  - Çıktı `kilavuz/Depo-Kullanma-Kilavuzu.html` (1,8 MB). README'ye bağlantı + yeniden üretme komutu.
- **Komutlar:**
  ```bash
  python -m pip install --user markdown-it-py pillow
  python kilavuz/html-olustur.py
  ```
- **Doğrulama:** Chrome'da açıldı: menü, tablolar, görseller, çapalar (#k02-3-uretime-ver) doğru.
- **Commit:** `518890d`.

## Kararlar
- Kılavuzlar Markdown (GitLab'da okunur); uygulama değişince aynı gün güncellenecek.
- Ajan notları: "Şirketler okunamadı" kullanıcıya görünmez, ekrandaki mesaj "Veritabanına bağlanılamadı"; KLY reddi yalnız Mamul Giriş'te; sevkiyatta çevrimdışı okutma yalnız daha önce indirilmiş siparişte.

## Açık kalanlar / sonraki adım
- Diğer uygulamalar (bantsayim, paketleme, kesimhane…) için kılavuzlar.
