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
if errorlevel 1 exit /b 1

set PYTHONNOUSERSITE=1

set "GITGLIDE_VERSION=0.0.0-dev"
if exist "%ROOT%\VERSION" (
    for /f "usebackq delims=" %%V in ("%ROOT%\VERSION") do (
        if not "%%V"=="" set "GITGLIDE_VERSION=%%V"
    )
)
echo === Git Glide GUI v%GITGLIDE_VERSION% quality checks ===

echo.
echo [1/6] Static package smoke test
python -S tests\static_smoke_test.py
if errorlevel 1 exit /b 1

echo.
echo [2/6] Windows smoke launch test
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\windows\smoke-launch.ps1
if errorlevel 1 exit /b 1

echo.
echo [3/6] Pester tests, if Pester is installed
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\windows\run-pester-tests.ps1
if errorlevel 1 exit /b 1

echo.
echo [4/6] ScriptAnalyzer checks, if PSScriptAnalyzer is installed
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\windows\run-scriptanalyzer.ps1
if errorlevel 1 exit /b 1

echo.
echo [5/6] Metrics collection and report refresh
call scripts\windows\collect-metrics.bat
if errorlevel 1 exit /b 1

echo.
echo [6/6] Release artifact consistency check
python -S tests\release_artifact_consistency_test.py
if errorlevel 1 exit /b 1

echo.
echo Quality checks completed.
endlocal & exit /b 0
