# Dokuman — 2026-11-16

## Bağlam
Kullanıcı `Modfex_Workflow_yapilacaklar.md` F2 sorularını cevapladı.

## Yapılanlar

### 1. Cevapların işlenmesi ve G bölümü
- **Kararlar (kullanıcı):** mal kabul fiş 1 → 43 K Karantina Deposu; onay 17 ile 43 → 1; red fiş 122 (mal alım iade); 99/101 sayım fazlası/noksanı; 129/29 gün içinde tek açık fişe satır ekleme (bant sonu fiş 10 gibi); aksesuar da 129/29 (17 değil); kesim kaydı `Erp_WorkOrderProduction` + variant; kurulum sırası ve rapor grupları bana bırakıldı / gruplar kullanıcı dolduracak.
- **Canlı kontrol (salt okunur):** depo 43 K mevcut; kesim = proses 167 "Kesim" (kod 50), ProductionType 1; 1.072 kesim kaydı elle giriliyor (kullanıcı 116, 21.01.2025–12.11.2026, 25 iş emri), yalnız adet dolu, pastal alanları boş/0; variant tablosu WorkOrderItemVariantId+Quantity; tetikleyici yok; 122 tipi henüz hiç kullanılmamış.
- **Eklenen:** G1 son fiş akışı tablosu, G2 kesim bulguları, G3 yeni sorular (elle giriş bırakılacak mı, hangi alanlar, günlük fiş iş emri başına mı), G4 kurulum sırası önerisi (sevkiyatmobil+KLY tek APK önce), G5 rapor grubu tablosu (alıcı/Telegram/saat boş).
- **Dokunulan dosyalar:** `Dokuman/Modfex_Workflow_yapilacaklar.md`, `Dokuman/DEVAM.md`

## Açık kalanlar
- G3 cevapları ve G5 tablosu kullanıcıda.
- Sonraki iş: sevkiyatmobil KLY reddi + APK; seri/tahsis tasarımının G1 akışıyla güncellenmesi.
