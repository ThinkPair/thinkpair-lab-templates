param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('Validate', 'PreviewImport', 'ApplyImport', 'Export')]
  [string]$Action,

  [Parameter(Mandatory = $true)]
  [ValidateSet('CapabilityTransfer', 'MarketFeedback')]
  [string]$Kind,

  [string]$CardPath,
  [string]$RecordPath,
  [string]$VaultRoot,
  [string]$ExchangeRoot,
  [string]$ExpectedHash,
  [string]$PreviewAt,
  [string]$PreviewToken,
  [switch]$Json
)

$ErrorActionPreference = 'Stop'
$modulePath = Join-Path $PSScriptRoot 'ExchangeContract.psm1'
Import-Module $modulePath -Force

function Require-Value {
  param([string]$Name, [AllowNull()][AllowEmptyString()][string]$Value)
  if ([string]::IsNullOrWhiteSpace($Value)) {
    $exception = New-Object System.ArgumentException("Missing required parameter: $Name")
    $exception.Data['ExchangeCode'] = 'E_ARGUMENT'
    throw $exception
  }
}

function Write-Result {
  param([Parameter(Mandatory = $true)]$Value)
  if ($Json) {
    $Value | ConvertTo-Json -Depth 20 -Compress
  } else {
    $Value | Format-List | Out-String | Write-Host
  }
}

$exitCodes = @{
  E_ARGUMENT = 2
  E_IO = 2
  E_PATH = 2
  E_ENVELOPE = 3
  E_TYPE = 3
  E_SCHEMA_UNSUPPORTED = 3
  E_FIELD_SET = 3
  E_ID = 3
  E_STATUS = 3
  E_HASH = 4
  E_MIRROR = 4
  E_DUPLICATE = 5
  E_ID_CONFLICT = 5
  E_TARGET_COLLISION = 5
  E_SOURCE_LINK = 6
  E_PRIVACY = 7
  E_PREVIEW_STALE = 9
  E_WRITE = 8
  E_INTERNAL = 10
}

try {
  switch ($Action) {
    'Validate' {
      Require-Value 'CardPath' $CardPath
      $result = Test-ExchangeCard -Path $CardPath -ExpectedKind $Kind
    }
    'PreviewImport' {
      Require-Value 'CardPath' $CardPath
      Require-Value 'VaultRoot' $VaultRoot
      Require-Value 'ExchangeRoot' $ExchangeRoot
      $result = New-ExchangeImportPreview -Kind $Kind -CardPath $CardPath -VaultRoot $VaultRoot -ExchangeRoot $ExchangeRoot -PreviewAt $PreviewAt
    }
    'ApplyImport' {
      Require-Value 'CardPath' $CardPath
      Require-Value 'VaultRoot' $VaultRoot
      Require-Value 'ExchangeRoot' $ExchangeRoot
      Require-Value 'ExpectedHash' $ExpectedHash
      Require-Value 'PreviewAt' $PreviewAt
      Require-Value 'PreviewToken' $PreviewToken
      $result = Import-ExchangeCard -Kind $Kind -CardPath $CardPath -VaultRoot $VaultRoot -ExchangeRoot $ExchangeRoot -ExpectedHash $ExpectedHash -PreviewAt $PreviewAt -PreviewToken $PreviewToken
    }
    'Export' {
      Require-Value 'RecordPath' $RecordPath
      Require-Value 'ExchangeRoot' $ExchangeRoot
      Require-Value 'ExpectedHash' $ExpectedHash
      $result = Export-ExchangeCard -Kind $Kind -RecordPath $RecordPath -ExchangeRoot $ExchangeRoot -ExpectedHash $ExpectedHash
    }
  }
  Write-Result $result
  exit 0
} catch {
  $code = Get-ExchangeErrorCode -Exception $_.Exception
  if ($code -eq 'E_INTERNAL' -and $_.Exception.Data.Contains('ExchangeCode')) {
    $code = [string]$_.Exception.Data['ExchangeCode']
  }
  $failure = [pscustomobject]@{
    ok = $false
    code = $code
    message = $_.Exception.Message
  }
  if ($Json) {
    $failure | ConvertTo-Json -Compress
  } else {
    Write-Host ("Exchange operation failed [{0}]: {1}" -f $code, $_.Exception.Message) -ForegroundColor Red
  }
  $exitCode = if ($exitCodes.ContainsKey($code)) { [int]$exitCodes[$code] } else { 10 }
  exit $exitCode
}
