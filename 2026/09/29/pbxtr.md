# pbxtr — 2026-09-29

## Bağlam
Kullanıcı: *"devam edermisin"*. Backlog'da açık kart **6**: dördü kullanıcı kararıyla
"şimdilik es geç" (BR-C2-1, BR-C2-2, BR-DB-74, BR-OPS-14), ikisi (BR-10, BR-OPS-09)
yanıtsız. İkisinin de engeli ölçüldü.

Sayım: `bekleyen-md.js` doğrudan koşulursa kullanıcının doldurduğu "Yapılacak" satırlarını
ezer; çıktı yolu geçici dosyaya çevrilerek koşuldu.

## Yapılanlar

### 1. BR-10 — Zamanlanmış rapor: Bitti
- **Neden:** tek engel `BR-BE-218` (POST/PUT 500 ama satır yazılıyor) 2026-09-24'te yayınlanmıştı;
  canlıda gözle ölçülmemişti.
- **Ölçüm (sunucu `date -u` 2026-09-28 23:58Z, demo.sahip, `https://pbxtr.com`):** POST **201**,
  satır tek; PUT **200** (`local_time=10:30`, sayı değişmedi); liste 200; DELETE **204**;
  sonra `report_schedules=0`, `report_deliveries=0`.
- Betik: parola sunucu `.env`'inden değişkenle, çıktıda yalnız durum/sayı
  (`scratchpad/br10-canli.sh`: login → `/me` → POST/PUT/GET/DELETE + psql sayım).
- Gerçek PG testleri 2026-09-28 tam koşusunda yeşildi (`ReportScheduleWriteHttpTests` vb.).
- **Commit:** `a237effa`. ClickUp: BR-10 complete, fark 0.

### 2. BR-OPS-09 — kartın engeli bayattı; yayın gerekiyor
- Ses içeriği **santralde var**: `sounds/pbxtr/sys/hizmet-disi-*` 9 dil, 2026-09-25 06:45–06:53Z
  kurulmuş, gerçek kayıt (8 kHz, ~6–8 sn). (2)(3) dialplan zinciri (`Progress()` +
  `Playback(x,noanswer)` + `en` yedeği + `Hangup(21)`) kodda (`ConfigRenderer.cs:3262-3296`,
  `d6356c98`). Ama canlı sürüm `28eb40f35952` (09-24) → santraldeki dialplan zinciri taşımıyor.
- Yayın başlatıldı: `PYTHONUTF8=1 bash deploy/yerel-yayin.sh --yayinla --santral`.

### 3. Yayını durduran kapı → 4 gündür donmuş santral teslimi bulundu ve açıldı
- **Belirti:** yayın `confd-sunucu-sapma` kapısında durdu: sunucudaki
  `pbxtr-confd-{dugum,cek}.sh` depodan geride (BR-AST-118 ve BR-BE-43-B taşınmamış).
- **Taşımadan önce ölçüldü:** `pbxtr-confd.service` **2026-09-25 07:24Z'den beri her tick
  exit 75**. `t0007/pjsip` rev 8 iki endpoint'i meşru kaldırmış; santral 14→13, beklenen 12.
  Fazla olan: confd dışında elle duran **lab trunk `t0007-trunk-lab`**
  (`/etc/asterisk/pbxtr-lab.d/`; CDR tenant çözümü için bilinçli `t0007-` önekli).
  Delta kriteri düşüşü yalnız TAM eşitlikte kabul ediyordu (`-ne`), mutlak kriter ise alt
  sınır (`-lt`). Revizyon DONDURULDU, t0007'ye 4 gün hiçbir provisioning inmedi.
- **Düzeltme (`19309ad3`):** delta `-lt` (soru "ne kaybettik"; silinmesi gerekip kalanı 10b
  mezar taşı ölçer). Öz-test: F57 (meşru silme + yabancı nesne → yeşil) + M42; M25 F58'e
  taşındı (alt sınırda satır saymanın zararı kaybı maskelemek).
- **Aynı turda:** confd öz-testinde **önceden 4 KALDI** vardı (yayın kapısında koşuyor):
  M6/M13 `String.replace` ilk eşleşmeyi değiştiriyordu ve BR-AST-118 aynı metni daha önce
  yazmıştı (yanlış satıra uygulanıyordu); M40'ta ajan dosyayı yedekten geri koyduğu için
  "dosya duruyor" mutantta da doğruydu; statik "silen fiil yok" iddiası BR-AST-118'in tek
  kapılı silme noktasını tanımıyordu. Sonuç **317/317** (önce 307/4 KALDI). Negatif kontrol:
  onaysız ikinci `rm` satırı → kırmızı.
