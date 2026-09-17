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
