# pbxtr — 2026-10-15

## Bağlam
Kullanıcı `Yapilacaklar 2026 10 14.md` dosyasını (depo kökünde, **izlenmeyen**; içinde SMTP
parolası var → `.git/info/exclude`'a yazıldı, ASLA commit edilmez) analiz edip işlememi istedi:
"Değişiklikler" menüsü, Lark SMTP, /agents–/dealers yetki/rol düzeni, liste sıralama/arama,
renkli rozetler, tenant sekmeli formlar, sistem ekranları (firewall/threats/health/audit/ssl),
bakım ekranları (komut paleti yazmaları, SSH konsolu, Asterisk/FreePBX komutları, sniff,
packages, updates), /setup. Ek istek: `/me/profile` 2FA kurulumunda QR kod.
Kurul dağıtılmış durumda — sorulmadan bitirildi. Sunucu 176.88.41.220 test ortamı.

## Yapılanlar

### 1. Analiz → backlog kartları + ClickUp
- **Neden:** Yapılacaklar dosyası panoda yoktu; kartsız iş görünmez.
- **Ne yapıldı:** 13 kart: BR-SYS-138..143, BR-BE-251..254, BR-FE-133/134, BR-SEC-32 (SSH).
  `node yonetim/arac/clickup-olustur.js` → `clickup-senkron.js` → `--kuru` (fark 0).
- **Commit:** `bcd5b07a`

### 2. nginx yükleme sınırı + retention
- **Neden:** tenant belge yüklemesi 413; çağrı verisi saklama işi kapalıydı.
- **Ne yapıldı:** tenant/documents ve platform/bayi ticket ekleri için 6m `client_max_body_size`
  regex konumu (`bb717ddb`). Compose'ta
  `PBXTR_BackgroundJobs__CallDataRetention__Enabled` varsayılan true (ilk denemede ad yanlıştı,
  düzeltme `48e1f013`). Sunucuya dağıtıldı, env=true doğrulandı.

### 3. SMTP (Lark)
- `PUT /api/v1/system/mail` ile smtp.larksuite.com:465 SSL, info@vuotech.com yazıldı (200).
- **Lark 535 döndü:** verilen parola hesap parolası; Lark SMTP için **uygulamaya özel
  IMAP/SMTP parolası** gerekiyor → KULLANICI AKSİYONU.
- `/etc/pbxtr/mail-onkosul.env`: vuotech.com / smtp.larksuite.com / spf.onlarksuite.com.
  DKIM selector bilinmiyor → KULLANICI AKSİYONU.

### 4. 2FA QR kodu
- `TotpQrCode.tsx`, qrcode-generator@1.4.4, yerel SVG (otpauth URI dışarı gitmez). `88efcfdd`.

### 5. Güvenlik paketi sabitleme
- System.Security.Cryptography.Pkcs 10.0.13 (MimeKit geçişli; GHSA-846f-f764-76mx,
  GHSA-2fmv-rv2c-59x7). `e448d5be`.

### 6. Altı ajan dalı birleştirildi
- Komut paleti yazmaları + Asterisk konsolu FreePBX komutları (BR-SYS-143) — `97590fcb`.
  Katalog 3-yollu birleştirme (`scratchpad/catalog_merge3.py`): 82 komut, 17 dosya okuma, 9 hariç.
- SSH web konsolu: `Pbxtr.ShellBridge` (host'ta PTY, root, tek oturum, boşta 15 dk/toplam 4 sa,
  asciicast kayıt), #66 `/maintenance/ssh`, yetki `system.shell` yalnız superadmin, parola
  yeniden girilerek 60 sn'lik bilet (BR-SEC-32) — `1ee1be65`. CLAUDE.md §5'e "ESKİDİ" notu.
- Sağlık yalnız sunucu satırları, #68 Posta Ayarları `/system/mail`, #67 Değişiklikler
  `/system/changes` (`system.changes.read`) — `acde6c19`.
- Super admin tam yetkili + dokunulmaz (`super_admin_immutable`), bayi = merkez tenant +
  kullanıcı, /agents'tan yalnız parola sıfırlama — `fee00935`.
- Liste sıralama/arama, Badge, lisans satırdan, borç/alacak, sekmeli tenant formları,
  migration `20261015065424_TenantContactUserLink` — `348dc529`.
- Sistem ekranları host ajanından: sysagent 8 MB tampon, GeoIP DB-IP (Dockerfile),
  host yakalama CAP-01..05, saldırı 48 saat grafiği + ülke — `c12661fb`.
- i18n 3-yollu birleştirme `scratchpad/i18n_merge3.py`.

### 7. Sunucu kurulumları
- shellbridge: `/usr/local/lib/pbxtr/pbxtr-shellbridge`, unit enabled, jeton /etc/pbxtr ve
  /etc/pbxtr/app, dinliyor. sysagent yeniden derlendi (82 komut; yedek
  `pbxtr-sysagent.onceki-20261015T082740Z`). Compose shellbridge bağlamasıyla dağıtıldı.

### 8. Yayın kapıları (yayın 32–37 kırmızıları)
- Görsel taban #53 pinli Playwright konteynerinde yeniden üretildi (12/13 aynı) — `d8cecacb`.
- `deploy/pbxtr-shell-ws.conf` snippet'i (mTLS başlıkları silinir, 14700 s zaman aşımı),
  nginx-dogrula / kapi_15 NON_MTLS / kapi-grep-cikis-kontrol / README; smoke.sh kopyası,
  env.example, ekran sayısı 72→75 — `4309286b`, `0b33702c`.
- Backlog BR-FE-63/BR-BE-119 atıfları `PlatformDataSections.tsx:356/:103` — `8b66c127`.
- **Yayın 37 entegrasyon takımı: 4 kırmızı + atlama tavanı aşımı (9 > 6)** — `3fff0e78`:
  - `system.changes.read` `platformScopeOnly` listesine (M5-only oturum system.* taşıyordu).
  - `/system/shell/recordings` MinIO yokken 500 → 200 + `storageUnavailable`, ekran "depoya
    ulaşılamadı" der (9 dilde `ssh.recStorageDown`).
  - StatusChangePrivilegeSurfaceTests geri yükleme: çapraz kipte `users` UPDATE RLS 42501 →
    satırın kendi tenant bağlamında yazıldı.
  - Kanonik artefakt `databaseSchemaRevision` → `20261015065424_TenantContactUserLink`.
  - Super admin dokunulmazlığı 7 vakayı `Skip`'e itmişti; BR-QA-81 listesi yalnız küçülür.
    SuperAdminFloorAmiOrderTests'in 6 ulaşılamaz vakası silindi, yerine dokunulmazlık
    kapısının santralden ÖNCE çalıştığını ölçen 2 vaka; SerializationLockWaitBoundTests
    taban kilidi vakası bugün ulaşılabilen tek yolla (super adminin KENDİ PUT'u) kuruldu.

## Kararlar
- Atlanan test sayısı büyütülmedi (tavan 6 kilitli); ulaşılamaz vakalar silinip yerine
  bugünkü kuralı ölçen vakalar yazıldı.
- Kayıt deposu ulaşılamazken boş liste "kayıt yok" diye okunmasın diye ayrı bayrak.

## Açık kalanlar / sonraki adım
- KULLANICI: Lark uygulamaya özel SMTP parolası; DKIM selector; Yapilacaklar dosyasındaki
  parolayı silmek.
