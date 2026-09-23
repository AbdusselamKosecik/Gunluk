# muftelif — 2026-09-23

## Bağlam
SarfKullanim canlıya yakın; diskte commit edilmemiş bir "makineye sabitlenen parça" ekranı vardı.
Kullanıcı bunu yeniden tanımladı: makine üzerindeki fiziksel parçaların envanteri, sarf stoğundan
**bağımsız**, malzeme kartı olmadan da kaydedilebilir, fotoğraflı, sök/değiştir tarihçeli + rapor.

## Yapılanlar

### 1. Diskteki commit edilmemiş iş kurtarıldı
- **Neden:** "Makineye sabitle" ekranı (api/Features/Makineler, web/pages/makineler, db/0002) diskte duruyordu, commit yoktu; HDD kuralı gereği önce push.
- **Doğrulama:** build 0 hata, 62 test geçti.
- **Commit:** `032aa4d`

### 2. Makine parça envanteri (yeni model)
- **Neden:** Sahada makine başında her parça kayıt altına alınacak; çoğunun ERP'de malzeme kartı yok.
  Eski model her parçayı bir sarf çıkışına bağlıyordu — kullanıcı bunu reddetti.
- **Kararlar (soru-cevap):** parça kendi tablosunda (A), fotoğraf diskte (A), "Değiştir" tek işlem
  ve iki kaydı bağlar (A), durum listesi: Çalışıyor/Arızalı/Bakımda/Yedek.
- **DB:** `db/0003_makine_parca_envanter.sql` çalıştırıldı →
  - `UZM_SARF_MAKINE_PARCA` (ad, tür, marka/model, seri no, adet, durum, konum, açıklama,
    InventoryId **null olabilir**, TakilmaTarihi/SokulmeTarihi/SokumAciklamasi, DegisenParcaId)
  - `UZM_SARF_MAKINE_PARCA_FOTO` (dosya adı; dosyalar diskte)
  - Eski akış kaldırıldı: `MakineyeSabitliMi` kolonu + `UZM_SARF_MAKINE_SOKUM` düşürüldü,
    sabitli 2 kayıt parçaya taşındı (sarf hareketleri çıkış olarak kaldı).
  - **Tuzak:** sqlcmd `-i` dosyayı ANSI okuyor; SQL içindeki Türkçe karakterler bozuk kaydedildi
    (`-f 65001` de çözmedi). Migration metinleri ASCII yapıldı. Uygulamanın kendi yazdığı
    kayıtlar etkilenmiyor (SqlClient parametreli nvarchar).
- **Ayrı tarihçe tablosu YOK:** parça satırının kendisi tarihçe (takılma/sökülme + DegisenParcaId zinciri).
- **Sözleşme:** `docs/api-contract.md` içindeki eski "sabit parçalar" bölümü yeni uçlarla değiştirildi.
- **3 paralel ajan:** API (.NET, ImageSharp 3.1.12 — 4.x lisans uyarısı verdiği için), web (React),
  deploy/dokümanlar. Sonra 61→134 test.
- **Fotoğraf:** diskte `MakineParca:FotoKlasoru` (varsayılan `<ContentRoot>/uploads/makine-parca`),
  1600 px + 320 px küçük, GUID dosya adı, path traversal testli. `uploads/` gitignore'a eklendi,
  Deploy-IIS robocopy `/XD logs uploads` ile koruyor ve app pool'a yazma izni veriyor.
- **Doğrulama (kendim):** build 0 uyarı/0 hata, `SARF_TEST_DB=1 dotnet test` 134/134, web build+lint OK.
  Tarayıcıda: manuel parça + fotoğraf eklendi, "Değiştir" iki kaydı bağladı (geçmişte söküm notu ve
  karşılıklı bağlantılar göründü), "Makine parçaları" raporu doğru listeledi. Test kayıtları ve
  fotoğraf dosyaları sonra silindi (tabloda yalnızca taşınan 2 kayıt kaldı).
- **Commit:** `607ad35`

### 3. IIS paketleri
- `SarfKullanim-IIS-192.168.3.228-89-20260923.zip` (parça özelliği öncesi)
- `SarfKullanim-IIS-192.168.3.228-89-20260923-parca.zip` (8.5 MB, 83 dosya) — site + db (0001/0002/0003) + IIS-KURULUM.txt
- Zip'lerde DB şifresi ve JWT anahtarı var → `.gitignore`'a `SarfKullanim-IIS-*.zip` eklendi (commit `0a3a1b1` öncesi turda).
- Paket üretimi: `npm run build` (Bash) + `.\Deploy-IIS.ps1 -SkipWebBuild`. PowerShell'de doğrudan
  çalıştırınca vite'ın stderr'i NativeCommandError'a dönüşüyor, web build ayrı yapılmalı.

## Açık kalanlar
- Sunucuda 0003 çalıştırılıp yeni paket deploy edilmeli.
- Parça soft delete API'de var, arayüzde yok (yanlış kayıt silme).
- Gerçek Sentez kullanıcısıyla login hâlâ denenmedi (şifre bilinmiyor).
- ImageSharp 4.x'e geçiş lisans alınırsa tek satır.
