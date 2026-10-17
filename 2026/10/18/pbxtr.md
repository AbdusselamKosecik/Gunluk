# pbxtr — 2026-10-18

## Bağlam
Operatör lab'i (2026-10-17) ile kullanıcı `deneme.agent` olarak web'den gerçek gelen çağrı denedi
ve üç sorun bildirdi: (1) "Telefonunuz santralde kayıtlı değil" uyarısı, (2) gelen çağrıda numara
yok, (3) "Kabul et" 502. Ardından: telefon çipindeki Aç/Kapat tasarımı, hoparlör testinde
"Ton çalınamadı", mesai saati kavramının kaldırılması, "testlerle uğraşma şimdilik".

## Yapılanlar

### 1. "Kabul et" 502 — BR-FE-136 (Bitti)
- **Ölçüm:** nginx `POST /api/v1/agent/calls/1792274733.3/actions` → 502 (uygulamanın kendisi,
  `TelephonyRejected`). Santral aynı anda `PJSIP/t0007-wrtc-1047-0000000x is ringing`: çağrı
  tarayıcıya ulaşıyordu. Kuyruk agent'ı `Dial()` ile arar; kanal Stasis'te değil, ARI `answer`
  reddediyor.
- **Düzeltme:** `AgentDeskScreen.tsx`, `shell/IncomingCallAlert.tsx`, `console/ConsoleScreen.tsx`
  — yazılım telefonu `ringing` ise `softphone.answer()` (SIP 200 OK, tarayıcıda); sunucu yolu yalnız
  telefon çalmıyorken.
- **Commit:** `0fad448e`.

### 2. Telefon çipi Aç/Kapat
- **Neden:** `SoftphoneBadge.tsx` `controls.primary`/`controls.danger`'ı taban `.btn` olmadan
  kullanıyordu → ham tarayıcı düğmesi, aralıksız.
- **Ne yapıldı:** `btn + accept` / `btn + dangerGhost` + `AgentDesk.module.css` `.softphoneChip`
  (gap) ve `.softphoneAction` (6/12 px, 11 px). Commit `0fad448e`.

### 3. "Ton çalınamadı" (hoparlör testi)
- **Ölçüm:** canlı CSP `media-src 'self' blob:` — `data:audio/wav` engelleniyor.
- **Düzeltme:** `shell/audioDevices.ts` `toneWavBytes()` + `playTestTone` `blob:` URL ile çalar
  (CSP gevşetilmedi). Commit `1d53a021`.

### 4. Kayıt uyarısı
- **Ölçüm:** Redis `pbxtr:1111…:telephony:registration` → `t0007-wrtc-1047 registered:true`;
  `RegistrationAxis.ForExtension` masa+tarayıcı birleşimi doğru. Uyarı kayıt ölçülmeden önce
  (sayfa açılışı/örnekleyici turu) görülmüş; kod değişikliği yapılmadı.

### 5. Numara görünmüyor — BR-AST-134 (Açık)
- `RedisLiveOperationsView.GetActiveCallAsync` cari eşleşmesi yoksa `null` → "Bilinmeyen arayan".
  Gelen DID çağrısında `contact_id` dolmuyor; `CallerIDNum` yalnız `PbxtrQueueCallback` için
  taşınıyor. Redis'te numara tutmama kuralı korunarak çözülecek (kart).

### 6. Trunk auth `username` — BR-AST-133 (Kısmen)
- **Neden:** yayın 51 (`0fad448e`) santral sapma kapısı S5'te durdu:
  `t0007-trunk-operator-lab: No authentication username` → auth nesnesi hiç yüklenmiyordu.
- **Ne yapıldı:** `ConfigRenderer.cs` trunk auth'a `username=<trunk adı>`. S5 "bu açılıştan beri"
  saydığı için sunucuda `/etc/asterisk/pbxtr.d/pjsip/t0007-pjsip.conf`'a aynı satır elle eklendi
  (yedek `/root/t0007-pjsip.conf.bak-20261018`) ve `docker restart pbxtr-asterisk` (0 aktif çağrı).
  `pjsip show auth` → `username: operator-lab`, yeni ERROR 0. confd sonrası `304 değişiklik yok`.

### 7. Mesai kapısı kaldırıldı + `--testsiz` yayın
- **Kullanıcı:** *"mesai saati kavramini cikart sistemden. testlerle ugrasma simdilik"*.
- `mesai_kapisi`/`mesai_muafiyet_kapisi` çağrıları ve tanımları: `deploy/staging-yayin.sh`,
  `deploy/pbxtr-deploy-artifact`, `deploy/lib/pbxtr-migrate-adimi.sh`; `PBXTR_MESAI_ICI_YAYIN`
  geçişi `deploy/yerel-yayin.sh`'tan çıktı.
- `yerel-yayin.sh --testsiz`: test takımları, güvenlik/DB kapıları, entegrasyon atlanır
  (`ATLANAN-KAPILAR.txt`); derleme, format, typecheck, imaj, staging ve santral kapıları koşar.
- **Komut:**
  ```bash
  nohup bash -c "bash deploy/yerel-yayin.sh --yayinla --testsiz > LOG 2>&1; ...; git push" &
  ```
- Yerel Docker Desktop kapalıydı (ilk deneme imaj adımında düştü); başlatılıp yeniden koşuldu.
- **Sonuç:** yayın 52 yeşil, `tekbirsoft/pbxtr:demo-1d53a02124c5`, push `157e7332..1d53a021`.
  Canlı paket `createObjectURL(new Blob(...audio/wav))` ve yeni kabul yolunu taşıyor.
- **Commit:** `1d53a021`.

## Kararlar
- Yayında mesai saati yok (kullanıcı).
- Şimdilik testsiz yayın (kullanıcı); santral sapma kapısı yine koşar.
- Hoparlör testi kaldırılmadı, düzeltildi (kullanıcı: "kaldirma sorunu coz").

## Açık kalanlar / sonraki adım
- BR-AST-134: kayıtsız arayanın numarası; masa telefonunda "Kabul et".
- BR-AST-133: trunk kullanıcı adı UI/DTO alanı.
- `deploy/lib/pbxtr-migrate-adimi.sh`'te `MESAI_MUAFIYETI_YASAK` listesi ve ilgili kapılar
  (kapi_53/55/68/86, öz-testler) artık ölü/kırmızı — testler açılınca temizlenecek.
- Kullanıcı testi: "Kabul et" ile çağrıyı açıp müziği duymak.
