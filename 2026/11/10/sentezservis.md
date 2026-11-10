# sentezservis (Modfex, `X:\Gitlab\modfex-apparel\sentezservis`) — 2026-11-10

## Bağlam
Kullanıcı: "Bizim web servise barkod listesi yüklememiz lazım. Hazır barkodlara küçük QR barkodlar oluşturmak istiyoruz.
Önce bu kolileri oluşturmak, sonra stoğa sokmak, en sonunda el terminaliyle otomatik sipariş kapatmak." Örnek liste:
`CustomerOrder WorkOrder Model KoliBarcode Renk S-M L-XL` (her satır bir koli, beden sütunları = adet).
(Seri/tahsis tasarımı — depo `2026-10-17-seri-kabul-tahsis-design.md` — UZM_ tablo izni sorusunda bekliyor; bu iş araya girdi.)

## Yapılanlar

### 1. Keşif (canlı SentezCore 100.119.104.122, salt okuma)
- `CustomerOrder` = `Erp_OrderReceipt.ReceiptNo` (ReceiptType 2). `00000007` → RecId 584661 açık, içinde NZR-2278 /
  KAR DESEN KIRMIZI / S-M, L-XL (3000'er) var, NZR-2277 yok. `00000008` yalnız tip 1 (kapalı satınalma).
- `WorkOrder` = `Erp_WorkOrder.WorkOrderNo` (NZR-2277 → 81565, NZR-2278 → 81566). `Model` = `Erp_Inventory.InventoryCode`.
- Renkler Sentez'de büyük harf (`EKRU`); listede `Ekru` → Türkçe büyük/küçük harf duyarsız eşleşme.
- UZM_Ayar: MamulDepoId 41, Kalite1TipId 2, UretimDepoId 42; UZM_PaketKoli'de MamulFisId/WorkOrderId var; compat 140 (OPENJSON).
- Paketleme koli yazımı (`KoliDeposu.cs`), fiş şablonu (`FisSql.cs`/`FisYazici.cs`), sevkiyatmobil koli bulma
  (`Erp_Box.BoxCode` + `UZM_PaketKoli` inner join, `Durum=1` ve `MamulFisId` şart) Explore ajanıyla çıkarıldı.
- Sentez kaynağında `MitoRequirementPM` (order tedarik ekranı): 129 üretime çıkış, 29 üretimden iade (ReturnType 1) — seri tasarımı için not.

### 2. Tasarım — `docs/superpowers/specs/2026-11-10-koli-listesi-yukleme-design.md`
- Builder kontrolü (alt ajan) 5 soru çıkardı; kullanıcı cevapları: **sipariş kapatmayı Sentez tetikleyicisi yapıyor**;
  **stoğa alırken 17 yok, doğrudan mamul depoya, baskı yok**; **QR etiket paketleme uygulamasından, yazıcı + ölçü seçerek,
  koli başına bir tane**. Benim kararlarım: fiş tipi 10 (UZM_Ayar.KoliListeFisTipi), sabit Sentez kullanıcısı
  (appsettings), yazma bayrağı kapalı başlar, sevkiyatmobil mamul giriş koruması (sonra).
- **Commit:** `8c46076` — Tasarim: koli listesi yukleme, mamul depoya giris (17'siz), QR etiket paketlemede

### 3. Kod
- **Core/KoliListe/**: `KoliListeAyristirici` (sekmeli/; metin + ClosedXML .xlsx, görünen metin → baştaki sıfırlar
  korunur, rakamsa 8 haneye tamamlanır; zorunlu 5 sütun, kalan başlıklar beden), `KoliListeKurallari` (barkod: boş/50
  karakter/boşluk/P1-P2-P4 öneki — sevkiyatmobil bu önekleri siler), `KoliListeDeposu` (doğrula: sipariş, iş emri, model,
  renk×beden varyantı, sipariş varyant satırı zorunlu; iş emri varyantı/sipariş-iş emri bağı/sipariş fazlası uyarı;
  koli aç: koli başına transaction, kilit `UZM_PaketKoliSira`, `Erp_Box`(BoxType 1, WorkOrderId) + `Erp_BoxItem` +
  `Erp_BoxItemVariant` + `UZM_PaketKoli` Durum=1 + `UZM_KoliListe`; stoğa al: kilit `UZM_UretimFis`, günlük başlık
  tip+`KLY`+depo, kalem BoxId'li, `UZM_PaketKoli.MamulFisId` set), `FisSql.cs` paketlemeden kopya.
- **Host/Api/KoliListeUclari.cs**: `/api/koli-listesi/durum|dogrula|koli-ac|stoga-al|koliler`; yazma
  `SentezServis:KoliListeYazmaAcik` + `KoliListeSentezKullaniciId` olmadan 503.
- **Web**: `pages/KoliListesiSayfasi.tsx` (Liste yükle / Açılmış koliler sekmeleri), `api/koliListe.ts` (+ VITE_MOCK sahte veri),
  menü Operasyon › Koli listesi.
- **db/sentezcore/koli-liste.sql**: `UZM_KoliListe` + `UZM_Ayar.KoliListeFisTipi=10`. **Canlıda çalıştırılmadı** (kullanıcı çalıştırır).
- Yazma hedefi koruma testi (`KarmaKoliTestleri.SentezCore_yazmasi_...`) KoliListe için genişletildi.
- **Komutlar / doğrulama:**
  ```bash
  dotnet test tests/SentezServis.Core.Tests        # 318 geçti, 12 atlandı
  SENTEZCORE_TEST=<salt okur> dotnet test --filter KoliListeDeposuCanli   # 1 geçti (örnek satırların hata nedenleri)
  cd web && npx vitest run && npm run build        # 61 geçti, derleme tamam
  VITE_MOCK=1 npx vite --port 5299                 # Chrome: yükle→doğrula (00000008 kırmızı)→koli aç→stoğa al
  ```
- **Commit:** `33b69ab` — Koli listesi: hazir barkodlu liste yukle/dogrula, Sentez'de koli ac, mamul depoya al (17'siz)

### 4. Paket — `SentezServis-yama-2026-11-10-koli-listesi.zip` (73 MB, repo kökü, git'e girmez)
- `deploy/yayinla.ps1` → `yayin/`; önceki `yayin` (19.10 PDKS) ile SHA256 karşılaştırma: farklı yalnız `SentezServis.exe`
  (tek dosya, 200 MB), `wwwroot/app.js` ve pdb'ler. Yama = exe + app.js + koli-liste.sql + KURULUM.txt.
  Tek dosya yayım yüzünden yama tam paketle aynı boyutta (exe her değişiklikte tümüyle değişir).
- İçerir: 2ca0022 (PDKS), 7786f82 (çoklu zaman, göç 018), 33b69ab (koli listesi).

## Kararlar
- Fiş 17 yok; tip 10 üretimden giriş → 41 (kullanıcı "17 oluşturulmadan mamul depoya").
- Sipariş kapatma kodu yok (Sentez tetikleyicisi). İlk canlı denemede `IsClosed` gözlenecek.
- QR etiket web'de değil paketlemede (kullanıcı). Koli başına 1 ("birer tane" yorumu).

## Açık kalanlar / sonraki adım
- **Paketleme "Koli QR etiketi" ekranı** (UZM_KoliListe listesi, yazıcı + ölçü 45×20×2 / 100×100, basım sayacı) — yapılmadı.
- sevkiyatmobil koruması (listeden gelen koliyi mamul girişte reddet) — yapılmadı.
- Canlı: betik çalıştırma, appsettings iki anahtar, yazmayı birlikte açma; yazma yolu (koli aç/stoğa al) canlıda denenmedi
  (UZM_KoliListe canlıda yok; DDL kullanıcıda).
- Seri/tahsis tasarımı (depo) — UZM_ tablo izni sorusu cevap bekliyor.

## Ek (15:20–15:45) — yeni tablo kaldırıldı, gerçek listeler doğrulandı

### 5. Mock karışıklığı
- Kullanıcı tarayıcıda açık kalan mock sayfasındaki "fiş 00000123"ü gerçek sandı ("fiş yok ortada", "Boxlar yok").
  Canlıda hiçbir şey yazılmamıştı. Mock sekmesi kapatıldı, vite durduruldu. **Ders:** mock denemesinden sonra sekmeyi kapat.

### 6. UZM_KoliListe kaldırıldı (kullanıcı: "koli-liste.sql'e ne gerek var… standart yürüyen sistemin arasına gireceğiz,
yeni alan falan ne"; "SpecialCode vardır oraya yaz")
- Listeden gelen koli: `Erp_Box.SpecialCode = 'KLY'`, `Explanation` = "dosya · web kullanıcısı" (50), QR basıldı
  `IsPrinted/PrintedAt/PrintedBy`; içerik Erp_BoxItem/Variant'tan (OUTER APPLY + FOR XML bedenler). `db/sentezcore/koli-liste.sql` silindi.
- Canlı şema: `Erp_Box.BoxCode` nvarchar(**25**) → barkod sınırı 50'den 25'e.
- Doğrulama (salt okunur canlı): masaüstü `2277.xlsx` (338 koli, 00000006 NZR-2277 EKRU 4+4) ve `2278.xlsx` (432 koli,
  00000007 NZR-2278 6+6) — **tüm satırlar geçerli**. Test: `KoliListeSorguCanliTestleri` (KOLI_LISTE_DOSYA ile).
- Testler 319 geçti + 3 canlı; vitest 61.
- **Commit:** `75a0800` — Koli listesi: yeni tablo yok - listeden gelen koli Erp_Box.SpecialCode='KLY'
- **Paket:** `SentezServis-yama-2026-11-10-koli-listesi.zip` (73 MB, exe + app.js + KURULUM.txt; SQL yok) yeniden üretildi.

## Açık kalanlar (güncel)
- Kurulum: yama + appsettings iki anahtar (`KoliListeYazmaAcik`, `KoliListeSentezKullaniciId`); ilk koli açma/stoğa alma canlıda birlikte.
- sevkiyatmobil koruması (SpecialCode KLY koliyi mamul girişte reddet) — yapılmadı.
