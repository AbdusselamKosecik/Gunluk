# paketleme — 2026-10-15

## Bağlam
Kullanıcı: "Siparis etiketinde Siparis altinda birden fazla Work oder varsa Workorder de secmemiz gerekiyor ayni ekrandan".
Etiket sekmesinin Sipariş modunda sipariş seçilince tüm sipariş kalemleri listeleniyordu.
Koli okutmada iş emri seçimi zaten vardı (`c1de795`), etiket ekranında yoktu.

## Yapılanlar

### 1. Sipariş etiketinde iş emri seçimi
- **Neden:** Siparişte birden fazla iş emri varsa etiket, seçilen iş emrinin ürün ve miktarıyla basılmalı.
  Canlıdaki iki siparişin ikisi de ikişer iş emrine bağlı:
  - 00000002 → Test-004-1 / -2
  - 00000001 → Test-005-1 / -2
- **Ne yapıldı:**
  - `UrunEtiketi.SatirlarAsync(orderReceiptId, workOrderId?)` eklendi. Bağlantı ve transaction alan internal bir sürümü de var.
    İş emri verilirse yalnız `UZM_SiparisWorkOrder.OrderReceiptItemId` ile o iş emrine bağlı kalemler gelir.
    Bu, koli okutmadaki filtrenin aynısı.
  - `EtiketViewModel`:
    - Sipariş seçilince `KoliDeposu.IsEmirleriAsync(Oturum.CompanyId, siparis)` çağrılır.
    - Tek iş emri varsa kendiliğinden seçilir.
    - Birden fazla iş emri varsa ComboBox görünür. Seçim yapılana kadar satır gelmez ve kırmızı "Önce iş emri seçin" uyarısı çıkar.
    - İş emri değişince satırlar yeniden yüklenir.
  - `EtiketView.axaml`: tablonun üstüne "İŞ EMRİ" ComboBox'ı eklendi. Koli okutmadaki ile aynı şablonu kullanıyor (no · model · tezgahta).
- **Dokunulan dosyalar:**
  - `Paketleme/Ekranlar/Veri/UrunEtiketi.cs`
  - `Paketleme/Ekranlar/EtiketViewModel.cs`
  - `Paketleme/Ekranlar/EtiketView.axaml`
  - `Paketleme.Tests/KoliIsEmriTestleri.cs`
- **Test:** `Siparis_etiketi_is_emrinin_kalemleriyle_sinirli` (önce kırmızı, sonra yeşil).
  - Test siparişinin S kalemi WO1'e, T kalemi WO2'ye bağlı; çalıştırma sonunda ROLLBACK yapılır.
  - WO1 yalnız S'yi, WO2 yalnız T'yi getiriyor.
  - İki iş emrinin toplamı, filtresiz toplamla eşit.
- **Komutlar:**
  ```bash
  MODFEX_DB_TEST=1 dotnet test Paketleme.Tests   # 210/210
  ```
- **Sonuç:** Uygulama yeniden derlenip açıldı (`dotnet Paketleme.Desktop.dll`).
- **Commit:** `daab989` — Siparis etiketi: sipariste birden fazla is emri varsa is emri secimi

## Kararlar
- İş emri listesi koli okutmadaki sorgudan geliyor (`KoliDeposu.IsEmirleriAsync`). Tezgah tabloları kurulu değilse liste boş döner
  ve eski davranış (tüm sipariş) sürer. Canlıda tezgah kurulu.
- Etikete iş emri no basılmıyor; yalnız satırlar ve miktarlar filtreleniyor.

## Açık kalanlar
- Ekranın kullanıcı tarafından denenmesi.

### 2. İş emri no Sentez'den (Erp_WorkOrder)
- **Neden:** Kullanıcı: "Is emri numralarini sentezden alirmisin? degistirdik ama TEST diye kaliyor".
  İş emri listesi `UZM_SiparisWorkOrder.WorkOrderNo` sütunundan okunuyordu. Bu sütun, sentezservis iş emrini oluştururken yazdığı kopya.
  Sentez'de 71531'in numarası Test-004-2 → 4315-2 olarak değişmiş ama kopya eski kalmıştı.
  Diğer üçü (Test-004-1, Test-005-1, Test-005-2) Sentez'de de hâlâ Test.
- **Ne yapıldı:** `KoliDeposu.IsEmirleriAsync`: numara artık `ISNULL(MIN(w.WorkOrderNo), MIN(sw.WorkOrderNo))`. Sıralama da bu ifadeye göre.
  Bu liste hem koli okutmada hem sipariş etiketinde kullanılıyor.
- **Test:** `Is_emri_no_sentezden_okunur`: transaction içinde kopya 'ESKI-NO' yapılır, listeden Sentez numarası beklenir.
  Önce kırmızı ("ESKI-NO"), sonra yeşil. Suite 211/211.
- **Commit:** `f8f291b`
- Uygulama yeniden derlenip açıldı.
