param(
  [Parameter(Mandatory = $true)]
  [string]$PackageRoot,
  [string]$OutputDirectory,
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Get-NormalizedPath {
  param([string]$Path)
  return [IO.Path]::GetFullPath($Path).TrimEnd('\')
}

function Get-RelativePath {
  param([string]$Root, [string]$Path)
  $prefix = (Get-NormalizedPath $Root) + '\'
  $full = Get-NormalizedPath $Path
  if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw "路径越界：$full" }
  return $full.Substring($prefix.Length)
}

function Test-IsDeliverable {
  param([string]$Relative)
  $allowedRootFiles = @(
    '1_打开个人能力复利驾驶舱.cmd', '3_检查能力驾驶舱.cmd', '4_备份我的能力数据.cmd',
    '2_打开一人公司商业运营驾驶舱.cmd', '6_检查商业驾驶舱.cmd', '7_备份我的经营数据.cmd',
    '0_先看我_双驾驶舱三步开始.txt', 'AGENTS.md', 'README.md', 'ROOT_PRODUCT.md', '版本信息与校验.txt'
  )
  $allowedTools = @(
    '_tools\open-vault.ps1', '_tools\backup-data.ps1', '_tools\validate-package.ps1',
    '_tools\exchange-card.ps1', '_tools\ExchangeContract.psm1',
    '_tools\open-business-vault.ps1', '_tools\validate-business-package.ps1', '_tools\backup-business-data.ps1'
  )
  $top = $Relative.Split('\')[0]
  return ($top -in @('2_个人能力复利空间_首次选择这个文件夹', '3_受控交换箱', 'LICENSES')) -or
    ($Relative -in $allowedRootFiles) -or ($Relative -in $allowedTools) -or
    (Test-IsSafeEmbeddedBusinessRelative -Relative $Relative)
}

function Test-IsSafeEmbeddedBusinessRelative {
  param([string]$Relative)
  $prefix = '4_一人公司商业运营驾驶舱\一人公司商业运营专家驾驶舱_根产品母版\'
  if (-not $Relative.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { return $false }
  $nested = $Relative.Substring($prefix.Length)
  if ($nested -match '(^|\\)(备份|\.trash|node_modules|dist|_prototype|tmp|temp|测试输出|发布包)(\\|$)') { return $false }
  if ($nested -match '(^|\\)\.claudian\\' -and $nested -notmatch '\.claudian\\claudian-settings\.json$') { return $false }
  if ($nested -match '(^|\\)(\.env(?:\..*)?|credentials?\.[^\\]+|secrets?\.[^\\]+|[^\\]*(session|conversation|chat-history)[^\\]*\.json)$') { return $false }
  if ([IO.Path]::GetExtension($nested) -in @('.zip', '.tmp', '.bak', '.log')) { return $false }
  return $true
}

function Invoke-BusinessReleaseValidation {
  param([string]$SuiteRoot)
  $business = Join-Path $SuiteRoot '4_一人公司商业运营驾驶舱\一人公司商业运营专家驾驶舱_根产品母版'
  $validator = Join-Path $business '_tools\validate-package.ps1'
  if (-not (Test-Path -LiteralPath $validator -PathType Leaf)) { throw '套件缺少商业驾驶舱 ReleaseMode 校验器。' }
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $validator -PackageRoot $business -ReleaseMode
  if ($LASTEXITCODE -ne 0) { throw '商业驾驶舱 ReleaseMode 校验失败，已拒绝打包。' }
}

$package = Get-NormalizedPath $PackageRoot
if (-not (Test-Path -LiteralPath $package -PathType Container)) { throw "产品根目录不存在：$package" }
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) { $OutputDirectory = Join-Path (Split-Path -Parent $package) '发布包' }
$outputRoot = Get-NormalizedPath $OutputDirectory
[IO.Directory]::CreateDirectory($outputRoot) | Out-Null

$validator = Join-Path $package '_tools\validate-package.ps1'
Write-Host '1/8 运行个人能力空间与套件边界校验……' -ForegroundColor Cyan
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $validator -PackageRoot $package -ReleaseMode -SkipBusinessValidation
if ($LASTEXITCODE -ne 0) { throw '根产品不是可发布的永久空白母版，已拒绝打包。' }

Write-Host '2/8 运行嵌套商业驾驶舱 ReleaseMode 校验……' -ForegroundColor Cyan
Invoke-BusinessReleaseValidation -SuiteRoot $package

Write-Host '3/8 运行 50 条练习 / 20 条证据压力测试……' -ForegroundColor Cyan
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $package '_tools\test-data-model.ps1') -PackageRoot $package
if ($LASTEXITCODE -ne 0) { throw '数据模型压力测试失败，已拒绝打包。' }

Write-Host '4/8 运行发布凭证与运行痕迹回归测试……' -ForegroundColor Cyan
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $package '_tools\test-release-security.ps1') -PackageRoot $package
if ($LASTEXITCODE -ne 0) { throw '发布安全回归测试失败，已拒绝打包。' }

