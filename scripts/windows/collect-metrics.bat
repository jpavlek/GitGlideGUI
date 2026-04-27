@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
set "ROOT=%SCRIPT_DIR%..\.."
cd /d "%ROOT%"

set PYTHONNOUSERSITE=1

echo === Git Glide GUI metrics collection ===
python -S scripts\metrics\collect_gitglide_metrics.py
if errorlevel 1 (
    echo Metrics collection failed.
    endlocal & exit /b 1
)

python -S scripts\metrics\generate_metrics_report.py
if errorlevel 1 (
    echo Metrics report generation failed.
    endlocal & exit /b 1
)

echo Metrics collection passed.
endlocal & exit /b 0
