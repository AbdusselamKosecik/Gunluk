# pbxtr — 2026-09-16

## Bağlam

Güne "maddeleri bitirelim" hedefiyle başlandı. Çalışma ağacında **87 değişmiş + 24 yeni**
dosya duruyordu. İlk değerlendirmem "başka bir oturumun yarım işi" idi ve **yanlıştı**:
`git log` gösterdi ki dünkü (2026-09-15) `a10a3d30` ve `ad75a0f1` commit'leri "BR-BE-156
**kod bitti**" diyor ama **yalnızca `yonetim/` altına** dokunuyor. Kodun kendisi
(`CrossTenantWriteAttribute.cs`, middleware kapısı, iki migration, beş yeni entegrasyon
testi) commit edilmemiş hâlde diskteydi. Global kural 1: push edilmemiş iş bitmiş sayılmaz.

Dosya zaman damgaları 14:54–15:07Z aralığında kümelenmişti, hiçbir `dotnet`/`node` süreci
çalışmıyordu → iş bitmiş, sahibi commit'lememiş.

## Yapılanlar

### 1. Dünkü işin ölçülüp commit edilmesi

- **Neden:** Dünkü yeşil TRX'ler (13:06–14:22Z) bu ağacı **kapsamıyordu** — dosyaların
  tamamı 14:54Z ve sonrası. "Takım yeşil" bir tarih iddiasıdır.
- **Ne yapıldı:** ağaç yeniden ölçüldü, sonra 111 yol **tek tek sayılarak** (`git add -A`
  yok, `--pathspec-from-file`) commit edildi.
- **Komutlar:**
  ```bash
  dotnet build pbxtr.sln -c Debug
  bash deploy/test-kos.sh tests/Pbxtr.Architecture.Tests/Pbxtr.Architecture.Tests.csproj --no-build
  bash deploy/ci/api-test-shards.sh --parca 4
  cd src/Pbxtr.Web && npm run typecheck && npx vitest run
  ```
- **Sonuç:** build 0 hata · Architecture **607/607** (beklenen 607) · Api.Tests
  **5347/5347**, kapsam dışı 0 metod · web typecheck rc=0 · vitest **1887/1887** (209 dosya).
- **Commit:** `d8181aa3` — Entegrasyon 8 kodu: çapraz kip yazma kapısı, tenant anons dili,
  kara liste sayacı, migrate sözleşmesi.

### 2. Docker: "yok" değil, YANLIŞ YERDE ARANMIŞ

- **Neden:** `docker info` bağlanamıyordu; 09-11'den beri "Docker Desktop kapalı →
  entegrasyon ölçülemez" diye not düşülüyordu. Bu, **10 kartın tamamını** bloke eden tek
  şeydi ("entegrasyon 8 bekliyor").
- **Ne yapıldı:** kurulum `C:\Program Files\Docker` altında **değil**,
  `C:\Users\abdus\AppData\Local\Programs\DockerDesktop` altındaydı. Oradan başlatıldı.
- **Sonuç:** motor `29.7.2` ayağa kalktı, Testcontainers (postgres:16-alpine + redis:7-alpine)
  çalıştı. **Ders:** "araç yok" ile "aracı yanlış yerde aradım" aynı hata mesajını verir.

### 3. Entegrasyon 8 — 11 kırmızı, üçü de fikstür kusuru

