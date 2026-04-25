@echo off
setlocal
set "ROOT=%~dp0"
call "%ROOT%scripts\windows\run-pester-tests.bat" %*
exit /b %errorlevel%
