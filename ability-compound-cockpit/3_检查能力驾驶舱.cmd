@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0_tools\validate-package.ps1" -PackageRoot "%~dp0."
pause
endlocal
