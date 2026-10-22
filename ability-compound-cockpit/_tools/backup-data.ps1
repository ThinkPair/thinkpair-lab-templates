param(
  [Parameter(Mandatory = $true)]
  [string]$PackageRoot,

  [string]$VaultRelativePath = '2_个人能力复利空间_首次选择这个文件夹'
)

$ErrorActionPreference = 'Stop'
$package = (Resolve-Path -LiteralPath $PackageRoot).Path
$vaultCandidate = Join-Path $package $VaultRelativePath
if (-not (Test-Path -LiteralPath (Join-Path $vaultCandidate '.obsidian') -PathType Container)) {
  throw "无法确定个人能力复利空间：$VaultRelativePath"
}

$vaultRoot = (Resolve-Path -LiteralPath $vaultCandidate).Path
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupRoot = Join-Path $package (Join-Path '备份' $stamp)
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null

$relativeItems = @(
  '20_能力地图\主技能.md',
  '20_能力地图\能力维度',
  '30_刻意练习\练习记录',
  '40_证据与反馈\证据记录',
  '40_证据与反馈\反馈记录',
  '40_证据与反馈\附件',
  '50_能力复盘\复盘记录',
  '60_双工具交换\能力移交卡',
  '60_双工具交换\市场反馈',
  '80_AI能力教练\已确认写回记录.md',
  '90_现场草稿'
)

foreach ($relative in $relativeItems) {
  $source = Join-Path $vaultRoot $relative
  if (-not (Test-Path -LiteralPath $source)) { continue }
  $destination = Join-Path $backupRoot $relative
  New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
  Copy-Item -LiteralPath $source -Destination $destination -Recurse -Force
}

$manifest = @(Get-ChildItem -LiteralPath $backupRoot -Recurse -File | ForEach-Object {
  [pscustomobject]@{
    relative_path = $_.FullName.Substring($backupRoot.Length + 1)
    size_bytes = $_.Length
    sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
  }
})
if ($manifest.Count -eq 0) {
  $backupParent = [IO.Path]::GetFullPath((Join-Path $package '备份')).TrimEnd('\', '/')
  $backupToRemove = [IO.Path]::GetFullPath($backupRoot).TrimEnd('\', '/')
  if (-not $backupToRemove.StartsWith($backupParent + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw '空备份清理路径越界。'
  }
  Remove-Item -LiteralPath $backupRoot -Recurse -Force
  throw '未找到可备份的能力数据；空备份未保留。'
}

ConvertTo-Json -InputObject $manifest -Depth 3 | Set-Content -LiteralPath (Join-Path $backupRoot 'manifest.json') -Encoding utf8
Write-Host "能力数据备份完成：$backupRoot" -ForegroundColor Green
