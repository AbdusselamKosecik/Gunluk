# Saas_erp — 2026-11-08

## Bağlam
"backlog'u tamamlayalım" hedefi geceden devam etti. Kurallar aynı:
- Kurul onayı olmadan kodlama yok.
- Ajanlar test koşmuyor; testler en sonda, seri (tek dilim) çalışıyor.
- Test edilmemiş iş push edilmiyor.

## Yapılanlar

### 1. UX post-check (yerel yığın, a655e6c9)
- **Kontrol edilen ekranlar:**
  - **E5 S3 bölme diyaloğu:** veri yoktu; MitoTex'teki bütün seri kartları kumaş. Diyalog yalnız tarayıcıda değiştirilmiş bir yanıtla açıldı, DB'ye yazılmadı.
  - **E10-2 paketleme atık alt satırları**
  - **E2 S3 transfer lot seçici:** yalnız kod incelemesi yapıldı.
- **Sonuç:** blok yok, hepsi PASS-WITH-NOTES.
- **Bulgular:**
  - Türkçe arayüzde ondalık nokta.
  - Boş miktarda mesaj çıkmıyor.
  - Ctrl+Insert yalnız buton odaktayken çalışıyor.
  - Aynı satırda brüt ve net fire birlikte görünüyor.
  - Lotsuz transferde buton metni yanıltıcı.
- **Notlar ve ekran görüntüleri:** `wt/uxlocal12-*`.
- **Düzeltmeler:** ayrı bir dilimde (wte27, `uxpol`).

### 2. Kurul turları
- **E2 S4b-2 (kimyasal sarfın emre bağlı çıkışla netleşmesi):**
  - v2'de şüpheci BLOCK verdi. Sebepler:
    - Fişsiz, yani tamamen netlenmiş bir sarf geri alınamıyordu.
    - Replay null fişte Conflict dönüyordu.
    - Netting unique anahtarı hatalıydı.
    - Eski ledger'sız sarflar R7 tarafından görülmüyordu, bu yüzden backfill gerekiyordu.
    - Kilit sırası ters'ti.
  - 14 koşul `wt/board-e2s4b2-v2.md` dosyasında toplandı.
  - v3 yazıldı. Yeniden denetimde APPROVE-WITH-CONDITIONS çıktı, 12 ek koşulla (`wt/e2-s4b2-v3-proposal.md`, BOARD DECISION bölümü). Bunlardan biri: geri alınmış kimyasal 3062 yeniden onaylanırsa 409 döner (çift düşümü önler).
- **E7 S3b-2 (sevk irsaliyesinde koli seçici):** kurulun tamamı koşullu onay verdi (`wt/board-e7s3b2.md`). Kararlar:
  - Yalnız Kapalı/Uyar modları; Engelle yok, çünkü karışık asorti koli bir satıra bağlanamıyor.
  - Yeni Logistics okuma endpoint'i: `packing-boxes/shippable`.
  - Lot takipli konfeksiyon ürünleri muaf.
  - Ayar `useGetSettings('system_parameters')` ile okunuyor.

### 3. E6 S3b-1 — push edildi
- **Commit:** `7dc255a5` feat(production): makine kontinü/kimyasal depo alanı, iş kaydı düzenle/sil, idempotent kayıt.
- **İçerik:**
  - `Machine.IsContinuous` ve `Machine.ChemicalWarehouseId`; depo doğrulaması Shared `IWarehouseReferenceQuery` portuyla yapılıyor.
  - `JobTransaction.ClientRequestKey` (X-Idempotency-Key) ve partial unique index.
  - PUT ile düzenleme (xmin eski sürüm → 409) ve soft silme.
  - Tenant ayarı `production.dyehouse.chemicalAutoPost` (kill-switch).
- **Migration'lar:**
  - `E6S3b1_MachineFlagsClientKey` (lock_timeout)
  - `E6S3b1_JobTransactionIndexes` (CONCURRENTLY)
- **Doğrulama:**
  - Unit: 9069 geçti.
  - TC, LINT ve vitest (3501) temiz.
  - PENDING_CHECK temiz.
  - PG karşılaştırması: yalnız bu dilimde kırılan yok (24 hata baseline ile aynı).
  - Boş PG17'ye (55432) tüm migration zinciri uygulandı; indeksler ve kolonlar var.
