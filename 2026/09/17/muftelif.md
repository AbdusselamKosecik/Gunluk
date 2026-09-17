# muftelif — 2026-09-17

## Bağlam
Yeni proje: **SarfKullanim** web uygulaması (muftelif monoreposu içinde `SarfKullanim/`).
Hedef: sarf malzemesinin içerideki stoğunu ve hangi makine/çalışana verildiğini takip etmek.
Bugün brainstorming → onaylı tasarım → spec dosyası yapıldı; kod yok.

## Yapılanlar

### 1. SarfKullanim tasarımı (spec)
- **Neden:** Sarf malzemesi Sentez'de 300 deposuna girişle geliyor ama kime/hangi makineye
  verildiği ve kalan miktar takip edilmiyor.
- **Ne yapıldı:** Kullanıcıyla soru-cevapla gereksinimler netleştirildi, SentezPlaning kalıbı
  (api .NET 10 + Dapper, web React 19 + Vite + Tailwind, tek IIS sitesi, Meta_User MD5 login + JWT)
  esas alınarak tasarım yazıldı.
- **Dokunulan dosyalar:** `SarfKullanim/docs/2026-09-17-sarf-kullanim-design.md`
- **Komutlar:**
  ```bash
  git switch main && git pull --ff-only   # kullanici: ayri dal acma, main
  git add SarfKullanim/docs/2026-09-17-sarf-kullanim-design.md
  git commit -m "docs(sarf-kullanim): SarfKullanim web uygulamasi tasarim dokumani"
  git push origin main
  ```
- **Sonuç / doğrulama:** Spec GitLab'a push edildi; kullanıcı incelemesi bekleniyor.
- **Commit:** `9ea603d` (main) — docs(sarf-kullanim): SarfKullanim web uygulamasi tasarim dokumani

