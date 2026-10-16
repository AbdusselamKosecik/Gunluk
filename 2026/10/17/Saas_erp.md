# Saas_erp — 2026-10-17

## Bağlam
İki panelli menü denemesi `feat/iki-panelli-menu` dalında sürüyor. Kullanıcı standart modüllerin Sentez gibi süreç bazlı ayrılmasını istedi (Envanter, Satın Alma, Satış Dağıtım, Finans…) ve SAP ile diğer ERP'lerin bunu nasıl ayırdığını sordu. Üretim modüllerine dokunulmayacak.

## Yapılanlar

### 1. ERP karşılaştırması (sohbette)
- SAP: MM (satın alma + stok + fatura kontrolü), SD (satış + sevkiyat + faturalama), FI/CO. Logo Tiger: Satınalma, Satış ve Dağıtım, Malzeme Yönetimi, Finans, Muhasebe. Sentez: Satın Alma, Satış, Malzeme, Finans, Genel Muhasebe. Netsis ve Odoo da benzer.
- Ortak ilke: belge türüne göre değil, süreçe göre ayırmak (talep → teklif → sipariş → irsaliye → fatura aynı modülde).

### 2. Süreç bazlı standart menü düzeni
- **Neden:** Bizde satın alma süreci Siparişler, Envanter, Finans ve Talep modüllerine dağılmıştı.
- **Ne yapıldı:**
  - `two-panel/menu-layout.ts`: `applyMenuLayout(modules, layout)` fonksiyonu. Sayfaları adresleri üzerinden yeniden gruplar.
    - Yalnızca tüm sayfaları `/inventory|orders|demand|logistics|crm|finance/` altında olan modüller "standart" sayılıyor, üretim modülleri hariç tutuluyor.
    - Sadece menüde görünen sayfalar yerleşiyor; lisans ve yetki filtresi korunuyor.
    - Düzende yeri olmayan sayfa eski modülünde kalıyor. Boş gruplar ve modüller budanıyor.
  - `two-panel/standard-menu-layout.tsx`: yeni modüller Stok, Satın Alma, Satış ve Dağıtım (Lojistik dahil), Fason, Finans (Cari/Kasa/Banka/Çek/Ödeme/Fatura/Kur-Vade/Döviz/Dış Ticaret), Muhasebe (Genel Muhasebe/Raporlar/Maliyet/Sabit Kıymet) ve CRM. Fiş tipleri `?type=` kodlarıyla dağıtıldı (ör. 3001 Mal Alım → Satın Alma, 3052 Toptan Satış → Satış, 3057 Fason Verilen Çıkış → Fason). "Tüm Siparişler / Teklifler / Talepler / Faturalar" hem Satın Alma'da hem Satış'ta duruyor.
  - `routes.tsx` değişmedi; sayfa adresleri aynı. Klasik menü eski gruplamayı gösteriyor.
- **Testler:** `menu-layout.test.ts` 6 test (yeniden gruplama, budama, artakalan sayfa, üretim modülüne dokunulmaması). `standard-menu-layout.test.ts` gerçek `HomeMenu` ile 3 test (her standart sayfa yerleşmiş, düzendeki her adres menüde var, üretim modülleri aynı). `src/layouts` toplamı 41 test geçti, typecheck temiz.
- **Görsel doğrulama:** playwright ile kontrol edildi. Şerit sırası: Anasayfa, Stok, Satın Alma, Satış ve Dağıtım, Fason, Finans, Muhasebe, CRM, Üretim, Boyahane… Mal Alım İrsaliyesi açıkken Satın Alma seçili.
- **Commit:** dal `feat/iki-panelli-menu`, push edildi.

## Kararlar
- Gruplama `routes.tsx` yerine menü katmanında yapıldı. Sebebi: route adresleri ebeveyn yolundan türetiliyor; öğeleri taşımak adresleri ve linkleri bozardı.

## Açık kalanlar / sonraki adım
- Kullanıcı onaylarsa kurul (CTO, Şüpheci, UX, Product Owner) çalıştırılacak, `dev`'e merge edilecek ve changelog maddesi eklenecek.
- Yeni modül başlıkları sabit Türkçe; i18n anahtarı yok (İngilizce arayüzde de Türkçe görünür).
