# pbxtr — 2026-10-19

## Bağlam
Yayın 71 (arayan numarası + canlı kuyruk → script) sahada. Kullanıcı testi: ilk bağlantıda numara geldi, çağrıyı kuyruğa geri gönderince ikinci bağlantıda gelmedi.

## Yapılanlar

### 1. Kuyruğa geri gönderilen çağrıda numara kayboluyordu
- **Neden:** Kullanıcı: "kuyruga gonderdim tekrar geldiginde numara gelmedi. ilk geldiginde geldi."
- **Ölçüm:** sunucuda `call_events`, linkedid `1792378951.100`. 03:03:31'de agent bacakları (.101/.102/.103) Hangup oldu, arayan (.100) kuyruğa döndü (QueueCallerJoin). 03:03:46'da .104 Newchannel geldi.
- **Kök sebep:** `TelephonyEventPipeline.UpdateLiveStateAsync` içindeki Hangup dalı, **her** bacağın Hangup'ında `live:call:{linkedid}` kaydını siliyordu. Kayıt .104 (Local) bacağıyla sıfırdan doğdu. Numarayı yalnız ilk bacak (trunk) yazdığı için numara, cari, köken ve StartedAt kayboldu.
- **Ne yapıldı:** `IsSubLegHangup(event)` eklendi: payload'daki `uniqueid` var ve linkedid'den farklıysa olay bir alt bacak Hangup'ıdır; bu durumda kayıt silinmez. Kapanan kanal dinleme/sufle hedefiyse (`AgentChannelId`) o alan null'a çekilir. `uniqueid` taşımayan olay (simülasyon) eski davranışa düşer; kök Hangup'ı kaçarsa kaydı TTL temizler.
- **Dokunulan dosyalar:** `src/Pbxtr.Infrastructure/Telephony/Pipeline/TelephonyEventPipeline.cs`, `tests/Pbxtr.Api.Tests/Modules/Telephony/InboundCallerScreenPopTests.cs` (+2 test, anti-vacuity: kayıt silinseydi numara null olurdu).
- **Sonuç / doğrulama:** Api.Tests Telephony + Realtime + AgentDesk + Live: 2224 geçti, 0 başarısız.
- **Commit:** `58896eeb` — Kuyruga geri gonderilen cagri: agent alt bacagi Hangup'i canli kaydi silmez.
- **Yayın:** 72 (`--testsiz`).

## Kararlar
- Canlı kayıt ömrü = kök kanalın (linkedid) ömrü. Bacak ömrü değildir.

## Açık kalanlar / sonraki adım
- BR-BE-262: alt bacak Hangup'ları hâlâ `call.ended` yayınlıyor ve CDR satırı yazıyor (çağrı başına 7 satır). Aynı kök sebep sınıfında; sıradaki iş bu.

### 2. Asterisk yapılandırma değişiklik kaydı (belge)
- **Neden:** Kullanıcı: "Asterisk configlerinde neleri degisitirdin bir dokuman cikarabilirmisin?"
- **Ne yapıldı:** Günlük (09-23…10-19) + `git log` (ConfigRenderer, deploy/asterisk-lab, carrier-lab, pbxtr-edge) + sunucu ölçümü (10:50Z: `/etc/asterisk` mtime, host↔depo md5/diff, AMI read/write, netns dinleyenleri) → `doc/mimari/asterisk-config-degisiklik-kaydi.md`.
- **Bulgu:** host ↔ depo farkı yalnız açıklama + lab include'ları; değer farkı yok. 10-18 elle `username` yaması confd üretimiyle örtüldü, yedek silinebilir.
- **Commit:** pbxtr `doc: Asterisk yapilandirma degisiklik kaydi`.

### 3. Tenant ayrımı belgesi (HTML)
- **Neden:** Kullanıcı: "tenati nasil ayirdik" → "tum bunlari ornekleriyle birlikte bir html dosyazi yapip doclara eklermisin".
- **Ne yapıldı:** `doc/mimari/tenant-ayrimi-ve-asterisk-config.html` (tek dosya, dış bağımlılık yok, açık/koyu tema). Örnekler sunucudan, parola satırları süzülerek alındı: `t0007-1047` endpoint, `t0007-trunk-operator-lab` + identify, kuyruk, `pbxtr-t0007-in` başı, `pbxtr.d/` ağacı. Kaynak sırası `AmiTenantCode.cs` ile doğrulandı.
- **Bulgu:** `[pbxtr-dialer]` öneksiz, t0007 ve t0012 dosyalarında birleşiyor (bugün çakışma yok, uzantılar önekli); BR-AST-132 düzeltilirken `pbxtr-{t}-dialer` önerildi.
