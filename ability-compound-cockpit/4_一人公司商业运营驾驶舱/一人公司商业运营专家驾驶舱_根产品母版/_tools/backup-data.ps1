param(
  [Parameter(Mandatory = $true)]
  [string]$PackageRoot
)

$ErrorActionPreference = 'Stop'
$package = (Resolve-Path -LiteralPath $PackageRoot).Path
$vaults = @(Get-ChildItem -LiteralPath $package -Directory | Where-Object {
  Test-Path -LiteralPath (Join-Path $_.FullName '.obsidian')
})
if ($vaults.Count -ne 1) { throw "无法唯一确定经营空间。" }
$vaultRoot = $vaults[0].FullName
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupRoot = Join-Path $package (Join-Path '备份' $stamp)
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null

$relativeItems = @(
  '20_经营数据\当前项目',
  '20_经营数据\归档项目',
  '20_经营数据\经营状态.md',
  '20_经营数据\经营核算\产品收费方案',
  '20_经营数据\经营核算\实际核算',
  '20_经营数据\经营核算\创业预估',
  '20_经营数据\经营核算\AI结论',
  '20_经营数据\经营目标',
  '30_五维周复盘',
  '40_能力商品化',
  '60_AI商业运营专家\已确认写回记录.md'
)

foreach ($relative in $relativeItems) {
  $source = Join-Path $vaultRoot $relative
  if (-not (Test-Path -LiteralPath $source)) { continue }
  $destination = Join-Path $backupRoot $relative
  New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
  Copy-Item -LiteralPath $source -Destination $destination -Recurse -Force
}

$manifest = Get-ChildItem -LiteralPath $backupRoot -Recurse -File | ForEach-Object {
  [pscustomobject]@{
    relative_path = $_.FullName.Substring($backupRoot.Length + 1)
    size_bytes = $_.Length
    sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
  }
}
$manifest | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $backupRoot 'manifest.json') -Encoding utf8
Write-Host "备份完成：$backupRoot" -ForegroundColor Green
