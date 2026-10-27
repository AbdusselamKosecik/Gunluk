# Saas_erp — 2026-10-28

## Bağlam
DIA B3 (varyant bazlı stok) 27'sinde DEV 1088 ile kapandı. Kullanıcı; İleri Üretim, İplik, Örme, Dokuma, Boyahane, Yıkama,
Çivit (İndigo) ve Konfeksiyon için uçtan uca, tüm olasılıklarıyla diagrams.net akış şeması istedi.

## Yapılanlar

### 1. Üretim akış şemaları (diagrams.net)
- **Neden:** Modüllerin gerçek davranışını (karar noktaları, hata/ret yolları, stok fiş kodları) tek yerde görmek; boşlukları görünür kılmak.
- **Ne yapıldı:**
  - Önce kodu okuyan araştırma ajanlarıyla her modülün gerçek akışı çıkarıldı. Yalnız kodun yaptığı çizildi; olmayanlar "sistemde YOK" notu oldu.
  - Python üreticisi yazıldı: `drawio_gen.py` (kulvar ızgarası, düğüm tipleri, ortogonal kenarlar, sıkıştırmasız mxfile) + `flows.py` (12 sayfa tanımı).
  - Sayfalar: Lejant, Genel zincir, Ortak üretim emri, İleri Üretim, İplik, Örme, Dokuma, Çözgü, İndigo/Haşıl, Boyahane, Yıkama, Konfeksiyon.
  - Doğrulama: XML geçerli (661 mxCell), düğüm çakışma kontrolü temiz, viewer.diagrams.net'te Dokuma sayfası görsel olarak kontrol edildi.
- **Dokunulan dosyalar:** `docs/design/flows/{README.md, uretim-akislari.drawio, flows.py, drawio_gen.py}`
- **Komutlar:**
  ```bash
  cd docs/design/flows && py -3 -B flows.py uretim-akislari.drawio
  ```
- **Önemli bulgular (şemalarda not olarak):**
  - Ortak yaşam döngüsü: 0 Taslak → 1 Planlı → 2 Serbest → 3 İşlemde → 4 Tamamlandı / 5 İptal; 4→3 yeniden açma. Otomatik tamamlama yalnız Boyahane'de.
  - AllocateFromReceipt yalnız rezerv yapar, fiziksel transfer yok.
  - Üretim fişi = 3062 Sarf + 3010 Üretim (ops. 3066 fason çıkış / 3014 transfer).
  - MRP yalnız Dokuma (iplik) ve Boyahane (kimyasal) için dolu.
  - Yıkama ayrı emir tipi değil; Boyahane rotasında operasyon/program. Konfeksiyon yıkaması YOK.
  - Fason faturalama YOK.
  - Konfeksiyonda mamul 3010 otomatik değil (elle).
  - Örme fişleri emre bağlı değil; FabricInspection yalnız Dokuma'da.
- **Commit:** `4b61f3fd` — docs(design): uretim akis semalari (diagrams.net)

## Kararlar
- Şemalar elle çizilmedi, kodla üretildi; akış değişince `flows.py` güncellenip yeniden üretilir.
- Ajanlar çeliştiğinde (AllocateFromReceipt'in Ham→WIP taşıdığı iddiası) koda bakıldı: `TransferAsync`'in çağıranı yok, yani yalnız rezerv.

## Açık kalanlar / sonraki adım
- DIA backlog: C4 (envanter idempotency) ve C6 (gerçek toplu upsert) — ikisi de kurul gerektirir.
- B3 takipleri: varyant bazlı üretim çıktısı/tahsis; DEV test kayıtları; düşük önemli güvenlik bulguları (ClickUp z8v9xnjkn9).
