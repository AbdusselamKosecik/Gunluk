# generic — 2026-10-10

## Bağlam
Ofis sunucusuna (Windows Server 2022 Standard, sadece CPU) yerel LLM kurulumu planlanıyor.
Henüz kurulum yapılmadı; sunucuya erişim (SSH) bekleniyor.

## Kararlar
- Çalıştırıcı: llama.cpp `win-cpu-x64` sürümü, `C:\llama`.
- Model: Gemma 4 12B-it Q4_K_M (~8 GB) ve CPU'da daha hızlı olabilecek 26B A4B (MoE, ~16 GB RAM)
  karşılaştırılacak. HF repo adı indirmeden önce doğrulanacak.
- **llama-server portu: 8180** (kullanıcı isteği; varsayılan 8080 değil). Firewall sadece iç ağ.
- Erişim: sunucuda OpenSSH Server + anahtar ile giriş (şifre sohbete yazılmayacak).
  Alternatif: Claude Code'u sunucuya kurmak.
- Hedef komut:
  ```powershell
  C:\llama\llama-server.exe -hf <repo>/gemma-4-12b-it-GGUF:Q4_K_M --host 0.0.0.0 --port 8180 -c 8192
  New-NetFirewallRule -DisplayName "llama-server 8180" -Direction Inbound -Protocol TCP -LocalPort 8180 -RemoteAddress LocalSubnet -Action Allow
  ```
- Servis: NSSM ile Windows servisi.

## Açık kalanlar
- Sunucu IP/adı, yönetici kullanıcı, RAM ve çekirdek sayısı, AVX512 desteği.

---

## Yapılanlar (devam)

### 1. Sunucu analizi — modfexsrv (192.168.0.2)
- **Neden:** "0.2'ye kuralım" → CPU-only kurulum için kapasite ve risk tespiti.
- **Erişim:** WinRM 5985 açık, laptop TrustedHosts'ta zaten 192.168.0.2 vardı. Kimlik bilgisi
  DPAPI ile `%USERPROFILE%\srv02.cred` (Export-Clixml) — `Invoke-Command -Credential (Import-Clixml ...)`.
- **Bulgular:** HPE DL380 Gen10, Xeon Silver 4210R 10C/20T, AVX2+AVX512, 95.7 GB RAM (78.7 boş),
  C: 777 GB boş, GPU yok. **Sunucu = DC (AD DS, DNS, DHCP) + SQL Server + Hyper-V + httpd + python servisleri.**
  Port 3'te **public IP 196.204.119.91/29**. Laptop sunucuya 192.168.0.221 olarak görünüyor (NAT).
- **Karar:** Seçenek A (doğrudan kurulum, kısıtlı). B = Hyper-V VM (Std lisansı 2 VM) ileride.

### 2. llama.cpp kurulumu
- **Ne:** `llama-b11541-bin-win-cpu-x64.zip` → `C:\llama\bin` (version 0.6.0-dev build 11541).
- **Model:** Google resmi QAT: `google/gemma-4-26B-A4B-it-qat-q4_0-gguf`
  → `gemma-4-26B_q4_0-it.gguf` (13.45 GB) + `gemma-4-26B-it-mmproj.gguf` (1.11 GB, görsel giriş).
  `C:\llama\models`. İndirme SYSTEM görevi `llama-model-download` (`C:\llama\dl\download.cmd`, curl -C - ile devam edebilir).
  Hat ~1.8 MB/s → ~2 saat. Bitince `C:\llama\logs\download.done`.
- **Servis:** `C:\llama\run-server.cmd` (-t 6 -tb 6 -c 16384 -np 2, port 8180, alias gemma-4-26b),
  görev `llama-server`: AtStartup, SYSTEM, Priority 7 (BelowNormal), RestartCount 999 / 1 dk.
- **Firewall:** `llama-server 8180` inbound TCP, RemoteAddress **192.168.0.0/16, 100.64.0.0/10** (Tailscale).
  LocalSubnet KULLANILMADI çünkü public /29 bloğunu da kapsıyor.
- **Betikler:** `generic-scripts/install1.ps1`, `generic-scripts/install2.ps1`
  (`Invoke-Command -ComputerName 192.168.0.2 -Credential $cred -FilePath <betik>`).

