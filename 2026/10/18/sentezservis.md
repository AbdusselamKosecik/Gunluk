# sentezservis — 2026-10-18

## Bağlam
Kullanıcı: "sentezservis de girisler gelmiyor sabah 8:30 da neden olabilir. cihazlarda birsey yapmak gerekirmi".
modfexsrv Tailscale'de çevrimdışı; SQL'e 192.168.0.2 üzerinden bağlanıldı. Sorguların hepsi salt okuma.
Scratchpad `sorgu2.ps1` ile `MODFEX_SUNUCU` / `MODFEX_DB` ortam değişkenleri kullanıldı.

## İnceleme (systematic debugging)
1. **ZKBioTime kayıtları zamanında geliyor mu?**
   - `zkbiotime.dbo.iclock_transaction`: bugün 08:10'a kadar 334 okutma, 326 kişi; önceki iş günlerinde ~330.
   - Yükleme gecikmesi yok. İki cihazın kayıt id'leri iç içe, yani ikisi de gerçek zamanlı yazıyor.
   - `iclock_terminal`: Yuz1 (SYZ8241400430, 192.168.0.30) ve Yuz2 (SYZ8241400429, .29) ikisi de aktif.
2. **İş çalışmış mı?**
   - `SentezServis.dbo.calistirmalar` (pdks-giris-cikis): 05:10:11 UTC'de (08:10 yerel) başarılı.
   - Özet: "357 personel (222 girissiz, 33 çikissiz)". 14.10'dan beri 210–222 girişsiz; 10–13.10 arasında 30–43.
3. **Raporun sorgusu bugün 08:10:11 itibarıyla elle çalıştırıldı:** 31 girişsiz çıktı. Çelişki var.
4. **Sunucudaki özet metni güncel kodla uyuşmuyor** ("dün … çıkışsız, dün … gelmedi" kısmı yok).
   Sunucuda 13.10 düzeltmesinden (`5b0f6ef`) önceki sürüm çalışıyor.
5. **`punch_state` dağılımı (saat 10:00'dan önce):** bugün Yuz1'in 199 okutmasının hepsi '1' (Çıkış), Yuz2'nin 135 okutması '0' (Giriş).
   Önceki günlerde ikisi de '0'.
   - Eski sürüm girişi yalnız '0' işaretinden okuyor: 357 − 135 = 222. Tam açıklama bu.
   - `iclock_terminaluploadlog`: Yuz1'de 08:06'da User/BioPhoto 5527 kaydı yapılmış (kullanıcı kaydı sırasında durum değişmiş olabilir).

## Sonuç / öneri (kod değişikliği yok)
- **Cihaz:** Yuz1'in durum tuşu Çıkış'ta kalmış. Hemen Giriş seçilmeli; kalıcı çözüm olarak durum Otomatik yapılıp saat tablosu tanımlanmalı
  (00:00–12:00 Giriş, 12:00–23:59 Çıkış). Aynı ayar iki cihazda da olmalı.
- **Yayın:** Güncel sürüm (yön işaretine güvenmiyor, işaret yoksa ilk okutmayı giriş sayıyor) yayınlanmalı.
  Kullanıcı onayı bekleniyor; canlı servis yeniden başlar.

## Açık kalanlar
- sentezservis'in güncel sürümünün modfexsrv'ye yayını (onay bekliyor).
