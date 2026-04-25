@echo off
setlocal
set "ROOT=%~dp0..\.."
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\windows\run-pester-tests.ps1" %*
exit /b %errorlevel%
