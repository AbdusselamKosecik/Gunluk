# muftelif — 2026-10-31

## Bağlam
Çalışma kopyasında commit edilmemiş büyük bir değişiklik yığını vardı (MitoSentezDashbord: 54 değişen + ~40 yeni dosya).
Hedef: değişiklikleri incelemek ve GitLab'a (`origin` = gitlab.com/mitotr/muftelif) göndermek.

## Yapılanlar

### 1. Değişikliklerin incelenmesi
- **Neden:** Push öncesi gizli bilgi / yanlış dosya kontrolü.
- **Ne yapıldı:**
  - Değişen dosyaların büyük kısmı yalnızca satır sonu (LF/CRLF) farkı; gerçek içerik farkı ~26 dosya (+1469/-276).
  - Yeni modüller: API'de `Weaving`, `KonfeksiyonYikama`, `Reports`, `ExcelFiles`, `Amortisman`, `Lamperti`,
    `SatisDashboard`, `Vuo/VuoLookup`, `Planning/OrderFlow(.sql)`, `Planning/WeavingStage.sql`;
    Auth'ta `LocalUsersStore`, `PasswordHasher`, `AdminUsersEndpoints`. Web'de karşılık gelen sayfalar,
    `RequireMenuAccess`/`RequireAdmin`, `i18n/`, `lib/` yardımcıları.
  - `.csproj`: yeni SQL'ler EmbeddedResource; `data/**` ve `appsettings.Local.json` yayın paketinden çıkarıldı
    (sunucudaki kullanıcı/ayar dosyalarının üzerine yazılmasın diye).
  - `Program.cs`: `appsettings.Local.json` opsiyonel yükleniyor, yeni servis/endpoint kayıtları.
  - Gizli bilgi taraması temiz. `api/data/` (ADMIN-GECICI-SIFRE.txt, local-users.json) `.gitignore`'da → repoya girmedi.
- **Komutlar:**
  ```bash
  git diff --ignore-cr-at-eol --stat
  git check-ignore -v MitoSentezDashbord/api/data/x.json MitoSentezDashbord/api/appsettings.Local.json
  ```

### 2. Doğrulama
- **Komutlar:**
  ```bash
  cd MitoSentezDashbord
  dotnet build api.Tests        # 0 hata
  (cd web && npx tsc -b)        # 0 hata
  dotnet test api.Tests --no-build   # 21/22 geçti
  ```
- **Sonuç:** `PlanningSettingsStoreTests.Get_DosyaYoksa_Varsayilan40_60` kırık — `PlanningSettingsStore` varsayılanı
  önceki bir commit'te `(50000, 80000)` yapılmış, test hâlâ `(40, 60)` bekliyor. Bu turdaki değişikliklerden değil.
- Uyarı: `System.Security.Cryptography.Pkcs` 9.0.13 için NU1903 (yüksek önem) güvenlik açığı uyarısı.

### 3. Commit + push
- **Dokunulan yollar:** `.gitignore`, `README.md`, `MitoSentezDashbord/` (91 dosya, +10270/-391)
- **Commit:** `be45c88` — feat: yeni moduller (dokuma, kasar takip, raporlar, excel, amortisman, lamperti, satis dashboard) + yerel kullanici yonetimi + i18n
- `git push` → `9b5e015..be45c88 main -> main`

## Kararlar
- `.claude/launch.json` (yerel dev başlatma ayarı) commit'e alınmadı.

## Açık kalanlar / sonraki adım
- `PlanningSettingsStoreTests` testini yeni varsayılana (50000/80000) güncelle.
- `System.Security.Cryptography.Pkcs` paketini güncel sürüme yükselt (NU1903).

---

### 4. mitotr repolarının GitHub organizasyonuna taşınması (20:45–21:50)
- **Neden:** `X:\Gitlab\mitotr` altındaki tüm repolar GitHub'da bir organizasyon altında da dursun.
- **Ne yapıldı:**
  - GitHub'da org **Mitotr** (https://github.com/Mitotr) web arayüzünden elle açıldı. github.com'da API ile org açılamıyor.
  - 6 private repo açıldı: MitoSentezApi, loomscreen, maliyet1, mezura, muftelif, sevkiyat.
  - GitLab'daki tüm uzak dallar, yerel dallar ve etiketler GitHub'a gönderildi. muftelif'te sadece yerelde olan `list` dalı da gitti.
  - Yerel klonlarda `origin` → GitHub, `gitlab` → GitLab. `main` artık `origin/main`'i izliyor.
- **Komutlar (her repo için):**
  ```bash
  git fetch origin --tags --prune
  gh repo create "Mitotr/$r" --private
  git push https://github.com/Mitotr/$r.git 'refs/remotes/origin/*:refs/heads/*'
  git push https://github.com/Mitotr/$r.git --all
  git push https://github.com/Mitotr/$r.git --tags
  git remote rename origin gitlab
  git remote add origin https://github.com/Mitotr/$r.git
  git fetch origin && git branch -u origin/main main && git remote set-head origin main
  ```
- **Sonuç / doğrulama:** `git ls-remote` ile GitLab ve GitHub ref'leri karşılaştırıldı, hepsi aynı çıktı (muftelif'te fazladan sadece `list` var).

## Kararlar (ek)
- GitLab silinmedi, `gitlab` remote'u olarak duruyor. GitLab'a da göndermek için: `git push gitlab main`.
