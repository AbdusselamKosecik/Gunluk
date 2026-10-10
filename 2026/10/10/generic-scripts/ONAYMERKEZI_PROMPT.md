# Görev: Onay Merkezi Telegram botuna yerel yapay zeka (/ai) ve PDKS raporu (/pdks) eklemek

Proje: `X:\Gitlab\modfex-apparel\onaymerkezi` (.NET, Telegram.Bot 22, Dapper, long polling, bot: @modfex_bot,
gruplar: "modfex onay", "modfex bildirim"). Önce bu projenin günlüklerini oku:
`X:\GitHub\Abdusselam\Gunluk\2026\10\08\onaymerkezi.md`, `...\2026\10\09\onaymerkezi.md`, ve bu işin geçmişi için
`...\2026\10\10\generic.md`. Spec: `docs/superpowers/specs/2026-10-09-onaymerkezi-design.md`.

## Daha önce yapılanlar (generic oturumu, 2026-10-10)

### 1. Yerel LLM sunucusu — ÇALIŞIYOR
- Sunucu: `modfexsrv` **192.168.0.2** — HPE DL380 Gen10, Xeon Silver 4210R 10C/20T (AVX512), 96 GB RAM, GPU yok.
  Aynı zamanda **DC (AD DS/DNS/DHCP), SQL Server 2022, Hyper-V**. Bir NIC'te **public IP 196.204.119.91/29** var.
- llama.cpp b11541 (win-cpu-x64) → `C:\llama\bin`. Model: Google resmi
  `gemma-4-26B-A4B-it-qat-q4_0-gguf` (`C:\llama\models\gemma-4-26B_q4_0-it.gguf` + `gemma-4-26B-it-mmproj.gguf`, görsel destekli).