- **Ne yapıldı:** `deploy/test-kos.sh tests/Pbxtr.Integration.Tests/...` → **980/991**.
  Kalan 11'in **tamamı** dün yazılan tek sınıftaydı: `CrossTenantWriteSurfaceHttpTests`.
  Ölçülen kapı (BR-BE-156) doğru çalışıyordu; kırık olan onu ölçen fikstürdü.

  1. **Tohum çapraz kipte `UPDATE public.users` yapıyordu** → `42501 new row violates RLS`.
     Bu arıza değil **karardır**: `users_tenant_isolation` WITH CHECK'i tam olarak
     `home_tenant_id = app_current_tenant()`; çapraz dal yalnız `USING`'de. Metin
     `USERS_ISOLATION_WRONG_QUAL` bekçisiyle birebir dondurulmuş (Karar #23 Ş23-3) — yani
     policy'yi gevşetmek, testin ölçtüğü yüzeyi açmak olurdu. Tohum hedef kullanıcının
     **ev tenant'ı** kapsamına alındı.
  2. **`sender_title`** fikstürü `varchar(11)` + `^[A-Z0-9][A-Z0-9 ]{1,9}[A-Z0-9]$`
     kısıtını ihlal ediyordu (8 haneli küçük harfli suffix) → `22001`.
  3. **İki kontrol yanlış uçta kuruluydu:**
     - Kontrol grubu `GET /api/v1/queues`: superadmin `queue.read` **taşımıyor**
       (permissions.seed.json) → 403 `PERMISSION_DENIED`. "Çapraz başlık GET'te kabul
       edilir" iddiası **hiç ölçülmüyordu**. `GET /api/v1/users` ile değiştirildi.
     - Vacuity `users-parola`: superadmin bir agent'ın parolasını **başlıksız da**
       sıfırlayamıyor (403 `target_more_privileged`; `UserAdminRules` parola sıfırlamada
       alt küme kuralı uyguluyor, agent'ta `call.originate`/`sms.send` var superadmin'de
       yok). O yolda "başlıksız geçer" iddiası baştan yanlıştı → `smtp-ayari`ye taşındı.
- **Dokunulan dosya:** `tests/Pbxtr.Integration.Tests/Tests/CrossTenantWriteSurfaceHttpTests.cs`
- **Sonuç:** `--filter CrossTenantWriteSurfaceHttpTests` → **11/11**, atlanan 0.
- **Commit:** `f3637458`

### 4. Kart ve pano

- 9 kart (`BR-BE-156/157/158/161`, `BR-DB-69/71`, `BR-QA-87`, `BR-OPS-10`, `BR-FE-87`)
  `Kod bitti → Bitti` yapıldı. Durum hücresi **şema ile** adreslendi (öncelik = `P<rakam>`
  ile başlayan son hücre, durum = ondan sonraki ikinci hücre) — konumsal indeks değil.
- ClickUp: `yazilan: 8`, doğrulama koşusunda `fark olan kart: 0, izde olmayan: 0`.

## Kararlar

- **`users` çapraz kipte yazılmaz** — testi geçirmek için policy gevşetilmedi; fikstür
  düzeltildi. Bir bekçinin birebir dondurduğu metni test uğruna değiştirmek, bekçiyi
  kaldırmakla aynı şeydir.
- **Vacuity kontrolü, aktörün gerçekten yapabildiği bir yazma üzerinde kurulur.** Aksi
  hâlde kontrol "başka bir kapıyı" ölçer ve kırmızısı yanlış sınıfta olur.

## Açık kalanlar / sonraki adım

- **Tam entegrasyon takımı fikstür düzeltmesinden SONRA yeniden koşturulmadı** (kullanıcı
  hız istedi). Geri kalan 980 test düzeltmeden önceki koşuda yeşildi ve commit yalnız o
  sınıfın fikstürüne dokunuyor — ama bu, tam takımın bugünkü HEAD'de ölçüldüğü anlamına
  **gelmez**.
- 09-11'den devreden: `BR-QA-55` (f) platform kararı (kurula), `BR-QA-56` (d) iki
  POSIX-bağımlı ST-44 öz-testi.
- Kullanıcıya ait: `/basla pbxtr sprint-44`, confd `ExecStart` geçişi (`BR-SYS-80/86`),
  `BR-SEC-16` sır rotasyonu.
- Yan tespit: 09-11'de bulunan `visual-tests/` typecheck deliği **kapanmış** —
  `npm run typecheck` artık `tsc -b --noEmit && tsc -p tsconfig.visual-tests.json` koşuyor.
