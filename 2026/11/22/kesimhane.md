# kesimhane — 2026-11-22

## Bağlam
- Kullanıcı Kesimhane masaüstünü açtırdı (`dotnet run --project Kesimhane.Desktop`) ve sordu: "Pastal Telegram'dan onay istiyor mu?"
- Durum: istemiyordu. Onay yalnız uygulama içindeydi: pastal detay → Onayla/Reddet; yetki `UZM_Ayar.PastalOnayKullanicilari` (boşsa herkes).
- Onay Merkezi'nde "pastal" türü tasarlanmıştı ama Kesimhane bağlı değildi.
- Kullanıcı: "evet bağla, Telegram'dan onay gelsin" ve "pastalda da şimdilik kumaş kontrolünü kaldıralım, istediğini yükleyebilsin".

## Yapılanlar

### 1. Kumaş kontrolü kaldırıldı (`b72e15b`)
- **Neden:** Kullanıcı kumaş seçmeden de pastal yüklenebilsin istedi.
- **Ne yapıldı:**
  - `PastalKurallari.RevizyonDogrula`: `KumasSecilmedi` kuralı kaldırıldı; kumaş 0 = seçilmedi. Şema `KumasInventoryId NOT NULL`, FK yok; DDL yapılmadı.
  - `RevizyonKaydetAsync`: aynı pastal kodu farklı kumaşla gelince `PastalKumasFarkli` yerine revizyon açılır. Pastalın kumaşı değişmez (UZM_Pastal tetikleyicisi güncellemeyi zaten yasaklıyor).
  - `KesimDurumuAsync`: kumaşsız pastalda NetTeslim, order kaleminin bütün kumaş hareketlerinden (`h.Kumas = 1`) hesaplanır. OncekiKullanilan kumaşsız pastalları da sayar.
  - Kesim iadesi kumaşsız pastalda en son teslim alınan kumaştan açılır (`InventoryId` kaynaktan alınır).
  - Metinler: "Kumaş (isteğe bağlı)"; kullanılmayan `KumasSecilmedi` / `PastalKumasFarkli` anahtarları silindi.
- **Testler:** `Revizyon_dogrulama` güncellendi. `Pastal_onayi_...` sonunda farklı kumaşla R3 başarılı ve kumaş aynı kalıyor. Yeni: `Kumassiz_pastal_kaydedilir_ve_teslim_alinan_kumasla_kesilir`.

### 2. Pastal onayı Telegram'a (`b72e15b`)
- **Ne yapıldı:** Yeni `Ekranlar/Veri/OnayMerkeziIstemcisi.cs`. Form kaydında revizyon commit edildikten sonra `POST {OnayMerkeziAdres}/api/olay` çağrılır (`X-Api-Anahtari`).
  - Gövde: tur `pastal`, başlık "Pastal — {order} · {kod} · R{n}", açıklama (kumaş, en/boy/kat/verim/pay, kat başı bedenler, marker), kaynakRef `PastalRevizyon:{revId}`, veri JSON.
  - Ayarlar `UZM_Ayar`: `OnayMerkeziAdres`, `OnayMerkeziAnahtar`. Boşsa hiçbir şey gönderilmez.
  - Gönderilemezse kayıt durur; "Telegram'a gönderilemedi — uygulamadan onaylanabilir" uyarısı çıkar.
  - `IslemSonucu.Id` eklendi; yeni revizyonun kimliğini taşır.
  - Uygulama içi onay da çalışıyor; önce gelen karar geçerli.
- **Testler:** `OnayMerkeziTestleri` (gövde, kumaşsız açıklama, ayarlı mı).
- **Komut:** DB testleri bağlantıyı malkabul'ün kayıtlı ayarından alan yardımcıyla koşuldu (şifre ekrana basılmaz). `dotnet test Kesimhane.Tests` → 39/39.

## Açık kalanlar
- Onay Merkezi yeni sürümü (`9939c5e`) sunucuya kurulmalı. Kurulum kullanıcı onayıyla yapılacak.
- Onay Merkezi paneli:
  - Uygulama `kesimhane` açılıp API anahtarı alınmalı.
  - Olay türü `pastal` tanımlanmalı: grup, gereken onay, görevler.
- `UZM_Ayar`: `OnayMerkeziAdres` ve `OnayMerkeziAnahtar` girilmeli.
- Kesimhane masaüstü yeniden derlenip dağıtılmalı; açık olan pencere eski sürüm.

## Düzeltme: pastal Sentez'den (aynı gün, akşam)
- **Kullanıcı:** "Kesimhane hâlâ bir tablo yüzünden hata veriyor; pastal konusunu Sentez'den yapmayacak mıydık?"
- **Teşhis:**
  - Log'da `Invalid object name 'dbo.UZM_KesimGirisBeden'`: db/0002 canlıya hiç kurulmamış.
  - 17.11'deki kararla pastal Sentez'den okunmalıydı (malkabul öyle çalışıyor). Kesimhane hâlâ eski UZM pastal modülündeydi; yukarıdaki 1. ve 2. madde de yanlışlıkla bu eski modülün üstüne yapıldı.
- **Karar (AskUserQuestion):** "Sentez'den oku + Telegram onayı".
- **Onay nerede tutulur (benim kararım):**
  - Sentez kesim kaydındaki `Erp_WorkOrderProduction.UD_CuttingApprove` alanı (nvarchar(50)). Canlıda hiçbir kayıtta dolu değildi.
  - DDL gerekmiyor, karar Sentez'de görünüyor, malkabul doğrudan okuyabiliyor.

### 3. Kesimhane yeniden yazıldı (`6d90acd`)
- **Silinenler:** UZM pastal modülü (PastalForm/Detay, OrderDetay, KesimGiris, GeminiMarker, KesimHesabi, IhtiyacPlani, PastalDeposu), PdfPig bağımlılığı ve örnek PDF'ler.
- **Yeni ana ekran `KesimListeViewModel`:**
  - `SentezKesimDeposu.KesimlerAsync` listeler: proses 167, ProductionType 1, son 300 kayıt; pastal no girilmiş olanlar önce.
  - Sütunlar: order, renk, model, pastal no, kat, adet, tarih, onay durumu.
- **Pastal hazır:** malkabul kuralıyla aynı, MarkerNo dolu ve NumberOfPlies > 1.
- **"Telegram'a gönder" akışı (`SentezKesimDeposu.OnayaGonderAsync`):**
  1. Alan "Bekliyor #0" yapılarak kayıt sahiplenilir; boş ya da "Ret:" değilse gönderilmez.
  2. Onay Merkezi'ne `tur = pastal`, `kaynakRef = SentezKesim:{RecId}` olayı gönderilir.
  3. Alana "Bekliyor #{olay}" yazılır. Gönderim hata verirse alan eski değerine döner.
- **Testler:** `SentezKesimTestleri`. Canlı TEST01 kaydı (194912) listelenir; gönderim, hatada geri dönüş ve ikinci gönderimin reddi rollback ile test edildi. 19/19.
- **Headless render:** `kesimhane-1-kesim-listesi.png` kontrol edildi. TEST01 satırında "Telegram'a gönder" düğmesi var; diğer kayıtlarda "Sentez'de pastal no / kat eksik" yazıyor.
