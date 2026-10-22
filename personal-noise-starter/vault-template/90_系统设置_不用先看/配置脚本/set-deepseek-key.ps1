param(
  [string]$PackageRoot,
  [string]$ApiKey
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($PackageRoot)) {
  $PackageRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..')).Path
}

$PackageRoot = (Resolve-Path -LiteralPath $PackageRoot).Path
$vaultDir = Get-ChildItem -LiteralPath $PackageRoot -Directory |
  Where-Object { $_.Name -like '2_*' } |
  Select-Object -First 1

if (-not $vaultDir) {
  throw 'Vault folder starting with 2_ was not found.'
}

$settingsPath = Join-Path $vaultDir.FullName '.claudian\claudian-settings.json'

if (-not (Test-Path -LiteralPath $settingsPath)) {
  throw "AI assistant settings file was not found: $settingsPath"
}

if ([string]::IsNullOrWhiteSpace($ApiKey)) {
  Write-Host ''
  Write-Host 'Paste your DeepSeek API Key. The input will be hidden.'
  $secureKey = Read-Host 'DeepSeek API Key' -AsSecureString
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
  try {
    $key = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
  }
  finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  }
}
else {
  $key = $ApiKey
}

if ([string]::IsNullOrWhiteSpace($key)) {
  throw 'API Key cannot be empty.'
}

$json = Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
$claude = $json.providerConfigs.claude
$existingLines = @()
if ($claude.environmentVariables) {
  $existingLines = $claude.environmentVariables -split "`r?`n" | Where-Object { $_ -ne '' }
}

$envMap = [ordered]@{}
foreach ($line in $existingLines) {
  $idx = $line.IndexOf('=')
  if ($idx -gt 0) {
    $envMap[$line.Substring(0, $idx)] = $line.Substring($idx + 1)
  }
}

$envMap['ANTHROPIC_BASE_URL'] = 'https://api.deepseek.com/anthropic'
$envMap['ANTHROPIC_AUTH_TOKEN'] = $key
$envMap['ANTHROPIC_API_KEY'] = $key
$envMap['ANTHROPIC_MODEL'] = 'deepseek-v4-flash'
$envMap['ANTHROPIC_DEFAULT_OPUS_MODEL'] = 'deepseek-v4-pro[1m]'
$envMap['ANTHROPIC_DEFAULT_SONNET_MODEL'] = 'deepseek-v4-pro[1m]'
$envMap['ANTHROPIC_DEFAULT_HAIKU_MODEL'] = 'deepseek-v4-flash'
$envMap['CLAUDE_CODE_SUBAGENT_MODEL'] = 'deepseek-v4-flash'
$envMap['CLAUDE_CODE_EFFORT_LEVEL'] = 'max'
$envMap['PATH'] = '.;..\_NoiseLab_Internal\claude-code\node_modules\@anthropic-ai\claude-code\bin;C:\Program Files\Git\cmd;C:\Windows\System32;C:\Windows;C:\Windows\System32\WindowsPowerShell\v1.0'

$order = @(
  'ANTHROPIC_BASE_URL',
  'ANTHROPIC_AUTH_TOKEN',
  'ANTHROPIC_API_KEY',
  'ANTHROPIC_MODEL',
  'ANTHROPIC_DEFAULT_OPUS_MODEL',
  'ANTHROPIC_DEFAULT_SONNET_MODEL',
  'ANTHROPIC_DEFAULT_HAIKU_MODEL',
  'CLAUDE_CODE_SUBAGENT_MODEL',
  'CLAUDE_CODE_EFFORT_LEVEL',
  'PATH'
)

$claude.environmentVariables = (($order | ForEach-Object { "$_=$($envMap[$_])" }) -join "`n")
$claude.environmentHash = 'ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic|ANTHROPIC_DEFAULT_HAIKU_MODEL=deepseek-v4-flash|ANTHROPIC_DEFAULT_OPUS_MODEL=deepseek-v4-pro[1m]|ANTHROPIC_DEFAULT_SONNET_MODEL=deepseek-v4-pro[1m]|ANTHROPIC_MODEL=deepseek-v4-flash'
$json.providerConfigs.claude = $claude

$json | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath $settingsPath -Encoding UTF8

Write-Host ''
Write-Host 'Done. You can now open 1_Open Noise Lab / 1_*.exe.'
