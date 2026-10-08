# bantsayim — 2026-10-08

## Bağlam
Kullanıcı paketlemede "tarih hatası" (işlem sırasında hata mesajı) bildirdi. Yerel loglarda iz yoktu;
hata sahadaki SQL oturumunda çıkıyor.

## Yapılanlar

### 1. Fiş SQL'inde dile bağlı tarih literali
- **Neden:** `FisSql.BaslikEkle` içinde `CAST('1899-12-30' AS datetime)` (ReceiptTime alanları için).
  `datetime` + `yyyy-MM-dd` literali oturum diline bağlı: SQL kullanıcısının dili Türkçe (DATEFORMAT dmy) ise
  yıl-gün-ay okunur, ay=30 → Msg 242 "varchar → datetime aralık dışı değer". Fiş yazımı (koli kapat / bant kabul) patlıyor.
  Testler İngilizce oturumla koştuğu için yakalanmamıştı.
- **Doğrulama (LocalDB):**
  ```bash
  sqlcmd -S "(localdb)\MSSQLLocalDB" -Q "SET LANGUAGE Turkish; SELECT CAST('1899-12-30' AS datetime)"  # Msg 242
  sqlcmd -S "(localdb)\MSSQLLocalDB" -Q "SET LANGUAGE Turkish; SELECT CAST('18991230' AS datetime)"    # OK
  ```
- **Ne yapıldı:** Literal `'18991230'` (ISO, dilden bağımsız) yapıldı. Aynı kod bantsayim ve paketlemede vardı; ikisi de düzeltildi.
  Regresyon testi `FisSqlTestleri`: BaslikEkle/KalemEkle/VaryantEkle içinde `'dddd-dd-dd` deseni olmamalı (önce kırmızı, sonra yeşil).
- **Dokunulan dosyalar:** `*/Ekranlar/Veri/FisSql.cs`, `*.Tests/FisSqlTestleri.cs`
- **Sonuç:** paketleme 34 geçti / 22 DB testi atlandı; bantsayim 41 geçti / 15 atlandı. DB testleri bu makinede kapalı (MODFEX_DB_TEST).
- **Commit:** `8985501` — Fiş SQL: tarih literali dilden bağımsız (18991230)

## Kararlar
- Tüm uygulamalarda SQL içinde tarih literali yalnızca `yyyyMMdd` biçiminde yazılacak.

## Açık kalanlar / sonraki adım
- Sahada yeni sürüm kurulup koli kapatma / fiş yazımı denenmeli; kullanıcı hata metnini iletmedi, teyit bekleniyor.
- Bant / paketleme / sevkiyat okutma ekranlarını "5 yaşındaki çocuk" sadeliğine getirme: brainstorming sürüyor
  (hedef: okutma ekranı sade; cihaz: PC + el okuyucu).
