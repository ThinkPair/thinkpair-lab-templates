@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0_tools\build-release.ps1" -PackageRoot "%~dp0." -Force
pause
endlocal
