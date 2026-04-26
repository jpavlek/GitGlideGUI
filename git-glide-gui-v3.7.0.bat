@echo off
setlocal EnableExtensions
pushd "%~dp0"
powershell -STA -NoProfile -ExecutionPolicy Bypass -File "scripts\windows\GitGlideGUI-v3.7.0.ps1"
set "GGG_EXIT=%ERRORLEVEL%"
popd
exit /b %GGG_EXIT%
