New-Item -ItemType Directory -Force C:\llama\bin, C:\llama\models, C:\llama\logs, C:\llama\dl | Out-Null
curl.exe -sSL -o C:\llama\dl\llama-b11541-cpu.zip https://github.com/ggml-org/llama.cpp/releases/download/b11541/llama-b11541-bin-win-cpu-x64.zip
Expand-Archive C:\llama\dl\llama-b11541-cpu.zip C:\llama\bin -Force
& C:\llama\bin\llama-server.exe --version 2>&1 | Select-Object -First 3

# Model indirme: WinRM oturumundan bağımsız SYSTEM görevi
$base = 'https://huggingface.co/google/gemma-4-26B-A4B-it-qat-q4_0-gguf/resolve/main'
$bat = @"
curl.exe -sSL -C - -o C:\llama\models\gemma-4-26B_q4_0-it.gguf $base/gemma-4-26B_q4_0-it.gguf
curl.exe -sSL -C - -o C:\llama\models\gemma-4-26B-it-mmproj.gguf $base/gemma-4-26B-it-mmproj.gguf
echo DONE > C:\llama\logs\download.done
"@
Set-Content C:\llama\dl\download.cmd $bat -Encoding ASCII
$a = New-ScheduledTaskAction -Execute 'C:\llama\dl\download.cmd'
Register-ScheduledTask -TaskName 'llama-model-download' -Action $a -User SYSTEM -RunLevel Highest -Force | Out-Null
Start-ScheduledTask llama-model-download
"indirme basladi"
