# bantsayim — 2026-09-30

## Bağlam
Dünkü (29.09) üretim bant terminali işinin devamı: ekranlar yazılmıştı ama evdeki VPN (100.119.104.122) koptuğu
için DB testleri tamamlanamamıştı. Kullanıcı PL-001 şifresini verdi (`001`) ve firmaya geçildi.

## Yapılanlar

### 1. PL-001 şifresi doğrulandı
- `CONVERT(varchar(32), HASHBYTES('MD5', N'001'), 2) = Meta_User.Password` → yalnız PL-001 için doğru (diğer PL'ler farklı).

### 2. VPN'de testler neden düştü
- "pre-login handshake ... SSL Provider ... wait operation timed out": TCP kuruluyor, TLS el sıkışması 8 sn
  ConnectTimeout içinde bitmiyor. İlk hatadan sonra SqlClient havuzu "blocking period" ile sonraki açılışları
  1–3 ms'de düşürüyor (hepsi aynı hata). Kod sorunu değil, VPN yavaşlığı.
- `BantSayim.Tests/xunit.runner.json` → `parallelizeTestCollections: false` (DB testleri ortak statik durum
  paylaşıyor: Oturum, UygulamaBilgisi.KullaniciFiltresi) + csproj'da `CopyToOutputDirectory`.

### 3. Giriş testi
- `GirisTestleri.PL001_girisi_okutma_ekranina_yonlenir`: yanlış şifre ve listede olmayan (TRM-01) → GirisHatasi;
  PL-001/001 → Oturum.UserId 1134, rol Bant, `OkutmaViewModel.Olustur()` bant 1 şirket 2, `GosterildiAsync` hatasız.

### 4. Firmada tam test
- Yerel ayar `Sunucu` → `192.168.0.2` (yalnız bu makinedeki `%LOCALAPPDATA%\Modfex\bantsayim\ayarlar.json`).
- `MODFEX_DB_TEST=1 dotnet test BantSayim.Tests` → **41/41, 4 sn**. Canlı iz kontrolü: TST/URT box 0, fiş 10 yok,
  UZM_UretimBox/Okutma 0, applock 0, TestModu 0.
- **Commit:** `a95de06` — Testler: PL-001 giris/yonlendirme testi, DB testleri sirayla (GitLab + GitHub)
- Uygulama `dotnet run --project BantSayim.Desktop` ile kullanıcının ekranında açıldı (elle deneme için).

## Kararlar
- DB testleri sırayla çalışır.
- Evden çalışırken bağlantı yavaş; testler firmada (LAN) koşulmalı.

## Açık kalanlar / sonraki adım
- Kullanıcının arayüzü elle denemesi (PL-001). Canlıda gerçek okutma = gerçek box + 10 fişi (TestModu 0).
- Sentez kullanıcısı şifresi (yönetim ekranı elle denemesi için).
- Ortak SURUM 2'yi diğer repolara taşı; Ubuntu paketi; TestModu sorusu açık.

### 5. Açılışta açık box'tan devam
- **İstek:** "Açıldığında box var mı kontrol edelim, varsa ondan devam edelim."
- **Durum:** Zaten böyleydi — `OkutmaViewModel.GosterildiAsync` → `UretimDurumu.AcikBoxlarAsync` (UZM_UretimBox Durum=0)
  kartlara yükler; `UretimDeposu.OkutAsync` açık box'ı `UPDLOCK` ile alır, yeni box açmaz (iş emri farklıysa kapatır + yeni).
- **Eklenen:** ilk açılışta açık box varsa toast `AcikBoxDevam` ("Açık box'tan devam ediliyor: URT1-… (12)"), TR/EN/AR.
- Canlı kontrol: şu an açık box yok, okutma 0, fiş 10 yok.
- Build: açık uygulama DLL'i kilitlediği için Desktop derlenemedi; `BantSayim` + testler 41/41.
- **Commit:** `7f65a25` — Okutma: acilista acik box bildirimi
