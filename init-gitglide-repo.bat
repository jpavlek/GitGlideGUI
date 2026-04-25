@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\windows\init-gitglide-repo.ps1" %*
exit /b %ERRORLEVEL%
