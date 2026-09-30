# pbxtr — 2026-09-30

## Bağlam
Kullanıcı: *"devam edelim"*. Açık kart yalnız dört "es geç" kartı (BR-C2-1, BR-C2-2,
BR-DB-74, BR-OPS-14). Dünden iki açık uç: belgede çürümüş edge/early-media cümleleri ve
BR-OPS-09'da ölçülmemiş RTP.

## Yapılanlar

### 1. Belge: edge dinliyor, rota kararı soruluyor; askı anonsu early media
- **Neden:** CLAUDE.md/AGENTS.md §3.2 "`pbxtr-edge` uygulanmamış, `8790` dinlemiyor, rota
  kararı hiç sorulmuyor" diyordu; dünkü gerçek INVITE santralde
  `HASH(PBXTR_RD)=1,t0007,announce_hangup,…` üretti. `RouteDecisionEndpoints.cs` yorumu ve
  `doc/mimari/asterisk-dialplan-sablonu.md` "`Answer()`, arayan ücretlendirilir" diyordu;
  üretilen dialplan `Progress()`+`noanswer`, arayan 183 → 603 aldı.
- **Ne yapıldı:** eski cümleler üstü çizili bırakıldı, ölçüm yazıldı; LKG satırı "edge VAR
  ama LKG yok (üst akış hatasında sabit `v=0`)" diye düzeltildi. Şablona "BELGE, ÜRETİCİ
  DEĞİL" notu.
- **Doğrulama:** `deploy/ci/astdb-fallback-iddiasi-kapisi.py` OK, `deploy/pbxtr-edge/selftest.py`
  OK, ClassBHotPath mimari testleri 3/3, tüm yerel kapılar 87+6 YEŞİL.
- **Commit:** `e2b8bed1 `.

### 2. BR-OPS-09 ek ölçüm: RTP
- **Neden:** dün "arayana RTP aktı mı" ölçülmemişti.
- **Ne yapıldı:** sunucuda geçici `exten => 7700` (lab bağlamı, damgalı yedek
  `lab-contexts.conf.yedek-20260930T051358Z`) + t0007 geçici `suspended`; yerel
  `deploy/asterisk-lab/trunk` (sır sunucudan değişkene) →
  `channel originate PJSIP/7700@t0007-trunk-lab-remote`. Not: `core show version` modüller
  yüklenmeden cevap veriyor; `core waitfullybooted` beklenmeli ("No such command").
- **Sonuç:** sunucu tx **220 paket / ~4,4 sn = 50 pps** (alaw 20 ms) → santral early media
  gönderiyor. Arayan rx **0** — ama **kontrol grubu** (cevaplanan 9001, `Wait`) de rx 0:
  lab trunk port yayımlamaz, dönüş medyası arayanın gönderdiği RTP'nin açtığı NAT
  eşlemesine bağlı; early media'da arayan hiç göndermez. **Arayan kulağı bu lab'da
  ölçülemez**; dışarıya açık gerçek SIP istemcisi gerekir. `Playback`li kontrol denemesi
  kurulamadı (kanal "not valid") — kovalanmadı.
- **Temizlik:** t0007 active, lab bağlamı geri + `dialplan reload`, trunk `compose down`;
  `call_events` 18 + `webhook_outbox` 6 satır sayı korumalı silindi (ilk deneme 18/0 ile
  geri alındı: outbox satırları arada `fanned_out_at` almıştı; `webhook_deliveries` 0,
  outbox'a başvuran tablo yok → filtresiz silindi). pbxtr `cdr`'de 6 satır kaldı:
  linkedid `1790745286.1`, `1790745321.2`, `1790745352.3`.
- **Commit:** `9ed46cd0` (kart notu). ClickUp `--kuru`: fark 0.

## Kararlar
- Lab'ın medya yolunu "düzeltmek" (port yayımlamak) yapılmadı: compose bunu bilinçli
  reddediyor (makinenin SIP'ini ağa açar).

## Açık kalanlar / sonraki adım
- Es geçilenler: BR-C2-1, BR-C2-2, BR-DB-74, BR-OPS-14.
- Lab trunk parolası dün oturum çıktısına düştü; değiştirilmesi önerildi (kullanıcıda).
- ÖLÇÜLMEDİ: #37 sağlık ekranının confd KISMI durumunu gösterip göstermediği.
