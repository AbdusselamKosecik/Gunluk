# kosecik-web — 2026-10-13

## Bağlam
kosecik.com, kosecik.com.tr, kosecik.tr, abdusselam.com, abdusselam.com.tr, abdusselam.tr için tek bir site yapılacak; alan adları DNS ile yönlendirilecek. Kullanıcı tasarım örneği ve detayları ekleyecek, önce repo istendi.

## Yapılanlar

### 1. Repo oluşturuldu
- **Neden:** Yeni site için temiz bir başlangıç. Mevcut `kosecik.com` reposu (Mart 2025, eski .NET çözümü) kullanıcı kararıyla olduğu gibi bırakıldı.
- **Ne yapıldı:** Private `AbdusselamKosecik/kosecik-web` reposu açıldı; README (alan adı tablosu + açık kararlar), `tasarim/` ve `docs/detaylar.md` iskeleti eklendi.
- **Dokunulan dosyalar:** `README.md`, `docs/detaylar.md`, `tasarim/README.md`
- **Komutlar:**
  ```bash
  git init -b main
  git add README.md docs/detaylar.md tasarim/README.md
  git commit -m "İlk iskelet: README, tasarim/ ve docs/ klasörleri"
  gh repo create AbdusselamKosecik/kosecik-web --private --source=. --remote=origin --push
  ```
- **Sonuç / doğrulama:** Push başarılı, `main` dalı origin'i takip ediyor.
- **Commit:** `ace1048` — İlk iskelet: README, tasarim/ ve docs/ klasörleri

## Kararlar
- Yeni repo adı `kosecik-web`, private.
- Eski `kosecik.com` reposuna dokunulmadı.

## Açık kalanlar / sonraki adım
- Kullanıcı tasarım örneklerini `tasarim/`, detayları `docs/` içine ekleyecek.
- Ana alan adı, teknoloji, barındırma ve DNS sağlayıcı kararları verilecek.
