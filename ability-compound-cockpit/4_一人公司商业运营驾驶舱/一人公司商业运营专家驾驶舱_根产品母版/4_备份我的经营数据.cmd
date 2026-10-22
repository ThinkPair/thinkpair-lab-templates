@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0_tools\backup-data.ps1" -PackageRoot "%~dp0."
if errorlevel 1 pause
endlocal
