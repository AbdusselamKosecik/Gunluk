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
