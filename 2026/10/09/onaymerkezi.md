# onaymerkezi — 2026-10-09

## Bağlam
Dünkü iskelet sonrası onay akışı kararları.

## Yapılanlar

### 1. Onay akışı kararları tasarım taslağına işlendi
- **Neden:** Kullanıcı: "gördü"yü iptal et; Onayla/Reddet koyalım; kim onayladı/kim onaylamadı anket gibi görünsün.
- **Ne yapıldı:** `docs/tasarim-taslak.md`: Telegram "gördü" kısıtı bölümü kaldırıldı, "Onay akışı" bölümü eklendi
  (Onayla/Reddet butonları, ret notu, her karar sonrası tüm alıcılardaki mesaj editMessageText ile
  ✅/❌/⏳ listesiyle güncellenir; panelde aynı görünüm). `UZM_OlayMesaj`'dan GorulduZaman çıktı.
  Telegram'ın yerleşik anketi kullanılmayacak (zaman/not/karar kuralı bizde).
- **Commit:** `39492d0` — Tasarim: gordu iptal, Onayla/Reddet, anket gibi durum mesaji

## Açık kalanlar / sonraki adım
- Karar kuralı (herkes / çoğunluk / ilk onay; tek ret düşürür mü), karar değiştirilebilir mi,
  grup sohbeti mi özel mesaj mı, kullanıcı eşleştirme, ilk olay türleri.