$rootManifest = [IO.File]::ReadAllText((Join-Path $package 'ROOT_PRODUCT.md'), $utf8NoBom)
$versionMatch = [regex]::Match($rootManifest, '(?m)^version:\s*([^\r\n]+)$')
if (-not $versionMatch.Success) { throw 'ROOT_PRODUCT.md 缺少 version。' }
$version = $versionMatch.Groups[1].Value.Trim(' ', '"', "'")
$releaseName = "降噪实验室｜双驾驶舱套件_${version}_Windows"
$zipPath = Join-Path $outputRoot ($releaseName + '.zip')
$hashPath = $zipPath + '.sha256.txt'
if ($version -eq 'v0.1.0' -and ((Test-Path -LiteralPath $zipPath) -or (Test-Path -LiteralPath $hashPath))) {
  throw '历史 v0.1.0 发布物受保护，不能覆盖或删除。请先提升版本号再生成新包。'
}
if ((Test-Path -LiteralPath $zipPath) -and -not $Force) { throw "发布包已存在：$zipPath。需要覆盖时加 -Force。" }

$tempBase = Get-NormalizedPath ([IO.Path]::GetTempPath())
$stagingRoot = Join-Path $tempBase ('ability-release-' + [guid]::NewGuid().ToString('N'))
$stagedPackage = Join-Path $stagingRoot $releaseName
$candidateZipPath = Join-Path $tempBase ('ability-release-candidate-' + [guid]::NewGuid().ToString('N') + '.zip')

try {
  Write-Host '5/8 复制双驾驶舱发布白名单文件……' -ForegroundColor Cyan
  [IO.Directory]::CreateDirectory($stagedPackage) | Out-Null
  $files = @(Get-ChildItem -LiteralPath $package -Recurse -Force -File | Where-Object {
    $relative = Get-RelativePath -Root $package -Path $_.FullName
    Test-IsDeliverable $relative
  })
  foreach ($file in $files) {
    $relative = Get-RelativePath -Root $package -Path $file.FullName
    $destination = Join-Path $stagedPackage $relative
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination)) | Out-Null
    [IO.File]::Copy($file.FullName, $destination, $true)
  }

  $manifestLines = New-Object System.Collections.Generic.List[string]
  $manifestLines.Add("# $releaseName")
  $manifestLines.Add('# SHA-256｜UTF-8 路径｜不含本清单自身')
  foreach ($file in @(Get-ChildItem -LiteralPath $stagedPackage -Recurse -Force -File | Sort-Object FullName)) {
    $relative = Get-RelativePath -Root $stagedPackage -Path $file.FullName
    $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    $manifestLines.Add("$hash  $($relative.Replace('\', '/'))")
  }
  [IO.File]::WriteAllLines((Join-Path $stagedPackage '发布文件清单_SHA256.txt'), $manifestLines, $utf8NoBom)

  Write-Host '6/8 复检净包个人能力空间与套件边界……' -ForegroundColor Cyan
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $stagedPackage '_tools\validate-package.ps1') -PackageRoot $stagedPackage -ReleaseMode -SkipExchangeTests -SkipBusinessValidation
  if ($LASTEXITCODE -ne 0) { throw '白名单净包复检失败，未生成 ZIP。' }

  Write-Host '7/8 复检净包商业驾驶舱……' -ForegroundColor Cyan
  Invoke-BusinessReleaseValidation -SuiteRoot $stagedPackage

  Write-Host '8/8 生成候选 ZIP、逐条目复检并发布……' -ForegroundColor Cyan
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  [IO.Compression.ZipFile]::CreateFromDirectory($stagingRoot, $candidateZipPath, [IO.Compression.CompressionLevel]::Optimal, $false)
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $stagedPackage '_tools\validate-package.ps1') -PackageRoot $stagedPackage -ReleaseMode -ReleaseZipPath $candidateZipPath -ZipOnly
  if ($LASTEXITCODE -ne 0) { throw '发布 ZIP 成品复检失败，不合格候选包已清理。' }

  if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
  if (Test-Path -LiteralPath $hashPath) { Remove-Item -LiteralPath $hashPath -Force }
  Move-Item -LiteralPath $candidateZipPath -Destination $zipPath
  $zipHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
  [IO.File]::WriteAllText($hashPath, "$zipHash  $([IO.Path]::GetFileName($zipPath))`r`n", $utf8NoBom)

  Write-Host '双驾驶舱套件发布包完成。' -ForegroundColor Green
  Write-Host "ZIP：$zipPath"
  Write-Host "SHA-256：$zipHash"
} finally {
  if (Test-Path -LiteralPath $stagingRoot) {
    $resolved = (Resolve-Path -LiteralPath $stagingRoot).Path
    $tempPrefix = $tempBase + '\'
    if ($resolved.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -and (Split-Path -Leaf $resolved) -like 'ability-release-*') {
      Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
  if (Test-Path -LiteralPath $candidateZipPath) {
    $candidateResolved = (Resolve-Path -LiteralPath $candidateZipPath).Path
    $candidatePrefix = $tempBase + '\'
    if ($candidateResolved.StartsWith($candidatePrefix, [StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path -Leaf $candidateResolved) -like 'ability-release-candidate-*.zip') {
      Remove-Item -LiteralPath $candidateResolved -Force -ErrorAction SilentlyContinue
    }
  }
}