## Kararlar
- Kullanıcılar `Meta_User`; yetki ayrımı yok (herkes her şeyi görür/kaydeder).
- Stok girişi = `Erp_InventoryReceiptItem` içinde **ReceiptType < 100** ve depo **300**; 300'e giren her kalem sarf.
- Masraf yeri giriş satırının `CostCenterId`'si (ör. Dikim Fashion); stok **malzeme × masraf yeri**.
- Çıkış yalnızca uygulamada; **Sentez'e geri yazma yok**.
- Hareket tipleri: Çıkış, İade, Sayım +, Sayım − — tek tablo `UZM_SARF_HAREKET` (SentezLive içinde).
- Çıkış/iadede makine veya çalışandan **en az biri** zorunlu; listeler masraf yerine göre filtreli + "tümünü göster".
- Bakiye saklanmaz; `UZM_SARF_VW_STOK` view'ı ile hesaplanır; çıkış bakiyeyi eksiye düşüremez (UPDLOCK kontrolü).
- Yaklaşım 1 seçildi (tablolar SentezLive'da); ayrı DB ve snapshot yaklaşımları reddedildi.

## Açık kalanlar / sonraki adım
- Kullanıcı spec'i inceleyecek.
- Sentez kolon adları (ReceiptType yeri, depo/masraf yeri kolonları, Resource/Employee → CostCenter bağı) SentezLive'a karşı doğrulanmalı — okuma bağlantı bilgisi gerekli.
- Onay sonrası: uygulama planı (writing-plans) → implementasyon.

### 2. Dal düzeni: main'de çalış + uzak/yerel eşitleme
- **Neden:** Kullanıcı "mainde çalış, başka dal oluşturma" ve "dalları eşitle uzakla lokali" dedi.
- **Ne yapıldı:** Spec commit'i `main`'e cherry-pick edildi (`9ea603d`) ve push edildi (yerel main'de push edilmemiş commit'ler de gitti). `feat/sarf-kullanim` yerelde ve uzakta silindi. Sadece yerelde olan `feature/birim-giris-cikis` ve `feature/fason-iscilik-history-workflow` uzağa push edildi (ikisi de main'e zaten dahil).
- **Komutlar:**
  ```bash
  git switch main && git pull --ff-only && git cherry-pick 45d1af8 && git push origin main
  git branch -D feat/sarf-kullanim && git push origin --delete feat/sarf-kullanim
  git push -u origin feature/birim-giris-cikis feature/fason-iscilik-history-workflow
  ```
- **Sonuç:** Tüm yerel dallar upstream ile birebir (ahead/behind yok).

### 3. feat/sentez-planing-ayrimi → main birleştirme
- **Neden:** Kullanıcı main'de çalışmak istiyor; güncel kod (SentezPlaning, OrderBarcode, PdfImport, apk/bat'lar, .gitignore — 441 dosya) sadece o daldaydı, `git switch main` bunları diskten kaldırmıştı.
- **Ne oldu:** İlk `git merge` kullanıcı tarafından yarıda kesildi → çalışma klasöründe 42 yarım değişmiş dosya, sıfır baytla dolu ~340 yeni dosya (mtime 03:56) ve bayat `.git/index.lock` kaldı. Commit oluşmadı, veri kaybı yok (her şey dalda ve uzakta).
- **Temizlik:** Değişen 42 dosyanın içeriği dal ile birebir aynı olduğu doğrulandı → `git restore`. Çakışan takip dışı dosyaların hepsinin 03:50 sonrası (birleştirme anında) oluştuğu doğrulandı → silindi. Çalışan git süreci olmadığı kontrol edilip `index.lock` silindi. Türkçe karakterli dosya adları için `-c core.quotepath=false` gerekti.
- **Komutlar:**
  ```bash
  rm -f .git/index.lock
  git restore -- <42 dosya>
  git -c core.quotepath=false diff --name-only --diff-filter=A main feat/sentez-planing-ayrimi | while read f; do rm -f "$f"; done
  git merge --no-edit feat/sentez-planing-ayrimi
  git push origin main
  ```
- **Sonuç:** `782b13d` Merge branch 'feat/sentez-planing-ayrimi' → main push edildi. `git diff HEAD feat/sentez-planing-ayrimi` yalnızca SarfKullanim spec'i. Tüm yerel dallar upstream ile eşit.
- **Ders:** Büyük (GB'lık apk) checkout/merge işlemleri kesilirse sıfır dolu dosya + index.lock bırakır; tekrar denemeden önce mtime ile kalıntı olduğunu doğrula.

### 4. SarfKullanim — şema doğrulama + uygulama (API, web, test, deploy)
- **Neden:** Kullanıcı hedef verdi: projeyi kararlara göre kur; `Erp_*` tablolarına **salt okunur** eriş, yeni alan açma/silme/ekleme yok. Paralel ajan + inceleme kurulu izni verdi. Çalışma `main` üzerinde.
- **Şema doğrulama (SentezLive 192.168.1.22, yalnızca SELECT, sqlcmd):**
  - 300 = `Erp_Warehouse.WarehouseCode='300'` → RecId 10 "Sarf Malzeme Depo".
  - Girişler `Erp_InventoryReceiptItem` satır bazlı: `ReceiptType` 1 (alış, 3902 satır, CostCenterId dolu) ve 16 (devir, 1362 satır, CostCenterId **boş**) → boş masraf yeri = `0` "Masraf yeri yok (devir)".
  - Başlıktaki `Erp_InventoryReceipt.CostCenterId` hep boş → masraf yeri **satırdan** alınır.
  - Birim: `Erp_Inventory.UnitId` bir **UnitSetId**; ana birim `Meta_UnitSetItem (UnitSetId, IsMainUnit=1).UnitCode`. 300 girişlerinin hepsi ana birimde, `Quantity` doğrudan kullanılır.
  - Makine/çalışan ↔ masraf yeri bağı Sentez'de **yok** (`Erp_Employee.CostCenterId` ve `Erp_Department.CostCenterId` boş) → seçiciler filtresiz, aranabilir, departman adıyla.
  - Sentez'de 300'den `ReceiptType 132` çıkışları var (~5700) → karar A gereği stoka **katılmaz** (README'de belirtildi).
- **DB:** `SarfKullanim/db/0001_init.sql` (idempotent) çalıştırıldı → sadece `UZM_SARF_HAREKET` (tip 1 Çıkış/2 İade/3 Sayım+/4 Sayım−, check constraint'ler, `IX_..._Stok (InventoryId, CostCenterId)`), `UZM_SARF_VW_GIRIS`, `UZM_SARF_VW_STOK`. Stok view'ı 2336 malzeme×masraf yeri satırı döndü.
- **Sözleşme:** `SarfKullanim/docs/api-contract.md` (ajanlar arası tek doğruluk kaynağı). Commit `61f137b`.
- **Paralel ajanlar:** (1) API .NET 10 + Dapper, (2) web React 19 + Vite + Tailwind (i18n yok, Türkçe), (3) `Deploy-IIS.ps1` (site SarfKullanim, port 8092) + README. Kalıp: SentezPlaning. Portlar: API 5399, web 5380.
  - Bakiye kuralı: tek transaction, ilgili anahtarlar `UZM_SARF_HAREKET WITH (UPDLOCK, HOLDLOCK)` ile sıralı kilitlenir; işlem bakiyeyi düşürüp < 0 yapıyorsa 409.
  - Excel export API tarafında (ClosedXML).
- **Doğrulama (kendim):**
  ```bash
  grep -rn -i -E "(insert into|update|delete from)" SarfKullanim/api  # tek hedef dbo.UZM_SARF_HAREKET
  dotnet build SarfKullanim/api/SarfKullanim.Api.sln   # 0 uyarı 0 hata
  SARF_TEST_DB=1 dotnet test ...                       # 61/61 (52 birim + 9 rollback'li entegrasyon)
  cd SarfKullanim/web && npm run build && npm run lint # geçti
  ```
  - Uçtan uca (Chrome DevTools, dev anahtarla üretilmiş JWT): Stok listesi gerçek veriyle; POŞET DOSYA (77) için 80 çıkış → 409 "Bakiye yetersiz"; 5 çıkış → kaydedildi, stok 72, makine raporu doğru. Test kaydı sonra `UZM_SARF_HAREKET`'ten silindi (tablo 0 satır).
- **İnceleme kurulu:** 2 bağımsız code-reviewer (backend doğruluk/eşzamanlılık/güvenlik; web↔API uyumu) → ≥80 güvenli hata yok.
- **Commit:** `f3951e9` — feat(sarf-kullanim): SarfKullanim API + web + testler + IIS deploy
- **Not:** `api/appsettings.Development.json` dev bağlantısını içerir (SentezPlaning'deki kullanıcı kararıyla aynı emsal); prod değerleri ortam değişkeni.

## Açık kalanlar (SarfKullanim)
- Gerçek bir Sentez kullanıcısıyla login denenmedi (şifre bilinmiyor); login kodu SentezPlaning'den birebir kopya.
- Düşük öncelik: İade'nin bağlı olduğu çıkış kaydı sonradan tip değiştirir/silinirse bağ tekrar doğrulanmıyor (bakiyeyi etkilemez).
- Web bundle 625 kB uyarısı (kod bölme yapılabilir).
- IIS'e deploy edilmedi.
