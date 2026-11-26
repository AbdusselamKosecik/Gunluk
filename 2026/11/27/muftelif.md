# muftelif — 2026-11-27

## Bağlam
OrderTakipWeb (MFG Genel Takip) için yeni talep + iki ekran görüntüsü (`OrderTakipEkkran.jpeg`, `HaftalikTakip.jpeg`):
1. 2. Kalite ve Numune sistemden (Sentez) gelsin; mevcut "kurtarma girişi = 2. kalite" mantığı Ürün Kurtarma kartına taşınsın.
2. Haftalık Tamir modülü: Yıkama/Finish sekmeleri, hafta seçimi, order bazlı gelen/çıkan/kalan, sonraki hafta
   çıkışları giriş haftasına yansısın, "sadece tamirde kalanlar" filtresi, veriler otomatik.

## Yapılanlar

### 1. 2. Kalite / Numune Sentez'den, Ürün Kurtarma kartı
- **Neden:** 23.11'de 2. kalite ve numune eşlenmemişti; kullanıcı sistemden istedi.
- **Kaynak bulma:** Canlı DB (192.168.1.22) erişilemedi. Repo'da arandı: `Selvedge/src/Selvedge.Application/Sentez/Overview/DashboardOverviewService.cs`
  ReceiptType=10 mamul girişi: depo 5 = 1. kalite, **23+24 = 2. kalite**, 25 = 3. kalite, **18 = numune**.
- **Ne yapıldı:** `OrderKaynak.BaslikSql`'e iki alt sorgu (`Erp_InventoryReceiptItem` + başlık `IsCancelled<>1`, `InWarehouseId IN (23,24)` / `= 18`).
  `Kalite` kaydı → `(Cut, First, Second, Recovery, Sample, Remaining)`; Kalan = kesim − 1.K − 2.K − numune; kurtarma Kalan'ı değiştirmez.
  Arayüzde 6 kart (Kesim, 1.K, 2.K, Ürün Kurtarma, Numune Ayrılan, Kalan), ≤359 px'te 3 sütun.
- **Dokunulan dosyalar:** `OrderTakipWeb/api/Takip/OrderTakip.cs`, `OrderKaynak.cs`, `api/wwwroot/index.html`, `tests/GenelTakipKabulTests.cs`

### 2. Haftalık Tamir modülü
- **Ne yapıldı:** `api/Takip/HaftalikTamir.cs` (saf): ISO hafta aralığı; order başına giriş partileri tarih sırasıyla,
  toplam çıkış bunlara **FIFO** dağıtılır; haftada girişi olan orderlar listelenir. Girişi aşan çıkış yazılmaz.
  `IOrderKaynak.TamirHareketleriAsync(from,to)`: CTE ile haftada 757/758 girişi olan iş emirleri → tüm tamir hareketleri.
  `GET /api/tamir/haftalik?yil=&hafta=` (Yıkama+Finish tek yanıt). Arayüz: 4. menü "Haftalık Tamir", sekmeler, hafta
  açılır listesi + ‹ ›, 3 özet kart, tablo + Toplam satırı, toggle filtre; satır → Order Takip Tamir sekmesi.
  Demo verisi: 95360/95410/95516/95620 (45. hafta Yıkama 161/138/23).
- **Dokunulan dosyalar:** `api/Takip/HaftalikTamir.cs`, `api/Takip/OrderKaynak.cs`, `api/Program.cs`, `api/wwwroot/index.html`,
  `tests/HaftalikTamirTests.cs`, `README.md`
- **Komutlar:**
  ```bash
  cd OrderTakipWeb && dotnet test OrderTakipWeb.slnx      # 53/53
  cd api && OrderTakip__DemoVeri=true OrderTakip__GirisGerekli=false ASPNETCORE_URLS=http://localhost:5187 dotnet run --no-launch-profile
  ```
- **Sonuç / doğrulama:** 53/53. Chrome 390 px demo: kartlar ekran görüntüsüyle aynı düzen, 45. hafta tablo doğru,
  filtre 3 satır bıraktı, Finish 22/17/5, satır tıklama Tamir sekmesini açtı, sonraki arama Üretim'e döndü, yatay taşma yok.
- **Hata/Not:** Bash heredoc içinde backtick'li Python yaması "unexpected EOF" verdi → yama betiği Write ile dosyaya yazılıp çalıştırıldı.
- **Commit:** `83a02b2` — feat(order-takip-web): 2. kalite ve numune Sentez'den, Urun Kurtarma karti, Haftalik Tamir

## Kararlar
- Çıkış tarihi dağıtımı etkilemez (saf FIFO): Finish Tamir'de çıkış girişten önce gelebiliyor (19.11 analizi), bu yolla yine dengelenir.
- Haftalık "Gelen" = tamir departmanına giriş (InOut 1), "Çıkan" = çıkış; Order Takip Tamir sekmesiyle aynı yön kuralı.
- Kalan'dan numune düşülür, kurtarma düşülmez.

## Açık kalanlar / sonraki adım
- Canlıda doğrulanmadı: depo 23/24/18 bir orderda Sentez ekranıyla karşılaştırılmalı; haftalık sorgu süresi ölçülmeli.
- Numune Bulma ekranı hâlâ bağlı değil (lokasyon/açıklama kaynağı yok).
- Yeni IIS paketi çıkarılmadı (`Deploy-IIS.ps1 -Paket`) — kullanıcı isterse.
