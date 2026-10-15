@echo off
rem Anlık ağ panosunu derler ve başlatır (yönetici onayı ister); pano tarayıcıda http://localhost:8765 adresinde açılır.
dotnet build "%~dp0canli\AgCanli.csproj" -c Release -o "%~dp0canli\bin\yayin" -v q -nologo || (echo Derleme basarisiz & pause & exit /b 1)
start "" "%~dp0canli\bin\yayin\AgCanli.exe"
