# muftelif — 2026-10-27

## Bağlam
26.10'da SentezPlaning'de Fashion & ND hattına Fashion / Non Denim alt görünümü (yalnız yük) eklenmişti
(`3148029`, `d7ee125`). Planlama (Asiye H.) paketi kurup kontrol etti, iki istek iletti (WhatsApp + mail):
1. Alt görünümde başlıklar eksik: **Çalışan, Eff, Dev., Tahmini, Fark**.
2. "Parametreler kısmına da bantları ekleyelim, oraya parametreleri gireyim."

Aynı gün (Olcay B.): SentezSelvedge'den mail gidecek kişiler — hbolu@, mtureli@, ybabadag@ (mfggiyim.com.tr).
Kullanıcı ayrıca "APK'yı da değiştirmen gerekiyor, önce SentezPlaning bitir sonra bak" dedi.

## Yapılanlar

### 1. SentezPlaning: bantlara (Fashion / Non Denim) kendi kadro parametresi
- **Neden:** Alt görünüm kapasite göstermiyordu çünkü çalışan hat başınaydı ve dikim yerine bölünemiyordu
  (26.10 kararı). Planlama bantların kadrosunu ayrı girmek istiyor → bölmek yerine bant başına ayrı parametre.
- **Ne yapıldı:**
  - Model: `LineDef.YerParametreleri : List<YerParam>`; `YerParam { DikimYeri, Calisan, EffGercek=0.85, Abs=0.03 }`.
    `HatAltGrup.Param(line, yer)` (boşluk/harf duyarsız eşleşme).
  - SQLite: yeni tablo `line_yer_param (line_id, dikim_yeri, calisan, eff_gercek, abs, PK(line_id,dikim_yeri))`,
    `CREATE TABLE IF NOT EXISTS` → açılışta kendiliğinden oluşur. Repository Load/Save + `DELETE FROM line_yer_param`.
  - `PUT lines`: bant parametresi yalnız hattın güncel dikim yerleri için tutulur (dikim yeri silinirse parametresi
    düşer), çift kayıt tekilleşir; doğrulama: calisan ≥ 0, eff 0–3, devamsızlık 0–1.
  - `GetWeeks(yer)`: bant parametresi varsa calisan/eff/abs ondan → Tahmini, Fark, Durum, Op. ihtiyacı (abs) hesaplanır;
    `CalisanKaynak/EffKaynak = "bant"`. Yoksa eskisi gibi `Durum="yok"` (yalnız yük). Bantta hafta override'ı yok.
    `GetWeeksToplam(yer)` parametreli bantta tam hafta özetini verir. `GetSevk(yer)` Op. ihtiyacında bandın abs'ı.
  - Excel: bant sayfası parametre varsa `Çalışan, Eff, Dev., Tahmini, Fark` kolonları (+ toplam) taşır.
  - Web: Parametreler → Hatlar'da çok dikim yerli hattın altında `↳ Fashion`, `↳ Non Denim` satırları
    (Çalışan / Eff gerçek / Devamsızlık; çalışan boşaltılırsa bant parametresi silinir). Dikim'de `bantParam`
    varsa `yukOnly=false` → kolonlar ve tam hafta özeti açılır; kaynak simgesi "⚙ bant satırı".
  - **Birleşik Fashion & ND hattının hesabı DEĞİŞMEDİ** (kendi Varsayilan'ını kullanır).
- **Dokunulan dosyalar:** `SentezPlaning/api/Sentez/UretimPlan/{HatAltGrup,UretimPlanController,UretimPlanExport,UretimPlanModels,UretimPlanService}.cs`,
  `SentezPlaning/api/Storage/{PlaningDb,UretimPlanRepository}.cs`, `SentezPlaning/web/src/api/uretimPlan.ts`,
  `SentezPlaning/web/src/pages/UretimPlanlamaPage.tsx`, `SentezPlaning/tests/SentezPlaning.Tests/{HatAltGrupTests,BantParamKayitTests}.cs`
- **Komutlar:**
  ```powershell
  cd SentezPlaning/api; dotnet build
  cd ../tests/SentezPlaning.Tests; dotnet test        # 271/271
  cd ../../web; npx tsc -b; npm run build
  cd ..; powershell -ExecutionPolicy Bypass -File .\Deploy-IIS.ps1
  Compress-Archive publish\* X:\Gitlab\fredericTr\SentezPlaning-paket-2026-10-27-4a71920.zip -Force
  ```
- **Sonuç / doğrulama:** test 271/271 (yeni: bant param eşleşmesi, Excel bant kolonları, SQLite kaydet/oku turu);
  tsc/build temiz; bundle `index-Cn6rDXyl.js`, zip 7.9 MB. Ekran tarayıcıda denenmedi (sunucu kullanıcıda).
- **Commit:** `4a71920` — feat(sentez-planing/dikim): Fashion ve Non Denim bantlarina kendi parametresi

## Kararlar
- Bant kadrosu hattın kadrosundan **bölünmüyor**, ayrıca giriliyor; birleşik hat kendi parametresiyle kalır
  (ikisi tutarsız girilebilir — planlamaya söylenecek).
- Bant için İK departman eşleşmesi ve hafta override'ı yok (istenmedi); verimlilik senaryoları hattınkiler.

## Açık kalanlar / sonraki adım
- SentezPlaning paketi (`SentezPlaning-paket-2026-10-27-4a71920.zip`) sunucuya kurulmalı → Parametreler'de
  Fashion / Non Denim satırlarına çalışan girilmeli → Ctrl+F5.
- Birleşik hat çalışanı = bantların toplamı mı olmalı? Planlamaya sorulacak.
- SentezSelvedge: mail alıcıları (3 adres) + APK değişikliği — sıradaki iş.
