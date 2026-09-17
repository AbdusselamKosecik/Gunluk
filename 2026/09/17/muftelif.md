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
  git switch -c feat/sarf-kullanim     # feat/sentez-planing-ayrimi HEAD'inden (main 106 commit geride)
  git add SarfKullanim/docs/2026-09-17-sarf-kullanim-design.md
  git commit -m "docs(sarf-kullanim): SarfKullanim web uygulamasi tasarim dokumani"
  git push -u origin feat/sarf-kullanim
  ```
- **Sonuç / doğrulama:** Spec GitLab'a push edildi; kullanıcı incelemesi bekleniyor.
- **Commit:** `45d1af8` — docs(sarf-kullanim): SarfKullanim web uygulamasi tasarim dokumani

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
