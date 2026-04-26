@echo off
rem Optional tool bootstrap. This is non-invasive by default.
rem Set GITGLIDE_AUTO_INSTALL_TOOLS=1 to install missing optional tools for CurrentUser.
if /I not "%GITGLIDE_SKIP_TOOL_BOOTSTRAP%"=="1" (
    if exist "%~dp0ensure-psscriptanalyzer.ps1" (
        powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ensure-psscriptanalyzer.ps1"
        if errorlevel 1 exit /b %errorlevel%
    )
)
setlocal
set "ROOT=%~dp0..\.."
cd /d "%ROOT%"

echo === Git Glide GUI v3.6.11 quality checks ===

echo.
echo [1/4] Static package smoke test
python tests\static_smoke_test.py
if errorlevel 1 exit /b 1

echo.
echo [2/4] Windows smoke launch test
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\windows\smoke-launch.ps1
if errorlevel 1 exit /b 1

echo.
echo [3/4] Pester tests, if Pester is installed
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\windows\run-pester-tests.ps1
if errorlevel 1 exit /b 1

echo.
echo [4/4] ScriptAnalyzer checks, if PSScriptAnalyzer is installed
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\windows\run-scriptanalyzer.ps1
if errorlevel 1 exit /b 1

echo.
echo Quality checks completed.
endlocal
