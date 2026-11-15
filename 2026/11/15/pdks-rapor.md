# pdks-rapor — 2026-11-15

## Bağlam
ZKBio Time (BioTime, 192.168.0.2, DB `zkbiotime`) kişi kodlarının Den (bordro) sicil numaralarına
(`EMPLOYEE NR`, 6 hane, baştaki sıfırlarla) çevrilmesi istendi. Sonraki adım: departmanları Den'e göre düzenlemek.

## Yapılanlar

### 1. Yapı keşfi (salt okunur)
- 914 kişi, 2 cihaz (SpeedFace-V5L: Yuz1 192.168.0.30 SN SYZ8241400430, Yuz2 192.168.0.29 SN SYZ8241400429).
- Kodun geçtiği tablolar: `personnel_employee`, `iclock_transaction`, `ep_eptransaction`, `iclock_terminalemployee`, `sync_employee`, `meeting_meetingtransaction` (hepsi nvarchar ≥20).
- Biyometri DB'de: `iclock_biodata` (yüz type 9: 823, avuç type 8: 60, parmak type 1: 19) — `employee_id` ile bağlı, koda değil.
- Kayıt fotoğrafları diskte: `C:\ZKBioTime1\auth_files\register\` (DB'de sadece dosya adı).
- Cihaza giden komutlar: `iclock_terminalcommandlog`. Kod değişince BioTime yeni PIN'i ekliyor, eskiyi silmiyor → cihaz temizlenip yeniden senkronize edilmeli.
- Cihaz baştaki sıfırları koruyor (test: `000000` cihazda öyle göründü).

### 2. Kaynak doğrulama
- Kaynak: `X:\Gitlab\modfex-apparel\coud  update.xlsx` — `Code`=eski, `EMPLOYEE NR`=yeni; `0` olanlar (10 kişi) değişmedi.
- Den `\\192.168.0.2\Dendata\Den\Per\Egp\12r\f01\2026\EMPXX.MAS`: sabit 786 bayt kayıt; isim @497 (35 kr, kesik), EMPLOYEE NR @677, PACS NR @688. Departman listesi `DEPXX.MAS` (4331 bayt kayıt, isim @3). Unvanlar `CFF\JDEXX.DAT` (32 bayt).
- Den Excel çıktısı `DendataSonEmployeeLi.XLS`: OLE akışı adı `WorkBook` (standart dışı) → xlrd/calamine açamıyor. Çözüm: `olefile` ile akışı çıkar, `xlrd.open_workbook(file_contents=stream)`. İsimler 10 karakterde kesik; DEPARTMENT sütunu güvenilir.

### 3. Uygulama
- **Yedekler** (sunucu): `C:\Yedek\zkbiotime_kod_degisimi_20261115\` → `zkbiotime_once.bak` (sabah), `zkbiotime_aksam_1800.bak` (uygulama öncesi, COPY_ONLY+CHECKSUM, VERIFYONLY ok), `auth_files`, `auth_files_aksam`.
- Betik: `kod-degisimi/kod_degistir.sql` — eşleştirme tablosu, çakışma kontrolü, satır sayısı doğrulaması, tek transaction, `UYGULA=0` kuru çalıştırma.
- Kuru çalıştırma: 346/346, 211222 geçiş satırı. Not: yorumdaki `{{...}}` yer tutucuları da değiştirildiği için ilk deneme sözdizimi hatası verdi → yorum düzeltildi.
- Test: 54562 (kullanıcının kendi kaydı) → 000000 → 099999.
- 18:05 toplu uygulama: 346 kişi, 211538 `iclock_transaction`, 211508 `ep_eptransaction` → COMMIT.
- Servis yeniden başlatma: `bio-server` restart'ta durdu, `Start-Service bio-server` ile açıldı. Web 200, cihazlar bağlı.
- 19:00 Den'e göre 3 düzeltme (Excel'deki Code sütunu hatalıydı): 5501 Saida → 000329, 5502 Abeer → 000328 (takas), 5055 Mervat → 5055 geri (Den'de yok). `emp_id` bazlı güncelleme, 895 geçiş satırı; 2026 için kod/kişi uyumsuzluğu 0.
- Rapor: `X:\Yazilim\generic\BioTime_Kod_Degisimi_2026-11-15.xlsx` (`kod-degisimi/kod_raporu.py`).

### 4. Ayrıca (Hyper-V / 192.168.1.4) — 11-11 günlüğüne bakınız.

- **Commit:** `107eeca`, `93f2550`, `7a94c18` (pdks-rapor, **remote yok → push edilemedi**)

## Kararlar
- Kodlar baştaki sıfırlarla (`000021`) tutulur.
- Listede olmayanlara dokunulmaz (5320, 5504 Marwan=Den 000330, 5540 Aya=Den 000362).
- Kişisel veri içeren dosyalar (json/csv/Den kopyası) git dışı (`.gitignore`).

## Açık kalanlar / sonraki adım
- Departmanları Den'e göre aç/taşı (karar bekleniyor: yeni departman mı, mevcutları yeniden adlandırma mı).
- Sonra cihazlar: Clear All Data + Sync Data to Device; komut log'dan doğrula.
- Den'de 000180 Haneen Khamis / 000181 Hanin Khamees mükerrer olabilir.
- Test kaydı 099999 — kullanıcının kararı.
- pdks-rapor için remote tanımlanmalı.

## Ek — 19:05 Departmanlar (Den'e göre)
- **Neden:** BioTime departmanları Den ile tutarsızdı (ör. Den LINE 1'deki 51 kişi BioTime'da 16 farklı departmanda).
- **Ne yapıldı:** Den `DEPXX.MAS` sırasıyla 18 yeni departman: `DEN01` ADMINISTRATION … `DEN18` SERVICE (TRANSPORT) (`personnel_department`, company_id=1, parent yok). Den Excel çıktısındaki DEPARTMENT'a göre 332 kişi taşındı. "Department Unassigned" (13, çoğu yeni işe girenler 000349–000361) ve Den'de olmayanlar eski departmanlarında kaldı.
- **Kontrol:** `auth_user_auth_dept`, `att_departmentschedule/policy/deptattrule` boş → departman kapsamı/vardiya etkisi yok. `dept_code` unique (company_id, dept_code), collation Turkish_100_CI_AS → isim yerine `DENnn` kodu seçildi.
- **Betik:** `kod-degisimi/departman_tasi.sql` (kuru + COMMIT, sayı doğrulamalı). Sonra `bio-cache` restart.
- **Sonuç:** acilan 18, tasinan 332/332.
- **Açık:** eski boş departmanların silinmesi (kullanıcı), cihaz Clear + Sync, 5504 Marwan (Den 000330) / 5540 Aya (Den 000362) kodları.
