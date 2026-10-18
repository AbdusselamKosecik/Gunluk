# malkabul — 2026-10-19

## Bağlam
Modfex Apparel paketine yeni Android uygulaması: **Mal Kabul**. Kumaş topları ve aksesuarlar
depoya seri numarasıyla alınıyor. Kamyon boşaltılırken her top için barkod basılıyor, sonra rafa konuyor.
Tedarikçinin topun üstüne yazdığı lot numarası da giriliyor.
Kullanıcının tarifi: "mal alım siparişini seçeceğiz, satırı seçeceğiz, miktar girip seri oluşturacağız."
Kısıtlar:
- Kesim ve tahsis tarafına **dokunulmaz**.
- Yalnızca seri kartı yazılır: UZM tablosu, fiş ve seri hareketi açılmaz ("kafana göre şey açıp karıştırma").

Repo: `git@gitlab.com:modfex-apparel/malkabul.git` (yerel `X:\Gitlab\modfex-apparel\malkabul`, dal main).

## Yapılanlar

### 1. İskelet: sevkiyatmobil kopyası
- **Neden:** Giriş, ayarlar, kabuk, çeviri ve Android ayarları (PM66, 480×800) hazır ve denenmiş durumda.
- **Ne yapıldı:**
  - Scratch `iskelet.py` ile sevkiyatmobil kopyalandı.
  - Adlar değiştirildi: SevkiyatMobil→MalKabul, sevkiyatmobil→malkabul, `com.modfex.sevkiyatmobil`→`com.modfex.malkabul`. Android Label "Mal Kabul".
  - Sevk ekranları, `Ekranlar/Veri/*`, db/, docs/ ve sevk testleri silindi.
  - Kalanlar: Ortak/*, Stiller.axaml, GeriBildirim.cs, Yon.cs.
- **Komut:** `python iskelet.py <kaynak sevkiyatmobil> <hedef malkabul>`. Kopyalayıp yeniden adlandırır, bin/obj/dagitim/.git'i atlar.

### 2. Veri katmanı (`MalKabul/Ekranlar/Veri/`)
- `MalKabulModelleri.cs`:
  - `SiparisOzet`, `SiparisSatiri` (Serilenen, SeriSayisi, MiktarMetni "serilenen / sipariş birim", Tamam), `OlusanSeri`.
  - `MalKabulHatasi(anahtar, değerler)`.
- `MalKabulKurallari.cs`:
  - `EnFazlaAdet = 100`.
  - `SonrakiSeriKodu`: 8 haneli sıra (D8).
  - `Aciklama(no, satır) = "SAS {no}/{satır}"`.
  - `Dogrula(miktar, adet)`: "," ve "." ondalık ayıracı kabul eder.
- `MalKabulDeposu.cs`:
  - `SiparislerAsync`:
    - Getirir: `Erp_OrderReceipt` ReceiptType=1, kapalı / iptal / silinmiş olmayan, TOP 60.
    - Arama: ReceiptNo veya tedarikçi adı.
  - `SatirlarAsync`:
    - Satır ölçüsü: `Erp_OrderReceiptItem` × `Erp_OrderReceiptItemVariant`.
    - Birim: `Meta_UnitSetItem.UnitCode`.
    - Varyant adı: `Erp_InventoryVariant.Variant1Id/2Id` → `Erp_VariantItem.ItemCode`.
    - Serilenen: OUTER APPLY ile `Erp_InventorySerialCard` toplamı. Koşul: Explanation = `'SAS '+ReceiptNo+'/'+ItemOrderNo`, InventoryId/VariantId eşit, IsDeleted=0.
  - `SeriOlusturAsync`:
    - Transaction açar, `sp_getapplock 'UZM_MalKabulSeri'` alır.
    - Şirketteki 8 haneli kodların MAX(SerialCode) değerinden sıra devam eder.
    - Her seri için `Erp_InventorySerialCard` INSERT: Quantity=miktar, PartyNo=lot (boşsa NULL, en çok 50 karakter, aşarsa `LotUzun`), IsMainSerial=1, InUse=1, UsedQuantity=0, Explanation="SAS no/satır". `OUTPUT INTO @t` ile okunur.
    - **Başka tabloya yazılmaz.** Tabloda lot kolonu yok, bu yüzden PartyNo kullanıldı.
  - Dapper eşlemesi sınıfla yapılıyor (`YeniKart`). Android release trimming büyük ValueTuple'ı bozuyordu (sevkiyatmobil 18d dersi).
- `SeriEtiketi.cs`:
  - ZPL `^CI28`, ölçü mm→dot.
  - Sol: stok kodu, ad, varyant ve Code128 seri (yorum satırıyla).
  - Sağ: "Lot", miktar+birim, "SAS no/satır", tarih.
  - Metindeki `^` ve `~` temizlenir.
- `Ortak/Donanim/ZplYazici.cs`: bantsayim'dan alındı, tek yazıcıya indirildi (TCP 9100, 5 sn).
- `Ayarlar` alanları: `YaziciIp`, `YaziciPort`=9100, `YaziciDpi`=203, `EtiketGenislikMm`=100, `EtiketYukseklikMm`=50. Ayarlar ekranında (CihazAyarlari) düzenlenir.

### 3. Ekranlar (`MalKabul/Ekranlar/`)
- **SiparisListe:**
  - Arama kutusu ve yenile düğmesi.
  - Liste kartı: sipariş no, tarih, tedarikçi, satır sayısı.
  - Arama yazılırken eski sonuç `_sira` sayacıyla atılır.
- **SatirListe:**
  - Üstte sipariş kartı.
  - Satır kartı: no, stok kodu, ad, varyant, "N seri", "serilenen / sipariş birim". Tamamlanan satır yeşil.
  - Geri dönünce yenilenir.
- **SeriGiris:**
  - Girdiler: Miktar (her seri), Kaç seri (top/paket), Lot.
  - "SERİ OLUŞTUR + ETİKET BAS" seriyi yazar, sonra etiketleri basar. İlk yazıcı hatasında durur. IP yoksa `YaziciTanimsiz` uyarısı verir.
  - Miktar ve lot ekranda kalır, adet 1'e döner (bir sonraki top için).
  - Alttaki listede satırın serileri ve "Bas" (tekrar bas) düğmesi var.
- Metinler TR/EN/AR (`UygulamaMetinleri.cs`).

### 4. Testler (`MalKabul.Tests/`)
- `MalKabulTestleri.cs`:
  - Kural testleri ve ZPL testi.
  - Canlı DB testleri (ROLLBACK): açık siparişler/satırlar; 2 seri × 48,5, lot " L-2231 ". Kontroller: kodlar sıralı, alanlar doğru, Serilenen +97, liste.
- `EkranGoruntusuTestleri.cs`: headless Skia ile üç ekranı örnek veriyle 480×800 PNG'ye çizer (yalnız `MODFEX_TEST_CIKTI` verilirse). Görsel kontrol yapıldı, düzgün.
- **Komutlar:**
  ```bash
  cd X:/Gitlab/modfex-apparel/malkabul
  MODFEX_DB_TEST=1 MODFEX_SUNUCU="tcp:100.119.104.122,1433" dotnet test MalKabul.Tests   # 15/15
  MODFEX_TEST_CIKTI=<klasör> dotnet test MalKabul.Tests --filter "FullyQualifiedName~EkranGoruntusu"
  ```
  Bugün 192.168.0.2 erişilemiyordu, bu yüzden `MODFEX_SUNUCU` ile Tailscale adresi kullanıldı. Ayar dosyasına yazılmaz, yalnız bellekte.

### 5. Git ve APK
- **Komutlar:**
  ```bash
  git init -b main && git remote add origin git@gitlab.com:modfex-apparel/malkabul.git
  git add .gitignore Directory.Packages.props MalKabul.slnx MalKabul MalKabul.Android MalKabul.Desktop MalKabul.Tests
  git commit && git push -u origin main      # proje push ile oluştu
  dotnet publish MalKabul.Android -c Release -f net10.0-android
  cp MalKabul.Android/bin/Release/net10.0-android/publish/com.modfex.malkabul-Signed.apk dagitim/malkabul-2026-10-19.apk
  ```
- **Sonuç:**
  - APK 71 MB, `dagitim/` içinde (gitignore'da).
  - El terminaline henüz kurulmadı, kullanıcıya soruldu.
- **Commit:** `658a586` — Mal Kabul mobil uygulaması: satın alma siparişi → satır → miktar/lot ile seri + etiket

## Kararlar
- Lot → `PartyNo`, çünkü seri kartında lot kolonu yok.
- Sipariş bağı → `Explanation = "SAS no/satır"`. Serilenen miktar bu açıklamadan hesaplanır. Fiş açmama kuralı yüzünden başka bağ alanı yok.
- Seri kodu 8 haneli sıralı. Mevcut test serileri 00000001–00000050 olduğu için devamından gider. Çakışmayı applock önler.
- Sipariş miktarını aşmak engellenmedi, gelen fazla mal da serilenebilir. Satır yalnızca yeşile döner.

## Açık kalanlar / sonraki adım
- PM66'ya kurulum: `adb install -r dagitim/malkabul-2026-10-19.apk`. Cihazda Ayarlar'dan Zebra IP'si girilecek.
- Gerçek etiketle ölçü ve yerleşim denemesi (100×50 mm varsayıldı).
- Hangi toptan parça alındı / kontrol edildi kaydı ilk istekte vardı, bu sürümde yok. Kullanıcı isterse ayrı adım.
