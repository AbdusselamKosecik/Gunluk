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
