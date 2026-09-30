# kesimhane — 2026-09-30

## Bağlam
Modfex Apparel suite'ine 6. uygulama olarak kesimhane isteniyor. İçerik (ekranlar) sonra planlanacak;
bugünkü hedef: bantsayim gibi Sentez girişli iskeleti kurup GitLab'a göndermek, bağlantı ayarlarını aynen taşımak.

## Yapılanlar

### 1. Proje iskeleti (bantsayim'den)
- **Neden:** Tüm suite uygulamaları aynı ortak kabuk/giriş/dil yapısını kullanıyor; yeni uygulama da öyle başlamalı.
- **Ne yapıldı:** `X:\Gitlab\modfex-apparel\kesimhane` oluşturuldu. bantsayim'den kopyalananlar: `.gitignore`,
  `.gitattributes`, `Directory.Packages.props`, `BantSayim/{App.axaml, App.axaml.cs, Assets, Ortak, Views, csproj}`,
  `BantSayim.Desktop/{app.manifest, Program.cs, csproj}`, `BantSayim.Android` (bin/obj hariç).
  Ortak dışındaki dosyalarda `BantSayim→Kesimhane`, `bantsayim→kesimhane` (sed). `Ortak/` birebir (en güncel hali, kiosk dahil).
  bantsayim'e özgü `Ekranlar/`, testler, db/, linux paketleme alınmadı.
- **Yeni dosyalar:** `Kesimhane/Ekranlar/UygulamaMetinleri.cs` (UygulamaAdi = Kesimhane / Cutting Room / قسم القص),
  `AnaSayfaViewModel.cs` + `AnaSayfaView.axaml(.cs)` (girişten sonra "Hoş geldiniz, {UserCode}" + "ekranlar hazırlanıyor").
  `App.axaml.cs`: `Kod="kesimhane"`, `KullaniciFiltresi` yok (kullanıcı kodu yazılır), `IlkSayfa = AnaSayfaViewModel`.
  `MainWindow` başlığı "Modfex — Kesimhane". csproj'dan `InternalsVisibleTo BantSayim.Tests` kaldırıldı. `Kesimhane.slnx`, `README.md`.
- **Komutlar:**
  ```bash
  dotnet build Kesimhane.Desktop -c Debug     # 0 hata, 0 uyarı
  ```
- **Sonuç / doğrulama:** Uygulama açıldı, giriş ekranı geldi, şirket listesi DB'den yüklendi (01 - 2025-MODFEX).

### 2. Bağlantı ayarları
- **Ne yapıldı:** `%LOCALAPPDATA%\Modfex\bantsayim\ayarlar.json` → `%LOCALAPPDATA%\Modfex\kesimhane\ayarlar.json`
  (Sunucu 192.168.0.2, SentezCore, uzman; DPAPI şifresi aynı kullanıcı + aynı entropi olduğu için çözülüyor).
  `SonKullanici` boşaltıldı (bantsayim'deki PL-001 bant kullanıcısıydı).

### 3. GitLab
- **Komutlar:** `git init -b main` → `git remote add origin git@gitlab.com:modfex-apparel/kesimhane.git` → `git push -u origin main`
  (push-to-create ile proje oluştu: https://gitlab.com/modfex-apparel/kesimhane)
- **Commit:** `3c8256f` — Ilk iskelet: Sentez girisi, ortak kabuk, bos ana sayfa

## Kararlar
- Ortak kod bantsayim'deki en güncel hali (kiosk'lu); diğer 4 uygulamanın Ortak'ı hâlâ eski.
- Linux paketleme/testler iskelette yok; ihtiyaç olunca bantsayim'den taşınacak.

## Açık kalanlar / sonraki adım
- Kesimhane içeriği planlanacak (kesim kaydı giriş? pastal planı? demet etiketi? kumaş sarfiyatı?).
  Bilinen: Sentez'de kesim = `Erp_WorkOrderProduction`, `ProcessId=167`; bantsayim bu miktarı okuyor.
- GitLab projesinin görünürlüğü (varsayılan private) kontrol edilmeli.
