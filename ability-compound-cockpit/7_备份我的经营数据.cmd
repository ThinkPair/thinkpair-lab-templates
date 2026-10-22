@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0_tools\backup-business-data.ps1" -SuiteRoot "%~dp0."
pause
endlocal
