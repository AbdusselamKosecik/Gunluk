# sentezservis — 2026-09-28

## Bağlam
25.09'da sipariş planlama spec'i ve uygulama planı yazılmıştı
(`docs/superpowers/specs/2026-09-25-siparis-planlama-design.md`,
`docs/superpowers/plans/2026-09-25-siparis-planlama.md`). Kullanıcı "karşılıyor, yap" dedi. Plan bu oturumda
inline uygulandı (executing-plans), sonunda bağımsız inceleme yapıldı. Ara istek: Mısırlı etiketinde paket
miktarının beden bazlı ayrılması, yalnız incelendi.

## Yapılanlar

### 1. Sipariş planlama — 8 görev (TDD)
- **Neden:** Açık e-ticaret siparişleri toplayıcılara atanacak; el terminali bu atamaya bakacak.
- **Ne yapıldı:**
  - **Core, `src/SentezServis.Core/SiparisPlanlama/`:**
    - `PlanlamaModelleri` (tipler)
    - `OtomatikDagitici` (1/2/3+ kalem grubu, sayaç gruplar arası kesintisiz)
    - `PlanlamaKurallari` (tekilleme, atlama nedeni, aktif olmayan kullanıcı)
    - `PlanlamaFiltreCozucu`
    - `PlanlamaSql` (açık sipariş, geçerli satır, depo yeri: sipariş şirketi → 01, `Quantity DESC, LocationCode`)
    - `PlanlamaDeposu` (Entegrasyon bağlantısı; OPENJSON + OUTPUT INTO, yarış koruması)
    - `PlanlamaGunlugu`
    - `PlanlamaServisi`
  - **Migration:** `021_siparis_planlama_gunlugu.sql` (SentezServices).
  - **Host:** `SiparisPlanlamaUclari.cs` (`/api/siparis-planlama`; okuma GirisIster, yazma MudahaleIster + denetim),
    `Program.cs` kaydı.
  - **Web:**
    - `api/siparisPlanlama.ts`, `pages/SiparisPlanlamaSayfasi.tsx` + test
    - Menü: Operasyon → Sipariş planlama; rota `/siparis-planlama`.
  - **Belge:** `docs/siparis-planlama.md`.
- **Kararlar:**
  - Öbek 500 değil 200. `Erp_OrderReceiptItemUpdate` tetikleyicisi her satırda imleçle sipariş toplamı
    prosedürlerini −1/+1 çağırıyor; yalnız yeri değişen satır güncellenir.
  - Kullanıcı listesinden roller (`IsUserRole = 1`) çıkarıldı: 32 kullanıcı, 9 rol.
- **Doğrulama (yerel host + SentezCore2026Test):**
  - Planla: `DeletedBy` yazıldı, `IsDeleted` 0 kaldı, `UD_RAF1` = 000, indirim satırı (100) değişmedi.
  - Eski beklenenle tekrar: "Başkası planladı: Ahmet ADALAR".
  - Kaldır: `DeletedBy` ve `UD_RAF1` NULL.
  - Rol kullanıcısı ve boş liste: 400.
  - Otomatik: 30 sipariş / 3 kişi → 10'ar. Dağılım kurala uygun (1 kalem A3/B2/C2, 2 kalem B'den, 3+ 6'şar).
    Uygulama 4,8 sn (371 satır).
  - Liste 1.800 siparişte ~3 sn.
  - Sonunda test ERP'de planlı sipariş ve dolu `UD_RAF1` sayısı 0.
- **Testler:** .NET 626 → 668, web 63 → 68.
- **Commit'ler:**
  - `6bc83cd`, `970b69d`, `799bd62`, `46ff410`, `93a94ca`, `bca3b7b`, `b803c91`, `fe9d127`
  - Düzeltmeler: `2785952`

### 2. Son inceleme (opus) ve düzeltmeler
- **Sonuç:** 0 kritik, 3 önemli, 6 küçük bulgu.
- **I1 — kısmi hata:** Sonraki öbek düşerse yazılanlar kayboluyordu.
  - Artık o ana kadar yazılanlar raporlanıp duruluyor (`PlanlamaServisi.IsleriYazAsync`, saf ve testli).
  - Otomatik uygulamada tüm kullanıcılar yazımdan önce doğrulanıyor.
  - Ekran hata sonrası listeyi yeniliyor.
- **I2 — İlk N:** "Planlı" filtresi açıkken başkasının siparişini taşıyordu; artık yalnız planlanmamış
  siparişleri alıyor.
- **I3 — gereksiz yazım:** Zaten istenen durumdaki sipariş yeniden yazılmıyor; nedeni "Zaten bu kullanıcıya
  planlı" / "Zaten planlanmamış".
- **Test ERP'de yeniden doğrulandı:** Pasif kullanıcı yazımdan önce 400; kalan 0/0.
- **Ertelenen küçükler:**
  - M1: Son sayfa boşalınca Toplam 0 görünüyor.
  - M2: `IsDeleted` siparişin atlama nedeni yanlış.
  - M3: `FisNo` NVARCHAR(50) sınırı.
  - M4: Eski hata mesajı ekranda kalıyor.
  - M5: İlk N adedi sessizce kırpılıyor.
  - M6: Öbek 200 (bilinçli).

### 3. Mısırlı etiketi — paket miktarı beden bazlı (yalnız inceleme)
- **Bulgu:**
  - `MisirliExcelOkuyucu.cs` beden başına miktarı (ör. 85B = 50, 95B = 5) okuyor ama atıyor.
  - Etikette tek BEDEN metni ve tek PAKET toplamı var.
  - Örnek dosyada 150 kolinin 133'ü çok bedenli ya da çok satırlı.
- **Seçenekler:**
  - A) BEDEN satırında döküm.
  - B) EAN satırında paket.
  - C) Beden başına etiket.
- **Kullanıcıya sorulanlar:** Hangi seçenek? Aynı beden çok renkliyse ne olacak? Döküm paket mi adet mi?

## Açık kalanlar / sonraki adım
- Sipariş planlama pakete girmedi; kullanıcı isterse yeni paket (önceki paketle karşılaştırarak).
- Ekran elle denenmedi (vitest + API uçtan uca ile kapsandı).
- Mısırlı beden dökümü: kullanıcının 3 cevabı bekleniyor.
- Canlıya geçiş: depo yeri kurulumu (bakım penceresi) + Entegrasyon bağlantısının canlıya çevrilmesi.
- Önceden kalanlar: Shopify indirim kodu, el terminali açık soruları.
