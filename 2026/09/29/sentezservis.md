# sentezservis — 2026-09-29

## Bağlam
28.09'da sipariş planlama ekranı ve Mısırlı etiketinin beden bazlı PAKET satırı yazıldı, push edildi. Kullanıcı
paket istedi.

## Yapılanlar

### 1. Paket: sipariş planlama + Mısırlı PAKET dökümü
- **Neden:** Canlı sunucuya yeni özellikler kurulacak.
- **Önce kontrol:** Hafızadaki `paket-onceki-paketle-karsilastir` kuralı uygulandı. Çalışma klasöründe commit
  edilmemiş kod yoktu; `main` = `origin/main` = `2e65f23`.
- **Komutlar:**
  ```powershell
  git worktree add -q --detach <scratch>\wt HEAD
  New-Item -ItemType Junction <wt>\web\node_modules -> ana web\node_modules
  Copy-Item src\SentezServis.Host\appsettings.json <wt>\src\SentezServis.Host\   # örnek ayar üretilsin
  powershell -File <wt>\deploy\yayinla.ps1
  Compress-Archive <wt>\yayin\* SentezServis-2026-09-29-siparis-planlama-misirli.zip
  cmd /c rmdir <wt>\web\node_modules ; git worktree remove --force <wt>
  ```
- **Sonuç:** `SentezServis-2026-09-29-siparis-planlama-misirli.zip`, 73,8 MB. Arayüz tarihi 2026-09-29 10:37.
- **Doğrulama (25.09 paketiyle karşılaştırma):**
  - Dosya listesi aynı (18 dosya).
  - app.js: karsit-kodlar 6 → 6, Pierre 3, Mısırlı 1, rayic 11, kasa 13 (korunmuş).
  - Yeni: `siparis-planlama` 0 → 9, `paketDokumu` 0 → 1.
  - `appsettings.ornek.json`: 6 × `Password=<DOLDURUN>`; `appsettings.json` pakette yok.
- **Kurulum sonrası:**
  - Açılışta migration 021 (`siparis_planlama_gunlugu`) koşar.
  - `/api/surum` → `arayuzTarihi` 2026-09-29 10:37.
  - Planlama ekranı Entegrasyon bağlantısına yazar: sunucuda bu bağlantı test ERP'yi gösteriyorsa test'e yazar.

## Açık kalanlar / sonraki adım
- Canlıya geçiş: canlıda depo yeri kurulumu (bakım penceresi) + Entegrasyon bağlantısının canlıya çevrilmesi.
  İkisi de ayrı onayla yapılır.
- Sipariş planlama ertelenen küçükler (M1–M6, 28.09 günlüğü).
- Shopify indirim kodu, el terminali açık soruları.
