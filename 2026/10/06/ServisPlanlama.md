# ServisPlanlama — 2026-10-06

## Bağlam
04.10'da otomatik rota önerici (OSM/OSRM) yapılmıştı (`a59e135`). Kullanıcı kapsamı değiştirdi: elle yönetilen bir
**servis planlama uygulaması** istendi — servis + kapasite, duraklar, PDKS'ten personel ama oturma adresi/durak/servis
bağlantısı bizim DB'de, servis ekle/sil/sırala, personeli **sürükle-bırak** kapasite sınırlı atama, "hesapla" ile
duraklara göre haritada tek tek gösterim + süre, web'den **günlük giriş** (servis no ile kaç kişi geldi, saat kaçta).
Gün içinde eklenenler: **aylık geç gelme raporu + Excel**, **TR/EN/AR dil**, **haritada tüm personel + duraklar**.
Kullanıcı kararları: günde servis başına tek kayıt; basit giriş (yönetici / giriş rolleri); otomatik öneri taslak
olarak aktarılabilir kalsın.

## Yapılanlar

### 1. DB: kendi tablolar, açılışta otomatik kurulum
- **Neden:** zkbiotime salt okunur; ek bilgiler bizde. Sunucuda elle SQL adımı azalsın.
- **Ne yapıldı:** `db/000_veritabani.sql` (yalnız CREATE DATABASE, elle bir kez). `db/tablolar/001_konum.sql` (eski tablolar),
  `002_servis.sql`: `Kullanici`, `Servis` (No, Ad, Kapasite, Plaka, Sofor, SoforTelefon, HedefVaris, Sira, Silindi;
  filtreli unique index No WHERE Silindi=0), `Durak`, `ServisDurak` (sıra), `PersonelServis` (OturmaAdresi, ServisId, DurakId),
  `GunlukGiris` (UNIQUE Tarih+ServisId), `Ayar` (VarsayilanVaris 07:45, GecikmeToleransDk 0).
  `Depo.TablolariKurAsync` açılışta `db/tablolar/*.sql`'i GO satırlarından bölüp çalıştırır (betikler IF OBJECT_ID ile
  idempotent); csproj `<None Include="..\..\db\tablolar\*.sql" Link=...>` ile çıktıya kopyalanır.
- **Kararlar:** servis/durak silme = işaretleme (günlük kayıtlar raporda kalsın). Kapasite kontrolü sunucuda Serializable
  işlem + UPDLOCK (iki kişi aynı anda son koltuğa sürüklese taşmaz). UPSERT'te `UPDATE ... OUTPUT` + `IF @@ROWCOUNT=0 INSERT OUTPUT`
  ExecuteScalar ile null döner (ilk boş sonuç kümesi) → `DECLARE @id; UPDATE SET @id=Id ...; SELECT @id` kullanıldı.

### 2. Kimlik
- Cookie auth (`ServisPlanlama`, 12 sa kayan), roller `yonetici` / `giris`; PBKDF2-SHA256 100k tur (`Kimlik/Parola.cs`).
  Hiç kullanıcı yoksa `/giris.html` ilk yöneticiyi oluşturur. `Sayfalar` ara katmanı: `/` yalnız yönetici, `/gunluk.html` girişli.
  API 401/403 döner (yönlendirme değil).

### 3. Planlama ekranı (`/`)
- **Servisler panosu:** SortableJS (yerel `lib/sortable`, MIT). Atanmamış listesi ↔ servis kartları; `put` ile dolu servise bırakma
  engellenir (sunucu da reddeder); bırakınca durak = ev konumuna en yakın güzergâh durağı. Servis kartları tutamakla sıralanır.
- **Harita & Hesap:** güzergâh listesi sürükle-sırala, haritaya tıkla → yeni durak, durak işaretini sürükle → taşı,
  "Sırayı optimize et" (OSRM matris + mevcut Cozucu, dev sabit maliyetle tek araç), "Hesapla" (`ServisHesap`: OSRM route,
  ayak süreleri, durak başı 60 sn, hedef varıştan geriye alış saati), ◀ ▶ / ← → ile durak durak. "Tümü" = tüm servis özeti.
- **Personel:** BioTime + oturma adresi (girilince konum hemen yeniden aranır; `PersonelKaynagi` etkin adresi verir), servis/durak satır içi.
- **Otomatik öneri:** eski planlayıcı; `TaslakAktarici` son öneriyi servis/durak/atamaya yazar (durak adı = en yakın bölge + sıra).
- **Ayarlar:** genel hedef varış + tolerans, konum araması, kullanıcılar.

### 4. Günlük giriş (`/gunluk.html`)
- Büyük alanlar: tarih ◀ ▶, Servis No (yazınca servis kartı), gelen kişi −/+, varış saati (Şimdi), not; Enter ile ilerler;
  kaydedince bildirim (+N dk geç) ve imleç servis no'ya döner. Sağda günün servisleri, girildi/girilmedi, geç/zamanında.
  Giriş rolü en çok 7 gün geriye; ileri tarih yok; kapasite aşımında onay.

