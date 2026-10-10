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
