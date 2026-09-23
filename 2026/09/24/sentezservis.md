# sentezservis — 2026-09-24

## Bağlam
23.09 madde 9'un devamı: pazaryeri cari/sipariş aktarımı SentezCore2026Test'e. Kullanıcı sorusu:
"e-arşivlerde EInvoiceAlias boş gelmesi lazım değil mi? e-faturalarda VKN'ye göre e-fatura kontrolü
yapan gerekecek".

## Yapılanlar

### 1. EInvoiceAlias ve e-fatura mükellefiyet kontrolü
- **Neden:** Kullanıcı sorusu (yukarıda).
- **Bulgular:**
  - Kod e-arşivde de e-faturada da `EInvoiceAlias=NULL` yazıyor. Canlı ERP'de 2025'te bu alanda müşterinin
    pazaryeri e-postası vardı (230.966 e-arşiv carisi); Ağustos 2026'dan beri hepsi boş, e-fatura dahil.
  - Mükellefiyet kontrolü (CRS `IsEInvoiceUser`, yalnızca 10 haneli VKN, 12 saat önbellek) zaten vardı,
    ama hiç çalışmıyordu. Yedekteki 4.317 carinin tamamında `vkn_tckn` NULL. Sebep: Trendyol'da kod
    `taxNumber`/`tcIdentityNumber` okuyordu; gerçek alan kökteki `identityNumber` (34.493'ü 11111111111,
    ~40'ı gerçek TCKN), kökteki `taxNumber` ise maskeli "***". 34.535 Trendyol siparişinde `commercial=true` yok.
  - CRS'e ulaşılamazsa cari `bilinmiyor` durumunda e-arşiv olarak yazılıyordu.
  - Canlıda Ağustos'tan beri e-fatura carisi: yalnızca 5 HB/HBT (10 haneli VKN) ve 329.x.
- **Ne yapıldı:**
  - `TrendyolSaglayici.KimlikNo`: ilk tamamen rakamdan oluşan değer (fatura adresi taxNumber → kök
    taxNumber → identityNumber → tcIdentityNumber).
  - `PazaryeriCariAktarJob`: `Bilinmiyor` durumundaki cari yazılmıyor, `bekliyor`'da kalıyor, özet mesajında
    "ertelendi" olarak görünüyor.
  - `docs/pazaryeri-carileri.md` güncellendi.
- **Dokunulan dosyalar:** `src/SentezServis.Core/Pazaryerleri/Saglayicilar/TrendyolSaglayici.cs`,
  `.../Cariler/PazaryeriCariAktarJob.cs`, `tests/.../CariUretimTestleri.cs`, `tests/.../CariYaziciSinirTestleri.cs`.
- **Sonuç / doğrulama:** `dotnet test tests/SentezServis.Core.Tests` → 602/602.
- **Commit:** `8a0ad57` — E-fatura kontrolu: Trendyol kimlik no okunur, CRS cevapsizsa cari ertelenir
- **Not:** Değişiklik, yeniden çekilecek siparişlerde etkili olur; paket henüz yeniden alınmadı.

## Açık kalanlar / sonraki adım
- Kullanıcı kararı: TCKN (11 hane, şahıs firmaları) de CRS'e sorulsun mu? Şu an yalnızca 10 haneli VKN soruluyor.
- Kullanıcı kararı: e-fatura carisinde `EInvoiceAlias`'a GİB posta kutusu etiketi yazılsın mı? Canlı boş bırakıyor.
- Boyner'de 102 siparişin tamamı `kurumsal_fatura=1`; şüpheli, bakılmadı.
- SentezCore2026Test temizliği: cari DELETE'i 29. dakikada hâlâ sürüyordu.