### 5. Geç gelme raporu
- `Rapor/GecikmeRaporu.cs` (saf hesap, test edildi): geç = varış > (servis hedefi ?? genel hedef) + tolerans.
  Servis başına girilen gün, geç gün, toplam/ort/en fazla gecikme, ort. gelen. Silinmiş servisin o ay kaydı raporda kalır.
- `GecikmeExcel.cs` (ClosedXML 0.105.1, sentezservis'teki gibi): Özet / Gün Gün (kırmızı geç, yorumda kişi+giren, Cuma gri) / Kayıtlar (filtreli).
- Ekranda ay seçici, özet tablo, gün gün matris, "Excel indir".

### 6. Çok dil (TR / EN / AR)
- İstemci: `wwwroot/dil.js` (~250 anahtar × 3 dil), `data-t / data-t-ph / data-t-title / data-t-html`, `t(anahtar, ...args)`;
  seçim localStorage + `dil` çerezi; Arapçada `<html dir="rtl">`. CSS mantıksal özelliklere çevrildi; `.leaflet-container{direction:ltr}`.
  Sunucunun Türkçe konum açıklamaları `aciklamaCevir` ile sabit ifadeleri çevrilir.
- Sunucu: `IsKuraliHatasi(sablon, args)`; `Kimlik/Mesajlar.cs` Türkçe şablon → EN/AR, çerezden dil; Excel `Uret(rapor, dil)`, AR'de RightToLeft.
- **Hata yakalandı:** `rapor.js`'de `r.gunler.map((t, i) => ... t("r.ipucu"))` → `t` gölgeleniyordu; `(tarih, i)` yapıldı,
  tüm `reduce((t, …))` → `top`.
- Doğrulama: node ile tüm `t("…")`/`data-t` anahtarlarının sözlükte 3 dilde olduğu kontrol edildi (244 kullanılan, eksik 0);
  C# testi: kaynak koddaki her mesaj şablonunun çevirisi var.

### 7. Haritada tüm personel + duraklar (durak belirlemek için)
- Katmanlar: Tüm personel (servis seçiliyken diğerleri soluk), Atanmamışları vurgula (kırmızı halka), Tüm duraklar (yolcu sayılı balon),
  Personel → durak çizgileri; lejant.
- Sorun: taslak duraklar kişilerin tam konumunda → noktalar balonun altında, aynı noktadakiler üst üste. Çözüm: kişiler divIcon,
  aynı 4-ondalık noktadakiler (ve durak üstündekiler) **piksel spirali** ile dağıtılır (altın açı, r = 14 + 4.2√i px); veri değişmez.
- Kişi penceresi: servisi/durağı, en yakın durak (km), "Servis X'e ata", "Buraya durak koy", "Konumu düzelt", "Ayrıntı".

## Komutlar
```bash
dotnet test ServisPlanlama.slnx                      # 34 test
ASPNETCORE_ENVIRONMENT=Development dotnet run --project src/ServisPlanlama --urls http://localhost:8086
# duman testi — Git Bash'te curl JSON'unda Türkçe karakter gönderme (cp1254 gider, sunucu UTF-8 hatası verir)
curl -c c.txt -b c.txt -X POST localhost:8086/api/oturum/kurulum -H Content-Type:application/json -d '{"kullaniciAdi":"admin","adSoyad":"Yonetici","parola":"..."}'
curl -b c.txt -X POST localhost:8086/api/oneri/aktar        # 29 servis, 87 durak, 336 kişi
```
Not: uzun Python düzenlemelerini bash heredoc'una gömmek iki kez "unexpected EOF" verdi; betiği dosyaya yazıp çalıştırmak güvenli.

## Sonuç / doğrulama
- Tarayıcıda (chrome-devtools): giriş → pano (29 servis, 335/434 koltuk), sürükle-bırak atama ve dolu serviste ret, Servis 11 hesap
  (86 dk, 79.3 km, ilk alış 06:19, durak adımlama), günlük giriş (+7 dk geç), rapor ekranı ve Excel (3 sayfa), Arapça RTL, harita katmanları.
- Yerelde DB'de test için `admin` yöneticisi oluşturuldu ve 4 günlük test kaydı girildi (Servis 1, 2, 7) — canlıya geçmeden silinmeli.
- **Commit'ler:** `48c2f1b` servis yönetimi, `0643713` çok dil + harita katmanları → https://gitlab.com/modfex-apparel/servisplanlama

## Kararlar
- Günlük: servis+gün başına tek kayıt (tekrar giriş günceller).
- Personeli servise atarken durak: ev konumuna kuş uçuşu en yakın güzergâh durağı (öneri; elle değiştirilebilir). Süre hesapları yol ağıyla.
- Gecikme dakikası hedefe göre (tolerans düşülmez); tolerans yalnız "geç mi" kararında.

## Açık kalanlar / sonraki adım
- modfexsrv kurulumu (`deploy/yayinla.ps1` → `servis-kur.ps1`), canlı DB'de test kullanıcısı/kayıtlarını temizlemek.
- Gerçek servis numaraları, plakalar, şoförler girilmeli; taslak durak adları (bölge + sıra) sahaya göre düzeltilmeli.
- İstenirse: akşam dönüş seferi, servis bazında kişi listesi yazdırma (çok dilli), mobil için günlük ekranın PWA'sı.
