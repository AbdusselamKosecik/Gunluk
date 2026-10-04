# paketleme — 2026-10-04

## Bağlam
03.10'da yazılan spec (`docs/superpowers/specs/2026-10-03-paketleme-etiket-koli-design.md`, `7c8cf09`) kullanıcı tarafından
onaylandı ("bu şekilde yapalım"). Bu tur: uygulama planı (writing-plans). Kod yok.

## Yapılanlar

### 1. SentezCore doğrulamaları (salt-okuma, `uzman`)
- **Neden:** Planı tahminle değil gerçek şemayla yazmak.
- **Komut:** scratchpad `db.ps1` (ayarlar.json'daki DPAPI şifresi çözülür, System.Data.SqlClient ile sorgu; `Fark` fonksiyonu iki kaydın
  farklı kolonlarını listeler).
- **Bulgular:**
  - 10 fişi (731526) ↔ 130 fişi (731509): başlık/kalem/varyantta tek anlamlı fark depo yönü (10: `InWarehouseId`, 130: `OutWarehouseId`).
    → bantsayim `FisSql.cs` VALUES satırları 240/681/967 (`OutWarehouseId` = NULL) `@OutWarehouseId` yapılarak paylaşılır.
  - `Erp_Box.OrderReceiptId`, `Erp_BoxItem.OrderReceiptItemId`, `Erp_BoxItemVariant.OrderReceiptItemVariantId` mevcut → UD_ gerekmez.
  - `Erp_InventoryTotal` kalite tutmuyor, `Erp_InventoryReceiptItemVariant`'ta `QualityTypeId` yok → kaliteli stok kalemden;
    NULL kalite 1K sayılır.
  - **Şirket 2'de satış siparişi (`ReceiptType=2`) yok**; 44 sipariş tip 1 = satın alma (FOSHAN, YIWU, aksesuar). Uygulama tip 2 kullanır.
  - Sipariş/box/fiş tablolarında NOT NULL + default'suz kolon yok → testler transaction içinde sahte satış siparişi ve stok fişi açabilir.
  - `uzman` CREATE TABLE yetkili → testler `UZM_KarmaKoli*` yoksa transaction içinde oluşturup ROLLBACK eder.

### 2. Plan
- **Dosya:** `docs/superpowers/plans/2026-10-04-paketleme-etiket-koli.md` (14 görev, TDD, her görev commit + push):
  1 Ortak SURUM 3 + test projesi · 2 şema `db/0001_paketleme.sql` + PaketAyarlari · 3 PaketKurallari · 4 tartı (V1/V2) ·
  5 FisYazici 10/130 · 6 karma koli/stok/sipariş sorguları · 7 okut/sil · 8 kapat (10+130) · 9 ürün etiketi 2×50×30 + Ortak SURUM 4 ·
  10 koli etiketi 10×10 · 11 eski ekranları sil + ana sayfa + etiket sekmesi · 12 koli listesi · 13 okutma/tartı ekranı · 14 canlı deneme + README.
- Spec §3'e bulgular eklendi.
- **Commit:** `576a7e6` — Paketleme: uygulama plani (14 gorev) + spec'e SentezCore bulgulari

## Kararlar
- Box tablolarına fiş bağı yazılmaz; `Erp_Box.InventoryReceiptId` sevkiyat irsaliyesine ayrılır (sevk edilmemiş tekli = InventoryReceiptId NULL).
- Etiket ölçüleri (50/30/2/0 mm) Ortak `Ayarlar`'a → Ortak SURUM 4 (diğer repolara taşıma ayrı iş).

## Açık kalanlar / sonraki adım
- Kullanıcı planı inceleyip yürütme yöntemini seçecek (subagent-driven / native).
- Sentez'de: paketleme deposu, en az bir satış siparişi, karma koli tabloları + tanımları.

## Ek — Plan yürütme (subagent-driven), dal `etiket-koli`

