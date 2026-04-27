@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
set "GUI_SCRIPT=%SCRIPT_DIR%scripts\windows\GitGlideGUI.ps1"

if not exist "%GUI_SCRIPT%" (
  echo Git Glide GUI script not found: %GUI_SCRIPT%
  exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%GUI_SCRIPT%" %*
set "EXIT_CODE=%ERRORLEVEL%"
endlocal & exit /b %EXIT_CODE%
