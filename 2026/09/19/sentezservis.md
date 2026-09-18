# sentezservis — 2026-09-19

## Bağlam

18.09'da yazılan belge kontrol ekranı (UUID → CRS + Sentez) kullanıcıdan **şirket ve tarih
aralığı** istiyordu; sebebi "CRS'te UUID ile tek belge çeken operasyon yok" varsayımıydı.
Kullanıcı şirket bağımsız arama istedi. Ayrıca üç yeni iş açıldı (pazaryeri servislerinin
birleştirilmesi, sipariş çekerken e-fatura/e-arşiv/mikro ihracat kontrolü, e-arşiv
oluştur/gönder ve kontrol servisleri).

## Yapılanlar

### 1. CRS WSDL'i okundu — varsayım yanlışmış

- **Neden:** Ekran şirket+tarih istiyordu ve bu, kullanıcının işini zorlaştırıyordu.
  "CRS'te tekil sorgu yok" bilgisi **koddan** çıkarılmıştı (bizde 3 operasyon kullanılıyor),
  servisin kendisinden değil.
- **Ne yapıldı:** `https://connect.crssoft.com/Services/Integration?wsdl` ve beş XSD indirildi.
- **Sonuç: serviste 65 operasyon var** ve aradıklarımız mevcut:
  - `GetOutboxInvoice(invoiceId)` — tekil belge
  - `QueryOutboxInvoiceStatus(invoiceIds[])` — **toplu** durum
  - `IsEInvoiceUser(vknTckn, alias)`, `FilterEInvoiceUsers`, `GetEInvoiceUsers` — 3. madde için
  - `SendInvoice`, `ValidateInvoice`, `CancelEArchiveInvoice`, `RecoverEArchiveCancel` — 4. madde için
- **Ders:** Dış servisin ne sunduğu, kendi kodumuzdaki kullanımdan değil **servisin
  sözleşmesinden** öğrenilir. Bir gün önceki tasarım bu yüzden gereğinden karmaşıktı.

### 2. Ölçümler

- `GetOutboxInvoice` **ETTN kabul ediyor**, fatura numarasını kabul etmiyor (ikisi de
  denendi; CRS ikisine de "Id" diyor, şemadan ayırt edilemiyordu).
- **CRS hesapları birbirinin belgesini görmüyor:** 01'in ETTN'i 03 hesabından sorulunca
  bulunamıyor. Yani "şirket bağımsız arama" = her hesaba sırayla sormak.
- `QueryOutboxInvoiceStatus` toplu çalışıyor → maliyet **şirket sayısı** kadar, belge sayısı
  kadar değil.
- **`ArrayOfString` CRS'in KENDİ (tempuri) ad alanındadır.** WCF'in alışıldık
  `schemas.microsoft.com/.../Arrays` ad alanı kullanıldığında CRS **hiçbir kimliği
  tanımıyor ve bunu hata olarak da bildirmiyor** — sessizce boş sonuç dönüyor. İlk deneme
  böyle "0 kimlik tanınıyor" verdi.

### 3. Tasarım değişti: şirket ve tarih artık istenmiyor

- `CrsIstemcisi.BelgeGetirAsync` ve `DurumlariSorAsync` eklendi.
- `BelgeSorgulayici` akışı: (1) Sentez'de tüm şirketlerde ara, (2) bulunanların gününü
  CRS'te tara (detay için), (3) **her kimliği her CRS hesabına toplu sor** — şirketi bu
  belirler.
- Tarih aralığı yalnızca **ek detay** için kaldı: durum sorgusu varlığı ve durumu söyler
  ama tutar/unvan taşımaz.
- **Dokunulan dosyalar:** `src/SentezServis.Core/Fatura/{CrsIstemcisi,BelgeSorgulayici,BelgeSorguModelleri}.cs`,
  `tests/SentezServis.Core.Tests/BelgeSorguTestleri.cs`, `web/src/api/fatura.ts`,
  `web/src/pages/BelgeSorguSayfasi.tsx`
- **Commit:** `1bcfa2d`

### 4. Yakalanan tuzak — demet (value tuple) null olmaz

`durumlar` sözlüğünün değeri `(string, CrsBelgeDurumu)` demetiydi ve satır kurulurken
`GetValueOrDefault` kullanılmıştı. **Demet bir değer tipidir**: bulunamayan anahtar için
`null` değil, içi `(null, null)` olan **dolu bir demet** döner ve `?.` bunu "var" sayar.

O hâliyle **her belge "CRS'te var" görünecekti** — ekranın verebileceği en kötü cevap.
Canlı denemede `NullReferenceException` olarak patladı; patlamasaydı sessizce yanlış sonuç
üretirdi. `TryGetValue`'ya çevrildi ve sınır testiyle kilitlendi.

### 5. Canlı doğrulama

Şirket ve tarih **verilmeden**:

```
3e9c3536-…7eda [ikisindeDe] 01 Approved  CRS MOD2026000002272 / Sentez 00002276
28951e33-…ffba [ikisindeDe] 03 Approved  CRS MOD2026000125843 / Sentez 00317401
1ace225f-…d13b [ikisindeDe] 04 Approved  CRS VME2026000193487 / Sentez 00453779
00000000-…0001 [hicbirindeYok]
```

508 .NET + 63 web testi geçti.

### 6. Paket

`SentezServis-2026-09-19-0215.zip`, arayüz tarihi **2026-09-19 02:15**.

## Kararlar

- **Dış servisin yetenekleri sözleşmesinden (WSDL/XSD) öğrenilir**, kendi kullanımımızdan
  değil. 18.09 tasarımı bu adım atlandığı için gereğinden karmaşıktı.
- Şirket bağımsızlık, her CRS hesabına **toplu** sormakla kurulur.

## Açık kalanlar / sonraki adım

Kullanıcının verdiği 4 maddeden **yalnızca 1.'si yapıldı.** Kalanlar tasarım kararı bekliyor:

- **2. Pazaryeri servislerinin birleştirilmesi.** `pazaryeri-cari-aktar`,
  `pazaryeri-cari-uret`, `pazaryeri-siparis-hazirla`, `pazaryeri-siparis-aktar` kaldırılıp
  tek servis olacak, içi sonra yazılacak. Bunlar canlı `zamanlamalar` tablosunda kayıtlı
  (cron'ları NULL, yani zamanlanmamış). **Sorulacak:** eski iş anahtarları ve çalıştırma
  geçmişi silinsin mi, yoksa kayıt kalsın mı? Göç yazılması gerekir.
- **3. Sipariş çekerken e-fatura / e-arşiv / mikro ihracat kontrolü.** CRS'te `IsEInvoiceUser`
  var (VKN/TCKN + alias ile sorar) — e-fatura mükellefi mi, değilse e-arşiv. Mikro ihracatın
  kuralı belirsiz. **Sorulacak:** karar nereye yazılacak (sipariş kaydına mı, ayrı tabloya mı)?
- **4. E-arşiv oluştur/gönder ve kontrol servisleri**, şimdilik boş iskelet. CRS tarafı
  hazır: `SendInvoice`, `ValidateInvoice`, `QueryOutboxInvoiceStatus`. **Dikkat:** bu ilk
  kez CRS'e YAZAN modül olacak; şimdiye kadar fatura modülü salt okunurdu ve bu bir kurul
  kararıdır — Karar yazılmadan uygulanmamalı.
