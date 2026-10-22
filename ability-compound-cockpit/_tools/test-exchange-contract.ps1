$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$modulePath = Join-Path $PSScriptRoot 'ExchangeContract.psm1'
$fixtureRoot = Join-Path $PSScriptRoot 'fixtures\exchange'
$capabilityFixture = Join-Path $fixtureRoot 'valid-capability-transfer.md'
$feedbackFixture = Join-Path $fixtureRoot 'valid-market-feedback.md'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
Import-Module $modulePath -Force

$script:passed = 0
$script:failed = 0

function Pass-Test {
  param([Parameter(Mandatory = $true)][string]$Name)
  $script:passed++
  Write-Host "PASS  $Name" -ForegroundColor Green
}

function Fail-Test {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Message
  )
  $script:failed++
  Write-Host "FAIL  $Name -- $Message" -ForegroundColor Red
}

function Assert-True {
  param(
    [Parameter(Mandatory = $true)][bool]$Condition,
    [Parameter(Mandatory = $true)][string]$Name,
    [string]$Message = 'Condition was false.'
  )
  if ($Condition) { Pass-Test $Name } else { Fail-Test $Name $Message }
}

function Assert-ErrorCode {
  param(
    [Parameter(Mandatory = $true)][scriptblock]$Action,
    [Parameter(Mandatory = $true)][string]$ExpectedCode,
    [Parameter(Mandatory = $true)][string]$Name
  )
  try {
    & $Action | Out-Null
    Fail-Test $Name "Expected $ExpectedCode but operation succeeded."
  } catch {
    $actual = Get-ExchangeErrorCode -Exception $_.Exception
    if ($actual -eq $ExpectedCode) { Pass-Test $Name }
    else { Fail-Test $Name "Expected $ExpectedCode but received ${actual}: $($_.Exception.Message)" }
  }
}

function New-Directory {
  param([Parameter(Mandatory = $true)][string]$Path)
  [IO.Directory]::CreateDirectory($Path) | Out-Null
}

