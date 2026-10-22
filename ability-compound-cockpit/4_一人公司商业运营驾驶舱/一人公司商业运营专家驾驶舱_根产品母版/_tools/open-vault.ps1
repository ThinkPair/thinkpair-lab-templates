param(
  [Parameter(Mandatory = $true)]
  [string]$PackageRoot
)

$ErrorActionPreference = 'Stop'
$package = (Resolve-Path -LiteralPath $PackageRoot).Path
$vaults = @(Get-ChildItem -LiteralPath $package -Directory | Where-Object {
  Test-Path -LiteralPath (Join-Path $_.FullName '.obsidian')
})

if ($vaults.Count -ne 1) {
  throw "应当且只能找到一个 Obsidian 经营空间，实际找到 $($vaults.Count) 个。"
}

$vaultRoot = (Resolve-Path -LiteralPath $vaults[0].FullName).Path
$registryPath = Join-Path $env:APPDATA 'obsidian\obsidian.json'
$homeFile = '00_开始这里/首页.md'

function Get-ObsidianRegistry {
  if (-not (Test-Path -LiteralPath $registryPath)) { return $null }
  try {
    return Get-Content -LiteralPath $registryPath -Raw -Encoding utf8 | ConvertFrom-Json
  } catch {
    return $null
  }
}

function Normalize-Path([string]$Path) {
  if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
  try {
    return [IO.Path]::GetFullPath($Path).TrimEnd([char[]]@('\', '/'))
  } catch {
    return $null
  }
}

function Find-RegisteredVault {
  $registry = Get-ObsidianRegistry
  if ($null -eq $registry -or $null -eq $registry.vaults) { return $null }
  $target = Normalize-Path $vaultRoot
  foreach ($property in $registry.vaults.PSObject.Properties) {
    $candidate = Normalize-Path ([string]$property.Value.path)
    if ($candidate -and [string]::Equals($candidate, $target, [StringComparison]::OrdinalIgnoreCase)) {
      return [pscustomobject]@{ Id = $property.Name; Path = $candidate }
    }
  }
  return $null
}

function Open-RegisteredVault([string]$VaultId) {
  $uri = 'obsidian://open?vault=' + [uri]::EscapeDataString($VaultId) + '&file=' + [uri]::EscapeDataString($homeFile)
  Start-Process $uri
}

$registered = Find-RegisteredVault
if ($registered) {
  Open-RegisteredVault $registered.Id
  exit 0
}

Write-Host ''
Write-Host '首次使用需要让官方 Obsidian 认识这个经营空间。' -ForegroundColor Cyan
Write-Host '经营空间已在资源管理器中为你定位；请在 Obsidian 选择“打开文件夹作为仓库”。' -ForegroundColor White
Write-Host $vaultRoot -ForegroundColor Yellow

try {
  Start-Process -FilePath 'explorer.exe' -ArgumentList ('/select,"{0}"' -f $vaultRoot)
} catch {
  Write-Host '未能打开资源管理器，请按上方完整路径手动选择文件夹。' -ForegroundColor Yellow
}

$obsidianExe = Join-Path $env:LOCALAPPDATA 'Programs\Obsidian\Obsidian.exe'
$obsidianCli = Join-Path $env:LOCALAPPDATA 'Programs\Obsidian\Obsidian.com'
$registryBefore = Get-ObsidianRegistry

try {
  if (Test-Path -LiteralPath $obsidianExe) {
    Start-Process -FilePath $obsidianExe
  } else {
    Start-Process 'obsidian://open'
  }
} catch {
  Write-Host '未能调用 Obsidian。请先安装官方 Obsidian，再重新打开。' -ForegroundColor Yellow
  Start-Process 'https://obsidian.md/download'
  throw
}

$managerOpened = $false
if ((Test-Path -LiteralPath $obsidianCli) -and $registryBefore -and $registryBefore.cli -eq $true) {
  Start-Sleep -Milliseconds 800
  try {
    & $obsidianCli command 'id=app:open-vault' 2>$null | Out-Null
    $managerOpened = $LASTEXITCODE -eq 0
  } catch { }
}

Add-Type -AssemblyName System.Windows.Forms
$managerStep = if ($managerOpened) {
  '“管理仓库”窗口应该已经打开；点击“打开文件夹作为仓库”。'
} else {
  '在 Obsidian 左下角打开仓库菜单，进入“管理仓库”，再点击“打开文件夹作为仓库”。'
}
$message = @"
首次只需选择一次：

1. $managerStep
2. 选择资源管理器已经定位的文件夹：
$vaultRoot
3. 等经营空间打开后，回到本提示点击“确定”。

以后双击启动器会直接进入驾驶舱首页，不会误入父知识库。
"@
[void][System.Windows.Forms.MessageBox]::Show(
  $message,
  '首次连接一人公司经营空间',
  [System.Windows.Forms.MessageBoxButtons]::OK,
  [System.Windows.Forms.MessageBoxIcon]::Information
)

for ($attempt = 0; $attempt -lt 30; $attempt++) {
  $registered = Find-RegisteredVault
  if ($registered) { break }
  Start-Sleep -Milliseconds 500
}

if (-not $registered) {
  throw '尚未检测到该经营空间。请确认已在 Obsidian 中选择“打开文件夹作为仓库”，然后重新双击启动器。'
}

Open-RegisteredVault $registered.Id
exit 0
