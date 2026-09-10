# pbxtr — 2026-09-11

## Bağlam

Gün, **2026-09-10 turunun kesintisiz devamı** olarak başladı: dün gece kapıların tamamı (42/42)
ve web takımı (1725/1725) koşulmuştu; mimari takımda **bugünün kırmızısı** bulunup kapatılmıştı
(SYS-19 ayrıcalık bekçisi, `eb1d643a`). Sıra hiç koşulmamış son takımdaydı: **`Pbxtr.Api.Tests`**.

Dünün tam kaydı: `2026/09/10/pbxtr.md`.

## Yapılanlar

### 1. `Pbxtr.Api.Tests` — `Platform` dilimi yeşil

- **Neden:** dün mimari takımı ayrı koşturmak **bugünün kırmızısını** ortaya çıkarmıştı
  (`DeployPrivilegeTests`). Aynı soru `Api.Tests` için sorulmamıştı ve o takım **380 dosya**
  taşıyor. Defterdeki uyarı da net: *"API testleri parçalanmalı — tek seferde 7 GB'a çıkıp
  takılıyor; CI gibi namespace'e böl."*
- **Ne yapıldı:** takım namespace'e bölünerek koşuldu. İlk dilim:
  ```bash
  dotnet test tests/Pbxtr.Api.Tests/Pbxtr.Api.Tests.csproj --nologo -v q \
      --filter "FullyQualifiedName~Pbxtr.Api.Tests.Platform"
  ```
- **Sonuç:** **1182 test, 0 kırmızı**, 8 dk 9 sn. `Skipped: 0` — yani `RequiresDockerFact`
  atlaması bu dilimde **hiç tetiklenmedi**; ölçüm gerçekten koştu.
- **Sıradaki:** `Modules` dilimi (daha büyük) arka planda koşuyor.

### 2. `Modules` dilimi — **testhost ÇÖKTÜ ve çıkış kodu 0 döndü**

- **Ne oldu:** `--filter "FullyQualifiedName~Pbxtr.Api.Tests.Modules"` koşusu **39 dakika** sonra
  `The active test run was aborted. Reason: Test host process crashed` +
  `MSBUILD : error MSB4166: Child node "3" exited prematurely` ile bitti.
  **Kabuk çıkış kodu `0`.**
- **Defterdeki iki ders aynı anda doğrulandı:**
  *"testhost çökmesi ölçüm kaybıdır — koşu yarıda kesilip başarı gibi görünebilir"* ve
  *"API testleri parçalanmalı; tek seferde takılıyor."* Çıkış kodu `0` olduğu için, çıktı
  okunmasa **"Modules yeşil" denirdi.**
- **Çökmeden önce 6 vaka `[FAIL]` bastı** — ve altısı da isim olarak güvenlik yüzeyinde:
  `RecordingSelfListenEndpointTests.Taninmayan_kip_ERISIM_ACMAZ`,
  `RecordingTargetEndpointTests.Sir_yanitta_DONMEZ_yalnizca_hasSecret_doner`,
  `CallResultEndpointTests.Kart_alanlari_toplanan_veriden_ATILIR`,
  `TenantSettingsEndpointTests.Invalid_values_are_rejected`,
  `SlaConsistencyTests.Uc_ekran_ayni_sla_rakamini_verir`,
  `AgentOriginateEndpointTests.Canli_goruntu_varsa_yapilandirmaya_HIC_bakilmaz`.
- **İLK ÜÇÜ TEK BAŞINA KOŞTURULDU → 51/51 YEŞİL** (4 dk 20 sn, `Skipped: 0`).
  Yani bu üç kırmızı **gerçek kusur değil**, çöken/yüklü koşunun artefaktı (paylaşılan fikstür
  kalıntısı ya da sınıf ortasında ölen host). Kalan üçü ayrıca ölçülüyor.
- **Yöntem notu:** bir çökmüş koşudan çıkan kırmızı, **kanıt değil adaydır**. Her birini yalıtıp
  tekrar koşmadan "kusur" demek, bugün defalarca eleştirdiğim yanlış-kırmızı sınıfının ta kendisi
  olurdu.

