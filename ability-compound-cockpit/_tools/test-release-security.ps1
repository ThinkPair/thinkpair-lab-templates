param(
  [string]$PackageRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
$validator = Join-Path $PSScriptRoot 'validate-package.ps1'
. $validator -PackageRoot $PackageRoot -LibraryMode

$script:Passed = 0
function Assert-True {
  param(
    [Parameter(Mandatory = $true)][bool]$Condition,
    [Parameter(Mandatory = $true)][string]$Message
  )
  if (-not $Condition) { throw "Release security regression failed: $Message" }
  $script:Passed++
}

function New-TestZip {
  param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Destination
  )
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  if (Test-Path -LiteralPath $Destination) { Remove-Item -LiteralPath $Destination -Force }
  [IO.Compression.ZipFile]::CreateFromDirectory($Source, $Destination, [IO.Compression.CompressionLevel]::Optimal, $false)
}

$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar)
$testRoot = Join-Path $tempBase ('ability-release-security-' + [guid]::NewGuid().ToString('N'))
$safeRoot = Join-Path $testRoot 'safe'
$badRoot = Join-Path $testRoot 'bad'
$modeRoot = Join-Path $testRoot 'mode-check'
$safeZip = Join-Path $testRoot 'safe.zip'
$badZip = Join-Path $testRoot 'bad.zip'
$utf8 = New-Object System.Text.UTF8Encoding($false)

