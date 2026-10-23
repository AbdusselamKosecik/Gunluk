# Saas_erp — 2026-10-24

## Bağlam
Dünkü tema/akordeon menü işinin devamı; kullanıcı menünün kategori/modül bazlı yeniden düzenlenmesi için öneri istedi.

## Yapılanlar

### Menü düzeni önerisi (Excel)
- **Neden:** Kullanıcı: "kategori ve modül bazlı … menülerin düzenlediğin excel oluşturabilir misin? kullanıcı kolaylığı ve anlam bütünlüğü olacak şekilde".
- **Ne yapıldı:** Güncel menü koddan çıkarıldı. Geçici bir vitest dosyası `HomeMenu` + `applyMenuLayout(STANDARD_MENU_LAYOUT)` + tr çevirileriyle ağacı JSON'a döktü; dosya sonra silindi. Çıkan menü: 27 modül, 369 satır, 363 farklı sayfa. Excel'i `scratchpad/menu_xlsx.py` (openpyxl) üretti. Script her mevcut sayfanın öneride yer aldığını kontrol ediyor.
- **Öneri:** 7 kategori (Genel, Ticari, Stok & Lojistik, Üretim, Finans & Muhasebe, İK, Sistem) ve 21 modül; bildirim ve mesaj üst çubuğa. Sıralama: önce iş, sonra rapor, en son tanımlar. Her sayfa tek yerde ('Tüm Faturalar' 3 kez görünüyordu). 6 üretim modülü için ortak şablon. Dokuma'nın 23 düz satırı 7 gruba ayrıldı. Organizasyon, Abonelik, İş Akışları ve Geliştirici Ayarlar altında grup oldu.
- **Excel sayfaları:** Özet (COUNTIFS sayımları) / Önerilen Menü / Mevcut Menü (yeni yeriyle) / Üretim Şablonu / Sorunlar & Kararlar.
- **Bulunan sorunlar:** `ExportFiles.menu` çevrilmemiş. Muhasebe'de iki 'Projeler' sayfası var (`/finance/project` ve `/finance/projects`). 'Ekstreler' ile 'Cari Hesap Ekstresi' karışıyor. Kalite tanımları ve muayene ekranları üç farklı yerde.
- **Dokunulan dosyalar:** `docs/design/menu-duzeni-onerisi.xlsx` (kopyası `C:\Users\abdus\Documents\VuoApp-menu-duzeni-onerisi.xlsx`).
- **Sonuç:** Yalnız öneri; kod değişmedi. Uygulamaya geçmek kullanıcı onayına ve kurula bağlı. LibreOffice kurulu olmadığından formüller yeniden hesaplanmadı (dosya açılışta hesaplıyor); sayımlar Python'da doğrulandı.
- **Commit:** `b7c014ad` — docs(menu): kategori/modul bazli menu duzeni onerisi (Excel)

## Açık kalanlar / sonraki adım
- Kullanıcı önerinin ne kadarını onaylıyor? Onay gelirse kurul (cto, skeptic, product-owner, ux), sonra `standard-menu-layout.tsx` ve sol şerit kategorileri.
- Karar bekleyenler: iki 'Projeler' sayfası, 'Ekstreler' adı, kalite tanımlarının tekleştirilmesi.

### Yeni sol menü düzeni uygulandı + DEV 1.0.2.1050
- **Neden:** Kullanıcı Excel önerisine "yap paket çık bakalım nasıl olacak" dedi.
- **Kurul:**
  - cto ve skeptic: APPROVE-WITH-CONDITIONS. Koşullar uygulandı:
    - sayfalar kaynak modüle göre aranıyor;
    - modül kimliği çeviriden bağımsız `key`;
    - aynı sayfa iki modüldeyse kullanıcının geldiği modül korunuyor;
    - tam / yalnız Örme / raporlamasız lisans testleri;
    - 11 dil;
    - changelog;
    - dosyalar 300 satırın altında.
  - ux-reviewer: PASS-WITH-NOTES. Düzeltilenler: İngilizcede şerit etiketinin kelime ortasından bölünmesi, Konfeksiyon grup sırası, kesilen "Otomasyon & Entegrasyon" (tr: "Otomasyon & API").
  - product-owner çağrılmadı: kullanıcı öneriyi doğrudan onayladı.
- **Teknik:**
  - `menu-layout.ts` `applyMenuLayout` artık tüm modülleri kapsıyor. Yeni alanlar: `sources` (modül yalnız kaynak modül görünürse kurulur ve sayfaları yalnız oradan alır), `from`, `fallback` (ikinci geçişte sahipsiz sayfayı alır), sayfa `title`. Yerleşmeyen sayfa eski modülünde kalıyor. `MenuPlacement` ve `STANDARD_PATH_PREFIXES` kaldırıldı.
  - Düzen verisi dosyalara bölündü: `menu-layout.commercial.tsx`, `menu-layout.production.ts`, `menu-layout.finance-system.tsx`.
  - `NavItem.key` ve `NavItem.category` eklendi.
  - Yeni `findActiveModuleKey(…, preferKey)`; eski `findActiveModuleTitle` kaldırıldı.
  - Şeritte kategori başlıkları var. Açık bölüm tercihleri artık modül key'iyle saklanıyor; mevcut tercihler bir kez sıfırlanır.
  - Çeviri: 55 yeni anahtar, 11 dil (`b25.json`). `ExportFiles.menu` eklendi. tr `f8a` "Tezgah Planlama" yazımı düzeltildi.
- **Kapı tamiri (ayrı commit):** Abdurrahman'ın `5efef44c` (Makine Panosu) commit'i kapıyı kırmıştı:
  - `border-l-*` → `border-s-*` (RTL kuralı);
  - `node scripts/extract-api-errors.mjs --write`;
  - `api-errors` tr/en'e 10 `machine_ops.*` mesajı. Diğer 9 dil İngilizceye düşüyor.
- **Doğrulama:** `bash tools/verify.sh frontend` rc=0, 1872 test. Chrome'da yerel kontrol: Dokuma grupları doğru; Örme › Reçeteler'e gidince Örme'de kalınıyor.
- **Commit'ler:**
  - `b9058d03` fix(frontend): kalite kapısı (machine_ops)
  - `f184d66a` feat(menu): yeni sol menü düzeni
- **DEV:** 1.0.2.1050 elle derlendi ve deploy edildi. Kontroller: deploy cevabı `status ok`, spa 200, api 200, robots `Disallow`, yeni paket `catStockLogistics` içeriyor.
- **UX notlarından açık kalanlar:**
  - mobilde seçili modül şeritte görünür alana kaydırılmıyor;
  - mobil ana panelde modüller kategorisiz listeleniyor;
  - açık sayfanın bölümü akordeonda açık kalıyor (bilinçli);
  - "İnsan Kaynakları" kategorisinde tek modül var.
