@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0_tools\validate-business-package.ps1" -SuiteRoot "%~dp0."
pause
endlocal
