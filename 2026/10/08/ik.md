# ik — 2026-10-08

## Bağlam
Kullanıcı Mısır için Sentez'e bağlı bir İK uygulaması projesi açılmasını ve eski Mısır bordro programının
(`C:\Users\abdus\OneDrive\Masaüstü\12r`, `f01` = master `CFF` + şirket `2026`) verisinin incelenmesini istedi.

## Yapılanlar

### 1. Eski programın incelenmesi
- **Neden:** Hangi verinin taşınacağını ve İK uygulamasının kapsamını anlamak.
- **Ne yapıldı:** exe'ler, menü, rapor tabloları ve veri dosyaları hex/strings ile incelendi (yalnızca okuma).
  - Program: DENDATA, Borland Delphi 32-bit; `PETEGP.exe` TR, `PEEEGP.exe` EN.
  - `PEREGP.MNU` her bayt +2 kaydırılmış → çözülünce menü: devam/puantaj (PDKS aktarımı), bordro, personel,
    raporlar (sigorta, vergi %10-25, yıllık izin...), tanımlar.
  - `PEREGT.TBL` rapor başlıkları → personel kartı alanları ve £E kazanç kalemleri (output/risk/customer bonus, clothing, transportation...).
  - Veri: Pascal `file of record`, ShortString. Firma adı MODFEX TEKSTIL, 1 şube; `EMPXX.MAS` (personel) 0 bayt,
    `DEPXX.MAS` 990 × 4331 B tamamen boş kayıt, parametre dosyaları boş şablon.
- **Sonuç:** Taşınacak personel/puantaj/bordro verisi **yok**; işe yarayan kısım alan listesi ve hesap kuralları.
- **Dokunulan dosyalar:** `ik/docs/eski-sistem.md` (ayrıntılı not, dosya tablosu).
- **Komut örneği:** menü çözme = her bayt `-2`, cp1254 (scratchpad `dec.py`).

### 2. `ik` proje iskeleti
- **Neden:** Suite'in tüm uygulamaları aynı Sentez girişli kabukla başlıyor.
- **Ne yapıldı:** `X:\Gitlab\modfex-apparel\ik` = kesimhane iskelet commit'i `3c8256f` (`git archive`) + kesimhane HEAD'deki
  güncel `Ortak/`. `Kesimhane→Ik`, `kesimhane→ik` (sed, Ortak hariç). ApplicationId `com.modfex.ik`,
  pencere başlığı "Modfex — İnsan Kaynakları", `UygulamaMetinleri`: İnsan Kaynakları / Human Resources / الموارد البشرية.
  `%LOCALAPPDATA%\Modfex\kesimhane\ayarlar.json` → `...\ik\ayarlar.json` kopyalandı.
- **Komutlar:**
  ```bash
  git -C kesimhane archive 3c8256f | tar -x -C ik
  rm -rf ik/Kesimhane/Ortak; git -C kesimhane archive HEAD Kesimhane/Ortak | tar -x -C ik
  dotnet build Ik.Desktop -c Debug   # 0 uyarı, 0 hata
  git init -b main; git remote add origin git@gitlab.com:modfex-apparel/ik.git; git push -u origin main
  ```
- **Sonuç / doğrulama:** Derleme temiz; uygulama 12 sn çökmeden açık kaldı. GitLab'da push-to-create ile proje oluştu.
- **Commit:** `29179fe` — Ilk iskelet: Misir IK uygulamasi + eski DENDATA bordro incelemesi

## Kararlar
- Proje adı `ik`, C# projeleri `Ik`, `Ik.Desktop`, `Ik.Android`.
- Ortak kod kesimhane'nin güncel hali (7 repo'ya yayıldı).

## Açık kalanlar / sonraki adım
- İK kapsamı planlanacak: personel kartı, puantaj/PDKS, bordro (Mısır sigorta+vergi), izin; Sentez'de personel nerede tutulacak (Erp_Employee? UZM_ tabloları?).
- Eski programda veri yok — gerçek personel verisi başka yerdeyse (eski şirket yılı, Excel) bulunmalı.
- GitLab görünürlüğü kontrol edilmeli.
