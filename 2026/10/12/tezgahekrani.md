# tezgahekrani — 2026-10-12

## Bağlam
Kullanıcı: "tezgah ekranı için bir uygulama yazman lazım, yeni proje olarak ekle. Tezgahta bekleyen ürünler, tezgaha
alınacak ürünler, paketlenen ürünlerin sayısı (tekli, paket sayısı), depoya alınan ürün sayısı. Tezgahtakilerde gün sınırı
yok ama paketlenen ve depoya işlenenlerde sadece ilgili günü göstersin." Veri kaynağı paketleme `db/0002_tezgah.sql`.

## Yapılanlar

### 1. Repo + tasarım
- **Ne yapıldı:** `X:\Gitlab\modfex-apparel\tezgahekrani` `git init -b main`, remote `git@gitlab.com:modfex-apparel/tezgahekrani.git`
  (push ile oluştu). Spec `docs/superpowers/specs/2026-10-12-tezgahekrani-design.md`.
- **Commit:** `4ab2b78` — Tasarim: tezgah ekrani

### 2. Uygulama (alt ajan, inceleme bende)
- **Neden:** paketleme tezgahını TV'de büyük göstermek; salt okunur.
- **Ne yapıldı:** iskelet `bantdurumekrani`'dan (Avalonia 12.1.2, .NET 10, `Ortak/`), Android yok.
  - `Ekranlar/Veri/TezgahVeriKaynagi.cs`: kurulum kontrolü + 4 bölüm tek batch, NOLOCK. Alınacak = `UZM_UretimBox Durum=1`
    ve `UZM_TezgahBox`'ta olmayan (son 30 gün, en çok 200 satır; toplamlar tümü). Paketlenen = `UZM_PaketKoli KapanisAt` bugün;
    depoya alınan = `MamulAt` bugün.
  - `PanoOzeti.cs` saf biçimleme/sıralama/"+N daha" (TDD, 42 birim testi).
  - 2×2 pano, 1920 tabanlı ölçek (1366×768 ve 1920×1080 kaydırmasız), hata şeridi son veriyi tutar, tablolar yoksa
    "Tezgah tabloları kurulmamış" ve kurulunca kendiliğinden açılır. Yenileme `UZM_Ayar.TezgahEkraniYenilemeSn` (10).
  - "Beni hatırla" otomatik giriş (Windows DPAPI, Linux 0600 dosya). Kiosk betikleri bantsayim'den; `paketle-linux.sh`.
- **Komutlar:**
  ```bash
  dotnet test                      # 42 geçti, 4 atlandı
  MODFEX_DB_TEST=1 dotnet test     # 44 geçti, 2 atlandı (tezgah tabloları kurulunca çalışır)
  ./paketle-linux.sh               # dagitim/tezgahekrani-linux-x64.tar.gz
  ```
- **Commit:** `c3f0261` — Tezgah ekrani: 2x2 pano

## Açık kalanlar
- `db/0002_tezgah.sql` çalıştırılınca 2 DB testi ve gerçek veri görülmeli.
- TV'de ve Linux kiosk'ta denenmedi.
