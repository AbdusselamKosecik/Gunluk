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
