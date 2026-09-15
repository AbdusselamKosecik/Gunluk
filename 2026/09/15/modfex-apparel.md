# modfex-apparel — 2026-09-15

## Bağlam
5 Avalonia iskeleti (bantsayim, bantdurumekrani, depo, paketleme, sevkiyat) "Ilk iskelet" durumunda.
Hedef: referans WPF uygulaması (`X:\Gitlab\fredericTr\paketlemevesevkiyat\PaketlemeVeSevkiyat`) ve
`İç Giyim Üretim Planlama Uygulaması` tasarımları baz alınarak tüm uygulamaların tasarımını çıkarmak (brainstorming).

## Yapılanlar

### 1. İnceleme (salt okuma)
- **Neden:** Tasarım kararları referans uygulama, tasarım dosyaları ve Sentez DB gerçeğine dayanmalı.
- **Ne yapıldı:** 3 paralel inceleme:
  - Referans WPF: Meta_User MD5(UTF-16LE, trim, büyük hex) login; Erp_Box/BoxItem/BoxItemVariant; SP'ler
    `UZM_Sevkiyat_BarcodeProcess(2)`, `UZM_Sevkiyat_BoxRead`, `UZM_Sevkiyat_Sayim_BoxRead` (gövdeleri repoda yok);
    1. kalite = siparişe bağlı koli, "Tekleme" (…TEK01) = 2K-Giyilebilir/2K-Giyilemez/3K; siyah+beyaz ikili mantığı YOK;
    sevk irsaliyesi ReceiptType 120; tartı seri port (`+ 45.32kg`, `= 1.12F`); Output.prn raw etiket (repoda yok).
  - Tasarım: Suite sekme 3 Hammadde, 4 Bant Kabul, 5 Paketleme, 6 Sevkiyat (açık tema, #b4457a, IBM Plex);
    TV Panosu 4 döner ekran (koyu tema, bant kartları % renkli). Login ve dil seçici tasarımda yok.
  - DB ModaSima2026 (100.73.123.69, sadece SELECT): `Sentez/147963` hash doğrulandı (4EC62C40979EF55034807B9E2E1B044B);
    referansın UD_ kolonları ve UZM_Sevkiyat_* SP'leri YOK; sipariş–iş emri bağlantısı boş; Erp_RecipeItem 30.440 satır;
    sentezservis Sentez login kullanmıyor (kendi kullanicilar tablosu, Argon2id).
- **Komutlar:**
  ```bash
  sqlcmd -S 100.73.123.69 -U sa -P "***" -d ModaSima2026 -C -W -Q "SELECT ... FROM sys.tables ..."
  ```

### 2. Tasarım kararları ve spec
- **Ne yapıldı:** Soru-cevapla kararlar alındı, 8 bölüm tek tek onaylandı, spec yazıldı.
- **Dokunulan dosyalar:** `bantsayim/docs/superpowers/specs/2026-09-15-modfex-uretim-uygulamalari-design.md`
- **Commit:** bantsayim `862d0c4` — Modfex uretim uygulamalari tasarim dokumani (spec)

## Kararlar
- Doğrudan SQL (API yok); iş kuralları `UZM_` stored procedure'lerde (yaklaşım A).
- Veri: Sentez tabloları + UD_ kolonları + UZM_ tabloları (UZM_Ayar, UZM_Bant, UZM_BantKabul, UZM_Paketleme, UZM_HammaddeIs, UZM_KoliAcma, UZM_SetEslesme, UZM_Mesaj, UZM_DbSurum).
- Sipariş = Erp_OrderReceipt, Order = Erp_WorkOrder. Aynı kombinasyon için ikinci kayıt yok (UNIQUE index).
- Bantlar UZM_Bant. Bant kolisi kapanınca üretimden giriş fişi (Bant ara depo).
- Paketleme: Box Aç = bant kolisi okut (siyah ve beyaz order kolileri); siyah/beyaz barkod okutunca aynı bedende açık siyah+beyazdan 1 set;
  set ayrı stok kartı, bileşenler Sentez reçetesinden; kalite anahtarı 1K/2K-G/2K-GZ/3K, 2K/3K da set olarak ayrı kutuya.
- Hammadde: iş emrine bağlı Sentez fişi, onay UD_ alanlarında.
- Ortak kod her repoya kopya (`Ortak/`, SURUM.txt). TR/EN/AR her ekranda, AR RTL.
- Donanım: Android el terminali (klavye gibi okuyucu), seri port tartı (Desktop), ağ etiket yazıcısı TCP 9100.
- TV "Giren" = banta atanmış order adedi. bantdurumekrani girişsiz, salt-okuma view'ler.
- Geliştirme DB: ModfexTest (ModaSima2026 kopyası). Canlıya DDL yok.
- Elle adet ekleme yok (sadece barkod).

## Açık kalanlar / sonraki adım
- Kullanıcı spec'i gözden geçirecek; onaydan sonra writing-plans ile 1. adım (ModfexTest + temel şema) planı.
- ModfexTest kopyasını kim açacak (kullanıcı mı, ben mi) netleşmedi.
- Doğrulanacaklar: ReceiptType numaraları, reçete/set bileşen yapısı, lot tablosu, şoför TC alanı.
