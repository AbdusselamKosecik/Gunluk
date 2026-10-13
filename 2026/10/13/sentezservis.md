# sentezservis — 2026-10-13

## Bağlam
Kullanıcı: "Personel giriş çıkış raporunda 1. bir önceki günler gelmiyor, 2. 12'de ve sabah 8:10 gönderilecek,
3. yukarıdaki yazıda total kişi sayısı, giriş yapmayan, giriş yapan, bir gün önce çıkış yapmayanlar, dün hiç gelmeyenler."
12:00 = öğlen, aynı rapor (sorulup netleşti).

## Yapılanlar

### 1. Teşhis (salt okuma)
- `SentezServis.dbo.calistirmalar` (is_anahtari='pdks-giris-cikis'): 7–13.10 her 08:10 çalışmasında "358 çıkışsız" (hepsi);
  06.10 10:38 elle çalışmada 35. Bu sabahki mail (`bildirim_kutusu`) Out sütunu tamamen "—", önceki gün doğru (12.10).
- Aynı sorgu 11:08'de 316 çıkış buluyor; kayıt sırası (`iclock_transaction.id`) normal → veri vardı, ama
  `punch_state='1'` sabah henüz oturmamış (cihaz/BioTime yön işaretini sonradan yazıyor).

### 2. Düzeltme — `5b0f6ef`
- `PdksDeposu.GunlukAsync`: çıkış = işaretli çıkış, yoksa (≥2 okutma) günün son okutması; giriş = işaretli giriş, yoksa ilk okutma.
  Yeni kolon `DunOkutma` (önceki günün okutma sayısı; işe giriş sonra ise −1) → `PdksSatiri.DunGelmedi`, `DunCikisYok`.
- `BildirimServisi.PdksOzetHtml`: `total · checked in today · not checked in today · no check-out on <önceki> · absent on <önceki>`;
  dün gelmeyenin Out hücresinde ABSENT.
- `CronHesaplayici`: `;` ile çoklu ifade (hepsi geçerli olmalı, en yakın tetikleme). İş varsayılanı
  `10 8 * * 0-4,6; 0 12 * * 0-4,6`.
- Testler: 276 geçti (yeni: çoklu cron, özet sırası/sayıları, dün gelmeyen/çıkışsız, ABSENT hücresi).
- Canlı doğrulama (salt okuma, yeni sorgu): toplam 358, giren 326, girmeyen 32, dün çıkışsız 11, dün gelmeyen 32.

### 3. Paket
```powershell
powershell -ExecutionPolicy Bypass -File deploy\yayinla.ps1   # yayin\ (arayüz 2026-10-13 12:14)
# yayin\* (appsettings hariç) → yayin-pdks-2026-10-13.zip (76,9 MB)
```

## Açık kalanlar
- Kullanıcı paketi MODFEXSRV'ye kuracak (servisi durdur, üzerine kopyala, başlat; appsettings korunur).
- Zamanlama ekranında pdks-giris-cikis cron'u `10 8 * * 0-4,6; 0 12 * * 0-4,6` yapılmalı (kayıtlı değer eski kalır).