- **Sunucu:** damgalı yedek (`*.yedek-20260929T000405Z`) → `systemctl stop pbxtr-confd.timer`
  → `PBXTR_CONFD_TASI_ONAY=EVET bash deploy/confd-sunucu-sapma.sh --tasi` → ilk koşu yine 75
  (dondurma defteri) → `/var/lib/pbxtr-confd/dondurulmus` yedeklenip iki t0007 satırı
  kaldırıldı → koşu: dialplan rev 29 + pjsip rev 8 **teslim edildi**, 13→13, komşu t0012
  değişmedi, `Result=success` → timer açıldı, sonraki tick 304 temiz.

- **Commit:** `19309ad3`; kart `BR-SYS-136` (Bitti) `c0d224cb`.

### 4. Yayın 7 → 10: yayın yolunun kırmızıları tek tek kapatıldı
Komut hep aynı: `PYTHONUTF8=1 bash deploy/yerel-yayin.sh --yayinla --santral > scratchpad/yayinN.log`.

| Koşu | Duran yer | Sebep | Düzeltme |
|---|---|---|---|
| önceki | asterisk sapma S1/S2/S5 | S2: konteyner giriş betiği = eski imajınki; S5: silinen ölçüm trunk'ının bayat yükleme hataları | `3d71a157` S2 dar muafiyeti (betik KOŞAN imajın commit'indekiyle bayt bayt aynıysa, yalnız `--santral`); pbxtr-asterisk konteyneri yeniden başlatıldı → 0 hata, 16 endpoint |
| önceki | 11 yerel kapı | bayat donmuş artefaktlar, 72 ekran, envanter/defterler | `3fe2ac8c`, `1bdca056` (görsel taban #27 yenilendi) |
| önceki | LeaderElection mutasyon testi aralıklı | örtüşme zamanlama şansına bağlıydı | `52a76f6b` `EtlProbeJob(workHold)` |
| 6 | Integration TRX kapısı | vstest `notExecuted` sayacını artırmıyor; 1290/1290 geçen koşu KIRMIZI | `efafd582` |
| 7 | 5/7 DB kapıları | sabit port 55432 Windows Hyper-V ayrılmış aralığında (55374–55473) → `bind: forbidden` | `d0bf26b3` port Docker'a seçtirilir, `docker port` ile okunur |
| 8 | yarıda (oturum kapandı) | + `RecordingFanoutJobTests` `pending` | — |
| 9 | Integration 9 KALDI | ilk düzeltmem (`6a615c94`, önceki hedefleri kapat) dinleme kaynağını da kapatıyordu → 23514 `ck_recording_targets_source_enabled`; sınıf TEK BAŞINA yeşildi | `736f570d` `AND NOT is_listen_source`; kaynağı bırakan sınıflarla birlikte 48/48, filtre kaldırılınca 9×23514 (mutasyon yakalıyor) |
| 10 | **testler + imajlar yeşil**, staging mesai kapısı | 15:21 İstanbul, mesai içi | aşağıda |

- **Yayın 10:** kapılar YESIL n=0; Architecture 794/794; Integration 1290/1292 (2 izinli atlama);
  Api 4 parça GEÇTİ; DB kapıları geçti; imajlar `demo-736f570d6557`, `pbxtr-asterisk:22-736f570d6557`
  push edildi; sunucuda dağıtıcı + migrate kütüphanesi güncellendi.
- **Staging reddi (doğru davranış):** bekleyen 9 migration içinde 6'sı ACCESS EXCLUSIVE
  muafiyeti YASAK sınıfında (Karar #69 Ş69-27 / BR-OPS-14); `PBXTR_MESAI_ICI_YAYIN=1`
  bunları geçirmez, kaçış yolu mesai dışıdır. Yedek alındı
  (`backups/pre-736f570d6557.dump`), hiçbir şey değişmedi. `PBXTR_OLCULMUS_PENCERE`
  kullanılmadı: o ölçüm BR-OPS-14'tür ve kullanıcı "es geç" dedi — sahte ölçüm üretilmez.
- Staging adımı 17:05Z'de (20:05 İstanbul) yalnız sunucu tarafı yeniden koşulacak şekilde
  kuruldu (imajlar zaten yayında; tam boru hattı tekrar koşulmaz).

### 5. Staging (20:05 İstanbul) + BR-OPS-09 gerçek santralde: Bitti
- **Staging:** mesai dışında yalnız sunucu adımı koşuldu (imajlar hazırdı):
  `ssh root@176.88.41.220 "PBXTR_DAGITICI_SHA=… PBXTR_SANTRAL_IMAJ='tekbirsoft/pbxtr-asterisk:22-736f570d6557' … /root/staging-yayin.sh 736f570d6557"`
  → `STAGING_RC=0`; 9 migration uygulandı (`__EFMigrationsHistory` 244, son
  `20260928100000_PartialUniqueIndexInventory`); app + santral `736f570d`.
- **S1–S9:** `bash deploy/asterisk-sunucu-sapma.sh` → dokuzu TAMAM (S1 imaj güncel, S2 betik depoyla aynı).
- **Dialplan:** confd ilk tick'te 304 aldı; renderer parmak izi değiştiği için
  `ProvisioningRerenderJob` ~6 dk sonra üç tenant'ı yeniden üretti (t0007 dialplan rev 30),
  confd teslim etti: `Progress()` ×10, `Playback(…,noanswer)`, `en` yedeği, `Hangup(21)`.
- **(4) telde ölçüm (17:16Z):** yerel `deploy/asterisk-lab/trunk` (compose; sır sunucu
  dosyasından değişkene okundu, basılmadı) → `channel originate PJSIP/7700@t0007-trunk-lab-remote`.
  Sunucuda geçici `exten => 7700,1,Goto(pbxtr-t0007-in,902129990007,1)` (lab bağlamı,
  damgalı yedek) + t0007 geçici `suspended`. Sonuç:
  - edge `announce=pbxtr%2Fsys%2Fhizmet-disi-en`; `CURLOPT(hashcompat)` `%2F`'yi **çözdü**;
  - `UserEvent(PbxtrRouteDecided … Reason: TENANT_SUSPENDED)` → `call_events` `routeSuspended=1`;
  - arayan: `100` → `183 Session Progress` → `603 Decline` (Q.850 cause=16); **200 OK yok**
    (cevaplanmadı, ücretlenmez); santral `Playing 'pbxtr/sys/hizmet-disi-en.gsm'` ~4,9 sn.
- **Yeni kusur — kapı hiç koşmamıştı:** `staging-yayin.sh` anons kapısını
  `/home/vuo/pbxtr-demo/deploy/` altında arıyordu, dizin sunucuda yoktu; 25 Eylül'den beri
  her yayın "ATLANDI" yazdı. `bakim-duyurusu.sh` de hiç açılmadı. Düzeltme `67e4e885`:
  `yerel-yayin.sh` üç betiği taşır, anons betiği yoksa `exit 1`; öz-test `sANONS` 18/18,
  eski dal geri konunca KIRMIZI. Kapı sunucuda ilk kez koştu: YEŞİL. Yerel kapılar 87+6 yeşil.
- **Temizlik:** t0007 `active` (uç 30 sn sonra askıyı bırakıyor), lab bağlamı yedekten geri +
  `dialplan reload`, verbose kapalı, yerel trunk `compose down`; `call_events` 3 +
  `webhook_outbox` 2 ölçüm satırı sayı korumalı silindi. pbxtr `cdr`'de 1 satır
  (linkedid `1790702169.0`) bırakıldı — Asterisk CDR'ı durduğu için.
- **Commit:** `67e4e885` (düzeltme), `51fc7746` (kart Bitti), ClickUp eşleme; pano fark 0.
- **Not:** lab trunk yapılandırması okunurken lab trunk parolası oturum çıktısına düştü;
  değiştirilmesi önerildi.

## Kararlar
- Test sunucusunda mesai kapısı **aşılmadı**; kapı ölçülmemiş kilit penceresini koruyor,
  bekleme maliyeti yalnız saat.
- Paylaşılan fikstür tenant'ında temizlik yapan test, başka sınıfların bıraktığı
  kısıtlı satırlara dokunmamalı — tek sınıf koşusu bunu göstermez (bkz. hafıza
  "Filtreli test kapıyı görmez").

## Açık kalanlar / sonraki adım
- Açık kart kalmadı; yalnız kullanıcının "es geç" dediği dört kart duruyor.
- ÖLÇÜLMEDİ: anonsun RTP'sinin arayana fiilen aktığı (sayaç okunmadı).
- ÖLÇÜLMEDİ: #37 sağlık ekranı confd KISMI durumunu 4 günde gösterdi mi.
- Es geçilenler: BR-C2-1, BR-C2-2, BR-DB-74, BR-OPS-14.