function Write-TestFile {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Content
  )
  New-Directory ([IO.Path]::GetDirectoryName($Path))
  [IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Get-TextHash {
  param([Parameter(Mandatory = $true)][string]$Text)
  $sha = [Security.Cryptography.SHA256]::Create()
  try { return (($sha.ComputeHash($utf8NoBom.GetBytes($Text)) | ForEach-Object { $_.ToString('x2') }) -join '') }
  finally { $sha.Dispose() }
}

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('noise-lab-exchange-tests-' + [guid]::NewGuid().ToString('N'))
try {
  New-Directory $tempRoot
  $exchangeRoot = Join-Path $tempRoot '3_受控交换箱'
  $capabilityInbox = Join-Path $exchangeRoot 'capability_to_business'
  $feedbackInbox = Join-Path $exchangeRoot 'market_feedback_to_personal'
  $businessVault = Join-Path $tempRoot '商业 空间'
  $personalVault = Join-Path $tempRoot '个人 能力空间'
  New-Directory $capabilityInbox
  New-Directory $feedbackInbox
  New-Directory (Join-Path $businessVault '40_能力商品化\验证记录')
  New-Directory (Join-Path $personalVault '60_双工具交换\能力移交卡')
  New-Directory (Join-Path $personalVault '60_双工具交换\市场反馈')

  $capabilityCard = Join-Path $capabilityInbox 'capability_transfer--ct-fixture.md'
  $feedbackCard = Join-Path $feedbackInbox 'market_feedback--mf-fixture.md'
  [IO.File]::Copy($capabilityFixture, $capabilityCard)
  [IO.File]::Copy($feedbackFixture, $feedbackCard)
  [IO.File]::Copy($capabilityFixture, (Join-Path $personalVault '60_双工具交换\能力移交卡\ct-550e8400-e29b-41d4-a716-446655440000.md'))

  $validCapability = Test-ExchangeCard -Path $capabilityFixture -ExpectedKind CapabilityTransfer
  Assert-True ($validCapability.content_hash -eq 'd8910f389b237ef152a8c07f4515920cf7f87e2d196030754f119d40e06792fe') 'valid capability fixture'
  $validFeedback = Test-ExchangeCard -Path $feedbackFixture -ExpectedKind MarketFeedback
  Assert-True ($validFeedback.content_hash -eq '5e1c7197aaaea4d78e531cb51568d98e6ae4d95f37b9fa3a40fbcae8b78ac527') 'valid feedback fixture'

  $tamperedPath = Join-Path $tempRoot 'tampered-capability.md'
  $tampered = [IO.File]::ReadAllText($capabilityFixture, $utf8NoBom).Replace('目标风味', '目标味型')
  Write-TestFile $tamperedPath $tampered
  Assert-ErrorCode { Test-ExchangeCard -Path $tamperedPath -ExpectedKind CapabilityTransfer } 'E_HASH' 'tampered payload is rejected'

  $oldSchemaPath = Join-Path $tempRoot 'old-schema-capability.md'
  $oldSchema = [IO.File]::ReadAllText($capabilityFixture, $utf8NoBom).Replace('exchange.capability_transfer.v1', 'exchange.capability_transfer.v0')
  Write-TestFile $oldSchemaPath $oldSchema
  Assert-ErrorCode { Test-ExchangeCard -Path $oldSchemaPath -ExpectedKind CapabilityTransfer } 'E_SCHEMA_UNSUPPORTED' 'old schema is rejected'

  $missingFieldPath = Join-Path $tempRoot 'missing-field-capability.md'
  $missing = [regex]::Replace([IO.File]::ReadAllText($capabilityFixture, $utf8NoBom), '(?m)^capability_version:.*\r?\n', '', 1)
  Write-TestFile $missingFieldPath $missing
  Assert-ErrorCode { Test-ExchangeCard -Path $missingFieldPath -ExpectedKind CapabilityTransfer } 'E_FIELD_SET' 'missing field is rejected'

  $previewAt = '2026-07-12T21:00:00+08:00'
  $capabilityPreview = New-ExchangeImportPreview -Kind CapabilityTransfer -CardPath $capabilityCard -VaultRoot $businessVault -ExchangeRoot $exchangeRoot -PreviewAt $previewAt
  Assert-True ($capabilityPreview.target_content -match '(?m)^validation_status: planned$') 'capability import remains planned'
  Assert-True ($capabilityPreview.target_content -match '(?m)^fact_gate_confirmed: false$') 'capability import keeps fact gate false'
  Assert-True (-not ($capabilityPreview.target_content -match '(?m)^(客户|项目|报价|回款):')) 'capability import creates no project or money fields'
  Assert-True ($capabilityPreview.target_content -match '(?m)^价格假设: ""$') 'capability import keeps price hypothesis empty'

  $capabilityImport = Import-ExchangeCard -Kind CapabilityTransfer -CardPath $capabilityCard -VaultRoot $businessVault -ExchangeRoot $exchangeRoot -ExpectedHash $capabilityPreview.source_hash -PreviewAt $capabilityPreview.preview_at -PreviewToken $capabilityPreview.preview_token
  $mappedCapabilityPath = Join-Path $businessVault ($capabilityImport.target_relative_path.Replace('/', '\'))
  Assert-True (Test-Path -LiteralPath $mappedCapabilityPath -PathType Leaf) 'capability import writes deterministic target'
  $mappedCapability = [IO.File]::ReadAllText($mappedCapabilityPath, $utf8NoBom)
  Assert-True ($mappedCapability -match '(?m)^source_transfer_hash: "d8910f389b237ef152a8c07f4515920cf7f87e2d196030754f119d40e06792fe"$') 'capability import preserves source hash'
  Assert-ErrorCode { New-ExchangeImportPreview -Kind CapabilityTransfer -CardPath $capabilityCard -VaultRoot $businessVault -ExchangeRoot $exchangeRoot -PreviewAt $previewAt } 'E_DUPLICATE' 'duplicate capability import is rejected'

  $conflicted = $mappedCapability.Replace('source_transfer_hash: "d8910f389b237ef152a8c07f4515920cf7f87e2d196030754f119d40e06792fe"', 'source_transfer_hash: "0000000000000000000000000000000000000000000000000000000000000000"')
  [IO.File]::WriteAllText($mappedCapabilityPath, $conflicted, $utf8NoBom)
  Assert-ErrorCode { New-ExchangeImportPreview -Kind CapabilityTransfer -CardPath $capabilityCard -VaultRoot $businessVault -ExchangeRoot $exchangeRoot -PreviewAt $previewAt } 'E_ID_CONFLICT' 'same transfer ID with another hash is rejected'

  $businessVault2 = Join-Path $tempRoot '商业空间-stale'
  New-Directory (Join-Path $businessVault2 '40_能力商品化\验证记录')
  $stalePreview = New-ExchangeImportPreview -Kind CapabilityTransfer -CardPath $capabilityCard -VaultRoot $businessVault2 -ExchangeRoot $exchangeRoot -PreviewAt $previewAt
  Assert-ErrorCode {
    Import-ExchangeCard -Kind CapabilityTransfer -CardPath $capabilityCard -VaultRoot $businessVault2 -ExchangeRoot $exchangeRoot -ExpectedHash ('0' * 64) -PreviewAt $stalePreview.preview_at -PreviewToken $stalePreview.preview_token
  } 'E_PREVIEW_STALE' 'stale capability preview is rejected'

  $feedbackPreviewAt = '2026-07-12T21:10:00+08:00'
  $feedbackPreview = New-ExchangeImportPreview -Kind MarketFeedback -CardPath $feedbackCard -VaultRoot $personalVault -ExchangeRoot $exchangeRoot -PreviewAt $feedbackPreviewAt
  Assert-True ($feedbackPreview.target_content -match '(?m)^record_status: draft$') 'feedback import remains draft'
  Assert-True ($feedbackPreview.target_content -match '(?m)^user_confirmed_at: null$') 'feedback import is not user-confirmed'
  $feedbackImport = Import-ExchangeCard -Kind MarketFeedback -CardPath $feedbackCard -VaultRoot $personalVault -ExchangeRoot $exchangeRoot -ExpectedHash $feedbackPreview.source_hash -PreviewAt $feedbackPreview.preview_at -PreviewToken $feedbackPreview.preview_token
  $mappedFeedbackPath = Join-Path $personalVault ($feedbackImport.target_relative_path.Replace('/', '\'))
  $mappedFeedbackValidation = Test-ExchangeCard -Path $mappedFeedbackPath -ExpectedKind MarketFeedback
  Assert-True ($mappedFeedbackValidation.valid -and (Get-Content -LiteralPath $mappedFeedbackPath -Raw -Encoding UTF8) -match '(?m)^record_status: draft$') 'imported feedback validates as draft'
  Assert-ErrorCode { New-ExchangeImportPreview -Kind MarketFeedback -CardPath $feedbackCard -VaultRoot $personalVault -ExchangeRoot $exchangeRoot -PreviewAt $feedbackPreviewAt } 'E_DUPLICATE' 'duplicate feedback import is rejected'

  $confirmedFeedback = [IO.File]::ReadAllText($mappedFeedbackPath, $utf8NoBom)
  $confirmedFeedback = $confirmedFeedback.Replace('record_status: draft', 'record_status: confirmed')
  $confirmedFeedback = $confirmedFeedback.Replace('updated_at: "2026-07-12T21:10:00+08:00"', 'updated_at: "2026-07-12T21:20:00+08:00"')
  $confirmedFeedback = $confirmedFeedback.Replace('user_confirmed_at: null', 'user_confirmed_at: "2026-07-12T21:20:00+08:00"')
  [IO.File]::WriteAllText($mappedFeedbackPath, $confirmedFeedback, $utf8NoBom)
  $confirmedResult = Test-ExchangeCard -Path $mappedFeedbackPath -ExpectedKind MarketFeedback
  Assert-True ($confirmedResult.content_hash -eq $validFeedback.content_hash) 'feedback confirmation preserves source hash'

  $orphanPersonalVault = Join-Path $tempRoot '个人空间-orphan'
  New-Directory (Join-Path $orphanPersonalVault '60_双工具交换\能力移交卡')
  New-Directory (Join-Path $orphanPersonalVault '60_双工具交换\市场反馈')
  Assert-ErrorCode { New-ExchangeImportPreview -Kind MarketFeedback -CardPath $feedbackCard -VaultRoot $orphanPersonalVault -ExchangeRoot $exchangeRoot -PreviewAt $feedbackPreviewAt } 'E_SOURCE_LINK' 'orphan feedback is rejected'

  $piiPath = Join-Path $feedbackInbox 'market_feedback--pii.md'
  $pii = [IO.File]::ReadAllText($feedbackFixture, $utf8NoBom)
  $pii = $pii.Replace('feedback_summary: "试用者能理解交付，但认为结果稳定性说明不足"', 'feedback_summary: "请联系 13800138000 继续沟通"')
  $payloadMatch = [regex]::Match($pii, '(?m)^\{"record_type":"market_feedback".*\}$')
  $piiPayload = $payloadMatch.Value.Replace('"feedback_summary":"试用者能理解交付，但认为结果稳定性说明不足"', '"feedback_summary":"请联系 13800138000 继续沟通"')
  $pii = $pii.Remove($payloadMatch.Index, $payloadMatch.Length).Insert($payloadMatch.Index, $piiPayload)
  $piiHash = Get-TextHash $piiPayload
  $pii = $pii.Replace('5e1c7197aaaea4d78e531cb51568d98e6ae4d95f37b9fa3a40fbcae8b78ac527', $piiHash)
  Write-TestFile $piiPath $pii
  Assert-ErrorCode { Test-ExchangeCard -Path $piiPath -ExpectedKind MarketFeedback } 'E_PRIVACY' 'feedback with phone number is rejected'

  $exportRoot = Join-Path $tempRoot 'export-box'
  New-Directory (Join-Path $exportRoot 'capability_to_business')
  New-Directory (Join-Path $exportRoot 'market_feedback_to_personal')
  $exportResult = Export-ExchangeCard -Kind CapabilityTransfer -RecordPath $capabilityFixture -ExchangeRoot $exportRoot -ExpectedHash $validCapability.content_hash
  Assert-True (Test-Path -LiteralPath (Join-Path $exportRoot "capability_to_business\$($exportResult.file)")) 'capability export copies immutable card'
  Assert-ErrorCode { Export-ExchangeCard -Kind CapabilityTransfer -RecordPath $capabilityFixture -ExchangeRoot $exportRoot -ExpectedHash $validCapability.content_hash } 'E_DUPLICATE' 'duplicate export is rejected'

  $cli = Join-Path $PSScriptRoot 'exchange-card.ps1'
  $cliOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $cli -Action Validate -Kind CapabilityTransfer -CardPath $capabilityFixture -Json
  Assert-True (($LASTEXITCODE -eq 0) -and (($cliOutput -join '') -match '"valid":true')) 'CLI validate returns JSON success'
} finally {
  if (Test-Path -LiteralPath $tempRoot) {
    $resolvedTemp = (Resolve-Path -LiteralPath $tempRoot).Path
    $systemTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
    if ($resolvedTemp.StartsWith($systemTemp + '\', [StringComparison]::OrdinalIgnoreCase)) {
      Remove-Item -LiteralPath $resolvedTemp -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}

Write-Host ''
Write-Host ("Exchange contract tests: {0} passed, {1} failed." -f $script:passed, $script:failed)
if ($script:failed -gt 0) { exit 1 }
exit 0
