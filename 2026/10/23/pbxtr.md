# pbxtr — 2026-10-23

## Bağlam
Çağrı merkezi tarafı tamam (kullanıcı onayı). Yeni hedef: fabrika gibi müşteriler için santral (PBX) hizmeti; menülerin tenant tipine göre açılıp kapanması.

## Yapılanlar

### 1. Santral hizmeti planı
- **Neden:** Kullanıcı santral hizmeti eklemek ve menüleri tenant tipine göre açıp kapamak istiyor.
- **Ne yapıldı:**
  - Kod tarandı.
    - `TenantCompanyInfo.Kind` (call_center/pbx/hybrid) zaten var, ama hiçbir ekranı açıp kapamıyor.
    - Menü yalnız kullanıcı yetkisiyle süzülüyor (`ScreenRegistry.cs:103-158`).
    - Santral çekirdeği hazır: dahili, trunk, DID, IVR, çalma grubu, iç arama, DND, arama sınıfı, konsol, park.
    - Eksikler: çağrı yakalama, yönlendirme, gerçek sesli mesaj, özellik kodları, anons (paging), konferans, cihaz otomatik yapılandırma, giden rota deseni, acil numara.
  - Plan yazıldı.
    - Faz A: modül maskesi (izin ∩ tenant modülü, `TenantContext` içinde tek noktada); tip→modül eşlemesi; `bundle.queue` ikiye bölünür; `staff` rolü; dahili kotası.
    - Faz B: günlük santral özellikleri.
    - Faz C: fabrika sahası (paging, kapı telefonu, konferans, cihaz yapılandırma, gece modu).
- **Dokunulan dosyalar:** `yonetim/santral-hizmeti-plani.md`
- **Sonuç:** Plan depoda. Uygulamaya geçilmedi; kullanıcının "başla" demesi bekleniyor.
- **Commit:** pbxtr `yonetim: santral (PBX) hizmeti ve tenant tipine gore modul acma/kapama plani`

## Kararlar (öneri, kullanıcı onayı bekliyor)
- Modül = yetkinin üstünde maske. Boş tipli eski tenant'lar bugünkü menüyü aynen görür.
- Tip değişince veri silinmez, yalnızca gizlenir.
- Acil numaralar fail-closed `call-permission` kapısının önünde kısa devre yapar.
- Özellik kodları için yeni Sınıf B ucu gerekir (`POST /telephony/feature-code`).

## Açık kalanlar / sonraki adım
- Kullanıcı onayı → Faz A'dan başla. Backlog kartları ve ClickUp senkronu o zaman açılacak.

### 2. Santral epiği: iş listesi + sprintler + ClickUp
- **Neden:** Kullanıcı: "iş listelerini çıkarır mısın, sprintleri ayarlar mısın?"
- **Ne yapıldı:**
  - `backlog.md` sonuna "EPIC SANTRAL" bölümü eklendi: 36 kart.
    - Kodlar: BR-BE-263…272, BR-DB-119…122, BR-FE-142…146, BR-AST-137…147, BR-QA-127…130, BR-SYS-144, BR-OPS-19.
    - Durum "Sprintte (2026-10-23, planli)" → ClickUp'ta `to do`.
  - Sprint dosyaları yazıldı:
    - sprint-46: Faz A, modül maskesi
    - sprint-47: B1, yakalama / yönlendirme / sesli mesaj / özellik kodları
    - sprint-48: B2, giden rota / acil numara / iç kayıt / rehber / BLF
    - sprint-49: C, paging / kapı / konferans / cihaz yapılandırma / gece modu / demo tenant
  - sprint-45 kullanılmadı: kurul kayıtlarında Sprint-44 artakalanlarına ayrılmış.
- **Komutlar:**
  ```bash
  node yonetim/arac/clickup-senkron.js --kuru   # 36 KAYIP
  node yonetim/arac/clickup-olustur.js          # yeni: 36
  node yonetim/arac/clickup-senkron.js          # fark 0
  node yonetim/arac/clickup-senkron.js --kuru   # fark olan kart: 0, izde olmayan: 0
  ```
- **Sonuç:** Pano senkron (1732 görev, fark 0).
- **Commit:** pbxtr `yonetim: santral epigi — 36 backlog karti, sprint-46..49, ClickUp eslemesi`

## Açık kalanlar (güncel)
- Kullanıcının "başla" demesi → sprint-46.
