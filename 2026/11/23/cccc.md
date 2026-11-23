# cccc — 2026-11-23

## Bağlam
`C:\cccc` klasöründe 4 Excel var (git reposu değil): `Özet Sipariş Listesi 2024.10.10.xlsx`,
`Export Stock.xlsx`, `Mixed & Individual Stock.xlsx`, `2nd Quality cotton.xlsx`.
Hedef: aktif order'ları model/renk/beden(+cup) bazında aşamaya göre gösteren, aynı
model-renk-beden için stok ve 2. kalite adetlerini yanına koyan Excel raporu.

## Yapılanlar

### 1. Order + stok + 2. kalite birleşik raporu
- **Neden:** Her model-renk-bedenden kaç adedin hangi aşamada olduğunu, ayrıca stok ve 2. kalite adetlerini tek tabloda görmek.
- **Ne yapıldı:**
  - Order filtresi: Order Durumu ∈ {Onay Bekliyor, Planlandı, Durduruldu, Başladı-Çalışıyor, Sevke Hazır}
    ("Başladı" ve "Çalışıyor" dosyada tek değer: `Başladı-Çalışıyor`). 1305 satır.
  - Aşama = `Order Durumu / Üretim Durumu`. Sıralama: Onay Bekliyor → Planlandı → Durduruldu → Başladı-Çalışıyor → Sevke Hazır;
    üretim içinde boş → Kesim Başladı → Kesim Bitti → Dikim Başladı → Paket Bekliyor → Pakette.
  - Beden: order sütunları `.34/70/XS … .46/100/XXXL`. Cup A/B/C/D/DD → bant+cup (`75B`), Cup `.` → numara (`36`).
  - Model anahtarı = kodun ilk 4 hanesi (`6106-M`→`6106`, `4731001`→`4731`). Renk: büyük harf, TR karakterler ASCII,
    çok renkli adlarda parçalar tekil + alfabetik (`BEYAZ-BEYAZ`=`BEYAZ`, `PUDRA-SİYAH`=`SIYAH-PUDRA`).
  - Stok = Export Stock "orders of shipment & STOK" (adet = beden × `QTY Lots PER CTN` × `NO OF CTNS`)
    + Mixed&Individual ("Final product", "YENİ STOK") QUALITY=1 st. 2. Kalite = Mixed QUALITY 2 nd/2 st + 2nd Quality cotton.
    `NO SIZE` → `BEDENSİZ`.
  - Çıktı sayfaları: Model Renk Beden Özet (model ara toplamlı, SUM formülleri), Aktif Order Detay (istenen tüm sütunlar),
    Stok ve 2.Kalite Detay, Aktif Order'ı Olmayan Stok, Notlar.
- **Dokunulan dosyalar:** `C:\cccc\rapor_olustur.py` (veri hazırlığı), `C:\cccc\rapor_excel.py` (Excel yazımı), çıktı `C:\cccc\Order_Stok_Raporu.xlsx`
- **Komutlar:**
  ```bash
  cd /c/cccc && PYTHONIOENCODING=utf-8 python -W ignore rapor_excel.py
  ```
- **Sonuç / doğrulama:** Kaynaklarla mutabakat: Export TOT PCs 229.910, Mixed 32.181 + 7.325, Cotton 18.021 birebir.
  Rapor toplamları: aktif order 1.447.834 adet (beden sütunları; Sipariş Adeti toplamı 1.447.934 — order 4280 / 4280-3'te 100 fark kaynakta),
  stok 246.736, 2. kalite 40.701. LibreOffice recalc Windows'ta çalışmadı (AF_UNIX); formüller Excel açılınca hesaplanır.
- **Commit:** yok — `C:\cccc` git reposu değil, remote yok.

## Kararlar
- "Final product" ve "YENİ STOK" ayrı stok sayıldı (çift sayım riski — kullanıcı teyit edecek).
- SIYAH-BORDO ile BORDO-SIYAH aynı renk sayıldı (sıralı parça eşleşmesi).

## Açık kalanlar / sonraki adım
- YENİ STOK / Final product çakışması teyidi.
- `C:\cccc` için repo + remote açılması (global kural: iş push edilmeli).
