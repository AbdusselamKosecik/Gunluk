# kesimhane — 2026-09-04

## Bağlam
Kesimhane WPF uygulamasında (FastReport + PdfiumViewer ile kart basımı) operatör her seri kartı
okuttuğunda uygulama ana iş parçacığında raporu hazırlayıp PDF'e çevirip yazıcıya gönderiyor; bir
sonraki kart okutma penceresi ancak yazdırma bitince açılıyordu. İstek: kart okutma yazdırmayı
beklemesin, hızlıca ardı ardına okutulabilsin.

## Yapılanlar

### 1. Yazdırmayı arka plan kuyruğuna al
- **Neden:** `KartBas()` döngüsünde `PrintForm` senkron çağrılıyor, `Report.Prepare` + PDF export +
  `PrintDocument.Print` UI'ı kilitliyordu.
- **Ne yapıldı:**
  - `PrintForm(WorkOrderProductionModel)` → `PrintForm(DataSet printData)`; paylaşılan `PrintData`
    yerine verilen kopya ile rapor verisi kaydediliyor.
  - `EnqueuePrint(DataSet snapshot)` eklendi: `_printChain = _printChain.ContinueWith(...)` ile
    kilit altında sıralı Task zinciri (kartlar okutma sırasıyla basılır, paralel yazıcı çakışması yok).
  - Çağrı noktası: `EnqueuePrint(PrintData.Copy())` — her kart için DataSet anlık kopyası, çünkü
    döngü aynı `dr` satırını (`Seri`, `ProductionLine`) ve `wf` tablosunu bir sonraki tur için değiştiriyor.
  - `ShowError` yardımcı metodu: arka plan iş parçacığından `MessageBox` için `Application.Current.Dispatcher.BeginInvoke`.
  - `using System.Threading.Tasks` eklendi.
- **Dokunulan dosyalar:** `kesimhane/ViewModels/OrderDetailViewModel.cs`
- **Komutlar:**
  ```bash
  dotnet build kesimhane/kesimhane.csproj -c Debug   # Build succeeded
  ```
- **Sonuç / doğrulama:** Derleme başarılı. Sahada test: kart okut → SeriCard penceresi anında
  tekrar açılmalı, kartlar sırayla yazıcıdan çıkmalı.
- **Commit:** `ac655ed` — Kart okutma ile yazdirmayi ayir: yazdirma arka plan kuyrugunda calisir

## Kararlar
- Tam paralel yazdırma yerine **sıralı kuyruk** seçildi: yazıcı çıktı sırası okutma sırasıyla aynı
  kalsın, yazıcıya aynı anda birden fazla iş gitmesin.
- DB insert (`Erp_WorkOrderProduction`) yazdırmayı beklemiyor; okutmalar bitince hemen kaydediliyor.

## Açık kalanlar / sonraki adım
- Yazdırma hataları artık modal olmayan MessageBox ile geç gösterilir; operatör eğitimi gerekebilir.

### 2. Kapanışta bekleyen yazdırma işlerini tamamla
- **Neden:** Madde 1'de açık kalan konu: uygulama kapatılırsa kuyruktaki kartlar kaybolabiliyordu.
- **Ne yapıldı:**
  - Yeni `Services/CardPrintQueue.cs`: uygulama geneli statik sıralı kuyruk (`Enqueue`, `WaitAll(timeout)`,
    `HasPending`). Adı `PrintQueue` olamadı; `System.Printing.PrintQueue` ile çakışıyor.
  - `OrderDetailViewModel.EnqueuePrint` artık bu servisi kullanıyor (ViewModel içindeki Task zinciri kaldırıldı).
  - `App.xaml.cs`: `OnExit` override; bekleyen iş varsa en fazla 2 dk beklenip çıkılıyor.
- **Dokunulan dosyalar:** `kesimhane/Services/CardPrintQueue.cs`, `kesimhane/App.xaml.cs`,
  `kesimhane/ViewModels/OrderDetailViewModel.cs`
- **Sonuç / doğrulama:** `dotnet build` başarılı.
- **Commit:** `8ea29dd` — Uygulama kapanisinda bekleyen kart yazdirma islerini tamamla
