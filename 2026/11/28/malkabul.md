# malkabul (SentezCore bakımı) — 2026-11-28

## Bağlam
GL hesapları 26.11'de silinmişti (bkz. 2026/11/26/malkabul.md §2). Yeni hesap planı `X:\Gitlab\modfex-apparel\MuhasebeKodlari.xlsx` dosyasında; kolonlar Kod / Turkce / Ingilizce / arabca. Kullanıcı İngilizce ve Arapça adların muhasebe terimleriyle, en fazla 25 karakter olarak doldurulmasını istedi.

## Yapılanlar

### 1. Hesap planı İngilizce/Arapça çevirisi
- **Ne yapıldı:**
  - 674 satırda 444 benzersiz Türkçe ad elle çevrildi.
  - İngilizce: IFRS terimleri (ACCUMULATED DEPREC(-), DEDUCTIBLE VAT vb.); ST/LT, PRV, EXP, ALLOC, VAR kısaltmaları kullanıldı.
  - Arapça: Mısır/Arap muhasebe terimleri (مجمع الإهلاك، مخصص، أوراق القبض vb.).
  - Firma, banka ve kişi adları Latin harfle bırakıldı; hesap numaraları korundu.
- **Kontrol:** Python betiği her değerin 25 karakteri aşmadığını doğruladı (en uzun 25/25). Arapçada aşan tek değer kısaltıldı.
- **Dosyalar:**
  - Çeviri tablosu: scratchpad `ceviri.py` (T listesi, benzersiz Türkçe adların sırasıyla).
  - Çıktı: `X:\Gitlab\modfex-apparel\MuhasebeKodlari-ceviri.xlsx`. Orijinal Excel'de açık olduğu için ayrı dosyaya yazıldı.
  - Orijinalin kopyası: `yedek\MuhasebeKodlari-orijinal-20261128.xlsx`.

## Açık kalanlar
- Kullanıcı çeviriyi gözden geçirip Sentez'e yükleyecek. Ardından KDV (Erp_TaxIA), cari ve banka hesap bağları yeniden kurulacak.

### 2. SentezCore — eski cari kartları yeni carilere taşı ve sil
- **Neden:** Yeni hesap planına geçiş; ilk kayıttaki geçici cari kodları (001–025, 20, 30, Bant-1/3/4/6/8, C, M, PZR) `320.99.999`'a, `120.01.012`→`120.02.005` (DEFACTO TURKEY), `120.01.048-1`→`120.02.004` (MODASIMA) taşınacak, eskiler silinecek.
- **Ne yapıldı:** `carisil.cs` (scratchpad/sqldene): #K (kod eşleme, `COLLATE DATABASE_DEFAULT` — DB Turkish_CS_AS) → #M (eski RecId→yeni RecId, 37 eşleşme şartı). `sys.foreign_keys` ile Erp_CurrentAccount'a bağlı 116 kolon tarandı (isim taramasıyla FK dışı kolon çıkmadı), dolu olanlar UPDATE ile yeni cariye taşındı, eski Erp_CurrentAccountTotal (hepsi 0) silindi, 37 cari silindi. Serializable tek transaction, önce ROLLBACK deneme, sonra `--onayla`.
- **Sonuç:** Taşınan satırlar: WorkOrder 1361, Inventory 27, OrderReceipt 19, InventoryReceipt 18, WorkOrderProduction 11, CurrentAccountTransaction 4, Address 3, InitialCost 2, PackingList 2, ProductivityTransaction 1. Silinen: 3 total, 37 cari. Yeniden tarama: eski Id'lere 0 bağ.
- **Yedek:** `X:\Gitlab\modfex-apparel\yedek\sentez-cari-birlestir-20261128-041459.json`
- **Not:** Erp_CurrentAccount/Transaction/Total tablolarında trigger yok; taşınan 4 cari hareketinin bakiyesi Total'a yansımadı (eski cariler için de Total satırı yoktu).

