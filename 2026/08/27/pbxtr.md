# pbxtr — 2026-08-27

## Bağlam
Gün, demo paketinin Docker Hub'a çıkarılıp sunucuya alınmasıyla başladı; Asterisk bağlantısının
planlanmasıyla devam etti; kurul kararıyla kapandı. Günün sonunda HDD kaybı riski üzerine
git'e girmeyen dosyaların yedeklenmesi işi eklendi.

## Yapılanlar

### 1. Demo imajı Docker Hub'a, sunucu yeni imaja alındı
- **Neden:** Sunucudaki sürüm yereldeki 146 migration'lık zinciri taşımıyordu.
- **Ne yapıldı:** İmaj yerelde derlendi, iki etiketle Docker Hub'a push edildi
  (`sha256:da6f3aa3a83e…`), sunucuda önce **doğrulanmış yedek** alındı, sonra geçiş yapıldı.
- **Sonuç / doğrulama:** 105 → 146 migration canlı veri üzerinde uygulandı, 26/26 bekçi yeşil,
  veri kaybı yok (öncesi ve sonrası 19 kullanıcı / 11 tenant).

### 2. Docker sıfırlandı, volume'ler silindi, sıfırdan ayağa kaldırıldı
- **Neden:** Zincirin taze kurulumda gerçekten koştuğu hiç ölçülmemişti.
- **Ne yapıldı:** İşlem **yalnızca `pbxtr` compose projesine** kapsandı — sunucuda ikinci bir
  proje (`asterisk-lab`) çalışıyordu, genel bir `prune` onu da silecekti.
- **Sonuç:** Boş DB 146 migration'ın tamamını sıfırdan kurdu — zincirin staging'de ilk gerçek
  kanıtı. Seed taban çizgisi 17 kullanıcı / 3 tenant.

### 3. Santral bağlantı planı
- **Dokunulan dosyalar:** `doc/mimari/santral-baglanti-plani.md` (yeni, 7 faz)

### 4. Kurul — Karar #28 (Asterisk bağlantısı + root sistem ajanı)
- **Neden:** Kullanıcı §3.0'daki "Asterisk'e fiilen bağlanılmayacak" emrini geri çekti ve
  ayrıca iç IP'den ufw/fail2ban gibi komutları çalıştıracak root'lu bir servis istedi.
- **Ne yapıldı:** 10 üyeli kurul toplandı, 3 öneri oylandı.
  A (Asterisk bağlantısı) = ŞARTLI ONAY 10/10, B (sistem ajanı) = ŞARTLI ONAY 9-1,
  C (JsSIP) = ERTELENDİ (7/10 eşiğine ulaşılamadı).
- **Kritik:** Kurul **benim yazdığım planı üç noktada çürüttü** — faz sırası yanlıştı, Faz 2'nin
  negatif ölçümü `AmiTenantCode`'un dört tenant kaynağından üçüncüsüyle sessizce geçerdi, Faz 4'ün
  fail-open ölçümü **durmuş** bir pbxtr'ı ölçüyordu (doğrusu **asılı** bir uçtur).
- **Dokunulan dosyalar:** `yonetim/kurul-kararlari.md` (Karar #28), `doc/mimari/santral-baglanti-plani.md`
- **Sonuç:** 24 ClickUp kartı açıldı (A-00…A-14, B-01…B-09).
- **Commit:** `4d8c5b5d` — docs: Kurul Karar #28 — Asterisk baglantisi + root sistem ajani sartli onay

### 5. Git'e girmeyen dosyaların yedeklenmesi (HDD riski)
- **Neden:** Kod global kural #1 ile korunuyor, ama `.gitignore`'lı dosyaların **tek kopyası
  diskteydi.** Kod geri gelir; çalışmayan bir `.env` her şeyi durdurur.
- **Ne yapıldı:** 176 depo diskten tarandı. Kod tarafında hiçbir remote'ta olmayan tek iş
  `fredericTr/muftelif` → `feature/haftalik-planlama` dalındaki 3 commit'ti; push edildi.
  Git'te izlenmeyen 17 gizli dosya (pbxtr `.env`'i, ClickUp token'ı, SSH özel anahtarı dahil)
  yeni **private** `sifreler` deposuna alındı. Ağaç `X:\` yolunu birebir aynalar.
- **Sonuç / doğrulama:** Depo `private=true`. `.gitattributes` içine `* -text` konuldu —
  satır sonu dönüşümü SSH özel anahtarını checkout'ta bozuyordu; temiz klon `cmp` ile bayt bayt
  doğrulandı. `~/.claude` global kuralları, memory ve ajan tanımları da alındı (oturum kaydı ve
  cache **alınmadı**).

## Kararlar
- CLAUDE.md §3.0 ("Asterisk'e fiilen bağlanılmayacak") **kullanıcı tarafından geri çekildi.**
- Faz 4 (`pbxtr-edge`) kapanmadan üretimde `Telephony:Provider=asterisk` **açılamaz** (Karar #28).
- Git'e girmeyen her `.env` / anahtar, üretildiği turda `sifreler` deposuna da eklenir.

## Açık kalanlar / sonraki adım
- Kullanıcı iç sorunları birlikte düzeltmek istiyor ve **maddeleri kendisi yazacak** — beklemede.
- Bazı gizli dosyalar **kendi depolarına commit edilmiş** durumda (`UzmanAdres/**/PRIVATEKEY.pem`,
  `vuo-app/General/Ssl/vuo_app.key`, `Ref01/**/*.pfx`, `netkimlik/certificate.pfx`,
  `Otelday/**/otelDay.pfx`). Depolar public ise **anahtar rotasyonu gerekir** — ölçülmedi.
- A-14: gerçek (lab olmayan) Asterisk'i kimin, ne zaman sağlayacağı kurulda cevaplanamadı.
