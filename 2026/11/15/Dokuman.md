# Dokuman — 2026-11-15

## Bağlam
Kullanıcı `Modfex_Workflow.pdf` (iş akışı el kitabı v1.0, 22 adım, 9 bölüm) verdi; buna göre yapılacakları ve birimlere gereken raporları madde madde istedi, sonra cevaplayabilmek için md dosyası olarak istedi.

## Yapılanlar

### 1. İş akışı yapılacaklar listesi
- **Neden:** El kitabındaki adımları mevcut uygulamalarla (malkabul, depo, kesimhane, bantsayim, paketleme, sevkiyatmobil, İşlem Merkezi = sentezservis web) eşleştirip eksikleri ve kararları çıkarmak.
- **Ne yapıldı:** `Modfex_Workflow_yapilacaklar.md` yazıldı. Bölümler: A) [TBC] karar soruları ve kılavuz çelişkileri (Cevap: satırlarıyla), B) adım bazında yazılım durumu, C) bekleyen kurulumlar (öncelik sütunu), D) G1–G6 kılavuz ve S1–S22 ekran görüntüsü eksikleri, E) 10 birim için rapor listesi (🟢 veri var / 🟡 kısmen / 🔴 önce adım gerekli, "İstiyor muyuz?" sütunu).
- **Önemli bulgular:** Adım 16 "kesilen adetten fazla değil" kontrolü için kesilen adet hiçbir yere kaydedilmiyor; el kitabı alan 42'ye "depo değil" diyor ama Sentez'de depo 42 (Fiş 10 / 130); adım 14 pastal verimi, adım 10/13 Sentez'e fiş yazılmadan hesaplanamaz; Nour'un adımı yok.
- **Dokunulan dosyalar:** `Dokuman/Modfex_Workflow_yapilacaklar.md`
- **Commit:** `64f61cc` — İş akışı el kitabına göre yapılacaklar, karar soruları ve birim raporları

## Açık kalanlar / sonraki adım
- Kullanıcı dosyadaki cevapları dolduracak; cevaplara göre seri/tahsis, kesilen adet kaydı ve 🟢 raporlar planlanacak.

### 2. Kullanıcı cevapları ve değerlendirme (F bölümü)
- **Neden:** Kullanıcı md dosyasına cevapları yazdı; netleşenleri ve açık kalanları ayırmak.
- **Kararlar (kullanıcı):** mal kabul = fiş 1; numune onayı Elif Hanım ekibi → 17, red → iade fişi; kesime 129, iade 29 (günlük); aksesuar banda 17; kesilen adet uygulamadan girilip Sentez kesim kayıtlarına yazılacak; alan 42 sorumlusu Reyhan + Seyhan Hanım, Sentez'de depo olarak kalır; tahsis Sentez tablolarıyla (gerekirse kolon/alt tablo eklenebilir); Nour için adım yok (son inspection); G1–G6 biz yazarız; raporlar Superset + günlük e-posta + Telegram.
- **Canlı kontrol (salt okunur):** kullanılan fiş tipleri 1,10,16,17,29,99,100,101,120,129,130; depolar RecId 1 General, 40 Reserved, 41 Product (M), 42 Uretim (U); kesim alanları `Erp_WorkOrderProduction` (SentForCutting, Cutter, CuttingLoss, UD_CuttingApprove); `Erp_InventoryAllocation.SerialCardId` mevcut; UZM_Pastal*/UZM_KesimGiris tabloları boş.
- **Açık sorular (F2):** kabul/karantina deposu, adım 8 fişi, iade fiş tipi (101?), 129/29 gün sonu tetikleyicisi, aksesuar sarfı, kesim ekranı, kurulum sırası, rapor alıcıları/saat.
- **Commit:** Dokuman `git log -1` — İş akışı: kullanıcı cevapları ve F bölümü

## Yapılanlar (akşam, 4. tur — G3 cevapları)

### G3 cevapları işlendi, H bölümü eklendi
- **Neden:** Kullanıcı G3'ü cevapladı: "Elle giriş yapılacak", "Kesim adet ve pastal alanları girilecek", "tek fiş olsun devam edelim".
- **Ne yapıldı:** `Modfex_Workflow_yapilacaklar.md` G3 cevap satırları dolduruldu; **H** bölümü: kesim kaydı Sentez'de elle kalır (adet + pastal alanları), bizim uygulama kesim yazmaz; 129/29 günde tek fiş; H1 yapılanlar tablosu. `DEVAM.md` baştan yazıldı (sıradaki 7 iş).
- **Yorum (kullanıcıya soruldu):** "Elle giriş" = Sentez'in kesim ekranında elle; uygulamadan değil.
- **Commit:** Dokuman `dafbde2`.

## Kararlar
- Kesim kaydı yazımı bizim kapsamımızdan çıktı; biz yalnız okuruz (rapor + bantsayim kontrolü).
