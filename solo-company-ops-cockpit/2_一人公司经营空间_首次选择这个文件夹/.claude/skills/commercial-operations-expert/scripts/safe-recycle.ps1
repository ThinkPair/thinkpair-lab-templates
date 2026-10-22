param(
  [Parameter(Mandatory = $true)][ValidateSet('preview', 'recycle')][string]$Mode,
  [Parameter(Mandatory = $true)][string]$PathBase64
)

$ErrorActionPreference = 'Stop'
$Utf8NoBom = New-Object Text.UTF8Encoding($false)
[Console]::OutputEncoding = $Utf8NoBom
$OutputEncoding = $Utf8NoBom

function Decode-Base64Url([string]$Text) {
  if ($Text -notmatch '^[A-Za-z0-9_-]+$') { throw 'PathBase64 is invalid.' }
  $value = $Text.Replace('-', '+').Replace('_', '/')
  while (($value.Length % 4) -ne 0) { $value += '=' }
  return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($value))
}

$decoded = Decode-Base64Url $PathBase64
$target = [IO.Path]::GetFullPath($decoded)
if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { throw 'Only one existing file can be moved to the Recycle Bin.' }
if ($target -match '(?i)(^|[\\/])(?:\.ssh|\.aws|\.gnupg|Windows|Program Files|ProgramData)([\\/]|$)' -or
    [IO.Path]::GetFileName($target) -match '(?i)^(?:\.env|id_rsa|id_ed25519|credentials|claudian-settings\.json)$' -or
    [IO.Path]::GetExtension($target) -match '(?i)^\.(?:pem|key|pfx|p12)$') {
  throw 'Protected or credential-bearing files cannot be recycled by the AI workflow.'
}

$vaultRoot = [IO.Path]::GetFullPath((Get-Location).Path).TrimEnd('\', '/')
$prefix = $vaultRoot + [IO.Path]::DirectorySeparatorChar
if ($target.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
  $relative = $target.Substring($prefix.Length).Replace('\', '/')
  if ($relative -match '^(?:\.claude|\.claudian|\.obsidian|10_商业运营专家内核)(?:/|$)' -or $relative -in @('CLAUDE.md', 'AGENTS.md')) {
    throw 'Product safeguards and expert-kernel files cannot be recycled.'
  }
}

$normalizedTarget = $target.Replace('\', '/')

if ($Mode -eq 'preview') {
  @{ schema = 'recycle-preview.v2'; operation = 'recycle_file'; target = $normalizedTarget; summary = 'Move one selected file to the Windows Recycle Bin.'; recoverable = $true; confirmation = 'native' } |
    ConvertTo-Json -Depth 4
  exit 0
}

Add-Type -AssemblyName Microsoft.VisualBasic
[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
  $target,
  [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
  [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin
)
@{ ok = $true; recycled = $true; original_path = $normalizedTarget; restore_from = 'Windows Recycle Bin' } |
  ConvertTo-Json -Depth 4
