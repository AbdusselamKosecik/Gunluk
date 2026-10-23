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
