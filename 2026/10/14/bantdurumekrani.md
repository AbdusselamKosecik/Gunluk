# bantdurumekrani — 2026-10-14

## Bağlam
TV panosunun 4 ekranında model/order/sipariş adları gerçekti, ama tüm ilerleme sayıları
(bant giren/çıkan/hedef, paketleme, sevk, order akış) `EkranAsamasiTvVeriKaynagi` içindeki demo
formüllerden geliyordu. Kullanıcı: "gercek verilerle yaparmisin" → "Ekranlar gerçek veri göstersin".

## Yapılanlar

### 1. Gerçek veri kaynağı (TvVeriKaynagi) + testler
- **Neden:** Panonun sahada anlamlı olması; demo sayılar yanıltıcı.
- **Ne yapıldı:**
  - `EkranAsamasiTvVeriKaynagi` (demo) silindi. Yerine `TvVeriKaynagi` geldi: tek batch SALT-OKUMA, NOLOCK.
    Statik `OkuAsync(SqlConnection, companyId)` testte doğrudan çağrılır.
  - Arayüz sadeleşti: `ITvVeriKaynagi.OkuAsync()` → `TvPanoVerisi` (Bantlar, Paketleme, Siparisler, Akis).
    ViewModel her yenilemede tek çağrı yapar.
  - Sorgular:
    - **Bant** (bugün = sunucu tarihi 00:00'dan):
      - Çıkan = net `UZM_UretimOkutma` (Islem 1 +, 2 −), bant = `UZM_UretimBox.BantNo` (BoxId ile).
      - Yapılan = kalite 1 net.
      - Model = bantta son okutulan ürün.
      - Giren = bantta bugün okutulan iş emirlerinin `Erp_WorkOrderItem.Quantity` toplamı. Bant kabul tablosu yok; geçici tanım bu.
    - **Hedef:**
      - `UZM_Ayar` anahtarı `BantSaatlikHedef` tüm bantlar için geçerli; `BantSaatlikHedef.N` N. bant için onu ezer.
      - Anlık hedef = saatlik hedef × `UZM_Calendars` bugünkü mesailerinde şimdiye kadar geçen dakika / 60.
        - DayOfWeek ISO: 1 = Pzt.
        - `ProductLineId` = bant no; banta özel mesai varsa genel mesainin yerine geçer.
      - Ayar yoksa kart nötr gösterilir (`TvPanel`, yüzde "—", "Hedef girilmemiş"). **Şu an ayar yok.**
    - **Paketleme / Order akış** (iş emri bazında): son 30 gün okutması olan ya da tezgah bakiyesi ≠ 0 olan iş emirleri.
      - Çıkan = tüm zamanların net okutması.
      - Paketlenen = −Σ `UZM_TezgahHareket.Miktar` (Islem 2 ve 4).
      - Bekleyen = max(0, çıkan − paketlenen).
      - Depoya giren = `MamulFisId` dolu kolilerin içeriği (`UZM_PaketKoli.WorkOrderId`).
      - Sevk = `UZM_SevkIrsaliye` fişinde `Erp_InventoryReceiptItem.BoxId` ile görünen kolilerin içeriği.
      - Dikime giren = planlanan iş emri adedi; Kalan = planlanan − sevk.
    - **Sipariş:**
      - Son satış siparişlerinden (ReceiptType 2) 12 tanesi; kolisi olanlar önce gelir.
      - Sevk ve depoda bekleyen, `UZM_PaketKoli.OrderReceiptId` kolilerinden hesaplanır.
  - Bağlantı koparsa son başarılı veri gösterilir, rozet "Bağlantı yok · son veri" olur, 30 sn'de bir yeniden denenir.
    Log satırına sunucu adı eklendi.
  - Yeni test projesi `BantDurumEkrani.Tests` (xunit; tezgahekrani kalıbı, `MODFEX_DB_TEST=1`):
    - `TvHesapTestleri` (6 birim): mesai dakikası, banta özel mesai, hedef ayarı önceliği, 10 kart, ayar yoksa hedef 0, ad sadeleştirme.
    - `TvVeriKaynagiTestleri` (2 canlı salt-okuma): tutarlılık; bant çıkışı = bugünkü net okutma.
- **Dokunulan dosyalar:**
  - `BantDurumEkrani/Ekranlar/Veri/TvVeriKaynagi.cs`
  - `BantDurumEkrani/Ekranlar/Veri/TvHesap.cs` (yeni)
  - `BantDurumEkrani/Ekranlar/TvPanoViewModel.cs`
  - `BantDurumEkrani/Ekranlar/UygulamaMetinleri.cs` (TvDemo silindi, HedefYok eklendi)
  - `BantDurumEkrani.Tests/*`
  - `BantDurumEkrani.slnx`
- **Komutlar:**
  ```bash
  dotnet test BantDurumEkrani.Tests                    # 6/6 (DB testleri atlanır)
  MODFEX_DB_TEST=1 dotnet test BantDurumEkrani.Tests   # 8/8
  ```
- **Sonuç / doğrulama:**
  - Uygulama açıldı, ekranda gerçek sayılar var.
    - Paketleme: çıkan 3.721, bekleyen 3.085, paketlenen 636.
    - İş emirleri: Test-005-2, 4315-2, Test-002, 4316-2.
  - Bant 2'de bugün 1934 net okutma var.
- **Commit:** `ac37e4f` — TV panosu gerçek veriyle: bant, paketleme, sipariş, order akış

## Kararlar
- Bant kabul (giren) tablosu yok. Giren = iş emri planlanan adedi. Bant kabul yazılınca değişecek.
- Hedef için ayar anahtarı açıldı ama **canlıya UZM_Ayar satırı yazılmadı.** Kullanıcı onayı ve rakam gerekiyor.
- Paketlenen tezgah birimiyle (bileşen) sayılıyor; depo ve sevk koli içeriğiyle (sipariş ürünü, set) sayılıyor.
  Set ürünlerde birimler farklı olabilir.

## Açık kalanlar / sonraki adım
- `BantSaatlikHedef` değerleri kullanıcıdan alınıp UZM_Ayar'a girilecek (izinle).
- **Ortam notu:**
  - Bu makinede `BantDurumEkrani.Desktop.exe` (apphost) SQL'e bağlanamıyor: Named Pipes / 1326 hatası, TCP oturumu yok.
  - Aynı dll `dotnet BantDurumEkrani.Desktop.dll` ile bağlanıyor.
  - Muhtemelen güvenlik duvarı veya güvenlik yazılımı yeni exe'yi engelliyor; kod sorunu değil.
