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

### 6. Uygulama planı + bildirim olayları
- **Neden:** Kullanıcı "başlayalım"; ardından botu (@modfex_bot) "modfex onay" ve "modfex bildirim" gruplarına ekledi.
- **Ne yapıldı:** `docs/superpowers/plans/2026-10-09-onaymerkezi.md` (12 görev, TDD, tam kod): KararMotoru (kota eşleştirme),
  MesajBicimleyici, UZM_ şema + Dapper depo, OlayServisi, YZ/iptal/zaman aşımı, Telegram long polling, Claude YZ,
  API + anahtar, panel (giriş/dil/olaylar, türler/görevler, Telegram/uygulamalar), Windows servisi (port 8086).
  Spec'e bildirim olayları (GerekenOnay = 0 → butonsuz, durum Bildirildi=5) ve `/kayit` ile kişi/grup tanıma eklendi.
- **Doğrulama:** Bot token'ı getMe ile doğrulandı (gizlilik modu açık). Token repoya/günlüğe yazılmadı; panelden UZM_OnayAyar'a girilecek.
- **Commit:** `c7bb6b4` — Uygulama plani (12 gorev) ve spec: bildirim olaylari, /kayit
## Sonraki adım
- Kullanıcı planı onaylayıp yürütme yöntemini seçecek; Task 3'te DDL'in SentezCore'a uygulanması için ayrıca onay istenecek.

### 7. Planın uygulanması (12 görev, inline, main dalında)
- **Neden:** Kullanıcı "yaz hacım" — planı bu oturumda yürüt.
- **Yöntem:** superpowers:executing-plans; her görev TDD (önce test kırmızı, sonra yeşil), plan kod blokları
  scratchpad'deki `cek.py` ile plandan birebir dosyaya kopyalandı (yeniden yazım hatası olmasın).
  Defter: `.superpowers/sdd/2026-10-09-onaymerkezi/progress.md` (gitignore'da).
- **Commitler:**
  - a0fe4b8 Dagitim betikleri (gitignore'daki dagitim/ kuralina ragmen izlenir)
  - a2b759a Windows servisi, dagitim betikleri, README ve spec guncellemesi
  - c21e93b Panel: Telegram/YZ ayarlari (gizli degerler maskeli), kisiler, uygulama anahtarlari
  - 5496890 Panel: olay turleri (gorev kotalari, YZ kurallari) ve gorevler (kisi atama)
  - 6117b39 Panel: Sentez girisi, TR/EN/AR, olay listesi ve detayi, iptal
  - fc1194f API: olay olustur/sorgula/iptal, uygulama anahtari filtresi, Program baglantilari
  - 0fecf6c Claude YZ degerlendirici: yapilandirilmis cikti, gorsel, refusal fallback
  - 4ca817a Telegram long polling, istemci, guncelleme cevirici; arka plan, zamanlayici, geri cagirma
  - 7ad5902 OlayServisi: YZ akisi, iptal, zaman asimi ve yeniden gonderme turu
  - 5b64981 OlayServisi: olustur/gonder, Onayla/Reddet, ret notu, kisi/grup kaydi, olay kilidi
  - 5a7c9ac UZM_ sema, IOnayDeposu, SqlOnayDeposu (Dapper), BellekDepo
  - 288eb2d Telegram mesaj bicimleyici (tr/en/ar), gorsel turu, buton verisi
  - 3a1ffa5 Alan modelleri ve KararMotoru (gorev kotalari, YZ sayimi, ret esigi)
- **Sonuç:** `dotnet test` → 100 geçti, 4 atlandı (3 DB testi `MODFEX_ONAY_DB` yok, 1 ücretli canlı YZ testi).
  `dotnet build -c Release` 0 uyarı. `yayinla.ps1` ile yayın alındı; bağlantı metni yokken uygulama açılışta durur (doğru).
- **Plandan sapmalar (rulings):** Telegram.Bot 22'de `Message.Id`; Anthropic SDK adları `MediaType`, `Effort`,
  `List<BetaFallbackParam>`; API'de durum sayfası yalnız /api dışı (401/404 yönlendirmeye dönüyordu);
  BaglantiAyari açılışta kontrol; sorgu parametresi byte? yerine int?; form POST testleri eklendi.
- **Ertelenen:** DDL'in SentezCore'a uygulanması (kullanıcı onayı), DB entegrasyon testleri, canlı uçtan uca deneme.
- **İnceleme:** son bütün-dal incelemesi bağımsız ajanla yapılıyor.