- **Sorunlar:**
  - **İzin sözleşme testi:** yazma endpoint sayısını 109 bekliyordu; 111'e güncellendi.
  - **RESUME ile ikinci koşu:** `regen` "ADD FAILED" verdi ve `clday` changelog'u bozdu. Changelog origin'den geri alınıp madde elle eklendi; ardından `gates.sh` ve `ship.sh` koşuldu. Hafıza notu: `autoship-rerun-pitfall`.
  - **Push:** ilk denemede DNS hatası verdi (github.com çözülemedi). Tekrar denendi ve başarılı oldu.

### 4. UX düzeltmeleri — push edildi
- **Commit:** `cf7c2d85`.
- **Lot bölme diyaloğu:**
  - Miktarlar `formatLocale` ile gösteriliyor (Türkçe arayüzde ondalık virgül).
  - Boş veya geçersiz miktarda satır içi mesaj çıkıyor.
  - Hatalı girişlere `aria-invalid` eklendi.
- **Paketleme:**
  - Ctrl+Insert satır seviyesine taşındı.
  - Etiket net fireyi gösteriyor.
  - Alt satır karanlık modda doğru görünüyor.
  - Pasif durumun sebebi yardım metni olarak yazılıyor.
- **Transfer:** lot seçilmeden onaylanırsa buton "Lotsuz taşı" diyor.
- **Atlanan:** atık seçicisinin boş durum ipucu. Paylaşılan grid bileşeninde bunun için bir yuva yok.
- **Kapılar:** hepsi temiz.

### 5. E7 S3b-2 — push edildi
- **Commit:** `e2d156c5`.
- **İçerik:**
  - `GET /api/v1/logistics/packing-boxes/shippable` (logistics:read).
  - Fiş detayında koli bilgisi.
  - Aynı satırda lot ve koli varsa red: `inventory.receipt.box_with_lots`.
  - Ayar `shipping.apparel.boxRequired`, yalnız Off/Warn.
  - Ön yüzde koli seçici, Uyar onayı ve sistem parametresi seçimi.
  - Fiş ekranı standardına 3052 istisnası eklendi.
- **Hat sorunları:**
  - `system_parameters.page.tsx`'te E6 S3b-1 ile çakışma çıktı; iki sabit de korunarak çözüldü.
  - TURKISH_IN_EN: `en_overrides.json`'a eklendi.
  - RTL guard: `ml-auto`/`mr-auto` → `ms-auto`/`me-auto`.
- **Doğrulama:**
  - Unit: 9082 geçti.
  - Vitest: 3534 geçti.
  - PG: yalnız bu dilimde kırılan yok.
- **Açık:** Chrome post-check (390px, karanlık mod) ve 300'den fazla kolide EXPLAIN kanıtı.

### 6. E2 S4b-2 — kodlandı, test hattı RAM yüzünden durdu
- **Kodlanan:**
  - wte25'te üç migration: `ChemicalNetting`, `ChemicalNettingValidate`, `DyeingBackfill`.
  - Netleştirme çekirdeği ve `ReverseChemicalPosting` (inventory:approve).
  - Modül bazlı erişim filtresi.
  - Ön yüzde panel, ayarlar ve diyalog.
  - Maliyet testi, onay ile sarfın eşzamanlı PG testi ve runbook (`docs/runbooks/chemical-netting-backfill.md`).
- **Bilinen sınır:** Örme ve Boyahane için teorik ihtiyaç henüz hesaplanmıyor. Fark kolonu "—" gösteriyor, Örme uyarı bandı pasif.
- **Hat durumu:**
  - 08:52'de sistem, düşük bellek (3,7 GB boş) yüzünden hattı durdurdu.
  - Yarım kalan migration'lar silindi; asıllar `wt/e2s4b2-mig`'de.
  - Kullanıcı onayıyla yeniden koşulacak.

## Açık kalanlar
- E2 S4b-2: test hattını yeniden koşmak (wte25, RESUME; prep artık temiz).
- E7 S3b-2: Chrome post-check.
- E6 S3b-2 (otomatik kimyasal sarf poster'ı): S3b-1 push edildiği için artık başlatılabilir.
- E6 S4: S3b-2 DEV'de bir tur denendikten sonra.
