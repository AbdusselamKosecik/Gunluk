# kamerakontrol — 2026-11-22

## Bağlam
Kullanıcı: "Bir repository proje açar mısın Kamera Kontrol diye".

## Yapılanlar

### 1. Repo açıldı
- **Ne yapıldı:** `X:\Gitlab\modfex-apparel\kamerakontrol` klasöründe `git init -b main` yapıldı ve README eklendi. Diğer modfex projeleri gibi GitLab'daki `modfex-apparel` grubuna push edildi. GitLab projeyi push sırasında **private** olarak oluşturdu.
- **Remote:** `git@gitlab.com:modfex-apparel/kamerakontrol.git`, web: https://gitlab.com/modfex-apparel/kamerakontrol
- **Komutlar:**
  ```bash
  mkdir kamerakontrol && cd kamerakontrol && git init -b main
  git add README.md && git commit -m "İlk commit"
  git remote add origin git@gitlab.com:modfex-apparel/kamerakontrol.git && git push -u origin main
  ```

## Açık kalanlar
- Kapsam henüz tanımlanmadı (hangi kameralar, ne kontrol edilecek, hangi platform).
