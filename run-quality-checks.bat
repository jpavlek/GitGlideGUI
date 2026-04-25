@echo off
setlocal
set "ROOT=%~dp0"
call "%ROOT%scripts\windows\run-quality-checks.bat" %*
exit /b %errorlevel%
