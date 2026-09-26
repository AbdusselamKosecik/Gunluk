# pbxtr — 2026-09-26

## Bağlam
Kullanıcı `yonetim/bekleyen-maddeler.md`'deki 50 açık kartın "Yapılacak" satırlarını doldurdu.
Özet emir: *kod yazılacaksa yaz, testini ben yapacağım; test işi kalanı tamamlandıya çek*;
BR-AST-124 maddesi: *tüm harici dalları main'e al, başka dal bırakma*; BR-C2-1/2, BR-DB-74,
BR-OPS-14 "şimdilik es geç"; BR-10 ve BR-OPS-09 boş bırakıldı. Ardından: *ClickUp'ı güncelle*.
Başlangıç hâli: çalışma ağacı = `wip/is-akisi-20260925` (dünkü durdurulan 14 gruplu akışın
doğrulanmamış yarım işi, içinde `wip/ast124-be221`), 244 dosya commit'siz.

## Yapılanlar

### 0. BR-AST-104 engel ölçümü (soru)
- **Komutlar:** `ssh root@176.88.41.220` → `date -u` (11:46Z); `nsenter -t <pbxtr-asterisk pid> -n ss -lnt`
  → `127.0.0.1:4573` ve `127.0.0.1:8790` DİNLİYOR (pbxtr-edge + pbxtr-edge-fastagi ayakta);
  `psql pbxtr`: `public.dids` = 0, `voicemail_messages` = 0.
- **Sonuç:** kartın yazılı engeli (8790 dinlemiyor) düştü; kalan: voicemail kararlı DID + gerçek çağrı.
- **Tuzak:** `docker ps | grep asterisk` önce `pbxtr-asteriskcdrdb`'yi seçti (5432 gördü) — konteyner adını tam ver.

### 1. Yarım iş akışı derlenir + yeşil yapıldı, main'e alındı
- **Neden:** kartların kodu WIP'teydi ve derlenmiyordu; "kod yazıldıysa tamama çek" ancak main'de anlamlı.
- **Derleme hataları ve düzeltmeler:**
  - BR-AST-79: `HealthComponents.AsteriskExtensionInventory` yoktu → sabit + `All` listesi +
    `SystemHealthProbe`'a satır + FE etiketi `ph.cmpExtensionInventory` (9 dil).
  - `PermissionCatalogTests.cs` fazla `}`; `ErasureRequestTests.cs` `$"""` içinde `'{{}}'::jsonb` → `jsonb_build_object()`.
  - `NoScriptRuntime.GetContentAsync` eksikti (BR-BE-76); `WallboardTiles.Read(... ringGroups = null)`.
- **Test kırmızıları ve düzeltmeler:**
  - `QueueMembershipSyncJob` (BR-AST-126): yeniden bağlanma turu periyodik turun damgasına takılıyordu
    (gerçek hata) → `_lastReconnectTicks` ayrı damga.
  - `ErasureSubjectRequestDto.Number` string → `PhoneInput` (ADR-004 §2.7).
  - `delivery-manifest.json` `voicemail.redial`: izin listesi sıralı değildi (DM005); sonra
    `asterisk_external` + `high_risk_manual` + `manual_rollback` (DM007/TPI007);
    `telephony-path-inventory.json`'a `voicemail.redial` yolu eklendi.
  - Ekran sayısı 71→72 (#65 Silme Talepleri): `ScreenRegistryTests` 72/63/64; duman matrisi
    `smoke-demo.sh` (agent 200 / bayi 403 / wallboard 403) + `duman-ekran-kapsami.json`.
  - `SampleDataSeederInsertOnlyTests`: K4 2→4 (BR-QA-121 (d) red-çekme silmeleri) + çağrı imzası.
  - Belgeler yeniden üretildi: `doc/rol-ekran-matrisi.md`, `doc/ekran-yazma-yollari.md`
    (üretici test yok; testin içine geçici `File.WriteAllText` satırı eklenip koşulup geri alındı —
    betik: scratchpad `matris.py` / `yazmayol.py`).
  - FE: 17 eksik i18n anahtarı (9 dil, önek grubunun sonuna eklendi — Python ile yeniden sıralama
    156 satır oynattı, geri alındı); `node scripts/generate-screens.mjs`; `IvrGraphCanvas.test.tsx`
    test adında kaçışsız `'`.
- **Doğrulama:** `dotnet build` 0 hata; Architecture 794/794; Api.Tests 4 parça (1307, 1028, 2800,
  1398; sonradan düzeltilen 9 kırmızı dahil Platform+ilgili 1407/1407); `npx tsc -b` 0;
  vitest 67 dosya / 506 test; `dotnet format --verify-no-changes` temiz.
  **KOŞMADI:** Integration.Tests — yerelde Docker kapalı (4 yeni migration dahil).
- **Commit:** `d6356c98` — Durdurulan is akisinin yarim isi main'e alindi ve derlenir/yesil hale getirildi

### 2. Dallar temizlendi (BR-AST-124 maddesi)
- Yerel 7 dal (hepsi main'de, 0 ileride) `git branch -d`; uzak `wip/ast124-be221`,
  `wip/is-akisi-20260925`, `feat/rol-ekran-matrisi` silindi. Kalan: yalnız `main`.

### 3. backlog.md + ClickUp
- 33 kart `Bitti (2026-09-26)` (durum hücresine önek, eski metin "Önceki kayıt" olarak korunur;
  betik scratchpad `durum.py`, durum hücresi = Öncelik hücresi + 2).
- `clickup-senkron.js --kuru` → `clickup-olustur.js` (yeni 0) → `clickup-senkron.js` (yazılan 33)
  → `--kuru`: `fark olan kart: 0, izde olmayan: 0`.
- **Commit:** `09858ac7` — yonetim: 33 kart Bitti

## Kararlar
- Kart bazında commit bölmesi yapılmadı: aynı dosyalar (screens.json, seed, i18n, Program.cs)
  birden çok karta ait; tek commit, mesajda kart listesi.
- WIP kartları kullanıcı emriyle "Bitti" sayıldı; kart bazında içerik denetimi yapılmadı — canlı
  test kullanıcıda.

## Açık kalanlar / sonraki adım
- Kodu hâlâ yazılmamış kartlar: BR-AST-59, BR-AST-62, BR-BE-203, BR-FE-111, BR-SYS-60 (2),
  BR-DB-52 (2), BR-DB-16 (2. adım), BR-DB-67, BR-OPS-11, BR-SYS-51, BR-BE-43-B.
- Integration.Tests Docker'lı ortamda koşulmalı (yeni migration'lar: IysPermissionRefreshIndexes,
  VoicemailCallbackAndResultCodeRequired, ErasureRequests, SlaAutoAnsweredCount).
- BR-10, BR-OPS-09: kullanıcı yapılacak yazmadı.
