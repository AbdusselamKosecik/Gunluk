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

## Açık kalanlar
- UX düzeltme dilimi (wte27): test hattında.
- E2 S4b-2 (wte25) ve E7 S3b-2 (wte26): kodlanıyor.
- E6 S3b-2 (otomatik kimyasal sarf poster'ı): S3b-1 push edildiği için artık başlatılabilir.
- E6 S4: S3b-2 DEV'de bir tur denendikten sonra.