### 3. SentezCore — 320.01.xx / 320.02.xx cari kodları 3 haneye
- **Neden:** Yeni hesap planı formatı `320.02.001` (son bölüm 3 hane).
- **Ne yapıldı:** `kodguncel.cs` (scratchpad/sqldene): CompanyId=2, `LEN=9 AND LIKE '320.0[12].[0-9][0-9]'` kodlar → `LEFT(kod,7)+'0'+RIGHT(kod,2)`. Çakışma kontrolü (0), kodu metin olarak tutan kolonlar da tarandı (ECMCurrentAccountCode, Erp_OrderReceipt.UD_CargoCurrentAccountCode, Erp_BudgetItem, Erp_GLReceiptItemInv — hepsinde 0 kullanım). Önce ROLLBACK deneme, sonra `--onayla`.
- **Sonuç:** 113 cari (320.01.001–099, 320.02.001–014) güncellendi; diğer tablolar Id ile bağlı olduğundan etkilenmedi.
- **Yedek:** `X:\Gitlab\modfex-apparel\yedek\sentez-cari-kod-3hane-*.json`

### 4. SentezCore — her cari için GL hesabı + cari muhasebe bağı
- **Neden:** Yeni hesap planı (653 hesap, 28.11 01:08'de yüklendi) 120.01/120.02/320.01/320.02 ana hesaplarını içeriyor ama cari detay hesapları yok; carilerin muhasebe kodu boş.
- **Ne yapıldı:** `glcari.cs` (scratchpad/sqldene), tek transaction:
  - Eksik ana hesaplar: `120.99` OTHER CUSTOMERS / DİĞER ALICILAR, `320.99` OTHER SUPPLIERS / DİĞER SATICILAR.
  - Her cari (CompanyId=2, `120|320.NN.NNN`) için aynı kodlu Erp_GLAccount: AccountName/UD_Turkce/UD_Arabic = cari adı (özel isim, Latin harf), AccountType=1, CDType=3, InUse=1, IsApproved=1, CostDistributionType=0, InsertedBy=1 (yüklenen planla aynı değerler).
  - Bağ: 120.* → `CustomerGLAccountId`, 320.* → `SupplierGLAccountId`.
  - Önce ROLLBACK deneme, sonra `--onayla`. Koruma: 129/129 doğru bağ, çift kod 0, GL artışı = eklenen.
- **Sonuç:** 2 ana + 129 detay GL hesabı; 15 müşteri, 114 satıcı bağı.
- **Yedek:** `X:\Gitlab\modfex-apparel\yedek\sentez-cari-glhesap-*.json` (önceki GL bağları; hepsi boştu). Geri alma: yeni GL'ler `InsertedAt` 28.11 04:3x ile ayırt edilir.

### 5. KDV muhasebe bağı — beklemede
- Erp_TaxIA: %14 (TaxId 18) ve %5 (19) için TypeNo 1–25 satırları var, hepsi GLAccountId NULL; %0 için satır yok (kullanıcı: %0 boşver). TypeNo anlamları DB'de yok (Meta_* tablolarında da yok), Sentez kurulumu erişilemez → kullanıcıdan Sentez'de %14 kartını doldurması ya da satır adlarını vermesi istendi.

### 6. Muhasebe-Ornek-Fisler.xlsx (eğitim materyali)
- **Neden:** Mısırlı muhasebecilere Türk mevzuatına (TDHP, 7/A) göre eğitim; Mısır'da 7 sınıfı yok → 7 ve 6 sınıfının bilançoya nasıl taşındığını göstermek.
- **Ne yapıldı:** `scratchpad/ornekfis.py` + `sss.py` (kopyası `X:\Gitlab\modfex-apparel\yedek\`), hesap adları canlı Erp_GLAccount'tan (`sqldene/plan4.cs` → planfull.tsv, TR/EN/AR). Sayfalar: Aciklama, Egitim Soru-Cevap (26 soru TR+EN), Ornek Fisler (24 fiş: satış/alış/gider faturası, banka tahsilat/ödeme, cariye banka/kasa ödemesi, virman, maaş), Yansitma ve Kapanis (12 fiş: 711/721/731→151→152, 761/771/781→631/632/660, 7 karşılıklı kapanış, 6→690, 691/370, 692→590), Mizan.
- **Doğrulama:** her fiş borç=alacak (assert), tüm kodlar planda mevcut, kapanış sonrası 6/7 sınıfı sıfır; bilanço aktif=pasif 49.165.
- **Çıktı:** `X:\Gitlab\modfex-apparel\Muhasebe-Ornek-Fisler.xlsx`
- **Notlar:** 191'in detay hesabı yok; isimli "Ödenecek KDV" detay hesabı yok (360.01.008 adsız); Mısır kurumlar vergisi %22,5 varsayıldı.
