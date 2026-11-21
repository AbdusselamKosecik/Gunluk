# malkabul — 2026-11-21

## Bağlam
Gece 20.11'den devam. İstek: Tahsis ekranında siparişi olmayan ihtiyaçlara alım siparişi açılsın. Siparişler Sentez'in tahsisine bağlansın, karantina onayında seriler otomatik tahsis edilsin.

## Yapılanlar

### 1. Eksiklere alım siparişi + ihtiyaca bağlama
- **Kararlar (kullanıcı):**
  - Yer: Tahsis ekranı; düğme seçili order için çalışır.
  - Kapsam: eksik = ihtiyaç − siparişe bağlı.
  - Gruplama: tedarikçi başına bir sipariş, satır = ihtiyaç; order no satır açıklamasına ve `UD_OrderAraligi`'ya yazılır.
  - Tedarikçi stok kartının carisinden (`Erp_Inventory.CurrentAccountId`); boşsa 320.99.999 (RecId 625440). Kart carisi şu an 4197 kartın yalnız 26'sında dolu.
  - Fiyat 0, sipariş başlığı deposu WI01.
  - Tedarikçinin bu order'a bağlı, hareket görmemiş siparişi varsa "mevcuta ekle?" diye sorulur (onay kutusu, varsayılan işaretli).
- **Sentez yazımı:**
  - `Erp_OrderReceipt`: tip 1, UpType 2, ReceiptNo = MAX+1 (8 hane), SpecialCode `UZMTD`.
  - `Erp_OrderReceiptItem`, renk varsa `Erp_OrderReceiptItemVariant`.
  - `Erp_InventoryAllocation` (OrderReceiptType 1, OrderReceiptItemId, RequirementId, WorkOrderItemId).
  - Stok sipariş toplamlarını Sentez tetikleyicileri günceller.
- **Karantina onayı (fiş 17):** Seri, geldiği sipariş satırına bağlı ihtiyaca otomatik tahsis edilir (`TahsisDeposu.OtomatikTahsisAsync`).
- **Ekstra kuralı (`TahsisKurali.Ekstra`):**
  - Ekstra = ihtiyaç zaten dolu, ya da aksesuarda ihtiyacı aşıyor. Kumaşta son top ihtiyacı aşabilir.
  - Ekstra seri otomatik tahsis edilmez.
  - Elle tahsiste `EkstraSeriOnay` hatası döner; ekranda "Evet, tahsis et" onay çubuğu çıkar.
- **İhtiyaç satırı:** "Sipariş X · karantinada Y" bilgisi eklendi.
- **Dosyalar:**
  - Yeni: `Veri/TedarikSiparisDeposu.cs`.
  - Değişen: `TahsisDeposu.cs`, `KarantinaDeposu.cs`, `UretimDeposu.cs`, `TahsisViewModel.cs`, `TahsisView.axaml`, `UygulamaMetinleri.cs`.
  - Tasarım: `docs/superpowers/specs/2026-11-21-tahsis-siparis-acma-design.md`.
- **Testler:**
  - `TedarikSiparisTestleri` 8 test (DB, rollback).
  - `TahsisEkraniTestleri` +4 test.
  - Toplam 232/232.
- **Commit:** `251618f`.

### 2. Yan bulgu: ihtiyacın rengi
- Canlı `Erp_Requirement.InventoryVariantId` hiçbir satırda dolu değil; renk `Variant1Id`/`Variant2Id` alanlarında.
- Bu yüzden Tahsis ekranında gerçek order'larda renk boş görünüyor, uygun seriler renge göre süzülmüyordu.
- Çözüm: `TahsisDeposu.EtkinVaryant` (CROSS APPLY). Tahsis, uygun seri ve üretim eşleştirmesinde kullanılıyor.

### 3. Hata: gece 00:00–01:00 arası her okutma yeni fiş
- **Sebep:** Sunucu saati istemciden 1 saat geride. Mal kabul fiş başlığı istemci tarihiyle yazılıyor, "bugünkü fiş" araması ise `GETDATE()` ile yapılıyordu.
- **Bulunuş:** Gece yarısından sonra çalışan test paketinde 8 test kırıldı.
- **Düzeltme:** Arama `@bugun = DateTime.Today` ile yapılıyor (`MalKabulFisDeposu.BaslikAsync`).
- **Commit:** `251618f`.

## Kararlar
- Sentez sipariş tamamen gelince başlığı ve satırı kendisi kapatıyor (`IsClosed=1`). Mal kabul kapalı siparişi listelemiyor; bu doğru davranış.

