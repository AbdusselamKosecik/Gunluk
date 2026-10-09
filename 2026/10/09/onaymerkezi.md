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

### 2. Grup onayı kararı
- **Neden:** Kullanıcı: mesaj bir gruba gitsin; grupta 10 kişi var, 3 onay gerekiyor.
- **Ne yapıldı:** `docs/tasarim-taslak.md`'ye "Grup onayı" bölümü: grupta tek mesaj, "Onay: x / 3" sayacı,
  her basışta editMessageText, 3. onayda ONAYLANDI + butonlar kalkar, yetkisizin basışı answerCallbackQuery
  ile reddedilir. Tablolar: `UZM_TelegramGrup` eklendi, `UZM_OlayMesaj` yerine `UZM_OlayKarar` (kişi başı karar).
- **Commit:** `14912b5` — Tasarim: grup mesaji, N onay esigi
- **Açık:** ret kuralı, yetkili kişiler (10'un hepsi mi), karar değiştirme.

### 3. Spec tamamlandı (kalan kuralları Claude belirledi)
- **Neden:** Kullanıcı: "sen istediğin gibi ayarla".
- **Ne yapıldı:** `docs/tasarim-taslak.md` → `docs/superpowers/specs/2026-10-09-onaymerkezi-design.md`.
  Kararlar: ret eşiği olay türü başına (varsayılan 1, ret notu zorunlu, force_reply); yalnız yetkili kişiler sayılır;
  kişi tanıma botun gördüğü kişilerden (UZM_TelegramKisi); karar değiştirilebilir (son karar sayılır, geçmiş log);
  isteğe bağlı zaman aşımı; kapanınca butonlar kalkar; API anahtarı (X-Api-Anahtari); sonuç GET + opsiyonel geri
  çağırma; panel Sentez girişi + TR/EN/AR; bot long polling, token panelden. API v1, 4 panel ekranı, 8 UZM_ tablosu.
- **Commit:** `3bff88c` — Spec: Onay Merkezi tasarimi
## Sonraki adım
- Spec onayı → writing-plans → uygulama. Kullanıcıdan: BotFather token + botu gruba eklemek.

### 4. Pastal onayı + yapay zeka onaycısı
- **Neden:** Kullanıcı: amaç pastal bilgisinin gitmesi; "Yapay zeka onayladı, Ahmet onayladı, Mehmet şu sebepten onaylamadı" gibi.
- **Ne yapıldı:** Spec'e iki bölüm eklendi. (1) İlk kullanım = kesimhane pastal revizyonu
  (`UZM_PastalRevizyon`: en, boy, kat, verim, pay, beden×kat başı adet, yerleşim PNG). Sonuç OnayDurum/OnayAt/OnayNotu'na yazılır.
  (2) Yapay zeka onaycısı: Claude API, panelde olay türü başına kurallar metni, JSON çıktı {karar, gerekce}.
  YZ onayı 1 onay sayılır (YzSayilir), YZ reddi olayı tek başına düşürmez. API'ye `veri` JSON + `gorsel` eklendi.
- **Commit:** `2ad2fc5` — Spec: pastal onayi ornegi ve yapay zeka onaycisi

### 5. Görev bazlı onay yetkisi
- **Neden:** Kullanıcı: kimlerin onaylayabileceğini görev bazlı tanımlayacağız.
- **Ne yapıldı:** Spec'e "Görev bazlı yetki": görevler + kişi atama (çoka çok), olay türünde onaylayan görevler ve
  görev başına EnAzOnay (örn. pastal: toplam 3; Kesimhane Şefi ≥1, Planlama ≥1). Çok görevli kişinin onayı tek onay,
  kotada eşleştirme ile sayılır. Mesajda isim yanında görev ve eksik kota satırı. Tablolar UZM_OnayGorev,
  UZM_OnayGorevKisi, UZM_OlayTuruGorev (UZM_OlayTuruYetkili kalktı); UZM_OlayKarar'a GorevId.
- **Commit:** `cab1381` — Spec: gorev bazli onay yetkisi