## Açık kalanlar
- İndirme bitince: `Start-ScheduledTask llama-server`, /health ve chat testi, hız ölçümü, CPU yükü kontrolü.
- `srv02.cred` iş bitince silinecek; Domain Admin şifresi sohbete yazıldı → değiştirilmeli.
- İsteğe bağlı: `--api-key`, 12B karşılaştırması.

### 3. llama-server devreye alındı ve test edildi
- İndirme 13:55'te bitti; `llama-model-download` görevi silindi, `Start-ScheduledTask llama-server`.
- `/health` 20 sn'de ok. Süreç önceliği **BelowNormal**, RAM ~28 GB.
- Laptop'tan `http://192.168.0.2:8180/v1/chat/completions` (firewall kuralı çalışıyor).
- **Hız:** prompt ~31 tok/s, üretim **~10.9 tok/s**. Türkçe yanıt kalitesi iyi.
- **Not:** Gemma 4 varsayılan "thinking" açık → max_tokens düşükse content boş döner.
  Kapatmak için istekte `"chat_template_kwargs":{"enable_thinking":false}`.
- Üretim sırasında toplam CPU ~%33 (6 thread); DNS yanıtı 1–2 ms (etkilenmedi).

### 4. Rapor (Sentez + PDKS) keşfi — sadece metadata okundu
- SQL Server 2022 (16.0.1200). DB'ler: **SentezCore** (3.6 GB, 511 tablo; Erp_WorkOrder*, Erp_Inventory*),
  **zkbiotime** (ZKTeco BioTime PDKS, 2.9 GB, 285 tablo; iclock_transaction ~312k, att_payloadtimecard ~230k),
  SentezServis, ServisPlanlama, Selvedge, FortiGateLogs, zkbiotime1.
- Plan (onay bekliyor): `ai_okuyucu` SQL login, sadece `ai` şemasındaki Türkçe kolonlu view'lara SELECT;
  text-to-SQL uygulaması (sadece SELECT, TOP 5000, 30 sn timeout, SQL'i göster) + sabit SQL'li sık raporlar.
- Kullanıcıdan beklenen: ilk 3–5 rapor listesi.

### 5. PDKS günlük giriş-çıkış raporu
- **Neden:** Kullanıcı günlük işe giriş/çıkış raporu istedi.
- **Ne:** `X:\Yazilim\generic\pdks-rapor\pdks_gunluk.py` (kopya: `generic-scripts/pdks_gunluk.py`).
  WinRM + SqlClient (ApplicationIntent=ReadOnly, sadece SELECT) ile zkbiotime'dan çeker, openpyxl ile Excel
  (sayfa "Günlük": sicil, ad, departman, ilk giriş, son çıkış, süre, okutma, durum; sayfa "Özet": departman bazlı).
- **Veri modeli:** `iclock_transaction` (emp_code, punch_time, punch_state 0=giriş 1=çıkış, terminal Yuz1/Yuz2),
  `personnel_employee` (status=0 aktif, 359 kişi), `personnel_department`. BioTime'da vardiya tanımlı DEĞİL
  (timecard check_in 00:00) → eşikler parametre: `--gec 06:30 --erken 16:30` (dakika bazında).
- **Komut:** `python pdks_gunluk.py --tarih 2026-10-07`
- **Sonuç 2026-10-07:** 359 aktif, 329 geldi, 30 gelmedi, 19 geç, 16 eksik okutma.
- **Bulgu:** 2026-10-08'de 3 kayıt, 2026-10-09'da hiç kayıt yok — tatil mi, cihaz sorunu mu sorulacak.
  Cihazlar şu an online (Yuz1 192.168.0.30, Yuz2 192.168.0.29).
- Yerel git repo açıldı (`*.xlsx` ignore — kişisel veri). **Remote yok → push yapılamadı, kullanıcıya soruldu.**

### 6. Onay Merkezi'ne devir promptu
- **Neden:** Kullanıcı: Telegram'ı ayrı bot yerine mevcut Onay Merkezi (@modfex_bot) botuna dahil edelim.
- **Ne:** `pdks-rapor/ONAYMERKEZI_PROMPT.md` (kopya `generic-scripts/`): yapılanların özeti + /ai, /pdks entegrasyon
  görevi. Kritik not: bir token = tek long polling (409 Conflict) → ayrı bot süreci yok, onaymerkezi işleyicisine eklenecek.
  Port 8086 çakışma kontrolü notu (sunucuda 8085–8088 dinleniyor).