try {
  [IO.Directory]::CreateDirectory($safeRoot) | Out-Null
  [IO.Directory]::CreateDirectory($badRoot) | Out-Null
  [IO.Directory]::CreateDirectory($modeRoot) | Out-Null

  $placeholderInner = @{ apiKey = 'PASTE_YOUR_API_KEY'; authToken = '${AUTH_TOKEN}' } | ConvertTo-Json -Compress
  $placeholderDocument = @{
    provider = @{ environmentVariables = 'ANTHROPIC_AUTH_TOKEN=YOUR_TOKEN_HERE' }
    nested = $placeholderInner
  } | ConvertTo-Json -Depth 6 -Compress
  Assert-True -Condition ($null -eq (Get-ContentCredentialFinding -Content $placeholderDocument)) -Message 'standard placeholders should pass'

  $opaqueSecret = 'runtime-' + ('Q' * 36)
  $directDocument = @{ apiKey = $opaqueSecret } | ConvertTo-Json -Compress
  Assert-True -Condition ($null -ne (Get-ContentCredentialFinding -Content $directDocument)) -Message 'a non-placeholder JSON credential must fail'

  $nestedInner = @{ environmentVariables = ('ANTHROPIC_AUTH_TOKEN=' + $opaqueSecret) } | ConvertTo-Json -Compress
  $nestedDocument = @{ provider = @{ serializedConfig = $nestedInner } } | ConvertTo-Json -Depth 6 -Compress
  Assert-True -Condition ($null -ne (Get-ContentCredentialFinding -Content $nestedDocument)) -Message 'a credential nested in a JSON string must fail'

  $escapedDocument = $nestedDocument.Replace('"', '\"')
  Assert-True -Condition ($null -ne (Get-ContentCredentialFinding -Content $escapedDocument)) -Message 'a credential in escaped JSON must fail'

  [IO.File]::WriteAllText((Join-Path $safeRoot 'settings.json'), $placeholderDocument, $utf8)
  [IO.File]::WriteAllText((Join-Path $safeRoot 'README.md'), "# clean release`r`n", $utf8)
  New-TestZip -Source $safeRoot -Destination $safeZip
  Assert-True -Condition (@(Get-ReleaseZipFindings -ZipPath $safeZip).Count -eq 0) -Message 'a placeholder-only ZIP should pass'

  [IO.File]::WriteAllText((Join-Path $badRoot 'settings.json'), $escapedDocument, $utf8)
  $sessionDirectory = Join-Path $badRoot '.claudian\sessions'
  [IO.Directory]::CreateDirectory($sessionDirectory) | Out-Null
  [IO.File]::WriteAllText((Join-Path $sessionDirectory 'session.json'), '{}', $utf8)
  $batchDirectory = Join-Path $badRoot 'ability-write'
  [IO.Directory]::CreateDirectory($batchDirectory) | Out-Null
  $pendingBatch = @{ schema_version = 'ability-write.v1'; batch_status = 'pending'; operations = @() } | ConvertTo-Json -Compress
  [IO.File]::WriteAllText((Join-Path $batchDirectory 'pending.json'), $pendingBatch, $utf8)
  [IO.File]::WriteAllText((Join-Path $badRoot 'unfinished-record.md'), "---`r`nrecord_status: draft`r`n---`r`n", $utf8)
  $testDataDirectory = Join-Path $badRoot 'test-data'
  [IO.Directory]::CreateDirectory($testDataDirectory) | Out-Null
  [IO.File]::WriteAllText((Join-Path $testDataDirectory 'sample.json'), '{}', $utf8)
  New-TestZip -Source $badRoot -Destination $badZip
  $badFindings = @(Get-ReleaseZipFindings -ZipPath $badZip)
  Assert-True -Condition ($badFindings.Count -ge 5) -Message 'a ZIP with credentials, sessions, batches, drafts and test data must fail'

  [IO.File]::WriteAllText((Join-Path $modeRoot 'settings.json'), $nestedDocument, $utf8)
  $modeSessionDirectory = Join-Path $modeRoot 'sessions'
  [IO.Directory]::CreateDirectory($modeSessionDirectory) | Out-Null
  [IO.File]::WriteAllText((Join-Path $modeSessionDirectory 'runtime.json'), '{}', $utf8)
  $modeBatchDirectory = Join-Path $modeRoot 'ability-write'
  [IO.Directory]::CreateDirectory($modeBatchDirectory) | Out-Null
  [IO.File]::WriteAllText((Join-Path $modeBatchDirectory 'pending.json'), $pendingBatch, $utf8)
  $modeFiles = @(Get-ChildItem -LiteralPath $modeRoot -Recurse -Force -File)

  $script:Failures.Clear()
  $script:Warnings.Clear()
  Test-CredentialAndRuntimeCleanliness -Root $modeRoot -DeliverableFiles $modeFiles
  $normalExit = if ($script:Failures.Count -eq 0) { 0 } else { 1 }
  Assert-True -Condition ($normalExit -eq 0) -Message 'Normal mode must not block a valid runtime copy'
  Assert-True -Condition ($script:Warnings.Count -ge 3) -Message 'Normal mode must warn about credentials, sessions and pending batches'

  $script:Failures.Clear()
  $script:Warnings.Clear()
  Test-CredentialAndRuntimeCleanliness -Root $modeRoot -DeliverableFiles $modeFiles -AsRelease
  $releaseExit = if ($script:Failures.Count -eq 0) { 0 } else { 1 }
  Assert-True -Condition ($releaseExit -eq 1) -Message 'Release mode must reject runtime credentials and traces'
  Assert-True -Condition ($script:Failures.Count -ge 3) -Message 'Release mode must report credentials, sessions and pending batches'

  $missingWriterVault = Join-Path $testRoot 'writer-missing'
  $missingHooks = Join-Path $missingWriterVault '.claude\hooks'
  $missingQueue = Join-Path $missingWriterVault '.claude\write-queue'
  [IO.Directory]::CreateDirectory($missingHooks) | Out-Null
  [IO.Directory]::CreateDirectory($missingQueue) | Out-Null
  foreach ($name in @('ability-write-core.ps1', 'ability-write.ps1', 'test-ability-write.ps1')) {
    [IO.File]::WriteAllText((Join-Path $missingHooks $name), '', $utf8)
  }
  [IO.File]::WriteAllText((Join-Path $missingQueue 'README.md'), '', $utf8)
  $script:Failures.Clear()
  Test-AbilityWriterIntegrity -Vault $missingWriterVault
  Assert-True -Condition ($script:Failures.Count -eq 1) -Message 'any missing writer artifact must fail validation'

  $actualVault = @(Get-ChildItem -LiteralPath $PackageRoot -Force -Directory | Where-Object { $_.Name -like '2_*' } | Select-Object -First 1).FullName
  $actualWriterTest = Join-Path $actualVault '.claude\hooks\test-ability-write.ps1'
  $actualAssertionCount = @([regex]::Matches((Read-Utf8Text $actualWriterTest), '(?m)^\s*Assert-True\b')).Count
  Assert-True -Condition ($actualAssertionCount -ge 29) -Message 'writer regression must retain the 29-test security baseline'
  $script:Failures.Clear()
  Test-AbilityWriterIntegrity -Vault $actualVault -AsRelease
  Assert-True -Condition ($script:Failures.Count -eq 0) -Message 'Release writer regression must pass by process exit code'

  Write-Host "PASS  Release security regression passed ($script:Passed assertions)" -ForegroundColor Green
} finally {
  if (Test-Path -LiteralPath $testRoot) {
    $resolved = (Resolve-Path -LiteralPath $testRoot).Path
    $tempPrefix = $tempBase + [IO.Path]::DirectorySeparatorChar
    $isOwnedTestPath = $resolved.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)
    $hasOwnedName = (Split-Path -Leaf $resolved) -like 'ability-release-security-*'
    if ($isOwnedTestPath -and $hasOwnedName) {
      Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}
