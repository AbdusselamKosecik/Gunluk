# WarehouseMobil — 2026-08-29

## Bağlam
`X:\Gitlab\Modasima` altında yeni bir proje istendi: **WarehouseMobil** (mobil depo / el
terminali uygulaması). Gün başında böyle bir klasör veya GitLab reposu yoktu. Hedef: boş bir
iskelet repo kurup GitLab'daki `modasima` grubuna private olarak eklemek.

## Yapılanlar

### 1. Teknoloji kararı için soru soruldu
- **Neden:** "WarehouseMobil" adı dışında teknoloji/hedef platform belirtilmemişti; yanlış
  iskelet kurmak sonradan silinecek iş demek.
- **Ne yapıldı:** Kullanıcıya iki soru soruldu — teknoloji (.NET MAUI / Flutter / React Native /
  boş repo) ve görünürlük (private / internal / public).
- **Sonuç:** Kullanıcı **"sadece boş repo"** ve **private** seçti. Kod sonra eklenecek.

### 2. Yerel iskelet oluşturuldu
- **Neden:** Repo'nun ilk commit'i boş olmasın; .gitignore baştan doğru olsun ki bin/obj,
  node_modules, .env gibi şeyler hiç girmesin.
- **Ne yapıldı:** `X:\Gitlab\Modasima\WarehouseMobil` klasörü açıldı, içine `README.md`
  (proje adı + "iskelet, kod eklenmedi" notu) ve teknoloji-agnostik bir `.gitignore`
  (.NET bin/obj/*.user, Node node_modules, IDE .vs/.vscode/.idea, OS Thumbs.db, ve
  `*.local.json` / `.env` gibi sır dosyaları) yazıldı.
- **Dokunulan dosyalar:** `WarehouseMobil/README.md`, `WarehouseMobil/.gitignore`
- **Komutlar:**
  ```bash
  cd X:/Gitlab/Modasima/WarehouseMobil
  git init -b main
  git add README.md .gitignore
  git commit -m "İlk commit: WarehouseMobil proje iskeleti (README + .gitignore)"
  git remote add origin git@gitlab.com:modasima/warehousemobil.git
  ```
- **Sonuç / doğrulama:** 2 dosya, 40 satır.
- **Commit:** `35d8ba7` — İlk commit: WarehouseMobil proje iskeleti (README + .gitignore)

### 3. GitLab projesi push-to-create ile oluşturuldu
- **Neden:** Makinede `glab` CLI kurulu değil (PATH'te yok), yani API'den proje açmak için
  hazır araç yoktu. GitLab'ın **push-to-create** özelliği bunu tek komutta hallediyor:
  var olmayan bir yola push edilince projeyi kendisi açıyor.
- **Ne yapıldı:** Remote adı, gruptaki diğer projelerin adlandırmasına uyularak küçük harf
  seçildi (`uzmanprintmanager`, `modasimaislemler`, `sentezservis` gibi →
  `warehousemobil`). Görünürlük push option'ı ile private'a sabitlendi.
- **Komutlar:**
  ```bash
  git -C "X:/Gitlab/Modasima/WarehouseMobil" push -u origin main -o visibility=private
  ```
- **Sonuç / doğrulama:** Sunucu yanıtı: "The private project modasima/warehousemobil was
  successfully created." `main` branch push edildi ve upstream'e bağlandı.
  URL: <https://gitlab.com/modasima/warehousemobil>

## Kararlar
- **Boş iskelet, framework yok.** Kullanıcı teknolojiyi henüz seçmedi; erken .NET MAUI /
  Flutter iskeleti kurmak yerine .gitignore'u her ikisini de kapsayacak şekilde geniş yazdım.
- **Proje adı diskte `WarehouseMobil`, GitLab'da `warehousemobil`.** Gruptaki mevcut 4
  projenin tamamı küçük harf slug kullanıyor, tutarlılık için aynısı yapıldı.
- **`glab` kurmak yerine push-to-create.** Tek seferlik iş için CLI kurup auth akışı
  yaşamaya gerek yoktu; SSH anahtarı zaten çalışıyor.

## Açık kalanlar / sonraki adım
- Teknoloji seçimi bekliyor (.NET MAUI en muhtemel — mevcut projeler C#/WPF).
- Hedef platform netleşmeli: Android el terminali mi, Windows da mı?
- `glab` kurmak ileride işe yarayabilir (issue/MR yönetimi için).