## Açık kalanlar / sonraki adım
- Karantinada onaydan önce uygulamadan yapılan anketleri ve resimleri görmek istiyorlar (kullanıcı "haberin olsun" dedi; kaynak belirlenecek).
- PM66'ya yeni APK kurulmadı. Masaüstüne yeni build verilmedi (eski exe açıktı).
- 5a4dee0 kod incelemesi yarım.

### 4. Mal kabul standart anketi + karantinada inspection (anket ve resimler)
- **İstek:** Mal kabul inspection'ına standart kodlu bir anket eklensin. Karantinada onaydan önce anketler ve resimler görülsün.
- **Kararlar:**
  - Kullanıcı "başla" dedi; sorduğum soruları cevaplamadığı için önerdiğim gibi ilerledim.
  - Anket kodu `MALKABUL`; başlangıç sorularını ben önerdim.
  - Rapor yoksa onay engellenmez; uyarı + ikinci basış.
  - Eşleşme önce seriyle, olmazsa irsaliye + siparişle.
- **Selvedge (`41662a7`):**
  - `db/migrations/0031_malkabul_anket.sql`: anket QcStage 'Mal Kabul', 9 soru. Sorular: etiket uyumu, renk tonu, en, gramaj, görsel hata (Yok / Az / Çok), koku-nem, ambalaj, fotoğraf (zorunlu), not. Anket zaten varsa dokunulmaz.
  - Migration canlı Selvedge'de, geri alınan bir işlem içinde iki kez çalıştırılarak denendi; ikinci çalıştırmada kayıt eklemedi.
  - Mobil `qc_entry_screen.dart`: 'Mal Kabul' aşamasında önce `MALKABUL` yüklenir (FINISH deseni); bulunursa temel anket eklenmez. `flutter analyze` hata/uyarı vermedi.
- **Malkabul (`bf721b8`):**
  - `InspeksiyonDeposu`:
    - Malkabul bağlantısıyla `Selvedge.dbo` okunur (aynı SQL sunucusu).
    - `COL_LENGTH` ile 0030 kontrol edilir; yoksa ya da veritabanı okunamazsa `Hazir=false` döner ve karantina yine çalışır.
    - `InspeksiyonEslestirme` saf eşleştirme fonksiyonudur; malzemesi tutan rapor genel rapordan önce gelir.
  - Resimler `http://192.168.0.2:8085/api/attachments/{id}/view` adresinden gelir (anonim, yalnız raster). Canlıda ek 12 → 200 image/jpeg doğrulandı.
  - Karantina ekranı:
    - satırda rozet (rapor yok / Pass / Fail), rozete tıklayınca sağda anket cevapları ve küçük resimler; resme tıklanınca tarayıcıda açılır;
    - raporsuz ya da Fail kalem onayı ikinci basışla yapılır;
    - Selvedge hazır değilse uyarı bandı çıkar.
  - Selvedge adresi `UZM_Ayar.SelvedgeAdresi`'nden okunur; boşsa varsayılan kullanılır.
  - Testler: `InspeksiyonTestleri` 7; toplam 239/239.
- **Durum:**
  - Canlı Selvedge'de 0030 (mal kabul alanları) ve 0031 henüz yok; ikisi de Selvedge servisi yeniden yayınlanınca açılışta uygulanır.
  - O zamana kadar karantinada "Selvedge inspection bilgisi okunamıyor" bandı görünür.
  - Selvedge mobil APK'sı yeniden derlenip dağıtılmalı.

### 5. PM66'ya dağıtım
- Mal kabul `bf721b8` sürümü release APK olarak derlendi ve `adb install -r` ile kuruldu (ayarlar korundu). Uygulama açıldı.
  ```bash
  dotnet publish MalKabul.Android -c Release -o <dir>
  adb -s 1ed69882 install -r com.modfex.malkabul-Signed.apk
  ```
- Kullanıcı "PM99" yazdı; bağlı tek terminal PM66'ydı (`1ed69882`), o güncellendi. Cihaz saati EET, bizden 1 saat geride.

### 6. Terminal kullanım düzeltmeleri (PM66 geri bildirimi)
- **Sorunlar:**
  - Sayımda renk seçimi listesi aşağı taşıyor, kaydırılamıyordu.
  - Manuel (yeni seri / malzeme seç) arama boşken liste boş geliyordu.
  - Yer değiştir ekranındaki hedef yer kartı ekranın yarısını kaplıyordu.
- **Neden:**
  - Renk listesi sınırsız bir WrapPanel'di.
  - `SayimDeposu.MalzemeAraAsync` 2 karakterden kısa aramada `[]` döndürüyordu.
  - Hedef kartı 22 puntoda, satıra sarılan "kod · açıklama" yazıyordu.
