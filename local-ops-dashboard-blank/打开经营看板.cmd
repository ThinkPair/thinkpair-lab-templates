@echo off
setlocal
cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0runtime\validate-and-sync.ps1"
if errorlevel 1 (
  echo.
  echo [DATA NOT UPDATED] Fix the JSON block in the 01_*.md data note.
  echo The previous valid dashboard data is still preserved.
  pause
  exit /b 1
)

where node >nul 2>nul
if errorlevel 1 goto POWERSHELL_MODE

for /f "usebackq delims=" %%H in (`powershell -NoProfile -Command "try { $r=Invoke-RestMethod -UseBasicParsing -TimeoutSec 1 'http://127.0.0.1:4173/__dashboard_health'; if($r.app -eq 'noise-lab-local-dashboard'){'READY'} } catch {}"`) do set "HEALTH=%%H"
if /i "%HEALTH%"=="READY" (
  start "" "http://127.0.0.1:4173/"
  exit /b 0
)

for /f %%P in ('powershell -NoProfile -Command "$port=4173; while($port -le 4182 -and (Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue)){ $port++ }; if($port -le 4182){$port}"') do set "DASHBOARD_PORT=%%P"
if not defined DASHBOARD_PORT goto STATIC_MODE

powershell -NoProfile -WindowStyle Hidden -Command "Start-Process -FilePath 'node.exe' -ArgumentList @('runtime/server.mjs','%DASHBOARD_PORT%') -WorkingDirectory '%~dp0' -WindowStyle Hidden"
timeout /t 2 /nobreak >nul
start "" "http://127.0.0.1:%DASHBOARD_PORT%/"
exit /b 0

:POWERSHELL_MODE
if not defined DASHBOARD_PORT (
  for /f %%P in ('powershell -NoProfile -Command "$port=4173; while($port -le 4182 -and (Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue)){ $port++ }; if($port -le 4182){$port}"') do set "DASHBOARD_PORT=%%P"
)
if not defined DASHBOARD_PORT goto STATIC_MODE
powershell -NoProfile -WindowStyle Hidden -Command "Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File','runtime/server.ps1','-Port','%DASHBOARD_PORT%') -WorkingDirectory '%~dp0' -WindowStyle Hidden"
timeout /t 2 /nobreak >nul
start "" "http://127.0.0.1:%DASHBOARD_PORT%/"
exit /b 0

:STATIC_MODE
echo No free local port was found between 4173 and 4182.
pause
exit /b 0
