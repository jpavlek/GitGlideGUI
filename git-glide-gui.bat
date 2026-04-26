@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
set "GUI_SCRIPT=%SCRIPT_DIR%scripts\windows\GitGlideGUI-v3.8.0.ps1"

if not exist "%GUI_SCRIPT%" (
  echo Git Glide GUI script not found: %GUI_SCRIPT%
  exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%GUI_SCRIPT%" %*
endlocal
