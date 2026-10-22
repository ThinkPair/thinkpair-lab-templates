@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0_tools\open-business-vault.ps1" -SuiteRoot "%~dp0."
pause
endlocal
