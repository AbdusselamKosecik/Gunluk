# bantdurumekrani — 2026-10-30

## Bağlam
Kullanıcı Superset için iki dashboard istedi: (1) bant sonu monitörü (bantdurumekrani TV panosu) sekme sekme,
(2) paketleme monitörü (tezgahekrani panosu). Superset müşteride; teslim = Import ZIP'i.

## Yapılanlar

### 1. Superset import ZIP'leri
- **Neden:** Müşteri Superset'ine Dashboards → Import ile yükleyecek; DB'ye yazmadan (sanal dataset).
- **Ne yapıldı:** `superset/sql/*.sql` = uygulama sorgularının Superset'e uyarlanmış kopyası (tek üst-düzey WITH,
  ORDER BY yalnız TOP ile, yorumlar olustur.py'de atılır, CompanyId=2 sabit). `bant_durum.sql` TvHesap'ın hedef/mesai
  hesabını SQL'e taşır (ISO gün `(DATEPART(WEEKDAY,..)+@@DATEFIRST-2)%7+1`, banta özel mesai genelin yerine geçer,
  `BantSaatlikHedef.N` → `BantSaatlikHedef`). `olustur.py` (stdlib; YAML'lar JSON olarak) database+dataset+chart+dashboard
  üretir, UUID'ler uuid5 ile sabit (yeniden import üzerine yazar).
  - Bant Durum: 4 sekme (Bant Giriş/Çıkış · Paketleme Durumu · Sipariş Durumları · Order Akış), 14 grafik, yenileme 60 sn;
    verimlilik renkleri ≥90 mavi / ≥80 yeşil / ≥50 amber / <50 kırmızı (conditional_formatting).
  - Paketleme Monitörü: 6 KPI + tezgahta bekleyen / tezgaha alınacak / bugün paketlenen tabloları, 10 grafik, 30 sn.
  - DB bağlantısı: `mssql+pymssql://superset_okur:XXXXXXXXXX@100.119.104.122:1433/SentezCore` — kullanıcı adı müşteride düzeltilecek (kullanıcı "başka kullanıcı" dedi).
- **Dokunulan dosyalar:** `superset/README.md`, `superset/olustur.py`, `superset/sql/*.sql`, `superset/*.zip`
- **Komutlar:**
  ```bash
  cd bantdurumekrani/superset && python olustur.py
  ```
- **Sonuç / doğrulama:** 7 SQL SentezCore'da Superset sarmalıyla (`__cte`/`virtual_table`) çalıştı; hedef hesabı sabit
  saatle sınandı (Salı 15:00 → 420 dk × 100/sa = 700). Docker `apache/superset:latest` (6.1.0) + pymssql'de API import
  200 OK, sekmeler ve yerleşim doğru. Grafik verisi Superset içinden görülemedi (bağlantı güncellemesi login hatası) —
  kullanıcı "denemene gerek yok, müşteride yüklenecek" dedi, test bırakıldı.
- **Commit:** `1938a31` — Superset: Bant Durum (4 sekme) ve Paketleme Monitörü dashboard import ZIP'leri

## Kararlar
- ZIP'ler bantdurumekrani reposunda (tezgahekrani'na ayrı koyulmadı; tek üreteç).
- Dataset'ler sanal; veritabanına view/tablo açılmadı.

## Açık kalanlar / sonraki adım
- Müşteride: `pip install pymssql`, import, bağlantı kullanıcı/sunucu düzeltmesi; grafiklerin veriyle görünmesi orada doğrulanacak.
- Uygulama sorguları değişirse `superset/sql` de güncellenmeli.
