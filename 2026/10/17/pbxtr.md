# pbxtr — 2026-10-17

## Bağlam
Menü matrisi 2026-10-16'da canlıya çıktı (`demo-e6f7e224da02`, bkz. `2026/10/16/pbxtr.md`).
Kullanıcı üç şey istedi: Lark SMTP/DKIM açıklaması, ekran × rol listesinin Excel'i (kendisi
düzenleyecek), bayi kısıtı için iş kartı.

## Yapılanlar

### 1. Lark SMTP ve DKIM ölçümü
- **Neden:** posta 535 dönüyor; DKIM selector bilinmiyordu.
- **Ölçüm (sunucudan `dig`):** `vuotech.com` MX = Lark (mx1/2/3.larksuite.com), SPF
  `v=spf1 +include:spf.onlarksuite.com -all` var. **DKIM yok:** 12 yaygın selector
  (`default s1 s2 lark larksuite larkmail feishu mail dkim selector1 google k1`) boş.
  **DMARC yok.**
- **Kullanıcıya:** Lark Yönetim Konsolu'nda üçüncü parti istemci izni + masaüstü uygulamada
  uygulamaya özel parola (*Settings → Mail → Third-party email client logon*); parolayı #68
  Posta Ayarları'na kendisi girer. DKIM TXT kaydını Lark *Mail → Domain*'den alıp DNS'e ekler,
  selector'ı bildirir → `/etc/pbxtr/mail-onkosul.env` `PBXTR_MAIL_DKIM_SELECTOR`.
  DMARC önerisi: `_dmarc` TXT `v=DMARC1; p=none; rua=mailto:info@vuotech.com`.

### 2. Rol × ekran Excel'i
- **Ne yapıldı:** `doc/rol-ekran-matrisi.md` (üretilmiş, canlıyla birebir) + `screens.json`
  (grup, route, sıra) → `C:\Users\abdus\Downloads\pbxtr-rol-ekran-matrisi.xlsx`.
  66 satır, 7 rol sütunu (1/boş, liste doğrulaması, sarı = düzenlenebilir), `COUNTIF` toplam
  satırı, "Notlar" sayfası (bilinçli sapmalar).
- **Betik:** scratchpad `matris-excel.py <repo> <çıktı>` (depoda değil; yeniden üretmek için
  aynı mantık: md tablosu + screens.json grubu).
- **Doğrulama:** satır başı sayım 29/28/8/40/37/5/2 = canlı `/api/v1/me/menu`. `recalc.py`
  Windows'ta koşmadı (`socket.AF_UNIX` yok); formüller basit `COUNTIF`, Excel açılışta hesaplar.

### 3. BR-SEC-33 — bayi çağrı merkezi işletemez
- **Kullanıcı:** *"bayi tenantinda cagri merkezi tenantindakileri yapamasin olmadi kendine bir
  tenant acsin oradan yonetsin"*.
- **Ölçülen bugünkü hâl:** bayi `user.impersonate` taşır; `ImpersonationRules.Check`
  (`src/Pbxtr.Domain/Platform/Identity/ImpersonationRules.cs`) single kapsamlı hedefe izin
  verir → bayi altındaki tenant'ın owner/süpervizör/agent'ı olarak her şeyi yapabilir;
  `tenant.write` + #53 drill-in de var.
- **Kart:** yalnız ticari yönetim (tenant kartı, limit, kullanıcı/rol, destek) kalsın;
  çağrı merkezi yetkileri bayi oturumunda ve taklitte 403; bayi kendi çağrı merkezi için kendi
  tenant'ını açar ve oradaki owner hesabıyla yönetir; kilit testleri.
- **ClickUp:** yeni kart açıldı, `--kuru` fark 0.
- **Commit:** `9e81e1c8`.

## Kararlar
- Bayi altındaki tenantları işletmez; işletme kendi tenant'ında owner hesabıyla (kullanıcı).

## Açık kalanlar / sonraki adım
- BR-SEC-33 uygulaması.
- Kullanıcının Excel'de yapacağı düzeltmeler → seed/screens'e işlenecek.
- KULLANICI: Lark uygulama parolası, DKIM kaydı + selector, DMARC; Yapilacaklar dosyasındaki
  parolayı silmek.