- **Ne yapıldı:**
  - Renk listesi `ScrollViewer MaxHeight=200` içine alındı (`SayimView`, `UretimView`).
  - Malzeme araması boşken ilk 50 malzemeyi kod sırasıyla getiriyor; tek harfle de arıyor.
  - Hedef kartı yalnız yer kodunu yazıyor: tek satır, 20 punto, sığmazsa "…" ile kesiliyor.
- **Testler:** +2 test; toplam 241/241.
- **Commit:** `58955bc`. PM66'ya kuruldu (`install -r`).

### 7. Masaüstü paketi
- Kullanıcı "deponun desktop uygulamasını" istedi; mal kabul masaüstü kastediliyor.
- `58955bc` sürümü önceki günlerle aynı komutla derlendi:
  ```bash
  dotnet publish MalKabul.Desktop -c Release -r win-x64 --self-contained -p:PublishSingleFile=true -o <dir>
  ```
- Çıktılar:
  - `dagitim/malkabul-masaustu-2026-11-21.zip` (74,5 MB);
  - `dagitim/malkabul-2026-11-21.apk` (PM66'daki sürüm).
- `MalKabul.Desktop.exe` açıldı ("Modfex — Mal Kabul" penceresi).

### 8. Masaüstü: uzun depo yeri kodu / adı üst üste biniyordu
- **Sebep:**
  - Canlıda en uzun yer kodu 20 karakter (`WH01-Z01-R01-L01-P01`), adı 42 karakter.
  - Raf etiketleri ekranında kod sütunu sabit 160 px idi (16 pt kalın mono kod yaklaşık 210 px). Sayım listesinde lot/yer sütunu 110 px idi. Metinler kısaltılmadığı için yan sütuna taşıyordu.
  - Açılır listelerde de kısaltma yoktu.
- **Düzeltme:**
  - Raf etiketleri: kod sütunu 240 px (15 pt), QR sütunu 230 px, hepsinde "…" ile kısaltma; satır ipucunda tam "kod · ad".
  - Sayım listesi: yer sütunu 170 px + kısaltma + ipucu.
  - Bütün depo / yer açılır listeleri (12 şablon): kısaltma + tam metin ipucu.
- **Doğrulama:** Ekran görüntüsü testine gerçek uzunlukta kod eklendi; kısaltma öncesi taşma, sonrası düzgün görünüm görüldü. Testler 241/241.
- **Commit:** `d493607`. `dagitim/malkabul-masaustu-2026-11-21.zip` yeniden üretildi; exe açıldı.
- **Ek (`84d6dc1`):**
  - Kullanıcı "gene üst üste biniyor" dedi; ekran Raf etiketleri.
  - Mesaj büyük ihtimalle eski exe açıkken geldi. Yine de 640 px'lik dar pencerede açıklamanın "…"ya düştüğü görüldü.
  - Satır iki satırlı düzene geçti: kod (kalın) üstte, açıklama altta, QR sağda (MaxWidth 230). Hiçbir genişlikte metinler aynı satırı paylaşmıyor.
  - Zip yeniden üretildi; eski pencere kapatılıp yeni exe açıldı.

### 9. Raf etiketi: uzun kod iki satır
- **Kullanıcı:** "15 karakterden sonrasını alt satıra alalım, eziliyor yoksa."
- **Sebep:** `RafEtiketi.Zpl`, 12 karakterden uzun kodu 76 noktalık yazıyla tek satıra koyuyordu. 20 karakter yaklaşık 900 nokta tutuyor, iç genişlik 736 nokta; Zebra sıkıştırıyordu.
- **Ne yapıldı:**
  - `KodSatirlari`: ≤ 15 karakter tek satır (eski boylar). Daha uzunsa ilk 15 karakter içindeki son tireden sonra bölünür (`WH01-Z01-R01-` / `L01-P01`); tire yoksa 15. karakterde.
  - İki satır `^FB…,2,…,C` + `\&` ile 70 noktada basılıyor; açıklama tek satıra iniyor, QR'a değmiyor.
- **Doğrulama:**
  - ZPL, ZebraSimulator `ZplCizici` ile PNG'ye çizildi: iki satır, ezilme yok; kısa kod eskisi gibi büyük.
  - Testler 244/244.
- **Commit:** `63b01f5`. Masaüstü zip yenilendi, yeni exe açıldı.

### 10. Karantina onayı satın alma siparişi bazlı + inspection PDF (akşam)
- **Neden:** Kullanıcı: "karantina onayı satın alma siparişi bazlı olacak, top top değil"; inspection PDF'i son onay ekranında indirilebilmeli.
  Kararlar (soru-cevap): onay / red siparişin **tamamına** (top seçimi yok); Pass raporu yoksa onay **engellenir**, Fail yalnız red.
- **Ne yapıldı:**
  - `KarantinaKurali.OnayDurumu(siparisNo, rapor)`: Onaylanabilir (Pass/Approved) / Kaldi (Fail) / Beklemede (Hold vb.) / RaporYok / SiparisYok.
  - `InspeksiyonEslestirme.SiparisRaporu`: rapor siparişe `PurchaseOrderNo` ile (boşluk/harf duyarsız), en yenisi. Eski seri/irsaliye eşleşmesi (`Bul`) kaldırıldı.
  - `KarantinaDeposu.BekleyenlerAsync`: serisiz stok artık bu karantinaya giren en yeni siparişli UZMMK kalemine bağlanıyor (sipariş, irsaliye, tedarikçi) — red de aynı kaleme dayanıyor.
  - `KarantinaViewModel`: `Siparisler` (KarantinaSiparisi: kalemler, rapor, durum, özet), `SiparisSec`, `Onayla` (engel varsa nedeni söyler, ikinci basış yok), `Reddet` (ikinci basışla), `PdfIndir`.
  - PDF: `InspeksiyonDeposu.PdfAsync` → Selvedge `/api/auth/login` (aynı Sentez kullanıcı kodu + şifre) → `/api/qa-reports/{id}/pdf`; İndirilenler'e `{ReportNo}.pdf`, açılır. Şifre `Oturum.Sifre`'de yalnız bellekte.
  - Ekran: solda sipariş kartları (rozet, seçili vurgulu), sağda durum yazısı + rapor + "Rapor PDF'ini indir" + toplar + cevaplar + resimler. Onay düğmesi yalnız Pass'te etkin.
- **Dokunulan dosyalar:** `MalKabul/Ekranlar/KarantinaViewModel.cs`, `KarantinaView.axaml`, `UygulamaMetinleri.cs`, `Veri/InspeksiyonDeposu.cs`, `Veri/KarantinaDeposu.cs`, `Ortak/Veri/SentezGiris.cs`, testler `InspeksiyonTestleri.cs`, `EkranGoruntusuTestleri.cs`.
- **Komutlar:** `MODFEX_DB_TEST=1 dotnet test MalKabul.Tests` (canlı DB, rollback).
- **Sonuç:** 253/253 (canlı DB dahil); ekran görüntüsü kontrol edildi.
- **Commit:** `8acfadd`.
- **Not (gece):** 21:29–21:31 masaüstü "açılmıyor" şikâyeti: uygulama kapanmıyordu, VPN kopuk olduğu için "Şirketler okunamadı" (SQL error 64). VPN bağlanınca açıldı.

### 11. Sayım fişinde satırlar birleşmiyordu (gece)
- **Neden:** Kullanıcı: "depo sayım, okutarak alma, oluşturarak almada birleştirme sorunları var, satırlar birleşmiyor".
- **Kanıt (canlı, salt okunur):** UZMSY fiş 16 `00000016`: aynı stok + renk + yer 5 seri → 5 ayrı kalem. Mal kabul UZMMK `00000025`: 5 seri tek kalemde (306), birleşme çalışıyor.
- **Kök neden:** `SayimDeposu` (yeni seri, serisiz, taşıma) her okutmada `FisYazimi.KalemEkleAsync` ile yeni kalem açıyordu; mal kabuldeki kümülatif kural sayımda yoktu.
- **Ne yapıldı:** `SayimDeposu.KumuleKalemAsync`: günün fişinde aynı stok + birim + tek renk + giriş yeri + çıkış yeri (siparişsiz) kalemi varsa miktar + varyant ona eklenir. Seri hareketi o kaleme bağlanır (`FisYazimi.SeriHareketiEkleAsync` artık RecId döner). `SayimKalemi.HareketId`; liste seri hareketi başına satır; `DegistirAsync(kalemId, hareketId, …)` yalnız o seriyi değiştirir, kalem/varyant farkla.
- **Dokunulan dosyalar:** `Veri/SayimDeposu.cs`, `Veri/FisYazimi.cs`, `SayimListesiViewModel.cs`, testler `SayimDeposuTestleri.cs`, `SayimListesiTestleri.cs`, `SayimListesiEkraniTestleri.cs`.
- **Sonuç:** Yeni testler önce kırmızı, sonra yeşil; tüm set 257/257 (canlı DB).
- **Commit:** bkz. git log (sayım kümülatif).
- **Not:** Terminal ekranları (içeri al, seri oluşturarak al, sayım) listede her seriyi ayrı satır gösteriyor — kullanıcıya soruldu.

## Açık kalanlar / sonraki adım
- Selvedge servisi yeni API ucu (`/api/purchase-inspection/orders`) ile sunucuya kurulmadı — kullanıcı onayı bekliyor.
- Mobil 1.0.5 tablete kurulmadı (tablet bağlı değildi).
- Malkabul masaüstü paketi bu sürümle yeniden çıkarılmadı.
