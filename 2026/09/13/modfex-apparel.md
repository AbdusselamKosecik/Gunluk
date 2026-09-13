# modfex-apparel — 2026-09-13

## Bağlam
`X:\Gitlab\modfex-apparel` boştu. Hedef: GitLab `modfex-apparel` grubunda 6 repo açmak.
SentezServis hariç hepsi Avalonia + .NET 10 (Windows + Android + Linux) olacak.

## Yapılanlar

### 1. Avalonia şablonu ve 5 uygulama iskeleti
- **Neden:** Bant Sayım, Bant Durum Ekranı, Depo, Paketleme ve Sevkiyat aynı teknolojiyle, aynı yapıda başlasın.
- **Ne yapıldı:** `Avalonia.Templates` yüklendi (Avalonia 12.1.2, net10.0, CommunityToolkit.Mvvm, CPM).
  `avalonia.xplat` ile üretildi. Browser ve iOS projeleri slnx'ten çıkarılıp silindi,
  `Directory.Packages.props` içinden de `Avalonia.iOS` ve `Avalonia.Browser` kaldırıldı. Her repoya README eklendi.
- **Klasör → proje adı:** bantsayim→BantSayim, bantdurumekrani→BantDurumEkrani, depo→Depo, paketleme→Paketleme, sevkiyat→Sevkiyat
  (her birinde `<Ad>`, `<Ad>.Desktop`, `<Ad>.Android` var)
- **Komutlar:**
  ```bash
  dotnet new install Avalonia.Templates
  dotnet new avalonia.xplat -n Depo -o depo
  dotnet sln Depo.slnx remove Depo.Browser/Depo.Browser.csproj Depo.iOS/Depo.iOS.csproj
  rm -rf Depo.Browser Depo.iOS
  sed -i '/Avalonia.iOS\|Avalonia.Browser/d' Directory.Packages.props
  ```
- **Sonuç / doğrulama:** 5 Desktop projesinin hepsi `dotnet build` ile 0 uyarıyla derlendi. Android derlenmedi, çünkü makinede `android` workload'u yok.

### 2. SentezServis
- **Ne yapıldı:** Sadece README ve .gitignore (VisualStudio) eklendi. Teknoloji henüz belli değil.
  (Modasima/sentezservis'e benziyor: .NET 10 Host/Core/Jobs yapısı, gerekirse oradan alınabilir.)

### 3. GitLab repoları (push-to-create)
- **Neden:** Credential manager'daki OAuth token'da `api` yetkisi yok (insufficient_scope). SSH (`@tekbirsoft`) ise çalışıyor.
  GitLab, SSH ile yapılan ilk push'ta private proje oluşturuyor.
- **Komutlar:**
  ```bash
  git init -b main && git add <yollar> && git commit -m "Ilk iskelet"
  git remote add origin git@gitlab.com:modfex-apparel/<slug>.git
  git push -u origin main
  ```
- **Commitler:** sentezservis `1b875b2`, bantsayim `4cd4824`, bantdurumekrani `9d957db`, depo `12b68f6`, paketleme `2dc848a`, sevkiyat `f7b2f78`, hepsinin mesajı "Ilk iskelet".

## Kararlar
- Repo yolları, Modasima'daki gibi küçük harf ve bitişik yazıldı.
- Desktop projesi hem Windows'u hem Linux'u kapsıyor. iOS ve Browser kullanılmayacak.
- Repolar private açıldı (push-to-create varsayılanı).

## Açık kalanlar / sonraki adım
- Android için `dotnet workload install android` kurulup Android projeleri derlenmeli.
- SentezServis'in teknolojisi ve yapısı belirlenmeli.
- GitLab'da proje görünen adları ("Bant Sayım Uygulaması" gibi) arayüzden düzenlenebilir.
