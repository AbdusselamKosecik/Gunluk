# paketleme — 2026-10-12

## Bağlam
Kullanıcı yeni paketleme akışını tarif etti: bant sonunda kapanan tekli ara üretim box'ları paketlemede "tezgaha dökülür",
siparişteki ürün okutulup adet yazılır, teraziden ağırlık alınır, 10×10 etiket (adres, order, model, içindekiler, QR) basılır,
koli U depoya (42) girer; sonra el terminaliyle Mamul'e (41), sevkiyatta 120. Ayrıca tezgah ekranı için yeni proje istendi.
`/loop 15m maddeleri konuştuğumuz gibi bitir` ile otonom tamamlama istendi. Evden çalışıldı: SQL `100.119.104.122` (Tailscale).

## Kararlar (kullanıcı, sohbette)
- Sipariş ürünü = üretilen ürün → fiş yok; farklı (set) → bileşenler 130 ile 42'den, set 10 ile **42'ye** (önceden PaketlemeDepoId).
- Eşleştirme: sentezservis "Order yap" + karma koli tanımı zaten var (set → bileşen WO'ları).
- Box okutulunca tüm içerik **tek ortak tezgaha**, limitli. Sipariş önce seçilir, "YENİ SİPARİŞ" düğmesi.
- Terazi kararlılık işareti göndermez → ardışık okumalardan yakalanır.
- Mamul giriş: el terminali, **fiş 17** (Sentez'deki tek 17 kaydı başlık/kalem/varyantta In+Out ikisi dolu: depo transferi).
- Etikette QR + (lazer okuyucu QR okuyamadığı için) aynı kodla Code 128.

## Yapılanlar

### 0. Ofis/ev IP
- **Neden:** "şu an evdeyiz ip'yi ev için olana çek". 192.168.0.2 evden erişilemiyor, 100.119.104.122 (Tailscale) erişiliyor.
- **Ne yapıldı:** `%LOCALAPPDATA%\Modfex\paketleme\ayarlar.json` ve `...\sevkiyat\ayarlar.json` `Sunucu` → `100.119.104.122`;
  ofis hâli `ayarlar.json.bak-ofis` yedekte. Ofiste geri almak için yedeği geri kopyala.

### 1. Tasarım
- `docs/superpowers/specs/2026-10-12-tezgah-paketleme-design.md` — commit `1190924`.
- Plan/kayıt: `docs/superpowers/plans/2026-10-12-tezgah-uygulama.md`.

### 2. Kararlı ağırlık — `a24bc3f`
- `Ekranlar/Veri/KararliAgirlik.cs`: son N okuma ≥ EnAzKg ve max−min ≤ tolerans → ortalama (2 hane). Null satır pencereyi
  bozmaz, sürüm 2 'D' sıfırlar. `TartiOkuyucu.DinleAsync` sürekli dinler (canlı, kararlı) bildirir.
- `PaketAyarlari` + `TartiAyari` (UZM_Ayar `TartiKararliSayi=5`, `TartiKararliTolerans=0.02`, `TartiEnAzKg=0.2`),
  `MamulDepoId=41`, `MamulFisTipi=17`; `PaketlemeDepoId` zorunlu değil.
- Testler: `KararliAgirlikTestleri` 9 (TDD, önce kırmızı).

### 3. db/0002_tezgah.sql + TezgahDeposu — `2c5413e`
- `UZM_TezgahBox` (BoxId UNIQUE, box bir kez dökülür), `UZM_TezgahHareket` (Islem 1 dök / 2 paketle / 3 düzelt / 4 geri al;
  bakiye = SUM), `UZM_PaketKoli.MamulFisId/MamulAt/MamulUserId`, ayarlar. **Canlıda çalıştırılmadı** (kullanıcı çalıştıracak):
  ```
  sqlcmd -S MODFEXSRV -d SentezCore -U uzman -P <şifre> -C -b -i db\0002_tezgah.sql
  ```
- `TezgahDeposu`: `DokAsync` (BoxType=1 + UZM_UretimBox Durum=1; ret BoxBulunamadi/BoxAcik/BoxZatenDokuldu/BoxBos),
  `DuzeltAsync` (sebep zorunlu, eksiye düşmez), `BakiyeListesiAsync`, `BantBoxuMuAsync`; kilit `sp_getapplock 'UZM_Tezgah'`.
- Testler: `TezgahTestVerisi` betiği test transaction'ı içinde uygular (ROLLBACK, canlıda iz yok — kontrol edildi), 8 DB testi.

### 4. Barkod + adet — `a624970`
- `KoliDeposu.OkutAsync(..., adet)`: tezgah kuruluysa limit tezgah bakiyesi (set: bileşen × adet), paketlenen tezgahtan
  düşer, sil iade eder; değilse eski 42 stok kontrolü (geri uyum). Kapanışta set 10 → `UretimDepoId`.
- Testler: `KoliTezgahTestleri` 6 (önce derleme kırmızı). Tüm suite `MODFEX_DB_TEST=1` → 98/98.

### 5. Koli etiketi — `b46e764`
- `ZplEtiket.Qr` (^BQN,2,m, `MA,` + veri). Etiket: SHIP TO + adres (Shipping → ShipTo → CustomerAddress → carinin varsayılan
  adresi; Line1–3 + PostalCode), ORDER · PO (`CustomerOrderNo`) · CARTON NO, MODEL (InventoryName), matris, TOTAL/GW/NW,
  alt Code 128 + okunur kod, sağ üst QR. Adres sorgusu canlıda söz dizimi doğrulandı (şirkette hiç Erp_Address yok).

### 6. Ekran — `002334c`
- Okut: bant box'ı → tezgaha dök; ürün → büyük adet sorusu (odak adet kutusunda, Enter=PAKETLE, Esc=iptal).
- Sağda TEZGAH paneli + ✎ düzeltme (± adet, sebep). Tablo "Tezgah" sütunu (set: çıkabilecek set sayısı).
- "🔄 YENİ SİPARİŞ": açık koli varsa reddeder (AcikKoliVar), yoksa listeye döner.
- Kapatma paneli açılınca terazi dinlenir; canlı kg, kararlı olunca yeşil ve brüt kendiliğinden dolar.
- TR/EN/AR metinleri. Derleme temiz; ekran canlı görülmedi (giriş şifresi + 0002 kurulumu gerekli).

### 7. README — `95fabc7`

## Açık kalanlar / sonraki adım
- Kullanıcı `db/0002_tezgah.sql`'i çalıştıracak; sonra ekran ve etiket baskısı ofiste denenmeli (yazıcılar evden erişilemez).
- Ofise dönünce `ayarlar.json.bak-ofis` geri alınmalı (ya da Ayarlar'dan sunucu 192.168.0.2).
- sevkiyatmobil (Mamul Giriş + 120) alt ajanla yazılıyor; tezgahekrani tamamlandı (`tezgahekrani.md`).

### 8. Bağımsız inceleme + düzeltmeler — `da07cb2`
- **Neden:** stok/tezgah mantığı kritik; 1190924..95fabc7 alt ajan (code-reviewer) ile incelendi. Kilit sırasında döngü yok,
  tezgah eksiye düşemez, adet hesabı/rollback/SQL/ZPL doğru bulundu.
- **Düzeltilen (düşük güvenli ama sahada olası):**
  - Adet sorusu açıkken başkasının okuttuğu barkod adet kutusuna düşüyordu → `PaketKurallari.BarkodGibi` (6 karakterden uzun
    ya da rakam dışı) ise bekleyen ürün iptal, uyarı `AdetYerineBarkod`, metin yeni okutma olarak kuyruğa (7 test).
  - Kapatma paneli açıkken sayfadan çıkılırsa terazi portu açık kalıyordu → `SayfaViewModel.Ayrildi()` + `KabukViewModel`
    eski sayfada çağırır; okutma ekranı dinleyiciyi durdurur.
- **Ertelenen:** SHIP TO'da şehir/ülke yok (SentezCore'da Erp_City/Erp_Country ad kolonu bulunamadı); SilAsync tek satıra bakar.
