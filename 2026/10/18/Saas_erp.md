# Saas_erp — 2026-10-18

## Bağlam
17 Ekim'de sınıfa göre stok tipi filtresi yapılmıştı (`293ef8fc`). Kullanıcı bir sistem tipi × Malzeme Sınıfı matrisi istedi, matrisi kendisi düzenleyip geri gönderdi. Bir de not ekledi: "firma kendisi sistem tipini açamayacak".

## Yapılanlar

### 1. Sınıf → stok tipi matrisi + sistem tipi kilidi (dev, `ab17d700`)
- **Neden:** Kullanıcının onayladığı matrisi uygulamak. Ayrıca stok tipine sistem tipini yalnız süper admin atayabilmeli.
- **Matris (`CLASS_ALLOWED_TYPES`, `inventory-system-classifications.ts`):**

  | Malzeme Sınıfı | Seçilebilen stok tipleri |
  |---|---|
  | Mamul | Mamul, Örme Kumaş, Dokuma Kumaş |
  | Hammadde | Hammadde + MATERIAL_TYPES |
  | Yarı Mamul | Yarı Mamul + MATERIAL_TYPES |
  | Yardımcı | Yardımcı + MATERIAL_TYPES + Ticari Mal |
  | Hizmet | yalnız Hizmet |
  | Demirbaş | yalnız Ticari Mal |
  | Ticari Mal | Ticari Mal + MATERIAL_TYPES |

  - `MATERIAL_TYPES` = Aksesuar, Ambalaj, Boya, Kimyasal, Örme Kumaş, Dokuma Kumaş.
  - Firmanın kendi açtığı tipler (systemType=0) şu sınıflarda listelenmiyor: Hizmet, Demirbaş, Ticari Mal. Kullanıcı Ticari Mal için "❓" bıraktı, mevcut durum korundu.
- **Backend:**
  - `CreateInventoryType`: süper admin değilse ve `SystemType != None` ise Forbidden döner.
  - `UpdateInventoryType`: süper admin değilse ve SystemType değiştiriliyorsa Forbidden döner. Eski firma tiplerinde dolu olan değer korunur.
  - Yeni hata kodu `inventory.type.system_type_locked`; EN mesaj ve tr/en arayüz mesajları eklendi.
- **Frontend:** Tip formunda Sistem Tipi seçimi süper admin değilse kapalı ve altında açıklama yazıyor.
- **Testler:**
  - `SystemTypeKindProtectionTests`: 4 yeni test; 17 test geçti.
  - Frontend inventory testleri 170/170 geçti, typecheck temiz.
- **Changelog:** 2026-10-18 tarihli kayda iki madde.
- **Commit:** `ab17d700`; `feat/iki-panelli-menu` dalına merge edildi (`9ec01ca6`).

## Kararlar
- Sınıf eşlemesi yalnız arayüz filtresi; backend zorlamıyor (17 Ekim kararı).
- Sistem tipi atama yetkisi API'de zorlanıyor.

## Açık kalanlar
- "Tür Standart gelmiyor": yeni kartta Standart geliyor. Tür'ü boş olan eski kartlar için toplu güncelleme kullanıcı onayı bekliyor.
- Ticari Mal sınıfında firmanın kendi tipleri listelenecek mi: karar bekliyor.
- 17 Ekim'den devreden açık işler sürüyor.