- Zamanlanmış görev `llama-server` (AtStartup, SYSTEM, BelowNormal öncelik, çökünce 1 dk'da yeniden başlar),
  başlatıcı `C:\llama\run-server.cmd`: `-t 6 -tb 6 -c 16384 -np 2 --alias gemma-4-26b --port 8180`.
- Firewall: 8180 yalnız `192.168.0.0/16, 100.64.0.0/10` (LocalSubnet KULLANILMADI — public /29'u kapsıyor).
- **API (OpenAI uyumlu):** `http://192.168.0.2:8180/v1/chat/completions`, `model: "gemma-4-26b"`.
- Ölçüm: üretim ~**11 tok/s**, prompt ~31 tok/s → 300 kelimelik yanıt ~30 sn. DC/DNS etkilenmedi (CPU ~%33).
- **Dikkat:** Gemma 4 varsayılan "thinking" açık; max_tokens düşükse `content` BOŞ döner.
  Hızlı yanıt için istek gövdesine `"chat_template_kwargs": {"enable_thinking": false}`.

### 2. PDKS günlük giriş-çıkış raporu — ÇALIŞIYOR (Python prototip)
- Kaynak DB: **zkbiotime** (ZKTeco BioTime), SQL Server localhost @ 192.168.0.2. Sadece SELECT.
- Tablolar: `iclock_transaction` (emp_code, punch_time, punch_state '0'=giriş '1'=çıkış, terminal_alias Yuz1/Yuz2),
  `personnel_employee` (status=0 aktif, ~359 kişi; first_name, last_name, department_id),
  `personnel_department` (dept_name). Cihazlar: Yuz1 192.168.0.30, Yuz2 192.168.0.29.
- BioTime'da **vardiya tanımlı değil** → eşikler parametre: geç `06:30`, erken çıkış `16:30` (dakika bazında
  karşılaştır, 06:30:45 geç DEĞİL). Kullanıcıdan doğru mesai saatleri teyit bekleniyor.
- Prototip: `X:\Yazilim\generic\pdks-rapor\pdks_gunluk.py` — SQL'i ve durum kuralları buradan C#'a taşınacak
  (Gelmedi / Giriş yok / Geç geldi / Çıkış yok / Erken çıktı / Normal; "Günlük" + departman "Özet" sayfası).
- 2026-10-07 sonucu: 359 aktif, 329 geldi, 30 gelmedi, 19 geç, 16 eksik okutma (doğrulama için referans).
- Açık soru: 2026-10-08'de 3, 2026-10-09'da 0 kayıt var — tatil mi cihaz mı, kullanıcıya sorulacak.

### 3. Sentez keşfi (sadece metadata)
- **SentezCore** 511 tablo (Erp_WorkOrder*, Erp_Inventory*...). Plan: `ai` şemasında Türkçe kolonlu view'lar +
  yalnız bu şemaya SELECT yetkili `ai_okuyucu` login → text-to-SQL. **Henüz oluşturulmadı, canlı DB'ye yazmadan önce kullanıcı onayı al.**

## Yapılacak: Onay Merkezi botuna entegrasyon

**Önemli:** Bir bot token'ı için yalnız TEK long polling istemcisi olabilir (ikinci getUpdates 409 Conflict verir).
Bu yüzden ayrı bot süreci YAZMA; komutları onaymerkezi'nin mevcut güncelleme işleyicisine ekle.

1. **`/ai <soru>`** — Metin yerel Gemma'ya (8180) gider, yanıt aynı sohbete döner.
   - Önce "⏳ düşünüyorum…" mesajı gönder, yanıt gelince `editMessageText` ile değiştir (yanıt 10–60 sn sürer).
   - HttpClient zaman aşımı ≥ 180 sn; thinking kapalı varsayılan, `/ai+` gibi bir varyantla açılabilir (opsiyonel).
   - Telegram 4096 karakter sınırı: uzun yanıtı böl. Mesaj biçimi mevcut HTML kaçış kurallarına uysun.
   - Gruplarda gizlilik modu açık: komut `/ai@modfex_bot` olarak da gelebilir, ikisini de tanı.
   - Aynı anda en fazla 2 istek (llama-server `-np 2`); fazlası kuyruğa, kullanıcıya "sırada" de.
2. **`/pdks [YYYY-AA-GG]`** — Tarih yoksa bugün. Özet sayıları mesaj olarak, departman özeti + kişi listesi
   Excel olarak (ClosedXML vb.) `sendDocument`. Ek: `/gelmeyenler`, `/gec` (bugün).
3. **Yetki:** Mevcut görev bazlı yetki yapısını kullan (UZM_OnayGorev / UZM_OnayGorevKisi) — örn. "YZ Kullanıcı" ve
   "PDKS Rapor" görevleri; yetkisiz kişiye kısa ret mesajı. Kişi tanıma mevcut `/kayit` / UZM_TelegramKisi üzerinden.
4. **Ayarlar panelden:** LLM adresi/model/thinking, PDKS bağlantı metni, geç/erken eşikleri (UZM_OnayAyar).
5. **DB erişimi salt okunur:** zkbiotime için ayrı, yalnız SELECT yetkili bir SQL login öner (`ai_okuyucu`);
   DDL/GRANT'i kullanıcıya gösterip onayını almadan çalıştırma. Bağlantı metninde `ApplicationIntent=ReadOnly`.
6. **KVKK:** Telegram yurtdışı sunucu → isimli personel listesi kişisel veri aktarımı. Kullanıcıya sor:
   gruplarda yalnız özet sayılar, isimli Excel yalnız özel mesajla/yetkililere mi gitsin?
7. **Opsiyonel:** Mevcut "Yapay zeka onaycısı" (Claude API) için sağlayıcı seçeneği olarak yerel Gemma
   (OpenAI uyumlu uç nokta) eklenebilir — veri dışarı çıkmaz; görsel için mmproj yüklü.
8. Kontroller: onaymerkezi servis portu planda **8086**, sunucuda 8085–8088 zaten dinleniyor → çakışma kontrol et.
   Sunucuya erişim: WinRM 5985, laptop'ta DPAPI kimlik `%USERPROFILE%\srv02.cred`
   (`Invoke-Command -ComputerName 192.168.0.2 -Credential (Import-Clixml "$env:USERPROFILE\srv02.cred")`).

## Kurallar
- TDD ile ilerle (projenin mevcut düzeni), `dotnet test` yeşil kalsın.
- Global kurallar: iş sonunda dokunulan yolları açıkça `git add`, commit, **push**; ardından
  `Gunluk\2026\10\<gün>\onaymerkezi.md` güncelle ve push et.
- Kullanıcıya sorulacaklar: mesai saatleri (cumartesi dahil), 8–9 Ekim boşluğu, KVKK tercihi, hangi gruplarda /ai açık olsun.
