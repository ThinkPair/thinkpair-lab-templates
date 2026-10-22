$ErrorActionPreference = 'Stop'
trap {
  if ($env:BUSINESS_COCKPIT_HOOK_DEBUG -eq '1') {
    [Console]::Error.WriteLine(($_ | Out-String))
    exit 1
  }
  exit 0
}

$Utf8NoBom = New-Object Text.UTF8Encoding($false)
[Console]::InputEncoding = $Utf8NoBom
[Console]::OutputEncoding = $Utf8NoBom
$OutputEncoding = $Utf8NoBom

function Test-AuditedRelativePath {
  param([string]$RelativePath)
  if ($RelativePath -eq '20_经营数据/经营状态.md') { return $true }
  if ($RelativePath -match '^20_经营数据/当前项目/[^/]+\.md$') { return $true }
  if ($RelativePath -match '^20_经营数据/经营核算/AI结论/[^/]+\.md$') { return $true }
  if ($RelativePath -match '^20_经营数据/经营目标/行动计划/oap-[a-f0-9]{16}\.md$') { return $true }
  if ($RelativePath -match '^30_五维周复盘/历史周复盘/[^/]+\.md$') { return $true }
  if ($RelativePath -match '^40_能力商品化/验证记录/[^/]+\.md$') { return $true }
  return $false
}

function Get-FileSha256 {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    $stream = [IO.File]::OpenRead($Path)
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '').ToLowerInvariant() }
    finally { $stream.Dispose() }
  } finally { $sha.Dispose() }
}

$raw = [Console]::In.ReadToEnd().TrimStart([char]0xFEFF)
if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
$inputData = $raw | ConvertFrom-Json
$toolName = [string]$inputData.tool_name
if ($toolName -notin @('Edit', 'Write')) { exit 0 }

$cwd = [IO.Path]::GetFullPath([string]$inputData.cwd).TrimEnd('\', '/')
$rawPath = [string]$inputData.tool_input.file_path
if ([string]::IsNullOrWhiteSpace($rawPath)) { exit 0 }
$target = if ([IO.Path]::IsPathRooted($rawPath)) { [IO.Path]::GetFullPath($rawPath) } else { [IO.Path]::GetFullPath((Join-Path $cwd $rawPath)) }
$prefix = $cwd + [IO.Path]::DirectorySeparatorChar
if (-not $target.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { exit 0 }
$relative = $target.Substring($prefix.Length).Replace('\', '/')
if (-not (Test-AuditedRelativePath $relative)) { exit 0 }

$runtime = Join-Path $cwd '.claude\runtime'
[IO.Directory]::CreateDirectory($runtime) | Out-Null
$completedAt = [DateTime]::UtcNow.ToString('o', [Globalization.CultureInfo]::InvariantCulture)
$operation = $toolName.ToLowerInvariant()
$targetExists = Test-Path -LiteralPath $target -PathType Leaf
$targetSha256 = Get-FileSha256 $target
$row = [ordered]@{
  format = 'business-cockpit-write-audit.v1'
  completed_at = $completedAt
  operation = $operation
  target_relative = $relative
  target_exists = $targetExists
  target_sha256 = $targetSha256
}
$auditPath = Join-Path $runtime 'write-audit.jsonl'
$jsonLine = ($row | ConvertTo-Json -Depth 4 -Compress) + [Environment]::NewLine
[IO.File]::AppendAllText($auditPath, $jsonLine, $Utf8NoBom)

exit 0
