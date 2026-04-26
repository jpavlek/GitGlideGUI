@echo off
rem Backward-compatible launcher for users/scripts that still call GitFlowGUI.
setlocal

set "ROOT=%~dp0"
set "LAUNCHER=%ROOT%git-glide-gui.bat"

if not exist "%LAUNCHER%" (
    echo ERROR: Expected launcher not found:
    echo   %LAUNCHER%
    endlocal
    exit /b 1
)

call "%LAUNCHER%" %*
set "EXIT_CODE=%ERRORLEVEL%"

endlocal & exit /b %EXIT_CODE%
