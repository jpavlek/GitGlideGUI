@echo off
rem Backward-compatible launcher for users/scripts that still call GitFlowGUI.
setlocal
set "SCRIPT_DIR=%~dp0"
call "%SCRIPT_DIR%git-glide-gui.bat" %*
endlocal
