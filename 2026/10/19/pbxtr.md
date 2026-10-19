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
