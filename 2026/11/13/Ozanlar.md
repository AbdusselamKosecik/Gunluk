# Ozanlar — 2026-11-13

## Bağlam
`X:\Yazilim\Ozanlar\Doc` içinde COORE/SMARTLAY projesine ait dokümanlar ve Mehmet Ozan Çelik ile
WhatsApp yazışması var. Hedef: hepsini okuyup analiz etmek, kapsam/sorumluluk ayrımını ve açıkları çıkarmak.
Klasör git reposu değil; kodda değişiklik yapılmadı, sadece analiz.

## Yapılanlar

### 1. Doc klasörünün tamamı okundu
- **Neden:** Ozan 09/11'de "projeyle ilgili ilerleme var mı" diye sordu; cevap öncesi tam resim lazım.
- **Okunanlar:**
  - `Yazisma.txt` (06–09 Kasım yazışma)
  - `SMARTLAY KESİMHANE-SERİM UYGULAMASI.pdf` (COORE ürün tanımı: Admin / Serim operatörü / Depocu, 5 sayfa)
  - 3 WhatsApp mockup (Serim ekranı, Ürün Giriş/Çıkış, Pastal ekranı — tablet tarzı) + MQTT broker WebUI ekran görüntüsü
  - `COORE_IT_TESLIM_rev3` paketi (v0.2.4, 7 Kasım): README, SISTEM_VE_SINIRLAR, IS_AKISI_VE_KAT_SAYIMI,
    MQTT_SOZLESMESI, IT_DEGISIKLIK_0_2_4, IT_gereksinim/*, IT_KABUL_TESTLERI.csv (42 test), schema/*.json,
    asyncapi.yaml, sql/01_tables.sql, examples/01–11, DWIN_durum/* (3 sayfa DGUS 800x480), Teknik Özet PDF.
- **Sonuç:** Analiz aşağıda "Kararlar" ve "Açık kalanlar" altında.

## Kararlar / tespitler
- **Mimari:** ESP32-S3 + DWIN 800x480 serim makinesinde (login / serim / aktif pastal). Cihaz ↔ sunucu MQTT 3.1.1
  (benim önerim, 06/11). "IT" = benim tarafım: broker, backend, admin, stok/ERP, rapor.
- **Topic kökü:** `coore/smartlay/v1/devices/{id}/` + `requests|responses|events|events/ack|status`.
  Request kind: `authenticate_operator`, `validate_pastal`, `validate_roll`. Olaylar QoS0 + uygulama ACK
  (DB commit sonrası), `event_id` ile idempotent.
- **Kapsam çelişkisi:** Ozan "B serim operatörü (tablet) ve C depocu (tablet) ekranlarını biz yaparız, sen admin"
  diyor; IT paketi ise depo ekranını IT'ye (bana) veriyor ve operatör ekranı tablet değil DWIN. Netleştirilmeli.
- **Tespit edilen teknik açıklar:**
  1. `event_id = {device}-{seq}` → cihaz flash/firmware sıfırlanırsa seq baştan başlar; SQL `ON CONFLICT DO NOTHING`
     + `accepted:true` yeni olayı sessizce yutar (veri kaybı). Öneri: `boot_id`/epoch alanı veya payload hash
     karşılaştırması; çakışma+farklı payload → `accepted:false` + alarm.
  2. `accepted:false` olayda kuyruk sırayla drain ediliyorsa baştaki red kuyruğu kilitler mi? Tanımsız.
  3. Teknik Özet PDF `validate_operator`, MD/şema `authenticate_operator` diyor.
  4. asyncapi Event `required` listesinde `uptime_ms` yok, JSON şemada var. Response/status için şema yok.
  5. Örnek 09–11'de `device_id` "SL-DEMO001" (diğerleri "SL-DEMO0001"); 09–11 aynı uptime/konum değerleri.
  6. Örnek 06 `layer_completed`'da `layer_number=12, completed_layers=11` — completed_layers olay sonrası mı önce mi?
  7. `roll_ended`/`roll_change_started` ve `roll_started`/`roll_changed` çift isimler; backend ikisini de anlamalı.
  8. Mockup'lar Model/Kat/Kumaş/Metraj gösteriyor ama `assigned_pastals`/`approved_rolls` sadece ID listesi.
  9. Fire nedeni için protokolde alan/olay yok. Ozan 2 sabit neden önerdi; ben çoklu hata (ram yanığı, boya hatası...)
     istiyorum → `defect_codes[]` + kalan metraj alanı gerekli, kodlar admin'den gelmeli.
  10. Pastal bitirirken "kat/metraj düzenle" mockup'ta var, protokolde düzeltme olayı yok.
  11. Kısmi kullanılan topun stoğa dönüşü (kalan metraj) akışı tanımsız.
  12. RTC yok → olay zamanı belirsiz. Öneri: response'lara `server_time` ekle veya DS3231 RTC; broker sunucusu
      yerel NTP (chrony) de verebilir.
- **Veri modeli (benim 06/11 notlarım):** tedarikçi (top kimden), müşteri (kimin ürünü), sezon, model
  (bir modele çok pastal), kumaş rolü (ana kumaş/tela/astar), bir ürün için çok kumaşlı pastal birlikte raporlanmalı.
  ERP'siz müşteri (Mısır) için kendi master data girişi / Excel import gerekli.

## Açık kalanlar / sonraki adım
- Ozan'ın 09/11 "ilerleme var mı" mesajı cevapsız.
- "22-23-30-31-32-33 nolu ekranlar" hangi dokümana ait? Doc klasöründe numaralı ekran listesi yok
  (muhtemelen benim gönderdiğim A/B/C bölümlü gereksinim dokümanı) — bulunup eşlenmeli.
- Ozan'a sorulacaklar: depo ekranı kimde, operatör tablet mi DWIN mi, fire nedeni alanı, event_id sıfırlanma,
  red olayında kuyruk davranışı, response'lara zengin pastal/top bilgisi.
- Backend iskeleti (broker + event/ack handler + PostgreSQL) henüz başlanmadı.

---

## Devam (05:00–05:50)

### 2. Teknoloji ve kapsam kararı
- **Karar (kullanıcı):** Bizim taraf .NET + React ile yapılacak. Cihaz (ESP32 + DWIN + donanım + emniyet) Ozan Bey/COORE'da.
- **Karar (kullanıcı):** Depo giriş/çıkış ekranı kesin olarak **bizde**.
- **Öneri (benim):** Veritabanı PostgreSQL (COORE SQL şablonu ona göre), broker Mosquitto.
- Bizim kapsam: MQTT broker + .NET cihaz köprüsü, React admin, ana veriler (müşteri/tedarikçi/sezon/model/kumaş rolü,
  ERP'siz Excel import), depo + stok + fire nedenleri, raporlar.

### 3. Görev dağılımı + Ozan Bey'e sorular Word dosyası
- **Neden:** Kimin neyi yaptığını yazılı netleştirip Ozan Bey'e soru listesi göndermek.
- **Ne yapıldı:** docx-js (npm `docx`) ile Word üretildi. İçerik: 1) Özet, 2) Görev dağılımı tablosu
  (34 madde, Sorumlu = COORE / Abdusselam / Ortak, renkli), 3) 17 soruluk tablo (Konu / Soru / Neden önemli / boş Cevap sütunu).
- **Sorular (özet):** fire kodları + kalan metraj, ekranda model/kat/kumaş bilgisi, event_id sıfırlanması (boot_id),
  accepted:false'ta kuyruk, server_time/RTC, pastal bitirirken düzeltme olayı, kalan top metrajı, operatör ekranı DWIN mi tablet mi,
  top barkodu kaynağı, authenticate_ vs validate_operator, responses/status şeması, completed_layers anlamı,
  roll_ended/roll_started durumu, deviceId ve masa sayısı, TLS/CA güncelleme, "22-23-30-31-32-33" ekranları, takvim.
- **Dosyalar:** `X:\Yazilim\Ozanlar\SMARTLAY_Gorev_Dagilimi_ve_Sorular.docx`; üretici script scratchpad'de `make_doc.js`
  (yeniden üretim: `npm i docx` → `node make_doc.js <cikti.docx>`).
- **Doğrulama:** docx skill `validate.py` → "All validations PASSED". Görsel render yapılamadı (LibreOffice yok, Word COM açılmadı).
- **Not:** `X:\Yazilim\Ozanlar` git reposu değil → Word dosyası uzak depoya gitmedi. Repo açılması gerekiyor.

## Açık kalanlar (güncel)
- Word'ü Ozan Bey'e gönder, cevapları al.
- Ozanlar klasörü için git repo + remote açılmalı.
- Cevaplar gelince tasarım dokümanı (brainstorming → yazılı tasarım) ve plan.
