# selvedge — 2026-11-21

## Yapılanlar

### 1. Mal kabul standart anketi (MALKABUL)
- `db/migrations/0031_malkabul_anket.sql` eklendi. Mobil QC, 'Mal Kabul' aşamasında önce MALKABUL anketini yüklüyor. Ayrıntı: `malkabul.md` §4.
- **Commit:** `41662a7`.

### 2. Mobil 1.0.4+5 → tablet
- **Neden:** Kullanıcı tablete hazır Selvedge'in yüklenmesini istedi. Tablette (SM-X110, `R83XB0S3C7Y`) zaten en son hazır APK (1.0.3, 06.10) vardı. 06.10'dan sonraki mobil işleri (giriş düzeltmesi, mal kabul inspection, MALKABUL) hiçbir APK'ya girmemişti.
- **Ne yapıldı:** Sürüm 1.0.4+5 yapıldı, release APK derlendi (debug imzası, eskisiyle aynı), `publish/modfex-qc-1.0.4.5.apk` olarak kopyalandı, `adb install -r` ile kuruldu ve açıldı.
  ```bash
  export JAVA_HOME="C:/Program Files/Android/openjdk/jdk-21.0.8"   # yoksa gradle hata verir
  flutter build apk --release
  ```
- **Commit:** `ed2a79b`.

### 3. Servis paketi
- `deploy/yayinla.ps1` → `publish/Selvedge-Modfex-Servis-20261121-1301.zip` (49,8 MB). İçinde `Selvedge.Api.exe`, wwwroot, `db/migrations` (0030 + 0031) ve gizli `appsettings.Production.json` var.
- Sunucuya kurulmadı. Kurulum: zip 192.168.0.2'de açılır → `servis-kur.ps1` (servisi durdurur, kopyalar, ayarı korur, başlatır). Migration'lar açılışta uygulanır. Kurulumdan sonra zip silinmeli (parola içeriyor).

### 4. Servis sunucuya kuruldu (kullanıcı istedi)
- **Sunucudaki gerçek durum:** Servis adı `SentezSelvedge`. NSSM ile sarılı, klasör `C:\Server\Selvedge-Modfex-Servis`. KURULUM.md'deki "Selvedge" servis adı ve `servis-kur.ps1` akışı geçerli değil. Klasördeki `kur.ps1` SentezServis'e ait, kullanılmadı.
- **Ayar dosyaları:** Sunucunun `appsettings.json` ve `appsettings.Production.json` dosyaları elle ayarlı (bağlantı, Storage `C:\modfex\...\files`, mail, Sentez:AdminUserCodes). İkisine de dokunulmadı.
- **Adımlar** (WinRM `Invoke-Command` + `\192.168.0.2\c$`):
  1. Yedek: `robocopy /E` → `C:\Server\_yedek\Selvedge-Modfex-Servis-20261121-1310` (318 MB).
  2. Hazırlık: yeni yayın, appsettings*.json hariç → `C:\Server\_guncelleme\selvedge-20261121`.
  3. `Stop-Service SentezSelvedge`, ardından `robocopy` (appsettings hariç, /MIR yok), ardından `Start-Service`. Sağlık kontrolü: `http://localhost:8085/` 200 dönmezse yedeğe otomatik geri dönüş.
  4. Hazırlık klasörü silindi.
- **Doğrulama:**
  - `_sv_SqlMigrations`: 0030 ve 0031, 10:05 UTC'de uygulandı.
  - `sv_QaReport.SerialCodes` var; `MALKABUL` anketi 9 soruyla oluştu.
  - `/` 200, `/api/attachments/12/view` 200, `/api/surveys` 401 (giriş gerekli, beklenen).
  - Servis günlüğünde ERR/FTL yok.
  - Malkabul `Canli_selvedge_okunur...` testi artık "hazır" dalından geçiyor.
- **Geri dönüş gerekirse:** Servisi durdur, `robocopy C:\Server\_yedek\Selvedge-Modfex-Servis-20261121-1310 C:\Server\Selvedge-Modfex-Servis /E`, servisi başlat. 0030 ve 0031 yalnız ekleme yaptığı için eski sürüm bunlarla da çalışır.
