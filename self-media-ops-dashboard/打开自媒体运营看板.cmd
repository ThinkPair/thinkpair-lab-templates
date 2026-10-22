@echo off
setlocal
cd /d "%~dp0"

where node >nul 2>nul
if errorlevel 1 (
  echo [错误] 未检测到 Node.js，暂时无法启动看板。
  pause
  exit /b 1
)

if not exist "node_modules" (
  echo 首次运行，正在安装本地依赖...
  call npm install --prefer-offline --no-audit --no-fund
  if errorlevel 1 (
    echo [错误] 依赖安装失败。
    pause
    exit /b 1
  )
)

powershell -NoProfile -WindowStyle Hidden -Command "$listener=Get-NetTCPConnection -LocalPort 4173 -State Listen -ErrorAction SilentlyContinue; if(-not $listener){Start-Process -FilePath 'npm.cmd' -ArgumentList @('run','dev','--','--host','127.0.0.1','--port','4173','--strictPort') -WorkingDirectory '%~dp0' -WindowStyle Hidden}"
timeout /t 2 /nobreak >nul
start "" "http://localhost:4173/"
endlocal
