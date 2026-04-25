@echo off
setlocal
set "ROOT=%~dp0..\.."
cd /d "%ROOT%"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\windows\package-release.ps1 %*
endlocal