### Bağlam
Kullanıcı planı onayladı ("fişte sorun yok, takıl kafana göre"), etiket ölçüsü 2×50×30 kaldı. Yöntem: her görev için ayrı uygulayıcı
ajan + ayrı inceleyici, sonunda tüm dal için son inceleme (opus). Dal: `etiket-koli` (main'den 576a7e6), her görev GitLab'a push.

### Yapılanlar (commit'ler)
| Görev | Commit | Not |
|---|---|---|
| 1 Ortak SURUM 3 + test projesi | `0af1603` | System.IO.Ports 10.0.12 |
| 2 Şema + PaketAyarlari + TestVerisi | `561b13e` | `db/0001_paketleme.sql` canlı SentezCore'a uygulandı (`paketleme 0001 tamam`); UZM_Ayar PaketlemeDepoId=0, KoliDara=1.1; test stok fiş no 'TST'+NEWID (Erp_InventoryReceipt_IX0 unique: CompanyId,ReceiptType,ReceiptNo) |
| 3 PaketKurallari | `9e30a03` | |
| 4 Tartı okuyucu | `05c2d3c` | |
| 5 FisYazici 10/130 | `6d13b41` | FisSql bantsayim kopyası, OutWarehouseId 3 satır parametre |
| 6 Sorgular | `6fe83ee` | bileşen kaydı adı `KarmaBilesen` (eski `Bilesen` sınıfıyla çakışma) |
| 7 Okut/sil | `85681de` | |
| 8 Kapat | `2f78522` → `a4bfeef` | düzeltme: kapanışta yalnız bu kolinin set-bileşen ayrımı hariç tutulur, tekliler ayrılmış kalır |
| 9 Ürün etiketi + Ortak SURUM 4 | `94ce908` | |
| 10 Koli etiketi | `02b8d15` | |
| 11 Ana sayfa + Etiket sekmesi | `0cdc46c` | eski ekranlar silindi |
| 12 Koli listesi | `33ab4c7` | |
| 13 Okutma ekranı | `9e6b297` → `1447dad` | düzeltme: kapanış sonrası her durumda yenile, boş brüt engeli |
| 14 README | `4afca65` | canlı deneme ertelendi (ön koşullar kullanıcıda) |
| Son inceleme düzeltmeleri | `ea553ad` | F1 barkod kuyruğu (OkutmaKuyrugu — okutma sürerken gelen barkod düşmüyordu), F2 kapanış beklenen BoxId ile (`KoliDegisti`), F3 tanımı silinmiş set kapanmaz (`KarmaKoliTanimiYok`), F4 fiş kilidi bantsayim ile ortak `UZM_UretimFis` + 2601/2627'de 1 tekrar, F5 iptal fişleri stok dışı, F6 koli etiketinde çok model ayrı satır, F7 temizle.sql sırası, F8 yazıcı yoksa uyarı, F9 README işletme kuralları |

- **Testler:** birim 31 geçti; `MODFEX_DB_TEST=1` 53/53 (canlı DB, ROLLBACK).
- **Ortam notu:** alt ajanların test için açtığı `Paketleme.Desktop` süreçleri zombi kaldı, `Paketleme.Desktop/bin/Debug` kilitli → derleme `-o` ile başka klasöre; bilgisayar yeniden başlatılınca düzelir.

### Kararlar (ruling'ler)
- Şube `etiket-koli`; main'e birleştirme kullanıcı kararı.
- `@haric` yalnız set-bileşen ayrımı için (tekli ürün 42'de irsaliyeye kadar ayrılmış).
- Fiş numarası kilidi bantsayim ile ortak (`UZM_UretimFis`).
- Aynı sipariş+kalitede iki istasyon aynı koliyi paylaşır (spec); kapanış ekrandaki koliye bağlı. Ayrı istasyon kolisi istenirse ayrıca konuşulacak.
- 130 fişi kolinin kalitesiyle yazılır; 42'de NULL kaliteli stok şu an yok.
- `Erp_Box.PrintedAt/PrintedBy` SentezCore'da var (kontrol edildi).

### Açık kalanlar
- Canlı deneme (Task 14): paketleme deposu (RecId → `UZM_Ayar.PaketlemeDepoId`), en az bir satış siparişi (tip 2), sentezservis `UZM_KarmaKoli*` + tanımlar, yazıcı IP. Denemede salt-okuma: StokSorgusu ↔ `Erp_InventoryTotal` (42) karşılaştırması.
- `etiket-koli` → main birleştirme kararı.
- Mobil (Android) düzen: derleniyor ama cihazda denenmedi; 9 sütunlu tablolar dar ekrana uyarlanmadı — cihaz modeli soruldu.
- SentezSelvedge → Modfex taşıma: tasarım sunuldu, onay ve SQL login (ayrı login / `uzman`) kararı bekleniyor.
